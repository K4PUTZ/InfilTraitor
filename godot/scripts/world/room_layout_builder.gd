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

## Inner corner cells — one step diagonally inside each map corner.
## These receive the wallCorner tile via Rule 2; the actual border corner cell
## gets a straight wall tile (Rule 0) so the corner assembly looks like:
##   [REPEAT border wall] [wallCorner inner] [REPEAT border wall]
const CORNER_INNER_CELLS: Array[Vector2i] = [
	Vector2i( 1,  1),   ## NW inner corner
	Vector2i(16,  1),   ## NE inner corner
	Vector2i( 1, 34),   ## SW inner corner
	Vector2i(16, 34),   ## SE inner corner
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
	_collect_corner_inners(wall_map, blocked_map)
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


func _collect_corner_inners(wall_map: Dictionary, blocked_map: Dictionary) -> void:
	for cell: Vector2i in CORNER_INNER_CELLS:
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
## Junction type → open-neighbour count → tile selected:
##
##   0 open  (X-junction / fully enclosed): block_N
##           Special case: MAP CORNERS have 0 open (adjacent border walls +
##           out-of-bounds are all solid), handled by Rule 0 → wallCorner_*.
##
##   1 open  (T-junction / wall end-cap facing one side): wall_<open_dir>
##           The exposed face points toward the single open (floor) side.
##
##   2 open, adjacent (L-junction / corner): wallCorner_<apex_dir>
##           The corner apex points away from the two open sides.
##
##   2 open, opposing (straight wall, both sides exposed): block_N
##           No single-face tile covers both sides; solid block used.
##
##   3 open  (passage end-cap): wall_<open_dir> facing opposite closed side
##           Applied by Rule 3 — the visible end-cap face of a wall stub.
##
##   4 open  (isolated tile, should not occur): block_N
##
## Rule order: 0 (map corner) → 1 (mid-border straight) → 2 (open-count) → 3 (end-cap)

func _pick_wall_tile(cell: Vector2i, wall_map: Dictionary) -> String:
	var on_west  := cell.x == 0
	var on_east  := cell.x == MAP_SIZE.x - 1
	var on_north := cell.y == 0
	var on_south := cell.y == MAP_SIZE.y - 1

	## ── Rule 0: map corners ─────────────────────────────────────────────────
	## The wallCorner tile lives at the inner corner cell (CORNER_INNER_CELLS),
	## one step diagonally inside the map. The actual border corner cell gets a
	## straight wall tile that caps its border wall cleanly:
	##   N corners → wall_S  (south face, matching north border row)
	##   S corners → wall_N  (north face, matching south border row)
	if on_west  and on_north: return "wall_S"   ## NW actual corner → N border cap
	if on_east  and on_north: return "wall_S"   ## NE actual corner → N border cap
	if on_west  and on_south: return "wall_N"   ## SW actual corner → S border cap
	if on_east  and on_south: return "wall_N"   ## SE actual corner → S border cap

	## ── Rule 1: mid-border override ─────────────────────────────────────────
	## Non-corner border cells always get their straight face tile regardless of
	## interior neighbours — prevents T-junction notches at the border.
	if on_west  and not on_north and not on_south: return "wall_E"
	if on_east  and not on_north and not on_south: return "wall_W"
	if on_north and not on_west  and not on_east:  return "wall_S"
	if on_south and not on_west  and not on_east:  return "wall_N"

	## ── Rule 2: open-count autotile ─────────────────────────────────────────
	var open_n := not _solid(cell + Vector2i( 0, -1), wall_map)
	var open_s := not _solid(cell + Vector2i( 0,  1), wall_map)
	var open_e := not _solid(cell + Vector2i( 1,  0), wall_map)
	var open_w := not _solid(cell + Vector2i(-1,  0), wall_map)

	var open_count: int = int(open_n) + int(open_s) + int(open_e) + int(open_w)

	match open_count:
		0:
			## X-junction or fully enclosed — no tile in the Kenney pack covers this.
			return "block_N"
		1:
			## T-junction / single face — wall faces the one open (floor) side.
			if open_n: return "wall_N"
			if open_s: return "wall_S"
			if open_e: return "wall_E"
			return "wall_W"
		2:
			## L-junction (adjacent open) → corner; straight (opposing open) → block.
			## Suffix = open interior quadrant; same -90° calibration as Rule 0.
			if open_n and open_e: return "wallCorner_E"   ## interior toward NE
			if open_n and open_w: return "wallCorner_N"   ## interior toward NW
			if open_s and open_e: return "wallCorner_S"   ## interior toward SE
			if open_s and open_w: return "wallCorner_W"   ## interior toward SW
			return "block_N"   ## N+S or E+W — straight wall, both sides exposed
		3:
			## ── Rule 3: passage end-cap ────────────────────────────────────
			## Three sides open; the one closed side continues the wall run.
			## Show the face pointing opposite to the wall connection.
			if not open_n: return "wall_S"   ## wall continues N → end-cap faces S
			if not open_s: return "wall_N"   ## wall continues S → end-cap faces N
			if not open_e: return "wall_W"   ## wall continues E → end-cap faces W
			return "wall_E"                  ## wall continues W → end-cap faces E
		_:
			## 4 open sides — isolated tile, should not occur in authored layouts.
			return "block_N"


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