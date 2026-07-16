## PAUSE-MENU-02: Controls Panel.
class_name ControlsPanel
extends WindowBase

@onready var _center_container := CenterContainer.new()
@onready var _panel_bg := Panel.new()
@onready var _margin := MarginContainer.new()
@onready var _container := VBoxContainer.new()

@onready var _lbl_title := Label.new()
@onready var _sep := HSeparator.new()
@onready var _scroll := ScrollContainer.new()
@onready var _list := VBoxContainer.new()
@onready var _btn_back := Button.new()

func _ready() -> void:
	pausable = true
	super._ready()
	
	# Background overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = get_node_or_null("background")
	if bg:
		bg.color = Color(0, 0, 0, 0.4)
	
	title = tr("ui.controls.title")
	
	# Layout hierarchy
	_center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center_container)
	
	# Dark box
	_panel_bg.custom_minimum_size = Vector2(480, 560)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel_bg.add_theme_stylebox_override("panel", style)
	_center_container.add_child(_panel_bg)
	
	# Margins
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_left", 32)
	_margin.add_theme_constant_override("margin_right", 32)
	_margin.add_theme_constant_override("margin_top", 32)
	_margin.add_theme_constant_override("margin_bottom", 32)
	_panel_bg.add_child(_margin)
	
	# VBox
	_container.add_theme_constant_override("separation", 16)
	_margin.add_child(_container)
	
	# Title
	_lbl_title.text = title
	_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_title.add_theme_font_size_override("font_size", 24)
	_container.add_child(_lbl_title)
	
	_container.add_child(_sep)
	
	# Scroll area
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_container.add_child(_scroll)
	
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	
	# Back button
	_btn_back.text = tr("ui.controls.back")
	_btn_back.custom_minimum_size = Vector2(200, 44)
	_btn_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_back.pressed.connect(request_close)
	_container.add_child(_btn_back)
	
	_populate_controls()

func _populate_controls() -> void:
	var actions = InputMap.get_actions()
	var relevant_actions = []
	for action in actions:
		if action.begins_with("ui_") or action.begins_with("debug_"):
			relevant_actions.append(action)
	
	relevant_actions.sort()
	
	for action in relevant_actions:
		var events = InputMap.action_get_events(action)
		if events.is_empty():
			continue
			
		var event = events[0]
		var key_name = ""
		if event is InputEventKey:
			key_name = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
			if event.shift_pressed:
				key_name = "Shift+" + key_name
			if event.ctrl_pressed:
				key_name = "Ctrl+" + key_name
			if event.alt_pressed:
				key_name = "Alt+" + key_name
		
		var row := HBoxContainer.new()
		var lbl_action := Label.new()
		var lbl_key := Label.new()
		
		lbl_action.text = action.capitalize().replace("Ui ", "").replace("Debug ", "Debug: ")
		lbl_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		lbl_key.text = key_name
		lbl_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_key.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		
		row.add_child(lbl_action)
		row.add_child(lbl_key)
		_list.add_child(row)
