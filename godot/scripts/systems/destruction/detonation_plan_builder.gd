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
static var SMOKE_SCALE_BASE: float = _env_float("INFILTRAITOR_SMOKE_SCALE", 1.7)

## A per-voxel puff is ONE blob, not the 2-3 cluster VFX-01 gives a lone
## destroyed voxel — there are now hundreds of them and each is meant to read as
## "um pouquinho de fumaça".
const SMOKE_BLOBS_PER_VOXEL: int = 1

## D-4 — the per-puff rise, multiplying `SmokeSparkOverlay.smoke_drift_y_*`.
## A `var` (Rule 1) and a LOOK stat: the spread is what stops a crater's smoke
## reading as one flat sheet lifting off together.
static var SMOKE_RISE_MIN: float = 0.65
static var SMOKE_RISE_MAX: float = 1.55

## D-4 — ⚠️ **THE PRICE OF THE THINNING, AND IT IS NOT A FREE PARAMETER.**
##
## `SMOKE_COLOR.a` is 0.2 and its own note explains why: the old model put ONE
## puff on every damaged voxel and got its density from OVERLAP, so no single disc
## could be legible on its own — at 0.8, 274 ring-0 puffs read as *"a heap of
## hard-edged discs"*. That note then warns that raising the alpha is the wrong
## lever for more smoke.
##
## It was right about that model. `smoke_chance` changes the model: at concrete's
## 0.40 there are 60% fewer puffs and the overlap the 0.2 was chosen for is gone,
## so keeping it would mean thinning a thing that was already invisible. Fewer,
## fatter, more opaque wisps IS the Director's *"uma fumacinha"* — one visible
## puff per surviving voxel rather than a fog nobody can resolve.
##
## Overridable for a bracket render: `INFILTRAITOR_SMOKE_ALPHA_GAIN`,
## `INFILTRAITOR_SMOKE_SCALE`, `INFILTRAITOR_SMOKE_CHANCE` (a global override of
## every material row). All three exist so the Director picks off a video instead
## of off a paragraph, and none is read per entry — see `_env_float()`.
static var SMOKE_ALPHA_GAIN: float = _env_float("INFILTRAITOR_SMOKE_ALPHA_GAIN", 2.4)


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
## E-JUNCTION-01 (2026-08-13): wall-junction corner columns, explosion-only
## (see find_affected_containers()'s own note) — mirrors PHASE_SLICES exactly,
## same simulate_container_damage() ring model, inserted right after it since
## a JunctionColumn is architecturally a diagonal wall segment.
const PHASE_JUNCTIONS: int = 2
const PHASE_ROOFS: int = 3
const PHASE_FLOORS: int = 4
const PHASE_WALK: int = 5
## D-2 (`DETONATION_PRESENTATION_MASTER_PLAN` §6): the fire, decided here and
## owned by the cook. It sits between WALK and SOOT because that is the only
## window where both halves of its input exist and both of its consumers are
## still ahead of it: WALK is what fills `flammable_cells`/`burn_cells` and
## `cell_to_voxel`, and SOOT/PACKAGE are what a burnt voxel has to reach to
## scorch, to land in `touched_this_blast`, and to be persisted. Built at the END
## of PHASE_SMOKE (where `_build_ember_wave()` used to be called) it was behind
## every one of them, which is exactly why the fire had to be a second mutation
## stream running under the animation.
const PHASE_BURN: int = 6
const PHASE_SOOT: int = 7
const PHASE_LIGHT: int = 8
const PHASE_PACKAGE: int = 9
const PHASE_EXPOSE: int = 10
const PHASE_SOOTWAVE: int = 11
const PHASE_SMOKE: int = 12
const PHASE_DONE: int = 13

