## INPUT-01: Input controller — dispatches mapped input actions to signals.
## Extracted from room.gd to provide a single source of truth for input bindings
## and enable rebinding without touching gameplay code.
## Signals are emitted here; room.gd connects and handles the resulting actions.
class_name InputController extends Node

signal posture_lower_requested
signal posture_raise_requested
signal view_mode_requested(mode: String)
signal peek_initiated
signal movement_input_requested(direction: Vector2i, is_large_step: bool)
signal debug_command_requested(command: String)
signal screenshot_requested
signal pause_requested
signal grenade_mode_requested
signal grenade_throw_requested
signal grenade_cancel_requested
var room: Node
var _camera_controller: Node = null


func _init(p_room: Node) -> void:
	room = p_room
	process_mode = Node.PROCESS_MODE_ALWAYS
	if room and room.has_meta("_camera_controller"):
		_camera_controller = room.get_meta("_camera_controller")


func _input(event: InputEvent) -> void:
	## Camera has priority — let it consume events first
	if _camera_controller and _camera_controller.handle_input(event):
		return

	## Keyboard input dispatch via action map
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			_handle_key_action(key)


func _unhandled_input(event: InputEvent) -> void:
	## Screenshot hotkey (Shift+P only) — handled in unhandled to catch
	## events that may be consumed by UI controls
	if event.is_action_pressed("debug_screenshot"):
		screenshot_requested.emit()
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()


func _handle_key_action(key: InputEventKey) -> void:
	## Dispatch keyboard actions based on the Input Map (via is_action_pressed).
	## This eliminates raw keycode matching and ensures rebindability works.
	
	var viewport = get_viewport()
	
	# Menu actions
	if key.is_action_pressed("ui_pause"):
		print_debug("[INPUT] Pause requested")
		pause_requested.emit()
		if viewport:
			viewport.set_input_as_handled()
		return
	
	## AUDIT-01 (2026-08-06): guarded like get_viewport() above. get_tree() is
	## null whenever this controller is driven outside the SceneTree — which is
	## exactly what input_controller_test.gd does, and what made it throw 17
	## SCRIPT ERRORs. Pause cannot be in effect off-tree, so falling through is
	## the correct reading, not a swallowed error.
	var tree := get_tree()
	if tree != null and tree.paused:
		return
	
	# Gameplay actions
	elif key.is_action_pressed("ui_posture_lower"):
		print_debug("[INPUT] Posture lower requested")
		posture_lower_requested.emit()
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_posture_raise"):
		print_debug("[INPUT] Posture raise requested")
		posture_raise_requested.emit()
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_view_mode_dev"):
		print_debug("[INPUT] View mode dev requested")
		view_mode_requested.emit("dev")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_view_mode_light"):
		print_debug("[INPUT] View mode light requested")
		view_mode_requested.emit("light")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_view_mode_heat"):
		print_debug("[INPUT] View mode heat requested")
		view_mode_requested.emit("heat")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_peek", false, true):
		print_debug("[INPUT] Peek initiated")
		peek_initiated.emit()
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_grenade_mode"):
		print_debug("[INPUT] Grenade mode requested")
		grenade_mode_requested.emit()
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_accept"):
		print_debug("[INPUT] Grenade throw requested")
		grenade_throw_requested.emit()
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_cancel"):
		print_debug("[INPUT] Grenade cancel requested")
		grenade_cancel_requested.emit()
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_move_up"):
		_emit_movement_input(Vector2i.UP)
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_move_down"):
		_emit_movement_input(Vector2i.DOWN)
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_move_left"):
		_emit_movement_input(Vector2i.LEFT)
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("ui_move_right"):
		_emit_movement_input(Vector2i.RIGHT)
		if viewport:
			viewport.set_input_as_handled()
	# Debug actions
	elif key.is_action_pressed("debug_toggle_map_loader"):
		print_debug("[INPUT] Debug: toggle map loader")
		debug_command_requested.emit("toggle_map_loader")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("debug_toggle_voxel_ruler"):
		print_debug("[INPUT] Debug: toggle voxel ruler")
		debug_command_requested.emit("toggle_voxel_ruler")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("debug_toggle_nudge_mode"):
		print_debug("[INPUT] Debug: toggle nudge mode")
		debug_command_requested.emit("toggle_nudge_mode")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("debug_toggle_bake_mode"):
		print_debug("[INPUT] Debug: toggle bake mode")
		debug_command_requested.emit("toggle_bake_mode")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("debug_cycle_blend_mode"):
		print_debug("[INPUT] Debug: cycle blend mode")
		debug_command_requested.emit("cycle_blend_mode")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("debug_cycle_language"):
		print_debug("[INPUT] Debug: cycle language")
		debug_command_requested.emit("cycle_language")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("debug_toggle_occlusion"):
		print_debug("[INPUT] Debug: toggle occlusion")
		debug_command_requested.emit("toggle_occlusion")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("debug_nudge_reset"):
		print_debug("[INPUT] Debug: nudge reset")
		debug_command_requested.emit("nudge_reset")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("debug_force_damage_gallery"):
		print_debug("[INPUT] Debug: force damage gallery")
		debug_command_requested.emit("force_damage_gallery")
		if viewport:
			viewport.set_input_as_handled()
	elif key.is_action_pressed("debug_atom_sheet"):
		print_debug("[INPUT] Debug: toggle atom sheet")
		debug_command_requested.emit("toggle_atom_sheet")
		if viewport:
			viewport.set_input_as_handled()


func _emit_movement_input(direction: Vector2i) -> void:
	## Helper: emit movement input with Shift modifier for step size.
	var is_large_step := Input.is_key_pressed(KEY_SHIFT)
	print_debug("[INPUT] Movement %s (large_step=%s)" % [direction, is_large_step])
	movement_input_requested.emit(direction, is_large_step)
