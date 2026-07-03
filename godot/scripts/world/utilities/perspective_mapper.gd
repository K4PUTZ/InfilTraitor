## Perspective Mapper: static utility for isometric perspective transformations.
## Handles direction-based cell coordinate conversions and tile name suffix remapping.
## Extracted from room.gd (Task 04 modularization).
class_name PerspectiveMapper


## Suffix remapping for tile names across the 4 compass directions.
## E.g., tile_name "wall_NE" becomes "wall_SE" when viewed from East (E).
const SUFFIX_MAP := {
	"N": {"NE": "NE", "SE": "SE", "SW": "SW", "NW": "NW"},
	"E": {"NE": "SE", "SE": "SW", "SW": "NW", "NW": "NE"},
	"S": {"NE": "SW", "SE": "NW", "SW": "NE", "NW": "SE"},
	"W": {"NE": "NW", "SE": "NE", "SW": "SE", "NW": "SW"},
}


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


## Remap tile suffix from base (N) to target direction.
## Parses tile_name as "base_SUFFIX" and replaces SUFFIX per SUFFIX_MAP[direction].
## Returns unchanged name if not recognized.
static func remap_tile_name(tile_name: String, direction: String) -> String:
	if tile_name.is_empty():
		return tile_name
	
	var i := tile_name.rfind("_")
	if i < 0:
		return tile_name
	
	var base := tile_name.substr(0, i)
	var suffix := tile_name.substr(i + 1)
	
	if not SUFFIX_MAP.has(direction):
		return tile_name
	
	var suffix_map: Dictionary = SUFFIX_MAP[direction]
	if not suffix_map.has(suffix):
		return tile_name
	
	return "%s_%s" % [base, String(suffix_map[suffix])]


## Query whether direction is valid (in SUFFIX_MAP).
static func is_valid_direction(direction: String) -> bool:
	return SUFFIX_MAP.has(direction)
