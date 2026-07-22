## DetonateContextMenu — small black-box context menu for right-clicking a
## detonatable TEST-ZONE prop (placeholder, 2026-07-21). Two actions:
## "Detonar (Enter)" then a separator then "Cancelar (Esc)". Enter/Space
## activate the focused button natively (Godot's own Control focus system) —
## no custom accept handling needed. Esc and outside-clicks are handled by
## the caller (room.gd owns all mouse/keyboard coordination — see its
## _unhandled_input), not here, so there is exactly one place deciding
## "is the menu open" instead of two competing input handlers.
class_name DetonateContextMenu
extends Control

signal detonate_requested
signal cancelled

@onready var _panel := Panel.new()
@onready var _vbox := VBoxContainer.new()
@onready var _btn_detonate := Button.new()
@onready var _sep := HSeparator.new()
@onready var _btn_cancel := Button.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	_vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(_vbox)

	_btn_detonate.text = tr("ui.context_menu.detonate")
	_btn_detonate.flat = true
	_btn_detonate.focus_mode = Control.FOCUS_ALL
	_btn_detonate.pressed.connect(_on_detonate_pressed)
	_vbox.add_child(_btn_detonate)

	## Explicit line style — HSeparator's default theme color is too close to
	## the panel's own black background to read as a divider at this size.
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(1, 1, 1, 0.25)
	sep_style.thickness = 1
	_sep.add_theme_stylebox_override("separator", sep_style)
	_vbox.add_child(_sep)

	_btn_cancel.text = tr("ui.context_menu.cancel")
	_btn_cancel.flat = true
	_btn_cancel.focus_mode = Control.FOCUS_ALL
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	_vbox.add_child(_btn_cancel)

	visible = false


## Show the box with its BOTTOM edge `gap_above_px` above `top_anchor_screen_pos`
## (already converted to screen/canvas space by the caller), horizontally
## centered on it. "Detonar" starts focused so Enter fires it immediately.
func open_at(top_anchor_screen_pos: Vector2, gap_above_px: float = 30.0) -> void:
	visible = true
	## Reset to a known size before measuring — a stale size from a previous
	## open() would otherwise mis-center this one for a single frame.
	_panel.reset_size()
	await get_tree().process_frame
	var box_size: Vector2 = _panel.size
	_panel.position = Vector2(
		top_anchor_screen_pos.x - box_size.x / 2.0,
		top_anchor_screen_pos.y - gap_above_px - box_size.y
	)
	_btn_detonate.grab_focus()


func close() -> void:
	visible = false


## True if a screen-space point falls inside the menu's own box — the
## caller (room.gd) uses this to distinguish "click on the menu" (already
## handled by the Button itself, never reaches this) from "click elsewhere"
## (outside-click dismiss).
func contains_screen_point(screen_pos: Vector2) -> bool:
	return visible and _panel.get_global_rect().has_point(screen_pos)


func _on_detonate_pressed() -> void:
	close()
	detonate_requested.emit()


func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()
