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


## A member with more than this many entries is emptied a slice at a time: releasing a 200 000-entry `cell_to_voxel` in one
## `erase()` took 101 ms on the Moto (2026-09-26), and that one call was the commit's next frame at 143 ms.
const BIG_MEMBER: int = 4000

## ⚠️ ONLY the members the cook alone holds. Draining EMPTIES the dictionary, so a member the delta or the presenter also
## references (`light_changed_cells`, `waves`, `soot_codes`, ...) would be emptied under them: the first version drained every
## big member and `LIGHT_COOK_GATE` failed with 5 295 and 206 cells. `cell_to_voxel` is read only inside the builder
## (grep: nothing outside `detonation_plan_builder.gd` names it; the delta has no such field).
const DRAINABLE: Array[String] = ["cell_to_voxel"]


static func _tick() -> void:
	var t0: int = Time.get_ticks_usec()
	var limit: int = int(budget_ms * 1000.0)
	while not _pending.is_empty():
		var state: Dictionary = _pending[0]
		while not state.is_empty():
			var k: Variant = state.keys()[0]
			var member: Variant = state[k]
			if DRAINABLE.has(k) and member is Dictionary and (member as Dictionary).size() > BIG_MEMBER:
				## The first keys of the remaining entries, not `keys()`: materialising 200 000 keys was itself ~100 ms.
				var big: Dictionary = member
				while not big.is_empty():
					var batch: Array = []
					for bk: Variant in big:
						batch.append(bk)
						if batch.size() >= 256:
							break
					for bk: Variant in batch:
						big.erase(bk)
					if Time.get_ticks_usec() - t0 >= limit:
						return
			member = null
			state.erase(k)
			if Time.get_ticks_usec() - t0 >= limit:
				return
		_pending.remove_at(0)
	_armed = false
	(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_tick)
