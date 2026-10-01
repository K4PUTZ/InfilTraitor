// R3D-ACTORS (`ACTOR` D64) — an actor's live skinned mesh lit the BOARD's way: no Godot light, only the cell planes the board's
// faces read (`mesh_planes.gdshaderinc`, shared with the props). Promoted from R3D-SPIKE-3D's spike_mesh_planes.gdshader at
// step 1 with its behaviour unchanged: the light bucket of the floor cell under each pixel times a fixed key on the normal.
// Soot on an actor is step 4's, not read here.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float has_tex = 0.0;
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
	float key = plane_key(v_normal);
	vec3 base = albedo.rgb;
	if (has_tex > 0.5) {
		base *= texture(albedo_tex, UV).rgb;
	}
	// the ladder is an sRGB multiplier (the board multiplies in sRGB); the albedo is already linear
	ALBEDO = base * pow(vec3(lum * key), vec3(2.2));
}
