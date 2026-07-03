## TurnController
## Orchestrates turn phases, enemy AI execution, and alert meter management.
## Handles tactical state updates, detection/alert accumulation, and camera control.

class_name TurnController

## Constants for detection thresholds (from former room.gd ID-01)
const DETECTION_THRESHOLD_SUSPICIOUS: float = 0.25
const DETECTION_THRESHOLD_ALERT: float = 0.50
const DETECTION_THRESHOLD_CHASE: float = 0.75

## Camera animation constants
const ENEMY_CAMERA_TWEEN_DURATION: float = 0.4
const ENEMY_PHASE_MAX_OPEN_ZOOM: float = 2.0
const ACTOR_END_HOLD_DELAY: float = 0.2
const ENEMY_INTER_TURN_DELAY: float = 0.5

## References to room components
var room: Node
var turn_manager: TacticalTurnManager = null
var enemy_phase_controller: EnemyPhaseController = null
var agent: DebugAgent = null
var camera: Camera2D = null
var floor_layer: TileMapLayer = null

## Cached references to arrays/dicts
var _guards: Array = []
var _blocked_cells: Dictionary = {}
var _current_blocked_edges: Array[Dictionary] = []
var _room_size: Vector2i = Vector2i.ZERO

## UI and overlay controllers
var _fow_controller: Object = null
var _hud_controller: Object = null
var _vision_controller: Object = null
var _guard_coordinator: Object = null
var _noise_system: Object = null
var _noise_overlay: Object = null

## Alert state (managed by this controller)
var _alert_meter: int = 0
var _alert_max: int = 0
var _alert_gain_full: int = 0

## Game constants
var VISUAL_GRID_OFFSET: Vector2 = Vector2.ZERO
var FOW_REVEAL_RADIUS: int = 0
var vision_bonus_tiles: int = 0

## State flags
var _actor_end_pause_active: bool = false
var _pending_auto_end_turn: bool = false
var _peek_active: bool = false
var _peek_timer: int = 0


func _init(p_room: Node) -> void:
	room = p_room


func setup(
	p_turn_manager: TacticalTurnManager,
	p_enemy_phase_controller: EnemyPhaseController,
	p_agent: DebugAgent,
	p_camera: Camera2D,
	p_floor_layer: TileMapLayer,
	p_fow_controller: Object,
	p_hud_controller: Object,
	p_vision_controller: Object,
	p_guard_coordinator: Object,
	p_noise_system: Object,
	p_noise_overlay: Object
) -> void:
	turn_manager = p_turn_manager
	enemy_phase_controller = p_enemy_phase_controller
	agent = p_agent
	camera = p_camera
	floor_layer = p_floor_layer
	_fow_controller = p_fow_controller
	_hud_controller = p_hud_controller
	_vision_controller = p_vision_controller
	_guard_coordinator = p_guard_coordinator
	_noise_system = p_noise_system
	_noise_overlay = p_noise_overlay


func set_constants(
	p_visual_grid_offset: Vector2,
	p_fow_radius: int,
	p_vision_bonus: int,
	p_alert_max: int,
	p_alert_gain: int
) -> void:
	VISUAL_GRID_OFFSET = p_visual_grid_offset
	FOW_REVEAL_RADIUS = p_fow_radius
	vision_bonus_tiles = p_vision_bonus
	_alert_max = p_alert_max
	_alert_gain_full = p_alert_gain


func set_game_state(
	p_guards: Array,
	p_blocked_cells: Dictionary,
	p_current_blocked_edges: Array[Dictionary],
	p_room_size: Vector2i
) -> void:
	_guards = p_guards
	_blocked_cells = p_blocked_cells
	_current_blocked_edges = p_current_blocked_edges
	_room_size = p_room_size


func get_alert_meter() -> int:
	return _alert_meter


func set_alert_meter(value: int) -> void:
	_alert_meter = value


func set_pending_auto_end_turn(value: bool) -> void:
	_pending_auto_end_turn = value


## Signal handlers

func _on_hud_end_turn_requested() -> void:
	if agent == null or turn_manager == null:
		return
	if agent.is_moving or turn_manager.is_enemy_phase or _actor_end_pause_active:
		return
	_pending_auto_end_turn = false
	turn_manager.end_turn()


