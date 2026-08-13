## DetonationPlanBuilder — EXPLOSION_REBUILD_MASTER_PLAN Task 4 (E-PLAN).
##
## Builds one `WorldDelta` for a single grenade detonation: all resolution, all
## exposure fallback, and the single map-wide light-field query, folded into one
## object a later choreography driver (Task 5/E-WAVE) can play back from
## `delta.waves` as a pure sequence of `set_cell()`/`erase_cell()` calls with
## zero further compositing/lookup — the performance idea §2 states once: "no
## compositing, no lookup, no light rebuild, no allocation happens inside a
## wave."
##
## **P-DELTA (PREDICTION_MASTER_PLAN Task 3, 2026-08-09): this class is now
## PURE.** It changes nothing — not a tile, not a Voxel — and returns a
## description of what a detonation WOULD do. `delta.commit()` is what makes it
## happen, and the caller owns that decision. Everything this pass used to read
## off freshly-mutated Voxels it now reads through `WorldDelta`'s projection.
##
## What this class does NOT do, on purpose:
##  - It never calls `layer.set_cell()`/`erase_cell()` — every VoxelRenderer
##    call it makes runs in resolve-only mode (`apply=false`, Task 4's own
##    seam added to `_set_voxel_cell()`/`render_slab()`/
##    `render_fixed_earth_level()`/`resolve_damage_voxel_swap()`). A voxel's
##    on-screen TILE is only ever resolved, never painted, until a wave chooses
##    to apply the plan entry produced here.
##  - It never writes DAMAGE STATE either, since P-DELTA. `BlastCalculator`'s
##    `commit_damage()` remains the single writer (DESTRUCTION_MASTER_PLAN §3);
##    this pass only ever calls its `simulate_*` half.
##  - It never CALLS `room.record_voxel_damage_to_base()`/increments
##    `_gu_blast_count`/appends a stamped-blast replay list — that is Task 5's
##    job, the same split Task 2/3 already established for their own new
##    parameters. It DOES return the raw material for the first of those
##    (`delta.touched_voxels`, `Array[Voxel]` — every voxel this blast's
##    containers would change the damage_state of, DESTROYED or DENTED/
##    CRACKED), so Task 5's caller can persist without a second flood/
##    find_affected_containers pass to re-derive the same set. That list is
##    only meaningful AFTER `commit()`, which is when its caller reads it.
##  - It never schedules or times anything — the plan is a static census of
##    what EVERY wave should eventually paint; Task 5 owns turning that into
##    a 40 ms-cadenced sequence.
##
## `ctx` is a plain Dictionary rather than a typed context object, matching
## the project's existing MinimalRoom precedent (damage_atom_bake_selftest.gd)
## for running real BlastCalculator machinery against either a full `room.gd`
## or a trimmed selftest scaffold without either needing to know about the
## other:
##   "edge_registry": EdgeRegistry        (required)
##   "slab_registry": SlabRegistry        (required)
##   "voxel_renderer": VoxelRenderer      (required)
##   "blocked_edges": Dictionary          (optional, default {})
##   "blocked_cells": Dictionary          (optional, default {})
##   "lights": Array                      (optional, default [] — real light
##                                          sources, e.g. RoomBuilder.get_
##                                          light_sources())
##   "shadow_results": Array              (optional, default [])
##   "under_structure": Dictionary        (optional, default {} — VL-D3
##                                          "never saw the sun" darkening;
##                                          derived from the CURRENT geometry
##                                          if omitted, see
##                                          _columns_with_structure())
##   "deep_layer_unlocked": bool          (optional, default false — D2; no
##                                          live caller drives true yet)
class_name DetonationPlanBuilder

const BlastCalculatorClass = preload("res://godot/scripts/systems/destruction/blast_calculator.gd")
const WorldDeltaClass = preload("res://godot/scripts/systems/prediction/world_delta.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const VoxelLightFieldClass = preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")

## VL-02c/D2 (unchanged from the pre-reset detonate_active() this task
## replaces) — the ground takes the blast as a CONTIGUOUS crater, radii
## derived from the bomb's own ring count.
##
## E-CRACK-01 (Director, 2026-08-08): "vamos diminuir um pouco a quantidade de
## voxels destruídos e tentar colocar mais decals." CORE 0.4 → 0.30 is the one
## number that does BOTH on the floor, which is why it moved alone: the core is
## the unconditionally-destroyed bowl, so shrinking it removes holes directly,
## and `rim_span = max - core` is the width unit every mark band is measured in,
## so the same edit widens the dent band AND the new crack band without touching
## the crater's outer reach (MAX is unchanged — the blast covers the same ground,
## it just eats less of it and marks more of it). First pass, a tuning lever
## (D6), not a researched constant — expect it to move again after a capture.
const CRATER_MAX_FACTOR: float = 0.40
const CRATER_CORE_FACTOR: float = 0.30

## E-SMOKE-01 (Director, 2026-08-08) — "intensidades diferentes". A puff's base
## strength comes from how hard its voxel was actually hit, so the smoke reads as
## a picture of the damage rather than a uniform fog: a hole vents most, a
## fracture barely wisps. This is the same severity ladder the damage tiers
## themselves ride on (E-CRACK-01), reused rather than re-invented. `var`, not
## `const` — architecture rule 1, these are tuning levers.
static var DESTROY_SMOKE_INTENSITY: float = 1.0
static var DENT_SMOKE_INTENSITY: float = 0.6
static var CRACK_SMOKE_INTENSITY: float = 0.35

## Per-voxel spread around that base, "durações diferentes". Applied as a
## deterministic per-cell hash rather than randf() so two runs of the same
## capture are comparable — the same reason every other roll in this pipeline is
## hashed (FacadeSampler._fnv1a_hash), even though smoke itself is purely visual.
static var SMOKE_JITTER: float = 0.7       ## ± fraction on scale/alpha
static var SMOKE_DURATION_JITTER: float = 0.6   ## ± fraction on duration

## How much of the base duration the WEAKEST puff still gets. Duration used to
## scale on `strength` directly, like size and alpha do, which made an outer
## cracked voxel's puff (strength ~0.07) last ~0.1 s — it was gone before the eye
## reached it, and the thinning outer edge of the cloud is precisely what the
## Director meant by "deixar a fumaça mais tempo no final". Size and alpha still
## scale on strength all the way down; only LIFETIME gets this floor, so a far
## puff is small and faint but not instantaneous.
static var SMOKE_DURATION_FLOOR: float = 0.55

## The overlay's own radii (6 px start, 16 px end) were authored for VFX-01's
## 2-3 blob cluster on ONE destroyed voxel. A single per-voxel blob at scale 1.0
## is smaller than the 32x16 voxel it is venting from, which is a large part of
## why the first per-voxel pass measured as invisible; this lifts the base so a
## puff at least covers its own voxel.
static var SMOKE_SCALE_BASE: float = 1.7

## A per-voxel puff is ONE blob, not the 2-3 cluster VFX-01 gives a lone
## destroyed voxel — there are now hundreds of them and each is meant to read as
## "um pouquinho de fumaça".
const SMOKE_BLOBS_PER_VOXEL: int = 1


