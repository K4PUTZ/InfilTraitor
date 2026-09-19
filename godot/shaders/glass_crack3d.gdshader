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

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec2 off = vec2((UV.x - 0.5) * crack_span.x, (0.5 - UV.y) * crack_span.y);
	if (off.x < crack_pane_lo.x || off.x > crack_pane_hi.x
			|| off.y < crack_pane_lo.y || off.y > crack_pane_hi.y) {
		discard;
	}
	vec2 sheet_uv = crack_field
		? ((off - crack_field_origin) * crack_field_dir) / max(crack_tile_span, vec2(0.0001))
		: UV;
	float ink = texture(crack_sheet, sheet_uv).r;
	vec2 occ_uv = (vec2(off.x - crack_occ_origin.x, crack_occ_origin.y - off.y)
			+ vec2(0.5)) / max(crack_occ_size, vec2(1.0));
	ink *= mix(1.0, texture(crack_occupancy, occ_uv).r, crack_hole_cut);
	vec2 op_uv = vec2(off.x - crack_opening_origin.x, crack_opening_origin.y - off.y)
			/ max(crack_opening_size, vec2(0.0001));
	if (op_uv.x >= 0.0 && op_uv.x <= 1.0 && op_uv.y >= 0.0 && op_uv.y <= 1.0) {
		ink *= 1.0 - texture(crack_opening, op_uv).r;
	}
	if (!crack_field) {
		vec2 e = min(UV, vec2(1.0) - UV) / max(crack_edge_feather, 0.001);
		ink *= clamp(min(e.x, e.y), 0.0, 1.0);
	}
	ALBEDO = to_linear(crack_color);
	ALPHA = clamp(ink * crack_strength, 0.0, 1.0) * crack_opacity;
}
