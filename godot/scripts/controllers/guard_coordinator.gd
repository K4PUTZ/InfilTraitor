extends Node

## MODULARIZE-06: Roteia sinais de coordenação entre guards via room.gd.
## NÃO se comunica diretamente com outro controller.
## _guards[] pertence a room.gd; acessa via _room._guards.

signal guard_whistled(origin_cell: Vector2i, last_known: Vector2i)
signal guard_radioed(origin_cell: Vector2i, last_known: Vector2i)
signal alarm_raised(origin_cell: Vector2i)
signal all_guards_alerted()

var _room: Node2D


func setup(room_ref: Node2D) -> void:
	_room = room_ref


## Conecta os sinais de um guard a este coordinator.
## Chamado por room.gd quando um guard é criado em _spawn_guards().
func register_guard(guard: Object) -> void:
	if guard == null:
		return
	guard.whistled.connect(_on_guard_whistled)
	guard.radioed.connect(_on_guard_radioed)


## ─────────────────────────────────────────────────────────────────────
## HANDLER: APITO (Whistle)
## ─────────────────────────────────────────────────────────────────────

## Apito: guards a até WHISTLE_RADIUS tiles entram em STATE_SEARCH
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
## HANDLER: RÁDIO (Radio)
## ─────────────────────────────────────────────────────────────────────

## Rádio: todos os guards em PATROL/SUSPICIOUS entram em STATE_ALERT
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
## HANDLER: ALARME (Alarm)
## ─────────────────────────────────────────────────────────────────────

## Alarme global: todos os guards entram em STATE_CHASE + HUD atualiza
func _on_guard_alarmed(origin_cell: Vector2i) -> void:
	## Todos os guards não em chase entram em STATE_CHASE
	for guard in _room._guards:
		if not is_instance_valid(guard):
			continue
		if guard.state != guard.STATE_CHASE:
			guard.receive_alert(_room.agent.cell, guard.STATE_CHASE)
	
	## Seta alert meter para máximo
	_room._alert_meter = _room._alert_max
	_room._update_alert_label()
	
	## Emite sinal para room.gd coordenar resposta
	alarm_raised.emit(origin_cell)
	all_guards_alerted.emit()


## ─────────────────────────────────────────────────────────────────────
## HANDLER: EMISSÃO DE RUÍDO (Guard Noise)
## ─────────────────────────────────────────────────────────────────────

## Emite ruído quando um guard se move (callback de enemy_phase_controller)
func _on_guard_emits_noise(guard: Object, guard_cell: Vector2i) -> void:
	if _room._noise_system == null or guard == null:
		return
	
	## Chance de ruído por estado do guarda
	var noise_chance: float = _room.GUARD_NOISE_CHANCE_BY_STATE.get(guard.state, 0.10) as float
	if randf() < noise_chance:
		## Intensidade de ruído por estado
		var noise_intensity: float = _room.GUARD_NOISE_INTENSITY_BY_STATE.get(guard.state, 0.5) as float
		## Emitir no sistema de ruído global
		_room._noise_system.emit(guard_cell, noise_intensity)
		## Emitir indicador sonoro para o agente
		_room._emit_guard_noise_indicator(guard_cell, noise_intensity)
		## Redraw dos overlays para atualizar visual
		if _room._noise_overlay != null:
			_room._noise_overlay.queue_redraw()
