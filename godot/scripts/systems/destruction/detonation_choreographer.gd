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
##
## ============================================================================
## P-PLAY (PREDICTION_MASTER_PLAN Task 1, 2026-08-09) — THE DEADLINE RULE ABOVE
## IS RETIRED. It is kept in this header because the measurement that produced
## it is still true and still governs; only the conclusion drawn from it was
## wrong.
##
## What the deadline rule actually did, measured on a real PLAYGROUND blast:
##
##     [E-WAVE] frame 1 cells=92/2185   elapsed=13ms   dt=10.0ms   target=92
##     [E-WAVE] frame 2 cells=2149/2185 elapsed=257ms  dt=226.0ms  target=2149
##     [E-WAVE] frame 3 cells=2185/2185 elapsed=385ms  dt=148.0ms  target=2185
##
## **The whole blast was three frames, 2 057 of its 2 185 steps on one of them.**
## `cells_due_now()` derived its quota from `elapsed_ms / sequence_ms`, so a
## single slow frame put `elapsed` past the deadline and the quota became the
## entire queue. The class documented that as a feature ("when frames are
## expensive the quota drags the sequence forward"); the Director saw it as
## "de repente a explosão já está toda construída", and they were right.
##
## It also hid E-RADIAL-01 completely. The radial ordering below is correct and
## has shipped since `04bfed1`, but a front that crosses 2 185 steps inside two
## visible frames is not a front — it is two states.
##
## The rule now: **the front advances by FRAME, never by wall clock.** The blast
## is `front_frames` frames long whatever each frame costs, which is what
## guarantees the Director's "todos os frames bem visíveis, na duração certa".
##
## The trade this makes, stated plainly rather than discovered later: wall-clock
## duration now scales with frame rate — 24 frames is 0.4 s at 60 fps and 1.2 s
## at 20 fps. That is correct for a purely visual sequence (nothing waits on it,
## and a machine rendering at 20 fps is slow at everything), and it is the exact
## property the old rule traded away to keep a wall-clock promise nobody had
## asked for. There is deliberately NO wall-clock cap: adding one re-introduces
## the dump the moment it fires.
## ============================================================================

## How many FRAMES the front takes to travel from the epicentre to the outermost
## step in the queue. The whole pacing rule, and the blast's duration knob.
##
## 24 → 5 (Director, 2026-08-09, on the real thing: "ficou ótima a explosão, mas
## está muito lenta, tem que ter mais ou menos 1/5 dessa duração"). 24 was
## reasoned from 60 fps (≈0.4 s) and that reasoning was wrong in practice, in a
## way this file's own measurements should have predicted: the blast's frames
## are exactly the frames that dirty a TileMapLayer, which are the expensive
## ones. Duration is `front_frames × the cost of a blast frame`, never
## `front_frames × 16.7 ms`, so the real sequence ran far longer than the 60 fps
## arithmetic promised.
##
## Deliberately NOT compensated for by reintroducing a wall-clock term — that is
## the retired rule, and it is what collapsed the blast to 3 frames. If the
## duration needs to track real time, the honest lever is this number.
##
## Smoke is unaffected and stays as it is (Director: "desconsidere a fumaça que
## já está boa"): puffs are emitted as queue steps but each one's lifetime is
## its own, set in DetonationPlanBuilder, so a faster front emits the same cloud
## sooner without shortening it.
var front_frames: int = 5

## Width of one visible band of the expanding front, in voxels. The front's
## radius is snapped DOWN to a multiple of this, so the wave advances in
## discrete steps instead of a continuous smear — the Director's "ondas na água
## de um lago" (2026-08-09), chosen over both a continuous front and a genuine
## second trailing ripple.
##
## This does NOT read as machined rings, because `front_jitter` below already
## scatters each cell up to ±0.45 voxels off the true circle, so a band's edge
## is ragged before it is ever drawn. Bands and jitter are therefore tuned
## together: raising jitter past the band width dissolves the banding entirely.
var band_voxels: float = 1.0