## ===========================================================================
## P-SLICE (PREDICTION_MASTER_PLAN Task 4, 2026-08-09) — the pipeline is a
## RESUMABLE STATE MACHINE, and `build_plan()` is that machine run with an
## unlimited budget.
##
## **There is exactly ONE implementation.** A one-shot build and a hover-time,
## frame-sliced prediction execute the same `_run_phase()` over the same state;
## the only difference is how many microseconds the caller hands it. That was
## the deciding constraint — a separate "fast path" would be a second copy of a
## 300-line pipeline, free to drift, and the 0-pixel gate would only ever be
## vouching for one of them.
##
## Phases, which are §1.1's six subdivided wherever they were map-wide:
##
##   0 SETUP      flood + affected containers + epicentre          atomic, ~1.5 ms
##   1 SLICES     damage + ring bookkeeping                       per slice
##   2 ROOFS      the same, for roof slabs                         per slab
##   3 FLOORS     crater damage + soot + expose resolution         per slab
##   4 WALK       the ONE map-wide voxel walk (see below)          per voxel chunk
##   5 SOOT       derive rings x2 + merge + self-soot              ATOMIC
##   6 LIGHT      VoxelLightField.build()                          ATOMIC
##   7 PACKAGE    destroy/dent/crack entries + census + smoke      per voxel chunk
##   8 EXPOSE     reveal-below wiring                              per ring
##   9 SOOTWAVE   the soot-only wave                               per cell chunk
##  10 SMOKE      the GU-level smoke remainder                     per GU
##
## **Phases 5 and 6 are honestly atomic, and that is a real limit rather than
## an omission** — recorded with its measurement in §8.8.
## `BlastCalculator.derive_soot_rings()` is a multi-source BFS and
## `VoxelLightField.build()` is one call into another system; neither can be
## suspended without being rewritten, which is a different job with a different
## risk profile and does not belong inside a task whose gate is "changes
## nothing".
##
## **THE THREE MAP-WIDE WALKS BECAME ONE.** `_columns_with_structure()`,
## `_index_soot_voxel()`'s loop and `_voxel_occupancy()` each traversed every
## voxel in the map separately — and after P-DELTA each wanted its own
## dictionary lookup against the Delta's projection. Phase 4 does all three in
## a single pass off a single lookup. This is the fix Task 3 measured and named
## (§8.7) and this task was told to collect.
##
## Note phase 4 reads BOTH projected and real state, deliberately: occupancy and
## the soot index want the world as it WOULD be, while `under_structure` (VL-D3,
## "never saw the sun") wants the geometry that stood there before the blast.
## Same voxel, same lookup, two questions.
## ===========================================================================

const PHASE_SETUP: int = 0
const PHASE_SLICES: int = 1
const PHASE_ROOFS: int = 2
const PHASE_FLOORS: int = 3
const PHASE_WALK: int = 4
const PHASE_SOOT: int = 5
const PHASE_LIGHT: int = 6
const PHASE_PACKAGE: int = 7
const PHASE_EXPOSE: int = 8
const PHASE_SOOTWAVE: int = 9
const PHASE_SMOKE: int = 10
const PHASE_DONE: int = 11

const PHASE_NAMES: Array[String] = [
	"SETUP", "SLICES", "ROOFS", "FLOORS", "WALK", "SOOT",
	"LIGHT", "PACKAGE", "EXPOSE", "SOOTWAVE", "SMOKE", "DONE",
]

## How many items a chunked phase processes between clock reads. `var`, Rule 1.
##
## Not arbitrary, and the trade runs in both directions: `Time.get_ticks_usec()`
## is not free, so at ~100 000 voxels a per-item read would be a measurable
## fraction of the very phase it is measuring — but too coarse a chunk overshoots
## the budget by however long one chunk takes.
##
## **Per-phase, because the per-item costs differ by an order of magnitude.**
## Measured on the real PLAYGROUND blast (§8.8): a WALK item is ~1.3 µs (one
## dictionary lookup and a few appends), while a PACKAGE item is ~12 µs (it
## resolves a tile through the bake registry). One shared size cannot be right
## for both — at 512 everywhere, WALK respected a 4 ms budget to within 0.7 ms
## while PACKAGE overshot it to 6.5 ms. Each number below is roughly "4 ms of
## that phase's own work".
##
## WALK was tried at 2048 and moved BACK to 512: the coarser chunk took its worst
## visit from 4.7 ms to 6.4 ms while the total moved only within run-to-run noise.
## The clock-read saving is real but tiny (49 reads instead of 195, ~20 µs on a
## 126 ms phase) and it is not what the budget is judged on.
static var WALK_CHUNK: int = 512
static var PACKAGE_CHUNK: int = 256
static var SOOTWAVE_CHUNK: int = 512


## Builds one WorldDelta start to finish. Convenience over the state machine —
## `begin()` + `step()` with no budget — and the shape every existing caller
## already had.
static func build_plan(bomb_def, source_gu: Vector2i, ctx: Dictionary) -> WorldDelta:
	var s := begin(bomb_def, source_gu, ctx)
	while not step(s, 0):
		pass
	return s["delta"]


## Opens a build. Returns the state; nothing is computed yet, so abandoning the
## state here costs exactly one allocation.
static func begin(bomb_def, source_gu: Vector2i, ctx: Dictionary) -> Dictionary:
	var delta := WorldDeltaClass.new()
	return {
		"bomb_def": bomb_def,
		"source_gu": source_gu,
		"ctx": ctx,
		"edge_registry": ctx["edge_registry"] as EdgeRegistry,
		"slab_registry": ctx["slab_registry"] as SlabRegistry,
		"voxel_renderer": ctx["voxel_renderer"] as VoxelRendererClass,
		"deep_layer_unlocked": bool(ctx.get("deep_layer_unlocked", false)),
		"delta": delta,
		"waves": delta.waves,
		"phase": PHASE_SETUP,
		"cursor": 0,
		"sub": 0,
		"work_usec": 0,
		## §8.8's evidence: total and worst-single-visit microseconds per phase.
		## Kept always-on rather than behind a debug flag — it is two clock reads
		## per phase visit against a pipeline that already reads the clock every
		## chunk, and a budget you cannot audit is a budget you are
		## guessing at.
		"phase_usec": {},
		"phase_worst": {},
	}


