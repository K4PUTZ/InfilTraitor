// ROOF_MASTER_PLAN v0.30 — the ragged flaps a blast leaves on a cloth roof's hole (ClothFlaps3D). A strip of triangles rebuilt every frame on the CPU
// (a dozen flaps, a few seconds), so there is nothing to animate here: COLOR is the baked tone (linear), UV2 the rest position in voxels (the facade is
// sampled there like the roof's own top face), and `char_amount` darkens the strip toward black with a hot edge while it burns. Two-sided, unshaded.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D facade : filter_nearest_mipmap, repeat_disable;
uniform float has_facade = 0.0;
uniform vec3 key_dir = vec3(-0.45, 0.8, 0.4);

varying vec3 v_world;
varying vec2 v_rest;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_rest = UV2;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(v_world), dFdy(v_world)));
	vec3 toward_camera = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	if (dot(n, toward_camera) < 0.0) {
		n = -n;
	}
	float key = 0.72 + 0.28 * max(dot(n, normalize(key_dir)), 0.0);
	float detail = 1.0;
	if (has_facade > 0.5) {
		vec2 fr = mod(v_rest / vec2(64.0, 32.0), 2.0);
		detail = texture(facade, mix(fr, 2.0 - fr, step(1.0, fr))).r;
	}
	ALBEDO = COLOR.rgb * pow(vec3(key * detail), vec3(2.2));
	EMISSION = vec3(1.0, 0.35, 0.08) * UV.x * COLOR.a;
}
