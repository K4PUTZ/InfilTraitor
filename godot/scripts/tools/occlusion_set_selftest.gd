## OCC-01: Occlusion Set — Headless Test
## Usage: godot --headless --script godot/scripts/tools/occlusion_set_selftest.gd
##
## TEST-DEBT-01 (2026-09-01): renamed from `occlusion_set_test.gd` into the
## `*_selftest.gd` glob, so `run_selftests.py` — the arbiter — actually runs it.
## The `class_name OcclusionSetTest` it used to declare went with the rename: no
## caller ever used it, no sibling selftest declares one, and a global class name
## on a `--script` entry point only buys a "hides a global script class" parse
## error the moment the file moves.
extends SceneTree

const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")
const OcclusionSetMod = preload("res://godot/scripts/systems/occlusion_set.gd")

## AUDIT-01 (2026-08-06): every test below used to hand recompute() a raw
## Array[Vector2i]. OCC-07 moved the decision from per-voxel to per-Slice, so
## _group_slices_by_edge() has been reading `slice.voxels` / `slice.edge_id`
## off a Vector2i ever since — a SCRIPT ERROR that aborts the calling function
## and leaves an EMPTY occlusion set. GDScript cannot fail its own process for
## that, so the file still exited 0 while printing "3/5 passed", and the three
## "passes" were vacuous ("Cardinality reasonable: 0 cells (expect dozens)").
## The fixtures now build the shape room.gd:2542 really passes.
##
## Levels matter: an edge's bottom BASE_VISIBLE_LEVELS (2) never ghost, so a
## fixture column must be taller than that to produce any occluded cell at all.
const FIXTURE_LEVELS: int = 6


## Wrap voxel cells in the Slice/Voxel shape EdgeRegistry.all_slices() yields.
## One synthetic edge per cell column: enough for depth/ring/cardinality
## assertions, which are all per-cell, without inventing a wall topology the
## real EdgeRegistry would own.
func _slices_from_cells(cells: Array) -> Array:
	var slices: Array = []
	for cell: Vector2i in cells:
		var edge_id := "AUDIT_EDGE_%d_%d" % [cell.x, cell.y]
		var slice := Slice.new(
			"AUDIT_SLICE_%d_%d" % [cell.x, cell.y],
			GeometryCoordsMod.voxel_to_gu(cell),
			0,            ## face — unread by compute_edge_occlusion()
			edge_id,
			1             ## storey_count
		)
		## LEVEL-RENUMBER (fixed 2026-09-01) — and this is AUDIT-01 happening a
		## SECOND time, the same way: the fixture built its voxels at levels 0..5,
		## which the renumber turned into a tower eighty levels under the ground
		## plane. compute_edge_occlusion() converts a level to a screen Y through
		## `min_level - PLAYABLE_LEVEL`, so the edge's rectangle landed ~1600 px
		## from the agent's, nothing triggered, and the set came back EMPTY — the
		## exact vacuous-pass shape this file's own header was written about.
		## Levels are derived from the ground plane now (CLAUDE.md rule 9).
		for level_offset in range(FIXTURE_LEVELS):
			slice.voxels.append(Voxel.new(
				cell, GeometryCoordsMod.storey_level_base(0) + level_offset, slice))
		slices.append(slice)
	return slices

## Test entry point (SceneTree._initialize replaces _ready())
func _initialize():
	var separator = "=========================================="
	print("\n" + separator)
	print("OCC-01: OCCLUSION SET SELFTEST")
	print(separator + "\n")
	
	var pass_count = 0
	var total_count = 0
	
	# Test 1: RED-BEFORE-GREEN — Show the test fails with wrong predicate
	print("GROUP: Red-Before-Green (Deliberately Wrong Predicate)")
	total_count += 1
	if _test_wrong_predicate():
		print("  ✓ EXPECTED FAILURE demonstrated (would pass with >=, must fail with >)")
		pass_count += 1
	else:
		print("  ✗ FAILED: Wrong predicate test did not fail as expected")
	
	# Test 2: Basic computation with fixture agent
	print("\nGROUP: Basic Occlusion Computation")
	total_count += 1
	if _test_basic_computation():
		print("  ✓ Basic computation works: cells computed, filtered by depth")
		pass_count += 1
	else:
		print("  ✗ FAILED: Basic computation")
	
	# Test 3: Depth ordering — all cells have (x+y) > agent_(x+y)
	print("\nGROUP: Depth Ordering (O5 Rule)")
	total_count += 1
	if _test_depth_ordering():
		print("  ✓ All occluded cells are on camera side of agent")
		pass_count += 1
	else:
		print("  ✗ FAILED: Depth ordering violated")
	
	# Test 4: Ring range (ordering coverage retired — see _test_ring_ordering)
	print("\nGROUP: Ring Range")
	total_count += 1
	if _test_ring_ordering():
		print("  ✓ Ring indices within the valid range")
		pass_count += 1
	else:
		print("  ✗ FAILED: Ring range")
	
	# Test 5: Cardinality — should be dozens, not thousands
	print("\nGROUP: Cardinality Guard (Anti-O5 Failure)")
	total_count += 1
	if _test_cardinality():
		print("  ✓ Occlusion set size is reasonable (dozens, not storeys)")
		pass_count += 1
	else:
		print("  ✗ FAILED: Cardinality check")
	
	print("\n" + separator)
	print("SUMMARY: %d/%d tests passed" % [pass_count, total_count])
	print(separator + "\n")
	
	## TEST-DEBT-01 (2026-09-01) — two contract fixes the move into the glob
	## exposed, both of which had made this file structurally unable to report a
	## failure to anything outside itself:
	##  · `quit()` with no argument exits 0 whatever happened. That is the exact
	##    "prints 3/5 passed, exits 0" trap this file's own AUDIT-01 header is
	##    about, still live in the line that reports the verdict.
	##  · run_selftests.py additionally requires the suite's own PASS banner in
	##    the output ("[SUCCESS] All tests passed" has no uppercase PASS), because
	##    a script that fails to LOAD also exits 0 having run nothing.
	if pass_count == total_count:
		print("[SUCCESS] OCCLUSION SET SELFTEST PASS — all %d tests" % total_count)
		quit(0)
	else:
		print("[FAILURE] %d test(s) failed" % [total_count - pass_count])
		quit(1)

