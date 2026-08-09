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
## §6.2: "Waves are scheduled on absolute elapsed time from the flash, so a
## slow wave never delays the next" — each wave gets its OWN SceneTreeTimer,
## fired from `start()` all at once (never chained/awaited sequentially), so
## wave N's delay is always `N * wave_interval_ms` from t=0 regardless of how
## long wave N-1 took to apply.
##
## Extends RefCounted, not Node: nothing here needs to be in the scene tree
## itself — `tree` (the SceneTree) is passed in once, for `create_timer()`.
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

## Cadence. Q5 confirmed 40 ms (15 waves ~= 600 ms) on 2026-08-06, before any
## of it had been seen moving; the Director halved it to 20 ms on 2026-08-08
## after watching real detonations — 15 waves ~= 300 ms, the blast reads as one
## event instead of a sequence you can count. `var`, not `const` — this is
## exactly the number that gets re-tuned against a capture.
var wave_interval_ms: float = 20.0

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
	for i in range(WAVE_TABLE.size()):
		var kind: String = WAVE_TABLE[i][0]
		var ring: int = WAVE_TABLE[i][1]
		var delay_s: float = (float(i) * wave_interval_ms) / 1000.0
		var timer := tree.create_timer(delay_s)
		timer.timeout.connect(_apply_wave.bind(i, kind, ring, plan, voxel_renderer, smoke_overlay))


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
