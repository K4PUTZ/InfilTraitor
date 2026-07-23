## PAUSE-MENU-01: First concrete menu built on WindowBase.
class_name MainMenuPanel
extends WindowBase

signal reset_requested
signal settings_requested
signal controls_requested

@onready var _center_container := CenterContainer.new()
@onready var _panel_bg := Panel.new()
@onready var _margin := MarginContainer.new()
@onready var _container := VBoxContainer.new()

@onready var _lbl_title := Label.new()
@onready var _sep := HSeparator.new()
@onready var _btn_new_game := Button.new()
@onready var _btn_load := Button.new()
@onready var _btn_controls := Button.new()
@onready var _btn_options := Button.new()
@onready var _btn_quit := Button.new()

func _ready() -> void:
	pausable = true
	super._ready()
	
	# Background overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = get_node_or_null("background")
	if bg:
		bg.color = Color(0, 0, 0, 0.4)
	
	title = tr("ui.main_menu.title")
	
	# Layout hierarchy
	_center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center_container)
	
	# Dark box
	_panel_bg.custom_minimum_size = Vector2(320, 480)
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
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", 16)
	_margin.add_child(_container)
	
	# Title
	_lbl_title.text = title
	_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_title.add_theme_font_size_override("font_size", 24)
	_container.add_child(_lbl_title)
	
	_container.add_child(_sep)
	
	# Buttons
	_setup_button(_btn_new_game, "ui.main_menu.new_game", _on_new_game_pressed)
	_setup_button(_btn_load, "ui.main_menu.load", _on_load_pressed)
	_setup_button(_btn_controls, "ui.main_menu.controls", _on_controls_pressed)
	_setup_button(_btn_options, "ui.main_menu.options", _on_options_pressed)
	_setup_button(_btn_quit, "ui.main_menu.quit", _on_quit_pressed)
	
	_btn_load.disabled = true
	_btn_options.disabled = true

## ESC-STACK-01: "New Game" starts focused so Enter advances immediately —
## same native Button/ui_accept mechanism DetonateContextMenu already relies
## on for its own "Enters avançam" behavior, applied here too.
func open() -> void:
	super.open()
	_btn_new_game.grab_focus()

func _setup_button(btn: Button, text_key: String, callable: Callable) -> void:
	btn.text = tr(text_key)
	btn.custom_minimum_size = Vector2(200, 44)
	btn.pressed.connect(callable)
	_container.add_child(btn)

func _on_new_game_pressed() -> void:
	reset_requested.emit()
	request_close()

func _on_load_pressed() -> void:
	pass

func _on_controls_pressed() -> void:
	controls_requested.emit()

func _on_options_pressed() -> void:
	settings_requested.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
