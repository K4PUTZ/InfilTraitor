## RoomBuilder
## Orchestrates room construction, tile placement, and perspective transformations.
## Handles loading maps, building layouts, caching blocked cells, and coordinate rotations.

class_name RoomBuilder

var room: Node
var PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
var BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")
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

	if not extraction.get("edges", []).is_empty():
		## New geometry path — the only active renderer when it has data.
		var _edge_registry = EdgeRegistry.new()
		SliceGenerator.generate(extraction["edges"], _edge_registry)
		var _junction_columns = JunctionResolver.resolve(_edge_registry)

		## Bake textures (S2: Wire baking into room_builder)
		var bake_config = load("res://godot/scripts/systems/bake_config.gd")
		if bake_config and bake_config.enabled:
			_bake_textures(extraction, _edge_registry)

		room._voxel_renderer.clear()
		room._voxel_renderer.render(_edge_registry, _junction_columns)
		_render_solid_blocks(extraction.get("solid_blocks", []))
		_render_voxel_props(layout.get("voxel_prop_instances", []))
		structure_wall_layer.visible = false
		for layer in _wall_upper_layers:
			layer.visible = false

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
	## Per-prop shadow heights (rotated cell → height class 1-4) from structure_tiles.
	## Consumed by LightingController._setup_tile_semantics so stacked props cast taller
	## (longer) shadows. Built here so it follows perspective rotation with the layout.
	_prop_heights.clear()
	for entry in layout.get("structure_tiles", []):
		if entry is Dictionary and entry.has("height"):
			_prop_heights[Vector2i(entry["cell"])] = int(entry["height"])
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


## Bake textures (S2: FIX-BAKE-05 integration)
func _bake_textures(extraction: Dictionary, _edge_registry: EdgeRegistry) -> void:
	print("[ROOM] Baking textures...")

	# Build wall descriptors: the compositor consumes Dictionaries, by contract.
	var wall_descriptors: Array = []
	for edge in extraction.get("edges", []):
		wall_descriptors.append({
			"material_id": edge.material,
			"facade_id": BakePolicyClass.facade_for_material(edge.material),
			"edge": edge,
		})

	# Create map spec for compositor
	var map_spec = {
		"walls": wall_descriptors,
		"room_geometry": extraction.get("room_geometry", {}),
	}

	# Create texture resolver
	var resolver_class = preload("res://godot/scripts/systems/texture_resolver.gd")
	var resolver = resolver_class.new()

	# Bake
	var compositor_class = preload("res://godot/scripts/systems/bake_compositor.gd")
	var compositor = compositor_class.new()

	var start = Time.get_ticks_msec()
	var baked_atlas = compositor.bake(map_spec, resolver)
	var elapsed = Time.get_ticks_msec() - start

	print("[ROOM] Bake complete: %.0f ms, %d pages" % [elapsed, baked_atlas.pages.size()])

	# Register baked atlas pages with the tileset
	var source_ids = {}
	for page_idx in range(baked_atlas.pages.size()):
		var source_id = _register_baked_atlas_page(baked_atlas.pages[page_idx], page_idx)
		source_ids[page_idx] = source_id
		print("[ROOM] Registered baked atlas page %d as source %d" % [page_idx, source_id])

	# Store lookup and source mapping for placement
	Engine.set_meta("GLOBAL_BAKED_ATLAS", baked_atlas)
	Engine.set_meta("BAKED_ATLAS_SOURCE_IDS", source_ids)
	Engine.set_meta("BAKE_TIMESTAMP", Time.get_ticks_msec())




## Register a baked atlas page as a tileset source
func _register_baked_atlas_page(page_image: Image, page_idx: int) -> int:
	# Create TileSetAtlasSource from the page image
	var source = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(page_image)
	source.texture_region_size = Vector2i(32, 16)

	# Register on the wall tileset
	var tileset = _wall_tileset
	if tileset == null:
		push_error("[ROOM] Wall tileset not set; cannot register baked atlas page %d" % page_idx)
		return -1

	var source_id = tileset.get_next_source_id()
	tileset.add_source(source, source_id)

	return source_id


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
	for instance in instances:
		var prop_def = registry.get_prop(instance.get("def_id", ""))
		if prop_def == null:
			push_warning("[RoomBuilder] Unknown prop def '%s' — skipped" % instance.get("def_id", ""))
			continue
		room._voxel_renderer.render_prop(instance["gu_cell"], instance.get("storey", 0), prop_def)
		_prop_cover[instance["gu_cell"]] = prop_def.gameplay.get("cover", "none")


func _get_prop_registry():
	var reg = Engine.get_meta("GLOBAL_PROP_REGISTRY", null)
	if reg == null:
		reg = PropRegistryClass.new()
		reg.load_from_disk()
		Engine.set_meta("GLOBAL_PROP_REGISTRY", reg)
	return reg


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
