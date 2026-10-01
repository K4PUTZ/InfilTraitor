extends Node2D
const GroundGridRef = preload("res://godot/scripts/geometry/ground_grid.gd")  ## R3D-5a: the cell lattice, no TileMapLayer
## Trail overlay for DEV_VISION — displays yellow diamond trail of last 5 tiles walked.

var _room_ref: Node2D = null
var _visual_offset: Vector2 = Vector2.ZERO


func setup(room_ref: Node2D, visual_offset: Vector2) -> void:
	_room_ref = room_ref
	_visual_offset = visual_offset
	z_index = 150  ## Well above movement_overlay (~100)


## R3D-WORLD — on the 3D board the trail goes to a `GroundCanvas3D` (same shape as `PathPreview`).
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
	_ground.attach(board, 7, 0.02, false)
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
	if _room_ref == null or not _room_ref._vision_controller.dev_vision:
		return

	var agent_trail: Array = _room_ref._agent_trail
	if agent_trail.is_empty():
		return

	var n := agent_trail.size()
	for i in range(n):
		var trail_cell: Vector2i = agent_trail[i]
		## i=0 is oldest, i=n-1 is newest
		var alpha := 0.2 + (float(i) / float(n - 1 if n > 1 else 1)) * 0.8
		var color := Color(1.0, 0.85, 0.1, alpha)

		## Yellow diamond centered on tile
		var center := _world_center_for_cell(trail_cell)
		var diamond := PackedVector2Array([
			center + Vector2(0.0,  -22.0),
			center + Vector2(32.0,  0.0),
			center + Vector2(0.0,   22.0),
			center + Vector2(-32.0, 0.0),
		])
		c.draw_colored_polygon(diamond, color)


func _world_center_for_cell(cell: Vector2i) -> Vector2:
	return GroundGridRef.map_to_local(cell) + Vector2(0.0, 64.0) + _visual_offset
