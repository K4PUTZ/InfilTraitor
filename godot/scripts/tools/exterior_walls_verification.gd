#!/usr/bin/env -S godot --headless --script
## FIX-EXTERIOR-WALLS-01b: Verify exterior walls have fixed 3-storey height

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
	print("FIX-EXTERIOR-WALLS-01b: Exterior Walls Fixed Height Verification (3 Storeys)")
	print("=".repeat(80))
	
	# Test 1: Constants have correct values
	print("\n[TEST 1] EXTERIOR_WALL_STOREYS = 3, DEFAULT_CEILING_FLOORS = 8")
	_test_constant()
	
	# Test 2: All maps compile
	print("\n[TEST 2] Verify maps compile with fixed exterior wall height")
	_test_maps_compile()
	
	# Test 3: Exterior walls have storey_count == 3 (3 storeys)
	print("\n[TEST 3] Sample exterior wall Edges have storey_count == 3")
	_test_wall_heights()
	
	# Test 4: Verify ceiling_floors default
	print("\n[TEST 4] ceiling_floors defaults to DEFAULT_CEILING_FLOORS")
	_test_ceiling_floors()
	
	# Print summary
	print("\n" + "=".repeat(80))
	print("SUMMARY")
	print("=".repeat(80))
	for result in test_results:
		print(result)
	
	print("\nRESULT: %d PASS, %d FAIL" % [test_pass_count, test_fail_count])


func _test_constant() -> void:
	var wall_storeys_ok = MapCompilerClass.EXTERIOR_WALL_STOREYS == 3
	var ceiling_ok = MapCompilerClass.DEFAULT_CEILING_FLOORS == 8
	
	if wall_storeys_ok:
		test_results.append("PASS: EXTERIOR_WALL_STOREYS = 3")
		test_pass_count += 1
		print("  OK: EXTERIOR_WALL_STOREYS = 3 (3 storeys)")
	else:
		test_results.append("FAIL: EXTERIOR_WALL_STOREYS = %d (expected 3)" % MapCompilerClass.EXTERIOR_WALL_STOREYS)
		test_fail_count += 1
		print("  FAIL: EXTERIOR_WALL_STOREYS = %d (expected 3)" % MapCompilerClass.EXTERIOR_WALL_STOREYS)
	
	if ceiling_ok:
		test_results.append("PASS: DEFAULT_CEILING_FLOORS = 8")
		test_pass_count += 1
		print("  OK: DEFAULT_CEILING_FLOORS = 8 (full scene composition)")
	else:
		test_results.append("FAIL: DEFAULT_CEILING_FLOORS = %d (expected 8)" % MapCompilerClass.DEFAULT_CEILING_FLOORS)
		test_fail_count += 1
		print("  FAIL: DEFAULT_CEILING_FLOORS = %d (expected 8)" % MapCompilerClass.DEFAULT_CEILING_FLOORS)


func _test_maps_compile() -> void:
	var map_ids = ["PLAYGROUND", "SIGMA_01", "TEST_BLOCKS"]
	var all_compile = true
	
	for map_id in map_ids:
		var spec = MapCatalogClass.get_spec(map_id, {})
		var layout = MapCompilerClass.compile(spec, {})
		
		if layout.is_empty():
			test_results.append("FAIL: Map '%s' failed to compile" % map_id)
			test_fail_count += 1
			all_compile = false
			print("  FAIL: %s failed to compile" % map_id)
		else:
			print("  OK: %s compiled" % map_id)
	
	if all_compile:
		test_results.append("PASS: All maps compile with fixed exterior wall height")
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
		test_results.append("FAIL: No edges found in PLAYGROUND")
		test_fail_count += 1
		print("  FAIL: No edges found")
		return
	
	# Sample a few wall edges and check their storey_count (should be 1)
	var wall_edges = []
	for edge in edges:
		if edge.material == "concrete":  # exterior walls are concrete
			wall_edges.append(edge)
			if wall_edges.size() >= 3:
				break
	
	if wall_edges.is_empty():
		test_results.append("FAIL: No wall edges found in PLAYGROUND")
		test_fail_count += 1
		print("  FAIL: No wall edges found")
		return
	
	var all_correct = true
	for edge in wall_edges:
		if edge.storey_count != 3:
			all_correct = false
			print("  FAIL: Wall edge %s has storey_count=%d (expected 3)" % [edge.id, edge.storey_count])
		else:
			print("  OK: Wall edge %s has storey_count=3" % edge.id)
	
	if all_correct:
		test_results.append("PASS: Sample wall edges have storey_count = 3")
		test_pass_count += 1
	else:
		test_results.append("FAIL: Some wall edges have incorrect storey_count")
		test_fail_count += 1


func _test_ceiling_floors() -> void:
	var spec = MapCatalogClass.get_spec("PLAYGROUND", {})
	var layout = MapCompilerClass.compile(spec, {})
	var ceiling_floors: int = layout.get("ceiling_floors", 0)
	
	# Should default to DEFAULT_CEILING_FLOORS (8) when not explicitly set
	var expected: int = MapCompilerClass.DEFAULT_CEILING_FLOORS
	if ceiling_floors == expected:
		test_results.append("PASS: ceiling_floors defaults to DEFAULT_CEILING_FLOORS")
		test_pass_count += 1
		print("  OK: ceiling_floors = %d (defaults to DEFAULT_CEILING_FLOORS)" % ceiling_floors)
	else:
		test_results.append("FAIL: ceiling_floors = %d (expected %d)" % [ceiling_floors, expected])
		test_fail_count += 1
		print("  FAIL: ceiling_floors = %d (expected %d)" % [ceiling_floors, expected])

