extends Node2D
class_name PathPreview
const GroundGridRef = preload("res://godot/scripts/geometry/ground_grid.gd")  ## R3D-5a: the cell lattice, no TileMapLayer
## Visual preview of the currently hovered movement path.

var visual_offset: Vector2 = Vector2.ZERO
var _cells: Array[Vector2i] = []
var _ap_cost: int = 0

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)
const PREVIEW_LINE := Color(1.0, 0.79, 0.18, 0.95)
const PREVIEW_FILL := Color(1.0, 0.76, 0.20, 0.22)
const TARGET_LINE := Color(1.0, 0.45, 0.10, 0.95)


func setup(offset: Vector2) -> void:
	visual_offset = offset


func set_path(cells: Array[Vector2i], ap_cost: int) -> void:
	_cells = cells.duplicate()
	_ap_cost = ap_cost
	queue_redraw()


func clear_path() -> void:
	if _cells.is_empty() and _ap_cost == 0:
		return
	_cells.clear()
	_ap_cost = 0
	queue_redraw()


## RENDER3D R3D-5b — when a 3D board is set this overlay's drawing goes to a `GroundCanvas3D` (the same
## calls, on the ground plane, depth-tested) instead of to the 2D canvas. See ground_canvas3d.gd.
const GroundCanvas3DRef = preload("res://godot/scripts/geometry/ground_canvas3d.gd")
var _ground: RefCounted = null


func set_board3d(board: Node3D) -> void:
	if _ground != null:
		_ground.detach()
		_ground = null
	if board == null:
		queue_redraw()
		return
	_ground = GroundCanvas3DRef.new()
	_ground.attach(board, 6, 0.016, false)
	_ground.follow_visibility_of(self)
	queue_redraw()


func _draw() -> void:
	if _ground == null:
		_draw_into(self)
		return
	_ground.begin(self)
	_draw_into(_ground)
	_ground.end()


func _draw_into(c: Object) -> void:
	if _cells.size() < 2:
		return

	var centers := PackedVector2Array()
	for cell in _cells:
		centers.append(_cell_to_center(cell))
		c.draw_colored_polygon(_diamond_points(cell), PREVIEW_FILL)

	c.draw_polyline(centers, PREVIEW_LINE, 6.0, true)

	var target := _diamond_points(_cells.back())
	c.draw_polyline(target + PackedVector2Array([target[0]]), TARGET_LINE, 3.0, true)


func _diamond_points(cell: Vector2i) -> PackedVector2Array:
	var top := GroundGridRef.map_to_local(cell) + visual_offset
	return PackedVector2Array([
		top,
		top + Vector2(128.0, 64.0),
		top + Vector2(0.0, 128.0),
		top + Vector2(-128.0, 64.0),
	])


func _cell_to_center(cell: Vector2i) -> Vector2:
	return GroundGridRef.map_to_local(cell) + TILE_CENTER_OFFSET + visual_offset