extends Node
## Global singleton — register as autoload "TurnManager".
##
## Turn cycle:  PLAYER → (end_player_turn) → ENEMY → (all enemies acted) → PLAYER → …
##
## M1 stub: enemy phase has no actors yet, so it resolves immediately.

enum Phase { PLAYER, ENEMY }

## Emitted whenever the active phase changes.
signal phase_changed(new_phase: Phase)

var phase: Phase = Phase.PLAYER


## Call from the "End Turn" button or when the agent runs out of AP.
func end_player_turn() -> void:
	phase = Phase.ENEMY
	phase_changed.emit(Phase.ENEMY)
	# Defer so listeners process ENEMY signal before we switch back.
	_end_enemy_turn.call_deferred()


func _end_enemy_turn() -> void:
	# TODO M2: iterate enemy actors and let each act before returning.
	phase = Phase.PLAYER
	phase_changed.emit(Phase.PLAYER)
