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

uniform float settle_clock = -1.0;   // seconds since the cloth came to rest (-1 before): the fire that spreads where it parks
uniform float clock = 0.0;   // seconds since the cloth was let go: where the fire that was creeping across the roof has got to

varying vec3 v_world;
varying vec2 v_rest;
varying float v_ignite;
varying float v_skirt;
varying float v_delay;
varying float v_final;
varying vec2 v_weight;
uniform float thickness = 0.0;   // GU: how far the skirt hangs below the cloth (its visible edge)

// node (i, j) = texel (x = j, y = i): the texture is nz wide and nx tall, the sim's own row-major order (`node_count` = (nx, nz)).
vec3 node_at(int i, int j) {
	return texelFetch(nodes, clamp(ivec2(j, i), ivec2(0), ivec2(node_count.y - 1, node_count.x - 1)), 0).xyz;
}

vec4 catmull_weights(float f) {
	float f2 = f * f;
	float f3 = f2 * f;
	return vec4(-0.5 * f3 + f2 - 0.5 * f, 1.5 * f3 - 2.5 * f2 + 1.0, -1.5 * f3 + 2.0 * f2 + 0.5 * f, 0.5 * f3 - 0.5 * f2);
}

// The surface through the nodes at node coordinates `st` (Catmull-Rom).
vec3 surface_at(vec2 st_in) {
	vec2 st = clamp(st_in, vec2(0.0), vec2(node_count) - vec2(1.0));
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
	return p;
}

void vertex() {
	vec3 p = surface_at(UV);
	// A SKIRT vertex (CUSTOM0.y = 1) hangs `thickness` below the cloth along its normal: the cloth has an edge instead of being a sheet of paper.
	if (CUSTOM0.y > 0.5 && thickness > 0.0) {
		vec3 du = surface_at(UV + vec2(0.1, 0.0)) - surface_at(UV - vec2(0.1, 0.0));
		vec3 dv = surface_at(UV + vec2(0.0, 0.1)) - surface_at(UV - vec2(0.0, 0.1));
		vec3 n = normalize(cross(dv, du));
		if (n.y < 0.0) {
			n = -n;
		}
		p -= n * thickness;
	}
	VERTEX = p;
	v_world = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
	v_rest = UV2;
	v_ignite = CUSTOM0.x;   // the second this part of the cloth starts to burn (1e9: never)
	v_skirt = CUSTOM0.y;
	v_delay = CUSTOM1.x;   // the second AFTER it parks that this part catches (1e9: never)
	v_weight = CUSTOM1.zw;   // how much of this vertex burns in the explosion's fire (x) and in the fire where it parks (y)
	v_final = CUSTOM1.y;   // the tone it ends: 1 clean, 0 black (a soft material ends a soot grey, not black)
}

uniform sampler2D noise_tex : filter_linear, repeat_enable;   // 64 x 64 smooth value noise, 3 channels (SoftSheet3D builds it once): one fetch, not a dozen hashes (Mali)

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
	// FIRE on the cloth (Director, 2026-10-16): the edge of the opening and the flaps burn while the cloth comes down (`clock`, from the release); when it parks
	// the fire spreads a little from the opening (`settle_clock`), goes out, and the soot is what stays. Each is a vertex-smooth ramp over 1.4 s:
	// untouched -> glowing -> soot (`v_final`).
	// The front is ragged: the ramp is pushed by a soft noise over the cloth's rest coordinates (3 voxels a feature), then smoothed again.
	vec3 nz = texture(noise_tex, v_rest * 0.012).rgb;
	float rag = (nz.r * 0.65 + nz.g * 0.35 - 0.5) * 1.1;
	float ba = clamp((clock - v_ignite) / 1.7 + rag * 0.5, 0.0, 1.0);
	float bb = clamp((settle_clock - v_delay) / 1.7 + rag * 0.5, 0.0, 1.0) * step(0.0, settle_clock);
	// WHERE it burns is a separate, ragged mask (the weight of the vertex plus noise), so a part on the edge of the burning area still finishes and goes out.
	float ma = smoothstep(0.15, 0.9, v_weight.x + rag * 0.55);
	float mb = smoothstep(0.15, 0.9, v_weight.y + rag * 0.55);
	float b = max(ba * ma, bb * mb);
	float soot_patch = 0.8 + 0.2 * nz.b;
	float sooted = mix(1.0, v_final * soot_patch, smoothstep(0.0, 1.0, b));
	float flicker = 0.75 + 0.25 * sin(clock * 37.0 + v_rest.x * 0.9 + v_rest.y * 0.7) * sin(settle_clock * 29.0 + v_rest.y * 1.1);
	vec3 cloth = COLOR.rgb * pow(vec3(key * detail * sooted * mix(1.0, 0.55, v_skirt)), vec3(2.2));
	// the flame is a band that sweeps through each part as it chars (peak at ~1/3 burnt), gone when it is soot
	float glow = (exp(-pow((ba - 0.3) / 0.22, 2.0)) * step(0.001, ba) * (1.0 - step(0.999, ba)) * ma * 1.6 + exp(-pow((bb - 0.3) / 0.22, 2.0)) * step(0.001, bb) * (1.0 - step(0.999, bb)) * mb * 1.5);
	// `unshaded` ignores EMISSION: the fire is added to the colour itself
	ALBEDO = cloth + vec3(1.0, 0.36, 0.08) * glow * flicker * 0.3;
}
