## RoomBuilder
## Orchestrates room construction, tile placement, and perspective transformations.
## Handles loading maps, building layouts, caching blocked cells, and coordinate rotations.

class_name RoomBuilder

var room: Node
var PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
var BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")
var MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")
var PropRegistryClass = preload("res://godot/scripts/systems/prop_registry.gd")
var MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
var DamageVariantBakerClass = preload("res://godot/scripts/systems/damage_variant_baker.gd")
var VoxelVariantRegistryClass = preload("res://godot/scripts/systems/voxel_variant_registry.gd")

# BAKE-FACADE-PLANE-02-b: Persistent bake compositor across map reloads
var _bake_compositor: Object = null

## D13 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): persistent material
## registry, shared by the damage-substrate-usage injection below and
## _bake_textures()'s own BakeCompositor wiring (which used to create its own
## local, throwaway instance each first bake) — one registry, lazily loaded
## once, same lifecycle as _bake_compositor.
var _material_registry: Object = null

func _get_material_registry() -> Object:
	if _material_registry == null:
		_material_registry = MaterialRegistryClass.new()
		_material_registry.load_from_disk()
	return _material_registry


## D34/E-SEAM-01: union roof and floor specs that landed on the same
## (material_id, facade_id) combo — which a `has_facade` material now always
## does, since its floor and its roof reproject the identical source. Returns
## one spec per combo carrying BOTH surfaces' cells; combos unique to one
## surface pass through unchanged. Order is preserved (roof first, then any
## floor-only combo) so a bake is deterministic across runs, which the
## VL-PERF-BAKE cache key depends on.
func _merge_horizontal_specs(roof_specs: Array, floor_specs: Array) -> Array:
	var by_combo: Dictionary = {}
	var order: Array[String] = []
	for spec: Dictionary in roof_specs + floor_specs:
		var combo_key := "%s|%s" % [spec.get("material_id", ""), spec.get("facade_id", "")]
		if not by_combo.has(combo_key):
			by_combo[combo_key] = {}
			order.append(combo_key)
		var seen: Dictionary = by_combo[combo_key]
		for cell in spec.get("cells", []):
			seen[cell] = true

	var merged: Array = []
	for combo_key in order:
		var parts: PackedStringArray = combo_key.split("|")
		merged.append({
			"material_id": parts[0],
			"facade_id": parts[1],
			"cells": by_combo[combo_key].keys(),
		})
	return merged


## D34/E-SEAM-01: the one field the SLAB texture family split reads (see
## BakePolicy's header). An unregistered material warns loudly (B6) and falls
## back to `false` — the pre-D34 behaviour for every floor, so an unknown
## material degrades to what it already did instead of silently changing
## family.
func _material_has_facade(material_id: String) -> bool:
	var md = _get_material_registry().get_material(material_id)
	if md == null:
		push_warning("[RoomBuilder] material '%s' is not registered — floor bake falls back to the photographic slab_ family (D34)" % material_id)
		return false
	return md.has_facade


## D13/§3 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): force
## DamageVariantBaker's chosen substrate-crop positions into real bake usage.
## BakeCompositor bakes SPARSELY — only (col,row) cells real wall/roof/floor
## placements actually use get composed — so without this, a declared
## material's damage-atom substrate would only resolve by accident, if a real
## surface happened to already use that exact synthetic position. Merges into
## the SAME `cells_by_combo` dict the real usage loop populates (not a
## separate spec entry), so a combo that's also genuinely used keeps its real
## cells too — `_compose_roof_pages` caches by (material, facade) combo, so a
## second, separate spec entry for the same combo would just cache-HIT the
## first one's cells and silently miss the synthetic positions.
##
## D34/E-SEAM-01: the combo key MUST be derived exactly the way the real usage
## loop above derives it, or the synthetic substrate positions land in a combo
## nothing places and the damage atoms resolve against an unbaked page. Now
## that a `has_facade` material's FLOOR shares its wall's `facade_<id>` combo,
## that means routing SLAB through texture_for_material() too, not through the
## bare slab_for_material() this used before.
func _inject_damage_substrate_usage(cells_by_combo: Dictionary, materials: Array,
		surface_class: int) -> void:
	if materials.is_empty():
		return
	var registry = _get_material_registry()
	var want_facade: bool = surface_class == BakePolicyClass.SurfaceClass.SLICE
	for material in materials:
		var m := String(material)
		var md = registry.get_material(m)
		if md == null or (want_facade and not md.has_facade):
			continue
		var facade_id: String = BakePolicyClass.texture_for_material(m, surface_class, md.has_facade)
		var combo_key := "%s|%s" % [m, facade_id]
		if not cells_by_combo.has(combo_key):
			cells_by_combo[combo_key] = {}
		for pos in DamageVariantBakerClass.SUBSTRATE_POSITIONS:
			cells_by_combo[combo_key][pos] = true

## VL-PERF-BAKE: baked pages/tiles depend only on the (material, facade) combos
## present, not on the view — so a perspective rotation produces byte-identical
## sources. Cache them keyed by (map_id, blend_mode, combo set); on a matching
## rotation, skip prune + compositor bake + ~9k create_tile registrations
## (~730ms) and rebuild only the cheap BakedTileLookup with the rotated runs.
## Invalidated (full rebake) on map change, blend-mode change, or a new combo.
var _cached_bake_key: String = ""
var _cached_baked_atlas = null
var _cached_source_ids: Dictionary = {}

var _room_size: Vector2i = Vector2i.ZERO
var _wall_tileset: TileSet = null
var _prop_stack_layers: Array[TileMapLayer] = []
var _blocked_cells: Dictionary = {}
var _prop_heights: Dictionary = {}
var _prop_cover: Dictionary = {}
var _exit_cells: Array[Vector2i] = []
var _current_light_sources: Array = []
var _tile_ids: Dictionary = {}

# References to room layers
var floor_layer: TileMapLayer = null
var structure_layer: TileMapLayer = null


func _init(p_room: Node) -> void:
	room = p_room


func setup(floor_ref: TileMapLayer, structure: TileMapLayer, wall_tileset: TileSet) -> void:
	floor_layer = floor_ref
	structure_layer = structure
	_wall_tileset = wall_tileset


