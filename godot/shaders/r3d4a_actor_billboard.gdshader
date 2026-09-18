// R3D-4a, approach A — the flat-normal relight of flat_normal_relight.gdshader, ported to a
// SPATIAL shader so a billboard quad in the 3D scene is depth-tested by the pipeline itself.
// Same maths, same order, same uniforms: only the output stage differs. The canvas shader writes
// display values straight to COLOR; here ALBEDO is linear and the pipeline sRGB-encodes it, so
// the lit result is decoded once (unshaded → the pipeline adds no light of its own).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : filter_linear;
uniform sampler2D normal_tex : filter_nearest;
uniform vec3 light_dir = vec3(0.0, 0.0, 1.0);
uniform float light_intensity = 1.0;
uniform float ambient = 0.55;
uniform float specular_strength = 0.4;
uniform float specular_shininess = 16.0;
uniform float saturation = 1.0;
uniform float contrast = 1.0;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	vec4 albedo = texture(albedo_tex, UV);
	if (albedo.a < 0.5) {
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
	lit = clamp(lit, 0.0, 1.0);
	ALBEDO = srgb_to_linear(lit);
}
