## D33 Part 2 — DecalCompositor: the GDScript port of
## tools/asset_generation/generate_voxel.py's real compositing math
## (_paste_decal + compose_decal_voxel), NOT the simplified "resize + shear"
## sketch D33's own §5 originally described — that sketch was written from
## memory before this file was read line by line. The actual Python compositor
## inverse-maps every destination pixel into the decal's parametric (s, t)
## space through a general parallelogram (not a fixed shear), 4x4-supersamples
## it, and premultiplied-alpha-blends the result — see _paste_decal's own
## docstring for why (inverse mapping so an oblique projection leaves no
## holes). This port must be numerically equal to that function, not to a
## cheaper approximation of it — proven by
## godot/scripts/tools/decal_compositor_equality_selftest.gd against fixtures
## godot/scripts/tools/fixtures/d33_part2/ generated straight from the real
## Python functions (tools/asset_generation/d33_part2_fixture_gen.py).
##
## Known, accepted sources of sub-tolerance divergence from the Python
## reference (measured by the selftest, not assumed away):
##  - Godot's Image.INTERPOLATE_LANCZOS and Pillow's Image.LANCZOS are
##    different implementations (kernel radius/windowing); the pre-resize
##    step this class ports (native x 4 supersample) cannot be bit-identical
##    across them.
##  - Python's round() is round-half-to-even; GDScript Image.set_pixel() on an
##    RGBA8-format Image rounds half-up at the C++ level. Only reachable at
##    exact .5 boundaries in 0..255 space, so it affects at most a handful of
##    pixels' least-significant bit.
## Rule 8 is not implicated here: this class produces an Image the caller
## registers exactly like any other baked/composite page (Part 1's
## DamageCompositeCache) — it never touches the tilemap directly.
class_name DecalCompositor
extends RefCounted

## Samples per axis, per destination pixel — pinned equal to generate_voxel.py's
## _DECAL_SUPERSAMPLE. Changing this on only one side is exactly the kind of
## silent divergence the equality selftest exists to catch.
const SUPERSAMPLE: int = 4

## Voxel geometry vertices — copied from generate_voxel.py's own constants
## (TILE_W=32, TILE_H=16, SIDE_H=20: V_N=(16,0) V_E=(32,8) V_S=(16,16)
## V_W=(0,8) V_WB=(0,28) V_SB=(16,36) V_EB=(32,28), the last two from
## TILE_H+SIDE_H-TILE_H//2 = 16+20-8 = 28). Single source of truth for every
## face target this class or its callers use — never re-derive these
## independently. V_WB/V_EB were briefly wrong here (26, an arithmetic slip —
## 28 was mistyped as 26) and it went undetected by the Part 2 equality
## selftest because that selftest's two targets (FACE_SE, FACE_TOP) don't
## reference V_WB or V_EB at all; FACE_SW and FACE_SE_MIRRORED do, and those
## are exactly what D33 Part 3a's bullet-LEFT/bullet-RIGHT wiring uses. Found
## while building Part 3b's fixtures (its geometry is printed straight from
## the real Python constants), fixed here, and the selftest gap that let it
## through is closed alongside this fix.
const V_N := Vector2(16, 0)
const V_E := Vector2(32, 8)
const V_S := Vector2(16, 16)
const V_W := Vector2(0, 8)
const V_WB := Vector2(0, 28)
const V_SB := Vector2(16, 36)
const V_EB := Vector2(32, 28)

const LATERAL_NATIVE := Vector2i(16, 20)
const TOP_NATIVE := Vector2i(16, 16)

## Face targets, in compose_decal_voxel()'s {"origin","u_end","v_end","native"}
## shape. Geometry matches generate_voxel.py's _FACE_TOP/_FACE_SW/_FACE_SE/
## _FACE_SE_MIRRORED exactly. FACE_SE_MIRRORED is NOT the same parallelogram
## as FACE_SE (origin/u_end/v_end swapped so `u` runs the opposite direction
## across the SAME physical face) — that swap IS the mirror, not a bug: see
## generate_voxel.py's _mirror_target() docstring, "order is preserved, so u
## ends up running right to left". FACE_SE is blast-cracked's un-mirrored
## third face; FACE_SE_MIRRORED is the bullet-cracked-RIGHT target.
const FACE_TOP := {"origin": V_N, "u_end": V_E, "v_end": V_W, "native": TOP_NATIVE}
const FACE_SW := {"origin": V_W, "u_end": V_S, "v_end": V_WB, "native": LATERAL_NATIVE}
const FACE_SE := {"origin": V_S, "u_end": V_E, "v_end": V_SB, "native": LATERAL_NATIVE}
const FACE_SE_MIRRORED := {"origin": V_E, "u_end": V_S, "v_end": V_EB, "native": LATERAL_NATIVE}

## D33 Part 3b — the exposed CUT FACE of a half voxel (HalfVoxelCompositor's
## CUT_PLANE, extruded the wall's own full height). Origin/u_end/v_end are
## generate_voxel.py's _CUT_NW_MID/_CUT_ES_MID/(+SIDE_H) — (8,4)/(24,12)/(8,24)
## — mirrored the same way FACE_SE_MIRRORED mirrors FACE_SE, for the same
## reason (a bullet/blast on the RIGHT side needs its own, not FACE_CUT_LEFT
## reused).
const FACE_CUT_LEFT := {"origin": Vector2(8, 4), "u_end": Vector2(24, 12), "v_end": Vector2(8, 24), "native": LATERAL_NATIVE}
const FACE_CUT_RIGHT := {"origin": Vector2(24, 4), "u_end": Vector2(8, 12), "v_end": Vector2(24, 24), "native": LATERAL_NATIVE}

