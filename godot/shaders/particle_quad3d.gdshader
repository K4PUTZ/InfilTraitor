// RENDER3D R3D-4e-3 — one solid rectangle of a QuadField3D: a spark streak segment, a shrapnel trail
// segment, a rotated debris chip. The instance colour carries the colour and alpha; display values in,
// linear out. MIX blend, depth-tested, never writing depth (a particle must not hide a particle).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

varying vec4 inst_color;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	inst_color = COLOR;
}

void fragment() {
	ALBEDO = srgb_to_linear(inst_color.rgb);
	ALPHA = inst_color.a;
}
