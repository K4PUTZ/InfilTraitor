## ScenarioDraw — waiting for a drawn frame always returns: in at most WAIT_FRAMES + a few process frames, whether or not the engine draws
## (the headless dummy renderer and an occluded window both draw nothing). A forced draw is announced by a warning, never silent.
extends SceneTree

const ScenarioDrawClass = preload("res://godot/scripts/systems/scenario_draw.gd")

var _failures: int = 0
var _done: bool = false
var _frames: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _initialize() -> void:
	print("\n== SCENARIO DRAW SELFTEST ==\n")
	_run.call_deferred()


func _run() -> void:
	var start: int = Engine.get_process_frames()
	await ScenarioDrawClass.next_drawn_frame(self)
	_frames = Engine.get_process_frames() - start
	await ScenarioDrawClass.next_drawn_frame(self)
	var second: int = Engine.get_process_frames() - start - _frames
	_check(_frames <= ScenarioDrawClass.WAIT_FRAMES + 3, "the wait returns within %d process frames (took %d)" % [ScenarioDrawClass.WAIT_FRAMES + 3, _frames])
	_check(second <= ScenarioDrawClass.WAIT_FRAMES + 3, "and again (took %d): no signal is left connected to leak into the next wait" % second)
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
