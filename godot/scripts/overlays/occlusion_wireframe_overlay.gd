## Occlusion Wireframe Overlay — OCC-07
##
## Draws a crisp white outline over each occluded Slice, reproducing that slice's own
## real 2.5D panel shape (top edge, two verticals, bottom edge) — not a generic box.
## VoxelRenderer.apply_occlusion() still hides the geometry (a single flat, low-alpha
## ghost — see HIDDEN_ALT_ID); this overlay is what tells the player a wall is there.
##
## OCC-07 replaced the previous per-gameplay-cell box-with-suppressed-edges approach.
## That version aggregated many voxel columns into a generic diamond box per cell and
## had to reverse-engineer which edges were "interior" via neighbour lookups — fragile,
## and it still didn't match a wall's actual thin shape. A Slice already IS the shape:
## one face, one gameplay cell, real voxels. There is nothing left to aggregate or
## suppress — each occluded slice draws its own rectangle, independently, using its
## own voxels' real grid positions for both corners and height.

extends Node2D

const OcclusionSetClass = preload("res://godot/scripts/systems/occlusion_set.gd")

var occlusion_set: OcclusionSetClass = null
var voxel_renderer = null

const LINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const LINE_WIDTH := 2.0


func _ready() -> void:
	set_visibility_layer(20)

## No _process(): same cadence discipline as OcclusionOverlay (OCC-FIX-02) — the occluded
## set only changes on map load, agent step and view change, and room.gd already calls
## queue_redraw() on all occlusion visuals at each of those.


func set_occlusion_set(occ_set: OcclusionSetClass) -> void:
	occlusion_set = occ_set


func set_voxel_renderer(renderer) -> void:
	voxel_renderer = renderer


func _draw() -> void:
	if occlusion_set == null or voxel_renderer == null:
		return
	for slice in occlusion_set.get_occluded_slices():
		_draw_slice_outline(slice)


## A slice is thin along one grid axis and spans ~8 voxels along the other (it is one
## face of one gameplay cell) — so its own voxels' bounding min/max corners ARE its two
## real footprint endpoints, not an approximation. Height comes from the same voxels'
## actual level range, not an assumed 0-to-top span, so a slice that starts above the
## ground (start_storey > 0) outlines correctly instead of reaching down to the floor.
func _draw_slice_outline(slice) -> void:
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

	var bottom_a := _voxel_to_screen(corner_a, min_level)
	var bottom_b := _voxel_to_screen(corner_b, min_level)
	var top_a := _voxel_to_screen(corner_a, max_level + 1)
	var top_b := _voxel_to_screen(corner_b, max_level + 1)

	_draw_line(top_a, top_b)         ## top edge
	_draw_line(bottom_a, bottom_b)   ## bottom edge
	_draw_line(top_a, bottom_a)      ## left vertical
	_draw_line(top_b, bottom_b)      ## right vertical


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


func _draw_line(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, LINE_COLOR, LINE_WIDTH, true)
