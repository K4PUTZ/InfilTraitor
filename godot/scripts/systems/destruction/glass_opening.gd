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

## How finely `coverage()` samples a cell before calling it FULL or NONE. A cell
## is 1 voxel and an opening's features are tenths of one, so a coarse grid would
## report FULL for a cell a spike merely crosses — and a cell wrongly called FULL
## is ERASED, which is not recoverable by a later pass.
const COVERAGE_SAMPLES: int = 9

## ── THE FAMILY ───────────────────────────────────────────────────────────────
##
## Every member is a star: `lobes` points at `r_out`, the valleys between them at
## `r_in`, turned by `phase`. That one generator covers everything the Director
## approved — an 8-point star is `lobes=8`, a V-notch is `lobes=4`, and a regular
## octagon is `lobes=8` with `r_in = r_out · cos(π/8)`, which is why the family
## needs no second shape language.
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
}

## The pools `pick()` draws from, by size class. Kept as explicit ordered arrays
## rather than filtered out of FAMILY at call time: the hash indexes into this
## list, so its ORDER is part of what makes a pick reproducible, and a Dictionary
## iteration order is not something to pin a saved hole's shape to.
const POOLS: Dictionary = {
	"small": ["star_deep", "star_shallow", "notch_v", "chamfer_45"],
	"large": ["star_deep_wide", "star_ragged_wide", "chamfer_45_wide"],
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
	var lobes: int = int(spec["lobes"])
	var r_out: float = float(spec["r_out"])
	var r_in: float = float(spec["r_in"])
	var phase: float = float(spec["phase"])
	var out := PackedVector2Array()
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
	if inside == 0:
		return Coverage.NONE
	if inside == total:
		return Coverage.FULL
	return Coverage.PARTIAL


## Is this point — in voxels from the struck cell's centre — inside the hole?
## The per-pixel test the atom cut runs.
static func contains(poly: PackedVector2Array, p: Vector2) -> bool:
	return not poly.is_empty() and Geometry2D.is_point_in_polygon(p, poly)
