## DetonationChoreographer — EXPLOSION_REBUILD_MASTER_PLAN Task 5 (E-WAVE).
##
## Plays back one DetonationPlanBuilder.build_plan() result as the real
## 15-wave sequence from §1's table, at `wave_interval_ms` (40, per Q5) apart.
## This is the ONLY class that ever turns a plan entry into a real
## `layer.set_cell()`/`erase_cell()` call — every value it applies was already
## fully resolved during Task 4's pre-compute pass, so a wave here is exactly
## what §2 promises: no compositing, no lookup, no light rebuild, no
## allocation beyond the trivial per-cell dictionary reads.
##
## §6.2 used to read: "Waves are scheduled on absolute elapsed time from the
## flash, so a slow wave never delays the next" — 15 independent SceneTreeTimers
## fired from start() at once. **Superseded 2026-08-08 by the Director's own
## cadence call: "vamos reduzir mais, até no máximo 1 frame por wave."**
##
## A timer cannot express that. At 20 ms on a 16.67 ms frame budget the timers
## did not land one per frame — they clumped (measured: waves 1-8 all inside one
## 14 ms window, then a 237 ms gap before wave 9), because each fires on the
## first frame past its own absolute deadline and the process frame rate does not
## divide 20 ms evenly. Driving the sequence off `process_frame` instead makes
## "one wave per frame" exactly true, removes the clumping, and makes the whole
## thing 15 frames long regardless of frame rate.
##
## What that trades away, stated plainly: a slow wave DOES now delay the next
## one, which is precisely what the old absolute-time scheduling existed to
## prevent. That is acceptable here and only here — the measured worst wave is
## wave 1 at ~11 ms, and every other wave is under 2 ms (see the `[E-WAVE]` log),
## so a wave overrunning a frame is a performance bug to fix at the source rather
## than a case to schedule around.
##
## Extends RefCounted, not Node: nothing here needs to be in the scene tree
## itself — `tree` (the SceneTree) is passed in once, to await its frames.
##
## The caller MUST keep its own strong reference to the instance for the
## whole ~600 ms sequence. Measured, not assumed (2026-08-07, real capture):
## a bound Callable held only by a SceneTreeTimer's `timeout` connection was
## NOT enough to keep this RefCounted alive in practice — every one of the
## 15 scheduled timers printed its own creation line, but not one `timeout`
## ever fired, because `detonate_active()`'s local `choreographer` var was
## the sole reference and it went out of scope the instant that function
## returned. Fixed by TestZoneController holding `_active_choreographer`
## (cleared via this class's own `finished` signal) — any other caller needs
## the same explicit ownership, not a shortcut through a local variable.
class_name DetonationChoreographer
extends RefCounted

## Cadence. Q5 confirmed 40 ms on 2026-08-06 before any of it had been seen
## moving; the Director halved it to 20 ms and then, the same session, to "no
## máximo 1 frame por wave". 16 ms is one wave per frame at 60 fps — the ceiling
## the Director asked for — while staying a real deadline, which is what keeps
## the sequence from STRETCHING when the frame rate drops (see _run_waves).
## `var`, not `const` (Rule 1).
var wave_interval_ms: float = 16.0

## §1 step 10's table, inner rings first — the one authoritative order.
## [kind, ring] pairs; kind indexes directly into the plan's own top-level keys.
const WAVE_TABLE: Array = [
	["destroy", 0], ["destroy", 1], ["destroy", 2],
	["dented", 0], ["dented", 1],
	["cracked", 1], ["cracked", 2],
	["smoke", 0], ["smoke", 1], ["smoke", 2], ["smoke", 3],
	["soot", 0], ["soot", 1], ["soot", 2], ["soot", 3],
]

## The DetonationPlan's own smoke entries carry no material (§6.1's literal
## shape — {world_pos, duration, scale} only, Task 4's own documented
## simplification: a blast's own smoke reads as generic ash/dust regardless
## of which wall it came from, unlike VFX-01's per-voxel material-tinted
## puffs). One flat color for every ring; Task 6's tuning pass is where this
## gets a real look if the Director wants ring-dependent tinting.
## E-SMOKE-01 (2026-08-08): lightened from Color(0.35, 0.35, 0.35, 0.6). At 0.35
## grey the puffs were dark smoke drawn over an already-sooted crater — measured,
## not eyeballed: a real capture mid-sequence differed from the same frame after
## the smoke had died on 1.1% of pixels at mean delta 12/255, i.e. present in the
## overlay and invisible on screen. Ash reads against both the dark crater and
## the light concrete around it, which is the whole span this smoke covers.
## The alpha is deliberately LOW. SmokeSparkOverlay draws each blob as a flat
## `draw_circle`, so at 0.8 the 274 ring-0 puffs read as a heap of hard-edged
## discs rather than smoke (real capture, 2026-08-08). Per-voxel smoke inverts
## the economics the old one-puff-per-GU model was tuned for: density now comes
## from OVERLAP, so each puff has to be faint enough that no single disc is
## legible on its own. Raising this back up is the wrong lever for "more smoke" —
## widen SMOKE_JITTER or lift the tier intensities instead.
const SMOKE_COLOR := Color(0.62, 0.60, 0.57, 0.2)

