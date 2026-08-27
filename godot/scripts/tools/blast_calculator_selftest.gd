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
const BombRegistryClass = preload("res://godot/scripts/systems/destruction/bomb_registry.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")
const VoxelClass = preload("res://godot/scripts/geometry/voxel.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")

var passed: int = 0
var failed: int = 0

## LEAK-CYCLE-01: anchors every Slab handed out by _synthetic_voxels(), which
## returns the voxels and not their container. Voxel holds its container by
## instance id now, so nothing else here would keep these alive and the first
## set_damage() would hit a freed container. Production has the same
## requirement and already meets it — SlabRegistry owns real Slabs, EdgeRegistry
## owns real Slices — so this array is the fixture's stand-in for the registry,
## not a workaround. Before the fix the container survived only because the
## cycle made it immortal, which is exactly the bug.
var _fixture_slabs: Array = []


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
	test_damage_tiers_are_mutually_exclusive()
	test_wood_container_mostly_destroyed_at_ring_zero()
	test_ring_beyond_range_untouched()
	test_soot_rings_spread_by_distance()
	test_soot_min_ring_wins_between_two_holes()
	test_face_soot_points_at_the_hole()
	test_face_soot_merges_at_a_corner()
	test_face_soot_leaves_isotropic_result_untouched()
	test_crater_core_solid_rim_ragged_beyond_intact()
	## FLOOR-DENT-01 (2026-08-01) — crater-rim survivors dent, prevalence from
	## the product of material dent_factor × bomb radii × distance.
	test_crater_dents_rim_and_band_by_material()
	test_bias_prefers_epicenter_facing_side()
	test_no_bias_sentinel_keeps_hash_only_behavior()
	## WEAPON_MASTER_PLAN D1 / DESTRUCTION Part 5 — the CONE shape.
	test_cone_is_directional_not_radial()
	test_cone_widens_with_distance()
	test_cone_respects_range_and_half_angle()
	test_cone_stops_at_blocked_edge()
	## 2026-08-01 — floods must honor solid GU blocks (blocked_cells), the same
	## gap the pellet walker closed on 2026-07-30. Flagged open 2026-07-30.
	test_flood_rings_stops_at_solid_block()
	test_flood_cone_stops_at_solid_block()
	test_cone_output_shape_matches_rings()
	test_destroy_multiplier_scales_damage()
	## WEAPON_MASTER_PLAN D26-D28 (2026-07-30) — per-projectile point impact.
	test_pellet_impacts_no_hard_range_cap()
	test_pellet_impacts_count_matches_projectile_count()
	test_pellet_does_not_detour_around_narrow_obstacle()
	test_point_impact_marks_only_the_impact_voxel()
	test_point_impact_neighbour_ladder()
	test_point_impact_cascades_only_on_full_destroy()
	test_point_impact_never_re_marks_an_existing_hole()
	test_punch_coefficient_ordering()
	test_no_shipped_weapon_reaches_the_cascade()
	test_line_impact_is_straight_and_measures_distance()
	test_aim_offset_steers_the_shot_off_axis()
	test_cone_spread_is_a_disc_not_a_line()
	test_pellet_selection_is_deterministic()
	## DESTRUCTION_MASTER_PLAN D25 (2026-07-31) — carved half-voxels.
	test_carved_side_faces_the_blast()
	test_carved_side_survives_rotation()
	## D33-SOOT-01 (2026-08-03) — a faint touch of soot on a DENTED/CRACKED
	## voxel's own struck face, even nowhere near an actual hole.
	test_self_soot_faces_dented_lateral_sides()
	test_self_soot_faces_dented_top_and_bottom()
	test_self_soot_faces_cracked_blast_hits_all_three()
	test_self_soot_faces_cracked_bullet_no_side_falls_back_to_top()
	test_self_soot_faces_intact_and_destroyed_get_none()
	test_apply_self_soot_fills_in_when_nothing_stronger_exists()
	test_apply_self_soot_never_weakens_an_existing_stronger_ring()
	## EXPLOSION_REBUILD_MASTER_PLAN Task 2 (E-RING, 2026-08-06) — 4th ring,
	## D14 spherical falloff, D2 two-layer floor, D17 slab-pierce multiplier.
	test_ring3_reached_but_zero_weighted()
	test_vertical_falloff_identical_for_wall_and_roof()
	test_roof_two_levels_same_ring_group()
	test_crater_dent_varies_by_real_floor_material_wood_vs_concrete()
	test_deep_layer_gate_blocks_floor_deep_level()
	test_slab_pierce_multiplier_scales_destruction()
	## E-CRACK-01 (Director, 2026-08-08) — the floor's own CRACKED tier.
	test_crater_crack_absent_without_weights()
	test_crater_crack_bands_and_severity_ladder()
	test_crater_crack_follows_crack_factor_and_respects_d32_6()
	## MAT-SOFT-01 (Director, 2026-08-21) — the soft materials' tier rule.
	test_soft_materials_never_take_a_mark()
	## SS-1 (SOOT_STORAGE_REFORM §2.1b) — the five-direction store format.
	test_full_faces_project_to_the_shipped_view_triple()
	test_full_faces_keep_what_the_view_triple_discards()
	test_full_faces_pack_round_trips()
	test_full_faces_merge_is_min_per_direction()

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


## PERF-02 B2: "count_a relates to count_b the same way factor_a relates to
## factor_b" — a strictly larger factor must yield a strictly larger count, and
## EQUAL factors must yield equal counts (same deterministic hash, same
## threshold, so the selected sets are identical, not merely similar). Used by
## the dent-prevalence check so it asserts the property instead of one
## session's numbers.
func _ordered_like(count_a: int, count_b: int, factor_a: float, factor_b: float) -> bool:
	if is_equal_approx(factor_a, factor_b):
		return count_a == count_b
	if factor_a > factor_b:
		return count_a > count_b
	return count_a < count_b


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
## dent_factor=0.5, crack_factor=0.3, so at ring 0 (multiplier 1.0) a
## 64-voxel group should produce barely any DESTROYED and mostly DENTED
## (the sunken look metal was originally meant to show), with some CRACKED
## on top. DESTRUCTION_MASTER_PLAN D22 (2026-07-30) split the old single
## CRACKED-only "distortion" outcome into DENTED (sunken) + CRACKED (flat
## mark) tiers, applied to every material, not just metal.
func test_metal_container_produces_cracked_not_destroyed() -> void:
	print("[7] Metal container: mostly DENTED, barely any DESTROYED\n")

	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(0, 0), Vector2i(1, 0), 1, "metal")]
	SliceGenerator.generate(edges, registry)
	var slice: Slice = registry.get_slice("SLICE_0_0_SE")
	if slice == null:
		_fail("Could not resolve synthetic metal Slice (id lookup mismatch — check Face/Edge canon)")
		print("")
		return

	BlastCalculatorClass.apply_container_damage(
		slice.voxels, slice.id, "metal", 0, GeometryCoords.PLAYABLE_LEVEL, false, [1.0, 0.5],
		[1.0, 0.5], [1.0, 0.5], [1.0, 0.5])

	var destroyed := 0
	var dented := 0
	var cracked := 0
	for voxel in slice.voxels:
		if voxel.damage_state == Voxel.DamageState.DESTROYED:
			destroyed += 1
		elif voxel.damage_state == Voxel.DamageState.DENTED:
			dented += 1
		elif voxel.damage_state == Voxel.DamageState.CRACKED:
			cracked += 1

	if dented > destroyed and destroyed <= 6:
		_pass("Metal slice: %d DENTED, %d CRACKED, %d DESTROYED (out of %d voxels) — matches 'barely affected, dented'" %
			[dented, cracked, destroyed, slice.voxels.size()])
	else:
		_fail("Metal slice: %d DENTED, %d CRACKED, %d DESTROYED (out of %d) — expected mostly DENTED, little DESTROYED" %
			[dented, cracked, destroyed, slice.voxels.size()])
	print("")


## D22: the three damage tiers must partition the affected voxels with no
## overlap — a voxel selected for DESTROYED can never also show up DENTED or
## CRACKED, and DENTED must be drawn before CRACKED so the harsher tier never
## loses a voxel to the milder one.
func test_damage_tiers_are_mutually_exclusive() -> void:
	print("[7b] Damage tiers (DESTROYED/DENTED/CRACKED) partition with no overlap\n")

	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(0, 0), Vector2i(1, 0), 1, "concrete")]
	SliceGenerator.generate(edges, registry)
	var slice: Slice = registry.get_slice("SLICE_0_0_SE")
	if slice == null:
		_fail("Could not resolve synthetic concrete Slice (id lookup mismatch — check Face/Edge canon)")
		print("")
		return

	BlastCalculatorClass.apply_container_damage(
		slice.voxels, slice.id, "concrete", 0, GeometryCoords.PLAYABLE_LEVEL, false, [1.0, 0.5],
		[1.0, 0.5], [1.0, 0.5], [1.0, 0.5])

	var counts := {
		Voxel.DamageState.INTACT: 0, Voxel.DamageState.DESTROYED: 0,
		Voxel.DamageState.DENTED: 0, Voxel.DamageState.CRACKED: 0,
	}
	for voxel in slice.voxels:
		counts[voxel.damage_state] = counts.get(voxel.damage_state, 0) + 1

	var total_tagged: int = counts[Voxel.DamageState.DESTROYED] + counts[Voxel.DamageState.DENTED] + counts[Voxel.DamageState.CRACKED]
	if counts[Voxel.DamageState.INTACT] + total_tagged == slice.voxels.size() and counts[Voxel.DamageState.DENTED] > 0 and counts[Voxel.DamageState.CRACKED] > 0:
		_pass("Concrete slice: destroyed=%d dented=%d cracked=%d intact=%d, sums to %d with no double-counting" %
			[counts[Voxel.DamageState.DESTROYED], counts[Voxel.DamageState.DENTED], counts[Voxel.DamageState.CRACKED], counts[Voxel.DamageState.INTACT], slice.voxels.size()])
	else:
		_fail("Concrete slice tiers don't partition cleanly: destroyed=%d dented=%d cracked=%d intact=%d (voxels=%d)" %
			[counts[Voxel.DamageState.DESTROYED], counts[Voxel.DamageState.DENTED], counts[Voxel.DamageState.CRACKED], counts[Voxel.DamageState.INTACT], slice.voxels.size()])
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
		slice.voxels, slice.id, "wood", 0, GeometryCoords.PLAYABLE_LEVEL, false, [1.0, 0.5],
		[1.0, 0.5], [1.0, 0.5], [1.0, 0.5])

	var destroyed := 0
	for voxel in slice.voxels:
		if voxel.damage_state == Voxel.DamageState.DESTROYED:
			destroyed += 1

	## PERF-02 B2b (2026-08-04): threshold RESTORED to its original 70%. It was
	## briefly lowered to 55% when the flat ×0.65 scale put wood at 0.6, and the
	## retune to 0.75 made that concession unnecessary — wood measures 75%
	## destroyed again. Kept as a real 70% bar rather than left loose: a
	## threshold that no longer matches the design statement it encodes is worse
	## than no threshold.
	var ratio := float(destroyed) / float(slice.voxels.size())
	if ratio >= 0.7:
		_pass("Wood slice: %d/%d voxels DESTROYED (%.0f%%) — matches 'quase toda destruída'" %
			[destroyed, slice.voxels.size(), ratio * 100.0])
	else:
		_fail("Wood slice: only %d/%d voxels DESTROYED (%.0f%%), expected >=70%%" %
			[destroyed, slice.voxels.size(), ratio * 100.0])

	## The ordering the Director's statement is really about — kept as a real
	## assertion so a future retune cannot quietly make wood the tough one.
	var wood_df: float = MaterialResistanceTableClass.destroy_factor("wood")
	var toughest_other: float = maxf(maxf(
		MaterialResistanceTableClass.destroy_factor("concrete"),
		MaterialResistanceTableClass.destroy_factor("stone")),
		MaterialResistanceTableClass.destroy_factor("metal"))
	if wood_df > toughest_other:
		_pass("wood destroy_factor %.2f still exceeds every other wall material (max %.2f)"
			% [wood_df, toughest_other])
	else:
		_fail("wood destroy_factor %.2f no longer leads the table (max other %.2f)"
			% [wood_df, toughest_other])
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
		slice.voxels, slice.id, "wood", 0, GeometryCoords.PLAYABLE_LEVEL, false, [1.0], [1.0], [1.0], [1.0])

	var top_storey_touched := false
	for voxel in slice.voxels:
		if voxel.level >= GeometryCoords.storey_level_base(2) and voxel.damage_state != Voxel.DamageState.INTACT:
			top_storey_touched = true

	if top_storey_touched:
		_fail("A voxel beyond the bomb's own ring range was damaged")
	else:
		_pass("Voxels beyond ring_multipliers.size() stayed INTACT (out-of-range, not clamped)")
	print("")


## VL-D1 — soot rings spread outward from a hole, one ring per BFS step, and
## stop at n_rings. A single hole in a 1×N row must tag its neighbours 0,1,2.
func test_soot_rings_spread_by_distance() -> void:
	print("[10] Soot rings spread by BFS distance from the hole\n")

	var slab := Slab.new("SOOT_ROW", Vector2i.ZERO, Slab.Role.FLOOR, 0, "concrete")
	var cell_to_voxel: Dictionary = {}
	var destroyed: Array = []
	for x in range(7):
		var v := VoxelClass.new(Vector2i(x, 0), 0, slab)
		if x == 3:
			v.visible = false
			v.set_damage(Voxel.DamageState.DESTROYED)
			destroyed.append(Vector3i(x, 0, 0))
		cell_to_voxel[Vector3i(x, 0, 0)] = v

	var snapshot: Dictionary = {}
	BlastCalculatorClass.derive_soot_rings(cell_to_voxel, destroyed, 3, snapshot)

	var expected := {0: 2, 1: 1, 2: 0, 3: -1, 4: 0, 5: 1, 6: 2}
	var ok := true
	for x in expected:
		var got: int = int(snapshot.get(0, {}).get(Vector2i(x, 0), -1))
		if got != expected[x]:
			_fail("x=%d expected soot_ring %d, got %d" % [x, expected[x], got])
			ok = false
	if ok:
		_pass("Rings 0/1/2 tagged symmetrically outward; hole itself untagged (-1)")
	print("")


## VL-D1 — a voxel reachable from two holes takes the SMALLER ring (darker
## scorch wins), so overlapping blast halos don't leave a bright seam.
func test_soot_min_ring_wins_between_two_holes() -> void:
	print("[11] Soot: min ring wins between two holes\n")

	var slab := Slab.new("SOOT_PAIR", Vector2i.ZERO, Slab.Role.FLOOR, 0, "concrete")
	var cell_to_voxel: Dictionary = {}
	var destroyed: Array = []
	# Holes at x=0 and x=4; x=2 is 2 from each, x=1 is 1 from the left hole.
	for x in range(5):
		var v := VoxelClass.new(Vector2i(x, 0), 0, slab)
		if x == 0 or x == 4:
			v.visible = false
			v.set_damage(Voxel.DamageState.DESTROYED)
			destroyed.append(Vector3i(x, 0, 0))
		cell_to_voxel[Vector3i(x, 0, 0)] = v

	var snapshot: Dictionary = {}
	BlastCalculatorClass.derive_soot_rings(cell_to_voxel, destroyed, 3, snapshot)

	# x=1: ring 0 from left hole. x=3: ring 0 from right hole. x=2: ring 1 from both.
	var r1: int = int(snapshot.get(0, {}).get(Vector2i(1, 0), -1))
	var r2: int = int(snapshot.get(0, {}).get(Vector2i(2, 0), -1))
	var r3: int = int(snapshot.get(0, {}).get(Vector2i(3, 0), -1))
	if r1 == 0 and r2 == 1 and r3 == 0:
		_pass("x=1,3 ring 0 (adjacent to a hole); x=2 ring 1 (min of the two paths)")
	else:
		_fail("Expected rings [0,1,0] for x=1,2,3; got [%d,%d,%d]" % [r1, r2, r3])
	print("")


