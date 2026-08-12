extends Node2D
class_name AimBubbleOverlay

## AimBubbleOverlay / E-BUBBLE — the grenade blast dome shown while aiming.
##
## Director, 2026-08-10, on the first version: "A bolha azul está gigante, tem
## que ser bem menor, cobrindo uma área de 3x3 GU aproximadamente. (...) Queremos
## mostrar apenas a bolha translúcida como um domo, uma esfera seccionada pelo
## chão (e paredes próximas), como em XCOM (ver a referência grenade.webp)."
## Reference: `REFERENCES/granade.webp`.
##
## So this is deliberately NOT the predicted damage footprint. The real blast
## silhouette has holes in it — cells shadowed by walls, cells that survive their
## tier roll — and the Director ruled that out explicitly: the dome reads as
## "this is the shape of the explosion", clean, and the per-cell truth is carried
## by ShrapnelPreviewOverlay's rays instead. Keeping the two jobs in two overlays
## is what lets the dome stay a simple analytic shape.
##
## WHAT IS ACTUALLY DRAWN: a hemisphere of `radius_gu` GU sitting on the floor at
## `center`, SECTIONED by the floor and by every nearby wall, plus — on the face
## of each of those walls — the patch the sphere actually covers, carrying its
## own grid.
##
## ============================================================================
## WALL SECTIONING (§6.2) — built 2026-08-12, after one rejected attempt.
##
## The first attempt (`48cf3b4`, reverted in `097be5a`) moulded only the lat/long
## GRID around the walls and left `outline`/`disc` as the full undistorted
## ellipses. Director on seeing it: "a distorção não é assim... vai ser uma coisa
## mais angulosa". Re-reading that commit says exactly why, and it is worth
## keeping because the mechanism was never the problem: the SILHOUETTE stayed a
## perfect round ellipse (byte-identical between `grenade_wall_grid_molded.png`
## and the plain build) while the interior lines squashed against the wall — so
## the bubble read as a round balloon with a dented interior, which is the mushy
## look, not a sectioned volume.
##
## Director's specification for this version (2026-08-12, with a diagram):
## "a bolha precisa ser seccionada pelas paredes, e não apenas distorcer o grid
## interno como foi feito. Vamos aumentar o número de linhas e engrossar todas
## elas, incluindo as bordas externas, pra ficar mais evidente onde está a bolha.
## Em vez de distorcer o grid da bolha, na realidade vamos ter um grid interno em
## volta das paredes, nas áreas em que estiverem dentro da bolha."
##
## Three consequences, and each is a different piece of code below:
##
##   1. The silhouette itself is cut       -> `_sectioned_outline()`
##   2. The sphere's own grid is NOT bent, only HIDDEN where a wall stops it
##                                         -> `_draw_sphere_grid()`
##   3. Each wall face inside the sphere gets its own grid, in the WALL's axes
##                                         -> `_draw_wall_patches()`
##
## THE DATA. `room._wall_height_edges` — EdgeExtractor's own per-edge
## `start_storey`/`storey_count`, retained by RoomBuilder and keyed by
## `WallEdgeData.edge_key()` (architecture Rule 3). 1 storey == 1 GU, since
## `GeometryCoords.LEVELS_PER_STOREY == VOXELS_PER_UNIT_AXIS == 8`. Per-edge
## height is not a nicety: "vamos ter parapeitos, morros e outros cenários com
## paredes mais baixas. Precisamos calcular por edge e por slice" (Director,
## 2026-08-11) — a parapet must cut only the low part of the dome and let it
## bulge over the top, which a uniform full-height plane cannot express.
##
## WHY A RADIAL SILHOUETTE AND NOT A CONVEX HULL, since the hull is the obvious
## reach and it is WRONG here. `sphere ∩ half-spaces` would be convex, and a hull
## of sampled surface points would be exact — but a wall is a FINITE rectangle
## (its span, and its own height range), so a parapet leaves a region that is not
## convex at all: the dome bulges back out over the top of it, and a hull would
## fill that notch straight in. What the region IS, always, is STAR-SHAPED about
## the dome's centre — every ray from the centre stops once, at the sphere or at
## the first wall it hits. A linear projection maps each of those rays to a
## segment from the projected centre, so the projected region is star-shaped too,
## and its boundary at a given screen angle is simply the farthest surface sample
## pointing that way. That is `_sectioned_outline()`, and it costs one polygon
## with no overlapping fills — which matters, because the dome is translucent and
## a triangle fan would double-darken every seam.
## ============================================================================

## Tuning — `var` per architecture Rule 1.
## Orange since 2026-08-10 ("vamos mudar a arte bolha de azul para laranja"),
## which also puts it in the same family as the shrapnel rays and the reference's
## own target volume instead of reading as a separate, cooler UI element.
var dome_color: Color = Color(1.0, 0.66, 0.30, 1.0)
var fill_alpha: float = 0.13          ## the dome's volume
var floor_fill_alpha: float = 0.20    ## the ground section, denser than the volume
var floor_line_alpha: float = 0.55    ## the section's own outline
var rim_alpha: float = 0.90           ## the sphere's silhouette
var line_width: float = 3.5           ## "engrossar todas elas, incluindo as bordas externas"