func build_from_layout(layout: Dictionary, room_size: Vector2i) -> void:
	_room_size = room_size
	floor_layer.clear()
	structure_layer.clear()

	var floor_tile_name := String(layout.get("floor_tile_name", "floor_SE"))
	## Fills exactly the MAP_SIZE grid. The 5-tile buffer in the layout builder
	## replaces the old negative extension — no coordinates outside the range [0, MAP_SIZE).
	for x in range(0, _room_size.x):
		for y in range(0, _room_size.y):
			_place(Vector2i(x, y), floor_tile_name)

	## Voxel render plane: wall/block descriptors become stacked voxel presence.
	## The old wall-storey layers remain as a fallback path, but the active render
	## now comes from the edge seam's voxel geometry integration.
	
	## SLICE-02: New geometry module integration — edges → slices → voxels
	var extraction: Dictionary = EdgeExtractor.extract(layout)

	var _diag_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var _diag_on: bool = _diag_bake_config != null and _diag_bake_config.debug_bake_set_dump
	if _diag_on:
		print("[BAKE-DIAG] build_from_layout: extraction edges=%d, bake_enabled=%s" % [
			extraction.get("edges", []).size(), _diag_bake_config.enabled
		])

	## E-BUBBLE wall-sectioning support: EdgeExtractor's edges already carry the
	## per-edge start_storey/storey_count SliceGenerator turns into voxels below
	## — but nothing retained that for a runtime query, so it was discarded the
	## moment the slices existed. AimBubbleOverlay needs exactly this (which
	## walls, how tall, in GU) to mould its grid around parapets and blocks
	## instead of assuming every nearby wall is full-height. Keyed by
	## WallEdgeData.edge_key() per Rule 3 — never a second key format.
	var wall_height_edges: Dictionary = {}
	for extracted_edge in extraction.get("edges", []):
		wall_height_edges[WallEdgeData.edge_key(extracted_edge.gu_a, extracted_edge.gu_b)] = {
			"start_storey": extracted_edge.start_storey,
			"storey_count": extracted_edge.storey_count,
		}
	room._wall_height_edges = wall_height_edges

	## D1/Part 1 (DESTRUCTION_MASTER_PLAN): SlabRegistry published unconditionally
	## — a room has a floor whether or not it has walls (edges), unlike the block
	## below. Previously nested inside the edges-conditional, which would have
	## left room._slab_registry null for any edge-less room; moved here so that
	## can no longer happen.
	room._slab_registry = SlabRegistry.new()

	## room._voxel_renderer.clear() also moved here, unconditional, mirroring why
	## floor_layer/structure_layer are cleared unconditionally above: a room that
	## loses its edges on rebuild must not keep stale wall geometry from a
	## previous build. render() below (walls) and render_slab() (floor, next)
	## only ADD cells on top of a cleared renderer — neither touches state the
	## other owns.
	room._voxel_renderer.clear()
	## FLOOR-DEPTH-01: same reasoning one level down — the per-GU zone table the
	## FIXED ground levels read is republished below from this build's own slabs,
	## so a map switch or rotation must not inherit the previous layout's.
	room._voxel_renderer.clear_floor_zones()

	## Floor-zone bake: author-declared material rects (layout.floor_zone_instances,
	## MapCompiler-produced, always present even if empty) expanded to a per-GU
	## dict. Last rect in the spec list wins on overlap. Computed unconditionally,
	## same as the floor loop below it feeds — floor zones don't depend on the
	## room having any edges/roof.
	var floor_zone_by_gu: Dictionary = {}
	for zone: Dictionary in layout.get("floor_zone_instances", []):
		var zone_gu_base: Vector2i = zone.get("gu_cell", Vector2i.ZERO)
		var zone_size: Vector2i = zone.get("size", Vector2i.ONE)
		var zone_material: String = String(zone.get("material", ""))
		if zone_material == "":
			continue
		for zx in range(zone_size.x):
			for zy in range(zone_size.y):
				floor_zone_by_gu[zone_gu_base + Vector2i(zx, zy)] = zone_material

	## Same connected-component flood-fill as the roof texture_anchor pass
	## below, substituting "same declared zone material" for "both roofed" as
	## the adjacency test (4-adjacency). Two disconnected regions of the same
	## material still get independent anchors, matching roof's behavior.
	var floor_anchor_by_gu: Dictionary = {}
	for start_gu: Vector2i in floor_zone_by_gu:
		if floor_anchor_by_gu.has(start_gu):
			continue
		var f_component: Array[Vector2i] = []
		var f_stack: Array[Vector2i] = [start_gu]
		var f_seen: Dictionary = {start_gu: true}
		var f_min_corner: Vector2i = start_gu
		var f_zone_material: String = floor_zone_by_gu[start_gu]
		while not f_stack.is_empty():
			var gu: Vector2i = f_stack.pop_back()
			f_component.append(gu)
			f_min_corner = Vector2i(mini(f_min_corner.x, gu.x), mini(f_min_corner.y, gu.y))
			for delta: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var neighbour := gu + delta
				if floor_zone_by_gu.get(neighbour, "") == f_zone_material and not f_seen.has(neighbour):
					f_seen[neighbour] = true
					f_stack.append(neighbour)
		var f_anchor: Vector2i = GeometryCoords.gu_to_voxel_origin(f_min_corner)
		for gu in f_component:
			floor_anchor_by_gu[gu] = f_anchor

	## DESTRUCTION D13/D17/D18: only the top destructible level (storey −1) is
	## built at map load, for every GU the legacy floor loop above also covers.
	## The 7 fixed levels beneath it (D13) stay unbuilt until something actually
	## digs down to them — that trigger is Part 3, not built yet (D18's lazy
	## reveal). Same _room_size/GU coverage as the legacy floor on purpose: the
	## two floors occupy different vertical space (storey −1 vs. the legacy
	## coarse plane) and are not in conflict, so there is no reason for their
	## coverage to differ.
	## NOTE: generation only here — rendering is deferred (see the render_slab()
	## loop after the edges-conditional block below). A zoned floor Slab's
	## flat_baked lookup needs _bake_textures() to have already run; rendering
	## immediately here (as this loop used to, back when floor never baked
	## anything) would query the atlas before this call's own bake pass built
	## it, always MISS, and silently fall back to MATERIALS[0] ("concrete") —
	## the same lesson ROOF-BAKE-01 already learned for roof_slabs, which is
	## why those are generated here but rendered only after render(), below.
	##
	## FLOOR-DEPTH-01 (Director, 2026-07-28): the destructible ground is now TWO
	## planes, not one — FLOOR_TOP_LEVEL as before, plus FLOOR_DEEP_LEVEL beneath
	## it, so a crater has a second storey to dig into instead of bottoming out on
	## indestructible bedrock the moment the surface goes. The deep plane is
	## GENERATED here (it must exist as real Voxels to take damage, persist through
	## rotation, and re-render through the same dirty-flag machinery as everything
	## else) but deliberately NOT rendered at build time: it is completely occluded
	## by the plane above it, so placing 64 cells per GU for it would double the
	## floor's tilemap footprint and the per-cell cost of every full light-field
	## repaint, to draw nothing. It is rendered on exposure instead — see
	## VoxelRenderer.reveal_floor_slab().
	const FLOOR_TOP_LEVEL := GeometryCoords.FLOOR_TOP_LEVEL
	var floor_slabs_by_gu: Dictionary = {}
	for fx in range(0, _room_size.x):
		for fy in range(0, _room_size.y):
			var floor_gu := Vector2i(fx, fy)
			## D35/E-EARTH-01: "earth" is BOTH a real material (buildable on
			## walls/blocks/roofs since D35) and the sentinel below for "this GU
			## has no declared floor zone". Only the floor path conflates them,
			## and the Director scoped D35 to buildable-earth deliberately — so
			## a zone that DECLARES earth is silently indistinguishable from an
			## undeclared GU. Say so out loud (B6) instead of dropping it: the
			## author gets told why their zone did nothing.
			if floor_zone_by_gu.get(floor_gu, "") == "earth":
				push_warning("[RoomBuilder] floor_zone at GU %s declares 'earth', which is the sentinel for an UNDECLARED floor — the zone is ignored and this GU renders via EarthVariantSelector. Baked earth ground needs the sentinel split (D35 scope note); earth on walls/blocks/roofs works today." % floor_gu)
			var floor_material: String = floor_zone_by_gu.get(floor_gu, "earth")
			var floor_anchor: Vector2i = floor_anchor_by_gu.get(floor_gu, Vector2i.ZERO)
			var floor_slab := SlabGenerator.generate(floor_gu, Slab.Role.FLOOR, FLOOR_TOP_LEVEL, floor_material, room._slab_registry)
			var deep_slab := SlabGenerator.generate(floor_gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_DEEP_LEVEL, floor_material, room._slab_registry)
			if floor_material != "earth":
				floor_slab.texture_anchor = floor_anchor
				deep_slab.texture_anchor = floor_anchor
				## Publish the zone for the FIXED levels below both Slabs (D13's
				## direct-cell path has no container to read it from).
				room._voxel_renderer.set_floor_zone(floor_gu, floor_material, floor_anchor)
			floor_slabs_by_gu[floor_gu] = floor_slab

	## Floor-zone bake spec, same shape/derivation as roof_specs below (real
	## Slab voxels, structure-local offsets). Built unconditionally so it's
	## ready regardless of whether the room has edges; only actually baked by
	## _bake_textures() below when it does — an edge-less room has no
	## edge_registry/junction infrastructure to bake against, so a floor zone
	## declared in an edge-less room falls back to plain earth rendering
	## (v1 scoping; matches every other roof/wall baked surface, which also
	## requires edges to exist).
	var floor_specs: Array = []
	var floor_cells_by_combo: Dictionary = {}
	## D13: real floor materials seen this build — the subset of the map's
	## declared damage_materials that DamageVariantBaker.bake_all() should
	## actually bake a FLOOR atom for (baking one for a declared material
	## that's never a floor would just be unused bloat).
	var floor_materials_used: Dictionary = {}
	for floor_gu in floor_slabs_by_gu:
		var floor_slab: Slab = floor_slabs_by_gu[floor_gu]
		if floor_slab.material == "earth":
			continue
		floor_materials_used[floor_slab.material] = true
		## D34/E-SEAM-01 (Director, 2026-08-08): a floor is a roof at the base
		## of the scene, so a `has_facade` material's floor bakes through the
		## SAME SLICE source its wall and roof do — which is what makes a
		## concrete floor read as concrete instead of as an unrelated ground
		## photo. Only `has_facade == false` materials (the organic ground:
		## grass/dirt/sand/gravel) keep D20's photographic `slab_<material>`
		## path. BakePolicy.texture_for_material() owns that split; the LOOKUP
		## side (BakedTileLookup.resolve_flat) must apply the identical rule or
		## B1 breaks, which is why both read it from the same MaterialDef field
		## rather than each deciding locally.
		var floor_combo_key := "%s|%s" % [floor_slab.material,
			BakePolicyClass.texture_for_material(floor_slab.material,
				BakePolicyClass.SurfaceClass.SLAB, _material_has_facade(floor_slab.material))]
		if not floor_cells_by_combo.has(floor_combo_key):
			floor_cells_by_combo[floor_combo_key] = {}
		for voxel in floor_slab.voxels:
			floor_cells_by_combo[floor_combo_key][voxel.grid_pos - floor_slab.texture_anchor] = true
	var damage_materials: Array = layout.get("damage_materials", [])
	var damage_floor_materials: Array = []
	for m in floor_materials_used.keys():
		if damage_materials.has(m):
			damage_floor_materials.append(m)
	_inject_damage_substrate_usage(floor_cells_by_combo, damage_floor_materials,
		BakePolicyClass.SurfaceClass.SLAB)

	## D13 (EXPLOSION_REBUILD_MASTER_PLAN §3.5): loud-fail (B6) if this map's
	## declared damage_materials is missing a material its walls/blocks/
	## floor_zones actually use — a forgotten declaration means that
	## material's damage atoms silently never bake, and every hit on it falls
	## back to D33 live compositing forever without anyone noticing why.
	var real_materials_used: Dictionary = {}
	for e in extraction.get("edges", []):
		real_materials_used[e.material] = true
	for b: Dictionary in layout.get("solid_block_instances", []):
		real_materials_used[String(b.get("material", ""))] = true
	for m in floor_materials_used.keys():
		real_materials_used[m] = true
	for m in real_materials_used.keys():
		if m != "" and m != "earth" and not damage_materials.has(m):
			push_warning("[RoomBuilder] material '%s' is used by this map but missing from its damage_materials section — its damage atoms will never bake (D13)" % m)
	for floor_combo_key in floor_cells_by_combo:
		var floor_parts: PackedStringArray = String(floor_combo_key).split("|")
		floor_specs.append({
			"material_id": floor_parts[0],
			"facade_id": floor_parts[1],
			"cells": floor_cells_by_combo[floor_combo_key].keys(),
		})

	## D18 amendment (Director, 2026-07-16), dev-only: the map's outer edge
	## shows the floor's lateral cut — lazy reveal alone leaves that edge only
	## 1 voxel thick. In the shipped game a non-playable camera-buffer zone
	## hides this by construction, so this eager-build is temporary scaffolding
	## for development (inspecting deeper cosmetic storeys before Part 3's dig
	## trigger exists), not permanent scope — remove once that buffer lands.
	## Enumerates the perimeter directly (top/bottom rows, then left/right
	## columns excluding the corners already covered) — O(room_size.x +
	## room_size.y), never the full area, however large the map gets.
	var border_gus: Array[Vector2i] = []
	for bx in range(0, _room_size.x):
		border_gus.append(Vector2i(bx, 0))
		if _room_size.y > 1:
			border_gus.append(Vector2i(bx, _room_size.y - 1))
	for by in range(1, _room_size.y - 1):
		border_gus.append(Vector2i(0, by))
		if _room_size.x > 1:
			border_gus.append(Vector2i(_room_size.x - 1, by))

	for border_gu in border_gus:
		for fixed_level in range(FLOOR_TOP_LEVEL - 7, FLOOR_TOP_LEVEL):  # -8..-2
			room._voxel_renderer.render_fixed_earth_level(border_gu, fixed_level)

	if not extraction.get("edges", []).is_empty():
		## New geometry path — the only active renderer when it has data.
		##
		## The registry and the junction columns are PUBLISHED BACK TO THE ROOM, not kept
		## local. Until 2026-07-12 these two lines read `var _edge_registry = ...` /
		## `var _junction_columns = ...` — function locals that shadowed room.gd's members
		## of the same name and were discarded on return. room._edge_registry therefore
		## stayed null forever, and room.gd::_tic_voxel_system() —
		##     if _voxel_renderer != null and _edge_registry != null:
		##         _voxel_renderer.process_dirty(_edge_registry)
		## — could never fire. The destruction/dirty-flag motor was not merely "built but
		## not switched on": it was severed at both ends. OCCLUSION and DESTRUCTION both
		## need this handle, so it is published here rather than re-derived by each.
		var edge_registry := EdgeRegistry.new()
		SliceGenerator.generate(extraction["edges"], edge_registry)
		var junction_columns := JunctionResolver.resolve(edge_registry)

		# BAKE-FIX-02: Apply junction overrides from layout (if available)
		_apply_junction_overrides(junction_columns, layout)

		## DESTRUCTION D1-ROOF: a roof above every real block from the map's own
		## "blocks" section. Reuses solid_block_instances (MapCompiler forwards
		## the ORIGINAL per-GU declaration — gu, size, storeys, material — same
		## data solidblock_ tiles were expanded from) rather than re-deriving
		## footprint/height/material from edge_registry, which represents the
		## block's WALLS, not "this GU is a block worth roofing" directly.
		## ROOF_LEVEL_COUNT is a placeholder default ("2 ou mais", Director) —
		## every level is an independent, fully destructible Slab (Role.CEILING),
		## unlike the floor's one-destructible-level model (D13).
		##
		## Each GU's roof grows a 1-voxel border (SlabGenerator.generate_with_border(),
		## Director 2026-07-16) to reach the wall's OUTER slice, which
		## SliceGenerator places one voxel into the NEIGHBOUR GU — a same-size
		## roof looks unfinished at every wall otherwise.
		##
		## Per-side, computed MAP-WIDE — corrected 2026-07-16 after
		## roof_integration_selftest.gd caught 15/49 real PLAYGROUND blocks
		## with corrupted core geometry. The first version only suppressed a
		## side when it faced another GU of the SAME solid_block_instances
		## entry (i.e. within one declared multi-GU block) — but PLAYGROUND's
		## own test fixture places 5 same-material blocks as 5 SEPARATE 1x1
		## declarations in a contiguous row, not one multi-GU block. GUs have
		## ZERO gap between them, so each border reached one voxel into the
		## next declaration's own core row/column — a real, reproducible
		## overlap, not the rare cross-structure edge case originally assumed
		## acceptable to leave undefended. Fix: build the set of every roofed
		## GU across ALL block instances first, then suppress a side whenever
		## ANY roofed neighbour exists there, regardless of which declaration
		## it came from.
		##
		## ROOF-BAKE-01: GENERATION hoisted above _bake_textures() (rendering
		## stays below, after render()): the bake pass needs each roof combo's
		## real voxel cells as sheet usage, and the actual Slab voxels are the
		## single truth for that footprint — deriving cells a second way here
		## would be exactly the split-brain the border fix above just killed.
		const ROOF_LEVEL_COUNT := 2

		## ROOF-BAKE-02b: adjacency is LEVEL-AWARE. The old boolean set made
		## neighbours of DIFFERENT heights mutually suppress borders neither
		## could visually provide at the other's level — a 1-voxel gap at every
		## storey step. Rule: suppress a side when the neighbour's roof base is
		## at the SAME level (continuous flat roof) or HIGHER (the taller
		## block's wall far-slice already fills that seam column at our level —
		## growing into it would double-write Slice-owned cells). Grow toward a
		## LOWER neighbour (an eave over its roof; levels never collide, the
		## height difference is ≥ LEVELS_PER_STOREY > ROOF_LEVEL_COUNT).
		var roof_level_by_gu: Dictionary = {}
		for block_instance: Dictionary in layout.get("solid_block_instances", []):
			var occ_gu_base: Vector2i = block_instance.get("gu_cell", Vector2i.ZERO)
			var occ_size: Vector2i = block_instance.get("size", Vector2i.ONE)
			var occ_level: int = maxi(1, int(block_instance.get("storeys", 1))) * GeometryCoords.LEVELS_PER_STOREY
			for ox in range(occ_size.x):
				for oy in range(occ_size.y):
					roof_level_by_gu[occ_gu_base + Vector2i(ox, oy)] = occ_level

		## ROOF-BAKE-02c: one texture anchor per CONNECTED component of roofed
		## GUs (4-adjacency, level- and material-blind: contiguous roofs form
		## one visual surface even across declarations — the D1-ROOF-b lesson).
		## Anchor = voxel origin of the component's bounding-box NW corner, so
		## the baked pattern is structure-local (see Slab.texture_anchor).
		var roof_anchor_by_gu: Dictionary = {}
		for start_gu: Vector2i in roof_level_by_gu:
			if roof_anchor_by_gu.has(start_gu):
				continue
			var component: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start_gu]
			var seen: Dictionary = {start_gu: true}
			var min_corner: Vector2i = start_gu
			while not stack.is_empty():
				var gu: Vector2i = stack.pop_back()
				component.append(gu)
				min_corner = Vector2i(mini(min_corner.x, gu.x), mini(min_corner.y, gu.y))
				for delta: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var neighbour := gu + delta
					if roof_level_by_gu.has(neighbour) and not seen.has(neighbour):
						seen[neighbour] = true
						stack.append(neighbour)
			var anchor: Vector2i = GeometryCoords.gu_to_voxel_origin(min_corner)
			for gu in component:
				roof_anchor_by_gu[gu] = anchor

		var roof_slabs: Array[Slab] = []
		for block_instance: Dictionary in layout.get("solid_block_instances", []):
			var block_gu_base: Vector2i = block_instance.get("gu_cell", Vector2i.ZERO)
			var block_size: Vector2i = block_instance.get("size", Vector2i.ONE)
			var block_storeys: int = int(block_instance.get("storeys", 1))
			var block_material: String = String(block_instance.get("material", "concrete"))
			var roof_base_level: int = block_storeys * GeometryCoords.LEVELS_PER_STOREY

			for rx in range(block_size.x):
				for ry in range(block_size.y):
					var roof_gu := block_gu_base + Vector2i(rx, ry)
					var border_west: int = 0 if int(roof_level_by_gu.get(roof_gu + Vector2i(-1, 0), -1)) >= roof_base_level else 1
					var border_east: int = 0 if int(roof_level_by_gu.get(roof_gu + Vector2i(1, 0), -1)) >= roof_base_level else 1
					var border_north: int = 0 if int(roof_level_by_gu.get(roof_gu + Vector2i(0, -1), -1)) >= roof_base_level else 1
					var border_south: int = 0 if int(roof_level_by_gu.get(roof_gu + Vector2i(0, 1), -1)) >= roof_base_level else 1
					for roof_level in range(roof_base_level, roof_base_level + ROOF_LEVEL_COUNT):
						var roof_slab := SlabGenerator.generate_with_border(
							roof_gu, Slab.Role.CEILING, roof_level, block_material, room._slab_registry,
							border_west, border_east, border_north, border_south,
						)
						roof_slab.texture_anchor = roof_anchor_by_gu[roof_gu]
						roof_slabs.append(roof_slab)

		## ROOF-BAKE-02c: per-combo roof usage for the compositor, read off the
		## real Slab voxels as STRUCTURE-LOCAL offsets (grid_pos − anchor). The
		## compositor owns the sheet fold (mirror period 64×32); placement uses
		## the same local offsets, so frag keys and lookup keys agree.
		var roof_specs: Array = []
		var roof_cells_by_combo: Dictionary = {}
		for roof_slab in roof_slabs:
			var combo_key := "%s|%s" % [roof_slab.material, BakePolicyClass.facade_for_material(roof_slab.material)]
			if not roof_cells_by_combo.has(combo_key):
				roof_cells_by_combo[combo_key] = {}
			for voxel in roof_slab.voxels:
				roof_cells_by_combo[combo_key][voxel.grid_pos - roof_slab.texture_anchor] = true
		_inject_damage_substrate_usage(roof_cells_by_combo, damage_materials,
			BakePolicyClass.SurfaceClass.SLICE)
		for combo_key in roof_cells_by_combo:
			var parts: PackedStringArray = String(combo_key).split("|")
			roof_specs.append({
				"material_id": parts[0],
				"facade_id": parts[1],
				"cells": roof_cells_by_combo[combo_key].keys(),
			})

		## Bake textures (S2: Wire baking into room_builder)
		## Floor-zone specs merge into the same array roof uses. D34/E-SEAM-01
		## changed what that merge means: the ids are no longer namespaced
		## apart (a concrete roof and a concrete floor are BOTH
		## "concrete|facade_concrete" now, deliberately — one shared page), so
		## the two spec lists must be merged BY COMBO, unioning their cells.
		## Plain concatenation would hand _compose_roof_pages() two specs on one
		## cache key and the second one's cells would vanish into a cache HIT —
		## the exact hazard _inject_damage_substrate_usage()'s own comment
		## already warns about. The VL-PERF-BAKE cache key below loops the
		## merged array, so invalidation on floor-zone edits stays automatic.
		var horizontal_specs: Array = _merge_horizontal_specs(roof_specs, floor_specs)
		var bake_config = load("res://godot/scripts/systems/bake_config.gd")
		if bake_config and bake_config.enabled:
			_bake_textures(extraction, edge_registry, junction_columns, horizontal_specs,
				damage_materials, damage_floor_materials)

		if _diag_on:
			print("[BAKE-DIAG] Pre-render: voxel_renderer._baked_lookup=%s, slices=%d, junction_columns=%d" % [
				("set" if room._voxel_renderer._baked_lookup != null else "NULL"),
				edge_registry.all_slices().size(), junction_columns.size()
			])

		room._edge_registry = edge_registry
		room._junction_columns = junction_columns

		## room._slab_registry and room._voxel_renderer.clear() moved to run
		## unconditionally above (before this if-block), so the floor exists even
		## for edge-less rooms. Do not re-add either here — re-instantiating the
		## registry would drop the floor Slabs just registered, and re-clear()ing
		## would erase the floor cells just placed.
		room._voxel_renderer.render(edge_registry, junction_columns)

		if _diag_on and room._voxel_renderer.has_method("print_render_diagnostics"):
			room._voxel_renderer.print_render_diagnostics()

		_render_solid_blocks(extraction.get("solid_blocks", []))
		_render_voxel_props(layout.get("voxel_prop_instances", []))

		## DESTRUCTION D1-ROOF rendering. Generation moved above _bake_textures()
		## (ROOF-BAKE-01) — see the hoisted block for the full D1-ROOF/border
		## rationale; this loop only renders what was generated there.
		for roof_slab in roof_slabs:
			room._voxel_renderer.render_slab_solid(roof_slab)
	elif _diag_on:
		print("[BAKE-DIAG] build_from_layout: extraction.edges EMPTY — geometry path skipped entirely, no voxel walls will render this call")

	## Floor rendering, deferred to here (generation happened earlier, before
	## the edges-conditional) so a zoned Slab's flat_baked lookup runs AFTER
	## _bake_textures() has had the chance to compose its page — see the
	## generation loop's own comment. Runs unconditionally: an edge-less room
	## never reaches _bake_textures() at all, so any zoned Slab there just
	## MISSes the (nonexistent) lookup and _set_voxel_cell falls back to
	## generic — matching the documented v1 edge-less-room limitation.
	for floor_gu in floor_slabs_by_gu:
		room._voxel_renderer.render_slab(floor_slabs_by_gu[floor_gu])

	## Props: base sprite on structure_layer; stacks render extra sprites on prop-stack
	## layers offset up by the crate body step (visual stacking). The taller stack also
	## drives a longer real shadow via _prop_heights (see _cache_blocked_cells).
	var max_stack := 1
	for structure_entry in layout.get("structure_tiles", []):
		max_stack = maxi(max_stack, int(structure_entry.get("stack", 1)))
	_clear_prop_stack_layers()
	_ensure_prop_stack_layers(maxi(0, max_stack - 1))
	for stack_layer in _prop_stack_layers:
		stack_layer.clear()
	for structure_entry in layout.get("structure_tiles", []):
		var cell: Vector2i = structure_entry.get("cell", INVALID_CELL)
		var tile_name := String(structure_entry.get("tile_name", ""))
		_place(cell, tile_name, structure_layer)
		var stack: int = maxi(1, int(structure_entry.get("stack", 1)))
		for level in range(1, stack):
			_place(cell, tile_name, _prop_stack_layers[level - 1])

	_cache_blocked_cells(layout)