const PHASE_NAMES: Array[String] = [
	"SETUP", "SLICES", "JUNCTIONS", "ROOFS", "FLOORS", "WALK", "BURN", "SOOT",
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
		PHASE_JUNCTIONS:
			_phase_junctions(s, deadline)
		PHASE_ROOFS:
			_phase_roofs(s, deadline)
		PHASE_FLOORS:
			_phase_floors(s, deadline)
		PHASE_WALK:
			_phase_walk(s, deadline)
		PHASE_BURN:
			_phase_burn(s)
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
	## E-JUNCTION-01: explosion-only (find_affected_containers()'s own note) —
	## ctx.get default keeps every non-explosion caller (firearms, selftests
	## that predate this) exactly as it was.
	var junction_columns: Array = ctx.get("junction_columns", [])
	var affected := BlastCalculatorClass.find_affected_containers(
		gu_rings, s["edge_registry"], s["slab_registry"], junction_columns)
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
	s["junction_ids"] = affected.get("junctions", {}).keys()
	s["junction_columns"] = junction_columns
	var junction_by_id: Dictionary = {}
	for column in junction_columns:
		junction_by_id[column.id] = column
	s["junction_by_id"] = junction_by_id

	s["soot_snapshot"] = {}
	s["soot_faces"] = {}
	s["ring_of"] = {}
	s["container_of"] = {}
	s["exposed_by_ring"] = {}
	s["cell_to_voxel"] = {}
	## E-EMBER-01: `{Vector3i: flammability}`, filled only for voxels whose
	## container's material actually catches — one table lookup per CONTAINER in
	## the walk, and a dictionary write only for the combustible ones. The
	## alternative (a whole-map cell -> material map) would add a write for every
	## voxel on the map to phase 4, which §8.8 already measures as 66% of the
	## build's whole cost.
	s["flammable_cells"] = {}
	## M3-3: the AMOUNT axis, alongside flammability's SPEED axis. Same shape and
	## same reason — one table lookup per CONTAINER, a dictionary write only for
	## the materials that actually burn away.
	s["burn_cells"] = {}
	## D-2 — `{Vector3i: {at, ring}}`, the voxels the fire consumes. Filled by
	## `_maybe_burn()` during PHASE_BURN and folded into the Delta in one batch at
	## the end of it; see `_commit_burn_to_delta()` for why it cannot be folded as
	## it is decided.
	s["burnt"] = {}
	## E-DEBRIS-01: which materials throw dust/sparks/chips and how often, as
	## plain data from the caller (`Room.blast_debris_policy()`). It travels in
	## `ctx` for the same reason `blast_soot_rings` does — the material→effect
	## mapping is room POLICY, and a builder that hardcoded it would be a second
	## place for the two weapon families to drift apart. Absent (every selftest
	## that predates this, and every non-explosion caller) means no debris at all,
	## which is exactly today's behaviour for those callers.
	s["debris_policy"] = ctx.get("debris", {})
	s["blast_cells"] = []
	s["weapon_cells"] = []
	s["damaged_voxels"] = []
	s["occupancy"] = {}
	s["touched_this_blast"] = {}
	s["touched_voxels"] = []
	s["census"] = {}
	s["smoked_gus"] = {}
	## D-4b — `{gu: [world_pos, level]}`, the HIGHEST damaged voxel of each GU the
	## blast reached. The seed for the rising plumes; see `_append_plumes()`.
	s["plume_gus"] = {}

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
		## LEVEL-RENUMBER — a real level, because `simulate_container_damage()`
		## subtracts it from `voxel.level`. Unshifted it made every offset ~80, the
		## ring lookup ran off its table and the blast damaged NOTHING.
		var base_level: int = GeometryCoords.storey_level_base(slice.start_storey)
		## GLASS G3-C — a glass PANEL is pulled out of the ring-scatter model: it
		## fractures, it does not deform, so it breaks whole (below) or not at all.
		## Glass BLOCKS keep the ring model (pane-shatter is deferred for them).
		if not _is_glass_pane_slice(slice):
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
		_shatter_glass_panes(s)
		_enter_phase(s, PHASE_JUNCTIONS)


## GLASS G3-C — true for a glass PANEL slice (has a pane_id, not a BLOCK).
static func _is_glass_pane_slice(slice: Slice) -> bool:
	return slice != null and slice.material == "glass" \
		and slice.pane_id != "" and not slice.pane_id.begins_with("PANE_BLOCK_")


## GLASS G3-C (GLASS_MASTER_PLAN §5.1) — a pane inside the blast's damage area
## breaks EFFECTIVELY. Groups the affected glass panel slices by `pane_id`, keeps
## the nearest ring, rolls one shatter per pane off the blast's per-ring falloff
## (GlassShatter.blast_glass_punch), and on a win floods the whole pane
## (plan_pane_shatter, with the G-D13 frame-ring remnants) into the Delta as
## blast-sourced DESTROYED entries. Deterministic: the roll and the remnant
## pattern hash off (source_gu, pane_id), so a replay matches.
static func _shatter_glass_panes(s: Dictionary) -> void:
	var edge_registry: EdgeRegistry = s["edge_registry"]
	var slab_registry: SlabRegistry = s["slab_registry"]
	var affected: Dictionary = s["affected"]["slices"]
	var bomb_def = s["bomb_def"]
	var delta: WorldDelta = s["delta"]
	var epicenter: Vector2i = s["epicenter"]
	var source_gu: Vector2i = s["source_gu"]

	var pane_min_ring: Dictionary = {}   ## pane_id -> nearest ring
	for sid in affected:
		var slc: Slice = edge_registry.get_slice(sid)
		if not _is_glass_pane_slice(slc):
			continue
		var r: int = int(affected[sid])
		if not pane_min_ring.has(slc.pane_id) or r < int(pane_min_ring[slc.pane_id]):
			pane_min_ring[slc.pane_id] = r
	if pane_min_ring.is_empty():
		return

	## Collect each pane's slices once. `all_slices` is hoisted because G-D13b's
	## anchor scan below needs the same registry-wide list.
	var all_slices: Array = edge_registry.all_slices()
	var slices_by_pane: Dictionary = {}
	for slc2 in all_slices:
		if slc2.pane_id in pane_min_ring:
			if not slices_by_pane.has(slc2.pane_id):
				slices_by_pane[slc2.pane_id] = []
			slices_by_pane[slc2.pane_id].append(slc2)

	for pid in pane_min_ring:
		var ring: int = int(pane_min_ring[pid])
		var glass_punch: float = GlassShatter.blast_glass_punch(bomb_def.ring_multipliers, ring)
		var salt := "BLAST_%d_%d_%s" % [source_gu.x, source_gu.y, pid]
		if not GlassShatter.rolls_shatter(glass_punch, salt):
			continue
		var pane_slices: Array = slices_by_pane.get(pid, [])
		if pane_slices.is_empty():
			continue
		## Flood origin = the pane voxel nearest the epicenter.
		var face: int = pane_slices[0].face
		var origin_v: Voxel = null
		var best_d: float = INF
		for ps in pane_slices:
			for v in ps.voxels:
				if not v.visible or v.damage_state == Voxel.DamageState.DESTROYED:
					continue
				var d: float = Vector2(v.grid_pos - epicenter).length()
				if d < best_d:
					best_d = d
					origin_v = v
		if origin_v == null:
			continue
		## G-D13b — same anchor rule as the shot path: remnants only where the pane
		## touches non-glass material. `all_slices` is the registry-wide list this
		## function already walked to group the panes.
		var anchors: Dictionary = GlassShatter.collect_anchor_positions(
			pane_slices, face, all_slices)
		var plan: Array = GlassShatter.plan_pane_shatter(pane_slices, face,
			origin_v.grid_pos, origin_v.level, glass_punch, salt, anchors)
		var entries: Array = []
		var fallen: Array = []
		for e in plan:
			var pv: Voxel = e["slice"].voxels[int(e["voxel_index"])]
			if pv.damage_state == Voxel.DamageState.DESTROYED:
				continue
			entries.append(BlastCalculatorClass.damage_entry(pv, Voxel.DamageState.DESTROYED, true))
			fallen.append({"grid_pos": pv.grid_pos, "level": pv.level})
		if not entries.is_empty():
			delta.add_damage(entries)
			print_debug("[GLASS-SHATTER-BLAST] pane=%s ring=%d glass_punch=%.2f flooded=%d voxel(s)"
				% [pid, ring, glass_punch, entries.size()])
			## G-D16a — the same landing report the shot path makes. Both paths or
			## neither: a pane shattered by a grenade producing no shard state while a
			## shot one does is exactly the asymmetry that gets found months later.
			var landings: Array = GlassFall.plan_landings(fallen, slab_registry.all_slabs())
			var piles: Dictionary = GlassFall.pile_by_cell(landings)
			var deepest: int = 0
			for c in piles.values():
				deepest = maxi(deepest, int(c))
			print_debug("[GLASS-FALL] %d of %d shard(s) landed, on %d cell(s), deepest pile %d (%d fell out of the world)"
				% [landings.size(), entries.size(), piles.size(), deepest, entries.size() - landings.size()])


## E-JUNCTION-01 (2026-08-13): wall-junction corner columns — mirrors
## _phase_slices() exactly (same simulate_container_damage() ring model,
## since a JunctionColumn is a diagonal wall segment structurally), reading
## from junction_by_id instead of edge_registry.get_slice() because
## JunctionColumn has no owning registry of its own, only the flat Array
## room._junction_columns arrived in.
static func _phase_junctions(s: Dictionary, deadline: int) -> void:
	var ids: Array = s["junction_ids"]
	var junction_by_id: Dictionary = s["junction_by_id"]
	var affected: Dictionary = s["affected"]["junctions"]
	var bomb_def = s["bomb_def"]
	var delta: WorldDelta = s["delta"]
	var epicenter: Vector2i = s["epicenter"]
	var ring_of: Dictionary = s["ring_of"]
	var container_of: Dictionary = s["container_of"]
	var i: int = int(s["cursor"])
	while i < ids.size():
		var column = junction_by_id[ids[i]]
		var base_ring: int = affected[ids[i]]
		var base_level: int = GeometryCoords.storey_level_base(column.start_storey)
		delta.add_damage(BlastCalculatorClass.simulate_container_damage(
			column.voxels, column.id, column.material, base_ring, base_level, false,
			bomb_def.ring_multipliers, bomb_def.destroy_ring_weights,
			bomb_def.dent_ring_weights, bomb_def.crack_ring_weights, epicenter))
		for v in column.voxels:
			var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
			ring_of[key] = base_ring + BlastCalculatorClass.vertical_ring_for(v.level - base_level)
			container_of[key] = column
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
		## E-JUNCTION-01: every junction column, not just the ones this blast
		## hit — same reason the walk covers every Slice/Slab regardless of
		## rings, since this pass is what makes soot/occupancy correct for the
		## WHOLE map, not just this blast's own reach.
		for column in (s["junction_columns"] as Array):
			walk.append([column, true])
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
	var flammable_cells: Dictionary = s["flammable_cells"]
	var burn_cells: Dictionary = s["burn_cells"]
	var chunk: int = WALK_CHUNK
	var ci: int = int(s["cursor"])
	var vi: int = int(s["sub"])
	var since_check: int = 0

	while ci < containers.size():
		var entry: Array = containers[ci]
		var voxels: Array = entry[0].voxels
		var is_slice: bool = bool(entry[1])
		## E-EMBER-01, resolved once per container rather than per voxel. D19 is
		## why this reads the material and not the surface: "a material behaves
		## identically on floor, wall and ceiling — durability, baked assets,
		## soot, effects, ember." The pre-2026-08-05 VL-D4 loop collected wood
		## from SLICES only, so a wood floor never glowed; that was an oversight
		## the D19 reform had already outlawed, not a look to reproduce.
		var flammability: float = MaterialResistanceTable.flammability(
			_material_name(entry[0]))
		var consumption: float = MaterialResistanceTable.burn_consumption(
			_material_name(entry[0]))
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
			if flammability > 0.0:
				flammable_cells[key] = flammability
				if consumption > 0.0:
					burn_cells[key] = consumption
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
	_enter_phase(s, PHASE_BURN)


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
## SS-3 (`SOOT_STORAGE_REFORM` §3.1) — this phase now also produces the blast's
## scorch as a PROPOSAL on the Delta (`delta.scorch_writes`), which `commit()`
## writes to the store. Nothing here mutates: the phase stays as pure as it has
## always been, which is the whole reason the soot layer was chosen as *"a model
## to copy"* by `PREDICTION_MASTER_PLAN` §2.2. What changes is that the proposal
## now has somewhere to go other than the animation.
static func _phase_soot(s: Dictionary, deadline: int) -> void:
	var ctx: Dictionary = s["ctx"]
	var delta = s["delta"]
	BlastCalculatorClass.build_soot_field(
		s["cell_to_voxel"], s["blast_cells"], s["weapon_cells"], s["damaged_voxels"],
		ctx.get("blast_soot_rings", 4), ctx.get("weapon_soot_rings", 3),
		s["soot_snapshot"], s["soot_faces"], _cells_this_blast_reveals(s), [],
		delta.scorch_writes)
	_scorch_revealed_fixed_cells(s, s["soot_snapshot"], s["soot_faces"],
		delta.scorch_writes)
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
		out_faces: Dictionary, out_full: Dictionary = {}) -> void:
	var cell_to_voxel: Dictionary = s["cell_to_voxel"]
	for ring_key in s["exposed_by_ring"].keys():
		for e in s["exposed_by_ring"][ring_key]:
			var pos: Vector2i = e["grid_pos"]
			var level: int = e["level"]
			if cell_to_voxel.has(Vector3i(pos.x, pos.y, level)):
				continue   ## a real Voxel — the BFS already owns it
			BlastCalculatorClass.scorch_floor_cell(out_snapshot, out_faces,
				level, pos, BlastCalculatorClass.EXPOSED_FLOOR_SOOT_RING, out_full)


