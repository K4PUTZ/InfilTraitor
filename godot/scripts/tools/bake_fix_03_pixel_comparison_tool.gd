## BAKE-FIX-07: Silhouette Identity Verification (B3 Closure)
##
## Headless Phase 1: Infrastructure check only
## Real pixel comparison happens in live smoke test after map rendering
##
## The actual B3 closure requires:
## 1. Load real map (PLAYGROUND or SIGMA_01)
## 2. Render with BakeConfig.enabled=false (generic path)
## 3. Render with BakeConfig.enabled=true (baked path)
## 4. Capture TileMap images
## 5. Compare pixels (alpha must be 100% identical)

extends SceneTree

const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")

var _test_results: Array = []

func _init() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FIX-07: Silhouette Identity Verification (B3 Closure)")
	print("=".repeat(80))
	print("Phase 1: Headless Infrastructure Check")
	print("Phase 2: Live Smoke Test (render + pixel comparison)")
	print("=".repeat(80) + "\n")
	
	# Setup
	BakeConfigClass.load_config()
	if not Engine.has_meta("GLOBAL_MATERIAL_REGISTRY"):
		var registry = MaterialRegistryClass.new()
		registry.register_defaults()
		Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", registry)
	
	# Run headless verification
	_verify_materials_available()
	_verify_bake_config()
	
	# Print summary
	_print_summary()
	
	# Exit
	quit(0 if _all_pass() else 1)


## Verify materials are registered
func _verify_materials_available() -> void:
	print("\n[TEST 1] Material Registry (Infrastructure)")
	print("-".repeat(80))
	
	var registry = Engine.get_meta("GLOBAL_MATERIAL_REGISTRY")
	if registry == null:
		_record_result("Material registry", "FAIL", "Not found")
		return
	
	var _materials = registry.list_materials()
	var expected = ["concrete", "stone", "wood", "metal"]
	var all_found = true
	
	for mat_id in expected:
		var mat = registry.get_material(mat_id)
		if mat == null:
			_record_result("Material: %s" % mat_id, "FAIL", "Not registered")
			all_found = false
		else:
			var color_str = "%.2f,%.2f,%.2f" % [mat.base_color.r, mat.base_color.g, mat.base_color.b]
			_record_result("Material: %s" % mat_id, "PASS", "color=%s" % color_str)
	
	if all_found:
		print("\n✓ All 4 materials registered correctly")
	else:
		print("\n✗ Some materials missing")


## Verify BakeConfig can be toggled
func _verify_bake_config() -> void:
	print("\n[TEST 2] BakeConfig (Toggle State)")
	print("-".repeat(80))
	
	var initial_state = BakeConfigClass.enabled
	_record_result("BakeConfig.enabled (initial)", "PASS", "%s" % initial_state)
	
	# Toggle and verify
	BakeConfigClass.enabled = not initial_state
	var toggled = BakeConfigClass.enabled
	
	if toggled == (not initial_state):
		_record_result("BakeConfig toggle", "PASS", "%s → %s" % [initial_state, toggled])
	else:
		_record_result("BakeConfig toggle", "FAIL", "Toggle failed")
	
	# Restore
	BakeConfigClass.enabled = initial_state
	
	print("\n✓ BakeConfig can be toggled (rendering path selection works)")
	print("  Note: Actual rendering paths tested in live smoke test")


## Record a test result
func _record_result(test_name: String, status: String, detail: String) -> void:
	var icon = "✓" if status == "PASS" else "✗"
	print("  %s %s: %s" % [icon, test_name, detail])
	_test_results.append({"name": test_name, "status": status})


## Check if all tests passed
func _all_pass() -> bool:
	for result in _test_results:
		if result["status"] != "PASS":
			return false
	return true


## Print final summary
func _print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("B3 SILHOUETTE VERIFICATION SUMMARY")
	print("=".repeat(80) + "\n")
	
	var pass_count = _test_results.filter(func(r): return r["status"] == "PASS").size()
	var fail_count = _test_results.filter(func(r): return r["status"] != "PASS").size()
	
	print("Headless Tests: %d PASS, %d FAIL" % [pass_count, fail_count])
	
	print("\n[NEXT STEP] Run Live Smoke Test")
	print("Execute: bake_fix_03_live_smoke_test.gd")
	print("  1. Loads real map (PLAYGROUND or SIGMA_01)")
	print("  2. Renders with BakeConfig.enabled=false (generic path)")
	print("  3. Captures TileMap image → Image A")
	print("  4. Renders with BakeConfig.enabled=true (baked path)")
	print("  5. Captures TileMap image → Image B")
	print("  6. Performs pixel-by-pixel alpha comparison")
	print("  7. Reports EXACT match counts")
	print("  8. Alpha MUST be 100% identical for B3 closure")
	
	if _all_pass():
		print("\n✓ Headless infrastructure check PASSED")
		print("  Ready for live smoke test")
	else:
		print("\n✗ Infrastructure check failed, fix above before live test")
	
	print("\n" + "=".repeat(80) + "\n")
