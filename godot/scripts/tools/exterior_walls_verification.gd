#!/usr/bin/env -S godot --headless --script
## FIX-EXTERIOR-WALLS-01: Verify exterior walls have fixed 8-storey height

extends SceneTree

const MapCatalogClass = preload("res://godot/scripts/world/maps/map_catalog.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")

var test_results: Array[String] = []
var test_pass_count: int = 0
var test_fail_count: int = 0


func _init() -> void:
	_run_tests()
	quit()


func _run_tests() -> void:
	print("\n" + "=".repeat(80))
	print("FIX-EXTERIOR-WALLS-01: Exterior Walls Fixed Height Verification")
	print("=".repeat(80))
	
	# Test 1: Constant exists and is 8
	print("\n[TEST 1] EXTERIOR_WALL_STOREYS constant = 8")
	_test_constant()
	
	# Test 2: All maps use the constant
	print("\n[TEST 2] Verify maps compile with fixed exterior wall height")
	_test_maps_compile()
	
	# Test 3: Exterior walls have storey_count == 8
	print("\n[TEST 3] Sample exterior wall Edges have storey_count == 8")
	_test_wall_heights()
	
	# Test 4: Verify ceiling_floors default
	print("\n[TEST 4] ceiling_floors defaults to EXTERIOR_WALL_STOREYS")
	_test_ceiling_floors()
	
	# Print summary
	print("\n" + "=".repeat(80))
	print("SUMMARY")
	print("=".repeat(80))
	for result in test_results:
		print(result)
	
	print("\nRESULT: %d PASS, %d FAIL" % [test_pass_count, test_fail_count])


func _test_constant() -> void:
	if MapCompilerClass.EXTERIOR_WALL_STOREYS == 8:
		test_results.append("✓ PASS: EXTERIOR_WALL_STOREYS = 8")
		test_pass_count += 1
		print("  ✓ Constant is 8")
	else:
		test_results.append("✗ FAIL: EXTERIOR_WALL_STOREYS = %d (expected 8)" % MapCompilerClass.EXTERIOR_WALL_STOREYS)
		test_fail_count += 1
		print("  ✗ Constant is %d (expected 8)" % MapCompilerClass.EXTERIOR_WALL_STOREYS)


func _test_maps_compile() -> void:
	var map_ids = ["PLAYGROUND", "SIGMA_01", "TEST_BLOCKS"]
	var all_compile = true
	
	for map_id in map_ids:
		var spec = MapCatalogClass.get_spec(map_id, {})
		var layout = MapCompilerClass.compile(spec, {})
		
		if layout.is_empty():
			test_results.append("✗ FAIL: Map '%s' failed to compile" % map_id)
			test_fail_count += 1
			all_compile = false
			print("  ✗ %s failed to compile" % map_id)
		else:
			print("  ✓ %s compiled" % map_id)
	
	if all_compile:
		test_results.append("✓ PASS: All maps compile with fixed exterior wall height")
		test_pass_count += 1
	else:
		test_fail_count += 1


func _test_wall_heights() -> void:
	var map_id = "PLAYGROUND"
	var spec = MapCatalogClass.get_spec(map_id, {})
	var layout = MapCompilerClass.compile(spec, {})
	var extraction = EdgeExtractorClass.extract(layout)
	var edges = extraction.get("edges", [])
	
	if edges.is_empty():
		test_results.append("✗ FAIL: No edges found in PLAYGROUND")
		test_fail_count += 1
		print("  ✗ No edges found")
		return
	
	# Sample a few wall edges and check their storey_count
	var wall_edges = []
	for edge in edges:
		if edge.material == "concrete":  # exterior walls are concrete
			wall_edges.append(edge)
			if wall_edges.size() >= 3:
				break
	
	if wall_edges.is_empty():
		test_results.append("✗ FAIL: No wall edges found in PLAYGROUND")
		test_fail_count += 1
		print("  ✗ No wall edges found")
		return
	
	var all_correct = true
	for edge in wall_edges:
		if edge.storey_count != MapCompilerClass.EXTERIOR_WALL_STOREYS:
			all_correct = false
			print("  ✗ Wall edge %s has storey_count=%d (expected %d)" % [edge.id, edge.storey_count, MapCompilerClass.EXTERIOR_WALL_STOREYS])
		else:
			print("  ✓ Wall edge %s has storey_count=%d" % [edge.id, edge.storey_count])
	
	if all_correct:
		test_results.append("✓ PASS: Sample wall edges have storey_count = %d" % MapCompilerClass.EXTERIOR_WALL_STOREYS)
		test_pass_count += 1
	else:
		test_results.append("✗ FAIL: Some wall edges have incorrect storey_count")
		test_fail_count += 1


func _test_ceiling_floors() -> void:
	var spec = MapCatalogClass.get_spec("TEST_BLOCKS", {})
	# Test map without explicit ceiling_floors
	if not spec.has("ceiling_floors"):
		var layout = MapCompilerClass.compile(spec, {})
		var max_floors = layout.get("max_floors", 0)
		
		# Should default to EXTERIOR_WALL_STOREYS
		if max_floors == MapCompilerClass.EXTERIOR_WALL_STOREYS:
			test_results.append("✓ PASS: ceiling_floors defaults to EXTERIOR_WALL_STOREYS")
			test_pass_count += 1
			print("  ✓ ceiling_floors = %d (defaults to EXTERIOR_WALL_STOREYS)" % max_floors)
		else:
			test_results.append("✗ FAIL: ceiling_floors = %d (expected %d)" % [max_floors, MapCompilerClass.EXTERIOR_WALL_STOREYS])
			test_fail_count += 1
			print("  ✗ ceiling_floors = %d (expected %d)" % [max_floors, MapCompilerClass.EXTERIOR_WALL_STOREYS])
	else:
		print("  ℹ Map has explicit ceiling_floors, skipping default test")
