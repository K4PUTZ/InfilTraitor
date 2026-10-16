## Selftest — SoftSheetSim (ROOF_MASTER_PLAN v0.28): the engine's port of the lab's Projective Dynamics sheet answers the two analytic gates the lab
## was validated on (a clamped strip against the EXACT DISCRETE beam, a hung chain against the catenary), is deterministic, never moves a pinned
## node, never sinks into the floor or a wall, and settles. The reference numbers come from `tools/research/cloth_lab/validate_pd.py`.
extends SceneTree

var passed: int = 0
var failed: int = 0
var _fabric: Dictionary = {"lb": 0.12, "k_stretch": 3000.0, "k_shear": 60.0, "drag": 1.0}


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("SoftSheetSim SELFTEST")
	print("=".repeat(70) + "\n")
	_test_cantilever()
	_test_catenary()
	_test_determinism()
	_test_awning()
	_test_wall()
	_test_group()
	_test_rest_cache()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _pass(m: String) -> void:
	passed += 1
	print("  ✓ " + m)


func _fail(m: String) -> void:
	failed += 1
	print("  ✗ " + m)


func _check(ok: bool, m: String) -> void:
	if ok:
		_pass(m)
	else:
		_fail(m)


## A clamped strip of `n` nodes, 0.5 GU long, `lb` 1 GU, small load: the tip drop against the exact discrete beam (the lab's linear solve of
## the same energy: 0.00705 at 9 nodes, 0.00746 at 17, 0.00764 at 33). The lab's own run at these settings: +6.5% / +2.5% / +1.0%.
## ROOF_MASTER_PLAN v0.43: a VERTICAL sheet (a wall of cloth: `basis_u` along it, `basis_v` DOWN, row 0 its top). Hung from its top row it stays a flat curtain;
## cut loose from all but one corner it falls along its own plane and, because the free nodes start a hair out of plane, FOLDS into a pile on the floor instead of
## staying a line (a perfectly planar sheet cannot buckle: the symmetry hides it); it settles, and nothing goes through the floor.
func _wall_sim(pins: Callable) -> SoftSheetSim:
	var nx: int = 10
	var nz: int = 7
	var p := PackedByteArray()
	p.resize(nx * nz)
	for i in range(nx):
		for j in range(nz):
			p[i * nz + j] = 1 if bool(pins.call(i, j, nx, nz)) else 0
	return SoftSheetSim.new({"nx": nx, "nz": nz, "hx": 3.0 / 9.0, "hz": 1.8 / 6.0, "origin": Vector3(10.0, 1.9, 5.0), "material": _fabric, "pins": p, "floor_y": 0.0,
		"basis_u": Vector3(1, 0, 0), "basis_v": Vector3(0, -1, 0)})


func _test_wall() -> void:
	print("[wall] a vertical sheet: hangs, falls, folds")
	var hung: SoftSheetSim = _wall_sim(func(_i: int, j: int, _nx: int, _nz: int) -> bool: return j == 0)
	var steps: int = hung.settle_now()
	var out_of_plane: float = 0.0
	var drop: float = 0.0
	for node in range(10 * 7):
		out_of_plane = maxf(out_of_plane, absf(hung.pos[node * 3 + 2] - 5.0))
		drop = maxf(drop, 1.9 - hung.pos[node * 3 + 1])
	_check(out_of_plane < 0.05, "hung from its top row it stays a curtain: %.3f GU out of plane after %d step(s)" % [out_of_plane, steps])
	_check(drop > 1.75 and drop < 2.0, "...hanging its whole height: the bottom is %.2f GU below the top (1.80 long, a little stretch)" % drop)
	var sides: SoftSheetSim = _wall_sim(func(i: int, _j: int, nx: int, _nz: int) -> bool: return i == 0 or i == nx - 1)
	sides.settle_now()
	var lowest_mid: float = 9.0
	for j in range(7):
		lowest_mid = minf(lowest_mid, sides.pos[(5 * 7 + j) * 3 + 1])
	_check(lowest_mid >= 0.0, "held only along its two sides it does not go through the floor (lowest middle node %.2f)" % lowest_mid)
	var fall: SoftSheetSim = _wall_sim(func(i: int, j: int, _nx: int, _nz: int) -> bool: return i == 0 and j == 0)
	var guard: int = 0
	while not fall.is_settled() and guard < 600:
		fall.step()
		guard += 1
	var z_lo: float = 99.0
	var z_hi: float = -99.0
	var y_hi: float = -99.0
	var y_lo: float = 99.0
	for node in range(10 * 7):
		z_lo = minf(z_lo, fall.pos[node * 3 + 2])
		z_hi = maxf(z_hi, fall.pos[node * 3 + 2])
		y_hi = maxf(y_hi, fall.pos[node * 3 + 1])
		y_lo = minf(y_lo, fall.pos[node * 3 + 1])
	_check(fall.is_settled() and fall.time < 11.9, "loose but for one corner it settles by itself (%d step(s), %.1f s)" % [guard, fall.time])
	_check(y_lo >= SoftSheetSim.CONTACT_MARGIN - 1.0e-9, "no node under the floor (lowest %.3f)" % y_lo)
	_check(z_hi - z_lo > 0.03, "it FOLDED: the pile is %.2f GU deep out of the wall's plane (a planar fall would stay a line)" % (z_hi - z_lo))


