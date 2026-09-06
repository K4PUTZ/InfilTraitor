## GLASS G4-1 / G-D38 + G-D39 + G-D44 — THE SHARD SHAPE FAMILY.
##
## (Director, 2026-09-05: *"Precisamos de alguns voxels especiais, nos mesmos
## moldes que usamos para fazer as aberturas das balas, com formatos bem
## irregulares e angulosos"*, and *"os demais voxels também se transformam em uma
## multidão de partículas com formatos irregulares, que na verdade vão ser só umas
## 5 shapes"*.)
##
## ── ONE FAMILY, TWO CONSUMERS (G-D38) ────────────────────────────────────────
##
## Those two sentences describe the SAME five shapes, and saying so once is what
## keeps this cheap:
##
##   * `polygon(id)` — the free fragment, jagged all round. Rasterised into a
##     5-cell atlas, it is one instance of the falling rain's MultiMesh.
##   * `anchored_polygon(id, mask, flop)` — the same member rotated to face the
##     material it hangs from, pushed into that edge and CUT FLAT there. It cuts a
##     voxel atom's alpha, exactly as `GlassOpening` already cuts a bullet hole's
##     rim, and it is the remnant stuck in the frame.
##
## ⚠️ **THIS CANNOT BE `GlassOpening` WITH THE TEST INVERTED.** An opening's
## INTERIOR is removed; a fragment's interior is what is KEPT. Reusing those
## members the other way round gives remnants shaped like the NEGATIVE of a bullet
## hole — a ring, or a cell with a star-shaped bite out of it — which is the
## opposite of *"irregulares e angulosos"*. Same authoring language, different
## family, and the two never share a member.
##
## ⚠️ **THE ATTACH EDGE IS STRAIGHT, AND THAT IS PHYSICS, NOT A SHORTCUT.** A
## remnant is the glass that survived inside its own cell, and it meets the frame
## at the CELL BOUNDARY, which is a straight line. So `anchored_polygon()` clips
## at that plane: flat where it is held, jagged everywhere it broke.
##
## ⚠️ **G-D39 — ORIENTED BY THE ANCHOR, NEVER FREELY ROTATED.** The four-neighbour
## test in `GlassShatter.plan_pane_shatter()` has already decided which side is
## solid. A jagged fragment placed without regard to it floats in the middle of
## the opening with its solid corner facing away from the brick — the detail that
## would make the whole feature read as decoration rather than as physics.
##
## ── THE SIZE LAW (G-D44) ─────────────────────────────────────────────────────
##
## *"os cacos se subdividem todos em partes com tamanhos entre 1 e 1/2 voxel."*
## Every member is authored to fit inside one voxel, and an instance asks for a
## TARGET SIZE in `TARGET_MIN..TARGET_MAX` which `size_scale()` converts to that
## member's own multiplier — so the band is exact for every member rather than
## approximate for most. The member's own invariant is what
## `glass_shard_shapes_selftest` pins:
##
##   * `EXTENT_MAX` — never wider or taller than one voxel, either axis;
##   * `MAJOR_MIN` — and its long axis reaches at least half a voxel;
##   * `AREA_MAX` — never a filled cell. A member at area 1.0 IS the square this
##     whole feature exists to remove.
##   * `ASPECT_MAX` and `FILL_MIN` — and not degenerate: not a splinter, not a
##     spider. ⚠️ Two bounds, not one: see the constants' own note, where a single
##     absolute area floor rejected the family's one deliberately elongated member
##     and a single fill ratio then let a 10:1 needle straight through.
##   * `ANGULAR_JUMPS` — at least this many adjacent-vertex pairs whose radii
##     differ by `ANGULAR_RATIO`. ⚠️ **The angular read comes from the JUMP
##     between adjacent radii, not from the range of them** — a straight fracture
##     edge is the chord between two vertices at very different radii, and
##     `GlassOpening` paid for this lesson once already with sixteen smoothly-eased
##     vertices that rendered as round blobs.
##
## ⚠️ CHOSEN BY HASH, NEVER BY `randf()` — B4's rule. A remnant is re-picked
## whenever the geometry is rebuilt (a perspective flip, a load), so an RNG would
## reshape a standing fragment every time the camera turned. The rain does not
## need this for correctness (G-D43: it rests nowhere), but it keeps it anyway,
## because a `randf()` field cannot host a pixel gate and a hashed one can.
class_name GlassShardShapes

