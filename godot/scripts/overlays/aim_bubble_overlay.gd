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
## NOT YET DONE — sectioning by nearby walls, the other half of the Director's
## note. That needs the depth classification FloatingCollectible already uses
## (`VoxelRenderer.classify_geometry_over_rect()`, OcclusionSet policy O5),
## because z_index encodes HEIGHT in this project and cannot express "behind that
## wall but in front of this one". Tracked, not silently dropped.

## Tuning — `var` per architecture Rule 1.
var dome_color: Color = Color(0.55, 0.75, 1.0, 1.0)
var fill_alpha: float = 0.13          ## the dome's volume
var floor_fill_alpha: float = 0.20    ## the ground section, denser than the volume
var floor_line_alpha: float = 0.50    ## the section's own outline
var rim_alpha: float = 0.85           ## the sphere's silhouette
var line_width: float = 2.0
var arc_segments: int = 32            ## per half-ellipse

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

	## Rim last, so it sits over both fills. Closed by repeating the first point.
	var rim := outline
	rim.append(outline[0])
	draw_polyline(rim, _tinted(rim_alpha), line_width)


func _tinted(alpha: float) -> Color:
	return Color(dome_color.r, dome_color.g, dome_color.b, alpha)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
