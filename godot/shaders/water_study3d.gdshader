// M6 WATER STUDY (2026-10-17) — one flat sheet over the channel, four LOOKS to compare, nothing simulated yet: the flow is a scrolling
// field, so every look can be judged for what it reads like before a mechanism is picked. `mode`: 0 flat tint (the control), 1 STIPPLE
// (autonomous dots that drift with the flow, hard-edged like the occlusion cutaway's dither), 2 SURFACE (colour bands, waves, edge foam,
// ripple rings, bubbles), 3 both. Unshaded and depth-tested, never depth-writing, like `ground_overlay3d`.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform int mode = 3;
uniform vec2 rect_min = vec2(0.0);       // the channel in the node's local xz (GU)
uniform vec2 rect_max = vec2(1.0);
uniform vec2 flow_dir = vec2(0.0, 1.0);  // unit vector, from pipe A to pipe B
uniform float flow_speed = 0.3;          // GU / s
uniform vec4 deep_color : source_color = vec4(0.04, 0.2, 0.26, 0.5);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.46, 0.5, 0.38);
uniform vec4 light_color : source_color = vec4(0.78, 0.95, 1.0, 1.0);
uniform float bubble_amount = 1.0;      // 0 = no bubbles
uniform float caustics = 0.0;           // light networks on the bed, as in clear shallow water
uniform float depth_shade = 0.0;        // the channel's own depth: the curbs' shade on the water, deeper blue toward the middle
uniform vec2 shade_dir = vec2(1.0, 0.0); // which way the curbs' shadow falls (local xz, away from the light)
uniform float detail_strength = 0.55;   // how strong rings / bubbles / dots / foam read (the Director's softened pass: 0.55)
uniform float scum = 0.0;               // floating clumps (algae, rubbish) that drift with the flow and bob
uniform vec4 scum_color : source_color = vec4(0.27, 0.45, 0.1, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.0);   // alpha 0 = the stipple dots take `light_color`; else they are specks of this colour
uniform float rain = 0.0;               // 0 off .. 1 heavy: concentric rings from random drops, independent of the flow
uniform float dot_cells = 11.0;          // stipple cells per GU

varying vec2 lp;

