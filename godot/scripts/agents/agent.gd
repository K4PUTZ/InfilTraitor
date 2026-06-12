extends Node2D
class_name DebugAgent
## Lightweight debug agent — draw-based placeholder (no sprites yet).
## Owns its grid cell, converts cell → world position, animates step-by-step.

signal move_started(from_cell: Vector2i, to_cell: Vector2i)
signal step_finished(cell: Vector2i)
signal move_finished(cell: Vector2i)
signal posture_changed(new_posture: Posture)

enum Posture { STANDING, CROUCHING, PRONE }

## Estado atual
var posture: Posture = Posture.STANDING

## Custo de AP para mudar de postura
const POSTURE_CHANGE_AP := 1

## Multiplicadores de detecção visual por postura
const POSTURE_DETECTION_MULT: Dictionary = {
	Posture.STANDING:  1.00,
	Posture.CROUCHING: 0.55,
	Posture.PRONE:     0.20,
}

## Custo de movimento extra por postura (tiles adicionais de AP)
## Agachado: +1 AP por tile. Deitado: não pode mover nesse turno.
const POSTURE_MOVE_AP_COST: Dictionary = {
	Posture.STANDING:  0,
	Posture.CROUCHING: 1,   ## cada tile custa +1 AP extra
	Posture.PRONE:     99,  ## impossível mover (99 = bloqueio efetivo)
}

## Cores temporárias por postura (substituídas por sprites em M3+)
const POSTURE_COLORS: Dictionary = {
	Posture.STANDING:  Color(0.16, 0.78, 0.32, 1.0),   ## verde — cor atual
	Posture.CROUCHING: Color(0.90, 0.75, 0.10, 1.0),   ## amarelo
	Posture.PRONE:     Color(0.90, 0.35, 0.10, 1.0),   ## laranja
}

## Declaradas para M3+ (combate) — não utilizadas agora
const POSTURE_HIT_MULT: Dictionary = {
	Posture.STANDING:  1.00,
	Posture.CROUCHING: 0.50,
	Posture.PRONE:     0.70,
}
const POSTURE_AIM_MULT: Dictionary = {
	Posture.STANDING:  1.00,
	Posture.CROUCHING: 0.75,
	Posture.PRONE:     0.50,
}

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var cell: Vector2i = Vector2i.ZERO
var vision_radius: int = 7  ## base player visibility radius in tiles; affects enemy fade thresholds
var vision_mode: String = "normal"  ## future modes: thermal, night vision, xray
var is_moving: bool = false
var dev_vision: bool = false

## Cover
enum CoverType { NONE, PARTIAL, FULL }
var cover_state: CoverType = CoverType.NONE
var cover_direction: Vector2i = Vector2i.ZERO  ## direção para o obstáculo

const COVER_FULL_MULT   := 0.20   ## probabilidade de detecção quando em cover full
const COVER_PARTIAL_MULT := 0.55  ## cover parcial (apenas 1 adjacente bloqueado)

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


func set_posture(new_posture: Posture) -> void:
	if new_posture == posture:
		return
	posture = new_posture
	posture_changed.emit(posture)
	queue_redraw()


func update_cover(blocked_cells: Dictionary) -> void:
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var blocked_count := 0
	var last_blocked_dir := Vector2i.ZERO

	for dir in dirs:
		if blocked_cells.has(cell + dir):
			blocked_count += 1
			last_blocked_dir = dir

	if blocked_count == 0:
		cover_state   = CoverType.NONE
		cover_direction = Vector2i.ZERO
	elif blocked_count == 1:
		cover_state   = CoverType.PARTIAL
		cover_direction = last_blocked_dir
	else:
		cover_state   = CoverType.FULL
		cover_direction = last_blocked_dir  ## direção primária

	queue_redraw()


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
	var body_color: Color = POSTURE_COLORS[posture]
	var body_dark:  Color = body_color.darkened(0.45)

	var shadow := PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(28.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-28.0, 0.0),
	])
	draw_colored_polygon(shadow, COLOR_SHADOW)

	## Corpo — forma muda com postura
	match posture:
		Posture.STANDING:
			## Diamond vertical alto — forma atual
			var body := PackedVector2Array([
				Vector2(0.0, -56.0), Vector2(22.0, -30.0),
				Vector2(0.0,  -6.0), Vector2(-22.0, -30.0),
			])
			draw_colored_polygon(body, body_color)
			draw_polyline(body + PackedVector2Array([body[0]]), body_dark, 3.0)
			draw_circle(Vector2(0.0, -64.0), 10.0, COLOR_HEAD)

		Posture.CROUCHING:
			## Diamond menor e mais baixo
			var body := PackedVector2Array([
				Vector2(0.0, -36.0), Vector2(20.0, -18.0),
				Vector2(0.0,  -4.0), Vector2(-20.0, -18.0),
			])
			draw_colored_polygon(body, body_color)
			draw_polyline(body + PackedVector2Array([body[0]]), body_dark, 3.0)
			draw_circle(Vector2(0.0, -44.0), 8.0, COLOR_HEAD)

		Posture.PRONE:
			## Elipse horizontal — deitado
			var body := PackedVector2Array([
				Vector2(0.0, -14.0), Vector2(30.0, -6.0),
				Vector2(0.0,   2.0), Vector2(-30.0, -6.0),
			])
			draw_colored_polygon(body, body_color)
			draw_polyline(body + PackedVector2Array([body[0]]), body_dark, 2.0)
			draw_circle(Vector2(26.0, -10.0), 7.0, COLOR_HEAD)

	if dev_vision:
		## Anel ao redor do agente com cor por nível de cover
		var ring_color := Color.TRANSPARENT
		match cover_state:
			CoverType.PARTIAL: ring_color = Color(0.2, 0.6, 1.0, 0.6)
			CoverType.FULL:    ring_color = Color(0.1, 0.4, 0.9, 0.9)
		if ring_color.a > 0.0:
			draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, ring_color, 2.5)