signal wave_applied(index: int, kind: String, ring: int, cell_count: int)
signal finished()

var _t0_ms: int = 0
var _waves_done: int = 0


## Schedules all 15 waves. `plan` is a real DetonationPlanBuilder.build_plan()
## result; `voxel_renderer`/`smoke_overlay` are the real, live instances this
## sequence paints into; `tree` is the SceneTree the timers run on (room.
## get_tree()).
func start(plan: Dictionary, voxel_renderer, smoke_overlay, tree: SceneTree) -> void:
	_t0_ms = Time.get_ticks_msec()
	_waves_done = 0
	_run_waves(plan, voxel_renderer, smoke_overlay, tree)


## The Director's cap — "no máximo 1 frame por wave" — read as a CEILING on how
## long a wave may wait, which is what it literally says. Two rules, together:
##
##   · at least one wave per frame, so no wave ever waits two frames;
##   · plus every wave whose absolute deadline (`i * wave_interval_ms` from t=0)
##     has already passed, so a slow frame does not push the whole sequence back.
##
## The second rule is what the first one alone gets wrong, and it was measured,
## not reasoned: a pure one-wave-per-frame loop ran the 15 waves in 1111 ms in
## the off-screen capture process (~9 fps there), because frame-locking hands the
## sequence's duration to the frame rate. With the deadline in place the same run
## finishes in roughly its target time at ANY frame rate — 60 fps spends about one
## wave per frame, a 10 fps frame simply flushes several at once.
##
## It also restores what §6.2's original absolute-time scheduling was protecting
## ("a slow wave never delays the next"), which a frame-chained loop had given up.
##
## Wave 0 lands on the calling frame: the blast's first destruction is
## simultaneous with the white flash that triggered it, not one frame after.
##
## The `await` keeps this coroutine (and therefore `self`) alive across the
## sequence, but that is NOT a substitute for the caller's own strong reference:
## the header's ownership note still holds, and TestZoneController still holds
## `_active_choreographer`. If the tree goes away mid-sequence (map reload,
## quit), `await tree.process_frame` simply never resumes and the remaining waves
## are dropped — correct behaviour for a purely visual replay of damage that has
## already been applied to the Voxel state.
func _run_waves(plan: Dictionary, voxel_renderer, smoke_overlay, tree: SceneTree) -> void:
	var next_wave := 0
	while next_wave < WAVE_TABLE.size():
		if next_wave > 0:
			await tree.process_frame
		var due := waves_due_now(next_wave, float(Time.get_ticks_msec() - _t0_ms),
			wave_interval_ms, WAVE_TABLE.size())
		while next_wave < due:
			_apply_wave(next_wave, WAVE_TABLE[next_wave][0], WAVE_TABLE[next_wave][1],
				plan, voxel_renderer, smoke_overlay)
			next_wave += 1


## How many waves this frame should apply, as an EXCLUSIVE end index: apply
## `next_wave .. return-1`. Pure and static so the cadence rule can be tested
## directly (detonation_choreographer_selftest) instead of only through a real
## 15-frame sequence whose timing a headless run cannot control.
##
## Always at least one wave — that is the Director's ceiling, "no máximo 1 frame
## por wave", i.e. no wave ever waits two frames. Then every further wave whose
## absolute deadline has already passed, which is the floor that stops a slow
## frame from pushing the rest of the sequence back.
static func waves_due_now(next_wave: int, elapsed_ms: float, interval_ms: float, total: int) -> int:
	var due: int = mini(next_wave + 1, total)
	if interval_ms <= 0.0:
		return total   ## no cadence at all — the whole sequence is due immediately
	while due < total and float(due) * interval_ms <= elapsed_ms:
		due += 1
	return due


