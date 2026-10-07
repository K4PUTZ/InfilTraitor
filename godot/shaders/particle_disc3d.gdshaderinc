// RENDER3D R3D-4e-1 — one disc of a CircleField3D. `CircleField` (2D) gets its soft rim from a canvas
// shader that reads the mesh UV; this is that shader as a SPATIAL one, on a quad. The instance colour
// carries the per-particle colour and alpha; display values in, linear out (the pipeline encodes).
uniform float feather : hint_range(0.0, 1.0) = 0.0;
varying vec4 inst_color;   // the instance colour in LINEAR light (converted once per vertex, not once per fragment)

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	inst_color = vec4(srgb_to_linear(COLOR.rgb), COLOR.a);
}

// No `discard`, and no per-fragment `pow`: a disc is drawn by the thousands (smoke, dust, embers, the steam vents) and they were the cost of a
// plume on the Moto (a vent at gameplay zoom cost 5-7 ms, 2026-10-06). The alpha already reaches 0 at the rim (`1 - smoothstep(1 - f, 1, d)` is 0 for
// d >= 1), so the discard added nothing but a break in the GPU's early-out; and the colour is the same on every fragment of an instance.
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float f = max(feather, 0.0001);
	ALBEDO = inst_color.rgb;
	ALPHA = inst_color.a * (1.0 - smoothstep(1.0 - f, 1.0, d));
}
