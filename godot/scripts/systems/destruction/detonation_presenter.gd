## DetonationPresenter — D-3 of `DETONATION_PRESENTATION_MASTER_PLAN`.
##
## **The world changes once, and the EFFECTS are what is animated.** That is the
## whole inversion (§4). `DetonationChoreographer` animates the WORLD — it spreads
## 20 ms of cell writes across 24 frames and decorates them — and this replaces it
## with one frame that writes everything and then N frames that write nothing.
##
## It is the only detonation path: the choreographer it replaced was deleted at D-6
## (`620f8e3a`).
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

## True from just before `finished` is emitted. The owner sweeps its list by this flag (a capture of `self` in the signal's
## callback would be a reference cycle).
var is_done: bool = false


## §13.3 — the Room that owns the consequence beat and the light. Null keeps this
## usable headless (no light beat), which is what a selftest wants.
var consequence_room = null

## D-7 (§7.4) — the WorldDelta, for its cook-computed light field inputs. Passed
## straight to `Room.play_consequence_light()`; null there means the full
## re-derivation, so a caller that does not set this loses nothing but speed.
var consequence_delta = null

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


func start(plan: Dictionary, voxel_board, smoke_overlay, tree: SceneTree) -> void:
	_t0_ms = Time.get_ticks_msec()
	## A hit-stop blast has already committed under the flash (`commit_under_flash()`); every other blast commits here.
	if not _committed:
		commit_under_flash(plan, voxel_board)
	var ramp: Array = _ramp
	_committed = false
	## The crater is drawn NOW (Director, 2026-09-26: the crater two frames late looked wrong). R3D-LIGHT: the glass flush (crack
	## re-cut, shard rims, craze masks: ~46 ms on the Moto for a blast that breaks glass) is the channel's SECOND frame's
	## (`_run_tail()`), followed by a second remesh when the rims shaped any glass, because the glass mesh reads the shaped
	## cells they record: the pane is gone in the crater frame and its shards arrive a frame later.
	var board3d: Node = _board3d()
	## Director, 2026-09-21 (a video of the blast on the Moto): the scorch was arriving BEFORE the crater and the smoke read.
	## It now arrives AFTER the crater is drawn, in steps: the ramp is armed here, `_run_consequence` steps it from `soot_start_s`
	## (0 = right after the commit), and whatever is left after the channel is finished by `_finish_soot`.
	_soot_begin(ramp)
	await _run_consequence(plan, voxel_board, smoke_overlay, tree)
	_run_tail(voxel_board)   ## a channel with nothing scheduled (or shorter than two frames) still owes it
	await _finish_soot(voxel_board, tree, board3d)
	## D-6 — the smoke is all instanced and rising, so the world may resume
	## (Director, 2026-08-29). The light ramp below runs with the agent already
	## unlocked; only the turn advance waits for it to land.
	if consequence_room != null:
		consequence_room.end_blast_lock()

	## D-6 — WAIT FOR THE SMOKE TO CLEAR BEFORE THE LIGHT DERIVE.
	##
	## Director, 2026-08-29: *"Consigo claramente ver o lag pela fumaça, quando
	## aparece 'light landed'. A fumaça dá uma pausinha quando entra. Vamos adiar a
	## luz até o fim mesmo."* `Room.play_consequence_light()` runs
	## `_repaint_voxel_light_buckets()` — the ~202 ms map-wide derive (§7.4) — in
	## one frame, and against drifting smoke that ~12-frame freeze reads as a
	## stutter. Deferring it until the puffs are gone puts the freeze on a still
	## scene, where it is nearly invisible.
	##
	## Not a fix for §7.4 — the derive still costs 202 ms. The real fix is
	## computing the light field in the cook. This just hides it where the Director
	## cannot see it.
	await _wait_for_smoke(smoke_overlay, tree)
	## §7 — the light lands LAST, after the smoke has had its say.
	##
	## ⚠️ AND IT WAITS FOR THE PLUMES ON PURPOSE — Director, 2026-08-28, on being
	## shown that they push the event from 3.2 s to 4.3 s: *"Pode deixar a luz ser
	## atualizada só depois da fumaça mesmo… a mudança de iluminação vai ser
	## assumida como um evento da rodada. Faz parte da dinâmica de turnos, mostrando
	## as consequências de uma ação. Pode manter os 240 frames rodando até a fumaça
	## se dissipar."*
	##
	## So the length is RATIFIED, not an oversight, and a future perf pass must not
	## "fix" it. An attempt to start the light early was built and thrown away here:
	## besides being unwanted, it hid a real defect —
	## `Room.play_consequence_light()` is `-> void`, so calling it without `await`
	## returns `null`, a `if coro != null` guard never closes, and the light was
	## restarted on EVERY frame. The frame probe caught it at once (a dozen `LIGHT`
	## marks, frames at 92-100 ms against the usual 18) and the PICTURE never would
	## have: concurrent light ramps converge on the same final state.
	##
	## AWAITED: `finished` is what clears the controller's only strong reference to
	## this object, and the light runs a coroutine of its own.
	if consequence_room != null and consequence_room.consequence_beat:
		consequence_room.event_probe_beat("LIGHT")
		await consequence_room.play_consequence_light(consequence_delta)
		if board3d != null and is_instance_valid(board3d):
			board3d.on_blast_light(consequence_delta)
	is_done = true
	finished.emit()


