// R3D-SURFACES — the feathered border between two organic ground materials (`GroundTransitions3D`).
//
// One quad per floor GU that touches a different organic ground; the quad wears the NEIGHBOUR's photographic plane (sampled in world
// space, exactly as that neighbour's own floor samples it, so the photo is continuous across the border) with an alpha that is
// 0.5 on the shared edge and falls to 0 one band-width inside this GU. The neighbour's GU does the same with this GU's photo, so at the
// edge both sides show the same 50 / 50 mix: the border dissolves from both sides and needs no priority between materials.
//
// The alpha is `smoothstep(-W', W', -d + n)`: `d` is the distance into THIS cell from the shared edge (straight, or radial around a
// corner that only touches diagonally), `n` is a world-space noise that moves the iso-line in and out. `n` depends on the world
// position only, so it is the same on both sides of the edge and the two overlays stay continuous. `W'` leaves room for `n` so the
// alpha is already 0 at the cell boundary (the overlay never ends in a visible step).
//
// Lit and sooted like the floor under it: the cell plane's light bucket and its soot tone (B, read bilinear) at this pixel.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform sampler2D surface_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D surface_macro : filter_linear_mipmap, repeat_enable;
uniform sampler2D edge_noise : filter_linear, repeat_enable;
uniform sampler2DArray cell_plane : filter_linear, repeat_disable;
uniform int level_base = 0;
uniform int level_count = 1;
uniform int mesh_ground_level = 80;
uniform int rel_offset = -80;
uniform ivec2 plane_origin = ivec2(64, 64);
uniform ivec2 plane_size = ivec2(512, 512);
uniform float bucket_lum[12];
uniform vec3 face_tone = vec3(1.0, 0.975, 0.945);
uniform float depth_dim[5];
// The knobs (GroundTransitions3D.WIDTH_GU / NOISE_AMOUNT / NOISE_PERIOD_GU), one band width per side, in GU.
uniform float band = 1.0;
uniform float noise_amount = 0.35;
uniform float noise_period = 2.5;

varying vec3 v_world;
varying float v_flags;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_flags = COLOR.r * 255.0;
}

void fragment() {
	// Bits: 1 W (-x), 2 E (+x), 4 N (-z), 8 S (+z), 16 NW, 32 NE, 64 SW, 128 SE — the neighbours across THIS target's material.
	int flags = int(floor(v_flags + 0.5));
	vec2 p = UV;
	float d = 1.0e3;
	if ((flags & 1) != 0) { d = min(d, p.x); }
	if ((flags & 2) != 0) { d = min(d, 1.0 - p.x); }
	if ((flags & 4) != 0) { d = min(d, p.y); }
	if ((flags & 8) != 0) { d = min(d, 1.0 - p.y); }
	if ((flags & 16) != 0) { d = min(d, length(p)); }
	if ((flags & 32) != 0) { d = min(d, length(p - vec2(1.0, 0.0))); }
	if ((flags & 64) != 0) { d = min(d, length(p - vec2(0.0, 1.0))); }
	if ((flags & 128) != 0) { d = min(d, length(p - vec2(1.0, 1.0))); }
	float n = (texture(edge_noise, v_world.xz / noise_period).r * 0.65 + texture(edge_noise, v_world.xz / (noise_period * 0.37)).r * 0.35 - 0.5) * 2.0;
	float amp = noise_amount * band;
	float w = band - amp;
	float alpha = smoothstep(-w, w, -d * band + n * amp);
	if (alpha <= 0.002) {
		discard;
	}
	// The floor's own lighting at this pixel.
	ivec3 v = ivec3(floor(v_world * 8.0 - vec3(0.0, 0.06, 0.0)));
	int level = v.y + mesh_ground_level;
	int layer = clamp(level - level_base, 0, level_count - 1);
	vec2 plane_uv = (v_world.xz * 8.0 + vec2(plane_origin)) / vec2(plane_size);
	float tone = texture(cell_plane, vec3(plane_uv, float(layer))).b;
	int bucket = int(floor(texelFetch(cell_plane, ivec3(ivec2(v.x, v.z) + plane_origin, layer), 0).g * 255.0 + 0.5));
	float f = face_tone.x * bucket_lum[clamp(bucket, 0, 11)] * tone;
	int rel = level + rel_offset;
	if (rel < 0) {
		f *= depth_dim[min(-rel - 1, 4)];
	}
	vec3 macro_n = texture(surface_macro, v_world.xz / 61.0).rgb;
	vec3 macro_mult = vec3(mix(0.85, 1.15, macro_n.r), mix(0.85, 1.15, macro_n.g), mix(0.90, 1.05, macro_n.b));
	ALBEDO = srgb_to_linear(texture(surface_tex, v_world.xz / 8.0).rgb * macro_mult * f);
	ALPHA = alpha;
}
