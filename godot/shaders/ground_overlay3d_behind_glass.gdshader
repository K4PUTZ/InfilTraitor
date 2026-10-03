// A ground overlay seen THROUGH a glass pane (RETIRE-3 follow-up): the same colour and alpha as `ground_overlay3d.gdshader`, drawn
// only where a pane is in front (stencil 1, written by `glass_pane3d.gdshader`) and at `fade` of its strength, so a line or a fill
// that lies behind glass reads as behind it instead of painted over it. The other half of the pair, for every other pixel, is
// `ground_overlay3d.gdshader` (stencil not equal 1); `GroundCanvas3D` chains this one as its `next_pass`.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
stencil_mode read, compare_equal, 1;

uniform float fade : hint_range(0.0, 1.0) = 0.3;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ALPHA = COLOR.a * fade;
}