## Lat/long grid — gives the fill a sense of real volume. Counts and width both
## raised on the Director's 2026-08-12 note ("aumentar o número de linhas e
## engrossar todas elas"); the grid is what says where the bubble IS, so it is
## deliberately no longer a faint hint.
var grid_alpha: float = 0.45
var grid_line_width: float = 2.4
var lat_ring_count: int = 5           ## strictly between the equator and the pole
var long_meridian_count: int = 12     ## evenly spaced around the vertical axis
var grid_meridian_steps: int = 16     ## samples per meridian, equator to pole
var grid_ring_steps: int = 48         ## samples per latitude ring, full turn

## The patch each wall face wears where the sphere covers it. Denser than the
## dome's own volume on purpose: it is a surface, not a translucent depth, and
## the Director's diagram draws it as the solid, hatched part of the figure.
var wall_fill_alpha: float = 0.24
var wall_line_alpha: float = 0.85
var wall_grid_alpha: float = 0.60
## Spacing of the wall patch's own grid, in GU, along BOTH of the wall's axes.
## 0.25 GU is 2 voxels — dense enough to read as a surface grid at a 2 GU dome
## without turning into a solid block.
var wall_grid_step_gu: float = 0.25

## Extra cells beyond `radius_gu` to scan for wall edges. One is enough: an edge
## is looked up by the cell PAIR it separates, so the far cell of a boundary
## exactly `radius_gu` out still has to be inside the scan.
var wall_search_margin: float = 1.0

## Silhouette sampling. `silhouette_angles` is how many points the rim polygon
## ends up with; `silhouette_ellipse_steps` walks the sphere's exact silhouette
## great circle; the (theta, phi) lattice is only the filler underneath (see
## `_sectioned_outline()`), so it is deliberately coarse.
##
## THE TWO EXACT CURVES ARE SAMPLED FOUR TIMES DENSER THAN THE BUCKETS, and that
## ratio is the fix for a real defect rather than padding. Measured 2026-08-12 by
## dumping the radial function: at 96 floor samples into 180 buckets, the EVEN
## buckets held a perfect symmetric ground ellipse (…217, 207, 198, 191, 185,
## 182, 181, 182, 185…) and the odd ones held whatever scrap the coarse lattice
## had left there, or nothing at all — 19 of 180 buckets came out empty. That is
## the comb along the floor and the sawtooth down the cut: not aliasing between
## surfaces, just a curve too coarse to reach every bucket. A curve must
## out-sample the buckets it feeds.
var silhouette_angles: int = 180
var silhouette_ellipse_steps: int = 720
var silhouette_phi_steps: int = 6
var floor_ring_steps: int = 720       ## the ground section's own polygon
## How far apart, in SCREEN pixels, a cut curve is sampled for the silhouette
## sweep. Per-pixel and not a fixed count per edge, because clipping produces
## edges of wildly different lengths — a rectangle corner a few pixels long and
## a wall's whole top edge in the same polygon — and it is the long ones that
## have to out-sample the buckets.
var patch_edge_sample_px: float = 4.0

## How far past a wall's edge, in GU, the shadow curve is probed. Small enough
## to sit on the edge visually, large enough that the ray genuinely clears the
## wall instead of landing on the knife-edge where "grazing" and "blocked" are
## the same floating-point comparison.
var edge_shadow_nudge_gu: float = 0.01
var patch_arc_steps: int = 48         ## the sphere-cut arc bounding a wall patch

## How many points a wall patch's grid line is checked at before it is drawn.
## Occlusion can begin mid-line — one wall shadowing part of another's patch —
## so a line is a run of visible samples rather than one visibility decision.
var patch_visibility_samples: int = 12

## Flat wall-segment record: `SEG_STRIDE` floats per wall, packed instead of an
## Array of Dictionaries because `_wall_hit_distance()` runs over all of it once
## per silhouette sample — `silhouette_angles * (silhouette_phi_steps + 1)` rays
## per redraw — and a Dictionary field lookup per wall per ray would dominate
## that loop. Same reasoning (and the same shape) as LightRayOverlay's pre-packed
## rays; nothing here is clever, it is just not re-hashing a string 100 000 times
## to move a cursor one cell.
const SEG_STRIDE: int = 6
const SEG_AXIS_X: int = 0       ## 1.0 when the wall separates two cells along X
const SEG_POS: int = 1          ## the wall plane's offset from the dome centre, GU
const SEG_SPAN_MIN: int = 2     ## bounds along the axis the wall RUNS on, GU
const SEG_SPAN_MAX: int = 3
const SEG_Z_MIN: int = 4        ## the wall's real height range, GU above the floor
const SEG_Z_MAX: int = 5

