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

var room: Node
var _camera_controller: Node = null


func _init(p_room: Node) -> void:
	room = p_room
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
		get_viewport().set_input_as_handled()


func _handle_key_action(key: InputEventKey) -> void:
	## Dispatch keyboard actions based on the Input Map.
	## This centralizes all key→action mapping.
	
	match key.keycode:
		KEY_Z:
			print_debug("[INPUT] Posture lower (Z) requested")
			posture_lower_requested.emit()
			get_viewport().set_input_as_handled()
		KEY_X:
			print_debug("[INPUT] Posture raise (X) requested")
			posture_raise_requested.emit()
			get_viewport().set_input_as_handled()
		KEY_V:
			print_debug("[INPUT] View mode dev (V) requested")
			view_mode_requested.emit("dev")
			get_viewport().set_input_as_handled()
		KEY_L:
			print_debug("[INPUT] View mode light (L) requested")
			view_mode_requested.emit("light")
			get_viewport().set_input_as_handled()
		KEY_H:
			print_debug("[INPUT] View mode heat (H) requested")
			view_mode_requested.emit("heat")
			get_viewport().set_input_as_handled()
		KEY_P:
			print_debug("[INPUT] Peek initiated (P)")
			peek_initiated.emit()
			get_viewport().set_input_as_handled()
		KEY_UP:
			var is_large_step := Input.is_key_pressed(KEY_SHIFT)
			print_debug("[INPUT] Movement up (large_step=%s)" % is_large_step)
			movement_input_requested.emit(Vector2i.UP, is_large_step)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			var is_large_step := Input.is_key_pressed(KEY_SHIFT)
			print_debug("[INPUT] Movement down (large_step=%s)" % is_large_step)
			movement_input_requested.emit(Vector2i.DOWN, is_large_step)
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			var is_large_step := Input.is_key_pressed(KEY_SHIFT)
			print_debug("[INPUT] Movement left (large_step=%s)" % is_large_step)
			movement_input_requested.emit(Vector2i.LEFT, is_large_step)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			var is_large_step := Input.is_key_pressed(KEY_SHIFT)
			print_debug("[INPUT] Movement right (large_step=%s)" % is_large_step)
			movement_input_requested.emit(Vector2i.RIGHT, is_large_step)
			get_viewport().set_input_as_handled()
		KEY_F2:
			print_debug("[INPUT] Debug: toggle map loader (F2)")
			debug_command_requested.emit("toggle_map_loader")
			get_viewport().set_input_as_handled()
		KEY_F3:
			print_debug("[INPUT] Debug: toggle voxel ruler (F3)")
			debug_command_requested.emit("toggle_voxel_ruler")
			get_viewport().set_input_as_handled()
		KEY_F4:
			print_debug("[INPUT] Debug: toggle nudge mode (F4)")
			debug_command_requested.emit("toggle_nudge_mode")
			get_viewport().set_input_as_handled()
		KEY_F6:
			print_debug("[INPUT] Debug: toggle bake mode (F6)")
			debug_command_requested.emit("toggle_bake_mode")
			get_viewport().set_input_as_handled()
		KEY_F7:
			print_debug("[INPUT] Debug: cycle blend mode (F7)")
			debug_command_requested.emit("cycle_blend_mode")
			get_viewport().set_input_as_handled()
		KEY_K:
			print_debug("[INPUT] Debug: cycle language (K)")
			debug_command_requested.emit("cycle_language")
			get_viewport().set_input_as_handled()
		KEY_R:
			print_debug("[INPUT] Debug: nudge reset (R)")
			debug_command_requested.emit("nudge_reset")
			get_viewport().set_input_as_handled()
