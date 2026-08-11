shader_type canvas_item;

// T-CURSOR — the "virtual grenade" treatment for the aiming cursor.
//
// Director, 2026-08-10: "para melhorar o visual e indicar que é uma granada
// 'virtual' podemos aplicar um color overlay vermelho com 50% de opacidade por
// cima, mais um stroke vermelho de 2px com 100% opacidade em volta, e hachuras
// diagonais vermelhas com 2px e 100% opacidade por cima do asset, ligando as
// bordas do stroke."
//
// All three marks in one pass over GrenadeProp's real baked frame, so the
// cursor is the same object the throw will put on the ground rather than a
// second, hand-drawn idea of it.
//
// SIZES ARE IN TEXTURE PIXELS, not screen pixels, and that is a decision rather
// than an oversight. The sprite is scaled by GrenadeProp.SPRITE_SCALE and again
// by the camera zoom (0.20-1.20), so a screen-space width would have to be fed
// the live zoom every frame AND would still make the marking read differently
// at every zoom level. Texture pixels keep the stroke and the hatch constant
// relative to the art they are marking, which is what makes it look like one
// symbol instead of a sprite with decoration bolted on.

uniform vec4 mark_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float overlay_strength : hint_range(0.0, 1.0) = 0.5;
uniform float outline_px : hint_range(0.0, 8.0) = 2.0;
uniform float hatch_px : hint_range(0.0, 8.0) = 2.0;
uniform float hatch_spacing_px : hint_range(2.0, 64.0) = 9.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.25;

// 1 where the asset is solid, 0 where it is not.
//
// The sampler is a PARAMETER rather than the built-in `TEXTURE`: Godot 4 only
// exposes stage built-ins inside `fragment()` itself, and reaching for TEXTURE
// here fails at compile time with "Unknown identifier in expression".
//
// UV is clamped because the outline test below deliberately samples off the
// edge of the frame, and a wrapped sample there would grow an outline out of
// the opposite side of the sprite.
float silhouette(sampler2D tex, vec2 uv, float cutoff) {
	return step(cutoff, texture(tex, clamp(uv, vec2(0.0), vec2(1.0))).a);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float inside = step(alpha_cutoff, tex.a);

	// STROKE: this texel is outside the asset, but something within a stroke's
	// width of it is inside. Eight neighbours so diagonals come out as thick as
	// the axes do.
	vec2 d = TEXTURE_PIXEL_SIZE * outline_px;
	float near = silhouette(TEXTURE, UV + vec2(d.x, 0.0), alpha_cutoff);
	near = max(near, silhouette(TEXTURE, UV + vec2(-d.x, 0.0), alpha_cutoff));
	near = max(near, silhouette(TEXTURE, UV + vec2(0.0, d.y), alpha_cutoff));
	near = max(near, silhouette(TEXTURE, UV + vec2(0.0, -d.y), alpha_cutoff));
	near = max(near, silhouette(TEXTURE, UV + d, alpha_cutoff));
	near = max(near, silhouette(TEXTURE, UV - d, alpha_cutoff));
	near = max(near, silhouette(TEXTURE, UV + vec2(d.x, -d.y), alpha_cutoff));
	near = max(near, silhouette(TEXTURE, UV + vec2(-d.x, d.y), alpha_cutoff));
	float outline = (1.0 - inside) * near;

	// HATCH: 45° lines measured in TEXEL space, so the spacing stays square on a
	// non-square frame. Masked by the silhouette, which is what makes every line
	// run from one edge of the stroke to the other with nothing sticking out.
	vec2 texel = UV / TEXTURE_PIXEL_SIZE;
	float diagonal = (texel.x + texel.y) * 0.70710678;
	float hatch = inside * step(mod(diagonal, hatch_spacing_px), hatch_px);

	// OVERLAY: half red over the asset, then the two 100% marks on top of that.
	vec3 rgb = mix(tex.rgb, mark_color.rgb, overlay_strength);
	float a = tex.a;
	float marked = max(outline, hatch);
	rgb = mix(rgb, mark_color.rgb, marked);
	a = mix(a, 1.0, marked);

	COLOR = vec4(rgb, a);
}
