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
	
	## LEAK-GATE-01 (fixed 2026-09-01): this node is never added to the tree, so
	## nothing else will ever free it — the runner's leak gate fails the whole
	## suite on it. `free()` rather than `queue_free()` for the same reason: an
	## orphan has no tree to process the deferred delete before quit().
	panel.free()
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
	
	window.free()  ## LEAK-GATE-01 — orphan node, same as TEST 1
	print("  ✓ WindowBase tests passed")


func test_background_swap_simple() -> void:
	print("\n[TEST 3] PanelBase background slot swap (real execution)")
	
	var panel = PanelBaseClass.new()
	
	# Add to scene tree so get_node() and add_child() work
	root.add_child(panel)
	
	# Manually call _ready() since we're headless
	panel._ready()
	
	# Panel starts closed
	assert_eq(panel.is_open(), false, "Panel initially closed")
	
	# Open the panel
	panel.open()
	assert_eq(panel.is_open(), true, "Panel open after open() call")
	assert_eq(panel.visible, true, "Panel visible after open()")
	
	# Verify background node exists before swap
	var bg_node = panel.get_node_or_null("background")
	if bg_node == null:
		assert_true(false, "Background node exists before swap")
		panel.queue_free()
		return
	var original_bg_class = bg_node.get_class()
	assert_true(bg_node is ColorRect, "Original background is ColorRect (got %s)" % original_bg_class)
	
	# Real swap: remove old background and add new one
	var old_bg = panel.get_node("background")
	panel.remove_child(old_bg)
	old_bg.free()
	
	var new_bg := TextureRect.new()
	new_bg.name = "background"
	panel.add_child(new_bg)
	panel.move_child(new_bg, 0)  # Back of stack so title/content overlay it
	
	# Verify state after swap: panel is_open() should still be true
	assert_eq(panel.is_open(), true, "Panel still open after background swap")
	assert_eq(panel.visible, true, "Panel still visible after background swap")
	
	# Verify new background is in place (TextureRect, not ColorRect)
	var swapped_bg = panel.get_node_or_null("background")
	assert_true(swapped_bg != null, "New background node exists after swap")
	if swapped_bg != null:
		var bg_class = swapped_bg.get_class()
		var is_texture_rect = swapped_bg is TextureRect
		assert_true(is_texture_rect, "Swapped background is TextureRect (got %s)" % bg_class)
	
	# Test close() works after swap
	var signal_counter := [0]  # Use array to capture by reference
	panel.closed.connect(func(): 
		signal_counter[0] += 1
	)
	
	panel.close()
	
	assert_eq(panel.is_open(), false, "is_open() false after close() post-swap")
	assert_eq(panel.visible, false, "Panel hidden after close() post-swap")
	assert_eq(signal_counter[0], 1, "closed signal emitted after close() post-swap")
	
	panel.queue_free()
	print("  ✓ Real background swap test passed")


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