## Test with deliberately wrong predicate (>= instead of >)
## This should FAIL to demonstrate the test catches the bug
func _test_wrong_predicate() -> bool:
	var occ = OcclusionSetMod.new()
	
	# Setup: agent at (10, 10) in gameplay → (80, 80) in voxel space
	var agent_cell := Vector2i(10, 10)  # Gameplay cell
	var agent_voxel := GeometryCoordsMod.gu_to_voxel_origin(agent_cell)
	var _agent_depth := agent_voxel.x + agent_voxel.y  # 80 + 80 = 160
	
	# Create test voxel cells: some on camera side, some behind
	var voxel_cells: Array = [
		Vector2i(85, 85),   # depth = 170, > 160 — camera side ✓ should include
		Vector2i(75, 75),   # depth = 150, < 160 — behind agent ✗ should exclude
		Vector2i(82, 82),   # depth = 164, > 160 — camera side ✓ should include
	]
	
	# Recompute: should only include cells with depth > agent_depth
	occ.recompute(agent_cell, _slices_from_cells(voxel_cells), Vector2i(100, 100))
	var occluded = occ.get_occluded_cells()
	
	# WRONG ASSERTION: if we used >= instead of >, we'd include the behind cell
	# This test passes iff the right implementation filters it out
	var has_behind_cell := occluded.has(Vector2i(75, 75))
	
	if has_behind_cell:
		print("    ✗ Behind-agent cell was included (implementation uses >= instead of >)")
		return false  # Test should FAIL if predicate is wrong
	else:
		print("    ✓ Behind-agent cell correctly excluded (predicate is >)")
		return true  # Test passes if predicate is right

## Basic computation test
func _test_basic_computation() -> bool:
	var occ = OcclusionSetMod.new()
	
	## OCC-FIX-02: fixture corrected. Agent (5,5) sits at voxel CENTRE (44, 44) — depth 88 —
	## because he stands in the middle of his 8×8 gameplay unit, not on its corner.
	##
	## The old fixture listed (40,40), (41,40), (40,41), (39,41): depths 80–81, i.e. cells
	## at the corner of the agent's OWN unit, BEHIND him. They only ever entered the set
	## because the buggy anchor placed the agent on that same corner. Under the corrected
	## anchor an empty set is the right answer for them — the test was encoding the bug.
	##
	## These cells are genuinely in front of him: depth 92–96 > 88, well inside the circle.
	var agent_cell := Vector2i(5, 5)
	var voxel_cells: Array = [
		Vector2i(46, 46),  # depth 92
		Vector2i(47, 46),  # depth 93
		Vector2i(46, 47),  # depth 93
		Vector2i(48, 48),  # depth 96
	]
	
	occ.recompute(agent_cell, _slices_from_cells(voxel_cells), Vector2i(100, 100))
	var occluded = occ.get_occluded_cells()
	
	if occluded.size() > 0:
		print("    ✓ Computed %d cells in occlusion set" % occluded.size())
		return true
	else:
		print("    ✗ No cells computed (empty set)")
		return false

