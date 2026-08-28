## DetonationPresenter — D-3 of `DETONATION_PRESENTATION_MASTER_PLAN`.
##
## **The world changes once, and the EFFECTS are what is animated.** That is the
## whole inversion (§4). `DetonationChoreographer` animates the WORLD — it spreads
## 20 ms of cell writes across 24 frames and decorates them — and this replaces it
## with one frame that writes everything and then N frames that write nothing.
##
## Behind `INFILTRAITOR_PRESENTER=1`; the choreographer stays the default until
## D-6 removes it. Both run from one binary, so a before/after needs no stash.
##
## ## What it does NOT contain, which is the point
##
## No `flatten_plan()`, no `_sort_key()`, no `KIND_RADIUS_BIAS`, no
## `front_radius_for()`, no `front_frames`, no `_fade_in_soot()`. Every one of
## those exists to decide WHEN a cell is written, and there is only one frame that
## writes cells. §3.1: the ordering problem does not get solved here, it stops
## existing — `KIND_RADIUS_BIAS` had been re-derived three times.
##
## ## The three beats
##
##   1. **THE COMMIT — one frame.** Every `destroy`, `expose`, `dented`, `cracked`
##      and `soot` entry, then one flush. From here the board is FINAL.
##   2. **The consequence channel — N frames, zero cell writes.** `smoke`, `ember`
##      and `debris`, each released at its own time.
##   3. **The light**, unchanged and still last (§7, the Director's standing
##      ruling: scorch is what the light is about to reveal).
##
## ⚠️ **THE SCORCH IS IN THE COMMIT, AND THAT IS WHY `soot_clean` IS FALSE HERE.**
## §13.4 made the wave write clean geometry because its scorch arrived later in a
## ramp, and a hole that opened already-scorched then had to be wiped and refilled.
## With one commit frame there is no later — §7.1 — so the cell writes carry their
## own soot and `_fade_in_soot()` has nothing left to do. Setting this true would
## produce a permanently clean crater with no error anywhere.
class_name DetonationPresenter
extends RefCounted

signal finished()

## §13.3 — the Room that owns the consequence beat and the light. Null keeps this
## usable headless (no light beat), which is what a selftest wants.
var consequence_room = null

## --- The consequence channel's timing, in SECONDS (§5.2) ------------------
##
## §4.2, the Director's own axis: *"pensar em um sistema por GU de distância e por
## slice de altura"*. Ordering stops being "on which frame do I write this cell"
## and becomes "when does this instance light up" — and that is affordable for the
## exact reason the front was not: a delay on an effect costs nothing, while a
## frame that writes cells costs 59 ms (D-1, §8.3).
##
## ⚠️ SECONDS, NOT FRAMES, AND THE RULE HAS TEETH HERE. §14.1's failure mode — a
## performance wave silently retuning the blast's duration 4.9x — needs a
## frame-denominated look value to bite. These cannot be retuned by a perf change
## because nothing about them is a frame budget.
##
## All `var` per architecture Rule 1: they are look stats and the Director tunes
## them on a filmstrip.
var ring_step_s: float = 0.055      ## per GU of distance from the epicentre
var storey_bias_s: float = 0.020    ## per storey above the impact storey
var jitter_s: float = 0.060         ## per-cell scatter, FNV-1a, never randf()

## Hard stop for the channel. A blast clipped by walls can have a small radial
## span and a wide one can have a large one; this keeps the beat's LENGTH a
## property of the design rather than of the geometry it happened to hit.
var consequence_max_seconds: float = 0.75

var _writer := DetonationEntryWriter.new()
var _t0_ms: int = 0


## Same signature as the choreographer's, deliberately: `TestZoneController` wires
## both from one call site and a diverging signature is a place for them to differ
## in what they were HANDED rather than in what they do.
func set_vfx_targets(ember_overlay: EmberOverlay, smoke_tints: Dictionary = {},
		debris_overlay: DebrisOverlay = null, debris_colors: Dictionary = {}) -> void:
	_writer.ember_overlay = ember_overlay
	_writer.smoke_tints = smoke_tints
	_writer.debris_overlay = debris_overlay
	_writer.debris_colors = debris_colors


func start(plan: Dictionary, voxel_renderer, smoke_overlay, tree: SceneTree) -> void:
	_t0_ms = Time.get_ticks_msec()
	## §7.1 — the scorch rides in the commit. See the class header.
	_writer.soot_clean = false
	_commit_frame(plan, voxel_renderer)
	await _run_consequence(plan, voxel_renderer, smoke_overlay, tree)
	if consequence_room != null and consequence_room.consequence_beat:
		consequence_room.event_probe_beat("LIGHT")
		## AWAITED: `finished` is what clears the controller's only strong
		## reference to this object, and the light runs a coroutine of its own.
		await consequence_room.play_consequence_light()
	finished.emit()