## Roadmap A1 (Director, 2026-10-07) — THE DESIGNED HIT-STOP. The strongest grenade (BombDef tag `hit_stop`) commits UNDER its own
## negative flash instead of after it: the heavy frames (cell writes, the crater remesh, then the glass flush and its second remesh)
## land while the screen is inverted, so the hitch reads as the blast's weight. The work is split in two frames on purpose (the
## commit, then `run_hit_stop_tail()`), each held to `hit_stop_ceiling_ms`: a frame past it is reported, never silently accepted.
## Every other blast is unchanged: it commits at `start()`, held to the 100 ms line by the budgets.
var hit_stop: bool = false
var hit_stop_ceiling_ms: float = 200.0
var _committed: bool = false
var _ramp: Array = []


## Beat 2, the commit frame, callable early. Idempotent: `start()` calls it itself when nobody did. Returns the frame's cost in ms.
func commit_under_flash(plan: Dictionary, voxel_board) -> float:
	if _committed:
		return 0.0
	var t0: int = Time.get_ticks_usec()
	## §7.1 — the scorch rides in the commit. The FADE is what arrives afterwards, and it is a plane walk, not a second set of
	## cell writes.
	_writer.soot_clean = false
	_ramp = _collect_soot_ramp(plan, voxel_board)
	_commit_frame(plan, voxel_board)
	_tail_pending = true
	var board3d: Node = _board3d()
	if board3d != null and consequence_delta != null:
		board3d.on_blast_commit(consequence_delta)
	_committed = true
	return _report_hit_stop("commit", t0)


## The glass flush owed by the commit (crack re-cut, shard rims, craze masks, the second remesh), on the flash's next frame.
func run_hit_stop_tail(voxel_board) -> float:
	var t0: int = Time.get_ticks_usec()
	_run_tail(voxel_board)
	return _report_hit_stop("glass tail", t0)


func _report_hit_stop(label: String, since_usec: int) -> float:
	var ms: float = float(Time.get_ticks_usec() - since_usec) / 1000.0
	if hit_stop:
		print("[E-PRESENT] hit-stop %s frame %.2f ms (ceiling %.0f)" % [label, ms, hit_stop_ceiling_ms])
		if ms > hit_stop_ceiling_ms:
			push_warning("[DetonationPresenter] hit-stop %s took %.1f ms, past its %.0f ms ceiling" % [label, ms, hit_stop_ceiling_ms])
	return ms


