// D70 PROTOTYPE — the costume's CLOTH (suit, coat, shirt, tie): `actor_mesh3d.gdshader` plus a soft SHEEN at grazing angles, so wool reads as wool and
// not as latex (Director, 2026-10-21: "precisa de uma textura/reflexo de tecido, pra não ficar com cara de látex"). The fabric's weave and pinstripe come
// from the albedo texture; this adds only the edge light. It reads neither the screen nor the depth. Dev bench only until it is merged into the actor shader.
// R3D-ACTORS (`ACTOR` D64) — an actor's live skinned mesh lit the BOARD's way: no Godot light, only the cell planes the board's
// faces read (`mesh_planes.gdshaderinc`, shared with the props). Promoted from R3D-SPIKE-3D's spike_mesh_planes.gdshader at
// step 1: the light bucket of the floor cell under each pixel times a fixed key on the normal. Step 4 adds the soot: the
// same reading a mesh prop takes (the top ring of the floor cell's soot code, or the charred tone), so a figure standing
// in a scorched room darkens with it.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float has_tex = 0.0;
// M6 F5 — what a liquid left ON the agent (`ActorMesh3D.set_status_tint`): rgb the colour, a how much (0 = none); `status_pulse` 1 makes it breathe
// (a fire on the agent), 0 holds it (a stain, a glow).
uniform vec4 status_tint = vec4(0.0);
uniform float status_pulse = 0.0;
uniform float sheen = 0.09;
uniform float sheen_power = 3.2;
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
	// the ladder is an sRGB multiplier (the board multiplies in sRGB); the albedo is already linear
	ALBEDO = base * pow(vec3(lum * key * soot), vec3(2.2)) * (inside ? plane_warm(t, cell) : vec3(1.0));
	float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), sheen_power);
	ALBEDO += vec3(0.90, 0.92, 1.0) * sheen * edge * 0.35 * pow(vec3(lum * key * soot), vec3(2.2));
	float breathe = mix(1.0, 0.55 + 0.45 * sin(TIME * 7.0 + v_world.y * 9.0), status_pulse);
	// the tint keeps the figure's own shading: the status colour at the pixel's brightness, never a flat fill
	vec3 tinted = status_tint.rgb * clamp(dot(ALBEDO, vec3(0.3333)) * 2.6, 0.18, 1.0);
	ALBEDO = mix(ALBEDO, tinted, clamp(status_tint.a * breathe, 0.0, 1.0));
}
