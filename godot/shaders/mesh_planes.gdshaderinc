// R3D-ACTORS step 1 — a mesh lit the BOARD's way, the half every board-lit mesh shares (actors: actor_mesh3d.gdshader,
// props: prop_mesh3d.gdshader). Promoted from R3D-SPIKE-3D's spike_mesh_planes.gdshader (measured on the Moto: 9 walking
// rigs +1.0 ms, 20 static props +1.5 ms, no Godot light anywhere). Each pixel reads the cell plane of the FLOOR cell under it
// (light bucket in G, soot code in R), so a mesh is exactly as bright as the floor it stands on and dims in the same steps.
//
// The uniform names are the ones `Board3DLive._build_plane()` / `register_prop_light_material()` set: a material registered
// there is kept lit by the board's own pass, with no update path of its own to fall stale. The ladder is the board's
// `_light_ladder` (R3D-9's neutral owner), handed over by that same pass.

uniform sampler2DArray cell_plane : filter_nearest, repeat_disable;
uniform int level_base = 0;
uniform int level_count = 1;
uniform int mesh_ground_level = 80;
uniform ivec2 plane_origin = ivec2(64, 64);
uniform ivec2 plane_size = ivec2(512, 512);
uniform float bucket_lum[12];
uniform vec4 soot_mult = vec4(0.38, 0.60, 0.76, 0.90);
uniform vec2 soot_char_range = vec2(0.10, 0.30);
uniform vec3 key_dir = vec3(-0.45, 0.8, 0.4);

varying vec3 v_world;
varying vec3 v_normal;

// A stable hash of a cell in [0, 1): the charred tone varies from cell to cell (the same formula the board's shader uses).
float char_hash(ivec3 c) {
	uint x = uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(c.z) * 83492791u;
	x = (x ^ (x >> 13u)) * 1274126177u;
	x = x ^ (x >> 16u);
	return float(x & 65535u) / 65536.0;
}

// The plane texel of the floor cell under `world`; `inside` is false off the plane (the mesh then reads full light, no soot).
vec4 plane_texel(vec3 world, out bool inside, out ivec3 cell) {
	ivec2 pc = ivec2(floor(vec2(world.x, world.z) * 8.0)) + plane_origin;
	int layer = (mesh_ground_level - 1) - level_base;
	cell = ivec3(pc.x, layer, pc.y);
	inside = layer >= 0 && layer < level_count && pc.x >= 0 && pc.y >= 0 && pc.x < plane_size.x && pc.y < plane_size.y;
	return inside ? texelFetch(cell_plane, ivec3(pc, layer), 0) : vec4(0.0);
}

// The light ladder's multiplier for a texel (sRGB, the way the board multiplies).
float plane_lum(vec4 t) {
	int bucket = int(floor(t.g * 255.0 + 0.5));
	return bucket_lum[clamp(bucket, 0, 11)];
}

// The soot multiplier for a texel: the TOP ring of the cell's base-6 soot code (`OPAQUE_SHADER`'s face==0 formula), or the
// charred tone. A mesh has no flat wall face to pick a ring from, so the ground's ring stands in for it.
float plane_soot(vec4 t, ivec3 cell) {
	float code = clamp(floor(t.r * 255.0 + 0.5), 0.0, 215.0);
	float ring = floor(code / 36.0);
	if (ring < 3.5) {
		return soot_mult[int(ring)];
	} else if (ring > 4.5) {
		float ch = char_hash(cell);
		return mix(soot_char_range.x, soot_char_range.y, ch * ch);
	}
	return 1.0;
}

// A fixed key direction on the normal keeps the volume readable (the board's own face tones do the same job per face).
float plane_key(vec3 normal) {
	return 0.72 + 0.28 * max(dot(normal, normalize(key_dir)), 0.0);
}
