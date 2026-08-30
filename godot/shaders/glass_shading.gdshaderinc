// GLASS G1 (GLASS_MASTER_PLAN §3) — shared body for the two glass blend sublayers.
//
// Glass cells are rendered on their OWN TileMapLayer(s), one MUL sublayer and one
// ADD sublayer per level, immediately above that level's opaque layer. The voxels
// still arrive through set_cell() (architecture Rule 8); only the layer's
// compositing changes. This include holds everything the two sublayer shaders
// share — every uniform, the face resolution, and the two fragment bodies — so
// glass_mul.gdshader / glass_add.gdshader are just a `render_mode` + a one-line
// call each.
//
// WHY A BLEND AND NOT ALPHA (G-D1, Director 2026-08-30): *"queremos ver a textura
// dele por cima do fundo, mas com transparência, tentando não usar opacidade
// pura, pra não ficar lavado."* Straight alpha averages the texture toward
// whatever is behind and washes it out. Glass instead MODULATES the background —
// a multiply for the tint (keeps the frosted pattern instead of averaging it
// away) plus an add for the highlights (what makes it read as glass, not tinted
// air). One blend cannot be both, hence two sublayers.
//
// The frosted atom the sublayers sample is built in memory at tileset-build time
// from ASSETS/materials/glass/facade_glass.png — see
// VoxelRenderer._build_glass_frosted_atom().

// Atom geometry — canon, matches voxel_face_shading.gdshader. Changing these
// means the tiles moved.
uniform vec2 atom_size = vec2(32.0, 36.0);
uniform float top_face_h = 16.0;

// FACE-READ-01 (Director hard rule) — the three faces of a voxel never read
// EXACTLY the same. On a flat glass PANE, though, a visible spread reads as hard
// diagonal shelves stepping across the sheet (Director, 2026-08-30: *"mitigar o
// serrilhado causado pela sobreposição das faces"*). So the glass values are
// distinct but sub-perceptual — a nod to the rule, not a relief map.
uniform float face_top : hint_range(0.0, 1.0) = 1.000;
uniform float face_se : hint_range(0.0, 1.0) = 0.988;
uniform float face_sw : hint_range(0.0, 1.0) = 0.976;

// The tint glass lays over the background. Pulled toward blue (Director,
// 2026-08-30: *"puxar a cor do vidro mais pro azul"*) from the [0.62, 0.74, 0.78]
// base_color; VoxelRenderer seeds the runtime value from `_glass_shader_params`.
uniform vec3 glass_tint : source_color = vec3(0.47, 0.63, 0.90);

// ---------------------------------------------------------------------------
// CALIBRATION UNIFORMS — the Director's to set, from the blind strip
// (glass_calibration.py). Defaults here are placeholders until that pick lands.
// ---------------------------------------------------------------------------
// How strongly the tint modulates the background. 0.0 ⇒ the pane is invisible,
// 1.0 ⇒ full tint. A small floor is added in glass_mul_color() so a pane never
// fully vanishes where nothing is behind it. Default from the Director's blind
// pick — "between panel 14 and 15", i.e. sheen mode at mul 0.45.
uniform float glass_mul_strength : hint_range(0.0, 1.0) = 0.45;
// How bright the additive highlights are. Panels 14/15 bracket add 0.25..0.45.
uniform float glass_add_strength : hint_range(0.0, 1.0) = 0.32;
// Facade luma below this contributes no sheen (ADD mode 0 only).
uniform float glass_add_threshold : hint_range(0.0, 1.0) = 0.55;
// 0.0 = highlights derived from the frosted facade's own bright mottling;
// 1.0 = a procedural diagonal reflection band. The Director picked the sheen
// (mode 1); mode 0 is kept so the strip can still compare.
uniform float glass_add_mode : hint_range(0.0, 1.0) = 1.0;
// Procedural sheen (ADD mode 1) shape, in canvas space so the band sticks to the
// world rather than the screen.
uniform float glass_sheen_freq = 0.011;
uniform float glass_sheen_phase = 0.6;
uniform float glass_sheen_sharpness : hint_range(0.0, 1.0) = 0.74;