## ROOF_MASTER_PLAN v0.43: cloth touching cloth is SEWN. A roof (a 3 x 2 GU sheet, held on one side only) and a wall that hangs from its free edge: stepped separately the wall
## lets go of the roof's edge and falls to the floor on its own; in a SoftSheetGroup the seam keeps the wall's top row on the roof's rim, so the wall hangs from the roof
## and the roof is held UP by what is sewn to it.
func _test_group() -> void:
	print("[group] a roof and a wall sewn along its edge")
	var rnx: int = 10
	var rnz: int = 7
	var rpins := PackedByteArray()
	rpins.resize(rnx * rnz)
	for j in range(rnz):
		rpins[0 * rnz + j] = 1   ## the roof's x = 10 side is held
	rpins[(rnx - 1) * rnz] = 1   ## and its two far corners (two posts)
	rpins[(rnx - 1) * rnz + rnz - 1] = 1
	var roof := SoftSheetSim.new({"nx": rnx, "nz": rnz, "hx": 3.0 / 9.0, "hz": 2.0 / 6.0, "origin": Vector3(10.0, 2.0, 5.0), "material": _fabric, "pins": rpins, "floor_y": 0.0})
	## the wall hangs from the roof's far edge (x = 13), 3 GU of it, 1.8 GU tall; nothing but the seam holds it
	var wnx: int = 7
	var wnz: int = 7
	var wall := SoftSheetSim.new({"nx": wnx, "nz": wnz, "hx": 2.0 / 6.0, "hz": 1.8 / 6.0, "origin": Vector3(13.0, 2.0, 5.0), "material": _fabric, "pins": PackedByteArray(),
		"floor_y": 0.0, "basis_u": Vector3(0, 0, 1), "basis_v": Vector3(0, -1, 0)})
	var group := SoftSheetGroup.new()
	group.add(roof)
	group.add(wall)
	var n_seams: int = group.sew()
	_check(n_seams >= wnx, "the wall's boundary is sewn to the roof's rim: %d seam node(s)" % n_seams)
	var guard: int = 0
	while not group.is_settled() and guard < 400:
		group.step()
		guard += 1
	var worst_gap: float = 0.0
	for seam: Dictionary in group.seams:
		var pb := Vector3(wall.pos[int(seam["nb"]) * 3], wall.pos[int(seam["nb"]) * 3 + 1], wall.pos[int(seam["nb"]) * 3 + 2])
		var k0 := Vector3(roof.pos[int(seam["k0"]) * 3], roof.pos[int(seam["k0"]) * 3 + 1], roof.pos[int(seam["k0"]) * 3 + 2])
		var k1 := Vector3(roof.pos[int(seam["k1"]) * 3], roof.pos[int(seam["k1"]) * 3 + 1], roof.pos[int(seam["k1"]) * 3 + 2])
		worst_gap = maxf(worst_gap, pb.distance_to(k0.lerp(k1, float(seam["t"]))))
	_check(worst_gap < 0.02, "after %d step(s) every seam is closed to within %.4f GU" % [guard, worst_gap])
	var wall_mid: float = wall.pos[(3 * wnz) * 3 + 1]   ## the middle of the wall's top row, between the roof's two posts
	_check(wall_mid > 0.5, "the wall hangs from the roof's rim: the middle of its top edge is %.2f GU up, not on the floor" % wall_mid)
	## the control: the same two sheets WITHOUT the seam, the wall lets go
	var roof2 := SoftSheetSim.new({"nx": rnx, "nz": rnz, "hx": 3.0 / 9.0, "hz": 2.0 / 6.0, "origin": Vector3(10.0, 2.0, 5.0), "material": _fabric, "pins": rpins.duplicate(), "floor_y": 0.0})
	var wall2 := SoftSheetSim.new({"nx": wnx, "nz": wnz, "hx": 2.0 / 6.0, "hz": 1.8 / 6.0, "origin": Vector3(13.0, 2.0, 5.0), "material": _fabric, "pins": PackedByteArray(),
		"floor_y": 0.0, "basis_u": Vector3(0, 0, 1), "basis_v": Vector3(0, -1, 0)})
	for _k in range(120):
		roof2.step()
		wall2.step()
	_check(wall2.pos[(3 * wnz) * 3 + 1] < 0.5, "control: unsewn, the same wall falls to the floor alone (top edge middle at %.2f GU)" % wall2.pos[(3 * wnz) * 3 + 1])