## --- Phase 6: ATOMIC. The single map-wide light-field query (§2). ----------
## Built ONCE, queried per cell below. VoxelLightField.build() never touches the
## TileMapLayer, and nothing here calls VoxelRenderer.apply_light_field().
static func _phase_light(s: Dictionary) -> void:
	var ctx: Dictionary = s["ctx"]
	var voxel_renderer: VoxelRendererClass = s["voxel_renderer"]
	var lights: Array = ctx.get("lights", [])
	var field := VoxelLightFieldClass.new()
	## D-7 (§7.4) — MAP-WIDE occupancy, not `s["occupancy"]` (which PHASE_WALK only
	## fills for the affected containers). The soot wave still only QUERIES the
	## blast neighbourhood, so a scoped occupancy was enough for it; but the room
	## applies this same field to `light_changed_cells` afterwards, and a cell at
	## the edge of the scoped set would see phantom holes beyond it. `build()` is
	## lazy — this is one `get_used_cells()` walk, the buckets are still computed
	## on first query in the soot wave.
	var predict_destroyed: Dictionary = {}
	for k in s["blast_cells"]:
		predict_destroyed[k] = true
	for k in s["weapon_cells"]:
		predict_destroyed[k] = true
	field.build(lights, ctx.get("shadow_results", []),
		voxel_renderer.top_wall_level(),
		voxel_renderer.build_occupancy(predict_destroyed),
		s["soot_snapshot"], s["under_structure"], s["soot_faces"])
	s["field"] = field
	s["ring_keys"] = s["ring_of"].keys()
	## D-7 (§7.4) — carry the field to the Delta. `_phase_soot_wave` fills
	## `light_changed_cells` (the set it also emits to `waves["soot"]`); the room
	## applies the field to exactly those, in ~18 ms, instead of re-deriving.
	var delta = s["delta"]
	delta.light_field = field
	## TEMPORAL LIGHTS DISQUALIFY THE SHORTCUT — a flicker/pulse/rotating light
	## changes every frame, and this field is fixed seconds ago at cook time.
	## Applying it forward would freeze that light's contribution at a stale value
	## until the next full repaint. Detected here, once, off the light list the
	## field was built from.
	var temporal: bool = false
	for light in lights:
		if light == null:
			continue
		var rot: Variant = light.get("rotation_speed")
		if light.get("flicker_enabled") == true or light.get("pulse_enabled") == true \
				or (rot != null and absf(float(rot)) > 0.0):
			temporal = true
			break
	delta.light_field_usable = not temporal
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
					smoke_weights, DESTROY_SMOKE_INTENSITY, voxel_renderer, epicenter,
					_material_name(container), s["plume_gus"])
				_append(waves["destroy"], ring, {"cell": voxel.grid_pos, "level": voxel.level,
					"r": _radius_of(voxel.grid_pos, epicenter)})
				_append_voxel_debris(waves["debris"], voxel, ring, _material_name(container),
					s["debris_policy"], voxel_renderer, epicenter)
			elif state == Voxel.DamageState.DENTED or state == Voxel.DamageState.CRACKED:
				touched_this_blast[key] = true
				touched_voxels.append(voxel)
				_append_voxel_smoke(waves["smoke"], smoked_gus, voxel, ring, smoke_weights,
					DENT_SMOKE_INTENSITY if state == Voxel.DamageState.DENTED
						else CRACK_SMOKE_INTENSITY,
					voxel_renderer, epicenter, _material_name(container), s["plume_gus"])
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
					"alt": alt, "soot": field.face_soot_code(voxel.grid_pos, voxel.level),
					"r": _radius_of(voxel.grid_pos, epicenter)})
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
				"soot": field.face_soot_code(e["grid_pos"], e["level"]),
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
					var soot_code: int = field.face_soot_code(cell, level)
					## ⚠️ PERF-P2b — THE COMPARISON HAD TO GROW A SECOND HALF.
					## It used to read "equal alt = nothing this blast changes
					## here", and that was true only while the alt carried soot.
					## With scorch in its own plane, a cell whose SOOT changes and
					## whose bucket does not now compares equal — which is every
					## cell this wave exists for. Left alone, the soot wave would
					## have come out EMPTY with no error anywhere.
					if alt != prev_alt \
							or soot_code != voxel_renderer.cell_soot_at(level, cell):
						_append(waves["soot"], ring, {"cell": cell, "level": level,
							"source_id": source_id,
							"atlas_coords": layer.get_cell_atlas_coords(cell),
							"alt": alt, "soot": soot_code,
							"r": _radius_of(cell, epicenter)})
						## D-7 (§7.4) — the same set, keyed for `apply_light_field_cells()`.
						## Every cell whose displayed light or soot this blast moves and
						## that is not a damaged cell (those carry their alt in the
						## commit's own destroy/dent/crack entry).
						s["delta"].light_changed_cells[Vector3i(cell.x, cell.y, level)] = true
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
			"r": _radius_of(gu_center, epicenter),
			## E-ORDER-01 — see `_append_voxel_smoke()`. This is the GU-level
			## remainder, so its cell is the GU's centre voxel, which is already the
			## point its radius is measured from.
			"cell": gu_center})
		if _out_of_time(deadline):
			break
	s["cursor"] = i
	if i >= gus.size():
		_append_plumes(s)
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


## --- E-EMBER-01: the combustible edge of this blast's holes. ---------------
##
## Restores VL-D4 ("wood ficar em brasa no momento da explosão, e depois de
## alguns segundos escurecer"), removed on 2026-08-05 by the `[RESET]` commit
## `d4124809` along with `TestZoneController._is_freshly_scorched()`, and never
## reconnected when Task 5 (E-WAVE) brought the trigger back. Three docs went on
## describing it as shipped for eight days; nothing in code had fired one since.
##
## The predicate is the original's, unchanged: a voxel that SURVIVES with at
## least one of its six neighbours gone glows. Not the destroyed voxel — the
## edge of the hole is what stays on screen to cool down, and the glow fading
## reveals the soot already painted under it.
##
## Seeded from this blast's own destroy entries rather than from the soot
## snapshot, even though soot ring 0 is the same predicate. The snapshot merges
## firearm holes and every older crater on the map, so seeding from it would
## light wood next to a bullet hole across the room every time a grenade went
## off somewhere else. A blast's embers belong to that blast.
##
## Cost is (this blast's holes x 6) dictionary lookups — no BFS, no second walk.
## --- Phase 6: the fire. -----------------------------------------------------
##
## ⚠️ **SEEDED FROM THE DELTA'S PROJECTION, NOT FROM `waves["destroy"]`** — and
## that is the whole reason this could move. The old call site ran at the END of
## PHASE_SMOKE and read the packaged destroy wave, which does not exist until
## PHASE_PACKAGE. The set is identical either way: PACKAGE appends a destroy
## entry for exactly the `ring_of` keys whose projected state is DESTROYED, which
## is what the loop below walks. Pre-existing holes inside an affected container
## are in BOTH (`state_of()` falls through to the real Voxel), so they keep
## seeding embers exactly as they did.
##
## ⚠️ **THE BURN ENTRIES ARE FOLDED IN ONE BATCH AT THE END, NEVER AS THEY ARE
## DECIDED.** `add_damage()` folds immediately, so a burnt voxel folded mid-pass
## would read DESTROYED to the next seed/climb test and silently stop lighting.
## Collecting first and folding once keeps the ember set bit-identical to the
## scheduled fire's, which is what makes this a change of OWNERSHIP rather than
## a change of look.
static func _phase_burn(s: Dictionary) -> void:
	_build_ember_wave(s)
	_commit_burn_to_delta(s)
	_mark_burnt_embers(s)
	_enter_phase(s, PHASE_SOOT)


