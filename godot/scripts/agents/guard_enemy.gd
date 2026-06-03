extends Node2D
class_name GuardEnemy
## Patrol guard placeholder: draw-based enemy with directional vision checks.

signal move_started(from_cell: Vector2i, to_cell: Vector2i)
signal step_finished(cell: Vector2i)
signal move_finished(cell: Vector2i)

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)
const STEP_DURATION := 0.13

const COLOR_BODY := Color(0.86, 0.26, 0.22, 1.0)
const COLOR_BODY_DARK := Color(0.58, 0.12, 0.10, 1.0)
const COLOR_HEAD := Color(1.0, 0.87, 0.80, 1.0)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.28)

const CARDINAL_DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var enemy_id: String = ""

var cell: Vector2i = Vector2i.ZERO
var patrol_route: Array[Vector2i] = []
var patrol_index: int = 0
var facing: Vector2i = Vector2i.UP
var is_moving: bool = false
var _path_queue: Array[Vector2i] = []


func setup(
		tile_layer: TileMapLayer,
		offset: Vector2,
		id: String,
		route: Array[Vector2i],
		start_index: int = 0
) -> void:
	floor_layer = tile_layer
	visual_offset = offset
	enemy_id = id
	patrol_route = route.duplicate()
	if patrol_route.is_empty():
		patrol_route = [Vector2i.ZERO]

	patrol_index = wrapi(start_index, 0, patrol_route.size())
	cell = patrol_route[patrol_index]
	position = _cell_to_world(cell)
	_set_facing_from_route()
	queue_redraw()


func reset_to_route_start() -> void:
	if patrol_route.is_empty():
		return
	patrol_index = 0
	cell = patrol_route[patrol_index]
	position = _cell_to_world(cell)
	_set_facing_from_route()
	queue_redraw()


func evaluate_detection(player_cell: Vector2i, vision_range: int = 6, close_warning_range: int = 2) -> Dictionary:
	var delta: Vector2i = player_cell - cell
	if delta == Vector2i.ZERO:
		return {"visible": true, "severity": 2}

	var forward := _axis_projection(delta, facing)
	if forward <= 0 or forward > vision_range:
		return {"visible": false, "severity": 0}

	var lateral := _axis_projection(delta, _orthogonal(facing))
	var cone_width := maxi(1, int(floor(float(forward) * 0.5)))
	if abs(lateral) > cone_width:
		return {"visible": false, "severity": 0}

	var severity := 2 if forward <= close_warning_range else 1
	return {"visible": true, "severity": severity}


func pick_next_patrol_cell(
		occupied_cells: Dictionary,
		blocked_cells: Dictionary,
		blocked_edges: Dictionary,
		room_size: Vector2i
) -> Vector2i:
	if patrol_route.size() < 2:
		return cell

	for i in range(1, patrol_route.size() + 1):
		var idx := (patrol_index + i) % patrol_route.size()
		var candidate: Vector2i = patrol_route[idx]
		if not _is_inside(candidate, room_size):
			continue
		if blocked_cells.has(candidate):
			continue
		if occupied_cells.has(candidate):
			continue
		if _is_edge_blocked(cell, candidate, blocked_edges):
			continue
		if candidate == cell:
			continue
		patrol_index = idx
		return candidate

	return cell


func move_to_cell_animated(new_cell: Vector2i) -> void:
	if new_cell == cell:
		return
	var path: Array[Vector2i] = _build_step_path_to(new_cell)
	if path.size() < 2:
		return
	move_along_path(path)


func move_along_path(path: Array[Vector2i]) -> void:
	if path.size() < 2:
		return
	is_moving = true
	move_started.emit(path[0], path.back())
	_path_queue = path.duplicate()
	_path_queue.pop_front()
	_step_next()


func _step_next() -> void:
	if _path_queue.is_empty():
		is_moving = false
		move_finished.emit(cell)
		queue_redraw()
		return

	var next_cell: Vector2i = _path_queue.pop_front()
	var previous_cell: Vector2i = cell
	cell = next_cell
	facing = _snap_to_cardinal(next_cell - previous_cell)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", _cell_to_world(next_cell), STEP_DURATION)
	await tween.finished
	step_finished.emit(next_cell)
	queue_redraw()
	_step_next()


func _build_step_path_to(target_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [cell]
	var cursor: Vector2i = cell
	var delta: Vector2i = target_cell - cursor
	var x_step: int = 0
	if delta.x > 0:
		x_step = 1
	elif delta.x < 0:
		x_step = -1
	while cursor.x != target_cell.x:
		cursor.x += x_step
		path.append(cursor)
	var y_step: int = 0
	if delta.y > 0:
		y_step = 1
	elif delta.y < 0:
		y_step = -1
	while cursor.y != target_cell.y:
		cursor.y += y_step
		path.append(cursor)
	return path


func _cell_to_world(map_cell: Vector2i) -> Vector2:
	if floor_layer == null:
		return Vector2.ZERO
	return floor_layer.map_to_local(map_cell) + TILE_CENTER_OFFSET + visual_offset


func _set_facing_from_route() -> void:
	if patrol_route.size() < 2:
		facing = Vector2i.UP
		return
	var next_idx := (patrol_index + 1) % patrol_route.size()
	var dir := patrol_route[next_idx] - patrol_route[patrol_index]
	if dir == Vector2i.ZERO:
		facing = Vector2i.UP
		return
	facing = _snap_to_cardinal(dir)


func _snap_to_cardinal(v: Vector2i) -> Vector2i:
	if abs(v.x) >= abs(v.y):
		return Vector2i.RIGHT if v.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if v.y >= 0 else Vector2i.UP


func _orthogonal(dir: Vector2i) -> Vector2i:
	if dir == Vector2i.UP or dir == Vector2i.DOWN:
		return Vector2i.RIGHT
	return Vector2i.UP


func _axis_projection(delta: Vector2i, axis: Vector2i) -> int:
	return delta.x * axis.x + delta.y * axis.y


func _is_inside(pos: Vector2i, room_size: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < room_size.x and pos.y < room_size.y


func _is_edge_blocked(from_cell: Vector2i, to_cell: Vector2i, blocked_edges: Dictionary) -> bool:
	var key := _edge_key(from_cell, to_cell)
	return blocked_edges.has(key)


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]


func _draw() -> void:
	var shadow := PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(26.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-26.0, 0.0),
	])
	draw_colored_polygon(shadow, COLOR_SHADOW)

	var body := PackedVector2Array([
		Vector2(0.0, -54.0),
		Vector2(20.0, -30.0),
		Vector2(0.0, -8.0),
		Vector2(-20.0, -30.0),
	])
	draw_colored_polygon(body, COLOR_BODY)
	draw_polyline(body + PackedVector2Array([body[0]]), COLOR_BODY_DARK, 3.0)
	draw_circle(Vector2(0.0, -62.0), 9.0, COLOR_HEAD)

	var p1 := Vector2(0.0, -82.0)
	var p2 := p1 + Vector2(facing.x * 18.0, facing.y * 12.0)
	draw_line(p1, p2, Color(1.0, 0.9, 0.5, 0.95), 3.0)
