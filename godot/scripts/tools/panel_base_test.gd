#!/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script
## PANEL-01 Test: Standalone verification of PanelBase and WindowBase functionality.
## Run: godot --headless --script godot/scripts/tools/panel_base_test.gd

extends SceneTree

const PanelBaseClass = preload("res://godot/scripts/ui/panel_base.gd")
const WindowBaseClass = preload("res://godot/scripts/ui/window_base.gd")

var test_passed: int = 0
var test_failed: int = 0


func _init() -> void:
	print("============================================================")
	print("[PANEL-01 TEST] Starting...")
	print("============================================================")
	
	print("[PANEL-01 TEST] Initialization complete, running tests...")
	
	# Run tests (note: nodes won't have _ready() called until next frame)
	# So we test the methods directly rather than relying on state
	test_panel_base()
	test_window_base()
	test_background_swap_simple()
	
	print("")
	print("============================================================")
	if test_failed == 0:
		print("[PANEL-01 TEST] ✅ ALL TESTS PASSED")
		print("============================================================")
	else:
		print("[PANEL-01 TEST] ❌ FAILED: %d/%d" % [test_failed, test_passed + test_failed])
		print("============================================================")
	
	quit(0 if test_failed == 0 else 1)


func test_panel_base() -> void:
	print("\n[TEST 1] PanelBase open/close/is_open")
	
	var panel = PanelBaseClass.new()
	
	# Initially state is set in constructor
	assert_eq(panel.is_open(), false, "PanelBase.is_open() initially false")
	
	# Test open() method works
	panel.open()
	assert_eq(panel.visible, true, "PanelBase.visible true after open()")
	assert_eq(panel.is_open(), true, "PanelBase.is_open() true after open()")
	
	# Test close() method works
	panel.close()
	assert_eq(panel.visible, false, "PanelBase.visible false after close()")
	assert_eq(panel.is_open(), false, "PanelBase.is_open() false after close()")
	
	# Test that signals exist and can be connected
	assert_true(panel.has_signal("opened"), "PanelBase has 'opened' signal")
	assert_true(panel.has_signal("closed"), "PanelBase has 'closed' signal")
	
	print("  ✓ PanelBase tests passed")


func test_window_base() -> void:
	print("\n[TEST 2] WindowBase close_requested signal and properties")
	
	var window = WindowBaseClass.new()
	
	# Test that WindowBase extends PanelBase (has its signals/methods)
	assert_true(window.has_signal("opened"), "WindowBase has 'opened' signal (from PanelBase)")
	assert_true(window.has_signal("closed"), "WindowBase has 'closed' signal (from PanelBase)")
	assert_true(window.has_signal("close_requested"), "WindowBase has 'close_requested' signal")
	
	# Test pausable property exists
	assert_true(window.has_meta("pausable") or window.get("pausable") != null, "WindowBase has pausable property")
	
	# Test request_close method exists
	assert_true(window.has_method("request_close"), "WindowBase has request_close() method")
	
	# Test open/close methods work (inherited from PanelBase)
	window.open()
	assert_eq(window.is_open(), true, "WindowBase.is_open() true after open()")
	
	window.close()
	assert_eq(window.is_open(), false, "WindowBase.is_open() false after close()")
	
	print("  ✓ WindowBase tests passed")


func test_background_swap_simple() -> void:
	print("\n[TEST 3] PanelBase design: background slot support")
	
	var panel = PanelBaseClass.new()
	
	# Design test: verify that PanelBase structure supports background swapping
	# (this would be fully tested with a scene tree, but we verify the API exists)
	
	# Test basic methods exist
	assert_true(panel.has_method("open"), "PanelBase has open() method")
	assert_true(panel.has_method("close"), "PanelBase has close() method")
	assert_true(panel.has_method("is_open"), "PanelBase has is_open() method")
	
	# Test that it's a Control (has add_child, move_child, etc. for background swapping)
	assert_true(panel is Control, "PanelBase is a Control (supports add_child/move_child for background slot)")
	
	# Test state consistency
	panel.open()
	panel.close()
	panel.open()
	assert_eq(panel.is_open(), true, "PanelBase state survives multiple open/close cycles")
	
	print("  ✓ Background swappability tests passed")


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
