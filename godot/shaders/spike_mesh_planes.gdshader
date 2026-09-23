// R3D-SPIKE-3D — a real mesh (actor or prop) lit the BOARD's way: no Godot light, only the same cell
// planes the board's faces read (light bucket in G, soot code in R). Each pixel takes the bucket of the
// FLOOR cell under it, so a figure is exactly as bright as the floor it stands on, and dims in the same
// steps. A fixed key direction on the normal keeps the volume readable (the board's own face tones do
// the same job per face). SPIKE ONLY: nothing in the game uses it unless `MESH_PLANES=1`.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float has_tex = 0.0;
uniform sampler2DArray cell_plane : filter_nearest, repeat_disable;
uniform int level_base = 0;
uniform int level_count = 1;
uniform int mesh_ground_level = 80;
uniform ivec2 plane_origin = ivec2(64, 64);
uniform int plane_size = 512;
uniform float bucket_lum[12];
uniform vec3 key_dir = vec3(-0.45, 0.8, 0.4);

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ivec2 pc = ivec2(floor(vec2(v_world.x, v_world.z) * 8.0)) + plane_origin;
	int layer = (mesh_ground_level - 1) - level_base;
	float lum = 1.0;
	if (layer >= 0 && layer < level_count && pc.x >= 0 && pc.y >= 0 && pc.x < plane_size && pc.y < plane_size) {
		int bucket = int(floor(texelFetch(cell_plane, ivec3(pc, layer), 0).g * 255.0 + 0.5));
		lum = bucket_lum[clamp(bucket, 0, 11)];
	}
	float key = 0.72 + 0.28 * max(dot(v_normal, normalize(key_dir)), 0.0);
	vec3 base = albedo.rgb;
	if (has_tex > 0.5) {
		base *= texture(albedo_tex, UV).rgb;
	}
	// the ladder is an sRGB multiplier (the board multiplies in sRGB); the albedo is already linear
	ALBEDO = base * pow(vec3(lum * key), vec3(2.2));
}
