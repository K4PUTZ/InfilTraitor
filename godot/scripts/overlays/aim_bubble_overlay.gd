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
## WHAT IS ACTUALLY DRAWN. A hemisphere of `radius_gu` GU sitting on the floor at
## `center`, which under this project's projection is the union of two
## screen-axis-aligned half-ellipses that share their horizontal semi-axis (see
## IsoProjection's header for why that is exact, not approximate):
##
##     upper half  -> IsoProjection.sphere_semi_axes()        (181.0, 183.8) per GU
##     lower half  -> IsoProjection.floor_circle_semi_axes()  (181.0,  90.5) per GU
##
## The full floor ellipse is drawn on top of the fill as its own disc: that is
## the section plane, and seeing it through the dome is what makes the shape read
## as a sphere cut by the ground rather than as a flat blob.
##
## WALL SECTIONING (§6.2, built 2026-08-11). Not the z_index depth trick
## FloatingCollectible uses — that only answers "in front of or behind," never
## "cut by, up to this height." Instead the dome grows a real lat/long
## wireframe: every grid vertex is cast in 3D from the dome's true centre and
## lands at min(sphere radius, distance to the nearest wall PLANE whose real
## height range actually covers that ray's hit point). A parapet only clips
## the low part of the grid; a wall over the dome's 2 GU apex clips nothing.
## The data is `room._wall_height_edges` — EdgeExtractor's own per-edge
## start_storey/storey_count (1 storey == 1 GU, GeometryCoords.LEVELS_PER_STOREY
## == VOXELS_PER_UNIT_AXIS == 8), retained by RoomBuilder specifically because
## nothing else needed real wall HEIGHT at runtime before this. Terrain that
## moves the floor itself (hills) is a separate, unbuilt system — this clamp
## already generalises to it (the ray's origin height just stops being 0), but
## nothing here invents that.

## Tuning — `var` per architecture Rule 1.
## Orange since 2026-08-10 ("vamos mudar a arte bolha de azul para laranja"),
## which also puts it in the same family as the shrapnel rays and the reference's
## own target volume instead of reading as a separate, cooler UI element.
var dome_color: Color = Color(1.0, 0.66, 0.30, 1.0)
var fill_alpha: float = 0.13          ## the dome's volume
var floor_fill_alpha: float = 0.20    ## the ground section, denser than the volume
var floor_line_alpha: float = 0.50    ## the section's own outline
var rim_alpha: float = 0.85           ## the sphere's silhouette
var line_width: float = 2.0
var arc_segments: int = 32            ## per half-ellipse

## Wall-sectioned lat/long grid (§6.2) — gives the fill actual volume.
var grid_alpha: float = 0.38
var grid_line_width: float = 1.2
var lat_ring_count: int = 3           ## strictly between the equator and the pole
var long_meridian_count: int = 8      ## evenly spaced around the vertical axis
var grid_meridian_steps: int = 12     ## samples per meridian, equator to pole
var grid_ring_steps: int = 32         ## samples per latitude ring, full turn
var wall_search_margin: float = 1.0   ## extra cells beyond radius_gu to search for walls

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


## Show the dome centred on a floor position, sized in GAME UNITS.
## `center_gu` is that same position as a GRID cell — the grid needs it to look
## up nearby walls in `wall_height_edges` (room._wall_height_edges; see the
## class header for its shape).
func show_dome(center: Vector2, radius_gu: float, center_gu: Vector2i,
		wall_height_edges: Dictionary) -> void:
	_center = center
	_radius_gu = radius_gu
	_center_gu = center_gu
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

	var sphere: Vector2 = IsoProjection.sphere_semi_axes(_radius_gu)
	var floor_axes: Vector2 = IsoProjection.floor_circle_semi_axes(_radius_gu)

	## Silhouette: over the top on the sphere ellipse, back under on the floor
	## ellipse. Both arcs end at (±semi_axes.x, 0), so the seam is exact.
	var outline := IsoProjection.ellipse_arc(_center, sphere, 0.0, PI, arc_segments)
	outline.append_array(
		IsoProjection.ellipse_arc(_center, floor_axes, PI, TAU, arc_segments))

	draw_colored_polygon(outline, _tinted(fill_alpha))

	## The section plane itself, drawn through the dome.
	var disc := IsoProjection.ellipse_arc(_center, floor_axes, 0.0, TAU, arc_segments * 2)
	draw_colored_polygon(disc, _tinted(floor_fill_alpha))
	draw_polyline(disc, _tinted(floor_line_alpha), line_width)

	## The lat/long grid, moulded around any wall it touches — over the fills,
	## under the rim so the silhouette stays the crispest line on screen.
	_draw_wall_grid(_nearby_wall_segments())

	## Rim last, so it sits over both fills. Closed by repeating the first point.
	var rim := outline
	rim.append(outline[0])
	draw_polyline(rim, _tinted(rim_alpha), line_width)


