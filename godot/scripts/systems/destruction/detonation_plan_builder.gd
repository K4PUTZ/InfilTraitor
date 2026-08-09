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


## Builds and returns one WorldDelta. Empty `{}` sub-dicts in `delta.waves` for
## any wave kind with nothing to show — Task 5 reads with `.get(ring, [])`.
##
## P-DELTA (PREDICTION_MASTER_PLAN Task 3, 2026-08-09) — **THIS FUNCTION NO
## LONGER MUTATES ANYTHING.** It used to damage the real Voxels on its way
## through and then read the result back off them; it now simulates into a
## `WorldDelta` and reads back through that Delta's projection. The caller
## decides whether any of it happens, by calling `delta.commit()` — or not.
##
## Two consequences worth naming, because they are the point:
##
##  - a Delta that is computed and discarded costs nothing but the time, which
##    is what makes §4's pre-production and §5's cache possible at all;
##  - the `under_structure` capture below no longer depends on WHERE in this
##    function it happens. Its old contract ("captured BEFORE any set_damage()")
##    was an ordering rule enforced by a comment; purity turns it into a
##    property of the code.
##
## What did NOT change: every roll, every hash salt, every ring table read and
## the order of every loop. The gate for this task is a real detonation whose
## census and per-frame cell counts are identical to the pre-refactor ones.
static func build_plan(bomb_def, source_gu: Vector2i, ctx: Dictionary) -> WorldDelta:
	var started_usec: int = Time.get_ticks_usec()
	var edge_registry: EdgeRegistry = ctx["edge_registry"]
	var slab_registry: SlabRegistry = ctx["slab_registry"]
	var voxel_renderer: VoxelRendererClass = ctx["voxel_renderer"]
	var blocked_edges: Dictionary = ctx.get("blocked_edges", {})
	var blocked_cells: Dictionary = ctx.get("blocked_cells", {})
	var deep_layer_unlocked: bool = ctx.get("deep_layer_unlocked", false)
	## Diagnostic toggle (Director, 2026-08-07, comparing a real capture
	## against the floor's own already-noisy dent decal art): true is the
	## real/shipped behavior. false skips ONLY stamp_container_soot()/
	## stamp_crater_soot() below — derive_soot_rings()/apply_self_soot() still
	## run unchanged, so a voxel next to a real hole still scorches; what's
	## missing is JUST the blast's authored ring-tone stamp (closes ring 3's
	## own gap, per Task 3). Default true everywhere except an explicit
	## comparison capture.
	var stamp_soot_enabled: bool = ctx.get("stamp_soot_enabled", true)

	var delta := WorldDeltaClass.new()
	var waves: Dictionary = delta.waves

	var gu_rings := BlastCalculatorClass.flood_gu_rings(source_gu, bomb_def, blocked_edges, blocked_cells)
	var affected := BlastCalculatorClass.find_affected_containers(gu_rings, edge_registry, slab_registry)
	var n_rings: int = bomb_def.ring_multipliers.size()
	var epicenter: Vector2i = source_gu * GeometryCoords.VOXELS_PER_UNIT_AXIS \
		+ Vector2i(int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0),
			int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0))

	## VL-D3's own contract: "computed from the INTACT geometry right after a
	## build, before reapply_damage" — a floor voxel newly exposed by THIS blast
	## must read as "never saw the sun" using the geometry that stood over it a
	## moment ago, not the hole this call is about to describe.
	##
	## P-DELTA: this used to be an ORDERING rule ("captured BEFORE any
	## set_damage() call below") held together by this comment. It is now a
	## property of the function — nothing below writes to a Voxel, so the real
	## geometry is intact wherever this line sits.
	var under_structure: Dictionary = ctx.get("under_structure", {})
	if under_structure.is_empty():
		under_structure = _columns_with_structure(edge_registry)

	## --- Resolution: the calc layer, now SIMULATED rather than applied (P-PURE).
	## ring_of/container_of are this pass's own bookkeeping — a Voxel carries
	## neither (Rule 4's spirit: only the resolution pass that just ran owns
	## ring/container assignment, not a field bolted onto Voxel). ---
	var soot_snapshot: Dictionary = {}
	var soot_faces: Dictionary = {}
	var ring_of: Dictionary = {}        ## Vector3i(x,y,level) -> int
	var container_of: Dictionary = {}   ## Vector3i(x,y,level) -> Slice/Slab

	for slice_id in affected["slices"]:
		var slice: Slice = edge_registry.get_slice(slice_id)
		var base_ring: int = affected["slices"][slice_id]
		var base_level: int = slice.start_storey * GeometryCoords.LEVELS_PER_STOREY
		delta.add_damage(BlastCalculatorClass.simulate_container_damage(
			slice.voxels, slice.id, slice.material, base_ring, base_level, false,
			bomb_def.ring_multipliers, bomb_def.destroy_ring_weights,
			bomb_def.dent_ring_weights, bomb_def.crack_ring_weights, epicenter))
		if stamp_soot_enabled:
			BlastCalculatorClass.stamp_container_soot(
				slice.voxels, base_ring, base_level, false, bomb_def.soot_ring_tones,
				epicenter, soot_snapshot, soot_faces)
		for v in slice.voxels:
			var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
			ring_of[key] = base_ring + BlastCalculatorClass.vertical_ring_for(v.level - base_level)
			container_of[key] = slice

	for slab_id in affected["roofs"]:
		var roof: Slab = slab_registry.get_slab(slab_id)
		var base_ring: int = affected["roofs"][slab_id]
		delta.add_damage(BlastCalculatorClass.simulate_container_damage(
			roof.voxels, roof.id, roof.material, base_ring, roof.level, true,
			bomb_def.ring_multipliers, bomb_def.destroy_ring_weights,
			bomb_def.dent_ring_weights, bomb_def.crack_ring_weights, epicenter))
		if stamp_soot_enabled:
			BlastCalculatorClass.stamp_container_soot(
				roof.voxels, base_ring, roof.level, true, bomb_def.soot_ring_tones,
				epicenter, soot_snapshot, soot_faces)
		for v in roof.voxels:
			var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
			ring_of[key] = base_ring + BlastCalculatorClass.vertical_ring_for(v.level - roof.level)
			container_of[key] = roof

	## D2's floor gate: unlocked from a GU's second blast onward. No live
	## caller drives that state yet (Task 2/3's own confirmed scope note —
	## room._gu_blast_count wiring is Task 5's job), so every plan built
	## today is honestly a first blast on whatever GU it targets, unless a
	## caller explicitly threads a later blast's state through ctx.
	var crater_max: float = float(n_rings) * float(GeometryCoords.VOXELS_PER_UNIT_AXIS) * CRATER_MAX_FACTOR
	var crater_core: float = crater_max * CRATER_CORE_FACTOR
	var crater_rim_span: float = maxf(crater_max - crater_core, 0.001)
	var exposed_by_ring: Dictionary = {}   ## ring -> Array[resolved expose entries]

	for slab_id in affected.get("floors", {}):
		var floor_slab: Slab = slab_registry.get_slab(slab_id)
		if floor_slab.level == GeometryCoords.FLOOR_DEEP_LEVEL and not deep_layer_unlocked:
			continue
		## E-CRACK-01: the bomb's own dent/crack ring tables now reach the floor
		## too — the same two arrays apply_container_damage() already reads for
		## every wall and roof above, so one authored number governs a tier
		## everywhere it can appear instead of the floor keeping a private
		## falloff. `slab_pierce_multiplier` stays at its D17 default (no stacked
		## slab exists on any real map yet) and is passed positionally only
		## because the ring tables sit behind it.
		delta.add_damage(BlastCalculatorClass.simulate_crater_damage(
			floor_slab.voxels, floor_slab.id, epicenter, crater_core, crater_max,
			floor_slab.material, deep_layer_unlocked, 1.0,
			bomb_def.dent_ring_weights, bomb_def.crack_ring_weights))
		if stamp_soot_enabled:
			BlastCalculatorClass.stamp_crater_soot(
				floor_slab.voxels, epicenter, crater_core, crater_max,
				bomb_def.soot_ring_tones, soot_snapshot, soot_faces)
		var min_destroy_ring: int = -1
		for v in floor_slab.voxels:
			var d: float = Vector2(v.grid_pos - epicenter).length()
			var ring: int = BlastCalculatorClass.crater_ring_for(d, crater_max, crater_rim_span)
			var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
			ring_of[key] = ring
			container_of[key] = floor_slab
			## P-DELTA: the Delta's projection, not the Voxel — this slab's own
			## simulate ran one statement ago and `add_damage()` folded it in, so
			## the answer here is the same one the old mutating version read off
			## the freshly-damaged Voxel.
			if delta.state_of(v) == Voxel.DamageState.DESTROYED:
				min_destroy_ring = ring if min_destroy_ring < 0 else mini(min_destroy_ring, ring)
		## D18 lazy reveal — a crater with nothing exposed below it shows the
		## legacy plane straight through the hole. Grouped under the EARLIEST
		## ring that actually opened this slab, so the reveal rides in on the
		## same wave a real destroy already lands in.
		if min_destroy_ring >= 0:
			var expose := _resolve_expose_below(floor_slab, voxel_renderer, slab_registry)
			if not expose.is_empty():
				if not exposed_by_ring.has(min_destroy_ring):
					exposed_by_ring[min_destroy_ring] = []
				exposed_by_ring[min_destroy_ring].append_array(expose)

	## --- Whole-map soot: derived-from-holes (matches room._build_soot_
	## snapshot()'s own scope, not just this blast's containers, so a
	## pre-existing hole elsewhere keeps its scorch) merged with the stamps
	## just recorded above. Task 3's own closure note: this compositional
	## step belongs here (the first real caller), not in room.gd. ---
	var cell_to_voxel: Dictionary = {}
	var blast_cells: Array = []
	var weapon_cells: Array = []
	var damaged_voxels: Array = []
	for slice2 in edge_registry.all_slices():
		for v in slice2.voxels:
			_index_soot_voxel(cell_to_voxel, blast_cells, weapon_cells, damaged_voxels, v, delta)
	for slab2 in slab_registry.all_slabs():
		for v in slab2.voxels:
			_index_soot_voxel(cell_to_voxel, blast_cells, weapon_cells, damaged_voxels, v, delta)

	var derived_blast_snapshot: Dictionary = {}
	var derived_blast_faces: Dictionary = {}
	BlastCalculatorClass.derive_soot_rings(cell_to_voxel, blast_cells,
		ctx.get("blast_soot_rings", 4), derived_blast_snapshot, derived_blast_faces,
		1, BlastCalculatorClass.FACE_SOOT_CLEAN)
	var derived_weapon_snapshot: Dictionary = {}
	var derived_weapon_faces: Dictionary = {}
	BlastCalculatorClass.derive_soot_rings(cell_to_voxel, weapon_cells,
		ctx.get("weapon_soot_rings", 3), derived_weapon_snapshot, derived_weapon_faces)
	_merge_soot(soot_snapshot, soot_faces, derived_blast_snapshot, derived_blast_faces)
	_merge_soot(soot_snapshot, soot_faces, derived_weapon_snapshot, derived_weapon_faces)
	BlastCalculatorClass.apply_self_soot(damaged_voxels, soot_snapshot, soot_faces)

	## --- The single map-wide light-field query (§2). Built ONCE, queried per
	## cell below — VoxelLightField.build() never touches the TileMapLayer,
	## and nothing here calls VoxelRenderer.apply_light_field(). ---
	var occupancy := _voxel_occupancy(edge_registry, slab_registry, delta)
	var top_wall_level: int = maxi(voxel_renderer.get_layer_count() - 1, 0)
	var field := VoxelLightFieldClass.new()
	field.build(ctx.get("lights", []), ctx.get("shadow_results", []), top_wall_level,
		occupancy, soot_snapshot, under_structure, soot_faces)

	## --- Package destroy/dented/cracked, keyed by ring, from the DELTA's
	## projected state (never re-derived, never re-rolled — P-DELTA swapped the
	## source from "the containers' already-mutated Voxels" to the projection,
	## and nothing else about this block). ---
	var touched_this_blast: Dictionary = {}   ## Vector3i -> true, excludes these from the soot-only wave
	## Every voxel whose damage_state this blast actually changed — the exact
	## set room.record_voxel_damage_to_base() needs for VL-PERSIST (rotation
	## survival). Returned alongside the plan (see "touched_voxels" below) so
	## Task 5's caller persists from real Voxel objects, never re-deriving the
	## affected set with a second flood/find_affected_containers pass.
	var touched_voxels: Array = []
	## E-DENT-01 census (Director, 2026-08-08): the one number §12's verification
	## contract actually asks for — how many dented/cracked atoms a REAL blast
	## lands, split by the surface each one landed on, and how many of those came
	## from the pre-bake instead of the D33 live-compositing fallback. `[E-WAVE]`
	## already prints per-wave cell counts, but those blend floor/wall/ceiling
	## into one figure, which is exactly what hid "69 dents on a fixture, zero on
	## PLAYGROUND" the first time. Built here (the only pass that knows each
	## voxel's container), printed once per detonation.
	var census: Dictionary = {}   ## "kind|surface" -> {"n": int, "baked": int}
	## E-SMOKE-01 (Director, 2026-08-08): "praticamente todo voxel afetado pode
	## soltar um pouquinho de fumaça, com intensidades diferentes e durações
	## diferentes." Smoke used to be ONE puff per flooded GU (1/4/7/10 per blast);
	## it is now one puff per voxel this blast actually damaged, emitted right
	## where the damage is. `smoked_gus` records which GUs that covered, so the
	## old per-GU puff can still fill the ones it didn't — see the smoke block
	## further down for why ring 3 needs exactly that.
	var smoked_gus: Dictionary = {}
	for key in ring_of:
		var voxel: Voxel = cell_to_voxel.get(key)
		if voxel == null:
			continue
		var ring: int = ring_of[key]
		var container = container_of.get(key)
		var state: int = delta.state_of(voxel)
		if state == Voxel.DamageState.DESTROYED:
			touched_this_blast[key] = true
			touched_voxels.append(voxel)
			_count(census, "destroy", container, true)
			_append_voxel_smoke(waves["smoke"], smoked_gus, voxel, ring,
				bomb_def.smoke_ring_weights, DESTROY_SMOKE_INTENSITY, voxel_renderer, epicenter)
			_append(waves["destroy"], ring, {"cell": voxel.grid_pos, "level": voxel.level,
				"r": _radius_of(voxel.grid_pos, epicenter)})
		elif state == Voxel.DamageState.DENTED or state == Voxel.DamageState.CRACKED:
			touched_this_blast[key] = true
			touched_voxels.append(voxel)
			_append_voxel_smoke(waves["smoke"], smoked_gus, voxel, ring,
				bomb_def.smoke_ring_weights,
				DENT_SMOKE_INTENSITY if state == Voxel.DamageState.DENTED
					else CRACK_SMOKE_INTENSITY,
				voxel_renderer, epicenter)
			## P-DELTA: the resolver takes a whole Voxel and reads five damage
			## fields off it, so it is handed the Delta's PROJECTED copy — see
			## WorldDelta.project_voxel(). The real Voxel is still what goes into
			## `touched_voxels`, because that list is the commit's persistence
			## seam and needs the object, not a snapshot of it.
			var resolved := _resolve_damaged_tile(
				delta.project_voxel(voxel), container, voxel_renderer)
			var alt := _alt_for(field, voxel.grid_pos, voxel.level, resolved["alternative_id"])
			var wave_key: String = "dented" if state == Voxel.DamageState.DENTED else "cracked"
			_count(census, wave_key, container, resolved["baked"])
			_append(waves[wave_key], ring, {"cell": voxel.grid_pos, "level": voxel.level,
				"source_id": resolved["source_id"], "atlas_coords": resolved["atlas_coords"], "alt": alt,
				"r": _radius_of(voxel.grid_pos, epicenter)})
	_print_census(census, source_gu,
		float(Time.get_ticks_usec() - started_usec) / 1000.0)

	## --- Exposure fallback: the floor reveals from above, wired into their
	## owning ring's destroy entries (§6.1's `expose` sub-array), lit through
	## the SAME field query as everything else. ---
	for ring in exposed_by_ring:
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
			## Shouldn't happen — a reveal only fires alongside a real destroy
			## in the same ring — kept as an honestly-labelled defensive entry
			## (epicenter cell, not a real destroyed voxel) rather than
			## silently dropping the exposed tiles.
			carrier.append({"cell": epicenter, "level": GeometryCoords.FLOOR_TOP_LEVEL,
				"r": 0.0, "expose": lit_expose})
		else:
			var entry: Dictionary = carrier[0]
			var existing_expose: Array = entry.get("expose", [])
			existing_expose.append_array(lit_expose)
			entry["expose"] = existing_expose

	## --- Soot-only wave: every surviving voxel whose soot changed and isn't
	## already carried by a destroy/dent/crack entry above. Ring is whatever
	## the merged snapshot assigned. ---
	for level in soot_snapshot.keys():
		var level_map: Dictionary = soot_snapshot[level]
		for cell in level_map.keys():
			var ring: int = int(level_map[cell])
			if ring >= BlastCalculatorClass.FACE_SOOT_CLEAN:
				continue
			var key := Vector3i(cell.x, cell.y, level)
			if touched_this_blast.has(key):
				continue
			var layer: TileMapLayer = voxel_renderer.get_layer(level)
			if layer == null:
				continue
			var source_id: int = layer.get_cell_source_id(cell)
			if source_id == -1:
				continue   ## erased elsewhere (occlusion/older destruction) — nothing to relight
			var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
			var prev_alt: int = layer.get_cell_alternative_tile(cell)
			var alt := _alt_for(field, cell, level, prev_alt)
			if alt == prev_alt:
				continue   ## nothing this blast changes for this cell — no wave entry needed
			_append(waves["soot"], ring, {"cell": cell, "level": level,
				"source_id": source_id, "atlas_coords": atlas_coords, "alt": alt,
				"r": _radius_of(cell, epicenter)})

	## --- Smoke, the GU-level remainder (E-SMOKE-01). The per-voxel puffs above
	## already cover every GU that took real damage; this fills only the GUs the
	## flood REACHED but left intact. Ring 3 is the case that makes it necessary
	## rather than decorative: `destroy/dent/crack_ring_weights[3]` are all 0.0
	## (§4.1 — ring 3 exists to carry soot), so ring 3 damages nothing and would
	## otherwise have lost the weak smoke D5/Q2 deliberately gave it ("smoke now
	## reaches ring 3, weak"). Same descriptor shape as before, one per GU. ---
	for gu in gu_rings.keys():
		if smoked_gus.has(gu):
			continue
		var ring: int = gu_rings[gu]
		if ring >= bomb_def.smoke_ring_weights.size():
			continue
		var weight: float = bomb_def.smoke_ring_weights[ring]
		if weight <= 0.0:
			continue
		var gu_center: Vector2i = GeometryCoords.gu_to_voxel_origin(gu) \
			+ Vector2i(int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0),
				int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0))
		var world_pos: Vector2 = voxel_renderer.voxel_world_position(gu_center, BlastCalculatorClass.GRENADE_LEVEL)
		_append(waves["smoke"], ring, {"world_pos": world_pos, "duration": weight,
			"scale": weight, "alpha": weight, "blobs": 0,
			"r": _radius_of(gu_center, epicenter)})

	## §3.4 — the Delta's queryable surface. `touched_voxels` is the object list
	## VL-PERSIST already consumed; `touched` is the same set as plain cells, for
	## anything that must outlive the Voxel references (a cached Delta, a HUD
	## readout). `census` stops being a print-only side effect.
	delta.touched_voxels = touched_voxels
	var touched_cells: Array[Vector3i] = []
	for v3 in touched_voxels:
		touched_cells.append(Vector3i(v3.grid_pos.x, v3.grid_pos.y, v3.level))
	delta.touched = touched_cells
	delta.census = census
	delta.cost_ms = float(Time.get_ticks_usec() - started_usec) / 1000.0
	return delta


