## GLASS_MASTER_PLAN §5.4 / §18.5 — GlassFall selftest.
## Rodar: python3 tools/persistent/run_selftests.py --only glass_fall
##
## G-D16a's claim is that ONE rule — fall to the first horizontal surface below —
## produces every case the Director named without a branch per case. G4-4 adds a
## second: the shard first SCATTERS a few cells from its own column (G-D41), and a
## grenade's shockwave BIASES that scatter downrange (G-D42). So the tests are
## those cases, on the same function, with nothing changing but the geometry
## underneath and the `impulse` on top:
##
##   [1] a pane over bare floor            -> the base pile, count preserved
##   [2] the same pane over a counter      -> the counter top, not the floor
##   [3] a skylight two storeys up         -> the floor below, a whole storey down
##   [4] glass under glass                 -> falls THROUGH, does not rest on it
##   [5] nothing underneath                -> NO_LANDING, dropped, not faked
##   [6] scatter conserves and concentrates -> 24 shards, a band near the column
##   [7] the scatter shape                 -> mostly 0, a tail to 3, never past it
##   [8] the shockwave biases downrange    -> the mean shifts, some clear the tail
##   [9] lift widens the scatter           -> SYNTHETIC, no real map exercises it
##  [10] determinism                       -> two identical plans, byte for byte

extends SceneTree

const GlassFallClass = preload("res://godot/scripts/systems/destruction/glass_fall.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS G-D16a / G4-4 — SHARD FALL + SCATTER SELFTEST")
	print("=".repeat(70) + "\n")

	test_pane_over_bare_floor_piles_at_the_base()
	test_a_counter_catches_the_shards_before_the_floor()
	test_a_skylight_drops_a_whole_storey()
	test_glass_is_not_a_surface()
	test_nothing_underneath_is_no_landing()
	test_scatter_conserves_and_concentrates()
	test_the_scatter_shape()
	test_the_shockwave_biases_downrange()
	test_lift_widens_the_scatter()
	test_determinism()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ GLASS FALL SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ GLASS FALL SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## One horizontal surface at `level` covering a (2*radius_gu+1)² block of GUs
## centred on `center_gu`. G4-4's scatter reaches SCATTER_MAX_CELLS cells past the
## pane's own column, so a one-GU fixture would drop shards off its own edge and
## make a test about the FALL rule fail for a reason that is not the fall rule.
##
## The Slabs are RETURNED and the caller keeps them alive — LEAK-CYCLE-01: a Slab
## owns its voxels strongly and they point back weakly, so a fixture that hands out
## voxels without anchoring the Slab frees the whole cluster underneath itself.
func _surfaces(center_gu: Vector2i, level: int, material: String,
		role: int = Slab.Role.FLOOR, radius_gu: int = 1) -> Array:
	var out: Array = []
	for gx in range(center_gu.x - radius_gu, center_gu.x + radius_gu + 1):
		for gy in range(center_gu.y - radius_gu, center_gu.y + radius_gu + 1):
			var gu := Vector2i(gx, gy)
			var slab := Slab.new(Slab.make_id(gu, role, level), gu, role, level, material)
			for vx in range(8):
				for vy in range(8):
					slab.voxels.append(Voxel.new(Vector2i(gu.x * 8 + vx, gu.y * 8 + vy), level, slab))
			out.append(slab)
	return out


## A column of destroyed glass at one grid_pos, `count` voxels tall from `base`.
func _falling_column(grid_pos: Vector2i, base: int, count: int) -> Array:
	var out: Array = []
	for i in range(count):
		out.append({"grid_pos": grid_pos, "level": base + i})
	return out


