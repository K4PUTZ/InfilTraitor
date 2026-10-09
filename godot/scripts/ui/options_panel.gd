## OPTIONS-01 (Director, 2026-10-08): the Options window, opened from the Main Menu (Escape).
##
## Holds the player's choices that persist in `user://settings.cfg`:
##  - Frame rate: 30 (default) / 60 / uncapped — `FrameRate` (no choice under 30, see its header).
##  - Language: every `Localization.supported_locales` entry — `Localization.set_language()`, which also saves it.
## Built in code like `MainMenuPanel` and `ControlsPanel`; texts are rebuilt on a language change.
class_name OptionsPanel
extends WindowBase

@onready var _center_container := CenterContainer.new()
@onready var _panel_bg := Panel.new()
@onready var _margin := MarginContainer.new()
@onready var _container := VBoxContainer.new()
@onready var _lbl_title := Label.new()
@onready var _lbl_fps := Label.new()
@onready var _row_fps := HBoxContainer.new()
@onready var _lbl_language := Label.new()
@onready var _row_language := HBoxContainer.new()
@onready var _btn_back := Button.new()

var _fps_buttons: Dictionary = {}       ## cap -> Button
var _language_buttons: Dictionary = {}  ## locale -> Button


func _ready() -> void:
	pausable = true
	super._ready()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = get_node_or_null("background")
	if bg:
		bg.color = Color(0, 0, 0, 0.4)

	_center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center_container)
	_panel_bg.custom_minimum_size = Vector2(420, 400)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel_bg.add_theme_stylebox_override("panel", style)
	_center_container.add_child(_panel_bg)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 32)
	_panel_bg.add_child(_margin)
	_container.add_theme_constant_override("separation", 14)
	_margin.add_child(_container)

	_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_title.add_theme_font_size_override("font_size", 24)
	_container.add_child(_lbl_title)
	_container.add_child(HSeparator.new())

	_container.add_child(_lbl_fps)
	_row_fps.add_theme_constant_override("separation", 8)
	_container.add_child(_row_fps)
	var fps_group := ButtonGroup.new()
	for cap: int in FrameRate.CHOICES:
		var btn := _choice_button(fps_group)
		btn.pressed.connect(_on_fps_chosen.bind(cap))
		_row_fps.add_child(btn)
		_fps_buttons[cap] = btn

	_container.add_child(_lbl_language)
	_row_language.add_theme_constant_override("separation", 8)
	_container.add_child(_row_language)
	var language_group := ButtonGroup.new()
	var localization: Node = get_node_or_null("/root/Localization")
	if localization != null:
		for locale: String in localization.supported_locales:
			var btn := _choice_button(language_group)
			btn.pressed.connect(_on_language_chosen.bind(locale))
			_row_language.add_child(btn)
			_language_buttons[locale] = btn
		localization.language_changed.connect(func(_locale: String) -> void: _apply_texts())

	_container.add_child(HSeparator.new())
	_btn_back.custom_minimum_size = Vector2(200, 44)
	_btn_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_back.pressed.connect(request_close)
	_container.add_child(_btn_back)
	_apply_texts()


## The current choices are shown pressed every time the window opens (a flag or another path may have changed them).
func open() -> void:
	super.open()
	var cap: int = FrameRate.saved_cap()
	if _fps_buttons.has(cap):
		(_fps_buttons[cap] as Button).button_pressed = true
	var locale: String = TranslationServer.get_locale()
	if _language_buttons.has(locale):
		(_language_buttons[locale] as Button).button_pressed = true
	_btn_back.grab_focus()


func _choice_button(group: ButtonGroup) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(110, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## The chosen option has to read at a glance; the default theme barely marks a pressed toggle.
	var chosen := StyleBoxFlat.new()
	chosen.bg_color = Color(0.85, 0.85, 0.85, 1.0)
	chosen.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", chosen)
	btn.add_theme_stylebox_override("hover_pressed", chosen)
	btn.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.05))
	btn.add_theme_color_override("font_hover_pressed_color", Color(0.05, 0.05, 0.05))
	return btn


func _apply_texts() -> void:
	title = tr("ui.options.title")
	_lbl_title.text = title
	_lbl_fps.text = tr("ui.options.frame_rate")
	for cap: int in _fps_buttons:
		(_fps_buttons[cap] as Button).text = tr("ui.options.fps_uncapped") if cap == 0 else tr("ui.options.fps_n") % cap
	_lbl_language.text = tr("ui.options.language")
	for locale: String in _language_buttons:
		(_language_buttons[locale] as Button).text = tr("language.name." + locale)
	_btn_back.text = tr("ui.controls.back")


func _on_fps_chosen(cap: int) -> void:
	FrameRate.set_cap(cap)


func _on_language_chosen(locale: String) -> void:
	var localization: Node = get_node_or_null("/root/Localization")
	if localization != null:
		localization.set_language(locale)
