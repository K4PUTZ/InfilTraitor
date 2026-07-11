## PANEL-01: Base class for all panels and windows.
## Provides open/close state management and signal hooks.
## Background slot (background child) is designed to be replaced by TextureRect/AnimatedSprite2D later.
class_name PanelBase extends Control

signal opened
signal closed

@export var title: String = ""

var _is_open: bool = false


func _ready() -> void:
	# Ensure background slot exists (default ColorRect for now)
	if not has_node("background"):
		var bg := ColorRect.new()
		bg.name = "background"
		add_child(bg)
		move_child(bg, 0)  # First child, so title/content overlay it
		bg.color = Color(0.1, 0.1, 0.1, 0.95)
	
	var background = get_node("background")
	if background:
		# Fill the panel with background
		background.anchor_left = 0.0
		background.anchor_top = 0.0
		background.anchor_right = 1.0
		background.anchor_bottom = 1.0
		background.offset_left = 0.0
		background.offset_right = 0.0
		background.offset_top = 0.0
		background.offset_bottom = 0.0
	
	# Start hidden
	visible = false
	_is_open = false


func open() -> void:
	"""Open the panel: set visible and emit signal."""
	visible = true
	_is_open = true
	opened.emit()


func close() -> void:
	"""Close the panel: hide and emit signal."""
	visible = false
	_is_open = false
	closed.emit()


func is_open() -> bool:
	"""Return whether the panel is currently open."""
	return _is_open