## Advances the build by at most `budget_usec` of work. `budget_usec <= 0` means
## "no budget": every phase runs to completion, which is what `build_plan()`
## uses and what makes the one-shot path literally the sliced path.
##
## Returns true when the Delta is finished. Cheap and safe to call again after
## that (it returns true immediately and does no work).
##
## The budget is honoured BETWEEN chunks, never inside one, and phases 5 and 6
## ignore it outright because they cannot be suspended. A caller with a hard
## frame budget must treat this as best-effort, which is why §4.4's gate is
## measured on real output rather than asserted from the parameter.
static func step(s: Dictionary, budget_usec: int) -> bool:
	if int(s["phase"]) == PHASE_DONE:
		return true
	var t0: int = Time.get_ticks_usec()
	var deadline: int = (t0 + budget_usec) if budget_usec > 0 else 0
	var profile: Dictionary = s["phase_usec"]
	while int(s["phase"]) != PHASE_DONE:
		## Per-phase accounting, attributed to the phase that was RUNNING rather
		## than to whichever one a step happened to start in. One `step()` can
		## cross several phase boundaries, so attributing by entry point reported
		## the whole first step as "SETUP" — which named the wrong phase for
		## exactly the question §4.4's budget gate is asking. Two clock reads per
		## phase visit; the chunked phases already read the clock far more often
		## than that.
		var phase: int = int(s["phase"])
		var p0: int = Time.get_ticks_usec()
		_run_phase(s, deadline)
		var spent: int = Time.get_ticks_usec() - p0
		profile[phase] = int(profile.get(phase, 0)) + spent
		var worst: Dictionary = s["phase_worst"]
		if spent > int(worst.get(phase, 0)):
			worst[phase] = spent
		if _out_of_time(deadline):
			break
	s["work_usec"] = int(s["work_usec"]) + (Time.get_ticks_usec() - t0)
	if int(s["phase"]) != PHASE_DONE:
		return false
	var delta: WorldDelta = s["delta"]
	delta.cost_ms = float(s["work_usec"]) / 1000.0
	return true


## How far along the build is, 0.0-1.0. Phase-granular and therefore rough —
## honest enough to drive a "cooking" indicator, not a progress bar with a
## percentage on it.
static func progress(s: Dictionary) -> float:
	return clampf(float(s["phase"]) / float(PHASE_DONE), 0.0, 1.0)


static func is_done(s: Dictionary) -> bool:
	return int(s["phase"]) == PHASE_DONE


## Which phase a suspended build is sitting in — for logs and for §8.8's
## measurements, never for control flow.
static func phase_name(s: Dictionary) -> String:
	return name_of_phase(int(s["phase"]))


static func name_of_phase(p: int) -> String:
	return PHASE_NAMES[p] if p >= 0 and p < PHASE_NAMES.size() else "?"


## One line per phase that did any work: total time, and the worst SINGLE visit.
## The worst-visit column is the one §4.4's per-frame budget is judged on — a
## phase that cannot be suspended shows up here as a single unavoidable spike,
## which is precisely the finding the gate exists to surface.
static func profile_lines(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var total: Dictionary = s["phase_usec"]
	var worst: Dictionary = s["phase_worst"]
	var phases: Array = total.keys()
	phases.sort()
	for p in phases:
		out.append("%-9s total %7.1f ms   worst visit %6.1f ms" % [
			name_of_phase(int(p)), float(total[p]) / 1000.0,
			float(worst.get(p, 0)) / 1000.0])
	return out


static func _out_of_time(deadline: int) -> bool:
	return deadline > 0 and Time.get_ticks_usec() >= deadline


static func _enter_phase(s: Dictionary, phase: int) -> void:
	s["phase"] = phase
	s["cursor"] = 0
	s["sub"] = 0


static func _run_phase(s: Dictionary, deadline: int) -> void:
	match int(s["phase"]):
		PHASE_SETUP:
			_phase_setup(s)
		PHASE_SLICES:
			_phase_slices(s, deadline)
		PHASE_ROOFS:
			_phase_roofs(s, deadline)
		PHASE_FLOORS:
			_phase_floors(s, deadline)
		PHASE_WALK:
			_phase_walk(s, deadline)
		PHASE_SOOT:
			_phase_soot(s, deadline)
		PHASE_LIGHT:
			_phase_light(s)
		PHASE_PACKAGE:
			_phase_package(s, deadline)
		PHASE_EXPOSE:
			_phase_expose(s, deadline)
		PHASE_SOOTWAVE:
			_phase_soot_wave(s, deadline)
		PHASE_SMOKE:
			_phase_smoke(s, deadline)


## --- Phase 0: the cheap header. -------------------------------------------
static func _phase_setup(s: Dictionary) -> void:
	var bomb_def = s["bomb_def"]
	var ctx: Dictionary = s["ctx"]
	var source_gu: Vector2i = s["source_gu"]
	var gu_rings := BlastCalculatorClass.flood_gu_rings(source_gu, bomb_def,
		ctx.get("blocked_edges", {}), ctx.get("blocked_cells", {}))
	var affected := BlastCalculatorClass.find_affected_containers(
		gu_rings, s["edge_registry"], s["slab_registry"])
	var n_rings: int = bomb_def.ring_multipliers.size()
	var half: int = int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0)
	var crater_max: float = float(n_rings) * float(GeometryCoords.VOXELS_PER_UNIT_AXIS) * CRATER_MAX_FACTOR

	s["gu_rings"] = gu_rings
	s["affected"] = affected
	s["epicenter"] = source_gu * GeometryCoords.VOXELS_PER_UNIT_AXIS + Vector2i(half, half)
	s["crater_max"] = crater_max
	s["crater_core"] = crater_max * CRATER_CORE_FACTOR
	s["crater_rim_span"] = maxf(crater_max - crater_max * CRATER_CORE_FACTOR, 0.001)

	s["slice_ids"] = affected["slices"].keys()
	s["roof_ids"] = affected["roofs"].keys()
	s["floor_ids"] = affected.get("floors", {}).keys()

	s["soot_snapshot"] = {}
	s["soot_faces"] = {}
	s["ring_of"] = {}
	s["container_of"] = {}
	s["exposed_by_ring"] = {}
	s["cell_to_voxel"] = {}
	s["blast_cells"] = []
	s["weapon_cells"] = []
	s["damaged_voxels"] = []
	s["occupancy"] = {}
	s["touched_this_blast"] = {}
	s["touched_voxels"] = []
	s["census"] = {}
	s["smoked_gus"] = {}

	## VL-D3's own contract: "computed from the INTACT geometry right after a
	## build, before reapply_damage" — a floor voxel newly exposed by THIS blast
	## must read as "never saw the sun" using the geometry that stood over it a
	## moment ago, not the hole this call is about to describe. P-DELTA turned
	## that from an ordering rule into a property (nothing here writes to a
	## Voxel); P-SLICE folds the derivation into phase 4's single walk.
	var supplied: Dictionary = ctx.get("under_structure", {})
	s["derive_under_structure"] = supplied.is_empty()
	s["under_structure"] = supplied if not supplied.is_empty() else {}
	_enter_phase(s, PHASE_SLICES)