## FACE-SOOT-01 — the face turned toward the hole takes the voxel's own ring;
## the other two visible faces fall one ring back. This is the whole point of
## the feature: a crater's inner wall reads scorched while the same voxel's
## outward faces stay comparatively clean.
func test_face_soot_points_at_the_hole() -> void:
	print("[FACE-SOOT-01a] The face turned toward the hole is the sooty one\n")

	## A 1x3 row on X with the hole at x=0. x=1 is reached by stepping +X, so its
	## direction BACK to the hole is -X — no visible face points that way, and all
	## three of its faces must take the fainter ring. Mirror it with a hole at
	## x=2 to get the case where the SE (+X) face IS the one facing the blast.
	var slab := Slab.new("FACE_SOOT_ROW", Vector2i.ZERO, Slab.Role.FLOOR, 0, "concrete")
	var cell_to_voxel: Dictionary = {}
	var destroyed: Array = []
	for x in range(3):
		var v := VoxelClass.new(Vector2i(x, 0), 0, slab)
		if x == 2:
			v.visible = false
			v.set_damage(Voxel.DamageState.DESTROYED)
			destroyed.append(Vector3i(x, 0, 0))
		cell_to_voxel[Vector3i(x, 0, 0)] = v

	var snapshot: Dictionary = {}
	var faces: Dictionary = {}
	BlastCalculatorClass.derive_soot_rings(cell_to_voxel, destroyed, 3, snapshot, faces)

	## x=1 sits next to the hole at x=2, reached by stepping -X, so the direction
	## back to the hole is +X — the SE face. SE keeps ring 0; top and SW fall to 1.
	var f1 = faces.get(0, {}).get(Vector2i(1, 0))
	## x=0 is ring 1, reached from x=1 by stepping -X, so again the SE face leads.
	var f0 = faces.get(0, {}).get(Vector2i(0, 0))
	if f1 == Vector3i(1, 0, 1) and f0 == Vector3i(2, 1, 2):
		_pass("SE face carries the near ring (x=1 %s, x=0 %s); top/SW one ring fainter" % [f1, f0])
	else:
		_fail("Expected x=1 (1,0,1) and x=0 (2,1,2); got %s and %s" % [f1, f0])
	print("")


## FACE-SOOT-01 — a voxel equidistant from two holes on DIFFERENT axes scorches
## on both faces that see one. Without the same-ring merge the BFS would keep
## whichever direction it happened to reach first, which would also make the
## result depend on frontier order and therefore unstable across rebuilds.
func test_face_soot_merges_at_a_corner() -> void:
	print("[FACE-SOOT-01b] A corner voxel scorches on every side that saw a hole\n")

	var slab := Slab.new("FACE_SOOT_CORNER", Vector2i.ZERO, Slab.Role.FLOOR, 0, "concrete")
	var cell_to_voxel: Dictionary = {}
	var destroyed: Array = []
	## Holes at (1,0) and (0,1); the voxel at (0,0) touches both — one across its
	## SE (+X) face, one across its SW (+Y) face.
	for pos in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var v := VoxelClass.new(pos, 0, slab)
		if pos != Vector2i(0, 0):
			v.visible = false
			v.set_damage(Voxel.DamageState.DESTROYED)
			destroyed.append(Vector3i(pos.x, pos.y, 0))
		cell_to_voxel[Vector3i(pos.x, pos.y, 0)] = v

	var snapshot: Dictionary = {}
	var faces: Dictionary = {}
	BlastCalculatorClass.derive_soot_rings(cell_to_voxel, destroyed, 3, snapshot, faces)

	var f = faces.get(0, {}).get(Vector2i(0, 0))
	if f == Vector3i(1, 0, 0):
		_pass("Corner voxel: SE and SW both ring 0, top one ring fainter (%s)" % [f])
	else:
		_fail("Expected (1,0,0) — both facing sides at ring 0; got %s" % [f])
	print("")


## FACE-SOOT-01 must not have moved the isotropic ring map it rides alongside:
## probes, vision modes and VoxelLightField.soot_factor() all still read that,
## and the crater-floor cells room.gd merges in have no face data at all.
func test_face_soot_leaves_isotropic_result_untouched() -> void:
	print("[FACE-SOOT-01c] The per-voxel ring map is byte-identical with and without faces\n")

	var slab := Slab.new("FACE_SOOT_ISO", Vector2i.ZERO, Slab.Role.FLOOR, 0, "concrete")
	var cell_to_voxel: Dictionary = {}
	var destroyed: Array = []
	for x in range(7):
		for y in range(3):
			var v := VoxelClass.new(Vector2i(x, y), 0, slab)
			if x == 3 and y == 1:
				v.visible = false
				v.set_damage(Voxel.DamageState.DESTROYED)
				destroyed.append(Vector3i(x, y, 0))
			cell_to_voxel[Vector3i(x, y, 0)] = v

	var without: Dictionary = {}
	BlastCalculatorClass.derive_soot_rings(cell_to_voxel, destroyed, 3, without)
	var with_faces: Dictionary = {}
	var faces: Dictionary = {}
	BlastCalculatorClass.derive_soot_rings(cell_to_voxel, destroyed, 3, with_faces, faces)

	if without == with_faces and not faces.is_empty():
		_pass("Ring map identical either way (%d levels), and %d face triples produced"
			% [without.size(), faces.get(0, {}).size()])
	else:
		_fail("Ring map diverged when faces were requested (without=%s with=%s)"
			% [without, with_faces])
	print("")


## VL-D2 — the radial crater: everything inside core_radius is DESTROYED, the
## rim (core..max) is partially removed (deterministically), and everything
## beyond max_radius is untouched. A 25×1 row from the epicentre makes the
## three zones unambiguous.
func test_crater_core_solid_rim_ragged_beyond_intact() -> void:
	print("[12] Radial crater: solid core, ragged rim, intact beyond\n")

	var slab := Slab.new("CRATER_ROW", Vector2i.ZERO, Slab.Role.FLOOR, 0, "earth")
	var voxels: Array = []
	for x in range(25):
		voxels.append(VoxelClass.new(Vector2i(x, 0), 0, slab))
	var epicenter := Vector2i(0, 0)
	BlastCalculatorClass.apply_crater_damage(voxels, slab.id, epicenter, 7.0, 17.0)

	var core_all_destroyed := true
	var beyond_all_intact := true
	var rim_destroyed := 0
	var rim_intact := 0
	for v in voxels:
		var d: float = float(v.grid_pos.x)
		var destroyed: bool = v.damage_state == Voxel.DamageState.DESTROYED
		if d <= 7.0:
			if not destroyed: core_all_destroyed = false
		elif d <= 17.0:
			if destroyed: rim_destroyed += 1
			else: rim_intact += 1
		else:
			if destroyed: beyond_all_intact = false

	if not core_all_destroyed:
		_fail("A voxel inside core_radius survived")
	elif not beyond_all_intact:
		_fail("A voxel beyond max_radius was destroyed")
	elif rim_destroyed == 0 or rim_intact == 0:
		_fail("Rim was all-or-nothing (destroyed=%d intact=%d) — expected a mix" % [rim_destroyed, rim_intact])
	else:
		_pass("Core solid, beyond intact, rim mixed (%d destroyed / %d intact)" % [rim_destroyed, rim_intact])
	print("")


## FLOOR-DENT-01 — floor dents: a rim voxel that survives the destroy roll,
## and any voxel in the band one rim-width past the crater, may become a
## carved-TOP blast DENTED pockmark. Prevalence must (a) be zero without a
## material (backward compat — every pre-FLOOR-DENT caller), (b) never touch
## the core (destroyed) or anything past max_radius + rim_span, (c) always
## carry blast provenance + CarvedSide.TOP, (d) scale monotonically with the
## material's dent_factor (same hash rolls, larger threshold ⇒ superset), and
## (e) never change WHICH voxels the destroy roll takes.
func test_crater_dents_rim_and_band_by_material() -> void:
	print("[12b] FLOOR-DENT: rim survivors + fading band dent, by material factor\n")

	const CORE := 7.0
	const MAX_R := 17.0
	const RIM_SPAN := MAX_R - CORE  ## dent band ends at MAX_R + RIM_SPAN = 27
	var epicenter := Vector2i(0, 0)

	## One 28×28 quadrant: distances 0..~38 cover core, rim, band, and beyond.
	var make_patch := func() -> Array:
		var slab := Slab.new("DENT_PATCH", Vector2i.ZERO, Slab.Role.FLOOR, 0, "earth")
		_fixture_slabs.append(slab)  ## LEAK-CYCLE-01 — see _fixture_slabs
		var out: Array = []
		for x in range(28):
			for y in range(28):
				out.append(VoxelClass.new(Vector2i(x, y), 0, slab))
		return out

	var count_states := func(voxels: Array) -> Dictionary:
		var stats := {"dents": 0, "destroyed": 0, "dent_in_core": 0,
			"dent_beyond_band": 0, "bad_provenance": 0}
		for v in voxels:
			var d: float = Vector2(v.grid_pos - epicenter).length()
			if v.damage_state == Voxel.DamageState.DESTROYED:
				stats["destroyed"] += 1
			elif v.damage_state == Voxel.DamageState.DENTED:
				stats["dents"] += 1
				if d <= CORE:
					stats["dent_in_core"] += 1
				if d > MAX_R + RIM_SPAN:
					stats["dent_beyond_band"] += 1
				if not v.damage_is_blast or v.damage_carved_side != VoxelClass.CarvedSide.TOP:
					stats["bad_provenance"] += 1
		return stats

	## (a) no material → the pre-FLOOR-DENT behaviour, zero dents.
	var bare: Array = make_patch.call()
	BlastCalculatorClass.apply_crater_damage(bare, "DENT_PATCH", epicenter, CORE, MAX_R)
	var bare_stats: Dictionary = count_states.call(bare)
	if bare_stats["dents"] == 0:
		_pass("no material → 0 dents (every pre-existing caller unchanged)")
	else:
		_fail("no material still produced %d dents" % bare_stats["dents"])

	## (b)(c) earth: dents exist, only in rim/band, always blast + carved TOP.
	var earth: Array = make_patch.call()
	BlastCalculatorClass.apply_crater_damage(earth, "DENT_PATCH", epicenter, CORE, MAX_R, "earth")
	var earth_stats: Dictionary = count_states.call(earth)
	if earth_stats["dents"] > 0 and earth_stats["dent_in_core"] == 0 \
			and earth_stats["dent_beyond_band"] == 0:
		_pass("earth: %d dents, none in the core, none past max+rim (%d..%d px)"
			% [earth_stats["dents"], int(CORE), int(MAX_R + RIM_SPAN)])
	else:
		_fail("earth dent placement wrong: dents=%d in_core=%d beyond_band=%d"
			% [earth_stats["dents"], earth_stats["dent_in_core"], earth_stats["dent_beyond_band"]])
	if earth_stats["bad_provenance"] == 0:
		_pass("every dent is blast-sourced with CarvedSide.TOP")
	else:
		_fail("%d dents missing blast provenance or carved TOP" % earth_stats["bad_provenance"])

	## (d) dent prevalence tracks dent_factor: same hash per voxel, larger
	## threshold ⇒ superset ⇒ ordered counts on a patch this size.
	##
	## PERF-02 B2 (Director, 2026-08-04): compares against the table's LIVE
	## values instead of the "metal 0.5 > earth 0.3 > concrete 0.2" ordering
	## hardcoded when this was written. Scaling the wall materials ~x0.65 put
	## metal's dent_factor (0.5 -> 0.3) exactly level with earth's untouched
	## 0.3, and a strict > then failed on a tie that is correct behaviour —
	## equal factors MUST produce equal counts, since the selection is the same
	## deterministic hash threshold. Reading the factors makes the assertion
	## about the property (prevalence follows the factor) rather than about one
	## session's numbers, so a future retune cannot make it wrong again.
	##
	## B2b moved metal to 0.35 and the tie no longer occurs at the shipped
	## values — this stays property-based anyway, because it is the stronger
	## assertion and the tie case is a real invariant of the hash selection,
	## not a workaround for one table.
	var metal: Array = make_patch.call()
	BlastCalculatorClass.apply_crater_damage(metal, "DENT_PATCH", epicenter, CORE, MAX_R, "metal")
	var concrete: Array = make_patch.call()
	BlastCalculatorClass.apply_crater_damage(concrete, "DENT_PATCH", epicenter, CORE, MAX_R, "concrete")
	var m: int = count_states.call(metal)["dents"]
	var e: int = earth_stats["dents"]
	var c: int = count_states.call(concrete)["dents"]
	var mf: float = MaterialResistanceTableClass.dent_factor("metal")
	var ef: float = MaterialResistanceTableClass.dent_factor("earth")
	var cf: float = MaterialResistanceTableClass.dent_factor("concrete")
	if _ordered_like(m, e, mf, ef) and _ordered_like(e, c, ef, cf):
		_pass("prevalence follows dent_factor: metal %d (%.2f), earth %d (%.2f), concrete %d (%.2f)"
			% [m, mf, e, ef, c, cf])
	else:
		_fail("prevalence not consistent with dent_factor: metal=%d (%.2f) earth=%d (%.2f) concrete=%d (%.2f)"
			% [m, mf, e, ef, c, cf])

	## (e) the destroy roll is untouched by the material's dent factor.
	if earth_stats["destroyed"] == bare_stats["destroyed"]:
		_pass("destroyed count identical with and without dents (%d)" % int(bare_stats["destroyed"]))
	else:
		_fail("dent roll changed destruction: %d vs %d"
			% [earth_stats["destroyed"], bare_stats["destroyed"]])
	print("")


## VL-D4 — "acentuar destruição na face mais próxima da granada": within one
## ring group, a bias_epicenter must select the NEAR side before the FAR side,
## not scatter across both. Ten voxels split into two clusters (x=0 near the
## epicenter, x=100 far from it) at the same ring/level; asking for exactly the
## near cluster's size must return ONLY near-side voxels.
func test_bias_prefers_epicenter_facing_side() -> void:
	print("[13] Directional bias selects the epicenter-facing side first\n")

	var slab := Slab.new("BIAS_TEST", Vector2i.ZERO, Slab.Role.FLOOR, 0, "wood")
	var near_side: Array = []
	var far_side: Array = []
	for i in range(5):
		near_side.append(VoxelClass.new(Vector2i(0, i), 0, slab))
		far_side.append(VoxelClass.new(Vector2i(100, i), 0, slab))
	var group: Array = near_side + far_side
	var epicenter := Vector2i(-5, 2)  ## clearly closer to the x=0 cluster

	var selected: Array = BlastCalculatorClass._select_deterministic(
			group, "WALL_BIAS", "DESTROY", 5, epicenter)

	var all_near := true
	for v in selected:
		if not near_side.has(v):
			all_near = false
			break
	if all_near and selected.size() == 5:
		_pass("All 5 selected voxels are on the epicenter-facing (near) side")
	else:
		var near_count := 0
		for v in selected:
			if near_side.has(v): near_count += 1
		_fail("Expected 5/5 near-side voxels, got %d/5 (bias not applied correctly)" % near_count)
	print("")


