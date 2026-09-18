// RENDER3D R3D-4b/4d — the flat-normal relight (ACTOR_MASTER_PLAN D17) as a SPATIAL include, shared by
// `actor_billboard3d.gdshader` and its outline variant so the maths exists once. Same maths, same
// order as flat_normal_relight.gdshader (R3D-4a measured 104 px of ~35 000 differing, all 1 px rows
// at the feet). The canvas shader writes display values to COLOR; here ALBEDO is linear and the
// pipeline sRGB-encodes it, so the lit result is decoded once. Use with `unshaded`.

uniform sampler2D albedo_tex : filter_linear;
uniform sampler2D normal_tex : filter_nearest;
uniform vec3 light_dir = vec3(0.0, 0.0, 1.0);
uniform vec3 light_color = vec3(1.0);
uniform float light_intensity = 1.0;
uniform float ambient = 0.55;
uniform float specular_strength = 0.4;
uniform float specular_shininess = 16.0;
uniform float saturation = 1.0;
uniform float contrast = 1.0;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

vec3 relit_linear(vec4 albedo, vec2 uv) {
	vec3 n = normalize(texture(normal_tex, uv).rgb * 2.0 - 1.0);
	vec3 l = normalize(light_dir);
	float ndotl = clamp(dot(n, l), 0.0, 1.0);
	vec3 half_vec = normalize(l + vec3(0.0, 0.0, 1.0));
	float spec = pow(clamp(dot(n, half_vec), 0.0, 1.0), specular_shininess) * specular_strength;
	vec3 lit = albedo.rgb * (ambient + ndotl * light_intensity * light_color) + spec * light_color;
	float luma = dot(lit, vec3(0.299, 0.587, 0.114));
	lit = mix(vec3(luma), lit, saturation);
	lit = (lit - 0.5) * contrast + 0.5;
	return srgb_to_linear(clamp(lit, 0.0, 1.0));
}
