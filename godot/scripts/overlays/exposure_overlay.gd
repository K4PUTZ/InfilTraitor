## ExposureOverlay — Tactical Visibility Classification Visualization
##
## Displays the semantic stealth visibility of each tile as computed by
## ExposureSystem. This overlay shows tactical exposure, NOT visual brightness.
##
## Colors represent stealth risk:
## - Yellow: FULL_LIT (high risk)
## - Orange: DIM (moderate risk)
## - Blue: PENUMBRA (low risk)
## - Purple: SHADOW (minimal risk)
## - Dark Blue/Black: DEEP_SHADOW (hidden)

extends Node2D

## Preload ExposureSystem to access visibility class constants
var ExposureSystem = preload("res://godot/scripts/systems/lighting/exposure_system.gd")

## References
var exposure_system
var tile_size: Vector2 = Vector2(256, 128)
var visual_offset: Vector2 = Vector2.ZERO

## Display options
var _show_labels: bool = false
var _label_font: Font = null

## Tactical color palette (stealth semantics, not visual brightness)
## Maps ExposureSystem visibility classes to colors
var _exposure_colors := {}

## ============================================================================
## Lifecycle
## ============================================================================

func _ready() -> void:
	_label_font = ThemeDB.fallback_font
	set_visibility_layer(20)
	_initialize_color_map()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

## ============================================================================
## Initialization
## ============================================================================

func _initialize_color_map() -> void:
	## Map ExposureSystem visibility classes to tactical colors
	_exposure_colors = {
		ExposureSystem.FULL_LIT: Color(1.0, 1.0, 0.0, 0.6),      # Yellow: high risk
		ExposureSystem.DIM: Color(1.0, 0.6, 0.0, 0.6),           # Orange: moderate risk
		ExposureSystem.PENUMBRA: Color(0.3, 0.7, 1.0, 0.6),      # Blue: low risk
		ExposureSystem.SHADOW: Color(0.8, 0.4, 1.0, 0.6),        # Purple: minimal risk
		ExposureSystem.DEEP_SHADOW: Color(0.1, 0.1, 0.3, 0.6),   # Dark blue: hidden
		ExposureSystem.OCCLUDED_VOID: Color(0.02, 0.02, 0.05, 0.7), # Near-black: sealed niche
	}

## ============================================================================
## Control Interface
## ============================================================================

func set_dev_vision(enabled: bool) -> void:
	visible = enabled

func set_show_labels(show_labels: bool) -> void:
	_show_labels = show_labels
	queue_redraw()

## ============================================================================
## Visualization
## ============================================================================

func _draw() -> void:
	if not exposure_system:
		return
	
	# Iterate over all tiles in exposure grid
	var _stats = exposure_system.get_exposure_stats()
	
	# Draw each tile by visibility class
	for vis_class in _exposure_colors.keys():
		var tiles = exposure_system.get_tiles_by_class(vis_class)
		for cell in tiles:
			_draw_exposure_tile(cell, vis_class)

## Draw a single tile with its exposure class color.
func _draw_exposure_tile(cell: Vector2i, vis_class: int) -> void:
	var screen_pos = _cell_to_screen(cell)
	## Only draw if we have a color mapping for this class
	if not vis_class in _exposure_colors:
		return
	var color = _exposure_colors[vis_class]
	
	# Draw filled rectangle (dimetric tile shape approximation)
	# Use draw_rect for simplicity (no invalid polygon issues)
	var rect = Rect2(screen_pos, tile_size)
	draw_rect(rect, color)
	
	# Optional: Draw label with semantic name
	if _show_labels:
		_draw_label(cell, vis_class)

## Draw semantic label (FULL_LIT, DIM, etc.)
func _draw_label(cell: Vector2i, _vis_class: int) -> void:
	if not _label_font or not exposure_system:
		return
	
	var screen_pos = _cell_to_screen(cell)
	var label_text = exposure_system.get_exposure_label(cell)
	
	# Position label in center of tile
	var label_pos = screen_pos + tile_size / 4
	
	# Draw with outline for readability
	draw_string(_label_font, label_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.BLACK)
	draw_string(_label_font, label_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)

## Convert grid cell to screen position (dimetric projection).
func _cell_to_screen(cell: Vector2i) -> Vector2:
	# Isometric projection: (x, y) -> (x * tile_width/2 - y * tile_width/2, x * tile_height/2 + y * tile_height/2)
	var x = float(cell.x)
	var y = float(cell.y)
	var screen_x = (x - y) * tile_size.x * 0.5
	var screen_y = (x + y) * tile_size.y * 0.5
	return Vector2(screen_x, screen_y) + visual_offset

## ============================================================================
## Debugging
## ============================================================================

func _to_string() -> String:
	if exposure_system:
		var stats = exposure_system.get_exposure_stats()
		return "ExposureOverlay: [visible=%s labels=%s stats=%s]" % [visible, _show_labels, stats]
	return "ExposureOverlay: [no exposure system]"
