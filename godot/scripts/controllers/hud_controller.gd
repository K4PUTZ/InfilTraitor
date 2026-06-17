extends Node
## HudController — Manages all UI wiring: buttons, labels, banners, checkboxes.
##
## The @onready nodes remain in room.gd. This controller receives references
## in setup() and emits signals for user actions.
##
## room.gd connects to this controller's signals and runs the gameplay logic.

signal end_turn_requested()
signal reset_requested()
signal fullscreen_toggled(enabled: bool)
signal viewport_toggled()
signal numbers_toggled(enabled: bool)

var _btn_end_turn: Button
var _btn_reset: Button
var _btn_fullscreen: Button
var _btn_viewport: Button
var _btn_numbers: Button
var _chk_auto_end_turn: CheckBox
var _lbl_ap: Label
var _lbl_alert: Label
var _busted_dialog: Control
var _enemy_turn_banner: Control


func setup(refs: Dictionary) -> void:
	## refs holds the @onready nodes from room.gd, passed by name.
	_btn_end_turn = refs.get("btn_end_turn")
	_btn_reset = refs.get("btn_reset")
	_btn_fullscreen = refs.get("btn_fullscreen")
	_btn_viewport = refs.get("btn_viewport")
	_btn_numbers = refs.get("btn_numbers")
	_chk_auto_end_turn = refs.get("chk_auto_end_turn")
	_lbl_ap = refs.get("lbl_ap")
	_lbl_alert = refs.get("lbl_alert")
	_busted_dialog = refs.get("busted_dialog")
	_enemy_turn_banner = refs.get("enemy_turn_banner")
	_connect_buttons()


## Updates the AP label with the current and max value
func update_ap(current: int, max_ap: int, is_enemy_phase: bool = false) -> void:
	if _lbl_ap:
		_lbl_ap.text = "ENEMIES" if is_enemy_phase else "AP %d/%d" % [current, max_ap]


## Updates the alert label with a percentage (0.0 - 1.0)
func update_alert(pct: float) -> void:
	if _lbl_alert:
		var alert_int := int(pct * 100)
		_lbl_alert.text = "ALERT %d%%" % alert_int
		# Modulate the color as the alert rises
		var t := pct
		_lbl_alert.modulate = Color(1.0, 1.0 - 0.55 * t, 1.0 - 0.75 * t, 1.0)


## Shows the enemy-turn banner
func show_enemy_banner() -> void:
	if _enemy_turn_banner:
		_enemy_turn_banner.visible = true


## Hides the enemy-turn banner
func hide_enemy_banner() -> void:
	if _enemy_turn_banner:
		_enemy_turn_banner.visible = false


## Shows the "Busted" dialog
func show_busted(text: String = "Busted") -> void:
	if _busted_dialog:
		_busted_dialog.text = text
		_busted_dialog.visible = true


## Hides the "Busted" dialog
func hide_busted() -> void:
	if _busted_dialog:
		_busted_dialog.visible = false


## Enables/disables the end-turn button
func set_end_turn_enabled(value: bool) -> void:
	if _btn_end_turn:
		_btn_end_turn.disabled = not value


## Checks whether auto-end-turn is enabled
func is_auto_end_turn_enabled() -> bool:
	if _chk_auto_end_turn:
		return _chk_auto_end_turn.button_pressed
	return false


## Updates the modulate of the numbers button (toggle)
func set_numbers_button_active(active: bool) -> void:
	if _btn_numbers:
		_btn_numbers.modulate = Color.WHITE if active else Color(1.0, 1.0, 1.0, 0.35)


## Updates the modulate of the viewport button
func set_viewport_button_text(text: String) -> void:
	if _btn_viewport:
		_btn_viewport.text = text


## Connects the button signals
func _connect_buttons() -> void:
	if _btn_end_turn:
		_btn_end_turn.pressed.connect(func() -> void: end_turn_requested.emit())

	if _btn_reset:
		_btn_reset.pressed.connect(func() -> void: reset_requested.emit())

	if _btn_fullscreen:
		_btn_fullscreen.pressed.connect(_on_fullscreen_pressed)

	if _btn_viewport:
		_btn_viewport.pressed.connect(func() -> void: viewport_toggled.emit())

	if _btn_numbers:
		_btn_numbers.pressed.connect(func() -> void: numbers_toggled.emit())


func _on_fullscreen_pressed() -> void:
	var mode := DisplayServer.window_get_mode()
	var enabled := mode != DisplayServer.WINDOW_MODE_FULLSCREEN and mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	fullscreen_toggled.emit(enabled)