## --- Phases 1-3: the affected containers, one per step item. ---------------
static func _phase_slices(s: Dictionary, deadline: int) -> void:
	var ids: Array = s["slice_ids"]
	var edge_registry: EdgeRegistry = s["edge_registry"]
	var affected: Dictionary = s["affected"]["slices"]
	var bomb_def = s["bomb_def"]
	var delta: WorldDelta = s["delta"]
	var epicenter: Vector2i = s["epicenter"]
	var ring_of: Dictionary = s["ring_of"]
	var container_of: Dictionary = s["container_of"]
	var i: int = int(s["cursor"])
	while i < ids.size():
		var slice: Slice = edge_registry.get_slice(ids[i])
		var base_ring: int = affected[ids[i]]
		var base_level: int = slice.start_storey * GeometryCoords.LEVELS_PER_STOREY
		delta.add_damage(BlastCalculatorClass.simulate_container_damage(
			slice.voxels, slice.id, slice.material, base_ring, base_level, false,
			bomb_def.ring_multipliers, bomb_def.destroy_ring_weights,
			bomb_def.dent_ring_weights, bomb_def.crack_ring_weights, epicenter))
		for v in slice.voxels:
			var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
			ring_of[key] = base_ring + BlastCalculatorClass.vertical_ring_for(v.level - base_level)
			container_of[key] = slice
		i += 1
		if _out_of_time(deadline):
			break
	s["cursor"] = i
	if i >= ids.size():
		_enter_phase(s, PHASE_ROOFS)


static func _phase_roofs(s: Dictionary, deadline: int) -> void:
	var ids: Array = s["roof_ids"]
	var slab_registry: SlabRegistry = s["slab_registry"]
	var affected: Dictionary = s["affected"]["roofs"]
	var bomb_def = s["bomb_def"]
	var delta: WorldDelta = s["delta"]
	var epicenter: Vector2i = s["epicenter"]
	var ring_of: Dictionary = s["ring_of"]
	var container_of: Dictionary = s["container_of"]
	var i: int = int(s["cursor"])
	while i < ids.size():
		var roof: Slab = slab_registry.get_slab(ids[i])
		var base_ring: int = affected[ids[i]]
		delta.add_damage(BlastCalculatorClass.simulate_container_damage(
			roof.voxels, roof.id, roof.material, base_ring, roof.level, true,
			bomb_def.ring_multipliers, bomb_def.destroy_ring_weights,
			bomb_def.dent_ring_weights, bomb_def.crack_ring_weights, epicenter))
		for v in roof.voxels:
			var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
			ring_of[key] = base_ring + BlastCalculatorClass.vertical_ring_for(v.level - roof.level)
			container_of[key] = roof
		i += 1
		if _out_of_time(deadline):
			break
	s["cursor"] = i
	if i >= ids.size():
		_enter_phase(s, PHASE_FLOORS)


## D2's floor gate: unlocked from a GU's second blast onward, threaded through
## ctx by the caller that knows the GU's blast count.
static func _phase_floors(s: Dictionary, deadline: int) -> void:
	var ids: Array = s["floor_ids"]
	var slab_registry: SlabRegistry = s["slab_registry"]
	var bomb_def = s["bomb_def"]
	var delta: WorldDelta = s["delta"]
	var epicenter: Vector2i = s["epicenter"]
	var ring_of: Dictionary = s["ring_of"]
	var container_of: Dictionary = s["container_of"]
	var deep_unlocked: bool = bool(s["deep_layer_unlocked"])
	var crater_core: float = float(s["crater_core"])
	var crater_max: float = float(s["crater_max"])
	var crater_rim_span: float = float(s["crater_rim_span"])
	var i: int = int(s["cursor"])
	while i < ids.size():
		var floor_slab: Slab = slab_registry.get_slab(ids[i])
		i += 1
		if floor_slab.level == GeometryCoords.FLOOR_DEEP_LEVEL and not deep_unlocked:
			continue
		## E-CRACK-01: the bomb's own dent/crack ring tables reach the floor too —
		## the same two arrays every wall and roof above already read, so one
		## authored number governs a tier everywhere it can appear instead of the
		## floor keeping a private falloff. `slab_pierce_multiplier` stays at its
		## D17 default and is passed positionally only because the tables sit
		## behind it.
		delta.add_damage(BlastCalculatorClass.simulate_crater_damage(
			floor_slab.voxels, floor_slab.id, epicenter, crater_core, crater_max,
			floor_slab.material, deep_unlocked, 1.0,
			bomb_def.dent_ring_weights, bomb_def.crack_ring_weights))
		var min_destroy_ring: int = -1
		for v in floor_slab.voxels:
			var d: float = Vector2(v.grid_pos - epicenter).length()
			var ring: int = BlastCalculatorClass.crater_ring_for(d, crater_max, crater_rim_span)
			var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
			ring_of[key] = ring
			container_of[key] = floor_slab
			## The Delta's projection, not the Voxel — this slab's own simulate ran
			## one statement ago and add_damage() folded it in, so the answer here
			## is the one the pre-P-DELTA code read off the freshly-damaged Voxel.
			if delta.state_of(v) == Voxel.DamageState.DESTROYED:
				min_destroy_ring = ring if min_destroy_ring < 0 else mini(min_destroy_ring, ring)
		## D18 lazy reveal — a crater with nothing exposed below it shows the
		## legacy plane straight through the hole. Grouped under the EARLIEST ring
		## that actually opened this slab, so the reveal rides in on the same wave
		## a real destroy already lands in.
		if min_destroy_ring >= 0:
			var expose := _resolve_expose_below(floor_slab, s["voxel_renderer"], slab_registry)
			if not expose.is_empty():
				var by_ring: Dictionary = s["exposed_by_ring"]
				if not by_ring.has(min_destroy_ring):
					by_ring[min_destroy_ring] = []
				by_ring[min_destroy_ring].append_array(expose)
		if _out_of_time(deadline):
			break
	s["cursor"] = i
	if i >= ids.size():
		var walk: Array = []
		for slice in (s["edge_registry"] as EdgeRegistry).all_slices():
			walk.append([slice, true])
		for slab in slab_registry.all_slabs():
			walk.append([slab, false])
		s["walk_containers"] = walk
		_enter_phase(s, PHASE_WALK)