var _center: Vector2 = Vector2.ZERO
var _center_gu: Vector2i = Vector2i.ZERO
var _radius_gu: float = 0.0
var _wall_height_edges: Dictionary = {}
var _visible: bool = false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat
	visible = false


## Show the dome centred on a floor position, sized in GAME UNITS. `center_gu` is
## the same position as a grid cell — the walls are looked up by cell pair, so
## the screen position alone cannot find them — and `wall_height_edges` is
## `room._wall_height_edges`, passed in rather than reached for so this overlay
## keeps knowing nothing about Room.
func show_dome(center: Vector2, radius_gu: float, center_gu: Vector2i,
		wall_height_edges: Dictionary) -> void:
	_center = center
	_center_gu = center_gu
	_radius_gu = radius_gu
	_wall_height_edges = wall_height_edges
	_visible = true
	visible = true
	queue_redraw()


## Move the dome without changing its size (cursor follow).
func update_position(center: Vector2, center_gu: Vector2i) -> void:
	_center = center
	_center_gu = center_gu
	queue_redraw()


func _draw() -> void:
	if not _visible or _radius_gu < 0.001:
		return

	var segments: PackedFloat32Array = _nearby_wall_segments()

	## The section plane, computed first because it is also the dome's own
	## boundary all along the bottom — the silhouette below consumes it rather
	## than casting the same ring of rays a second time.
	var disc: PackedVector2Array = _floor_section(segments)

	## The dome's volume, cut by the floor and by every wall that reaches it.
	var outline: PackedVector2Array = _sectioned_outline(segments, disc)
	if outline.size() < 3:
		return
	draw_colored_polygon(outline, _tinted(fill_alpha))

	if disc.size() >= 3:
		draw_colored_polygon(disc, _tinted(floor_fill_alpha))
		draw_polyline(_closed(disc), _tinted(floor_line_alpha), line_width)

	## The sphere's own grid: undistorted, and simply absent where a wall stops
	## it. Over the fills, under the rim so the silhouette stays the crispest
	## line on screen.
	_draw_sphere_grid(segments)

	## What the walls themselves wear, drawn last of the fills so it sits on top
	## of the volume it replaced.
	_draw_wall_patches(segments)

	draw_polyline(_closed(outline), _tinted(rim_alpha), line_width)


## Wall segments near the dome, in GU relative to `_center_gu`, packed flat (see
## SEG_STRIDE). Each is a straight vertical plane perpendicular to one grid axis
## — cell edges are exactly that, since GU cell CENTRES sit at integer offsets
## (IsoProjection's own convention) and a wall sits on the shared boundary half a
## GU either side.
func _nearby_wall_segments() -> PackedFloat32Array:
	var raw: Array = []
	if _wall_height_edges.is_empty():
		return PackedFloat32Array()
	var reach: int = int(ceil(_radius_gu + wall_search_margin))
	for dx: int in range(-reach, reach + 1):
		for dy: int in range(-reach, reach + 1):
			var cell_a: Vector2i = _center_gu + Vector2i(dx, dy)
			for delta: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var cell_b: Vector2i = cell_a + delta
				var key: String = WallEdgeData.edge_key(cell_a, cell_b)
				if not _wall_height_edges.has(key):
					continue
				var info: Dictionary = _wall_height_edges[key]
				var mid: Vector2 = Vector2(cell_a - _center_gu) + Vector2(delta) * 0.5
				var z_min: float = float(info["start_storey"])
				var z_max: float = z_min + float(info["storey_count"])
				var axis_x: bool = delta.x == 1
				var pos: float = mid.x if axis_x else mid.y
				var along: float = mid.y if axis_x else mid.x
				## A wall entirely outside the sphere can never cut it, and
				## dropping it here is what keeps the ray loop short.
				if absf(pos) >= _radius_gu or z_min >= _radius_gu:
					continue
				raw.append([axis_x, pos, along - 0.5, along + 0.5, z_min, z_max])
	return _merge_collinear(raw)


