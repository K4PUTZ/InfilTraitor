extends RefCounted
## Builds segment and room layouts for the InfilTraitor level system.
## Segment: W=18, H=36 tiles (6912x3456 px screen space).
## Interior: 16x34 tiles. Border: 1 tile wide on all sides.
## Access points are placed as doorOpen_XX tiles and remain passable.

const MAP_SIZE         := Vector2i(18, 36)
const AGENT_START_CELL := Vector2i(9, 34)   ## South interior centre
const FLOOR_TILE       := "floor_SE"

const CRATE_VARIANTS: Array[String] = ["crate_SE", "crate_SW", "crate_NW", "crate_NE"]
const CRATE_CELLS: Array[Vector2i] = [
	## Corredor de cover oeste (x=3) — sombra e abrigo ao longo do flanco
	Vector2i(3,  8),
	Vector2i(3, 12),
	Vector2i(3, 17),
	Vector2i(3, 22),
	Vector2i(3, 27),
	## Corredor de cover leste (x=14) — rota rápida, mais exposta
	Vector2i(14,  6),
	Vector2i(14, 10),
	Vector2i(14, 15),
	Vector2i(14, 20),
	Vector2i(14, 25),
	## Staging central perto do spawn — repositionamento inicial
	Vector2i( 7, 27),
	Vector2i( 9, 27),
	Vector2i(11, 27),
	Vector2i( 8, 30),
	Vector2i(10, 30),
	## Aproximação ao quarto objetivo
	Vector2i( 6,  8),
	Vector2i(11,  8),
	Vector2i( 6,  5),
	Vector2i(11,  5),
]

## Default segment exits. Override via build_layout(access_points) for dynamic level graphs.
## Each entry: { "cell": Vector2i } — door direction is inferred from border position.
const DEFAULT_ACCESS_POINTS: Array[Dictionary] = [
	{"cell": Vector2i(9, 35)},   ## entrada sul — spawn do agente
	{"cell": Vector2i(7,  0)},   ## saída norte — assimétrica, força abordagem oeste
]

const DEFAULT_GUARD_PATROLS: Array[Array] = [
	## Guarda 1 — patrulha a zona norte aberta, cruza o eixo central
	## Inclui waypoints na mesma linha para forçar rotações em Y
	[
		Vector2i(4,  9), Vector2i(8,  9), Vector2i(12,  9),
		Vector2i(12, 12), Vector2i(8, 12), Vector2i(4, 12),
	],
	## Guarda 2 — patrulha corredor leste (x=13..16, y=16..28)
	## Rota rectangular que cobre toda a faixa leste
	[
		Vector2i(13, 16), Vector2i(16, 16),
		Vector2i(16, 22), Vector2i(16, 28),
		Vector2i(13, 28), Vector2i(13, 22),
	],
	## Guarda 3 — patrulha o perímetro externo do quarto objetivo
	## Rota curta e apertada — força timing preciso para entrar
	[
		Vector2i(3, 3), Vector2i(7, 3),
		Vector2i(7, 7), Vector2i(3, 7),
	],
]


