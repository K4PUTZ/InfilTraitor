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
		vec3 lit = glass_apply(behind, local);
		COLOR = vec4(lit, cover);
	}
}
