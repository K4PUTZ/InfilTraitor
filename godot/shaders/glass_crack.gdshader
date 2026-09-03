shader_type canvas_item;

// GLASS CRACK-02 / G-D27 — THE CRACK IS A SPRITE, NOT SOMETHING THE VOXEL
// SHADER DRAWS.
//
// (Director, 2026-09-02: *"talvez fosse melhor colocar um sprite em alpha, só com
// a parte branca das rachaduras, sobre a vidraça deixando o buraco sem voxels no
// centro. Porque no fim do dia a gente quer que os voxels atrás da rachadura
// sejam idênticos aos outros."*)
//
// CRACK-01 drew the web inside `glass_pane.gdshader`, and that is why it was
// rejected three times: a crack drawn BY the voxel shader inherits the atom's
// per-plane `dim` (1.0 / 0.78 / 0.60), the coverage alpha `cover` the whole
// fragment is blended at, and the quad seams — additive or not, it is still the
// voxel's. Only LEAVING the voxel reaches *"idênticos aos outros"*.
//
// ── HOW THE GEOMETRY WORKS, AND WHY THERE IS NO INVERSE IN HERE ──────────────
//
// CRACK-01-D established the pane's own basis: a voxel's position on a wall face
// is `impact + run · RUN_STEP + level · (0, −VOXEL_STEP)`, with RUN_STEP =
// (±16, 8). CRACK-01 needed to INVERT that per fragment. The sprite does not:
// VoxelRenderer bakes the FORWARD basis straight into the node's Transform2D, so
// the quad is already the pane's parallelogram and UV is already the sheet.
// The basis changed job rather than being thrown away (§13.1), and
// `glass_crack_selftest` [10] still pins it — against the transform now.
//
// So all this shader has to do with UV is turn it back into (run, level)
// OFFSETS in voxels, which is one multiply, for the pane clipping below.
// ⚠️ BLEND MODE IS THE DIRECTOR'S, AND IT CHANGED ON 2026-09-02 (*"vamos tentar
// botar ele com 90% de opacidade, e deixar um pouquinho de transparência
// passar"*). It was `blend_add`, which is what G-D26 proposed — but additive
// SATURATES: the web's core blew out to pure white over anything, so there was
// no "a little transparency" left to give. `blend_mix` at an alpha of
// `crack_opacity` is the sticker he described: 90% crack, 10% of the pane
// showing through, everywhere the sheet has ink.
//
// G-D26 IS NOT WEAKENED BY THIS, and the distinction is the whole reason the
// crack left the voxel. G-D26 bans changing a VOXEL's transparency, because that
// property is read continuously across a pane and the untouched neighbour draws
// the cell boundary for you — a moldura. A sprite cannot do that whatever it
// blends with: it draws OVER the pane in one continuous piece, and the glass
// underneath is untouched.
render_mode blend_mix;

// The fracture sheet: GRAYSCALE ON BLACK (the art G-ART shipped, unchanged —
// §13.1). Luma IS the alpha; the art carries no alpha channel and must not need
// one, because `check_decal.py` measures the ink in luminance for exactly this
// reason. hint_default_black so an unbound sampler draws nothing.
uniform sampler2D crack_sheet : filter_linear, repeat_disable, hint_default_black;

// How many VOXELS the full sheet spans, per width (G-D14's two hole sizes). The
// node's transform is built from this, so the shader is TOLD the number rather
// than deriving it — the two must agree or the clipping is off.
uniform vec2 crack_span = vec2(20.0, 10.0);

// ── THE ONE REAL COST G-D27 NAMED BEFORE THE BUILD ──────────────────────────
//
// A sprite is a rectangle and a pane is not, so a crack near a frame would bleed
// over whatever is beside it. These are the pane's own bounds as (run, level)
// OFFSETS from the impact, in voxels — the pane is a rect in that space by
// construction, so the clip is two comparisons.
uniform vec2 crack_pane_lo = vec2(-1000.0);
uniform vec2 crack_pane_hi = vec2(1000.0);