## D33 Part 3c — the sunken top surface of a floor-DENTED (blast-from-above)
## half voxel: the whole top diamond shifted down by DENTED_CUT_DEPTH (10).
## generate_voxel.py's _FACE_SUNK_TOP = (sunk_N, sunk_E, sunk_W, _TOP_NATIVE);
## no mirrored variant — a floor dent has no left/right, only "from above".
const FACE_SUNK_TOP := {"origin": Vector2(16, 10), "u_end": Vector2(32, 18), "v_end": Vector2(0, 18), "native": TOP_NATIVE}


## Alpha-composites `decal` onto `dst` (both must already be Image.FORMAT_RGBA8),
## mapping the decal's whole rectangle onto the parallelogram
## (origin, u_end, v_end), scaled to `native` texels before the supersample.
## Direct port of generate_voxel.py's _paste_decal() — inverse-mapped per
## destination pixel so an oblique projection cannot leave sampling holes, and
## the 0 <= s,t < 1 test doubles as the clip against the target polygon.
static func paste_decal(dst: Image, decal: Image, origin: Vector2, u_end: Vector2,
		v_end: Vector2, native: Vector2i) -> void:
	var ux: float = u_end.x - origin.x
	var uy: float = u_end.y - origin.y
	var vx: float = v_end.x - origin.x
	var vy: float = v_end.y - origin.y
	var det: float = ux * vy - uy * vx
	if is_zero_approx(det):
		push_error("[DecalCompositor] paste_decal: degenerate parallelogram (origin=%s u_end=%s v_end=%s)" % [origin, u_end, v_end])
		return

	## Reduce the decal to exactly the face's native texel grid x supersample —
	## same reduction generate_voxel.py's canon x20/16 stretch happens through
	## (native encodes the (16,20) vs (16,16) asymmetry, not this function).
	var work: Image = decal.duplicate()
	work.resize(native.x * SUPERSAMPLE, native.y * SUPERSAMPLE, Image.INTERPOLATE_LANCZOS)
	var src_w: int = work.get_width()
	var src_h: int = work.get_height()

	var corners_x: Array[float] = [origin.x, u_end.x, v_end.x, origin.x + ux + vx]
	var corners_y: Array[float] = [origin.y, u_end.y, v_end.y, origin.y + uy + vy]
	var x0: int = maxi(0, int(corners_x.min()) - 1)
	var x1: int = mini(dst.get_width(), int(corners_x.max()) + 2)
	var y0: int = maxi(0, int(corners_y.min()) - 1)
	var y1: int = mini(dst.get_height(), int(corners_y.max()) + 2)

	var step: float = 1.0 / float(SUPERSAMPLE)
	var sample_weight: float = 1.0 / float(SUPERSAMPLE * SUPERSAMPLE)

	for py in range(y0, y1):
		for px in range(x0, x1):
			var acc_r: float = 0.0
			var acc_g: float = 0.0
			var acc_b: float = 0.0
			var acc_a: float = 0.0
			for sy in range(SUPERSAMPLE):
				for sx in range(SUPERSAMPLE):
					var dx: float = float(px) + (float(sx) + 0.5) * step - origin.x
					var dy: float = float(py) + (float(sy) + 0.5) * step - origin.y
					var s: float = (dx * vy - dy * vx) / det
					var t: float = (ux * dy - uy * dx) / det
					if not (s >= 0.0 and s < 1.0 and t >= 0.0 and t < 1.0):
						continue
					var sample: Color = work.get_pixel(
						mini(src_w - 1, int(s * float(src_w))),
						mini(src_h - 1, int(t * float(src_h))))
					var alpha: float = sample.a
					acc_r += sample.r * alpha
					acc_g += sample.g * alpha
					acc_b += sample.b * alpha
					acc_a += alpha
			if acc_a <= 0.0:
				continue
			## Averaged premultiplied -> straight alpha, then source-over.
			var s_r: float = acc_r / acc_a
			var s_g: float = acc_g / acc_a
			var s_b: float = acc_b / acc_a
			var s_a: float = acc_a * sample_weight
			var backdrop: Color = dst.get_pixel(px, py)
			var b_a: float = backdrop.a
			var n_a: float = s_a + b_a * (1.0 - s_a)
			if n_a <= 0.0:
				continue
			var inv: float = b_a * (1.0 - s_a)
			dst.set_pixel(px, py, Color(
				(s_r * s_a + backdrop.r * inv) / n_a,
				(s_g * s_a + backdrop.g * inv) / n_a,
				(s_b * s_a + backdrop.b * inv) / n_a,
				n_a,
			))


## Pastes one decal onto every listed face of a COPY of `substrate`, then
## clamps the result to the substrate's own alpha — INVARIANT B3: silhouette
## alpha always comes from the canonical voxel texture, never from the decal.
## Direct port of generate_voxel.py's compose_decal_voxel(). `targets` is an
## Array of Dictionaries: {"origin": Vector2, "u_end": Vector2, "v_end":
## Vector2, "native": Vector2i} — the same four numbers as the Python tuple,
## named instead of positional so a Part 3 caller can't transpose two Vector2s
## silently.
static func compose_decal_voxel(substrate: Image, decal: Image, targets: Array) -> Image:
	var img: Image = substrate.duplicate()
	for target in targets:
		paste_decal(img, decal, target["origin"], target["u_end"], target["v_end"], target["native"])

	var w: int = substrate.get_width()
	var h: int = substrate.get_height()
	for y in range(h):
		for x in range(w):
			if is_zero_approx(substrate.get_pixel(x, y).a) and not is_zero_approx(img.get_pixel(x, y).a):
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return img
