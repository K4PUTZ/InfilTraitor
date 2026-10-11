shader_type spatial;
// RENDER3D R3D-6 item 2 — glass_crack.gdshader's fragment on a pane-plane quad in the 3D board.
// Every uniform is MIRRORED from the 2D GlassCrackSprite's material (GlassCrackMirror3D), so the
// occupancy cut, the opening void and the field lattice stay owned by the 2D-side code that
// already builds them. UV is the sprite's UV: the quad is `crack_span` voxels, centred on the
// impact, run along +X or +Z and level up.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D crack_sheet : filter_linear, repeat_enable, hint_default_black;
uniform vec2 crack_span = vec2(20.0, 10.0);
uniform vec2 crack_pane_lo = vec2(-1000.0);
uniform vec2 crack_pane_hi = vec2(1000.0);
uniform bool crack_field = false;
uniform vec2 crack_tile_span = vec2(8.0, 8.0);
uniform vec2 crack_field_origin = vec2(0.0);
uniform vec2 crack_field_dir = vec2(1.0, 1.0);
uniform sampler2D crack_occupancy : filter_nearest, repeat_disable, hint_default_white;
uniform vec2 crack_occ_size = vec2(1.0);
uniform vec2 crack_occ_origin = vec2(0.0);
uniform float crack_hole_cut : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D crack_opening : filter_linear, repeat_disable, hint_default_black;
uniform vec2 crack_opening_origin = vec2(0.0);
uniform vec2 crack_opening_size = vec2(1.0);
uniform vec3 crack_color = vec3(0.90, 0.94, 1.0);
uniform float crack_strength : hint_range(0.0, 2.0) = 1.0;
uniform float crack_opacity : hint_range(0.0, 1.0) = 0.80;
uniform float crack_edge_feather : hint_range(0.0, 0.5) = 0.12;
// G-D54 (Director, 2026-10-09): the ink SPILLS past a hole's edge by up to this many voxels, a jagged reach per half-voxel, so it runs
// over the rim's thickness seen beside the face (the 2D board's accident that read as a torn edge). Visual chaos on purpose: it need
// not match the rim's geometry. 0 = the exact occupancy cut.
// 2026-10-10: 0 — the rim walls draw the ink themselves now (glass_pane3d's rim branch); the dial stays for an A/B.
uniform float crack_edge_spill : hint_range(0.0, 3.0) = 0.0;
// G-D55 (2026-10-10): the same crack on a FALLING VOXEL. One MultiMesh instance per voxel, a one-voxel quad on its front face;
// INSTANCE_CUSTOM.xy is that voxel's (run, level) offset from the impact, so `off` is the point of the pane the face came from and the
// ink is the pane's own. No occupancy, no opening: the voxel IS the glass.
uniform bool crack_per_voxel = false;
varying vec4 v_inst;
// The edge strips' tone (2026-10-10, Director: the darker / lighter slivers get the same effect on the decal): COLOR.r scales the
// ink as the pane's edge shades its own planes (top lighter, ends darker, bottom darkest). 1 on the face quad (no vertex colour).
varying float v_tone;
// One crack, two faces (Director, 2026-10-11: the crack must reach the pane's back face): the face quad and its twin on the back
// plane share this material; each shows only from its own side (1 = when FRONT_FACING, -1 = when not, 0 = both: strips, voxels).
instance uniform float crack_side = 0.0;

void vertex() {
	v_inst = INSTANCE_CUSTOM;
	v_tone = COLOR.r;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	if ((crack_side > 0.5 && !FRONT_FACING) || (crack_side < -0.5 && FRONT_FACING)) {
		discard;
	}
	vec2 off = crack_per_voxel ? v_inst.xy + vec2(UV.x - 0.5, 0.5 - UV.y)
		: vec2((UV.x - 0.5) * crack_span.x, (0.5 - UV.y) * crack_span.y);
	// The point of the WHOLE crack quad this is (its UV): what the sheet and the feather read.
	vec2 quad_uv = vec2(off.x / max(crack_span.x, 0.0001) + 0.5, 0.5 - off.y / max(crack_span.y, 0.0001));
	if (off.x < crack_pane_lo.x || off.x > crack_pane_hi.x
			|| off.y < crack_pane_lo.y || off.y > crack_pane_hi.y) {
		discard;
	}
	vec2 sheet_uv = crack_field
		? ((off - crack_field_origin) * crack_field_dir) / max(crack_tile_span, vec2(0.0001))
		: quad_uv;
	float ink = texture(crack_sheet, sheet_uv).r;
	vec2 occ_uv = (vec2(off.x - crack_occ_origin.x, crack_occ_origin.y - off.y)
			+ vec2(0.5)) / max(crack_occ_size, vec2(1.0));
	float occ = crack_per_voxel ? 1.0 : texture(crack_occupancy, occ_uv).r;
	if (occ < 0.5 && crack_edge_spill > 0.0) {
		vec2 cellv = floor(off * 2.0);
		float h = fract(sin(dot(cellv, vec2(12.9898, 78.233))) * 43758.5453);
		float reach = crack_edge_spill * mix(0.25, 1.0, h);
		vec2 step_uv = vec2(reach) / max(crack_occ_size, vec2(1.0));
		float o = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7853982 + h * 0.6;
			o = max(o, texture(crack_occupancy, occ_uv + vec2(cos(a), sin(a)) * step_uv).r);
		}
		occ = o;
	}
	ink *= mix(1.0, occ, crack_hole_cut);
	vec2 op_uv = vec2(off.x - crack_opening_origin.x, crack_opening_origin.y - off.y)
			/ max(crack_opening_size, vec2(0.0001));
	if (!crack_per_voxel && op_uv.x >= 0.0 && op_uv.x <= 1.0 && op_uv.y >= 0.0 && op_uv.y <= 1.0) {
		ink *= 1.0 - texture(crack_opening, op_uv).r;
	}
	if (!crack_field) {
		vec2 e = min(quad_uv, vec2(1.0) - quad_uv) / max(crack_edge_feather, 0.001);
		ink *= clamp(min(e.x, e.y), 0.0, 1.0);
	}
	ALBEDO = to_linear(crack_color) * v_tone;
	ALPHA = clamp(ink * crack_strength, 0.0, 1.0) * crack_opacity * mix(0.6, 1.0, v_tone);
}