func get_blocked_cells() -> Dictionary:
	return _blocked_cells


func get_prop_heights() -> Dictionary:
	return _prop_heights


func get_exit_cells() -> Array[Vector2i]:
	return _exit_cells


func get_light_sources() -> Array:
	return _current_light_sources


func build_registry(ts: TileSet) -> void:
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		var td := src.get_tile_data(Vector2i(0, 0), 0)
		if td:
			_tile_ids[td.get_custom_data("tile_name")] = sid
	print("[Room] %d tiles registered." % _tile_ids.size())


func build_navigation_blocked_cells(guards: Array) -> Array[Vector2i]:
	var nav: Array[Vector2i] = []
	for cell in _blocked_cells.keys():
		nav.append(cell)
	for guard in guards:
		if not is_instance_valid(guard):
			continue
		# NOTE: we need agent reference but it's in room
		# For now, skip agent check — guards don't block at agent.cell anyway in the logic
		nav.append(guard.cell)
	return nav




## Group consecutive collinear edges into runs (run = edges sharing material+facade, forming a continuous line)
## Each run is a Dictionary with keys: "edges", "material_id", "facade_id", "min_edge"
func _group_edges_into_runs(edges: Array) -> Array:
	if edges.is_empty():
		return []
	
	var runs: Array = []
	var visited: Dictionary = {}
	
	for start_edge in edges:
		if visited.has(start_edge.id):
			continue
		
		# Build a run starting from this edge
		var run_edges: Array = []
		var current_edge = start_edge
		
		# Walk backward to find the true start of the run
		while current_edge != null:
			if visited.has(current_edge.id):
				# Already part of another run, stop
				break
			
			# Check if there's an edge before current_edge in the run
			var prev_edge = _find_preceding_edge(current_edge, edges, visited)
			if prev_edge == null:
				# current_edge is the start of the run
				break
			
			current_edge = prev_edge
		
		# Now walk forward from current_edge to collect all edges in the run
		while current_edge != null and not visited.has(current_edge.id):
			# Validate continuity: material and facade must match
			if not _edges_share_material_and_facade(start_edge, current_edge):
				break
			
			run_edges.append(current_edge)
			visited[current_edge.id] = true
			
			# Find next edge in the run (collinear continuation)
			var next_edge = _find_next_edge_in_run(current_edge, edges, visited)
			current_edge = next_edge
		
		# Create run record
		if not run_edges.is_empty():
			var min_edge = _find_canonical_min_edge(run_edges)
			runs.append({
				"edges": run_edges,
				"material_id": run_edges[0].material,
				"facade_id": BakePolicyClass.facade_for_material(run_edges[0].material),
				"min_edge": min_edge,
			})
	
	return runs


