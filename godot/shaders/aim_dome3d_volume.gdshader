shader_type spatial;
// AIM-DOME-3D — the dome's translucent VOLUME (`AimBubbleOverlay`). Drawn on the shell's FRONT faces only: a ray from the
// camera enters the sectioned dome through exactly one surface — the near side of the shell, or, where a wall in front of
// the centre took that side away, the wall patch facing the camera (which carries the volume's share of its own alpha,
// `aim_dome3d_patch`) — so the fill is laid once per pixel, as the 2D dome's single polygon was, without a translucent seam
// doubling where faces overlap. The camera is always above the floor, so the floor disc is never an entry.
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled, blend_mix;
#include "res://godot/shaders/aim_dome3d.gdshaderinc"
uniform float fill_alpha = 0.13;

void vertex() {
	v_p = VERTEX * vertex_scale;
}

void fragment() {
	if (!dome_reaches(v_p)) {
		discard;
	}
	ALBEDO = dome_linear();
	ALPHA = fill_alpha;
}
