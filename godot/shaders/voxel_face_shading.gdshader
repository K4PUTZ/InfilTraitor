shader_type canvas_item;

// FACE-READ-01 (Director, 2026-07-31) — per-FACE shading for voxel tiles.
//
// "Eu queria garantir que nunca as três faces de um voxel vão ter exatamente a
// mesma aparência [...] a gente fez com que toda a arte tivesse iluminação
// flat, justamente para poder usar os shaders."
//
// WHY A SHADER AND NOT ART: a TileMapLayer carries ONE modulate per cell (the
// light bucket, VL-01), which paints the whole 32×36 atom — top diamond and
// both side faces together. Differentiating faces in the source PNG was tried
// first and measured to move only 0.25% of a real capture, because it reaches
// exclusively the voxels that bypass the baked lookup (impact marks and D25
// carved half-voxels); every photographically baked wall takes its pixels from
// a facade page and never sees an art change. Measured for this shader on the
// same capture: 60.8%. A shader is the only seam that covers both paths, and
// it needs no re-bake.
//
// HOW THE FACE IS FOUND: both tile paths lay atoms out on an exact 32×36 grid
// aligned to the texture origin — the per-material sources are a single 32×36
// texture with one tile at (0,0), and register_baked_atlas_page() sets
// texture_region_size = (32, 36) with zero margins and zero separation. So the
// atom-local pixel is just mod(pixel, atom_size), with no per-tile uniform and
// no region lookup. VERIFIED by capture, not assumed: a debug build writing
// `local` out as a red/green gradient shows the gradient restarting once per
// atom across both the baked walls and the material-only floor
// (auto_2026-07-31_22-57-30.png). An earlier reading of a strong-value capture
// mistook this working per-voxel effect for a tiling artefact — the mapping was
// never wrong, the values were simply far too strong to read as shading.
//
// This MULTIPLIES the existing colour, so the light bucket, the soot term and
// every tile modulate survive untouched underneath — this shader only decides
// how much darker one face is than another, never absolute brightness.

// Atom geometry — canon, not tuning. Changing these means the tiles moved.
uniform vec2 atom_size = vec2(32.0, 36.0);
uniform float top_face_h = 16.0;

// Tuning (Rule 1: never const). DELIBERATELY SUBTLE — Director, 2026-07-31:
// *"usar valores baixos, essa diferenciação é pra ser sutil, e não causar
// grande impacto na aparência geral. O grande segredo é só diferenciar as 3
// faces de cada voxel."* What matters is only that the three values are
// DISTINCT, not that they are far apart; a strong spread reads as noise at this
// voxel size, which is what the first pass got wrong. Capped at 1.0 so a face
// can only be darkened relative to the art, never brightened into clipping.
uniform float face_top : hint_range(0.0, 1.0) = 1.00;
uniform float face_se : hint_range(0.0, 1.0) = 0.975;
uniform float face_sw : hint_range(0.0, 1.0) = 0.945;

