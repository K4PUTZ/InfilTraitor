extends Node2D
## DEBUG-02: Voxel-resolution ruler grid overlay
## Draws independent grid at 8×8 voxel resolution (32×16 per tile)
## computed from canonical floor frame only — zero dependency on VoxelRenderer.
## Toggled F3, z_index above walls for visibility.

class_name VoxelRulerOverlay

## Voxel tile dimensions (from Transform Canon)
const VOXEL_TILE_SIZE := Vector2i(32, 16)

## Floor tile dimensions (for subdivision calculation)
const FLOOR_TILE_SIZE := Vector2i(256, 128)

## Voxels per GU axis (8×8 voxels per GU)
const VOXELS_PER_AXIS := 8

## Line colors
const VOXEL_LINE_COLOR := Color(0.0, 1.0, 1.0, 0.25)  ## Cyan, 25% alpha
const GU_LINE_COLOR := Color(0.0, 1.0, 1.0, 0.5)      ## Cyan, 50% alpha (brighter)

## Line widths (pixels)
const VOXEL_LINE_WIDTH := 0.5
const GU_LINE_WIDTH := 1.0

## References to canonical frame
var _floor_layer: TileMapLayer = null
var _visual_grid_offset: Vector2 = Vector2.ZERO
var _room_size: Vector2i = Vector2i(18, 36)  ## Default PLAYGROUND size

## Visible flag
var visible_grid: bool = false


func setup(floor_layer: TileMapLayer, visual_grid_offset: Vector2, room_size: Vector2i) -> void:
	_floor_layer = floor_layer
	_visual_grid_offset = visual_grid_offset
	_room_size = room_size
	z_index = 100  ## Above walls, below HUD


func _draw() -> void:
	if not visible_grid or _floor_layer == null:
		return

	## Compute grid bounds: playable area + one-tile buffer margin
	var min_gu := Vector2i(-1, -1)
	var max_gu := _room_size + Vector2i(1, 1)

	## Draw voxel grid (8×8 per GU)
	for gu_x in range(min_gu.x, max_gu.x + 1):
		for gu_y in range(min_gu.y, max_gu.y + 1):
			_draw_gu_voxel_grid(gu_x, gu_y)


## Draw 8×8 voxel grid for one GU cell
func _draw_gu_voxel_grid(gu_x: int, gu_y: int) -> void:
	var gu_cell := Vector2i(gu_x, gu_y)

	## Get the canonical GU center in world space
	var floor_origin := _floor_layer.map_to_local(gu_cell)
	var floor_half := Vector2(FLOOR_TILE_SIZE) / 2.0

	## Canonical GU NW corner (top of diamond) in world space
	var canon_nw := floor_origin - floor_half + _visual_grid_offset

	## Isometric tile map_to_local formula for DIAMOND_DOWN:
	## For a voxel at (vx, vy), its position relative to GU origin (gu_x*8, gu_y*8) is:
	## screen_offset = (vx - vy) * (tile_width/2, tile_height/2) + (vy + vx) * (tile_width/2, -tile_height/2)
	##               = ((vx - vy) * 16, (vx - vy) * 8 + (vy + vx) * (-8))
	##               = ((vx - vy) * 16, (vx - vy - vy - vx) * 8)
	##               = ((vx - vy) * 16, -2*vy * 8)

	## Simpler: in isometric DIAMOND_DOWN, moving one step in voxel_x adds (16, -8) to screen
	## and moving one step in voxel_y adds (-16, -8) to screen (both downward Y).
	## Wait, let me reconsider with the actual tile_size (32, 16):
	## Moving (1, 0) in grid → screen moves by (16, 8) — right and down
	## Moving (0, 1) in grid → screen moves by (-16, 8) — left and down

	## Draw constant-voxel_x lines (these go diagonally SW as voxel_y increases)
	for vx in range(VOXELS_PER_AXIS + 1):
		var voxel_x_screen := float(vx) * 16.0  ## Each voxel_x step = 16 px right
		var p1 := canon_nw + Vector2(voxel_x_screen, 0.0)
		var p2 := canon_nw + Vector2(voxel_x_screen - float(VOXELS_PER_AXIS) * 16.0,
									  float(VOXELS_PER_AXIS) * 8.0)

		var is_gu_boundary := (vx == 0 or vx == VOXELS_PER_AXIS)
		var color := GU_LINE_COLOR if is_gu_boundary else VOXEL_LINE_COLOR
		var width := GU_LINE_WIDTH if is_gu_boundary else VOXEL_LINE_WIDTH

		draw_line(p1, p2, color, width)

	## Draw constant-voxel_y lines (these go diagonally SE as voxel_x increases)
	for vy in range(VOXELS_PER_AXIS + 1):
		var p1 := canon_nw + Vector2(-float(vy) * 16.0, float(vy) * 8.0)
		var p2 := canon_nw + Vector2(-float(vy) * 16.0 + float(VOXELS_PER_AXIS) * 16.0,
									  float(vy) * 8.0 + float(VOXELS_PER_AXIS) * 8.0)

		var is_gu_boundary := (vy == 0 or vy == VOXELS_PER_AXIS)
		var color := GU_LINE_COLOR if is_gu_boundary else VOXEL_LINE_COLOR
		var width := GU_LINE_WIDTH if is_gu_boundary else VOXEL_LINE_WIDTH

		draw_line(p1, p2, color, width)