## How many stray puffs may still be on screen before the light runs — the last
## few fading discs are dim enough that the derive freeze does not read on them.
## `_max_s` is the hard cap: a blast far from material leaves almost no smoke, one
## clipped by walls leaves a lot, and the light must not wait forever on a
## straggler. Both `var` (Rule 1) — tuned on a video.
var light_smoke_slack: int = 4
var light_smoke_max_s: float = 3.5
func _wait_for_smoke(smoke_overlay, tree: SceneTree) -> void:
	if smoke_overlay == null or not smoke_overlay.has_method("smoke_count"):
		return
	var waited: float = 0.0
	while smoke_overlay.smoke_count() > light_smoke_slack and waited < light_smoke_max_s:
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
	if consequence_room != null:
		consequence_room.event_probe_beat("SMOKE CLEAR")
	print("[E-PRESENT] smoke cleared after %.2fs (%d puff(s) left)" % [
		waited, smoke_overlay.smoke_count()])


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
func _commit_frame(plan: Dictionary, voxel_board) -> void:
	var cells: int = 0
	var t0: int = Time.get_ticks_usec()
	for ring in plan.get("destroy", {}).keys():
		for entry: Dictionary in plan["destroy"][ring]:
			cells += _writer.apply("destroy", entry, voxel_board, null)
			for reveal: Dictionary in entry.get("expose", []):
				cells += _writer.apply("expose", reveal, voxel_board, null)
	for kind: String in ["dented", "cracked", "soot"]:
		for ring in plan.get(kind, {}).keys():
			for entry: Dictionary in plan[kind][ring]:
				cells += _writer.apply(kind, entry, voxel_board, null)
	## (`_writer.flush()` is `_run_tail()`'s now.)
	print("[E-PRESENT] commit frame — %d cell(s) in %.3f ms of apply" % [
		cells, float(Time.get_ticks_usec() - t0) / 1000.0])


## D-3b — THE SCORCH FADES IN OVER A HANDFUL OF FRAMES.
##
## > Director, 2026-08-28: *"daria pra fazer a fuligem entrar com fade in de 4 ou
## > 5 frames?"* — restoring what they asked for on 2026-08-19 (*"a fuligem pode
## > ser processada depois do fato, desde que apareça com fade in, e não de
## > repente"*), which §7.1 had dropped by putting the scorch in the commit.
##
## ⚠️ **THIS IS HALF OF `_fade_in_soot()`, AND THE HALF THAT WAS NEVER THE
## PROBLEM.** That function did two things: a `set_cell()` block that re-placed
## tiles using a `source_id` read during the COOK — §9.11e's writer, 350 cells put
## back on holes the fire had eaten — and then a ladder walk that only writes the
## SOOT PLANE. §3 killed the function for the first half. The commit frame has
## already placed every cell correctly, with live data, so only the ladder is
## needed here and there is no `set_cell()` in it at all.
##
## That is also why it is nearly free: a plane write is a pixel write (PERF-P2b —
## no alternative, no TileSet rebuild, nothing to pre-mint), and one upload per
## frame. The choreographer's own 32-frame version measured at ~17.8 ms/frame,
## which is an idle frame.
##
## The ladder itself is the ratified LOOK, unchanged: faces are lightened by k and
## k walks to zero, so a face landing on tone 0 climbs the whole ladder while one
## landing on tone 3 arrives in a single step — scorch settling rather than a
## uniform dissolve.
var soot_fade_frames: int = 5

## When the scorch starts to darken, counted from the start of the consequence channel, and the time between its steps. SECONDS,
## not frames (a step per N frames would run 4x slower on the Moto than on the desktop). 4 steps (`soot_fade_frames` - 1) of
## 0.075 s: about 0.3 s of darkening that starts as soon as the crater is formed (Director, 2026-09-21: shorter, and no need to wait for the smoke). Both `var`: the Director tunes them on a video.
var soot_start_s: float = 0.0
var soot_step_s: float = 0.075

var _soot_ramp: Array = []
var _soot_next_k: int = 1
var _soot_next_t: float = 0.0
var _channel_elapsed: float = 0.0


## Which cells will ramp, and what to. Runs BEFORE the commit, because it has to
## read the scorch each cell carries NOW.
##
## ⚠️ §9.11a — a cell whose scorch is ALREADY its target is excluded, and this is
## not an optimisation. The soot wave admits cells whose light bucket moved with
## their scorch unchanged; ramping those means writing them clean and walking them
## back, which is the flash the Director reported on 2026-08-23. Excluding them
## here is also what keeps them out of `soot_ramp_cells`, so the commit writes them
## at their real value and they never go clean at all.
## R3D-LIGHT - the ramp collection (30 ms of the Moto's presenter-start frame) done ahead, a few ms a frame, while the fuse and
## the flash frames play: `prepare()` flattens the entries, `prepare_step()` notes some of them, and `_collect_soot_ramp()`
## finishes whatever is left and returns the result. Nothing writes a soot plane between the two, so the answer is the one
## the commit frame would have computed.
var _prep: Dictionary = {}


