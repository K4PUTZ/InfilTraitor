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
const VISION_RANGE := 6
const VISION_CONE_RADIUS := 6
const VISION_CONE_HALF_WIDTH_TILES := 3
const STATE_PATROL := "patrol"
const STATE_SUSPICIOUS := "suspicious"
const STATE_ALERT := "alert"
const STATE_CHASE := "chase"
const INVALID_CELL: Vector2i = Vector2i(-9999, -9999)

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var enemy_id: String = ""

var cell: Vector2i = Vector2i.ZERO
var patrol_route: Array[Vector2i] = []
var patrol_index: int = 0
var facing: Vector2i = Vector2i.UP
var state: String = STATE_PATROL
var state_timer: int = 0
var last_known_agent_cell: Vector2i = INVALID_CELL
var is_moving: bool = false
var _path_queue: Array[Vector2i] = []

## Angular FOV detection
var fov_degrees: float = 90.0      ## full cone width in degrees
var fov_range: int = 8             ## max detection range in tiles
var facing_angle_deg: float = 0.0  ## 0=UP 90=RIGHT 180=DOWN 270=LEFT

## A* path caching
var _cached_target: Vector2i = INVALID_CELL
var _cached_path: Array[Vector2i] = []
var _path_index: int = 1

## Dev vision mode
var dev_vision: bool = false


func set_dev_vision(enabled: bool) -> void:
	dev_vision = enabled
	queue_redraw()


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
	_update_facing_angle()
	queue_redraw()


func reset_to_route_start() -> void:
	if patrol_route.is_empty():
		return
	patrol_index = 0
	cell = patrol_route[patrol_index]
	position = _cell_to_world(cell)
	_set_facing_from_route()
	_update_facing_angle()
	queue_redraw()


func evaluate_detection(player_cell: Vector2i, _vision_range: int = VISION_RANGE, blocked_cells: Dictionary = {}, blocked_edges: Dictionary = {}, _close_warning_range: int = 2) -> Dictionary:
	var delta := player_cell - cell
	if delta == Vector2i.ZERO:
		return {"visible": true, "severity": 2, "distance": 0, "angle_ratio": 1.0}

	var dist := absi(delta.x) + absi(delta.y)
	if dist > fov_range:
		return {"visible": false, "severity": 0}

	var to_target_angle := rad_to_deg(atan2(float(delta.x), float(-delta.y)))
	var angle_diff := wrapf(to_target_angle - facing_angle_deg, -180.0, 180.0)
	var half_fov := fov_degrees / 2.0
	if absf(angle_diff) > half_fov:
		return {"visible": false, "severity": 0}

	if blocked_cells != null and blocked_edges != null:
		if not can_see_cell(player_cell, blocked_cells, blocked_edges):
			return {"visible": false, "severity": 0}

	var angle_ratio := 1.0 - (absf(angle_diff) / half_fov)
	var severity := 2 if dist <= 2 else 1
	return {"visible": true, "severity": severity, "distance": dist, "angle_ratio": angle_ratio}


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


func move_to_cell_animated(
		new_cell: Vector2i,
		blocked_cells: Dictionary,
		blocked_edges: Dictionary,
		room_size: Vector2i
) -> void:
	if new_cell == cell:
		return
	var path: Array[Vector2i] = GuardPathfinder.find_path(cell, new_cell, blocked_cells, blocked_edges, room_size)
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
	_update_facing_angle()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", _cell_to_world(next_cell), STEP_DURATION)
	await tween.finished
	step_finished.emit(next_cell)
	queue_redraw()
	_step_next()





func _cell_to_world(map_cell: Vector2i) -> Vector2:
	if floor_layer == null:
		return Vector2.ZERO
	return floor_layer.map_to_local(map_cell) + TILE_CENTER_OFFSET + visual_offset


func _set_facing_from_route() -> void:
	if patrol_route.size() < 2:
		facing = Vector2i.UP
		_update_facing_angle()
		return
	var next_idx := (patrol_index + 1) % patrol_route.size()
	var dir := patrol_route[next_idx] - patrol_route[patrol_index]
	if dir == Vector2i.ZERO:
		facing = Vector2i.UP
		_update_facing_angle()
		return
	facing = _snap_to_cardinal(dir)
	_update_facing_angle()


func _snap_to_cardinal(v: Vector2i) -> Vector2i:
	if abs(v.x) >= abs(v.y):
		return Vector2i.RIGHT if v.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if v.y >= 0 else Vector2i.UP


func _update_facing_angle() -> void:
	if facing == Vector2i.UP:
		facing_angle_deg = 0.0
	elif facing == Vector2i.RIGHT:
		facing_angle_deg = 90.0
	elif facing == Vector2i.DOWN:
		facing_angle_deg = 180.0
	elif facing == Vector2i.LEFT:
		facing_angle_deg = 270.0





