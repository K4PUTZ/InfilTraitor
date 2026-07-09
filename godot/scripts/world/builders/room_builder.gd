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
var _room_size: Vector2i = Vector2i.ZERO
var _wall_tileset: TileSet = null
var _wall_upper_layers: Array[TileMapLayer] = []
var _prop_stack_layers: Array[TileMapLayer] = []
var _blocked_cells: Dictionary = {}
var _prop_heights: Dictionary = {}
var _prop_cover: Dictionary = {}
var _exit_cells: Array[Vector2i] = []
var _current_light_sources: Array = []
var _tile_ids: Dictionary = {}
var _base_layout: Dictionary = {}

# References to room layers
var floor_layer: TileMapLayer = null
var structure_layer: TileMapLayer = null
var structure_wall_layer: TileMapLayer = null


func _init(p_room: Node) -> void:
	room = p_room


func setup(floor_ref: TileMapLayer, structure: TileMapLayer, wall_layer: TileMapLayer, wall_tileset: TileSet) -> void:
	floor_layer = floor_ref
	structure_layer = structure
	structure_wall_layer = wall_layer
	_wall_tileset = wall_tileset


func build_from_layout(layout: Dictionary, room_size: Vector2i) -> void:
	_room_size = room_size
	floor_layer.clear()
	structure_wall_layer.clear()
	structure_layer.clear()
	for layer in _wall_upper_layers:
		layer.clear()
		layer.visible = true

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

	if not extraction.get("edges", []).is_empty():
		## New geometry path — the only active renderer when it has data.
		var _edge_registry = EdgeRegistry.new()
		SliceGenerator.generate(extraction["edges"], _edge_registry)
		var _junction_columns = JunctionResolver.resolve(_edge_registry)
		
		# BAKE-FIX-02: Apply junction overrides from layout (if available)
		_apply_junction_overrides(_junction_columns, layout)

		## Bake textures (S2: Wire baking into room_builder)
		var bake_config = load("res://godot/scripts/systems/bake_config.gd")
		if bake_config and bake_config.enabled:
			_bake_textures(extraction, _edge_registry, _junction_columns)

		if _diag_on:
			print("[BAKE-DIAG] Pre-render: voxel_renderer._baked_lookup=%s, slices=%d, junction_columns=%d" % [
				("set" if room._voxel_renderer._baked_lookup != null else "NULL"),
				_edge_registry.all_slices().size(), _junction_columns.size()
			])

		room._voxel_renderer.clear()
		room._voxel_renderer.render(_edge_registry, _junction_columns)

		if _diag_on and room._voxel_renderer.has_method("print_render_diagnostics"):
			room._voxel_renderer.print_render_diagnostics()

		_render_solid_blocks(extraction.get("solid_blocks", []))
		_render_voxel_props(layout.get("voxel_prop_instances", []))
		structure_wall_layer.visible = false
		for layer in _wall_upper_layers:
			layer.visible = false
	elif _diag_on:
		print("[BAKE-DIAG] build_from_layout: extraction.edges EMPTY — geometry path skipped entirely, no voxel walls will render this call")

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


func cache_blocked_cells(layout: Dictionary) -> void:
	_blocked_cells.clear()
	for cell in layout.get("blocked_cells", []):
		_blocked_cells[cell] = true
	## Per-prop shadow heights (rotated cell → height class 1-4) from structure_tiles and voxel_props.
	## Consumed by LightingController._setup_tile_semantics so stacked props cast taller
	## (longer) shadows. Built here so it follows perspective rotation with the layout.
	_prop_heights.clear()
	for entry in layout.get("structure_tiles", []):
		if entry is Dictionary and entry.has("height"):
			_prop_heights[Vector2i(entry["cell"])] = int(entry["height"])
	# Also populate from voxel_prop_instances using prop definitions' storeys
	var prop_registry = _get_prop_registry()
	if prop_registry:
		for instance in layout.get("voxel_prop_instances", []):
			if instance is Dictionary:
				var def_id: String = instance.get("def_id", "")
				var gu_cell: Vector2i = instance.get("gu_cell", Vector2i.ZERO)
				var prop_def = prop_registry.get_prop(def_id)
				if prop_def:
					# Derive shadow height using the same convention as legacy stacked props:
					# height = clamp(storeys + 1, 1, 4). This ensures voxel props cast
					# shadows consistent with their visual presence (1-storey = height class 2).
					var height: int = clampi(int(prop_def.storeys) + 1, 1, 4)
					_prop_heights[gu_cell] = height
	## Segment exits — used by the purple overlay in _draw()
	_exit_cells.clear()
	for raw in layout.get("exit_cells", []):
		_exit_cells.append(Vector2i(raw))
	## Active (perspective-rotated) map lights — consumed by LightingController.
	_current_light_sources = layout.get("light_sources", [])
	print("[Room] Cache: %d blocked_cells, %d exit_cells, %d lights" % [
		_blocked_cells.size(), _exit_cells.size(), _current_light_sources.size()])
	print("[Room] Border check: (0,0)=%s (17,0)=%s (0,35)=%s (17,35)=%s (9,0)=%s (9,35)=%s" % [
		_blocked_cells.has(Vector2i(0,0)), _blocked_cells.has(Vector2i(17,0)),
		_blocked_cells.has(Vector2i(0,35)), _blocked_cells.has(Vector2i(17,35)),
		_blocked_cells.has(Vector2i(9,0)), _blocked_cells.has(Vector2i(9,35))
	])


