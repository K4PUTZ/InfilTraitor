shader_type canvas_item;

// GLASS G1 — the glass pane, composited against a BACKBUFFER snapshot.
//
// THE CONTAINER (Director, 2026-08-30: *"criar um container rasterizado, de forma
// que as opacidades das faces não conflitem"*). A BackBufferCopy captures the
// scene just before the glass draws; every glass fragment reads THAT snapshot,
// applies the tint + sheen ONCE, and blends the result in with blend_mix at its
// coverage alpha. Overlapping voxel faces (a pane's edge voxels carry their side
// and top for 1-voxel thickness) all read the same snapshot, so there is no
// tint² where they overlap — the whole pane reads as one surface (G-D2).
render_mode blend_mix;

#include "res://godot/shaders/glass_shading.gdshaderinc"

// The pre-glass scene, captured by VoxelRenderer's BackBufferCopy.
uniform sampler2D glass_screen : hint_screen_texture, filter_linear;

// ── CRACK-01 (GLASS_MASTER_PLAN §8.2, G-D19/G-D21/G-D23) ─────────────────────
//
// G-D21 amended 2026-09-02: the crack is a plain texture sampled by the
// fragment's offset from the IMPACT — a subtraction, one fetch, ZERO atoms
// minted. Not the baked `_compute_facade_key()` offset (glass never rides that
// path) and not a reanchored atom page (36–144 MB, §8.2).
//
// Two data sources, both owned by VoxelRenderer:
//   · glass_crack_plane — one R8 texel per glass cell, per level: the CRACK
//     GROUP id (0 = intact). The soot-plane pattern (`_write_cell_soot`), reused
//     verbatim down to the origin offset.
//   · glass_crack_groups — a GLASS_CRACK_GROUP_CAP-wide RGBAF strip: one texel
//     per crack EVENT. rg = the impact voxel's CANVAS position, b = axis +
//     2·wide, a = active. This is what solves §8.2's multiplicity (each pane its
//     own impact) without a `uniform vec3[]`, which prints a compiler error on
//     every boot in this shader family (V-B).
uniform sampler2D glass_crack_plane : filter_nearest, repeat_disable, hint_default_black;
uniform vec2 glass_crack_plane_size = vec2(512.0, 512.0);
uniform vec2 glass_crack_plane_origin = vec2(64.0, 64.0);
uniform sampler2D glass_crack_groups : filter_nearest, repeat_disable, hint_default_black;
uniform float glass_crack_group_cap = 16.0;
// The two fracture sheets (G-D14). hint_default_black so an unbound sampler
// reads "no crack" rather than white.
uniform sampler2D glass_fracture_tight : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D glass_fracture_wide : filter_linear, repeat_disable, hint_default_black;

// ⚠️ THE PANE IS A WALL FACE, AND THE GROUND-PLANE INVERSE DOES NOT ADDRESS IT.
//
// The first build reused `voxel_face_shading`'s inverse basis to turn a fragment
// into a sheet UV. That basis answers "which GROUND cell is this screen point",
// and on a vertical face the vertical screen axis is LEVEL, not ground depth:
// `c.x = P.x/32 + P.y/16`, so moving one level DOWN (20 px) shifts the sheet
// column by 1.25 voxels. The crack sheared 1.25 voxels per level and the web
// read as scrambled, disconnected tiles (Director, 2026-09-02: *"as linhas não
// se encontram e estão todas embaralhadas"*).
//
// A wall face has its own, simpler basis. A voxel's canvas position is
//     P = origin + run · RUN_STEP + level · (0, −VOXEL_STEP)
// with RUN_STEP = map_to_local's e1 (16, 8) for a run along X, e2 (−16, 8) for a
// run along Y — the sign `sx` below. Inverting the 2×2:
//     run   =  sx · d.x / RUN_STEP.x
//     level = (run · RUN_STEP.y − d.y) / VOXEL_STEP
// Continuous by construction, exact on the face, and no cell recovery in it.
uniform vec2 glass_run_step = vec2(16.0, 8.0);
uniform float glass_voxel_step_px = 20.0;

// How many VOXELS the full 64 × 32 sheet spans on screen, per width. This is the
// compactness dial (Director, 2026-09-02: *"está muito grande o padrão visual pra
// um buraco de pistola"*): the sheets carry their ink in the middle ~34% of the
// page, so a `tight` span of 20 × 10 puts a pistol's web inside ~3–4 voxels.
uniform vec2 glass_sheet_span_tight = vec2(20.0, 10.0);
uniform vec2 glass_sheet_span_wide = vec2(44.0, 22.0);

// Set per level by VoxelRenderer: the offset between canvas space (all the
// vertex stage can see) and layer space, exactly as voxel_face_shading's
// `layer_origin`. Only the PLANE lookup needs it now.
uniform vec2 glass_layer_origin = vec2(0.0);
// Cell recovery for the PLANE lookup only — the same affine inverse
// voxel_face_shading.gdshader uses, quantised per quad, which is what makes it
// correct here: one cell per voxel quad, never a per-fragment coordinate.
uniform vec2 glass_inv_basis_row0 = vec2(0.03125, 0.0625);
uniform vec2 glass_inv_basis_row1 = vec2(-0.03125, 0.0625);
uniform vec2 glass_quad_to_map = vec2(0.0, 20.0);

