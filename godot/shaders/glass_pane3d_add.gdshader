shader_type spatial;
// PERFORMANCE_BUDGET PB-2 — the screen-free glass, pass 2 of 2: ADDS the body floor and the sheen over pass 1's multiply.
// See `glass_pane3d_mul.gdshader` for the whole reasoning and what this approximates.
render_mode unshaded, cull_back, blend_add, depth_draw_never;
// Once per pixel, after pass 1 marked it (see `glass_pane3d_mul.gdshader`): 3 > stored 0/1 passes, writes 3; 3 > 3 fails.
stencil_mode read, write, compare_greater, 3;

#include "res://godot/shaders/glass_pane3d_common.gdshaderinc"

// The sRGB brightness of the background the add is calibrated for (see fragment()).
uniform float glass_add_base : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	if (glass_cut_open()) {
		discard;
	}
	// The original adds in sRGB, where +0.15 over a dark floor is a strong lift; added in linear the same term is ~0.02 and the
	// glass loses its glow. The pass cannot see the background, so it adds what the sRGB sum WOULD add over a typical one
	// (`glass_add_base`, sRGB, times this pane's multiply): to_linear(base × mul + add) - to_linear(base × mul).
	vec3 base = vec3(glass_add_base) * glass_mul_srgb();
	vec3 add = glass_tint * glass_min_body * v_face + glass_sheen_srgb();
	ALBEDO = max(to_linear(clamp(base + add, vec3(0.0), vec3(1.0))) - to_linear(base), vec3(0.0));
}
