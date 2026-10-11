## DetonationPrediction — PREDICTION_MASTER_PLAN §4, Task 4 (P-SLICE),
## 2026-08-09.
##
## One detonation being computed, as an object you can hold, advance a few
## milliseconds at a time, ask about, and throw away.
##
## `DetonationPlanBuilder` owns the pipeline and its phases; this owns the
## *handle*. The split matters for §5: a cache stores predictions, and a cache
## entry that is a bare `Dictionary` of pipeline internals would leak that
## pipeline into every consumer.
##
## ## Cancellation is free, and that is the entire payoff of Tasks 2 and 3
##
## `cancel()` drops the state. There is no rollback, no restore set, nothing to
## undo — because nothing was done. Every phase writes only into the Delta and
## the build's own scratch dictionaries, so an abandoned prediction leaves the
## world byte-identical to how it found it. That property is asserted, not
## assumed: `blast_purity_selftest.gd` cancels a half-finished build mid-phase
## and snapshots all 7 mutable fields of all ~100 000 voxels either side.
##
## §3.2 rejected snapshot/restore partly on this: a restore-based design would
## have to enumerate its undo set perfectly on every cancellation, and a player
## sweeping a cursor across ten GUs cancels nine times.
##
## ## Best-effort budgets
##
## `step()` honours its budget BETWEEN chunks, never inside one, and two phases
## (SOOT, LIGHT) cannot be suspended at all — see `DetonationPlanBuilder`'s phase
## table and §8.8's measurements. A caller must treat the budget as a target, not
## a guarantee, and `worst_step_ms` is here so it can find out what it actually
## got instead of trusting the number it asked for.
class_name DetonationPrediction
extends RefCounted

const DetonationPlanBuilderClass = preload("res://godot/scripts/systems/destruction/detonation_plan_builder.gd")

## The finished Delta, or null until `is_done()`. Deliberately not exposed
## half-built: a partial Delta describes a partial blast, and there is no
## consumer for which that is a useful thing to be handed.
var delta: WorldDelta = null

## Identity, for §5's cache key. Set by whoever creates the prediction; this
## class never interprets it.
var signature: String = ""

## Diagnostics, filled as the build runs. `worst_step_ms` is what §4.4's budget
## gate is actually measured against.
var steps: int = 0
var worst_step_ms: float = 0.0
var worst_step_phase: String = ""

## P-WARM (2026-08-12) — the playback-side preparation that used to happen at
## the instant the grenade went off, carried here so the throw window can pay
## for it instead. `warmed` records that the two IMPURE preparations — minting
## tile alternatives and pushing composite pages to the GPU — have already been
## done for this prediction. Both mutate the renderer, so they can never move
## into the pure pipeline; what they can do is happen an entire second earlier.
##
## Measured on a real PLAYGROUND throw, the reason this exists at all:
##
##     without warming   5 wave frames, 753 ms   (~150 ms per frame)
##     with warming      5 wave frames,  85 ms   (~17 ms per frame)
##
## False is always safe: `_ensure_light_alt()`/`flush_damage_composite_pages()`
## are idempotent, so an unwarmed job simply pays what it always paid.
##
## D-6 dropped `playback_queue` — it was the choreographer's radial flatten of
## `delta.waves`, and the presenter writes every cell in one frame in container
## order.
var warmed: bool = false

var _state: Dictionary = {}
var _cancelled: bool = false
## G-D55 — the glass-support walk on the predicted world, on the WorkerThreadPool once the plan is built; `delta` is published when it
## is done. -1 = none running.
var _support_task: int = -1
var _support_holder: Array = []
var _pending: WorldDelta = null
const GlassSupportRef = preload("res://godot/scripts/systems/destruction/glass_support.gd")
## Walks of cancelled cooks, still running: reaped (waited, which is then instant) once they finish.
static var _orphan_tasks: Array = []


static func _reap_orphans() -> void:
	for t: int in _orphan_tasks.duplicate():
		if WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
			_orphan_tasks.erase(t)


## Opens the build. Nothing is computed here.
func begin(bomb_def, source_gu: Vector2i, ctx: Dictionary) -> void:
	_state = DetonationPlanBuilderClass.begin(bomb_def, source_gu, ctx)
	_cancelled = false
	delta = null
	_pending = null
	steps = 0
	worst_step_ms = 0.0
	worst_step_phase = ""
	warmed = false