// ⚠️ THE LOOK. G-D19's "50% see-through on a cracked voxel" was built FLAT, and
// the Director rejected it on sight (2026-09-02): a uniform frost over every
// voxel in the radius reads as *"praticamente um bloco que parece outro material
// no meio do vidro"* — a rectangle, because its silhouette is the RADIUS, not
// the fracture. So the drop is DENSITY-DRIVEN: the glass loses see-through
// exactly where the sheet has ink, and the effect's outline becomes the crack's
// own. G-D19's intent survives (a cracked voxel is less see-through, and the
// tactical half is state-driven anyway); the rectangle does not.
uniform float glass_crack_frost : hint_range(0.0, 2.0) = 0.85;
uniform float glass_crack_ink : hint_range(0.0, 1.0) = 0.75;
uniform vec3 glass_crack_ink_color : source_color = vec3(0.90, 0.94, 1.0);
// A soft outer falloff so the web fades instead of ending on a voxel boundary.
uniform float glass_crack_edge_feather : hint_range(0.0, 0.5) = 0.18;

void vertex() {
	v_glass_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// CRACK-01 — the web + the see-through drop for one fragment, given the glass
// colour `lit` already computed. `frag_cell` is the recovered voxel cell (for
// the PLANE lookup, quantised per quad); `canvas` is this fragment's canvas
// position, which is all the sheet UV needs. Returns `lit` unchanged off a
// cracked cell or off the sheet (G-D23: beyond the sheet there is simply no
// crack, never a mirrored one).
vec3 glass_apply_crack(vec3 lit, vec2 frag_cell, vec2 canvas, vec3 tint) {
	vec2 pcell = frag_cell + glass_crack_plane_origin;
	if (pcell.x < 0.0 || pcell.y < 0.0
			|| pcell.x >= glass_crack_plane_size.x || pcell.y >= glass_crack_plane_size.y) {
		return lit;
	}
	float gid = floor(texture(glass_crack_plane,
			(pcell + vec2(0.5)) / glass_crack_plane_size).r * 255.0 + 0.5);
	if (gid < 1.0 || gid > glass_crack_group_cap) {
		return lit;
	}
	vec4 grp = texelFetch(glass_crack_groups, ivec2(int(gid) - 1, 0), 0);
	if (grp.a < 0.5) {
		return lit;
	}
	// RGBAF, no decode: rg = the impact voxel's canvas position.
	// b = axis + 2·wide (axis 0 = run along X, 1 = along Y).
	float axis = mod(grp.b, 2.0);
	float is_wide = step(2.0, grp.b);
	float sx = mix(1.0, -1.0, axis);          // e1 (16,8) vs e2 (−16,8)

	// The WALL-FACE inverse — see the uniform block. Continuous, and it does not
	// shear a level into a column the way the ground-plane inverse did.
	vec2 d = canvas - grp.rg;
	float run_off = sx * d.x / glass_run_step.x;
	float level_off = (run_off * glass_run_step.y - d.y) / glass_voxel_step_px;

	vec2 span = mix(glass_sheet_span_tight, glass_sheet_span_wide, is_wide);
	vec2 fuv = vec2(0.5 + run_off / span.x, 0.5 - level_off / span.y);

	// G-D23 — the clamp. Beyond the sheet there is no crack at all, so this
	// fragment is untouched glass (NOT frosted: the frost is the crack's, and a
	// frost without a crack is the rectangle the Director rejected).
	if (fuv.x < 0.0 || fuv.x > 1.0 || fuv.y < 0.0 || fuv.y > 1.0) {
		return lit;
	}
	float crack = clamp(mix(
		texture(glass_fracture_tight, fuv).r,
		texture(glass_fracture_wide, fuv).r,
		is_wide), 0.0, 1.0);
	// Feather the last band of the sheet so the web fades out instead of ending
	// on a hard edge.
	vec2 e = min(fuv, vec2(1.0) - fuv) / max(glass_crack_edge_feather, 0.001);
	crack *= clamp(min(e.x, e.y), 0.0, 1.0);
	if (crack <= 0.0) {
		return lit;
	}

	// G-D19, DENSITY-DRIVEN — the see-through drop rides the ink, so the effect's
	// silhouette is the fracture rather than the crack radius.
	float frost = texture(glass_frost_tex, canvas * glass_frost_scale).r;
	vec3 frosted = tint * (0.40 + 0.60 * frost);
	vec3 out_rgb = mix(lit, frosted, clamp(crack * glass_crack_frost, 0.0, 1.0));
	out_rgb = mix(out_rgb, glass_crack_ink_color, crack * glass_crack_ink);
	return out_rgb;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float cover = smoothstep(glass_alpha_floor, 0.85, t.a);
	if (cover <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 local = mod(UV / TEXTURE_PIXEL_SIZE, atom_size);
		vec3 behind = texture(glass_screen, SCREEN_UV).rgb;
		// The atom's RED channel is the per-plane DIM (1.0 face, <1 top/side cap);
		// its BLUE channel is the glass member's tint index (G-D16 / V-B). GREEN is
		// reserved for G-D19's per-voxel damage term and is not read yet.
		vec3 tint = glass_class_tint(t.b);
		vec3 lit = glass_apply(behind, local, t.r, tint);

		// CRACK-01 — the cell, for the PLANE lookup only. `quad_tl` is the quad's
		// top-left in layer space, so this is quantised per voxel (which is what
		// makes the ground-plane inverse legitimate HERE). The sheet UV takes the
		// raw canvas position instead — see glass_apply_crack.
		vec2 quad_tl = (v_glass_world - glass_layer_origin) - local;
		vec2 frag_cell = floor(vec2(
			dot(glass_inv_basis_row0, quad_tl + glass_quad_to_map),
			dot(glass_inv_basis_row1, quad_tl + glass_quad_to_map)) + 0.5);
		lit = glass_apply_crack(lit, frag_cell, v_glass_world, tint);

		COLOR = vec4(lit, cover);
	}
}
