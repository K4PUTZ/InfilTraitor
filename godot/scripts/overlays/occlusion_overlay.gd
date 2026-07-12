## Occlusion Overlay — DEV visualization of occluded geometry
##
## Displays: voxel cells that occlude the agent, color-coded by ring distance.
## This is the only visual output of OCC-01 (geometry computation).

extends Node2D

const OcclusionSetClass = preload("res://godot/scripts/systems/occlusion_set.gd")
const GeometryCoords = preload("res://godot/scripts/geometry/geometry_coords.gd")

## References
var occlusion_set: OcclusionSetClass = null
var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO

## Voxel tile dimensions (must match tileset_voxels)
var voxel_tile_size: Vector2 = Vector2(32, 16)

## Color palette for occlusion rings
var ring_colors := {
	0: Color(1.0, 0.0, 0.0, 0.5),   # Red — ring 0 (nearest, most transparent)
	1: Color(1.0, 0.5, 0.0, 0.5),   # Orange — ring 1 (middle)
	2: Color(1.0, 1.0, 0.0, 0.5),   # Yellow — ring 2 (outer, least transparent)
}

## ============================================================================
## Lifecycle
## ============================================================================

func _ready() -> void:
	set_visibility_layer(20)  # Same layer as other debug overlays

func _process(_delta: float) -> void:
	if visible and occlusion_set != null:
		queue_redraw()

## ============================================================================
## Control Interface
## ============================================================================

func set_occlusion_set(occ_set: OcclusionSetClass) -> void:
	occlusion_set = occ_set

func set_floor_layer(layer: TileMapLayer) -> void:
	floor_layer = layer

func set_visual_offset(offset: Vector2) -> void:
	visual_offset = offset

## ============================================================================
## Visualization
## ============================================================================

func _draw() -> void:
	if occlusion_set == null or occlusion_set.get_occluded_cells().is_empty():
		return
	
	# Draw each occluded voxel cell as a diamond, colored by ring
	var occluded_cells := occlusion_set.get_occluded_cells()
	for voxel_cell in occluded_cells.keys():
		var ring_index: int = occluded_cells[voxel_cell]
		var color = ring_colors.get(ring_index, Color.WHITE)
		_draw_voxel_cell(voxel_cell, color)
	
	# Draw stats in corner
	_draw_stats()

## Draw a single voxel cell as a diamond in isometric space
func _draw_voxel_cell(voxel_cell: Vector2i, color: Color) -> void:
	var screen_pos = _voxel_to_screen(voxel_cell)
	var half_w = voxel_tile_size.x * 0.5
	var half_h = voxel_tile_size.y * 0.5
	
	var points = PackedVector2Array([
		screen_pos + Vector2(half_w, 0.0),
		screen_pos + Vector2(0.0, half_h),
		screen_pos + Vector2(-half_w, 0.0),
		screen_pos + Vector2(0.0, -half_h),
	])
	draw_colored_polygon(points, color)

## Draw statistics text in the corner
func _draw_stats() -> void:
	if occlusion_set == null:
		return
	
	var occluded_cells := occlusion_set.get_occluded_cells()
	var ring_counts := [0, 0, 0]
	for cell in occluded_cells.values():
		if cell >= 0 and cell <= 2:
			ring_counts[cell] += 1
	
	var stats_text = "Occlusion: %d cells\nR0:%d R1:%d R2:%d (cnt:%d)" % [
		occluded_cells.size(),
		ring_counts[0], ring_counts[1], ring_counts[2],
		occlusion_set.get_recompute_count()
	]
	
	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, 80),
		stats_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		ThemeDB.fallback_font_size,
		Color.WHITE
	)

## ============================================================================
## Coordinate Conversion
## ============================================================================

## Convert voxel grid cell to screen position (isometric projection)
## Voxel coordinates use standard isometric: screen-y ∝ (x + y)
func _voxel_to_screen(voxel_cell: Vector2i) -> Vector2:
	var x = float(voxel_cell.x)
	var y = float(voxel_cell.y)
	var screen_x = (x - y) * voxel_tile_size.x * 0.5
	var screen_y = (x + y) * voxel_tile_size.y * 0.5
	return Vector2(screen_x, screen_y) + visual_offset
