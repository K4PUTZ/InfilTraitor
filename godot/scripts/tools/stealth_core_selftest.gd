## STEALTH-CORE selftest — the stealth loop AS IT BEHAVES TODAY, pinned before A2 builds on it (HERITAGE T5,
## 2026-11-11). Nothing here says the numbers are right: it says what they ARE, so a change to any of them is a
## decision someone makes, never a drift. The live path is `TurnController._apply_tic_result()` (Room's own copy only
## delegates to it), so its thresholds are the ones pinned: 0.25 / 0.50 / 0.75.
##
##  1. NoiseSystem: emit keeps the louder, decay is 0.25 a turn, a tile at or under 0 is gone.
##  2. TicSystem.evaluate_audio: Manhattan radius 2, distance factor 1 - d / 3, each wall x 0.6, silence is 0.
##  3. TicSystem.evaluate: raw chance = the guard's final probability x the state multiplier x the exposure multiplier.
##  4. TurnController._apply_tic_result: gain x 0.4 when seen, the per-state decay when not, the noise bonus, the three
##     thresholds and the alert meter (gain 45 of 100, capped, the alarm at the cap).
##  5. GuardEnemy's FSM: escalation only, the timers, tick_state's de-escalation, hearing.
##
## Run: python3 tools/persistent/run_selftests.py --only stealth_core (a SCENE selftest: `TurnController` reads the
## `Telemetry` autoload, which only a scene run registers).
extends Node


class AlarmSpy:
	var calls: Array[Vector2i] = []

	func _on_guard_alarmed(cell: Vector2i) -> void:
		calls.append(cell)


## Stands in for `GuardEnemy.evaluate_detection()` (cone, distance, shadow and cover are the guard's own business and
## are not what this pins) and for the exposure system.
class DetectionStub extends Node:
	var state: String = "patrol"
	var fov_range: int = 6
	var final_prob: float = 0.5
	var seen: bool = true

	func evaluate_detection(_target: Vector2i, _range: int, _cells: Dictionary, _edges: Dictionary, _bonus: int,
			_agent: Variant) -> Dictionary:
		return {"visible": seen, "final_prob": final_prob, "angle_ratio": 1.0, "distance": 2}


class ExposureStub:
	var mult: float = 1.0

	func get_detection_multiplier(_cell: Vector2i) -> float:
		return mult


class AudioGuard:
	var cell: Vector2i = Vector2i.ZERO


var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_failures += 1


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _ready() -> void:
	print("\n== STEALTH-CORE SELFTEST ==\n")
	await get_tree().process_frame
	_noise()
	_audio()
	_tic()
	_apply_tic_result()
	_fsm()
	if _failures == 0:
		print("\n[SUCCESS] STEALTH-CORE SELFTEST PASS — all checks")
		get_tree().quit(0)
	else:
		print("\n[FAILURE] %d check(s) failed" % _failures)
		get_tree().quit(1)


func _noise() -> void:
	print("[1] NoiseSystem")
	var n := NoiseSystem.new()
	var t := Vector2i(3, 4)
	n.emit(t, 0.5)
	n.emit(t, 0.3)
	_check(_near(n.get_intensity(t), 0.5), "emit keeps the louder of two (0.5 over 0.3)")
	n.emit(t, 0.8)
	_check(_near(n.get_intensity(t), 0.8), "a louder emit replaces it (0.8)")
	n.decay_all()
	_check(_near(n.get_intensity(t), 0.55), "one turn decays 0.25 (0.8 -> 0.55)")
	n.decay_all()
	n.decay_all()
	_check(_near(n.get_intensity(t), 0.05), "three turns: 0.05 left")
	n.decay_all()
	_check(n.get_noisy_tiles().is_empty() and _near(n.get_intensity(t), 0.0), "a tile at or under 0 is removed")
	_check(_near(NoiseSystem.NOISE_CHANCE_WALK, 0.20) and _near(NoiseSystem.NOISE_INTENSITY_WALK, 0.5),
		"a step makes noise one time in five, at 0.5")