## Wall segments near the dome, in GU relative to `_center_gu`. Each is a
## straight line perpendicular to one grid axis — cell edges are exactly that,
## since GU cell CENTRES sit at integer offsets (IsoProjection's own
## convention) and a wall sits on the shared boundary half a GU either side.
## `axis_x` true means the wall separates two cells along X (so it runs along
## Y); false means the reverse. `span_min/span_max` bound the wall along the
## axis it runs on; `z_min/z_max` is its real height range in GU.
func _nearby_wall_segments() -> Array:
	var segments: Array = []
	if _wall_height_edges.is_empty():
		return segments
	var reach: int = int(ceil(_radius_gu + wall_search_margin))
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
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
				if delta.x == 1:
					segments.append({
						"axis_x": true, "pos": mid.x,
						"span_min": mid.y - 0.5, "span_max": mid.y + 0.5,
						"z_min": z_min, "z_max": z_max,
					})
				else:
					segments.append({
						"axis_x": false, "pos": mid.y,
						"span_min": mid.x - 0.5, "span_max": mid.x + 0.5,
						"z_min": z_min, "z_max": z_max,
					})
	return segments


## Distance along unit direction `dir` (GU, from the dome's true 3D centre —
## X/Y horizontal, Z up) to the nearest wall this specific ray actually hits;
## INF if none. A wall only counts if the ray crosses its span AND the hit
## point's height falls inside that wall's own [z_min, z_max) — this is what
## lets a parapet clip only the low part of the grid instead of the whole ray.
func _wall_hit_distance(dir: Vector3, segments: Array) -> float:
	var best: float = INF
	for seg: Dictionary in segments:
		var d_axis: float = dir.x if seg["axis_x"] else dir.y
		if absf(d_axis) < 0.0001:
			continue
		var t: float = seg["pos"] / d_axis
		if t <= 0.0 or t >= best:
			continue
		var along: float = (dir.y if seg["axis_x"] else dir.x) * t
		if along < seg["span_min"] or along > seg["span_max"]:
			continue
		var z_hit: float = dir.z * t
		if z_hit < seg["z_min"] or z_hit > seg["z_max"]:
			continue
		best = t
	return best


## One grid vertex: cast from the dome's centre at (theta, phi) — theta around
## the vertical axis, phi up from the equator — and stop at whichever is
## nearer, the sphere surface or a wall. Screen position, ready to draw.
func _grid_point(theta: float, phi: float, segments: Array) -> Vector2:
	var dir := Vector3(cos(phi) * cos(theta), cos(phi) * sin(theta), sin(phi))
	var t: float = minf(_radius_gu, _wall_hit_distance(dir, segments))
	return _center + IsoProjection.project_point(dir * t)


## The wireframe itself: `long_meridian_count` meridians from the equator to
## the pole, `lat_ring_count` full rings strictly between them. The equator
## itself is skipped — it is exactly the floor disc already drawn (both are
## the projection of the same flat GU circle) — and so is the pole, a single
## point every meridian already passes through.
func _draw_wall_grid(segments: Array) -> void:
	for m in range(long_meridian_count):
		var theta: float = TAU * float(m) / float(long_meridian_count)
		var pts := PackedVector2Array()
		for s in range(grid_meridian_steps + 1):
			var phi: float = (PI * 0.5) * float(s) / float(grid_meridian_steps)
			pts.append(_grid_point(theta, phi, segments))
		draw_polyline(pts, _tinted(grid_alpha), grid_line_width)

	for r in range(1, lat_ring_count + 1):
		var phi: float = (PI * 0.5) * float(r) / float(lat_ring_count + 1)
		var pts := PackedVector2Array()
		for s in range(grid_ring_steps + 1):
			var theta: float = TAU * float(s) / float(grid_ring_steps)
			pts.append(_grid_point(theta, phi, segments))
		draw_polyline(pts, _tinted(grid_alpha), grid_line_width)


func _tinted(alpha: float) -> Color:
	return Color(dome_color.r, dome_color.g, dome_color.b, alpha)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
