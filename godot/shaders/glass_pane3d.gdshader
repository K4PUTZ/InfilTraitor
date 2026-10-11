shader_type spatial;
// The glass pane in ONE pass, premultiplied alpha (2026-10-09, Director): out = behind x (1 - ALPHA) + ALBEDO.
// It replaces PB-2's two passes (`glass_pane3d_mul` + `glass_pane3d_add`), which had no defined order between them: both sat at the
// same depth and the transparent sort is not stable, so per chunk the add ran first (a frosted white pane) or second (a blue one)
// depending on the boot — the pixel gate's intermittent GLASS g1. The Director chose the white; this draws it every time, with a
// small cover over what is behind (`glass_cover`) and the reflection read from a texture (`glass_sheen_tex`, see
// tools/persistent/gen_glass_sheen.py). One pass, one fetch: cheaper than the two it replaces.
render_mode unshaded, cull_back, blend_premul_alpha, depth_draw_never;
// Writes 3, the glass mark the ground overlays read (`ground_overlay3d*`), on every pixel a pane covers. No longer once per pixel
// (2026-10-09, Director: the glass is a real object of the world): a pane seen through another one is drawn too, back to front, so
// two panes stack instead of the far one being cut out where the near one already drew (G-D2's "tint once" was the 2D board's rule).
stencil_mode write, compare_always, 3;

#include "res://godot/shaders/glass_pane3d_common.gdshaderinc"

// The reflection (L) and the cover multiplier (A), grayscale + alpha, tileable; one tile = one period of the sheen.
uniform sampler2D glass_sheen_tex : filter_linear, repeat_enable, hint_default_black;
// How much the pane darkens what is behind it (0 = not at all, as the white pane did).
uniform float glass_cover : hint_range(0.0, 1.0) = 0.12;
// The pane's EDGE faces (its thickness and its top, `Board3DLive` routes them to an edge twin of the material): a darker,
// denser face so the slice reads apart from the pane's broad faces.
uniform float glass_edge = 0.0;
// Each plane of the edge its own shade, so the panes read as solid slabs (Director, 2026-10-09): the TOP lighter, the SIDES (the
// thickness facing the camera) darker, the FAR edge (back-facing, seen through the pane) between the two and lighter in cover.
uniform float glass_edge_top_light : hint_range(0.0, 1.0) = 0.9;
uniform float glass_edge_top_cover : hint_range(0.0, 1.0) = 0.35;
uniform float glass_edge_light : hint_range(0.0, 1.0) = 0.25;
uniform float glass_edge_cover : hint_range(0.0, 1.0) = 0.55;
uniform float glass_edge_back_light : hint_range(0.0, 1.0) = 0.4;
uniform float glass_edge_back_cover : hint_range(0.0, 1.0) = 0.3;
// The sRGB brightness of the background the reflection is calibrated for (the two-pass pane's `glass_add_base`).
uniform float glass_add_base : hint_range(0.0, 1.0) = 0.35;
// 2026-10-10 (Director: "aplicar o decal na parede da espessura também, sem fazer gambiarra com as bordas"): a hole's RIM walls draw
// the crack's ink themselves — the fracture sheet in world space, plus a pale base (a broken glass edge reads lighter) — so the face
// decal needs no spill past the hole (`crack_edge_spill` 0). Intact edges are untouched: only walls the mesher marks broken.
uniform sampler2D glass_rim_ink_tex : filter_linear, repeat_enable, hint_default_black;
uniform float glass_rim_ink_scale = 1.0;      // sheet tiles per GU
uniform vec3 glass_rim_ink_color = vec3(0.90, 0.94, 1.0);
uniform float glass_rim_ink_opacity : hint_range(0.0, 1.0) = 0.75;
// The pale floor under the ink. 0.35 read as a white band (Director, 2026-10-10: "a base clara da espessura está meio forte […]
// queremos que se confunda mesmo com a parte da frente"): low, so the rim is the front face's look, the ink's lines on the glass.
uniform float glass_rim_base : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	if (glass_cut_open()) {
		discard;
	}
	// The white pane's light, as the two-pass add computed it, with the sheen band read from the texture instead of a sine.
	vec2 uv = v_glass_world * glass_sheen_freq / 6.2831853 + vec2(glass_sheen_phase / 6.2831853, 0.0);
	vec4 tex = texture(glass_sheen_tex, uv);
	vec3 base = vec3(glass_add_base) * clamp(mix(vec3(1.0), glass_tint * 0.97 * v_face, mix(0.12, 1.0, glass_mul_strength)),
		vec3(0.0), vec3(1.0));
	vec3 sheen = mix(glass_tint, vec3(1.0), 0.5) * tex.r * glass_add_strength * v_face;
	vec3 add = glass_tint * glass_min_body * v_face + sheen;
	vec3 light = max(to_linear(clamp(base + add, vec3(0.0), vec3(1.0))) - to_linear(base), vec3(0.0));
	float cover = glass_cover * tex.a;
	if (glass_edge > 0.5) {
		if (!FRONT_FACING) {
			light *= glass_edge_back_light;
			cover = max(cover, glass_edge_back_cover);
		} else if (abs(v_normal.y) > 0.5) {
			light *= glass_edge_top_light;
			cover = max(cover, glass_edge_top_cover);
		} else {
			light *= glass_edge_light;
			cover = max(cover, glass_edge_cover);
		}
	}
	if (glass_edge > 0.5 && v_rim > 0.5) {
		vec2 ink_uv = vec2(v_world.x + v_world.z, v_world.y * 1.7) * glass_rim_ink_scale;
		float ink = max(texture(glass_rim_ink_tex, ink_uv).r, glass_rim_base) * glass_rim_ink_opacity;
		light = light * (1.0 - ink) + to_linear(glass_rim_ink_color) * ink;
		cover = max(cover, ink);
	}
	ALBEDO = light;
	ALPHA = cover;
}
