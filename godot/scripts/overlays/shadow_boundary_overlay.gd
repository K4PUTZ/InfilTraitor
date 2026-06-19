## ShadowBoundaryOverlay — Always-visible shadow region visualization
##
## Renders two passes on shadow cells:
## 1. Semi-transparent fill (vignette effect) inside shadow tiles
## 2. Dark lines on boundaries where shadow meets non-shadow
##
## Uses pure drawing (no blend mode) so lines are not overridden by multiply blend.
## Updated whenever lighting rebuilds via set_shadow_cells().

extends Node2D

@export var tile_size: Vector2 = Vector2(128, 64)
@export var visual_offset: Vector2 = Vector2(0, 0)

var _floor_layer: TileMapLayer = null
var _full_shadow_cells: Dictionary = {}    ## Deep shadow tiles
var _lite_shadow_cells: Dictionary = {}    ## Penumbra/lite shadow tiles

## Inward offset (pixels) — shrinks losango to avoid overlapping movement perimeter
var _inset_distance: float = 6.0

## Color palette for different shadow intensities
var _full_shadow_fill: Color = Color(0.0, 0.0, 0.0, 0.40)      ## Darker fill
var _full_shadow_line: Color = Color(0.05, 0.05, 0.05, 0.95)    ## Nearly black line

var _lite_shadow_fill: Color = Color(0.2, 0.2, 0.2, 0.25)       ## Lighter fill (penumbra)
var _lite_shadow_line: Color = Color(0.15, 0.15, 0.15, 0.80)    ## Medium grey line

## Internal boundary line (between full_shadow and lite_shadow)
var _internal_boundary_line: Color = Color(0.08, 0.08, 0.08, 0.85)  ## Dark grey, intermediate

var _line_width: float = 3.5

func setup(floor_layer: TileMapLayer, offset: Vector2) -> void:
	_floor_layer = floor_layer
	visual_offset = offset

func set_full_shadow_cells(cells: Array[Vector2i]) -> void:
	_full_shadow_cells.clear()
	for cell in cells:
		_full_shadow_cells[cell] = true
	queue_redraw()

func set_lite_shadow_cells(cells: Array[Vector2i]) -> void:
	_lite_shadow_cells.clear()
	for cell in cells:
		_lite_shadow_cells[cell] = true
	queue_redraw()

func _draw() -> void:
	## Draw full shadows first (darker, behind)
	for cell in _full_shadow_cells.keys():
		_draw_shadow_tile(cell, _full_shadow_fill, _full_shadow_line)

	## Draw lite shadows second (lighter, potentially overlapping)
	for cell in _lite_shadow_cells.keys():
		_draw_shadow_tile(cell, _lite_shadow_fill, _lite_shadow_line)

	## Draw internal boundaries (full_shadow ↔ lite_shadow transitions)
	for cell in _full_shadow_cells.keys():
		_draw_internal_boundaries(cell)

func _draw_internal_boundaries(cell: Vector2i) -> void:
	var diamond := _diamond_points_inset(cell)

	## Check each edge for full_shadow → lite_shadow transitions
	var neighbors: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var edge_indices = [0, 1, 2, 3]  ## V0, V1, V2, V3

	for i in range(4):
		var neighbor := cell + neighbors[i]
		if _lite_shadow_cells.has(neighbor):
			## Draw line between full and lite shadow
			var v1 = diamond[edge_indices[i]]
			var v2 = diamond[edge_indices[(i + 1) % 4]]
			draw_line(v1, v2, _internal_boundary_line, _line_width, true)

func _draw_shadow_tile(cell: Vector2i, fill_color: Color, line_color: Color) -> void:
	var diamond := _diamond_points(cell)
	draw_colored_polygon(diamond, fill_color)
	_draw_external_boundaries(cell, line_color)

func _draw_external_boundaries(cell: Vector2i, line_color: Color) -> void:
	var diamond := _diamond_points_inset(cell)

	## Draw lines only where this shadow cell borders non-shadow (external boundary)
	var neighbors: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in range(4):
		var neighbor := cell + neighbors[i]
		if not (_full_shadow_cells.has(neighbor) or _lite_shadow_cells.has(neighbor)):
			var v1 = diamond[i]
			var v2 = diamond[(i + 1) % 4]
			draw_line(v1, v2, line_color, _line_width, true)

func _diamond_points(cell: Vector2i) -> PackedVector2Array:
	var top := _floor_layer.map_to_local(cell) + visual_offset
	return PackedVector2Array([
		top,
		top + Vector2(128.0, 64.0),
		top + Vector2(0.0, 128.0),
		top + Vector2(-128.0, 64.0),
	])

func _diamond_points_inset(cell: Vector2i) -> PackedVector2Array:
	## Shrink the diamond inward by _inset_distance to avoid overlapping movement perimeter
	var center := _floor_layer.map_to_local(cell) + visual_offset + Vector2(0.0, 64.0)

	## Scale factor: reduce diamond size by moving vertices toward center
	var scale_factor := 1.0 - (_inset_distance / 128.0)  ## Normalize to tile half-width

	var top = center + Vector2(0.0, -64.0) * scale_factor
	var right = center + Vector2(128.0, 0.0) * scale_factor
	var bottom = center + Vector2(0.0, 64.0) * scale_factor
	var left = center + Vector2(-128.0, 0.0) * scale_factor

	return PackedVector2Array([top, right, bottom, left])

func _cell_to_screen(cell: Vector2i) -> Vector2:
	return _floor_layer.map_to_local(cell) + visual_offset

