shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque;

// T-CURSOR on the 3D board — the "virtual grenade" treatment, now on the real mesh (RETIRE-2 of R3D-RETIRE-2D).
//
// Director, 2026-08-10: a red colour overlay at 50% opacity, a red stroke around the asset and red diagonal hatching over it
// ("planned", not "there"). The 2D shader did this per texel of a baked frame; here the same three marks come from the mesh:
//  - the OVERLAY is the whole surface, tinted `overlay_strength` red;
//  - the STROKE is the silhouette rim (the surface turning away from the camera), fully opaque;
//  - the HATCH is a diagonal stripe pattern in SCREEN pixels, fully opaque, so it reads the same at every zoom, as the 2D
//    version's texture-pixel widths did relative to the art.

uniform vec4 mark_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float overlay_strength : hint_range(0.0, 1.0) = 0.5;
uniform float rim_start : hint_range(0.0, 1.0) = 0.62;
uniform float hatch_px : hint_range(0.0, 8.0) = 2.0;
uniform float hatch_spacing_px : hint_range(2.0, 64.0) = 8.0;

void fragment() {
	float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float stroke = step(rim_start, rim);
	float diag = mod(FRAGCOORD.x + FRAGCOORD.y, hatch_spacing_px);
	float hatch = 1.0 - step(hatch_px, diag);
	float solid = max(stroke, hatch);
	ALBEDO = mark_color.rgb;
	ALPHA = mix(overlay_strength, 1.0, solid);
}
