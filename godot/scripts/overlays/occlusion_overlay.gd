## Occlusion Overlay — DEV visualization of occluded geometry
##
## Displays: voxel cells that occlude the agent, color-coded by ring distance.
## This is the only visual output of OCC-01 (geometry computation).

extends Node2D

const OcclusionSetClass = preload("res://godot/scripts/systems/occlusion_set.gd")
const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")

## References
var occlusion_set: OcclusionSetClass = null
## OCC-FIX-02: the overlay asks the voxel renderer where a cell is. It does not re-derive
## the isometric transform. See _voxel_to_screen().
var voxel_renderer = null

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

## OCC-FIX-02: no _process(). This overlay used to queue_redraw() every single frame while
## visible — the exact per-frame cadence OCC-01 was written to avoid. The set only changes
## on map load, agent step and view change, and room.gd::_recompute_occlusion() already
## calls queue_redraw() on each. Redrawing between those events draws the same pixels again.

## ============================================================================
## Control Interface
## ============================================================================

func set_occlusion_set(occ_set: OcclusionSetClass) -> void:
	occlusion_set = occ_set

## OCC-FIX-02: replaces set_floor_layer()/set_visual_offset(). The overlay used to be
## handed the FLOOR layer and an offset, then hand-roll the isometric projection from
## them — but occluded cells live on the VOXEL grid (8 voxels per gameplay unit), not the
## floor grid. Two planes, one transform, wrong answer: the painted region landed on a
## different cube entirely. The renderer owns the voxel transform; ask it.
func set_voxel_renderer(renderer) -> void:
	voxel_renderer = renderer

## ============================================================================
## Visualization
## ============================================================================

func _draw() -> void:
	if occlusion_set == null or occlusion_set.get_occluded_cells().is_empty():
		return
	
	# Draw each occluded voxel cell as a diamond, colored by ring
	# OCC-09: get_occluded_cells() values are now {"ring": int, "min_level": int}
	# dicts, not a bare ring int — min_level travels with the cell so
	# VoxelRenderer can skip levels the vertical reveal cutoff excluded.
	var occluded_cells := occlusion_set.get_occluded_cells()
	for voxel_cell in occluded_cells.keys():
		var ring_index: int = occluded_cells[voxel_cell]["ring"]
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
	for entry in occluded_cells.values():
		var ring: int = entry["ring"]
		if ring >= 0 and ring <= 2:
			ring_counts[ring] += 1
	
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

## Convert a voxel-grid cell to screen position by asking the layer that actually draws it.
##
## OCC-FIX-02. This used to hand-roll the projection:
##     screen = ((x - y) * 16, (x + y) * 8) + visual_offset
## which silently re-derived the Transform Canon and got it wrong — it omits TILE_OFFSET
## (112, 64) and the layer's own texture_origin, so every painted diamond landed far from
## the cell it claimed to mark (in the capture that caught this, on a different cube
## entirely). The voxel TileMapLayer already knows where its cells are. Ask it, and there
## is only one copy of the transform in the project.
##
## Level 0 is the right layer to query: the set is over voxel COLUMNS, and column identity
## is the ground-level cell.
func _voxel_to_screen(voxel_cell: Vector2i) -> Vector2:
	if voxel_renderer == null:
		return Vector2.ZERO
	var layer: TileMapLayer = voxel_renderer.get_layer(0)
	if layer == null:
		return Vector2.ZERO
	return layer.map_to_local(voxel_cell) + layer.position
