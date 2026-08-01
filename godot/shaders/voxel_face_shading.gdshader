shader_type canvas_item;

// ============================================================================
// STATUS 2026-07-31: WRITTEN AND SPIKED, NOT WIRED. VoxelRenderer does NOT
// attach this to its layers yet — deliberately, see "OPEN PROBLEM" below.
// Direction approved by the Director; the remaining blocker is one unknown
// about Godot's own UV parameterisation, not about the design.
//
// WHAT THE SPIKE PROVED: attaching a ShaderMaterial to the voxel TileMapLayers
// reaches BOTH tile paths — a real detonation capture changed 60.8% of the
// screen, against 0.25% for the equivalent change made in the atom ART, which
// only ever touches the voxels that bypass the baked lookup. So a shader IS the
// right seam, and no re-bake is needed.
//
// OPEN PROBLEM — deriving the ATOM-LOCAL pixel from UV. Two formulas were tried
// against the real scene and both produced artefacts, so neither is correct:
//   1. mod(UV / TEXTURE_PIXEL_SIZE, atom_size)
//      → fine checkerboard over every surface, including floor tops that should
//        be uniformly face_top.
//   2. fract(UV) * atom_size
//      → large diagonal bands; consistent with UV being normalised over the
//        WHOLE atlas (4096×576 for a baked page), so the entire page collapses
//        into a single atom-sized range.
// Next step is NOT another guess: write a debug shader that outputs UV and
// TEXTURE_PIXEL_SIZE directly as colour, capture it, and read the actual values
// back — then derive the mapping from measurement instead of assumption.
//
// Everything below is the intended shading logic and is believed correct once
// `local` is right; only that one line is in question.
// ============================================================================

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
// a facade page and never sees an art change. A shader is the only seam that
// covers both paths without re-baking anything.
//
// HOW THE FACE IS FOUND: both tile paths lay atoms out on an exact 32×36 grid
// aligned to the texture origin — the per-material sources are a single 32×36
// texture with one tile at (0,0), and register_baked_atlas_page() sets
// texture_region_size = (32, 36) with zero margins and zero separation. So the
// atom-local pixel is just mod(pixel, atom_size), with no per-tile uniform and
// no region lookup. The atom's geometry is canon (Transform Canon / SLICE-00):
// a top diamond over the first `top_face_h` rows, then the SW face left of the
// midline and the SE face right of it.
//
// This MULTIPLIES the existing colour, so the light bucket, the soot term and
// every tile modulate survive untouched underneath — this shader only decides
// how much darker one face is than another, never absolute brightness.

// Atom geometry — canon, not tuning. Changing these means the tiles moved.
uniform vec2 atom_size = vec2(32.0, 36.0);
uniform float top_face_h = 16.0;

// Tuning (Rule 1: never const). Kept at or below 1.0 so a face can only be
// darkened relative to the art, never brightened into clipping. The art itself
// keeps its single flat side tone; the differentiation lives here.
uniform float face_top : hint_range(0.0, 1.0) = 1.0;
uniform float face_se : hint_range(0.0, 1.0) = 1.0;
uniform float face_sw : hint_range(0.0, 1.0) = 0.80;

void fragment() {
	vec2 local = mod(UV / TEXTURE_PIXEL_SIZE, atom_size);  // ← the open problem

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