## Find the preceding edge in a run (collinear edge that ends at the start of current_edge)
## OVERLORD-FIX-01: a run advances ALONG the wall surface, which is
## perpendicular to the face normal: SE faces border the +X neighbor so the
## surface (and the run) advances along +Y; SW faces advance along +X.
## The previous chaining compared candidate.gu_a against edge.gu_b — but gu_b
## is the cell ACROSS the wall (the normal direction), so almost no edge ever
## chained and every run degenerated to a single edge (position_in_run stuck
## at 0 → facade column never advanced past 7 on any wall).
func _run_advance_delta(edge: Edge) -> Vector2i:
	return Vector2i(0, 1) if edge.face_a == Face.SE else Vector2i(1, 0)


func _find_preceding_edge(edge: Edge, all_edges: Array, visited: Dictionary) -> Edge:
	var prev_gu: Vector2i = edge.gu_a - _run_advance_delta(edge)
	for candidate in all_edges:
		if visited.has(candidate.id):
			continue
		if candidate.gu_a == prev_gu and candidate.face_a == edge.face_a:
			if _edges_share_material_and_facade(edge, candidate):
				return candidate
	return null


## Find the next edge in a run (collinear continuation along the run axis)
func _find_next_edge_in_run(edge: Edge, all_edges: Array, visited: Dictionary) -> Edge:
	var next_gu: Vector2i = edge.gu_a + _run_advance_delta(edge)
	for candidate in all_edges:
		if visited.has(candidate.id):
			continue
		if candidate.gu_a == next_gu and candidate.face_a == edge.face_a:
			if _edges_share_material_and_facade(edge, candidate):
				return candidate
	return null


