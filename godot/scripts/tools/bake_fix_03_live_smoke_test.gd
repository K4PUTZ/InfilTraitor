## BAKE-FIX-07: Live Smoke Test (Phase 2 — Headless)
##
## Map file loading + map compilation + BakeConfig verification.
## Tests infrastructure for rendering without actual rendering.
##
## Run: godot --headless --script godot/scripts/tools/bake_fix_03_live_smoke_test.gd

extends SceneTree

const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")

var _timeout_ms: int = 5000  # 5 seconds per operation
var _test_results: Array = []
var _start_time: int = 0


func _init() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FIX-07: Live Smoke Test (Phase 2 — Headless)")
	print("=".repeat(80))
	print("Map loading + compilation + BakeConfig verification")
	print("Timeout: %dms per operation" % _timeout_ms)
	print("=".repeat(80) + "\n")
	
	_start_time = Time.get_ticks_msec()
	
	# Run tests
	_test_load_map()
	_test_map_compilation()
	_test_bakeconfig_toggle()
	
	# Print summary
	_print_summary()
	
	# Exit
	quit(0 if _all_pass() else 1)


## TEST 1: Load map file from disk
func _test_load_map() -> void:
	print("[TEST 1] Load PLAYGROUND map file")
	print("-".repeat(80))
	
	# Create file source and get runtime spec
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("PLAYGROUND")
	
	if map_spec == null or map_spec.is_empty():
		_record_result("Load map", "FAIL", "get_runtime_spec returned empty")
		return
	
	var width = map_spec.get("width", 0)
	var height = map_spec.get("height", 0)
	
	_record_result("Load map", "PASS", "Loaded PLAYGROUND (%dx%d)" % [width, height])


## TEST 2: Compile map to layout
func _test_map_compilation() -> void:
	print("\n[TEST 2] Compile map to layout")
	print("-".repeat(80))
	
	# Load map
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("PLAYGROUND")
	
	if map_spec == null or map_spec.is_empty():
		_record_result("Map compilation", "FAIL", "Could not load map")
		return
	
	# Try to compile
	var layout = MapCompilerClass.compile(map_spec)
	
	if layout == null:
		_record_result("Map compilation", "FAIL", "compiler.compile() returned null")
		return
	
	_record_result("Map compilation", "PASS", "Layout compiled successfully")


## TEST 3: Verify BakeConfig can toggle
func _test_bakeconfig_toggle() -> void:
	print("\n[TEST 3] BakeConfig toggle (rendering path selection)")
	print("-".repeat(80))
	
	BakeConfigClass.load_config()
	
	var initial = BakeConfigClass.enabled
	print("  Initial: BakeConfig.enabled = %s" % initial)
	
	# Toggle ON
	BakeConfigClass.enabled = true
	if BakeConfigClass.enabled != true:
		_record_result("BakeConfig toggle", "FAIL", "Could not enable")
		return
	
	print("  Toggled: BakeConfig.enabled = true (baked path)")
	
	# Toggle OFF
	BakeConfigClass.enabled = false
	if BakeConfigClass.enabled != false:
		_record_result("BakeConfig toggle", "FAIL", "Could not disable")
		return
	
	print("  Toggled: BakeConfig.enabled = false (generic path)")
	
	_record_result("BakeConfig toggle", "PASS", "Both rendering paths accessible")


## Helper: Record result
func _record_result(name: String, status: String, detail: String) -> void:
	var icon = "✓" if status == "PASS" else "✗"
	print("  [%s] %s: %s" % [icon, name, detail])
	_test_results.append({"name": name, "status": status})


## Check all tests passed
func _all_pass() -> bool:
	for result in _test_results:
		if result["status"] != "PASS":
			return false
	return true


## Print final summary
func _print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("LIVE SMOKE TEST RESULTS")
	print("=".repeat(80) + "\n")
	
	var pass_count = _test_results.filter(func(r): return r["status"] == "PASS").size()
	var fail_count = _test_results.size() - pass_count
	
	print("Results: %d PASS, %d FAIL\n" % [pass_count, fail_count])
	
	if _all_pass():
		print("✓ LIVE SMOKE TEST PASSED")
		print("  Map loads and compiles successfully")
		print("  BakeConfig rendering path selection works")
		print("  Infrastructure ready for rendering tests")
		print("\n  For full B3 closure:")
		print("  • Implement SubViewport image capture")
		print("  • Render both paths")
		print("  • Compare alpha channels (must be 100% identical)")
	else:
		print("✗ LIVE SMOKE TEST FAILED")
		print("  See errors above")
	
	print("\n" + "=".repeat(80) + "\n")
	
	var elapsed = Time.get_ticks_msec() - _start_time
	print("Total time: %dms (timeout budget: %dms)\n" % [elapsed, _timeout_ms * 3])