## The default (NO_EPICENTER_BIAS) path must stay EXACTLY the pre-VL-D4 pure
## hash-rank — every existing caller/selftest relies on this not changing.
## Cross-checked against the untouched 4-argument call form.
func test_no_bias_sentinel_keeps_hash_only_behavior() -> void:
	print("[14] No bias_epicenter argument reproduces the original hash-only pick\n")

	var voxels := _synthetic_voxels(20)
	var without_arg := BlastCalculatorClass._select_deterministic(voxels, "SLICE_A", "DESTROY", 5)
	var with_sentinel := BlastCalculatorClass._select_deterministic(
			voxels, "SLICE_A", "DESTROY", 5, BlastCalculatorClass.NO_EPICENTER_BIAS)

	if _same_voxel_set(without_arg, with_sentinel) and without_arg.size() == with_sentinel.size():
		_pass("Omitting bias_epicenter and passing NO_EPICENTER_BIAS explicitly agree")
	else:
		_fail("Default and explicit-sentinel calls diverged — the 'off' path changed behavior")
	print("")


## ── WEAPON_MASTER_PLAN D1 — CONE delivery ────────────────────────────────
## NE is grid delta (0,-1) per docs/DIRECTION_GLOSSARY.md §3; a shotgun on the
## test bench aims along it at the wall row "above" it.
const NE := Vector2i(0, -1)


func test_cone_is_directional_not_radial() -> void:
	print("TEST: cone reaches forward and NOT backward (the whole point of CONE)")
	var cone := BlastCalculatorClass.flood_gu_cone(Vector2i(10, 10), NE, 25.0, 4, {})
	var forward_hit := cone.has(Vector2i(10, 8))
	var backward_hit := cone.has(Vector2i(10, 12))
	var sideways_hit := cone.has(Vector2i(14, 10))
	if forward_hit and not backward_hit and not sideways_hit:
		_pass("forward (10,8) in cone; backward (10,12) and broadside (14,10) excluded")
	else:
		_fail("directionality wrong — forward=%s backward=%s sideways=%s" %
			[forward_hit, backward_hit, sideways_hit])
	## The radial flood from the same source WOULD have taken all three — proving
	## the cone is doing real work, not just producing a smaller ring set.
	var rings := BlastCalculatorClass.flood_gu_rings(Vector2i(10, 10), _test_bomb([1.0, 1.0, 1.0, 1.0, 1.0]), {})
	if rings.has(Vector2i(10, 12)) and rings.has(Vector2i(14, 10)):
		_pass("same source as RADIAL does reach backward/broadside — cone is the difference")
	else:
		_fail("radial baseline did not reach backward/broadside; comparison is meaningless")
	print("")


func test_cone_widens_with_distance() -> void:
	print("TEST: cone is a wedge — wider far from the muzzle than next to it")
	var cone := BlastCalculatorClass.flood_gu_cone(Vector2i(10, 20), NE, 30.0, 6, {})
	var width_by_row: Dictionary = {}
	for gu in cone:
		var dy: int = 20 - gu.y
		width_by_row[dy] = int(width_by_row.get(dy, 0)) + 1
	var near: int = int(width_by_row.get(1, 0))
	var far: int = int(width_by_row.get(5, 0))
	if far > near and near >= 1:
		_pass("row 1 holds %d cell(s), row 5 holds %d — widens with distance" % [near, far])
	else:
		_fail("cone did not widen: row1=%d row5=%d (%s)" % [near, far, width_by_row])
	print("")


func test_cone_respects_range_and_half_angle() -> void:
	print("TEST: range caps depth; half-angle caps spread")
	var short_cone := BlastCalculatorClass.flood_gu_cone(Vector2i(10, 20), NE, 30.0, 3, {})
	var too_far := short_cone.has(Vector2i(10, 16))  ## 4 steps out, range is 3
	if not too_far:
		_pass("nothing beyond the step cap (10,16) at range 3")
	else:
		_fail("cone exceeded its range cap")

	var narrow := BlastCalculatorClass.flood_gu_cone(Vector2i(10, 20), NE, 5.0, 5, {})
	var wide := BlastCalculatorClass.flood_gu_cone(Vector2i(10, 20), NE, 45.0, 5, {})
	if narrow.size() < wide.size():
		_pass("5 deg cone (%d cells) is tighter than 45 deg (%d) — accuracy is the half-angle" %
			[narrow.size(), wide.size()])
	else:
		_fail("half-angle had no effect: narrow=%d wide=%d" % [narrow.size(), wide.size()])

	## A near-zero half-angle must still fire straight down the axis, not produce
	## an empty cone — a weapon with perfect accuracy still hits something.
	var axis_only := BlastCalculatorClass.flood_gu_cone(Vector2i(10, 20), NE, 1.0, 4, {})
	if axis_only.has(Vector2i(10, 16)):
		_pass("a 1 deg cone still reaches straight down the axis")
	else:
		_fail("near-zero half-angle produced no forward hit — perfect accuracy must still fire")
	print("")


func test_cone_stops_at_blocked_edge() -> void:
	print("TEST: cone is wall-aware, same gate flood_gu_rings uses")
	var blocked: Dictionary = {}
	blocked[WallEdgeData.edge_key(Vector2i(10, 19), Vector2i(10, 18))] = true
	var cone := BlastCalculatorClass.flood_gu_cone(Vector2i(10, 20), NE, 5.0, 5, blocked)
	if cone.has(Vector2i(10, 19)) and not cone.has(Vector2i(10, 18)):
		_pass("reached (10,19), stopped at the blocked edge before (10,18)")
	else:
		_fail("blocked edge not honored: 19=%s 18=%s" %
			[cone.has(Vector2i(10, 19)), cone.has(Vector2i(10, 18))])
	print("")


## 2026-08-01 — a solid GU block (spec.blocks / bench material walls) marks a
## whole CELL occupied (room._blocked_cells) and never touches blocked_edges,
## so the ring flood propagated straight through it — the exact bug the pellet
## walker had before its 2026-07-30 blocked_cells fix, still open on the
## RADIAL path. An occupied cell must never be entered, and cells only
## reachable THROUGH it must stay unreached (a 2-ring bomb makes the shortest
## legal detour, 4 steps, unreachable — same disambiguation technique
## test_flood_stops_at_blocked_edge uses).
func test_flood_rings_stops_at_solid_block() -> void:
	print("TEST: ring flood does not propagate through a solid GU block (blocked_cells)")
	var bomb := _test_bomb([1.0, 0.7, 0.4])  # max_ring=2: detour around 1 block needs 4
	var source := Vector2i(5, 5)
	var occupied: Dictionary = {Vector2i(6, 5): true}

	var rings := BlastCalculatorClass.flood_gu_rings(source, bomb, {}, occupied)

	var block_excluded: bool = not rings.has(Vector2i(6, 5))
	var behind_excluded: bool = not rings.has(Vector2i(7, 5))
	var open_side_ok: bool = int(rings.get(Vector2i(4, 5), -1)) == 1
	if block_excluded and behind_excluded and open_side_ok:
		_pass("occupied (6,5) never entered, (7,5) behind it unreached, open (4,5) still ring 1")
	else:
		_fail("solid block leaked: block_in=%s behind_in=%s open(4,5)=%s" %
			[rings.has(Vector2i(6, 5)), rings.has(Vector2i(7, 5)), rings.get(Vector2i(4, 5), "MISSING")])
	print("")


## Same gap, CONE path — a dead-ahead cone must stop at an occupied cell, not
## flood through it to whatever lies behind.
func test_flood_cone_stops_at_solid_block() -> void:
	print("TEST: cone flood does not propagate through a solid GU block (blocked_cells)")
	var occupied: Dictionary = {Vector2i(10, 18): true}
	var cone := BlastCalculatorClass.flood_gu_cone(Vector2i(10, 20), NE, 5.0, 5, {}, occupied)
	var reached_before: bool = cone.has(Vector2i(10, 19))
	var block_excluded: bool = not cone.has(Vector2i(10, 18))
	var behind_excluded: bool = not cone.has(Vector2i(10, 17))
	if reached_before and block_excluded and behind_excluded:
		_pass("reached (10,19), occupied (10,18) never entered, (10,17) behind it unreached")
	else:
		_fail("solid block leaked: 19=%s 18=%s 17=%s" %
			[cone.has(Vector2i(10, 19)), cone.has(Vector2i(10, 18)), cone.has(Vector2i(10, 17))])
	print("")


func test_cone_output_shape_matches_rings() -> void:
	print("TEST: cone returns the SAME {gu -> step} shape find_affected_containers() consumes")
	var cone := BlastCalculatorClass.flood_gu_cone(Vector2i(10, 20), NE, 25.0, 4, {})
	var ok := true
	for key in cone:
		if typeof(key) != TYPE_VECTOR2I or typeof(cone[key]) != TYPE_INT:
			ok = false
			break
	var apex_is_zero: bool = int(cone.get(Vector2i(10, 20), -1)) == 0
	if ok and apex_is_zero:
		_pass("Vector2i -> int, apex at step 0 — drop-in for the existing damage path")
	else:
		_fail("shape mismatch (types ok=%s, apex step=%s)" % [ok, cone.get(Vector2i(10, 20), -1)])

	## Steps must be monotone along the axis, or the falloff table is meaningless.
	var s1: int = int(cone.get(Vector2i(10, 19), -1))
	var s3: int = int(cone.get(Vector2i(10, 17), -1))
	if s1 == 1 and s3 == 3:
		_pass("axis steps are the real distance (1 and 3), so step_multipliers index correctly")
	else:
		_fail("axis steps wrong: (10,19)=%d (10,17)=%d" % [s1, s3])
	print("")


func test_destroy_multiplier_scales_damage() -> void:
	print("TEST: destroy_multiplier (calibre) scales destruction, and defaults inert")
	var full := _synthetic_voxels(64)
	BlastCalculatorClass.apply_container_damage(full, "CAL_A", "concrete", 0, 0, false, [1.0],
		[1.0], [1.0], [1.0])
	var full_destroyed := _count_destroyed(full)

	var half := _synthetic_voxels(64)
	BlastCalculatorClass.apply_container_damage(half, "CAL_A", "concrete", 0, 0, false, [1.0],
		[1.0], [1.0], [1.0], BlastCalculatorClass.NO_EPICENTER_BIAS, 0.5)
	var half_destroyed := _count_destroyed(half)

	if half_destroyed < full_destroyed and half_destroyed > 0:
		_pass("0.5x calibre destroyed %d vs %d at 1.0x — scales, without zeroing out" %
			[half_destroyed, full_destroyed])
	else:
		_fail("multiplier did not scale: 0.5x=%d 1.0x=%d" % [half_destroyed, full_destroyed])

	## The default must be byte-for-byte the old behavior — every grenade call
	## site omits this argument.
	var explicit := _synthetic_voxels(64)
	BlastCalculatorClass.apply_container_damage(explicit, "CAL_A", "concrete", 0, 0, false, [1.0],
		[1.0], [1.0], [1.0], BlastCalculatorClass.NO_EPICENTER_BIAS, 1.0)
	if _count_destroyed(explicit) == full_destroyed:
		_pass("omitting the argument matches passing 1.0 — existing callers unaffected")
	else:
		_fail("default diverged from 1.0: %d vs %d" % [_count_destroyed(explicit), full_destroyed])
	print("")


## E-RING (EXPLOSION_REBUILD_MASTER_PLAN Task 2, 2026-08-06) — the 4th ring is
## now IN RANGE (ring_multipliers.size()=4 on the real frag_grenade.json),
## unlike test_ring_beyond_range_untouched()'s OUT-OF-RANGE case above. Real
## production data (loaded via BombRegistry, not a hand-built array) has
## destroy/dent/crack_ring_weights all read 0.0 at index 3 — only
## smoke_ring_weights[3]=0.1 is nonzero there, and smoke isn't consumed yet
## (Task 3/E-SOOT's job). Proves ring 3 is REACHED and EVALUATED (not simply
## skipped by the `ring >= ring_multipliers.size()` gate) yet still produces
## zero material damage — the real shape the "4th ring is smoke-only" design
## intent has to produce.
func test_ring3_reached_but_zero_weighted() -> void:
	print("[E-RING-1] Ring 3 is in range and evaluated, but frag_grenade's real weights zero it out\n")

	var registry := BombRegistryClass.new()
	registry.load_from_disk()
	var frag = registry.get_bomb("frag_grenade")
	if frag == null:
		_fail("Could not load real frag_grenade.json via BombRegistry")
		print("")
		return
	if frag.ring_multipliers.size() != 4:
		_fail("frag_grenade.json no longer has 4 rings (%d) — this test's premise changed" % frag.ring_multipliers.size())
		print("")
		return

	var edge_registry := EdgeRegistry.new()
	## 4 storeys tall (32 levels) so vertical_ring reaches exactly 3 at levels 24..31.
	var edges: Array = [Edge.between(Vector2i(0, 0), Vector2i(1, 0), 4, "concrete")]
	SliceGenerator.generate(edges, edge_registry)
	var slice: Slice = edge_registry.get_slice("SLICE_0_0_SE")
	if slice == null:
		_fail("Could not resolve synthetic concrete Slice")
		print("")
		return

	BlastCalculatorClass.apply_container_damage(
		slice.voxels, slice.id, "concrete", 0, GeometryCoords.PLAYABLE_LEVEL, false, frag.ring_multipliers,
		frag.destroy_ring_weights, frag.dent_ring_weights, frag.crack_ring_weights)

	var ring0_damaged := 0
	var ring3_damaged := 0
	for voxel in slice.voxels:
		var touched: bool = voxel.damage_state != Voxel.DamageState.INTACT
		## LEVEL-RENUMBER — these bucket a voxel by which STOREY of the wall it is
		## on, so they compare against the ground plane, not against zero.
		if voxel.level < GeometryCoords.storey_level_base(1):
			if touched: ring0_damaged += 1
		elif voxel.level >= GeometryCoords.storey_level_base(3):
			if touched: ring3_damaged += 1

	if ring0_damaged > 0 and ring3_damaged == 0:
		_pass("ring 0 (real weights): %d voxels damaged; ring 3 (in-range, weight 0.0): 0 damaged" % ring0_damaged)
	else:
		_fail("expected ring0>0 and ring3==0, got ring0=%d ring3=%d" % [ring0_damaged, ring3_damaged])
	print("")


## D14 (2026-08-06) — the vertical ring step is now IDENTICAL for wall
## (is_roof=false) and roof (is_roof=true): both advance one ring per whole
## STOREY (LEVELS_PER_STOREY=8), never per raw level for roofs. Before this
## change, is_roof=true advanced one ring per RAW level, so a roof voxel just
## ONE level above the blast's own level (offset 1, still well inside storey
## 0) would already fall to ring 1 and lose that ring's multiplier worth of
## damage — the exact asymmetry D14 retires. Proves both flags now keep an
## entire storey (levels 0..7) at ring 0, and only storey 1 (levels 8..15)
## drops to ring 1 — for BOTH is_roof values identically.
func test_vertical_falloff_identical_for_wall_and_roof() -> void:
	print("[E-RING-2] D14: vertical ring step is per-STOREY for both wall and roof, not per-raw-level for roof\n")

	for is_roof in [false, true]:
		var registry := EdgeRegistry.new()
		var edges: Array = [Edge.between(Vector2i(0, 0), Vector2i(1, 0), 2, "concrete")]
		SliceGenerator.generate(edges, registry)
		var slice: Slice = registry.get_slice("SLICE_0_0_SE")
		if slice == null:
			_fail("Could not resolve synthetic concrete Slice (is_roof=%s)" % is_roof)
			continue

		BlastCalculatorClass.apply_container_damage(
			slice.voxels, slice.id, "concrete", 0, GeometryCoords.PLAYABLE_LEVEL, is_roof, [1.0, 0.0],
			[1.0, 0.0], [1.0, 0.0], [1.0, 0.0])

		var storey0_damaged := 0
		var storey1_damaged := 0
		for voxel in slice.voxels:
			var touched: bool = voxel.damage_state != Voxel.DamageState.INTACT
			if voxel.level < GeometryCoords.storey_level_base(1):
				if touched: storey0_damaged += 1
			else:
				if touched: storey1_damaged += 1

		if storey0_damaged > 0 and storey1_damaged == 0:
			_pass("is_roof=%s: storey 0 damaged (%d voxels), storey 1 untouched (ring-1 weight 0.0)" % [is_roof, storey0_damaged])
		else:
			_fail("is_roof=%s: expected storey0>0 storey1==0, got storey0=%d storey1=%d" % [is_roof, storey0_damaged, storey1_damaged])
	print("")