func _is_inside(pos: Vector2i, room_size: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < room_size.x and pos.y < room_size.y


func _is_edge_blocked(from_cell: Vector2i, to_cell: Vector2i, blocked_edges: Dictionary) -> bool:
	var key := WallEdgeData.edge_key(from_cell, to_cell)
	return blocked_edges.has(key)


func can_see_cell(target_cell: Vector2i, blocked_cells: Dictionary, blocked_edges: Dictionary) -> bool:
	var current: Vector2i = cell
	var dx := target_cell.x - current.x
	var dy := target_cell.y - current.y
	var step_x: int = 0
	if dx > 0:
		step_x = 1
	elif dx < 0:
		step_x = -1
	var step_y: int = 0
	if dy > 0:
		step_y = 1
	elif dy < 0:
		step_y = -1
	var abs_dx: int = abs(dx)
	var abs_dy: int = abs(dy)
	var err: int = abs_dx - abs_dy

	while current != target_cell:
		var e2 := err * 2
		var next_cell := current
		if e2 > -abs_dy:
			next_cell.x += step_x
			err -= abs_dy
		if e2 < abs_dx:
			next_cell.y += step_y
			err += abs_dx
		if _is_edge_blocked(current, next_cell, blocked_edges):
			return false
		if blocked_cells.has(next_cell) and next_cell != target_cell:
			return false
		current = next_cell
	return true


func observe_player(player_visible: bool, severity: int, player_cell: Vector2i) -> void:
	if player_visible:
		last_known_agent_cell = player_cell
		if severity >= 2:
			state = STATE_ALERT
			state_timer = 3
		elif state != STATE_ALERT:
			state = STATE_SUSPICIOUS
			state_timer = 3
	return


func tick_state() -> void:
	if state == STATE_PATROL:
		return
	state_timer -= 1
	if state_timer <= 0:
		if state == STATE_ALERT:
			state = STATE_CHASE
			state_timer = 3
		elif state == STATE_SUSPICIOUS:
			state = STATE_PATROL
			last_known_agent_cell = INVALID_CELL
		elif state == STATE_CHASE:
			state = STATE_SUSPICIOUS
			state_timer = 2


func choose_next_cell(
		occupied_cells: Dictionary,
		blocked_cells: Dictionary,
		blocked_edges: Dictionary,
		player_cell: Vector2i,
		room_size: Vector2i
) -> Vector2i:
	if state == STATE_PATROL:
		return pick_next_patrol_cell(occupied_cells, blocked_cells, blocked_edges, room_size)
	if state == STATE_SUSPICIOUS:
		if last_known_agent_cell != INVALID_CELL:
			return _step_toward(last_known_agent_cell, occupied_cells, blocked_cells, blocked_edges, room_size)
		return cell
	if state == STATE_ALERT or state == STATE_CHASE:
		var target := player_cell
		if last_known_agent_cell != INVALID_CELL:
			target = last_known_agent_cell
		return _step_toward(target, occupied_cells, blocked_cells, blocked_edges, room_size)
	return cell


func _step_toward(
		target_cell: Vector2i,
		occupied_cells: Dictionary,
		blocked_cells: Dictionary,
		blocked_edges: Dictionary,
		room_size: Vector2i
) -> Vector2i:
	## Replan if target changed or path exhausted
	if target_cell != _cached_target or _path_index >= _cached_path.size():
		_cached_target = target_cell
		_cached_path = GuardPathfinder.find_path(cell, target_cell, blocked_cells, blocked_edges, room_size)
		_path_index = 1

	## No path found
	if _cached_path.is_empty():
		return cell

	## Path exhausted (shouldn't happen, but failsafe)
	if _path_index >= _cached_path.size():
		return cell

	## Get next step from path
	var next_cell: Vector2i = _cached_path[_path_index]
	_path_index += 1

	## Skip if occupied
	if occupied_cells.has(next_cell):
		return cell

	return next_cell




func _draw() -> void:
	var cone := _vision_cone_points()
	draw_colored_polygon(cone, Color(1.0, 0.9, 0.2, 0.14))
	draw_polyline(cone + PackedVector2Array([cone[0]]), Color(1.0, 0.9, 0.3, 0.6), 2.0, true)

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

	## DEV_VISION extras — only visible when dev_vision mode is active
	if not dev_vision:
		return

	## Highlight vision cone in dev_vision mode
	var dev_cone := _vision_cone_points()
	draw_colored_polygon(dev_cone, Color(1.0, 0.85, 0.1, 0.35))
	draw_polyline(dev_cone + PackedVector2Array([dev_cone[0]]), Color(1.0, 1.0, 0.0, 0.9), 2.5, true)

	## Draw patrol route as dashed line connecting waypoints
	if patrol_route.size() >= 2:
		for i in range(patrol_route.size()):
			var a := _cell_to_world(patrol_route[i]) - position
			var b := _cell_to_world(patrol_route[(i + 1) % patrol_route.size()]) - position
			draw_dashed_line(a, b, Color(0.4, 0.8, 1.0, 0.6), 2.0, 8.0)
			draw_circle(a, 5.0, Color(0.4, 0.8, 1.0, 0.8))


func _vision_cone_points() -> PackedVector2Array:
	var base := Vector2(0.0, -62.0)
	match facing:
		Vector2i.UP:
			return PackedVector2Array([base, base + Vector2(-80.0, -170.0), base + Vector2(80.0, -170.0)])
		Vector2i.DOWN:
			return PackedVector2Array([base, base + Vector2(80.0, 40.0), base + Vector2(-80.0, 40.0)])
		Vector2i.LEFT:
			return PackedVector2Array([base, base + Vector2(-170.0, -50.0), base + Vector2(-170.0, 50.0)])
		Vector2i.RIGHT:
			return PackedVector2Array([base, base + Vector2(170.0, 50.0), base + Vector2(170.0, -50.0)])
	return PackedVector2Array([base, base + Vector2(-80.0, -170.0), base + Vector2(80.0, -170.0)])
