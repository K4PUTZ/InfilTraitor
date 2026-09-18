// RENDER3D R3D-5b — a flat overlay on the 3D board's ground plane (movement range, path preview,
// selection diamond, ...). The vertex colour carries colour and alpha as the 2D overlay drew them
// (display values); decoded once to linear for the pipeline to encode. Depth-tested and never
// depth-writing: a wall in front of a tile hides it, an actor standing on it covers it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ALPHA = COLOR.a;
}