## Check if two edges share the same material and facade
func _edges_share_material_and_facade(edge_a: Edge, edge_b: Edge) -> bool:
	if edge_a.material != edge_b.material:
		return false
	
	var facade_a = BakePolicyClass.facade_for_material(edge_a.material)
	var facade_b = BakePolicyClass.facade_for_material(edge_b.material)
	
	return facade_a == facade_b


## Find the canonical minimum edge in a run (lexicographically smallest gu_a)
func _find_canonical_min_edge(run_edges: Array) -> Edge:
	var min_edge = run_edges[0]
	for edge in run_edges:
		if edge.gu_a.x < min_edge.gu_a.x or (edge.gu_a.x == min_edge.gu_a.x and edge.gu_a.y < min_edge.gu_a.y):
			min_edge = edge
	return min_edge


## BAKE-FIX-02: Apply junction overrides from map spec to junction columns
## Each override in layout["junction_overrides"] contains:
##   {"gu_cell": Vector2i, "material"?: String, "facade_enabled"?: bool}
static func _apply_junction_overrides(junction_columns: Array, layout: Dictionary) -> void:
	var overrides = layout.get("junction_overrides", [])
	if overrides.is_empty():
		return
	
	# Build lookup by gu_cell for O(1) lookup
	var override_map: Dictionary = {}
	for override in overrides:
		var gu_cell = Vector2i(override.get("gu_cell", Vector2i.ZERO))
		override_map[gu_cell] = override
	
	# Apply overrides to matching columns
	for column in junction_columns:
		if override_map.has(column.gu_cell):
			var override = override_map[column.gu_cell]
			if override.has("material"):
				column.override_material = String(override["material"])
			if override.has("facade_enabled"):
				column.facade_enabled = bool(override["facade_enabled"])