const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")

## ── THE INVARIANT, IN NUMBERS ────────────────────────────────────────────────
const EXTENT_MAX: float = 1.0      ## voxels, either axis — G-D44's upper bound
const MAJOR_MIN: float = 0.50      ## voxels — an authored member's LONG axis
const AREA_MAX: float = 0.58       ## voxels² — over this it starts to read as the cell
const ANGULAR_RATIO: float = 1.55  ## adjacent radii this far apart make a straight chord
const ANGULAR_JUMPS: int = 2       ## how many such pairs a member must have

## ⚠️ **"TOO SMALL" IS THREE DIFFERENT DEGENERACIES AND ONE NUMBER CANNOT HOLD
## THEM.** The first version of this gate was a single `AREA_MIN = 0.12`, and it
## rejected `sliver` on its first run at area 0.114 — a member that is not small
## at all: it measures 0.980 x 0.420, a full voxel on its long axis. An absolute
## area floor conflates "too small" with "ELONGATED", and `sliver` exists
## precisely so the family is not five radial blobs.
##
## The replacement was a FILL RATIO — and the control written for it immediately
## showed that one number cannot do this job either: a 1.0 x 0.1 rectangle, which
## is a needle by any reading, has fill 0.70, because a rectangle IS its own
## bounding box. So the two failure modes are separated and each is gated by the
## thing that actually measures it, each with its own control in [3]:
##
##   * `ASPECT_MAX` — a long thin splinter. `sliver` is 2.33:1; the needle is 10:1.
##   * `FILL_MIN` — a spidery star: plenty of bounding box, no body. A rectangle
##     passes this and a thin four-armed cross does not.
const ASPECT_MAX: float = 3.0      ## long axis / short axis
const FILL_MIN: float = 0.22       ## area / (bbox w * h) — under this it is a spider

## ── G-D44 IS MADE EXACT BY CONSTRUCTION, NOT APPROXIMATED ────────────────────
##
## *"partes com tamanhos entre 1 e 1/2 voxel"*. ⚠️ A single `scale in [0.5, 1.0]`
## applied to members of DIFFERENT authored sizes does not produce that band: with
## `chip` authored at 0.534 across, half of it is 0.267 — half the Director's lower
## bound, on the member nobody would look at twice. So the instance does not scale
## the member by a fraction of itself; it asks for a TARGET SIZE and
## `size_scale()` works out the multiplier. The band then holds for every member
## by construction, whatever the family grows into later.
static var TARGET_MIN: float = 0.5   ## voxels across the piece's long axis
static var TARGET_MAX: float = 1.0

## The size an anchored remnant is placed at, in the same units. It is inside the
## band and below the top of it on purpose: a member pushed flush at a full voxel
## would need clipping on the far side too, and a fragment clipped on three sides
## is a square again.
static var ANCHORED_TARGET: float = 0.84

## ⚠️ **HOW DEEP THE MEMBER IS PUSHED IS SOLVED, NOT AUTHORED.** The first version
## pushed a fixed 0.06 voxel past the edge, and the capture showed why that cannot
## work: whether that yields a broad contact or a nub depends entirely on which
## part of the member happens to face the anchor after the rotation, so half the
## placements read as fragments FLOATING near the brick rather than held by it.
## Authoring a "dense side" into every member would only move the problem — a
## member has four rotations and one dense side.
##
## So the push searches for the depth at which the cut is `ATTACH_MIN_CONTACT`
## long, and gives up at `ATTACH_MAX_LOSS` of the member's area, because a piece
## that has to be buried to be held is one the frame would not have kept.
static var ATTACH_MIN_CONTACT: float = 0.30   ## voxels of flat edge against the material
static var ATTACH_MAX_LOSS: float = 0.45      ## fraction of the free area the cut may take
static var ATTACH_STEPS: int = 24             ## resolution of the search

