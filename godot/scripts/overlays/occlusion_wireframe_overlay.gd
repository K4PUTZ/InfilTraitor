## Occlusion Wireframe Overlay — OCC-07-b
##
## Draws a crisp white outline over each occluded Slice, reproducing that slice's own
## real 2.5D panel shape (top edge, two verticals, bottom edge) — not a generic box.
## VoxelRenderer.apply_occlusion() still hides the geometry (a single flat, low-alpha
## ghost — see HIDDEN_ALT_ID); this overlay is what tells the player a wall is there.
##
## OCC-07-b (2026-07-14): no longer a single Node2D drawing at one flat elevated
## z_index (150). That always won against nearer, unoccluded geometry that should
## have covered part of it — e.g. a ghosted back wall's outline showing straight
## through the box's own solid front walls, which are unaffected and nearer the
## camera. Director's fix: each wireframe segment must carry the z_index of the
## voxel layer whose slice it stands in for, not a value picked to "clear everything".
##
## Levels, not one shape: this manager splits each slice's rectangle into one
## horizontal band per voxel LEVEL it spans, and spawns one OcclusionSlicePanel
## child per band, each stamped with THAT level's real voxel-layer z_index (read
## directly off VoxelRenderer.get_layer(level), the same TileMapLayer the real wall
## cells are placed on — never re-derived). A single flat rectangle could only ever
## carry one z_index, which would still be wrong for any level range it didn't
## match; per-level bands is what lets a tall slice interleave correctly against
## blockers that only exist at some of its levels.

extends Node2D

const OcclusionSetClass = preload("res://godot/scripts/systems/occlusion_set.gd")
const SlicePanelClass = preload("res://godot/scripts/overlays/occlusion_slice_panel.gd")

var occlusion_set: OcclusionSetClass = null
var voxel_renderer = null

var _panels: Array = []


func set_occlusion_set(occ_set: OcclusionSetClass) -> void:
	occlusion_set = occ_set


func set_voxel_renderer(renderer) -> void:
	voxel_renderer = renderer


## Called by room.gd wherever it used to call queue_redraw() on this node directly.
## Rebuilds the whole set of per-level panel children — the occluded set only
## changes on map load, agent step and view change (O1's cadence), never per frame,
## so tearing down and respawning a few dozen small nodes here is not a hot path.
func refresh() -> void:
	for panel in _panels:
		panel.queue_free()
	_panels.clear()

	if occlusion_set == null or voxel_renderer == null:
		return

	for slice in occlusion_set.get_occluded_slices():
		_spawn_slice_panels(slice)


## A slice is thin along one grid axis and spans ~8 voxels along the other (it is one
## face of one gameplay cell) — so its own voxels' bounding min/max corners ARE its two
## real footprint endpoints, not an approximation.
func _spawn_slice_panels(slice) -> void:
	if slice.voxels.is_empty():
		return

	var min_gx: int = slice.voxels[0].grid_pos.x
	var max_gx: int = min_gx
	var min_gy: int = slice.voxels[0].grid_pos.y
	var max_gy: int = min_gy
	var min_level: int = slice.voxels[0].level
	var max_level: int = min_level
	for voxel in slice.voxels:
		min_gx = mini(min_gx, voxel.grid_pos.x)
		max_gx = maxi(max_gx, voxel.grid_pos.x)
		min_gy = mini(min_gy, voxel.grid_pos.y)
		max_gy = maxi(max_gy, voxel.grid_pos.y)
		min_level = mini(min_level, voxel.level)
		max_level = maxi(max_level, voxel.level)

	var corner_a := Vector2i(min_gx, min_gy)
	var corner_b := Vector2i(max_gx, max_gy)

	## One band per level the slice actually occupies, each its own panel node at
	## that level's own z_index — see this file's header for why. Only the very top
	## and very bottom band draw their horizontal cap edge; every level boundary in
	## between is an internal seam, not a real silhouette edge — see
	## occlusion_slice_panel.gd's header for why that was producing a "venetian
	## blind" of rungs down every tall occluded span.
	for level in range(min_level, max_level + 1):
		var panel := Node2D.new()
		panel.set_script(SlicePanelClass)
		panel.bottom_a = _voxel_to_screen(corner_a, level)
		panel.bottom_b = _voxel_to_screen(corner_b, level)
		panel.top_a = _voxel_to_screen(corner_a, level + 1)
		panel.top_b = _voxel_to_screen(corner_b, level + 1)
		panel.draw_top = (level == max_level)
		panel.draw_bottom = (level == min_level)
		panel.z_index = _layer_z_index(level)
		add_child(panel)
		_panels.append(panel)


## The real z_index of the voxel layer at this level — read directly off the
## TileMapLayer the actual wall cells are placed on, never re-derived, so a panel
## always ends up in exactly the same draw bucket as its own level's geometry. Falls
## back to extrapolating one level past the last built layer (mirrors _voxel_to_screen).
func _layer_z_index(level: int) -> int:
	var layer: TileMapLayer = voxel_renderer.get_layer(level)
	if layer != null:
		return layer.z_index
	var base_layer: TileMapLayer = voxel_renderer.get_layer(0)
	if base_layer == null:
		return 0
	return base_layer.z_index + level


## Screen position of a VOXEL-grid coordinate at a given LEVEL. Same technique
## OCC-FIX-02 established for OcclusionOverlay: ask the layer that actually draws it,
## never hand-roll the isometric transform (Transform Canon has exactly one copy).
## Levels beyond what's currently built (e.g. max_level + 1 on the tallest existing
## layer) fall back to extrapolating from level 0 by VOXEL_STEP_PX per level — the
## same per-level offset every voxel layer is positioned with (see VoxelRenderer's
## _ensure_voxel_layers()), so this stays exact even one level past the last built one.
func _voxel_to_screen(voxel_cell: Vector2i, level: int) -> Vector2:
	var layer: TileMapLayer = voxel_renderer.get_layer(level)
	if layer != null:
		return layer.map_to_local(voxel_cell) + layer.position
	var base_layer: TileMapLayer = voxel_renderer.get_layer(0)
	if base_layer == null:
		return Vector2.ZERO
	var base_pos := base_layer.map_to_local(voxel_cell) + base_layer.position
	return base_pos + Vector2(0.0, -float(level) * GeometryCoords.VOXEL_STEP_PX)