## One wave's real work — the only place in this whole pipeline that ever
## calls `layer.set_cell()`/`erase_cell()`/`SmokeSparkOverlay.add_smoke()`.
func _apply_wave(index: int, kind: String, ring: int, plan: Dictionary,
		voxel_renderer, smoke_overlay) -> void:
	var apply_start_us := Time.get_ticks_usec()
	var count := 0
	match kind:
		"destroy":
			for entry in plan["destroy"].get(ring, []):
				var layer: TileMapLayer = voxel_renderer.get_layer(entry["level"])
				if layer != null:
					layer.erase_cell(entry["cell"])
					count += 1
				## §2's exposure fallback (B5) rides on the SAME wave that
				## opened the hole — the reveal and the destruction land in
				## the same frame, matching "a crater has no bottom until its
				## own wave fires."
				for exp in entry.get("expose", []):
					var elayer: TileMapLayer = voxel_renderer.get_layer(exp["level"])
					if elayer != null:
						voxel_renderer._ensure_light_alt(exp["source_id"], exp["atlas_coords"], exp["alt"])
						elayer.set_cell(exp["cell"], exp["source_id"], exp["atlas_coords"], exp["alt"])
						count += 1
		"dented", "cracked", "soot":
			for entry in plan[kind].get(ring, []):
				var layer: TileMapLayer = voxel_renderer.get_layer(entry["level"])
				if layer == null:
					continue
				## _ensure_light_alt() mints the (source_id, atlas_coords,
				## alt) TileData alternative if it doesn't exist yet — the
				## SAME call VoxelRenderer._apply_light_to_layer() makes
				## right before its own set_cell(). Cheap/memoized, not a
				## "lookup" in §2's sense (no resolution decision happens
				## here, the triple already arrived fully resolved).
				voxel_renderer._ensure_light_alt(entry["source_id"], entry["atlas_coords"], entry["alt"])
				layer.set_cell(entry["cell"], entry["source_id"], entry["atlas_coords"], entry["alt"])
				count += 1
		"smoke":
			if smoke_overlay != null:
				for entry in plan["smoke"].get(ring, []):
					## E-SMOKE-01: scale and alpha are now per-entry, not the flat
					## 1.0 this used to pass — DetonationPlanBuilder derives both
					## from the voxel's damage tier, its ring, and a per-cell hash
					## (see _append_voxel_smoke()). `blobs` is 0 for the GU-level
					## remainder puffs, which means "use the overlay's own 2-3
					## range" — only the per-voxel puffs pin themselves to 1.
					var puff_color := SMOKE_COLOR
					puff_color.a *= float(entry.get("alpha", 1.0))
					smoke_overlay.add_smoke(entry["world_pos"], puff_color,
						float(entry.get("scale", 1.0)), entry["duration"],
						int(entry.get("blobs", 0)))
					count += 1

	## GPU-UPLOAD-01 (2026-08-08): every dented/cracked/soot entry's
	## source_id/atlas_coords was resolved by DetonationPlanBuilder against
	## DamageVariantBaker's pre-bake OR live-composited on the spot — either
	## way it was written through DamageCompositeCache.store(), which blits
	## into a CPU-side Image and marks the page dirty but leaves the GPU
	## texture upload for flush_dirty_pages() (that class's own doc comment).
	## This choreographer is the ONLY place a plan ever reaches set_cell()
	## (this file's own header), and it never called that flush — every real
	## detonation's dented/cracked/soot marks rendered whatever the page
	## texture already held (stale content from a previous flush, or nothing
	## at all), never what was actually composited, unless some UNRELATED
	## event happened to flush the same page first (e.g. a bullet fired
	## earlier in the same session). Root-caused 2026-08-08 via
	## damage_gallery_debug.gd hitting the identical gap directly (see that
	## file's own header) — this is the real-gameplay half of the same fix,
	## not a separate bug. Called once per wave, unconditionally: cheap
	## no-op when nothing composited this wave (flush_dirty_pages() checks
	## an empty dirty-page set itself), so "destroy"/"smoke" waves pay
	## nothing extra.
	voxel_renderer.flush_damage_composite_pages()

	var apply_ms: float = float(Time.get_ticks_usec() - apply_start_us) / 1000.0
	var elapsed_ms: int = Time.get_ticks_msec() - _t0_ms
	## The Task 5 gate's own evidence — "measured per-wave ms" — printed for
	## every real detonation, not just a dev capture's own harness.
	print("[E-WAVE] wave %d/%d kind=%s ring=%d cells=%d elapsed=%dms apply=%.3fms" %
		[index + 1, WAVE_TABLE.size(), kind, ring, count, elapsed_ms, apply_ms])
	wave_applied.emit(index, kind, ring, count)

	_waves_done += 1
	if _waves_done == WAVE_TABLE.size():
		finished.emit()
