#!/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script
## INPUT-01-c Test: Verify InputController dispatches all 18 actions with real signal firing.
## Run: godot --headless --script godot/scripts/tools/input_controller_test.gd

extends SceneTree

const InputControllerClass = preload("res://godot/scripts/world/controllers/input_controller.gd")

var test_passed: int = 0
var test_failed: int = 0

# Expected signal payloads for each action (signal_name, expected_args)
var action_expectations: Dictionary = {
	"ui_posture_lower": ["posture_lower_requested", []],
	"ui_posture_raise": ["posture_raise_requested", []],
	"ui_view_mode_dev": ["view_mode_requested", ["dev"]],
	"ui_view_mode_light": ["view_mode_requested", ["light"]],
	"ui_view_mode_heat": ["view_mode_requested", ["heat"]],
	"ui_peek": ["peek_initiated", []],
	"ui_move_up": ["movement_input_requested", [Vector2i.UP, false]],
	"ui_move_down": ["movement_input_requested", [Vector2i.DOWN, false]],
	"ui_move_left": ["movement_input_requested", [Vector2i.LEFT, false]],
	"ui_move_right": ["movement_input_requested", [Vector2i.RIGHT, false]],
	"debug_toggle_map_loader": ["debug_command_requested", ["toggle_map_loader"]],
	"debug_toggle_voxel_ruler": ["debug_command_requested", ["toggle_voxel_ruler"]],
	"debug_toggle_nudge_mode": ["debug_command_requested", ["toggle_nudge_mode"]],
	"debug_toggle_bake_mode": ["debug_command_requested", ["toggle_bake_mode"]],
	"debug_cycle_blend_mode": ["debug_command_requested", ["cycle_blend_mode"]],
	"debug_cycle_language": ["debug_command_requested", ["cycle_language"]],
	"debug_nudge_reset": ["debug_command_requested", ["nudge_reset"]],
	"debug_screenshot": ["screenshot_requested", []],
}


func _init() -> void:
	print("============================================================")
	print("[INPUT-01-c TEST] Starting...")
	print("============================================================")
	print("[INPUT-01-c TEST] Verifying real signal firing for all 18 actions")
	
	test_all_actions_fire_signals()
	
	print("")
	print("============================================================")
	if test_failed == 0:
		print("[INPUT-01-c TEST] ✅ ALL TESTS PASSED (%d assertions verified)" % test_passed)
		print("============================================================")
	else:
		print("[INPUT-01-c TEST] ❌ FAILED: %d passed, %d failed" % [test_passed, test_failed])
		print("============================================================")
	
	quit(0 if test_failed == 0 else 1)



func test_all_actions_fire_signals() -> void:
	print("\n[FIRING] Testing all 18 actions fire correct signals...\n")
	
	# Create a dummy room node
	var dummy_room := Node.new()
	
	# Create controller and add to scene tree so it has a viewport
	var controller = InputControllerClass.new(dummy_room)
	root.add_child(controller)
	
	# Test each action
	for action_name in action_expectations.keys():
		var expected_signal = action_expectations[action_name][0]
		var expected_args = action_expectations[action_name][1]
		
		# debug_screenshot is handled in _unhandled_input, not _handle_key_action
		if action_name == "debug_screenshot":
			test_screenshot_signal_firing(controller, action_name, expected_signal, expected_args)
		else:
			test_action_signal_firing(controller, action_name, expected_signal, expected_args)
	
	controller.queue_free()
	dummy_room.queue_free()
	
	print("  ✓ All action signal firing tests complete")


func test_screenshot_signal_firing(controller: Node, action: String, expected_signal: String, expected_args: Array) -> void:
	## Test screenshot signal via _unhandled_input (different dispatch path than _handle_key_action).
	
	# Get the actual InputEventKey from the Input Map
	var ss_events := InputMap.action_get_events(action)
	
	if ss_events.size() == 0:
		test_failed += 1
		print("    ✗ %s: No events bound in InputMap" % action)
		return
	
	# Use the first bound event
	var ss_event = ss_events[0]
	
	if not ss_event is InputEventKey:
		test_failed += 1
		print("    ✗ %s: First event is not InputEventKey (got %s)" % [action, ss_event.get_class()])
		return
	
	# Create a copy and mark as pressed
	var ss_key_event := ss_event as InputEventKey
	var ss_test_event := ss_key_event.duplicate() as InputEventKey
	ss_test_event.pressed = true
	
	# Track signal firing
	var ss_fired := [false]
	
	# Connect to screenshot signal
	var ss_handler = Callable(func():
		ss_fired[0] = true
	)
	
	controller.connect(expected_signal, ss_handler)
	
	# Dispatch via _unhandled_input
	controller._unhandled_input(ss_test_event)
	
	# Verify signal fired
	if not ss_fired[0]:
		test_failed += 1
		print("    ✗ %s → %s: Signal did not fire" % [action, expected_signal])
		controller.disconnect(expected_signal, ss_handler)
		return
	
	# All good!
	test_passed += 1
	print("    ✓ %s → %s" % [action, expected_signal])
	
	controller.disconnect(expected_signal, ss_handler)


