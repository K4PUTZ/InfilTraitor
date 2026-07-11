extends Node
## HudController — Manages all UI wiring: buttons, labels, banners, checkboxes.
##
## HUD-PANEL-01 refactor: This controller now delegates to TopBarPanel and
## EnemyBannerPanel (if present) while maintaining backward compatibility
## with direct node access. The @onready nodes remain in room.gd.
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
var _lbl_end_turn: Label
var _lbl_enemy_turn: Label

# Panel references (populated in setup() if panels exist)
var _enemy_banner_panel: Variant = null

## Cached so the labels can be rebuilt verbatim when the language changes.
var _ap_current: int = 0
var _ap_max: int = 0
var _ap_is_enemy: bool = false
var _alert_pct: float = 0.0
var _busted_visible: bool = false
var _busted_key: String = "ui.banner.busted"


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
	_lbl_end_turn = refs.get("lbl_end_turn")
	_lbl_enemy_turn = refs.get("lbl_enemy_turn")
	
	# HUD-PANEL-01: Capture panel references if they exist (new architecture)
	if _enemy_turn_banner:
		_enemy_banner_panel = _enemy_turn_banner.get_parent() if _enemy_turn_banner.get_parent() else _enemy_turn_banner
		# If the node itself is a panel (has open/close methods), use it
		if _enemy_turn_banner.has_method("open"):
			_enemy_banner_panel = _enemy_turn_banner
	
	_connect_buttons()
	_apply_static_text()
	## Fetched via tree path (dynamic) so it resolves regardless of autoload
	## global indexing. See OPERATOR_CONTEXT → Localization.
	var localization: Variant = get_node_or_null("/root/Localization")
	if localization:
		localization.language_changed.connect(_on_language_changed)


## Updates the AP label with the current and max value
func update_ap(current: int, max_ap: int, is_enemy_phase: bool = false) -> void:
	_ap_current = current
	_ap_max = max_ap
	_ap_is_enemy = is_enemy_phase
	if _lbl_ap:
		_lbl_ap.text = tr("ui.hud.enemies") if is_enemy_phase else tr("ui.hud.ap_counter") % [current, max_ap]


## Updates the alert label with a percentage (0.0 - 1.0)
func update_alert(pct: float) -> void:
	_alert_pct = pct
	if _lbl_alert:
		var alert_int := int(pct * 100)
		_lbl_alert.text = tr("ui.hud.alert") % alert_int
		# Modulate the color as the alert rises
		var t := pct
		_lbl_alert.modulate = Color(1.0, 1.0 - 0.55 * t, 1.0 - 0.75 * t, 1.0)


## Shows the enemy-turn banner
func show_enemy_banner() -> void:
	# Delegate to panel if available (HUD-PANEL-01 refactor)
	if _enemy_banner_panel and _enemy_banner_panel.has_method("show_banner"):
		_enemy_banner_panel.show_banner()
	elif _enemy_turn_banner:
		_enemy_turn_banner.visible = true


## Hides the enemy-turn banner
func hide_enemy_banner() -> void:
	# Delegate to panel if available (HUD-PANEL-01 refactor)
	if _enemy_banner_panel and _enemy_banner_panel.has_method("hide_banner"):
		_enemy_banner_panel.hide_banner()
	elif _enemy_turn_banner:
		_enemy_turn_banner.visible = false


## Shows the "Busted" dialog. `text_key` is a localization key (see ui.csv).
func show_busted(text_key: String = "ui.banner.busted") -> void:
	_busted_key = text_key
	_busted_visible = true
	if _busted_dialog:
		_busted_dialog.text = tr(text_key)
		_busted_dialog.visible = true


## Hides the "Busted" dialog
func hide_busted() -> void:
	_busted_visible = false
	if _busted_dialog:
		_busted_dialog.visible = false


## Applies localized text to the static labels (set once + on language change).
func _apply_static_text() -> void:
	if _lbl_end_turn:
		_lbl_end_turn.text = tr("ui.button.end_turn")
	if _lbl_enemy_turn:
		_lbl_enemy_turn.text = tr("ui.banner.enemy_turn")


## Rebuilds every label in the new language. Dynamic labels use their cached
## values so the displayed numbers are preserved across the switch.
func _on_language_changed(_locale: String) -> void:
	_apply_static_text()
	update_ap(_ap_current, _ap_max, _ap_is_enemy)
	update_alert(_alert_pct)
	if _busted_visible and _busted_dialog:
		_busted_dialog.text = tr(_busted_key)


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
