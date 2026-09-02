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
// G-D21 amended 2026-09-02: the crack is a plain texture sampled by RECOVERED
// (cell, level) against the impact's own (cell, level) — a subtraction, one
// fetch, ZERO atoms minted. Not the baked `_compute_facade_key()` offset (glass
// never rides that path) and not a reanchored atom page (36–144 MB, §8.2).
//
// Two data sources, both owned by VoxelRenderer:
//   · glass_crack_plane — one R8 texel per glass cell, per level: the CRACK
//     GROUP id (0 = intact). The soot-plane pattern (`_write_cell_soot`), reused
//     verbatim down to the origin offset.
//   · glass_crack_groups — a GLASS_CRACK_GROUP_CAP-wide RGBAF strip: one texel
//     per crack EVENT. r = impact run-coord, g = impact rel-level, b = axis +
//     2·wide, a = active. This is what solves §8.2's multiplicity (each pane its
//     own impact) without a `uniform vec3[]`, which prints a compiler error on
//     every boot in this shader family (V-B).
uniform sampler2D glass_crack_plane : filter_nearest, repeat_disable, hint_default_black;
uniform vec2 glass_crack_plane_size = vec2(512.0, 512.0);
uniform vec2 glass_crack_plane_origin = vec2(64.0, 64.0);
uniform sampler2D glass_crack_groups : filter_nearest, repeat_disable, hint_default_black;
uniform float glass_crack_group_cap = 16.0;
// The two fracture sheets (G-D14). Sampled by the reanchored (cell, level) UV;
// hint_default_black so an unbound sampler reads "no crack" rather than white.
uniform sampler2D glass_fracture_tight : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D glass_fracture_wide : filter_linear, repeat_disable, hint_default_black;
// The sheet's own voxel dimensions — 64 columns × 32 rows (one facade page,
// G-D21/G-D23). The reanchored UV is (frag − impact) / this + 0.5.
uniform vec2 glass_sheet_voxels = vec2(64.0, 32.0);

// This layer's own rel-level, and the offset between canvas space (all the
// vertex stage can see) and layer space (what the cell recovery inverts). Both
// set per level by VoxelRenderer, exactly as voxel_face_shading.gdshader's
// `layer_origin` is.
uniform float glass_layer_rel_level = 0.0;
uniform vec2 glass_layer_origin = vec2(0.0);
// Cell recovery — the SAME affine inverse voxel_face_shading.gdshader uses (the
// glass atom registers pixel-exact with the opaque layer). The simple form
// without that shader's provoking-vertex corner_shift: the glass atlas is 16
// atoms, so `mod`'s float residue is negligible and a 1px edge fragment landing
// one cell off only mis-reads a crack GROUP whose neighbour carries the same id.
uniform vec2 glass_inv_basis_row0 = vec2(0.03125, 0.0625);
uniform vec2 glass_inv_basis_row1 = vec2(-0.03125, 0.0625);
uniform vec2 glass_quad_to_map = vec2(0.0, 20.0);

// The look. G-D19: a cracked voxel is ~50% less see-through — a flat per-voxel
// mix toward a frosted body, NOT a channel on the atom (the Director allowed
// this simplification, "G-D21 simplifies G-D19").
uniform float glass_crack_see_through : hint_range(0.0, 1.0) = 0.5;
uniform float glass_crack_ink : hint_range(0.0, 1.0) = 0.85;
uniform vec3 glass_crack_ink_color : source_color = vec3(0.90, 0.94, 1.0);

void vertex() {
	v_glass_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// CRACK-01 — the web + the see-through drop for one fragment, given the glass
// colour `lit` already computed. `frag_cell` is the recovered voxel cell, `tint`
// the member tint (for the frosted body). Returns `lit` unchanged when this
// fragment's cell carries no crack group or the reanchored sample lands off the
// sheet (G-D23: beyond the sheet there is simply no crack, never a mirrored one).
vec3 glass_apply_crack(vec3 lit, vec2 frag_cell, vec2 local_frost_world, vec3 tint) {
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
	// RGBAF — raw voxel coords, no decode. b = axis + 2·wide.
	float impact_run = grp.r;
	float impact_rel_level = grp.g;
	float axis = mod(grp.b, 2.0);             // 0 = run along X, 1 = along Y
	float is_wide = step(2.0, grp.b);
	float frag_run = mix(frag_cell.x, frag_cell.y, axis);

	vec2 fuv = vec2(
		0.5 + (frag_run - impact_run) / glass_sheet_voxels.x,
		0.5 + (impact_rel_level - glass_layer_rel_level) / glass_sheet_voxels.y);

	// G-D19 — the whole cracked voxel loses see-through, whether or not a crack
	// LINE passes through this exact fragment.
	float frost = texture(glass_frost_tex, local_frost_world * glass_frost_scale).r;
	vec3 frosted = tint * (0.40 + 0.60 * frost);
	vec3 out_rgb = mix(lit, frosted, glass_crack_see_through);

	// G-D23 — the clamp. Off the sheet: the see-through drop stays, the web does
	// not wrap.
	if (fuv.x < 0.0 || fuv.x > 1.0 || fuv.y < 0.0 || fuv.y > 1.0) {
		return out_rgb;
	}
	float crack = mix(
		texture(glass_fracture_tight, fuv).r,
		texture(glass_fracture_wide, fuv).r,
		is_wide);
	out_rgb = mix(out_rgb, glass_crack_ink_color, clamp(crack, 0.0, 1.0) * glass_crack_ink);
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

		// CRACK-01 — recover this fragment's cell and overlay any crack on it.
		vec2 quad_tl = (v_glass_world - glass_layer_origin) - local;
		vec2 frag_cell = floor(vec2(
			dot(glass_inv_basis_row0, quad_tl + glass_quad_to_map),
			dot(glass_inv_basis_row1, quad_tl + glass_quad_to_map)) + 0.5);
		lit = glass_apply_crack(lit, frag_cell, v_glass_world, tint);

		COLOR = vec4(lit, cover);
	}
}
