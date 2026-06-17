class_name MapGeometry
extends RefCounted
## Pure, coordinate-agnostic geometry primitives for building room layouts.
##
## These helpers operate on whatever Rect2i/cells they are handed — they know
## nothing about the buffer offset or any specific map. MapCompiler is responsible
## for translating spec coordinates into the final grid space before calling here.
##
## Relocated from the old room_layout_builder.gd so both hand-authored maps and the
## procedural generator share one source of wall/door/edge logic.


## Builds a rectangular room bounded by rect.
## doors: Array of {"cell": Vector2i} — direction inferred from position on border.
## Returns {wall_tiles: Array[Dictionary], _blocked_map: Dictionary, blocked_edges: Array}.
## NOTE: wall cells are NOT added to _blocked_map — walls block movement via blocked_edges
## only (the interior stays bounded by edges, matching the original SIGMA-01 behaviour).
static func build_room(rect: Rect2i, doors: Array[Dictionary]) -> Dictionary:
	var min_x := rect.position.x
	var min_y := rect.position.y
	var max_x := rect.position.x + rect.size.x - 1
	var max_y := rect.position.y + rect.size.y - 1

	var wall_map:    Dictionary = {}
	var blocked_map: Dictionary = {}
	var blocked_edges: Array = []

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if x == min_x or x == max_x or y == min_y or y == max_y:
				wall_map[Vector2i(x, y)] = true

	## Open door cells — remove from wall, queue for door tile
	var door_set: Dictionary = {}
	for ap: Dictionary in doors:
		var cell: Vector2i = ap["cell"]
		wall_map.erase(cell)
		door_set[cell] = true

	var wall_tiles: Array[Dictionary] = []
	for cell: Vector2i in wall_map.keys():
		wall_tiles.append({"cell": cell, "tile_name": _pick_wall_tile(cell, rect)})
		blocked_edges += _wall_cell_blocked_edges(cell, rect)
	for cell: Vector2i in door_set.keys():
		wall_tiles.append({"cell": cell, "tile_name": _pick_door_tile(cell, rect)})

	return {"wall_tiles": wall_tiles, "_blocked_map": blocked_map, "blocked_edges": blocked_edges}


## Places an inner rectangular room inside an outer room.
## inner_rect must fit strictly inside outer_rect (≥1 tile gap from outer walls).
## existing_blocked: current blocked dict of the segment {Vector2i: true}.
## Returns {wall_tiles, _blocked_map, blocked_edges} to merge, or {} on validation failure.
static func place_inner_room(
		outer_rect:       Rect2i,
		inner_rect:       Rect2i,
		doors:            Array[Dictionary],
		existing_blocked: Dictionary
) -> Dictionary:
	var i_min := inner_rect.position
	var i_max := inner_rect.position + inner_rect.size - Vector2i(1, 1)
	var o_min := outer_rect.position
	var o_max := outer_rect.position + outer_rect.size - Vector2i(1, 1)

	if i_min.x <= o_min.x or i_min.y <= o_min.y \
	or i_max.x >= o_max.x or i_max.y >= o_max.y:
		push_error("MapGeometry: inner_rect %s must be strictly inside outer_rect %s" \
				% [inner_rect, outer_rect])
		return {}

	for x in range(i_min.x, i_max.x + 1):
		for y in range(i_min.y, i_max.y + 1):
			if x == i_min.x or x == i_max.x or y == i_min.y or y == i_max.y:
				if existing_blocked.has(Vector2i(x, y)):
					push_error("MapGeometry: inner_rect overlaps existing blocked cell %s" \
							% Vector2i(x, y))
					return {}

	return build_room(inner_rect, doors)


## --- tile picking -----------------------------------------------------------

static func _pick_wall_tile(cell: Vector2i, rect: Rect2i) -> String:
	var min_x := rect.position.x
	var min_y := rect.position.y
	var max_x := rect.position.x + rect.size.x - 1
	var max_y := rect.position.y + rect.size.y - 1

	var on_sw := cell.x == min_x   ## left column  — SW border
	var on_ne := cell.x == max_x   ## right column — NE border
	var on_nw := cell.y == min_y   ## top row      — NW border
	var on_se := cell.y == max_y   ## bottom row   — SE border

	## Corners first
	if on_nw and on_sw: return "wallCorner_NW"
	if on_nw and on_ne: return "wallCorner_NE"
	if on_se and on_sw: return "wallCorner_SW"
	if on_se and on_ne: return "wallCorner_SE"

	## Straight edges
	if on_nw: return "wall_NW"
	if on_se: return "wall_SE"
	if on_sw: return "wall_SW"
	if on_ne: return "wall_NE"

	return "block_SE"   ## interior fallback (should not be reached for border cells)


static func _pick_door_tile(cell: Vector2i, rect: Rect2i) -> String:
	var min_x := rect.position.x
	var min_y := rect.position.y
	var max_x := rect.position.x + rect.size.x - 1
	var max_y := rect.position.y + rect.size.y - 1

	if cell.y == min_y: return "doorOpen_NW"
	if cell.y == max_y: return "doorOpen_SE"
	if cell.x == min_x: return "doorOpen_SW"
	if cell.x == max_x: return "doorOpen_NE"

	return "doorOpen_SE"   ## fallback


static func _wall_cell_blocked_edges(cell: Vector2i, rect: Rect2i) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	var min_x := rect.position.x
	var min_y := rect.position.y
	var max_x := rect.position.x + rect.size.x - 1
	var max_y := rect.position.y + rect.size.y - 1

	if cell.x == min_x:
		edges.append({"from": cell, "to": cell + Vector2i(-1, 0)})
	if cell.x == max_x:
		edges.append({"from": cell, "to": cell + Vector2i(1, 0)})
	if cell.y == min_y:
		edges.append({"from": cell, "to": cell + Vector2i(0, -1)})
	if cell.y == max_y:
		edges.append({"from": cell, "to": cell + Vector2i(0, 1)})

	return edges
