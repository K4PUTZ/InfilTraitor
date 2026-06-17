extends Node

## MODULARIZE-06: Routes coordination signals between guards via room.gd.
## Does NOT communicate directly with another controller.
## _guards[] belongs to room.gd; accessed via _room._guards.

signal guard_whistled(origin_cell: Vector2i, last_known: Vector2i)
signal guard_radioed(origin_cell: Vector2i, last_known: Vector2i)
signal alarm_raised(origin_cell: Vector2i)
signal all_guards_alerted()

var _room: Node2D


func setup(room_ref: Node2D) -> void:
	_room = room_ref


## Connects a guard's signals to this coordinator.
## Called by room.gd when a guard is created in _spawn_guards().
func register_guard(guard: Object) -> void:
	if guard == null:
		return
	guard.whistled.connect(_on_guard_whistled)
	guard.radioed.connect(_on_guard_radioed)


## ─────────────────────────────────────────────────────────────────────
## HANDLER: WHISTLE
## ─────────────────────────────────────────────────────────────────────

## Whistle: guards within WHISTLE_RADIUS tiles enter STATE_SEARCH
func _on_guard_whistled(origin_cell: Vector2i, last_known: Vector2i) -> void:
	if last_known == _room.INVALID_CELL:
		return

	guard_whistled.emit(origin_cell, last_known)

	for guard in _room._guards:
		if not is_instance_valid(guard):
			continue
		var dist: float = float((guard.cell - origin_cell).length())
		if dist <= _room.WHISTLE_RADIUS:
			guard.receive_alert(last_known, guard.STATE_SEARCH)


## ─────────────────────────────────────────────────────────────────────
## HANDLER: RADIO
## ─────────────────────────────────────────────────────────────────────

## Radio: all guards in PATROL/SUSPICIOUS enter STATE_ALERT
func _on_guard_radioed(_origin_cell: Vector2i, last_known: Vector2i) -> void:
	if last_known == _room.INVALID_CELL:
		return

	guard_radioed.emit(_origin_cell, last_known)

	for guard in _room._guards:
		if not is_instance_valid(guard):
			continue
		if guard.state == guard.STATE_PATROL or \
		   guard.state == guard.STATE_SUSPICIOUS:
			guard.receive_alert(last_known, guard.STATE_ALERT)


## ─────────────────────────────────────────────────────────────────────
## HANDLER: ALARM
## ─────────────────────────────────────────────────────────────────────

## Global alarm: all guards enter STATE_CHASE + HUD updates
func _on_guard_alarmed(origin_cell: Vector2i) -> void:
	## All guards not already chasing enter STATE_CHASE
	for guard in _room._guards:
		if not is_instance_valid(guard):
			continue
		if guard.state != guard.STATE_CHASE:
			guard.receive_alert(_room.agent.cell, guard.STATE_CHASE)

	## Set alert meter to maximum
	_room._alert_meter = _room._alert_max
	_room._update_alert_label()

	## Emit signal so room.gd can coordinate the response
	alarm_raised.emit(origin_cell)
	all_guards_alerted.emit()


## ─────────────────────────────────────────────────────────────────────
## HANDLER: GUARD NOISE EMISSION
## ─────────────────────────────────────────────────────────────────────

## Emit noise when a guard moves (callback from enemy_phase_controller)
func _on_guard_emits_noise(guard: Object, guard_cell: Vector2i) -> void:
	if _room._noise_system == null or guard == null:
		return

	## Noise chance per guard state
	var noise_chance: float = _room.GUARD_NOISE_CHANCE_BY_STATE.get(guard.state, 0.10) as float
	if randf() < noise_chance:
		## Noise intensity per guard state
		var noise_intensity: float = _room.GUARD_NOISE_INTENSITY_BY_STATE.get(guard.state, 0.5) as float
		## Emit into the global noise system
		_room._noise_system.emit(guard_cell, noise_intensity)
		## Emit a sound indicator toward the agent
		_room._emit_guard_noise_indicator(guard_cell, noise_intensity)
		## Redraw overlays to update the visuals
		if _room._noise_overlay != null:
			_room._noise_overlay.queue_redraw()