## D-4 — A LITTLE MORE BRASA ON THE MATERIALS THAT BURN
## (`DETONATION_PRESENTATION_MASTER_PLAN` §5.1, downscoped by the Director on
## 2026-08-29: *"a gente já chegou num visual bem bom, só falta um pouquinho de
## brasa nos materiais moles… o que a gente conseguir colocar de vermelho
## brilhando que vira preto é lucro. De resto pode deixar assim mesmo."*).
##
## §5.1's full spec — a vibrating flame at each hole edge, an incandescent voxel
## left behind, transmission that turns a voxel to ash — is NOT built. It does not
## need to be: `_build_ember_wave()` already queues exactly one ember on every
## voxel the fire consumes (`_maybe_burn()` is only ever called right after that
## cell gets its ember, so `burnt` ⊆ the ember wave's cells), and `EmberOverlay`
## already ramps yellow-hot → deep red → charcoal and hands a puff to the smoke
## overlay on death. That IS "vermelho que vira preto"; it was just tuned small
## and dim for a hard-material crater's crowding (E-EMBER-02).
##
## So this only FLAGS those embers. The writer routes a flagged one through a
## boosted profile (`EmberOverlay.burnt_ember_*`) — bigger, longer, and slower to
## cool — so a soft-material blast reads as "it caught" without touching wood's
## ratified look, which produces no `burnt` cells and no flag.
##
## ⚠️ A flagged ember sits ON the hole the fire opened, which is the exact
## opposite of `_build_ember_wave()`'s survivor predicate (test_7 pins that for
## the UNFLAGGED embers). The glow still fades to reveal the scorch under it, the
## same way an edge ember does — the voxel is simply gone underneath now.
static func _mark_burnt_embers(s: Dictionary) -> void:
	var burnt: Dictionary = s["burnt"]
	if burnt.is_empty():
		return
	var ember_by_ring: Dictionary = s["waves"]["ember"]
	var marked: int = 0
	for ring in ember_by_ring.keys():
		for entry: Dictionary in ember_by_ring[ring]:
			var key := Vector3i(entry["cell"].x, entry["cell"].y, int(entry["level"]))
			if burnt.has(key):
				entry["burnt"] = true
				## The pace the retired burn schedule ran at (`_maybe_burn()`),
				## kept purely so `DetonationPresenter._delay_for()` can release
				## these in the order the fire actually spread — §5.1's "which
				## voxels wear an ember, in what order, is what tells the story".
				## The choreographer ignores it and paces with the radial front.
				entry["at"] = float(burnt[key]["at"])
				marked += 1
	print("[E-BURNEMBER] %d of %d burnt cell(s) carry a boosted ember" % [marked, burnt.size()])


## D-2 — the fire stops being a second mutation stream.
##
## `_maybe_burn()` has already decided WHICH voxels the fire consumes, with the
## same FNV-1a rolls as before. This is where that decision becomes damage on the
## Delta instead of a schedule the room plays out over 1.38 s afterwards.
##
## Four consequences, in the order they matter, and each one is a defect closing:
##
##  1. **§9.11e dies at its root.** `touched_this_blast` is built by PHASE_PACKAGE
##     from the projected state, so a fire-consumed voxel now lands in it and the
##     soot wave stops replaying a cook-time `source_id` onto a cell the fire has
##     since erased. Measured before: `[E-FUME-ERASED] 350 of 1914`.
##  2. **The scorch survives**, which is the Director's §5.3 ruling and the reason
##     a guard was refused: a burnt cell is appended to `blast_cells`, so the soot
##     BFS in PHASE_SOOT seeds from it exactly as it does from a blast hole.
##  3. **The light is right.** `occupancy` was built by PHASE_WALK from the
##     projection and the fire was not in it yet; the burnt cells are erased from
##     it here, before PHASE_LIGHT builds the field over it.
##  4. **Rotation keeps them.** PHASE_PACKAGE puts them in `touched_voxels`, which
##     is VL-PERSIST's seam — the burn path had to call
##     `record_voxel_damage_to_base()` by hand for exactly this reason.
##
## `ring_of`/`container_of` are filled in for any burnt voxel that has none. The
## ember pass reaches neighbours through the map-wide `cell_to_voxel`, so the fire
## can consume a voxel in a container this blast never damaged — and PHASE_PACKAGE
## walks `ring_of` keys, so without this such a voxel would be destroyed on the
## Delta and reach no wave, no census and no persistence.
static func _commit_burn_to_delta(s: Dictionary) -> void:
	var burnt: Dictionary = s["burnt"]
	if burnt.is_empty():
		return
	var delta: WorldDelta = s["delta"]
	var cell_to_voxel: Dictionary = s["cell_to_voxel"]
	var occupancy: Dictionary = s["occupancy"]
	var blast_cells: Array = s["blast_cells"]
	var ring_of: Dictionary = s["ring_of"]
	var container_of: Dictionary = s["container_of"]
	var entries: Array = []
	for key: Vector3i in burnt.keys():
		var voxel: Voxel = cell_to_voxel.get(key)
		if voxel == null:
			continue
		## from_blast TRUE: the fire is the blast's own consequence, and D24
		## derives scorch from ABSENT voxels by provenance. A burnt-away voxel that
		## claimed to be a bullet hole would scorch with the wrong soot.
		entries.append(BlastCalculatorClass.damage_entry(
			voxel, Voxel.DamageState.DESTROYED, true))
		blast_cells.append(key)
		var by_level: Dictionary = occupancy.get(voxel.level, {})
		if not by_level.is_empty():
			by_level.erase(voxel.grid_pos)
		if not ring_of.has(key):
			ring_of[key] = int(burnt[key]["ring"])
			var cid: int = voxel.container_id()
			if cid != 0:
				container_of[key] = instance_from_id(cid)
	delta.add_damage(entries)
	delta.burnt_cells = burnt


static func _build_ember_wave(s: Dictionary) -> void:
	var flammable_cells: Dictionary = s["flammable_cells"]
	if flammable_cells.is_empty():
		return
	var cell_to_voxel: Dictionary = s["cell_to_voxel"]
	var delta: WorldDelta = s["delta"]
	var voxel_renderer: VoxelRendererClass = s["voxel_renderer"]
	var epicenter: Vector2i = s["epicenter"]
	var waves: Dictionary = s["waves"]
	var ring_of: Dictionary = s["ring_of"]
	var seen: Dictionary = {}
	for origin_key: Vector3i in ring_of.keys():
		var hole_voxel: Voxel = cell_to_voxel.get(origin_key)
		if hole_voxel == null or delta.state_of(hole_voxel) != Voxel.DamageState.DESTROYED:
			continue
		var ring: int = int(ring_of[origin_key])
		for d: Vector3i in EMBER_NEIGHBOURS:
			var ncell: Vector3i = origin_key + d
			if seen.has(ncell):
				continue
			var flammability: float = float(flammable_cells.get(ncell, 0.0))
			if flammability <= 0.0:
				continue
			var neighbour: Voxel = cell_to_voxel.get(ncell)
			if neighbour == null:
				continue
			## PROJECTED, not live — the same trap phase 4 names for
			## `damaged_voxels`. The real Voxel still reads INTACT/visible
			## here (nothing has committed yet), so a voxel this very blast
			## destroys would light up as if it had survived.
			var p: Array = delta.projection_of(neighbour)
			var touched: bool = not p.is_empty()
			var state: int = int(p[WorldDelta.P_STATE]) if touched else neighbour.damage_state
			var vis: bool = bool(p[WorldDelta.P_VISIBLE]) if touched else neighbour.visible
			if not vis or state == Voxel.DamageState.DESTROYED:
				continue
			seen[ncell] = true
			_append(waves["ember"], ring, {
				"cell": neighbour.grid_pos,
				"level": neighbour.level,
				"world_pos": voxel_renderer.voxel_world_position(
					neighbour.grid_pos, neighbour.level),
				"duration_scale": flammability,
				## E-EMBER-02 tuning pass: a small per-cell stagger. Without it
				## every seed in a crater ignites on the SAME frame at the same
				## hot end of the ramp, and under ADD blending ~137 of them sum
				## into one molten sheet the shape of the crater (seen directly
				## on the first filmstrip). Spread over a fraction of a second
				## they read as a patch catching, which is also the Director's
				## own "tudo com duração e velocidades ligeiramente diferentes".
				"delay": EMBER_SEED_STAGGER_S * _hash_unit(
					"EMBERSEED", neighbour.grid_pos, neighbour.level),
				## Rank in the upward creep — 0 is a seed beside a real hole,
				## >0 is a rung the fire climbed to. Carried explicitly rather
				## than inferred from `delay`, which stopped being a reliable
				## discriminator the moment seeds got a stagger of their own.
				"climb": 0,
				"r": _radius_of(neighbour.grid_pos, epicenter),
			})
			_maybe_burn(s, neighbour, ring, EMBER_SEED_STAGGER_S * _hash_unit(
				"EMBERSEED", neighbour.grid_pos, neighbour.level), flammability,
				_radius_of(neighbour.grid_pos, epicenter))
			_climb_from(ncell, ring, s, seen, waves["ember"])


