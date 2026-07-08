## BAKE-FIX-07: Pixel Comparison (Phase 3 — Extended Infrastructure)
##
## Validates that BOTH rendering paths (generic + baked) are accessible
## and can successfully render the same map layout.
## 
## NOTE: Pixel-by-pixel alpha comparison requires SubViewport image capture.
## This phase validates the paths are available; full rendering will be
## implemented once a proper rendering test scene is in place.
##
## Run: godot --headless --script godot/scripts/tools/bake_fix_03_pixel_comparison.gd

extends SceneTree

const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")

var _test_results: Array = []


func _init() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FIX-07: Pixel Comparison (Phase 3 — Extended Infrastructure)")
	print("=".repeat(80))
	print("Validates both rendering paths can compile the same layout")
	print("Full pixel comparison awaits SubViewport rendering implementation")
	print("=".repeat(80) + "\n")
	
	# Test both rendering paths
	_test_generic_path()
	_test_baked_path()
	_test_layout_identity()
	
	# Print summary
	_print_summary()
	
	quit(0 if _all_pass() else 1)


## TEST 1: Generic path compilation
func _test_generic_path() -> void:
	print("[TEST 1] Generic path compilation (BakeConfig.enabled=false)")
	print("-".repeat(80))
	
	BakeConfigClass.load_config()
	BakeConfigClass.enabled = false
	
	print("  BakeConfig.enabled = %s" % BakeConfigClass.enabled)
	
	# Load and compile
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("PLAYGROUND")
	
	if map_spec.is_empty():
		_record_result("Generic path", "FAIL", "Map spec empty")
		return
	
	var layout = MapCompilerClass.compile(map_spec)
	if layout == null or layout.is_empty():
		_record_result("Generic path", "FAIL", "Layout empty")
		return
	
	_record_result("Generic path", "PASS", "Compiled layout (%d keys)" % layout.size())


## TEST 2: Baked path compilation
func _test_baked_path() -> void:
	print("\n[TEST 2] Baked path compilation (BakeConfig.enabled=true)")
	print("-".repeat(80))
	
	BakeConfigClass.enabled = true
	
	print("  BakeConfig.enabled = %s" % BakeConfigClass.enabled)
	
	# Load and compile
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("PLAYGROUND")
	
	if map_spec.is_empty():
		_record_result("Baked path", "FAIL", "Map spec empty")
		return
	
	var layout = MapCompilerClass.compile(map_spec)
	if layout == null or layout.is_empty():
		_record_result("Baked path", "FAIL", "Layout empty")
		return
	
	_record_result("Baked path", "PASS", "Compiled layout (%d keys)" % layout.size())


## TEST 3: Layout identity check
func _test_layout_identity() -> void:
	print("\n[TEST 3] Layout structure identity")
	print("-".repeat(80))
	
	# Compile with both paths and verify structure is identical
	BakeConfigClass.enabled = false
	var generic_layout = MapCompilerClass.compile(FileMapSourceClass.new().get_runtime_spec("PLAYGROUND"))
	
	BakeConfigClass.enabled = true
	var baked_layout = MapCompilerClass.compile(FileMapSourceClass.new().get_runtime_spec("PLAYGROUND"))
	
	if generic_layout.is_empty() or baked_layout.is_empty():
		_record_result("Layout identity", "FAIL", "One or both layouts empty")
		return
	
	# Check that both have the same keys
	if generic_layout.keys() != baked_layout.keys():
		_record_result("Layout identity", "FAIL", "Layout keys differ")
		return
	
	_record_result("Layout identity", "PASS", "Both layouts have identical structure")


## Helper: Record result
func _record_result(test_name: String, status: String, detail: String) -> void:
	var icon = "✓" if status == "PASS" else "✗"
	print("  [%s] %s: %s" % [icon, test_name, detail])
	_test_results.append({"name": test_name, "status": status})


## Check all tests passed
func _all_pass() -> bool:
	for result in _test_results:
		if result["status"] != "PASS":
			return false
	return true


## Print final summary
func _print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("EXTENDED INFRASTRUCTURE RESULTS")
	print("=".repeat(80) + "\n")
	
	var pass_count = _test_results.filter(func(r): return r["status"] == "PASS").size()
	var fail_count = _test_results.size() - pass_count
	
	print("Results: %d PASS, %d FAIL\n" % [pass_count, fail_count])
	
	if _all_pass():
		print("✓ RENDERING PATHS VALIDATED")
		print("  ✓ Both BakeConfig paths compile successfully")
		print("  ✓ Layouts have identical structure")
		print("  ⏳ Next: SubViewport image capture + pixel-by-pixel comparison")
		print("\n  To complete B3 closure:")
		print("  1. Capture generic + baked rendered images via SubViewport")
		print("  2. Compare alpha channels (must be 100% identical)")
		print("  3. Report: material/face/pixel-count/match-percentage")
		print("  4. Update OPERATOR_CONTEXT.md B3 status")
		print("  5. Bump VERSION: 0.4.33 → 0.4.34")
	else:
		print("✗ RENDERING PATH VALIDATION FAILED")
		print("  See errors above")
	
	print("\n" + "=".repeat(80) + "\n")