## D14/D17 consequence check: a real roof is two Slabs at consecutive levels
## (ROOF_LEVEL_COUNT=2, room_builder.gd), not one. Under the pre-D14 per-raw-
## level roof stepping, level 0 and level 1 would have landed in DIFFERENT
## ring groups (ring 0 vs ring 1) and taken different damage. D14's storey-
## based step puts both at vertical_ring = floor(0/8) = floor(1/8) = 0 — the
## SAME ring group — which is the concrete proof behind the master plan's
## "roof pierces as one unit falls out for free" finding, not an assumption.
func test_roof_two_levels_same_ring_group() -> void:
	print("[E-RING-3] D14/D17: a roof's two levels (ROOF_LEVEL_COUNT=2) land in the SAME ring group\n")

	var slab_a := Slab.new("ROOF_TEST_L0", Vector2i(9, 9), Slab.Role.CEILING, 0, "concrete")
	var slab_b := Slab.new("ROOF_TEST_L1", Vector2i(9, 9), Slab.Role.CEILING, 1, "concrete")
	var voxels: Array = []
	for x in range(10):
		for y in range(10):
			voxels.append(VoxelClass.new(Vector2i(x, y), 0, slab_a))
			voxels.append(VoxelClass.new(Vector2i(x, y), 1, slab_b))

	## ring_multipliers/weights sized 2: ring 0 destroys everything, ring 1
	## destroys nothing — a real roof's two levels must land ENTIRELY in
	## ring 0, never split.
	BlastCalculatorClass.apply_container_damage(
		voxels, "ROOF_TEST", "concrete", 0, 0, true, [1.0, 0.0],
		[1.0, 0.0], [1.0, 0.0], [1.0, 0.0])

	var level0_destroyed := 0
	var level1_destroyed := 0
	for voxel in voxels:
		if voxel.level == 0 and voxel.damage_state == Voxel.DamageState.DESTROYED:
			level0_destroyed += 1
		elif voxel.level == 1 and voxel.damage_state == Voxel.DamageState.DESTROYED:
			level1_destroyed += 1

	if level0_destroyed > 0 and level1_destroyed > 0:
		_pass("both roof levels destroyed proportionally (level0=%d, level1=%d) — same ring group" % [level0_destroyed, level1_destroyed])
	else:
		_fail("roof levels split across rings: level0=%d level1=%d (expected both > 0)" % [level0_destroyed, level1_destroyed])
	print("")


## D19/D20 legalized non-ground materials (e.g. wood) as real floor-zone
## materials, no longer hardcoded to "earth"/"ground_*". Proves
## apply_crater_damage()'s D9 real-material lookup gives wood its own,
## distinct, nonzero dent_factor through the reformed one-row-per-material
## table — not a missing row silently reading 0, and not collapsed onto
## concrete's value.
func test_crater_dent_varies_by_real_floor_material_wood_vs_concrete() -> void:
	print("[E-RING-4] D9/D19: apply_crater_damage() dent prevalence differs for a real wood floor vs a concrete floor\n")

	var epicenter := Vector2i(0, 0)
	const CORE := 7.0
	const MAX_R := 17.0
	var make_patch := func(mat: String) -> Array:
		var slab := Slab.new("WOOD_FLOOR_TEST", Vector2i.ZERO, Slab.Role.FLOOR, 0, mat)
		_fixture_slabs.append(slab)  ## LEAK-CYCLE-01 — see _fixture_slabs
		var out: Array = []
		for x in range(28):
			for y in range(28):
				out.append(VoxelClass.new(Vector2i(x, y), 0, slab))
		return out

	var wood: Array = make_patch.call("wood")
	BlastCalculatorClass.apply_crater_damage(wood, "WOOD_FLOOR_TEST", epicenter, CORE, MAX_R, "wood")
	var concrete: Array = make_patch.call("concrete")
	BlastCalculatorClass.apply_crater_damage(concrete, "WOOD_FLOOR_TEST", epicenter, CORE, MAX_R, "concrete")

	var w: int = 0
	for v in wood:
		if v.damage_state == Voxel.DamageState.DENTED: w += 1
	var c: int = 0
	for v in concrete:
		if v.damage_state == Voxel.DamageState.DENTED: c += 1

	var wf: float = MaterialResistanceTableClass.dent_factor("wood")
	var cf: float = MaterialResistanceTableClass.dent_factor("concrete")

	if wf <= 0.0:
		_fail("wood dent_factor is %.3f — D19/D20's reform left wood with no real dent row" % wf)
	elif _ordered_like(w, c, wf, cf):
		_pass("wood (%d dents, factor %.2f) vs concrete (%d dents, factor %.2f) — D9's real-material lookup varies by floor material" %
			[w, wf, c, cf])
	else:
		_fail("dent counts don't track dent_factor: wood=%d (%.2f) concrete=%d (%.2f)" % [w, wf, c, cf])
	print("")


## D2 (EXPLOSION_REBUILD_MASTER_PLAN §4.4) — deep_layer_unlocked is the
## principled replacement for the removed PERF-02 B4 hack. false must leave
## every GeometryCoords.FLOOR_DEEP_LEVEL voxel INTACT even well inside
## core_radius (where a FLOOR_TOP_LEVEL voxel would be unconditionally
## destroyed); true must let the same voxels take real damage.
func test_deep_layer_gate_blocks_floor_deep_level() -> void:
	print("[E-RING-5] D2: deep_layer_unlocked gates FLOOR_DEEP_LEVEL voxels out entirely when false\n")

	var epicenter := Vector2i(5, 5)
	var make_deep_patch := func() -> Array:
		var slab := Slab.new("DEEP_GATE_TEST", Vector2i.ZERO, Slab.Role.FLOOR, GeometryCoords.FLOOR_DEEP_LEVEL, "concrete")
		_fixture_slabs.append(slab)  ## LEAK-CYCLE-01 — see _fixture_slabs
		var out: Array = []
		for x in range(10):
			for y in range(10):
				out.append(VoxelClass.new(Vector2i(x, y), GeometryCoords.FLOOR_DEEP_LEVEL, slab))
		return out

	var locked: Array = make_deep_patch.call()
	BlastCalculatorClass.apply_crater_damage(locked, "DEEP_GATE_TEST", epicenter, 3.0, 6.0, "concrete")
	var locked_touched := 0
	for v in locked:
		if v.damage_state != Voxel.DamageState.INTACT:
			locked_touched += 1

	var unlocked: Array = make_deep_patch.call()
	BlastCalculatorClass.apply_crater_damage(unlocked, "DEEP_GATE_TEST", epicenter, 3.0, 6.0, "concrete", true)
	var unlocked_destroyed := 0
	for v in unlocked:
		if v.damage_state == Voxel.DamageState.DESTROYED:
			unlocked_destroyed += 1

	if locked_touched == 0:
		_pass("deep_layer_unlocked=false (default): every FLOOR_DEEP_LEVEL voxel stays INTACT, even inside core_radius")
	else:
		_fail("deep_layer_unlocked=false: %d deep-level voxels still took damage" % locked_touched)

	if unlocked_destroyed > 0:
		_pass("deep_layer_unlocked=true: %d deep-level voxels destroyed inside core_radius" % unlocked_destroyed)
	else:
		_fail("deep_layer_unlocked=true: expected core-radius deep voxels destroyed, got 0")
	print("")


## D17 — slab_pierce_multiplier must visibly change the destroy count in the
## crater's RIM band (core_radius is already 100% destroy regardless, so the
## multiplier only has room to act where keep_prob < 1.0), proving the knob
## is live and not a dead trailing parameter.
func test_slab_pierce_multiplier_scales_destruction() -> void:
	print("[E-RING-6] D17: slab_pierce_multiplier scales rim destruction, harmless at the 1.0 default\n")

	var epicenter := Vector2i(0, 0)
	var make_patch := func() -> Array:
		var slab := Slab.new("PIERCE_TEST", Vector2i.ZERO, Slab.Role.CEILING, 0, "concrete")
		_fixture_slabs.append(slab)  ## LEAK-CYCLE-01 — see _fixture_slabs
		var out: Array = []
		for x in range(20):
			for y in range(20):
				out.append(VoxelClass.new(Vector2i(x, y), 0, slab))
		return out

	var base: Array = make_patch.call()
	BlastCalculatorClass.apply_crater_damage(base, "PIERCE_TEST", epicenter, 4.0, 14.0, "", false, 1.0)
	var pierced: Array = make_patch.call()
	BlastCalculatorClass.apply_crater_damage(pierced, "PIERCE_TEST", epicenter, 4.0, 14.0, "", false, 3.0)

	var base_destroyed := _count_destroyed(base)
	var pierced_destroyed := _count_destroyed(pierced)

	if pierced_destroyed > base_destroyed:
		_pass("slab_pierce_multiplier 3.0 destroyed %d vs %d at 1.0x — scales rim destruction" %
			[pierced_destroyed, base_destroyed])
	else:
		_fail("multiplier did not scale: 3.0x=%d 1.0x=%d" % [pierced_destroyed, base_destroyed])

	## The default (omitted) must be byte-for-byte the explicit-1.0 behavior.
	var explicit: Array = make_patch.call()
	BlastCalculatorClass.apply_crater_damage(explicit, "PIERCE_TEST", epicenter, 4.0, 14.0)
	if _count_destroyed(explicit) == base_destroyed:
		_pass("omitting slab_pierce_multiplier matches passing 1.0 explicitly — existing callers unaffected")
	else:
		_fail("default diverged from explicit 1.0: %d vs %d" % [_count_destroyed(explicit), base_destroyed])
	print("")


func _count_destroyed(voxels: Array) -> int:
	var n := 0
	for v in voxels:
		if v.damage_state == Voxel.DamageState.DESTROYED:
			n += 1
	return n


func _synthetic_voxels(count: int) -> Array:
	var voxels: Array = []
	var slab := Slab.new("DUMMY", Vector2i.ZERO, Slab.Role.FLOOR, -1, "earth")
	_fixture_slabs.append(slab)
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


## WEAPON_MASTER_PLAN D26-D28 (Director, 2026-07-30) — a shot is N discrete
## pellet point-impacts, never a flood-filled area; no authored range cap.


## A wall wide enough (in x) that a pellet drifting laterally within
## half_angle_deg over `depth` forward steps still finds it — isolates the
## count/range/determinism tests from the per-pellet angle spread, which the
## narrow-obstacle test below exercises on purpose instead.
func _wide_wall_registry(row_near: int, row_far: int, x_from: int, x_to: int, material: String) -> EdgeRegistry:
	var registry := EdgeRegistry.new()
	var edges: Array = []
	for x in range(x_from, x_to + 1):
		edges.append(Edge.between(Vector2i(x, row_near), Vector2i(x, row_far), 1, material))
	SliceGenerator.generate(edges, registry)
	return registry


func _wide_wall_blocked(row_near: int, row_far: int, x_from: int, x_to: int) -> Dictionary:
	var blocked: Dictionary = {}
	for x in range(x_from, x_to + 1):
		blocked[WallEdgeData.edge_key(Vector2i(x, row_far), Vector2i(x, row_near))] = true
	return blocked


func test_pellet_impacts_no_hard_range_cap() -> void:
	print("TEST: D26 - no range cap, a wall 9 GU away still yields pellet candidates")
	## Wide wall between y=-5 and y=-4, x=0..10: flood from (5,5) facing NE
	## crosses 9 steps of open ground — well past the OLD ceiling
	## (weapon_def.step_multipliers.size()-1 = 4 for the shotgun).
	_wide_wall_registry(-5, -4, 0, 10, "concrete")
	var blocked := _wide_wall_blocked(-5, -4, 0, 10)
	var picks := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 25.0, 40, 8, blocked, {}, "RANGE_TEST")
	if picks.size() == 8:
		_pass("8 pellets picked against a wall 9 GU away — the old 4-step ceiling would have found nothing")
	else:
		_fail("expected 8 picks, got %d — did a pellet path stop short?" % picks.size())
	print("")


func test_pellet_impacts_count_matches_projectile_count() -> void:
	print("TEST: pellet pick count matches projectile_count when every pellet finds the (wide) wall")
	_wide_wall_registry(1, 2, 0, 10, "concrete")
	var blocked := _wide_wall_blocked(1, 2, 0, 10)
	var picks3 := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 25.0, 40, 3, blocked, {}, "COUNT_A")
	var picks8 := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 25.0, 40, 8, blocked, {}, "COUNT_B")
	if picks3.size() == 3 and picks8.size() == 8:
		_pass("3 pellets -> 3 picks, 8 pellets -> 8 picks")
	else:
		_fail("pick count mismatch: 3->%d, 8->%d" % [picks3.size(), picks8.size()])
	print("")


func test_pellet_does_not_detour_around_narrow_obstacle() -> void:
	print("TEST: D26/D27 regression - a pellet does not walk AROUND a narrow obstacle to something behind it")
	## Real bug, caught on the real bench 2026-07-30, TWO layers deep:
	## (a) an earlier version aggregated flood_gu_cone()'s WHOLE reachable set
	##     and picked wall-adjacent cells from all of it, so a pellet's
	##     "impact" could be a wall reached by flowing sideways around a
	##     narrow block via some other open path — fixed by giving each
	##     pellet its own straight(ish) walk.
	## (b) that walk only checked blocked_edges, but MapCompiler's solid GU
	##     blocks (spec.blocks — this bench's own material walls) mark whole
	##     CELLS occupied (room._blocked_cells, the same dict LOS already
	##     uses) and never touch blocked_edges at all — so the straight walk
	##     STILL sailed straight through a real block and hit the room's
	##     outer wall behind it. Every pellet came back "concrete" regardless
	##     of which material column was actually fired at. Both forms tested:
	## a single-GU obstacle with nothing else blocked anywhere nearby makes a
	## leak unmistakable either way — a dead-centre pellet (half_angle 0)
	## must stop AT the block, not beyond it.
	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(5, 1), Vector2i(5, 2), 1, "metal")]
	SliceGenerator.generate(edges, registry)

	var edge_blocked: Dictionary = {WallEdgeData.edge_key(Vector2i(5, 2), Vector2i(5, 1)): true}
	var picks_edge := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 0.0, 40, 1, edge_blocked, {}, "NARROW_TEST_EDGE")
	if picks_edge.size() == 1 and picks_edge[0]["gu"] == Vector2i(5, 2) and picks_edge[0]["face"] == Face.NE:
		_pass("blocked_edges form: dead-centre pellet stopped at (5,2)/NE — did not detour past it")
	else:
		_fail("blocked_edges form: expected exactly one pick at (5,2)/NE, got %s" % [picks_edge])

	## The form that actually broke on the real bench: the obstacle cell is
	## OCCUPIED (blocked_cells), not edge-flagged at all.
	var occupied: Dictionary = {Vector2i(5, 2): true}
	var picks_cell := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 0.0, 40, 1, {}, occupied, "NARROW_TEST_CELL")
	if picks_cell.size() == 1 and picks_cell[0]["gu"] == Vector2i(5, 3) and picks_cell[0]["face"] == Face.NE:
		_pass("blocked_cells form: dead-centre pellet stopped at (5,3), facing the occupied (5,2) — the exact real-bench bug")
	else:
		_fail("blocked_cells form: expected exactly one pick at (5,3)/NE, got %s" % [picks_cell])
	print("")


