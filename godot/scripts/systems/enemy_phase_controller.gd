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
		occupied: Dictionary,
		tic_callback: Callable   ## novo parâmetro — room._apply_tic_result
) -> Dictionary:
	if not is_instance_valid(guard):
		return {"max_severity": 0, "events": []}

	occupied.erase(guard.cell)
	var events: Array[Dictionary] = []
	var max_severity := 0

	## Tic antes do movimento
	var before := TicSystem.evaluate(guard, player_cell, blocked_cells, blocked_edges)
	tic_callback.call(guard, before)
	if bool(before.detected):
		max_severity = 2
	elif bool(before.visible):
		max_severity = 1
	events.append({
		"enemy_id": guard.enemy_id,
		"cell": guard.cell,
		"detected": before.detected,
		"moment": "before_move",
	})

	var next_cell: Vector2i = guard.choose_next_cell(occupied, blocked_cells, blocked_edges, player_cell, room_size)
	if next_cell != guard.cell:
		await guard.move_to_cell_animated(next_cell, blocked_cells, blocked_edges, room_size)

	## Tic depois do movimento
	var after := TicSystem.evaluate(guard, player_cell, blocked_cells, blocked_edges)
	tic_callback.call(guard, after)
	if bool(after.detected):
		max_severity = 2
	elif bool(after.visible):
		max_severity = maxi(max_severity, 1)
	events.append({
		"enemy_id": guard.enemy_id,
		"cell": guard.cell,
		"detected": after.detected,
		"moment": "after_move",
	})

	occupied[guard.cell] = guard
	guard.tick_state()

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
		blocked[WallEdgeData.edge_key(from_cell, to_cell)] = true
	return blocked


