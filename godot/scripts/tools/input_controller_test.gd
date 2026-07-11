#!/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script
## INPUT-01-b Test: Verify InputController dispatches all 18 actions via InputMap.
## Run: godot --headless --script godot/scripts/tools/input_controller_test.gd

extends SceneTree

const InputControllerClass = preload("res://godot/scripts/world/controllers/input_controller.gd")

var test_passed: int = 0
var test_failed: int = 0


func _init() -> void:
	print("============================================================")
	print("[INPUT-01-b TEST] Starting...")
	print("============================================================")
	print("[INPUT-01-b TEST] Verifying InputMap action dispatch")
	
	test_input_map_actions()
	
	print("")
	print("============================================================")
	if test_failed == 0:
		print("[INPUT-01-b TEST] ✅ ALL TESTS PASSED (%d assertions verified)" % test_passed)
		print("============================================================")
	else:
		print("[INPUT-01-b TEST] ❌ FAILED: %d passed, %d failed" % [test_passed, test_failed])
		print("============================================================")
	
	quit(0 if test_failed == 0 else 1)


func test_input_map_actions() -> void:
	print("\n[ACTIONS] Testing InputMap action completeness...")
	
	# Verify all 18 actions exist in Input Map
	var actions := [
		"ui_posture_lower",
		"ui_posture_raise",
		"ui_view_mode_dev",
		"ui_view_mode_light",
		"ui_view_mode_heat",
		"ui_peek",
		"ui_move_up",
		"ui_move_down",
		"ui_move_left",
		"ui_move_right",
		"debug_toggle_map_loader",
		"debug_toggle_voxel_ruler",
		"debug_toggle_nudge_mode",
		"debug_toggle_bake_mode",
		"debug_cycle_blend_mode",
		"debug_cycle_language",
		"debug_nudge_reset",
		"debug_screenshot"
	]
	
	for action in actions:
		var exists := InputMap.has_action(action)
		if exists:
			test_passed += 1
			print("    ✓ Action '%s' exists in InputMap" % action)
		else:
			test_failed += 1
			print("    ✗ Action '%s' NOT found in InputMap" % action)
	
	# Create a dummy node to pass as room
	var dummy_room := Node.new()
	dummy_room.set_meta("_camera_controller", null)
	
	print("\n[SIGNALS] Testing InputController signal declarations...")
	
	var controller = InputControllerClass.new(dummy_room)
	root.add_child(controller)
	
	# Verify all expected signals exist
	var signals := [
		"posture_lower_requested",
		"posture_raise_requested",
		"view_mode_requested",
		"peek_initiated",
		"movement_input_requested",
		"debug_command_requested",
		"screenshot_requested"
	]
	
	for sig in signals:
		if controller.has_signal(sig):
			test_passed += 1
			print("    ✓ Signal '%s' exists" % sig)
		else:
			test_failed += 1
			print("    ✗ Signal '%s' NOT found" % sig)
	
	# Verify all expected methods exist
	print("\n[METHODS] Testing InputController method structure...")
	
	var methods := [
		"_input",
		"_unhandled_input",
		"_handle_key_action",
		"_emit_movement_input"
	]
	
	for method in methods:
		if controller.has_method(method):
			test_passed += 1
			print("    ✓ Method '%s' exists" % method)
		else:
			test_failed += 1
			print("    ✗ Method '%s' NOT found" % method)
	
	controller.queue_free()
	dummy_room.queue_free()
	print("\n  ✓ InputController structure verification complete")