// FACE-READ-02 (Director, 2026-08-01) — *"forçar a fuligem de destruição e
// tiros a seguir o mesmo princípio de nunca deixar um voxel existir com as 3
// faces totalmente iguais [...] garantir que as 3 faces tem uma micro
// diferença."*
//
// The multiplies above are PROPORTIONAL, so their effect shrinks with the
// pixel value and vanishes entirely into 8-bit quantisation exactly where soot
// lives. Measured over the real value grid (bucket_luminance x soot_darkening x
// FLOOR_DEPTH_DIM, art pixel 4..255): 63% of combinations rendered fewer than 3
// distinct face values, and the collapse reached mid-tones as bright as 38/255
// — a ring-0 sooted voxel at bucket 0.12 came out [4, 4, 4], three identical
// faces, which is precisely the state this whole shader exists to prevent.
//
// This term is the ABSOLUTE floor that survives quantisation: one extra 1/255
// step subtracted per face index (top 0, SE 1, SW 2). It is deliberately an
// offset and not a steeper multiply — a multiply large enough to survive at
// 4/255 would read as noise at 200/255, which is the failure the bucket-jitter
// experiment already hit and retired on 2026-07-31.
//
// Same measurement after: 4.7% residual, and EVERY remaining collapse has a top
// face of at most 2/255 — a voxel that is black on screen. So the guarantee is
// honest but bounded: three distinct faces wherever the voxel renders above
// 2/255, and below that nothing is distinguishable from black anyway.
//
// Soot from blasts and from firearms share one mechanism (D24), so this covers
// both with no separate firearm path.
// FACE-READ-03 (2026-08-01) — RETIRES face_min_sep, which FACE-SOOT-01 broke.
//
// face_min_sep was an absolute 1/255 offset subtracted per face INDEX (top 0,
// SE 1, SW 2). That works only while the three faces are already ordered
// top >= SE >= SW, which was true when every face took the same soot. Per-face
// soot inverts the order — a top face at ring 0 is darker than an SE face at
// ring 1 — and a fixed per-index offset can then land two faces on exactly the
// same 8-bit value. MEASURED, not predicted: sweeping the real canon grid
// (bucket_luminance x FLOOR_DEPTH_DIM x all 64 per-face ring combinations) with
// face_min_sep still in place collapses a pair at 24/255 — a plainly visible
// mid-tone, and the precise failure this shader exists to prevent.
//
// The replacement makes the guarantee UNCONDITIONAL by construction instead of
// arithmetically hoping: each face is forced onto its own residue class mod 3 of
// the 8-bit value (top ≡ 0, SE ≡ 1, SW ≡ 2). Two different residues cannot be
// equal, so no combination of light, depth, material colour or per-face soot can
// ever merge two faces — including the near-black range FACE-READ-02 had to
// explicitly exclude ("three distinct faces wherever a voxel renders above
// 2/255"). That caveat is now gone: the guarantee holds everywhere.
//
// Rounding is always DOWNWARD to the residue class (max 2/255 darker, never
// brighter, so nothing clips), with a single +3 correction when that would go
// below zero. Setting this to 0.0 disables the enforcement, which is what the
// selftest's teeth-check drives.
uniform float face_residue_sep : hint_range(0.0, 1.0) = 1.0;

