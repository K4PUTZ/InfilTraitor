// ROOF_MASTER_PLAN v0.28 — the skin of a soft roof (SoftSheet3D). The simulation (SoftSheetSim) has a COARSE grid of nodes (about one per
// 0.33 GU); their world positions are the texels of `nodes`, and this vertex shader puts every vertex of a fine mesh (one per two voxels)
// on the bicubic (Catmull-Rom) surface through them, so the cloth reads smooth at the voxel resolution for 16 texel fetches a vertex and
// no per-frame CPU skin. The mesh's UV is the vertex's place in NODE units, UV2 its rest position in voxels (the facade is sampled there,
// the way the board maps a roof's top face, so at the instant of release the cloth is the roof it replaces).
//
// LIT BAKED: COLOR is the material colour times the tone the roof's own voxel had (the board's light and soot at the release, in linear),
// so nothing darkens or brightens as the cloth falls over a darker floor cell (the rubble's rule, `BAKED_LIGHT`). Two-sided: the normal
// (from the surface's own screen derivatives) always faces the camera, and the key tone is the props' (`plane_key`).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D nodes : filter_nearest, repeat_disable;
uniform ivec2 node_count = ivec2(2, 2);
uniform sampler2D facade : filter_nearest_mipmap, repeat_disable;
uniform float has_facade = 0.0;
uniform vec3 key_dir = vec3(-0.45, 0.8, 0.4);

varying vec3 v_world;
varying vec2 v_rest;

// node (i, j) = texel (x = j, y = i): the texture is nz wide and nx tall, the sim's own row-major order (`node_count` = (nx, nz)).
vec3 node_at(int i, int j) {
	return texelFetch(nodes, clamp(ivec2(j, i), ivec2(0), ivec2(node_count.y - 1, node_count.x - 1)), 0).xyz;
}

vec4 catmull_weights(float f) {
	float f2 = f * f;
	float f3 = f2 * f;
	return vec4(-0.5 * f3 + f2 - 0.5 * f, 1.5 * f3 - 2.5 * f2 + 1.0, -1.5 * f3 + 2.0 * f2 + 0.5 * f, 0.5 * f3 - 0.5 * f2);
}

void vertex() {
	vec2 st = clamp(UV, vec2(0.0), vec2(node_count) - vec2(1.0));
	ivec2 i0 = min(ivec2(floor(st)), node_count - ivec2(2));
	vec2 f = st - vec2(i0);
	vec4 wi = catmull_weights(f.x);
	vec4 wj = catmull_weights(f.y);
	vec3 p = vec3(0.0);
	for (int a = 0; a < 4; a++) {
		vec3 row = vec3(0.0);
		for (int b = 0; b < 4; b++) {
			row += wj[b] * node_at(i0.x + a - 1, i0.y + b - 1);
		}
		p += wi[a] * row;
	}
	VERTEX = p;
	v_world = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
	v_rest = UV2;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(v_world), dFdy(v_world)));
	vec3 toward_camera = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	if (dot(n, toward_camera) < 0.0) {
		n = -n;
	}
	float key = 0.72 + 0.28 * max(dot(n, normalize(key_dir)), 0.0);
	float detail = 1.0;
	if (has_facade > 0.5 && COLOR.a > 0.5) {
		vec2 fr = mod(v_rest / vec2(64.0, 32.0), 2.0);
		detail = texture(facade, mix(fr, 2.0 - fr, step(1.0, fr))).r;
	}
	ALBEDO = COLOR.rgb * pow(vec3(key * detail), vec3(2.2));
}