## E-EMBER-02 (Director, 2026-08-13): *"os voxels também se propagam para cima,
## de maneira mais comedida e errática, apagando logo em seguida."*
##
## Fire creeps UP from a lit voxel, one level at a time, and stops at the first
## level that does not catch — a continuous creep, not a scatter of independent
## lights up the column. That single rule is most of what makes it read as
## "comedido": the chance decays with height AND any miss ends the climb, so a
## tall wall lights a short tongue rather than a full stripe.
##
## Rolled from FNV-1a per cell, never `randf()`. This runs inside `build_plan()`,
## which is PURE and whose output the prediction layer caches and the filmstrip
## replays — a runtime roll here would make two captures of the same detonation
## differ, and CLAUDE.md's own pixel-diff discipline (36 733 differing pixels
## from one non-deterministic capture) is what that costs.
##
## Each rung starts LATER and lives SHORTER than the one below it, which is the
## "apagando logo em seguida" half and also what keeps the climb from reading as
## a solid bar appearing at once.
static func _climb_from(origin: Vector3i, ring: int, s: Dictionary,
		seen: Dictionary, ember_by_ring: Dictionary) -> void:
	var flammable_cells: Dictionary = s["flammable_cells"]
	var cell_to_voxel: Dictionary = s["cell_to_voxel"]
	var delta: WorldDelta = s["delta"]
	var voxel_renderer: VoxelRendererClass = s["voxel_renderer"]
	var epicenter: Vector2i = s["epicenter"]
	var chance: float = EMBER_CLIMB_CHANCE
	for step in range(1, EMBER_CLIMB_MAX_LEVELS + 1):
		var up := Vector3i(origin.x, origin.y, origin.z + step)
		if seen.has(up):
			return
		var flammability: float = float(flammable_cells.get(up, 0.0))
		if flammability <= 0.0:
			return
		var voxel: Voxel = cell_to_voxel.get(up)
		if voxel == null:
			return
		var p: Array = delta.projection_of(voxel)
		var touched: bool = not p.is_empty()
		var state: int = int(p[WorldDelta.P_STATE]) if touched else voxel.damage_state
		var vis: bool = bool(p[WorldDelta.P_VISIBLE]) if touched else voxel.visible
		if not vis or state == Voxel.DamageState.DESTROYED:
			return
		if _hash_unit("EMBERCLIMB", voxel.grid_pos, voxel.level) > chance:
			return
		seen[up] = true
		var jitter: float = _hash_unit("EMBERDELAY", voxel.grid_pos, voxel.level)
		_append(ember_by_ring, ring, {
			"cell": voxel.grid_pos,
			"level": voxel.level,
			"world_pos": voxel_renderer.voxel_world_position(voxel.grid_pos, voxel.level),
			"duration_scale": flammability * pow(EMBER_CLIMB_LIFE_DECAY, float(step)),
			"delay": EMBER_CLIMB_DELAY_S * float(step)
				* (1.0 - EMBER_CLIMB_DELAY_JITTER + 2.0 * EMBER_CLIMB_DELAY_JITTER * jitter),
			"climb": step,
			"r": _radius_of(voxel.grid_pos, epicenter),
		})
		_maybe_burn(s, voxel, ring, EMBER_CLIMB_DELAY_S * float(step), flammability,
			_radius_of(voxel.grid_pos, epicenter))
		chance *= EMBER_CLIMB_DECAY


## M3-3 — a lit voxel that will be CONSUMED, and when.
##
## Records the cell in `s["burnt"]` — a damage entry on the Delta, destroyed in
## the commit frame with everything else (D-2). `at` survives as visual
## attribution only: which voxel wears an ember, and in what order, is what tells
## the story once the world has already changed.
##
## The roll is FNV-1a per cell, never randf(), for `_climb_from()`'s own stated
## reason — this runs inside build_plan(), whose output the prediction layer
## caches and the filmstrip replays.
##
## Only reaches materials with `burn_consumption > 0`, so wood's ratified VL-D4
## look is untouched: it still glows and leaves its geometry standing.
## PERF-F3/F4 — HOW MUCH THE BLAST TAKES OUTRIGHT, and how much is left to burn.
##
## Director, 2026-08-23: *"a explosão pode destruir mais voxels de uma vez e queimar
## só o final do tecido e do papelão… vamos testar inicialmente uns 70% da area
## afetada, e queima o que sobrar"* — soft materials are curtains, boxes and props,
## not whole walls (MATERIALS M3-5b), so a fire's job is the REMNANT (§3.1a) rather
## than the surface.
##
## ⚠️ IMPLEMENTED IN THE SCHEDULE, NOT IN THE RESISTANCE MODEL. The `destroy` wave
## is CHOREOGRAPHY; the actual damage comes from `delta.state_of(voxel)`, i.e. from
## BlastCalculator. Forcing 70% through there would mean editing the resistance
## model to get a scheduling outcome, which is the wrong lever and puts the
## destruction selftests at risk for a tuning number. Instead the share lands in
## the fire's FIRST batch (`at = lit_at`), which is one committing frame and reads
## as the blast having taken it.
##
## ⚠️ AND IT IS NOT WHERE THE PERFORMANCE WIN COMES FROM. The committing-frame
## COUNT is the fire's duration over BURN_COMMIT_INTERVAL_S, and the 30% remnant
## still spans the same window — so this cuts the WORK inside a frame (~36 ms of
## ~350) and not the number of frames. PERF §9's F1 is what carries the win; this
## carries the design, and less total burn work with it.
##
## A `static var` rather than a const: it is a STAT the Director tunes (Rule 1),
## and the roll is FNV-1a per cell for the same reason every other roll here is —
## build_plan() is pure and its output is cached and replayed.
static var blast_takes_share: float = 0.70

## D-2 (`DETONATION_PRESENTATION_MASTER_PLAN` §6) — the fire is the cook's: which
## voxels it consumes is folded into the Delta (`_commit_burn_to_delta()`) and
## destroyed in the commit frame, not played out over ~1.4 s by a `BurnScheduler`.
## D-6 (2026-08-29) deleted the schedule path outright.
##
## `INFILTRAITOR_NO_BURN=1` runs a blast with the fire suppressed — a control for
## captures that want the same detonation without anything it lit burning away.
## Read once into a `static var` rather than per call: `build_plan()` is pure and
## its output is CACHED, so a switch that could change between two cooks of the
## same world revision would hand back a Delta built under the other rule.
static var no_burn: bool = OS.get_environment("INFILTRAITOR_NO_BURN") == "1"


