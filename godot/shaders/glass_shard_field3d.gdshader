// RENDER3D R3D-4e-4 — glass_shard_field.gdshader as a SPATIAL shader, for a ShardField3D quad.
// The atlas is a strip of shard silhouettes; the instance's custom-data x picks a cell. Same maths as
// the canvas shader: a slice of U, tinted by the instance colour. Display values in, linear out, MIX
// blend, depth-tested and never depth-writing (a shard must not hide a shard).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D atlas : filter_nearest;
uniform float atlas_cells = 5.0;

varying flat float inst_cell;
varying vec4 inst_color;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	inst_cell = INSTANCE_CUSTOM.x;
	inst_color = COLOR;
}

void fragment() {
	vec2 uv = vec2((UV.x + inst_cell) / max(atlas_cells, 1.0), UV.y);
	vec4 texel = texture(atlas, uv) * inst_color;
	ALBEDO = srgb_to_linear(texel.rgb);
	ALPHA = texel.a;
}
