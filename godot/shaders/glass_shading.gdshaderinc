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

// FACE-READ-01 (Director hard rule) — never let the three faces of a voxel read
// exactly the same. Subtle by design, as in voxel_face_shading.gdshader: what
// matters is that the three values are DISTINCT, not that they are far apart.
// These are applied to the glass CONTRIBUTION (the tint on the MUL side, the
// added light on the ADD side), never to absolute background brightness.
uniform float face_top : hint_range(0.0, 1.0) = 1.00;
uniform float face_se : hint_range(0.0, 1.0) = 0.94;
uniform float face_sw : hint_range(0.0, 1.0) = 0.88;

// The tint glass lays over the background — seeded from glass.json base_color
// [0.62, 0.74, 0.78] by VoxelRenderer.
uniform vec3 glass_tint : source_color = vec3(0.62, 0.74, 0.78);

// ---------------------------------------------------------------------------
// CALIBRATION UNIFORMS — the Director's to set, from the blind strip
// (glass_calibration.py). Defaults here are placeholders until that pick lands.
// ---------------------------------------------------------------------------
// How strongly the tint modulates the background. 0.0 ⇒ the pane is invisible,
// 1.0 ⇒ full tint. A small floor is added in glass_mul_color() so a pane never
// fully vanishes where nothing is behind it.
uniform float glass_mul_strength : hint_range(0.0, 1.0) = 0.55;
// How bright the additive highlights are.
uniform float glass_add_strength : hint_range(0.0, 1.0) = 0.25;
// Facade luma below this contributes no sheen (ADD mode 0 only).
uniform float glass_add_threshold : hint_range(0.0, 1.0) = 0.55;
// 0.0 = highlights derived from the frosted facade's own bright mottling;
// 1.0 = a procedural diagonal reflection band. Both built so the strip can
// compare them side by side (Director: "A gente consegue testar as opções lado
// a lado?").
uniform float glass_add_mode : hint_range(0.0, 1.0) = 0.0;
// Procedural sheen (ADD mode 1) shape, in canvas space so the band sticks to the
// world rather than the screen.
uniform float glass_sheen_freq = 0.011;
uniform float glass_sheen_phase = 0.6;
uniform float glass_sheen_sharpness : hint_range(0.0, 1.0) = 0.74;

// Below this atom alpha there is no glass here — the MUL side must return a
// no-op (white) and the ADD side nothing.
uniform float glass_alpha_floor : hint_range(0.0, 0.5) = 0.004;

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
	float pattern = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	// The frosted grain modulates the tint gently AROUND its mean, so the
	// background's own texture reads through instead of flattening to one wash
	// (G-D1) — subtle, because every voxel samples the same atom and a strong
	// term reads as hard vertical banding across a pane.
	vec3 tinted = glass_tint * (0.82 + 0.30 * pattern) * ff;
	// A small floor (0.12) keeps a pane present even against a black background.
	float k = mix(0.12, 1.0, glass_mul_strength);
	vec3 m = mix(vec3(1.0), tinted, k);
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
		float pattern = dot(t.rgb, vec3(0.299, 0.587, 0.114));
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
	vec3 added = glass_tint * sheen * glass_add_strength * ff;
	return vec4(added, t.a);
}
