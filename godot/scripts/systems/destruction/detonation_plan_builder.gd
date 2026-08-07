## DetonationPlanBuilder — EXPLOSION_REBUILD_MASTER_PLAN Task 4 (E-PLAN).
##
## Builds one `DetonationPlan` (§6.1) for a single grenade detonation: all
## resolution, all exposure fallback, and the single map-wide light-field
## query, folded into one plain Dictionary a later choreography driver
## (Task 5/E-WAVE) can play back as a pure sequence of `set_cell()`/
## `erase_cell()` calls with zero further compositing/lookup — the
## performance idea §2 states once: "no compositing, no lookup, no light
## rebuild, no allocation happens inside a wave."
##
## What this class does NOT do, on purpose:
##  - It never calls `layer.set_cell()`/`erase_cell()` — every VoxelRenderer
##    call it makes runs in resolve-only mode (`apply=false`, Task 4's own
##    seam added to `_set_voxel_cell()`/`render_slab()`/
##    `render_fixed_earth_level()`/`resolve_damage_voxel_swap()`). A voxel's
##    DAMAGE STATE is real (BlastCalculator.set_damage() calls are the
##    established, unchanged writer — DESTRUCTION_MASTER_PLAN §3), but its
##    on-screen TILE is only ever resolved, never painted, until a wave
##    chooses to apply the plan entry it produced here.
##  - It never CALLS `room.record_voxel_damage_to_base()`/increments
##    `_gu_blast_count`/appends a stamped-blast replay list — that is Task 5's
##    job, the same split Task 2/3 already established for their own new
##    parameters. It DOES return the raw material for the first of those
##    (`plan["touched_voxels"]`, `Array[Voxel]` — every voxel this blast's
##    containers actually changed the damage_state of, DESTROYED or DENTED/
##    CRACKED), so Task 5's caller can persist without a second flood/
##    find_affected_containers pass to re-derive the same set.
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
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const VoxelLightFieldClass = preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")

## VL-02c/D2 (unchanged from the pre-reset detonate_active() this task
## replaces) — the ground takes the blast as a CONTIGUOUS crater, radii
## derived from the bomb's own ring count.
const CRATER_MAX_FACTOR: float = 0.40
const CRATER_CORE_FACTOR: float = 0.4


