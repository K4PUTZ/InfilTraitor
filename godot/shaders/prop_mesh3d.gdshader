// R3D-PROPS — a static prop mesh lit the BOARD's way: no Godot light, only the same cell-plane
// texture the board's own faces read (light bucket in G). Promoted from R3D-SPIKE-3D's
// spike_mesh_planes.gdshader (measured: +1.5 ms GPU for 20 props on the Moto, no shadow). A fixed
// key direction on the normal keeps the volume readable, matching the board's per-face tones.
// Uniform names match `Board3DLive._build_plane()`'s own material loop exactly, so a prop material
// registered via `Board3DLive.register_prop_light_material()` is kept lit by that same pass — no
// separate update path to fall stale.
//
// SOOT (2026-09-28, Director: props should scorch like a wall does): reads the SAME cell's R
// channel `OPAQUE_SHADER` decodes into a per-face ring — a prop has no flat wall face to pick a
// face from, so this reads the TOP ring only (`floor(code / 25.0)`, `OPAQUE_SHADER`'s face==0
// formula) of the floor cell the prop already samples for light, which is "how sooted is the
// ground this prop stands on/near" — a reasonable stand-in for an arbitrary mesh normal, not a
// per-face read. `soot_mult` values are `BoardLook.SOOT_FACE_MULT`, same as every wall material.
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
uniform vec4 soot_mult = vec4(0.38, 0.60, 0.76, 0.90);
uniform float soot_char = 0.18;
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
	float soot = 1.0;
	if (layer >= 0 && layer < level_count && pc.x >= 0 && pc.y >= 0 && pc.x < plane_size && pc.y < plane_size) {
		vec4 t = texelFetch(cell_plane, ivec3(pc, layer), 0);
		int bucket = int(floor(t.g * 255.0 + 0.5));
		lum = bucket_lum[clamp(bucket, 0, 11)];
		float code = clamp(floor(t.r * 255.0 + 0.5), 0.0, 215.0);
		float ring = floor(code / 36.0);
		soot = ring < 3.5 ? soot_mult[int(ring)] : (ring > 4.5 ? soot_char : 1.0);
	}
	float key = 0.72 + 0.28 * max(dot(v_normal, normalize(key_dir)), 0.0);
	vec3 base = albedo.rgb;
	if (has_tex > 0.5) {
		base *= texture(albedo_tex, UV).rgb;
	}
	// the ladder is an sRGB multiplier (the board multiplies in sRGB); the albedo is already linear
	ALBEDO = base * pow(vec3(lum * key * soot), vec3(2.2));
}
