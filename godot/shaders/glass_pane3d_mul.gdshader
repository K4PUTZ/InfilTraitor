shader_type spatial;
// PERFORMANCE_BUDGET PB-2 (adopted by the Director 2026-10-09) — the glass pane, pass 1 of 2, WITHOUT a screen read.
// The R3D-6 pane (`glass_pane3d.gdshader`, deleted; last in `c9c0a119`) read the scene behind through `hint_screen_texture`; on
// the Galaxy A16 a material that does that costs ~35 MiB of engine buffers and ~250-295 MiB of driver memory (GL mtrack ~500 ->
// ~208 MiB in the ablation), just by existing. Its maths was `max(behind × mul, body) + sheen` in sRGB; the blend unit does most
// of it without reading anything:
//   pass 1 (this): the framebuffer is MULTIPLIED by `mul` (blend_mul). In linear space, behind_lin × to_linear(mul) is the
//                  original's product exactly under a pure power law, close under the sRGB curve.
//   pass 2 (`glass_pane3d_add`, next_pass): ADDS the body floor and the sheen.
// What it cannot reproduce: `max(…, body)` becomes `+ body` (a ~0.7 % linear lift over a bright background, the same floor over a
// dark one), the sheen is added in linear instead of sRGB (softer over bright backgrounds), and the add is calibrated for a typical background
// (`glass_add_base`), so it lifts a very dark one (a black-clad actor behind a pane) more than the original does.
render_mode unshaded, cull_back, blend_mul, depth_draw_never;
// ONE multiply and ONE add per pixel (G-D2: the tint applies once), held by the stencil in two stages: this pass passes only on
// an unmarked pixel (ref 1 > stored 0) and writes 1; the add pass passes only below 3 (ref 3 > stored 0 or 1) and writes 3.
// A second glass face over the same pixel fails both. 3 is the glass mark the ground overlays read (`ground_overlay3d*`), the
// same value the screen-reading original wrote.
stencil_mode read, write, compare_greater, 1;

#include "res://godot/shaders/glass_pane3d_common.gdshaderinc"

void fragment() {
	if (glass_cut_open()) {
		discard;
	}
	ALBEDO = to_linear(glass_mul_srgb());
}