// FACE-SOOT-01 (Director, 2026-08-01) — soot is now delivered PER FACE, and the
// shader is what applies it.
//
// WHY IT HAD TO MOVE HERE: soot used to multiply into the light BUCKET
// (VoxelLightField._static_factor). A bucket is one scalar per cell, so while
// soot lived inside it a voxel structurally could not carry three different
// amounts of scorch — the thing this shader exists to express.
//
// HOW THE PER-CELL DATA ARRIVES — and why NOT in R/G/B, which is what
// VOXEL_LIGHT_MASTER_PLAN's open item proposed: that proposal assumed the tile
// modulate was "a grayscale multiply" with three spare channels. Measured, it is
// not. On the baked path (BakeConfig.enabled, the live default) the pages are
// grayscale by invariant B2 and the MATERIAL'S COLOUR is precisely what those
// RGB channels carry (BakeCompositor._modulate_for_mode() returns
// material.base_color under MULTIPLY); on the material path the colour is in the
// texture instead. Packing three luminances into RGB destroys the material
// colour on the first path and splats it to a single channel on the second.
//
// ALPHA is genuinely free — occlusion stopped placing ghost alternatives at
// OCC-21 — so the per-face code rides there: VoxelRenderer._ensure_light_alt()
// writes modulate.a = (code + 1) / 64, code = top*16 + se*4 + sw with each face
// a soot ring 0..2 and 3 = clean. Clean is code 63 → alpha exactly 1.0, so an
// untouched voxel's tile is bit-identical to what it was before this existed.
// (PERF-02 B3-2: now `(code + 1) / 125`, code = top*25 + se*5 + sw, ring 0..3
// with 4 = clean — clean is code 124, still exactly alpha 1.0.)
//
// DECODING WITHOUT THE `MODULATE` BUILT-IN: COLOR arrives as
// texture(TEXTURE, UV) * tile_modulate * node_modulate, and every node modulate
// in play is opaque (FLOOR_DEPTH_DIM is Color(d, d, d, 1.0)), so dividing
// COLOR.a by the texture's own alpha recovers the carrier exactly. That avoids
// depending on whether MODULATE includes TileData.modulate for a TileMapLayer —
// a semantic this shader would otherwise be silently betting on. It costs one
// extra sample of a texel already in cache, and nothing else.
//
// PERF-02 B3-2 (2026-08-04): FOUR real soot tones per face, not three, and the
// code is packed base-5 (`top*25 + se*5 + sw`, ring 0..3 with 4 = clean, 125
// codes) instead of base-4. Rings 0/1/2 keep their exact previous multipliers,
// so a firearm's 3-ring scorch is bit-identical to before; ring 3 is new and
// only a blast reaches it. Five tones were asked for and do not fit — see
// VoxelRenderer.FACE_SOOT_CODE_COUNT for the measured alternative-id ceiling.
// The base lives in two files that cannot import each other (this one and
// VoxelLightField.FACE_SOOT_BASE); voxel_face_separation_selftest.gd parses
// these uniforms out of this file precisely so a change here cannot drift.
//
uniform vec4 soot_face_mult = vec4(0.33, 0.47, 0.69, 0.84);
// Ring 4 = clean. Split out of the vec4 above because there are now five
// entries; must be 1.0 or an untouched voxel would be tinted by a table it is
// not supposed to be subject to at all.
uniform float soot_clean_mult = 1.0;
// Below this texture alpha the division is not worth trusting (a fully
// transparent texel carries no recoverable carrier); such pixels are invisible
// anyway, so they simply take no soot.
uniform float soot_alpha_floor : hint_range(0.0, 0.5) = 0.02;

// PERF-P2 (2026-08-22) — THE SOOT CODE NOW ARRIVES PER CELL, NOT PER ALTERNATIVE.
//
// It used to ride in the alternative's `modulate.a`, which meant every distinct
// (bucket, soot) pair was a separate TileSet alternative and every soot change
// minted tiles and rebuilt the TileSet. PERFORMANCE_MASTER_PLAN §1.4: 12 buckets
// x 125 soot codes x 2 flips = up to 3 000 alternatives per tile. Read from a
// per-LEVEL data texture instead, one texel per cell, and a soot change becomes
// a pixel write.
//
// HOW THE CELL IS RECOVERED — proven by PERF-SPIKE-01 before any of this was
// designed (see the plan's §3):
//   · cell -> local position is exactly AFFINE on every voxel layer (0.000000 px
//     error out to cell (350,350); basis e1 (16,8), e2 (-16,8), det 256);
//   · each LEVEL is its own TileMapLayer, so the third dimension disappears and
//     `VERTEX` being layer-local makes layer.position cancel;
//   · the fragment's offset inside its own quad is exactly `local` below, so
//     `VERTEX - local` is the quad's TOP-LEFT and is CONSTANT across the quad.
//     That last one is what matters: all THREE faces of a voxel must resolve to
//     ONE cell, and this is why they do.
//   · quad top-left = map_to_local(cell) + (-16, -28), the same rect the
//     renderer builds — not a number invented here.
uniform sampler2D cell_soot : filter_nearest, repeat_disable, hint_default_white;
uniform vec2 cell_soot_size = vec2(512.0, 512.0);
// The map's buffer puts real geometry at NEGATIVE voxel cells — the seams
// between GUs resolve to things like (-8, 8) — so the plane is indexed from an
// origin, not from zero. Measured, not assumed: indexing from zero dropped ~12%
// of a frame's fragments onto the clean fallback.
uniform vec2 cell_plane_origin = vec2(64.0, 64.0);
// 1/32 and 1/16 written out: Godot rejects a division in a uniform default.
uniform vec2 inv_basis_row0 = vec2(0.03125, 0.0625);
uniform vec2 inv_basis_row1 = vec2(-0.03125, 0.0625);
uniform vec2 quad_to_map = vec2(0.0, 20.0);