static func _maybe_burn(s: Dictionary, voxel: Voxel, ring: int,
		lit_at: float, flammability: float, entry_radius: float = 0.0) -> void:
	if no_burn:
		return
	var burn_cells: Dictionary = s["burn_cells"]
	var key := Vector3i(voxel.grid_pos.x, voxel.grid_pos.y, voxel.level)
	var consumption: float = float(burn_cells.get(key, 0.0))
	if consumption <= 0.0:
		return
	## ⚠️ 1.0 IS UNCONDITIONAL, and that is the whole semantics of the column.
	## §3.1: *"'Burns entirely' makes fabric and cardboard OBJECT-scoped, not
	## radius-scoped… the old 'how far does it spread' question only ever applied
	## to plywood."* So a material at 1.0 burns wherever it caught, and anything
	## BELOW 1.0 is a base probability the position then modulates. One number,
	## two behaviours, and no second flag to keep in sync with the first.
	var effective: float = consumption
	if consumption < 1.0:
		var reach: float = 1.0 - float(entry_radius) / BURN_RADIAL_REACH_VOXELS
		effective = consumption * clampf(reach, 0.0, 1.0)
	if _hash_unit("BURNROLL", voxel.grid_pos, voxel.level) > effective:
		return
	var jitter: float = 1.0 - BURN_LIFE_JITTER \
		+ 2.0 * BURN_LIFE_JITTER * _hash_unit("BURNLIFE", voxel.grid_pos, voxel.level)
	var life: float = BURN_BASE_LIFE_S * maxf(flammability, 0.01) * jitter
	## PERF-F3/F4 — the blast's share goes in the FIRST batch. Its own hash domain
	## ("BURNSHARE"), so changing this split cannot shift which voxels burn at all
	## (BURNROLL) or how long the survivors take (BURNLIFE) — three independent
	## rolls, so one can be tuned without disturbing the other two.
	if _hash_unit("BURNSHARE", voxel.grid_pos, voxel.level) < blast_takes_share:
		life = 0.0
	## D-2 — THE DECISION IS THE SAME; WHERE IT LANDS IS NOT.
	##
	## Every roll above is untouched (BURNROLL picks the voxels, BURNLIFE their
	## pace, BURNSHARE the split), so which voxels the fire consumes is bit-identical
	## to the scheduled path. What changes is that the answer goes into a SET the
	## cook then folds into the Delta (`_commit_burn_to_delta()`) instead of into a
	## wave the room plays out over 1.38 s afterwards.
	##
	## `at` survives as **visual attribution only** — §6.2: everything is destroyed
	## in the commit frame, and which voxels wear an ember, in what order, is what
	## tells the story. It is what D-4's symbolic fire reads for its per-instance
	## phase. Nothing mutates the world off it any more, which is also why
	## `blast_takes_share` stopped being a performance lever and became a look one.
	s["burnt"][Vector3i(voxel.grid_pos.x, voxel.grid_pos.y, voxel.level)] = {
		"at": lit_at + life, "ring": ring,
	}


## How far a creep may reach above the voxel that lit it, and how willingly.
## All `var`-free by intent: these are structural limits on the plan's size, not
## per-difficulty stats — Rule 1 governs STATS, and a climb ceiling is the same
## kind of constant as EMBER_NEIGHBOURS. Tuning happens on the Director's eye
## via the filmstrip, which is why they are named rather than inlined.
## M3-3 — how long a lit voxel takes to burn AWAY, as opposed to how long its
## ember GLOWS.
##
## ⚠️ DELIBERATELY NOT READ OFF THE EMBER'S LIFETIME, and the reason is
## measurable: `EmberOverlay.add_ember()` rolls its duration with
## `randf_range(min_glow_duration, max_glow_duration)`. Hanging a world MUTATION
## on that would make two captures of the same detonation destroy different
## voxels — the exact non-determinism CLAUDE.md's pixel-diff discipline costs 36
## 733 pixels to discover. The glow is the LOOK; consumption is the MECHANIC, and
## the mechanic gets its own timeline, rolled from FNV-1a inside this pure
## builder like every other decision here.
##
## Scaled by the material's `flammability`, which is its SPEED axis — fabric 0.6
## flares and is gone, cardboard 1.4 smoulders. That is §3.1's "cardboard burns
## everything too, slightly slower overall than fabric", expressed with the
## number that already meant it.
## M3-4 — plywood's spatial rule, and the ONLY material property that is
## position-dependent (§3.1: *"Plywood is the complex one and the only one with a
## spatial rule"*).
##
## Director: *"uma granada bem na base da parede abre passagem; mais longe queima
## menos."* The reach below is in VOXELS of horizontal radius from the
## epicentre — the `r` every ember entry already carries.
##
## ⚠️ NO SEPARATE "IS IT AT THE BASE" TERM, deliberately. A grenade is on the
## FLOOR — the Director's own point when settling the passage rule — so the cells
## closest to it are the base cells by geometry. A radial falloff therefore
## produces "the base opens, higher up burns less" without a level rule to tune,
## and the upward attenuation is already in the ember wave (EMBER_CLIMB_DECAY
## makes each rung likelier to stop).
const BURN_RADIAL_REACH_VOXELS: float = 26.0

## PERF-F6 (Director, 2026-08-23) — *"vamos seguir e deixar o fogo mais rápido e
## volátil"*, and it is the lever that replaces the rejected light tick.
##
## WHY THE SPAN IS WHAT COSTS. A fire's committing frames are
## `span / BURN_COMMIT_INTERVAL_S` and each one repaints the light, so the SPAN is
## the whole bill — 3.0 s of fire is ~15 rebuilds whatever the voxel count. The
## previous values put a wall's span at ~3.3 s, and most of that was not `life` at
## all: `EMBER_CLIMB_DELAY_S` staggers the flame UP the wall and dominated.
##
## Faster AND more volatile, so the two read as one change rather than as a fire
## that simply got shorter: the base life comes down hard, the jitter goes UP so
## the patch dies unevenly, and the climb and seed staggers come down with them.
## Look values — the Director tunes these on a filmstrip, not on argument.
const BURN_BASE_LIFE_S: float = 0.55
const BURN_LIFE_JITTER: float = 0.60   ## ±60% — volatility, and it still cannot vanish in one frame

const EMBER_CLIMB_MAX_LEVELS: int = 3
const EMBER_CLIMB_CHANCE: float = 0.55       ## chance the first level above catches
const EMBER_CLIMB_DECAY: float = 0.55        ## each further level is this much likelier to stop
const EMBER_CLIMB_LIFE_DECAY: float = 0.7    ## each rung burns out sooner than the one below
const EMBER_CLIMB_DELAY_S: float = 0.10      ## PERF-F6: base stagger per level climbed (was 0.28 — this dominated the span)
const EMBER_CLIMB_DELAY_JITTER: float = 0.55 ## +/- fraction of that stagger, per cell
const EMBER_SEED_STAGGER_S: float = 0.20     ## PERF-F6: window the seeds' own ignitions spread across (was 0.45)