## ── THE ANCHOR BITS ──────────────────────────────────────────────────────────
##
## Keyed to `GlassShatter.plan_pane_shatter()`'s own neighbour list — (col, level)
## in the PANE's frame, never a compass direction, because a pane's run axis is X
## for SW/NE faces and Y for SE/NW ones and a compass name here would be wrong on
## half the map (DIRECTION_GLOSSARY: always qualify the axis explicitly).
const ANCHOR_RUN_POS: int = 1     ## the neighbour at (col + 1, level)
const ANCHOR_RUN_NEG: int = 2     ## (col - 1, level)
const ANCHOR_LEVEL_POS: int = 4   ## (col, level + 1)
const ANCHOR_LEVEL_NEG: int = 8   ## (col, level - 1)

## The outward unit vector of each bit, in the pane's (run, level) frame.
const ANCHOR_DIRS: Dictionary = {
	ANCHOR_RUN_POS: Vector2(1.0, 0.0),
	ANCHOR_RUN_NEG: Vector2(-1.0, 0.0),
	ANCHOR_LEVEL_POS: Vector2(0.0, 1.0),
	ANCHOR_LEVEL_NEG: Vector2(0.0, -1.0),
}

## ── THE FIVE MEMBERS ─────────────────────────────────────────────────────────
##
## Polar vertex lists, radii in VOXELS from the piece's own centre, angles in
## TURNS (0..1) so the table reads as fractions of a circle rather than as radians
## nobody can picture. `phase` turns the whole member.
##
## ⚠️ AUTHORED WITH THE DENSE SIDE TOWARD −x. `anchored_polygon()` rotates that
## side onto the anchor, so a member whose heavy mass sat on the free side would
## hang the wrong way round for every anchor at once — invisible in the free form,
## wrong in all four of the anchored ones.
##
## Five reads, deliberately not five variations of one:
const FAMILY: Dictionary = {
	## A — the classic fragment: one long point, a broad back.
	"wedge": {"phase": 0.06, "radii": [
		0.30, 0.24, 0.50, 0.20, 0.34, 0.19, 0.29]},

	## B — elongated. Every other member is roughly radial, so without this one a
	## map of them reads as four sizes of the same idea: a pane splits along a
	## LINE as often as it punches out a disc.
	##
	## ⚠️ THE FIRST VERSION OF THIS MEMBER WAS A FOUR-POINTED STAR, NOT A SPLINTER,
	## and every number passed. It had radii alternating 0.50 / 0.13 at EVENLY
	## SPACED angles, which is a sparkle — the shape had the elongation in its
	## radii and none in its outline, because two long points opposite each other
	## on a symmetric ring make a cross, not a shard. Elongation lives in the ANGLE
	## table: the long radii sit at 0.00 and 0.50 turns and everything between them
	## is short, so the outline itself runs long. Found by looking at the capture;
	## the gate had flagged it as the lowest fill ratio in the family and I read
	## that as "it is thin", which was the symptom and not the shape.
	## ⚠️ AND THE SECOND VERSION WAS A SMOOTH LENS. Ten vertices whose radii eased
	## from 0.50 down to 0.15 and back gave a convex almond — elongated, and with
	## nothing on its flanks that reads as a break. The elongation has to come from
	## the angle table AND the flanks have to zigzag, so the radii alternate along
	## them instead of easing.
	"sliver": {"phase": 0.0, "radii": [
		0.50, 0.19, 0.29, 0.15, 0.25, 0.14, 0.21, 0.38, 0.16, 0.27, 0.13, 0.23, 0.15, 0.30],
		"angles": [0.00, 0.06, 0.13, 0.20, 0.27, 0.34, 0.42,
			0.50, 0.57, 0.64, 0.71, 0.79, 0.86, 0.93]},

	## C — blocky: three broad faces with hard corners between them, the piece that
	## came away along two existing cracks. ⚠️ Its radii used to be 0.31 / 0.20,
	## a ratio of 1.55 — exactly ANGULAR_RATIO, so it counted as angular and read
	## as a rounded hexagon. `angular_jumps()` is a floor, not a target.
	"chip": {"phase": 0.19, "radii": [
		0.34, 0.15, 0.30, 0.17, 0.36, 0.14]},

	## D — asymmetric, with a concave bite out of one flank. The bite IS the shape.
	"hook": {"phase": 0.42, "radii": [
		0.47, 0.42, 0.14, 0.19, 0.44, 0.24, 0.36, 0.16, 0.30]},

	## E — one long straight edge against a jagged opposite side: the piece that
	## broke along an existing crack on one flank only.
	"blade": {"phase": 0.27, "radii": [
		0.49, 0.46, 0.17, 0.29, 0.15, 0.34, 0.18, 0.44],
		"angles": [0.00, 0.09, 0.28, 0.40, 0.52, 0.66, 0.80, 0.91]},
}

