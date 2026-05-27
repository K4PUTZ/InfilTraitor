extends Node
class_name TacticalTurnManager
## Minimal player-turn controller for the M1.5 tactical UI slice.

signal ap_changed(current_ap: int, max_ap: int)

const MAX_AP := 2
const MOVE_POINTS_PER_AP := 3

var current_ap: int = MAX_AP


func _ready() -> void:
	ap_changed.emit(current_ap, MAX_AP)


func reset_player_turn() -> void:
	current_ap = MAX_AP
	ap_changed.emit(current_ap, MAX_AP)


func end_turn() -> void:
	## Enemy phase is not implemented yet, so end-turn simply refreshes AP.
	reset_player_turn()


func get_max_move_points() -> int:
	return current_ap * MOVE_POINTS_PER_AP


func can_afford_path_cost(path_cost: int) -> bool:
	var ap_cost := path_cost_to_ap(path_cost)
	if ap_cost <= 0:
		return false
	return ap_cost <= current_ap


func spend_for_path_cost(path_cost: int) -> bool:
	var ap_cost := path_cost_to_ap(path_cost)
	if ap_cost <= 0 or ap_cost > current_ap:
		return false
	current_ap -= ap_cost
	ap_changed.emit(current_ap, MAX_AP)
	return true


func path_cost_to_ap(path_cost: int) -> int:
	if path_cost <= 0:
		return 0
	return int(ceili(float(path_cost) / float(MOVE_POINTS_PER_AP)))