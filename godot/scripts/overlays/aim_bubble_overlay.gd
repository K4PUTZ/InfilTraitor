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
## LAT/LONG GRID (§6.2, built 2026-08-11) — a plain UV-sphere wireframe over
## the fill, giving it a sense of real volume instead of a flat silhouette.
##
## PAUSED, NOT DROPPED: the first version also moulded the grid around nearby
## walls (each vertex cast as a real 3D ray, stopping at a wall plane instead
## of the sphere surface when the wall's real height covered the hit point).
## Director, 2026-08-11, on seeing it: "a distorção não é assim... vai ser uma
## coisa mais angulosa" — the curved ray-clamp is the wrong shape and the
## request needs refining before it's rebuilt. Removed here down to the plain
## grid; the wall-height DATA it read (`room._wall_height_edges` —
## EdgeExtractor's per-edge start_storey/storey_count, 1 storey == 1 GU,
## GeometryCoords.LEVELS_PER_STOREY == VOXELS_PER_UNIT_AXIS == 8) stays
## retained by RoomBuilder regardless, since nothing else needed real wall
## HEIGHT at runtime before this and re-deriving it later would be pure waste.

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

## Lat/long grid (§6.2) — gives the fill a sense of real volume.
var grid_alpha: float = 0.38
var grid_line_width: float = 1.8
var lat_ring_count: int = 3           ## strictly between the equator and the pole
var long_meridian_count: int = 8      ## evenly spaced around the vertical axis
var grid_meridian_steps: int = 12     ## samples per meridian, equator to pole
var grid_ring_steps: int = 32         ## samples per latitude ring, full turn

var _center: Vector2 = Vector2.ZERO
var _radius_gu: float = 0.0
var _visible: bool = false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat
	visible = false


## Show the dome centred on a floor position, sized in GAME UNITS.
func show_dome(center: Vector2, radius_gu: float) -> void:
	_center = center
	_radius_gu = radius_gu
	_visible = true
	visible = true
	queue_redraw()


## Move the dome without changing its size (cursor follow).
func update_position(center: Vector2) -> void:
	_center = center
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

	## The lat/long grid, over the fills, under the rim so the silhouette
	## stays the crispest line on screen.
	_draw_grid()

	## Rim last, so it sits over both fills. Closed by repeating the first point.
	var rim := outline
	rim.append(outline[0])
	draw_polyline(rim, _tinted(rim_alpha), line_width)


## One grid vertex, plain sphere surface: cast from the dome's centre at
## (theta, phi) — theta around the vertical axis, phi up from the equator —
## at the full radius. Screen position, ready to draw.
func _grid_point(theta: float, phi: float) -> Vector2:
	var dir := Vector3(cos(phi) * cos(theta), cos(phi) * sin(theta), sin(phi))
	return _center + IsoProjection.project_point(dir * _radius_gu)


## The wireframe itself: `long_meridian_count` meridians from the equator to
## the pole, `lat_ring_count` full rings strictly between them. The equator
## itself is skipped — it is exactly the floor disc already drawn (both are
## the projection of the same flat GU circle) — and so is the pole, a single
## point every meridian already passes through.
func _draw_grid() -> void:
	for m in range(long_meridian_count):
		var theta: float = TAU * float(m) / float(long_meridian_count)
		var pts := PackedVector2Array()
		for s in range(grid_meridian_steps + 1):
			var phi: float = (PI * 0.5) * float(s) / float(grid_meridian_steps)
			pts.append(_grid_point(theta, phi))
		draw_polyline(pts, _tinted(grid_alpha), grid_line_width)

	for r in range(1, lat_ring_count + 1):
		var phi: float = (PI * 0.5) * float(r) / float(lat_ring_count + 1)
		var pts := PackedVector2Array()
		for s in range(grid_ring_steps + 1):
			var theta: float = TAU * float(s) / float(grid_ring_steps)
			pts.append(_grid_point(theta, phi))
		draw_polyline(pts, _tinted(grid_alpha), grid_line_width)


func _tinted(alpha: float) -> Color:
	return Color(dome_color.r, dome_color.g, dome_color.b, alpha)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
