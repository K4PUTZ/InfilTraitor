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

## E-ORGANIC-01 (Director, 2026-08-09): "não precisamos fixar as 15 waves,
## queremos que seja o mais orgânico e natural possível."
##
## The wave TABLE below still defines the ORDER — that ordering is the blast's
## dramatic shape and nothing here changes it. What is gone is the idea that a
## wave is a unit of TIME. A wave was whatever cells fell in one (kind, ring)
## bucket, and buckets are wildly uneven: destroy ring 0 on a real PLAYGROUND
## blast is 872 cells while destroy ring 2 is 4. The sequence is paced by WORK
## now — one flat queue of single-cell steps, drained against a deadline.
##
## THE MEASUREMENT THAT SHAPED THIS, because it inverted the obvious answer:
## the cost of this sequence is NOT per cell, it is **per frame that writes to a
## TileMapLayer at all**. Measured on one real PLAYGROUND blast (2072 steps),
## same blast each time, varying only the per-frame budget:
##
##     all 2072 in one frame ....... 26 ms total,  24.3 ms apply
##     600 cells/frame ............ 509 ms total,  ~4.4 ms apply per frame
##     160 cells/frame ............ 496 ms total,  ~2.2 ms apply per frame
##      60 cells/frame ............ 485 ms total,  ~0.9 ms apply per frame
##
## A frame costs ~120 ms whether it writes 60 cells or 600 — that is Godot
## rebuilding the dirtied layers, and it is paid once per frame, not once per
## cell. So a naive "spread the work thinner" budget makes the blast three to
## twenty times SLOWER while making each individual frame look cheap in the log.
## Anyone tuning this must read the totals, never the apply column.
##
## Hence: pace against a DEADLINE with catch-up, the same ceiling/floor shape the
## per-wave scheduler used, but at cell granularity. On a healthy frame budget
## the blast spreads into a dozen fine steps and reads as propagation; when
## frames are expensive the quota drags the sequence forward instead of letting
## it stretch. Total time is bounded by `sequence_ms` either way.
##
## CAVEAT, stated because the numbers above came from the off-screen capture
## harness, which renders the blast at ~8 fps: the ~120 ms per-frame figure is
## almost certainly much smaller on a real windowed run, and the SHAPE of the
## conclusion (per-frame, not per-cell) is what to trust, not the constant.
var sequence_ms: float = 240.0

## Floor on progress, so a fast machine still subdivides rather than dumping the
## whole quota at once, and so the queue always advances even at elapsed 0.
var min_cells_per_frame: int = 24

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


## Starts the sequence. `plan` is a real DetonationPlanBuilder.build_plan()
## result; `voxel_renderer`/`smoke_overlay` are the real, live instances this
## sequence paints into; `tree` is the SceneTree its frames come from.
func start(plan: Dictionary, voxel_renderer, smoke_overlay, tree: SceneTree) -> void:
	_t0_ms = Time.get_ticks_msec()
	_waves_done = 0
	_run_queue(flatten_plan(plan), voxel_renderer, smoke_overlay, tree)


## The plan, flattened into ONE ordered queue of single-cell steps, in WAVE_TABLE
## order. Static and pure so the ordering can be asserted directly in a selftest.
##
## `expose` entries are broken out as their own steps rather than riding inside
## the destroy entry that carries them. That is the single most important line in
## this function: one destroy entry can hold 628 exposure reveals, so leaving
## them nested would put 628 `set_cell`s into one indivisible step and rebuild the
## exact spike the budget exists to prevent. They still land immediately after
## the destruction that opened them, so §2's "a crater has no bottom until its
## own wave fires" still holds — the reveal is now one step behind the hole
## instead of inside it.
static func flatten_plan(plan: Dictionary) -> Array:
	var queue: Array = []
	for pair in WAVE_TABLE:
		var kind: String = pair[0]
		var ring: int = pair[1]
		for entry in plan.get(kind, {}).get(ring, []):
			queue.append({"kind": kind, "ring": ring, "entry": entry})
			if kind == "destroy":
				for exp in entry.get("expose", []):
					queue.append({"kind": "expose", "ring": ring, "entry": exp})
	return queue