## --- Phase 4: THE map-wide walk. Three former passes, one traversal. -------
##
## Every local below is hoisted out of the loop on purpose. The body runs ~100
## 000 times per detonation, and a `s["cell_to_voxel"]` inside it would be a
## string-keyed dictionary hit per voxel per collection — six of them, i.e.
## ~600 000 extra lookups, which is the same order as the cost this phase exists
## to remove. Readability lost here is bought back in the header's phase table.
static func _phase_walk(s: Dictionary, deadline: int) -> void:
	var containers: Array = s["walk_containers"]
	var delta: WorldDelta = s["delta"]
	var cell_to_voxel: Dictionary = s["cell_to_voxel"]
	var blast_cells: Array = s["blast_cells"]
	var weapon_cells: Array = s["weapon_cells"]
	var damaged_voxels: Array = s["damaged_voxels"]
	var occupancy: Dictionary = s["occupancy"]
	var under_structure: Dictionary = s["under_structure"]
	var derive_us: bool = bool(s["derive_under_structure"])
	var chunk: int = WALK_CHUNK
	var ci: int = int(s["cursor"])
	var vi: int = int(s["sub"])
	var since_check: int = 0

	while ci < containers.size():
		var entry: Array = containers[ci]
		var voxels: Array = entry[0].voxels
		var is_slice: bool = bool(entry[1])
		while vi < voxels.size():
			var v: Voxel = voxels[vi]
			vi += 1
			var p: Array = delta.projection_of(v)
			var touched: bool = not p.is_empty()
			var state: int = int(p[WorldDelta.P_STATE]) if touched else v.damage_state
			var vis: bool = bool(p[WorldDelta.P_VISIBLE]) if touched else v.visible

			## (a) the soot index — mirrors room._index_soot_voxel()'s three
			## buckets exactly (absent -> blast/weapon seed by provenance,
			## visible+damaged -> self-soot), classified through the projection.
			var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
			cell_to_voxel[key] = v
			if not vis or state == Voxel.DamageState.DESTROYED:
				var from_blast: bool = bool(p[WorldDelta.P_BLAST]) if touched else v.damage_is_blast
				if from_blast:
					blast_cells.append(key)
				else:
					weapon_cells.append(key)
			elif state == Voxel.DamageState.DENTED or state == Voxel.DamageState.CRACKED:
				## PROJECTED, and this one is a trap worth naming: the only
				## consumer, apply_self_soot(), reads damage_state/is_blast/
				## carved_side off these objects. Real Voxels would read INTACT
				## here and the self-soot on every fresh mark would vanish with no
				## error at all. project_voxel() returns the original when nothing
				## changed, so untouched voxels cost no allocation.
				damaged_voxels.append(delta.project_voxel(v) if touched else v)

			## (b) occupancy for the light field — PROJECTED, so the fresh crater
			## lights as a hole rather than as solid rock (the live TileMapLayer
			## still shows it placed; nothing has erased it yet, on purpose).
			if vis:
				if not occupancy.has(v.level):
					occupancy[v.level] = {}
				occupancy[v.level][v.grid_pos] = true

			## (c) VL-D3 "never saw the sun" — REAL visible, walls only. The one
			## consumer in this walk that wants the world BEFORE the blast.
			if is_slice and derive_us and v.visible:
				under_structure[v.grid_pos] = true

			since_check += 1
			if since_check >= chunk:
				since_check = 0
				if _out_of_time(deadline):
					s["cursor"] = ci
					s["sub"] = vi
					return
		vi = 0
		ci += 1
	s["cursor"] = ci
	s["sub"] = 0
	_enter_phase(s, PHASE_SOOT)


## --- Phase 5: ATOMIC. Whole-map soot, derived from holes. ------------------
##
## Scope is the whole map (matching room._build_soot_snapshot()), not just this
## blast's containers, so a pre-existing hole elsewhere keeps its scorch.
##
## Cannot be sliced as written: derive_soot_rings() is a multi-source BFS whose
## frontier IS its state, and suspending it would mean turning that frontier
## into resumable state inside BlastCalculator. Flagged, measured in §8.8, not
## silently accepted.
## Split across three VISITS at the natural call boundaries — the two BFS runs
## and the merge/self-soot tail. That is as fine as this phase gets without
## reaching inside `derive_soot_rings()` to make its frontier resumable, which
## would mean changing a BlastCalculator function that `room.gd`'s repaint path
## also calls. Measured, named and deliberately not done — §8.8.
##
## `sub` is the cursor: 0 = blast rings, 1 = weapon rings, 2 = merge + self-soot.
static func _phase_soot(s: Dictionary, deadline: int) -> void:
	var ctx: Dictionary = s["ctx"]
	BlastCalculatorClass.build_soot_field(
		s["cell_to_voxel"], s["blast_cells"], s["weapon_cells"], s["damaged_voxels"],
		ctx.get("blast_soot_rings", 4), ctx.get("weapon_soot_rings", 3),
		s["soot_snapshot"], s["soot_faces"], _cells_this_blast_reveals(s))
	_scorch_revealed_fixed_cells(s, s["soot_snapshot"], s["soot_faces"])
	_enter_phase(s, PHASE_LIGHT)


## S-DEEP part 1 — every cell this blast is about to REVEAL, as the BFS's
## `also_visible` set. Reads `exposed_by_ring`, which `_phase_floors` has already
## filled by the time this phase runs (phase order: FLOORS, WALK, SOOT).
static func _cells_this_blast_reveals(s: Dictionary) -> Dictionary:
	var revealed: Dictionary = {}
	for ring in s["exposed_by_ring"].keys():
		for e in s["exposed_by_ring"][ring]:
			var pos: Vector2i = e["grid_pos"]
			revealed[Vector3i(pos.x, pos.y, e["level"])] = true
	return revealed


## S-DEEP part 2 — the revealed cells that are not Voxels at all.
##
## `_resolve_expose_below()` has two outcomes: a real deep Slab
## (`reveal_floor_slab()`, real Voxel objects the BFS can reach once told they
## are about to be visible) or the FIXED earth level
## (`render_fixed_earth_level()`, cells with no Voxel behind them). The BFS walks
## `cell_to_voxel`, so the second kind is unreachable by construction, no matter
## what it is told about visibility.
##
## `room.gd`'s repaint has always handled exactly this, via
## `add_crater_floor_soot()` at `EXPOSED_FLOOR_SOOT_RING` — and the detonation
## path never did. That asymmetry is SOOT_MASTER_PLAN §1.2's predicted defect:
## the same crater reading clean right after the blast and sooted after a
## rotation. Both sides now write the same constant through the same helper.
static func _scorch_revealed_fixed_cells(s: Dictionary, out_snapshot: Dictionary,
		out_faces: Dictionary) -> void:
	var cell_to_voxel: Dictionary = s["cell_to_voxel"]
	for ring_key in s["exposed_by_ring"].keys():
		for e in s["exposed_by_ring"][ring_key]:
			var pos: Vector2i = e["grid_pos"]
			var level: int = e["level"]
			if cell_to_voxel.has(Vector3i(pos.x, pos.y, level)):
				continue   ## a real Voxel — the BFS already owns it
			BlastCalculatorClass.scorch_floor_cell(out_snapshot, out_faces,
				level, pos, BlastCalculatorClass.EXPOSED_FLOOR_SOOT_RING)


## --- Phase 6: ATOMIC. The single map-wide light-field query (§2). ----------
## Built ONCE, queried per cell below. VoxelLightField.build() never touches the
## TileMapLayer, and nothing here calls VoxelRenderer.apply_light_field().
static func _phase_light(s: Dictionary) -> void:
	var ctx: Dictionary = s["ctx"]
	var voxel_renderer: VoxelRendererClass = s["voxel_renderer"]
	var field := VoxelLightFieldClass.new()
	field.build(ctx.get("lights", []), ctx.get("shadow_results", []),
		maxi(voxel_renderer.get_layer_count() - 1, 0),
		s["occupancy"], s["soot_snapshot"], s["under_structure"], s["soot_faces"])
	s["field"] = field
	s["ring_keys"] = s["ring_of"].keys()
	_enter_phase(s, PHASE_PACKAGE)


