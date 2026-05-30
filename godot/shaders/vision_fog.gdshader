shader_type canvas_item;
// Radial fog that fades from transparent at the agent's screen position
// to a dark semi-opaque colour at the vision boundary.
// All radii are expressed in screen-space Y-UV units (0..1 = full viewport height)
// so they automatically adjust when the viewport is resized.

// Agent position in screen UV (0..1 each axis). Updated every frame by room.gd.
uniform vec2 agent_screen_uv = vec2(0.5, 0.5);

// Distance (in Y-UV units) at which fog begins.
uniform float fog_inner_uv = 0.40;

// Distance (in Y-UV units) at which fog reaches full opacity.
uniform float fog_outer_uv = 0.72;

// Fog colour (RGB) and maximum alpha.
uniform vec4 fog_color : source_color = vec4(0.04, 0.04, 0.09, 0.88);

void fragment() {
	// Correct for non-square viewports so the fog is a circle, not an ellipse.
	// SCREEN_PIXEL_SIZE = vec2(1/width, 1/height), so y/x = width/height.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - agent_screen_uv) * vec2(aspect, 1.0);
	float dist = length(d);
	float alpha = smoothstep(fog_inner_uv, fog_outer_uv, dist);
	COLOR = vec4(fog_color.rgb, fog_color.a * alpha);
}
