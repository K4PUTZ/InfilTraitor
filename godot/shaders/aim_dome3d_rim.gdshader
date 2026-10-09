shader_type spatial;
// AIM-DOME-3D — the sphere's silhouette, the crispest line of the dome (`AimBubbleOverlay`): front faces where the surface
// turns away from the eye. The field is N·V, zero exactly on the silhouette; the band is drawn on the dome's own side of it.
// Along the bottom the silhouette is the floor section's front half (`aim_dome3d_floor`).
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled, blend_mix;
#include "res://godot/shaders/aim_dome3d.gdshaderinc"
uniform float rim_alpha = 0.90;
uniform float rim_width = 3.5;

void vertex() {
	v_p = VERTEX * vertex_scale;
}

void fragment() {
	if (!dome_reaches(v_p)) {
		discard;
	}
	float w = rim_width * px_per_world(PROJECTION_MATRIX, VIEWPORT_SIZE) / px_per_unit_2d;
	float cov = edge_cov(max(dot(normalize(NORMAL), VIEW), 0.0), w);
	if (cov <= 0.001) {
		discard;
	}
	ALBEDO = dome_linear();
	ALPHA = rim_alpha * cov;
}
