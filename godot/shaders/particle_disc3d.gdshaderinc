// RENDER3D R3D-4e-1 — one disc of a CircleField3D. `CircleField` (2D) gets its soft rim from a canvas
// shader that reads the mesh UV; this is that shader as a SPATIAL one, on a quad. The instance colour
// carries the per-particle colour and alpha; display values in, linear out (the pipeline encodes).
uniform float feather : hint_range(0.0, 1.0) = 0.0;
varying vec4 inst_color;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	inst_color = COLOR;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	if (d > 1.0) {
		discard;
	}
	float f = max(feather, 0.0001);
	ALBEDO = srgb_to_linear(inst_color.rgb);
	ALPHA = inst_color.a * (1.0 - smoothstep(1.0 - f, 1.0, d));
}
