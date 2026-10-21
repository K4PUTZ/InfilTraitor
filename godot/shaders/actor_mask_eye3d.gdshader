// D71 PROTOTYPE — the mask's eye lens: dark when the mask is off, an amber light that RAMPS ON ("os olhos acendem") when `intensity` goes 0 -> 1.
// Unshaded and NOT dimmed by the board's light ladder: it is a light source, so it must stay bright in a dark room, which is exactly the liability the
// Director described (the glow is seen from 4-5 GU in dark places). Reads neither the screen nor the depth.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 glow : source_color = vec3(1.0, 0.58, 0.10);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	ALBEDO = mix(vec3(0.015, 0.014, 0.012), glow * (1.0 + 0.7 * intensity), intensity);
}
