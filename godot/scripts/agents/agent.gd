extends Node2D
class_name DebugAgent
## Lightweight debug agent — draw-based placeholder (no sprites yet).
## Owns its grid cell, converts cell → world position, animates step-by-step.

signal move_started(from_cell: Vector2i, to_cell: Vector2i)
signal step_finished(cell: Vector2i)
signal move_finished(cell: Vector2i)

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var cell: Vector2i = Vector2i.ZERO
var vision_radius: int = 7  ## base player visibility radius in tiles; affects enemy fade thresholds
var vision_mode: String = "normal"  ## future modes: thermal, night vision, xray
var is_moving: bool = false

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)
## Duration per tile step — snappy tactical feel.
const STEP_DURATION := 0.13

const COLOR_BODY := Color(0.16, 0.78, 0.32, 1.0)
const COLOR_BODY_DARK := Color(0.07, 0.42, 0.18, 1.0)
const COLOR_HEAD := Color(0.84, 0.96, 0.88, 1.0)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.28)

var _path_queue: Array[Vector2i] = []


func setup(tile_layer: TileMapLayer, offset: Vector2, start_cell: Vector2i) -> void:
	floor_layer = tile_layer
	visual_offset = offset
	set_cell(start_cell)


func set_cell(new_cell: Vector2i) -> void:
	cell = new_cell
	position = _cell_to_world(new_cell)
	queue_redraw()


func get_vision_radius() -> int:
	return vision_radius

func set_vision_radius(new_radius: int) -> void:
	vision_radius = max(0, new_radius)


## Animate the agent along every cell in `path` (must include the start cell).
## Emits step_finished(cell) on each arrival; move_finished(cell) at the end.
func move_along_path(path: Array[Vector2i]) -> void:
	if path.size() < 2:
		return
	is_moving = true
	move_started.emit(path[0], path.back())
	_path_queue = path.duplicate()
	_path_queue.pop_front()  ## already at path[0] — skip it
	_step_next()


func _step_next() -> void:
	if _path_queue.is_empty():
		is_moving = false
		move_finished.emit(cell)
		queue_redraw()
		return

	var next_cell: Vector2i = _path_queue.pop_front()
	cell = next_cell  ## logical cell advances immediately

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", _cell_to_world(next_cell), STEP_DURATION)
	tween.finished.connect(func() -> void:
		step_finished.emit(next_cell)
		queue_redraw()
		_step_next()
	)


func _cell_to_world(map_cell: Vector2i) -> Vector2:
	if floor_layer == null:
		return Vector2.ZERO
	return floor_layer.map_to_local(map_cell) + TILE_CENTER_OFFSET + visual_offset


func _draw() -> void:
	var shadow := PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(28.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-28.0, 0.0),
	])
	draw_colored_polygon(shadow, COLOR_SHADOW)

	var body := PackedVector2Array([
		Vector2(0.0, -56.0),
		Vector2(22.0, -30.0),
		Vector2(0.0, -6.0),
		Vector2(-22.0, -30.0),
	])
	draw_colored_polygon(body, COLOR_BODY)
	draw_polyline(body + PackedVector2Array([body[0]]), COLOR_BODY_DARK, 3.0)

	draw_circle(Vector2(0.0, -64.0), 10.0, COLOR_HEAD)
