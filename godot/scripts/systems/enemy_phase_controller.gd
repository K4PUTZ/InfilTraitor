extends Node
class_name EnemyPhaseController
## Runs the enemy phase in sequence so movement and detection stay deterministic.

const DEFAULT_VISION_RANGE := 6


func run_single_guard_turn(
		guard,
		player_cell: Vector2i,
		blocked_cells: Dictionary,
		blocked_edges: Dictionary,
		room_size: Vector2i,
		occupied: Dictionary
) -> Dictionary:
	if not is_instance_valid(guard):
		return {"max_severity": 0, "events": []}

	occupied.erase(guard.cell)
	var events: Array[Dictionary] = []
	var max_severity := 0

	var before: Dictionary = guard.evaluate_detection(player_cell, DEFAULT_VISION_RANGE)
	if bool(before.get("visible", false)):
		var before_severity := int(before.get("severity", 1))
		max_severity = maxi(max_severity, before_severity)
		events.append({
			"enemy_id": guard.enemy_id,
			"cell": guard.cell,
			"severity": before_severity,
			"moment": "before_move",
		})

	var next_cell: Vector2i = guard.pick_next_patrol_cell(occupied, blocked_cells, blocked_edges, room_size)
	if next_cell != guard.cell:
		await guard.move_to_cell_animated(next_cell)

	var after: Dictionary = guard.evaluate_detection(player_cell, DEFAULT_VISION_RANGE)
	if bool(after.get("visible", false)):
		var after_severity := int(after.get("severity", 1))
		max_severity = maxi(max_severity, after_severity)
		events.append({
			"enemy_id": guard.enemy_id,
			"cell": guard.cell,
			"severity": after_severity,
			"moment": "after_move",
		})

	occupied[guard.cell] = guard

	return {
		"max_severity": max_severity,
		"events": events,
	}


func build_blocked_edge_set(edges: Array[Dictionary]) -> Dictionary:
	return _build_edge_block_set(edges)


func _build_edge_block_set(edges: Array[Dictionary]) -> Dictionary:
	var blocked: Dictionary = {}
	for edge in edges:
		var from_cell: Vector2i = edge.get("from", Vector2i.ZERO)
		var to_cell: Vector2i = edge.get("to", Vector2i.ZERO)
		blocked[_edge_key(from_cell, to_cell)] = true
	return blocked


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]