func prepare(plan: Dictionary) -> void:
	var entries: Array = []
	for kind: String in ["dented", "cracked", "soot"]:
		for ring in plan.get(kind, {}).keys():
			entries.append_array(plan[kind][ring])
	for ring in plan.get("destroy", {}).keys():
		for entry: Dictionary in plan["destroy"][ring]:
			entries.append_array(entry.get("expose", []))
	_prep = {"entries": entries, "i": 0, "out": [], "cells": {}}
	## The consequence channel's schedule (a delay per VFX entry, then the sort by it) was built in the frame the channel
	## starts: ~400-530 entries, a measurable part of the Moto's presenter-start frame. Same treatment as the ramp.
	var src: Array = []
	var per_kind: Dictionary = {}
	for kind: String in ["smoke", "ember", "debris"]:
		for ring in plan.get(kind, {}).keys():
			for entry: Dictionary in plan[kind][ring]:
				src.append([kind, entry])
				per_kind[kind] = int(per_kind.get(kind, 0)) + 1
	_sched_prep = {"src": src, "i": 0, "out": [], "per_kind": per_kind}


var _sched_prep: Dictionary = {}

## The commit's glass flush, still owed (see `start()`).
var _tail_pending: bool = false


func _run_tail(voxel_board) -> void:
	if not _tail_pending:
		return
	_tail_pending = false
	var shaped: int = _writer.flush(voxel_board)
	var board3d: Node = _board3d()
	if shaped > 0 and board3d != null and consequence_delta != null:
		board3d.on_blast_commit(consequence_delta)

## Microseconds of one frame the consequence channel may spend dispatching VFX entries. `var` (Rule 1).
var effect_budget_us: int = 8000


func prepare_step(voxel_board, budget_usec: int) -> void:
	var t0: int = Time.get_ticks_usec()
	if not _prep.is_empty():
		var entries: Array = _prep["entries"]
		var i: int = _prep["i"]
		while i < entries.size():
			_note_ramp(entries[i], voxel_board, _prep["out"], _prep["cells"])
			i += 1
			if budget_usec > 0 and (i & 63) == 0 and Time.get_ticks_usec() - t0 >= budget_usec:
				break
		_prep["i"] = i
		if i < entries.size():
			return
	if not _sched_prep.is_empty():
		var src: Array = _sched_prep["src"]
		var out: Array = _sched_prep["out"]
		var j: int = _sched_prep["i"]
		while j < src.size():
			var pair: Array = src[j]
			out.append([_delay_for(pair[1]), pair[0], pair[1]])
			j += 1
			if budget_usec > 0 and (j & 63) == 0 and Time.get_ticks_usec() - t0 >= budget_usec:
				break
		_sched_prep["i"] = j


func _collect_soot_ramp(plan: Dictionary, voxel_board) -> Array:
	## DIAG-19 (DEVICE_DIAGNOSTICS §15.2) — `NO_SOOT=1`, an instrument: the commit writes
	## every scorch clean (`soot_clean`, the writer's own switch) and there is no fade.
	## The cells still get their light alternatives — only the scorch is priced.
	if _no_soot():
		_writer.soot_clean = true
		_writer.soot_ramp_cells = {}
		return []
	if not _prep.is_empty():
		prepare_step(voxel_board, 0)
		var done: Array = _prep["out"]
		_writer.soot_ramp_cells = _prep["cells"]
		_prep = {}
		return done
	var out: Array = []
	var ramp_cells: Dictionary = {}
	for kind: String in ["dented", "cracked", "soot"]:
		for ring in plan.get(kind, {}).keys():
			for entry: Dictionary in plan[kind][ring]:
				_note_ramp(entry, voxel_board, out, ramp_cells)
	for ring in plan.get("destroy", {}).keys():
		for entry: Dictionary in plan["destroy"][ring]:
			for reveal: Dictionary in entry.get("expose", []):
				_note_ramp(reveal, voxel_board, out, ramp_cells)
	_writer.soot_ramp_cells = ramp_cells
	return out


