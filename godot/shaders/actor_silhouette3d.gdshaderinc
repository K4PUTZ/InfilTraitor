// RENDER3D R3D-7 — a revealed actor seen THROUGH a wall, in two passes that share this file: the FILL (alternating
// diagonal stripes that scroll) and the OUTLINE (purple, drawn after every fill so no layer's fill covers another
// layer's line). Both draw only where the scene's depth is NEARER than the actor's (something opaque covers it);
// where the actor is in the clear the normal billboard shows and this discards.
//
// THE SILHOUETTE IS THE SPRITE'S CURRENT FRAME. `albedo_tex` is mirrored every frame from the same Sprite2D the
// body billboard reads, so whatever the actor does (a walk cycle, and later the idle breathing that is planned in
// the movement milestone) reshapes the silhouette with no code of its own. `phase` and `scroll_px_per_s` are the
// two knobs a future animation drives.
//
// The including shader declares `shader_type` and `render_mode`, and defines OUTLINE_PASS for the line pass.

uniform sampler2D albedo_tex : filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 stripe_a : source_color = vec4(0.62, 0.58, 0.95, 1.0);
uniform vec4 stripe_b : source_color = vec4(0.20, 0.18, 0.40, 1.0);
uniform vec4 outline_color : source_color = vec4(0.62, 0.28, 0.95, 1.0);
uniform float stripe_px = 5.0;            // one stripe's width on screen, measured across the stripe
uniform float scroll_px_per_s = 14.0;     // signed: positive scrolls one way, negative the other
uniform float phase = 0.0;                // added to the scroll, in stripes
uniform float depth_bias = 0.03;          // world units: layer offsets and the feet lift are smaller than this
uniform float fill_alpha = 0.9;
uniform int outline_texels : hint_range(1, 3) = 2;  // outline thickness, in sprite texels

void fragment() {
	vec4 albedo = texture(albedo_tex, UV);
	if (albedo.a < 0.5) {
		discard;
	}
	float scene_depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	if (-scene_view.z > -VERTEX.z - depth_bias) {
		discard;  // nothing nearer than this actor covers the pixel
	}
#ifdef OUTLINE_PASS
	vec2 texel = 1.0 / vec2(textureSize(albedo_tex, 0));
	float edge = 0.0;
	for (int i = 1; i <= 3; i++) {
		if (i > outline_texels) {
			break;
		}
		vec2 step_uv = texel * float(i);
		edge = max(edge, step(texture(albedo_tex, UV + vec2(step_uv.x, 0.0)).a, 0.5));
		edge = max(edge, step(texture(albedo_tex, UV - vec2(step_uv.x, 0.0)).a, 0.5));
		edge = max(edge, step(texture(albedo_tex, UV + vec2(0.0, step_uv.y)).a, 0.5));
		edge = max(edge, step(texture(albedo_tex, UV - vec2(0.0, step_uv.y)).a, 0.5));
	}
	if (edge < 0.5) {
		discard;
	}
	ALBEDO = outline_color.rgb;
	ALPHA = 1.0;
#else
	float across = (FRAGCOORD.x + FRAGCOORD.y) * 0.70710678 / stripe_px;
	float band = step(0.5, fract((across + TIME * scroll_px_per_s / stripe_px + phase) * 0.5));
	ALBEDO = mix(stripe_a.rgb, stripe_b.rgb, band);
	ALPHA = fill_alpha;
#endif
}