## Advances the build by at most `budget_ms` of work. Returns true when done.
##
## The phase name recorded for a slow step is the phase the build was in when
## the step STARTED — which is the one that overran, since a step stops at the
## first chunk boundary past the deadline.
func step(budget_ms: float) -> bool:
	if _cancelled or _state.is_empty():
		return true
	if delta != null:
		return true
	_reap_orphans()
	if _pending != null:
		return _poll_support(budget_ms <= 0.0)
	var entering: String = DetonationPlanBuilderClass.phase_name(_state)
	var t0: int = Time.get_ticks_usec()
	var done: bool = DetonationPlanBuilderClass.step(_state, int(budget_ms * 1000.0))
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	steps += 1
	if elapsed_ms > worst_step_ms:
		worst_step_ms = elapsed_ms
		worst_step_phase = entering
	if done:
		_pending = _state["delta"]
		_start_support(_pending)
		return _poll_support(budget_ms <= 0.0)
	return false


## G-D55 — walk the glass support on the world this plan predicts, off the main thread. The snapshot is the live store with every
## claim the plan destroys marked gone (a few packed-array copies: cheap). Pure: nothing is written outside the snapshot.
func _start_support(d: WorldDelta) -> void:
	var store: VoxelStore = VoxelStore.active
	if store == null:
		return
	var snap = GlassSupportRef.snapshot(store)
	var gone := PackedInt32Array()
	var proj: Dictionary = d.projections()
	for v in proj:
		if int(proj[v][WorldDelta.P_STATE]) == Voxel.DamageState.DESTROYED:
			var c: int = store.claim_of(v)
			if c >= 0:
				gone.append(c)
	GlassSupportRef.apply_destroyed(snap, gone)
	_support_holder = [[]]
	var holder: Array = _support_holder
	_support_task = WorkerThreadPool.add_task(func() -> void: holder[0] = GlassSupportRef.unsupported(snap), false, "glass support (cook)")


## True once the walk is done (`wait` blocks for it: the one-shot path), publishing `delta` with its collapse plan.
func _poll_support(wait: bool) -> bool:
	if _support_task != -1:
		if not wait and not WorkerThreadPool.is_task_completed(_support_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_support_task)
		_support_task = -1
		_pending.glass_collapse = _support_holder[0]
		_pending.glass_collapse_ready = true
	delta = _pending
	_pending = null
	return true


## Runs to completion with no budget — the one-shot path, for a caller that has
## nowhere to hide the cost and would rather pay it now.
func run(bomb_def, source_gu: Vector2i, ctx: Dictionary) -> WorldDelta:
	begin(bomb_def, source_gu, ctx)
	while not step(0.0):
		pass
	return delta


## Abandons the build. Safe at any point, including mid-phase, and safe to call
## twice. See the class doc for why this needs no rollback.
func cancel() -> void:
	_cancelled = true
	if _support_task != -1:   ## a worker task cannot be stopped, and waiting here would stall the aim: it is reaped once finished
		_orphan_tasks.append(_support_task)
		_support_task = -1
	_pending = null
	PredictionReaper.retire(_state)
	_state = {}
	delta = null


func is_cancelled() -> bool:
	return _cancelled


func is_done() -> bool:
	return delta != null


## 0.0-1.0, phase-granular. Honest enough to drive a "cooking" indicator; not
## honest enough to put a percentage next to.
func progress() -> float:
	if delta != null:
		return 1.0
	if _state.is_empty():
		return 0.0
	return DetonationPlanBuilderClass.progress(_state)


func phase_name() -> String:
	if delta != null:
		return "DONE"
	if _state.is_empty():
		return "CANCELLED" if _cancelled else "IDLE"
	return DetonationPlanBuilderClass.phase_name(_state)


## Per-phase timings, one line each — §8.8's evidence for whether §4.4's budget
## is actually being met, and which phase is responsible when it is not.
##
## This has to be read on the REAL map, not in a selftest: the two phases that
## cannot be suspended (SOOT, LIGHT) are both cheap on a synthetic scaffold with
## no lights and a small blast, so a fixture would report a comfortable profile
## for a pipeline that spikes in the real game. That is CLAUDE.md's standing
## lesson in its exact original shape.
func profile_lines() -> Array[String]:
	if _state.is_empty():
		return []
	return DetonationPlanBuilderClass.profile_lines(_state)