## Builds the full segment layout.
## access_points: pass the output of LevelGraph.access_points_for() to override defaults.
func build_layout(access_points: Array[Dictionary] = DEFAULT_ACCESS_POINTS) -> Dictionary:
	var room      := build_room(Rect2i(Vector2i.ZERO, MAP_SIZE), access_points)
	var blocked_map: Dictionary = room["_blocked_map"]
	var blocked_edges: Array = room.get("blocked_edges", [])
	var wall_tiles: Array[Dictionary] = room["wall_tiles"].duplicate()

	## Quarto objetivo — noroeste: mais difícil de acessar do leste
	var inner_room_rect := Rect2i(Vector2i(2, 2), Vector2i(7, 7))
	var inner_doors: Array[Dictionary] = [
		{"cell": Vector2i(5, 2)},    ## porta norte (saída para exit)
		{"cell": Vector2i(2, 5)},    ## porta oeste
		{"cell": Vector2i(8, 5)},    ## porta leste
		{"cell": Vector2i(5, 8)},    ## porta sul (entrada principal)
	]
	var inner_room := place_inner_room(Rect2i(Vector2i.ZERO, MAP_SIZE), inner_room_rect, inner_doors, blocked_map)
	if inner_room.size() > 0:
		wall_tiles += inner_room["wall_tiles"]
		# Merge inner room's blocked cells into main blocked map
		var inner_blocked: Dictionary = inner_room.get("_blocked_map", {})
		for cell: Vector2i in inner_blocked.keys():
			blocked_map[cell] = true
		# Merge inner room's blocked edges into main blocked edges
		for edge in inner_room.get("blocked_edges", []):
			blocked_edges.append(edge)

	## Parede-stub: fragmento de parede interior em y=13 (chokepoint)
	## Força o agente a escolher rota antes de avançar para o norte
	const STUB_WALL_CELLS: Array[Vector2i] = [
		Vector2i(5, 13), Vector2i(6, 13), Vector2i(7, 13), Vector2i(8, 13),
	]
	for stub_cell in STUB_WALL_CELLS:
		if not blocked_map.has(stub_cell):
			wall_tiles.append({"cell": stub_cell, "tile_name": "block_SE"})
			blocked_map[stub_cell] = true
			## Registrar arestas para LOS
			blocked_edges.append({"from": stub_cell, "to": stub_cell + Vector2i(0, -1)})
			blocked_edges.append({"from": stub_cell, "to": stub_cell + Vector2i(0,  1)})

	## Crates
	var crate_map: Dictionary = {}
	_collect_crates(crate_map, blocked_map)

	return {
		"size":             MAP_SIZE,
		"agent_start_cell": AGENT_START_CELL,
		"floor_tile_name":  FLOOR_TILE,
		"wall_tiles":       wall_tiles,
		"structure_tiles":  _crate_map_to_array(crate_map),
		"blocked_cells":    _dict_keys_to_vec2i_array(blocked_map),
		"blocked_edges":    blocked_edges,
		"enemy_defs":       _build_enemy_defs(blocked_map),
	}


## Builds a rectangular room bounded by rect.
## doors: Array of {"cell": Vector2i} — direction inferred from position on border.
## Returns {wall_tiles: Array[Dictionary], _blocked_map: Dictionary}.
func build_room(rect: Rect2i, doors: Array[Dictionary]) -> Dictionary:
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
## Returns {wall_tiles, _blocked_map} to merge, or {} on validation failure.
func place_inner_room(
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
		push_error("RoomLayoutBuilder: inner_rect %s must be strictly inside outer_rect %s" \
				% [inner_rect, outer_rect])
		return {}

	for x in range(i_min.x, i_max.x + 1):
		for y in range(i_min.y, i_max.y + 1):
			if x == i_min.x or x == i_max.x or y == i_min.y or y == i_max.y:
				if existing_blocked.has(Vector2i(x, y)):
					push_error("RoomLayoutBuilder: inner_rect overlaps existing blocked cell %s" \
							% Vector2i(x, y))
					return {}

	return build_room(inner_rect, doors)


## --- tile picking -----------------------------------------------------------

func _pick_wall_tile(cell: Vector2i, rect: Rect2i) -> String:
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


func _pick_door_tile(cell: Vector2i, rect: Rect2i) -> String:
	var min_x := rect.position.x
	var min_y := rect.position.y
	var max_x := rect.position.x + rect.size.x - 1
	var max_y := rect.position.y + rect.size.y - 1

	if cell.y == min_y: return "doorOpen_NW"
	if cell.y == max_y: return "doorOpen_SE"
	if cell.x == min_x: return "doorOpen_SW"
	if cell.x == max_x: return "doorOpen_NE"

	return "doorOpen_SE"   ## fallback


func _wall_cell_blocked_edges(cell: Vector2i, rect: Rect2i) -> Array[Dictionary]:
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


## --- private helpers --------------------------------------------------------

func _collect_crates(crate_map: Dictionary, blocked_map: Dictionary) -> void:
	for i in range(CRATE_CELLS.size()):
		var cell: Vector2i = CRATE_CELLS[i]
		if cell == AGENT_START_CELL or blocked_map.has(cell):
			continue
		crate_map[cell] = CRATE_VARIANTS[i % CRATE_VARIANTS.size()]
		blocked_map[cell] = true


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


func _build_enemy_defs(blocked_map: Dictionary) -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for i in range(DEFAULT_GUARD_PATROLS.size()):
		var route: Array[Vector2i] = []
		for raw in DEFAULT_GUARD_PATROLS[i]:
			var cell: Vector2i = raw
			if cell == AGENT_START_CELL:
				continue
			if blocked_map.has(cell):
				continue
			if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
				continue
			route.append(cell)

		if route.size() < 2:
			continue

		defs.append({
			"id": "guard_%d" % (i + 1),
			"route": route,
			"start_index": 0,
		})

	return defs
