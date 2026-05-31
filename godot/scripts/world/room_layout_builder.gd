extends RefCounted
## Builds a single segment layout for the InfilTraitor segment system.
## Segment: W=18, H=36 (W+H=54 → 6912×3456 px screen space).
## Interior: 16×34 tiles. Border: 1 tile wide on all sides.
## Access points replace border tiles with passable floor.
##
## Autotile rule (from Kenney Information.png):
##   N = top-right vertex, E = bottom-right, S = bottom-left, W = top-left.
##   Camera is at position N (top-right), looking inward.
##   Suffix = direction of the open (interior/floor) neighbour:
##     open to N → wall_N   open to S → wall_S
##     open to E → wall_E   open to W → wall_W
##   Two adjacent open dirs → wallCorner; opposite/3+ open dirs → block_N.

const MAP_SIZE         := Vector2i(18, 36)
const AGENT_START_CELL := Vector2i(9, 34)   ## South interior centre
const FLOOR_TILE       := "floor_N"

const CRATE_VARIANTS: Array[String] = ["crate_N", "crate_E", "crate_S", "crate_W"]
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

## Interior wall cells — horizontal barrier at y=17 with a 4-tile gap at x=7..10.
## Splits the segment into a south lobby and north target area.
const INTERIOR_WALL_CELLS: Array[Vector2i] = [
	Vector2i( 1, 17), Vector2i( 2, 17), Vector2i( 3, 17),
	Vector2i( 4, 17), Vector2i( 5, 17), Vector2i( 6, 17),
	Vector2i(11, 17), Vector2i(12, 17), Vector2i(13, 17),
	Vector2i(14, 17), Vector2i(15, 17), Vector2i(16, 17),
]


func build_layout() -> Dictionary:
	## wall_map: all solid wall cells (border + interior walls).
	var wall_map: Dictionary = {}
	## blocked_map: everything the agent cannot enter (walls + crates).
	var blocked_map: Dictionary = {}
	## crate_map: cell → tile_name for crate structure tiles.
	var crate_map: Dictionary = {}

	_collect_border_walls(wall_map, blocked_map)
	_open_access_points(wall_map, blocked_map)
	_collect_interior_walls(wall_map, blocked_map)
	_collect_crates(crate_map, blocked_map)

	## Autotile: pick the correct Kenney wall variant for each wall cell.
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


## ─── wall collection ────────────────────────────────────────────────────────

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


## ─── autotile ───────────────────────────────────────────────────────────────
## Suffix = direction of the open (walkable-floor) neighbour.
## Cells outside the map boundary are treated as solid (not open).

func _pick_wall_tile(cell: Vector2i, wall_map: Dictionary) -> String:
	var open_n := not _solid(cell + Vector2i( 0, -1), wall_map)
	var open_s := not _solid(cell + Vector2i( 0,  1), wall_map)
	var open_e := not _solid(cell + Vector2i( 1,  0), wall_map)
	var open_w := not _solid(cell + Vector2i(-1,  0), wall_map)

	var open_count: int = int(open_n) + int(open_s) + int(open_e) + int(open_w)

	match open_count:
		0:
			return "block_N"
		1:
			if open_n: return "wall_N"
			if open_s: return "wall_S"
			if open_e: return "wall_E"
			return "wall_W"
		2:
			## Adjacent open pair → L-corner; opposite pair → full block (both sides exposed).
			if open_n and open_e: return "wallCorner_S"
			if open_n and open_w: return "wallCorner_E"
			if open_s and open_e: return "wallCorner_W"
			if open_s and open_w: return "wallCorner_N"
			return "block_N"   ## open_n+open_s or open_e+open_w (thin wall, both sides exposed)
		_:
			return "block_N"   ## 3+ open sides — wall cap or isolated tile


func _solid(cell: Vector2i, wall_map: Dictionary) -> bool:
	## Out-of-bounds cells count as solid so border autotile works correctly.
	if cell.x < 0 or cell.x >= MAP_SIZE.x or cell.y < 0 or cell.y >= MAP_SIZE.y:
		return true
	return wall_map.has(cell)


## ─── serialisation helpers ──────────────────────────────────────────────────

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