const EMBER_NEIGHBOURS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


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
	## E-JUNCTION-01: a JunctionColumn is a diagonal wall segment, so it takes
	## the same live-resolve shape a Slice does — the one real difference is
	## orientation. A Slice has one face; a column has two (face_a/face_b, the
	## corner itself). face_a is the plan's recorded default (EXPLOSION_
	## REBUILD_MASTER_PLAN's E-JUNCTION-01 section) — a look detail to revisit
	## after a real capture, not a correctness question.
	if container is JunctionResolver.JunctionColumn:
		var column: JunctionResolver.JunctionColumn = container
		var voxel_xy2 := Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
		var render_material3 := VoxelRendererClass.damage_variant_material(
			column.material, voxel.damage_state, voxel.damage_is_blast,
			voxel.damage_carved_side, voxel.damage_variant)
		var resolved3 := voxel_renderer._set_voxel_cell(voxel.grid_pos, voxel.level, render_material3,
			null, voxel_xy2, column.face_a, false, "", BakePolicyClass.SurfaceClass.SLICE, false)
		return {"source_id": resolved3["source_id"], "atlas_coords": resolved3["atlas_coords"],
			"alternative_id": resolved3["alternative_id"], "baked": false}
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
	## E-JUNCTION-01: counted as its own group rather than folded into WALL —
	## the census exists to catch a tier silently going inert on one surface
	## (§ "E-DENT-01 census bookkeeping" above); merging it into WALL would
	## hide exactly that failure mode for junction columns specifically.
	if container is JunctionResolver.JunctionColumn:
		return "JUNCTION"
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
	if container is Slice or container is Slab or container is JunctionResolver.JunctionColumn:
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
	## E-EMBER-01: reported on the REAL blast, next to the census, for exactly
	## the reason CLAUDE.md's floor-dent case exists — a synthetic fixture is
	## built out of the material that works, so it cannot catch a feature made
	## inert by real map data (69 dents on a patch, zero on PLAYGROUND). A zero
	## here on a map that HAS a combustible material is the finding.
	var ember_total: int = 0
	for ring in delta.waves.get("ember", {}).keys():
		ember_total += (delta.waves["ember"][ring] as Array).size()
	print("[E-EMBER] %d ember(s) queued — surviving combustible voxels edging this blast's holes"
		% ember_total)
	## M3-3, reported for the same reason and with the same trap in mind: a burn
	## count of zero on a map that HAS a consuming material is the finding, not
	## the absence of a print.
	## ⚠️ D-2 — READ OFF `burnt_cells`. The fire is damage on the Delta, consumed
	## in the commit frame; a census reading a `waves["burn"]` schedule (deleted in
	## D-6) would print `[E-BURN] 0` on every fabric blast in the game.
	var burn_total: int = delta.burnt_cells.size()
	var burn_last: float = 0.0
	for key in delta.burnt_cells.keys():
		burn_last = maxf(burn_last, float(delta.burnt_cells[key].get("at", 0.0)))
	if burn_total > 0:
		print("[E-BURN] %d voxel(s) consumed IN THE COMMIT, last ember at %.2fs — of %d lit (%.0f%%)"
			% [burn_total, burn_last, ember_total,
			100.0 * float(burn_total) / maxf(float(ember_total), 1.0)])
	else:
		print("[E-BURN] 0 — nothing this blast lit has burn_consumption > 0")
	## E-DEBRIS-01, per effect for the same reason the census is per material: a
	## single total would hide one effect being structurally unreachable, and only
	## a DESTROYED voxel throws debris.
	##
	## Sparks looked like exactly that risk — metal's `destroy_factor` is 0.03, so
	## a blast essentially never destroys a metal WALL voxel. Measured instead of
	## assumed, and the measurement said otherwise: `apply_crater_damage()`'s
	## crater geometry ignores `destroy_factor` entirely, so a metal FLOOR loses
	## voxels freely (real capture: `FLOOR/metal destroyed 143`, `sparks/metal=28`).
	## Recorded because the reasoning was sound and the conclusion was wrong.
	var debris_by_effect: Dictionary = {}
	for ring in delta.waves.get("debris", {}).keys():
		for e in delta.waves["debris"][ring]:
			var key: String = "%s/%s" % [e["effect"], e["material"]]
			debris_by_effect[key] = int(debris_by_effect.get(key, 0)) + 1
	if debris_by_effect.is_empty():
		print("[E-DEBRIS] none — no destroyed voxel matched a debris rule")
	else:
		var keys: Array = debris_by_effect.keys()
		keys.sort()
		var parts: PackedStringArray = PackedStringArray()
		for k in keys:
			parts.append("%s=%d" % [k, debris_by_effect[k]])
		print("[E-DEBRIS] %s" % " ".join(parts))


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
## PERF-P2b: the alt is bucket + flip; the SOOT the same cell will wear travels
## beside it as its own entry field, because it no longer fits in an id.
static func _alt_for(field: VoxelLightFieldClass, cell: Vector2i, level: int, base_alt: int) -> int:
	var bucket: int = field.bucket_for(cell, level)
	var flipped: bool = VoxelRendererClass.decode_light_flipped(base_alt)
	return VoxelRendererClass.encode_light_alt(bucket, flipped)


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
## `material` (E-SMOKE-TINT-01, 2026-08-13) rides on the entry so the
## choreographer can tint the puff. It is only ever the container's own id — the
## COLOUR is resolved by the caller that has a MaterialRegistry (see
## Room.blast_smoke_tints()), because this builder is static and runs headless in
## selftests where the `Registries` autoload does not exist.
static func _append_voxel_smoke(smoke_by_ring: Dictionary, smoked_gus: Dictionary,
		voxel: Voxel, ring: int, smoke_ring_weights: Array[float], tier_intensity: float,
		voxel_renderer: VoxelRendererClass, epicenter: Vector2i,
		material: String = "", plume_gus: Dictionary = {}) -> void:
	if ring < 0 or ring >= smoke_ring_weights.size():
		return
	var weight: float = smoke_ring_weights[ring]
	if weight <= 0.0:
		return
	## D-4b — the plume seed, recorded for EVERY damaged voxel and therefore
	## BEFORE the per-material thinning below. `smoked_gus` stopped meaning "GUs
	## this blast damaged" the moment that roll was added; it means "GUs that got a
	## puff". The plumes want the first, and reusing the second would have made a
	## fabric crater emit almost no columns for a reason that has nothing to do
	## with columns.
	##
	## The HIGHEST damaged voxel wins, which is what puts a plume on a WALL rather
	## than always on the floor under it — the Director's own drawing has two
	## columns rising off wall faces, not just off the crater.
	var pgu: Vector2i = GeometryCoords.voxel_to_gu(voxel.grid_pos)
	var prev: Array = plume_gus.get(pgu, [])
	if prev.is_empty() or voxel.level > int(prev[1]):
		plume_gus[pgu] = [
			voxel_renderer.voxel_world_position(voxel.grid_pos, voxel.level),
			voxel.level, ring]
	## D-4 — the per-material thinning, rolled BEFORE `smoked_gus` is marked.
	##
	## ⚠️ THE ORDER OF THOSE TWO LINES IS A DESIGN DECISION, not tidiness. Marking
	## the GU first would mean a GU whose voxels ALL lose the roll gets no per-voxel
	## puff and is also skipped by `_phase_smoke()`'s GU-level remainder — a damaged
	## GU that emits nothing at all. Rolling first leaves that GU unmarked, so the
	## remainder puff covers it: thinning per voxel, never per GU.
	if _hash_unit("SMOKEROLL", voxel.grid_pos, voxel.level) \
			> MaterialResistanceTable.smoke_chance(material):
		return
	smoked_gus[GeometryCoords.voxel_to_gu(voxel.grid_pos)] = true

	var size_roll: float = _hash_unit("SMOKESIZE", voxel.grid_pos, voxel.level)
	var time_roll: float = _hash_unit("SMOKETIME", voxel.grid_pos, voxel.level)
	## D-4 — the HEIGHT axis the Director asked for (*"tempo, intensidade e altura
	## ligeiramente variando"*). Time and intensity already varied; height did not,
	## and `SmokeSparkOverlay.add_smoke()` has taken a `drift_scale` the whole time
	## that no blast ever passed. Its own hash domain, so tuning the spread cannot
	## disturb which voxels emit (SMOKEROLL) or how big they are (SMOKESIZE).
	var rise_roll: float = _hash_unit("SMOKERISE", voxel.grid_pos, voxel.level)
	var strength: float = tier_intensity * weight
	var scale: float = maxf(
		SMOKE_SCALE_BASE * strength * (1.0 - SMOKE_JITTER + 2.0 * SMOKE_JITTER * size_roll), 0.05)
	var rise: float = SMOKE_RISE_MIN + (SMOKE_RISE_MAX - SMOKE_RISE_MIN) * rise_roll
	var duration: float = maxf(
		lerpf(SMOKE_DURATION_FLOOR, 1.0, clampf(strength, 0.0, 1.0))
		* (1.0 - SMOKE_DURATION_JITTER + 2.0 * SMOKE_DURATION_JITTER * time_roll), 0.05)
	_append(smoke_by_ring, ring, {
		"world_pos": voxel_renderer.voxel_world_position(voxel.grid_pos, voxel.level),
		"duration": duration,
		"scale": scale,
		"alpha": clampf(strength * (0.6 + 0.8 * size_roll) * SMOKE_ALPHA_GAIN, 0.05, 4.0),
		"drift": rise,
		"blobs": SMOKE_BLOBS_PER_VOXEL,
		"material": material,
		"r": _radius_of(voxel.grid_pos, epicenter),
		## E-ORDER-01 — smoke was the ONE played kind with no `cell`, and
		## `DetonationChoreographer._sort_key()` falls back to Vector2i.ZERO, so
		## every puff in the blast drew the SAME jitter roll. Two consequences, both
		## visible: the smoke front was a machined circle while everything else was
		## ragged, and its separation from the destruction was a single random
		## constant per blast (+/-0.45 voxels on top of its 0.70 bias) rather than an
		## average — so on some blasts the smoke effectively led the decals.
		## The puff already knows its voxel; handing it over costs nothing and puts
		## it on the same footing as every other kind. Consumers read `world_pos`,
		## never this — see `_apply_entry()`'s "smoke" branch.
		"cell": voxel.grid_pos,
	})


