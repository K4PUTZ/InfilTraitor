shader_type spatial;
// AIM-DOME-3D — the sphere's lat/long grid (`AimBubbleOverlay`): `long_meridians` meridians and `lat_rings` rings strictly
// between the equator (the floor section's own outline) and the pole. Both faces, as the 2D wireframe drew the far side
// through the near one. NOT MOULDED (Director, 2026-08-12: "em vez de distorcer o grid da bolha"): a line simply stops
// where a wall took the sphere away; the grid that follows a wall is the patch's own (`aim_dome3d_patch`).
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
#include "res://godot/shaders/aim_dome3d.gdshaderinc"
uniform float grid_alpha = 0.45;
uniform float grid_width = 2.4;
uniform float long_meridians = 12.0;
uniform float lat_rings = 5.0;

void vertex() {
	v_p = VERTEX * vertex_scale;
}

void fragment() {
	if (!dome_reaches(v_p)) {
		discard;
	}
	vec3 n = normalize(v_p);
	float theta = atan(n.z, n.x);
	float phi = asin(clamp(n.y, -1.0, 1.0));
	float w = grid_width * px_per_world(PROJECTION_MATRIX, VIEWPORT_SIZE) / px_per_unit_2d;
	// Meridians every TAU / long_meridians: the zeros of sin(theta * long_meridians / 2).
	float cov = line_cov(sin(theta * long_meridians * 0.5), w);
	// Rings every (PI / 2) / (lat_rings + 1), the equator and the pole left out.
	float step_phi = (PI * 0.5) / (lat_rings + 1.0);
	if (phi > step_phi * 0.5 && phi < PI * 0.5 - step_phi * 0.5) {
		cov = max(cov, line_cov(sin(phi * PI / step_phi), w));
	}
	if (cov <= 0.001) {
		discard;
	}
	ALBEDO = dome_linear();
	ALPHA = grid_alpha * cov;
}
