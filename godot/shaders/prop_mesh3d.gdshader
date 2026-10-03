// R3D-PROPS — a static prop mesh lit the BOARD's way: no Godot light, only the same cell-plane
// texture the board's own faces read (light bucket in G). The cell-plane half (uniforms, light, soot,
// key) is shared with the actors in mesh_planes.gdshaderinc (R3D-ACTORS step 1 promoted the spike's
// shader there; measured: +1.5 ms GPU for 20 props on the Moto, no shadow).
// Uniform names match `Board3DLive._build_plane()`'s own material loop exactly, so a prop material
// registered via `Board3DLive.register_prop_light_material()` is kept lit by that same pass — no
// separate update path to fall stale.
//
// SOOT (2026-09-28, Director: props should scorch like a wall does): reads the SAME cell's R
// channel `OPAQUE_SHADER` decodes into a per-face ring — a prop has no flat wall face to pick a
// face from, so this reads the TOP ring only (`floor(code / 25.0)`, `OPAQUE_SHADER`'s face==0
// formula) of the floor cell the prop already samples for light, which is "how sooted is the
// ground this prop stands on/near" — a reasonable stand-in for an arbitrary mesh normal, not a
// per-face read. `soot_mult` values are `BoardLook.SOOT_FACE_MULT`, same as every wall material.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
// The material's grayscale FACADE (`ASSETS/materials/<id>/facade_<id>.png`, B2), the same texture the walls of that material
// use, sampled in WORLD space with the board's own mapping: 16 texels per voxel (a tile spans FACADE_SPAN = 64 x 32 voxels),
// the face's dominant axis picking the plane, mirrored repeat. One fetch. `has_facade` 0 = a flat tint (PROPS_TIER4_PLAN D-P1:
// a prop's colour and detail come from OUR material registry, never from the model's own texture).
uniform sampler2D facade : filter_nearest_mipmap, repeat_disable;
uniform float has_facade = 0.0;
// 1 = multiply by the per-instance colour (the voxel fragments of a broken prop, PROPS_TIER4_PLAN P2). Off for every mesh prop.
uniform float use_color = 0.0;
// 1 = the ground's soot darkens this prop (every mesh prop). 0 = it does not: a voxel fragment already carries its own charred tone
// in its colour, and the floor's soot on top of it would darken it twice.
uniform float soot_affects = 1.0;
// A curve on the LIGHT term (the cell plane's bucket x the face tone) only, not on the colour or the detail: 1 = the board's own
// ladder (every prop), > 1 darkens the shaded faces and leaves the fully lit ones, so a small rounded object reads with more
// form. Per material (`PropMesh3D.set_contrast`).
uniform float contrast : hint_range(0.5, 3.0) = 1.0;
#include "res://godot/shaders/mesh_planes.gdshaderinc"

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	bool inside;
	ivec3 cell;
	vec4 t = plane_texel(v_world, inside, cell);
	float lum = 1.0;
	float soot = 1.0;
	if (inside) {
		lum = plane_lum(t);
		soot = mix(1.0, plane_soot(t, cell), soot_affects);
	}
	float key = plane_key(v_normal);
	vec3 base = albedo.rgb;
	if (use_color > 0.5) {
		base *= COLOR.rgb;
	}
	// the ladder is an sRGB multiplier (the board multiplies in sRGB); the albedo is already linear
	float detail = 1.0;
	if (has_facade > 0.5) {
		vec3 an = abs(v_normal);
		vec3 vox = v_world * 8.0;
		vec2 uv = an.y >= max(an.x, an.z) ? vox.xz : (an.x >= an.z ? vec2(vox.z, -vox.y) : vec2(vox.x, -vox.y));
		vec2 fr = mod(uv / vec2(64.0, 32.0), 2.0);
		detail = texture(facade, mix(fr, 2.0 - fr, step(1.0, fr))).r;
	}
	float light = contrast == 1.0 ? lum * key : pow(lum * key, contrast);
	ALBEDO = base * pow(vec3(light * soot * detail), vec3(2.2));
}
