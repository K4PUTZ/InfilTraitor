## Selftest — PropFragmentSim (PROPS_TIER4_PLAN P2): a voxelized prop falls, is carved by the blast, piles up and slumps,
## deterministically and in simulated time. Synthetic table (boxes), no ASSETS needed.
extends SceneTree

var passed: int = 0
var failed: int = 0
var _cells: Array = []
var _zones: PackedInt32Array = PackedInt32Array()
var _voxel: float = 0.125
var _division: int = 1


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("PropFragmentSim SELFTEST")
	print("=".repeat(70) + "\n")
	_fixture()
	_test_determinism()
	_test_carving_by_weight()
	_test_piling_invariants()
	_test_fixed_step_time()
	_test_walls_hold_fragments()
	_test_fine_lattice()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _pass(m: String) -> void:
	passed += 1
	print("  ✓ " + m)


func _fail(m: String) -> void:
	failed += 1
	print("  ✗ " + m)


func _box_part(size: Vector3, centre: Vector3) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size = size
	return {"mesh": mesh, "xf": Transform3D(Basis.IDENTITY, centre)}


func _fixture(division: int = 1) -> void:
	var parts: Array = [_box_part(Vector3(0.95, 0.03, 0.59), Vector3(0.0, 0.68, 0.0))]
	for lx in [-0.42, 0.42]:
		for lz in [-0.24, 0.24]:
			parts.append(_box_part(Vector3(0.05, 0.6, 0.05), Vector3(lx, 0.3, lz)))
	var r: Dictionary = PropVoxelizer.fragment_voxelize(parts, division)
	_cells = r["cells"]
	_zones = r["zones"]
	_voxel = float(r["voxel"])
	_division = int(r["division"])


func _sim(weight: float, seed_text: String = "T1", can_cross: Callable = Callable()) -> PropFragmentSim:
	var p := {"cells": _cells, "zones": _zones, "origin": Vector3(0.5, 0.0, 0.5), "blast": Vector2(2.5, 0.5),
		"weight": weight, "seed": seed_text, "voxel": _voxel}
	if can_cross.is_valid():
		p["can_cross"] = can_cross
	return PropFragmentSim.new(p)


func _run(sim: PropFragmentSim) -> float:
	var guard: int = 0
	while not sim.is_done() and guard < 400:
		sim.advance(1.0 / 60.0)
		guard += 1
	return sim.time


func _test_determinism() -> void:
	print("[1] the same blast gives the same pile; another seed another pile")
	var a := _sim(0.85)
	var b := _sim(0.85)
	var c := _sim(0.85, "T2")
	_run(a)
	_run(b)
	_run(c)
	if a.pile_records() == b.pile_records() and a.pile_records().size() > 0:
		_pass("identical twice (%d fragments in the pile)" % a.pile_records().size())
	else:
		_fail("two runs differ or the pile is empty")
	if a.pile_records() != c.pile_records():
		_pass("a different seed gives a different pile")
	else:
		_fail("a different seed gave the same pile")
	print("")


func _test_carving_by_weight() -> void:
	print("[2] the ring weight decides how many are carved away")
	var n: int = _cells.size()
	var results: Array = []
	for w in [0.0, 0.28, 0.85, 1.0]:
		var s := _sim(w)
		_run(s)
		results.append([w, s.vanished_count(), s.pile_records().size()])
	var ok: bool = true
	for r in results:
		var want: int = int(round(float(r[0]) * float(n)))
		if int(r[1]) != want or int(r[1]) + int(r[2]) != n:
			ok = false
	if ok and int(results[0][1]) == 0 and int(results[3][2]) == 0:
		_pass("weights 0 / 0.28 / 0.85 / 1 carve %s of %d; carved + piled = all" % [str([results[0][1], results[1][1], results[2][1], results[3][1]]), n])
	else:
		_fail("carving wrong: %s (n=%d)" % [str(results), n])
	print("")


## Columns are contiguous from the floor (no gaps, no two cubes in one slot), every cube sits on the lattice, none under the floor.
func _test_piling_invariants() -> void:
	print("[3] the pile: stacked columns, on the lattice, above the floor, done in time")
	var s := _sim(0.6)
	var t: float = _run(s)
	var recs: Array = s.pile_records()
	var by_col: Dictionary = {}
	for r: Dictionary in recs:
		var c: Vector2i = r["column"]
		if not by_col.has(c):
			by_col[c] = []
		by_col[c].append(int(r["level"]))
	var contiguous: bool = true
	var tallest: int = 0
	for c in by_col:
		var lv: Array = by_col[c]
		lv.sort()
		for k in range(lv.size()):
			if int(lv[k]) != k:
				contiguous = false
		tallest = maxi(tallest, lv.size())
	var on_lattice: bool = true
	for i in range(s.count):
		if s.state[i] == PropFragmentSim.State.LANDED:
			var expect_y: float = (float(s.level[i]) + 0.5) * s.voxel
			if absf(s.pos[i].y - expect_y) > 1.0e-4 or s.pos[i].y < 0.0:
				on_lattice = false
	if contiguous and on_lattice and recs.size() > 0:
		_pass("%d cubes in %d columns, tallest %d, contiguous and on the lattice" % [recs.size(), by_col.size(), tallest])
	else:
		_fail("pile invalid: contiguous=%s on_lattice=%s cubes=%d" % [contiguous, on_lattice, recs.size()])
	if t <= 1.6 + 0.02:
		_pass("finished after %.2f s of simulated time (hard cap 1.6 s)" % t)
	else:
		_fail("ran %.2f s" % t)
	print("")