## --- Phase 7: package destroy/dented/cracked, keyed by ring. ---------------
## Read from the DELTA's projected state — never re-derived, never re-rolled.
static func _phase_package(s: Dictionary, deadline: int) -> void:
	var keys: Array = s["ring_keys"]
	var delta: WorldDelta = s["delta"]
	var waves: Dictionary = s["waves"]
	var field: VoxelLightFieldClass = s["field"]
	var cell_to_voxel: Dictionary = s["cell_to_voxel"]
	var ring_of: Dictionary = s["ring_of"]
	var container_of: Dictionary = s["container_of"]
	var touched_this_blast: Dictionary = s["touched_this_blast"]
	var touched_voxels: Array = s["touched_voxels"]
	var census: Dictionary = s["census"]
	var smoked_gus: Dictionary = s["smoked_gus"]
	var voxel_renderer: VoxelRendererClass = s["voxel_renderer"]
	var epicenter: Vector2i = s["epicenter"]
	var smoke_weights: Array[float] = s["bomb_def"].smoke_ring_weights
	var chunk: int = PACKAGE_CHUNK
	var i: int = int(s["cursor"])
	var since_check: int = 0

	while i < keys.size():
		var key = keys[i]
		i += 1
		var voxel: Voxel = cell_to_voxel.get(key)
		if voxel != null:
			var ring: int = ring_of[key]
			var container = container_of.get(key)
			var state: int = delta.state_of(voxel)
			if state == Voxel.DamageState.DESTROYED:
				touched_this_blast[key] = true
				touched_voxels.append(voxel)
				_count(census, "destroy", container, true)
				_append_voxel_smoke(waves["smoke"], smoked_gus, voxel, ring,
					smoke_weights, DESTROY_SMOKE_INTENSITY, voxel_renderer, epicenter)
				_append(waves["destroy"], ring, {"cell": voxel.grid_pos, "level": voxel.level,
					"r": _radius_of(voxel.grid_pos, epicenter)})
			elif state == Voxel.DamageState.DENTED or state == Voxel.DamageState.CRACKED:
				touched_this_blast[key] = true
				touched_voxels.append(voxel)
				_append_voxel_smoke(waves["smoke"], smoked_gus, voxel, ring, smoke_weights,
					DENT_SMOKE_INTENSITY if state == Voxel.DamageState.DENTED
						else CRACK_SMOKE_INTENSITY,
					voxel_renderer, epicenter)
				## The resolver takes a whole Voxel and reads five damage fields off
				## it, so it is handed the Delta's PROJECTED copy. The real Voxel is
				## what goes into `touched_voxels`, because that list is the commit's
				## persistence seam and needs the object, not a snapshot of it.
				var resolved := _resolve_damaged_tile(
					delta.project_voxel(voxel), container, voxel_renderer)
				var alt := _alt_for(field, voxel.grid_pos, voxel.level, resolved["alternative_id"])
				var wave_key: String = "dented" if state == Voxel.DamageState.DENTED else "cracked"
				_count(census, wave_key, container, resolved["baked"])
				_append(waves[wave_key], ring, {"cell": voxel.grid_pos, "level": voxel.level,
					"source_id": resolved["source_id"], "atlas_coords": resolved["atlas_coords"],
					"alt": alt, "r": _radius_of(voxel.grid_pos, epicenter)})
		since_check += 1
		if since_check >= chunk:
			since_check = 0
			if _out_of_time(deadline):
				break
	s["cursor"] = i
	if i >= keys.size():
		s["expose_rings"] = s["exposed_by_ring"].keys()
		_enter_phase(s, PHASE_EXPOSE)


## --- Phase 8: exposure fallback, wired into its ring's destroy entries. ----
## §6.1's `expose` sub-array, lit through the SAME field query as everything else.
static func _phase_expose(s: Dictionary, deadline: int) -> void:
	var rings: Array = s["expose_rings"]
	var exposed_by_ring: Dictionary = s["exposed_by_ring"]
	var waves: Dictionary = s["waves"]
	var field: VoxelLightFieldClass = s["field"]
	var epicenter: Vector2i = s["epicenter"]
	var i: int = int(s["cursor"])
	while i < rings.size():
		var ring = rings[i]
		i += 1
		var lit_expose: Array = []
		for e in exposed_by_ring[ring]:
			var alt := _alt_for(field, e["grid_pos"], e["level"], e["alternative_id"])
			lit_expose.append({"cell": e["grid_pos"], "level": e["level"],
				"source_id": e["source_id"], "atlas_coords": e["atlas_coords"], "alt": alt,
				"r": _radius_of(e["grid_pos"], epicenter)})
		if not waves["destroy"].has(ring):
			waves["destroy"][ring] = []
		var carrier: Array = waves["destroy"][ring]
		if carrier.is_empty():
			## Shouldn't happen — a reveal only fires alongside a real destroy in
			## the same ring — kept as an honestly-labelled defensive entry
			## (epicenter cell, not a real destroyed voxel) rather than silently
			## dropping the exposed tiles.
			carrier.append({"cell": epicenter, "level": GeometryCoords.FLOOR_TOP_LEVEL,
				"r": 0.0, "expose": lit_expose})
		else:
			var entry: Dictionary = carrier[0]
			var existing_expose: Array = entry.get("expose", [])
			existing_expose.append_array(lit_expose)
			entry["expose"] = existing_expose
		if _out_of_time(deadline):
			break
	s["cursor"] = i
	if i >= rings.size():
		## Flattened here rather than iterated nested, so the phase below has a
		## single cursor to suspend on. Cheap: this is the sooted-cell count, not
		## the map.
		var flat: Array = []
		var snapshot: Dictionary = s["soot_snapshot"]
		for level in snapshot.keys():
			for cell in (snapshot[level] as Dictionary).keys():
				flat.append([level, cell])
		s["soot_cells"] = flat
		_enter_phase(s, PHASE_SOOTWAVE)


## --- Phase 9: the soot-only wave. -----------------------------------------
## Every surviving voxel whose soot changed and isn't already carried by a
## destroy/dent/crack entry. Ring is whatever the merged snapshot assigned.
static func _phase_soot_wave(s: Dictionary, deadline: int) -> void:
	var cells: Array = s["soot_cells"]
	var snapshot: Dictionary = s["soot_snapshot"]
	var waves: Dictionary = s["waves"]
	var field: VoxelLightFieldClass = s["field"]
	var touched_this_blast: Dictionary = s["touched_this_blast"]
	var voxel_renderer: VoxelRendererClass = s["voxel_renderer"]
	var epicenter: Vector2i = s["epicenter"]
	var chunk: int = SOOTWAVE_CHUNK
	var i: int = int(s["cursor"])
	var since_check: int = 0
	while i < cells.size():
		var pair: Array = cells[i]
		i += 1
		var level: int = pair[0]
		var cell: Vector2i = pair[1]
		var ring: int = int((snapshot[level] as Dictionary)[cell])
		if ring < BlastCalculatorClass.FACE_SOOT_CLEAN \
				and not touched_this_blast.has(Vector3i(cell.x, cell.y, level)):
			var layer: TileMapLayer = voxel_renderer.get_layer(level)
			if layer != null:
				var source_id: int = layer.get_cell_source_id(cell)
				## -1 = erased elsewhere (occlusion/older destruction) — nothing to
				## relight.
				if source_id != -1:
					var prev_alt: int = layer.get_cell_alternative_tile(cell)
					var alt := _alt_for(field, cell, level, prev_alt)
					## Equal alt = nothing this blast changes here, no wave entry.
					if alt != prev_alt:
						_append(waves["soot"], ring, {"cell": cell, "level": level,
							"source_id": source_id,
							"atlas_coords": layer.get_cell_atlas_coords(cell),
							"alt": alt, "r": _radius_of(cell, epicenter)})
		since_check += 1
		if since_check >= chunk:
			since_check = 0
			if _out_of_time(deadline):
				break
	s["cursor"] = i
	if i >= cells.size():
		s["smoke_gus"] = s["gu_rings"].keys()
		_enter_phase(s, PHASE_SMOKE)


