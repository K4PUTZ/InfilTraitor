extends Node2D
## GU-GRID-01: always-visible outline of each GU's floor footprint.
## Restores the grid reference the legacy floor art used to bake into its own
## texture, lost when the earth-voxel Slab floor (DESTRUCTION_MASTER_PLAN
## D2/D4) started painting over it.
##
## Deliberately NOT reusing VoxelRulerOverlay's (F3 debug ruler) per-voxel line
## family filtered down to boundary-only lines — those lines are parametrized
## per voxel column/row and, taken only at the two extreme indices, do not
## actually close into one rhombus per GU (confirmed visually 2026-07-22: the
## result showed extra lines crossing through the middle of each GU instead of
## a clean border). Uses the same 4-point diamond selection_overlay.gd already
## draws correctly instead: map_to_local() returns the diamond's TOP vertex
## directly, so the other 3 corners are a fixed offset away — no re-derivation
## of the isometric projection needed.
class_name GuGridOverlay

## Floor tile 256×128 → half-width 128, half-height 64 (Transform Canon).
const COLOR_BLACK := Color(0.0, 0.0, 0.0, 0.35)
const LINE_WIDTH := 1.5

var _floor_layer: TileMapLayer = null
var _visual_grid_offset: Vector2 = Vector2.ZERO
var _room_size: Vector2i = Vector2i.ZERO


func setup(floor_layer: TileMapLayer, visual_grid_offset: Vector2) -> void:
	_floor_layer = floor_layer
	_visual_grid_offset = visual_grid_offset


## Called whenever room_size can have changed (real map load or a
## perspective/rotation rebuild) — see room.gd's _refresh_gu_grid_overlay().
func set_room_size(room_size: Vector2i) -> void:
	_room_size = room_size
	queue_redraw()


func _draw() -> void:
	if _floor_layer == null or _room_size == Vector2i.ZERO:
		return
	for gu_x in range(_room_size.x):
		for gu_y in range(_room_size.y):
			_draw_gu_outline(Vector2i(gu_x, gu_y))


func _draw_gu_outline(cell: Vector2i) -> void:
	var top := _floor_layer.map_to_local(cell) + _visual_grid_offset
	var right := top + Vector2(128.0, 64.0)
	var bottom := top + Vector2(0.0, 128.0)
	var left := top + Vector2(-128.0, 64.0)

	draw_line(top, right, COLOR_BLACK, LINE_WIDTH)
	draw_line(right, bottom, COLOR_BLACK, LINE_WIDTH)
	draw_line(bottom, left, COLOR_BLACK, LINE_WIDTH)
	draw_line(left, top, COLOR_BLACK, LINE_WIDTH)
