## PredictionCache — PREDICTION_MASTER_PLAN §5, Task 5 (P-CACHE), 2026-08-09.
##
## Holds finished predictions so that coming BACK to a target is free. The
## Director's own reason, and it is the right one:
##
##   *"O jogador pode decidir mudar de GU na última hora (é o mais provável, a
##   gente só pára de ficar mexendo quando acerta a que estava buscando), então
##   temos que jogar fora e começar de novo rapidamente."*
##
## A cursor sweeping ten GUs generates ten predictions and discards nine. Coming
## back is the COMMON case, because the sweep is a comparison.
##
## ## The key, and why invalidation is deliberately blunt
##
## `(signature, world_revision)`. The signature is the action's own identity
## (bomb + target GU + perspective); the revision is a counter the world bumps on
## every committed mutation. A bumped revision drops the whole cache at once.
##
## That is coarse on purpose. §5.2: a precise dependency graph is a second system
## to get wrong, and the common case — nothing changes while the player is
## choosing a target — is served perfectly by the blunt version. Flagged there as
## revisitable, not as final.
##
## ## One prediction is pumped at a time, and a superseded one is CANCELLED
##
## §4.2: *"hover moves to another GU → previous request cancelled, not completed;
## cache keeps whatever finished."* A half-built prediction for a GU the player
## has already left is pure cost, so it is dropped rather than finished in the
## background. Cancelling is free (nothing was written — see
## `DetonationPrediction`), which is what makes "throw away and start again
## quickly" a real option instead of an expensive one.
##
## ## Sizing
##
## `max_entries` = 8 by default, and that is a SETTLED number rather than a
## provisional one (§5.4, Q3): the workload is one cursor comparing GUs, not a
## guard swarm. Guard AI is out of scope and gets its own system if it ever needs
## one, so nothing here is shaped around it.
class_name PredictionCache
extends RefCounted

const DetonationPredictionClass = preload("res://godot/scripts/systems/prediction/detonation_prediction.gd")

## LRU bound, in whole predictions. `var` (Rule 1). A blast Delta is on the
## order of a couple of thousand small entries, so eight of them is tens of
## thousands — acceptable. A consumer that wants more than this should be asking
## for a census (§3.4), not for more full Deltas.
var max_entries: int = 8

## Counters, for the §8.9 measurements and for anyone debugging a cache that is
## not helping. Not gameplay state.
var hits: int = 0
var misses: int = 0
var evictions: int = 0
var cancellations: int = 0
var invalidations: int = 0

## signature -> DetonationPrediction (finished, or the one currently building)
var _entries: Dictionary = {}
## signatures, least-recently-used first
var _lru: Array[String] = []
## the world revision every entry here was computed against
var _revision: int = -1
## the one prediction being advanced by pump(); null when everything is settled
var _active: DetonationPrediction = null


## The signature half of the key. Static and public so a caller cannot invent a
## second, subtly different format — two spellings of the same action would be
## two cache entries and the cache would silently never hit.
##
## Perspective is in the key because anything resolving through view space
## (carved sides, screen-x reads) differs between rotations, and §2.4 lists it as
## a real input.
static func blast_signature(bomb_id: String, source_gu: Vector2i,
		perspective: String) -> String:
	return "blast:%s:%d,%d:%s" % [bomb_id, source_gu.x, source_gu.y, perspective]


## Asks for a prediction, starting one if this is new. Returns the handle —
## which may be finished already (a hit) or barely begun (a miss).
##
## A miss for a DIFFERENT signature cancels whatever was mid-build, per §4.2.
func request(signature: String, revision: int, bomb_def, source_gu: Vector2i,
		ctx: Dictionary) -> DetonationPrediction:
	_sync_revision(revision)

	var existing: DetonationPrediction = _entries.get(signature)
	if existing != null and not existing.is_cancelled():
		hits += 1
		_touch(signature)
		if not existing.is_done():
			_active = existing   ## resume it rather than restart it
		return existing

	misses += 1
	_abandon_active_unless(signature)

	var job := DetonationPredictionClass.new()
	job.signature = signature
	job.begin(bomb_def, source_gu, ctx)
	_entries[signature] = job
	_touch(signature)
	_evict_if_needed()
	_active = job
	return job


## The finished Delta for this key, or null. Never starts work and never
## cancels anything — safe to call from a draw or a UI poll.
func peek(signature: String, revision: int) -> WorldDelta:
	if revision != _revision:
		return null
	var job: DetonationPrediction = _entries.get(signature)
	if job == null or not job.is_done():
		return null
	_touch(signature)
	return job.delta


## Advances the one in-flight prediction by at most `budget_ms`. Call once per
## frame from whoever owns the frame loop. Returns true if work was done.
func pump(budget_ms: float) -> bool:
	if _active == null:
		return false
	if _active.is_cancelled():
		_active = null
		return false
	if _active.step(budget_ms):
		_active = null
	return true


## True while something is still being computed.
func is_busy() -> bool:
	return _active != null and not _active.is_done()


## Drops everything. Called when the world moves under the cache — §2.4's
## dependency list, applied bluntly (see the class doc).
func invalidate() -> void:
	if _entries.is_empty() and _active == null:
		return
	invalidations += 1
	if _active != null:
		_active.cancel()
		_active = null
	for job in _entries.values():
		(job as DetonationPrediction).cancel()
	_entries.clear()
	_lru.clear()


func size() -> int:
	return _entries.size()


func stats_line() -> String:
	return "[P-CACHE] %d entr(ies) rev=%d — hits %d · misses %d · evictions %d · cancels %d · invalidations %d" % [
		_entries.size(), _revision, hits, misses, evictions, cancellations, invalidations]


func _sync_revision(revision: int) -> void:
	if revision == _revision:
		return
	## Not counted as an `invalidation` when the cache was empty anyway — the
	## first request of a session would otherwise report one and make the counter
	## useless for spotting a cache that is being thrashed.
	if not _entries.is_empty() or _active != null:
		invalidate()
	_revision = revision


## Cancels the in-flight prediction unless it happens to be the one now wanted.
func _abandon_active_unless(signature: String) -> void:
	if _active == null or _active.signature == signature:
		return
	cancellations += 1
	_active.cancel()
	_entries.erase(_active.signature)
	_lru.erase(_active.signature)
	_active = null


func _touch(signature: String) -> void:
	_lru.erase(signature)
	_lru.append(signature)


## LRU by entry count. The in-flight prediction is never evicted — evicting the
## thing currently being computed would be a pure waste of the work already
## spent on it.
func _evict_if_needed() -> void:
	while _lru.size() > max_entries:
		var victim: String = ""
		for candidate in _lru:
			if _active != null and _active.signature == candidate:
				continue
			victim = candidate
			break
		if victim.is_empty():
			return
		_lru.erase(victim)
		var job: DetonationPrediction = _entries.get(victim)
		if job != null:
			job.cancel()
		_entries.erase(victim)
		evictions += 1