## Fuses cell-edges that are really one wall into one segment.
##
## NOT an optimization, though it is also that. `EdgeExtractor` works per cell
## PAIR, so a plain 7 GU wall arrives as seven 1 GU edges sharing a plane and a
## height — measured on PLAYGROUND next to the test-zone wall row, which is
## exactly seven. The ray cast could not care less (a union of touching spans
## answers the same question), but `_draw_wall_patches()` draws one outline per
## segment, so unfused edges put six full-weight seam strokes across the middle
## of what is one flat surface, and the patch reads as a row of tiles instead of
## a wall. Merging first is what makes it one shape with one border.
static func _merge_collinear(raw: Array) -> PackedFloat32Array:
	var merged := PackedFloat32Array()
	if raw.is_empty():
		return merged
	## Same plane and same height range first, then ordered along the span, so a
	## run of touching edges lands contiguously and one linear pass fuses it.
	raw.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return not bool(a[0])
		if not is_equal_approx(a[1], b[1]):
			return float(a[1]) < float(b[1])
		if not is_equal_approx(a[4], b[4]):
			return float(a[4]) < float(b[4])
		if not is_equal_approx(a[5], b[5]):
			return float(a[5]) < float(b[5])
		return float(a[2]) < float(b[2]))

	var current: Array = raw[0].duplicate()
	for i: int in range(1, raw.size()):
		var next: Array = raw[i]
		var same_plane: bool = bool(next[0]) == bool(current[0]) \
			and is_equal_approx(float(next[1]), float(current[1])) \
			and is_equal_approx(float(next[4]), float(current[4])) \
			and is_equal_approx(float(next[5]), float(current[5]))
		if same_plane and float(next[2]) <= float(current[3]) + 0.001:
			current[3] = maxf(float(current[3]), float(next[3]))
			continue
		_append_segment(merged, current)
		current = next.duplicate()
	_append_segment(merged, current)
	return merged


static func _append_segment(into: PackedFloat32Array, seg: Array) -> void:
	into.append(1.0 if bool(seg[0]) else 0.0)
	into.append(float(seg[1]))
	into.append(float(seg[2]))
	into.append(float(seg[3]))
	into.append(float(seg[4]))
	into.append(float(seg[5]))


## Distance along unit direction `dir` (GU, from the dome's true 3D centre —
## X/Y horizontal, Z up) to the nearest wall this specific ray actually hits;
## INF if none. A wall only counts if the ray crosses its span AND the hit
## point's height falls inside that wall's own [z_min, z_max] — this is what
## lets a parapet clip only the low part of the dome instead of the whole ray.
func _wall_hit_distance(dir: Vector3, segments: PackedFloat32Array) -> float:
	var best: float = INF
	var i: int = 0
	while i < segments.size():
		var axis_x: bool = segments[i + SEG_AXIS_X] > 0.5
		var d_axis: float = dir.x if axis_x else dir.y
		if absf(d_axis) >= 0.0001:
			var t: float = segments[i + SEG_POS] / d_axis
			if t > 0.0 and t < best:
				var along: float = (dir.y if axis_x else dir.x) * t
				if along >= segments[i + SEG_SPAN_MIN] and along <= segments[i + SEG_SPAN_MAX]:
					var z_hit: float = dir.z * t
					if z_hit >= segments[i + SEG_Z_MIN] and z_hit <= segments[i + SEG_Z_MAX]:
						best = t
		i += SEG_STRIDE
	return best


## Unit direction for (theta, phi) — theta around the vertical axis, phi up from
## the equator. The one place the dome's spherical convention is written down.
static func _direction(theta: float, phi: float) -> Vector3:
	return Vector3(cos(phi) * cos(theta), cos(phi) * sin(theta), sin(phi))


## Where the dome's surface really is along one direction: the sphere, or the
## first wall in the way, whichever comes first.
func _surface_offset(dir: Vector3, segments: PackedFloat32Array) -> Vector2:
	return IsoProjection.project_point(
		dir * minf(_radius_gu, _wall_hit_distance(dir, segments)))