func _on_player_turn_started() -> void:
	if _vision_controller == null:
		return
	# Dummy call to update vision data
	_update_guard_los_data()
	if _peek_active:
		_peek_timer -= 1
		if _peek_timer <= 0:
			_peek_active = false
			if _fow_controller != null:
				_fow_controller.reset_peek_reveals()


func _on_enemy_phase_started() -> void:
	if _guards.is_empty():
		if turn_manager != null:
			turn_manager.finish_enemy_phase()
		return
	
	_update_guard_los_data()
	
	if _hud_controller != null:
		_hud_controller.show_enemy_banner()
	
	if floor_layer != null:
		# Clear overlays
		pass  # Movement and path preview cleared in room context
	
	if agent != null:
		if _fow_controller != null:
			_center_camera(agent.cell)
	
	await _hold_actor_end_pause()
	await _run_enemy_phase()
	
	if _hud_controller != null:
		_hud_controller.hide_enemy_banner()
	
	if _alert_meter >= _alert_max:
		await _show_busted_dialog()
		# room will handle _reset_room_state()
	
	_update_alert_label()
	
	# M2-04: Decay noise at end of enemy phase
	if _noise_system != null:
		_noise_system.decay_all()
	if _noise_overlay != null:
		_noise_overlay.queue_redraw()
	
	# Return camera to agent
	if agent != null:
		_center_camera(agent.cell)
	
	if turn_manager != null:
		turn_manager.finish_enemy_phase()


## Detection and Alert System (CRITICAL: Rule 5 - alert accumulation ONLY here)

func _apply_tic_result(guard, result: TicSystem.TicResult) -> void:
	## Accumulate or decay the guard's detection field
	if result.visible:
		guard.detection = clampf(
			guard.detection + result.raw_chance * TicSystem.DETECTION_GAIN_PER_TIC,
			0.0, 1.0
		)
	else:
		## Decay outside the cone
		var decay := _get_detection_decay(guard.state)
		guard.detection = clampf(guard.detection + decay, 0.0, 1.0)

	## M2-04: Noise amplifies detection if the guard already sees the tile
	if _noise_system != null:
		var noise_intensity: float = _noise_system.get_intensity(agent.cell)
		if noise_intensity > 0.0 and result.visible:
			var bonus: float = noise_intensity * 0.3
			guard.detection = clampf(guard.detection + bonus, 0.0, 1.0)

	if _vision_controller != null and _vision_controller.dev_vision:
		guard.queue_redraw()

	## ID-01: Gradual threshold-based escalation — only when the agent is visible
	if result.visible:
		if guard.detection >= DETECTION_THRESHOLD_CHASE:
			guard.observe_player(true, 3, agent.cell)
			_alert_meter = mini(_alert_max, _alert_meter + _alert_gain_full)
			if _alert_meter >= _alert_max and _guard_coordinator != null:
				_guard_coordinator._on_guard_alarmed(guard.cell)
		elif guard.detection >= DETECTION_THRESHOLD_ALERT:
			guard.observe_player(true, 2, agent.cell)
			_alert_meter = mini(_alert_max, _alert_meter + _alert_gain_full)
			if _alert_meter >= _alert_max and _guard_coordinator != null:
				_guard_coordinator._on_guard_alarmed(guard.cell)
		elif guard.detection >= DETECTION_THRESHOLD_SUSPICIOUS:
			guard.observe_player(true, 1, agent.cell)
		## Below DETECTION_THRESHOLD_SUSPICIOUS: meter accumulates, no state change

	_update_alert_label()


func _get_detection_decay(state: String) -> float:
	match state:
		"patrol":
			return -0.15
		"suspicious":
			return -0.06
		"alert":
			return -0.04
		"chase":
			return -0.01
	return -0.10


## M2-05: Processes auditory detection for all guards
func _process_audio_detection() -> void:
	if _noise_system == null or enemy_phase_controller == null or agent == null:
		return

	var blocked_edges: Dictionary = enemy_phase_controller.build_blocked_edge_set(_current_blocked_edges)

	for guard in _guards:
		if not is_instance_valid(guard):
			continue

		for noise_tile in _noise_system.get_noisy_tiles():
			var intensity: float = _noise_system.get_intensity(noise_tile)
			if intensity <= 0.0:
				continue

			var perceived: float = TicSystem.evaluate_audio(
				guard, noise_tile, intensity, blocked_edges
			)
			if perceived > 0.0:
				guard.hear_noise(noise_tile, perceived)