## Bake textures (S2: FIX-BAKE-05 integration + BAKE-FIX-02 run grouping & junction columns)
func _bake_textures(extraction: Dictionary, _edge_registry: EdgeRegistry, _junction_columns: Array = [],
		roof_specs: Array = [], damage_materials: Array = [], damage_floor_materials: Array = []) -> void:
	print("[ROOM] Baking textures with %d junction columns..." % _junction_columns.size())

	# Get current map ID for cache keying
	var current_map_id = room.map_id if room.has_meta("map_id") else "UNKNOWN"
	if room.has_method("get") and room.get("map_id"):
		current_map_id = room.map_id

	# Group edges into runs (consecutive collinear edges with same material+facade)
	var runs = _group_edges_into_runs(extraction.get("edges", []))
	print("[ROOM] Grouped edges into %d runs" % runs.size())
	
	# Build wall descriptors with run information
	var wall_descriptors: Array = []
	for run in runs:
		# All edges in a run share material + facade by construction
		var edge_list = run["edges"]
		var material_id = edge_list[0].material
		var facade_id = BakePolicyClass.facade_for_material(material_id)
		
		for edge in edge_list:
			wall_descriptors.append({
				"material_id": material_id,
				"facade_id": facade_id,
				"edge": edge,
				"run": run,  # Include run reference for strip walking
			})

	# OVERLORD-FIX-02: junction specs — each junction column's half-faces must
	# CONTINUE the adjacent legs' facade planes. Project the junction voxel
	# onto each leg's run axis (falls one past the run's end → mirrored-repeat
	# yields the last column mirrored, per Director spec).
	var edge_to_run: Dictionary = {}
	for run in runs:
		for e in run["edges"]:
			edge_to_run[e.id] = run
	var junction_specs: Array = []
	for jc in _junction_columns:
		if not jc.facade_enabled:
			continue
		var run_a = edge_to_run.get(jc.edge_a_id)
		var run_b = edge_to_run.get(jc.edge_b_id)
		if run_a == null or run_b == null:
			continue  # unresolvable leg → renderer falls back to mirror path
		var run_x = null  # X-axis leg (SW faces, dir 0)
		var run_y = null  # Y-axis leg (SE faces, dir 1)
		for r in [run_a, run_b]:
			if r["edges"][0].face_a == Face.SE:
				run_y = r
			else:
				run_x = r
		if run_x == null or run_y == null:
			continue  # parallel legs (not an elbow) → fallback path
		var jc_material: String = jc.override_material if jc.override_material != "" else jc.material
		junction_specs.append({
			"voxel_pos": jc.voxel_pos,
			"material_id": jc_material,
			"facade_id": BakePolicyClass.facade_for_material(jc_material),
			"col_x": jc.voxel_pos.x - run_x["edges"][0].gu_a.x * 8,
			"col_y": jc.voxel_pos.y - run_y["edges"][0].gu_a.y * 8,
			"level_start": jc.start_storey * GeometryCoords.LEVELS_PER_STOREY,
			"level_end": (jc.start_storey + jc.storey_count) * GeometryCoords.LEVELS_PER_STOREY,
		})

	## VL-PERF-BAKE: if the (material, facade) combos present, the map, and the
	## blend mode are all unchanged from the last bake, the pages and their
	## registered sources are byte-identical — this is a perspective rotation.
	## Reuse them and rebuild only the lookup (the runs rotated, but they map to
	## the same per-material atlas coords). Skips prune + bake + ~9k create_tile.
	var _cfg_for_key = load("res://godot/scripts/systems/bake_config.gd")
	var _blend_for_key = _cfg_for_key.blend_mode if _cfg_for_key else 0
	var _combo_set: Dictionary = {}
	for wd in wall_descriptors:
		_combo_set["%s|%s" % [wd["material_id"], wd["facade_id"]]] = true
	for rs in roof_specs:
		_combo_set["%s|%s" % [rs.get("material_id", ""), rs.get("facade_id", "")]] = true
	var _combo_keys: Array = _combo_set.keys()
	_combo_keys.sort()
	var bake_key := "%s|%d|%s" % [current_map_id, _blend_for_key, "_".join(_combo_keys)]

	if bake_key == _cached_bake_key and _cached_baked_atlas != null:
		print("[ROOM] Bake cache HIT (%s) — reusing sources, rebuilding lookup only" % bake_key)
		_wire_baked_lookup(runs, _cached_baked_atlas, _cached_source_ids)
		return

	## Full bake path (map/blend/combo changed, or first build). Drop the previous
	## pass's pages before this one adds its own — see prune_baked_sources().
	room._voxel_renderer.prune_baked_sources()

	# Create map spec for compositor
	var map_spec = {
		"walls": wall_descriptors,
		"room_geometry": extraction.get("room_geometry", {}),
		"junction_columns": _junction_columns,  # Pass junction columns for override resolution
		"junction_specs": junction_specs,  # OVERLORD-FIX-02: leg-continuation data
		"roofs": roof_specs,  # ROOF-BAKE-01: per-combo roof voxel cells (raw fine-grid)
		"map_id": current_map_id,  # BAKE-FACADE-PLANE-02-b: For cache keying
	}

	var _bt_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var _bt_diag_on: bool = _bt_bake_config != null and _bt_bake_config.debug_bake_set_dump
	if _bt_diag_on:
		var mats := {}
		for wd in wall_descriptors:
			mats[wd["material_id"]] = mats.get(wd["material_id"], 0) + 1
		print("[BAKE-DIAG] wall_descriptors=%d, material histogram=%s" % [wall_descriptors.size(), mats])
		# TOP-JUNCTION-06: junction column projections. src_x0/src_x1 are the
		# source-x the compositor crops each half-face from; both must land
		# inside the plane image [0, PLANE_W=1056) or blit_rect silently
		# clips and the half-face bakes blank.
		for js in junction_specs:
			var d_cx: int = int(js["col_x"])
			var d_cy: int = int(js["col_y"])
			var d_x0: int = d_cx * 16
			var d_x1: int = 1024 - d_cy * 16 + 16
			var d_ok: bool = d_x0 >= 0 and d_x0 + 16 <= 1056 and d_x1 >= 0 and d_x1 + 16 <= 1056
			print("[BAKE-DIAG] junction vp=%s mat=%s col_x=%d col_y=%d src_x0=%d src_x1=%d in_plane=%s" % [
				js["voxel_pos"], js["material_id"], d_cx, d_cy, d_x0, d_x1, d_ok
			])

	# Create texture resolver
	var resolver_class = preload("res://godot/scripts/systems/texture_resolver.gd")
	var resolver = resolver_class.new()

	# BAKE-FACADE-PLANE-02-b: Use persistent compositor across map reloads
	if _bake_compositor == null:
		var compositor_class = preload("res://godot/scripts/systems/bake_compositor.gd")
		_bake_compositor = compositor_class.new()
		_bake_compositor.set_material_registry(_get_material_registry())
		print("[BAKE] Created persistent BakeCompositor for session")

	# TOP-01-b / BAKE-CACHE-01: One-shot disk cache clear (moved from bake_config.gd)
	if _bt_bake_config != null and _bt_bake_config.debug_clear_bake_cache:
		_bake_compositor.clear_disk_cache()
		print("[BAKE] Disk cache cleared (debug_clear_bake_cache one-shot)")
		_bt_bake_config.debug_clear_bake_cache = false

	# BAKE-FACADE-PLANE-02-b: Clear cache when switching maps (compare with previous map ID)
	if _bake_compositor.has_meta("_last_map_id"):
		var last_map_id = _bake_compositor.get_meta("_last_map_id")
		if last_map_id != current_map_id:
			print("[BAKE] Map changed %s → %s, clearing cache" % [last_map_id, current_map_id])
			if _bake_compositor.has_method("clear_cache"):
				_bake_compositor.clear_cache()
	_bake_compositor.set_meta("_last_map_id", current_map_id)

	var start = Time.get_ticks_msec()
	var baked_atlas = _bake_compositor.bake(map_spec, resolver)
	var elapsed = Time.get_ticks_msec() - start

	print("[ROOM] Bake complete: %.0f ms, %d pages" % [elapsed, baked_atlas.atom_pages.size()])

	if _bt_diag_on:
		var sample_keys: Array = baked_atlas.lookup.keys()
		sample_keys = sample_keys.slice(0, mini(3, sample_keys.size()))
		print("[BAKE-DIAG] baked_atlas.lookup has %d keys. Sample: %s" % [baked_atlas.lookup.size(), sample_keys])

	# Register baked atlas pages with the voxel renderer's own TileSet.
	# BAKE-DIAG-01: pass the exact atlas_coords the compositor wrote to, so
	# register_baked_atlas_page() can create_tile() each one (otherwise the
	# source has zero valid tiles and every baked cell renders invisible).
	var coords_by_page: Dictionary = {}  # page_idx -> Array[Vector2i]
	for lookup_key in baked_atlas.lookup:
		var entry = baked_atlas.lookup[lookup_key]
		var p_idx = entry.get("page", -1)
		if p_idx < 0:
			continue
		if not coords_by_page.has(p_idx):
			coords_by_page[p_idx] = []
		coords_by_page[p_idx].append(entry.get("atlas_coords", Vector2i.ZERO))

	var source_ids = {}
	for page_idx in range(baked_atlas.atom_pages.size()):
		var page_coords: Array = coords_by_page.get(page_idx, [])
		# OVERLORD-FIX-01: per-page modulate realizes the blend mode on the
		# grayscale baked pages (TEXTURE_ONLY = white, MULTIPLY = base color)
		var page_modulate: Color = Color.WHITE
		if page_idx < baked_atlas.page_modulates.size():
			page_modulate = baked_atlas.page_modulates[page_idx]
		var source_id = room._voxel_renderer.register_baked_atlas_page(baked_atlas.atom_pages[page_idx], page_coords, page_modulate)
		source_ids[page_idx] = source_id
		print("[ROOM] Registered baked atlas page %d as source %d on voxel_renderer (%d tiles created)" % [page_idx, source_id, page_coords.size()])
		# OVERLORD-PROBE-01: dump pages to user:// for offline pixel verification
		if _bt_diag_on:
			var dump_path := "user://bake_debug_page_%d.png" % page_idx
			baked_atlas.atom_pages[page_idx].save_png(dump_path)
			print("[BAKE-DIAG] page %d saved to %s" % [page_idx, dump_path])

	# VL-PERF-BAKE: remember this bake so a subsequent rotation (same map/blend/
	# combos) can reuse the sources instead of re-registering them.
	_cached_bake_key = bake_key
	_cached_baked_atlas = baked_atlas
	_cached_source_ids = source_ids

	_wire_baked_lookup(runs, baked_atlas, source_ids)
	
	## Task 1b/E-BAKE (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): populate the
	## registry for real via DamageVariantBaker, reading the map's own
	## declared damage_materials. apply_damage_voxel_swap() falls back to D33
	## live compositing on any miss regardless (unreachable name, undeclared
	## material, disk/bake failure), so this is additive — never a new way to
	## fail damage rendering.
	_initialize_damage_variant_registry(damage_materials, damage_floor_materials)


