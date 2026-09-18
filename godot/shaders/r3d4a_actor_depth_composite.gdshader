// R3D-4a, approach B — the 2D sprite, relit exactly as flat_normal_relight.gdshader does it
// (the shipped shader, outline branch omitted: it is off for the agent), then cut against the
// board's depth pass. `sprite_depth` is ONE camera-space depth for the whole sprite — the plan's
// "world-space depth per sprite" — compared against the board's depth under each pixel.
shader_type canvas_item;

uniform sampler2D normal_tex : source_color, filter_nearest;
uniform sampler2D depth_tex : filter_nearest;
uniform vec3 light_dir = vec3(0.0, 0.0, 1.0);
uniform float light_intensity = 1.0;
uniform float ambient = 0.55;
uniform float specular_strength = 0.4;
uniform float specular_shininess = 16.0;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float sprite_depth = 0.0;
uniform float depth_range = 100.0;
uniform float depth_slack = 0.004;
uniform bool flip_depth_y = false;

void fragment() {
	vec4 albedo = texture(TEXTURE, UV);
	if (albedo.a < 0.5) {
		discard;
	}
	vec2 suv = SCREEN_UV;
	if (flip_depth_y) {
		suv.y = 1.0 - suv.y;
	}
	vec4 dc = texture(depth_tex, suv);
	float board_d = (round(dc.r * 255.0) * 256.0 + round(dc.g * 255.0)) / 65535.0 * depth_range;
	if (sprite_depth > board_d + depth_slack) {
		discard;
	}
	vec3 n = normalize(texture(normal_tex, UV).rgb * 2.0 - 1.0);
	vec3 l = normalize(light_dir);
	float ndotl = clamp(dot(n, l), 0.0, 1.0);
	vec3 half_vec = normalize(l + vec3(0.0, 0.0, 1.0));
	float spec = pow(clamp(dot(n, half_vec), 0.0, 1.0), specular_shininess) * specular_strength;
	vec3 lit = albedo.rgb * (ambient + ndotl * light_intensity) + vec3(spec);
	float luma = dot(lit, vec3(0.299, 0.587, 0.114));
	lit = mix(vec3(luma), lit, saturation);
	lit = (lit - 0.5) * contrast + 0.5;
	COLOR = vec4(clamp(lit, 0.0, 1.0), 1.0);
}