## VL-D3 equivalent, computed from Voxel state rather than the live
## TileMapLayer (this class must not read placement state off the layer for
## anything that feeds the light field — see this file's own header doc).
static func _columns_with_structure(edge_registry: EdgeRegistry) -> Dictionary:
	var cols: Dictionary = {}
	for slice in edge_registry.all_slices():
		for v in slice.voxels:
			if v.visible:
				cols[v.grid_pos] = true
	return cols


## build_occupancy()'s own shape ({level: {cell: true}}), derived from
## Voxel.visible instead of the live TileMapLayer's get_used_cells() — the
## live layer still shows every voxel this blast just destroyed as PLACED
## (nothing has erased it yet, on purpose), so reading occupancy off it would
## light the fresh crater as if it were still solid rock.
##
## P-DELTA: `delta.visible_of()` rather than `v.visible`, because with a pure
## builder the crater does not exist on the Voxels yet either. One dictionary
## miss per untouched voxel is the whole cost of that, and it buys the property
## that this same function lights a PREDICTED crater correctly — which is what a
## blast-radius preview will need.
static func _voxel_occupancy(edge_registry: EdgeRegistry, slab_registry: SlabRegistry,
		delta: WorldDelta) -> Dictionary:
	var occupancy: Dictionary = {}
	for slice in edge_registry.all_slices():
		for v in slice.voxels:
			if not delta.visible_of(v):
				continue
			if not occupancy.has(v.level):
				occupancy[v.level] = {}
			occupancy[v.level][v.grid_pos] = true
	for slab in slab_registry.all_slabs():
		for v in slab.voxels:
			if not delta.visible_of(v):
				continue
			if not occupancy.has(v.level):
				occupancy[v.level] = {}
			occupancy[v.level][v.grid_pos] = true
	return occupancy


