extends SceneTree

## SOOT-STAMP selftest (2026-09-22, updated for SOOT-VARY same day) — the rules a
## stamp is made of, in isolation.
##
## Soot stopped being derived: an event stamps a tone per cell once
## (`BlastCalculator`'s SOOT-STAMP block). What this pins is what the rest of the
## system relies on without re-checking: the roll is deterministic and lightens by
## one or two steps or darkens by one (SOOT-VARY "more tones"), the outermost ring
## may drop a cell outright, a tone survives the soot plane's code and back, the
## firearm's ball reaches exactly its radius, the edge offset (SOOT-VARY "irregular
## edge") never pushes a stamp past that radius, and the nearest seed wins. The live
## paths (a real shot and a real blast writing the store and the plane) are measured
## in a real boot, not here.

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


## The roll decides "kept, lightened by one or two steps, or darkened by one"
## (SOOT-VARY "more tones") — plus, at the outermost ring only, "dropped outright".
## The same cell rolls the same way every time. Past the last tone a cell is clean.
func _test_jitter_is_deterministic_and_only_lightens() -> void:
	var clean: int = BlastCalculatorClass.FACE_SOOT_CLEAN
	var bad_step: int = 0
	var unstable: int = 0
	var lightened: int = 0
	var darkened: int = 0
	var two_step: int = 0
	var edge_dropped: int = 0
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
				if a == -1:
					## Either the outermost ring's own drop, or a lighten step that
					## saturated past the last tone (ring+1 or ring+2 == clean) —
					## both are "clean" outcomes, not a bug.
					if ring == clean - 1 or ring >= clean - 2:
						edge_dropped += 1
					else:
						bad_step += 1
					continue
				var delta: int = a - ring
				if delta < -1 or delta > 2 or a < 0 or a >= clean:
					bad_step += 1
				elif delta == 2:
					two_step += 1
					lightened += 1
				elif delta == 1:
					lightened += 1
				elif delta == -1:
					if ring == 0:
						bad_step += 1
					darkened += 1
	_check(unstable == 0, "the roll is deterministic (%d cells rolled twice)" % cells)
	_check(bad_step == 0,
		"a stamped tone is kept, lightened by one/two steps, darkened by one, "
		+ "or (outermost ring only) dropped")
	## Every outcome must actually occur, or the "sorteio" is a constant in disguise.
	_check(lightened > 0 and darkened > 0 and two_step > 0 and edge_dropped > 0
		and lightened < cells,
		"the roll really varies: lightened=%d (of which two-step=%d) darkened=%d edge-dropped=%d of %d"
			% [lightened, two_step, darkened, edge_dropped, cells])
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


## Two seeds: a cell between them takes the NEARER seed's distance (shifted by
## SOOT-VARY 1's per-cell edge offset before the ring is picked), and nothing past
## the radius is written. With no store every cell counts as solid.
func _test_stamp_nearest_seed_wins() -> void:
	var level: int = GeometryCoords.PLAYABLE_LEVEL
	var radius: int = 3
	var seeds: Array = [Vector3i(0, 0, level), Vector3i(6, 0, level)]
	var out: Dictionary = BlastCalculatorClass.stamp_around(seeds, radius, null)
	var lv: Dictionary = out.get(level, {})
	## (4, 0): distance 4 from the first seed, 2 from the second -> best distance 2,
	## then the cell's own edge offset shifts it before the ring is picked.
	var expected_dist: int = 2 + BlastCalculatorClass.soot_edge_offset(Vector2i(4, 0), level)
	var expected_between: int = -1
	if expected_dist >= 0 and expected_dist <= radius:
		expected_between = BlastCalculatorClass.soot_tone(
			Vector2i(4, 0), level, maxi(expected_dist - 1, 0), false)
	var between: int = int(lv.get(Vector2i(4, 0), -1))
	_check(between == expected_between,
		"a cell between two seeds takes the nearer seed's ring, edge-shifted (got %d, expected %d)"
			% [between, expected_between])
	## The seed itself (a dent that survived) is distance 0, edge-shifted the same way.
	var seed_dist: int = 0 + BlastCalculatorClass.soot_edge_offset(Vector2i(0, 0), level)
	var expected_seed: int = -1
	if seed_dist >= 0 and seed_dist <= radius:
		expected_seed = BlastCalculatorClass.soot_tone(
			Vector2i(0, 0), level, maxi(seed_dist - 1, 0), false)
	_check(int(lv.get(Vector2i(0, 0), -2)) == expected_seed,
		"a surviving seed takes ring 0, edge-shifted the same way (got %d, expected %d)"
			% [int(lv.get(Vector2i(0, 0), -2)), expected_seed])
	## Clear of BOTH seeds' balls by more than the edge offset's ±1 range, so no
	## jitter can reach them either.
	_check(not lv.has(Vector2i(-5, 0)) and not lv.has(Vector2i(11, 0)),
		"nothing past both seeds' radius is stamped")
	## SOOT-EDGE — tone 0 only beside a hole; never elsewhere.
	var holes := {Vector3i(20, 0, level): true}
	var edge: Dictionary = BlastCalculatorClass.stamp_around([Vector3i(20, 0, level)], 3, null, holes).get(level, {})
	var zero_away: int = 0
	for c2: Vector2i in edge:
		var adjacent: bool = absi(c2.x - 20) + absi(c2.y) == 1
		if int(edge[c2]) == 0 and not adjacent:
			zero_away += 1
	_check(int(edge.get(Vector2i(21, 0), -1)) == 0 and zero_away == 0,
		"tone 0 lands on a hole's neighbour and nowhere else (%d elsewhere)" % zero_away)