## E-DEBRIS-01 (2026-08-13) — dust, sparks and wood chips for a DESTROYED voxel.
## The last piece of VFX-01 that never reached explosions: the choreographer
## erases cells directly, so `VoxelRenderer.voxel_destroyed` (which drives
## `Room._dispatch_destruction_vfx()`) has only ever fired for firearms.
##
## Reconnecting that dispatch was again the wrong move, for the third time and
## the same reason: its smoke half would double against the staged smoke waves.
## The plan carries the debris instead, resolved here.
##
## THE ROLLS ARE HASHED, NOT `randf()` — and here that is not only the filmstrip
## discipline. `build_plan()` is PURE and its output is CACHED by
## `PredictionCache`: a cursor sweeping GUs builds and discards a plan per hover,
## and a cache HIT returns one built earlier. With `randf()` the debris a blast
## finally showed would depend on how many times the player had moved the mouse.
##
## Effects roll INDEPENDENTLY, under different salts, because VFX-01 let stone
## throw both dust and sparks from one strike and that is worth keeping.
## --- D-4b: THE PLUMES — what the Director actually asked for. ------------
##
## > *"queremos efetivamente que ela seja mais presente e maior, subindo e se
## > dissipando, persistindo pelo menos mais 1 segundo depois da explosão… As
## > areas afetadas pela explosão soltam uma fumaça no final."*
##
## ⚠️ **THIS IS NOT THE PER-VOXEL SMOKE, AND CONFUSING THE TWO COST A WHOLE PASS.**
## The Director's second drawing circles the small discs expanding outward from the
## centre and labels them *"a fumaça da granada que já está funcionando"* — those
## are `_append_voxel_smoke()`'s puffs, and they are FINE. What was missing is a
## different effect entirely: a FEW LARGE COLUMNS rising off the affected areas at
## the END, which is what the first drawing shows. Tuning the per-voxel puffs could
## never have produced it, however far it was pushed.
##
## So: one column per damaged GU, not one puff per damaged voxel. A column is
## `PLUME_PUFFS` puffs from the same point, staggered over `PLUME_SPAN_S`, each
## much larger, much longer-lived and rising much harder than a per-voxel puff.
## Staggering is what makes it read as a continuous plume rather than one balloon.
##
## They ride in `waves["smoke"]` rather than in a kind of their own: they ARE
## smoke entries, they need no new writer branch, no `PLAYED_KINDS` row and no
## change to the drop-check. `at` is what separates them — see
## `DetonationPresenter._delay_for()`, which honours an explicit release time and
## does not clamp it to the consequence channel's own span.
##
## Every number is a `var` in SECONDS (Rule 1, §5.2). The persistence the Director
## asked for is `PLUME_SPAN_S` (when the last puff of a column is released) plus
## the overlay's own 1.8-3.2 s lifetime scaled by `PLUME_DURATION` — so the smoke
## is still thinning out well past a second after the blast.
static var PLUME_PUFFS: int = 3
static var PLUME_FIRST_S: float = 0.18      ## the lead puff, right after the crater lands
static var PLUME_SPAN_S: float = 1.05       ## the last one, a second later
static var PLUME_JITTER_S: float = 0.22     ## per-GU scatter so columns do not pulse together
static var PLUME_SCALE: float = 3.4         ## against SMOKE_SCALE_BASE 2.3 for a per-voxel puff
## ⚠️ 3.6 is the CAP, not a taste: the writer clamps a puff at 0.72 and
## `SMOKE_COLOR.a` is 0.2, so 3.6 is exactly where a plume saturates. Measured at
## 1.7 the columns were on screen and effectively invisible — the feather spreads a
## big disc's alpha over a large area, so a plume needs the ceiling where a small
## per-voxel puff does not.
static var PLUME_ALPHA: float = 1.7
static var PLUME_DRIFT: float = 1.7         ## rises harder and further than a puff
static var PLUME_DURATION: float = 1.5      ## x the overlay's own 1.8-3.2 s


static func _append_plumes(s: Dictionary) -> void:
	var plume_gus: Dictionary = s["plume_gus"]
	if plume_gus.is_empty():
		return
	var waves: Dictionary = s["waves"]
	var epicenter: Vector2i = s["epicenter"]
	var half: int = int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0)
	var made: int = 0
	for gu: Vector2i in plume_gus.keys():
		var seed_row: Array = plume_gus[gu]
		var origin: Vector2 = seed_row[0]
		var level: int = int(seed_row[1])
		var ring: int = int(seed_row[2])
		var gu_center: Vector2i = GeometryCoords.gu_to_voxel_origin(gu) + Vector2i(half, half)
		var jitter: float = _hash_unit("PLUMEAT", gu, level)
		var size_roll: float = _hash_unit("PLUMESIZE", gu, level)
		for k in range(maxi(PLUME_PUFFS, 1)):
			var t: float = float(k) / float(maxi(PLUME_PUFFS - 1, 1))
			_append(waves["smoke"], ring, {
				"world_pos": origin,
				"at": PLUME_FIRST_S + (PLUME_SPAN_S - PLUME_FIRST_S) * t
					+ PLUME_JITTER_S * jitter,
				"duration": PLUME_DURATION,
				## The column narrows as it climbs, which is most of what makes it
				## read as rising rather than as four discs in a stack.
				"scale": PLUME_SCALE * (1.15 - 0.45 * t) * (0.75 + 0.5 * size_roll),
				"alpha": PLUME_ALPHA,
				"drift": PLUME_DRIFT,
				"blobs": SMOKE_BLOBS_PER_VOXEL,
				"material": "",
				"plume": true,
				"r": _radius_of(gu_center, epicenter),
				"cell": gu_center,
				"level": level,
			})
			made += 1
	print("[E-PLUME] %d column(s) over %d damaged GU(s), last released at %.2fs"
		% [made, plume_gus.size(), PLUME_SPAN_S + PLUME_JITTER_S])


static func _append_voxel_debris(debris_by_ring: Dictionary, voxel: Voxel, ring: int,
		material: String, policy: Dictionary, voxel_renderer: VoxelRendererClass,
		epicenter: Vector2i) -> void:
	if policy.is_empty():
		return
	var origin: Vector2 = voxel_renderer.voxel_world_position(voxel.grid_pos, voxel.level)
	## Where dust settles and chips land — the floor under this voxel, the same
	## point VFX-01's own dispatch uses. Falls back to the origin when level 0 has
	## no cell there (an unbuilt column), matching that dispatch exactly.
	var floor_pos: Vector2 = voxel_renderer.voxel_world_position(voxel.grid_pos, 0)
	if floor_pos == Vector2.ZERO:
		floor_pos = origin
	var r: float = _radius_of(voxel.grid_pos, epicenter)
	for effect: String in DEBRIS_EFFECTS:
		var rule: Dictionary = policy.get(effect, {})
		if rule.is_empty():
			continue
		if not (rule.get("materials", []) as Array).has(material):
			continue
		if _hash_unit("DEBRIS" + effect, voxel.grid_pos, voxel.level) >= float(rule.get("chance", 0.0)):
			continue
		## E-SPARK-02: a per-material count overrides the rule's shared range
		## where the policy declares one ("cimento só um pouquinho, metal
		## bastante, pedra médio"). Optional, so a rule with a single range —
		## every rule before this, and the selftest's own — is unchanged.
		var span: Array = (rule.get("per_material", {}) as Dictionary).get(material, [])
		var lo: int = int(span[0]) if span.size() == 2 else int(rule.get("count_min", 1))
		var hi: int = int(span[1]) if span.size() == 2 else int(rule.get("count_max", 1))
		var count: int = lo
		if hi > lo:
			count = lo + int(_hash_unit("DEBRISN" + effect, voxel.grid_pos, voxel.level)
				* float(hi - lo + 1))
			count = mini(count, hi)
		_append(debris_by_ring, ring, {
			"effect": effect,
			"material": material,
			"count": count,
			"world_pos": origin,
			"floor_pos": floor_pos,
			"cell": voxel.grid_pos,
			"level": voxel.level,
			"r": r,
		})


## Fixed order so a voxel that throws two effects always queues them the same
## way — the determinism above would be pointless if Dictionary iteration order
## decided which of a stone voxel's dust and sparks landed first.
const DEBRIS_EFFECTS: Array[String] = ["dust", "sparks", "chips"]


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
## Read ONCE into a static var, never per entry: `build_plan()` is pure and its
## output is cached, so a value that could change between two cooks of the same
## world revision would hand back a plan built under different rules.
static func _env_float(name: String, fallback: float) -> float:
	var raw := OS.get_environment(name)
	return raw.to_float() if raw.is_valid_float() else fallback


static func _hash_unit(salt: String, cell: Vector2i, level: int) -> float:
	return float(FacadeSampler._fnv1a_hash("%s:%d,%d,%d" % [salt, cell.x, cell.y, level]) % 10000) / 10000.0