## VL-PERF-BAKE: build the BakedTileLookup from runs + a baked atlas + source ids
## and hand it to the renderer. Shared by the full-bake path and the cached
## rotation fast-path (the runs differ per view, the atlas/sources do not).
func _wire_baked_lookup(runs: Array, baked_atlas, source_ids: Dictionary) -> void:
	var lookup_class = preload("res://godot/scripts/systems/baked_tile_lookup.gd")
	var lookup = lookup_class.new()
	lookup.register_runs(runs)
	# BAKE-LIVE-VERIFY-01-b Part 2: real baked data, not Engine.get_meta() nulls.
	lookup.set_baked_atlas(baked_atlas)
	lookup.set_source_ids(source_ids)
	# D34/E-SEAM-01: the SAME registry instance the bake side derived its
	# texture ids from — B1 requires both ends to agree on `has_facade`.
	lookup.set_material_registry(_get_material_registry())
	room._voxel_renderer.set_baked_lookup(lookup)


## Task 1b/E-BAKE: build a real VoxelVariantRegistry via DamageVariantBaker.
## `declared_materials`/`floor_materials` come from the map's own
## damage_materials section (D13) — see build_from_layout()'s own
## `damage_materials`/`damage_floor_materials` locals. An empty declared list
## (map has no section, or bake disabled) yields an empty-but-real registry,
## same fallback-safe shape the old stub always produced: every lookup misses
## and apply_damage_voxel_swap() falls back to D33 live compositing.
func _initialize_damage_variant_registry(declared_materials: Array, floor_materials: Array) -> void:
	var registry = VoxelVariantRegistryClass.new()
	if not declared_materials.is_empty() or not floor_materials.is_empty():
		var declared: Array[String] = []
		for m in declared_materials:
			declared.append(String(m))
		var floors: Array[String] = []
		for m in floor_materials:
			floors.append(String(m))
		var baker = DamageVariantBakerClass.new(
			room._voxel_renderer, registry, _get_material_registry(), _bake_compositor)
		baker.bake_all(declared, floors)
	room._voxel_renderer.set_damage_variant_registry(registry)
	print("[ROOM] Initialized damage variant registry (%d atoms)" % registry.size())