## The DevFlags NODE, not the global name: this RefCounted is also built by tools
## that run without autoloads, where it simply reads as off.
## DIAG-21 step 2 — the 3D board, once a map is loaded. It follows the same
## three beats the 2D board changes on: the commit frame, the settled soot, the light.
func _board3d() -> Node:
	if consequence_room == null or not consequence_room.has_method("board3d"):
		return null
	return consequence_room.board3d()


static func _no_soot() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var flags: Node = tree.root.get_node_or_null("DevFlags") if tree != null else null
	return flags != null and flags.on("NO_SOOT")


func _note_ramp(entry: Dictionary, voxel_board, out: Array,
		ramp_cells: Dictionary) -> void:
	if not entry.has("soot") or not entry.has("level") or not entry.has("cell"):
		return
	var level: int = int(entry["level"])
	var cell: Vector2i = entry["cell"]
	var target: int = int(entry["soot"])
	if voxel_board.cell_soot_at(level, cell) == target:
		return
	ramp_cells[Vector3i(cell.x, cell.y, level)] = true
	out.append([level, cell, VoxelLightField.decode_face_soot(target)])


func _soot_begin(ramp: Array) -> void:
	_soot_ramp = ramp
	_soot_next_k = 1
	_soot_next_t = soot_start_s
	_channel_elapsed = 0.0


## One ladder step, when its time has come. Step 0 is what the commit frame wrote (fully lightened); the last step is the
## settled scorch. Each call writes ONE step, so a slow frame delays the ladder instead of collapsing it into a jump cut.
func _soot_tick(elapsed: float, voxel_board) -> void:
	var steps: int = maxi(soot_fade_frames, 1)
	if _soot_ramp.is_empty() or _soot_next_k >= steps or elapsed < _soot_next_t:
		return
	if _soot_next_k == 1 and consequence_room != null:
		consequence_room.event_probe_beat("SOOT FADE")
	var lighten: int = steps - 1 - _soot_next_k
	for row: Array in _soot_ramp:
		voxel_board._write_cell_soot(int(row[0]), row[1],
			VoxelLightField.encode_face_soot(DetonationEntryWriter.lightened(row[2], lighten)))
		voxel_board.note_external_write(int(row[0]), row[1])
	## R3D-6: the 3D board reads the plane when it is told to upload it; every step is one upload of the levels the blast touched.
	var board3d: Node = _board3d()
	if board3d != null:
		## The last step also settles the cells no entry carried, before the one upload.
		board3d.on_blast_soot(_settle_soot() if _soot_next_k + 1 >= steps else {})
	_soot_next_k += 1
	_soot_next_t = elapsed + soot_step_s


## The scorch's end: the plane takes the map's tone on every cell the blast stamped (`Room.settle_soot()`), so a cell no wave
## carried does not stay clean while the map says CHARRED. Returns the levels it moved, for the upload. `NO_SOOT` is an
## instrument that writes everything clean on purpose.
func _settle_soot() -> Dictionary:
	if consequence_room == null or _no_soot():
		return {}
	return consequence_room.settle_soot()


## Whatever the channel did not get to: the ladder finishes on its own clock. An empty ramp (nothing sooted, or `NO_SOOT`)
## still tells the 3D board once, as before.
func _finish_soot(voxel_board, tree: SceneTree, board3d: Node) -> void:
	var steps: int = maxi(soot_fade_frames, 1)
	var t0: int = Time.get_ticks_usec()
	var clock: float = _channel_elapsed
	while not _soot_ramp.is_empty() and _soot_next_k < steps:
		await tree.process_frame
		if not is_instance_valid(voxel_board):
			return
		clock += tree.root.get_process_delta_time()
		_soot_tick(clock, voxel_board)
	if board3d != null and is_instance_valid(board3d):
		if _soot_ramp.is_empty():
			board3d.on_blast_soot(_settle_soot())
		else:
			## The ladder's last tick settles and uploads; this catches a fade with no tick at all (`soot_fade_frames` 1).
			var moved: Dictionary = _settle_soot()
			if not moved.is_empty():
				board3d.on_blast_soot(moved)
	print("[E-PRESENT] soot fade — %d cell(s) in %d step(s) from %.2fs, finished %.2fs after the channel (%.2f ms in the tail)" % [
		_soot_ramp.size(), steps - 1, soot_start_s, maxf(clock - _channel_elapsed, 0.0), float(Time.get_ticks_usec() - t0) / 1000.0])


