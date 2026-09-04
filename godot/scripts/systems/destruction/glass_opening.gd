## GLASS CRACK-04 / G-D34 — THE FAMILY OF OPENINGS.
##
## (Director, 2026-09-04: *"Vamos usar formatos simples internos conhecidos, como
## os 4 sugeridos anteriormente, e outros para os buracos maiores. Criamos uma
## família de aberturas para serem escolhidas. Os decals se adaptam a esses
## formatos internos, podendo variar completamente do buraco para fora. Dessa
## forma já sabemos como construir o buraco sempre, independente de como vai ser
## o decal."*)
##
## ── WHAT AN OPENING IS ──────────────────────────────────────────────────────
##
## A closed polygon in the PANE's own (run, level) space, in VOXEL units, centred
## on the struck cell's CENTRE. Its interior is the hole. That single shape is
## the whole contract:
##
##   * a glass cell entirely inside it is ERASED;
##   * a cell the boundary CROSSES keeps only the glass outside the polygon —
##     the intrusion into that cell's border the Director asked for;
##   * a cell entirely outside is untouched;
##   * and the crack sheet's inner void is this same polygon, so the hole's total
##     shape and the decal's internal shape are equal by construction.
##
## ⚠️ THE OPENING IS THE AUTHORITY, NOT THE ART — AND THAT IS THE POINT OF THE
## FAMILY. The previous ruling (*"o decal é o dono da forma"*) was refined the
## same day for a concrete reason: if the shape lived in the sheet's pixels, the
## voxel side would have to RECOVER it (flood-fill the central black region,
## which is exactly what I was measuring when the Director stopped me), and the
## hole could not be built at all until that class's art existed. Measured on the
## two sheets that do exist: `fracture_glass_tight`'s void is **0.29 voxels**
## across and `fracture_glass_wide`'s is **2.02** — both well-defined, and both
## irrelevant, because a known family means *"já sabemos como construir o buraco
## sempre, independente de como vai ser o decal"*. The decal adapts to the
## opening; beyond the opening it is free to be anything.
##
## ⚠️ CHOSEN BY HASH, NEVER BY `randf()` — B4's rule, and G-D32's for the same
## reason one level up. The opening is re-picked whenever the geometry is rebuilt
## (a perspective flip, a load), so an RNG would reshape a standing hole every
## time the camera turned. The key must be BASE-space; `pick()` takes the key
## rather than building one, because the renderer has no base-space knowledge and
## the room does (`PerspectiveMapper.cell_to_base`).
class_name GlassOpening

const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")

## Coverage of one cell by an opening.
enum Coverage { NONE, PARTIAL, FULL }

## How finely `coverage()` samples a cell before calling it FULL or NONE.
##
## ⚠️ IT MUST DOMINATE THE RASTER, and 9 did not. `_cut_glass_opening()` decides
## per ATOM PIXEL — about 32 x 20 of them across a cell's face — so a spike
## narrower than the sampler's spacing is invisible here and perfectly visible
## there. `chunk_bite` has one: cell (3,1) read NONE and came back CUT, and the
## two disagreeing about the same cell is the whole failure mode, in either
## direction (a cell wrongly FULL would be ERASED, which no later pass can undo).
## 33 puts a sample on every atom pixel column and then some. Selftest [16] holds
## the two in agreement now, cell by cell, rather than trusting this number.
const COVERAGE_SAMPLES: int = 33

## `coverage()` is pure and its answer never changes for a given (opening, cell),
## so it is memoised — 33 x 33 point-in-polygon tests per cell over an 8x8
## footprint is 70k tests, and the walk asks for the same cells on every hole.
static var _coverage_cache: Dictionary = {}

