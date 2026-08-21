## BurnScheduler — MATERIALS_MASTER_PLAN M3-3. The clock fire burns on.
##
## `DetonationPlanBuilder` decides WHICH voxels burn away and WHEN, inside the
## pure plan (`waves["burn"]`, entries of `{voxel, cell, level, at}`). This holds
## that schedule and answers one question per frame: which of them are due now.
##
## ⚠️ IT WRITES NOTHING. `advance()` returns the voxels whose time has come and
## the caller commits them — `BlastCalculator.commit_damage()` stays the single
## writer (DESTRUCTION_MASTER_PLAN §3), and a scheduler that reached for Voxels
## itself would be a second one. It also makes the whole class testable headless
## with no room, no renderer and no registries.
##
## §3.3, Director 2026-08-21: the tick is `delta` for v1 — *"o fogo precisa ficar
## existindo em looping enquanto o jogador pensa, pra não ficar congelado"* — and
## the turn-based variant stays a live proposal. **That swap is this file's whole
## design constraint**: every piece of delta arithmetic lives in `advance()`, so
## moving to per-turn advancement is changing WHO calls it and with what, not
## rewriting the burn. Nothing else in the codebase should ever add its own
## `_burn_elapsed`.
class_name BurnScheduler

## Pending entries, ASCENDING by `at`. Sorted once on schedule() so `advance()`
## is a walk from the front rather than a scan — a fabric object schedules ~340
## of these and the walk runs every frame for a couple of seconds.
var _pending: Array = []
var _cursor: int = 0
var _elapsed: float = 0.0

## Diagnostics, read by the room's print and by the selftest. Cheap, and the
## alternative is inferring "did the fire finish" from an empty array, which is
## also what a fire that never started looks like.
var _scheduled_total: int = 0
var _consumed_total: int = 0


## Take a plan's `burn` wave. Replaces whatever was pending: a second blast
## re-schedules rather than interleaving, which is the honest v1 behaviour and
## is why `_scheduled_total` resets with it.
##
## Entries arrive grouped by ring (`{ring: [entry]}`) because every wave in a
## Delta is; ring ordering carries no meaning here — `at` already does — so they
## are flattened and re-sorted on the one key that matters.
func schedule(burn_wave: Dictionary) -> void:
	_pending.clear()
	_cursor = 0
	_elapsed = 0.0
	_consumed_total = 0
	for ring in burn_wave.keys():
		for entry in burn_wave[ring]:
			_pending.append(entry)
	_pending.sort_custom(func(a, b) -> bool:
		return float(a.get("at", 0.0)) < float(b.get("at", 0.0)))
	_scheduled_total = _pending.size()


## THE ONE ADVANCE CALL (§3.3). Returns the Voxels whose burn time has arrived
## since the last call — possibly empty, usually empty.
##
## A voxel already DESTROYED is dropped rather than returned: the blast that lit
## the fire may reach it first, and re-marking a hole is the defect W-FIX-01
## closed on the shot path (*"a hole is not a target"*). `set_damage()` still
## does not clamp, on purpose, so the check belongs to whoever knows a hole when
## it sees one — here, that is this loop.
func advance(delta: float) -> Array:
	if _cursor >= _pending.size():
		return []
	_elapsed += maxf(delta, 0.0)
	var due: Array = []
	while _cursor < _pending.size():
		var entry: Dictionary = _pending[_cursor]
		if float(entry.get("at", 0.0)) > _elapsed:
			break
		_cursor += 1
		var voxel = entry.get("voxel")
		if voxel == null or not is_instance_valid(voxel):
			continue
		if voxel.damage_state == Voxel.DamageState.DESTROYED:
			continue
		due.append(voxel)
	_consumed_total += due.size()
	return due


## True while there is anything left to burn. The room polls this to know
## whether to keep calling advance() at all.
func is_burning() -> bool:
	return _cursor < _pending.size()


## Drop the schedule without consuming it. Called when the world the Voxel
## references point into is rebuilt — a perspective flip rebuilds every Voxel
## from the MapSpec (VL-PERSIST), so a schedule that survived one would be
## holding objects that no longer belong to any container.
func cancel() -> void:
	_pending.clear()
	_cursor = 0
	_elapsed = 0.0


func scheduled_count() -> int:
	return _scheduled_total


func consumed_count() -> int:
	return _consumed_total


func elapsed() -> float:
	return _elapsed
