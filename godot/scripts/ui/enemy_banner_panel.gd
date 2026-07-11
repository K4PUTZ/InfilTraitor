extends "res://godot/scripts/ui/window_base.gd"
## EnemyBannerPanel — Dismissible banner displayed during enemy turns
##
## Wraps EnemyTurnBanner from room.tscn, replacing raw visibility toggling
## with PanelBase open/close semantics. Uses WindowBase to provide close_requested
## signal support (though currently called directly from HudController).

class_name EnemyBannerPanel

var lbl_enemy_turn: Label


func _ready() -> void:
	_find_children()
	# Banner starts hidden (closed)
	close()


func _find_children() -> void:
	## Locates the enemy turn label
	lbl_enemy_turn = find_child("LblEnemyTurn", false, false)


func show_banner() -> void:
	## Thin wrapper: replaces show_enemy_banner()
	open()


func hide_banner() -> void:
	## Thin wrapper: replaces hide_enemy_banner()
	close()
