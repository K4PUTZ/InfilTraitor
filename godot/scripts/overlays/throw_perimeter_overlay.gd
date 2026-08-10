extends Node2D
class_name ThrowPerimeterOverlay

## ThrowPerimeterOverlay — elliptical perimeter showing grenade throw range.
##
## Task T-MODE: visual feedback during targeting mode. Respects isometric 2:1
## perspective: drawn as ellipse with width_radius (horizontal GU distance) and
## height_radius = width_radius / 2 (vertical GU distance in isometric view).

var perimeter_color: Color = Color(1.0, 0.3, 0.3, 0.6)  ## red translucent
var line_width: float = 2.0
var arc_segments: int = 40  ## number of segments for smooth ellipse

var _center: Vector2 = Vector2.ZERO
var _radius_x: float = 0.0  ## horizontal radius (GU grid distance)
var _radius_y: float = 0.0  ## vertical radius (half of _radius_x for isometric 2:1)
var _visible: bool = false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat
	visible = false


## Show the elliptical perimeter (respects isometric 2:1 perspective).
func show_perimeter(center: Vector2, radius: float) -> void:
	_center = center
	_radius_x = radius
	_radius_y = radius * 0.5  ## isometric 2:1 aspect ratio
	_visible = true
	visible = true
	queue_redraw()


func _draw() -> void:
	if not _visible or _radius_x < 0.001:
		return

	var outline := perimeter_color
	outline.a = 1.0

	## Draw ellipse outline using points
	var points: PackedVector2Array = []
	for i in range(arc_segments + 1):
		var angle: float = (TAU * float(i)) / float(arc_segments)
		var x: float = cos(angle) * _radius_x
		var y: float = sin(angle) * _radius_y
		points.append(_center + Vector2(x, y))

	draw_polyline(points, outline, line_width)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
