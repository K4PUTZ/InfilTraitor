extends Node2D
class_name MovementOverlay
## Reachable movement bands for the current player turn.
## Computes a simple Dijkstra flood over 4-directional walkable cells.

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var origin_cell: Vector2i = Vector2i(-9999, -9999)
var max_path_cost: int = 0

var _costs: Dictionary = {}
var _came_from: Dictionary = {}
var _blocked_cells: Dictionary = {}
var _blocked_edges: Dictionary = {}
var _points_per_ap: int = 3   ## Kept in sync with TurnManager.MOVE_POINTS_PER_AP
var _highlighted_ap: int = 1  ## Current AP zone to highlight (1 or 2)
var _remaining_ap: int = 2     ## Remaining AP to determine colors

const TILE_TOP_TO_CENTER := Vector2(0.0, 64.0)

const BLUE_LINE   := Color(0.25, 0.70, 1.0, 0.90)  ## Azul para Zona 1 (2 AP restantes)
const ORANGE_LINE := Color(1.0, 0.60, 0.20, 0.95)  ## Laranja para Zona 2 (ou Zona 1 com 1 AP)
const FILL_COLOR  := Color(1.0, 1.0, 1.0, 1.0)     ## Base branca para o fill (será colorida no draw)

## Constantes de cor para Cover
const COLOR_COVER_FULL    := Color(0.1, 0.4, 0.9, 0.25)   ## azul tático denso
const COLOR_COVER_PARTIAL := Color(0.2, 0.6, 1.0, 0.12)   ## azul claro suave


func setup(tile_layer: TileMapLayer, offset: Vector2, points_per_ap: int = 3) -> void:
	floor_layer = tile_layer
	visual_offset = offset
	_points_per_ap = points_per_ap


func set_blocked_cells(cells: Array[Vector2i]) -> void:
	_blocked_cells.clear()
	for cell in cells:
		_blocked_cells[cell] = true


func set_blocked_edges(edges: Array[Dictionary]) -> void:
	_blocked_edges.clear()
	for edge in edges:
		var from_cell: Vector2i = edge.get("from", Vector2i.ZERO)
		var to_cell: Vector2i = edge.get("to", Vector2i.ZERO)
		_blocked_edges[WallEdgeData.edge_key(from_cell, to_cell)] = true


func rebuild(start_cell: Vector2i, new_max_path_cost: int) -> void:
	origin_cell = start_cell
	max_path_cost = new_max_path_cost
	_costs.clear()
	_came_from.clear()

	if floor_layer == null or max_path_cost <= 0:
		queue_redraw()
		return

	_costs[origin_cell] = 0
	var frontier: Array[Vector2i] = [origin_cell]

	while not frontier.is_empty():
		frontier.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return int(_costs.get(a, 999999)) < int(_costs.get(b, 999999))
		)
		var current: Vector2i = frontier.pop_front()
		var current_cost := int(_costs.get(current, 0))

		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next_cell: Vector2i = current + step
			if _is_edge_blocked(current, next_cell):
				continue
			if not _is_traversable(next_cell):
				continue

			var next_cost := current_cost + _movement_cost(next_cell)
			if next_cost > max_path_cost:
				continue

			if not _costs.has(next_cell) or next_cost < int(_costs[next_cell]):
				_costs[next_cell] = next_cost
				_came_from[next_cell] = current
				if not frontier.has(next_cell):
					frontier.append(next_cell)

	queue_redraw()


func clear_overlay() -> void:
	origin_cell = Vector2i(-9999, -9999)
	max_path_cost = 0
	_costs.clear()
	_came_from.clear()
	_highlighted_ap = 1
	queue_redraw()


func set_highlight_ap(ap: int) -> void:
	var new_val := clampi(ap, 1, 2)
	if _highlighted_ap != new_val:
		_highlighted_ap = new_val
		queue_redraw()


func _draw_cover_hints(target_cells: Array[Vector2i]) -> void:
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for tile in target_cells:
		var count := 0
		for dir in dirs:
			if _blocked_cells.has(tile + dir):
				count += 1
		if count == 0:
			continue
		var color := COLOR_COVER_FULL if count >= 2 else COLOR_COVER_PARTIAL
		draw_colored_polygon(_diamond_points(tile), color)


func set_remaining_ap(ap: int) -> void:
	_remaining_ap = ap
	queue_redraw()


func is_reachable(cell: Vector2i) -> bool:
	return _costs.has(cell) and cell != origin_cell


func get_cost(cell: Vector2i) -> int:
	return int(_costs.get(cell, -1))


