## DESTRUCTION_MASTER_PLAN Part 3 — BlastCalculator selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/blast_calculator_selftest.gd
##
## Synthetic fixtures only (SliceGenerator/SlabGenerator against a hand-built
## Edge list), same discipline as roof_slab_selftest.gd/slab_render_selftest.gd
## — no real map involved. Real-map end-to-end proof is the screenshot
## captures (INFILTRAITOR_CAPTURE_ACTION=test_zone_menu/test_zone_detonate).

extends SceneTree

const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")
const BombDefClass = preload("res://godot/scripts/systems/destruction/bomb_def.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION Part 3 — BlastCalculator SELFTEST")
	print("=".repeat(70) + "\n")

	test_flood_unobstructed_rings()
	test_flood_stops_at_blocked_edge()
	test_flood_capped_at_bomb_range()
	test_affected_slice_on_source_gu_boundary()
	test_deterministic_selection_is_stable()
	test_deterministic_selection_differs_by_salt_and_container()
	test_metal_container_produces_cracked_not_destroyed()
	test_wood_container_mostly_destroyed_at_ring_zero()
	test_ring_beyond_range_untouched()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ BLAST CALCULATOR SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ BLAST CALCULATOR SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func _test_bomb(ring_multipliers: Array) -> BombDefClass:
	var bomb := BombDefClass.new()
	bomb.id = "test_bomb"
	bomb.ring_multipliers = []
	for m in ring_multipliers:
		bomb.ring_multipliers.append(float(m))
	return bomb


## Open floor, no walls: ring index must equal Manhattan-ish BFS distance
## exactly (4-directional, one step per ring).
func test_flood_unobstructed_rings() -> void:
	print("[1] Unobstructed flood — ring index matches BFS distance\n")

	var bomb := _test_bomb([1.0, 0.7, 0.35, 0.1])
	var rings := BlastCalculatorClass.flood_gu_rings(Vector2i(10, 10), bomb, {})

	var all_ok := true
	var checks := {
		Vector2i(10, 10): 0,
		Vector2i(11, 10): 1,
		Vector2i(10, 11): 1,
		Vector2i(12, 10): 2,
		Vector2i(9, 8): 3,   # |9-10|+|8-10| = 1+2 = 3
	}
	for cell in checks:
		var expected: int = checks[cell]
		if not rings.has(cell) or rings[cell] != expected:
			all_ok = false
			_fail("cell %s: expected ring %d, got %s" % [cell, expected, rings.get(cell, "MISSING")])

	if all_ok:
		_pass("All 5 sampled cells match expected BFS ring distance")
	print("")


## A blocked edge between the source and a neighbor must prevent that
## neighbor from being reached DIRECTLY (ring 1) — Director's confirmed
## decision: walls block/reduce. Only the one edge is blocked, so a longer
## detour around it is legitimate (same partial-blocking model
## movement_overlay.gd already uses) — a 1-ring bomb makes that 3-step
## detour unreachable regardless, keeping the assertion unambiguous.
func test_flood_stops_at_blocked_edge() -> void:
	print("[2] Wall-blocked edge stops the flood (Director: walls block/reduce)\n")

	var bomb := _test_bomb([1.0, 0.5])  # max_ring=1: too short for any detour
	var source := Vector2i(5, 5)
	var blocked_neighbor := source + Vector2i(1, 0)
	var blocked: Dictionary = {WallEdgeData.edge_key(source, blocked_neighbor): true}

	var rings := BlastCalculatorClass.flood_gu_rings(source, bomb, blocked)

	if rings.has(blocked_neighbor):
		_fail("Blocked neighbor %s was reached anyway" % blocked_neighbor)
	else:
		_pass("Blocked neighbor %s correctly excluded from the flood" % blocked_neighbor)

	# The other 3 open sides must still flood normally.
	var open_neighbor := source + Vector2i(-1, 0)
	if rings.get(open_neighbor, -1) == 1:
		_pass("Open neighbor %s on the unblocked side still reached at ring 1" % open_neighbor)
	else:
		_fail("Open neighbor %s should be ring 1, got %s" % [open_neighbor, rings.get(open_neighbor, "MISSING")])
	print("")


