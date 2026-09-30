// R3D-PROPS P6 — a prop's CONTACT SHADOW: a soft, flat, multiplied patch on the floor (PROPS_TIER4_PLAN D-P6, `ACTOR` D68).
// No shadow map (real lamps were +24 ms GPU on the Moto, the board is unshaded by design): the patch is a small image built once from
// the prop's own voxels, projected along the board's key light (`PropShadow`). MULTIPLY, like the tile shadows (`ground_overlay3d_mul`):
// the floor keeps its own light and soot and is only darkened where the shadow falls, so a shadow on sooted ground is darker ground.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mul;

uniform sampler2D shadow : filter_linear, repeat_disable;
uniform float strength = 0.42;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	float a = texture(shadow, UV).r;
	ALBEDO = srgb_to_linear(vec3(1.0 - strength * a));
	ALPHA = 1.0;
}