## Beat 3 — the channel. Every VFX entry gets a release time; frames pass; each
## is dispatched when its time comes. **No frame here writes a cell**, which is
## what makes a dropped one cosmetic instead of a desync.
func _run_consequence(plan: Dictionary, voxel_board, smoke_overlay,
		tree: SceneTree) -> void:
	var scheduled: Array = []
	var per_kind: Dictionary = {}
	if not _sched_prep.is_empty():
		prepare_step(voxel_board, 0)
		scheduled = _sched_prep["out"]
		per_kind = _sched_prep["per_kind"]
		_sched_prep = {}
	else:
		for kind: String in ["smoke", "ember", "debris"]:
			for ring in plan.get(kind, {}).keys():
				for entry: Dictionary in plan[kind][ring]:
					scheduled.append([_delay_for(entry), kind, entry])
					per_kind[kind] = int(per_kind.get(kind, 0)) + 1
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
		## VoxelBoard it paints into is a child of the Room, and `load_map()`
		## builds a new one. Same guard, same reason as the choreographer's.
		if not is_instance_valid(voxel_board):
			push_warning("[DetonationPresenter] renderer went away mid-sequence (map reload?) — abandoned with %d of %d effect(s) undispatched" % [scheduled.size() - next, scheduled.size()])
			return
		frames += 1
		## The tail's commit uploads the cell planes; a soot step in the SAME frame uploads them again, and that second upload
		## waited ~375 ms on the Moto (the tail + tick in one frame, first version). The step goes to the next frame.
		var ran_tail: bool = false
		if frames == 2 and _tail_pending:
			_run_tail(voxel_board)
			ran_tail = true
		elapsed += tree.root.get_process_delta_time()
		if not ran_tail:
			_soot_tick(elapsed, voxel_board)
		_channel_elapsed = elapsed
		var _disp0: int = Time.get_ticks_usec()
		while next < scheduled.size() and float(scheduled[next][0]) <= elapsed:
			_writer.apply(String(scheduled[next][1]), scheduled[next][2],
				voxel_board, smoke_overlay)
			next += 1
			## A frame that is due for hundreds of effects spends a few ms and hands the rest to the next one: these are
			## VFX (nothing here writes a cell), and 403 puffs at once were 32 ms of the Moto's frame (R3D-LIGHT).
			if (next & 15) == 0 and Time.get_ticks_usec() - _disp0 >= effect_budget_us:
				break
	## Per kind, because "N effects" cannot answer the question D-4 is tuned on —
	## a smoke count that changed and an ember count that did not look identical in
	## one total, and the per-material thinning moves exactly one of them.
	print("[E-PRESENT] consequence — %d effect(s) %s over %d frame(s), last at %.2fs (elapsed %.2fs, %d ms wall)" % [
		scheduled.size(), per_kind, frames, last_delay, elapsed,
		Time.get_ticks_msec() - _t0_ms])


## §4.2's formula. Every input is already on the entry — `r` is the radius in
## VOXELS the plan builder computed, and `level` is the cell's own — so this adds
## no walk and no second pass over the map.
##
## The ember's OWN `delay` field is untouched and still forwarded to the overlay
## by the writer: that one is E-EMBER-02's upward creep, an intra-column stagger,
## a different axis from this radial one. Adding them is intended.
func _delay_for(entry: Dictionary) -> float:
	## D-4b — an explicit release time wins, and is NOT clamped to
	## `consequence_max_seconds`. The plumes are the one effect whose whole point is
	## to outlast the blast (*"persistindo pelo menos mais 1 segundo depois da
	## explosão"*), so the cap that keeps the radial channel snappy would delete
	## exactly the thing they exist for. The channel's loop runs until everything is
	## dispatched, so the beat simply lasts as long as the last column.
	if entry.has("at"):
		return maxf(float(entry["at"]), 0.0)
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