## ring_multipliers.size()-1 IS the max ring — nothing beyond it should ever
## appear in the flood, regardless of how open the map is.
func test_flood_capped_at_bomb_range() -> void:
	print("[3] Flood capped at bomb range (ring_multipliers.size()-1)\n")

	var bomb := _test_bomb([1.0, 0.5])  # max_ring = 1
	var rings := BlastCalculatorClass.flood_gu_rings(Vector2i(0, 0), bomb, {})

	var max_ring_seen := 0
	for cell in rings:
		max_ring_seen = maxi(max_ring_seen, rings[cell])

	if max_ring_seen == 1:
		_pass("2-ring bomb (multipliers.size()=2) never floods past ring 1 (saw max %d)" % max_ring_seen)
	else:
		_fail("Expected max ring 1, saw %d" % max_ring_seen)
	print("")


## A Slice sitting on the source GU's own boundary must be picked up at
## ring 0 — the case a real grenade "in front of a wall" always hits.
func test_affected_slice_on_source_gu_boundary() -> void:
	print("[4] Slice on the source GU's own boundary is affected at ring 0\n")

	var registry := EdgeRegistry.new()
	var edges: Array = [
		Edge.between(Vector2i(3, 3), Vector2i(4, 3), 1, "concrete"),
	]
	SliceGenerator.generate(edges, registry)

	var bomb := _test_bomb([1.0, 0.5])
	var rings := BlastCalculatorClass.flood_gu_rings(Vector2i(3, 3), bomb, {})
	var affected := BlastCalculatorClass.find_affected_containers(rings, registry, SlabRegistry.new())

	var found_ring0 := false
	for slice_id in affected["slices"]:
		if affected["slices"][slice_id] == 0:
			found_ring0 = true
	if found_ring0:
		_pass("At least one Slice on gu (3,3) resolved at ring 0")
	else:
		_fail("No ring-0 Slice found; affected.slices = %s" % [affected["slices"]])
	print("")


## D4/B4's determinism guarantee, generalized from "pick 1 of 8" to "pick
## top N of M": same inputs must always produce the same subset.
func test_deterministic_selection_is_stable() -> void:
	print("[5] _select_deterministic — same inputs always produce the same subset\n")

	var voxels := _synthetic_voxels(20)
	var first := BlastCalculatorClass._select_deterministic(voxels, "SLICE_A", "DESTROY", 5)
	var second := BlastCalculatorClass._select_deterministic(voxels, "SLICE_A", "DESTROY", 5)

	var same := first.size() == second.size()
	if same:
		for i in range(first.size()):
			if first[i] != second[i]:
				same = false
				break

	if same and first.size() == 5:
		_pass("Two calls with identical inputs returned the identical 5-voxel subset")
	else:
		_fail("Repeated calls diverged or wrong size (first=%d, second=%d)" % [first.size(), second.size()])
	print("")


## A different salt (DESTROY vs CRACK) or a different container_id must be
## able to select a different subset — otherwise the hash isn't actually
## reading its inputs.
func test_deterministic_selection_differs_by_salt_and_container() -> void:
	print("[6] _select_deterministic — different salt/container_id can select a different subset\n")

	var voxels := _synthetic_voxels(20)
	var destroy_set := BlastCalculatorClass._select_deterministic(voxels, "SLICE_A", "DESTROY", 5)
	var crack_set := BlastCalculatorClass._select_deterministic(voxels, "SLICE_A", "CRACK", 5)
	var other_container := BlastCalculatorClass._select_deterministic(voxels, "SLICE_B", "DESTROY", 5)

	if _same_voxel_set(destroy_set, crack_set):
		_fail("DESTROY and CRACK salts produced the identical subset — hash ignores salt")
	else:
		_pass("DESTROY and CRACK salts produced different subsets")

	if _same_voxel_set(destroy_set, other_container):
		_fail("SLICE_A and SLICE_B produced the identical subset — hash ignores container_id")
	else:
		_pass("Different container_id produced a different subset")
	print("")


