## R3D-SURFACES SM-6 — `VentEmitter`: the timing is pure and deterministic, vents are out of phase, a hitch does not burst, a bad kind is refused,
## and the `ground_vents` section reaches the compiler on the real gallery map.
extends SceneTree

const VentEmitterClass = preload("res://godot/scripts/overlays/vent_emitter.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== VENT EMITTER SELFTEST ==\n")
	var emitter = VentEmitterClass.new()
	emitter.setup([{"at": Vector2(10, 10), "kind": "steam"}, {"at": Vector2(12, 10), "kind": "steam"}, {"at": Vector2(1, 1), "kind": "lava"}], Callable())
	_check(emitter.count() == 2, "an unknown kind is refused (loudly), the two steam vents stay")
	var per_vent: Dictionary = {}
	var t: float = 0.0
	while t < 10.0:
		for e: Dictionary in emitter.step(1.0 / 60.0):
			per_vent[e["at"]] = int(per_vent.get(e["at"], 0)) + 1
		t += 1.0 / 60.0
	var interval: float = float(VentEmitterClass.KINDS["steam"]["interval"])
	var expected: float = 10.0 / interval
	_check(absf(float(per_vent[Vector2(10, 10)]) - expected) <= 2.0 and absf(float(per_vent[Vector2(12, 10)]) - expected) <= 2.0,
		"each vent releases about one puff per interval (%d and %d in 10 s, expected %.0f)" % [per_vent[Vector2(10, 10)], per_vent[Vector2(12, 10)], expected])
	var run_a = VentEmitterClass.new()
	run_a.setup([{"at": Vector2(10, 10), "kind": "steam"}], Callable())
	var run_b = VentEmitterClass.new()
	run_b.setup([{"at": Vector2(10, 10), "kind": "steam"}], Callable())
	var ticks_a: Array = []
	var ticks_b: Array = []
	for i in range(120):
		ticks_a.append((run_a.step(1.0 / 60.0) as Array).size())
		ticks_b.append((run_b.step(1.0 / 60.0) as Array).size())
	_check(str(ticks_a) == str(ticks_b), "two runs of one vent release on the same frames (a hash phase, never a RNG)")
	run_a.free()
	run_b.free()
	var p1: float = VentEmitterClass._phase("steam", Vector2(10, 10))
	var p2: float = VentEmitterClass._phase("steam", Vector2(12, 10))
	_check(p1 != p2 and p1 >= 0.0 and p1 < 1.0, "neighbouring vents have different phases (%.3f, %.3f)" % [p1, p2])
	var hitch = VentEmitterClass.new()
	hitch.setup([{"at": Vector2(5, 5), "kind": "steam"}], Callable())
	_check((hitch.step(5.0) as Array).size() <= 4, "a 5 s hitch releases at most 4 puffs (no burst)")
	hitch.free()
	emitter.free()
	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("SURFACES_GALLERY")
	_check((spec.get("ground_vents", []) as Array).size() == 4, "the gallery's `ground_vents` reaches the runtime spec (4 vents)")
	var layout: Dictionary = MapCompilerClass.compile(spec)
	var vents: Array = layout.get("ground_vent_instances", [])
	var offset := Vector2(layout.get("playable_rect", Rect2i()).position)
	_check(vents.size() == 4 and (vents[0]["at"] as Vector2) == Vector2(spec["ground_vents"][0]["at"][0], spec["ground_vents"][0]["at"][1]) + offset, "MapCompiler forwards them shifted by the buffer")
	var bad_spec: Dictionary = spec.duplicate(true)
	bad_spec["ground_vents"] = [{"at": [1.05, 2], "kind": "steam"}, {"at": [3, 4]}, {"at": [3.5, 4.25], "kind": "steam"}]
	_check((MapCompilerClass.compile(bad_spec).get("ground_vent_instances", []) as Array).size() == 1, "an off-lattice vent and one with no kind are refused (loudly), the good one stays")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
