// D72 PROTOTYPE — the cloaked agent: the board-lit actor of `actor_mesh3d.gdshader` turned into a faint, desaturated, edge-lit ghost
// (Director, 2026-10-20: "tirar a opacidade do agente, dessaturar a silhueta, botar alguma fuleirinha, glow, tipo um fantasminha").
// It reads NEITHER the screen NOR the depth buffer (a material that does cost ~250-295 MiB of driver memory on the Galaxy,
// PERFORMANCE_BUDGET), so the "see-through" is plain alpha over what is already drawn. Dev bench only until measured on the Moto.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_always;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float has_tex = 0.0;
uniform vec4 status_tint = vec4(0.0);
uniform float status_pulse = 0.0;
uniform float base_alpha = 0.30;
uniform float rim_alpha = 0.55;
uniform float keep_colour = 0.18;
uniform vec3 glow : source_color = vec3(0.55, 0.85, 1.0);
#include "res://godot/shaders/mesh_planes.gdshaderinc"

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	bool inside;
	ivec3 cell;
	vec4 t = plane_texel(v_world, inside, cell);
	float lum = inside ? plane_lum(t) : 1.0;
	float soot = inside ? plane_soot(t, cell) : 1.0;
	float key = plane_key(v_normal);
	vec3 base = albedo.rgb;
	if (has_tex > 0.5) {
		base *= texture(albedo_tex, UV).rgb;
	}
	vec3 lit = base * pow(vec3(lum * key * soot), vec3(2.2)) * (inside ? plane_warm(t, cell) : vec3(1.0));
	float grey = dot(lit, vec3(0.3333));
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);
	// a slow vertical shimmer that crawls up the body, so the ghost breathes instead of sitting there
	float shimmer = 0.5 + 0.5 * sin(TIME * 2.6 + v_world.y * 22.0 + v_world.x * 5.0);
	ALBEDO = mix(vec3(grey), lit, keep_colour) * 0.75 + glow * (rim * 0.85 + shimmer * 0.06);
	ALPHA = clamp(base_alpha + rim * rim_alpha + shimmer * 0.06, 0.0, 0.95);
}
