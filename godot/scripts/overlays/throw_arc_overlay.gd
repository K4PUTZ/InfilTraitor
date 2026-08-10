extends Node2D
class_name ThrowArcOverlay

## ThrowArcOverlay — 2D parabolic arc showing grenade throw trajectory.
##
## Task T-ARC: visual feedback during grenade targeting. Draws a parabolic
## curve from agent hand position to target position, showing throw arc.
## One line at z=max+8 (same as AnimatedRayOverlay).

var arc_color: Color = Color(1.0, 0.8, 0.3, 0.7)  ## yellow translucent
var line_width: float = 2.0
var arc_segments: int = 20  ## number of line segments in parabola

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _visible: bool = false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	visible = false


## Show the arc from a starting position to a target position.
func show_arc(from_pos: Vector2, to_pos: Vector2) -> void:
	_from = from_pos
	_to = to_pos
	_visible = true
	visible = true
	queue_redraw()


func _draw() -> void:
	if not _visible:
		return

	## Compute parabolic arc: y = a*x^2 + c (simple inverted parabola)
	var delta: Vector2 = _to - _from
	var horizontal_dist: float = delta.x
	var vertical_dist: float = delta.y

	## Avoid division by zero
	if absf(horizontal_dist) < 0.1:
		horizontal_dist = 0.1

	## Parabola coefficient (higher = flatter arc)
	var arc_height: float = absf(horizontal_dist) * 0.3

	var prev_point: Vector2 = _from
	for i in range(1, arc_segments + 1):
		var t: float = float(i) / float(arc_segments)
		var x_offset: float = horizontal_dist * t
		var y_offset: float = vertical_dist * t

		## Add parabolic height (peaks at t=0.5)
		var parabola_y: float = -arc_height * 4.0 * (t - 0.5) * (t - 0.5) + arc_height

		var point: Vector2 = _from + Vector2(x_offset, y_offset + parabola_y)
		draw_line(prev_point, point, arc_color, line_width)
		prev_point = point


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