## The dome's screen silhouette once the walls have cut it.
##
## See the header for why this is a radial sweep and not a convex hull: the
## boundary at a given screen angle is the farthest surface point pointing that
## way, and buckets are only how the winner per angle is found. Each winner is
## kept at the angle it was actually found at, never at its bucket's centre, so
## the buckets never quantize the result.
##
## WHAT IS FED IN, AND WHY IT IS NOT JUST A LATTICE. The first version sampled a
## plain (theta, phi) grid and aliased badly — a hard sawtooth down the cut and a
## comb along the floor (`z_rim` isolation capture, 2026-08-12, fill and rim only,
## every grid disabled). The cause is that (theta, phi) maps to screen angle very
## unevenly, so near a cut one bucket would catch a far sphere sample and its
## neighbour only a near wall sample, and the boundary oscillated between the two
## surfaces. Denser sampling only makes that rarer, never correct.
##
## The fix is to sample the curves the true boundary is actually MADE of, so
## every bucket sees the real extreme instead of a lattice approximation:
##
##   · the sphere's silhouette great circle (IsoProjection.silhouette_basis()),
##     kept only where no wall has taken it away;
##   · each wall patch's own boundary — that IS the cut curve;
##   · the floor section, which is the boundary all along the bottom.
##
## The lattice stays underneath as a filler for anything those three miss; it is
## no longer load-bearing, which is why it can be coarse.
func _sectioned_outline(segments: PackedFloat32Array,
		floor_section: PackedVector2Array) -> PackedVector2Array:
	var best_r := PackedFloat32Array()
	var best_a := PackedFloat32Array()
	best_r.resize(silhouette_angles)
	best_a.resize(silhouette_angles)
	best_r.fill(0.0)
	best_a.fill(0.0)

	var basis: Array[Vector3] = IsoProjection.silhouette_basis()
	for i: int in range(silhouette_ellipse_steps):
		var u: float = TAU * float(i) / float(silhouette_ellipse_steps)
		var point: Vector3 = (basis[0] * cos(u) + basis[1] * sin(u)) * _radius_gu
		## The lower half of that great circle is under the floor, and this is a
		## hemisphere — the floor section owns the boundary down there.
		if point.z >= 0.0 and _is_visible(point, segments):
			_offer(best_r, best_a, IsoProjection.project_point(point))

	var i_seg: int = 0
	while i_seg < segments.size():
		_offer_patch_curves(best_r, best_a, segments,
			segments[i_seg + SEG_AXIS_X] > 0.5, segments[i_seg + SEG_POS],
			segments[i_seg + SEG_SPAN_MIN], segments[i_seg + SEG_SPAN_MAX],
			maxf(segments[i_seg + SEG_Z_MIN], 0.0), segments[i_seg + SEG_Z_MAX])
		i_seg += SEG_STRIDE

	for point: Vector2 in floor_section:
		_offer(best_r, best_a, point - _center)

	for i: int in range(silhouette_angles):
		var theta: float = TAU * float(i) / float(silhouette_angles)
		for j: int in range(1, silhouette_phi_steps + 1):
			var phi: float = (PI * 0.5) * float(j) / float(silhouette_phi_steps)
			_offer(best_r, best_a, _surface_offset(_direction(theta, phi), segments))

	var points := PackedVector2Array()
	for bucket: int in range(silhouette_angles):
		if best_r[bucket] <= 0.0001:
			continue
		points.append(_center + Vector2(cos(best_a[bucket]), sin(best_a[bucket])) * best_r[bucket])
	return points


## One wall's contribution to the silhouette sweep: its cut curve, and the
## SHADOW of its own edges.
##
## The cut curve is walked ALONG its edges, never vertex by vertex — clipping
## leaves the patch with a handful of corners that can span 70+ degrees of screen
## angle, far too coarse for 2-degree buckets. Sampling is per PIXEL rather than
## a fixed count per edge, because the same polygon holds a few-pixel corner and
## a wall's entire top edge.
##
## THE SHADOW CURVES ARE THE THIRD FAMILY, and leaving them out is what kept the
## profile oscillating over a wall the dome can clear (measured on a 3 GU dome
## against the 2 GU stone block: nine jumps over 60 px between buckets 138 and
## 179, all in the arc above the block). Where a ray grazes the wall's top edge
## and carries on to the sphere, the farthest visible point is neither on the
## sphere's own silhouette great circle nor on the cut — it is on the curve the
## edge casts onto the sphere, which is just the edge normalised out to the
## radius. Only the edges the dome can actually get PAST generate one: the top,
## and the two ends. Not the floor edge, since nothing goes under the floor, and
## not the disc arc, which is already at full radius.
func _offer_patch_curves(best_r: PackedFloat32Array, best_a: PackedFloat32Array,
		segments: PackedFloat32Array, axis_x: bool, pos: float,
		u_min: float, u_max: float, v_min: float, v_max: float) -> void:
	var boundary: PackedVector2Array = _patch_boundary_uv(pos, u_min, u_max, v_min, v_max)
	for i: int in range(boundary.size()):
		var from_uv: Vector2 = boundary[i]
		var to_uv: Vector2 = boundary[(i + 1) % boundary.size()]
		var outward: Vector2 = _edge_outward(from_uv, to_uv, u_min, u_max, v_max)
		var steps: int = clampi(int(ceil(
			IsoProjection.project_point(_wall_point(axis_x, pos, from_uv)).distance_to(
				IsoProjection.project_point(_wall_point(axis_x, pos, to_uv)))
			/ patch_edge_sample_px)), 1, 256)
		for s: int in range(steps):
			var uv: Vector2 = from_uv.lerp(to_uv, float(s) / float(steps))
			var point: Vector3 = _wall_point(axis_x, pos, uv)
			if _is_visible(point, segments):
				_offer(best_r, best_a, IsoProjection.project_point(point))
			if outward == Vector2.ZERO:
				continue
			var past: Vector3 = _wall_point(axis_x, pos, uv + outward * edge_shadow_nudge_gu)
			var direction: Vector3 = past.normalized()
			if _wall_hit_distance(direction, segments) >= _radius_gu - 0.001:
				_offer(best_r, best_a, IsoProjection.project_point(direction * _radius_gu))