void vertex() {
	lp = VERTEX.xz;
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
vec2 h22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Stipple: a grid of cells, each with its own dot that wanders inside the cell on its own phase; a lane (a column of cells) has its own
// speed, so the field flows without moving as one rigid sheet. Hard edge: a dot is on or off, like a dithered pixel.
float stipple(vec2 p, float t) {
	vec2 along = flow_dir;
	vec2 across = vec2(-flow_dir.y, flow_dir.x);
	float a = dot(p, along) * dot_cells;
	float c = dot(p, across) * dot_cells;
	float lane = floor(c);
	float lane_speed = mix(0.55, 1.45, h21(vec2(lane, 3.0)));
	float q = a - t * flow_speed * dot_cells * lane_speed;
	vec2 id = vec2(floor(q), lane);
	vec2 f = vec2(fract(q), fract(c));
	vec2 r = h22(id);
	vec2 centre = vec2(0.5) + 0.3 * vec2(sin(t * 1.3 + r.x * 6.2832), cos(t * 1.1 + r.y * 6.2832));
	float alive = step(0.42, r.x);
	float radius = mix(0.14, 0.3, h21(id + 7.0)) * (0.65 + 0.35 * sin(t * 2.2 + r.y * 9.0));
	return alive * step(length(f - centre), radius);
}

// Rings: one cell of 0.9 GU holds a ring that grows from its centre and fades, on its own phase; the cells drift with the flow.
float rings(vec2 p, float t) {
	vec2 q = p / 0.9 - flow_dir * t * flow_speed * 0.4;
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	vec2 r = h22(id + 11.0);
	f += (r - 0.5) * 0.3;
	float phase = fract(t * 0.32 + r.x);
	float radius = phase * 0.46;
	float ring = smoothstep(0.035, 0.0, abs(length(f) - radius));
	return ring * (1.0 - phase) * step(0.35, r.y);
}

// Bubbles: small hard discs with a bright rim, rising along the flow a little faster than the water.
float bubbles(vec2 p, float t) {
	vec2 q = p / 0.16 - flow_dir * t * flow_speed * 1.3 / 0.16 * 0.5;
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	vec2 r = h22(id + 29.0);
	f += (r - 0.5) * 0.35;
	float radius = mix(0.12, 0.26, r.x) * (0.8 + 0.2 * sin(t * 3.0 + r.y * 6.0));
	float d = length(f);
	float disc = step(d, radius);
	float rim = step(radius * 0.62, d) * disc;
	return step(0.86, r.y) * (rim * 1.0 + disc * 0.3);
}

// Caustics: the bright network the sun draws on a shallow bed; two warped layers, thin lines where a sine sum crosses zero.
float caustic_net(vec2 p, float t) {
	float c = 0.0;
	for (int i = 0; i < 2; i++) {
		float k = float(i);
		vec2 q = p * (9.0 + 5.0 * k);
		q += vec2(sin(q.y * 0.9 + t * (0.7 + 0.2 * k) + k * 1.9), cos(q.x * 0.8 - t * (0.6 + 0.15 * k) + k * 2.7)) * 0.9;
		float s = abs(sin(q.x) + sin(q.y * 1.1 + 1.3));
		c = max(c, smoothstep(0.16, 0.0, s));
	}
	return c;
}

// Rain: drops land at random places on a 0.4 GU grid; each draws two concentric rings that grow and fade in about a second. `rain` sets
// how many cells have a drop at once. Not carried by the flow: rain falls where it falls.
float rain_rings(vec2 p, float t) {
	vec2 q = p / 0.4;
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	vec2 r = h22(id + 53.0);
	float cycle = 1.1 + r.x * 0.9;
	float k = t / cycle + r.y * 7.0;
	float n = floor(k);
	float phase = fract(k);
	vec2 r2 = h22(id + n * 1.7 + 91.0);
	if (r2.x > rain) {
		return 0.0;
	}
	f -= (r2 - 0.5) * 0.4;
	float d = length(f);
	float radius = phase * 0.5;
	float ring = smoothstep(0.05, 0.0, abs(d - radius)) + 0.7 * smoothstep(0.04, 0.0, abs(d - radius * 0.62));
	return ring * (1.0 - phase) * (1.0 - phase);
}

void fragment() {
	vec2 p = lp;
	float edge = min(min(p.x - rect_min.x, rect_max.x - p.x), min(p.y - rect_min.y, rect_max.y - p.y));
	float t = TIME * 0.6;   // the whole set slower
	float soft = detail_strength;      // how strong the details are (the Director's pass: softer, the bed shows through)
	float along = dot(p, flow_dir);
	float across_d = min(p.x - rect_min.x, rect_max.x - p.x);   // distance to the nearest curb
	vec4 col = deep_color;

	if (mode >= 2) {
		float warp = vnoise(vec2(p.x * 3.0, along * 1.3 - t * flow_speed * 1.4));
		float bands = 0.5 + 0.5 * sin((along - t * flow_speed) * 10.0 + warp * 5.5 + sin(p.x * 8.0 + t) * 0.7);
		float shade = clamp(bands * 0.55 + warp * 0.35 + (1.0 - clamp(across_d * 2.2, 0.0, 1.0)) * 0.25, 0.0, 1.0);
		col = mix(deep_color, shallow_color, shade);
		float foam = smoothstep(0.16, 0.0, across_d) * (0.35 + 0.65 * vnoise(p * 15.0 - flow_dir * t * 2.0));
		col.rgb = mix(col.rgb, light_color.rgb, foam * 0.75 * soft);
		col.a = max(col.a, foam * 0.9 * soft);
		float glints = smoothstep(0.82, 1.0, bands) * smoothstep(0.55, 0.85, warp);
		col.rgb = mix(col.rgb, light_color.rgb, glints * 0.45 * soft);
		float ring = rings(p, t);
		float bub = bubbles(p, t) * bubble_amount;
		col.rgb = mix(col.rgb, light_color.rgb, clamp(ring * 0.8 + bub, 0.0, 1.0) * soft);
		col.a = max(col.a, clamp(ring * 0.85 + bub, 0.0, 1.0) * soft);
	}
	if (scum > 0.0) {
		// floating clumps: thresholded noise carried by the flow (slower than the water), a dark rim and a lit top so they read as lumps
		vec2 sp = p - flow_dir * t * flow_speed * 0.6;
		float n = vnoise(sp * 6.0) * 0.65 + vnoise(sp * 17.0 + 3.0) * 0.35;
		float bob = 0.015 * sin(t * 1.4 + n * 20.0);
		float body = smoothstep(0.62 + bob, 0.66 + bob, n) * scum;
		float rim = smoothstep(0.58, 0.62, n) * (1.0 - smoothstep(0.62, 0.68, n)) * scum;
		float top = smoothstep(0.7, 0.82, n);
		vec3 lump = mix(scum_color.rgb * 0.7, scum_color.rgb * 1.5, top);
		col.rgb = mix(col.rgb, scum_color.rgb * 0.3, rim * 0.7);
		col.rgb = mix(col.rgb, lump, body);
		col.a = max(col.a, max(body * 0.95, rim * 0.6));
	}
	if (depth_shade > 0.0) {
		// depth: shallow turquoise at the curbs, deep blue in the middle; and each curb throws a soft shade onto the water on the side
		// away from the light (the shade of a wall standing in the channel), wavering a little with the surface
		float mid = clamp(across_d / (0.5 * (rect_max.x - rect_min.x)), 0.0, 1.0);
		col.rgb = mix(col.rgb, deep_color.rgb * 0.65, mid * 0.5 * depth_shade);
		float d_shade = shade_dir.x > 0.0 ? (p.x - rect_min.x) : (rect_max.x - p.x);
		float wob = 0.03 * sin(along * 6.0 - t * 1.2) + 0.02 * vnoise(vec2(along * 3.0, t * 0.4));
		float shade = smoothstep(0.42 + wob, 0.0, d_shade) * 0.5 * depth_shade;
		col.rgb *= 1.0 - shade * 0.7;
		col.a = max(col.a, shade * 0.55);
	}
	if (caustics > 0.0) {
		float cn = caustic_net(p * vec2(1.0) + flow_dir * t * 0.05, t);
		float lit = 1.0 - (depth_shade > 0.0 ? smoothstep(0.42, 0.0, shade_dir.x > 0.0 ? (p.x - rect_min.x) : (rect_max.x - p.x)) * 0.8 : 0.0);
		col.rgb = mix(col.rgb, light_color.rgb, cn * 0.3 * caustics * lit);
		col.a = max(col.a, cn * 0.2 * caustics * lit);
	}
	if (mode == 1 || mode == 3) {
		float d = stipple(p, t);
		if (mode == 1) {
			// the stipple IS the water: a faint wash in the channel's footprint, the dots on top
			col = vec4(deep_color.rgb, 0.28);
		}
		col.rgb = mix(col.rgb, dirt_color.a > 0.0 ? dirt_color.rgb : light_color.rgb, d * soft);
		col.a = max(col.a, d * 0.95 * soft);
	}
	if (rain > 0.0) {
		float drop = clamp(rain_rings(p, TIME * 0.6), 0.0, 1.0) * 0.95;
		col.rgb = mix(col.rgb, light_color.rgb, drop);
		col.a = max(col.a, drop);
	}
	ALBEDO = col.rgb;
	ALPHA = col.a * smoothstep(0.0, 0.03, edge);
}