// Below this atom alpha there is no glass here — the MUL side must return a
// no-op (white) and the ADD side nothing.
uniform float glass_alpha_floor : hint_range(0.0, 0.5) = 0.004;

// GLASS G1 — the frosted grain, sampled by WORLD position so it flows across the
// whole pane instead of repeating once per voxel (the "xadrez" the Director saw).
// VoxelRenderer._make_glass_material() binds this to facade_glass.png.
uniform sampler2D glass_frost_tex : filter_linear, repeat_enable, hint_default_white;
uniform float glass_frost_scale = 0.010;

// Canvas-space position of the vertex — MODEL_MATRIX folds in the TileMapLayer
// quadrant transform, so this is quadrant-independent (the same reason
// voxel_face_shading.gdshader takes VERTEX this way). Assigned directly in each
// wrapper's vertex() — Godot forbids assigning a varying inside a helper.
varying vec2 v_glass_world;

// 0 = top diamond, then SE / SW by the same test voxel_face_shading.gdshader uses.
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

// MUL sublayer (render_mode blend_mul → framebuffer.rgb *= COLOR.rgb): what the
// background is multiplied by. 1.0 leaves the background untouched. The atom
// texel and the atom-local pixel are sampled in fragment() and passed in — a
// `sampler2D` argument that receives the `TEXTURE` built-in trips Godot's canvas
// shader compiler.
vec4 glass_mul_color(vec4 t, vec2 local) {
	if (t.a < glass_alpha_floor) {
		return vec4(1.0, 1.0, 1.0, 1.0);
	}
	float ff = glass_face_factor(local);
	// The frosted grain, sampled by WORLD position — continuous across the pane,
	// no per-voxel repeat. Modulates the tint gently around its mean so the
	// background's texture still reads through (G-D1).
	float pattern = texture(glass_frost_tex, v_glass_world * glass_frost_scale).r;
	vec3 tinted = glass_tint * (0.82 + 0.30 * pattern) * ff;
	// A small floor (0.12) keeps a pane present even against a black background.
	float k = mix(0.12, 1.0, glass_mul_strength);
	// COVER — the atom's alpha is feathered at the silhouette (_build_glass_
	// frosted_atom), so a partial-alpha edge pixel gets a partial multiply and
	// the pane edge anti-aliases instead of stair-stepping.
	float cover = smoothstep(glass_alpha_floor, 0.85, t.a);
	vec3 m = mix(vec3(1.0), tinted, k * cover);
	return vec4(clamp(m, vec3(0.0), vec3(1.0)), 1.0);
}

// ADD sublayer (render_mode blend_add → framebuffer.rgb += COLOR.rgb * COLOR.a):
// the highlights added on top of the tinted background.
vec4 glass_add_color(vec4 t, vec2 local) {
	if (t.a < glass_alpha_floor) {
		return vec4(0.0);
	}
	float ff = glass_face_factor(local);
	float sheen;
	if (glass_add_mode < 0.5) {
		// Mode 0 — the frosted facade's own bright mottling becomes the sheen.
		float pattern = texture(glass_frost_tex, v_glass_world * glass_frost_scale).r;
		sheen = max(pattern - glass_add_threshold, 0.0)
				/ max(1.0 - glass_add_threshold, 0.001);
	} else {
		// Mode 1 — a diagonal reflection band in canvas space.
		float phase = (v_glass_world.x + v_glass_world.y) * glass_sheen_freq
				+ glass_sheen_phase;
		float band = sin(phase) * 0.5 + 0.5;
		float lo = mix(0.30, 0.92, glass_sheen_sharpness);
		sheen = smoothstep(lo, 1.0, band);
	}
	// A whiter highlight than the tint — a reflection is light, not more glass.
	vec3 hi = mix(glass_tint, vec3(1.0), 0.5);
	vec3 added = hi * sheen * glass_add_strength * ff;
	// blend_add sums COLOR.rgb * COLOR.a, so the feathered silhouette alpha
	// anti-aliases the sheen edge for free.
	return vec4(added, clamp(t.a, 0.0, 1.0));
}
