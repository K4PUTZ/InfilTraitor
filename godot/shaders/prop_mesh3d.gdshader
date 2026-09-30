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
// The material's grayscale FACADE (`ASSETS/materials/<id>/facade_<id>.png`, B2), the same texture the walls of that material
// use, sampled in WORLD space with the board's own mapping: 16 texels per voxel (a tile spans FACADE_SPAN = 64 x 32 voxels),
// the face's dominant axis picking the plane, mirrored repeat. One fetch. `has_facade` 0 = a flat tint (PROPS_TIER4_PLAN D-P1:
// a prop's colour and detail come from OUR material registry, never from the model's own texture).
uniform sampler2D facade : filter_nearest_mipmap, repeat_disable;
uniform float has_facade = 0.0;
// 1 = multiply by the per-instance colour (the voxel fragments of a broken prop, PROPS_TIER4_PLAN P2). Off for every mesh prop.
uniform float use_color = 0.0;
// 1 = the ground's soot darkens this prop (every mesh prop). 0 = it does not: a voxel fragment already carries its own charred tone
// in its colour, and the floor's soot on top of it would darken it twice.
uniform float soot_affects = 1.0;
uniform sampler2DArray cell_plane : filter_nearest, repeat_disable;
uniform int level_base = 0;
uniform int level_count = 1;
uniform int mesh_ground_level = 80;
uniform ivec2 plane_origin = ivec2(64, 64);
uniform int plane_size = 512;
uniform float bucket_lum[12];
uniform vec4 soot_mult = vec4(0.38, 0.60, 0.76, 0.90);
uniform vec2 soot_char_range = vec2(0.10, 0.30);
uniform vec3 key_dir = vec3(-0.45, 0.8, 0.4);

// A stable hash of a cell in [0, 1): the charred tone varies from cell to cell (the same formula the board's shader uses).
float char_hash(ivec3 c) {
	uint x = uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(c.z) * 83492791u;
	x = (x ^ (x >> 13u)) * 1274126177u;
	x = x ^ (x >> 16u);
	return float(x & 65535u) / 65536.0;
}

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
		if (ring < 3.5) {
			soot = soot_mult[int(ring)];
		} else if (ring > 4.5) {
			float ch = char_hash(ivec3(pc.x, layer, pc.y));
			soot = mix(soot_char_range.x, soot_char_range.y, ch * ch);
		}
		soot = mix(1.0, soot, soot_affects);
	}
	float key = 0.72 + 0.28 * max(dot(v_normal, normalize(key_dir)), 0.0);
	vec3 base = albedo.rgb;
	if (use_color > 0.5) {
		base *= COLOR.rgb;
	}
	// the ladder is an sRGB multiplier (the board multiplies in sRGB); the albedo is already linear
	float detail = 1.0;
	if (has_facade > 0.5) {
		vec3 an = abs(v_normal);
		vec3 vox = v_world * 8.0;
		vec2 uv = an.y >= max(an.x, an.z) ? vox.xz : (an.x >= an.z ? vec2(vox.z, -vox.y) : vec2(vox.x, -vox.y));
		vec2 fr = mod(uv / vec2(64.0, 32.0), 2.0);
		detail = texture(facade, mix(fr, 2.0 - fr, step(1.0, fr))).r;
	}
	ALBEDO = base * pow(vec3(lum * key * soot * detail), vec3(2.2));
}