// PERF-P3 GATE — paint the recovered cell's RAW plane byte, so a capture can be
// checked against a position computed in GDScript. 0.0 = off, and off is the
// shipping value.
//
// WHY IT LIVES IN THIS SHADER AND NOT IN A COPY: PERF-SPIKE-01 ran its gates
// against `experimental/voxel_face_shading_cellindex.gdshader`, and a gate that
// audits a copy proves things about the copy. The recovery this branch reads is
// the SAME `cell` the soot lookup below uses — there is nothing between them to
// drift. The cost of the branch is measured, not assumed (see the P3-GATE
// commit): a uniform that never changes is a scalar the driver folds, and the
// A/B at --fixed-fps 60 is what says so in pixels.
//
// The output is deliberately not a colour: R = the plane byte at the recovered
// cell, G = 0 and B = 255 as a signature (so a HUD or agent pixel cannot be
// mistaken for a marked voxel), and alpha is hard 0 or 1 — an antialiased edge
// blending a code with what is behind it would read back as a value that was
// never written, which is a false answer rather than a missing one.
uniform float cell_debug_paint : hint_range(0.0, 1.0) = 0.0;

// PERF-P3 — THE LIGHT BUCKET, READ FROM THE PLANE'S G CHANNEL.
//
// It used to arrive baked into the TileData modulate of a per-(bucket, soot)
// alternative, which is why a light change minted tiles and rebuilt the whole
// TileSet — measured at ~240 ms per committing frame of a fire, regardless of how
// many alternatives that frame minted (PERFORMANCE_MASTER_PLAN §8.15).
//
// `bucket_lum` is VoxelRenderer.bucket_luminance, pushed as a uniform so the
// ladder has exactly ONE definition; `p3_enabled` is 0.0 when the alternative
// path is live, so the same shader serves both sides of the A/B in one binary.
//
// ⚠️ The multiply MOVED, so this is not bit-identical to the old path: the
// modulate was quantised to 8 bits before the shader saw it, and this multiplies
// in float. FACE-READ-03's residue snap below absorbs most of the difference.
uniform float bucket_lum[12];
uniform float p3_enabled : hint_range(0.0, 1.0) = 0.0;

// PERF-P5 — the layer's own origin in canvas space, set per level by
// VoxelRenderer._build_voxel_layer_node(). See vertex() for why it exists.
uniform vec2 layer_origin = vec2(0.0);

varying vec2 v_vertex;

// §12.9 — THE QUAD'S OWN CORNER, CARRIED FLAT.
//
// `local` used to come from `mod(UV / TEXTURE_PIXEL_SIZE, atom_size)`, and `mod`
// is DISCONTINUOUS at the atlas region boundary: a fragment that belongs to
// region R but samples at or past R + 32 folds to ~0, and the recovered quad
// lands one quad width away. §12.8 measured that — 95.4% of the floor's wrong
// pixels within 8 px of a `mod` boundary, against a 3.2% error rate in true
// interiors — after ruling out float32 residue (exactly 0), off-grid atlas
// origins (none) and multi-cell tile spans (none).
//
// `flat` takes the PROVOKING VERTEX's value, so every fragment of a triangle
// receives one corner of its own quad, exactly, with no atlas arithmetic in the
// path at all. Which corner is driver-dependent and is resolved below from the
// fragment's own position rather than assumed — see fragment().
varying flat vec2 v_corner;

