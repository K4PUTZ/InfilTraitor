extends Node2D
class_name ThrowPerimeterOverlay

## ThrowPerimeterOverlay — red circle showing grenade throw range.
##
## Task T-MODE: visual feedback during targeting mode. Drawn at the
## grenade's starting position (typically agent's center) with radius =
## throw_range (from BombDef). One ring at GU-grid resolution.

var perimeter_color: Color = Color(1.0, 0.3, 0.3, 0.6)  ## red translucent
var line_width: float = 2.0

var _center: Vector2 = Vector2.ZERO
var _radius: float = 0.0
var _visible: bool = false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat
	visible = false


## Show the perimeter at a given center with radius.
func show_perimeter(center: Vector2, radius: float) -> void:
	_center = center
	_radius = radius
	_visible = true
	visible = true
	queue_redraw()


func _draw() -> void:
	if not _visible or _radius < 0.001:
		return
	var outline := perimeter_color
	outline.a = 1.0
	draw_circle(_center, _radius, Color.TRANSPARENT)  ## fill transparent
	draw_circle(_center, _radius, outline, false, line_width)  ## outline only


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
