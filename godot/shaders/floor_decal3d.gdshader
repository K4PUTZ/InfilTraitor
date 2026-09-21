// RENDER3D — a textured decal lying on the 3D board's ground plane (the glass-shard piles). The vertex
// colour carries the pile's opacity as the 2D sprite's `modulate` did (display values); the texture is
// the 2D decal, sampled linear as the Sprite2D drew it. Depth-tested and never depth-writing: a wall in
// front of a pile hides it, an actor standing on it covers it.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D decal : filter_linear, source_color;

void fragment() {
	vec4 texel = texture(decal, UV);
	ALBEDO = texel.rgb * COLOR.rgb;
	ALPHA = texel.a * COLOR.a;
}
