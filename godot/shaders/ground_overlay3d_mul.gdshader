// RENDER3D R3D-5b — the MULTIPLY twin of ground_overlay3d.gdshader, for TileOverlay (shadows, detection
// cone, exits): the result is floor.rgb × colour, as `CanvasItemMaterial.BLEND_MODE_MUL` did in 2D,
// where the colour's alpha is ignored and the darkness lives in its RGB. ALPHA is 1 to match.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mul;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ALPHA = 1.0;
}
