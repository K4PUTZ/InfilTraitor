// R3D-ACTORS step 4 — a revealed actor's LIVE MESH seen through a wall: the billboard's silhouette (actor_silhouette3d,
// R3D-7) on real geometry. One pass, chained as the `next_pass` of every board-lit surface while gameplay reveals the
// actor: it draws only where the scene's depth is NEARER than the mesh (something opaque covers it), as scrolling
// diagonal stripes, with the outline taken from the mesh's own rim (where the surface turns away from the eye) instead
// of the sprite's alpha edge, which a mesh does not have.
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 stripe_a : source_color = vec4(0.62, 0.58, 0.95, 1.0);
uniform vec4 stripe_b : source_color = vec4(0.20, 0.18, 0.40, 1.0);
uniform vec4 outline_color : source_color = vec4(0.62, 0.28, 0.95, 1.0);
uniform float stripe_px = 5.0;
uniform float scroll_px_per_s = 14.0;
uniform float phase = 0.0;
// World units. The billboard's 0.03 covers a flat quad's layer offsets; a mesh covers ITSELF (an arm in front of the
// torso), so the tolerance is a body's depth: 0.3 units = 0.48 m. Measured: at 0.03 the torso striped wherever the arm
// crossed it. A wall nearer than that to the body part it covers is not revealed there, and a wall stands at least half
// a GU from an actor at its GU's centre.
uniform float depth_bias = 0.3;
uniform float fill_alpha = 0.9;
// 1 - |N.V| above this is the outline: the last sliver of the silhouette before the surface turns away.
uniform float rim_threshold = 0.6;

void fragment() {
	float scene_depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	if (-scene_view.z > -VERTEX.z - depth_bias) {
		discard;  // nothing nearer than this actor covers the pixel
	}
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	if (rim > rim_threshold) {
		ALBEDO = outline_color.rgb;
		ALPHA = 1.0;
	} else {
		float across = (FRAGCOORD.x + FRAGCOORD.y) * 0.70710678 / stripe_px;
		float band = step(0.5, fract((across + TIME * scroll_px_per_s / stripe_px + phase) * 0.5));
		ALBEDO = mix(stripe_a.rgb, stripe_b.rgb, band);
		ALPHA = fill_alpha;
	}
}
