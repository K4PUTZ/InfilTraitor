// PERFORMANCE_BUDGET PB-2 (2026-10-08): what the two passes of the screen-free glass share with each other (and, by copy, with
// `glass_pane3d.gdshader`, the screen-reading original): uniforms, the frost/sheen world mapping, the CRACK-03/04 opening cut,
// and the sRGB tint maths. See `glass_pane3d_mul.gdshader` for why there are two passes.
uniform vec3 glass_tint = vec3(0.47, 0.63, 0.90);
uniform float face_top : hint_range(0.0, 1.0) = 1.000;
uniform float face_se : hint_range(0.0, 1.0) = 0.982;
uniform float face_sw : hint_range(0.0, 1.0) = 0.966;
uniform float glass_mul_strength : hint_range(0.0, 1.0) = 0.68;
uniform float glass_add_strength : hint_range(0.0, 1.0) = 0.20;
uniform float glass_sheen_freq = 0.011;
uniform float glass_sheen_phase = 0.6;
uniform float glass_sheen_sharpness : hint_range(0.0, 1.0) = 0.74;
uniform float glass_min_body : hint_range(0.0, 0.5) = 0.16;
uniform sampler2D glass_frost_tex : filter_linear, repeat_enable, hint_default_white;
uniform float glass_frost_scale = 0.010;
// Screen-pixel length of one grid unit along the ground axes and of one level, so the frost and
// the sheen flow at the 2D board's scale (they are sampled by world position there too).
uniform vec2 px_per_gu_x = vec2(112.0, 64.0);
uniform vec2 px_per_gu_z = vec2(-112.0, 64.0);
uniform float px_per_level_y = 156.8;

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

varying vec2 v_glass_world;
varying float v_face;
varying vec3 v_world;
varying vec3 v_normal;

// CRACK-03/04 on the 3D pane: each applied opening is a polygon mask (one layer of open_masks, in a
// square frame of +-open_half voxels around its struck cell). A fragment inside one is discarded, so
// the cells the hole touches are torn along the polygon instead of ending in a rectangle.
uniform int open_count = 0;
uniform vec4 open_a[16]; // (anchor.x, anchor.y, anchor level, 1 = runs along X)
uniform sampler2DArray open_masks : filter_linear, repeat_disable;
uniform float open_half = 4.0;
uniform int mesh_ground_level = 80;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_glass_world = px_per_gu_x * w.x + px_per_gu_z * w.z - vec2(0.0, px_per_level_y * w.y);
	v_world = w;
	v_normal = NORMAL;
	v_face = (abs(NORMAL.y) > 0.5 ? face_top : (abs(NORMAL.x) > 0.5 ? face_se : face_sw)) * COLOR.r;
}


// The opening cut (discard inside an applied opening) — the original's, verbatim.
bool glass_cut_open() {
	if (open_count > 0) {
		vec3 p = v_world * 8.0;
		vec3 pn = p - v_normal * 0.5;
		float level_c = p.y + float(mesh_ground_level);
		for (int i = 0; i < open_count; i++) {
			vec4 a = open_a[i];
			bool run_x = a.w > 0.5;
			float cross_v = floor(run_x ? pn.z : pn.x);
			if (cross_v != (run_x ? a.y : a.x)) {
				continue;
			}
			float dr = (run_x ? p.x - (a.x + 0.5) : p.z - (a.y + 0.5));
			float dl = level_c - (a.z + 0.5);
			vec2 uv = vec2((dr + open_half) / (2.0 * open_half), (open_half - dl) / (2.0 * open_half));
			if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0
					&& texture(open_masks, vec3(uv, float(i))).r > 0.5) {
				return true;
			}
		}
	}
	return false;
}

// The multiplier the original applies to the scene behind, in sRGB.
vec3 glass_mul_srgb() {
	float frost = texture(glass_frost_tex, v_glass_world * glass_frost_scale).r;
	vec3 tinted = glass_tint * (0.82 + 0.30 * frost) * v_face;
	float k = mix(0.12, 1.0, glass_mul_strength);
	return clamp(mix(vec3(1.0), tinted, k), vec3(0.0), vec3(1.0));
}

// The sheen the original adds, in sRGB.
vec3 glass_sheen_srgb() {
	float phase = (v_glass_world.x + v_glass_world.y) * glass_sheen_freq + glass_sheen_phase;
	float sheen = smoothstep(mix(0.30, 0.92, glass_sheen_sharpness), 1.0, sin(phase) * 0.5 + 0.5);
	return mix(glass_tint, vec3(1.0), 0.5) * sheen * glass_add_strength * v_face;
}
