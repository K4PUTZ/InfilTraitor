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

void fragment() {
	vec2 local = mod(UV / TEXTURE_PIXEL_SIZE, atom_size);

	// Top diamond: |dx|/halfW + |dy|/halfH <= 1 about the diamond's own centre.
	vec2 half_top = vec2(atom_size.x * 0.5, top_face_h * 0.5);
	float diamond = abs(local.x - half_top.x) / half_top.x
			+ abs(local.y - half_top.y) / half_top.y;

	float f = face_sw;
	if (diamond <= 1.0) {
		f = face_top;
	} else if (local.x >= half_top.x) {
		f = face_se;
	}

	COLOR.rgb *= f;
}