func get_ap_cost(cell: Vector2i) -> int:
	var cost := get_cost(cell)
	if cost <= 0:
		return 0
	return int(ceili(float(cost) / float(_points_per_ap)))


func build_path_to(target: Vector2i) -> Array[Vector2i]:
	if not _costs.has(target):
		return []

	var path: Array[Vector2i] = [target]
	var current: Vector2i = target
	while current != origin_cell:
		if not _came_from.has(current):
			return []
		current = _came_from[current]
		path.push_front(current)
	return path


func _get_fill_alpha(cell: Vector2i) -> float:
	var dist := absi(cell.x - origin_cell.x) + absi(cell.y - origin_cell.y)
	## Aumenta 0.05 (5%) a cada 1 tile de distância, após o primeiro tile.
	return clampf(float(dist - 1) * 0.05, 0.0, 0.40)


func _draw() -> void:
	if floor_layer == null or _costs.is_empty():
		return

	var target_cells: Array[Vector2i] = []
	for cell in _costs.keys():
		if cell == origin_cell:
			continue
		if get_ap_cost(cell) <= _highlighted_ap:
			target_cells.append(cell)

	## M2-10: Cover Hints
	_draw_cover_hints(target_cells)

	## Determinar cor do perímetro:
	## Zona 1 fica laranja quando só resta 1 AP (já gastou 1)
	var line_color: Color
	if _highlighted_ap == 2:
		line_color = ORANGE_LINE
	elif _highlighted_ap == 1 and _remaining_ap < 2:
		line_color = ORANGE_LINE
	else:
		line_color = BLUE_LINE

	# 1. Draw Gradient Fills
	for cell in target_cells:
		var alpha := _get_fill_alpha(cell)
		if alpha > 0.0:
			var fill_color := line_color
			fill_color.a = alpha
			draw_colored_polygon(_diamond_points(cell), fill_color)

	# 2. Draw Perimeters (External edges or blocked internal edges)
	for cell in target_cells:
		var diamond := _diamond_points(cell)
		
		# Edges: V0->V1 (TR), V1->V2 (BR), V2->V3 (BL), V3->V0 (TL)
		# Neighbor mapping: UP(0,-1), RIGHT(1,0), DOWN(0,1), LEFT(-1,0)
		
		# Top-Right edge (V0 -> V1): Neighbor UP
		if _should_draw_edge(cell, Vector2i.UP):
			draw_line(diamond[0], diamond[1], line_color, 3.0, true)
			
		# Bottom-Right edge (V1 -> V2): Neighbor RIGHT
		if _should_draw_edge(cell, Vector2i.RIGHT):
			draw_line(diamond[1], diamond[2], line_color, 3.0, true)
			
		# Bottom-Left edge (V2 -> V3): Neighbor DOWN
		if _should_draw_edge(cell, Vector2i.DOWN):
			draw_line(diamond[2], diamond[3], line_color, 3.0, true)
			
		# Top-Left edge (V3 -> V0): Neighbor LEFT
		if _should_draw_edge(cell, Vector2i.LEFT):
			draw_line(diamond[3], diamond[0], line_color, 3.0, true)


func _should_draw_edge(cell: Vector2i, step: Vector2i) -> bool:
	var neighbor := cell + step
	# If neighbor is NOT in the current AP range, or movement is blocked by a wall
	if _is_edge_blocked(cell, neighbor):
		return true
	if not _costs.has(neighbor):
		return true
	if get_ap_cost(neighbor) > _highlighted_ap:
		return true
	return false


func _diamond_points(cell: Vector2i) -> PackedVector2Array:
	var top := floor_layer.map_to_local(cell) + visual_offset
	return PackedVector2Array([
		top,
		top + Vector2(128.0, 64.0),
		top + Vector2(0.0, 128.0),
		top + Vector2(-128.0, 64.0),
	])


func _is_traversable(cell: Vector2i) -> bool:
	if floor_layer == null:
		return false
	if _blocked_cells.has(cell):
		return false
	var source_id := floor_layer.get_cell_source_id(cell)
	if source_id == -1:
		return false

	var source := floor_layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return false
	var tile_data := source.get_tile_data(Vector2i(0, 0), 0)
	if tile_data == null:
		return false
	return bool(tile_data.get_custom_data("walkable"))


func _is_edge_blocked(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return _blocked_edges.has(WallEdgeData.edge_key(from_cell, to_cell))




func _movement_cost(_cell: Vector2i) -> int:
	return 1