## RoomBuilder
## Orchestrates room construction, tile placement, and perspective transformations.
## Handles loading maps, building layouts, caching blocked cells, and coordinate rotations.

class_name RoomBuilder

var room: Node
var PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
var MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")
var PropRegistryClass = preload("res://godot/scripts/systems/prop_registry.gd")

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
var structure_layer: TileMapLayer = null


func _init(p_room: Node) -> void:
	room = p_room


func setup(structure: TileMapLayer, wall_tileset: TileSet) -> void:
	structure_layer = structure
	_wall_tileset = wall_tileset


func build_from_layout(layout: Dictionary, room_size: Vector2i) -> void:
	MemStage.mark("11 room build starts")
	_room_size = room_size
	## R3D-11: nothing reads the floor layer any more (gameplay asks `GroundGrid.has_cell`), so nothing writes it either.
	structure_layer.clear()

	## Voxel render plane: wall/block descriptors become stacked voxel presence.
	## The old wall-storey layers remain as a fallback path, but the active render
	## now comes from the edge seam's voxel geometry integration.
	
	## SLICE-02: New geometry module integration — edges → slices → voxels
	var extraction: Dictionary = EdgeExtractor.extract(layout)

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
			floor_slabs_by_gu[floor_gu] = floor_slab

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
		## GLASS G2 — stamp `pane_id` on every glass slice so a single hit can take
		## the whole surface (G3). Once, here, never per shot.
		GlassPaneGrouper.assign(edge_registry, layout.get("solid_block_instances", []))
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
		## Everything that carries a roof: the blocks' own, plus the free-standing roofs of the map's `roofs`
		## section (R3D-7). Both are {gu_cell, size, storeys, material}; only `kind` "flat" exists so far.
		var roof_sources: Array = []
		for source: Dictionary in layout.get("solid_block_instances", []):
			roof_sources.append(source)
		for source: Dictionary in layout.get("roof_instances", []):
			if String(source.get("kind", "flat")) != "flat":
				push_error("[RoomBuilder] roof kind '%s' at %s is not implemented (only \"flat\"); skipped" % [source.get("kind"), source.get("gu_cell")])
				continue
			roof_sources.append(source)
		var roof_level_by_gu: Dictionary = {}
		for block_instance: Dictionary in roof_sources:
			var occ_gu_base: Vector2i = block_instance.get("gu_cell", Vector2i.ZERO)
			var occ_size: Vector2i = block_instance.get("size", Vector2i.ONE)
			var occ_level: int = GeometryCoords.storey_level_base(maxi(1, int(block_instance.get("storeys", 1))))
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
		for block_instance: Dictionary in roof_sources:
			var block_gu_base: Vector2i = block_instance.get("gu_cell", Vector2i.ZERO)
			var block_size: Vector2i = block_instance.get("size", Vector2i.ONE)
			var block_storeys: int = int(block_instance.get("storeys", 1))
			var block_material: String = String(block_instance.get("material", "concrete"))
			## ⚠️ Takes the offset TOGETHER with `occ_level` above: the two are
			## compared against each other in the border tests below, and this one
			## is additionally a real render level. Shifting one without the other
			## would leave the comparisons intact and the placement wrong, or the
			## reverse — which is exactly the half-right this helper exists to stop.
			var roof_base_level: int = GeometryCoords.storey_level_base(block_storeys)

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

		room._edge_registry = edge_registry
		room._junction_columns = junction_columns

		## room._slab_registry and room._voxel_renderer.clear() moved to run
		## unconditionally above (before this if-block), so the floor exists even
		## for edge-less rooms. Do not re-add either here — re-instantiating the
		## registry would drop the floor Slabs just registered, and re-clear()ing
		## would erase the floor cells just placed.
		room._voxel_renderer.render(edge_registry, junction_columns)

		_render_solid_blocks(extraction.get("solid_blocks", []))
		_render_voxel_props(layout.get("voxel_prop_instances", []))

		## DESTRUCTION D1-ROOF rendering. The roof Slabs are generated above (see the D1-ROOF/border
		## rationale there); this loop only renders what was generated.
		for roof_slab in roof_slabs:
			room._voxel_renderer.render_slab_solid(roof_slab)

	## Floor rendering, deferred to here: generation happened earlier, before the edges-conditional.
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
func _place(cell: Vector2i, tile_name: String, layer: TileMapLayer) -> void:
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