## Beat 2 — every cell this blast changes, in one frame, then one flush.
##
## The kind order is fixed and it is not the same question the choreographer's
## radial sort answered. Inside one frame nothing is visible until the frame ends,
## so this order cannot be SEEN; it exists only so that two writes to one cell
## resolve the same way every run. `destroy` leads because it erases, and an
## `expose` reveal is the thing a destroy uncovers.
##
## ⚠️ `expose` entries ride NESTED inside destroy entries, not as their own kind.
## `flatten_plan()` broke them out because one destroy entry can hold 628 reveals
## and that would have been one indivisible 628-cell step in a paced front. There
## is no pacing here, so they are simply applied where they live — the reason to
## break them out went away with the front.
func _commit_frame(plan: Dictionary, voxel_renderer) -> void:
	var cells: int = 0
	var t0: int = Time.get_ticks_usec()
	for ring in plan.get("destroy", {}).keys():
		for entry: Dictionary in plan["destroy"][ring]:
			cells += _writer.apply("destroy", entry, voxel_renderer, null)
			for reveal: Dictionary in entry.get("expose", []):
				cells += _writer.apply("expose", reveal, voxel_renderer, null)
	for kind: String in ["dented", "cracked", "soot"]:
		for ring in plan.get(kind, {}).keys():
			for entry: Dictionary in plan[kind][ring]:
				cells += _writer.apply(kind, entry, voxel_renderer, null)
	_writer.flush(voxel_renderer)
	print("[E-PRESENT] commit frame — %d cell(s) in %.3f ms of apply" % [
		cells, float(Time.get_ticks_usec() - t0) / 1000.0])


## Beat 3 — the channel. Every VFX entry gets a release time; frames pass; each
## is dispatched when its time comes. **No frame here writes a cell**, which is
## what makes a dropped one cosmetic instead of a desync.
func _run_consequence(plan: Dictionary, voxel_renderer, smoke_overlay,
		tree: SceneTree) -> void:
	var scheduled: Array = []
	for kind: String in ["smoke", "ember", "debris"]:
		for ring in plan.get(kind, {}).keys():
			for entry: Dictionary in plan[kind][ring]:
				scheduled.append([_delay_for(entry), kind, entry])
	if scheduled.is_empty():
		return
	scheduled.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	if consequence_room != null:
		consequence_room.event_probe_beat("CONSEQUENCE")
	var next: int = 0
	var elapsed: float = 0.0
	var frames: int = 0
	var last_delay: float = float(scheduled[scheduled.size() - 1][0])
	while next < scheduled.size():
		await tree.process_frame
		## RUNTIME-GUARD-01 — this is a RefCounted living across `await`s while the
		## VoxelRenderer it paints into is a child of the Room, and `load_map()`
		## builds a new one. Same guard, same reason as the choreographer's.
		if not is_instance_valid(voxel_renderer):
			push_warning("[DetonationPresenter] renderer went away mid-sequence (map reload?) — abandoned with %d of %d effect(s) undispatched" % [scheduled.size() - next, scheduled.size()])
			return
		frames += 1
		elapsed += tree.root.get_process_delta_time()
		while next < scheduled.size() and float(scheduled[next][0]) <= elapsed:
			_writer.apply(String(scheduled[next][1]), scheduled[next][2],
				voxel_renderer, smoke_overlay)
			next += 1
	print("[E-PRESENT] consequence — %d effect(s) over %d frame(s), last at %.2fs (elapsed %.2fs, %d ms wall)" % [
		scheduled.size(), frames, last_delay, elapsed, Time.get_ticks_msec() - _t0_ms])


## §4.2's formula. Every input is already on the entry — `r` is the radius in
## VOXELS the plan builder computed, and `level` is the cell's own — so this adds
## no walk and no second pass over the map.
##
## The ember's OWN `delay` field is untouched and still forwarded to the overlay
## by the writer: that one is E-EMBER-02's upward creep, an intra-column stagger,
## a different axis from this radial one. Adding them is intended.
func _delay_for(entry: Dictionary) -> float:
	var r: float = float(entry.get("r", 0.0))
	var gu_ring: float = r / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	## §4.2's "storey from impact", and the grenade sits on the playable storey.
	## LEVEL-RENUMBER — that storey is 10, not 0, so the subtraction is not
	## cosmetic: without it every entry would read as ten storeys up and the bias
	## would be a constant. Floors BELOW the impact get 0 rather than a negative
	## delay: a crater's floor is part of the same instant as its walls.
	var storey: float = 0.0
	if entry.has("level"):
		storey = maxf(float(int(entry["level"]) / GeometryCoords.LEVELS_PER_STOREY
			- GeometryCoords.PLAYABLE_STOREY), 0.0)
	var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
	var jitter: float = _hash_unit(cell, int(entry.get("level", 0)))
	return minf(ring_step_s * gu_ring + storey_bias_s * storey + jitter_s * jitter,
		consequence_max_seconds)


## FNV-1a, never `randf()` — two captures of the same detonation must dispatch in
## the same order, which is the discipline CLAUDE.md prices at 36 733 pixels.
static func _hash_unit(cell: Vector2i, level: int) -> float:
	var h: int = 2166136261
	for v: int in [cell.x, cell.y, level, 0x50524553]:
		h = (h ^ (v & 0xFFFFFFFF)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return float(h % 100000) / 100000.0
