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
uniform float scum_cut = 0.6;           // clump threshold: higher = sparser clumps
uniform float scum_scale = 6.0;         // clump size: lower = bigger chunks
uniform vec4 scum_top_color : source_color = vec4(0.0);   // alpha 0 = the clumps' lit tops are the scum colour brightened; else this colour (white fat on red flesh)
uniform float froth = 0.0;              // white foam patches: mottled, packed with tiny bubbles
uniform float junk = 0.0;               // floating rubbish: planks, cardboard, plastic, cans, drifting and turning slowly
uniform float junk_skip = 0.55;         // a cell holds a piece when its hash is above this: higher = fewer pieces
uniform float pop_bubbles = 0.0;       // slow bubbles that swell, hold, and burst with a ring (nuclear)
uniform float glow = 0.0;               // phosphorescence: slow pulsing patches pushed toward light_color
uniform float crust = 0.0;              // 0..1: how much of the surface is cooled plates (the rest is the molten base showing); lava only
uniform vec4 crust_color : source_color = vec4(0.07, 0.05, 0.045, 1.0);
uniform vec4 crack_color : source_color = vec4(1.0, 0.55, 0.1, 1.0);
uniform float crack_scale = 3.2;        // plates per GU
uniform vec4 scum_rim_color : source_color = vec4(0.0);   // alpha 0 = a clump's rim is dark; else it glows this colour (a hot rock edge)
uniform float stipple_alive = 0.42;     // a stipple cell holds a dot when its hash is above this: higher = fewer dots
uniform float oil_cut = 0.64;           // slick zone threshold: lower = the film covers more
uniform float oil = 0.0;                // sparse iridescent slicks, scattered zones that drift slowly
uniform float time_scale = 1.0;         // 0 = frozen (ice), 1 = the usual pace, 2 = twice as fast: the whole animation, not the flow alone
uniform float foam_amount = 1.0;        // the foam along the curbs
uniform float ring_amount = 1.0;        // the ring ripples of the surface look
uniform float wave_amount = 1.0;        // the bands and glints of the surface look
uniform float fire_surface = 0.2;       // how much a burning cell tints the SURFACE (the oil stays dark; the flames above it are the fire: LiquidFlames / LiquidFlameTongues)
uniform float rain = 0.0;               // 0 off .. 1 heavy: concentric rings from random drops, independent of the flow
uniform float plate_mask = 0.0;         // 1: a crust body with walkable plates (M6 F5): the vertex green says which plates still stand (0 = broken, the melt shows)
uniform vec4 ice_color : source_color = vec4(0.78, 0.88, 0.95, 0.96);   // water a cryogenic liquid froze (the vertex blue)
uniform float dot_cells = 11.0;          // stipple cells per GU

varying vec2 lp;
varying float wet;   // the vertex alpha: 0 where the cell is dry, 1 from half a voxel of depth
varying float flame; // the vertex red: how much of the surface burns here (0 water .. 1 fire), set by `LiquidSheet3D` from `LiquidFire`
varying float plate_v; // the vertex green: the share of standing plates around the vertex (`LiquidSurfaceState`), read when `plate_mask` is 1
varying float ice;     // the vertex blue: the share of frozen cells around the vertex

