shader_type canvas_item;

// GLASS G1 — the MUL half of glass transparency. `blend_mul` multiplies this
// layer's colour into the framebuffer, so what it emits is the modulation the
// background is seen through: the tint plus the frosted pattern. All the logic
// lives in the shared include so the ADD half cannot drift from it.
render_mode blend_mul;

#include "res://godot/shaders/glass_shading.gdshaderinc"

void vertex() {
	v_glass_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 local = mod(UV / TEXTURE_PIXEL_SIZE, atom_size);
	COLOR = glass_mul_color(t, local);
}
