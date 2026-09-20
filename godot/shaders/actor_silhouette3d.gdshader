// RENDER3D R3D-7 — a revealed actor seen THROUGH a wall: the actor's own silhouette, filled with alternating
// diagonal stripes that scroll, and outlined. Drawn only where the scene's depth is NEARER than the actor's
// (something opaque covers it); where the actor is in the clear the normal billboard shows and this discards.
//
// THE SILHOUETTE IS THE SPRITE'S CURRENT FRAME. `albedo_tex` is mirrored every frame from the same Sprite2D the
// body billboard reads, so whatever the actor does (a walk cycle, and later the idle breathing that is planned in
// the movement milestone) reshapes the silhouette with no code of its own. `phase` and `scroll_px_per_s` are the
// two knobs a future animation drives.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D albedo_tex : filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 stripe_a : source_color = vec4(0.62, 0.58, 0.95, 1.0);
uniform vec4 stripe_b : source_color = vec4(0.20, 0.18, 0.40, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float stripe_px = 5.0;            // one stripe's width on screen, measured across the stripe
uniform float scroll_px_per_s = 14.0;     // signed: positive scrolls one way, negative the other
uniform float phase = 0.0;                // added to the scroll, in stripes
uniform float depth_bias = 0.03;          // world units: layer offsets and the feet lift are smaller than this
uniform float fill_alpha = 0.9;

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
	float across = (FRAGCOORD.x + FRAGCOORD.y) * 0.70710678 / stripe_px;
	float band = step(0.5, fract((across + TIME * scroll_px_per_s / stripe_px + phase) * 0.5));
	vec3 colour = mix(stripe_a.rgb, stripe_b.rgb, band);
	vec2 texel = 1.0 / vec2(textureSize(albedo_tex, 0));
	float edge = 0.0;
	edge = max(edge, step(texture(albedo_tex, UV + vec2(texel.x, 0.0)).a, 0.5));
	edge = max(edge, step(texture(albedo_tex, UV - vec2(texel.x, 0.0)).a, 0.5));
	edge = max(edge, step(texture(albedo_tex, UV + vec2(0.0, texel.y)).a, 0.5));
	edge = max(edge, step(texture(albedo_tex, UV - vec2(0.0, texel.y)).a, 0.5));
	ALBEDO = mix(colour, outline_color.rgb, edge);
	ALPHA = mix(fill_alpha, 1.0, edge);
}