## Which way is "off the wall" for one edge of a patch, in that wall's own
## (u, v) coordinates — ZERO when the edge is the sphere's own cut arc or the
## floor, neither of which the dome can reach past. Written as literal vectors
## rather than Vector2.UP/DOWN: v is HEIGHT here, so Godot's screen-space names
## would read backwards at exactly the line where it matters.
static func _edge_outward(from_uv: Vector2, to_uv: Vector2,
		u_min: float, u_max: float, v_max: float) -> Vector2:
	if is_equal_approx(from_uv.x, u_min) and is_equal_approx(to_uv.x, u_min):
		return Vector2(-1.0, 0.0)
	if is_equal_approx(from_uv.x, u_max) and is_equal_approx(to_uv.x, u_max):
		return Vector2(1.0, 0.0)
	if is_equal_approx(from_uv.y, v_max) and is_equal_approx(to_uv.y, v_max):
		return Vector2(0.0, 1.0)
	return Vector2.ZERO


## Offers one surface point (as a screen offset from the dome's centre) to the
## radial sweep, keeping it only if it reaches farther than whatever already
## claimed its angle.
func _offer(best_r: PackedFloat32Array, best_a: PackedFloat32Array,
		offset: Vector2) -> void:
	var radius: float = offset.length()
	if radius <= 0.0001:
		return
	var angle: float = fposmod(atan2(offset.y, offset.x), TAU)
	var bucket: int = int(angle / TAU * float(silhouette_angles)) % silhouette_angles
	if radius > best_r[bucket]:
		best_r[bucket] = radius
		best_a[bucket] = angle


## One wall patch's boundary, in that wall's own (u, v) surface coordinates —
## the cut curve the dome's silhouette follows wherever the wall took a bite out
## of it. Shared by the silhouette sweep and by the patch drawing, so the two can
## never disagree about where the cut is. Empty when this wall reaches nothing.
func _patch_boundary_uv(pos: float, u_min: float, u_max: float,
		v_min: float, v_max: float) -> PackedVector2Array:
	var cut_radius: float = _cut_radius(pos)
	if cut_radius <= 0.001 or v_min >= v_max or u_min >= u_max or v_min >= cut_radius:
		return PackedVector2Array()
	return _clip_to_rect(_disc_boundary(cut_radius), u_min, u_max, v_min, v_max)


## Radius of the disc a wall plane `pos` GU from the centre cuts out of the
## sphere — plain Pythagoras, and the number every patch is sized by.
func _cut_radius(pos: float) -> float:
	return sqrt(maxf(_radius_gu * _radius_gu - pos * pos, 0.0))