// ── G-D30 — A DESTROYED VOXEL CUTS THE SPRITE ───────────────────────────────
//
// (Director, 2026-09-02: *"possivelmente, tirar o voxel de trás e deixar o
// adesivo pode ser que não incomode, representa de fato os estilhaços. Mas
// precisamos ver acontecendo pra confirmar. Talvez seja necessário remover um
// pedaço do sprite em runtime […] dá pra fazer isso?"*)
//
// `crack_occupancy` is a small R8 image in the PANE's own (run, level) space —
// one texel per cell, 1 where glass still stands, 0 where it is gone. The
// renderer rebuilds it from the glass TileMapLayer itself (the live authority
// that `erase_cell` writes), so a second event re-cuts every existing crack with
// no "update the old sprites" pass beyond that rebuild.
//
// ⚠️ THE CUT AMOUNT IS THE DIRECTOR'S AND IT IS A DIAL, NOT A BOOLEAN. The open
// question is fiction, not engineering: cutting says *the crack lives on glass
// that exists*; not cutting says *the crack IS the shard cloud, and it outlives
// the pane*. So `crack_hole_cut` is continuous 0..1 and gets settled by looking
// at a same-boot triptych.
//
// Two consequences worth stating: a G-D9 banded pane's brick sill is not on the
// glass layer either, so the web is cut off it for free (§13.5); and armored
// glass never destroys a voxel (G-D15), so its occupancy is solid and this dial
// cannot erase it.
//
// hint_default_white: an unbound occupancy reads 1 everywhere = no cut.
uniform sampler2D crack_occupancy : filter_nearest, repeat_disable, hint_default_white;
uniform vec2 crack_occ_size = vec2(1.0);
// (run_min, level_max) of the occupancy image, as offsets from the impact — the
// RAW pane bounds, NOT the clip bounds above (those carry half a voxel of slack,
// which would shift the lookup by half a texel).
uniform vec2 crack_occ_origin = vec2(0.0);
uniform float crack_hole_cut : hint_range(0.0, 1.0) = 1.0;

// G-D26 — ADDITIVE, and now additive by BLEND MODE rather than by arithmetic
// inside someone else's shader. `blend_add` is `dst.rgb += src.rgb · src.a`, so
// this is literally `lit + crack_colour · crack`: the glass behind is untouched,
// and a cracked voxel cannot frame itself against its neighbours.
uniform vec3 crack_color : source_color = vec3(0.90, 0.94, 1.0);
uniform float crack_strength : hint_range(0.0, 2.0) = 1.0;
// How opaque the web is at full ink. 1.0 would hide the pane completely where the
// sheet is solid, and the Director wants a little of it through — *"da pra ver um
// pouco do cenário atrás da rachadura"*. Ruled 0.90 and then 0.80 the same day.
//
// ⚠️ It is the WHOLE opacity: `crack_strength` used to be a second multiplier
// tuned for the additive mode, and 0.85 × 0.90 landed at 76%, not the 90% that
// was asked for. Under a mix the ink IS the shape, so the gain is 1.0 and this
// dial means what it says.
uniform float crack_opacity : hint_range(0.0, 1.0) = 0.80;

// A soft outer falloff so the web fades instead of ending on the sheet's edge
// (G-D23: beyond the sheet there is simply NO crack, never a mirrored one).
uniform float crack_edge_feather : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	// UV -> (run, level) offsets from the impact, in voxels. UV.y grows DOWNWARD
	// and level grows UPWARD, hence the sign.
	vec2 off = vec2((UV.x - 0.5) * crack_span.x, (0.5 - UV.y) * crack_span.y);
	if (off.x < crack_pane_lo.x || off.x > crack_pane_hi.x
			|| off.y < crack_pane_lo.y || off.y > crack_pane_hi.y) {
		discard;
	}

	// Luma -> alpha. The sheet is grayscale, so RED is the whole story.
	float ink = texture(crack_sheet, UV).r;

	// G-D30 — the cut. Nearest-filtered on purpose: a destroyed voxel IS a voxel,
	// and the hole's own edge is voxel-shaped whatever this does. Softening it
	// would put a blurred square back into a web that exists to have none.
	vec2 occ_uv = (vec2(off.x - crack_occ_origin.x, crack_occ_origin.y - off.y)
			+ vec2(0.5)) / max(crack_occ_size, vec2(1.0));
	ink *= mix(1.0, texture(crack_occupancy, occ_uv).r, crack_hole_cut);

	// G-D23's clamp, as a feather: the sheet does not repeat and does not mirror,
	// it fades out at its own edge.
	vec2 e = min(UV, vec2(1.0) - UV) / max(crack_edge_feather, 0.001);
	ink *= clamp(min(e.x, e.y), 0.0, 1.0);

	COLOR = vec4(crack_color, clamp(ink * crack_strength, 0.0, 1.0) * crack_opacity);
}
