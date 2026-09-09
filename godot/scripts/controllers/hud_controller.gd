extends Node
## HudController — the ONLY thing in the project that knows a HUD widget's name.
##
## UI-SPLIT-02 (2026-09-09) finished the HUD-PANEL-01 migration this file's
## docstring used to describe as half-done ("The @onready nodes remain in
## room.gd"). They no longer do. This controller resolves every widget from the
## HUD scene root itself, and the engine — room.gd, camera_controller,
## vision_controller, debug_tools_controller — reaches the interface only
## through the signals and intent-level methods below.
##
## THAT IS THE POINT, and it is why this file belongs to the DESIGN branch even
## though its callers are engine: renaming or restructuring a widget changes the
## node paths in setup() and NOTHING else. Before this, the engine held 21
## hardcoded $HUD/... paths, so moving a button broke the game at RUNTIME with a
## null @onready — a failure no git gate can catch, which is exactly what the
## two-workspace split had to eliminate.
##
## Adding a widget the engine must drive: give it a signal (input) or a
## set_*/update_* method (output) here. Never hand the node itself out.

signal end_turn_requested()
signal reset_requested()
signal fullscreen_toggled(enabled: bool)
signal viewport_toggled()
signal numbers_toggled(enabled: bool)
## UI-SPLIT-02: raised by the perspective pad and the view-mode buttons, which
## camera_controller used to reach into room.gd to fetch and wire by hand.
signal perspective_requested(direction: String)
signal view_mode_toggled(which: String, is_pressed: bool)

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
## UI-SPLIT-02: taken over from room.gd's @onready block.
var _toolbar_row: BoxContainer
var _perspective_pad: Control
var _btn_perspective: Dictionary = {}   ## "W"/"N"/"S"/"E" → Button
var _btn_view: Dictionary = {}          ## "heat"/"light"/"dev" → Button

# Panel references (populated in setup() if panels exist)
var _enemy_banner_panel: Variant = null

## Cached so the labels can be rebuilt verbatim when the language changes.
var _ap_current: int = 0
var _ap_max: int = 0
var _ap_is_enemy: bool = false
var _alert_pct: float = 0.0
var _busted_visible: bool = false
var _busted_key: String = "ui.banner.busted"


## `hud_root` is the HUD CanvasLayer — godot/scenes/ui/hud.tscn, instanced by
## room.tscn. Every path below is relative to it and appears ONCE in the whole
## project, which is what lets the interface be restructured without touching
## the engine. A widget that has been renamed away resolves to null, and every
## method here is already null-guarded, so a partial HUD degrades instead of
## crashing the room.
func setup(hud_root: Node) -> void:
	if hud_root == null:
		push_error("[HudController] setup: hud_root is null — the HUD scene is missing from room.tscn")
		return
	_btn_end_turn = hud_root.get_node_or_null("TopBar/Row/BtnEndTurn")
	_btn_reset = hud_root.get_node_or_null("TopBar/Row/BtnReset")
	_btn_fullscreen = hud_root.get_node_or_null("TopBar/Row/BtnFullscreen")
	_btn_viewport = hud_root.get_node_or_null("TopBar/Row/BtnViewport")
	_btn_numbers = hud_root.get_node_or_null("TopBar/Row/BtnNumbers")
	_chk_auto_end_turn = hud_root.get_node_or_null("TopBar/Row/BtnEndTurn/Content/ChkAutoEndTurn")
	_lbl_ap = hud_root.get_node_or_null("TopBar/Row/LblAp")
	_lbl_alert = hud_root.get_node_or_null("TopBar/Row/LblAlert")
	_busted_dialog = hud_root.get_node_or_null("BustedDialog")
	_enemy_turn_banner = hud_root.get_node_or_null("EnemyTurnBanner")
	_lbl_end_turn = hud_root.get_node_or_null("TopBar/Row/BtnEndTurn/Content/LblEndTurn")
	_lbl_enemy_turn = hud_root.get_node_or_null("EnemyTurnBanner/LblEnemyTurn")
	_toolbar_row = hud_root.get_node_or_null("TopBar/Row")
	_perspective_pad = hud_root.get_node_or_null("PerspectivePad")
	_btn_perspective = {
		"W": hud_root.get_node_or_null("PerspectivePad/Grid/BtnPerspectiveNW"),
		"N": hud_root.get_node_or_null("PerspectivePad/Grid/BtnPerspectiveNE"),
		"S": hud_root.get_node_or_null("PerspectivePad/Grid/BtnPerspectiveSW"),
		"E": hud_root.get_node_or_null("PerspectivePad/Grid/BtnPerspectiveSE"),
	}
	_btn_view = {
		"heat": hud_root.get_node_or_null("TopBar/Row/BtnViewH"),
		"light": hud_root.get_node_or_null("TopBar/Row/BtnViewL"),
		"dev": hud_root.get_node_or_null("TopBar/Row/BtnViewV"),
	}

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


## ── UI-SPLIT-02: what the engine used to do by holding the widget ──────────

const _ACTIVE_MOD := Color(1.0, 1.0, 1.0, 1.0)
const _INACTIVE_MOD := Color(1.0, 1.0, 1.0, 0.45)
const _DIM_MOD := Color(1.0, 1.0, 1.0, 0.35)


## Highlights the pad button matching the active perspective ("W"/"N"/"S"/"E").
func set_perspective_active(direction: String) -> void:
	for key: String in _btn_perspective:
		var btn: Button = _btn_perspective[key]
		if btn:
			btn.modulate = _ACTIVE_MOD if key == direction else _INACTIVE_MOD


## Reflects a view mode's state on its button ("heat" / "light" / "dev").
## `set_pressed_no_signal` matters: the engine calls this from inside the
## handler the button itself raised, so echoing the signal would recurse.
func set_view_mode_active(which: String, enabled: bool) -> void:
	var btn: Button = _btn_view.get(which)
	if btn == null:
		return
	btn.set_pressed_no_signal(enabled)
	btn.modulate = _ACTIVE_MOD if enabled else _DIM_MOD


## ROTATE-KILL-01: the perspective pad is a dev/QA tool, shown only with dev
## vision on. vision_controller drives this; it used to set .visible itself.
func set_perspective_pad_visible(is_visible: bool) -> void:
	if _perspective_pad:
		_perspective_pad.visible = is_visible


## Adds an engine-created button to the top toolbar (the F-key dev tools do
## this). Returns false when there is no toolbar to add it to, so the caller
## can skip its own setup rather than half-build a control nobody can reach.
func add_toolbar_button(button: Button) -> bool:
	if _toolbar_row == null or button == null:
		return false
	_toolbar_row.add_child(button)
	return true


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

	## UI-SPLIT-02: camera_controller used to fetch these seven buttons off
	## room.gd and connect them itself. They are wired where they live now, and
	## the engine listens for the intent.
	for key: String in _btn_perspective:
		var pad_btn: Button = _btn_perspective[key]
		if pad_btn:
			pad_btn.pressed.connect(
				func() -> void: perspective_requested.emit(key))

	for which: String in _btn_view:
		var view_btn: Button = _btn_view[which]
		if view_btn:
			view_btn.toggled.connect(
				func(is_pressed: bool) -> void: view_mode_toggled.emit(which, is_pressed))


func _on_fullscreen_pressed() -> void:
	var mode := DisplayServer.window_get_mode()
	var enabled := mode != DisplayServer.WINDOW_MODE_FULLSCREEN and mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	fullscreen_toggled.emit(enabled)
