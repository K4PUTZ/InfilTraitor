shader_type canvas_item;

// RENDER_ORDER_MASTER_PLAN §10b.3, OPTION A — a glass voxel drawn as an ORDINARY
// tile inside its level's opaque layer, `INFILTRAITOR_GLASS_TILE=1`. Default OFF:
// glass_pane.gdshader is the shipping path and is not touched by this file.
//
// The layer's own draw order IS iso depth order (Q8), so the tile takes its turn
// among the walls for free. What it gives up is the SNAPSHOT — Option A exists to
// drop the BackBufferCopy container — and with it, G-D1.
//
// WHAT G-D1 IS, AND WHY A TILE CANNOT DO IT. glass_pane composites against the
// scene behind it:
//
//     out = behind * mul + add          (mul a COLOURED multiply, per channel)
//
// A tile without a snapshot has only blend_mix:
//
//     out = src * a + behind * (1 - a)  (ONE scalar on behind)
//
// so a per-channel multiply is not expressible. This is the closest fit: `(1 - a)`
// is the SMALLEST channel of `mul` (the most the glass darkens anything), and the
// rest of the tint goes into `src`, sized so the result is EXACT when `behind` is
// the reference grey `glass_mix_ref`:
//
//     a       = 1 - min(mul)
//     src * a = ref * (mul - min(mul)) + add
//
// Over a background brighter than ref the tint reads weaker than G-D1; over a
// darker one it reads as a coloured haze. That is the "wash" the Director is to
// judge, and `glass_mix_ref` is the one dial it has.
//
// ⚠️ `glass_terms()` MIRRORS `glass_apply()` in glass_shading.gdshaderinc, and that
// is a second copy of calibrated maths. Deliberate while this is a gate: splitting
// the include to share it would edit the SHIPPING shader for an experiment, and the
// default board is supposed to be byte-identical. If A is ratified, glass_apply()
// is the one to split and this copy goes.
//
// ⚠️ Not reproduced: G-D1's `glass_min_body` floor. Under a snapshot it only lifts a
// pane over black; under blend_mix it would be ADDED over every background, which is
// a wash of its own. Over black this shader already returns the tinted `src * a`.
render_mode blend_mix;

#include "res://godot/shaders/glass_shading.gdshaderinc"

uniform float glass_mix_ref : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	v_glass_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// glass_apply()'s two terms, returned apart: xyz of `mul`, and `add`.
void glass_terms(vec2 local, float dim, vec3 tint, out vec3 mul, out vec3 add) {
	float ff = glass_face_factor(local) * dim;
	float frost = texture(glass_frost_tex, v_glass_world * glass_frost_scale).r;
	vec3 tinted = tint * (0.82 + 0.30 * frost) * ff;
	float k = mix(0.12, 1.0, glass_mul_strength);
	mul = clamp(mix(vec3(1.0), tinted, k), vec3(0.0), vec3(1.0));

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
	vec3 hi = mix(tint, vec3(1.0), 0.5);
	add = hi * sheen * glass_add_strength * ff;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float cover = smoothstep(glass_alpha_floor, 0.85, t.a);
	if (cover <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 local = mod(UV / TEXTURE_PIXEL_SIZE, atom_size);
		vec3 mul;
		vec3 add;
		// RED is the per-plane dim, BLUE the member's tint index — the same atom
		// data glass_pane.gdshader decodes.
		glass_terms(local, t.r, glass_class_tint(t.b), mul, add);
		float m0 = min(mul.r, min(mul.g, mul.b));
		vec3 premul = glass_mix_ref * (mul - vec3(m0)) + add;
		// `src = premul / a` must stay <= 1. Where the highlight is bright enough
		// to break that, the alpha is raised instead of the highlight clipped —
		// the background then darkens a little past min(mul), which is the
		// smaller error of the two.
		float a = max(1.0 - m0, max(premul.r, max(premul.g, premul.b)));
		a = max(a, 0.001);
		COLOR = vec4(clamp(premul / a, vec3(0.0), vec3(1.0)), a * cover);
	}
}