func test_point_impact_marks_only_the_impact_voxel() -> void:
	print("TEST: D28/D30 - a MARK exists ONLY at the impact voxel; neighbours may be DESTROYED but never marked")
	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(5, 1), Vector2i(5, 2), 1, "wood")]
	SliceGenerator.generate(edges, registry)
	var slice: Slice = registry.get_slice("SLICE_5_2_NE")
	if slice == null:
		_fail("Could not resolve synthetic wood Slice (id lookup mismatch)")
		print("")
		return
	## D30 amends D28's SCOPE, not its invariant: a heavy round now takes
	## neighbours with it, but the mark itself stays the projectile's alone.
	## Driven at a punch high enough to guarantee a full 8-neighbour hole, so
	## this exercises the amended path rather than trivially passing on a shot
	## that destroyed nothing.
	var touched := BlastCalculatorClass.apply_point_impact(
		slice, 12, 2.5, registry, "ISOLATION_TEST")
	var marked_strays := 0
	var destroyed_strays := 0
	for i in range(slice.voxels.size()):
		if i == 12:
			continue
		var st: int = slice.voxels[i].damage_state
		if st == Voxel.DamageState.DENTED or st == Voxel.DamageState.CRACKED:
			marked_strays += 1
		elif st == Voxel.DamageState.DESTROYED:
			destroyed_strays += 1
	if marked_strays == 0 and destroyed_strays > 0 and touched.size() > 1:
		_pass("%d neighbours DESTROYED, ZERO of them marked (%d touched total) — D30.1 holds: only the projectile marks" %
			[destroyed_strays, touched.size()])
	else:
		_fail("marked_strays=%d (must be 0), destroyed_strays=%d (must be >0 at punch 2.5)" %
			[marked_strays, destroyed_strays])
	print("")


func test_point_impact_neighbour_ladder() -> void:
	print("TEST: D30 - neighbour count is monotonic in punch, 0 below the start, capped at 8")
	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(5, 1), Vector2i(5, 2), 1, "wood")]
	SliceGenerator.generate(edges, registry)
	var counts: Array = []
	for punch in [0.8, 1.0, 1.5, 2.0, 2.5, 4.0]:
		var slice: Slice = registry.get_slice("SLICE_5_2_NE")
		for v in slice.voxels:
			v.damage_state = Voxel.DamageState.INTACT
		var sib := registry.sibling_slice(slice.id)
		if sib != null:
			for v in sib.voxels:
				v.damage_state = Voxel.DamageState.INTACT
		BlastCalculatorClass.apply_point_impact(slice, 12, punch, registry, "LADDER_%f" % punch)
		var destroyed := 0
		for i in range(slice.voxels.size()):
			if i != 12 and slice.voxels[i].damage_state == Voxel.DamageState.DESTROYED:
				destroyed += 1
		counts.append(destroyed)
	var monotonic := true
	for i in range(1, counts.size()):
		if counts[i] < counts[i - 1]:
			monotonic = false
	## Index 12 is an interior voxel of an 8-wide slice, so all 8 neighbours exist.
	if monotonic and counts[0] == 0 and counts[counts.size() - 1] == 8:
		_pass("neighbour counts across punch [0.8,1.0,1.5,2.0,2.5,4.0] = %s — monotonic, 0 below start, capped at 8" % [counts])
	else:
		_fail("counts=%s (expected monotonic, first 0, last 8)" % [counts])
	print("")


func test_point_impact_cascades_only_on_full_destroy() -> void:
	print("TEST: D28/D30 - the CENTRE column cascades one layer when destroyed; neighbours only cascade above NEIGHBOUR_CASCADE_PUNCH")
	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(5, 1), Vector2i(5, 2), 1, "metal")]
	SliceGenerator.generate(edges, registry)
	var slice: Slice = registry.get_slice("SLICE_5_2_NE")
	var sib := registry.sibling_slice(slice.id)
	if slice == null or sib == null:
		_fail("Could not resolve the synthetic metal Slice pair")
		print("")
		return

	## Below the DESTROY threshold: a mark and nothing else — no cascade at all.
	var touched_mark := BlastCalculatorClass.apply_point_impact(
		slice, 12, 0.4, registry, "CASCADE_MARK")
	var mark_ok: bool = touched_mark.size() == 1 \
		and slice.voxels[12].damage_state == Voxel.DamageState.DENTED \
		and sib.voxels[12].damage_state == Voxel.DamageState.INTACT

	## Mid punch: the round goes through and the hole NARROWS behind it.
	##
	## W-TUNE-02 (2026-08-20) changed what this half can assert. It used to demand
	## `sib_destroyed_mid <= 1` — no neighbours at all in layer 2 — which held only
	## because NEIGHBOUR_PUNCH_START (1.0) sat above every attenuated depth-1
	## punch. The Director's spec now asks for exactly what that forbade: *"o fuzil
	## perfura e pode destruir uns 5 voxels na primeira slice e até 3 na segunda"*,
	## and three in the second slice IS a centre plus two neighbours.
	##
	## What D30.2 actually guarantees is still here and still tested: below
	## NEIGHBOUR_CASCADE_PUNCH the second layer is damaged by the round that
	## reached it — attenuated, so its hole is SMALLER — rather than receiving a
	## copy of the first layer's neighbour pattern. That is the difference the
	## heavy case below measures.
	_reset_slice_pair(slice, sib)
	BlastCalculatorClass.apply_point_impact(slice, 12, 1.6, registry, "CASCADE_MID")
	var sib_destroyed_mid := 0
	for i in range(sib.voxels.size()):
		if sib.voxels[i].damage_state == Voxel.DamageState.DESTROYED:
			sib_destroyed_mid += 1
	var face_destroyed_mid := 0
	for i in range(slice.voxels.size()):
		if slice.voxels[i].damage_state == Voxel.DamageState.DESTROYED:
			face_destroyed_mid += 1
	var mid_ok: bool = slice.voxels[12].damage_state == Voxel.DamageState.DESTROYED \
		and sib_destroyed_mid >= 1 and sib_destroyed_mid < face_destroyed_mid

	## Above NEIGHBOUR_CASCADE_PUNCH: the crater goes through — neighbours
	## reach the second layer too.
	_reset_slice_pair(slice, sib)
	BlastCalculatorClass.apply_point_impact(slice, 12, 6.0, registry, "CASCADE_HEAVY")
	var sib_destroyed_heavy := 0
	for i in range(sib.voxels.size()):
		if sib.voxels[i].damage_state == Voxel.DamageState.DESTROYED:
			sib_destroyed_heavy += 1
	var heavy_ok: bool = sib_destroyed_heavy > sib_destroyed_mid

	if mark_ok and mid_ok and heavy_ok:
		_pass("punch 0.4 -> mark only, no cascade; punch 1.6 -> through, hole narrows (%d in layer 1, %d in layer 2); punch 6.0 -> the whole crater goes through (%d in layer 2)" %
			[face_destroyed_mid, sib_destroyed_mid, sib_destroyed_heavy])
	else:
		_fail("mark_ok=%s mid_ok=%s (layer2=%d) heavy_ok=%s (layer2=%d)" %
			[mark_ok, mid_ok, sib_destroyed_mid, heavy_ok, sib_destroyed_heavy])
	print("")


## A HOLE IS NOT A TARGET — the regression pin for a bug that shipped and was
## caught on the real map, not here.
##
## Two shotgun shots at PLAYGROUND's wood block in one boot wrote
## DESTROYED -> DENTED on two voxels the first shot had already opened. The salt
## carries `room._world_revision`, which every shot bumps, so consecutive shots at
## one target roll different luck — measured 1.11 then 0.96 against wood's breach
## of 1.03 — and nothing between the ladder and `set_damage()` (which must not
## clamp: the segment-rewind system has to be able to walk a voxel back) checked
## whether the voxel was still there.
##
## This test drives the exact sequence: destroy, then hit the same index with a
## punch that would only mark. The hole must stay a hole, and the round must
## arrive at the slice behind it — which is what the real fix's counts showed
## (`wood:s1 dented` 19 -> 17, `wood:s2 dented` 2 -> 4).
func test_point_impact_never_re_marks_an_existing_hole() -> void:
	print("TEST: an already-DESTROYED voxel is a hole the round passes THROUGH, never a surface it re-marks")
	var registry := EdgeRegistry.new()
	var edges: Array = [Edge.between(Vector2i(9, 1), Vector2i(9, 2), 1, "wood")]
	SliceGenerator.generate(edges, registry)
	var slice: Slice = registry.get_slice("SLICE_9_2_NE")
	var sib := registry.sibling_slice(slice.id)
	if slice == null or sib == null:
		_fail("Could not resolve the synthetic wood Slice pair")
		print("")
		return

	## Shot 1: hard enough to breach. blowout 0.0 keeps the hole to one voxel, so
	## the second shot's target is unambiguous.
	BlastCalculatorClass.apply_point_impact(
		slice, 12, 2.0, registry, "HOLE_FIRST", [], BlastCalculatorClass.NO_EPICENTER_BIAS, 0.0)
	var opened: bool = slice.voxels[12].damage_state == Voxel.DamageState.DESTROYED
	var sib_before: int = sib.voxels[12].damage_state

	## Shot 2: same index, a punch that can only MARK. Pre-fix this wrote DENTED
	## over the hole; post-fix it must skip the hole entirely.
	var touched := BlastCalculatorClass.apply_point_impact(
		slice, 12, 0.4, registry, "HOLE_SECOND", [], BlastCalculatorClass.NO_EPICENTER_BIAS, 0.0)
	var hole_held: bool = slice.voxels[12].damage_state == Voxel.DamageState.DESTROYED
	## ...and the round is not swallowed: it reaches the slice behind and marks it.
	var reached_sibling: bool = sib.voxels[12].damage_state != sib_before \
		and sib.voxels[12].damage_state != Voxel.DamageState.INTACT
	var no_hole_entry: bool = true
	for v in touched:
		if v == slice.voxels[12]:
			no_hole_entry = false

	if opened and hole_held and reached_sibling and no_hole_entry:
		_pass("the hole stayed DESTROYED, the plan carried no entry for it, and the round marked the slice behind (state %d)"
			% sib.voxels[12].damage_state)
	else:
		_fail("opened=%s hole_held=%s (state %d) reached_sibling=%s (state %d) no_hole_entry=%s" %
			[opened, hole_held, slice.voxels[12].damage_state,
			reached_sibling, sib.voxels[12].damage_state, no_hole_entry])
	print("")


func _reset_slice_pair(a: Slice, b: Slice) -> void:
	for v in a.voxels:
		v.damage_state = Voxel.DamageState.INTACT
	for v in b.voxels:
		v.damage_state = Voxel.DamageState.INTACT


func test_punch_coefficient_ordering() -> void:
	print("TEST: D30 - the punch coefficient orders correctly across weapon, skill, material and distance")
	## Weapon ordering at neutral everything: sniper > rifle > revolver > pistol
	## > smg > one shotgun pellet. This is the Director's stated intent —
	## *"sniper deixa 1 buraco maior, shotgun deixa vários pequenos"* — expressed
	## as a single number, so a regression in the JSONs shows up here.
	var order: Array = []
	for wp in [0.70, 0.45, 0.35, 0.25, 0.22, 0.12]:
		order.append(ShotPunchTable.compute(wp, "concrete", ShotPunchTable.SKILL_NEUTRAL,
			1.0, "ORDER_FIXED"))
	var weapon_ok := true
	for i in range(1, order.size()):
		if order[i] >= order[i - 1]:
			weapon_ok = false

	## Skill: novice < neutral < elite, same weapon and material.
	var novice: float = ShotPunchTable.compute(0.70, "concrete", ShotPunchTable.SKILL_NOVICE, 1.0, "S")
	var neutral: float = ShotPunchTable.compute(0.70, "concrete", ShotPunchTable.SKILL_NEUTRAL, 1.0, "S")
	var elite: float = ShotPunchTable.compute(0.70, "concrete", ShotPunchTable.SKILL_ELITE, 1.0, "S")
	var skill_ok: bool = novice < neutral and neutral < elite

	## Material: the harder the material, the lower the punch.
	var on_metal: float = ShotPunchTable.compute(0.70, "metal", 1.0, 1.0, "M")
	var on_concrete: float = ShotPunchTable.compute(0.70, "concrete", 1.0, 1.0, "M")
	var on_wood: float = ShotPunchTable.compute(0.70, "wood", 1.0, 1.0, "M")
	var material_ok: bool = on_metal < on_concrete and on_concrete < on_wood

	## D1's two meanings of step_multipliers must NOT be interchangeable.
	## CONE: distance bands, indexed by GU travelled, holding the last entry past
	## the table's end (D26 — a miss keeps travelling, it does not stop at range).
	var falloff: Array = [1.0, 0.5]
	var near: float = ShotPunchTable.cone_distance_multiplier(falloff, 0)
	var far: float = ShotPunchTable.cone_distance_multiplier(falloff, 1)
	var beyond: float = ShotPunchTable.cone_distance_multiplier(falloff, 99)
	var distance_ok: bool = far < near and is_equal_approx(beyond, far)

	## LINE: the SAME table read as penetration depth. Layer 0 never attenuates;
	## layer 1 takes the table's own second entry, NOT the flat fallback. This is
	## the exact confusion that shipped and was caught on the bench — a sniper
	## reading its penetration table as distance came out weaker at range than a
	## pistol.
	var sniper_steps: Array = [1.0, 0.95, 0.9]
	var pen_ok: bool = is_equal_approx(ShotPunchTable.penetration_multiplier(sniper_steps, 0), 1.0) \
		and is_equal_approx(ShotPunchTable.penetration_multiplier(sniper_steps, 1), 0.95) \
		and is_equal_approx(ShotPunchTable.penetration_multiplier([], 1), ShotPunchTable.PENETRATION_FALLOFF)

	## Luck: same inputs, different shot salt -> different punch, but always
	## inside [LUCK_MIN, LUCK_MAX] of the unlucked value.
	var luck_values: Dictionary = {}
	for i in range(50):
		luck_values[ShotPunchTable.luck_for("LUCK_%d" % i)] = true
	var luck_ok: bool = luck_values.size() > 1
	for lv in luck_values:
		if lv < ShotPunchTable.LUCK_MIN or lv > ShotPunchTable.LUCK_MAX:
			luck_ok = false

	if weapon_ok and skill_ok and material_ok and distance_ok and pen_ok and luck_ok:
		_pass("weapon order %s strictly descending; skill %.2f<%.2f<%.2f; metal %.2f < concrete %.2f < wood %.2f; CONE distance holds past table end; LINE penetration reads its own table; %d distinct luck values in range" %
			[order.map(func(v): return snappedf(v, 0.01)), novice, neutral, elite,
			on_metal, on_concrete, on_wood, luck_values.size()])
	else:
		_fail("weapon_ok=%s skill_ok=%s material_ok=%s distance_ok=%s pen_ok=%s luck_ok=%s" %
			[weapon_ok, skill_ok, material_ok, distance_ok, pen_ok, luck_ok])
	print("")


