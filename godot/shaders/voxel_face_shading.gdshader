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

void fragment() {
	vec2 local = mod(UV / TEXTURE_PIXEL_SIZE, atom_size);

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
	float ring = 4.0;  // clean
	if (tex_a > soot_alpha_floor) {
		float code = floor((COLOR.a / tex_a) * 125.0 + 0.5) - 1.0;
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
}