void vertex() {
	// ⚠️ `VERTEX` ALONE IS NOT LAYER-LOCAL, and the whole cell recovery below
	// depends on a coordinate that is.
	//
	// A TileMapLayer batches its tiles into quadrants of `rendering_quadrant_size`
	// cells (default 16) and pushes each quadrant's own transform, so plain
	// VERTEX is QUADRANT-local: the recovery read `cell mod 16`, measured as a
	// clean wrap in a scan of the painted cell (... (14,7) (-2,7) ...).
	//
	// Forcing one quadrant per layer fixes that and COSTS TOO MUCH — with a
	// single quadrant every `set_cell()` rebuilds the whole layer's draw list,
	// measured at 15 928 ms of burn wall clock against 10 986 ms at the default
	// 16, a 45% regression on the one event this project has spent two sessions
	// making cheaper.
	//
	// MODEL_MATRIX carries the quadrant transform folded in, so this is
	// canvas-space and therefore quadrant-independent; subtracting the layer's
	// own origin puts it back in layer space, which is what the inverse of
	// map_to_local() expects. Quadrants stay at the engine default.
	v_vertex = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - layer_origin;
	// Same value, taken flat — see the varying's note.
	v_corner = v_vertex;
}

void fragment() {
	vec2 local = mod(UV / TEXTURE_PIXEL_SIZE, atom_size);
	// PERF-P3 — SNAP THE QUAD ORIGIN TO THE PIXEL LATTICE BEFORE INVERTING.
	//
	// `v_vertex - local` is the quad's top-left, and in exact arithmetic it is
	// always an INTEGER layer-space point: map_to_local() returns integers and the
	// quad offset (region/2 + texture_origin) is integral too. In float32 it is
	// not, and the error is not uniform across the board — `local` comes from
	// `mod(UV / TEXTURE_PIXEL_SIZE, atom_size)`, whose input is an atlas pixel
	// coordinate. The floor's atlas is small; a baked WALL sheet carries 2 048
	// atoms, so its coordinates run into the thousands, where a float32 mantissa
	// leaves ~1e-4 and `mod` of a large value keeps very little of it.
	//
	// The `+ 0.5` below then turns that residue into a whole-cell error wherever
	// the fraction lands near a rounding boundary — which is why P3 rendered a
	// neighbour's light bucket on WALL facades and not on the floor.
	// §12.9 — WHICH CORNER `v_corner` IS, decided by this fragment, not assumed.
	//
	// Relative to the quad's TOP-LEFT a fragment sits in [0, 32) x [0, 36). So a
	// NEGATIVE component of `v_vertex - v_corner` can only mean the provoking
	// vertex was the right (or bottom) corner, and the top-left is one quad width
	// (or height) back. This is exact for every fragment of the quad and needs
	// neither the lattice nor the atlas — which matters, because the lattice
	// CANNOT decide it: (32, 0) is `e1 - e2`, a legitimate cell step of (+1, -1),
	// and that is precisely the ambiguity the old `mod` was losing to.
	vec2 corner_shift = vec2(
		(v_vertex.x - v_corner.x) < 0.0 ? atom_size.x : 0.0,
		(v_vertex.y - v_corner.y) < 0.0 ? atom_size.y : 0.0);
	vec2 quad_tl = floor(v_corner - corner_shift + 0.5);
	vec2 cell = floor(vec2(
		dot(inv_basis_row0, quad_tl + quad_to_map),
		dot(inv_basis_row1, quad_tl + quad_to_map)) + 0.5);

	// Top diamond: |dx|/halfW + |dy|/halfH <= 1 about the diamond's own centre.
	vec2 half_top = vec2(atom_size.x * 0.5, top_face_h * 0.5);
	float diamond = abs(local.x - half_top.x) / half_top.x
			+ abs(local.y - half_top.y) / half_top.y;

	// Face index: 0 = top, 1 = SE, 2 = SW. Drives BOTH the multiply and the
	// separation offset (FACE-READ-01/02) and the soot lookup (FACE-SOOT-01), so
	// the three can never disagree about which face they are shading.
	float f = face_sw;
	float sep_index = 2.0;
	if (diamond <= 1.0) {
		f = face_top;
		sep_index = 0.0;
	} else if (local.x >= half_top.x) {
		f = face_se;
		sep_index = 1.0;
	}

	float tex_a = texture(TEXTURE, UV).a;

	// PERF-P3 — the plane fetch, hoisted out of the soot branch below because the
	// LIGHT applies to every fragment while soot only applies above the alpha
	// floor. One texture() call now serves both channels.
	vec2 pcell = cell + cell_plane_origin;
	bool in_plane = pcell.x >= 0.0 && pcell.y >= 0.0
			&& pcell.x < cell_soot_size.x && pcell.y < cell_soot_size.y;
	vec2 plane = in_plane
			? texture(cell_soot, (pcell + vec2(0.5)) / cell_soot_size).rg
			: vec2(1.0, 1.0);

	if (p3_enabled > 0.5) {
		// A cell outside the plane reads FULL LIT, matching the fill and matching
		// what an unwritten cell meant under the alternative path (the base tile).
		// 255 is BUCKET_UNWRITTEN, the plane's sentinel; the clamp folds it (and an
		// out-of-plane fragment) onto full-lit, which is what the alternative path
		// rendered for a cell nothing had touched.
		int b = in_plane ? int(floor(plane.g * 255.0 + 0.5)) : 255;
		f *= bucket_lum[clamp(b, 0, 11)];
	}

	float ring = 4.0;  // clean
	if (tex_a > soot_alpha_floor) {
		// A cell outside the data texture reads CLEAN rather than wrapping —
		// repeat_disable plus hint_default_white already give 255, which the
		// clamp below folds onto 124 (clean), but the explicit bounds test is
		// what makes that a decision rather than a coincidence.
		float code = in_plane ? floor(plane.r * 255.0 + 0.5) : 124.0;
		code = clamp(code, 0.0, 124.0);
		// top*25 + se*5 + sw, selected by the face index resolved above.
		if (sep_index < 0.5) {
			ring = floor(code / 25.0);
		} else if (sep_index < 1.5) {
			ring = floor(mod(code, 25.0) / 5.0);
		} else {
			ring = mod(code, 5.0);
		}
	}
	f *= (ring < 3.5) ? soot_face_mult[int(ring)] : soot_clean_mult;
	COLOR.rgb = max(COLOR.rgb * f, vec3(0.0));

	// FACE-READ-03: force this face onto its own residue class mod 3, LAST, so
	// nothing downstream can re-merge two faces. See the uniform's note above.
	if (face_residue_sep > 0.0) {
		vec3 q = floor(COLOR.rgb * 255.0 + 0.5);
		vec3 adj = q - mod(q - sep_index, 3.0);
		adj += step(adj, vec3(-0.5)) * 3.0;
		COLOR.rgb = adj / 255.0;
	}
	// Alpha carried data, not transparency — hand back the real silhouette.
	COLOR.a = tex_a;

	// PERF-P3 GATE (see the uniform above). LAST, and as an overwrite rather
	// than an early exit, because Godot rejects `return` inside fragment().
	// Reads the plane RAW — no clamp to the 0..124 soot range — since the gate
	// issues codes the soot encoding has no room for, and clamping them would
	// fold different cells onto one value and hide the very confusion being
	// tested for.
	if (cell_debug_paint > 0.5) {
		vec2 dcell = cell + cell_plane_origin;
		float dcode = 0.0;
		if (dcell.x >= 0.0 && dcell.y >= 0.0
				&& dcell.x < cell_soot_size.x && dcell.y < cell_soot_size.y) {
			dcode = floor(texture(cell_soot, (dcell + vec2(0.5)) / cell_soot_size).r * 255.0 + 0.5);
		}
		COLOR = vec4(dcode / 255.0, 0.0, 1.0, step(0.99, tex_a));
	}
	// Mode 3 (PERF-P3) paints the plane's G channel — the LIGHT BUCKET, as the
	// GPU sees it. The CPU-side census can say the Image holds the right buckets
	// and still not answer whether the sampler agrees, which is the only question
	// when the data is right and the picture is not.
	if (cell_debug_paint > 2.5) {
		float g = in_plane ? floor(plane.g * 255.0 + 0.5) : 255.0;
		COLOR = vec4(g / 255.0, 0.0, 1.0, step(0.99, tex_a));
	}
	// Mode 2 paints the RECOVERED CELL ITSELF, EXACTLY, with no plane lookup in
	// the way. R and G carry the low byte of x and y; BLUE carries both high
	// bytes, biased so a negative recovery is representable rather than folded
	// onto a positive cell:
	//
	//   B = 64 + (x + 512) / 256 + 8 * ((y + 512) / 256)
	//
	// The bias is not decoration. An earlier version painted x mod 256 alone and
	// left the reader to decide between x and x + 256 by asking which one held a
	// voxel — on a board with a continuous floor BOTH always do, so it picked
	// the low one every time and reported 0% correct on a mapping that may well
	// have been right. B >= 64 also marks "a voxel drew this", which is what
	// separates the board from the cleared background.
	// Bounded ABOVE as well: mode 3 sits past this one, and an unbounded `> 1.5`
	// would let mode 2 overwrite it.
	if (cell_debug_paint > 1.5 && cell_debug_paint < 2.5) {
		float bx = clamp(floor((cell.x + 512.0) / 256.0), 0.0, 7.0);
		float by = clamp(floor((cell.y + 512.0) / 256.0), 0.0, 7.0);
		COLOR = vec4(mod(cell.x, 256.0) / 255.0, mod(cell.y, 256.0) / 255.0,
			(64.0 + bx + 8.0 * by) / 255.0, step(0.99, tex_a));
	}
	// Mode 5 (§12.8) — THE RESIDUE `floor(x + 0.5)` IS ABOUT TO ROUND.
	//
	// `v_vertex - local` is an INTEGER layer-space point in exact arithmetic, so
	// the distance from the nearest integer is pure error. The block above this
	// one predicts that error and blames float32 in `local`; §3.3 tried snapping
	// `local` and moved the gate by 0.02 points, which kills the fix but not the
	// diagnosis — a residue in `v_vertex` snapping cannot reach would behave the
	// same way. NOBODY HAS MEASURED THE RESIDUE ITSELF, on either surface.
	//
	// R and G carry |q - round(q)| for x and y, scaled by 2 so the byte spans the
	// full 0..0.5 range a rounding boundary lives in: 0 is exact, 255 is sitting
	// exactly on the flip. Ground-truth-free by construction — it needs no model
	// of which cell owns a pixel, which is what every earlier instrument here
	// needed and got wrong at least once.
	// Mode 6 (§12.8) — `local` ITSELF, the atom-local pixel offset.
	//
	// Mode 5 proved the residue is exactly 0, which kills float32 as the cause
	// and leaves only one way for the recovery to be wrong: `local` is an exact
	// integer that is exactly WRONG, i.e. `mod` is wrapping on the wrong period.
	// R = local.x * 8 and G = local.y * 7 spread 0..31 and 0..35 over most of a
	// byte, so a scanline read gives the WRAP PERIOD directly — which is the one
	// property `debug_atlas_alignment()` infers from the TileSet's declared
	// margins and pitch instead of observing in the rendered pixel.
	if (cell_debug_paint > 5.5 && cell_debug_paint < 6.5) {
		COLOR = vec4(clamp(local.x * 8.0 / 255.0, 0.0, 1.0),
			clamp(local.y * 7.0 / 255.0, 0.0, 1.0), 1.0, step(0.99, tex_a));
	}
	if (cell_debug_paint > 4.5 && cell_debug_paint < 5.5) {
		vec2 q = v_vertex - local;
		vec2 res = abs(q - floor(q + 0.5));
		COLOR = vec4(clamp(res.x * 2.0, 0.0, 1.0), clamp(res.y * 2.0, 0.0, 1.0),
			1.0, step(0.99, tex_a));
	}
}
