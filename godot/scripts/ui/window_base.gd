## PANEL-01: Base class for all windows (panels with close semantics).
## Extends PanelBase with close_requested signal and pause handling.
class_name WindowBase

extends "res://godot/scripts/ui/panel_base.gd"

signal close_requested

@export var pausable: bool = false


func _ready() -> void:
	super._ready()
	
	# Configure process mode for pause-aware windows
	if pausable:
		process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	else:
		process_mode = Node.PROCESS_MODE_INHERIT


func request_close() -> void:
	close()
	close_requested.emit()
