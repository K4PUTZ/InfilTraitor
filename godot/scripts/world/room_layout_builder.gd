extends RefCounted
## Builds a single segment layout for the InfilTraitor segment system.
## Segment: W=18, H=36 (W+H=54 -> 6912x3456 px screen space).
## Interior: 16x34 tiles. Border: 1 tile wide on all sides.
## Access points replace border tiles with passable floor.

const MAP_SIZE         := Vector2i(18, 36)
const AGENT_START_CELL := Vector2i(9, 34)   ## South interior centre
const FLOOR_TILE       := "floor_SE"

const CRATE_VARIANTS: Array[String] = ["crate_SE", "crate_SW", "crate_NW", "crate_NE"]
const CRATE_CELLS: Array[Vector2i] = [
	Vector2i( 4,  5),
	Vector2i(13,  5),
	Vector2i( 4, 14),
	Vector2i(13, 14),
	Vector2i( 9, 11),
	Vector2i( 5, 26),
	Vector2i(12, 26),
]

## Border cells replaced with passable floor (open passages).
const ACCESS_POINTS: Array[Dictionary] = [
	{ "cell": Vector2i(9, 35), "side": "south", "type": "main" },
	{ "cell": Vector2i(9,  0), "side": "north", "type": "main" },
]

## Interior wall cells -- horizontal barrier at y=17 with a 4-tile gap at x=7..10.
## Splits the segment into a south lobby and north target area.
const INTERIOR_WALL_CELLS: Array[Vector2i] = [
	Vector2i( 1, 17), Vector2i( 2, 17), Vector2i( 3, 17),
	Vector2i( 4, 17), Vector2i( 5, 17), Vector2i( 6, 17),
	Vector2i(11, 17), Vector2i(12, 17), Vector2i(13, 17),
	Vector2i(14, 17), Vector2i(15, 17), Vector2i(16, 17),
]


func build_layout() -> Dictionary:
	var wall_map:    Dictionary = {}   ## all solid wall cells
	var blocked_map: Dictionary = {}   ## walls + crates (agent cannot enter)
	var crate_map:   Dictionary = {}   ## cell -> tile_name for crate tiles

	_collect_border_walls(wall_map, blocked_map)
	_open_access_points(wall_map, blocked_map)
	_collect_interior_walls(wall_map, blocked_map)
	_collect_crates(crate_map, blocked_map)

	var wall_tiles: Array[Dictionary] = []
	for cell: Vector2i in wall_map.keys():
		wall_tiles.append({
			"cell": cell,
			"tile_name": _pick_wall_tile(cell, wall_map),
		})

	return {
		"size": MAP_SIZE,
		"agent_start_cell": AGENT_START_CELL,
		"floor_tile_name": FLOOR_TILE,
		"wall_tiles": wall_tiles,
		"structure_tiles": _crate_map_to_array(crate_map),
		"blocked_cells": _dict_keys_to_vec2i_array(blocked_map),
		"blocked_edges": [],
	}


## --- wall collection --------------------------------------------------------

func _collect_border_walls(wall_map: Dictionary, blocked_map: Dictionary) -> void:
	for x in range(MAP_SIZE.x):
		for y in range(MAP_SIZE.y):
			if x == 0 or x == MAP_SIZE.x - 1 or y == 0 or y == MAP_SIZE.y - 1:
				wall_map[Vector2i(x, y)] = true
				blocked_map[Vector2i(x, y)] = true


func _open_access_points(wall_map: Dictionary, blocked_map: Dictionary) -> void:
	for ap: Dictionary in ACCESS_POINTS:
		var cell: Vector2i = ap["cell"]
		wall_map.erase(cell)
		blocked_map.erase(cell)


func _collect_interior_walls(wall_map: Dictionary, blocked_map: Dictionary) -> void:
	for cell: Vector2i in INTERIOR_WALL_CELLS:
		if cell == AGENT_START_CELL:
			continue
		wall_map[cell] = true
		blocked_map[cell] = true


func _collect_crates(crate_map: Dictionary, blocked_map: Dictionary) -> void:
	for i in range(CRATE_CELLS.size()):
		var cell: Vector2i = CRATE_CELLS[i]
		if cell == AGENT_START_CELL or blocked_map.has(cell):
			continue
		crate_map[cell] = CRATE_VARIANTS[i % CRATE_VARIANTS.size()]
		blocked_map[cell] = true


## --- autotile ---------------------------------------------------------------

func _pick_wall_tile(cell: Vector2i, wall_map: Dictionary) -> String:
	## TODO: implement new autotile logic here.
	return "block_SE"


func _solid(cell: Vector2i, wall_map: Dictionary) -> bool:
	if cell.x < 0 or cell.x >= MAP_SIZE.x or cell.y < 0 or cell.y >= MAP_SIZE.y:
		return true
	return wall_map.has(cell)


## --- serialisation helpers --------------------------------------------------

func _crate_map_to_array(crate_map: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for cell: Vector2i in crate_map.keys():
		entries.append({"cell": cell, "tile_name": String(crate_map[cell])})
	return entries


func _dict_keys_to_vec2i_array(d: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in d.keys():
		cells.append(cell)
	return cells