## ROOF_MASTER_PLAN v0.45: a settled cloth is read back from the cache instead of simulated. The key must change with anything that changes the result (a pin, a material
## number, the grid) and a restored sim must be the settled one, at rest.
func _test_rest_cache() -> void:
	print("[rest cache] the key and the restore")
	var pins := PackedByteArray()
	pins.resize(10 * 7)
	for j in range(7):
		pins[j] = 1
	var params: Dictionary = {"nx": 10, "nz": 7, "hx": 3.0 / 9.0, "hz": 1.8 / 6.0, "origin": Vector3(10.0, 1.9, 5.0), "material": _fabric, "pins": pins, "floor_y": 0.0,
		"basis_u": Vector3(1, 0, 0), "basis_v": Vector3(0, -1, 0)}
	var key: String = SoftSheetRestCache.key_of(params)
	_check(key == SoftSheetRestCache.key_of(params.duplicate(true)), "the same setup has the same key (a key that moved between runs would never hit)")
	var other_pins: PackedByteArray = pins.duplicate()
	other_pins[20] = 1
	var changed: Dictionary = params.duplicate()
	changed["pins"] = other_pins
	_check(key != SoftSheetRestCache.key_of(changed), "one more pinned node is another key")
	var stiffer: Dictionary = params.duplicate()
	stiffer["material"] = {"lb": 0.7, "k_stretch": 3000.0, "k_shear": 600.0, "drag": 1.5}
	_check(key != SoftSheetRestCache.key_of(stiffer), "another material is another key")
	var a := SoftSheetSim.new(params)
	a.settle_now()
	var b := SoftSheetSim.new(params)
	b.restore(a.pos)
	var same: bool = true
	for k in range(a.pos.size()):
		if a.pos[k] != b.pos[k] or b.vel[k] != 0.0:
			same = false
	_check(same, "a restored sim holds the settled positions, with no velocity")


func _test_cantilever() -> void:
	print("[cantilever] a clamped strip vs the exact discrete beam")
	var exact: Dictionary = {9: 0.00705, 17: 0.00746, 33: 0.00764}
	var slack: Dictionary = {9: 0.10, 17: 0.06, 33: 0.04}
	for n: int in [9, 17, 33]:
		var h: float = 0.5 / float(n - 1)
		var pins := PackedByteArray()
		pins.resize(n)
		pins[0] = 1
		pins[1] = 1
		var sim := SoftSheetSim.new({"nx": n, "nz": 1, "hx": h, "hz": h, "origin": Vector3(0.0, 10.0, 0.0),
			"material": {"lb": 1.0, "k_stretch": 3000.0, "k_shear": 0.0, "drag": 6.0}, "pins": pins,
			"dt": 1.0 / 60.0, "iterations": 12, "floor_y": -100.0})
		for _s in range(300):
			sim.step()
		var drop: float = sim.node_position(0, 0).y - sim.node_position(n - 1, 0).y
		var err: float = drop / float(exact[n]) - 1.0
		_check(absf(err) <= float(slack[n]), "%2d nodes: tip drop %.5f vs exact %.5f (%+.1f%%, allowed ±%.0f%%)" % [n, drop, float(exact[n]), err * 100.0, float(slack[n]) * 100.0])


## A 4.0 GU chain pinned at both ends 3.2 GU apart, no bending: the sag against the catenary `2 a sinh(D / 2a) = L` (1.0618 GU).
func _test_catenary() -> void:
	print("[catenary] a hung chain vs the analytic sag")
	var n: int = 33
	var h: float = 4.0 / float(n - 1)
	var pins := PackedByteArray()
	pins.resize(n)
	pins[0] = 1
	pins[n - 1] = 1
	# the pinned end sits 3.2 GU away: the chain is longer than the gap and has to sag
	var start := PackedFloat64Array()
	start.resize(n * 3)
	for i in range(n):
		start[i * 3] = 3.2 * float(i) / float(n - 1)
		start[i * 3 + 1] = 10.0
	var sim := SoftSheetSim.new({"nx": n, "nz": 1, "hx": h, "hz": h, "origin": Vector3(0.0, 10.0, 0.0),
		"material": {"lb": 0.0, "k_stretch": 3000.0, "k_shear": 0.0, "drag": 3.0}, "pins": pins, "initial": start,
		"dt": 1.0 / 60.0, "iterations": 12, "floor_y": -100.0})
	var low: float = 0.0
	for _s in range(480):
		sim.step()
	for i in range(n):
		low = maxf(low, 10.0 - sim.node_position(i, 0).y)
	var analytic: float = 1.0618
	var err: float = low / analytic - 1.0
	_check(absf(err) <= 0.03, "33 nodes: sag %.4f vs analytic %.4f (%+.1f%%, allowed ±3%%; the lab's run: +1.3%%)" % [low, analytic, err * 100.0])


