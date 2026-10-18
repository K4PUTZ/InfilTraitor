// M6 F5 flame TONGUES: one Y-billboarded teardrop per instance (a MultiMesh of quads, see `LiquidFlameTongues`), the shape and the colour made in the
// fragment from scrolling noise: the body narrows toward the tip and bends more the higher it is, the heat runs white-yellow at the foot, orange, red at the
// edge, and the tip burns away. INSTANCE_CUSTOM = (level 0..1, seed, width scale, height scale): level 0 collapses the quad. Unshaded, additive, never
// depth-writing, like the sheet it stands on; real time, so a paused game still burns.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float flame_width = 0.38;    // GU
uniform float flame_height = 0.75;   // GU
uniform float intensity = 0.8;
uniform float scroll_speed = 1.35;
uniform float sway_amount = 0.95;    // how far a tongue bends toward its tip
uniform float flicker_amount = 0.35; // how much a tongue's brightness and height breathe
uniform vec4 base_color : source_color = vec4(0.0);   // the COOL flames among the others (rgb, a = the share of tongues that are cool): blue for a hydrocarbon, deep red for organic matter; a 0 = none

varying vec4 cd;
varying float cool;     // 1 for a small cool tongue (blue), 0 for an ordinary one

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
	cd = INSTANCE_CUSTOM;
	float on = step(0.02, cd.x);
	cool = step(fract(cd.y * 7.13 + 0.11), base_color.a);
	VERTEX.x *= mix(1.0, 0.62, cool);
	VERTEX.y *= mix(1.0, 0.5, cool);
	VERTEX.y *= 1.0 - flicker_amount * 0.45 + flicker_amount * 0.9 * vnoise(vec2(cd.y * 50.0, TIME * 2.3));    // each tongue breathes in height
	VERTEX.x *= flame_width * cd.z * (0.55 + 0.45 * cd.x) * on;
	VERTEX.y *= flame_height * cd.w * (0.3 + 0.7 * cd.x) * on;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float h = 1.0 - UV.y;                       // 0 at the foot, 1 at the tip
	float seed = cd.y;
	float t = TIME * scroll_speed * (0.8 + 0.5 * fract(seed * 3.7));
	float n1 = vnoise(vec2(UV.x * 2.5 + seed * 11.0, h * 2.2 - t * 1.7));
	float n2 = vnoise(vec2(UV.x * 5.5 - seed * 5.0, h * 4.5 - t * 3.1));
	float wind = 0.14 * sin(TIME * 0.8 + cd.y * 3.0) + 0.06 * sin(TIME * 2.1);    // a lean the tongues share, a little out of step
	float sway = ((n1 - 0.5) * sway_amount + wind) * h * h;      // bends more toward the tip
	float x = (UV.x - 0.5) - sway;
	float half_w = 0.46 * pow(max(1.0 - h, 0.0), 0.8) * (0.78 + 0.45 * n2);
	half_w *= smoothstep(0.0, 0.10, h);          // a rounded foot
	float d = abs(x) / max(half_w, 0.0001);
	float body = 1.0 - smoothstep(0.45, 1.0, d + (n2 - 0.5) * 0.3 * h);
	float burn = 1.0 - smoothstep(0.55, 1.0, h + (n1 - 0.5) * 0.35);   // the tip frays away
	float heat = body * burn * (1.0 - 0.75 * h);
	vec3 col = mix(vec3(0.6, 0.05, 0.01), vec3(1.0, 0.38, 0.04), smoothstep(0.08, 0.45, heat));
	col = mix(col, vec3(1.0, 0.8, 0.28), smoothstep(0.55, 0.95, heat));    // a small yellow heart, not a white one
	// a cool tongue: the same shape, smaller (the vertex shrank it), in the cool colour with a pale heart
	vec3 cool_col = mix(base_color.rgb * 0.55, base_color.rgb * 1.25, smoothstep(0.08, 0.5, heat));
	cool_col = mix(cool_col, mix(base_color.rgb, vec3(1.0), 0.75), smoothstep(0.6, 0.95, heat));
	col = mix(col, cool_col, cool);
	float flick = 1.0 - flicker_amount + flicker_amount * 1.6 * vnoise(vec2(seed * 40.0, TIME * 3.4));    // brightness varies per tongue
	ALBEDO = col * intensity * flick;
	ALPHA = clamp(body * burn * cd.x, 0.0, 1.0) * 0.9;
}
