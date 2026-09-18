// R3D-4a, approach B — the depth pass. Renders every opaque board mesh as its own camera-space
// depth (distance along the view axis, which is what an orthographic camera measures), packed
// into two 8-bit channels (R = high byte, G = low byte, 16 bits over `depth_range` units).
// The pipeline sRGB-encodes what an unshaded material writes, so the value is decoded first:
// the bytes that land in the viewport texture are exactly hi/lo.
shader_type spatial;
render_mode unshaded;

uniform float depth_range = 100.0;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	float d = clamp(-VERTEX.z / depth_range, 0.0, 0.99999);
	float v = floor(d * 65535.0 + 0.5);
	float hi = floor(v / 256.0);
	float lo = v - hi * 256.0;
	ALBEDO = srgb_to_linear(vec3(hi / 255.0, lo / 255.0, 0.0));
}