## The ground section, sectioned by the same walls. Simpler than the silhouette
## above and deliberately not sharing its machinery: this one lives entirely in
## the z = 0 plane, where the projection is a plain linear map of that plane, so
## sweeping theta already produces the boundary in screen-angle order — there is
## nothing for a bucket to resolve.
func _floor_section(segments: PackedFloat32Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in range(floor_ring_steps):
		var theta: float = TAU * float(i) / float(floor_ring_steps)
		points.append(_center + _surface_offset(_direction(theta, 0.0), segments))
	return points


## The wireframe itself: `long_meridian_count` meridians from the equator to
## the pole, `lat_ring_count` full rings strictly between them. The equator
## itself is skipped — it is exactly the floor section already drawn — and so is
## the pole, a single point every meridian already passes through.
##
## NOT MOULDED. A vertex whose ray hits a wall before the sphere is simply not
## part of the dome any more, so the polyline BREAKS there and picks up again on
## the far side; it never slides down the wall's face. That is the whole
## correction the Director asked for ("em vez de distorcer o grid da bolha"),
## and the grid that does follow a wall is `_draw_wall_patches()`, in the wall's
## own axes rather than in the sphere's.
func _draw_sphere_grid(segments: PackedFloat32Array) -> void:
	for m: int in range(long_meridian_count):
		var theta: float = TAU * float(m) / float(long_meridian_count)
		var meridian := PackedVector2Array()
		for s: int in range(grid_meridian_steps + 1):
			var phi: float = (PI * 0.5) * float(s) / float(grid_meridian_steps)
			meridian = _extend_or_flush(meridian, _direction(theta, phi), segments)
		_flush_grid_run(meridian)

	for r: int in range(1, lat_ring_count + 1):
		var phi_ring: float = (PI * 0.5) * float(r) / float(lat_ring_count + 1)
		var ring := PackedVector2Array()
		for s: int in range(grid_ring_steps + 1):
			var theta_ring: float = TAU * float(s) / float(grid_ring_steps)
			ring = _extend_or_flush(ring, _direction(theta_ring, phi_ring), segments)
		_flush_grid_run(ring)


## Adds one grid vertex to the run in progress, or ends that run when a wall
## blocks the direction. Returns the run to keep building — empty after a break,
## which is what makes the grid vanish behind a wall instead of bending onto it.
func _extend_or_flush(run: PackedVector2Array, dir: Vector3,
		segments: PackedFloat32Array) -> PackedVector2Array:
	if _wall_hit_distance(dir, segments) < _radius_gu:
		_flush_grid_run(run)
		return PackedVector2Array()
	run.append(_center + IsoProjection.project_point(dir * _radius_gu))
	return run


func _flush_grid_run(run: PackedVector2Array) -> void:
	if run.size() >= 2:
		draw_polyline(run, _tinted(grid_alpha), grid_line_width)


## Every wall face the sphere reaches, wearing the patch the sphere covers it
## with, plus that patch's own grid.
##
## THE GEOMETRY, because it is exact rather than sampled. A wall is the plane
## `x = p` (or `y = p`) at distance |p| from the dome's centre. A sphere of
## radius R cut by that plane leaves a DISC of radius sqrt(R² − p²) centred on
## the foot of the perpendicular — so the patch is that disc, clipped to the
## wall's own rectangle: its span along the axis it runs on, and its real height
## range from `EdgeExtractor`. Working in the wall's own (u, v) coordinates —
## u along the span, v up — makes both the disc and the rectangle trivial, and
## the projection back to the screen is one linear map away.
## ONLY THE FACES THE DOME CAN ACTUALLY SEE, which is not a refinement — it is
## the difference between this being right and being nonsense. Measured on
## PLAYGROUND with the dome one cell in front of the 3-block stone group: the
## scan returns FOUR walls, because a solid block is a box and every one of its
## faces is a real edge. Only the near one is visible; the other three (the
## block's far face and its two end caps) are entirely behind it. This overlay
## draws above the voxels, so without this test all three would paint bright
## orange grid onto the back of a solid block, straight through it.
##
## The test is exact and reuses the ray cast the sectioning already needs: a
## point on a wall is on the dome's surface exactly when nothing else stops that
## ray first. It is applied per SAMPLE, not per wall, so a patch that is only
## partly shadowed keeps the part that is real.
func _draw_wall_patches(segments: PackedFloat32Array) -> void:
	var i: int = 0
	while i < segments.size():
		_draw_one_wall_patch(
			segments[i + SEG_AXIS_X] > 0.5, segments[i + SEG_POS],
			segments[i + SEG_SPAN_MIN], segments[i + SEG_SPAN_MAX],
			maxf(segments[i + SEG_Z_MIN], 0.0), segments[i + SEG_Z_MAX], segments)
		i += SEG_STRIDE


func _draw_one_wall_patch(axis_x: bool, pos: float, u_min: float, u_max: float,
		v_min: float, v_max: float, segments: PackedFloat32Array) -> void:
	var boundary: PackedVector2Array = _patch_boundary_uv(pos, u_min, u_max, v_min, v_max)
	if boundary.size() < 3:
		return

	var visible: int = 0
	var screen := PackedVector2Array()
	for uv: Vector2 in boundary:
		var point: Vector3 = _wall_point(axis_x, pos, uv)
		if _is_visible(point, segments):
			visible += 1
		screen.append(_center + IsoProjection.project_point(point))
	if visible == 0:
		return
	## The fill is one flat polygon and cannot be broken up the way a line can,
	## so it is drawn only when the whole patch is real. A partly shadowed patch
	## keeps its grid and its outline and loses the tint — legible, and never a
	## fill claiming ground it does not have.
	if visible == boundary.size():
		draw_colored_polygon(screen, _tinted(wall_fill_alpha))

	_draw_wall_patch_grid(axis_x, pos, _cut_radius(pos), u_min, u_max, v_min, v_max, segments)

	var ring: PackedVector2Array = boundary
	ring.append(boundary[0])
	_draw_patch_polyline(axis_x, pos, ring, segments, _tinted(wall_line_alpha), line_width)


## Is this point on the dome's real surface, or is there a nearer wall in the
## way? Exact: `_wall_hit_distance()` already answers "where does this ray stop",
## and a point stops the ray exactly when it is the nearest thing along it.
func _is_visible(point_gu: Vector3, segments: PackedFloat32Array) -> bool:
	var distance: float = point_gu.length()
	if distance <= 0.0001:
		return true
	return _wall_hit_distance(point_gu / distance, segments) >= distance - 0.001


## Draws a path given in one wall's (u, v) surface coordinates, broken wherever
## another wall shadows it. The projection is linear, so a straight run of
## samples stays exactly straight on screen — sampling costs visibility
## resolution, never shape.
func _draw_patch_polyline(axis_x: bool, pos: float, uv_points: PackedVector2Array,
		segments: PackedFloat32Array, color: Color, width: float) -> void:
	var run := PackedVector2Array()
	for uv: Vector2 in uv_points:
		var point: Vector3 = _wall_point(axis_x, pos, uv)
		if not _is_visible(point, segments):
			if run.size() >= 2:
				draw_polyline(run, color, width)
			run = PackedVector2Array()
			continue
		run.append(_center + IsoProjection.project_point(point))
	if run.size() >= 2:
		draw_polyline(run, color, width)


## A point on the wall plane, from that wall's own (u, v) surface coordinates
## back into the dome's 3D GU frame. `axis_x` means the wall separates two cells
## along X, so it RUNS along Y — u is a Y offset and the plane is x = pos.
static func _wall_point(axis_x: bool, pos: float, uv: Vector2) -> Vector3:
	return Vector3(pos, uv.x, uv.y) if axis_x else Vector3(uv.x, pos, uv.y)


## The sphere's cut, as a closed polygon in the wall's (u, v) coordinates.
func _disc_boundary(cut_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in range(patch_arc_steps):
		var a: float = TAU * float(i) / float(patch_arc_steps)
		points.append(Vector2(cos(a), sin(a)) * cut_radius)
	return points


## Sutherland–Hodgman against the wall's four edges. The subject is convex (a
## disc) and so is the window, so the result is a single convex ring — no
## degenerate cases to handle beyond an empty one, which the callers check.
static func _clip_to_rect(poly: PackedVector2Array, u_min: float, u_max: float,
		v_min: float, v_max: float) -> PackedVector2Array:
	var result: PackedVector2Array = poly
	## [axis, sign, limit]: sign +1 keeps `coord <= limit`, −1 keeps `coord >= limit`.
	for edge: Array in [[0, -1.0, u_min], [0, 1.0, u_max], [1, -1.0, v_min], [1, 1.0, v_max]]:
		result = _clip_to_half_plane(result, int(edge[0]), float(edge[1]), float(edge[2]))
		if result.is_empty():
			return result
	return result


static func _clip_to_half_plane(poly: PackedVector2Array, axis: int, sign: float,
		limit: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count: int = poly.size()
	for i: int in range(count):
		var current: Vector2 = poly[i]
		var previous: Vector2 = poly[(i + count - 1) % count]
		var d_current: float = sign * ((current.x if axis == 0 else current.y) - limit)
		var d_previous: float = sign * ((previous.x if axis == 0 else previous.y) - limit)
		if d_current <= 0.0:
			if d_previous > 0.0:
				out.append(previous.lerp(current, d_previous / (d_previous - d_current)))
			out.append(current)
		elif d_previous <= 0.0:
			out.append(previous.lerp(current, d_previous / (d_previous - d_current)))
	return out


## The patch's own grid — "um grid interno em volta das paredes". Lines run
## along the wall's two axes, not along the sphere's, which is what makes the
## patch read as something lying ON the wall rather than as more of the bubble.
##
## Each line is solved analytically against the same disc that bounds the patch
## (a chord of half-length sqrt(r² − offset²)) and then clamped to the wall's
## rectangle, so no line can escape the fill it belongs to.
func _draw_wall_patch_grid(axis_x: bool, pos: float, cut_radius: float,
		u_min: float, u_max: float, v_min: float, v_max: float,
		segments: PackedFloat32Array) -> void:
	var step: float = maxf(wall_grid_step_gu, 0.01)
	var color: Color = _tinted(wall_grid_alpha)

	var v: float = ceil(maxf(v_min, -cut_radius) / step) * step
	while v <= minf(v_max, cut_radius):
		var half_u: float = sqrt(maxf(cut_radius * cut_radius - v * v, 0.0))
		_draw_patch_line(axis_x, pos, maxf(-half_u, u_min), minf(half_u, u_max),
			v, true, color, segments)
		v += step

	var u: float = ceil(maxf(u_min, -cut_radius) / step) * step
	while u <= minf(u_max, cut_radius):
		var half_v: float = sqrt(maxf(cut_radius * cut_radius - u * u, 0.0))
		_draw_patch_line(axis_x, pos, maxf(-half_v, v_min), minf(half_v, v_max),
			u, false, color, segments)
		u += step


## One grid line on a wall patch. `along_u` true sweeps u at a fixed v, false
## sweeps v at a fixed u; `from`/`to` are that sweep's own bounds.
func _draw_patch_line(axis_x: bool, pos: float, from: float, to: float,
		fixed: float, along_u: bool, color: Color,
		segments: PackedFloat32Array) -> void:
	if to - from <= 0.001:
		return
	var samples := PackedVector2Array()
	for i: int in range(patch_visibility_samples + 1):
		var t: float = lerpf(from, to, float(i) / float(patch_visibility_samples))
		samples.append(Vector2(t, fixed) if along_u else Vector2(fixed, t))
	_draw_patch_polyline(axis_x, pos, samples, segments, color, grid_line_width)


## `draw_polyline` does not close a ring on its own — every filled shape here is
## a closed polygon, so its outline repeats the first point.
static func _closed(polygon: PackedVector2Array) -> PackedVector2Array:
	var ring: PackedVector2Array = polygon
	ring.append(polygon[0])
	return ring


func _tinted(alpha: float) -> Color:
	return Color(dome_color.r, dome_color.g, dome_color.b, alpha)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
