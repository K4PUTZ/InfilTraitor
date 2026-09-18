// RENDER3D R3D-4d — actor_billboard3d.gdshader plus flat_normal_relight.gdshader's silhouette stroke
// (COLLECTIBLE-OUTLINE-01): the "this is interactive" affordance, drawn in the frame's own transparent
// margin from a neighbourhood alpha test, NOT relit (it must not dim with the room). Coverage is
// alpha-scissored at 0.5 rather than blended, so the stroke stays in the opaque pass and keeps its
// depth; it is a 1 px line, and the aliasing is the cost of that.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://godot/shaders/actor_relight.gdshaderinc"

uniform vec4 outline_color : source_color = vec4(0.35, 0.72, 1.0, 1.0);
uniform float outline_width = 0.0;
uniform float outline_threshold = 0.4;

void fragment() {
	vec4 albedo = texture(albedo_tex, UV);
	if (albedo.a >= outline_threshold) {
		ALBEDO = relit_linear(albedo, UV);
	} else {
		float neighbour_a = 0.0;
		if (outline_width > 0.0 && outline_color.a > 0.0) {
			vec2 o = (1.0 / vec2(textureSize(albedo_tex, 0))) * outline_width;
			neighbour_a = max(neighbour_a, texture(albedo_tex, UV + vec2( o.x,  0.0)).a);
			neighbour_a = max(neighbour_a, texture(albedo_tex, UV + vec2(-o.x,  0.0)).a);
			neighbour_a = max(neighbour_a, texture(albedo_tex, UV + vec2( 0.0,  o.y)).a);
			neighbour_a = max(neighbour_a, texture(albedo_tex, UV + vec2( 0.0, -o.y)).a);
			neighbour_a = max(neighbour_a, texture(albedo_tex, UV + vec2( o.x,  o.y)).a);
			neighbour_a = max(neighbour_a, texture(albedo_tex, UV + vec2( o.x, -o.y)).a);
			neighbour_a = max(neighbour_a, texture(albedo_tex, UV + vec2(-o.x,  o.y)).a);
			neighbour_a = max(neighbour_a, texture(albedo_tex, UV + vec2(-o.x, -o.y)).a);
		}
		float coverage = smoothstep(0.02, outline_threshold, neighbour_a) * outline_color.a;
		if (coverage < 0.5) {
			discard;
		}
		ALBEDO = outline_color.rgb;
	}
}