void vertex() {
	lp = VERTEX.xz;
	wet = COLOR.a;
	flame = COLOR.r;
	plate_v = COLOR.g;
	ice = COLOR.b;
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
	float alive = step(stipple_alive, r.x);
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

// Junk: one piece per 0.75 GU cell (when the cell's hash allows), carried by the flow slower than the water, turning slowly. Kinds by hash:
// plank (long, brown, grain), cardboard (tan square), plastic (small, blue or white), can (grey disc). Hard edges, a darker rim.
vec4 junk_layer(vec2 p, float t) {
	vec2 q = p / 0.75 - flow_dir * t * flow_speed * 0.45 / 0.75;
	vec2 id = floor(q);
	vec2 f = (fract(q) - 0.5) * 0.75;
	vec2 r = h22(id + 71.0);
	if (r.x < junk_skip) {
		return vec4(0.0);
	}
	f -= (r - 0.5) * 0.26;
	float ang = h21(id + 13.0) * 6.2832 + t * 0.2 * (r.y - 0.5);
	vec2 g = mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang))) * f;
	float kind = h21(id + 5.0);
	vec2 hs;
	vec3 c;
	bool disc = false;
	if (kind < 0.4) {
		hs = vec2(0.22, 0.032);
		c = vec3(0.36, 0.22, 0.1) * (0.85 + 0.3 * sin(g.x * 70.0 + r.y * 9.0) * 0.5);
	} else if (kind < 0.7) {
		hs = vec2(0.1, 0.085) * (0.8 + 0.4 * r.y);
		c = vec3(0.62, 0.47, 0.28);
	} else if (kind < 0.88) {
		hs = vec2(0.06, 0.04);
		c = r.y > 0.5 ? vec3(0.2, 0.4, 0.75) : vec3(0.85, 0.85, 0.8);
	} else {
		hs = vec2(0.05);
		c = vec3(0.55, 0.57, 0.6);
		disc = true;
	}
	hs *= 1.4;
	vec2 d = abs(g) - hs;
	float m = disc ? length(g) - hs.x : max(d.x, d.y);
	float inside = step(m, 0.0);
	float rim = smoothstep(-0.012, 0.0, m);
	c *= 1.0 - 0.45 * rim;
	if (disc) {
		c = mix(c, vec3(0.8), step(length(g), hs.x * 0.55) * 0.5);
	}
	// a soft dark shadow on the water just below-right of the piece
	float shadow = smoothstep(0.03, 0.0, disc ? length(g - vec2(0.02)) - hs.x : max(abs(g.x - 0.018) - hs.x, abs(g.y - 0.018) - hs.y)) * (1.0 - inside);
	return vec4(mix(vec3(0.0), c, inside), max(inside, shadow * 0.45));
}

// Popping bubbles: a 0.5 GU cell holds one bubble on a 3-6 s life: it swells (0..70%), holds and wobbles, then bursts (the last 30%): the
// disc vanishes and a ring runs outward and fades. Slow on purpose. Returns (disc, rim, ring).
vec3 pop_bubble(vec2 p, float t) {
	vec2 q = p / 0.45 - flow_dir * t * flow_speed * 0.5 / 0.45;
	vec2 id = floor(q);
	vec2 f = (fract(q) - 0.5) * 0.9;
	vec2 r = h22(id + 17.0);
	float life = 3.0 + r.x * 3.0;
	float k = t / life + r.y * 9.0;
	float n = floor(k);
	float ph = fract(k);
	vec2 r2 = h22(id + n * 2.3 + 41.0);
	if (r2.x > 0.7) {
		return vec3(0.0);
	}
	f -= (r2 - 0.5) * 0.45;
	float d = length(f);
	if (ph < 0.7) {
		float grow = smoothstep(0.0, 0.7, ph);
		float rad = (0.04 + 0.075 * r2.y) * (0.15 + 0.85 * grow) * (1.0 + 0.05 * sin(t * 4.0 + r.x * 8.0));
		float disc = step(d, rad);
		float rim = disc * step(rad * 0.6, d);
		return vec3(disc, rim, 0.0);
	}
	float b = (ph - 0.7) / 0.3;
	float rad0 = 0.04 + 0.075 * r2.y;
	float ring = smoothstep(0.014, 0.0, abs(d - rad0 * (1.0 + b * 1.8))) * (1.0 - b);
	return vec3(0.0, 0.0, ring);
}