func test_pane_over_bare_floor_piles_at_the_base() -> void:
	print("[1] a pane over bare floor — every shard lands, all on the floor\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var slabs := _surfaces(Vector2i(3, 3), ground, "concrete")
	var gp := Vector2i(3 * 8 + 4, 3 * 8 + 4)
	var landings := GlassFallClass.plan_landings(
		_falling_column(gp, GeometryCoords.storey_level_base(0), 24), slabs)

	var all_on_floor: bool = landings.size() == 24
	for l in landings:
		if int(l["landing_level"]) != ground:
			all_on_floor = false
	if all_on_floor:
		_pass("all 24 shards of a 3-storey column land on the floor at level %d" % ground)
	else:
		_fail("expected 24 landings all at level %d, got %d landings" % [ground, landings.size()])
	print("")


func test_a_counter_catches_the_shards_before_the_floor() -> void:
	print("[2] the SAME pane over a counter — the counter catches them, not the floor\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var base: int = GeometryCoords.storey_level_base(0)
	var counter_level: int = base + 5
	var slabs := _surfaces(Vector2i(3, 3), ground, "concrete")
	slabs.append_array(_surfaces(Vector2i(3, 3), counter_level, "wood", Slab.Role.INTERIOR))
	var gp := Vector2i(3 * 8 + 4, 3 * 8 + 4)

	## The split is by `from_level` vs the counter top, not by grid_pos, so the
	## scatter does not move it: levels base+0..base+5 (6) reach the floor,
	## base+6..base+23 (18) rest on the counter.
	var landings := GlassFallClass.plan_landings(_falling_column(gp, base, 24), slabs)
	var on_counter: int = 0
	var on_floor: int = 0
	for l in landings:
		if int(l["landing_level"]) == counter_level:
			on_counter += 1
		elif int(l["landing_level"]) == ground:
			on_floor += 1
	if on_counter == 18 and on_floor == 6:
		_pass("18 shards rest on the counter at level %d, the 6 at or below it reach the floor" % counter_level)
	else:
		_fail("counter=%d floor=%d (want 18 / 6) — the nearest-surface rule did not split the column"
			% [on_counter, on_floor])
	print("")


func test_a_skylight_drops_a_whole_storey() -> void:
	print("[3] a skylight — the shard falls a whole storey to the floor below\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var slabs := _surfaces(Vector2i(5, 5), ground, "concrete")
	var sky_level: int = GeometryCoords.storey_level_base(2)
	var gp := Vector2i(5 * 8 + 2, 5 * 8 + 6)
	var landings := GlassFallClass.plan_landings([{"grid_pos": gp, "level": sky_level}], slabs)

	if landings.size() == 1 and int(landings[0]["landing_level"]) == ground:
		var drop: int = sky_level - ground
		_pass("a shard from level %d lands at %d — a %d-level drop, no surface invented on the way"
			% [sky_level, ground, drop])
	else:
		_fail("skylight shard did not reach the floor: %s" % [landings])
	print("")


## A shard falling through a skylight must not come to rest on the next pane under
## it — it goes through, the same way a round does (G-D5).
func test_glass_is_not_a_surface() -> void:
	print("[4] glass is not a surface — a shard falls THROUGH the pane below it\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var base: int = GeometryCoords.storey_level_base(0)
	var slabs := _surfaces(Vector2i(7, 2), ground, "concrete")
	slabs.append_array(_surfaces(Vector2i(7, 2), base + 4, "glass", Slab.Role.INTERIOR))
	var gp := Vector2i(7 * 8 + 1, 2 * 8 + 1)
	var landings := GlassFallClass.plan_landings(
		[{"grid_pos": gp, "level": base + 20}], slabs)

	if landings.size() == 1 and int(landings[0]["landing_level"]) == ground:
		_pass("the shard passed the glass ledge at level %d and landed on the floor" % (base + 4))
	else:
		_fail("a glass ledge caught the shard: %s" % [landings])
	print("")


func test_nothing_underneath_is_no_landing() -> void:
	print("[5] nothing underneath — dropped, never a landing invented at level 0\n")
	var gp := Vector2i(9 * 8 + 3, 9 * 8 + 3)
	var landings := GlassFallClass.plan_landings(
		[{"grid_pos": gp, "level": GeometryCoords.storey_level_base(0) + 6}], [])
	var direct: int = GlassFallClass.landing_level(gp, GeometryCoords.storey_level_base(0), {})

	if landings.is_empty() and direct == GlassFallClass.NO_LANDING:
		_pass("an empty column yields no landing at all (NO_LANDING = %d), not a fake one at 0"
			% GlassFallClass.NO_LANDING)
	else:
		_fail("expected zero landings and NO_LANDING, got %d landing(s) and level %d"
			% [landings.size(), direct])
	print("")


## G4-4 replaces the old "one column -> one deep pile" assertion: the pile is now
## a BAND, but the scatter must not lose a shard and must not fling one across the
## room. So: count preserved, every landing within the tail of its own column, and
## the origin column still the single densest cell.
func test_scatter_conserves_and_concentrates() -> void:
	print("[6] scatter conserves the shard count and concentrates it near the column\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var slabs := _surfaces(Vector2i(4, 4), ground, "concrete", Slab.Role.FLOOR, 1)
	var gp := Vector2i(4 * 8 + 4, 4 * 8 + 4)
	var landings := GlassFallClass.plan_landings(
		_falling_column(gp, GeometryCoords.storey_level_base(0), 24), slabs)
	var piles := GlassFallClass.pile_by_cell(landings)

	var conserved: bool = landings.size() == 24
	var within_tail: bool = true
	var total: int = 0
	var core: int = 0            ## shards within Chebyshev 1 of the column
	var on_column: int = 0
	for key in piles:
		var k: Vector3i = key
		var c: int = int(piles[key])
		total += c
		var cheb: int = maxi(absi(k.x - gp.x), absi(k.y - gp.y))
		if cheb > GlassFallClass.scatter_max_cells():
			within_tail = false
		if cheb <= 1:
			core += c
		if k.x == gp.x and k.y == gp.y:
			on_column = c

	var spread: bool = piles.size() > 1     ## it is a band, not a line
	var concentrated: bool = core >= 15      ## the near cells hold the strong majority
	var column_real: bool = on_column >= 4

	if conserved and within_tail and total == 24 and spread and concentrated and column_real:
		_pass("24 shards -> %d cells, all within %d, %d in the 3x3 core (%d on the column itself)"
			% [piles.size(), GlassFallClass.scatter_max_cells(), core, on_column])
	else:
		_fail("conserved=%s within_tail=%s total=%d spread=%s core=%d on_column=%d"
			% [conserved, within_tail, total, spread, core, on_column])
	print("")


## Draw a large population off distinct hashes (one src, many `from_level`s) and
## tally the per-axis offset magnitude. Zero impulse.
func _offset_histogram(samples: int, impulse: Dictionary) -> Dictionary:
	var src := Vector2i(20, 20)
	var hist: Dictionary = {}
	var sum_x: float = 0.0
	var beyond_tail: int = 0
	for i in range(samples):
		var t: Vector2i = GlassFallClass.scatter_target(src, i, impulse)
		var dx: int = t.x - src.x
		var dy: int = t.y - src.y
		sum_x += float(dx)
		for d in [dx, dy]:
			hist[absi(d)] = int(hist.get(absi(d), 0)) + 1
		if maxi(absi(dx), absi(dy)) > GlassFallClass.scatter_max_cells():
			beyond_tail += 1
	return {"hist": hist, "mean_x": sum_x / float(samples), "beyond_tail": beyond_tail}


func test_the_scatter_shape() -> void:
	print("[7] the scatter shape — mostly on the column, a tail to 3, never past it\n")
	var r := _offset_histogram(2000, {})
	var hist: Dictionary = r["hist"]
	var n0: int = int(hist.get(0, 0))
	var n1: int = int(hist.get(1, 0))
	var n2: int = int(hist.get(2, 0))
	var n3: int = int(hist.get(3, 0))
	var n_over: int = int(hist.get(4, 0)) + int(hist.get(5, 0)) + int(hist.get(6, 0))

	## The distribution is monotone decreasing, 3 is present but rarest, and with
	## no impulse NOTHING escapes the tail.
	var monotone: bool = n0 > n1 and n1 > n2 and n2 > n3
	var tail_present: bool = n3 > 0
	var capped: bool = n_over == 0 and int(r["beyond_tail"]) == 0
	var symmetric: bool = absf(float(r["mean_x"])) < 0.15   ## zero impulse -> centred

	if monotone and tail_present and capped and symmetric:
		_pass("per-axis magnitudes 0/1/2/3 = %d/%d/%d/%d, none past %d, mean %.3f"
			% [n0, n1, n2, n3, GlassFallClass.scatter_max_cells(), r["mean_x"]])
	else:
		_fail("monotone=%s tail=%s capped=%s symmetric=%s (0/1/2/3 = %d/%d/%d/%d, over=%d, mean_x=%.3f)"
			% [monotone, tail_present, capped, symmetric, n0, n1, n2, n3, n_over, r["mean_x"]])
	print("")


func test_the_shockwave_biases_downrange() -> void:
	print("[8] the shockwave — the band's mean shifts downrange, some shards clear the tail\n")
	var base := _offset_histogram(2000, {})
	var pushed := _offset_histogram(2000, {"dir": Vector2(1, 0), "strength": 1.0, "lift": 0.0})

	## A grenade to the WEST of the pane throws the pile EAST: the mean X offset
	## goes clearly positive, and — the only term allowed past SCATTER_MAX_CELLS —
	## some shards land beyond it.
	var shifted: bool = float(pushed["mean_x"]) > float(base["mean_x"]) + 1.0
	var reaches_further: bool = int(pushed["beyond_tail"]) > 0
	var base_did_not: bool = int(base["beyond_tail"]) == 0

	if shifted and reaches_further and base_did_not:
		_pass("mean X offset %.2f -> %.2f under a unit impulse, %d shard(s) past the symmetric tail"
			% [base["mean_x"], pushed["mean_x"], pushed["beyond_tail"]])
	else:
		_fail("shifted=%s reaches_further=%s base_clean=%s (mean %.2f -> %.2f, beyond %d -> %d)"
			% [shifted, reaches_further, base_did_not, base["mean_x"], pushed["mean_x"],
			base["beyond_tail"], pushed["beyond_tail"]])
	print("")


## ⚠️ SYNTHETIC. `lift` is authored for skylights and NO REAL MAP EXERCISES IT:
## G-D16c/d is unbuilt, CEILING glass renders opaque and has no `pane_id`, so a
## skylight cannot shatter yet (§18.5). This proves the term does what it says so
## it does not rot into a fourth built-but-never-triggered feature.
func test_lift_widens_the_scatter() -> void:
	print("[9] lift widens the scatter — SYNTHETIC, skylights only (G-D16c/d unbuilt)\n")
	var src := Vector2i(20, 20)
	var flat: float = 0.0
	var lifted: float = 0.0
	for i in range(2000):
		var a: Vector2i = GlassFallClass.scatter_target(src, i, {})
		var b: Vector2i = GlassFallClass.scatter_target(src, i, {"dir": Vector2.ZERO, "strength": 0.0, "lift": 1.0})
		flat += Vector2(a - src).length()
		lifted += Vector2(b - src).length()
	var flat_mean: float = flat / 2000.0
	var lifted_mean: float = lifted / 2000.0

	if lifted_mean > flat_mean * 1.25:
		_pass("mean radius %.2f -> %.2f with lift 1.0 (>25%% wider) — the toss lands the shards wider"
			% [flat_mean, lifted_mean])
	else:
		_fail("lift did not widen the scatter enough: mean radius %.2f -> %.2f" % [flat_mean, lifted_mean])
	print("")


func test_determinism() -> void:
	print("[10] determinism — the same plan twice is byte for byte identical\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var slabs_a := _surfaces(Vector2i(6, 6), ground, "concrete")
	var slabs_b := _surfaces(Vector2i(6, 6), ground, "concrete")
	var col := _falling_column(Vector2i(6 * 8 + 3, 6 * 8 + 5), GeometryCoords.storey_level_base(0), 24)
	var imp := {"dir": Vector2(-2, 1), "strength": 0.6, "lift": 0.0}
	var a := GlassFallClass.plan_landings(col.duplicate(true), slabs_a, imp.duplicate(true))
	var b := GlassFallClass.plan_landings(col.duplicate(true), slabs_b, imp.duplicate(true))

	var same: bool = a.size() == b.size()
	if same:
		for i in range(a.size()):
			if a[i]["grid_pos"] != b[i]["grid_pos"] or int(a[i]["landing_level"]) != int(b[i]["landing_level"]) \
					or a[i]["origin_pos"] != b[i]["origin_pos"]:
				same = false
				break
	if same:
		_pass("two independent runs of one impulse plan produced %d identical landings" % a.size())
	else:
		_fail("the plan is not deterministic: %d vs %d landings, or a row differs" % [a.size(), b.size()])
	print("")