func test_cone_spread_is_a_disc_not_a_line() -> void:
	print("TEST: CONE-DISC-01 - shotgun pellets scatter over an AREA that grows with distance, not along one voxel row")
	## The regression this pins: resolve_pellet_voxel() used to place every
	## pellet at chest level, so 24 pellets landed on ONE row — the horizontal
	## streak in the Director's capture. Asserting "more than one row" is the
	## whole point, so it must be measured from the real functions.
	var registry := _wide_wall_registry(1, 2, 0, 20, "concrete")
	var blocked := _wide_wall_blocked(1, 2, 0, 20)

	var near_rows: Dictionary = {}
	var near_cells: Dictionary = {}
	var picks_near := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(10, 5), NE, 6.0, 40, 24, blocked, {}, "DISC_NEAR")
	for i in range(picks_near.size()):
		var r := BlastCalculatorClass.resolve_pellet_voxel(picks_near[i], registry, "DISC_NEAR:%d" % i)
		if r.is_empty():
			continue
		var idx: int = r["voxel_index"]
		near_rows[idx / GeometryCoords.VOXELS_PER_UNIT_AXIS] = true
		near_cells["%s:%d" % [r["slice"].id, idx]] = true

	## Same weapon, further away: the cone is wider there, so the pattern must
	## cover at least as many rows — *"tiros de longe erram mais longe"*.
	var far_rows: Dictionary = {}
	var picks_far := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(10, 12), NE, 6.0, 40, 24, blocked, {}, "DISC_FAR")
	for i in range(picks_far.size()):
		var r := BlastCalculatorClass.resolve_pellet_voxel(picks_far[i], registry, "DISC_FAR:%d" % i)
		if r.is_empty():
			continue
		far_rows[int(r["voxel_index"]) / GeometryCoords.VOXELS_PER_UNIT_AXIS] = true

	var vertical_ok: bool = near_rows.size() > 1
	var grows_ok: bool = far_rows.size() >= near_rows.size()
	var area_ok: bool = near_cells.size() > near_rows.size()

	if vertical_ok and grows_ok and area_ok:
		_pass("near shot covers %d rows / %d distinct voxels; far shot covers %d rows — an area, and it widens with range" %
			[near_rows.size(), near_cells.size(), far_rows.size()])
	else:
		_fail("vertical_ok=%s (near rows=%d) grows_ok=%s (far rows=%d) area_ok=%s (near cells=%d)" %
			[vertical_ok, near_rows.size(), grows_ok, far_rows.size(), area_ok, near_cells.size()])
	print("")


func test_no_shipped_weapon_reaches_the_cascade() -> void:
	print("TEST: D30.2 - no weapon in the shipped arsenal can trigger the neighbour cascade (that is reserved for a future heavy weapon)")
	## Reads the REAL weapon JSONs, not a fixture: the whole point is to catch a
	## future balance edit that quietly turns a rifle into a bazooka. An earlier
	## pass set this threshold from a concrete-only hand calculation and was
	## wrong by 2x because wood is softer — hence a test over every material,
	## at the worst case of every other factor.
	var dir := DirAccess.open("res://weapons")
	if dir == null:
		_fail("could not open res://weapons")
		print("")
		return
	var worst := 0.0
	var worst_label := ""
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("res://weapons/%s" % file_name)
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			_fail("could not parse weapons/%s" % file_name)
			print("")
			return
		var def := WeaponDef.from_json(data)
		for material in ShotPunchTable.RESISTANCE:
			## ⚠️ THE GLASS EXCLUSION IS GONE, and its removal is the POINT of
			## A0b rather than a side effect. This loop used to carry a hardcoded
			## `if material == "glass": continue`, because at resistance 0.4 a
			## sniper reaches punch 8.82 against a global ceiling of 5.0 — and
			## that comment ended with "if glass ever gets its own destruction
			## rule this exclusion goes". Adding cardboard (0.35), fabric (0.3)
			## and plywood (0.6) would have grown it to four siblings, at which
			## point the test pins nothing.
			##
			## Now every material is measured against ITS OWN ceiling
			## (ShotPunchTable.cascade_min), so the property under test is the one
			## D30.2 actually states — no shipped weapon craters ANY material —
			## and it is now genuinely checked for the soft ones instead of
			## skipped. The headroom is what is being pinned: a future heavy
			## weapon must be able to reach these, so this reports the closest
			## approach rather than merely passing.
			## Worst case: elite agent, point blank (step 0), luckiest roll.
			var p: float = ShotPunchTable.PUNCH_GAIN * def.punch \
				* ShotPunchTable.SKILL_ELITE \
				* ShotPunchTable.cone_distance_multiplier(def.step_multipliers, 0) \
				* ShotPunchTable.LUCK_MAX \
				/ ShotPunchTable.resistance(material)
			## Normalised: how close this weapon gets to THIS material's ceiling.
			## Comparing raw punch across materials is meaningless once the
			## ceiling varies — fabric's 11.76 is further from its own 13.5 than
			## wood's 4.41 is from 5.0.
			var ratio: float = p / maxf(ShotPunchTable.cascade_min(material), 0.001)
			if ratio > worst:
				worst = ratio
				worst_label = "%s on %s (punch %.2f vs ceiling %.2f)" % \
					[def.id, material, p, ShotPunchTable.cascade_min(material)]
	## `worst` is now a RATIO to each material's own ceiling, so 1.0 is the
	## threshold for every material at once and the number is comparable across
	## a table that is no longer flat.
	if worst > 0.0 and worst < 1.0:
		_pass("arsenal worst case is %s — %.0f%% of that material's own ceiling, over %d materials with no exclusions" %
			[worst_label, worst * 100.0, ShotPunchTable.RESISTANCE.size()])
	else:
		_fail("worst case %s reached %.0f%% of its material's ceiling — at or above it" %
			[worst_label, worst * 100.0])
	print("")


func test_line_impact_is_straight_and_measures_distance() -> void:
	print("TEST: D30 - LINE fires ONE straight ray and reports the GU distance it travelled")
	_wide_wall_registry(1, 2, 0, 10, "concrete")
	var blocked := _wide_wall_blocked(1, 2, 0, 10)
	## Muzzle at (5,5) firing NE (toward -Y) into the wall between rows 2 and 1.
	var hit := BlastCalculatorClass.select_line_impact(Vector2i(5, 5), NE, 40, blocked, {})
	var straight_ok: bool = not hit.is_empty() \
		and hit["gu"] == Vector2i(5, 2) \
		and hit["face"] == Face.NE \
		and int(hit["steps"]) == 3

	## Determinism: LINE has no angular term at all, so two identical calls must
	## be identical — and unlike a cone pellet, no salt is even involved.
	var hit_again := BlastCalculatorClass.select_line_impact(Vector2i(5, 5), NE, 40, blocked, {})
	var deterministic_ok: bool = hit == hit_again

	## A ray into open space finds nothing and returns {} — it keeps travelling
	## (D26), it does not stop at a range limit and invent an impact.
	var miss := BlastCalculatorClass.select_line_impact(Vector2i(5, 5), -NE, 40, {}, {})
	var miss_ok: bool = miss.is_empty()

	if straight_ok and deterministic_ok and miss_ok:
		_pass("ray from (5,5) NE stopped at (5,2)/NE after 3 GU steps; identical on repeat; a ray into the void returns {}")
	else:
		_fail("straight_ok=%s (hit=%s) deterministic_ok=%s miss_ok=%s" %
			[straight_ok, hit, deterministic_ok, miss_ok])
	print("")


## §6c Part A (2026-08-19) — `aim_offset_deg`, the term that lets a shot fired BY
## AN ACTOR aim at another ACTOR that is not on a shared grid axis.
##
## The test that actually matters is the DEFAULT one: every caller written before
## this parameter existed passes nothing, and all of them must stay bit-identical
## or the parameter is a silent behaviour change to the shipped bench path
## instead of an addition.
func test_aim_offset_steers_the_shot_off_axis() -> void:
	print("TEST: §6c aim_offset_deg biases the cone/ray off the grid axis, and defaults to a no-op")
	_wide_wall_registry(1, 2, 0, 10, "concrete")
	var blocked := _wide_wall_blocked(1, 2, 0, 10)

	## 1. DEFAULT IS A NO-OP. Explicit 0.0 must equal the omitted argument, for
	##    both shapes — this is the backwards-compatibility claim itself.
	var line_omitted := BlastCalculatorClass.select_line_impact(
		Vector2i(5, 5), NE, 40, blocked, {})
	var line_zero := BlastCalculatorClass.select_line_impact(
		Vector2i(5, 5), NE, 40, blocked, {}, 0.0)
	var cone_omitted := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 25.0, 40, 8, blocked, {}, "AIM_OFFSET_DEFAULT")
	var cone_zero := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 25.0, 40, 8, blocked, {}, "AIM_OFFSET_DEFAULT", 0.0)
	var default_ok: bool = line_omitted == line_zero and cone_omitted.size() == cone_zero.size()
	if default_ok:
		for i in range(cone_omitted.size()):
			if cone_omitted[i]["gu"] != cone_zero[i]["gu"] \
					or cone_omitted[i]["face"] != cone_zero[i]["face"]:
				default_ok = false
				break

	## 2. A NON-ZERO OFFSET ACTUALLY MOVES THE IMPACT, and moves it the way the
	##    sign says. Firing NE from (5,5) into the wall north of row 2 lands at
	##    x=5 dead on axis; `lateral` for NE=(0,-1) is (1,0), so a POSITIVE
	##    offset must drift the impact toward +x and a negative one toward -x.
	##    Asserting the DIRECTION and not just "it differs" is the point — a sign
	##    error here aims every actor's shot at the mirror image of its target.
	var pos := BlastCalculatorClass.select_line_impact(
		Vector2i(5, 5), NE, 40, blocked, {}, 25.0)
	var neg := BlastCalculatorClass.select_line_impact(
		Vector2i(5, 5), NE, 40, blocked, {}, -25.0)
	var on_axis_x: int = int(line_omitted["gu"].x) if not line_omitted.is_empty() else -999
	var pos_ok: bool = not pos.is_empty() and int(pos["gu"].x) > on_axis_x
	var neg_ok: bool = not neg.is_empty() and int(neg["gu"].x) < on_axis_x

	## 3. STILL DETERMINISTIC. The offset is applied to the angle AFTER the hash,
	##    so B4's FNV-1a determinism must survive it untouched.
	var det_a := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 25.0, 40, 8, blocked, {}, "AIM_OFFSET_DET", 18.0)
	var det_b := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 25.0, 40, 8, blocked, {}, "AIM_OFFSET_DET", 18.0)
	var det_ok: bool = det_a.size() == det_b.size()
	if det_ok:
		for i in range(det_a.size()):
			if det_a[i]["gu"] != det_b[i]["gu"] or det_a[i]["face"] != det_b[i]["face"]:
				det_ok = false
				break

	if default_ok and pos_ok and neg_ok and det_ok:
		_pass("default is bit-identical to 0.0 for CONE and LINE; +25 deg drifts to x=%d and -25 deg to x=%d around the on-axis x=%d; offset picks stay deterministic" %
			[int(pos["gu"].x), int(neg["gu"].x), on_axis_x])
	else:
		_fail("default_ok=%s pos_ok=%s (%s) neg_ok=%s (%s) det_ok=%s on_axis_x=%d" %
			[default_ok, pos_ok, pos, neg_ok, neg, det_ok, on_axis_x])
	print("")


func test_pellet_selection_is_deterministic() -> void:
	print("TEST: pellet picks are deterministic (no RNG, D22) — identical inputs, identical picks")
	_wide_wall_registry(1, 2, 0, 10, "concrete")
	var blocked := _wide_wall_blocked(1, 2, 0, 10)
	var picks_a := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 25.0, 40, 8, blocked, {}, "DETERMINISM_TEST")
	var picks_b := BlastCalculatorClass.select_cone_pellet_impacts(
		Vector2i(5, 5), NE, 25.0, 40, 8, blocked, {}, "DETERMINISM_TEST")
	var same := true
	for i in range(picks_a.size()):
		if picks_a[i]["gu"] != picks_b[i]["gu"] or picks_a[i]["face"] != picks_b[i]["face"]:
			same = false
			break
	if same:
		_pass("two calls with identical inputs picked the identical 8 pellets")
	else:
		_fail("identical inputs produced different pellet picks")
	print("")


## D25 (Director diagram, 2026-07-31) — a DENTED voxel is carved on the side
## that faced the blast. This is the regression guard for the Director's
## 2026-07-31 report: a ceiling above a grenade was showing its damage on the
## outward TOP ("as marcas estão aparecendo por cima") when a blast passing
## underneath can only ever eat the underside.
func test_carved_side_faces_the_blast() -> void:
	print("TEST: D25 — the carved side is the one that faced the explosion")

	## A roof container is above whatever blast reached it, so it always
	## carves BOTTOM — this is the reported bug, pinned.
	var roof_side: int = BlastCalculatorClass.carved_side_for(
		Vector2i(10, 10), true, Vector2i(10, 20))
	if roof_side == Voxel.CarvedSide.BOTTOM:
		_pass("roof voxel carves BOTTOM (blast came from below, not above)")
	else:
		_fail("roof voxel expected CarvedSide.BOTTOM, got %d" % roof_side)

	## Walls resolve left/right in SCREEN space, where x runs along (x − y).
	## Epicentre at (0,20): screen-x −20, vs the voxel's 0 → screen-left.
	var left_side: int = BlastCalculatorClass.carved_side_for(
		Vector2i(10, 10), false, Vector2i(0, 20))
	var right_side: int = BlastCalculatorClass.carved_side_for(
		Vector2i(10, 10), false, Vector2i(20, 0))
	if left_side == Voxel.CarvedSide.LEFT and right_side == Voxel.CarvedSide.RIGHT:
		_pass("wall voxel carves toward the epicentre on both screen sides")
	else:
		_fail("wall expected LEFT/RIGHT, got %d/%d" % [left_side, right_side])

	## No epicentre supplied (every pure-hash caller and its tests) must not
	## invent a direction — it falls back to the flat pre-D25 mark.
	var none_side: int = BlastCalculatorClass.carved_side_for(
		Vector2i(10, 10), false, BlastCalculatorClass.NO_EPICENTER_BIAS)
	if none_side == Voxel.CarvedSide.NONE:
		_pass("no epicentre bias → CarvedSide.NONE, no guessed direction")
	else:
		_fail("expected CarvedSide.NONE without a bias epicentre, got %d" % none_side)
	print("")


