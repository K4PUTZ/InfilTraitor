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

## References
var exposure_system
var tile_size: Vector2 = Vector2(256, 128)
var visual_offset: Vector2 = Vector2.ZERO

## Display options
var _show_labels: bool = false
var _label_font: Font = null

## Tactical color palette (stealth semantics, not visual brightness)
var _exposure_colors := {
	4: Color(1.0, 1.0, 0.0, 0.6),      # FULL_LIT: Bright yellow (high risk)
	3: Color(1.0, 0.6, 0.0, 0.6),      # DIM: Orange (moderate risk)
	2: Color(0.3, 0.7, 1.0, 0.6),      # PENUMBRA: Blue (low risk)
	1: Color(0.8, 0.4, 1.0, 0.6),      # SHADOW: Purple (minimal risk)
	0: Color(0.1, 0.1, 0.3, 0.6),      # DEEP_SHADOW: Dark blue (hidden)
}

## ============================================================================
## Lifecycle
## ============================================================================

func _ready() -> void:
	_label_font = ThemeDB.fallback_font
	set_visibility_layer(20)

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

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
	var color = _exposure_colors[vis_class]
	
	# Draw filled rectangle (dimetric tile shape approximation)
	# For simplicity, use a square; precise dimetric would use parallelogram
	var half_size = tile_size / 2
	draw_colored_polygon([
		screen_pos,
		screen_pos + Vector2(half_size.x, 0),
		screen_pos + half_size,
		screen_pos + Vector2(half_size.x, 0)
	], color)
	
	# Optional: Draw label with semantic name
	if _show_labels:
		_draw_label(cell, vis_class)

## Draw semantic label (FULL_LIT, DIM, etc.)
func _draw_label(cell: Vector2i, _vis_class: int) -> void:
	var screen_pos = _cell_to_screen(cell)
	var label_text = exposure_system.get_exposure_label(cell)
	
	# Position label in center of tile
	var label_pos = screen_pos + tile_size / 4
	
	# Draw with outline for readability
	draw_string(_label_font, label_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.BLACK)
	draw_string(_label_font, label_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)

## Convert grid cell to screen position (dimetric projection).
func _cell_to_screen(cell: Vector2i) -> Vector2:
	# Dimetric: 45° horizontal, 26.57° elevation
	var x_offset = float(cell.x) * tile_size.x / 2.0
	var y_offset = float(cell.y) * tile_size.y / 2.0
	var dimetric_x = x_offset - y_offset
	var dimetric_y = (x_offset + y_offset) / 2.0
	return Vector2(dimetric_x, dimetric_y) + visual_offset

## ============================================================================
## Debugging
## ============================================================================

func _to_string() -> String:
	if exposure_system:
		var stats = exposure_system.get_exposure_stats()
		return "ExposureOverlay: [visible=%s labels=%s stats=%s]" % [visible, _show_labels, stats]
	return "ExposureOverlay: [no exposure system]"