func _audio() -> void:
	print("[2] TicSystem.evaluate_audio")
	var g := AudioGuard.new()
	var none: Dictionary = {}
	_check(_near(TicSystem.evaluate_audio(g, Vector2i(0, 0), 0.9, none), 0.9), "distance 0: the whole intensity")
	_check(_near(TicSystem.evaluate_audio(g, Vector2i(1, 0), 0.9, none), 0.6), "distance 1: x 2/3")
	_check(_near(TicSystem.evaluate_audio(g, Vector2i(1, 1), 0.9, none), 0.3), "distance 2 (Manhattan): x 1/3")
	_check(_near(TicSystem.evaluate_audio(g, Vector2i(2, 1), 0.9, none), 0.0), "distance 3: not heard")
	_check(_near(TicSystem.evaluate_audio(g, Vector2i(1, 0), 0.0, none), 0.0), "silence is not heard")
	var walled: Dictionary = {WallEdgeData.edge_key(Vector2i(0, 0), Vector2i(1, 0)): true}
	_check(_near(TicSystem.evaluate_audio(g, Vector2i(1, 0), 0.9, walled), 0.6 * 0.6), "one wall between: x 0.6")


func _tic() -> void:
	print("[3] TicSystem.evaluate")
	_check(_near(TicSystem.DETECTION_GAIN_PER_TIC, 0.4), "the gain per tic is 0.4")
	var mults: Dictionary = {"patrol": 0.55, "suspicious": 1.60, "search": 0.80, "alert": 2.00, "chase": 2.80}
	for s: String in mults:
		_check(_near(float(TicSystem.STATE_MULTIPLIER[s]), float(mults[s])), "the %s multiplier is %.2f" % [s, mults[s]])
	var guard := DetectionStub.new()
	add_child(guard)
	var exposure := ExposureStub.new()
	exposure.mult = 2.0
	guard.state = "alert"
	var r: TicSystem.TicResult = TicSystem.evaluate(guard, Vector2i(2, 2), {}, {}, exposure)
	_check(r.visible and _near(r.raw_chance, 0.5 * 2.0 * 2.0), "raw chance = 0.5 x alert 2.00 x exposure 2.0 = 2.0")
	guard.seen = false
	r = TicSystem.evaluate(guard, Vector2i(2, 2), {}, {}, exposure)
	_check(not r.visible and _near(r.raw_chance, 0.0) and not r.detected, "unseen: no chance, no detection")
	guard.queue_free()


func _controller(alarm: AlarmSpy, noise: NoiseSystem) -> TurnController:
	var tc := TurnController.new(null)
	var agent := Agent.new()
	agent.cell = Vector2i(5, 5)
	tc.setup(null, null, agent, null, null, null, null, alarm, noise, null)
	tc.set_constants(Vector2.ZERO, 0, 0, 100, 45)
	return tc


func _result(seen: bool, raw: float) -> TicSystem.TicResult:
	var r := TicSystem.TicResult.new()
	r.visible = seen
	r.raw_chance = raw
	return r


func _apply_tic_result() -> void:
	print("[4] TurnController._apply_tic_result (the live path)")
	_check(_near(TurnController.DETECTION_THRESHOLD_SUSPICIOUS, 0.25) and _near(TurnController.DETECTION_THRESHOLD_ALERT, 0.50)
		and _near(TurnController.DETECTION_THRESHOLD_CHASE, 0.75), "the thresholds are 0.25 / 0.50 / 0.75")
	var alarm := AlarmSpy.new()
	var tc := _controller(alarm, NoiseSystem.new())
	var g := GuardEnemy.new()
	g.cell = Vector2i(9, 9)
	tc._apply_tic_result(g, _result(true, 0.5))
	_check(_near(g.detection, 0.2) and g.state == GuardEnemy.STATE_PATROL and tc.get_alert_meter() == 0,
		"seen at 0.5: +0.2, under 0.25 nothing else")
	tc._apply_tic_result(g, _result(true, 0.5))
	_check(_near(g.detection, 0.4) and g.state == GuardEnemy.STATE_SUSPICIOUS and g.state_timer == 4
		and tc.get_alert_meter() == 0, "0.4: SUSPICIOUS (timer 4), the meter does not move")
	tc._apply_tic_result(g, _result(true, 0.5))
	_check(_near(g.detection, 0.6) and g.state == GuardEnemy.STATE_ALERT and g.state_timer == 3
		and tc.get_alert_meter() == 45, "0.6: ALERT (timer 3), the meter +45")
	tc._apply_tic_result(g, _result(true, 0.5))
	_check(_near(g.detection, 0.8) and g.state == GuardEnemy.STATE_CHASE and tc.get_alert_meter() == 90,
		"0.8: CHASE, the meter 90")
	_check(alarm.calls.is_empty(), "no alarm under the cap")
	tc._apply_tic_result(g, _result(true, 0.5))
	_check(_near(g.detection, 1.0) and tc.get_alert_meter() == 100 and alarm.calls == [Vector2i(9, 9)],
		"1.0: the meter capped at 100 and the alarm raised once, at the guard's cell")
	tc._apply_tic_result(g, _result(false, 0.0))
	_check(_near(g.detection, 0.99), "unseen in CHASE: -0.01")
	var decay: Dictionary = {"patrol": -0.15, "suspicious": -0.06, "alert": -0.04, "chase": -0.01, "search": -0.10}
	for s: String in decay:
		var d := GuardEnemy.new()
		d.state = s
		d.detection = 0.5
		tc._apply_tic_result(d, _result(false, 0.0))
		_check(_near(d.detection, 0.5 + float(decay[s])), "unseen in %s: %.2f" % [s, decay[s]])
		d.free()
	var noisy := NoiseSystem.new()
	noisy.emit(Vector2i(5, 5), 0.5)
	var tc2 := _controller(AlarmSpy.new(), noisy)
	var h := GuardEnemy.new()
	tc2._apply_tic_result(h, _result(true, 0.0))
	_check(_near(h.detection, 0.15), "seen while the agent's tile is noisy (0.5): +0.3 x 0.5")
	h.free()
	g.free()
	tc.agent.free()
	tc2.agent.free()


