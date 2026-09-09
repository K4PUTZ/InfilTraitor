## UI-SPLIT-02 — the HUD seam between the engine and the design branch.
##
## What this pins is the CONTRACT, not the look: HudController must resolve every
## widget it needs out of the real godot/scenes/ui/hud.tscn, raise a signal for
## each interaction the engine acts on, and change the widgets when the engine
## asks. If that holds, the interface can be restructured on the design branch
## without the engine noticing — which is the whole reason the split exists.
##
## It is written against the REAL scene, deliberately. A fixture built here would
## be assembled from the node names this test already assumes, so it could not
## catch the failure that matters: someone renaming a node in hud.tscn and the
## engine silently losing a null @onready. Loading the shipped scene is what
## makes a rename fail HERE instead of on the Director's screen.
##
## RUNS AS A SCENE (TEST-DEBT-03): HudController reaches /root/Localization and
## calls tr(), so it needs autoloads, which exist only when a MAIN SCENE runs.
## run_selftests.py launches the sibling .tscn for exactly this reason.
##
## ⚠️ SceneTree.quit(code) is DEFERRED — every failing branch must `return` too,
## or a later quit(0) overwrites the failure's exit code.

extends Node

const HudControllerClass = preload("res://godot/scripts/controllers/hud_controller.gd")
const HUD_SCENE := "res://godot/scenes/ui/hud.tscn"

var _passed: int = 0
var _failed: int = 0

var _hud: CanvasLayer = null
var _hud_controller: Node = null


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("UI-SPLIT-02 TEST: the HUD seam")
	print("=".repeat(70) + "\n")

	await get_tree().process_frame

	var packed: PackedScene = load(HUD_SCENE)
	if packed == null:
		_fail("hud.tscn loads")
		_finish()
		return
	_hud = packed.instantiate()
	add_child(_hud)

	_hud_controller = HudControllerClass.new()
	add_child(_hud_controller)
	_hud_controller.setup(_hud)

	await get_tree().process_frame

	_test_widgets_resolved()
	_test_intents_are_signals()
	_test_engine_can_drive_presentation()

	_finish()


## TEST 1 — every widget the engine depends on was found in the real scene.
## Asserted through BEHAVIOUR rather than a null check: a null-guarded facade
## answers "not absent" happily while doing nothing, so the only honest question
## is whether asking it to change something changes something.
func _test_widgets_resolved() -> void:
	print("[TEST 1] setup() resolves the widgets out of hud.tscn")

	_hud_controller.update_ap(3, 7)
	var lbl_ap: Label = _hud.get_node_or_null("TopBar/Row/LblAp")
	_check(lbl_ap != null and "3" in lbl_ap.text and "7" in lbl_ap.text,
		"update_ap(3, 7) reaches LblAp (text=%s)"
		% ("<missing>" if lbl_ap == null else lbl_ap.text))

	_hud_controller.update_alert(0.5)
	var lbl_alert: Label = _hud.get_node_or_null("TopBar/Row/LblAlert")
	_check(lbl_alert != null and "50" in lbl_alert.text,
		"update_alert(0.5) reaches LblAlert (text=%s)"
		% ("<missing>" if lbl_alert == null else lbl_alert.text))

	var banner: Control = _hud.get_node_or_null("EnemyTurnBanner")
	_hud_controller.show_enemy_banner()
	_check(banner != null and banner.visible, "show_enemy_banner() shows it")
	_hud_controller.hide_enemy_banner()
	_check(banner != null and not banner.visible, "hide_enemy_banner() hides it")

	var busted: Control = _hud.get_node_or_null("BustedDialog")
	_hud_controller.show_busted()
	_check(busted != null and busted.visible, "show_busted() shows it")
	_hud_controller.hide_busted()
	_check(busted != null and not busted.visible, "hide_busted() hides it")