## The stable order. ⚠️ It is the ATLAS CELL INDEX and it is what `pick()` hashes
## into, so this array's ORDER is part of what makes a pick reproducible — a
## Dictionary iteration order is not something to pin a standing remnant's shape
## to. Appending is safe; reordering is not.
const IDS: Array = ["wedge", "sliver", "chip", "hook", "blade"]

## ⚠️ CAPTURE-ONLY OVERRIDE, the same convention `GlassOpening.FORCE` uses:
## `INFILTRAITOR_GLASS_SHARD=<id>` forces every piece to one member so the family
## can be photographed on the real map one shape at a time. Never on the play path.
static var FORCE: String = OS.get_environment("INFILTRAITOR_GLASS_SHARD")


## Every member id, in the atlas order.
static func ids() -> Array:
	return IDS.duplicate()


## The atlas cell a member occupies, or -1 for an unknown id — which the caller
## must treat as the error it is rather than substituting cell 0.
static func index_of(id: String) -> int:
	return IDS.find(id)


## Which member this piece is. `base_key` must be BASE-space for anything that
## survives a rebuild (a remnant); the rain may key on whatever it likes, since it
## rests nowhere.
static func pick(base_key: String) -> String:
	if FORCE != "" and FAMILY.has(FORCE):
		return FORCE
	return String(IDS[FacadeSamplerClass._fnv1a_hash("SHARD|%s" % base_key) % IDS.size()])


## The free fragment, closed, in voxels from its own centre. `+x` is run+, `+y` is
## level+ — the same frame `GlassOpening.polygon()` works in.
static func polygon(id: String) -> PackedVector2Array:
	var spec: Dictionary = FAMILY.get(id, {})
	if spec.is_empty():
		push_error("[GlassShardShapes] unknown shard shape '%s'" % id)
		return PackedVector2Array()
	var phase: float = float(spec.get("phase", 0.0))
	var radii: Array = spec["radii"]
	var angles: Array = spec.get("angles", [])
	var out := PackedVector2Array()
	for i in range(radii.size()):
		var frac: float = float(angles[i]) if i < angles.size() \
			else float(i) / float(radii.size())
		var ta: float = TAU * (phase + frac)
		var ra: float = float(radii[i])
		out.append(Vector2(cos(ta) * ra, sin(ta) * ra))
	return out


## The member's long axis, in voxels, as authored.
static func major_extent(id: String) -> float:
	var e: Vector2 = extent(polygon(id))
	return maxf(e.x, e.y)


## The multiplier that makes this member's long axis exactly `target_major`
## voxels. This is what G-D44's band is applied through — never a fraction of the
## member's own authored size, which would give each member a different band.
static func size_scale(id: String, target_major: float) -> float:
	var m: float = major_extent(id)
	if m <= 0.0001:
		push_error("[GlassShardShapes] '%s' has no extent — cannot size it" % id)
		return 1.0
	return target_major / m


