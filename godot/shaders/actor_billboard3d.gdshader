// RENDER3D R3D-4b — a baked actor frame as a depth-tested billboard in the 3D board. The relight
// lives in actor_relight.gdshaderinc. No outline branch: it is off for every actor, and a sprite that
// wants one uses actor_billboard3d_outline.gdshader instead of paying for the branch here.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://godot/shaders/actor_relight.gdshaderinc"

void fragment() {
	vec4 albedo = texture(albedo_tex, UV);
	if (albedo.a < 0.5) {
		discard;
	}
	ALBEDO = relit_linear(albedo, UV);
}
