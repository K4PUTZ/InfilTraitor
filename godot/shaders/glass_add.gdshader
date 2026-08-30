shader_type canvas_item;

// GLASS G1 — the ADD half of glass transparency. `blend_add` sums this layer's
// colour into the framebuffer, so what it emits is the highlight light: the
// bright streaks and reflections that make the surface read as glass rather than
// as tinted air. All the logic lives in the shared include so the MUL half
// cannot drift from it.
render_mode blend_add;

#include "res://godot/shaders/glass_shading.gdshaderinc"

void vertex() {
	v_glass_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 local = mod(UV / TEXTURE_PIXEL_SIZE, atom_size);
	COLOR = glass_add_color(t, local);
}