## VL-PERF-BAKE: force the next _bake_textures() to do a full rebake instead of
## reusing cached sources. Called on map (re)load — a reload may be a deliberate
## re-bake (e.g. changed facade files, F6), whereas a perspective rotation keeps
## the cache. Map-id changes invalidate on their own via the key; this also
## covers reloading the SAME map.
func invalidate_bake_cache() -> void:
	_cached_bake_key = ""
	_cached_baked_atlas = null
	_cached_source_ids = {}


func layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary:
	return PerspectiveMapperClass.layout_with_perspective(layout, direction)


## Private helpers

## Place a named tile at cell. LOUD-FAILS on an unknown name (bake invariant B6).
##
## This used to be a silent no-op: `if sid != -1: set_cell(...)`, with the docstring
## cheerfully calling it "silent no-op for unknown names". That is the same failure mode
## as Image.blit_rect silently clipping an out-of-range source rect — the bug that cost a
## week on the serrated junction columns. A tile that does not render, and says nothing
## about it, is the most expensive kind of bug this project has met.
##
## It went from latent to live on 2026-07-12: the sprite purge cut tile_registry from 32
## names to 8 (4 floors + 4 voxel atoms). Any map still asking for "crate_SE" or "wall_NW"
## would have drawn nothing, in silence. Now it says so.
func _place(cell: Vector2i, tile_name: String, layer: TileMapLayer = null) -> void:
	if layer == null:
		layer = floor_layer
	var sid: int = _tile_ids.get(tile_name, -1)
	if sid == -1:
		push_error("[RoomBuilder] Unknown tile '%s' at %s — not in tile_registry.gd. Scenery is voxels now; only floor_* and voxel_* are sprites. See docs/technical/ASSET_MAP.md." % [tile_name, cell])
		return
	layer.set_cell(cell, sid, Vector2i(0, 0))


func _clear_prop_stack_layers() -> void:
	for layer in _prop_stack_layers:
		if is_instance_valid(layer):
			room.remove_child(layer)
			layer.queue_free()
	_prop_stack_layers.clear()


func _ensure_prop_stack_layers(count: int) -> void:
	while _prop_stack_layers.size() < count:
		var level := _prop_stack_layers.size() + 1
		var layer := TileMapLayer.new()
		layer.tile_set = _wall_tileset
		layer.y_sort_origin = 1
		layer.position = Vector2(0.0, -WALL_FLOOR_STEP_PX * float(level))
		layer.z_index = WALL_BASE_Z_INDEX + level
		room.add_child(layer)
		_prop_stack_layers.append(layer)


## SLICE-02: A-T2 — Render solid blocks at their correct storeys
## Fixed from G3: reads actual EdgeExtractor shape (gu_cell, storey, material)
## and routes through voxel renderer for baking/theming/destructibility
func _render_solid_blocks(blocks: Array) -> void:
	if blocks.is_empty():
		return
	
	var groups: Dictionary = {}
	for block in blocks:
		var gu_cell: Vector2i = block.get("gu_cell", Vector2i.ZERO)
		var storey: int = int(block.get("storey", 0))
		var material_name: String = block.get("material", "concrete")
		var key := "%d,%d,%s" % [gu_cell.x, gu_cell.y, material_name]
		
		if key not in groups:
			groups[key] = {"gu_cell": gu_cell, "material_name": material_name, "storeys": []}
		groups[key]["storeys"].append(storey)
	
	for key in groups:
		var group = groups[key]
		var gu_cell: Vector2i = group["gu_cell"]
		var material_name: String = group["material_name"]
		var storeys: Array = group["storeys"]
		
		storeys.sort()
		var runs: Array = []
		var current_run: Array = []
		
		for i in range(storeys.size()):
			var storey: int = storeys[i]
			if i == 0:
				current_run.append(storey)
			else:
				var prev_storey: int = storeys[i - 1]
				if storey == prev_storey + 1:
					current_run.append(storey)
				else:
					runs.append(current_run.duplicate())
					current_run = [storey]
		
		if not current_run.is_empty():
			runs.append(current_run)
		
		for run in runs:
			var run_start: int = run[0]
			var run_span: int = run.size()
			room._voxel_renderer.render_block(gu_cell, run_start, run_span, material_name)


func _render_voxel_props(instances: Array) -> void:
	if instances.is_empty():
		return
	var registry = _get_prop_registry()
	if registry == null:
		push_warning("[RoomBuilder] Prop registry unavailable — props skipped")
		return
	for instance in instances:
		var prop_def = registry.get_prop(instance.get("def_id", ""))
		if prop_def == null:
			push_warning("[RoomBuilder] Unknown prop def '%s' — skipped" % instance.get("def_id", ""))
			continue
		room._voxel_renderer.render_prop(instance["gu_cell"], instance.get("storey", 0), prop_def)
		_prop_cover[instance["gu_cell"]] = prop_def.gameplay.get("cover", "none")


## Hard-disabled, and the reason it gives used to be false. AUDIT-01
## (2026-08-06): the old note read "TODO: Fix Registries reference", but
## `Registries` IS a registered autoload (project.godot) and
## `ensure_prop_registry()` exists (registries_autoload.gd) — the reference
## needs no fixing. Returning null keeps PROP-01's whole PropDef path
## unreachable: _render_voxel_props() warns and skips every instance.
##
## Nothing is missing on screen today because the shipped maps place crates
## through the LEGACY tile path in their .map.json, not through voxel_props;
## only the SIGMA_01 *code* spec (fallback-only) declares 9 of them.
##
## Re-enabling is the one line below, but it is a rendering change on a path
## no currently-running test covers (prop_01_tests.gd is outside the selftest
## runner's glob), so it is a Director call, not a cleanup.
func _get_prop_registry():
	# return Registries.ensure_prop_registry()
	return null


func _cache_blocked_cells(layout: Dictionary) -> void:
	_blocked_cells.clear()
	for cell in layout.get("blocked_cells", []):
		_blocked_cells[cell] = true
	_prop_heights.clear()
	for entry in layout.get("structure_tiles", []):
		if entry is Dictionary and entry.has("height"):
			_prop_heights[Vector2i(entry["cell"])] = int(entry["height"])
	_prop_cover.clear()
	_exit_cells.clear()
	for raw in layout.get("exit_cells", []):
		_exit_cells.append(Vector2i(raw))
	_current_light_sources = layout.get("light_sources", [])


const WALL_FLOOR_STEP_PX := 20.0
const WALL_BASE_Z_INDEX := 8
const INVALID_CELL := Vector2i(-1, -1)
