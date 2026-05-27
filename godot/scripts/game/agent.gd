extends Node2D
class_name DebugAgent
## Lightweight debug agent for the M1.5 tactical UI slice.
## Owns its grid cell, converts cell → world position, and animates movement.

signal move_started(from_cell: Vector2i, to_cell: Vector2i)
signal move_finished(cell: Vector2i)

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var cell: Vector2i = Vector2i.ZERO
var is_moving: bool = false

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)
const MOVE_DURATION := 1.0

const COLOR_BODY := Color(0.16, 0.78, 0.32, 1.0)
const COLOR_BODY_DARK := Color(0.07, 0.42, 0.18, 1.0)
const COLOR_HEAD := Color(0.84, 0.96, 0.88, 1.0)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.28)


func setup(tile_layer: TileMapLayer, offset: Vector2, start_cell: Vector2i) -> void:
	floor_layer = tile_layer
	visual_offset = offset
	set_cell(start_cell)


func set_cell(new_cell: Vector2i) -> void:
	cell = new_cell
	position = _cell_to_world(new_cell)
	queue_redraw()


func move_to_cell(new_cell: Vector2i, duration: float = MOVE_DURATION) -> Tween:
	var from_cell := cell
	cell = new_cell
	is_moving = true
	move_started.emit(from_cell, new_cell)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _cell_to_world(new_cell), duration)
	tween.finished.connect(_finish_move)
	return tween


func _finish_move() -> void:
	is_moving = false
	move_finished.emit(cell)
	queue_redraw()


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