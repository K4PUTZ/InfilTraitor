## DetonateContextMenu — small black-box context menu for right-clicking an
## interactive TEST-ZONE prop (placeholder, 2026-07-21). One parameterised
## action then a separator then "Cancelar (Esc)". Enter/Space activate the
## focused button natively (Godot's own Control focus system) — no custom
## accept handling needed. Esc and outside-clicks are handled by the caller
## (room.gd owns all mouse/keyboard coordination — see its _unhandled_input),
## not here, so there is exactly one place deciding "is the menu open" instead
## of two competing input handlers.
##
## WEAPON-FIRE-01 (2026-07-29): the action label and its handler are now passed
## in at open_at() time, because a second prop type needed a second verb
## ("Atirar" on a bench weapon vs. "Detonar" on a grenade). One shared menu
## INSTANCE is deliberate, not incidental: room.gd's _unhandled_input treats any
## click while `_context_menu.visible` as an outside-click cancel, and a second
## instance would need that guard to know about both.
##
## The class and file name are now historical — this is no longer detonation
## specific. Renaming both is a follow-up, not a silent partial rename that
## would leave the file and the class disagreeing.
class_name DetonateContextMenu
extends Control

## Emitted when the parameterised action button is pressed. The caller decides
## what that means — see open_at()'s on_confirm.
signal action_requested
signal cancelled
## GU-GRID-01/ESC-STACK-01: mirrors PanelBase's opened/closed contract (this
## menu extends Control directly, not PanelBase, for its custom black-box
## layout) so room.gd can push/pop it on the same ModalStack as the WindowBase
## panels without a special case.
signal opened
signal closed

@onready var _panel := PanelContainer.new()
@onready var _vbox := VBoxContainer.new()
@onready var _btn_action := Button.new()
@onready var _sep := HSeparator.new()
@onready var _btn_cancel := Button.new()

## WEAPON-FIRE-01: what the action button should do for the prop this open()
## was for. Cleared on close so a stale handler can never fire against a prop
## that is no longer selected.
var _on_confirm: Callable = Callable()


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

	## Text is set per-open (open_at); this is only the pre-open default so the
	## button is never blank if something opens it without a label.
	_btn_action.text = tr("ui.context_menu.detonate")
	_btn_action.flat = true
	_btn_action.focus_mode = Control.FOCUS_ALL
	_btn_action.pressed.connect(_on_action_pressed)
	_vbox.add_child(_btn_action)

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
## centered on it. The action button starts focused so Enter fires it
## immediately.
##
## action_key: a localization key ("ui.context_menu.detonate"/".fire"). Never a
## literal string — CLAUDE.md bans hardcoded player-facing text.
## on_confirm: invoked when that button is pressed. Defaults to an empty
## Callable, in which case only the `action_requested` signal is emitted.
func open_at(top_anchor_screen_pos: Vector2, gap_above_px: float = 30.0,
		action_key: String = "ui.context_menu.detonate",
		on_confirm: Callable = Callable()) -> void:
	_btn_action.text = tr(action_key)
	_on_confirm = on_confirm
	visible = true
	opened.emit()
	## Reset to a known size before measuring — a stale size from a previous
	## open() would otherwise mis-center this one for a single frame.
	_panel.reset_size()
	await get_tree().process_frame
	var box_size: Vector2 = _panel.size
	_panel.position = Vector2(
		top_anchor_screen_pos.x - box_size.x / 2.0,
		top_anchor_screen_pos.y - gap_above_px - box_size.y
	)
	_btn_action.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_on_confirm = Callable()
	closed.emit()


func _on_action_pressed() -> void:
	## Capture before close() clears it — close() must run first so the menu is
	## already gone by the time the action's own visuals (blast flash, muzzle
	## flash) play.
	var confirm := _on_confirm
	close()
	if confirm.is_valid():
		confirm.call()
	action_requested.emit()


func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()
