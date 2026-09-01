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
		tic_callback: Callable,   ## room._apply_tic_result
		noise_callback: Callable,  ## M2-14: room._on_guard_emits_noise (guard noise emission)
		## G3 STAGE D — the set the guard's FEET obey, which since G-D8 is not the
		## one its eyes do. Empty means "same as `blocked_edges`", so every caller
		## that has not been split behaves exactly as it did.
		movement_edges: Dictionary = {}
) -> Dictionary:
	if not is_instance_valid(guard):
		return {"max_severity": 0, "events": []}

	occupied.erase(guard.cell)
	var events: Array[Dictionary] = []
	var max_severity := 0

	## Tic before the move
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

	## G3 STAGE D — the guard's FEET use the movement set (intact glass blocks),
	## its EYES the vision one (glass does not). Defaulted to `blocked_edges` so a
	## caller that has not been split yet behaves exactly as before.
	var move_edges: Dictionary = movement_edges if not movement_edges.is_empty() else blocked_edges
	var next_cell: Vector2i = guard.choose_next_cell(occupied, blocked_cells, move_edges, player_cell, room_size)
	if next_cell != guard.cell:
		await guard.move_to_cell_animated(next_cell, blocked_cells, move_edges, room_size)
		## M2-14: Emit noise after the guard moves
		noise_callback.call(guard, next_cell)

	## Tic after the move
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


## GLASS G3 STAGE D / G-D8 — THE MOVEMENT SET, split from the vision one.
##
## Director, 2026-08-31: *"o agente consegue atravessar o vidro, precisamos
## implementar a questão da abertura de passagem."* A half-thickness glass panel
## never enters `blocked_edges` (§2), so agent AND guards walk straight through an
## intact pane today.
##
## The fix cannot be "add glass to `blocked_edges`", because that one set feeds
## MOVEMENT, VISION, DETECTION, NOISE and LIGHT alike — and G-D7 is explicit that
## glass must block the BODY without blocking the EYE. So this is a second set,
## used only where feet are involved:
##
##   movement  MovementOverlay (the agent), GuardPathfinder via
##             `choose_next_cell()` / `move_to_cell_animated()`   <- THIS set
##   vision    `can_see_cell()`, TicSystem                        <- the old set
##   noise     NoiseSystem propagation                            <- the old set
##   light     ShadowProjector                                    <- the old set
##
## And it answers the other half of G-D8 in the same pass — *"a broken pane opens
## a passage"* — by asking `PassageQuery` rather than a boolean: a glass edge
## blocks the body only while its pane is still `PassageClass.NONE`. Once a break
## has opened a real hole the edge simply stops being added, so the passage opens
## on the next recompute with no separate bookkeeping and no second source of
## truth about what is broken.
##
## `glass_edges` is `EdgeRegistry.glass_edge_keys()` (edge_key -> pane_id) and
## already excludes `PANE_BLOCK_*`, whose cells live in `blocked_cells` instead.
func build_movement_edge_set(edges: Array[Dictionary], glass_edges: Dictionary,
		edge_registry) -> Dictionary:
	var blocked: Dictionary = _build_edge_block_set(edges)
	if edge_registry == null:
		return blocked
	for edge in edge_registry.all_edges():
		if edge.material != "glass":
			continue
		var key: String = WallEdgeData.edge_key(edge.gu_a, edge.gu_b)
		if not glass_edges.has(key):
			continue   ## a BLOCK pane — its cells are blocked, not its edges
		if PassageQuery.passage_class(edge, edge_registry) == PassageQuery.PassageClass.NONE:
			blocked[key] = true
	return blocked


func _build_edge_block_set(edges: Array[Dictionary]) -> Dictionary:
	var blocked: Dictionary = {}
	for edge in edges:
		var from_cell: Vector2i = edge.get("from", Vector2i.ZERO)
		var to_cell: Vector2i = edge.get("to", Vector2i.ZERO)
		blocked[WallEdgeData.edge_key(from_cell, to_cell)] = true
	return blocked


