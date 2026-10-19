## M6 consolidation (2026-10-18) — the liquids' error protection: a malformed `gameplay` value is refused at load (loud, the key dropped, never a script
## error mid-step), and a body's plane survives bad map data (an oversized grid is cut, a zone that holds no cell and a grate off the body are said, NaN
## and negative numbers are neutralised), with every real liquid file loading clean. And the WATERFALL: on PIPE_LAB's layout read from voxels (a raised pipe over a dug
## channel) the water leaves the bore over a step and `FluidPlane.falls()` finds the fall at the mouth, and nowhere on a flat body.
extends SceneTree

const RegistryClass = preload("res://godot/scripts/systems/liquid_registry.gd")
const PlaneClass = preload("res://godot/scripts/systems/fluid_plane.gd")
const FireClass = preload("res://godot/scripts/systems/liquid_fire.gd")
const FallsClass = preload("res://godot/scripts/geometry/liquid_falls3d.gd")
const WorldClass = preload("res://godot/scripts/tools/liquid_test_world.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _body(rect: Rect2, fluid: Dictionary) -> Dictionary:
	var base: Dictionary = {"cell": 0.5, "rim": 2.0, "dig": 0.0, "walls": [], "grounds": [], "roofs": [], "sources": [], "sinks": [], "grates": []}
	base.merge(fluid, true)
	return {"rect": rect, "fluid": base}


func _init() -> void:
	print("\n== LIQUID GUARDS SELFTEST ==\n")
	var errors: Array = []
	var files: int = 0
	for file_name: String in DirAccess.get_files_at("res://liquids"):   ## every real file's rules through the same check the registry runs at load
		if not file_name.ends_with(".json"):
			continue
		var row: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://liquids/" + file_name))
		if row is Dictionary and (row as Dictionary).get("gameplay", {}) is Dictionary:
			RegistryClass.check_gameplay((row as Dictionary).get("gameplay", {}), file_name, errors)
			files += 1
	_check(files >= 18 and errors.is_empty(), "every real liquid file's rules pass the check (%d files, %d error(s))" % [files, errors.size()])
	errors = []
	var good: Dictionary = {"exposure": {"shallow": 0.1, "deep": 0.4, "recovery": 0.1}, "footprint": {"color": [0.2, 0.3, 0.4], "turns": 4},
		"light": {"body": {"radius": 3, "energy": 0.5, "tint": "cool"}}, "corrodes": ["metal", "curb"], "trap": {"escape_ap": 2}}
	var kept: Dictionary = RegistryClass.check_gameplay(good, "good", errors)
	_check(errors.is_empty() and kept.size() == good.size(), "a well-formed block passes whole")
	var bad: Dictionary = {
		"exposure": 0.4,                                   ## a number where an object is read
		"footprint": {"color": [0.2, 0.3], "turns": 4},   ## two channels
		"fire": {"burn": -0.2},                            ## a negative burn would add oil
		"light": {"body": {"tint": "blue"}},               ## an unknown hue
		"corrodes": ["metal", "glass"],                    ## glass is not a target
		"trap": {"escape": 2},                             ## an unknown field
		"slippery": "yes",                                 ## a text where a flag is read
		"wade_ap": NAN,
		"wobble": true,                                    ## an unknown key
		"noise": 0.3,                                      ## the one good key
	}
	errors = []
	kept = RegistryClass.check_gameplay(bad, "bad", errors)
	_check(kept.keys() == ["noise"], "every malformed key is dropped, the good one kept (%s)" % str(kept.keys()))
	_check(errors.size() == bad.size() - 1, "and each one is reported (%d of %d)" % [errors.size(), bad.size() - 1])

	## the plane: an oversized body is cut to MAX_CELLS
	var huge = PlaneClass.from_body(_body(Rect2(0, 0, 200, 200), {"cell": 0.125}), 1.0)
	_check(huge.cols * huge.rows <= PlaneClass.MAX_CELLS and huge.cols >= 3, "a 200 x 200 GU body at one voxel is cut to %d cells (max %d)" % [huge.cols * huge.rows, PlaneClass.MAX_CELLS])
	## NaN, zero and negative numbers
	var odd = PlaneClass.from_body(_body(Rect2(0, 0, 2, 2), {"cell": NAN, "fill": -3.0, "sources": [{"rect": Rect2(0, 0, 1, 1), "rate": NAN}]}), 1.0)
	_check(odd.cell_gu == PlaneClass.MIN_CELL_GU and odd.total_volume() == 0.0, "a NaN cell becomes one voxel, a negative fill holds nothing")
	odd.tick()
	_check(odd.total_volume() == 0.0 and is_finite(odd.spilled), "a NaN source rate adds nothing (volume %.2f)" % odd.total_volume())
	## a zone outside the body and a grate off it do nothing (and warn) instead of writing out of the grid
	var lost = PlaneClass.from_body(_body(Rect2(0, 0, 2, 2), {"sources": [{"rect": Rect2(10, 10, 1, 1), "rate": 2.0}], "grates": [{"axis": "y", "at": 50.0}]}), 1.0)
	lost.tick()
	_check(lost.total_volume() == 0.0, "a source outside the body adds nothing")
	## a full pool keeps its volume through ticks (nothing created, nothing lost without a rim to spill over)
	var pool = PlaneClass.from_body(_body(Rect2(0, 0, 3, 2), {"rim": 4.0, "fill": 2.0}), 1.0)
	var before: float = pool.total_volume()
	for _t in range(20):
		pool.tick()
	_check(absf(pool.total_volume() - before) < 0.01 and pool.spilled < 0.01, "a still pool under its rim keeps its volume over 20 ticks (%.3f -> %.3f)" % [before, pool.total_volume()])
	## a fire's spec cannot add oil or run backwards
	var fire = FireClass.new()
	fire.setup(pool, {"speed": -5.0, "burn": -1.0, "dose_step": -1.0})
	fire.ignite(Vector2(1.5, 1.0), 5.0)
	fire.tick()
	_check(fire.burn_per_turn == 0.0 and fire.speed_gu == 0.0 and fire.dose_step == 0.0 and pool.total_volume() <= before + 0.01, "negative fire numbers are clamped to zero (no oil made)")
	## the waterfall, PIPE_LAB's layout read from voxels: a raised pipe pours over the end of a channel dug 4 (a body takes its shape from the world)
	var world = WorldClass.new()
	world.lay(Rect2i(0, 0, 6, 14), [Rect2i(2, 3, 2, 8)])
	world.raised_pipe(2, 1, 3)
	var made: Dictionary = world.body(Vector2(3.0, 1.4), RegistryClass.fluidity("caribe"), {"sources": [{"rect": Rect2(2.5, 1.0, 1.0, 0.5), "rate": 2.0}], "sinks": [{"rect": Rect2(2.5, 10.5, 1.0, 0.5), "rate": 1.0}]})
	var lab = made["plane"]
	var mouth_y: float = 3.0
	var seen: Array = []
	for _t in range(6):
		lab.begin_tick()
		for _r in range(lab.rounds_per_tick()):
			lab.step_rounds(1)
			if seen.is_empty():
				seen = lab.falls()
	_check(not seen.is_empty(), "water flowing out of the raised bore makes a fall (%d edge(s))" % seen.size())
	if not seen.is_empty():
		var f: Dictionary = seen[0]
		_check(absf((f["a"] as Vector2).y - mouth_y) < 0.01 and f["dir"] == Vector2(0, 1) and float(f["top"]) >= 6.0 and float(f["top"]) - float(f["bottom"]) >= PlaneClass.FALL_DROP,
				"at the mouth (y %.2f), falling south, from the bore (%.2f voxels) to the channel (%.2f)" % [(f["a"] as Vector2).y, float(f["top"]), float(f["bottom"])])
	for _t in range(20):   ## twenty more turns: the bore settles at its level
		lab.tick()
	var steady: Array = lab.falls()
	var chains: Array = FallsClass._chains(steady)
	_check(steady.size() >= 2 and chains.size() == 1 and (chains[0] as Array).size() == steady.size(), "the mouth's edges (the bore's two cells) join into ONE curtain (%d edge(s), %d chain(s))" % [steady.size(), chains.size()])
	var deepest: float = 0.0
	for f: Dictionary in steady:
		deepest = maxf(deepest, float(f["depth"]))
	_check(deepest > 1.0 and deepest < 5.0, "the weir holds a level in the (flat, four-cell) bore: %.2f voxels over its bottom, not a film" % deepest)
	var channel: float = 0.0
	for i in lab.cells_in(Rect2(2.0, 3.5, 2.0, 5.0)):
		channel += lab.depth[i]
	_check(channel > 1.0, "the water reached the channel below (%.2f voxels in it)" % channel)
	var flat = PlaneClass.from_body(_body(Rect2(0, 0, 3, 2), {"rim": 4.0, "fill": 2.0, "sources": [{"rect": Rect2(0, 0, 1, 2), "rate": 2.0}]}), 1.0)
	var flat_falls: int = 0
	for _t in range(4):
		flat.begin_tick()
		for _r in range(flat.rounds_per_tick()):
			flat.step_rounds(1)
			flat_falls += flat.falls().size()
	_check(flat_falls == 0, "a flat body with a source has no fall")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
