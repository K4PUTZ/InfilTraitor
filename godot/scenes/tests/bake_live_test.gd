## BAKE LIVE TEST: Interactive test scene with PLAYGROUND
## Tests BakeConfig.enabled=true rendering in interactive mode
## Also tests F5 toggle (generic vs baked rendering comparison)

extends Node

const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")

var _current_room: Node = null
var _baking_enabled: bool = true
var _ui_label: Label = null


func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE LIVE TEST: Interactive rendering with baking toggle")
	print("=".repeat(80))
	print("Controls: F5 = toggle baking (generic ↔ baked)")
	print("Expected: Visual difference in wall textures (baked should be smoother)")
	print("=".repeat(80) + "\n")
	
	# Setup
	BakeConfigClass.load_config()
	
	# Create UI label
	_ui_label = Label.new()
	_ui_label.anchor_left = 0.0
	_ui_label.anchor_top = 0.0
	_ui_label.offset_right = 400
	_ui_label.offset_bottom = 100
	_ui_label.text = "BakeConfig.enabled = true\nPress F5 to toggle"
	_ui_label.add_theme_font_size_override("font_size", 20)
	add_child(_ui_label)
	
	# Load PLAYGROUND map
	_load_and_render_map("PLAYGROUND", _baking_enabled)
	print("✓ PLAYGROUND loaded with baking ENABLED\n")


func _load_and_render_map(map_name: String, bake_enabled: bool) -> void:
	# Cleanup old room
	if _current_room:
		_current_room.queue_free()
		_current_room = null
	
	# Configure baking
	BakeConfigClass.enabled = bake_enabled
	print("  Setting BakeConfig.enabled = %s" % bake_enabled)
	
	# Load map spec
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec(map_name)
	
	if map_spec == null or map_spec.is_empty():
		print("  ✗ Could not load %s" % map_name)
		return
	
	# Build room
	_current_room = RoomBuilderClass.build_from_layout(map_spec)
	if _current_room:
		add_child(_current_room)
		_current_room.position = Vector3.ZERO
		print("  ✓ Room rendered with BakeConfig.enabled=%s" % bake_enabled)
	else:
		print("  ✗ Failed to build room")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			_baking_enabled = not _baking_enabled
			_load_and_render_map("PLAYGROUND", _baking_enabled)
			_update_ui_label()
			get_tree().root.set_input_as_handled()


func _update_ui_label() -> void:
	if _ui_label:
		var mode = "BAKED" if _baking_enabled else "GENERIC"
		_ui_label.text = "BakeConfig.enabled = %s (%s)\nPress F5 to toggle" % [_baking_enabled, mode]