func test_action_signal_firing(controller: Node, action: String, expected_signal: String, expected_args: Array) -> void:
	## Test that a specific action fires the expected signal with correct payload.
	
	# Get the actual InputEventKey from the Input Map
	var events := InputMap.action_get_events(action)
	
	if events.size() == 0:
		test_failed += 1
		print("    ✗ %s: No events bound in InputMap" % action)
		return
	
	# Use the first bound event (should be an InputEventKey)
	var event = events[0]
	
	if not event is InputEventKey:
		test_failed += 1
		print("    ✗ %s: First event is not InputEventKey (got %s)" % [action, event.get_class()])
		return
	
	# Create a copy and ensure it's marked as pressed
	var key_event := event as InputEventKey
	var test_event := key_event.duplicate() as InputEventKey
	test_event.pressed = true
	
	# Track signal firing and payload (use array to capture by reference)
	var signal_fired := [false]
	var received_args := [[]]  # Wrapped array for mutable reference
	
	# Create appropriate handler based on signal type
	var handler: Callable
	match expected_signal:
		"posture_lower_requested":
			handler = Callable(func():
				signal_fired[0] = true
			)
		"posture_raise_requested":
			handler = Callable(func():
				signal_fired[0] = true
			)
		"peek_initiated":
			handler = Callable(func():
				signal_fired[0] = true
			)
		"screenshot_requested":
			handler = Callable(func():
				signal_fired[0] = true
			)
		"view_mode_requested":
			handler = Callable(func(mode: String):
				signal_fired[0] = true
				received_args[0] = [mode]
			)
		"movement_input_requested":
			handler = Callable(func(direction: Vector2i, is_large_step: bool):
				signal_fired[0] = true
				received_args[0] = [direction, is_large_step]
			)
		"debug_command_requested":
			handler = Callable(func(command: String):
				signal_fired[0] = true
				received_args[0] = [command]
			)
		_:
			test_failed += 1
			print("    ✗ %s: Unknown signal type '%s'" % [action, expected_signal])
			return
	
	controller.connect(expected_signal, handler)
	
	# Dispatch the event
	controller._handle_key_action(test_event)
	
	# Verify signal fired
	if not signal_fired[0]:
		test_failed += 1
		print("    ✗ %s → %s: Signal did not fire" % [action, expected_signal])
		controller.disconnect(expected_signal, handler)
		return
	
	# Verify payload if applicable
	var actual_args = received_args[0]
	if expected_args.size() > 0:
		if actual_args.size() != expected_args.size():
			test_failed += 1
			print("    ✗ %s → %s: Expected %d args, got %d" % [action, expected_signal, expected_args.size(), actual_args.size()])
			controller.disconnect(expected_signal, handler)
			return
		
		# Check each argument
		var args_match := true
		for i in range(expected_args.size()):
			if actual_args[i] != expected_args[i]:
				args_match = false
				print("    ✗ %s → %s: Arg %d mismatch (got %s, expected %s)" % [action, expected_signal, i, actual_args[i], expected_args[i]])
				break
		
		if not args_match:
			test_failed += 1
			controller.disconnect(expected_signal, handler)
			return
	
	# All good!
	test_passed += 1
	if expected_args.size() > 0:
		print("    ✓ %s → %s(%s)" % [action, expected_signal, _format_args(expected_args)])
	else:
		print("    ✓ %s → %s" % [action, expected_signal])
	
	controller.disconnect(expected_signal, handler)


func _format_args(args: Array) -> String:
	## Format arguments for display.
	var parts := []
	for arg in args:
		if arg is Vector2i:
			parts.append(arg)
		elif arg is String:
			parts.append("\"%s\"" % arg)
		else:
			parts.append(str(arg))
	return ", ".join(parts)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		test_passed += 1
		print("    ✓ %s" % message)
	else:
		test_failed += 1
		print("    ✗ %s (got %s, expected %s)" % [message, actual, expected])


func assert_true(condition: bool, message: String) -> void:
	if condition:
		test_passed += 1
		print("    ✓ %s" % message)
	else:
		test_failed += 1
		print("    ✗ %s" % message)


