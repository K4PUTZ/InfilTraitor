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

// ⚠️ THE CRACK IS NOT IN HERE, AND PUTTING IT BACK IS THE REJECTED DESIGN
// (CRACK-02 / G-D27, GLASS_MASTER_PLAN §13).
//
// CRACK-01-B added a crack plane, a groups strip and a per-fragment cell
// recovery to this shader. The Director rejected the result three times, and the
// third rejection was the mechanism itself: a crack drawn HERE inherits the
// atom's per-plane `dim`, the coverage alpha `cover` the whole fragment is
// blended at, and the quad seams — *"ainda dá pra ver muita diferença entre
// voxels"*. No amount of tuning reaches *"idênticos aos outros"* from inside the
// voxel. The web is a SPRITE over the pane now (glass_crack.gdshader), and this
// file is deliberately back to exactly what it was before CRACK-01-B.

void vertex() {
	v_glass_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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
		vec3 lit = glass_apply(behind, local, t.r, glass_class_tint(t.b));
		COLOR = vec4(lit, cover);
	}
}
