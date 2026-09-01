## GLASS_MASTER_PLAN §5.4 / G-D16a — GlassFall selftest.
## Rodar: python3 tools/persistent/run_selftests.py --only glass_fall
##
## The whole claim of G-D16a is that ONE rule — fall to the first horizontal
## surface below — produces every case the Director named without a branch per
## case. So the tests are those cases, on the same function, with nothing changing
## but the geometry underneath:
##
##   [1] a pane over bare floor            -> the base pile
##   [2] the same pane over a counter      -> the counter top, not the floor
##   [3] a skylight two storeys up         -> the floor below, a whole storey down
##   [4] glass under glass                 -> falls THROUGH, does not rest on it
##   [5] nothing underneath                -> NO_LANDING, dropped, not faked
##   [6] pile density                      -> a tall column lands as one deep pile

extends SceneTree

const GlassFallClass = preload("res://godot/scripts/systems/destruction/glass_fall.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS G-D16a — SHARD FALL SELFTEST")
	print("=".repeat(70) + "\n")

	test_pane_over_bare_floor_piles_at_the_base()
	test_a_counter_catches_the_shards_before_the_floor()
	test_a_skylight_drops_a_whole_storey()
	test_glass_is_not_a_surface()
	test_nothing_underneath_is_no_landing()
	test_pile_density_counts_every_shard()

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


## One horizontal surface: a real Slab at `level`, covering its GU's 8x8. The Slab
## is RETURNED and the caller keeps it alive — LEAK-CYCLE-01: a Slab owns its
## voxels strongly and they point back weakly, so a fixture that hands out voxels
## without anchoring the Slab frees the whole cluster underneath itself.
func _surface(gu: Vector2i, level: int, material: String, role: int = Slab.Role.FLOOR) -> Slab:
	var slab := Slab.new(Slab.make_id(gu, role, level), gu, role, level, material)
	for vx in range(8):
		for vy in range(8):
			slab.voxels.append(Voxel.new(Vector2i(gu.x * 8 + vx, gu.y * 8 + vy), level, slab))
	return slab


## A column of destroyed glass at one grid_pos, `count` voxels tall from `base`.
func _falling_column(grid_pos: Vector2i, base: int, count: int) -> Array:
	var out: Array = []
	for i in range(count):
		out.append({"grid_pos": grid_pos, "level": base + i})
	return out


func test_pane_over_bare_floor_piles_at_the_base() -> void:
	print("[1] a pane over bare floor — the shards pile at its base\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var floor_slab := _surface(Vector2i(3, 3), ground, "concrete")
	var gp := Vector2i(3 * 8 + 4, 3 * 8 + 4)
	var landings := GlassFallClass.plan_landings(
		_falling_column(gp, GeometryCoords.storey_level_base(0), 24), [floor_slab])

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
	var floor_slab := _surface(Vector2i(3, 3), ground, "concrete")
	var counter := _surface(Vector2i(3, 3), counter_level, "wood", Slab.Role.INTERIOR)
	var gp := Vector2i(3 * 8 + 4, 3 * 8 + 4)

	## Only the glass ABOVE the counter can fall onto it; the rest of the column is
	## below the counter top and lands on the floor. Both halves in one run, since
	## "the nearest surface below" is the whole rule.
	var landings := GlassFallClass.plan_landings(_falling_column(gp, base, 24), [floor_slab, counter])
	var on_counter: int = 0
	var on_floor: int = 0
	for l in landings:
		if int(l["landing_level"]) == counter_level:
			on_counter += 1
		elif int(l["landing_level"]) == ground:
			on_floor += 1
	## The rule is "the highest surface STRICTLY below", so levels base+0..base+5 —
	## including the shard level-with the counter top, which is beside it and not on
	## it — go to the floor: 6, not 5. (The first version of this test asserted 5
	## and was wrong about its own arithmetic, not about the code.) base+6..base+23
	## rest on the counter: 18.
	if on_counter == 18 and on_floor == 6:
		_pass("18 shards rest on the counter at level %d, the 6 at or below it reach the floor" % counter_level)
	else:
		_fail("counter=%d floor=%d (want 18 / 6) — the nearest-surface rule did not split the column"
			% [on_counter, on_floor])
	print("")


func test_a_skylight_drops_a_whole_storey() -> void:
	print("[3] a skylight — the shards fall a whole storey to the floor below\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var floor_slab := _surface(Vector2i(5, 5), ground, "concrete")
	## A horizontal pane in the ceiling of storey 1: two storeys of empty air under it.
	var sky_level: int = GeometryCoords.storey_level_base(2)
	var gp := Vector2i(5 * 8 + 2, 5 * 8 + 6)
	var landings := GlassFallClass.plan_landings([{"grid_pos": gp, "level": sky_level}], [floor_slab])

	if landings.size() == 1 and int(landings[0]["landing_level"]) == ground:
		var drop: int = sky_level - ground
		_pass("a shard from level %d lands at %d — a %d-level drop, no surface invented on the way"
			% [sky_level, ground, drop])
	else:
		_fail("skylight shard did not reach the floor: %s" % [landings])
	print("")


## A shard falling through a skylight must not come to rest on the next pane under
## it — it goes through, the same way a round does (G-D5). If glass counted as a
## surface, a stacked window would catch its own building's shards mid-air.
func test_glass_is_not_a_surface() -> void:
	print("[4] glass is not a surface — a shard falls THROUGH the pane below it\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var base: int = GeometryCoords.storey_level_base(0)
	var floor_slab := _surface(Vector2i(7, 2), ground, "concrete")
	var glass_ledge := _surface(Vector2i(7, 2), base + 4, "glass", Slab.Role.INTERIOR)
	var gp := Vector2i(7 * 8 + 1, 2 * 8 + 1)
	var landings := GlassFallClass.plan_landings(
		[{"grid_pos": gp, "level": base + 20}], [floor_slab, glass_ledge])

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


func test_pile_density_counts_every_shard() -> void:
	print("[6] pile density — a tall column lands as ONE deep pile, not one flat mark\n")
	var ground: int = GeometryCoords.FLOOR_TOP_LEVEL
	var floor_slab := _surface(Vector2i(4, 4), ground, "concrete")
	var gp := Vector2i(4 * 8 + 7, 4 * 8 + 7)
	var landings := GlassFallClass.plan_landings(
		_falling_column(gp, GeometryCoords.storey_level_base(0), 24), [floor_slab])
	var piles := GlassFallClass.pile_by_cell(landings)
	var key := Vector3i(gp.x, gp.y, ground)

	if piles.size() == 1 and int(piles.get(key, 0)) == 24:
		_pass("24 shards from one column resolve to a single cell with density 24")
	else:
		_fail("expected one cell at density 24, got %d cell(s): %s" % [piles.size(), piles])
	print("")
