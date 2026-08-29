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
	## §7.1 — the scorch rides in the commit. The FADE (below) is what arrives
	## afterwards, and it is a plane walk, not a second set of cell writes.
	_writer.soot_clean = false
	var ramp: Array = _collect_soot_ramp(plan, voxel_renderer)
	_commit_frame(plan, voxel_renderer)
	await _fade_soot_plane(ramp, voxel_renderer, tree)
	await _run_consequence(plan, voxel_renderer, smoke_overlay, tree)
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


## Which cells will ramp, and what to. Runs BEFORE the commit, because it has to
## read the scorch each cell carries NOW.
##
## ⚠️ §9.11a — a cell whose scorch is ALREADY its target is excluded, and this is
## not an optimisation. The soot wave admits cells whose light bucket moved with
## their scorch unchanged; ramping those means writing them clean and walking them
## back, which is the flash the Director reported on 2026-08-23. Excluding them
## here is also what keeps them out of `soot_ramp_cells`, so the commit writes them
## at their real value and they never go clean at all.
func _collect_soot_ramp(plan: Dictionary, voxel_renderer) -> Array:
	var out: Array = []
	var ramp_cells: Dictionary = {}
	for kind: String in ["dented", "cracked", "soot"]:
		for ring in plan.get(kind, {}).keys():
			for entry: Dictionary in plan[kind][ring]:
				_note_ramp(entry, voxel_renderer, out, ramp_cells)
	for ring in plan.get("destroy", {}).keys():
		for entry: Dictionary in plan["destroy"][ring]:
			for reveal: Dictionary in entry.get("expose", []):
				_note_ramp(reveal, voxel_renderer, out, ramp_cells)
	_writer.soot_ramp_cells = ramp_cells
	return out


func _note_ramp(entry: Dictionary, voxel_renderer, out: Array,
		ramp_cells: Dictionary) -> void:
	if not entry.has("soot") or not entry.has("level") or not entry.has("cell"):
		return
	var level: int = int(entry["level"])
	var cell: Vector2i = entry["cell"]
	var target: int = int(entry["soot"])
	if voxel_renderer.cell_soot_at(level, cell) == target:
		return
	ramp_cells[Vector3i(cell.x, cell.y, level)] = true
	out.append([level, cell, VoxelLightField.decode_face_soot(target)])


func _fade_soot_plane(ramp: Array, voxel_renderer, tree: SceneTree) -> void:
	if ramp.is_empty():
		return
	if consequence_room != null:
		consequence_room.event_probe_beat("SOOT FADE")
	var steps: int = maxi(soot_fade_frames, 1)
	var t0: int = Time.get_ticks_usec()
	## Starts at step 1: step 0 is "fully lightened", which the commit frame has
	## already written for exactly these cells (`soot_ramp_cells`). Repeating it
	## would spend a frame drawing what is already on screen.
	for step: int in range(1, steps):
		await tree.process_frame
		if not is_instance_valid(voxel_renderer):
			return
		var lighten: int = steps - 1 - step
		for row: Array in ramp:
			voxel_renderer._write_cell_soot(int(row[0]), row[1],
				VoxelLightField.encode_face_soot(
					DetonationEntryWriter.lightened(row[2], lighten)))
			voxel_renderer.note_external_write(int(row[0]), row[1])
		voxel_renderer.flush_cell_soot()
	print("[E-PRESENT] soot fade — %d cell(s) over %d frame(s), %.2f ms of writes" % [
		ramp.size(), steps - 1, float(Time.get_ticks_usec() - t0) / 1000.0])


## Beat 3 — the channel. Every VFX entry gets a release time; frames pass; each
## is dispatched when its time comes. **No frame here writes a cell**, which is
## what makes a dropped one cosmetic instead of a desync.
func _run_consequence(plan: Dictionary, voxel_renderer, smoke_overlay,
		tree: SceneTree) -> void:
	var scheduled: Array = []
	var per_kind: Dictionary = {}
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