## Simulated time: 60 x 1/60 s and 30 x 1/30 s are the same half second and give the same pile.
func _test_fixed_step_time() -> void:
	print("[4] timed, not counted: the frame rate does not change the result")
	var a := _sim(0.85)
	var b := _sim(0.85)
	for _i in range(40):
		a.advance(1.0 / 60.0)
	for _i in range(20):
		b.advance(1.0 / 30.0)
	var same: bool = absf(a.time - b.time) < 1.0e-6
	for i in range(a.count):
		if a.state[i] != b.state[i] or a.pos[i].distance_to(b.pos[i]) > 1.0e-5:
			same = false
	if same:
		_pass("two-thirds of a second at 60 fps and at 30 fps: identical state")
	else:
		_fail("the frame rate changed the simulation")
	print("")


## A wall between two GUs: nothing ends on the far side of it.
func _test_walls_hold_fragments() -> void:
	print("[5] a wall between two cells stops the fragments")
	var wall_x: int = 1   ## GU x = 1 is the far side; crossing from x = 0 to x = 1 is blocked
	var cross := func(from: Vector2i, to: Vector2i) -> bool:
		return not (from.x == 0 and to.x >= wall_x)
	var s := _sim(0.9, "T1", cross)
	_run(s)
	var beyond: int = 0
	for r: Dictionary in s.pile_records():
		var c: Vector2i = r["column"]
		if c.x >= 8 * _division:   ## board voxel x = 8 is GU x = 1
			beyond += 1
	if beyond == 0 and s.pile_records().size() > 0:
		_pass("no fragment ended beyond the wall (%d in the pile)" % s.pile_records().size())
	else:
		_fail("%d fragments crossed the wall" % beyond)
	print("")


## The same laws on the fragment lattice (1/32 GU): a finer cube changes the count, never the rules.
func _test_fine_lattice() -> void:
	print("[6] the fragment lattice 4x finer: same laws, more and smaller cubes")
	var coarse_count: int = _cells.size()
	_fixture(4)
	if _division == 4 and _cells.size() > coarse_count * 3:
		_pass("%d cubes of 1/32 GU where the board's voxel gave %d" % [_cells.size(), coarse_count])
	else:
		_fail("division %d, %d cubes (was %d)" % [_division, _cells.size(), coarse_count])
	var a := _sim(0.85)
	var b := _sim(0.85)
	_run(a)
	_run(b)
	if a.pile_records() == b.pile_records() and a.pile_records().size() > 0:
		_pass("deterministic (%d cubes in the pile)" % a.pile_records().size())
	else:
		_fail("two runs differ or the pile is empty")
	var n: int = _cells.size()
	if a.vanished_count() == int(round(0.85 * float(n))) and a.vanished_count() + a.pile_records().size() == n:
		_pass("the weight carves %d of %d; carved + piled = all" % [a.vanished_count(), n])
	else:
		_fail("carving wrong: vanished %d, piled %d, n %d" % [a.vanished_count(), a.pile_records().size(), n])
	var by_col: Dictionary = {}
	for r: Dictionary in a.pile_records():
		var c: Vector2i = r["column"]
		if not by_col.has(c):
			by_col[c] = []
		by_col[c].append(int(r["level"]))
	var contiguous: bool = true
	for c in by_col:
		var lv: Array = by_col[c]
		lv.sort()
		for k in range(lv.size()):
			if int(lv[k]) != k:
				contiguous = false
	var on_lattice: bool = true
	for i in range(a.count):
		if a.state[i] == PropFragmentSim.State.LANDED:
			if absf(a.pos[i].y - (float(a.level[i]) + 0.5) * a.voxel) > 1.0e-4:
				on_lattice = false
	if contiguous and on_lattice:
		_pass("the columns are contiguous and every cube sits on the fine lattice")
	else:
		_fail("fine pile invalid: contiguous=%s on_lattice=%s" % [contiguous, on_lattice])
	## Time stays simulated time: the same half second at any frame rate.
	var c60 := _sim(0.85)
	var c30 := _sim(0.85)
	for _i in range(40):
		c60.advance(1.0 / 60.0)
	for _i in range(20):
		c30.advance(1.0 / 30.0)
	var same: bool = absf(c60.time - c30.time) < 1.0e-6
	for i in range(c60.count):
		if c60.state[i] != c30.state[i] or c60.pos[i].distance_to(c30.pos[i]) > 1.0e-5:
			same = false
	if same:
		_pass("60 fps and 30 fps give the same state")
	else:
		_fail("the frame rate changed the fine simulation")
	_fixture(1)
	print("")

