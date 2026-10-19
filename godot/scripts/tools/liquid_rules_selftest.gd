## M6 F3-F6 — the liquids' RULES: the dose model (lethal in the deep, little on top, worse the longer), wading cost and blocked paths, the trap, a
## `LiquidField` lookup over a PIPE_LAB-like channel read from voxels, the player's valve, and a breach.
extends SceneTree

const ExposureClass = preload("res://godot/scripts/systems/liquid_exposure.gd")
const FieldClass = preload("res://godot/scripts/systems/liquid_field.gd")
const PlaneClass = preload("res://godot/scripts/systems/fluid_plane.gd")
const RegistryClass = preload("res://godot/scripts/systems/liquid_registry.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const WorldClass = preload("res://godot/scripts/tools/liquid_test_world.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== LIQUID RULES SELFTEST ==\n")
	var toxic: Dictionary = RegistryClass.gameplay("toxic")
	var lava: Dictionary = RegistryClass.gameplay("lava_gold")
	var water: Dictionary = RegistryClass.gameplay("clean")
	var mud: Dictionary = RegistryClass.gameplay("lama")
	_check(ExposureClass.rate(toxic, 1.0) < ExposureClass.rate(toxic, 4.0) and ExposureClass.rate(toxic, 1.0) > 0.0, "toxic waste hurts a little on top and more in the deep")
	_check(ExposureClass.rate(water, 6.0) == 0.0 and ExposureClass.rate(toxic, 0.0) == 0.0, "water never hurts, and a dry cell never does")
	var dose: float = 0.0
	var steps: int = 0
	while not ExposureClass.is_lethal(dose) and steps < 100:
		dose = ExposureClass.after_step(dose, toxic, 1.0)
		steps += 1
	var turns: float = 0.0
	var dose_turn: float = 0.0
	while not ExposureClass.is_lethal(dose_turn) and turns < 100:
		dose_turn = ExposureClass.after_turn(dose_turn, toxic, 4.0)
		turns += 1.0
	_check(steps > 3 and turns <= 3.0, "shallow toxic takes %d steps to kill, standing in the deep %d turns" % [steps, int(turns)])
	_check(ExposureClass.is_lethal(ExposureClass.after_turn(0.0, lava, 4.0)), "lava kills in a turn in the deep")
	_check(not ExposureClass.is_lethal(ExposureClass.after_turn(0.0, lava, 1.0)) and ExposureClass.is_lethal(ExposureClass.after_turn(ExposureClass.after_turn(0.0, lava, 1.0), lava, 1.0)), "and in two turns on top")
	var recovering: float = ExposureClass.after_turn(0.5, RegistryClass.gameplay("acido"), 0.0)
	_check(recovering < 0.5 and ExposureClass.after_turn(0.5, RegistryClass.gameplay("nuclear"), 0.0) == 0.5, "acid exposure recovers out of the liquid, nuclear does not")
	_check(ExposureClass.is_blocked(lava, 4.0) and not ExposureClass.is_blocked(lava, 1.0) and not ExposureClass.is_blocked(water, 6.0), "a deep lethal liquid is a blocked path, shallow and harmless water are not")
	_check(ExposureClass.wade_points(mud, 1.0) == 2 and ExposureClass.wade_points(mud, 4.0) == 4 and ExposureClass.wade_points(water, 1.0) == 0, "mud costs 2 points a step, 4 in the deep, water none")
	_check(ExposureClass.wade_points(RegistryClass.gameplay("petroleo"), 1.0) == 2, "oil costs a point and a slippery one")
	_check(ExposureClass.trap_ap(mud, 4.0) == 2 and ExposureClass.trap_ap(mud, 1.0) == 0 and ExposureClass.trap_ap(water, 4.0) == 0, "deep mud holds the agent for 2 AP, shallow mud and water do not")

	## a channel as PIPE_LAB lays it, built from voxels (2026-10-19: a body takes its shape from the world): a raised pipe pours into a channel dug 4 under
	## the floor, a drain at its far end
	var world = WorldClass.new()
	world.lay(Rect2i(0, 0, 6, 14), [Rect2i(2, 3, 2, 8)])
	world.raised_pipe(2, 1, 3)
	var made: Dictionary = world.body(Vector2(3.0, 1.4), 1.0, {"sources": [{"rect": Rect2(2.5, 1.0, 1.0, 0.5), "rate": 2.0}], "sinks": [{"rect": Rect2(2.5, 10.5, 1.0, 0.5), "rate": 1.0}]})
	var plane = made["plane"]
	var field = FieldClass.new()
	field.add_body("caribe", made["rect"], plane)
	var probe := Vector2i(3, 6)
	_check(field.at_cell(probe).is_empty(), "before any turn the channel is dry")
	for _t in range(60):
		plane.tick()
	var wet: Dictionary = field.at_cell(probe)
	_check(not wet.is_empty() and String(wet["kind"]) == "caribe" and float(wet["depth"]) > 0.5, "after 60 turns the field reports caribe in the channel (%.2f voxels)" % float(wet.get("depth", 0.0)))
	_check(field.at_cell(Vector2i(0, 6)).is_empty() and field.at_cell(Vector2i(1, 6)).is_empty(), "and nothing on the floor beside it")
	var before: float = float(wet["depth"])
	field.set_source_rate(0, 0, 0.0)
	for _t in range(200):
		plane.tick()
	var after: float = float(field.at_cell(probe).get("depth", 0.0))
	_check(after < before * 0.7, "shutting the valve lowers the channel (%.2f to %.2f voxels)" % [before, after])
	field.set_source_rate(0, 0, 8.0)
	for _t in range(80):
		plane.tick()
	var spilled_before: float = plane.spilled
	plane.lower_ground(Rect2(1.5, 5.0, 0.5, 1.0), 0.0)   ## the rim cell beside the channel: a breach through its wall
	for _t in range(20):
		plane.tick()
	_check(plane.spilled > spilled_before and not field.set_source_rate(5, 0, 1.0), "a breach in the wall lets the liquid out; a valve that does not exist says so")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
