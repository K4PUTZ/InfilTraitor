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
## for it instead.
##
## Kept on the job rather than inside the Delta because none of it is part of
## what `build_plan()` computes: `playback_queue` is DetonationChoreographer's
## own flattening of `delta.waves` (pure, but the choreographer's business), and
## `warmed` records that the two IMPURE preparations — minting tile alternatives
## and pushing composite pages to the GPU — have already been done for this
## prediction. Both of those mutate the renderer, so they can never move into
## the pure pipeline; what they can do is happen an entire second earlier.
##
## Measured on a real PLAYGROUND throw, the reason this exists at all:
##
##     without warming   5 wave frames, 753 ms   (~150 ms per frame)
##     with warming      5 wave frames,  85 ms   (~17 ms per frame)
##
## Empty/false is always safe: DetonationChoreographer falls back to flattening
## the plan itself, and `_ensure_light_alt()`/`flush_damage_composite_pages()`
## are both idempotent, so an unwarmed job simply pays what it always paid.
var playback_queue: Array = []
var warmed: bool = false

var _state: Dictionary = {}
var _cancelled: bool = false


## Opens the build. Nothing is computed here.
func begin(bomb_def, source_gu: Vector2i, ctx: Dictionary) -> void:
	_state = DetonationPlanBuilderClass.begin(bomb_def, source_gu, ctx)
	_cancelled = false
	delta = null
	steps = 0
	worst_step_ms = 0.0
	worst_step_phase = ""
	playback_queue = []
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
	var entering: String = DetonationPlanBuilderClass.phase_name(_state)
	var t0: int = Time.get_ticks_usec()
	var done: bool = DetonationPlanBuilderClass.step(_state, int(budget_ms * 1000.0))
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	steps += 1
	if elapsed_ms > worst_step_ms:
		worst_step_ms = elapsed_ms
		worst_step_phase = entering
	if done:
		delta = _state["delta"]
	return done


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
