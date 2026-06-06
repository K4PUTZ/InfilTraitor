class_name GuardPathfinder
## A* pathfinding for guards over the tile grid.
## Respects the same blocked_cells and blocked_edges used everywhere else.
## Returns full path [start, ..., target] or [] if unreachable.


static func find_path(
	start: Vector2i,
	target: Vector2i,
	blocked_cells: Dictionary,
	blocked_edges: Dictionary,
	room_size: Vector2i
) -> Array[Vector2i]:
	if start == target:
		return [start]

	var open: Dictionary = {}      ## cell → f_score
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	g_score[start] = 0
	f_score[start] = _heuristic(start, target)
	open[start] = f_score[start]

	while not open.is_empty():
		## Pick cell with lowest f_score
		var current: Vector2i = _lowest_f(open, f_score)
		if current == target:
			return _reconstruct(came_from, current)

		open.erase(current)
		var g_cur: int = g_score[current]

		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nb := current + step
			if not _in_bounds(nb, room_size):
				continue
			if blocked_cells.has(nb):
				continue
			if WallEdgeData.is_edge_blocked(current, nb, blocked_edges):
				continue

			var g_nb := g_cur + 1
			if not g_score.has(nb) or g_nb < g_score[nb]:
				came_from[nb] = current
				g_score[nb] = g_nb
				f_score[nb] = g_nb + _heuristic(nb, target)
				if not open.has(nb):
					open[nb] = f_score[nb]

	## No path found
	return []


static func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _lowest_f(open: Dictionary, f_score: Dictionary) -> Vector2i:
	var best: Vector2i = open.keys()[0]
	var best_f: int = f_score.get(best, 999999)
	for cell in open.keys():
		var f: int = f_score.get(cell, 999999)
		if f < best_f:
			best = cell
			best_f = f
	return best


static func _reconstruct(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path


static func _in_bounds(cell: Vector2i, room_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < room_size.x and cell.y < room_size.y