## --- Phase 10: smoke, the GU-level remainder (E-SMOKE-01). -----------------
## The per-voxel puffs already cover every GU that took real damage; this fills
## only the GUs the flood REACHED but left intact. Ring 3 is what makes it
## necessary rather than decorative: destroy/dent/crack_ring_weights[3] are all
## 0.0 (§4.1 — ring 3 exists to carry soot), so ring 3 damages nothing and would
## otherwise lose the weak smoke D5/Q2 deliberately gave it.
static func _phase_smoke(s: Dictionary, deadline: int) -> void:
	var gus: Array = s["smoke_gus"]
	var gu_rings: Dictionary = s["gu_rings"]
	var smoked_gus: Dictionary = s["smoked_gus"]
	var waves: Dictionary = s["waves"]
	var voxel_renderer: VoxelRendererClass = s["voxel_renderer"]
	var epicenter: Vector2i = s["epicenter"]
	var smoke_weights: Array[float] = s["bomb_def"].smoke_ring_weights
	var half: int = int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0)
	var i: int = int(s["cursor"])
	while i < gus.size():
		var gu = gus[i]
		i += 1
		if smoked_gus.has(gu):
			continue
		var ring: int = gu_rings[gu]
		if ring >= smoke_weights.size():
			continue
		var weight: float = smoke_weights[ring]
		if weight <= 0.0:
			continue
		var gu_center: Vector2i = GeometryCoords.gu_to_voxel_origin(gu) + Vector2i(half, half)
		_append(waves["smoke"], ring, {
			"world_pos": voxel_renderer.voxel_world_position(
				gu_center, BlastCalculatorClass.GRENADE_LEVEL),
			"duration": weight, "scale": weight, "alpha": weight, "blobs": 0,
			"r": _radius_of(gu_center, epicenter)})
		if _out_of_time(deadline):
			break
	s["cursor"] = i
	if i >= gus.size():
		## §3.4 — the Delta's queryable surface. `touched_voxels` is the object
		## list VL-PERSIST consumes after the commit; `touched` is the same set as
		## plain cells, for anything that must outlive those references (a cached
		## Delta, a HUD readout). `census` stops being a print-only side effect.
		var delta: WorldDelta = s["delta"]
		var touched_voxels: Array = s["touched_voxels"]
		delta.touched_voxels = touched_voxels
		var touched_cells: Array[Vector3i] = []
		for v in touched_voxels:
			touched_cells.append(Vector3i(v.grid_pos.x, v.grid_pos.y, v.level))
		delta.touched = touched_cells
		delta.census = s["census"]
		_enter_phase(s, PHASE_DONE)


static func _resolve_damaged_tile(voxel: Voxel, container, voxel_renderer: VoxelRendererClass) -> Dictionary:
	if container == null:
		return {"source_id": 0, "atlas_coords": Vector2i.ZERO, "alternative_id": 0, "baked": false}
	var baked := voxel_renderer.resolve_damage_voxel_swap(voxel, container)
	if not baked.is_empty():
		return {"source_id": baked["source_id"], "atlas_coords": baked["atlas_coords"],
			"alternative_id": 0, "baked": true}
	if container is Slice:
		var slice: Slice = container
		var voxel_xy := Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
		var render_material := VoxelRendererClass.damage_variant_material(
			slice.material, voxel.damage_state, voxel.damage_is_blast,
			voxel.damage_carved_side, voxel.damage_variant)
		var resolved := voxel_renderer._set_voxel_cell(voxel.grid_pos, voxel.level, render_material,
			null, voxel_xy, slice.face, false, "", BakePolicyClass.SurfaceClass.SLICE, false)
		return {"source_id": resolved["source_id"], "atlas_coords": resolved["atlas_coords"],
			"alternative_id": resolved["alternative_id"], "baked": false}
	## Slab (FLOOR/CEILING/INTERIOR) — mirrors render_slab_solid()'s own
	## fixed-material call shape. A live-fallback miss on a Slab is not
	## exercised by any real material on PLAYGROUND today (Task 1b measured 0
	## unresolved atoms across all three element classes), so this resolves
	## the same shared solid material name the live pipeline would, without
	## reproducing _process_dirty_slab_voxel()'s full zoned-floor branch —
	## flagged, not silently assumed correct: a real miss here resolves to a
	## plausible but unverified tile rather than crashing.
	var slab: Slab = container
	var render_material2 := VoxelRendererClass.damage_variant_material(
		slab.material, voxel.damage_state, voxel.damage_is_blast,
		voxel.damage_carved_side, voxel.damage_variant)
	var resolved2 := voxel_renderer._set_voxel_cell(voxel.grid_pos, voxel.level, render_material2,
		null, voxel.grid_pos - slab.texture_anchor, 0, slab.role == Slab.Role.CEILING,
		"", BakePolicyClass.SurfaceClass.SLICE, false)
	return {"source_id": resolved2["source_id"], "atlas_coords": resolved2["atlas_coords"],
		"alternative_id": resolved2["alternative_id"], "baked": false}


## E-DENT-01 census bookkeeping — one row per (surface, material, tier) triple.
## Material is in the key because the whole point of D34's floor zones is that
## each material's slab shows its OWN defects; a blended "FLOOR 93" cannot tell
## a working concrete patch apart from a silently inert metal one.
static func _count(census: Dictionary, kind: String, container, was_baked: bool) -> void:
	var group := "%s|%s" % [_surface_name(container), _material_name(container)]
	if not census.has(group):
		census[group] = {"destroy": 0, "dented": 0, "cracked": 0, "baked": 0, "live": 0}
	var row: Dictionary = census[group]
	row[kind] = int(row[kind]) + 1
	if kind != "destroy":
		var tier: String = "baked" if was_baked else "live"
		row[tier] = int(row[tier]) + 1


static func _surface_name(container) -> String:
	if container is Slice:
		return "WALL"
	if container is Slab:
		var slab: Slab = container
		match slab.role:
			Slab.Role.FLOOR:
				return "FLOOR"
			Slab.Role.CEILING:
				return "CEILING"
			_:
				return "INTERIOR"
	return "NONE"


static func _material_name(container) -> String:
	if container is Slice or container is Slab:
		return container.material
	return "?"


