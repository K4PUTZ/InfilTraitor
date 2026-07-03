## Selection Controller: manages tile selection, validation, and player movement attempts.
## Extracted from room.gd (Task 05 modularization).
## Delegates to room for state access (movement_overlay, selection_overlay, etc.)
class_name SelectionController


var room: Node
var selected_cell: Vector2i = Vector2i(-1, -1)


func _init(p_room: Node) -> void:
	room = p_room
	selected_cell = Vector2i(-1, -1)  # INVALID_CELL


## Check if a cell can be selected (not blocked, not a guard, has floor tile).
func is_selectable_cell(cell: Vector2i) -> bool:
	if cell == Vector2i(-1, -1):  # INVALID_CELL
		return false
	if room._blocked_cells.has(cell):
		return false
	if room._is_guard_cell(cell):
		return false
	return room.floor_layer.get_cell_source_id(cell) != -1


## Set the selected cell (if selectable) and update overlays.
func set_selected_cell(cell: Vector2i) -> void:
	if not is_selectable_cell(cell):
		return
	selected_cell = cell
	room.selection_overlay.set_selected(cell)
	room._update_selected_preview()
	
	## Dev 03: update hover label on selection change if dev vision active
	if room._vision_controller.dev_vision:
		room._hovered_cell = cell
		room._update_dev_hover_label()


## Handle tile click (left-button release on a cell).
## If cell differs from selected: select it.
## If cell == selected and not agent cell: try to move.
## Otherwise: update path preview.
func handle_tile_click(cell: Vector2i) -> void:
	if room.turn_manager.is_enemy_phase or room._actor_end_pause_active:
		return
	if not is_selectable_cell(cell):
		room.path_preview.clear_path()
		return

	if selected_cell != cell:
		set_selected_cell(cell)
		return

	if cell != room.agent.cell and try_move_to(cell):
		return

	room._update_selected_preview()


## Attempt to move agent to target cell.
## Returns true if movement initiated; false if invalid/unreachable/insufficient AP.
func try_move_to(cell: Vector2i) -> bool:
	if room._actor_end_pause_active:
		return false
	if room.turn_manager.is_enemy_phase:
		return false
	if room.agent.is_moving or cell == Vector2i(-1, -1) or cell == room.agent.cell:
		return false
	if not room.movement_overlay.is_reachable(cell):
		return false

	var path_cost: int = room.movement_overlay.get_cost(cell)
	## Build path before spending AP — spend triggers ap_changed → rebuild → clears _costs.
	var path: Array[Vector2i] = room.movement_overlay.build_path_to(cell)
	if path.size() < 2:
		return false
	if not room.turn_manager.spend_for_path_cost(path_cost):
		return false

	selected_cell = cell
	room._pending_auto_end_turn = room._hud_controller.is_auto_end_turn_enabled() and int(room.turn_manager.current_ap) <= 0
	room.agent.move_along_path(path)
	return true


## Execute a move (right-click on selected cell).
func try_execute_move() -> void:
	if room.turn_manager.is_enemy_phase or room._actor_end_pause_active:
		return
	if selected_cell != Vector2i(-1, -1) and selected_cell != room.agent.cell:
		try_move_to(selected_cell)


## Query current selected cell.
func get_selected_cell() -> Vector2i:
	return selected_cell


## Reset selection (e.g., when perspective changes or map reloads).
func reset_selection() -> void:
	selected_cell = Vector2i(-1, -1)