// Plates: a cellular (Voronoi) field; returns (distance to the nearest point, to the second nearest, the nearest cell's hash). The gap F2-F1
// is small ON a crack between two plates.
vec3 plates(vec2 p, float t) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = h22(ip + g);
			o = 0.5 + 0.38 * sin(t * 0.18 + 6.2832 * o);
			vec2 d = g + o - fp;
			float dd = dot(d, d);
			if (dd < f1) {
				f2 = f1;
				f1 = dd;
				id = h21(ip + g);
			} else if (dd < f2) {
				f2 = dd;
			}
		}
	}
	return vec3(sqrt(f1), sqrt(f2), id);
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
	float t = TIME * 0.6 * time_scale;   // the whole set slower
	float soft = detail_strength;      // how strong the details are (the Director's pass: softer, the bed shows through)
	float along = dot(p, flow_dir);
	float across_d = min(p.x - rect_min.x, rect_max.x - p.x);   // distance to the nearest curb
	vec4 col = deep_color;

	if (mode >= 2) {
		float warp = vnoise(vec2(p.x * 3.0, along * 1.3 - t * flow_speed * 1.4));
		float bands = 0.5 + 0.5 * sin((along - t * flow_speed) * 10.0 + warp * 5.5 + sin(p.x * 8.0 + t) * 0.7);
		float shade = clamp(bands * 0.55 * wave_amount + warp * 0.35 + (1.0 - clamp(across_d * 2.2, 0.0, 1.0)) * 0.25, 0.0, 1.0);
		col = mix(deep_color, shallow_color, shade);
		float foam = smoothstep(0.16, 0.0, across_d) * (0.35 + 0.65 * vnoise(p * 15.0 - flow_dir * t * 2.0));
		col.rgb = mix(col.rgb, light_color.rgb, foam * 0.75 * soft * foam_amount);
		col.a = max(col.a, foam * 0.9 * soft * foam_amount);
		float glints = smoothstep(0.82, 1.0, bands) * smoothstep(0.55, 0.85, warp);
		col.rgb = mix(col.rgb, light_color.rgb, glints * 0.45 * soft * wave_amount);
		float ring = rings(p, t) * ring_amount;
		float bub = bubbles(p, t) * bubble_amount;
		col.rgb = mix(col.rgb, light_color.rgb, clamp(ring * 0.8 + bub, 0.0, 1.0) * soft);
		col.a = max(col.a, clamp(ring * 0.85 + bub, 0.0, 1.0) * soft);
	}
	if (scum > 0.0) {
		// floating clumps: thresholded noise carried by the flow (slower than the water), a dark rim and a lit top so they read as lumps
		vec2 sp = p - flow_dir * t * flow_speed * 0.6;
		float n = vnoise(sp * scum_scale) * 0.65 + vnoise(sp * 17.0 + 3.0) * 0.35;
		float bob = 0.015 * sin(t * 1.4 + n * 20.0);
		float body = smoothstep(scum_cut + bob, scum_cut + 0.1 + bob, n) * scum;
		float rim = smoothstep(scum_cut - 0.06, scum_cut + 0.02, n) * (1.0 - smoothstep(scum_cut + 0.02, scum_cut + 0.12, n)) * scum;
		float top = smoothstep(scum_cut + 0.1, scum_cut + 0.22, n);
		vec3 lump = mix(scum_color.rgb * 0.7, scum_top_color.a > 0.0 ? scum_top_color.rgb : scum_color.rgb * 1.5, top);
		col.rgb = mix(col.rgb, scum_rim_color.a > 0.0 ? scum_rim_color.rgb : scum_color.rgb * 0.3, rim * (scum_rim_color.a > 0.0 ? 0.95 : 0.7));
		col.rgb = mix(col.rgb, lump, body);
		col.a = max(col.a, max(body * 0.95, rim * 0.6));
	}
	if (crust > 0.0) {
		// cooled plates on the molten base: each plate is dark, mottled and a little lit at its middle by the heat below; the cracks between
		// them glow and pulse; some plates are missing (a hole shows the base), as many as `crust` leaves
		vec3 pl = plates(p * crack_scale - flow_dir * t * flow_speed * 0.4 * crack_scale, t);
		float gap = pl.y - pl.x;
		float crack = smoothstep(0.12, 0.0, gap);
		float present = step(pl.z, crust) * mix(1.0, smoothstep(0.35, 0.65, plate_v), plate_mask);
		float mott = 0.65 + 0.7 * vnoise(p * 19.0 + pl.z * 31.0);
		vec3 plate = crust_color.rgb * (0.6 + 0.8 * pl.z) * mott;
		plate = mix(plate, crack_color.rgb * 0.35, smoothstep(0.55, 0.0, pl.x) * 0.25);   // warmer toward the plate's middle
		float pulse = 0.75 + 0.25 * sin(t * 1.6 + pl.z * 12.0);
		vec3 glowc = crack_color.rgb * pulse * (0.6 + 0.8 * smoothstep(0.12, 0.0, gap));
		vec3 surf = mix(plate, glowc, crack);
		col.rgb = mix(col.rgb, surf, present);
		col.a = max(col.a, present * 0.98);
	}
	if (glow > 0.0) {
		float g = 0.5 + 0.5 * sin(t * 0.9 + vnoise(p * 2.5) * 6.0);
		float patch_mask = smoothstep(0.35, 0.8, vnoise(p * 3.0 - flow_dir * t * 0.05)) * (0.5 + 0.5 * g);
		col.rgb = mix(col.rgb, light_color.rgb, patch_mask * 0.55 * glow);
		col.a = max(col.a, 0.9 * glow * patch_mask);
	}
	if (pop_bubbles > 0.0) {
		vec3 pb = pop_bubble(p, t);
		col.rgb = mix(col.rgb, light_color.rgb * 0.8 + 0.2, pb.x * 0.35 * pop_bubbles);
		col.rgb = mix(col.rgb, vec3(0.95, 1.0, 0.9), (pb.y * 0.9 + pb.z * 0.8) * pop_bubbles);
		col.a = max(col.a, max(pb.x * 0.6, max(pb.y, pb.z)) * pop_bubbles);
	}
	if (junk > 0.0) {
		vec4 j = junk_layer(p, t);
		col.rgb = mix(col.rgb, j.rgb, j.a * junk);
		col.a = max(col.a, j.a * junk);
	}
	if (froth > 0.0) {
		// froth: where a slow noise says so, a mottled white mass (tiny bubbles packed together), drifting and breaking up
		vec2 fp = p - flow_dir * t * flow_speed * 0.5;
		float zone = smoothstep(0.66, 0.8, vnoise(fp * 4.5 + vec2(2.0, 9.0))) * froth;
		float speck = step(0.45, vnoise(fp * 38.0 + t * 0.3)) * 0.55 + step(0.62, vnoise(fp * 17.0 - t * 0.2)) * 0.45;
		float f = zone * (0.45 + 0.55 * speck);
		col.rgb = mix(col.rgb, light_color.rgb, f * 0.8);
		col.a = max(col.a, f * 0.9);
	}
	if (oil > 0.0) {
		// oil slicks: a low-frequency mask picks a few scattered zones (soft edges); inside, a thin-film rainbow that slowly swirls
		vec2 op = p - flow_dir * t * flow_speed * 0.35;
		float zone = vnoise(op * 1.7 + vec2(7.0, 3.0));
		float mask = smoothstep(oil_cut, oil_cut + 0.2, zone) * oil;
		float film = vnoise(op * 4.0 + zone * 3.0 + vec2(t * 0.15, 0.0)) + 0.4 * vnoise(op * 8.0 - t * 0.1);
		vec3 rainbow = mix(vec3(0.35), 0.5 + 0.5 * cos(6.2832 * (film + vec3(0.0, 0.33, 0.67))), 0.5);
		col.rgb = mix(col.rgb, mix(col.rgb * 0.4, rainbow * 0.6, 0.45), mask * 0.8);
		col.a = max(col.a, mask * 0.9);
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
	if (ice > 0.01) {
		// ICE (M6 F5): still, pale and frosted, a network of white cracks; it does not move with the flow (a frozen sheet)
		vec3 ip = plates(p * 2.6, 0.0);
		float ice_crack = smoothstep(0.06, 0.0, ip.y - ip.x);
		vec3 icec = ice_color.rgb * (0.85 + 0.25 * vnoise(p * 23.0)) * (0.9 + 0.2 * ip.z);
		icec = mix(icec, vec3(1.0), ice_crack * 0.6);
		col.rgb = mix(col.rgb, icec, clamp(ice, 0.0, 1.0));
		col.a = max(col.a, clamp(ice, 0.0, 1.0) * ice_color.a);
	}
	if (flame > 0.01) {
		// FIRE on the surface (M6 F5): tongues that rise (the noise scrolls up the board) and flicker, red at the foot, yellow at the heart; it loops in
		// real time, so a paused game still burns. Unshaded, brighter than the water so it reads as light.
		float heat = flame * (0.45 + 0.55 * vnoise(lp * 5.0 + vec2(TIME * 0.8, -TIME * 2.4)) * (0.6 + 0.4 * vnoise(lp * 11.0 + vec2(-TIME * 1.3, -TIME * 3.7))));
		vec3 fire_col = mix(vec3(0.85, 0.18, 0.03), vec3(1.0, 0.82, 0.25), smoothstep(0.5, 0.95, heat));
		col.rgb = mix(col.rgb, fire_col * 1.15, clamp(heat * 1.5, 0.0, 1.0) * fire_surface);
		col.a = max(col.a, clamp(heat * 1.4, 0.0, 1.0) * fire_surface);
	}
	ALBEDO = col.rgb;
	ALPHA = col.a * smoothstep(0.0, 0.03, edge) * wet;
}