## Test that all cells pass depth check: (x+y) > agent_(x+y)
func _test_depth_ordering() -> bool:
	var occ = OcclusionSetMod.new()
	
	var agent_cell := Vector2i(10, 10)
	var agent_voxel := GeometryCoordsMod.gu_to_voxel_origin(agent_cell)
	var _agent_depth := agent_voxel.x + agent_voxel.y
	
	## AUDIT-01: the old span (78..84)² sat almost entirely BEHIND the agent —
	## his centre is voxel (84, 84), depth 168, while that span tops out at 168.
	## The set came back empty and the assertion below passed over nothing
	## ("All 0 cells pass depth test"), which is the same vacuous green the
	## SCRIPT ERROR used to produce. Straddle him instead: this span runs
	## depth 156..190, so there is real material on both sides to filter.
	var voxel_cells: Array = []
	for x in range(78, 96):
		for y in range(78, 96):
			voxel_cells.append(Vector2i(x, y))
	
	occ.recompute(agent_cell, _slices_from_cells(voxel_cells), Vector2i(200, 200))
	var occluded = occ.get_occluded_cells()
	
	## AUDIT-01: an empty set must not pass this test by vacuity.
	if occluded.is_empty():
		print("    ✗ Empty occlusion set — nothing to depth-test")
		return false

	# Verify: all cells have depth > agent_depth
	for cell in occluded.keys():
		var cell_depth: int = cell.x + cell.y
		if cell_depth <= _agent_depth:
			print("    ✗ Cell %s has depth %d <= agent_depth %d" % [cell, cell_depth, _agent_depth])
			return false
	
	print("    ✓ All %d cells pass depth test: (x+y) > agent_(x+y)" % occluded.size())
	return true

## Ring RANGE, not ring-vs-distance.
##
## AUDIT-01 (2026-08-06) — COVERAGE DELIBERATELY REDUCED HERE, read before
## trusting this test: it used to assert "ring index grows with euclidean
## distance from the agent", configured through occ.circle_radius_voxels /
## ring_N_width. Those four properties no longer exist. OCC-08/09/10 replaced
## the concentric-circle model with ring propagation along the EDGE ADJACENCY
## GRAPH (`vertex_to_edges`, MAX_RING) — a far edge reachable in one hop is
## ring 1 while a nearer edge reached in two hops is ring 2, so the old
## assertion is not merely misconfigured, it is FALSE under the current model.
##
## Assigning the dead property threw a SCRIPT ERROR that aborted this function
## silently. What is asserted below (every ring within [0, MAX_RING]) is true
## and worth keeping, but it is strictly weaker. **Ring ORDERING is no longer
## covered by any test** — writing the right assertion for the adjacency model
## is a design question for whoever resumes OCCLUSION_MASTER_PLAN, not
## something to guess here.
func _test_ring_ordering() -> bool:
	var occ = OcclusionSetMod.new()

	var agent_cell := Vector2i(10, 10)
	var agent_voxel := GeometryCoordsMod.gu_to_voxel_origin(agent_cell)
	
	# Create many test cells
	var voxel_cells: Array = []
	for x in range(75, 95):
		for y in range(75, 95):
			voxel_cells.append(Vector2i(x, y))
	
	occ.recompute(agent_cell, _slices_from_cells(voxel_cells), Vector2i(200, 200))
	var occluded = occ.get_occluded_cells()
	
	if occluded.size() == 0:
		print("    ✗ No occluded cells (cannot test ring ordering)")
		return false
	
	var rings_present: Dictionary = {}
	for cell in occluded.keys():
		## OCC-09/OCC-10/OCC-26: the value is a dict now, not a bare ring int.
		var ring: int = occluded[cell]["ring"]
		if ring < 0 or ring > OcclusionSetMod.MAX_RING:
			print("    ✗ Cell %s has ring %d outside [0, %d]" % [cell, ring, OcclusionSetMod.MAX_RING])
			return false
		rings_present[ring] = rings_present.get(ring, 0) + 1

	print("    ✓ Every ring within [0, %d]: %s" % [OcclusionSetMod.MAX_RING, rings_present])
	return true

## Test cardinality: should be dozens, not thousands (guards against O5 failure)
func _test_cardinality() -> bool:
	var occ = OcclusionSetMod.new()
	
	var agent_cell := Vector2i(20, 20)
	var voxel_cells: Array = []
	
	# Fill a large voxel region
	for x in range(150, 170):
		for y in range(150, 170):
			voxel_cells.append(Vector2i(x, y))
	
	occ.recompute(agent_cell, _slices_from_cells(voxel_cells), Vector2i(200, 200))
	var occluded = occ.get_occluded_cells()
	
	# Expect: ~50–200 cells (dozens). NOT thousands.
	# If we mistakenly selected by z_index, we'd get thousands.
	if occluded.size() > 1000:
		print("    ✗ Occlusion set too large (%d) — likely selected whole storey by z_index" % occluded.size())
		return false
	## An EMPTY or near-empty set used to pass here with a warning, which is how
	## this guard reported "✓ Cardinality reasonable: 0 cells (expect dozens)" for
	## as long as the fixture was broken — twice now (AUDIT-01, then the level
	## renumber). A guard that accepts the degenerate answer is not a guard.
	## The floor is deliberately loose (5, against 31 measured on 2026-09-01):
	## it exists to catch "nothing was computed at all", not to pin a tuning
	## number that any legitimate change to the trigger geometry would move.
	if occluded.size() < 5:
		print("    ✗ Occlusion set is empty or near-empty (%d) — the fixture produced nothing to test" % occluded.size())
		return false
	
	print("    ✓ Cardinality reasonable: %d cells (expect dozens)" % occluded.size())
	return true
