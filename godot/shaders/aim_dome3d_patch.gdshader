shader_type spatial;
// AIM-DOME-3D — what a wall wears where the sphere covers it (`AimBubbleOverlay`, §6.2, Director 2026-08-12: "um grid
// interno em volta das paredes, nas áreas em que estiverem dentro da bolha"). One quad per wall, built in GU on the wall's
// plane: UV = (u along the wall, v up) from the foot of the perpendicular, UV2.x = the radius of the disc the plane cuts
// out of the sphere, CUSTOM0 = the wall's own rectangle (u min, u max, v min, v max). A fragment shows only inside that disc
// and only when no nearer wall stops the ray from the centre (the far faces of a solid block stay bare).
// The fill carries the volume's alpha under its own where the patch is the volume's ENTRY (its outward side faces the
// camera: the wall cut away the near side of the shell, whose front faces would otherwise have painted the volume).
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
#include "res://godot/shaders/aim_dome3d.gdshaderinc"
uniform float fill_alpha = 0.13;
uniform float wall_fill_alpha = 0.24;
uniform float wall_line_alpha = 0.85;
uniform float wall_grid_alpha = 0.60;
uniform float wall_grid_step = 0.25;
uniform float line_width = 3.5;
uniform float grid_width = 2.4;

varying vec4 v_rect;
varying vec2 v_cut;

void vertex() {
	v_p = VERTEX * vertex_scale;
	v_rect = CUSTOM0;
	v_cut = UV2;
}

void fragment() {
	vec2 uv = UV;
	float cut = v_cut.x;
	float r = length(uv);
	if (r > cut || !dome_reaches(v_p)) {
		discard;
	}
	float px = px_per_world(PROJECTION_MATRIX, VIEWPORT_SIZE) / px_per_unit_2d;
	// Outward from the dome's centre, across this wall: along the axis the wall separates, on the side of the plane.
	vec3 outward = v_cut.y > 0.5 ? vec3(sign(v_p.x), 0.0, 0.0) : vec3(0.0, 0.0, sign(v_p.z));
	vec3 to_cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
	float a = dot(outward, to_cam) > 0.0 ? over_alpha(fill_alpha, wall_fill_alpha) : wall_fill_alpha;
	float grid = max(line_cov(sin(uv.x * PI / wall_grid_step), grid_width * px),
		line_cov(sin(uv.y * PI / wall_grid_step), grid_width * px));
	a = over_alpha(a, wall_grid_alpha * grid);
	// The patch's own border: the sphere's cut arc and the wall rectangle's edges, whichever is nearest.
	float edge = min(edge_cov(cut - r, line_width * px), 1.0);
	edge = max(edge, edge_cov(uv.x - v_rect.x, line_width * px));
	edge = max(edge, edge_cov(v_rect.y - uv.x, line_width * px));
	edge = max(edge, edge_cov(uv.y - v_rect.z, line_width * px));
	edge = max(edge, edge_cov(v_rect.w - uv.y, line_width * px));
	a = over_alpha(a, wall_line_alpha * edge);
	ALBEDO = dome_linear();
	ALPHA = a;
}
