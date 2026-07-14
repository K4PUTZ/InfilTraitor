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

# BAKE-FACADE-PLANE-02-b: Persistent bake compositor across map reloads
var _bake_compositor: Object = null

var _room_size: Vector2i = Vector2i.ZERO
var _wall_tileset: TileSet = null
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

		## Bake textures (S2: Wire baking into room_builder)
		var bake_config = load("res://godot/scripts/systems/bake_config.gd")
		if bake_config and bake_config.enabled:
			_bake_textures(extraction, edge_registry, junction_columns)

		if _diag_on:
			print("[BAKE-DIAG] Pre-render: voxel_renderer._baked_lookup=%s, slices=%d, junction_columns=%d" % [
				("set" if room._voxel_renderer._baked_lookup != null else "NULL"),
				edge_registry.all_slices().size(), junction_columns.size()
			])

		room._edge_registry = edge_registry
		room._junction_columns = junction_columns

		room._voxel_renderer.clear()
		room._voxel_renderer.render(edge_registry, junction_columns)

		if _diag_on and room._voxel_renderer.has_method("print_render_diagnostics"):
			room._voxel_renderer.print_render_diagnostics()

		_render_solid_blocks(extraction.get("solid_blocks", []))
		_render_voxel_props(layout.get("voxel_prop_instances", []))
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
func _bake_textures(extraction: Dictionary, _edge_registry: EdgeRegistry, _junction_columns: Array = []) -> void:
	print("[ROOM] Baking textures with %d junction columns..." % _junction_columns.size())

	## Every view rotation re-bakes and re-registers baked atlas pages from scratch.
	## Drop the previous pass's pages before this one adds its own — see
	## VoxelRenderer.prune_baked_sources() for why this can't live in clear() instead.
	room._voxel_renderer.prune_baked_sources()

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

	# Create map spec for compositor
	var map_spec = {
		"walls": wall_descriptors,
		"room_geometry": extraction.get("room_geometry", {}),
		"junction_columns": _junction_columns,  # Pass junction columns for override resolution
		"junction_specs": junction_specs,  # OVERLORD-FIX-02: leg-continuation data
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
		# Inject material registry
		var material_registry = preload("res://godot/scripts/systems/material_registry.gd").new()
		material_registry.register_defaults()
		_bake_compositor.set_material_registry(material_registry)
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