## TEST 2 — an interaction leaves the HUD as an INTENT, never as a widget.
## This is the half camera_controller used to do by fetching seven buttons off
## room.gd and connecting them itself.
func _test_intents_are_signals() -> void:
	print("\n[TEST 2] interactions arrive as signals carrying what happened")

	## ⚠️ A GDScript lambda captures a local BY VALUE, so `seen = d` inside one
	## writes to the copy and the outer variable never changes — the first
	## version of this test failed for exactly that reason and blamed the
	## controller. A Dictionary is a reference type, so mutating it carries out.
	var seen := {"direction": "", "mode": "", "pressed": false}
	_hud_controller.perspective_requested.connect(
		func(d: String) -> void: seen["direction"] = d)
	var btn_se: Button = _hud.get_node_or_null("PerspectivePad/Grid/BtnPerspectiveSE")
	if btn_se == null:
		_fail("BtnPerspectiveSE exists in hud.tscn")
		return
	btn_se.pressed.emit()
	_check(seen["direction"] == "E",
		"pressing the SE pad button emits perspective_requested(\"E\") (got %s)"
		% ["<none>" if seen["direction"] == "" else seen["direction"]])

	_hud_controller.view_mode_toggled.connect(
		func(which: String, is_pressed: bool) -> void:
			seen["mode"] = which
			seen["pressed"] = is_pressed)
	var btn_view_v: Button = _hud.get_node_or_null("TopBar/Row/BtnViewV")
	if btn_view_v == null:
		_fail("BtnViewV exists in hud.tscn")
		return
	btn_view_v.button_pressed = true
	_check(seen["mode"] == "dev" and seen["pressed"],
		"toggling the V button emits view_mode_toggled(\"dev\", true) (got %s/%s)"
		% [("<none>" if seen["mode"] == "" else seen["mode"]), seen["pressed"]])


## TEST 3 — the engine changes the HUD by asking, and the ask lands.
func _test_engine_can_drive_presentation() -> void:
	print("\n[TEST 3] the engine drives presentation through the facade")

	_hud_controller.set_perspective_active("N")
	var btn_n: Button = _hud.get_node_or_null("PerspectivePad/Grid/BtnPerspectiveNE")
	var btn_s: Button = _hud.get_node_or_null("PerspectivePad/Grid/BtnPerspectiveSW")
	## Identity, not "not the wrong thing": N must be the ACTIVE alpha and S the
	## inactive one, so a facade that dimmed everything could not pass.
	_check(btn_n != null and is_equal_approx(btn_n.modulate.a, 1.0),
		"set_perspective_active(\"N\") lights N (a=%.2f)"
		% (-1.0 if btn_n == null else btn_n.modulate.a))
	_check(btn_s != null and btn_s.modulate.a < 1.0,
		"...and dims the others (S a=%.2f)"
		% (-1.0 if btn_s == null else btn_s.modulate.a))

	var btn_h: Button = _hud.get_node_or_null("TopBar/Row/BtnViewH")
	_hud_controller.set_view_mode_active("heat", true)
	_check(btn_h != null and btn_h.button_pressed
			and is_equal_approx(btn_h.modulate.a, 1.0),
		"set_view_mode_active(\"heat\", true) presses and lights H")
	_hud_controller.set_view_mode_active("heat", false)
	_check(btn_h != null and not btn_h.button_pressed,
		"...and releases it again")

	var pad: Control = _hud.get_node_or_null("PerspectivePad")
	_hud_controller.set_perspective_pad_visible(false)
	_check(pad != null and not pad.visible, "set_perspective_pad_visible(false)")
	_hud_controller.set_perspective_pad_visible(true)
	_check(pad != null and pad.visible, "set_perspective_pad_visible(true)")

	## The dev toolbar button: debug_tools_controller hands one over and must be
	## told whether it was taken, so it can drop a control nobody could reach.
	var row: Node = _hud.get_node_or_null("TopBar/Row")
	var before: int = row.get_child_count() if row else -1
	var probe := Button.new()
	probe.text = "probe"
	var accepted: bool = _hud_controller.add_toolbar_button(probe)
	_check(accepted and row != null and row.get_child_count() == before + 1,
		"add_toolbar_button() reports true and parents the button")
	_check(not _hud_controller.add_toolbar_button(null),
		"add_toolbar_button(null) reports false instead of crashing")


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("  ✓ %s" % what)
	else:
		_failed += 1
		print("  ✗ %s" % what)


func _fail(what: String) -> void:
	_check(false, what)


func _finish() -> void:
	## The leak gate fails the suite on a surviving object, so the scene and the
	## controller are torn down here rather than left to the quitting tree.
	if _hud_controller and is_instance_valid(_hud_controller):
		_hud_controller.free()
	if _hud and is_instance_valid(_hud):
		_hud.free()

	print("\n" + "=".repeat(70))
	if _failed == 0:
		print("UI-SPLIT-02 SELFTEST PASS — %d checks" % _passed)
	else:
		print("UI-SPLIT-02 SELFTEST FAIL — %d of %d checks failed"
			% [_failed, _passed + _failed])
	print("=".repeat(70))
	get_tree().quit(0 if _failed == 0 else 1)