## Director (this session): metal is "praticamente não afetado, mas pode ser
## distorcido" — MaterialResistanceTable gives metal destroy_factor=0.05,
## crack_factor=0.6, so at ring 0 (multiplier 1.0) a 64-voxel group should
## produce ~3 DESTROYED and ~38 CRACKED, not the reverse.
func test_metal_container_produces_cracked_not_destroyed() -> void:
	print("[7] Metal container: mostly CRACKED, barely any DESTROYED\n")

	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(0, 0), Vector2i(1, 0), 1, "metal")]
	SliceGenerator.generate(edges, registry)
	var slice: Slice = registry.get_slice("SLICE_0_0_SE")
	if slice == null:
		_fail("Could not resolve synthetic metal Slice (id lookup mismatch — check Face/Edge canon)")
		print("")
		return

	BlastCalculatorClass.apply_container_damage(
		slice.voxels, slice.id, "metal", 0, 0, false, [1.0, 0.5])

	var destroyed := 0
	var cracked := 0
	for voxel in slice.voxels:
		if voxel.damage_state == Voxel.DamageState.DESTROYED:
			destroyed += 1
		elif voxel.damage_state == Voxel.DamageState.CRACKED:
			cracked += 1

	if cracked > destroyed and destroyed <= 6:
		_pass("Metal slice: %d CRACKED > %d DESTROYED (out of %d voxels) — matches 'barely affected, distorted'" %
			[cracked, destroyed, slice.voxels.size()])
	else:
		_fail("Metal slice: %d CRACKED, %d DESTROYED (out of %d) — expected mostly CRACKED, little DESTROYED" %
			[cracked, destroyed, slice.voxels.size()])
	print("")


## Director: wood is "quase toda destruída" — destroy_factor=0.9 at ring 0
## should destroy the large majority of a wood container's voxels.
func test_wood_container_mostly_destroyed_at_ring_zero() -> void:
	print("[8] Wood container at ring 0: large majority DESTROYED\n")

	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(0, 0), Vector2i(1, 0), 1, "wood")]
	SliceGenerator.generate(edges, registry)
	var slice: Slice = registry.get_slice("SLICE_0_0_SE")
	if slice == null:
		_fail("Could not resolve synthetic wood Slice")
		print("")
		return

	BlastCalculatorClass.apply_container_damage(
		slice.voxels, slice.id, "wood", 0, 0, false, [1.0, 0.5])

	var destroyed := 0
	for voxel in slice.voxels:
		if voxel.damage_state == Voxel.DamageState.DESTROYED:
			destroyed += 1

	var ratio := float(destroyed) / float(slice.voxels.size())
	if ratio >= 0.7:
		_pass("Wood slice: %d/%d voxels DESTROYED (%.0f%%) — matches 'quase toda destruída'" %
			[destroyed, slice.voxels.size(), ratio * 100.0])
	else:
		_fail("Wood slice: only %d/%d voxels DESTROYED (%.0f%%), expected >=70%%" %
			[destroyed, slice.voxels.size(), ratio * 100.0])
	print("")


## A ring index >= ring_multipliers.size() must be skipped entirely — a
## voxel group beyond the bomb's own range takes zero damage, not
## clamped-to-last-ring damage.
func test_ring_beyond_range_untouched() -> void:
	print("[9] Voxel group beyond bomb range takes zero damage\n")

	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(0, 0), Vector2i(1, 0), 3, "wood")]  # 3 storeys tall
	SliceGenerator.generate(edges, registry)
	var slice: Slice = registry.get_slice("SLICE_0_0_SE")

	# base_ring=0, is_roof=false -> storey 0 is ring 0, storey 2 is ring 2.
	# Bomb only has rings [1.0] (max_ring=0) -> everything above storey 0 must
	# be skipped entirely (still INTACT), not clamped to ring 0's multiplier.
	BlastCalculatorClass.apply_container_damage(
		slice.voxels, slice.id, "wood", 0, 0, false, [1.0])

	var top_storey_touched := false
	for voxel in slice.voxels:
		if voxel.level >= 2 * GeometryCoords.LEVELS_PER_STOREY and voxel.damage_state != Voxel.DamageState.INTACT:
			top_storey_touched = true

	if top_storey_touched:
		_fail("A voxel beyond the bomb's own ring range was damaged")
	else:
		_pass("Voxels beyond ring_multipliers.size() stayed INTACT (out-of-range, not clamped)")
	print("")


func _synthetic_voxels(count: int) -> Array:
	var voxels: Array = []
	var slab := Slab.new("DUMMY", Vector2i.ZERO, Slab.Role.FLOOR, -1, "earth")
	for i in range(count):
		voxels.append(Voxel.new(Vector2i(i, 0), i, slab))
	return voxels


func _same_voxel_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for v in a:
		if not b.has(v):
			return false
	return true
