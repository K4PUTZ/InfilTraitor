#!/usr/bin/env -S godot -s
## Quick validation script for MODULARIZE-03
## Tests: LightingController initialization, signal connections, reference resolution

extends SceneTree

func _init() -> void:
	print("\n=== MODULARIZE-03 Validation Test ===\n")
	
	var success = true
	
	# Test 1: Check preloads resolve correctly
	print("[Test 1] Checking preload resolution...")
	var LightingControllerClass = preload("res://godot/scripts/controllers/lighting_controller.gd")
	var VisionControllerClass = preload("res://godot/scripts/controllers/vision_controller.gd")
	var HudControllerClass = preload("res://godot/scripts/controllers/hud_controller.gd")
	
	if LightingControllerClass == null or VisionControllerClass == null or HudControllerClass == null:
		print("  ❌ FAILED: Preload resolution")
		success = false
	else:
		print("  ✓ PASSED: All controllers preload correctly")
	
	# Test 2: Verify LightingController has required methods
	print("\n[Test 2] Checking LightingController interface...")
	var lc = LightingControllerClass.new()
	if not lc.has_method("setup") or not lc.has_method("get_light_registry") or not lc.has_method("get_exposure_system"):
		print("  ❌ FAILED: LightingController missing methods")
		success = false
	else:
		print("  ✓ PASSED: LightingController has setup(), get_light_registry(), get_exposure_system()")
	
	# Test 3: Verify signal exists
	print("\n[Test 3] Checking LightingController signals...")
	if not lc.has_signal("lighting_rebuilt"):
		print("  ❌ FAILED: lighting_rebuilt signal missing")
		success = false
	else:
		print("  ✓ PASSED: lighting_rebuilt signal exists")
	
	# Test 4: Check vision_controller.gd compiles (already checked via get_errors, but worth re-verifying)
	print("\n[Test 4] Checking VisionController interface...")
	var vc = VisionControllerClass.new()
	if not vc.has_method("setup") or not vc.has_method("request_redraw") or not vc.has_method("toggle_dev"):
		print("  ❌ FAILED: VisionController missing methods")
		success = false
	else:
		print("  ✓ PASSED: VisionController has required methods")
	
	# Test 5: Check HudController
	print("\n[Test 5] Checking HudController interface...")
	var hc = HudControllerClass.new()
	if not hc.has_method("setup") or not hc.has_method("update_ap"):
		print("  ❌ FAILED: HudController missing methods")
		success = false
	else:
		print("  ✓ PASSED: HudController has required methods")
	
	print("\n==================================================")
	if success:
		print("OK: ALL VALIDATION TESTS PASSED")
		print("  MODULARIZE-03 ready for gameplay validation")
	else:
		print("FAIL: SOME TESTS FAILED")
	print("==================================================\n")
	
	quit(0 if success else 1)
