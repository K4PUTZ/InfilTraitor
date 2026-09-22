extends SceneTree

## SOOT-STAMP selftest (2026-09-22) — the rules a stamp is made of, in isolation.
##
## Soot stopped being derived: an event stamps a tone per cell once
## (`BlastCalculator`'s SOOT-STAMP block). What this pins is what the rest of the
## system relies on without re-checking: the roll is deterministic and only ever
## LIGHTENS by one step, a tone survives the soot plane's code and back, the firearm's
## ball reaches exactly its radius, and the nearest seed wins. The live paths (a real
## shot and a real blast writing the store and the plane) are measured in a real boot,
## not here.

const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")

var _fails: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("SOOT-STAMP SELFTEST")
	print("=".repeat(70) + "\n")

	_test_jitter_is_deterministic_and_only_lightens()
	_test_code_round_trip()
	_test_ball_reaches_exactly_its_radius()
	_test_stamp_nearest_seed_wins()

	print("")
	if _fails == 0:
		print("[SOOT-STAMP] RESULT: PASS — all checks passed")
		quit(0)
	else:
		print("[SOOT-STAMP] RESULT: FAIL — %d check(s) failed" % _fails)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("[SOOT-STAMP] ✅ %s" % label)
	else:
		print("[SOOT-STAMP] ❌ %s" % label)
		_fails += 1


## The roll decides "this tone or one lighter", never darker, never two steps, and the
## same cell rolls the same way every time. Past the last tone a cell is clean.
func _test_jitter_is_deterministic_and_only_lightens() -> void:
	var clean: int = BlastCalculatorClass.FACE_SOOT_CLEAN
	var bad_step: int = 0
	var unstable: int = 0
	var lightened: int = 0
	var cells: int = 0
	for ring in range(clean):
		for x in range(-20, 20):
			for y in range(-6, 6):
				var cell := Vector2i(x, y)
				var a: int = BlastCalculatorClass.soot_jitter(cell, 84, ring)
				var b: int = BlastCalculatorClass.soot_jitter(cell, 84, ring)
				cells += 1
				if a != b:
					unstable += 1
				var expected_light: int = ring + 1 if ring + 1 < clean else -1
				if a != ring and a != expected_light:
					bad_step += 1
				if a != ring:
					lightened += 1
	_check(unstable == 0, "the roll is deterministic (%d cells rolled twice)" % cells)
	_check(bad_step == 0, "a stamped tone is either kept or lightened by exactly one step")
	## Both outcomes must actually occur, or the "sorteio" is a constant in disguise.
	_check(lightened > 0 and lightened < cells,
		"the roll really dithers: %d of %d cells came out one step lighter" % [lightened, cells])
	_check(BlastCalculatorClass.soot_jitter(Vector2i(3, 3), 84, clean) == -1
		and BlastCalculatorClass.soot_jitter(Vector2i(3, 3), 84, -1) == -1,
		"a ring outside 0..3 comes out clean")


## Every tone survives the soot plane's code and back; clean is its own code.
func _test_code_round_trip() -> void:
	var ok: bool = true
	for ring in range(BlastCalculatorClass.FACE_SOOT_CLEAN):
		if BlastCalculatorClass.soot_ring_of_code(BlastCalculatorClass.soot_code(ring)) != ring:
			ok = false
	_check(ok, "tones 0..3 round-trip through the plane code")
	_check(BlastCalculatorClass.soot_code(-1) == VoxelRenderer.FACE_SOOT_CODE_CLEAN
		and BlastCalculatorClass.soot_ring_of_code(VoxelRenderer.FACE_SOOT_CODE_CLEAN) == -1,
		"clean maps to the clean code and back to -1")


## The L1 ball of radius 3 is the 63 cells whose |dx|+|dy|+|dz| <= 3, each with its
## own distance, and nothing further.
func _test_ball_reaches_exactly_its_radius() -> void:
	var ball: Array = BlastCalculatorClass.soot_ball(3)
	var worst: int = 0
	var mismatched: int = 0
	for row: Array in ball:
		var o: Vector3i = row[0]
		var d: int = absi(o.x) + absi(o.y) + absi(o.z)
		if d != int(row[1]):
			mismatched += 1
		worst = maxi(worst, d)
	_check(ball.size() == 63 and worst == 3 and mismatched == 0,
		"the radius-3 ball holds 63 cells, reaches distance 3 and no further (got %d, max %d)"
			% [ball.size(), worst])


## Two seeds: a cell between them takes the NEARER seed's distance, and nothing past the
## radius is written. With no store every cell counts as solid.
func _test_stamp_nearest_seed_wins() -> void:
	var level: int = GeometryCoords.PLAYABLE_LEVEL
	var seeds: Array = [Vector3i(0, 0, level), Vector3i(6, 0, level)]
	var out: Dictionary = BlastCalculatorClass.stamp_around(seeds, 3, null)
	var lv: Dictionary = out.get(level, {})
	## (4, 0): distance 4 from the first seed, 2 from the second -> ring 1 before the roll.
	var between: int = int(lv.get(Vector2i(4, 0), -1))
	_check(between == BlastCalculatorClass.soot_jitter(Vector2i(4, 0), level, 1),
		"a cell between two seeds takes the nearer seed's ring (got %d)" % between)
	## The seed itself (a dent that survived) is ring 0 before the roll.
	_check(int(lv.get(Vector2i(0, 0), -2)) == BlastCalculatorClass.soot_jitter(Vector2i(0, 0), level, 0),
		"a surviving seed takes ring 0")
	_check(not lv.has(Vector2i(-4, 0)) and not lv.has(Vector2i(10, 0)),
		"nothing past the radius is stamped")