## Drains the queue against the deadline above. The `await` keeps this
## coroutine (and therefore `self`) alive across the sequence, but that is NOT a
## substitute for the caller's own strong reference: the header's ownership note
## still holds, and TestZoneController still holds `_active_choreographer`. If the
## tree goes away mid-sequence (map reload, quit), `await tree.process_frame`
## simply never resumes and the rest is dropped — correct for a purely visual
## replay of damage already applied to the Voxel state.
func _run_queue(queue: Array, voxel_renderer, smoke_overlay, tree: SceneTree) -> void:
	var next_step := 0
	var frame_index := 0
	while next_step < queue.size():
		if frame_index > 0:
			await tree.process_frame
		var elapsed_ms: float = float(Time.get_ticks_msec() - _t0_ms)
		var target: int = cells_due_now(next_step, elapsed_ms, sequence_ms,
			min_cells_per_frame, queue.size())
		var apply_start_us := Time.get_ticks_usec()
		var applied := 0
		while next_step < target:
			var step: Dictionary = queue[next_step]
			_apply_entry(step["kind"], step["entry"], voxel_renderer, smoke_overlay)
			next_step += 1
			applied += 1
		_flush(voxel_renderer)
		var apply_ms: float = float(Time.get_ticks_usec() - apply_start_us) / 1000.0
		print("[E-WAVE] frame %d cells=%d/%d elapsed=%dms apply=%.3fms" %
			[frame_index + 1, next_step, queue.size(), Time.get_ticks_msec() - _t0_ms, apply_ms])
		wave_applied.emit(frame_index, "queue", 0, applied)
		frame_index += 1
	_waves_done = frame_index
	finished.emit()


## How far into the queue this frame should get, as an EXCLUSIVE end index.
## Pure and static so the pacing rule is testable without controlling frame
## timing — the same reason its per-wave predecessor was.
##
## The quota is where the sequence SHOULD be by now if it were spread evenly
## across `sequence_ms`; `min_cells` is the floor that guarantees progress on the
## first frame (elapsed 0) and keeps a fast machine subdividing. Past
## `sequence_ms` the quota is the whole queue, so the blast finishes on time
## regardless of how expensive the frames turned out to be.
static func cells_due_now(next_step: int, elapsed_ms: float, sequence_ms: float,
		min_cells: int, total: int) -> int:
	if total <= 0:
		return 0
	var quota: int = total
	if sequence_ms > 0.0 and elapsed_ms < sequence_ms:
		quota = int(ceil(float(total) * (elapsed_ms / sequence_ms)))
	return clampi(maxi(quota, next_step + maxi(min_cells, 1)), 0, total)


## Applies EVERY entry of one (kind, ring) bucket at once. No longer the
## real-time path — E-ORGANIC-01 replaced that with the budgeted queue above —
## but kept as the honest "apply this whole wave now" operation the selftest
## drives to check each kind's write logic in isolation, and the one place the
## per-wave `wave_applied` signal shape still makes sense.
func _apply_wave(index: int, kind: String, ring: int, plan: Dictionary,
		voxel_renderer, smoke_overlay) -> void:
	var apply_start_us := Time.get_ticks_usec()
	var count := 0
	for entry in plan.get(kind, {}).get(ring, []):
		count += _apply_entry(kind, entry, voxel_renderer, smoke_overlay)
		if kind == "destroy":
			for exp in entry.get("expose", []):
				count += _apply_entry("expose", exp, voxel_renderer, smoke_overlay)
	_flush(voxel_renderer)
	var apply_ms: float = float(Time.get_ticks_usec() - apply_start_us) / 1000.0
	print("[E-WAVE] wave %d kind=%s ring=%d cells=%d apply=%.3fms" %
		[index + 1, kind, ring, count, apply_ms])
	wave_applied.emit(index, kind, ring, count)