## ── THE FAMILY ───────────────────────────────────────────────────────────────
##
## A member is written in one of two forms, and `polygon()` resolves both to the
## same thing — a closed polygon — so there is one shape language at RUNTIME and
## two conveniences at authoring time.
##
##   * REGULAR: `lobes` points at `r_out`, valleys at `r_in`, turned by `phase`.
##     An 8-point star is `lobes=8`, a V-notch is `lobes=4`, and a regular octagon
##     is `lobes=8` with `r_in = r_out · cos(π/8)`.
##   * IRREGULAR: `radii`, one per vertex, with optional `angles` in TURNS. This
##     exists because the regular form cannot express what the Director asked for
##     — *"um chunk grande faltando, angulos irregulares"* — at ANY parameter
##     value: it has exactly one point length and one valley length by
##     construction, so every arm is every other arm.
##
## `SMALL` is the four he already ruled on (`glass_rim_shape_options_2026-09-02`,
## A/B/C/D). `LARGE` is the room the same message asked for — *"os buracos de
## tiros maiores vão precisar de mais estados de voxels intermediários"* — and a
## larger opening gets those states for free, because more cells fall on the
## boundary the wider the polygon is.
##
## ⚠️ RADII ARE IN VOXELS FROM THE STRUCK CELL'S CENTRE, so a cell is 1.0 wide and
## its own corners are at 0.707. `r_out` over 0.5 intrudes on a neighbour, which
## is the whole mechanism.
##
## ⚠️ AND `r_in` MUST CLEAR 0.708 — THE STRUCK CELL'S OWN CORNERS. Found by
## selftest [15] on its first run, on three of the four small members: with a
## valley at 0.42 the polygon's boundary crosses the cell that was HIT, so the
## opening wants to keep that cell's four corners while destruction has already
## removed the whole voxel. The two models then disagree about the one cell they
## are both certain about, and the disagreement has no fix — a destroyed voxel
## cannot keep its corners. So an opening swallows the cell it is centred on,
## `coverage(id, 0, 0) == FULL`, and [16] asserts it for every member.
##
## The cost is real and it is paid in `r_out`, not in the look: pinning the valley
## at 0.75 collapsed `notch_v` into a rhombus and `star_shallow` into a blob,
## because a star's read is the RATIO of point to valley, not the point's reach.
## The small members' points were widened to restore it (measured on
## `glass_openings_family_2026-09-04.png`, before and after). The alternative —
## unioning the opening with the struck cell's square — was rejected because the
## square's corners would poke out past a low valley and put the rectangle back
## into the silhouette, which is the one thing this whole feature exists to
## remove.
const MIN_VALLEY: float = 0.708
const FAMILY: Dictionary = {
	## A — "bico fundo": the long-spiked star, the silhouette the build has been
	## making since CRACK-03.
	"star_deep":    {"lobes": 8, "r_out": 1.90, "r_in": 0.75, "phase": 0.0, "size": "small"},
	## B — "bico raso": the same star pulled in to half the reach.
	"star_shallow": {"lobes": 8, "r_out": 1.30, "r_in": 0.74, "phase": 0.0, "size": "small"},
	## C — "entalhe em V, cantos ficam": four points on the orthogonals only, so
	## the diagonal corners of the struck cell's neighbours are never reached.
	"notch_v":      {"lobes": 4, "r_out": 1.70, "r_in": 0.76, "phase": 0.0, "size": "small"},
	## D — "chanfro 45 graus": the compact one. `r_in = r_out · cos(π/8)` makes it
	## a regular octagon rather than a star.
	"chamfer_45":   {"lobes": 8, "r_out": 0.80, "r_in": 0.739, "phase": 0.3927, "size": "small"},

	## The large members. Same language, more reach — a rifle or a shotgun breach
	## is not a different mechanism, only a bigger polygon.
	"star_deep_wide":  {"lobes": 8, "r_out": 3.20, "r_in": 1.05, "phase": 0.0, "size": "large"},
	"star_ragged_wide": {"lobes": 11, "r_out": 2.80, "r_in": 1.20, "phase": 0.19, "size": "large"},
	"chamfer_45_wide": {"lobes": 8, "r_out": 2.10, "r_in": 1.94, "phase": 0.3927, "size": "large"},

	## ── THE IRREGULAR MEMBERS (Director, 2026-09-04: *"algumas mais esquisitas,
	## com um chunk grande faltando, angulos irregulares"*, on three references —
	## a real bullet impact and two shard renders). ──────────────────────────
	##
	## ⚠️ EVERY RADIUS STILL CLEARS `MIN_VALLEY`. An asymmetric opening is one
	## whose LARGE side is much larger, never one whose small side vanishes: the
	## struck voxel is gone whole either way, so a radius under 0.708 would ask
	## to keep a corner of it. [16] holds the line for these the same as the rest.
	##
	## `chunk_bite` — one big smooth chunk gone from a single quadrant, the rest a
	## tight ragged rim. The asymmetry IS the shape.
	##
	## ⚠️ THE READ COMES FROM THE JUMP BETWEEN ADJACENT RADII, NOT FROM THE RANGE.
	## The first pass at these two used 16 vertices easing smoothly from 4.2 down
	## to 1.0, a 4:1 range — and both rendered as ROUND BLOBS
	## (`glass_openings_family_2026-09-04.png`, first version). Every reference the
	## Director sent is made of long STRAIGHT fracture edges, and a straight edge
	## is what you get when two adjacent vertices are far apart in radius: the
	## chord between them cuts across. Fewer vertices, bigger jumps.
	"chunk_bite": {"size": "small", "phase": 0.55, "radii": [
		2.90, 3.10, 1.00, 0.85, 1.60, 0.80, 1.10, 0.78, 0.90, 2.20]},

	## `star_wild` — irregular in BOTH axes: spikes of unequal length at unequal
	## angles, so no two arms of the hole read as a pair.
	"star_wild": {"size": "small", "phase": 0.11, "radii": [
		2.10, 0.80, 1.30, 0.75, 2.60, 0.90, 1.00, 0.76, 1.70, 0.80, 2.30, 0.85],
		"angles": [
		0.00, 0.06, 0.13, 0.21, 0.27, 0.35, 0.44, 0.51, 0.60, 0.68, 0.79, 0.90]},

	## `shard_fan_wide` — the many-thin-spikes read of the third reference: a
	## dense fan of long slivers, each a different length.
	"shard_fan_wide": {"size": "large", "phase": 0.0, "radii": [
		3.40, 1.10, 2.60, 1.05, 3.90, 1.20, 2.20, 1.00, 3.10, 1.15,
		3.60, 1.05, 2.40, 1.10, 3.30, 1.00, 2.80, 1.20, 3.70, 1.10]},

	## `crescent_wide` — the first reference's silhouette: a huge chunk taken out
	## of one side with a long sweeping edge, the far side barely opened.
	"crescent_wide": {"size": "large", "phase": 0.30, "radii": [
		4.30, 3.90, 1.15, 1.00, 1.40, 1.05, 0.95, 1.20, 1.00, 1.60, 2.60, 3.90]},

	## `gash_wide` — the one shape class the other eleven did not have: ELONGATED.
	## Every other member is roughly radial, so a map of them reads as twelve sizes
	## of the same idea. This one runs long on one axis and stays tight on the
	## other, with the sides jagged rather than parallel — a pane that split along
	## a line rather than a round that punched through it.
	"gash_wide": {"size": "large", "phase": 0.08, "radii": [
		3.60, 1.50, 2.20, 0.90, 1.10, 0.85, 2.90,
		3.80, 1.30, 0.90, 1.00, 0.80, 1.90, 1.20]},
}

