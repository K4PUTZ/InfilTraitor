extends "res://godot/scripts/ui/panel_base.gd"
## TopBarPanel — Persistent HUD panel for game controls (buttons, AP/alert labels)
##
## Wraps TopBar from room.tscn hierarchy, providing PanelBase interface while
## maintaining compatibility with HudController's internal node references.
##
## This panel is ALWAYS open (never closed by user), but extends PanelBase for
## architectural consistency and potential future dismissible variants.

class_name TopBarPanel

# All child references pulled from room.tscn structure
var btn_end_turn: Button
var btn_reset: Button
var btn_fullscreen: Button
var btn_viewport: Button
var btn_numbers: Button
var chk_auto_end_turn: CheckBox
var lbl_ap: Label
var lbl_alert: Label
var lbl_end_turn: Label


func _ready() -> void:
	# Find child nodes by looking through the scene tree
	# Assuming structure: TopBarPanel/Row/BtnNumbers, etc.
	_find_children()
	
	# This panel is always open by default
	open()


func _find_children() -> void:
	## Locates all child nodes by name (matching room.tscn structure)
	var root = find_child("Row", false, false)
	if root:
		btn_numbers = root.find_child("BtnNumbers", false, false)
		btn_fullscreen = root.find_child("BtnFullscreen", false, false)
		btn_viewport = root.find_child("BtnViewport", false, false)
		btn_reset = root.find_child("BtnReset", false, false)
		lbl_ap = root.find_child("LblAp", false, false)
		lbl_alert = root.find_child("LblAlert", false, false)
		
		btn_end_turn = root.find_child("BtnEndTurn", false, false)
		if btn_end_turn:
			var content = btn_end_turn.find_child("Content", false, false)
			if content:
				chk_auto_end_turn = content.find_child("ChkAutoEndTurn", false, false)
				lbl_end_turn = content.find_child("LblEndTurn", false, false)


func open() -> void:
	## Override: TopBar is always visible (persistent HUD)
	if not _is_open:
		visible = true
		_is_open = true
		opened.emit()


func close() -> void:
	## Override: TopBar remains visible even when "closed" (persistent HUD)
	## This method exists for API consistency but does nothing.
	pass