func _fsm() -> void:
	print("[5] GuardEnemy FSM")
	var g := GuardEnemy.new()
	g.observe_player(true, 2, Vector2i(1, 1))
	_check(g.state == GuardEnemy.STATE_ALERT and g.state_timer == 3, "severity 2: ALERT, timer 3")
	g.observe_player(true, 1, Vector2i(1, 1))
	_check(g.state == GuardEnemy.STATE_ALERT, "never downgrades (severity 1 leaves ALERT alone)")
	g.tick_state()
	g.tick_state()
	g.tick_state()
	_check(g.state == GuardEnemy.STATE_CHASE and g.state_timer == 3, "ALERT runs out in 3 turns into CHASE (timer 3)")
	g.tick_state()
	g.tick_state()
	g.tick_state()
	_check(g.state == GuardEnemy.STATE_SEARCH, "CHASE runs out, the last known cell is set: SEARCH")
	for i in range(5):
		g.tick_state()
	_check(g.state == GuardEnemy.STATE_SUSPICIOUS and g.state_timer == 2, "SEARCH lasts 5 turns, then SUSPICIOUS (timer 2)")
	g.tick_state()
	g.tick_state()
	_check(g.state == GuardEnemy.STATE_PATROL and g.last_known_agent_cell == GuardEnemy.INVALID_CELL,
		"SUSPICIOUS runs out: PATROL, the last known cell forgotten")
	g.free()
	var e := GuardEnemy.new()
	e.receive_alert(Vector2i(2, 2), GuardEnemy.STATE_SEARCH)
	_check(e.state == GuardEnemy.STATE_SEARCH, "receive_alert escalates PATROL to SEARCH")
	e.receive_alert(Vector2i(2, 2), GuardEnemy.STATE_SUSPICIOUS)
	_check(e.state == GuardEnemy.STATE_SEARCH, "receive_alert never downgrades")
	e.free()
	var n := GuardEnemy.new()
	n.hear_noise(Vector2i(3, 3), 0.2)
	_check(n.state == GuardEnemy.STATE_PATROL and _near(n.detection, 0.1), "a faint noise (0.2) only adds 0.1 detection")
	n.hear_noise(Vector2i(3, 3), 0.3)
	_check(n.state == GuardEnemy.STATE_SUSPICIOUS and n.state_timer == 2, "a medium noise (0.3): SUSPICIOUS, timer 2")
	n.free()
	var l := GuardEnemy.new()
	l.hear_noise(Vector2i(4, 4), 0.6)
	_check(l.state == GuardEnemy.STATE_SUSPICIOUS and l.state_timer == 3 and l.last_known_agent_cell == Vector2i(4, 4),
		"a loud noise (0.6): SUSPICIOUS, timer 3, and the guard knows where")
	l.free()
