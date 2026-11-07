// ACTOR D94: the COAT's variant of actor_mesh3d.gdshader — the same shader, drawn two-sided. R3D-ACTORS (`ACTOR` D64) — an actor's live skinned mesh lit the BOARD's way: no Godot light, only the cell planes the board's
// faces read (`mesh_planes.gdshaderinc`, shared with the props). Promoted from R3D-SPIKE-3D's spike_mesh_planes.gdshader at
// step 1: the light bucket of the floor cell under each pixel times a fixed key on the normal. Step 4 adds the soot: the
// same reading a mesh prop takes (the top ring of the floor cell's soot code, or the charred tone), so a figure standing
// in a scorched room darkens with it.
shader_type spatial;
render_mode unshaded, cull_disabled;   // the coat is a one-sided shell with the legs pushing it about: a face turned away must not let the trousers behind it show (Director, 2026-11-01: the coat's inside and the calf)

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float has_tex = 0.0;
// the leather's matte sheen (CHARACTER §7a; TripoFigure.SHEEN sets it per piece): 0 = none
uniform float sheen = 0.0;
uniform float sheen_power = 6.0;
// ACTOR D95 — the coat's EMBLEM: the logo (RGBA, resolved by `CoatEmblem` through the TextureResolver's tiers) laid over the colour inside the coat's baked zone (UV2 = the zone, COLOR.b = its mask)
uniform sampler2D emblem_tex : source_color, filter_linear_mipmap;
uniform float has_emblem = 0.0;
// M6 F5 — what a liquid left ON the agent (`ActorMesh3D.set_status_tint`): rgb the colour, a how much (0 = none); `status_pulse` 1 makes it breathe
// (a fire on the agent), 0 holds it (a stain, a glow).
uniform vec4 status_tint = vec4(0.0);
uniform float status_pulse = 0.0;
#include "res://godot/shaders/mesh_planes.gdshaderinc"
#include "res://godot/shaders/coat_push.gdshaderinc"

void vertex() {
	VERTEX = coat_push(VERTEX, NORMAL, COLOR);   // ACTOR D94: the legs push the coat's skirt (CoatPush3D drives it); every other piece returns at once
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	bool inside;
	ivec3 cell;
	vec4 t = plane_texel(v_world, inside, cell);
	float lum = inside ? plane_lum(t) : 1.0;
	float soot = inside ? plane_soot(t, cell) : 1.0;
	float key = plane_key(FRONT_FACING ? v_normal : -v_normal);
	vec3 base = albedo.rgb;
	if (has_tex > 0.5) {
		base *= texture(albedo_tex, UV).rgb;
	}
	if (has_emblem > 0.5 && FRONT_FACING && UV2.x > 0.0 && UV2.x < 1.0 && UV2.y > 0.0 && UV2.y < 1.0) {   // the outer wall seen from outside only: the lining and the front panels carry no mask / are not front-facing
		vec4 em = texture(emblem_tex, UV2);
		base = mix(base, em.rgb, em.a * COLOR.b);
	}
	// the ladder is an sRGB multiplier (the board multiplies in sRGB); the albedo is already linear
	ALBEDO = base * pow(vec3(lum * key * soot), vec3(2.2)) * (inside ? plane_warm(t, cell) : vec3(1.0));
	if (sheen > 0.0) {
		ALBEDO += vec3(sheen * plane_sheen((FRONT_FACING ? v_normal : -v_normal), normalize(INV_VIEW_MATRIX[2].xyz), sheen_power) * pow(lum * soot, 2.2));
	}
	float breathe = mix(1.0, 0.55 + 0.45 * sin(TIME * 7.0 + v_world.y * 9.0), status_pulse);
	// the tint keeps the figure's own shading: the status colour at the pixel's brightness, never a flat fill
	vec3 tinted = status_tint.rgb * clamp(dot(ALBEDO, vec3(0.3333)) * 2.6, 0.18, 1.0);
	ALBEDO = mix(ALBEDO, tinted, clamp(status_tint.a * breathe, 0.0, 1.0));
}