## The free fragment at a given size, in voxels across its long axis.
static func polygon_sized(id: String, target_major: float) -> PackedVector2Array:
	var k: float = size_scale(id, target_major)
	var out := PackedVector2Array()
	for p in polygon(id):
		out.append(p * k)
	return out


## G-D39 — the member as it hangs from the frame.
##
## `anchor_mask` is the OR of the ANCHOR_* bits for every orthogonal neighbour
## that holds non-glass, i.e. exactly what the survival test in
## `GlassShatter.plan_pane_shatter()` already computed. `flop` mirrors the member
## across the attach axis, which doubles the vocabulary for nothing.
##
## The result is in voxels from the CELL's centre and never leaves the cell:
## sized to ANCHORED_TARGET, pushed until it overhangs the anchored edge, then cut
## flat at that edge — once per set bit, so a fragment in the CORNER of a frame is
## cut on both of its edges rather than on a 45° plane through the corner, which
## is what an L-shaped frame actually does to it.
##
## An empty mask returns an empty polygon on purpose: a remnant with no anchor is
## not something this file should invent a placement for, it is a caller bug.
static func anchored_polygon(id: String, anchor_mask: int, flop: bool = false,
		target_major: float = -1.0) -> PackedVector2Array:
	var size: float = ANCHORED_TARGET if target_major <= 0.0 else target_major
	var free: PackedVector2Array = polygon_sized(id, size)
	if free.is_empty():
		return free
	var dirs: Array = anchor_dirs(anchor_mask)
	if dirs.is_empty():
		push_error("[GlassShardShapes] anchored_polygon('%s') with an empty anchor mask — a remnant with no anchor has no placement" % id)
		return PackedVector2Array()

	var axis: Vector2 = Vector2.ZERO
	for dv in dirs:
		axis += dv
	axis = axis.normalized()

	var out := PackedVector2Array()
	for p in free:
		var q: Vector2 = p
		if flop:
			## Mirror across the attach axis: the component along it is kept, the
			## one across it is negated.
			var along: float = q.dot(axis)
			q = axis * along - (q - axis * along)
		out.append(q)

	## Push and cut, once per anchored edge, deep enough to be genuinely held.
	for dv in dirs:
		out = _push_and_cut(out, dv)
		if out.is_empty():
			return out

	## ⚠️ **RECENTRE THE FREE AXIS, OR THE FRAGMENT LEAVES ITS OWN CELL.** Pushing
	## flush fixes the piece on the ANCHORED axis only; on the other one it is
	## still sitting wherever the polar construction left it, and a member's
	## bounding box is not symmetric about its own origin (the radii differ, that
	## is the whole point of the family). Measured on the first run: 5 of the 20
	## single-anchor placements had a vertex past the cell edge — `wedge/run+`,
	## `chip/level+`, `chip/level-`, `blade/run+`, `blade/run-`.
	##
	## Where along the edge the fragment hangs is a free parameter, so centring it
	## is not a compromise — it is the only answer that does not need a second
	## clip, and a fragment clipped on three sides is a square again.
	var free_axes := Vector2(1.0, 1.0)
	for dv in dirs:
		var dd: Vector2 = dv
		if absf(dd.x) > 0.5:
			free_axes.x = 0.0
		if absf(dd.y) > 0.5:
			free_axes.y = 0.0
	if free_axes != Vector2.ZERO:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in out:
			lo = lo.min(p)
			hi = hi.max(p)
		var mid: Vector2 = (lo + hi) * 0.5
		var shift2 := Vector2(-mid.x * free_axes.x, -mid.y * free_axes.y)
		var centred := PackedVector2Array()
		for p in out:
			centred.append(p + shift2)
		out = centred
	return out


