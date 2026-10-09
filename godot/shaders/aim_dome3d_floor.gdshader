shader_type spatial;
// AIM-DOME-3D — the ground section (`AimBubbleOverlay`): the disc the floor cuts out of the sphere, sectioned by the same
// walls, denser than the volume, with its outline, over the volume the shell's front faces already laid (as the 2D dome
// drew the disc over its volume polygon).
// The outline's FRONT half is the dome's silhouette along the bottom and takes the rim's weight; the back half lies inside
// the dome and keeps the section's own.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
#include "res://godot/shaders/aim_dome3d.gdshaderinc"
uniform float floor_fill_alpha = 0.20;
uniform float floor_line_alpha = 0.55;
uniform float rim_alpha = 0.90;
uniform float line_width = 3.5;

void vertex() {
	v_p = VERTEX * vertex_scale;
}

void fragment() {
	vec3 q = vec3(v_p.x, 0.0, v_p.z);
	float d = length(q);
	float limit = d > 0.0001 ? min(radius, wall_hit(q / d)) : radius;
	if (d > limit) {
		discard;
	}
	float w = line_width * px_per_world(PROJECTION_MATRIX, VIEWPORT_SIZE) / px_per_unit_2d;
	// Toward the camera along the ground: the third column of the inverse view, flattened.
	vec3 to_cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
	bool front = dot(q, vec3(to_cam.x, 0.0, to_cam.z)) > 0.0;
	float a = floor_fill_alpha;
	a = over_alpha(a, (front ? rim_alpha : floor_line_alpha) * edge_cov(limit - d, w));
	ALBEDO = dome_linear();
	ALPHA = a;
}
