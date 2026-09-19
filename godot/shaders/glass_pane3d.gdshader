shader_type spatial;
// RENDER3D R3D-6 item 2 — the 2D glass look (glass_shading.gdshaderinc) on the 3D board.
// One pass that reads the scene BEHIND the pane, like the 2D board's BackBufferCopy container:
// every overlapping face reads the same "behind", so the tint applies once (G-D2). MULTIPLY the
// tint (with a faint self-body floor over dark backgrounds), then ADD the sheen.
// THE MATHS RUNS IN sRGB, like the 2D shader's: the screen texture arrives linear and ALBEDO is
// encoded on the way out, so doing it raw applied tint^(1/2.2) — measured 2026-09-19 as an
// effective multiply of (0.81, 0.87, 0.96) where the parameters ask for (0.61, 0.72, 0.91).
render_mode unshaded, cull_back, blend_mix, depth_draw_never;

uniform sampler2D glass_screen : hint_screen_texture, filter_linear;
uniform vec3 glass_tint = vec3(0.47, 0.63, 0.90);
uniform float face_top : hint_range(0.0, 1.0) = 1.000;
uniform float face_se : hint_range(0.0, 1.0) = 0.982;
uniform float face_sw : hint_range(0.0, 1.0) = 0.966;
uniform float glass_mul_strength : hint_range(0.0, 1.0) = 0.60;
uniform float glass_add_strength : hint_range(0.0, 1.0) = 0.20;
uniform float glass_sheen_freq = 0.011;
uniform float glass_sheen_phase = 0.6;
uniform float glass_sheen_sharpness : hint_range(0.0, 1.0) = 0.74;
uniform float glass_min_body : hint_range(0.0, 0.5) = 0.16;
uniform sampler2D glass_frost_tex : filter_linear, repeat_enable, hint_default_white;
uniform float glass_frost_scale = 0.010;
// Screen-pixel length of one grid unit along the ground axes and of one level, so the frost and
// the sheen flow at the 2D board's scale (they are sampled by world position there too).
uniform vec2 px_per_gu_x = vec2(112.0, 64.0);
uniform vec2 px_per_gu_z = vec2(-112.0, 64.0);
uniform float px_per_level_y = 156.8;

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

varying vec2 v_glass_world;
varying float v_face;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_glass_world = px_per_gu_x * w.x + px_per_gu_z * w.z - vec2(0.0, px_per_level_y * w.y);
	v_face = abs(NORMAL.y) > 0.5 ? face_top : (abs(NORMAL.x) > 0.5 ? face_se : face_sw);
}

void fragment() {
	vec3 behind = to_srgb(texture(glass_screen, SCREEN_UV).rgb);
	float frost = texture(glass_frost_tex, v_glass_world * glass_frost_scale).r;
	vec3 tinted = glass_tint * (0.82 + 0.30 * frost) * v_face;
	float k = mix(0.12, 1.0, glass_mul_strength);
	vec3 mul = clamp(mix(vec3(1.0), tinted, k), vec3(0.0), vec3(1.0));
	vec3 out_rgb = max(behind * mul, glass_tint * glass_min_body * v_face);
	float phase = (v_glass_world.x + v_glass_world.y) * glass_sheen_freq + glass_sheen_phase;
	float sheen = smoothstep(mix(0.30, 0.92, glass_sheen_sharpness), 1.0, sin(phase) * 0.5 + 0.5);
	out_rgb += mix(glass_tint, vec3(1.0), 0.5) * sheen * glass_add_strength * v_face;
	ALBEDO = to_linear(clamp(out_rgb, vec3(0.0), vec3(1.0)));
}
