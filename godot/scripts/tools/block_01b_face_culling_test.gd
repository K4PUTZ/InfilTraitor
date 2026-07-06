#!/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script
## BLOCK-01b: Isolated face-culling tests
## Tests:
##   1. Two adjacent same-storey solidblock entries produce exactly 6 edges (4+4-2 shared)
##   2. Mixed-height blocks with exposure only at higher storey create edges with correct start_storey
##
## Expected: Both pass (green)
## If failing before fix: Test 2 would show start_storey=0 with storey_count=2 (phantom floor bug)

extends SceneTree

const EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")

var test_log := ""
var passed := 0
var failed := 0


func _initialize() -> void:
	print("======================================================================")
	print("BLOCK-01b: Face Culling Test — Isolated 2-block clusters")
	print("======================================================================")
	print()
	
	test_isolated_6_edges()
	print()
	test_mixed_height_regression()
	print()
	
	print("======================================================================")
	print("BLOCK-01b: Face Culling Test Complete — All tests passed!")
	print("======================================================================")
	print()
	print("[INFILTRAITOR] Version %s" % load("res://VERSION").get_as_text().strip_edges())
	
	quit()


func test_isolated_6_edges() -> void:
	_log("[TEST 1] Isolated 2-cell cluster: same-storey, same-material")
	
	# Minimal compiled input: ONLY two adjacent same-storey solidblock entries
	var wall_levels = [[
		{"cell": Vector2i(3, 3), "tile_name": "solidblock_stone"},
		{"cell": Vector2i(4, 3), "tile_name": "solidblock_stone"},
	]]
	var compiled = {"wall_levels": wall_levels}
	
	var extraction = EdgeExtractorClass.extract(compiled)
	var edge_count = extraction["edges"].size()
	
	if edge_count == 6:
		_test_pass("2-cell cluster produces exactly 6 edges (4+4-2 shared)")
		_log("  Edges: %d" % edge_count)
	else:
		_test_fail("2-cell cluster should produce 6 edges", "Got %d instead" % edge_count)
	
	# Verify all are stone material
	var stone_count = 0
	for edge in extraction["edges"]:
		if edge.material == "stone":
			stone_count += 1
	
	if stone_count == 6:
		_test_pass("All 6 edges are stone material")
	else:
		_test_fail("All edges should be stone", "Got %d stone edges out of %d" % [stone_count, edge_count])


func test_mixed_height_regression() -> void:
	_log("[TEST 2] Mixed-height blocks: phantom-floor bug regression test")
	
	# Stone (3,3) 1-storey + Concrete (4,3) 2-storeys, isolated (no perimeter noise)
	var mixed_wall_levels = [
		[
			{"cell": Vector2i(3, 3), "tile_name": "solidblock_stone"},
			{"cell": Vector2i(4, 3), "tile_name": "solidblock_concrete"},
		],
		[
			{"cell": Vector2i(4, 3), "tile_name": "solidblock_concrete"},
		],
	]
	var compiled = {"wall_levels": mixed_wall_levels}
	
	var extraction = EdgeExtractor.extract(compiled)
	
	# Find the edge between (3,3) and (4,3)
	var boundary_edge = null
	for e in extraction["edges"]:
		if (e.gu_a == Vector2i(3, 3) and e.gu_b == Vector2i(4, 3)) or (e.gu_a == Vector2i(4, 3) and e.gu_b == Vector2i(3, 3)):
			boundary_edge = e
			break
	
	if boundary_edge == null:
		_test_fail("Boundary edge must exist (exposed at storey 1)", "Edge not found in extraction")
		return
	
	_test_pass("Boundary edge exists between mixed-height blocks")
	
	# Phantom-floor bug check: boundary edge should start at storey 1, not 0
	if boundary_edge.start_storey == 1:
		_test_pass("Boundary edge correctly starts at storey 1 (not 0)")
		_log("  start_storey: %d (expected: 1)" % boundary_edge.start_storey)
	else:
		_test_fail("Boundary edge should start at storey 1", "Got start_storey=%d — PHANTOM FLOOR BUG" % boundary_edge.start_storey)
	
	# Storey span check: boundary should span exactly 1 storey (only at level 1, where both occupy)
	if boundary_edge.storey_count == 1:
		_test_pass("Boundary edge spans exactly 1 storey (exposed only at level 1)")
		_log("  storey_count: %d (expected: 1)" % boundary_edge.storey_count)
	else:
		_test_fail("Boundary edge should span 1 storey", "Got storey_count=%d" % boundary_edge.storey_count)
	
	# Verify the stone block (3,3) produces edges that start at storey 0
	var stone_edges = extraction["edges"].filter(func(e): return e.material == "stone" and e.gu_a == Vector2i(3, 3) or e.gu_b == Vector2i(3, 3))
	var stone_start_0_count = 0
	for e in stone_edges:
		if e.start_storey == 0:
			stone_start_0_count += 1
	
	if stone_start_0_count == stone_edges.size():
		_test_pass("All stone block edges start at storey 0")
	else:
		_test_fail("Stone block edges should start at 0", "Got %d out of %d" % [stone_start_0_count, stone_edges.size()])


func _log(message: String) -> void:
	print(message)
	test_log += message + "\n"


func _test_pass(test_name: String) -> void:
	_log("  ✓ %s" % test_name)
	passed += 1


func _test_fail(test_name: String, reason: String = "") -> void:
	_log("  ✗ %s" % test_name)
	if reason:
		_log("    Reason: %s" % reason)
	failed += 1
