// LiquidFalls3D (consolidation, 2026-10-18) — the falling curtain of a liquid and its splash, in the body's own colours. A curtain's UV.y runs from the
// lip (0) to where it meets the surface below (1); streaks scroll DOWN with time and bend apart near the lip; the bottom band froths. A splash quad (vertex
// green 1) is a ring of foam on the surface under the fall. Vertex alpha = how much is falling (the flow), so a valve turned down thins it away.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 body_color : source_color = vec4(0.16, 0.46, 0.5, 0.6);
uniform vec4 light_color : source_color = vec4(0.78, 0.95, 1.0, 1.0);
uniform float fall_speed = 1.6;     // curtain heights a second
uniform float time_scale = 1.0;     // 0: frozen (ice), as the body's own look

varying float amount;
varying float curtain_gu;   // the curtain's width in GU (vertex blue), so the streaks keep their size on a wide fall
varying float splash;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	amount = COLOR.a;
	splash = COLOR.g;
	curtain_gu = max(COLOR.b, 0.25);
}

void fragment() {
	float t = TIME * time_scale;
	vec4 col;
	if (splash > 0.5) {
		// the splash: a ring of foam that breathes, broken by noise, fading at its rim
		vec2 q = UV * 2.0 - 1.0;
		float r = length(q);
		float ring = smoothstep(1.0, 0.55, r) * (0.55 + 0.45 * sin(t * 7.0 - r * 9.0));
		float speck = step(0.5, vnoise(q * 9.0 + vec2(t * 1.3, -t * 0.9)));
		col = vec4(mix(body_color.rgb, light_color.rgb, 0.75), ring * (0.35 + 0.5 * speck));
	} else {
		// the curtain: vertical streaks scrolling down, thinner and more broken as they fall; a pale lip; froth at the foot
		float y = UV.y;
		float lane = UV.x * 16.0 * curtain_gu;   // thin streaks, the same size on any width
		float streak = vnoise(vec2(lane, y * 2.5 - t * fall_speed)) * 0.7 + vnoise(vec2(lane * 2.3 + 5.0, y * 5.0 - t * fall_speed * 1.7)) * 0.3;
		float body = smoothstep(0.25, 0.75, streak);
		float broken = mix(1.0, smoothstep(0.35, 0.6, vnoise(vec2(lane * 1.7, y * 4.0 - t * fall_speed * 1.2))), y * 0.6);
		float sides = smoothstep(0.0, 0.06, UV.x) * smoothstep(1.0, 0.94, UV.x);   // only the ends of a whole curtain fade
		vec3 rgb = mix(body_color.rgb, light_color.rgb, body * 0.55 + smoothstep(0.12, 0.0, y) * 0.35);
		float a = mix(body_color.a, 0.95, body * 0.6) * broken;
		float froth = smoothstep(0.78, 1.0, y) * (0.6 + 0.4 * vnoise(vec2(lane * 3.0, t * 4.0)));
		rgb = mix(rgb, light_color.rgb, froth * 0.85);
		a = max(a, froth * 0.9);
		col = vec4(rgb, a * sides);
	}
	ALBEDO = col.rgb;
	ALPHA = clamp(col.a * amount, 0.0, 1.0);
}
