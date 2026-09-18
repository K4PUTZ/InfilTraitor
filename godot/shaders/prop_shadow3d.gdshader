// RENDER3D R3D-4d — object_ground_shadow.gdshader as a SPATIAL shader, for a quad lying on the 3D
// board's ground. Same maths: the sprite's own silhouette alpha, hard-edged on the floor, a 5x5 box
// blur in the air, black at `strength`. `TEXTURE_PIXEL_SIZE` does not exist here, so the texel size
// is read from the texture.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D tex : filter_linear;
uniform float blur_px = 0.0;
uniform float strength = 0.55;

void fragment() {
	float alpha;
	if (blur_px <= 0.01) {
		alpha = texture(tex, UV).a;
	} else {
		vec2 step_uv = (1.0 / vec2(textureSize(tex, 0))) * blur_px * 0.5;
		float total = 0.0;
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				vec2 uv = clamp(UV + vec2(float(x), float(y)) * step_uv, vec2(0.0), vec2(1.0));
				total += texture(tex, uv).a;
			}
		}
		alpha = total / 25.0;
	}
	ALBEDO = vec3(0.0);
	ALPHA = alpha * strength;
}