## The pools `pick()` draws from, by size class. Kept as explicit ordered arrays
## rather than filtered out of FAMILY at call time: the hash indexes into this
## list, so its ORDER is part of what makes a pick reproducible, and a Dictionary
## iteration order is not something to pin a saved hole's shape to.
const POOLS: Dictionary = {
	"small": ["star_deep", "star_shallow", "notch_v", "chamfer_45",
		"chunk_bite", "star_wild"],
	"large": ["star_deep_wide", "star_ragged_wide", "chamfer_45_wide",
		"shard_fan_wide", "crescent_wide", "gash_wide"],
}


## Every opening id, in a stable order — for the capture harness and the gates.
static func ids() -> Array:
	var out: Array = FAMILY.keys()
	out.sort()
	return out


## The pool for a size class, or an empty array if the class is unknown (a
## caller's typo must not silently fall back to a shape that happens to exist).
static func pool(size_class: String) -> Array:
	return POOLS.get(size_class, [])


## Pick one opening from a size class's pool. `base_key` must be derived from
## BASE coordinates — a view-space key is renumbered by a perspective flip and
## the hole would change shape every time the camera turned.
##
## ⚠️ B4: FNV-1a, the project's one hash, never `randf()`. Returns "" when the
## class is unknown, and the caller must treat that as the error it is rather
## than substituting a default.
static func pick(size_class: String, base_key: String) -> String:
	var p: Array = pool(size_class)
	if p.is_empty():
		push_error("[GlassOpening] unknown size class '%s' — no opening picked" % size_class)
		return ""
	return String(p[FacadeSamplerClass._fnv1a_hash("%s|%s" % [size_class, base_key]) % p.size()])


