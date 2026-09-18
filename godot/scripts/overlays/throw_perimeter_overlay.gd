extends Node2D
class_name ThrowPerimeterOverlay

## ThrowPerimeterOverlay — the reachable-throw boundary drawn on the floor.
##
## T-MODE: visual feedback during targeting mode. The radius is given in GAME
## UNITS and projected here, so the line the player sees is the exact locus of
## "agent cell + throw_range_gu in any direction" — the same set the throw's own
## clamp tests against. The first pass took a pixel radius and halved it by hand
## for the Y axis; that produced the right 2:1 shape by luck but meant nothing in
## GU, and the clamp beside it used a THIRD geometry (an |dx| + 2|dy| diamond
## inscribed in this ellipse), so the bubble could never reach the line it was
## being clamped to. IsoProjection owns the derivation now.

var perimeter_color: Color = Color(1.0, 0.3, 0.3, 1.0)
var line_alpha: float = 0.75
var line_width: float = 2.0
var arc_segments: int = 64  ## whole ellipse, so it stays smooth at throw ranges

var _center: Vector2 = Vector2.ZERO
var _radius_gu: float = 0.0
var _visible: bool = false


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat
	visible = false


## Show the perimeter centred on a floor position, radius in GAME UNITS.
func show_perimeter(center: Vector2, radius_gu: float) -> void:
	_center = center
	_radius_gu = radius_gu
	_visible = true
	visible = true
	queue_redraw()


## RENDER3D R3D-5b — when a 3D board is set this overlay's drawing goes to a `GroundCanvas3D` (the same
## calls, on the ground plane, depth-tested) instead of to the 2D canvas. See ground_canvas3d.gd.
const GroundCanvas3DRef = preload("res://godot/scripts/geometry/ground_canvas3d.gd")
var _ground: RefCounted = null
var _c: Object = self  ## where the draw calls go: this node, or `_ground` while a 3D board is set


func set_board3d(board: Node3D) -> void:
	if _ground != null:
		_ground.detach()
		_ground = null
	if board == null:
		queue_redraw()
		return
	_ground = GroundCanvas3DRef.new()
	_ground.attach(board, 3, 0.016, false)
	_ground.follow_visibility_of(self)
	queue_redraw()


func _draw() -> void:
	if _ground == null:
		_c = self
		_draw_into()
		return
	_c = _ground
	_ground.begin(self)
	_draw_into()
	_ground.end()
	_c = self


func _draw_into() -> void:
	if not _visible or _radius_gu < 0.001:
		return
	var axes: Vector2 = IsoProjection.floor_circle_semi_axes(_radius_gu)
	var points := IsoProjection.ellipse_arc(_center, axes, 0.0, TAU, arc_segments)
	var c := perimeter_color
	_c.draw_polyline(points, Color(c.r, c.g, c.b, line_alpha), line_width)


func clear() -> void:
	_visible = false
	visible = false
	queue_redraw()
