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
//
// THIS IS THE BASE MEMBER'S TINT, index 0 of GlassMaterials.PANE_TINT, and it
// stays a lone uniform rather than folding into the array below for one reason:
// the calibration capture action drives it by name
// (`set_glass_shader_param("glass_tint", …)`), and that is how "painel 005" was
// picked in the first place.
uniform vec3 glass_tint : source_color = vec3(0.47, 0.63, 0.90);

// G-D16 / V-B — THE REST OF THE FAMILY, in GlassMaterials.FAMILY order minus the
// base: glass_armored, glass_screen_{green,red,amber}.
//
// One shader, one BackBufferCopy container and one TileMapLayer per level still
// serve every glass material. The alternative — a layer set per material — would
// multiply draw submission by the roster size, and submission is what a
// detonation actually pays for (VFX-COST-01). What multiplies instead is the
// ATOM table: 16 atoms per member, composed once at load, and an atom carries
// its member's index in the BLUE channel it was already wasting (the builder
// writes RGB identical; the shader has only ever read RED, and GREEN is spoken
// for by G-D19's damage term).
//
// Fixed count 4, deliberately. GlassMaterials.TINT_SLOTS mirrors it and
// VoxelRenderer LOUD-FAILS if the roster outgrows it — a sixth member silently
// wearing the fifth's colour is worse than a boot error.
//
// ⚠️ FOUR SCALARS AND NOT `uniform vec3 glass_tint_alt[4]`, which is what this
// was first written as. The array compiles and RENDERS CORRECTLY, and prints
// this on every boot:
//
//   ERROR: Condition "!actions.custom_samplers.has(function->arguments[j].tex_builtin)"
//   is true. Continuing.
//
// Measured, not guessed: 0 occurrences with the pre-V-B shader, 1 per boot with
// the array, 0 again with these scalars — the whole difference being the array.
// "Continuing." makes it the worst kind of error, the sort that is easy to learn
// to scroll past. Four named uniforms and a four-way select cost nothing at
// runtime (the branch is on a value constant across each atom) and cost one boot
// error less.
uniform vec3 glass_tint_alt_0;
uniform vec3 glass_tint_alt_1;
uniform vec3 glass_tint_alt_2;
uniform vec3 glass_tint_alt_3;

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
// ADD highlight. `local` is the atom-local pixel (for the face factor); `dim` is
// the per-plane brightness from the atom (1.0 = the pane face, < 1 = a top or
// side cap, so those planes read darker — Director, 2026-08-30).
// The member's tint, from the index the atom carries in its BLUE channel. The
// atom is 8-bit RGBA and every texel of one atom holds the same value, so the
// round-trip is exact and interpolation inside an atom is a no-op.
vec3 glass_class_tint(float encoded) {
	int i = int(round(encoded * 255.0));
	if (i <= 0) {
		return glass_tint;
	}
	int k = clamp(i - 1, 0, 3);
	if (k == 0) { return glass_tint_alt_0; }
	if (k == 1) { return glass_tint_alt_1; }
	if (k == 2) { return glass_tint_alt_2; }
	return glass_tint_alt_3;
}

vec3 glass_apply(vec3 behind, vec2 local, float dim, vec3 tint) {
	float ff = glass_face_factor(local) * dim;
	float frost = texture(glass_frost_tex, v_glass_world * glass_frost_scale).r;

	// --- MULTIPLY: the tint ---
	vec3 tinted = tint * (0.82 + 0.30 * frost) * ff;
	float k = mix(0.12, 1.0, glass_mul_strength);   // a floor so a pane never vanishes
	vec3 mul = mix(vec3(1.0), tinted, k);
	// max() with a faint tinted body so glass over a black void is not a black
	// hole — it still reads as glass.
	vec3 out_rgb = max(behind * clamp(mul, vec3(0.0), vec3(1.0)),
			tint * glass_min_body * ff);

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
	vec3 hi = mix(tint, vec3(1.0), 0.5);   // a reflection is light, not more glass
	out_rgb += hi * sheen * glass_add_strength * ff;

	return clamp(out_rgb, vec3(0.0), vec3(1.0));
}
