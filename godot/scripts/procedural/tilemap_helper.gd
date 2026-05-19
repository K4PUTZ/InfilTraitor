class_name TileMapHelper
extends RefCounted
## Utility functions for isometric TileMapLayer operations.
##
## Provides: directional tile selection, coordinate conversion,
## neighbour queries, and cover-facing logic for the procedural generator.


## Return the correct directional variant for a tile based on facing.
## facing: 0=N  1=E  2=S  3=W
static func tile_dir(base: String, facing: int) -> String:
	const DIRS := ["N", "E", "S", "W"]
	return "%s_%s" % [base, DIRS[facing % 4]]


## Convert a TileMap cell coord to isometric world position (diamond-down).
static func cell_to_world(cell: Vector2i, tile_size: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * tile_size.x / 2.0,
		(cell.x + cell.y) * tile_size.y / 2.0
	)


## Return the 4 orthogonal neighbours of a cell (N, E, S, W order).
static func neighbours(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i( 0, -1),  # N
		cell + Vector2i( 1,  0),  # E
		cell + Vector2i( 0,  1),  # S
		cell + Vector2i(-1,  0),  # W
	]


## Return the wall-facing direction index when looking FROM outside TOWARD cell.
## Used to pick block_N/S/E/W facing the correct way on room perimeters.
static func wall_facing(cell: Vector2i, room_interior_center: Vector2i) -> int:
	var dx := cell.x - room_interior_center.x
	var dy := cell.y - room_interior_center.y
	if abs(dx) >= abs(dy):
		return 1 if dx > 0 else 3  # E or W
	return 2 if dy > 0 else 0      # S or N
