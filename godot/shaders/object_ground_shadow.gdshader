shader_type canvas_item;

// Ground shadow for a baked prop, taken from the prop's OWN silhouette.
//
// Director, 2026-08-10: "a sombra da granada. Nós já temos nas outras armas, e
// está funcionando bem. Vamos aplicar na granada também."
//
// SUBSTITUTION, STATED RATHER THAN HIDDEN. FloatingCollectible's shadow is two
// BAKED passes per frame (`frame_%02d_shadow_{sharp,soft}.png`), crossfaded by
// height — and `grenade_collectible_frames/` really does ship 480 of them. The
// thrown prop's own `grenade_frames/` has none: `grenade_frame_bake_spike.gd`
// never had a shadow pass, only `grenade_collectible_bake_spike.gd` does. So
// this reads the alpha of the colour frame the prop is already showing and
// blurs it on the fly, which gives the same two looks from one texture and no
// new pipeline run. It is the object's real silhouette, not a stand-in ellipse.
// If the baked route is wanted later, the missing piece is a shadow pass on the
// prop spike, and this shader stops being needed.

uniform float blur_px : hint_range(0.0, 16.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	float alpha;
	if (blur_px <= 0.01) {
		// Touching the floor: the shadow is the silhouette, hard-edged.
		alpha = texture(TEXTURE, UV).a;
	} else {
		// In the air: a 5x5 box over the alpha. Averaging is what produces the
		// diffusion — the edge texels pick up their transparent neighbours and
		// fall off gradually, so the penumbra grows with `blur_px` without the
		// core moving. UV is clamped because the taps deliberately reach past
		// the frame, where a wrapped read would smear the opposite edge in.
		vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_px * 0.5;
		float total = 0.0;
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				vec2 uv = clamp(UV + vec2(float(x), float(y)) * step_uv,
					vec2(0.0), vec2(1.0));
				total += texture(TEXTURE, uv).a;
			}
		}
		alpha = total / 25.0;
	}
	COLOR = vec4(0.0, 0.0, 0.0, alpha * strength);
}
