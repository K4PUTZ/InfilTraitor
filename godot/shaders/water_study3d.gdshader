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
uniform float flow_speed = 0.5;          // GU / s
uniform vec4 deep_color : source_color = vec4(0.04, 0.2, 0.26, 0.82);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.46, 0.5, 0.74);
uniform vec4 light_color : source_color = vec4(0.78, 0.95, 1.0, 1.0);
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

void fragment() {
	vec2 p = lp;
	float edge = min(min(p.x - rect_min.x, rect_max.x - p.x), min(p.y - rect_min.y, rect_max.y - p.y));
	float t = TIME;
	float along = dot(p, flow_dir);
	float across_d = min(p.x - rect_min.x, rect_max.x - p.x);   // distance to the nearest curb
	vec4 col = deep_color;

	if (mode >= 2) {
		float warp = vnoise(vec2(p.x * 3.0, along * 1.3 - t * flow_speed * 1.4));
		float bands = 0.5 + 0.5 * sin((along - t * flow_speed) * 10.0 + warp * 5.5 + sin(p.x * 8.0 + t) * 0.7);
		float shade = clamp(bands * 0.55 + warp * 0.35 + (1.0 - clamp(across_d * 2.2, 0.0, 1.0)) * 0.25, 0.0, 1.0);
		col = mix(deep_color, shallow_color, shade);
		float foam = smoothstep(0.16, 0.0, across_d) * (0.35 + 0.65 * vnoise(p * 15.0 - flow_dir * t * 2.0));
		col.rgb = mix(col.rgb, light_color.rgb, foam * 0.75);
		col.a = max(col.a, foam * 0.9);
		float glints = smoothstep(0.82, 1.0, bands) * smoothstep(0.55, 0.85, warp);
		col.rgb = mix(col.rgb, light_color.rgb, glints * 0.45);
		float ring = rings(p, t);
		float bub = bubbles(p, t);
		col.rgb = mix(col.rgb, light_color.rgb, clamp(ring * 0.8 + bub, 0.0, 1.0));
		col.a = max(col.a, clamp(ring * 0.85 + bub, 0.0, 1.0));
	}
	if (mode == 1 || mode == 3) {
		float d = stipple(p, t);
		if (mode == 1) {
			// the stipple IS the water: a faint wash in the channel's footprint, the dots on top
			col = vec4(deep_color.rgb, 0.28);
		}
		col.rgb = mix(col.rgb, light_color.rgb, d);
		col.a = max(col.a, d * 0.95);
	}
	ALBEDO = col.rgb;
	ALPHA = col.a * smoothstep(0.0, 0.03, edge);
}
