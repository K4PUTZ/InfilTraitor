extends RefCounted
## MAP SIGMA-01 — Mapa de testes sistemático para INFILTRAITOR.
##
## ARQUITETURA DE BUFFER:
## MAP_SIZE (28×46) inclui 5 tiles de buffer em cada borda além do segmento jogável
## (INNER_SIZE 18×36). O buffer substitui a extensão negativa de piso, garantindo
## que todos os tiles fiquem dentro do grid numerado e controlado pelo pathfinder.
##
## Segmento jogável: x=5..22, y=5..40
## Buffer bloqueado em blocked_map. Tiles de borda da sala bloqueados por tile type.
## Nenhuma coordenada negativa gerada.

const BUFFER       := 5
const INNER_SIZE   := Vector2i(18, 36)
const MAP_SIZE     := Vector2i(28, 46)   ## INNER_SIZE + 2*BUFFER em cada eixo
const INNER_ORIGIN := Vector2i(BUFFER, BUFFER)

const AGENT_START_CELL := Vector2i(14, 39)   ## (9+5, 34+5)
const FLOOR_TILE       := "floor_SE"

const CRATE_VARIANTS: Array[String] = ["crate_SE", "crate_SW", "crate_NW", "crate_NE"]

const CRATE_CELLS: Array[Vector2i] = [
	## Zona 0 — cover inicial
	Vector2i(8,  37), Vector2i(19, 37),
	## Zona B — caixas centrais
	Vector2i(12, 26), Vector2i(15, 26),
	## Zona B — armazém (shadow zone direita)
	Vector2i(20, 18), Vector2i(21, 18), Vector2i(20, 19),
	## Zona B — pilares
	Vector2i(10, 22), Vector2i(18, 22),
]

## Pontos de acesso fixos — ignoram parâmetro access_points do LevelGraph
const SIGMA_ACCESS_POINTS: Array[Dictionary] = [
	{"cell": Vector2i(14, 40)},   ## saída sul  — y=40 = borda sul da sala
	{"cell": Vector2i(14,  5)},   ## saída norte — y=5  = borda norte da sala
]

const DEFAULT_GUARD_PATROLS: Array[Array] = [
	## ALPHA (α) — Zona A, corredor iluminado, E-W
	[Vector2i(7, 33), Vector2i(20, 33)],

	## BRAVO (β) — Zona B centro iluminado, retangular
	[
		Vector2i(9,  16), Vector2i(18, 16),
		Vector2i(18, 27), Vector2i(9,  27),
	],

	## CHARLIE (γ) — Zona B shadow esquerda, N-S curto
	[Vector2i(7, 19), Vector2i(7, 23)],

	## DELTA (δ) — Zona C sala superior, E-W
	[Vector2i(7, 10), Vector2i(20, 10)],
]

## Divisória Zona C ↔ Zona B (y=14)
## Portão esquerdo: x=9-10  |  Portão direito: x=17-18
const SIGMA_DIVIDER_A: Array[Vector2i] = [
	Vector2i(6, 14), Vector2i(7, 14), Vector2i(8, 14),
	Vector2i(11, 14), Vector2i(12, 14), Vector2i(13, 14),
	Vector2i(14, 14), Vector2i(15, 14), Vector2i(16, 14),
	Vector2i(19, 14), Vector2i(20, 14), Vector2i(21, 14),
]

## Divisória Zona B ↔ Zona A (y=30)
## Portão esquerdo: x=7-8  |  Portão direito: x=19-20  |  SEM passagem central
const SIGMA_DIVIDER_B: Array[Vector2i] = [
	Vector2i(6,  30),
	Vector2i(9,  30), Vector2i(10, 30), Vector2i(11, 30), Vector2i(12, 30),
	Vector2i(13, 30), Vector2i(14, 30), Vector2i(15, 30), Vector2i(16, 30),
	Vector2i(17, 30), Vector2i(18, 30),
	Vector2i(21, 30),
]