## D25 — the carved side is stored in BASE space and re-derived per view, so a
## hole stays on the physical side that faced the blast instead of following
## the screen when the map turns. Exercises room.gd's REAL static conversions
## (not a copy) across all four perspectives.
func test_carved_side_survives_rotation() -> void:
	print("TEST: D25 — carved side round-trips through base space, all 4 views")

	## Owned by BlastCalculator, not room.gd — room only persists what it decides.
	var base_size := Vector2i(160, 144)     ## a 20×18 GU map at 8 voxels/GU
	var cell := Vector2i(40, 56)
	var views: Array = ["N", "E", "S", "W"]

	## 1. Same view in and out must return the side it went in as.
	var round_trip_ok := true
	for view in views:
		for side in [Voxel.CarvedSide.LEFT, Voxel.CarvedSide.RIGHT,
				Voxel.CarvedSide.TOP, Voxel.CarvedSide.BOTTOM]:
			var dir: Vector3i = BlastCalculatorClass.carved_side_to_base_dir(cell, side, view, base_size)
			var base_xy: Vector2i = PerspectiveMapperClass.cell_to_base(cell, view, base_size)
			var back: int = BlastCalculatorClass.carved_side_from_base(base_xy, dir, view, base_size)
			if back != side:
				_fail("view %s: side %d round-tripped to %d" % [view, side, back])
				round_trip_ok = false
	if round_trip_ok:
		_pass("every side survives a same-view base round-trip in all 4 views")

	## 2. The real point: one physical hole, recorded once, read back under a
	## DIFFERENT view must land on the side that still faces the blast — which
	## for a 180° turn is the opposite screen side, not the same one.
	var recorded: Vector3i = BlastCalculatorClass.carved_side_to_base_dir(
		cell, Voxel.CarvedSide.LEFT, "N", base_size)
	var base_cell: Vector2i = PerspectiveMapperClass.cell_to_base(cell, "N", base_size)
	var seen_from_s: int = BlastCalculatorClass.carved_side_from_base(base_cell, recorded, "S", base_size)
	if seen_from_s == Voxel.CarvedSide.RIGHT:
		_pass("a hole carved screen-LEFT in view N reads screen-RIGHT from view S (180°)")
	else:
		_fail("expected RIGHT from view S after a LEFT carve in view N, got %d" % seen_from_s)

	## 3. Vertical carves are rotation-invariant — a ceiling's underside is its
	## underside from every compass direction.
	var vertical_ok := true
	var down: Vector3i = BlastCalculatorClass.carved_side_to_base_dir(
		cell, Voxel.CarvedSide.BOTTOM, "N", base_size)
	for view in views:
		if BlastCalculatorClass.carved_side_from_base(base_cell, down, view, base_size) != Voxel.CarvedSide.BOTTOM:
			_fail("BOTTOM carve changed under view %s" % view)
			vertical_ok = false
	if vertical_ok:
		_pass("a BOTTOM (ceiling underside) carve is identical from all 4 views")


## D33-SOOT-01 — the root cause the Director reported: pistol/metal,
## pistol/stone, shotgun/metal (and any other weapon/material combo whose
## punch never crosses PUNCH_DESTROY_MIN) never produced a hole, so
## derive_soot_rings() never had anything to seed from and these voxels
## stayed completely clean regardless of weapon or material. These tests
## cover _self_soot_faces()'s face-selection table directly.
func test_self_soot_faces_dented_lateral_sides() -> void:
	print("[SOOT-SELF-1] A DENTED voxel's own faint soot lands on its carved lateral face only\n")

	var left := BlastCalculatorClass._self_soot_faces(Voxel.DamageState.DENTED, false, Voxel.CarvedSide.LEFT)
	var expected_left := Vector3i(BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.SELF_SOOT_RING_BULLET)
	if left == expected_left:
		_pass("LEFT (bullet) -> SW faint only, top/SE clean (%s)" % left)
	else:
		_fail("LEFT -> %s, expected %s" % [left, expected_left])

	var right := BlastCalculatorClass._self_soot_faces(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.RIGHT)
	var expected_right := Vector3i(BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.SELF_SOOT_RING, BlastCalculatorClass.FACE_SOOT_CLEAN)
	if right == expected_right:
		_pass("RIGHT (blast) -> SE faint only, top/SW clean (%s)" % right)
	else:
		_fail("RIGHT -> %s, expected %s" % [right, expected_right])

	## W-TUNE-01: this test USED to assert that "blast-sourced DENTED behaves the
	## same as bullet", and that is exactly the invariant the Director's
	## 2026-08-20 note broke on purpose — a bullet's own-face soot is one rung
	## darker so a shotgun mark on metal reads as *"uma lembrança de fuligem"*
	## instead of nothing. Asserting the RELATIONSHIP rather than either number
	## keeps both halves honest: a future retune may move the tones, but a bullet
	## that stops being darker than a blast rim is a regression, not a retune.
	if BlastCalculatorClass.SELF_SOOT_RING_BULLET < BlastCalculatorClass.SELF_SOOT_RING:
		_pass("a bullet's self-soot is strictly darker than a blast's (ring %d vs %d — lower is darker)"
			% [BlastCalculatorClass.SELF_SOOT_RING_BULLET, BlastCalculatorClass.SELF_SOOT_RING])
	else:
		_fail("bullet self-soot ring %d is not darker than the blast's %d"
			% [BlastCalculatorClass.SELF_SOOT_RING_BULLET, BlastCalculatorClass.SELF_SOOT_RING])

	print("")


func test_self_soot_faces_dented_top_and_bottom() -> void:
	print("[SOOT-SELF-2] A DENTED floor (TOP) gets a faint top face; a DENTED ceiling (BOTTOM) stays clean\n")

	var top := BlastCalculatorClass._self_soot_faces(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP)
	var expected_top := Vector3i(BlastCalculatorClass.SELF_SOOT_RING, BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.FACE_SOOT_CLEAN)
	if top == expected_top:
		_pass("TOP -> top face faint only (%s)" % top)
	else:
		_fail("TOP -> %s, expected %s" % [top, expected_top])

	var bottom := BlastCalculatorClass._self_soot_faces(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.BOTTOM)
	var clean := Vector3i(BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.FACE_SOOT_CLEAN)
	if bottom == clean:
		_pass("BOTTOM (ceiling underside, never visible) stays fully clean (%s)" % bottom)
	else:
		_fail("BOTTOM -> %s, expected fully clean %s" % [bottom, clean])

	print("")


## D32.3 — "não existe voxel rachado só em uma face": a blast-CRACKED voxel's
## own soot must match its own decal, which lands on all three visible faces.
func test_self_soot_faces_cracked_blast_hits_all_three() -> void:
	print("[SOOT-SELF-3] A blast-CRACKED voxel's faint soot touches all three visible faces\n")

	var faces := BlastCalculatorClass._self_soot_faces(Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE)
	var expected := Vector3i(BlastCalculatorClass.SELF_SOOT_RING, BlastCalculatorClass.SELF_SOOT_RING, BlastCalculatorClass.SELF_SOOT_RING)
	if faces == expected:
		_pass("blast CRACKED -> all three faces faint (%s), matching the decal's own _all placement" % faces)
	else:
		_fail("blast CRACKED -> %s, expected %s" % [faces, expected])

	print("")


func test_self_soot_faces_cracked_bullet_no_side_falls_back_to_top() -> void:
	print("[SOOT-SELF-4] A bullet CRACKED voxel with no known side falls back to the top face, same as its flat mark\n")

	var faces := BlastCalculatorClass._self_soot_faces(Voxel.DamageState.CRACKED, false, Voxel.CarvedSide.NONE)
	var expected := Vector3i(BlastCalculatorClass.SELF_SOOT_RING_BULLET, BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.FACE_SOOT_CLEAN)
	if faces == expected:
		_pass("bullet CRACKED, no side -> top face faint only (%s)" % faces)
	else:
		_fail("bullet CRACKED, no side -> %s, expected %s" % [faces, expected])

	print("")


func test_self_soot_faces_intact_and_destroyed_get_none() -> void:
	print("[SOOT-SELF-5] INTACT and DESTROYED voxels get no self-soot (DESTROYED is the BFS's own job)\n")

	var clean := Vector3i(BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.FACE_SOOT_CLEAN)
	var intact := BlastCalculatorClass._self_soot_faces(Voxel.DamageState.INTACT, false, Voxel.CarvedSide.NONE)
	var destroyed := BlastCalculatorClass._self_soot_faces(Voxel.DamageState.DESTROYED, true, Voxel.CarvedSide.LEFT)
	if intact == clean and destroyed == clean:
		_pass("INTACT (%s) and DESTROYED (%s) both produce no self-soot" % [intact, destroyed])
	else:
		_fail("expected both clean, got INTACT=%s DESTROYED=%s" % [intact, destroyed])

	print("")


## End-to-end apply_self_soot(): a lone DENTED voxel with no hole anywhere
## near it — the exact "shotgun on metal" case the Director reported — must
## still come out of _build_soot_snapshot()'s equivalent pipeline lightly
## sooted instead of perfectly clean.
func test_apply_self_soot_fills_in_when_nothing_stronger_exists() -> void:
	print("[SOOT-SELF-6] A lone DENTED voxel with no nearby hole still gets a faint self-soot\n")

	var slab := Slab.new("SOOT_SELF_LONE", Vector2i.ZERO, Slab.Role.FLOOR, 0, "metal")
	var v := VoxelClass.new(Vector2i(5, 5), 0, slab)
	v.set_damage(Voxel.DamageState.DENTED, false, Voxel.CarvedSide.RIGHT, 0)

	var snapshot: Dictionary = {}
	var faces: Dictionary = {}
	## No derive_soot_rings() call at all — no destroyed_cells, nothing to BFS.
	BlastCalculatorClass.apply_self_soot([v], snapshot, faces)

	var f = faces.get(0, {}).get(Vector2i(5, 5))
	var s = snapshot.get(0, {}).get(Vector2i(5, 5), -1)
	var expected_faces := Vector3i(BlastCalculatorClass.FACE_SOOT_CLEAN, BlastCalculatorClass.SELF_SOOT_RING_BULLET, BlastCalculatorClass.FACE_SOOT_CLEAN)
	if f == expected_faces and int(s) == BlastCalculatorClass.SELF_SOOT_RING_BULLET:
		_pass("lone dent (RIGHT, bullet) -> faces %s, isotropic ring %d — no longer perfectly clean" % [f, s])
	else:
		_fail("lone dent -> faces %s (expected %s), isotropic ring %s (expected %d)"
			% [f, expected_faces, s, BlastCalculatorClass.SELF_SOOT_RING_BULLET])

	print("")


## The other half of the merge contract: a voxel that ALSO sits right beside
## a real hole must keep the BFS's stronger (numerically lower) ring — self
## soot must never overwrite it with the fainter value.
func test_apply_self_soot_never_weakens_an_existing_stronger_ring() -> void:
	print("[SOOT-SELF-7] apply_self_soot() never weakens a stronger ring derive_soot_rings() already placed\n")

	var slab := Slab.new("SOOT_SELF_STRONG", Vector2i.ZERO, Slab.Role.FLOOR, 0, "concrete")
	var hole := VoxelClass.new(Vector2i(0, 0), 0, slab)
	hole.visible = false
	hole.set_damage(Voxel.DamageState.DESTROYED)
	var neighbour := VoxelClass.new(Vector2i(1, 0), 0, slab)
	## Also DENTED — this voxel is both "next to a hole" AND itself damaged,
	## which is the realistic case (a hole's rim survivors are often dented).
	neighbour.set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.RIGHT, 0)

	var cell_to_voxel: Dictionary = {
		Vector3i(0, 0, 0): hole,
		Vector3i(1, 0, 0): neighbour,
	}
	var snapshot: Dictionary = {}
	var faces: Dictionary = {}
	BlastCalculatorClass.derive_soot_rings(cell_to_voxel, [Vector3i(0, 0, 0)], 3, snapshot, faces)
	var before = faces.get(0, {}).get(Vector2i(1, 0))

	BlastCalculatorClass.apply_self_soot([neighbour], snapshot, faces)
	var after = faces.get(0, {}).get(Vector2i(1, 0))

	if before == after and int(snapshot.get(0, {}).get(Vector2i(1, 0), -1)) == 0:
		_pass("ring-0 neighbour unchanged by apply_self_soot() (%s before and after, isotropic ring 0)" % after)
	else:
		_fail("expected apply_self_soot() to leave the stronger ring alone — before %s, after %s" % [before, after])

	print("")
	print("")

## E-CRACK-01 (a) — the byte-compat guarantee this signature's trailing +
## defaulted convention exists for: no crack table passed ⇒ the function behaves
## exactly as it did before the crack tier existed. Asserted against a material
## that DOES crack (concrete, crack_factor > 0), so a pass means "the weights
## gate it", not "this material could never crack anyway".
func test_crater_crack_absent_without_weights() -> void:
	print("[E-CRACK-1] no crack_ring_weights ⇒ 0 cracks, even on a cracking material\n")

	var voxels := _crater_patch("CRACK_PATCH_A", "concrete")
	BlastCalculatorClass.apply_crater_damage(
		voxels, "CRACK_PATCH_A", Vector2i.ZERO, 7.0, 17.0, "concrete")

	var cracked := 0
	var dented := 0
	for v in voxels:
		if v.damage_state == Voxel.DamageState.CRACKED:
			cracked += 1
		elif v.damage_state == Voxel.DamageState.DENTED:
			dented += 1
	if cracked == 0 and dented > 0:
		_pass("no weights → 0 cracked, %d dented (every pre-E-CRACK-01 caller unaffected)" % dented)
	else:
		_fail("expected 0 cracked and some dents without weights — got cracked=%d dented=%d" % [cracked, dented])
	print("")


## E-CRACK-01 (b) — the real placement rules, against the REAL frag_grenade.json
## (via BombRegistry, never a hand-built array — Task 2's own precedent, so a
## retune of the shipped table is caught here instead of quietly diverging):
##   · cracks exist at all on a floor, which was structurally impossible before;
##   · none in crater ring 0 — the Director's own table rule (§4.2, "cracked
##     never in ring 0"), and the rule a real capture proved load-bearing on
##     2026-08-08: a cracked voxel inside the crater renders as an isolated
##     full-voxel cube standing in the hole, because CRACKED is a 3-face
##     composite while DENTED is a half-voxel carve;
##   · none past ring CRATER_DAMAGE_MAX_RING;
##   · the severity ladder holds — DENTED is offered each voxel first, so no
##     voxel is ever both, and every crack sits at a distance where the dent
##     roll had already passed it over.
func test_crater_crack_bands_and_severity_ladder() -> void:
	print("[E-CRACK-2] crack bands + the destroy→dent→crack ladder, on the real frag_grenade table\n")

	var registry := BombRegistryClass.new()
	registry.load_from_disk()
	var frag = registry.get_bomb("frag_grenade")
	if frag == null:
		_fail("Could not load real frag_grenade.json via BombRegistry")
		print("")
		return

	const CORE := 7.0
	const MAX_R := 17.0
	const RIM := MAX_R - CORE
	var voxels := _crater_patch("CRACK_PATCH_B", "concrete")
	BlastCalculatorClass.apply_crater_damage(
		voxels, "CRACK_PATCH_B", Vector2i.ZERO, CORE, MAX_R, "concrete", false, 1.0,
		frag.dent_ring_weights, frag.crack_ring_weights)

	var cracked := 0
	var crack_in_ring0 := 0
	var crack_beyond_max_ring := 0
	var bad_side := 0
	var overlap := 0
	for v in voxels:
		if v.damage_state != Voxel.DamageState.CRACKED:
			continue
		cracked += 1
		var d: float = Vector2(v.grid_pos).length()
		var ring: int = BlastCalculatorClass.crater_ring_for(d, MAX_R, RIM)
		if ring == 0:
			crack_in_ring0 += 1
		if ring > BlastCalculatorClass.CRATER_DAMAGE_MAX_RING:
			crack_beyond_max_ring += 1
		## D32.3 — a blast cracks the whole voxel, one name, no side.
		if not v.damage_is_blast or v.damage_carved_side != Voxel.CarvedSide.NONE:
			bad_side += 1
		## A Voxel carries ONE damage_state, so "both tiers" cannot be read off
		## the state itself — what the ladder really guarantees is that the
		## DENT roll passed this voxel over. Re-run its dent roll here with the
		## same salt/threshold the production path uses and assert it failed.
		if _would_dent("CRACK_PATCH_B", v, d, MAX_R, RIM,
				MaterialResistanceTableClass.dent_factor("concrete"), frag.dent_ring_weights):
			overlap += 1

	if cracked > 0:
		_pass("%d cracked floor voxels — the tier is reachable at all (it was structurally impossible before)" % cracked)
	else:
		_fail("0 cracked voxels with the real frag_grenade table — the crack tier never fires")
	if crack_in_ring0 == 0 and crack_beyond_max_ring == 0:
		_pass("every crack sits in rings 1..%d — none in the crater (§4.2), none past the mark bands"
			% BlastCalculatorClass.CRATER_DAMAGE_MAX_RING)
	else:
		_fail("crack placement wrong: %d in ring 0, %d past ring %d"
			% [crack_in_ring0, crack_beyond_max_ring, BlastCalculatorClass.CRATER_DAMAGE_MAX_RING])
	if bad_side == 0:
		_pass("every crack is blast-sourced with CarvedSide.NONE (D32.3)")
	else:
		_fail("%d cracks carry a carved side or lost blast provenance" % bad_side)
	if overlap == 0:
		_pass("severity ladder holds: no cracked voxel would also have dented")
	else:
		_fail("%d voxels cracked despite passing their own dent roll — DENTED must win first" % overlap)
	print("")


