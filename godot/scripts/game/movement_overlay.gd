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

const TILE_TOP_TO_CENTER := Vector2(0.0, 64.0)

const ONE_AP_FILL := Color(0.24, 0.64, 1.0, 0.18)
const ONE_AP_LINE := Color(0.38, 0.78, 1.0, 0.92)
const TWO_AP_FILL := Color(0.05, 0.31, 0.92, 0.22)
const TWO_AP_LINE := Color(0.27, 0.56, 1.0, 0.95)


func setup(tile_layer: TileMapLayer, offset: Vector2) -> void:
	floor_layer = tile_layer
	visual_offset = offset


func set_blocked_cells(cells: Array[Vector2i]) -> void:
	_blocked_cells.clear()
	for cell in cells:
		_blocked_cells[cell] = true


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
	queue_redraw()


func is_reachable(cell: Vector2i) -> bool:
	return _costs.has(cell) and cell != origin_cell


func get_cost(cell: Vector2i) -> int:
	return int(_costs.get(cell, -1))


func get_ap_cost(cell: Vector2i) -> int:
	var cost := get_cost(cell)
	if cost <= 0:
		return 0
	return int(ceili(float(cost) / 3.0))


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


func _draw() -> void:
	if floor_layer == null:
		return

	for cell in _costs.keys():
		if cell == origin_cell:
			continue

		var cost := int(_costs[cell])
		var fill := ONE_AP_FILL if cost <= 3 else TWO_AP_FILL
		var line := ONE_AP_LINE if cost <= 3 else TWO_AP_LINE
		var diamond := _diamond_points(cell)
		draw_colored_polygon(diamond, fill)
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), line, 2.0, true)


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


func _movement_cost(_cell: Vector2i) -> int:
	return 1