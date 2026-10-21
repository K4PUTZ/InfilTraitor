// D71 PROTOTYPE — the soft glow around the mask's eye lens: an ADDITIVE quad with a radial falloff, brought up by `intensity`. No texture, no screen read.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 glow : source_color = vec3(1.0, 0.52, 0.08);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 q = (UV - vec2(0.5)) * vec2(2.0, 3.4);
	float a = pow(clamp(1.0 - length(q), 0.0, 1.0), 2.2) * intensity;
	ALBEDO = glow;
	ALPHA = clamp(a * 0.9, 0.0, 1.0);
}