func get_blocked_cells() -> Dictionary:
	return _blocked_cells


func get_prop_heights() -> Dictionary:
	return _prop_heights


func get_prop_cover() -> Dictionary:
	return _prop_cover


func get_exit_cells() -> Array[Vector2i]:
	return _exit_cells


func get_light_sources() -> Array:
	return _current_light_sources


func get_base_layout() -> Dictionary:
	return _base_layout


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
func _find_preceding_edge(edge: Edge, all_edges: Array, visited: Dictionary) -> Edge:
	for candidate in all_edges:
		if visited.has(candidate.id):
			continue
		
		# Check if candidate.gu_b == edge.gu_a and they point in the same direction
		if candidate.gu_b == edge.gu_a and candidate.face_a == edge.face_a:
			if _edges_share_material_and_facade(edge, candidate):
				return candidate
	
	return null


## Find the next edge in a run (collinear edge that starts where current_edge ends)
func _find_next_edge_in_run(edge: Edge, all_edges: Array, visited: Dictionary) -> Edge:
	for candidate in all_edges:
		if visited.has(candidate.id):
			continue
		
		# Check if candidate.gu_a == edge.gu_b and they point in the same direction
		if candidate.gu_a == edge.gu_b and candidate.face_a == edge.face_a:
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
func _bake_textures(extraction: Dictionary, _edge_registry: EdgeRegistry, _junction_columns: Array = []) -> void:
	print("[ROOM] Baking textures with %d junction columns..." % _junction_columns.size())

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

	# Create map spec for compositor
	var map_spec = {
		"walls": wall_descriptors,
		"room_geometry": extraction.get("room_geometry", {}),
		"junction_columns": _junction_columns,  # Pass junction columns for override resolution
	}

	var _bt_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var _bt_diag_on: bool = _bt_bake_config != null and _bt_bake_config.debug_bake_set_dump
	if _bt_diag_on:
		var mats := {}
		for wd in wall_descriptors:
			mats[wd["material_id"]] = mats.get(wd["material_id"], 0) + 1
		print("[BAKE-DIAG] wall_descriptors=%d, material histogram=%s" % [wall_descriptors.size(), mats])

	# Create texture resolver
	var resolver_class = preload("res://godot/scripts/systems/texture_resolver.gd")
	var resolver = resolver_class.new()

	# Bake
	var compositor_class = preload("res://godot/scripts/systems/bake_compositor.gd")
	var compositor = compositor_class.new()
	# Inject material registry - use default material registry
	# TODO: Fix Registries reference (FIX-SHUTDOWN-CRASH-01)
	# var material_registry = Registries.ensure_material_registry()
	var material_registry = preload("res://godot/scripts/systems/material_registry.gd").new()
	material_registry.register_defaults()
	compositor.set_material_registry(material_registry)

	var start = Time.get_ticks_msec()
	var baked_atlas = compositor.bake(map_spec, resolver)
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
		var source_id = room._voxel_renderer.register_baked_atlas_page(baked_atlas.atom_pages[page_idx], page_coords)
		source_ids[page_idx] = source_id
		print("[ROOM] Registered baked atlas page %d as source %d on voxel_renderer (%d tiles created)" % [page_idx, source_id, page_coords.size()])

	# BAKE-FIX-02: Register runs and populate lookup with baked atlas data
	var lookup_class = preload("res://godot/scripts/systems/baked_tile_lookup.gd")
	var lookup = lookup_class.new()
	lookup.register_runs(runs)
	
	# BAKE-LIVE-VERIFY-01-b Part 2: Populate lookup with baked atlas and source IDs
	# This is critical: lookup.resolve() will now find real data instead of hitting Engine.get_meta() nulls
	lookup.set_baked_atlas(baked_atlas)
	lookup.set_source_ids(source_ids)
	
	# Pass the fully-populated lookup to voxel_renderer
	room._voxel_renderer.set_baked_lookup(lookup)



func layout_with_perspective(layout: Dictionary, direction: String) -> Dictionary:
	return PerspectiveMapperClass.layout_with_perspective(layout, direction)


## Private helpers

func _place(cell: Vector2i, tile_name: String, layer: TileMapLayer = null) -> void:
	if layer == null:
		layer = floor_layer
	var sid: int = _tile_ids.get(tile_name, -1)
	if sid != -1:
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


func _get_prop_registry():
	# TODO: Fix Registries reference
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
