extends Node2D
## Trail overlay for DEV_VISION — displays yellow diamond trail of last 5 tiles walked.

var _room_ref: Node2D = null
var _floor_layer: TileMapLayer = null
const VISUAL_GRID_OFFSET := Vector2(0.0, 512.0)


func setup(room_ref: Node2D, floor_layer: TileMapLayer) -> void:
	_room_ref = room_ref
	_floor_layer = floor_layer
	z_index = 150  ## Well above movement_overlay (~100)


func _draw() -> void:
	if _room_ref == null or not _room_ref.dev_vision:
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
		draw_colored_polygon(diamond, color)


func _world_center_for_cell(cell: Vector2i) -> Vector2:
	return _floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET
