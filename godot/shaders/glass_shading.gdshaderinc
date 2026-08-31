// GLASS G1 (GLASS_MASTER_PLAN §3) — the glass appearance, applied against the
// scene BEHIND the pane.
//
// THE CONTAINER (Director, 2026-08-30: *"criar um container rasterizado, de forma
// que as opacidades das faces não conflitem"*). glass_pane.gdshader draws every
// glass voxel against a BackBufferCopy snapshot of the scene — so overlapping
// voxel faces (a pane's edge voxels carry side + top for 1-voxel thickness) all
// read the same "behind", apply the tint ONCE, and the pane reads as one surface
// (G-D2) with no double-tint.
//
// WHY A BLEND AND NOT ALPHA (G-D1): straight alpha averages the texture toward
// whatever is behind and washes it out. Glass MODULATES it — a MULTIPLY for the
// tint (keeps the frosted pattern) plus an ADD for the highlights (what makes it
// read as glass, not tinted air).

// Atom geometry — canon, matches voxel_face_shading.gdshader.
uniform vec2 atom_size = vec2(32.0, 36.0);
uniform float top_face_h = 16.0;

// FACE-READ-01 (Director hard rule) — the three faces of a voxel never read
// EXACTLY the same. Sub-perceptual on glass: a visible spread reads as diagonal
// shelves stepping across a flat pane.
uniform float face_top : hint_range(0.0, 1.0) = 1.000;
uniform float face_se : hint_range(0.0, 1.0) = 0.982;
uniform float face_sw : hint_range(0.0, 1.0) = 0.966;

// The tint glass lays over the background — blue (Director, 2026-08-30). The
// runtime value is seeded from VoxelRenderer._glass_shader_params.
uniform vec3 glass_tint : source_color = vec3(0.47, 0.63, 0.90);

// CALIBRATION — the Director's pick on the parallelogram strip was "painel 005":
// sheen mode, mul 0.60, add 0.20.
uniform float glass_mul_strength : hint_range(0.0, 1.0) = 0.60;
uniform float glass_add_strength : hint_range(0.0, 1.0) = 0.20;
uniform float glass_add_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float glass_add_mode : hint_range(0.0, 1.0) = 1.0;
uniform float glass_sheen_freq = 0.011;
uniform float glass_sheen_phase = 0.6;
uniform float glass_sheen_sharpness : hint_range(0.0, 1.0) = 0.74;

uniform float glass_alpha_floor : hint_range(0.0, 0.5) = 0.004;
// A faint self-body so glass against a dark/void background reads as tinted
// glass, not a black hole.
uniform float glass_min_body : hint_range(0.0, 0.5) = 0.16;

// The frosted grain, sampled by WORLD position so it flows across the whole pane
// instead of repeating once per voxel. Bound to facade_glass.png.
uniform sampler2D glass_frost_tex : filter_linear, repeat_enable, hint_default_white;
uniform float glass_frost_scale = 0.010;

varying vec2 v_glass_world;

// 0 = top diamond, then SE / SW.
float glass_face_factor(vec2 local) {
	vec2 half_top = vec2(atom_size.x * 0.5, top_face_h * 0.5);
	float diamond = abs(local.x - half_top.x) / half_top.x
			+ abs(local.y - half_top.y) / half_top.y;
	if (diamond <= 1.0) {
		return face_top;
	}
	if (local.x >= half_top.x) {
		return face_se;
	}
	return face_sw;
}

// Apply the glass to the colour that is BEHIND this fragment: MULTIPLY tint, then
// ADD highlight. `local` is the atom-local pixel (for the face factor).
vec3 glass_apply(vec3 behind, vec2 local) {
	float ff = glass_face_factor(local);
	float frost = texture(glass_frost_tex, v_glass_world * glass_frost_scale).r;

	// --- MULTIPLY: the tint ---
	vec3 tinted = glass_tint * (0.82 + 0.30 * frost) * ff;
	float k = mix(0.12, 1.0, glass_mul_strength);   // a floor so a pane never vanishes
	vec3 mul = mix(vec3(1.0), tinted, k);
	// max() with a faint tinted body so glass over a black void is not a black
	// hole — it still reads as glass.
	vec3 out_rgb = max(behind * clamp(mul, vec3(0.0), vec3(1.0)),
			glass_tint * glass_min_body * ff);

	// --- ADD: the highlight ---
	float sheen;
	if (glass_add_mode < 0.5) {
		sheen = max(frost - glass_add_threshold, 0.0)
				/ max(1.0 - glass_add_threshold, 0.001);
	} else {
		float phase = (v_glass_world.x + v_glass_world.y) * glass_sheen_freq
				+ glass_sheen_phase;
		float band = sin(phase) * 0.5 + 0.5;
		float lo = mix(0.30, 0.92, glass_sheen_sharpness);
		sheen = smoothstep(lo, 1.0, band);
	}
	vec3 hi = mix(glass_tint, vec3(1.0), 0.5);   // a reflection is light, not more glass
	out_rgb += hi * sheen * glass_add_strength * ff;

	return clamp(out_rgb, vec3(0.0), vec3(1.0));
}