## §1 step 10's table, inner rings first — the one authoritative order.
## [kind, ring] pairs; kind indexes directly into the plan's own top-level keys.
## E-FUME: soot is no longer in this table; it's its own late fade-in step after
## smoke (see _apply_entry's "soot" handler and _run_queue's end-of-sequence).
const WAVE_TABLE: Array = [
	["destroy", 0], ["destroy", 1], ["destroy", 2],
	["dented", 0], ["dented", 1],
	["cracked", 1], ["cracked", 2],
	["smoke", 0], ["smoke", 1], ["smoke", 2], ["smoke", 3],
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
	_run_queue(flatten_plan(plan), voxel_renderer, smoke_overlay, tree, plan)


## E-RADIAL-01 (Director, 2026-08-09): "eu tô achando as waves duras, parece que
## entram em soquinhos por categoria. Seria possível fazer as ondas de destruição
## granularizadas por voxels? De forma que realmente vão se expandindo a partir do
## centro, cada efeito surgindo no seu tempo individual e terminando no círculo
## mais largo?"
##
## Yes, and this is it. The queue is no longer ordered by WAVE_TABLE — it is
## ordered by each cell's own DISTANCE FROM THE EPICENTRE. What the Director was
## seeing was structural: WAVE_TABLE order means every destruction everywhere
## lands, then every dent everywhere, then every crack, then every soot. Four
## blocks by category, exactly the "soquinhos" described, and no amount of pacing
## could hide it because the ORDER itself was categorical.
##
## Sorted by radius, the categories interleave on their own — you get destruction
## near the centre, dents a little further out, cracks and soot at the rim,
## because that is physically where each one IS. A single front expands outward
## and every cell's own effect appears as the front reaches it, ending at the
## widest circle. The category is no longer a schedule; it is just what happens to
## be true at that radius.
##
## WAVE_TABLE survives as the TIE-BREAK ordering (see KIND_RADIUS_BIAS): at the
## same radius, a hole still leads its own scorch.
##
## `expose` entries are broken out as their own steps rather than riding inside
## the destroy entry that carries them — one destroy entry can hold 628 exposure
## reveals, so leaving them nested would put 628 `set_cell`s into one indivisible
## step. Each carries its own radius, so a reveal naturally lands with the
## destruction that opened it rather than needing to be pinned to it.
##
## Static and pure so the ordering can be asserted directly in a selftest.
static func flatten_plan(plan: Dictionary) -> Array:
	var queue: Array = []
	for pair in WAVE_TABLE:
		var kind: String = pair[0]
		var ring: int = pair[1]
		for entry in plan.get(kind, {}).get(ring, []):
			queue.append({"kind": kind, "ring": ring, "entry": entry,
				"sort": _sort_key(kind, entry)})
			if kind == "destroy":
				for exp in entry.get("expose", []):
					queue.append({"kind": "expose", "ring": ring, "entry": exp,
						"sort": _sort_key("expose", exp)})
	queue.sort_custom(func(a, b): return float(a["sort"]) < float(b["sort"]))
	return queue


## Sub-voxel offsets applied to a step's radius so that, at the SAME distance,
## effects still resolve in a sensible order instead of arbitrarily: the hole
## opens, what it exposed appears, the dents and cracks around it register, and
## the scorch settles last. All well under one voxel, so they order simultaneous
## effects without ever letting a category jump the expanding front — which is the
## whole point of sorting by radius in the first place.
const KIND_RADIUS_BIAS: Dictionary = {
	"destroy": -0.60,
	"expose": -0.50,
	"dented": -0.30,
	"cracked": -0.20,
	"smoke": 0.0,
	"soot": 0.40,
}

## How far a single cell may deviate from the true circle, in voxels. Without it
## the front is a perfect expanding ring, which reads as machined rather than as
## an explosion; with it the edge is ragged. Deterministic per cell (FNV-1a, the
## project's standard roll) so two captures of the same blast stay comparable —
## the same reason the camera shake is not randf()-seeded. `static var` because
## flatten_plan() is static, which is what keeps the ordering testable without
## constructing a choreographer.
static var front_jitter: float = 0.9


static func _sort_key(kind: String, entry: Dictionary) -> float:
	var r: float = float(entry.get("r", 0.0))
	var bias: float = float(KIND_RADIUS_BIAS.get(kind, 0.0))
	var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
	## Salted per kind as well as per cell: two different effects on the SAME
	## voxel should not receive the identical wobble, or their bias separation
	## would be all that ever distinguishes them.
	var roll: float = float(FacadeSampler._fnv1a_hash(
		"FRONT:%s:%d,%d" % [kind, cell.x, cell.y]) % 10000) / 10000.0
	return r + bias + (roll - 0.5) * front_jitter


## Drains the queue against the deadline above. The `await` keeps this
## coroutine (and therefore `self`) alive across the sequence, but that is NOT a
## substitute for the caller's own strong reference: the header's ownership note
## still holds, and TestZoneController still holds `_active_choreographer`. If the
## tree goes away mid-sequence (map reload, quit), `await tree.process_frame`
## simply never resumes and the rest is dropped — correct for a purely visual
## replay of damage already applied to the Voxel state.
func _run_queue(queue: Array, voxel_renderer, smoke_overlay, tree: SceneTree, plan: Dictionary = {}) -> void:
	var next_step := 0
	var frame_index := 0
	## The outermost step's own sort key — the radius the front has to reach for
	## the blast to be over. Read off the queue rather than recomputed from the
	## bomb's rings, so it stays honest when a blast is clipped by walls.
	var max_r: float = 0.0
	if not queue.is_empty():
		max_r = float(queue[queue.size() - 1]["sort"])
	while next_step < queue.size():
		if frame_index > 0:
			await tree.process_frame
		var front_r: float = front_radius_for(frame_index, front_frames, max_r, band_voxels)
		var target: int = steps_within(queue, next_step, front_r)
		var apply_start_us := Time.get_ticks_usec()
		var applied := 0
		while next_step < target:
			var step: Dictionary = queue[next_step]
			_apply_entry(step["kind"], step["entry"], voxel_renderer, smoke_overlay)
			next_step += 1
			applied += 1
		_flush(voxel_renderer)
		var apply_ms: float = float(Time.get_ticks_usec() - apply_start_us) / 1000.0
		print("[E-WAVE] frame %d front_r=%.1f cells=%d/%d elapsed=%dms apply=%.3fms" %
			[frame_index + 1, front_r, next_step, queue.size(),
			Time.get_ticks_msec() - _t0_ms, apply_ms])
		wave_applied.emit(frame_index, "queue", 0, applied)
		frame_index += 1

	## E-FUME: soot as its own late step after smoke (visual reordering only).
	## Soot is removed from WAVE_TABLE and applied here after the expanding front
	## is done, so it visually appears after smoke has mostly dissipated rather than
	## landing alongside it. The "alpha ramp in" in the plan's language is the
	## temporal ordering (appears later), not a technical fade—set_cell applies
	## the pre-computed alt instantly.
	var soot_entries: Array = []
	for ring: int in plan.get("soot", {}).keys():
		soot_entries.append_array(plan["soot"][ring])
	if not soot_entries.is_empty():
		for entry in soot_entries:
			_apply_entry("soot", entry, voxel_renderer, smoke_overlay)
		_flush(voxel_renderer)
		frame_index += 1
		await tree.process_frame

	_waves_done = frame_index
	finished.emit()


## Where the expanding front stands on a given frame, as a radius in the same
## units the queue's `sort` keys are in. Pure and static so the pacing rule is
## testable without controlling frame timing — the same reason its two
## predecessors (`waves_due_now`, `cells_due_now`) were.
##
## Linear in FRAME INDEX, never in wall clock. That single change is what
## retires the dump documented in this file's header: no elapsed time is
## consulted, so no slow frame can make the rest of the queue "due".
##
## Snapped DOWN to a `band` multiple so the front advances in visible steps.
## `floor` and not `round` on purpose — a band must be fully reached before it
## fires, or the first half of every band leaks into the previous frame and the
## banding softens back into the smear it exists to prevent.
##
## The last frame returns INF: whatever the arithmetic and the quantization have
## left over lands, so the sequence always terminates on exactly `frames`
## frames. Without it a rounding-down at the top of the range could strand the
## outermost steps and hang the coroutine.
static func front_radius_for(frame_index: int, frames: int, max_r: float,
		band: float) -> float:
	var f: int = maxi(frames, 1)
	if frame_index >= f - 1:
		return INF
	var reach: float = max_r * (float(frame_index + 1) / float(f))
	if band > 0.0:
		reach = floor(reach / band) * band
	return reach


## How far into the queue the front has reached, as an EXCLUSIVE end index.
## A linear scan from where the last frame stopped, which is correct precisely
## because `flatten_plan()` leaves the queue sorted by this same key — the scan
## and the ordering are the same fact, so this cannot silently disagree with it.
##
## Returning `from_index` unchanged is a legitimate result, not a stall: it means
## the front is crossing empty space this frame, which is exactly the pause a
## blast should have between a dense inner band and a sparse outer one. The
## INF on the last frame (above) is what guarantees termination regardless.
static func steps_within(queue: Array, from_index: int, front_r: float) -> int:
	var i: int = from_index
	while i < queue.size() and float(queue[i]["sort"]) <= front_r:
		i += 1
	return i


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

