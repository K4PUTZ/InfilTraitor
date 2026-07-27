// ACTOR_MASTER_PLAN D17 — relights a flat, unlit sprite using a baked normal
// map, so a pre-rendered 2D frame (actor_frame_bake_spike.gd's output) reads
// with real directional shading + specular "shine" without any voxel
// geometry or live 3D scene at runtime. The normal map was baked in the same
// fixed camera space the game's isometric view always uses (elevation 30°,
// azimuth 45°) — light_dir must be supplied in that same space (see
// FloatingCollectible.gd for the world→camera-space conversion).
//
// Deliberately continuous (not bucket-quantized) — VoxelLightField's 12
// discrete buckets are a wall-baking technique (D13's own scope); a live
// per-pixel shader has no bake-time cost to economize on, so real N·L reads
// better here and is what makes the normal map worth having at all.
shader_type canvas_item;

uniform sampler2D normal_tex : source_color, filter_nearest;
uniform vec3 light_dir = vec3(0.0, 0.0, 1.0); // camera-space, normalized
uniform vec3 light_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float light_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float ambient : hint_range(0.0, 1.0) = 0.35;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.4;
uniform float specular_shininess : hint_range(1.0, 128.0) = 16.0;

void fragment() {
	vec4 albedo = texture(TEXTURE, UV);
	vec4 n_sample = texture(normal_tex, UV);
	vec3 n = normalize(n_sample.rgb * 2.0 - 1.0);
	vec3 l = normalize(light_dir);

	float ndotl = clamp(dot(n, l), 0.0, 1.0);
	// Fixed view direction: the bake camera never moves relative to the
	// object within one frame, so straight-on (+Z in this encoding) is a
	// reasonable stand-in for a view vector without carrying a second
	// baked map just for that.
	vec3 view_dir = vec3(0.0, 0.0, 1.0);
	vec3 half_vec = normalize(l + view_dir);
	float spec = pow(clamp(dot(n, half_vec), 0.0, 1.0), specular_shininess) * specular_strength;

	vec3 lit = albedo.rgb * (ambient + ndotl * light_intensity * light_color) + spec * light_color;
	COLOR = vec4(lit, albedo.a);
}