## Divisória Zona A ↔ Zona 0 (y=35)
## Portão único central: x=13-14
const SIGMA_DIVIDER_C: Array[Vector2i] = [
	Vector2i(6,  35), Vector2i(7,  35), Vector2i(8,  35),
	Vector2i(9,  35), Vector2i(10, 35), Vector2i(11, 35), Vector2i(12, 35),
	Vector2i(15, 35), Vector2i(16, 35), Vector2i(17, 35), Vector2i(18, 35),
	Vector2i(19, 35), Vector2i(20, 35), Vector2i(21, 35),
]

const SIGMA_LIGHT_SOURCES: Array[Dictionary] = [
	{"x": 14, "y": 10, "height": 5.0, "radius": 8,  "intensity": 0.90},  ## Zona C
	{"x": 14, "y": 22, "height": 5.0, "radius": 7,  "intensity": 0.85},  ## Zona B
	{"x": 14, "y": 33, "height": 5.0, "radius": 6,  "intensity": 0.85},  ## Zona A
]

## Builds the SIGMA-01 test map layout.
## Ignora o parâmetro access_points — usa SIGMA_ACCESS_POINTS fixos.
func build_layout(_access_points: Array[Dictionary] = []) -> Dictionary:
	## Sala jogável começa em INNER_ORIGIN (5,5), não em (0,0)
	var room          := build_room(Rect2i(INNER_ORIGIN, INNER_SIZE), SIGMA_ACCESS_POINTS)
	var blocked_map: Dictionary       = room["_blocked_map"]
	var blocked_edges: Array          = room.get("blocked_edges", [])
	var wall_tiles: Array[Dictionary] = room["wall_tiles"].duplicate()

	## Bloquear toda a zona de buffer — tiles de chão fora do segmento jogável.
	## Impede o pathfinder de usar tiles além das paredes externas da sala.
	for bx: int in range(MAP_SIZE.x):
		for by: int in range(MAP_SIZE.y):
			if bx < BUFFER or bx >= MAP_SIZE.x - BUFFER or \
			   by < BUFFER or by >= MAP_SIZE.y - BUFFER:
				var buf_cell := Vector2i(bx, by)
				if not blocked_map.has(buf_cell):
					blocked_map[buf_cell] = true

	## Três paredes-divisórias internas com gaps de porta
	var divider_cells: Array[Vector2i] = []
	divider_cells.append_array(SIGMA_DIVIDER_C)
	divider_cells.append_array(SIGMA_DIVIDER_B)
	divider_cells.append_array(SIGMA_DIVIDER_A)
	for cell: Vector2i in divider_cells:
		if not blocked_map.has(cell):
			wall_tiles.append({"cell": cell, "tile_name": "block_SE"})
			blocked_map[cell] = true
			blocked_edges.append({"from": cell, "to": cell + Vector2i(0, -1)})
			blocked_edges.append({"from": cell, "to": cell + Vector2i(0,  1)})

	## Caixas e pilares
	var crate_map: Dictionary = {}
	_collect_crates(crate_map, blocked_map)

	## Saídas para o overlay roxo em room.gd
	var exit_cells: Array[Vector2i] = []
	for ap: Dictionary in SIGMA_ACCESS_POINTS:
		exit_cells.append(ap["cell"])

	return {
		"size":             MAP_SIZE,
		"agent_start_cell": AGENT_START_CELL,
		"floor_tile_name":  FLOOR_TILE,
		"wall_tiles":       wall_tiles,
		"structure_tiles":  _crate_map_to_array(crate_map),
		"blocked_cells":    _dict_keys_to_vec2i_array(blocked_map),
		"blocked_edges":    blocked_edges,
		"enemy_defs":       _build_enemy_defs(blocked_map),
		"light_sources":    SIGMA_LIGHT_SOURCES,
		"exit_cells":       exit_cells,
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
