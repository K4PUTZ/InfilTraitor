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
const GroundGridRef = preload("res://godot/scripts/geometry/ground_grid.gd")  ## R3D-5a: the cell lattice, no TileMapLayer

## Preload ExposureSystem script to access visibility class constants (rename to avoid shadowing)
const EXPOSURE_SYSTEM_CLASS = preload("res://godot/scripts/systems/lighting/exposure_system.gd")

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
		EXPOSURE_SYSTEM_CLASS.FULL_LIT: Color(1.0, 1.0, 0.0, 0.6),      # Yellow: high risk
		EXPOSURE_SYSTEM_CLASS.DIM: Color(1.0, 0.6, 0.0, 0.6),           # Orange: moderate risk
		EXPOSURE_SYSTEM_CLASS.PENUMBRA: Color(0.3, 0.7, 1.0, 0.6),      # Blue: low risk
		EXPOSURE_SYSTEM_CLASS.SHADOW: Color(0.8, 0.4, 1.0, 0.6),        # Purple: minimal risk
		EXPOSURE_SYSTEM_CLASS.DEEP_SHADOW: Color(0.1, 0.1, 0.3, 0.6),   # Dark blue: hidden
		EXPOSURE_SYSTEM_CLASS.OCCLUDED_VOID: Color(0.02, 0.02, 0.05, 0.7), # Near-black: sealed niche
	}

## ============================================================================
## Control Interface
## ============================================================================

func set_dev_vision(enabled: bool) -> void:
	visible = enabled


## ============================================================================
## Visualization
## ============================================================================

## RENDER3D R3D-5b, the dev overlays (2026-10-02): when a 3D board is set this overlay's drawing goes to a `GroundCanvas3D`
## (the same calls, on the ground plane, depth-tested) instead of the 2D canvas, so under a camera yaw it stays on its cells.
const GroundCanvas3DRef = preload("res://godot/scripts/geometry/ground_canvas3d.gd")
var _ground: RefCounted = null
var _c: Object = self  ## where the draw calls go: this node, or `_ground` while a 3D board is set


func set_board3d(board: Node3D) -> void:
	if _ground != null:
		_ground.detach()
		_ground = null
	if board == null:
		queue_redraw()
		return
	_ground = GroundCanvas3DRef.new()
	_ground.attach(board, 7, 0.016, false)
	_ground.follow_visibility_of(self)
	queue_redraw()


func _draw() -> void:
	if _ground == null:
		_c = self
		_draw_into()
		return
	_c = _ground
	_ground.begin(self)
	_draw_into()
	_ground.end()
	_c = self


func _draw_into() -> void:
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

	var half_w = tile_size.x * 0.5
	var half_h = tile_size.y * 0.5
	var points = PackedVector2Array([
		screen_pos + Vector2(half_w, 0.0),
		screen_pos + Vector2(0.0, half_h),
		screen_pos + Vector2(-half_w, 0.0),
		screen_pos + Vector2(0.0, -half_h),
	])
	_c.draw_colored_polygon(points, color)
	
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
	_c.draw_string(_label_font, label_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.BLACK)
	_c.draw_string(_label_font, label_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)

## Convert grid cell to screen position (dimetric projection).
func _cell_to_screen(cell: Vector2i) -> Vector2:
	return GroundGridRef.map_to_local(cell) + Vector2(0.0, 64.0) + visual_offset

## ============================================================================
## Debugging
## ============================================================================

func _to_string() -> String:
	if exposure_system:
		var stats = exposure_system.get_exposure_stats()
		return "ExposureOverlay: [visible=%s labels=%s stats=%s]" % [visible, _show_labels, stats]
	return "ExposureOverlay: [no exposure system]"