## Mirrors room._index_soot_voxel() exactly (same three buckets, same rule:
## visible+damaged -> damaged_voxels, absent -> blast/weapon seed by
## provenance) — kept as an independent copy rather than a call into room.gd
## because this class must run without a real Room (the MinimalRoom selftest
## scaffold, matching Task 1b/2/3's own precedent).
##
## P-DELTA: classifies through the Delta's projection, for the same reason
## `_voxel_occupancy()` does — the holes this blast makes are what the soot is
## derived FROM, and with a pure builder they exist only in the Delta.
##
## The two output collections are deliberately DIFFERENT about this:
##  - `cell_to_voxel` keeps the REAL Voxel. `derive_soot_rings()` reads nothing
##    but the cell key off it, and the packaging loop downstream wants the real
##    object so `touched_voxels` can persist it.
##  - `damaged_voxels` gets the PROJECTED voxel, because its only consumer
##    (`apply_self_soot()`) reads `damage_state`, `damage_is_blast` and
##    `damage_carved_side` — a real Voxel would still read INTACT here and the
##    self-soot on every fresh dent/crack would silently vanish.
##    `project_voxel()` returns the original when nothing changed, so untouched
##    voxels cost no allocation.
static func _index_soot_voxel(cell_to_voxel: Dictionary, blast_cells: Array,
		weapon_cells: Array, damaged_voxels: Array, v: Voxel, delta: WorldDelta) -> void:
	var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
	cell_to_voxel[key] = v
	## ONE projection lookup, not three — this runs ~100 000 times per
	## detonation. See WorldDelta.projection_of() for the measurement.
	var p: Array = delta.projection_of(v)
	var touched: bool = not p.is_empty()
	var state: int = int(p[WorldDelta.P_STATE]) if touched else v.damage_state
	var vis: bool = bool(p[WorldDelta.P_VISIBLE]) if touched else v.visible
	if not vis or state == Voxel.DamageState.DESTROYED:
		var from_blast: bool = bool(p[WorldDelta.P_BLAST]) if touched else v.damage_is_blast
		if from_blast:
			blast_cells.append(key)
		else:
			weapon_cells.append(key)
	elif state == Voxel.DamageState.DENTED or state == Voxel.DamageState.CRACKED:
		damaged_voxels.append(delta.project_voxel(v) if touched else v)


