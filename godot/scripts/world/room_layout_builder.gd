extends RefCounted
## MAP SIGMA-01 — Mapa de testes sistemático para INFILTRAITOR.
## Grade 18×36. Interior: 16×34 tiles (x=1–16, y=1–34).
## 4 zonas, 3 paredes-divisórias, fontes de luz posicionadas.
## Prompt A: geometria e iluminação (sem guardas).
## Prompt B: adiciona DEFAULT_GUARD_PATROLS com 4 guardas.

const MAP_SIZE         := Vector2i(18, 36)
const AGENT_START_CELL := Vector2i(9, 34)   ## Sul interior central
const FLOOR_TILE       := "floor_SE"

const CRATE_VARIANTS: Array[String] = ["crate_SE", "crate_SW", "crate_NW", "crate_NE"]

const CRATE_CELLS: Array[Vector2i] = [
	## Zona 0 — cover inicial (entrada)
	Vector2i(3,  32), Vector2i(14, 32),
	## Zona B — caixas centrais (cover atrás de caixa)
	Vector2i(7,  21), Vector2i(10, 21),
	## Zona B — armazém (shadow zone direita)
	Vector2i(15, 13), Vector2i(16, 13), Vector2i(15, 14),
	## Zona B — pilares (bloqueiam LOS, criam penumbra)
	Vector2i(5,  17), Vector2i(13, 17),
]

## Pontos de acesso fixos do SIGMA-01 — ignora LevelGraph para mapa de testes
const SIGMA_ACCESS_POINTS: Array[Dictionary] = [
	{"cell": Vector2i(9, 35)},   ## entrada sul — spawn do agente
	{"cell": Vector2i(9,  0)},   ## saída norte — extração
]

## Guardas — definidos no Prompt B com 4 rotas cobrindo todos os cenários de teste
const DEFAULT_GUARD_PATROLS: Array[Array] = [
	## ALPHA (α) — ZONA A, corredor iluminado, patrulha E-W completa
	## Cria janelas de timing previsíveis; shadow x=1-2 e x=15-16 são rotas seguras
	[Vector2i(2, 28), Vector2i(15, 28)],

	## BRAVO (β) — ZONA B centro iluminado, patrulha retangular
	## Passa próximo das caixas em y=21; cruza o raio whistle de CHARLIE no extremo oeste
	[
		Vector2i(4,  11), Vector2i(13, 11),
		Vector2i(13, 22), Vector2i(4,  22),
	],

	## CHARLIE (γ) — ZONA B shadow esquerda, patrulha curta N-S
	## A ~3 tiles de BRAVO quando BRAVO está em (4,11)–(4,22): raio whistle ativo
	## Detecta passos do agente na Zona A pelo portão de (2–3, 25)
	[Vector2i(2, 14), Vector2i(2, 18)],

	## DELTA (δ) — ZONA C sala superior, patrulha E-W longa
	## Sightlines longas; último desafio antes da extração em (9, 0)
	[Vector2i(2, 5), Vector2i(15, 5)],
]

## Parede-divisória entre ZONA C e ZONA B (y=9)
## Portão esquerdo: x=4–5  |  Portão direito: x=12–13
const SIGMA_DIVIDER_A: Array[Vector2i] = [
	Vector2i(1, 9), Vector2i(2, 9), Vector2i(3, 9),
	Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9),
	Vector2i(10, 9), Vector2i(11, 9),
	Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9),
]

## Parede-divisória entre ZONA B e ZONA A (y=25)
## Portão esquerdo: x=2–3  |  Portão direito: x=14–15  |  SEM passagem central
const SIGMA_DIVIDER_B: Array[Vector2i] = [
	Vector2i(1, 25),
	Vector2i(4, 25), Vector2i(5, 25), Vector2i(6, 25), Vector2i(7, 25),
	Vector2i(8, 25), Vector2i(9, 25), Vector2i(10, 25), Vector2i(11, 25),
	Vector2i(12, 25), Vector2i(13, 25),
	Vector2i(16, 25),
]

## Parede-divisória entre ZONA A e ZONA 0 (y=30)
## Portão único central: x=8–9
const SIGMA_DIVIDER_C: Array[Vector2i] = [
	Vector2i(1, 30), Vector2i(2, 30), Vector2i(3, 30), Vector2i(4, 30),
	Vector2i(5, 30), Vector2i(6, 30), Vector2i(7, 30),
	Vector2i(10, 30), Vector2i(11, 30), Vector2i(12, 30), Vector2i(13, 30),
	Vector2i(14, 30), Vector2i(15, 30), Vector2i(16, 30),
]

## Fontes de luz SIGMA-01 — passadas ao room.gd via chave "light_sources" no layout dict
## room.gd lê em _setup_light_sources() e usa em _compute_shadow_tiles()
const SIGMA_LIGHT_SOURCES: Array[Dictionary] = [
	{"x": 9, "y":  5, "height": 5.0, "radius": 8, "intensity": 0.9},    ## Zona C
	{"x": 9, "y": 17, "height": 5.0, "radius": 7, "intensity": 0.85},   ## Zona B
	{"x": 9, "y": 28, "height": 5.0, "radius": 6, "intensity": 0.85},   ## Zona A
]

## Builds the SIGMA-01 test map layout.
## O parâmetro access_points é ignorado — usa SIGMA_ACCESS_POINTS fixos.
func build_layout(_access_points: Array[Dictionary] = []) -> Dictionary:
	var room          := build_room(Rect2i(Vector2i.ZERO, MAP_SIZE), SIGMA_ACCESS_POINTS)
	var blocked_map: Dictionary       = room["_blocked_map"]
	var blocked_edges: Array          = room.get("blocked_edges", [])
	var wall_tiles: Array[Dictionary] = room["wall_tiles"].duplicate()

	## Bloquear toda a borda externa exceto os tiles de saída (doorOpen).
	## Impede o jogador de contornar as paredes pelos fundos do mapa.
	var exit_set: Dictionary = {}
	for ap: Dictionary in SIGMA_ACCESS_POINTS:
		exit_set[ap["cell"]] = true
	for bx in range(MAP_SIZE.x):
		for by in range(MAP_SIZE.y):
			if bx == 0 or bx == MAP_SIZE.x - 1 or by == 0 or by == MAP_SIZE.y - 1:
				var border_cell := Vector2i(bx, by)
				if not exit_set.has(border_cell) and not blocked_map.has(border_cell):
					blocked_map[border_cell] = true

	## Adicionar três paredes-divisórias horizontais com gaps de porta
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

	## Caixas e pilares como structure_tiles
	var crate_map: Dictionary = {}
	_collect_crates(crate_map, blocked_map)

	## Extrair posições das saídas para o overlay em room.gd
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