## E-CRACK-01 (c) — two separate properties, both live-table-driven rather than
## pinned to one session's numbers:
##
##   1. A material cracks on a floor IFF its crack_factor > 0. That is the whole
##      of D32.6 on this surface ("metal e madeira não ficam rachados, só dented
##      ou balas") and it is the assertion that would catch the tier being wired
##      to the wrong material property.
##   2. Prevalence scales with the crack term, proven by halving the crack ring
##      weights and checking the smaller result is a strict SUBSET of the larger
##      (same per-voxel hash, smaller threshold ⇒ subset — the same argument the
##      dent test makes).
##
## Deliberately NOT asserted: an ordering between concrete and stone. They share
## crack_factor 0.10 but differ in dent_factor (0.15 vs 0.20), and DENTED draws
## from the pool first, so the material that dents more leaves fewer voxels for
## the crack roll — 44 vs 40 measured. That gap is the severity ladder working,
## not a prevalence bug, and an ordering assertion here would be asserting
## something false. No two shipped materials currently differ in crack_factor at
## all, which is why (2) isolates the term by moving the weight instead.
func test_crater_crack_follows_crack_factor_and_respects_d32_6() -> void:
	print("[E-CRACK-3] cracks iff crack_factor > 0 (D32.6), and prevalence scales with the crack term\n")

	var registry := BombRegistryClass.new()
	registry.load_from_disk()
	var frag = registry.get_bomb("frag_grenade")
	if frag == null:
		_fail("Could not load real frag_grenade.json via BombRegistry")
		print("")
		return

	var cracked_cells := func(material: String, crack_weights: Array[float]) -> Dictionary:
		var id := "CRACK_PATCH_%s" % material
		var voxels := _crater_patch(id, material)
		BlastCalculatorClass.apply_crater_damage(
			voxels, id, Vector2i.ZERO, 7.0, 17.0, material, false, 1.0,
			frag.dent_ring_weights, crack_weights)
		var cells: Dictionary = {}
		for v in voxels:
			if v.damage_state == Voxel.DamageState.CRACKED:
				cells[v.grid_pos] = true
		return cells

	var mismatched: Array[String] = []
	var summary: Array[String] = []
	for material in ["concrete", "stone", "metal", "wood"]:
		var n: int = cracked_cells.call(material, frag.crack_ring_weights).size()
		var expects_cracks: bool = MaterialResistanceTableClass.crack_factor(material) > 0.0
		summary.append("%s %d (factor %.2f)" % [material, n, MaterialResistanceTableClass.crack_factor(material)])
		if (n > 0) != expects_cracks:
			mismatched.append(material)
	if mismatched.is_empty():
		_pass("cracks appear exactly where crack_factor > 0: %s" % ", ".join(summary))
	else:
		_fail("crack presence disagrees with crack_factor for: %s (%s)"
			% [", ".join(mismatched), ", ".join(summary)])

	var half: Array[float] = []
	for w in frag.crack_ring_weights:
		half.append(float(w) * 0.5)
	var full_set: Dictionary = cracked_cells.call("concrete", frag.crack_ring_weights)
	var half_set: Dictionary = cracked_cells.call("concrete", half)
	var escaped := 0
	for cell in half_set:
		if not full_set.has(cell):
			escaped += 1
	if half_set.size() < full_set.size() and escaped == 0:
		_pass("halving the crack weights gives %d cracks, a strict subset of the full table's %d"
			% [half_set.size(), full_set.size()])
	else:
		_fail("half-weight crack set is not a strict subset: %d vs %d, %d cells outside the full set"
			% [half_set.size(), full_set.size(), escaped])
	print("")


## One 28×28 quadrant of a real FLOOR Slab's Voxels, epicenter at (0,0) — the
## same fixture shape test_crater_dents_rim_and_band_by_material() uses, so both
## tiers are measured on identical geometry.
func _crater_patch(slab_id: String, material: String) -> Array:
	var slab := Slab.new(slab_id, Vector2i.ZERO, Slab.Role.FLOOR, 0, material)
	_fixture_slabs.append(slab)  ## LEAK-CYCLE-01 — see _fixture_slabs
	var out: Array = []
	for x in range(28):
		for y in range(28):
			out.append(VoxelClass.new(Vector2i(x, y), 0, slab))
	return out


## Recomputes one voxel's DENT roll exactly as _roll_floor_surface_damage() does
## — same salt, same falloff, same ring weight — so the ladder assertion tests
## the real threshold rather than a restatement of it.
func _would_dent(container_id: String, voxel, d: float, max_radius: float,
		rim_span: float, dent_f: float, dent_ring_weights: Array[float]) -> bool:
	var ring: int = BlastCalculatorClass.crater_ring_for(d, max_radius, rim_span)
	var weight: float = dent_ring_weights[ring] if ring < dent_ring_weights.size() else 0.0
	var dent_p: float = clampf(dent_f
		* clampf(1.0 - (d - max_radius) / rim_span, 0.0, 1.0) * weight, 0.0, 1.0)
	if dent_p <= 0.0:
		return false
	var key := "%s:FLOORDENT:%d,%d,%d" % [container_id, voxel.grid_pos.x, voxel.grid_pos.y, voxel.level]
	return float(FacadeSampler._fnv1a_hash(key) % 10000) / 10000.0 < dent_p


## MAT-SOFT-01 (Director, 2026-08-21): *"Não vamos ter decals nos materiais
## moles porque eles não ficam cracked e nem dented, apenas furam ou queimam."*
##
## The ruling is usually read as an ART decision, and it is not: the tier data
## underneath it promised dents. fabric/cardboard/plywood shipped with
## dent_factor 0.10/0.15/0.22, and a material with no authored decal family is
## NOT unmarked — it falls to the GENERIC family
## (VoxelRenderer._generic_flat_mark_plan), so a blast was marking cardboard
## with a grey dent nobody had asked for.
##
## Two halves, and both must hold or the ruling is only half true:
##   - the BLAST side, which reads MaterialResistanceTable's factors;
##   - the SHOT side, where damage_state_for()'s CRACKED floor is BELOW every
##     breach threshold, so a soft material could not have reached DESTROYED on
##     a weak hit no matter what its breach number said.
## The Director's answer to the second (2026-08-21) is "sempre fura": a soft
## material has exactly two states, INTACT and DESTROYED.
func test_soft_materials_never_take_a_mark() -> void:
	print("TEST: MAT-SOFT-01 - fabric/cardboard/plywood are hole-or-nothing: no CRACKED, no DENTED, on either the blast or the shot path")

	var offenders: Array[String] = []
	var summary: Array[String] = []
	for material in ShotPunchTable.HOLE_ONLY_MATERIALS:
		var dent: float = MaterialResistanceTableClass.dent_factor(material)
		var crack: float = MaterialResistanceTableClass.crack_factor(material)
		summary.append("%s dent %.2f crack %.2f" % [material, dent, crack])
		if dent > 0.0 or crack > 0.0:
			offenders.append(material)
	if offenders.is_empty():
		_pass("blast side: every hole-only material has dent_factor and crack_factor at 0 — %s" % ", ".join(summary))
	else:
		_fail("blast side: %s still carry a dent/crack factor (%s), so a blast marks them"
			% [", ".join(offenders), ", ".join(summary)])

	## The sweep deliberately starts BELOW PUNCH_DENT_MIN (0.30), because that is
	## the rung the breach threshold cannot reach: damage_state_for() returns
	## CRACKED there before it ever looks at breach_min, so lowering the
	## threshold to zero would not have been enough on its own.
	var marked: Array[String] = []
	var sweep: Array[float] = [0.0, 0.01, 0.1, 0.29, 0.30, 0.5, 1.0, 2.0, 2.74, 2.75, 5.0, 12.0]
	for material in ShotPunchTable.HOLE_ONLY_MATERIALS:
		for punch in sweep:
			var state: int = ShotPunchTable.damage_state_for(punch,
				ShotPunchTable.destroy_min(material), material)
			if state != Voxel.DamageState.DESTROYED:
				marked.append("%s at punch %.2f -> %d" % [material, punch, state])
	if marked.is_empty():
		_pass("shot side: %d punch levels from %.2f to %.2f, over %d materials, and every one is a hole"
			% [sweep.size(), sweep[0], sweep[sweep.size() - 1], ShotPunchTable.HOLE_ONLY_MATERIALS.size()])
	else:
		_fail("shot side: a soft material took a mark instead of a hole — %s" % ", ".join(marked))

	## The guard against the change being undone by a well-meaning edit: a hard
	## material passing through this branch must be UNTOUCHED, or the ruling has
	## quietly retuned the calibrated arsenal.
	var control: int = ShotPunchTable.damage_state_for(0.5, ShotPunchTable.destroy_min("concrete"), "concrete")
	if control == Voxel.DamageState.DENTED:
		_pass("control: concrete at punch 0.50 against breach %.2f is still DENTED — the hard materials are untouched"
			% ShotPunchTable.destroy_min("concrete"))
	else:
		_fail("control: concrete at punch 0.50 returned %d, not DENTED — the hard ladder moved" % control)
	print("")


## --- SS-1 / SOOT_STORAGE_REFORM §2.1b -------------------------------------

## ⚠️ THE LOAD-BEARING TEST OF THE WHOLE STORE FORMAT.
##
## The five-direction record is only allowed to exist if it is a strict SUPERSET
## of the `Vector3i(top, SE, SW)` triple that ships today: projected back into the
## perspective it was written in, it must reproduce `_face_rings_for()` component
## for component, for EVERY direction a BFS can reach a voxel from — including the
## three that reach no drawable face at all.
##
## The two functions are written independently and deliberately (neither is
## expressed in terms of the other), so this comparison is a real check rather
## than the tautology B3 exists to forbid.
func test_full_faces_project_to_the_shipped_view_triple() -> void:
	print("\n[SS-1] the five-direction record projects to today's view triple")
	var dirs: Array = [
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	]
	var mismatches: int = 0
	var checked: int = 0
	for n_rings: int in [1, 2, 3, 4]:
		for falloff: int in [0, 1, 2]:
			for ring: int in range(n_rings):
				for d: Vector3i in dirs:
					var view := BlastCalculatorClass._face_rings_for(ring, d, n_rings, falloff)
					var full := BlastCalculatorClass._full_faces_for(ring, d, n_rings, falloff)
					var projected := BlastCalculatorClass.full_faces_to_view(full)
					checked += 1
					if projected != view:
						mismatches += 1
						if mismatches <= 3:
							print("      ring %d toward %s n=%d fall=%d : view %s vs projected %s"
								% [ring, d, n_rings, falloff, view, projected])
	if mismatches == 0:
		_pass("%d (ring x direction x n_rings x falloff) cases project exactly" % checked)
	else:
		_fail("%d of %d cases diverge from _face_rings_for()" % [mismatches, checked])


## The reason the format exists at all: a hole to view −X or −Y is information the
## triple THROWS AWAY (every component falls to the isotropic faint), and the
## store must keep it — otherwise a rotation that turns that face toward the
## camera presents a placeholder instead of a measurement.
func test_full_faces_keep_what_the_view_triple_discards() -> void:
	print("\n[SS-1] the record keeps the two directions the triple discards")
	var kept: int = 0
	for d: Vector3i in [Vector3i(-1, 0, 0), Vector3i(0, -1, 0)]:
		var view := BlastCalculatorClass._face_rings_for(0, d, 3, 1)
		var full := BlastCalculatorClass._full_faces_for(0, d, 3, 1)
		var slot: int = BlastCalculatorClass.FULL_XN if d.x < 0 else BlastCalculatorClass.FULL_YN
		## Today's triple: every component on the faint fallback, ring 0 nowhere.
		if view.x == 0 or view.y == 0 or view.z == 0:
			_fail("the view triple was expected to discard direction %s, but it kept ring 0: %s" % [d, view])
			return
		if full[slot] == 0:
			kept += 1
		else:
			_fail("direction %s : the record should hold ring 0 in slot %d, holds %d" % [d, slot, full[slot]])
			return
	if kept == 2:
		_pass("both view-negative directions keep their measured ring where the triple has only faint")


func test_full_faces_pack_round_trips() -> void:
	print("\n[SS-1] the base-5 pack round-trips over the whole space")
	var bad: int = 0
	var n: int = 0
	var clean: int = BlastCalculatorClass.FACE_SOOT_CLEAN
	for a: int in range(clean + 1):
		for b: int in range(clean + 1):
			var faces := BlastCalculatorClass.full_faces_clean()
			faces[BlastCalculatorClass.FULL_TOP] = a
			faces[BlastCalculatorClass.FULL_XP] = b
			faces[BlastCalculatorClass.FULL_XN] = clean - a
			faces[BlastCalculatorClass.FULL_YP] = (a + b) % (clean + 1)
			faces[BlastCalculatorClass.FULL_YN] = b
			var code := BlastCalculatorClass.encode_full_faces(faces)
			n += 1
			if BlastCalculatorClass.decode_full_faces(code) != faces:
				bad += 1
			## The layout must also fit the space the plan claims: 5^5 = 3125.
			if code < 0 or code >= 3125:
				bad += 1
	if bad == 0:
		_pass("%d packs round-trip, every code inside 0..3124" % n)
	else:
		_fail("%d of %d packs failed to round-trip or left the 3125 space" % [bad, n])


## Min-wins per direction is what makes the store PERMANENT but NOT ACCUMULATING
## (SOOT_MASTER_PLAN §6 Q3): writing into an already-scorched cell resolves to the
## tone a clean cell would have produced, never a darker one.
func test_full_faces_merge_is_min_per_direction() -> void:
	print("\n[SS-1] merging is min per direction, so a second write cannot deepen")
	var out: Dictionary = {}
	var a := BlastCalculatorClass.full_faces_clean()
	a[BlastCalculatorClass.FULL_XP] = 2
	a[BlastCalculatorClass.FULL_YP] = 1
	BlastCalculatorClass._write_full_faces(out, 0, Vector2i(5, 5), a, false)
	var b := BlastCalculatorClass.full_faces_clean()
	b[BlastCalculatorClass.FULL_XP] = 3     ## lighter — must lose
	b[BlastCalculatorClass.FULL_YP] = 0     ## darker  — must win
	b[BlastCalculatorClass.FULL_XN] = 1     ## new direction — must land
	BlastCalculatorClass._write_full_faces(out, 0, Vector2i(5, 5), b, true)
	var got: PackedInt32Array = out[0][Vector2i(5, 5)]
	var ok: bool = (got[BlastCalculatorClass.FULL_XP] == 2
		and got[BlastCalculatorClass.FULL_YP] == 0
		and got[BlastCalculatorClass.FULL_XN] == 1
		and got[BlastCalculatorClass.FULL_TOP] == BlastCalculatorClass.FACE_SOOT_CLEAN)
	if ok:
		_pass("min-wins per direction: 2 beat 3, 0 beat 1, an unseen direction landed, TOP stayed clean")
	else:
		_fail("merge produced %s" % [got])