## Push `poly` along `d` until the plane at 0.5 cuts a chord of at least
## ATTACH_MIN_CONTACT, then return the cut polygon.
##
## Monotone enough to walk rather than bisect: pushing deeper never shortens the
## chord for these members, and a linear walk reports the FIRST depth that works
## instead of the deepest one that also would — a fragment should be held, not
## buried. Falls back to the deepest depth inside ATTACH_MAX_LOSS when no depth
## reaches the target, which is a member too pointed at this rotation to hang
## broadly; that is a real answer, not a failure.
static func _push_and_cut(poly: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var free_area: float = area(poly)
	var far: float = -INF
	var near: float = INF
	for p in poly:
		far = maxf(far, p.dot(d))
		near = minf(near, p.dot(d))
	var span: float = far - near
	var best: PackedVector2Array = PackedVector2Array()
	for step in range(1, ATTACH_STEPS + 1):
		var depth: float = span * ATTACH_MAX_LOSS * float(step) / float(ATTACH_STEPS)
		var shift: float = (0.5 + depth) - far
		var moved := PackedVector2Array()
		for p in poly:
			moved.append(p + d * shift)
		var cut: PackedVector2Array = _clip_half_plane(moved, d, 0.5)
		if cut.size() < 3:
			continue
		if area(cut) < free_area * (1.0 - ATTACH_MAX_LOSS):
			break
		best = cut
		if contact_length(cut, d) >= ATTACH_MIN_CONTACT:
			return cut
	return best


## How long the flat edge against `d`'s plane is, in voxels — the measure of how
## broadly the fragment is held. Zero means it only touches at a point.
static func contact_length(poly: PackedVector2Array, d: Vector2) -> float:
	var perp := Vector2(-d.y, d.x)
	var lo: float = INF
	var hi: float = -INF
	for p in poly:
		if absf(p.dot(d) - 0.5) <= 0.0005:
			lo = minf(lo, p.dot(perp))
			hi = maxf(hi, p.dot(perp))
	return 0.0 if lo == INF else hi - lo


## Every anchored edge's outward unit vector, in the bit order of ANCHOR_DIRS.
static func anchor_dirs(anchor_mask: int) -> Array:
	var out: Array = []
	for bit in [ANCHOR_RUN_POS, ANCHOR_RUN_NEG, ANCHOR_LEVEL_POS, ANCHOR_LEVEL_NEG]:
		if (anchor_mask & bit) != 0:
			out.append(ANCHOR_DIRS[bit])
	return out


## Sutherland-Hodgman against one half-plane: keep `dot(p, n) <= d`.
static func _clip_half_plane(poly: PackedVector2Array, n: Vector2, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count: int = poly.size()
	if count < 3:
		return out
	for i in range(count):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		var da: float = a.dot(n) - d
		var db: float = b.dot(n) - d
		if da <= 0.0:
			out.append(a)
		if (da > 0.0) != (db > 0.0):
			var t: float = da / (da - db)
			out.append(a + (b - a) * t)
	return out


## Signed area's magnitude, in voxels². The gate's own instrument.
static func area(poly: PackedVector2Array) -> float:
	var n: int = poly.size()
	if n < 3:
		return 0.0
	var acc: float = 0.0
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		acc += a.x * b.y - b.x * a.y
	return absf(acc) * 0.5


## Width and height of the member's bounding box, in voxels.
static func extent(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	return hi - lo


## How many adjacent-vertex pairs jump by at least `ANGULAR_RATIO` in radius —
## the measure of how many STRAIGHT fracture edges the member reads as having.
static func angular_jumps(id: String) -> int:
	var spec: Dictionary = FAMILY.get(id, {})
	if spec.is_empty():
		return 0
	var radii: Array = spec["radii"]
	var n: int = radii.size()
	var jumps: int = 0
	for i in range(n):
		var a: float = float(radii[i])
		var b: float = float(radii[(i + 1) % n])
		var hi: float = maxf(a, b)
		var lo: float = minf(a, b)
		if lo > 0.0001 and hi / lo >= ANGULAR_RATIO:
			jumps += 1
	return jumps


## Is this point — in voxels from the piece's own centre — inside the fragment?
static func contains(poly: PackedVector2Array, p: Vector2) -> bool:
	return not poly.is_empty() and Geometry2D.is_point_in_polygon(p, poly)


## ── G6b-1 — THE ATLAS ────────────────────────────────────────────────────────
##
## The five members rasterised side by side into ONE texture, so the falling rain
## is a single `MultiMesh` with a single draw call and the shape is chosen per
## instance by custom data rather than by which of five nodes it lives in.
##
## White with alpha, deliberately: the glass TINT is the instance colour, so one
## atlas serves every glass material in the family — a `glass_screen_green` pane
## rains green shards off these same five cells.
##
## ⚠️ `ATLAS_MARGIN` IS NOT DECORATION. Cells are laid out edge to edge in U, and
## `filter_linear` on a shard drawn a few pixels tall samples ACROSS the boundary:
## without a margin, member 2 bleeds a fringe of member 3 into every instance at
## small scale, which is exactly the size the rain is drawn at. The shape is fitted
## to `1 - 2 * ATLAS_MARGIN` of the cell so the border texels are always empty.
##
## ⚠️ SUPERSAMPLED. A hard point-in-polygon test at 64 px gives a stair-stepped
## silhouette that reads as noise once it is scaled down to 10-20 px, and the whole
## point of authoring angular members is that their EDGES are the shape.
const ATLAS_CELL_PX: int = 64
const ATLAS_MARGIN: float = 0.10
const ATLAS_SUPERSAMPLE: int = 3


## A polygon translated so its BOUNDING BOX is centred on the origin. Also what
## the rain wants: an instance's transform origin should be the piece's visual
## centre, or a spinning shard orbits a point that is not in it.
static func centred(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.is_empty():
		return poly
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var mid: Vector2 = (lo + hi) * 0.5
	var out := PackedVector2Array()
	for p in poly:
		out.append(p - mid)
	return out


## Build the atlas. `Image`, RGBA8, `ids().size()` cells wide by one cell tall;
## cell `i` holds `IDS[i]`, which is what makes `index_of()` the custom-data value.
static func atlas_image(cell_px: int = ATLAS_CELL_PX) -> Image:
	var n: int = IDS.size()
	var img := Image.create(cell_px * n, cell_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
	var fit: float = 1.0 - 2.0 * ATLAS_MARGIN
	var ss: int = maxi(ATLAS_SUPERSAMPLE, 1)
	var samples: float = float(ss * ss)
	for i in range(n):
		## Sized so the member's LONG axis spans `fit` of the cell — the same
		## normalisation `size_scale()` applies everywhere else, so a cell's ink is
		## proportional to the member's shape and never to its authored size.
		## ⚠️ CENTRED ON ITS BOUNDING BOX, NOT ON THE POLAR ORIGIN. A member's box is
		## not symmetric about that origin — the radii differ, which is the whole
		## point of the family — so sizing alone leaves the shape offset and it
		## pokes past the margin on whichever side is longer. Measured on the first
		## run of this atlas: 84 texels in the borders. The same recentre
		## `anchored_polygon()` applies to its free axis, and for the same reason.
		var poly: PackedVector2Array = centred(polygon_sized(String(IDS[i]), fit))
		if poly.size() < 3:
			continue
		var ox: int = i * cell_px
		for y in range(cell_px):
			for x in range(cell_px):
				var hits: int = 0
				for sy in range(ss):
					for sx in range(ss):
						var p := Vector2(
							(float(x) + (float(sx) + 0.5) / float(ss)) / float(cell_px) - 0.5,
							0.5 - (float(y) + (float(sy) + 0.5) / float(ss)) / float(cell_px))
						if Geometry2D.is_point_in_polygon(p, poly):
							hits += 1
				if hits > 0:
					img.set_pixel(ox + x, y, Color(1.0, 1.0, 1.0, float(hits) / samples))
	return img