## Builds and returns one DetonationPlan Dictionary. Empty `{}` sub-dicts for
## any wave kind with nothing to show — Task 5 reads with `.get(ring, [])`.
static func build_plan(bomb_def, source_gu: Vector2i, ctx: Dictionary) -> Dictionary:
	var edge_registry: EdgeRegistry = ctx["edge_registry"]
	var slab_registry: SlabRegistry = ctx["slab_registry"]
	var voxel_renderer: VoxelRendererClass = ctx["voxel_renderer"]
	var blocked_edges: Dictionary = ctx.get("blocked_edges", {})
	var blocked_cells: Dictionary = ctx.get("blocked_cells", {})
	var deep_layer_unlocked: bool = ctx.get("deep_layer_unlocked", false)

	var plan: Dictionary = {
		"destroy": {}, "dented": {}, "cracked": {}, "smoke": {}, "soot": {},
		"touched_voxels": [],   ## Array[Voxel] — Task 5's persistence seam, see below
	}

	var gu_rings := BlastCalculatorClass.flood_gu_rings(source_gu, bomb_def, blocked_edges, blocked_cells)
	var affected := BlastCalculatorClass.find_affected_containers(gu_rings, edge_registry, slab_registry)
	var n_rings: int = bomb_def.ring_multipliers.size()
	var epicenter: Vector2i = source_gu * GeometryCoords.VOXELS_PER_UNIT_AXIS \
		+ Vector2i(int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0),
			int(float(GeometryCoords.VOXELS_PER_UNIT_AXIS) / 2.0))

	## Captured BEFORE any set_damage() call below — VL-D3's own contract
	## ("computed from the INTACT geometry right after a build, before
	## reapply_damage") — a floor voxel newly exposed by THIS blast must read
	## as "never saw the sun" using the geometry that stood over it a moment
	## ago, not the hole this same call is about to punch.
	var under_structure: Dictionary = ctx.get("under_structure", {})
	if under_structure.is_empty():
		under_structure = _columns_with_structure(edge_registry)

	## --- Resolution: the real writers, unchanged (Task 2/3's own calc layer).
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
		BlastCalculatorClass.apply_container_damage(
			slice.voxels, slice.id, slice.material, base_ring, base_level, false,
			bomb_def.ring_multipliers, bomb_def.destroy_ring_weights,
			bomb_def.dent_ring_weights, bomb_def.crack_ring_weights, epicenter)
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
		BlastCalculatorClass.apply_container_damage(
			roof.voxels, roof.id, roof.material, base_ring, roof.level, true,
			bomb_def.ring_multipliers, bomb_def.destroy_ring_weights,
			bomb_def.dent_ring_weights, bomb_def.crack_ring_weights, epicenter)
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
		BlastCalculatorClass.apply_crater_damage(
			floor_slab.voxels, floor_slab.id, epicenter, crater_core, crater_max,
			floor_slab.material, deep_layer_unlocked)
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
			if v.damage_state == Voxel.DamageState.DESTROYED:
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
			_index_soot_voxel(cell_to_voxel, blast_cells, weapon_cells, damaged_voxels, v)
	for slab2 in slab_registry.all_slabs():
		for v in slab2.voxels:
			_index_soot_voxel(cell_to_voxel, blast_cells, weapon_cells, damaged_voxels, v)

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
	var occupancy := _voxel_occupancy(edge_registry, slab_registry)
	var top_wall_level: int = maxi(voxel_renderer.get_layer_count() - 1, 0)
	var field := VoxelLightFieldClass.new()
	field.build(ctx.get("lights", []), ctx.get("shadow_results", []), top_wall_level,
		occupancy, soot_snapshot, under_structure, soot_faces)

	## --- Package destroy/dented/cracked, keyed by ring, from the containers'
	## already-mutated Voxel state (never re-derived, never re-rolled). ---
	var touched_this_blast: Dictionary = {}   ## Vector3i -> true, excludes these from the soot-only wave
	## Every voxel whose damage_state this blast actually changed — the exact
	## set room.record_voxel_damage_to_base() needs for VL-PERSIST (rotation
	## survival). Returned alongside the plan (see "touched_voxels" below) so
	## Task 5's caller persists from real Voxel objects, never re-deriving the
	## affected set with a second flood/find_affected_containers pass.
	var touched_voxels: Array = []
	for key in ring_of:
		var voxel: Voxel = cell_to_voxel.get(key)
		if voxel == null:
			continue
		var ring: int = ring_of[key]
		if voxel.damage_state == Voxel.DamageState.DESTROYED:
			touched_this_blast[key] = true
			touched_voxels.append(voxel)
			_append(plan["destroy"], ring, {"cell": voxel.grid_pos, "level": voxel.level})
		elif voxel.damage_state == Voxel.DamageState.DENTED or voxel.damage_state == Voxel.DamageState.CRACKED:
			touched_this_blast[key] = true
			touched_voxels.append(voxel)
			var resolved := _resolve_damaged_tile(voxel, container_of.get(key), voxel_renderer)
			var alt := _alt_for(field, voxel.grid_pos, voxel.level, resolved["alternative_id"])
			var wave_key: String = "dented" if voxel.damage_state == Voxel.DamageState.DENTED else "cracked"
			_append(plan[wave_key], ring, {"cell": voxel.grid_pos, "level": voxel.level,
				"source_id": resolved["source_id"], "atlas_coords": resolved["atlas_coords"], "alt": alt})

	## --- Exposure fallback: the floor reveals from above, wired into their
	## owning ring's destroy entries (§6.1's `expose` sub-array), lit through
	## the SAME field query as everything else. ---
	for ring in exposed_by_ring:
		var lit_expose: Array = []
		for e in exposed_by_ring[ring]:
			var alt := _alt_for(field, e["grid_pos"], e["level"], e["alternative_id"])
			lit_expose.append({"cell": e["grid_pos"], "level": e["level"],
				"source_id": e["source_id"], "atlas_coords": e["atlas_coords"], "alt": alt})
		if not plan["destroy"].has(ring):
			plan["destroy"][ring] = []
		var carrier: Array = plan["destroy"][ring]
		if carrier.is_empty():
			## Shouldn't happen — a reveal only fires alongside a real destroy
			## in the same ring — kept as an honestly-labelled defensive entry
			## (epicenter cell, not a real destroyed voxel) rather than
			## silently dropping the exposed tiles.
			carrier.append({"cell": epicenter, "level": GeometryCoords.FLOOR_TOP_LEVEL, "expose": lit_expose})
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
			_append(plan["soot"], ring, {"cell": cell, "level": level,
				"source_id": source_id, "atlas_coords": atlas_coords, "alt": alt})

	## --- Smoke: smoke_ring_weights' first real consumer (Task 3's closure
	## note flagged this as still-unread). One descriptor per GU actually
	## reached by the flood, ring-scaled duration/scale — Task 5 owns picking
	## a material color and calling SmokeSparkOverlay.add_smoke(). ---
	for gu in gu_rings.keys():
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
		_append(plan["smoke"], ring, {"world_pos": world_pos, "duration": weight, "scale": weight})

	plan["touched_voxels"] = touched_voxels
	return plan


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
static func _voxel_occupancy(edge_registry: EdgeRegistry, slab_registry: SlabRegistry) -> Dictionary:
	var occupancy: Dictionary = {}
	for slice in edge_registry.all_slices():
		for v in slice.voxels:
			if not v.visible:
				continue
			if not occupancy.has(v.level):
				occupancy[v.level] = {}
			occupancy[v.level][v.grid_pos] = true
	for slab in slab_registry.all_slabs():
		for v in slab.voxels:
			if not v.visible:
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
static func _index_soot_voxel(cell_to_voxel: Dictionary, blast_cells: Array,
		weapon_cells: Array, damaged_voxels: Array, v: Voxel) -> void:
	var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
	cell_to_voxel[key] = v
	if not v.visible or v.damage_state == Voxel.DamageState.DESTROYED:
		if v.damage_is_blast:
			blast_cells.append(key)
		else:
			weapon_cells.append(key)
	elif v.damage_state == Voxel.DamageState.DENTED or v.damage_state == Voxel.DamageState.CRACKED:
		damaged_voxels.append(v)


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
static func _resolve_damaged_tile(voxel: Voxel, container, voxel_renderer: VoxelRendererClass) -> Dictionary:
	if container == null:
		return {"source_id": 0, "atlas_coords": Vector2i.ZERO, "alternative_id": 0}
	var baked := voxel_renderer.resolve_damage_voxel_swap(voxel, container)
	if not baked.is_empty():
		return {"source_id": baked["source_id"], "atlas_coords": baked["atlas_coords"], "alternative_id": 0}
	if container is Slice:
		var slice: Slice = container
		var voxel_xy := Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
		var render_material := VoxelRendererClass.damage_variant_material(
			slice.material, voxel.damage_state, voxel.damage_is_blast,
			voxel.damage_carved_side, voxel.damage_variant)
		var resolved := voxel_renderer._set_voxel_cell(voxel.grid_pos, voxel.level, render_material,
			null, voxel_xy, slice.face, false, "", BakePolicyClass.SurfaceClass.SLICE, false)
		return {"source_id": resolved["source_id"], "atlas_coords": resolved["atlas_coords"],
			"alternative_id": resolved["alternative_id"]}
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
		"alternative_id": resolved2["alternative_id"]}


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