## Mirrors room._merge_soot_into() exactly (min-wins per cell, min-per-face
## component) — independent copy for the same reason as _index_soot_voxel().
static func _merge_soot(out_snapshot: Dictionary, out_faces: Dictionary,
		src_snapshot: Dictionary, src_faces: Dictionary) -> void:
	for level in src_snapshot:
		if not out_snapshot.has(level):
			out_snapshot[level] = {}
		var level_map: Dictionary = out_snapshot[level]
		for cell in src_snapshot[level]:
			var ring: int = int(src_snapshot[level][cell])
			var existing: int = int(level_map.get(cell, -1))
			if existing < 0 or ring < existing:
				level_map[cell] = ring
	for level in src_faces:
		if not out_faces.has(level):
			out_faces[level] = {}
		var level_faces: Dictionary = out_faces[level]
		for cell in src_faces[level]:
			var faces: Vector3i = src_faces[level][cell]
			if level_faces.has(cell):
				var prev: Vector3i = level_faces[cell]
				level_faces[cell] = Vector3i(
					mini(prev.x, faces.x), mini(prev.y, faces.y), mini(prev.z, faces.z))
			else:
				level_faces[cell] = faces


## Baked pre-bake first (resolve_damage_voxel_swap(), zero live compositing),
## D33 live-compositing fallback second (_set_voxel_cell(apply=false), the
## SAME fallback the live render pipeline already falls to) — same two-tier
## order _process_dirty_slice_voxel()/_process_dirty_slab_voxel() use, just
## never applying either result to the live layer. Always returns a usable
## triple (the D33 fallback's own last-resort material-only path never
## fails), so this never returns {}.
##
## The trailing `baked` flag is census-only (E-DENT-01) — which of the two tiers
## actually answered. It is deliberately NOT copied into the plan entry: §6.1's
## entry shape is what Task 5 replays, and a wave has no business knowing where
## its tile came from.
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
## P-DELTA appended `cost_ms` — the Delta's own §3.4 field, printed here because
## this is the line a detonation is already read from, and §4.4's slice budget is
## measured against exactly this number. It is the cost UP TO the census, not the
## whole call (the soot-only wave and the GU smoke remainder still follow), which
## makes it comparable across runs but NOT the same figure as `delta.cost_ms`.
static func _print_census(census: Dictionary, source_gu: Vector2i, cost_ms: float) -> void:
	print("[E-PLAN] census gu=%s cost=%.1fms — surface/material: destroyed · dented · cracked (bake hits)"
		% [source_gu, cost_ms])
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
