## Perspective Mapper: static utility for the four compass views' cell maps (base N <-> view).
## Extracted from room.gd (Task 04 modularization).
##
## 2026-11-11 (HERITAGE T1): the layout rotation (`layout_with_perspective`, the tile-name and face
## remaps, `rotated_size`, the light-angle delta) went: rotation is camera-only since R3D-ROT and the
## game never rotates a layout. What is left are the cell maps the blast and the occlusion still use.
class_name PerspectiveMapper


const DIRECTIONS: Array[String] = ["N", "E", "S", "W"]


## Convert a view-space cell to base (North) orientation.
## Applies rotation based on direction:
##   "N" (North): identity
##   "E" (East): 90° CW → (y, h-1-x)
##   "S" (South): 180° → (w-1-x, h-1-y)
##   "W" (West): 270° CW → (w-1-y, x)
static func cell_to_base(view_cell: Vector2i, direction: String, base_size: Vector2i) -> Vector2i:
	if view_cell == Vector2i(-1, -1):  # INVALID_CELL
		return Vector2i(-1, -1)
	
	var w := base_size.x
	var h := base_size.y
	
	match direction:
		"E":
			return Vector2i(view_cell.y, h - 1 - view_cell.x)
		"S":
			return Vector2i(w - 1 - view_cell.x, h - 1 - view_cell.y)
		"W":
			return Vector2i(w - 1 - view_cell.y, view_cell.x)
		_:
			return view_cell


## `cell_from_base()` without the INVALID_CELL sentinel: pure arithmetic, so a REAL cell at (-1, -1) (the map's buffer puts
## voxel columns at negative coordinates) turns like any other. For code that turns coordinates it did not get from `Room`.
static func turn_from_base(base_cell: Vector2i, direction: String, base_size: Vector2i) -> Vector2i:
	var w := base_size.x
	var h := base_size.y
	match direction:
		"E":
			return Vector2i(h - 1 - base_cell.y, base_cell.x)
		"S":
			return Vector2i(w - 1 - base_cell.x, h - 1 - base_cell.y)
		"W":
			return Vector2i(base_cell.y, w - 1 - base_cell.x)
		_:
			return base_cell


## Query whether direction is one of the four views.
static func is_valid_direction(direction: String) -> bool:
	return DIRECTIONS.has(direction)


## Convert a base (North) cell to view-space, given the active direction.
## Inverse of cell_to_base — see that function's docstring for the rotation
## table. INVALID_CELL is the room.gd sentinel Vector2i(-1, -1).
static func cell_from_base(base_cell: Vector2i, direction: String, base_size: Vector2i) -> Vector2i:
	if base_cell == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var w := base_size.x
	var h := base_size.y
	match direction:
		"E":
			return Vector2i(h - 1 - base_cell.y, base_cell.x)
		"S":
			return Vector2i(w - 1 - base_cell.x, h - 1 - base_cell.y)
		"W":
			return Vector2i(base_cell.y, w - 1 - base_cell.x)
		_:
			return base_cell