## ONE cell's real work — the only place in this whole pipeline that ever calls
## `layer.set_cell()`/`erase_cell()`/`SmokeSparkOverlay.add_smoke()`. Returns how
## many cells it actually touched (0 when the target layer does not exist), which
## is what both callers above count with.
func _apply_entry(kind: String, entry: Dictionary, voxel_renderer, smoke_overlay) -> int:
	match kind:
		"destroy":
			var layer: TileMapLayer = voxel_renderer.get_layer(entry["level"])
			if layer == null:
				return 0
			layer.erase_cell(entry["cell"])
			return 1
		"expose":
			## §2's exposure fallback (B5). Its own step since E-ORGANIC-01 —
			## see flatten_plan() for why nesting these was the spike.
			var elayer: TileMapLayer = voxel_renderer.get_layer(entry["level"])
			if elayer == null:
				return 0
			voxel_renderer._ensure_light_alt(entry["source_id"], entry["atlas_coords"], entry["alt"])
			elayer.set_cell(entry["cell"], entry["source_id"], entry["atlas_coords"], entry["alt"])
			return 1
		"dented", "cracked", "soot":
			var layer2: TileMapLayer = voxel_renderer.get_layer(entry["level"])
			if layer2 == null:
				return 0
			## _ensure_light_alt() mints the (source_id, atlas_coords, alt)
			## TileData alternative if it doesn't exist yet — the SAME call
			## VoxelRenderer._apply_light_to_layer() makes right before its own
			## set_cell(). Cheap/memoized, not a "lookup" in §2's sense (no
			## resolution decision happens here, the triple already arrived
			## fully resolved).
			voxel_renderer._ensure_light_alt(entry["source_id"], entry["atlas_coords"], entry["alt"])
			layer2.set_cell(entry["cell"], entry["source_id"], entry["atlas_coords"], entry["alt"])
			return 1
		"smoke":
			if smoke_overlay == null:
				return 0
			## E-SMOKE-01: scale and alpha are per-entry, not a flat 1.0 —
			## DetonationPlanBuilder derives both from the voxel's damage tier,
			## its ring, and a per-cell hash (see _append_voxel_smoke()).
			## `blobs` is 0 for the GU-level remainder puffs, which means "use
			## the overlay's own 2-3 range"; only per-voxel puffs pin to 1.
			var puff_color := SMOKE_COLOR
			puff_color.a *= float(entry.get("alpha", 1.0))
			smoke_overlay.add_smoke(entry["world_pos"], puff_color,
				float(entry.get("scale", 1.0)), entry["duration"],
				int(entry.get("blobs", 0)))
			return 1
	return 0


## GPU-UPLOAD-01 (2026-08-08): every dented/cracked/soot entry's
## source_id/atlas_coords was resolved by DetonationPlanBuilder against
## DamageVariantBaker's pre-bake OR live-composited on the spot — either way it
## was written through DamageCompositeCache.store(), which blits into a CPU-side
## Image and marks the page dirty but leaves the GPU texture upload for
## flush_dirty_pages() (that class's own doc comment). This choreographer is the
## ONLY place a plan ever reaches set_cell() (this file's own header), and it
## never called that flush — every real detonation's marks rendered whatever the
## page texture already held (stale content, or nothing), unless some UNRELATED
## event happened to flush the same page first. Root-caused via
## damage_gallery_debug.gd hitting the identical gap directly.
##
## Called once per FRAME now rather than once per wave (E-ORGANIC-01) — same
## contract, fewer calls, and still a cheap no-op when nothing composited
## (flush_dirty_pages() checks an empty dirty-page set itself).
func _flush(voxel_renderer) -> void:
	voxel_renderer.flush_damage_composite_pages()