## The opening's boundary, as a closed polygon in voxels from the struck cell's
## centre. `+x` is run+, `+y` is level+.
static func polygon(id: String) -> PackedVector2Array:
	var spec: Dictionary = FAMILY.get(id, {})
	if spec.is_empty():
		push_error("[GlassOpening] unknown opening '%s'" % id)
		return PackedVector2Array()
	var phase: float = float(spec.get("phase", 0.0))
	var out := PackedVector2Array()

	## ── THE IRREGULAR FORM: an explicit polar vertex list. ──────────────────
	## `radii` is one radius per vertex, evenly spaced unless `angles` gives the
	## spacing too (in TURNS, 0..1, so the table reads as fractions of a circle
	## rather than as radians nobody can picture). This is what the regular
	## generator below structurally cannot produce — it has one `r_out` and one
	## `r_in`, so every point and every valley are the same, and a big chunk
	## missing from one side is not expressible at any parameter value.
	if spec.has("radii"):
		var radii: Array = spec["radii"]
		var angles: Array = spec.get("angles", [])
		for i in range(radii.size()):
			var frac: float = float(angles[i]) if i < angles.size() \
				else float(i) / float(radii.size())
			var ta: float = phase + TAU * frac
			var ra: float = float(radii[i])
			out.append(Vector2(cos(ta) * ra, sin(ta) * ra))
		return out

	## ── THE REGULAR FORM: the star shorthand. ───────────────────────────────
	## Kept because four of the members really are regular and writing them as
	## 16 explicit vertices would hide that, not reveal it.
	var lobes: int = int(spec["lobes"])
	var r_out: float = float(spec["r_out"])
	var r_in: float = float(spec["r_in"])
	## 2 vertices per lobe: the point, then the valley after it.
	for i in range(lobes * 2):
		var t: float = phase + TAU * float(i) / float(lobes * 2)
		var r: float = r_out if i % 2 == 0 else r_in
		out.append(Vector2(cos(t) * r, sin(t) * r))
	return out


## The bounding box of an opening, in whole cells, as (min_dr, min_dl, max_dr,
## max_dl) offsets from the struck cell. The walk that applies an opening covers
## exactly this and no more.
static func cell_bounds(id: String) -> Rect2i:
	var poly: PackedVector2Array = polygon(id)
	if poly.is_empty():
		return Rect2i()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	## A cell is centred on its integer offset and spans ±0.5, so a point at 1.5
	## touches cell 2 (which spans 1.5..2.5) only on its edge — `floor`/`ceil` of
	## (extent ± 0.5) is the exact set of cells the polygon can reach.
	var min_dr: int = int(floor(lo.x + 0.5))
	var min_dl: int = int(floor(lo.y + 0.5))
	var max_dr: int = int(ceil(hi.x - 0.5))
	var max_dl: int = int(ceil(hi.y - 0.5))
	return Rect2i(min_dr, min_dl, max_dr - min_dr + 1, max_dl - min_dl + 1)


## How much of the cell at integer offset (dr, dl) the opening covers.
##
## ⚠️ SAMPLED, NOT SOLVED. An exact polygon-vs-square clip would be the "right"
## answer and is not worth it: the consumer rasterises the cut at the atom's own
## resolution anyway, so an analytic area here would be more precise than the
## thing it feeds. What matters is that FULL is never returned for a cell the
## boundary merely crosses, which is why the grid is 9x9 and includes the corners.
static func coverage(id: String, dr: int, dl: int) -> Coverage:
	var ck := "%s|%d|%d" % [id, dr, dl]
	if _coverage_cache.has(ck):
		return _coverage_cache[ck]
	var poly: PackedVector2Array = polygon(id)
	if poly.is_empty():
		return Coverage.NONE
	var inside: int = 0
	var total: int = 0
	for iy in range(COVERAGE_SAMPLES):
		for ix in range(COVERAGE_SAMPLES):
			var p := Vector2(
				float(dr) - 0.5 + float(ix) / float(COVERAGE_SAMPLES - 1),
				float(dl) - 0.5 + float(iy) / float(COVERAGE_SAMPLES - 1))
			total += 1
			if Geometry2D.is_point_in_polygon(p, poly):
				inside += 1
	var result: Coverage = Coverage.PARTIAL
	if inside == 0:
		result = Coverage.NONE
	elif inside == total:
		result = Coverage.FULL
	_coverage_cache[ck] = result
	return result


