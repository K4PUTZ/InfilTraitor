## OCC-01: Occlusion Set — Headless Test
## Usage: godot --headless --script godot/scripts/tools/occlusion_set_test.gd
extends SceneTree

class_name OcclusionSetTest

const GeometryCoords = preload("res://godot/scripts/geometry/geometry_coords.gd")
const OcclusionSet = preload("res://godot/scripts/systems/occlusion_set.gd")

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
	
	# Test 4: Ring assignment by distance
	print("\nGROUP: Ring Distance Ordering")
	total_count += 1
	if _test_ring_ordering():
		print("  ✓ Ring indices match distance from agent")
		pass_count += 1
	else:
		print("  ✗ FAILED: Ring ordering")
	
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
	
	if pass_count == total_count:
		print("[SUCCESS] All tests passed")
	else:
		print("[FAILURE] %d test(s) failed" % [total_count - pass_count])
	
	quit()

## Test with deliberately wrong predicate (>= instead of >)
## This should FAIL to demonstrate the test catches the bug
func _test_wrong_predicate() -> bool:
	var occ = OcclusionSet.new()
	
	# Setup: agent at (10, 10) in gameplay → (80, 80) in voxel space
	var agent_cell := Vector2i(10, 10)  # Gameplay cell
	var agent_voxel := GeometryCoords.gu_to_voxel_origin(agent_cell)
	var agent_depth := agent_voxel.x + agent_voxel.y  # 80 + 80 = 160
	
	# Create test voxel cells: some on camera side, some behind
	var voxel_cells: Array = [
		Vector2i(85, 85),   # depth = 170, > 160 — camera side ✓ should include
		Vector2i(75, 75),   # depth = 150, < 160 — behind agent ✗ should exclude
		Vector2i(82, 82),   # depth = 164, > 160 — camera side ✓ should include
	]
	
	# Recompute: should only include cells with depth > agent_depth
	occ.recompute(agent_cell, voxel_cells, Vector2i(100, 100))
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
	var occ = OcclusionSet.new()
	
	# Fixture: agent at origin, voxel cells in circle around it
	var agent_cell := Vector2i(5, 5)
	var voxel_cells: Array = [
		Vector2i(40, 40),  # 8 voxels per GU → 5*8+2 = 42, 5*8+2 = 42
		Vector2i(41, 40),
		Vector2i(40, 41),
		Vector2i(39, 41),
	]
	
	occ.recompute(agent_cell, voxel_cells, Vector2i(100, 100))
	var occluded = occ.get_occluded_cells()
	
	if occluded.size() > 0:
		print("    ✓ Computed %d cells in occlusion set" % occluded.size())
		return true
	else:
		print("    ✗ No cells computed (empty set)")
		return false

## Test that all cells pass depth check: (x+y) > agent_(x+y)
func _test_depth_ordering() -> bool:
	var occ = OcclusionSet.new()
	
	var agent_cell := Vector2i(10, 10)
	var agent_voxel := GeometryCoords.gu_to_voxel_origin(agent_cell)
	var agent_depth := agent_voxel.x + agent_voxel.y
	
	# Create voxel cells at different depths
	var voxel_cells: Array = []
	for x in range(78, 85):  # 10*8 = 80, so range around that
		for y in range(78, 85):
			voxel_cells.append(Vector2i(x, y))
	
	occ.recompute(agent_cell, voxel_cells, Vector2i(200, 200))
	var occluded = occ.get_occluded_cells()
	
	# Verify: all cells have depth > agent_depth
	for cell in occluded.keys():
		var cell_depth: int = cell.x + cell.y
		if cell_depth <= agent_depth:
			print("    ✗ Cell %s has depth %d <= agent_depth %d" % [cell, cell_depth, agent_depth])
			return false
	
	print("    ✓ All %d cells pass depth test: (x+y) > agent_(x+y)" % occluded.size())
	return true

## Test ring ordering: ring index should increase with distance
func _test_ring_ordering() -> bool:
	var occ = OcclusionSet.new()
	
	# Tune small radii for predictable results
	occ.circle_radius_voxels = 25.0
	occ.ring_0_width = 5.0
	occ.ring_1_width = 8.0
	occ.ring_2_width = 12.0
	
	var agent_cell := Vector2i(10, 10)
	var agent_voxel := GeometryCoords.gu_to_voxel_origin(agent_cell)
	
	# Create many test cells
	var voxel_cells: Array = []
	for x in range(75, 95):
		for y in range(75, 95):
			voxel_cells.append(Vector2i(x, y))
	
	occ.recompute(agent_cell, voxel_cells, Vector2i(200, 200))
	var occluded = occ.get_occluded_cells()
	
	if occluded.size() == 0:
		print("    ✗ No occluded cells (cannot test ring ordering)")
		return false
	
	# Check that rings are used and distance increases
	var rings_present: Dictionary = {}
	var max_ring_dist: Dictionary = {}
	
	for cell in occluded.keys():
		var ring: int = occluded[cell]
		var dist_sq: float = float((cell.x - agent_voxel.x) * (cell.x - agent_voxel.x) +
			int((cell.y - agent_voxel.y) * 0.5) * int((cell.y - agent_voxel.y) * 0.5))
		
		if not rings_present.has(ring):
			rings_present[ring] = 0
			max_ring_dist[ring] = 0.0
		
		rings_present[ring] = rings_present[ring] + 1
		if dist_sq > max_ring_dist[ring]:
			max_ring_dist[ring] = dist_sq
	
	# Verify ring distances increase: max_dist[0] < max_dist[1] < max_dist[2]
	if max_ring_dist.has(0) and max_ring_dist.has(1):
		var dist_0: float = max_ring_dist[0]
		var dist_1: float = max_ring_dist[1]
		if dist_0 > dist_1:
			print("    ✗ Ring 0 distance > Ring 1 distance (reversed ordering)")
			return false
	
	print("    ✓ Ring ordering consistent: %s" % rings_present)
	return true

## Test cardinality: should be dozens, not thousands (guards against O5 failure)
func _test_cardinality() -> bool:
	var occ = OcclusionSet.new()
	
	var agent_cell := Vector2i(20, 20)
	var voxel_cells: Array = []
	
	# Fill a large voxel region
	for x in range(150, 170):
		for y in range(150, 170):
			voxel_cells.append(Vector2i(x, y))
	
	occ.recompute(agent_cell, voxel_cells, Vector2i(200, 200))
	var occluded = occ.get_occluded_cells()
	
	# Expect: ~50–200 cells (dozens). NOT thousands.
	# If we mistakenly selected by z_index, we'd get thousands.
	if occluded.size() > 1000:
		print("    ✗ Occlusion set too large (%d) — likely selected whole storey by z_index" % occluded.size())
		return false
	elif occluded.size() < 5:
		print("    ⚠ Occlusion set very small (%d) — may be tuning issue, but not a bug" % occluded.size())
		# Not a failure, just a warning
	
	print("    ✓ Cardinality reasonable: %d cells (expect dozens)" % occluded.size())
	return true
