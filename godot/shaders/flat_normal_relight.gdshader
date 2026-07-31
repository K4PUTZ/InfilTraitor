// ACTOR_MASTER_PLAN D17 — relights a flat, unlit sprite using a baked normal
// map, so a pre-rendered 2D frame (actor_frame_bake_spike.gd's output) reads
// with real directional shading + specular "shine" without any voxel
// geometry or live 3D scene at runtime. The normal map was baked in the same
// fixed camera space the game's isometric view always uses (elevation 30°,
// azimuth 45°) — light_dir must be supplied in that same space (see
// FloatingCollectible.gd for the world→camera-space conversion).
//
// Deliberately continuous (not bucket-quantized) — VoxelLightField's 12
// discrete buckets are a wall-baking technique (D13's own scope); a live
// per-pixel shader has no bake-time cost to economize on, so real N·L reads
// better here and is what makes the normal map worth having at all.
shader_type canvas_item;

uniform sampler2D normal_tex : source_color, filter_nearest;
uniform vec3 light_dir = vec3(0.0, 0.0, 1.0); // camera-space, normalized
uniform vec3 light_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float light_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float ambient : hint_range(0.0, 1.0) = 0.55;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.4;
uniform float specular_shininess : hint_range(1.0, 128.0) = 16.0;

// COLLECTIBLE-OUTLINE-01 (Director, 2026-07-29: "a arma está muito escura em
// relação ao fundo... dá pra colocar um stroke azulzinho de 1 pixel?").
//
// Silhouette stroke drawn in the frame's own transparent margin — a
// neighbourhood alpha test, not a second sprite scaled up (which shears thin
// features and needs its own copy of every frame). It costs one extra texture
// fetch set on the transparent pixels only, needs no new asset, and follows all
// 8 baked rotation frames for free because it is derived from whatever alpha the
// current frame has.
//
// Deliberately NOT relit: this is an affordance telling the player the object is
// interactive, and the whole reason it exists is that the lit sprite disappears
// into a dark floor. A stroke that dims with the room would fail exactly when it
// is needed. Width is in TEXELS, so it scales with the object and the camera.
// Default OFF (width 0). This shader is shared — GrenadeProp relights through it
// too and never sets these uniforms, so a non-zero default would have silently
// outlined every test-zone grenade as well. Opt in per material, as
// FloatingCollectible does.
uniform vec4 outline_color : source_color = vec4(0.35, 0.72, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 0.0;
uniform float outline_threshold : hint_range(0.0, 1.0) = 0.4;

// COLOR-GRADE-02 (Director, 2026-07-30: "dá pra aumentar um pouquinho a
// saturação e o contraste das armas sem refazer o bake?"). A RUNTIME nudge on
// top of D31's baked grade (ACTOR_MASTER_PLAN), not a replacement for it —
// the whole point is a tunable knob that needs no windowed GPU re-bake to
// iterate on. Defaults 1.0 = no-op, same "shared shader, opt in per material"
// contract outline_width already uses: GrenadeProp relights through this
// shader too and never sets these, and the grenade already reads with real
// colour (D31 measured it, deliberately left alone), so a non-1.0 default
// here would have silently re-graded every grenade as well.
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec4 albedo = texture(TEXTURE, UV);

	// Outside the silhouette: paint the stroke where a neighbour is inside it.
	if (albedo.a < outline_threshold) {
		float neighbour_a = 0.0;
		if (outline_width > 0.0 && outline_color.a > 0.0) {
			vec2 o = TEXTURE_PIXEL_SIZE * outline_width;
			neighbour_a = max(neighbour_a, texture(TEXTURE, UV + vec2( o.x,  0.0)).a);
			neighbour_a = max(neighbour_a, texture(TEXTURE, UV + vec2(-o.x,  0.0)).a);
			neighbour_a = max(neighbour_a, texture(TEXTURE, UV + vec2( 0.0,  o.y)).a);
			neighbour_a = max(neighbour_a, texture(TEXTURE, UV + vec2( 0.0, -o.y)).a);
			neighbour_a = max(neighbour_a, texture(TEXTURE, UV + vec2( o.x,  o.y)).a);
			neighbour_a = max(neighbour_a, texture(TEXTURE, UV + vec2( o.x, -o.y)).a);
			neighbour_a = max(neighbour_a, texture(TEXTURE, UV + vec2(-o.x,  o.y)).a);
			neighbour_a = max(neighbour_a, texture(TEXTURE, UV + vec2(-o.x, -o.y)).a);
		}
		// Coverage, not a binary test. A hard `>= threshold` cut left the stroke
		// DASHED on the real capture: the sprite draws at a non-integer scale, so
		// some outline texels land between screen pixels and their neighbour
		// alpha (linear-filtered) fell just under the cut. Fading the stroke in
		// across the threshold anti-aliases it and fills those gaps with dimmer
		// pixels instead of dropping them.
		float coverage = smoothstep(0.02, outline_threshold, neighbour_a);
		COLOR = vec4(outline_color.rgb, outline_color.a * coverage);
	} else {
		vec4 n_sample = texture(normal_tex, UV);
		vec3 n = normalize(n_sample.rgb * 2.0 - 1.0);
		vec3 l = normalize(light_dir);

		float ndotl = clamp(dot(n, l), 0.0, 1.0);
		// Fixed view direction: the bake camera never moves relative to the
		// object within one frame, so straight-on (+Z in this encoding) is a
		// reasonable stand-in for a view vector without carrying a second
		// baked map just for that.
		vec3 view_dir = vec3(0.0, 0.0, 1.0);
		vec3 half_vec = normalize(l + view_dir);
		float spec = pow(clamp(dot(n, half_vec), 0.0, 1.0), specular_shininess) * specular_strength;

		vec3 lit = albedo.rgb * (ambient + ndotl * light_intensity * light_color) + spec * light_color;

		// COLOR-GRADE-02: saturation first (pivot on this pixel's own luma, the
		// standard grade formula), then contrast (pivot on mid-grey) — both
		// no-ops at 1.0, clamped so an aggressive nudge can't wrap/invert.
		float luma = dot(lit, vec3(0.299, 0.587, 0.114));
		lit = mix(vec3(luma), lit, saturation);
		lit = (lit - 0.5) * contrast + 0.5;
		lit = clamp(lit, 0.0, 1.0);

		COLOR = vec4(lit, albedo.a);
	}
}
