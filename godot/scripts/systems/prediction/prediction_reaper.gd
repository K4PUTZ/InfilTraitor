## PredictionReaper - lets go of a finished cook's working state a few milliseconds a frame.
##
## R3D-LIGHT (2026-09-26, Moto g04s): `bump_world_revision()` at the commit cancels the cached job, `cancel()` drops the
## cook's state dictionary, and freeing that one object (every ring, cell-to-voxel and packaging table the cook built) took
## **115 ms** inside the commit frame. Dropping a reference is atomic, so the state is handed here instead and emptied entry
## by entry under a budget; whatever a frame does not reach waits for the next one. Nothing reads a retired state again:
## `cancel()` had already made it unreachable.
class_name PredictionReaper
extends RefCounted

## Milliseconds of releasing one frame may spend. `var` (Rule 1).
static var budget_ms: float = 3.0

static var _pending: Array = []
static var _armed: bool = false


## Takes the state; the caller must drop its own reference (`_state = {}`) after this returns.
static func retire(state: Dictionary) -> void:
	if state.is_empty():
		return
	_pending.append(state)
	if _armed:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		_pending.clear()   ## no loop to pace on (a headless script): release at once
		return
	_armed = true
	tree.process_frame.connect(_tick)


static func pending() -> int:
	return _pending.size()


static func _tick() -> void:
	var t0: int = Time.get_ticks_usec()
	var limit: int = int(budget_ms * 1000.0)
	while not _pending.is_empty():
		var state: Dictionary = _pending[0]
		while not state.is_empty():
			state.erase(state.keys()[0])
			if Time.get_ticks_usec() - t0 >= limit:
				return
		_pending.remove_at(0)
	_armed = false
	(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_tick)
