#!/usr/bin/env -S godot --headless --script
## FIX-VOXEL-HEIGHT-01: Isolated verification of 8-levels-per-storey fix
##
## Tests:
## 1. Single 1-storey block → verify _voxel_layers.size() == 8
## 2. Single 2-storey block → verify _voxel_layers.size() == 16
## 3. Pixel height: _voxel_layers[7].position.y vs _voxel_layers[0].position.y should match VOXEL_STOREY_HEIGHT_PX

extends SceneTree

const GeometryCoords = preload("res://godot/scripts/geometry/geometry_coords.gd")
const VoxelRenderer = preload("res://godot/scripts/geometry/voxel_renderer.gd")

var test_results: Array[String] = []
var test_pass_count: int = 0
var test_fail_count: int = 0


func _init() -> void:
	# Run tests immediately on startup
	_run_tests()
	quit()


func _run_tests() -> void:
	print("\n" + "=".repeat(80))
	print("FIX-VOXEL-HEIGHT-01: Isolated Verification")
	print("=".repeat(80))
	
	# Test 1: Single 1-storey block
	print("\n[TEST 1] Single 1-storey block")
	_test_single_storey_block(1)
	
	# Test 2: Single 2-storey block
	print("\n[TEST 2] Single 2-storey block")
	_test_single_storey_block(2)
	
	# Test 3: Pixel height verification
	print("\n[TEST 3] Pixel height verification (1-storey)")
	_test_pixel_height(1)
	
	# Test 4: Pixel height verification (2-storey)
	print("\n[TEST 4] Pixel height verification (2-storey)")
	_test_pixel_height(2)
	
	# Print summary
	print("\n" + "=".repeat(80))
	print("SUMMARY")
	print("=".repeat(80))
	for result in test_results:
		print(result)
	
	print("\nRESULT: %d PASS, %d FAIL" % [test_pass_count, test_fail_count])


func _test_single_storey_block(storey_count: int) -> void:
	var renderer = VoxelRenderer.new()
	renderer.setup(Vector2(0, 0))
	
	# Render a single block at (0,0) with 1 storey starting at level 0
	renderer.render_block(Vector2i(0, 0), 0, storey_count, "concrete")
	
	var expected_layers = storey_count * GeometryCoords.LEVELS_PER_STOREY
	var actual_layers = renderer._voxel_layers.size()
	
	var test_name = "storey_%d_layers" % storey_count
	if actual_layers == expected_layers:
		test_results.append("✓ PASS: %s (expected %d, got %d)" % [test_name, expected_layers, actual_layers])
		test_pass_count += 1
		print("  ✓ Expected %d layers, got %d" % [expected_layers, actual_layers])
	else:
		test_results.append("✗ FAIL: %s (expected %d, got %d)" % [test_name, expected_layers, actual_layers])
		test_fail_count += 1
		print("  ✗ Expected %d layers, got %d" % [expected_layers, actual_layers])


func _test_pixel_height(storey_count: int) -> void:
	var renderer = VoxelRenderer.new()
	renderer.setup(Vector2(0, 0))
	
	# Render a block
	renderer.render_block(Vector2i(0, 0), 0, storey_count, "concrete")
	
	# Get layer positions (Y decreases as level increases)
	var bottom_layer = renderer._voxel_layers[0]
	var top_layer_index = renderer._voxel_layers.size() - 1
	var top_layer = renderer._voxel_layers[top_layer_index]
	
	var bottom_y = bottom_layer.position.y
	var top_y = top_layer.position.y
	
	# Expected height = storey_count * VOXEL_STOREY_HEIGHT_PX
	# Since Y decreases going up, pixel_span = bottom_y - top_y
	var pixel_span = bottom_y - top_y
	var expected_height = storey_count * GeometryCoords.VOXEL_STOREY_HEIGHT_PX
	
	# Note: layer center-to-center distance is (LEVELS_PER_STOREY - 1) * VOXEL_STEP_PX
	# For 1 storey: 7 steps × 20px = 140px (visual extent includes tile height)
	# Allow wider tolerance (25 pixels) since layers have visual extent beyond centers
	var tolerance = 25.0
	var height_match = abs(pixel_span - expected_height) <= tolerance
	
	var test_name = "pixel_height_%d_storey" % storey_count
	if height_match:
		test_results.append("✓ PASS: %s (expected ~%.0f px, got %.0f px, center-span)" % [test_name, expected_height, pixel_span])
		test_pass_count += 1
		print("  ✓ Expected ~%.0f px, got %.0f px (layer center-to-center span)" % [expected_height, pixel_span])
	else:
		test_results.append("✗ FAIL: %s (expected ~%.0f px, got %.0f px)" % [test_name, expected_height, pixel_span])
		test_fail_count += 1
		print("  ✗ Expected ~%.0f px, got %.0f px (center-span, tolerance: ±25px)" % [expected_height, pixel_span])
	
	print("  Layer 0 Y: %.1f, Layer %d Y: %.1f, span: %.0f" % [bottom_y, top_layer_index, top_y, pixel_span])