## How finely an opening is rasterised for the SHEET's cut, in texels per voxel.
## The sheet is continuous and the hole's edge is the thing the eye lands on, so
## this is a look number, not a correctness one — but it must be fine enough that
## the sheet's void edge reads as the same line the voxel shards cut, and the
## voxel side works at roughly 32 x 20 atom pixels per voxel.
const MASK_TEXELS_PER_VOXEL: int = 24
## Slack around the polygon's own extent, in voxels, so the mask's border texels
## are outside the shape and `filter_linear` has something to fade into.
const MASK_PAD: float = 0.25


## Rasterise an opening into an R8 image: 1 INSIDE the hole, 0 outside.
##
## ⚠️ THIS IS THE SAME POLYGON THE VOXELS ARE CUT WITH, AND THAT IS THE ENTIRE
## POINT (Director, 2026-09-04: *"o que realmente importa é o shape total do
## buraco casar exatamente com o shape interno do decal"*). Twelve openings and
## two fracture sheets cannot be made equal by AUTHORING without twenty-four
## files that would then have to be re-made every time a member is added. Cutting
## the sheet at runtime from the opening makes the equality hold by construction
## instead — one shape, read by the atom cut and by the sprite shader.
##
## Returns { image, origin, size } with origin/size in VOXELS from the impact, the
## same space `glass_crack.gdshader` already works in for the occupancy.
static func mask_image(id: String) -> Dictionary:
	var poly: PackedVector2Array = polygon(id)
	if poly.is_empty():
		return {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	lo -= Vector2(MASK_PAD, MASK_PAD)
	hi += Vector2(MASK_PAD, MASK_PAD)
	var size: Vector2 = hi - lo
	var w: int = maxi(2, int(ceil(size.x * float(MASK_TEXELS_PER_VOXEL))))
	var h: int = maxi(2, int(ceil(size.y * float(MASK_TEXELS_PER_VOXEL))))
	var img := Image.create(w, h, false, Image.FORMAT_R8)
	for y in range(h):
		for x in range(w):
			## Texel centre -> voxels. `+y` here is the image's own DOWN; the
			## shader flips it back, the same way it does for the occupancy.
			var p := Vector2(
				lo.x + (float(x) + 0.5) / float(w) * size.x,
				hi.y - (float(y) + 0.5) / float(h) * size.y)
			img.set_pixel(x, y, Color(1.0, 0.0, 0.0) if Geometry2D.is_point_in_polygon(p, poly)
				else Color(0.0, 0.0, 0.0))
	return {"image": img, "origin": Vector2(lo.x, hi.y), "size": size}


## Distance from `p` to the opening's BOUNDARY, in voxels. Positive either side —
## the caller already knows which side it is on from `contains()`.
##
## Used to give a cut its FACET: the glass immediately outside the boundary is the
## fractured thickness of the pane and must read as a different plane, not as more
## of the same sheet.
static func distance_to_edge(poly: PackedVector2Array, p: Vector2) -> float:
	var best: float = INF
	var n: int = poly.size()
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var ab: Vector2 = b - a
		var len2: float = ab.length_squared()
		var t: float = 0.0 if len2 < 0.000001 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		best = minf(best, (p - (a + ab * t)).length())
	return best


## Is this point — in voxels from the struck cell's centre — inside the hole?
## The per-pixel test the atom cut runs.
static func contains(poly: PackedVector2Array, p: Vector2) -> bool:
	return not poly.is_empty() and Geometry2D.is_point_in_polygon(p, poly)