## Enemy Phase Execution

func _run_enemy_phase() -> void:
	if enemy_phase_controller == null or agent == null:
		return
	
	## M2-05: Process persistent noise before the guards act
	_process_audio_detection()

	var blocked_edges: Dictionary = enemy_phase_controller.build_blocked_edge_set(_current_blocked_edges)
	var occupied: Dictionary = {}
	for guard in _guards:
		if is_instance_valid(guard):
			occupied[guard.cell] = guard

	var max_severity := 0
	for i in range(_guards.size()):
		var guard = _guards[i]
		if not is_instance_valid(guard):
			continue

		var report: Dictionary = await enemy_phase_controller.run_single_guard_turn(
			guard,
			agent.cell,
			_blocked_cells,
			blocked_edges,
			_room_size,
			occupied,
			_apply_tic_result,   ## passes the callback
			_guard_coordinator._on_guard_emits_noise if _guard_coordinator != null else func(_a, _b): pass   ## M2-14: noise callback
		)
		max_severity = maxi(max_severity, int(report.get("max_severity", 0)))

		## Camera follows the guard only if its tile is revealed by the FOW
		if _fow_controller != null and _fow_controller.is_cell_revealed(guard.cell):
			await _focus_camera_for_enemy_phase(guard.cell)

		await _hold_actor_end_pause()

	## Alert accumulation now happens in _apply_tic_result() during the tics
	_update_enemy_visibility()


func _hold_actor_end_pause() -> void:
	_actor_end_pause_active = true
	await room.get_tree().create_timer(ACTOR_END_HOLD_DELAY).timeout
	_actor_end_pause_active = false


func _enemy_inter_turn_pause_with_camera(target_cell: Vector2i) -> void:
	var tween_time := minf(ENEMY_CAMERA_TWEEN_DURATION, ENEMY_INTER_TURN_DELAY)
	await _focus_camera_for_enemy_phase(target_cell, tween_time)
	var remain := ENEMY_INTER_TURN_DELAY - tween_time
	if remain > 0.0:
		await room.get_tree().create_timer(remain).timeout


## Camera Control

func _focus_camera_for_enemy_phase(target_cell: Vector2i, duration: float = ENEMY_CAMERA_TWEEN_DURATION) -> void:
	if target_cell == Vector2i(-1, -1) or camera == null or floor_layer == null:
		return
	
	var target_world := _world_center_for_cell(target_cell)
	var target_zoom := camera.zoom.x
	if target_zoom > ENEMY_PHASE_MAX_OPEN_ZOOM:
		target_zoom = ENEMY_PHASE_MAX_OPEN_ZOOM

	var tween := room.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", target_world, duration)
	tween.tween_property(camera, "zoom", Vector2(target_zoom, target_zoom), duration)
	await tween.finished


func _world_center_for_cell(cell: Vector2i) -> Vector2:
	if floor_layer == null:
		return Vector2.ZERO
	return floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET


func _center_camera(cell: Vector2i) -> void:
	if camera == null or floor_layer == null:
		return
	var target_pos := _world_center_for_cell(cell)
	camera.global_position = target_pos


## State Management

func _refresh_tactical_state() -> void:
	# Called from room context to update overlays
	# Actual implementation stays in room (depends on movement_overlay, etc)
	pass


func _update_guard_los_data() -> void:
	# Placeholder for any turn-start LOS updates
	pass


func _update_enemy_visibility() -> void:
	# Called after guard actions - handled by room
	pass


func _update_alert_label() -> void:
	if _hud_controller == null:
		return
	var pct := float(_alert_meter) / float(_alert_max)
	_hud_controller.update_alert(pct)


func _show_busted_dialog() -> void:
	if _hud_controller == null:
		return
	_hud_controller.show_busted("ui.banner.busted")
	await room.get_tree().create_timer(1.2).timeout
	_hud_controller.hide_busted()
