## M6 (Director 2026-10-19) — the fire lava starts on voxels: it catches, spreads only to what is flammable enough, burns `burn_turns`, then eats or chars
## the voxel by its `burn_consumption`; it never lights a voxel twice and is capped. Pure state over lookup callables, plus the real material rows.
extends SceneTree

const FireClass = preload("res://godot/scripts/systems/voxel_fire.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	## the real rows the rule reads: wood and cardboard burn, brick does not; cardboard is eaten, wood only charred
	_check(MaterialResistanceTable.flammability("wood") >= 0.8 and MaterialResistanceTable.flammability("brick") == 0.0, "wood is flammable enough to spread, brick is not")
	_check(MaterialResistanceTable.burn_consumption("cardboard") >= 0.5 and MaterialResistanceTable.burn_consumption("wood") < 0.5, "cardboard is eaten by fire, wood only charred")

	## a row of voxels along x: 0 cardboard, 1..2 wood, 3 brick, 4 cardboard (beyond the brick)
	var rows: Dictionary = {0: "cardboard", 1: "wood", 2: "wood", 3: "brick", 4: "cardboard"}
	var flam := func(key: Vector3i) -> float: return MaterialResistanceTable.flammability(String(rows.get(key.x, ""))) if key.y == 0 and key.z == 0 else 0.0
	var cons := func(key: Vector3i) -> float: return MaterialResistanceTable.burn_consumption(String(rows.get(key.x, "")))
	var fire = FireClass.new()
	fire.spread_chance = 1.0
	_check(fire.ignite(Vector3i(0, 0, 0)) and not fire.ignite(Vector3i(0, 0, 0)), "a voxel catches once")
	var first: Dictionary = fire.advance(flam, cons)
	_check((first["lit"] as Array) == [Vector3i(1, 0, 0)] and fire.is_burning(Vector3i(1, 0, 0)), "the first turn it passes to the flammable neighbour, and only that one")
	var second: Dictionary = fire.advance(flam, cons)
	_check((second["consumed"] as Array) == [Vector3i(0, 0, 0)] and (second["lit"] as Array) == [Vector3i(2, 0, 0)], "the second turn the cardboard is eaten and the next wood catches")
	_check((second["charred"] as Array) == [Vector3i(1, 0, 0)] and not (second["consumed"] as Array).has(Vector3i(1, 0, 0)), "the first wood burns out CHARRED, not eaten")
	var third: Dictionary = fire.advance(flam, cons)
	_check((third["charred"] as Array) == [Vector3i(2, 0, 0)] and fire.burning_count() == 0, "the last wood chars and the fire is out: brick stopped it, the cardboard behind never caught")
	_check(not fire.ignite(Vector3i(0, 0, 0)), "a voxel that burnt out never lights twice")

	## the chance gates the spread, deterministically
	var a = FireClass.new()
	var b = FireClass.new()
	a.spread_chance = 0.5
	b.spread_chance = 0.5
	var open_rows: Dictionary = {}
	for x in range(40):
		open_rows[x] = "wood"
	var flam_open := func(key: Vector3i) -> float: return 1.4 if key.y == 0 and key.z == 0 and open_rows.has(key.x) else 0.0
	var none := func(_key: Vector3i) -> float: return 0.0
	a.ignite(Vector3i(0, 0, 0))
	b.ignite(Vector3i(0, 0, 0))
	var run_a: Array = []
	var run_b: Array = []
	for _t in range(10):
		run_a.append((a.advance(flam_open, none)["lit"] as Array).size())
		run_b.append((b.advance(flam_open, none)["lit"] as Array).size())
	_check(run_a == run_b, "two fires from the same cell spread identically (hash roll, no randf)")

	## the cap
	var capped = FireClass.new()
	capped.max_burning = 3
	for x in range(10):
		capped.ignite(Vector3i(x, 0, 0))
	_check(capped.burning_count() == 3, "a fire never burns more than max_burning voxels")

	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