## Printed once per detonation, next to the `[E-WAVE]` per-wave lines the
## choreographer already emits. One line per surface+material this blast
## actually reached, plus an explicit "nothing reached" line when it reached
## none — a silent census and a zero census are different findings, and
## FLOOR-DENT-01 (69 dents on a fixture, zero on PLAYGROUND) is what happens
## when they read the same.
## P-COOK moved this OUT of the builder, and the reason is not tidiness: a
## census describes a blast that HAPPENED. Once predictions became routine —
## a cursor sweeping GUs computes and discards one per target — a builder that
## printed would narrate every hover, and gating it behind a `quiet` flag went
## wrong the first time it was tried (a cache HIT returns the job that was built
## quietly, so the committing path silently lost its census).
##
## So the committing caller prints, from the finished Delta. `cost_ms` is the
## Delta's own §3.4 field and covers the WHOLE build, including any frames it
## spent suspended mid-slice — which is exactly the number §4.4's budget is
## judged against.
static func print_census(delta: WorldDelta, source_gu: Vector2i) -> void:
	var census: Dictionary = delta.census
	print("[E-PLAN] census gu=%s cost=%.1fms — surface/material: destroyed · dented · cracked (bake hits)"
		% [source_gu, delta.cost_ms])
	if census.is_empty():
		print("[E-PLAN]   (no container reached — nothing to damage)")
		return
	var groups: Array = census.keys()
	groups.sort()
	for group in groups:
		var row: Dictionary = census[group]
		print("[E-PLAN]   %-16s destroyed %4d · dented %4d · cracked %4d   (baked %d/live %d)" % [
			String(group).replace("|", "/"), int(row["destroy"]), int(row["dented"]),
			int(row["cracked"]), int(row["baked"]), int(row["live"])])


## §2's exposure fallback (B5): resolve the deep floor Slab's tiles (the
## common real case on PLAYGROUND — a real registered Slab always exists at
## FLOOR_DEEP_LEVEL) or the fixed earth plane beneath it (only reached once a
## SECOND blast opens the deep layer too — D2), WITHOUT applying either to
## the live layer. Mirrors TestZoneController's pre-reset _expose_below()
## exactly (same two branches, same below_level derivation).
static func _resolve_expose_below(slab: Slab, voxel_renderer: VoxelRendererClass, slab_registry: SlabRegistry) -> Array:
	var below_level: int = slab.level - 1
	var below_slab: Slab = slab_registry.get_slab(
		Slab.make_id(slab.gu_cell, Slab.Role.FLOOR, below_level))
	if below_slab != null:
		return voxel_renderer.reveal_floor_slab(below_slab, false)
	return voxel_renderer.render_fixed_earth_level(slab.gu_cell, below_level, false)


## The final `alt` for one cell: whatever bucket/soot the single light-field
## query gives it, preserving the flip bit the resolve step already decided
## (junction-mirror half-voxels bake their own H-flip into `base_alt` — the
## SAME technique VoxelRenderer._apply_light_to_layer() uses on `prev_alt`,
## just fed the fresh resolve's own alt instead of a live read).
static func _alt_for(field: VoxelLightFieldClass, cell: Vector2i, level: int, base_alt: int) -> int:
	var bucket: int = field.bucket_for(cell, level)
	var soot_code: int = field.face_soot_code(cell, level)
	var flipped: bool = VoxelRendererClass.decode_light_flipped(base_alt)
	return VoxelRendererClass.encode_voxel_alt(bucket, soot_code, flipped)


static func _append(by_ring: Dictionary, ring: int, entry: Dictionary) -> void:
	if not by_ring.has(ring):
		by_ring[ring] = []
	by_ring[ring].append(entry)


## E-SMOKE-01 — one puff descriptor for one damaged voxel, at that voxel's own
## world position (not its GU's centre: the point of going per-voxel is that the
## smoke traces the real shape of the damage).
##
## Three independent terms multiply into every puff, which is what produces
## "intensidades diferentes e durações diferentes" without a single random call:
##   · the damage tier's own base intensity (destroyed > dented > cracked);
##   · the bomb's `smoke_ring_weights[ring]`, so an outer ring genuinely wisps
##     less than the epicentre — the same table the GU-level path already read;
##   · a deterministic per-cell hash, so two neighbouring voxels in the same ring
##     and the same tier still differ. Scale/alpha and duration draw from
##     SEPARATE salts, so a big puff is not systematically also a long one.
##
## Records the voxel's GU in `smoked_gus` so the GU-level remainder pass at the
## end of build_plan() knows this GU is already covered.
static func _append_voxel_smoke(smoke_by_ring: Dictionary, smoked_gus: Dictionary,
		voxel: Voxel, ring: int, smoke_ring_weights: Array[float], tier_intensity: float,
		voxel_renderer: VoxelRendererClass, epicenter: Vector2i) -> void:
	if ring < 0 or ring >= smoke_ring_weights.size():
		return
	var weight: float = smoke_ring_weights[ring]
	if weight <= 0.0:
		return
	smoked_gus[GeometryCoords.voxel_to_gu(voxel.grid_pos)] = true

	var size_roll: float = _hash_unit("SMOKESIZE", voxel.grid_pos, voxel.level)
	var time_roll: float = _hash_unit("SMOKETIME", voxel.grid_pos, voxel.level)
	var strength: float = tier_intensity * weight
	var scale: float = maxf(
		SMOKE_SCALE_BASE * strength * (1.0 - SMOKE_JITTER + 2.0 * SMOKE_JITTER * size_roll), 0.05)
	var duration: float = maxf(
		lerpf(SMOKE_DURATION_FLOOR, 1.0, clampf(strength, 0.0, 1.0))
		* (1.0 - SMOKE_DURATION_JITTER + 2.0 * SMOKE_DURATION_JITTER * time_roll), 0.05)
	_append(smoke_by_ring, ring, {
		"world_pos": voxel_renderer.voxel_world_position(voxel.grid_pos, voxel.level),
		"duration": duration,
		"scale": scale,
		"alpha": clampf(strength * (0.6 + 0.8 * size_roll), 0.05, 1.0),
		"blobs": SMOKE_BLOBS_PER_VOXEL,
		"r": _radius_of(voxel.grid_pos, epicenter),
	})


## E-RADIAL-01 (Director, 2026-08-09): every plan entry carries its own distance
## from the epicentre, in voxels. This is what lets the choreographer replay the
## blast as an EXPANDING FRONT instead of category-by-category — see
## DetonationChoreographer.flatten_plan(). Computed here because this is the pass
## that already knows the epicentre; recomputing it downstream would mean handing
## the choreographer geometry it has no other reason to know.
static func _radius_of(cell: Vector2i, epicenter: Vector2i) -> float:
	return Vector2(cell - epicenter).length()


## A deterministic value in [0,1) for one cell under one salt — the project's
## standard FNV-1a roll (BlastCalculator's own idiom), reused here so smoke
## variation survives a re-run of the same capture.
static func _hash_unit(salt: String, cell: Vector2i, level: int) -> float:
	return float(FacadeSampler._fnv1a_hash("%s:%d,%d,%d" % [salt, cell.x, cell.y, level]) % 10000) / 10000.0