func _awning(extra: Dictionary = {}) -> SoftSheetSim:
	# ROOF_LAB room B's roof, in the lab's own coordinates: gu 15..19 x 6..10, 2 GU up, held on the west edge and the north edge to x = 18,
	# the two back walls as boxes; 13 x 13 nodes, a pinned corner patch (the post)
	var n: int = 13
	var h: float = 4.0 / float(n - 1)
	var pins := PackedByteArray()
	pins.resize(n * n)
	for j in range(n):
		pins[j] = 1
	for i in range(1, n):
		if 15.0 + float(i) * h <= 18.0 + 1.0e-6:
			pins[i * n] = 1
	for i in range(n - 2, n):
		for j in range(n - 2, n):
			pins[i * n + j] = 1
	var p: Dictionary = {"nx": n, "nz": n, "hx": h, "hz": h, "origin": Vector3(15.0, 2.0, 6.0), "material": _fabric, "pins": pins,
		"boxes": [AABB(Vector3(14.0, 0.0, 5.0), Vector3(1.0, 2.0, 5.0)), AABB(Vector3(14.0, 0.0, 5.0), Vector3(4.0, 2.0, 1.0))]}
	p.merge(extra)
	return SoftSheetSim.new(p)


## The same code twice gives the same sheet to the last bit; the pinned nodes do not move; nothing enters the floor or a wall; it settles.
func _test_determinism() -> void:
	print("[determinism / contact] ROOF_LAB's awning, 13 x 13 nodes")
	var a: SoftSheetSim = _awning()
	var b: SoftSheetSim = _awning()
	var held_before: PackedFloat64Array = a.pos.duplicate()
	var floor_ok: bool = true
	var wall_ok: bool = true
	for _s in range(120):
		a.step()
		b.step()
		for node in range(a.nx * a.nz):
			if a.pinned[node] == 1:
				continue
			var y: float = a.pos[node * 3 + 1]
			if y < a.floor_y + SoftSheetSim.CONTACT_MARGIN - 1.0e-9:
				floor_ok = false
			var q := Vector3(a.pos[node * 3], y, a.pos[node * 3 + 2])
			for box: AABB in a._boxes:
				if box.grow(-SoftSheetSim.BOX_MARGIN * 1.5).has_point(q):
					wall_ok = false
	_check(a.pos == b.pos, "two identical sheets are identical after 120 steps (4 s of simulated time)")
	var held_ok: bool = true
	for node in range(a.nx * a.nz):
		if a.pinned[node] == 1:
			for d in range(3):
				if a.pos[node * 3 + d] != held_before[node * 3 + d]:
					held_ok = false
	_check(held_ok, "no pinned node moved")
	_check(floor_ok, "no node sank into the floor")
	_check(wall_ok, "no node entered a wall")
	var finite: bool = true
	for v in a.pos:
		if is_nan(v) or is_inf(v):
			finite = false
	_check(finite, "every coordinate is finite")


## It settles into the lab's pouch: with the corner post, mean height 1.68 (the lab's N=13 at dt 1/30: 1.682; its 33 x 33 reference: 1.646),
## lowest node 1.0-1.25 GU (the reference's 1.03), and it comes to rest.
func _test_awning() -> void:
	print("[awning] fabric with a corner post settles into a pouch")
	var sim: SoftSheetSim = _awning()
	var guard: int = 0
	while not sim.is_settled() and guard < 600:
		sim.step()
		guard += 1
	var mean: float = 0.0
	var low: float = 99.0
	for node in range(sim.nx * sim.nz):
		mean += sim.pos[node * 3 + 1]
		low = minf(low, sim.pos[node * 3 + 1])
	mean /= float(sim.nx * sim.nz)
	_check(sim.is_settled() and guard < 600, "it settled after %d steps (%.1f s simulated)" % [guard, sim.time])
	_check(mean > 1.58 and mean < 1.78, "mean height %.3f GU (lab: 1.682 at N=13, 1.646 at the reference)" % mean)
	_check(low > 0.95 and low < 1.30, "lowest node %.3f GU (lab reference 1.03: a pouch, not the floor)" % low)
