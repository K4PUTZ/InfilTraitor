## Geometry Module — Voxel Renderer: TileMapLayer-based voxel wall rendering
## Port from room.gd voxel functions, honoring Transform Canon
## Extends Node2D to add to scene tree
extends Node2D
class_name VoxelRenderer

var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")

## TileSet source ID for voxels
const VOXEL_SOURCE_ID: int = 0

## Materials to load (in order)
const MATERIALS: Array[String] = ["concrete", "metal", "stone", "wood"]

## Voxel asset path template
const VOXEL_ASSET_TEMPLATE: String = "res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_%s.png"

## Z-index base for wall layers (from room.gd context)
var _wall_base_z_index: int = 10

## Array of TileMapLayers [level_0, level_1, ...]
var _voxel_layers: Array[TileMapLayer] = []

## Runtime TileSet
var _tileset: TileSet

## Visual grid offset (isometric screen space)
var _visual_grid_offset: Vector2

## DEBUG-02: Accumulated nudge offset (pixels). Applied to all layers for real-time measurement.
var debug_nudge: Vector2 = Vector2.ZERO

## Cached baking components (Item 7: caching hot-path objects)
var _bake_config = null       # Script ref, loaded once
var _baked_lookup = null      # BakedTileLookup instance, created once


## Setup: builds tileset and prepares for rendering
func setup(visual_grid_offset: Vector2, wall_base_z_index: int = 10) -> void:
	_visual_grid_offset = visual_grid_offset
	_wall_base_z_index = wall_base_z_index
	_build_voxel_tileset()


## Set baked lookup (called by room_builder after baking completes)
## This is the key link between room_builder's populated lookup and live rendering
func set_baked_lookup(lookup) -> void:
	_baked_lookup = lookup
	print("[VOXEL] Baked lookup set: %s" % ("registered" if lookup != null else "null"))


## Getter for voxel layer at given level (for diagnostics)
func get_layer(level: int) -> TileMapLayer:
	if level < 0 or level >= _voxel_layers.size():
		return null
	return _voxel_layers[level]


## Getter for the runtime TileSet (for diagnostics/tests — e.g. reading TileData.flip_h)
func get_tileset() -> TileSet:
	return _tileset


## DEBUG-02: Apply real-time positional offset to all voxel layers.
## Accumulates nudges and shifts existing layers; new layers inherit the offset.
func apply_debug_nudge(delta: Vector2) -> void:
	debug_nudge += delta
	for layer in _voxel_layers:
		layer.position += delta


## Build runtime TileSet with 4 materials
## Honors Transform Canon: tile_size (32,16), DIAMOND_DOWN, texture_origin=(0,10)
func _build_voxel_tileset() -> void:
	_tileset = TileSet.new()
	_tileset.tile_size = GeometryCoords.VOXEL_TILE_SIZE
	_tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	_tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	
	# Add custom_data layer for tile name tracking
	_tileset.add_custom_data_layer(0)
	_tileset.set_custom_data_layer_name(0, "tile_name")
	_tileset.set_custom_data_layer_type(0, Variant.Type.TYPE_STRING)
	
	# Create TileSetAtlasSource for each material
	for mat_index in range(MATERIALS.size()):
		var material_name: String = MATERIALS[mat_index]
		var asset_path := VOXEL_ASSET_TEMPLATE % material_name
		
		var texture := load(asset_path)
		if not texture:
			push_error("VoxelRenderer: missing texture for material '%s' at %s" % [material_name, asset_path])
			continue
		
		var atlas_source := TileSetAtlasSource.new()
		atlas_source.texture = texture
		atlas_source.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
		atlas_source.separation = Vector2i.ZERO
		atlas_source.margins = Vector2i.ZERO
		
		# Add tile at (0, 0) in atlas
		atlas_source.create_tile(Vector2i.ZERO)
		
		# Add to tileset first (required before setting custom_data)
		_tileset.add_source(atlas_source, mat_index)
		
		# Now get tile_data and set properties
		var tile_data: TileData = atlas_source.get_tile_data(Vector2i.ZERO, 0)
		if tile_data != null:
			# Set texture_origin (Transform Canon 3: from SLICE-00 verification)
			tile_data.texture_origin = GeometryCoords.voxel_texture_origin()
			# Set custom_data: tile_name = material_name
			tile_data.set_custom_data("tile_name", material_name)


## Render all slices and junction columns from registry
## Creates cells in layers based on voxel positions and levels
func render(registry: EdgeRegistry, junction_columns: Array = []) -> void:
	# Iterate all slices and render their voxels
	for slice in registry.all_slices():
		# Try to get edge from registry (if available)
		var edge = registry.get_edge(slice.edge_id) if registry.has_method("get_edge") else null
		_render_slice(slice, edge)

	# Render junction columns
	for column in junction_columns:
		_render_junction_column(column, registry)


## Render a solid block (SLICE-02: A-T2)
## Fills all 64 voxel positions of a GU across [start_level, start_level + storey_span).
## start_level=0 reproduces the old ground-anchored behavior; start_level>0 supports
## floating geometry (ceiling props, chandeliers, hanging objects — any block that
## doesn't start at floor 0).
func render_block(gu_cell: Vector2i, start_level: int, storey_span: int, material_name: String) -> void:
	# FIX-VOXEL-HEIGHT-01: multiply storey_span by LEVELS_PER_STOREY to expand to level-space
	_ensure_voxel_layers(start_level * GeometryCoords.LEVELS_PER_STOREY + storey_span * GeometryCoords.LEVELS_PER_STOREY)
	
	# Get all voxel positions in this GU
	var voxel_positions: Array[Vector2i] = GeometryCoords.gu_voxels(gu_cell)
	
	# Render each voxel at each level in the span
	for level in range(start_level * GeometryCoords.LEVELS_PER_STOREY, (start_level + storey_span) * GeometryCoords.LEVELS_PER_STOREY):
		for voxel_pos in voxel_positions:
			_set_voxel_cell(voxel_pos, level, material_name)


## Render a single slice's voxels
func _render_slice(slice: Slice, edge = null) -> void:
	# Ensure we have enough layers
	# FIX-VOXEL-HEIGHT-01: multiply storey_count by LEVELS_PER_STOREY to expand to level-space
	_ensure_voxel_layers(slice.storey_count * GeometryCoords.LEVELS_PER_STOREY)

	# For each voxel in the slice, set_cell at the appropriate layer
	for voxel in slice.voxels:
		if voxel.visible:
			# Derive local voxel position within 8×8 quad from grid position
			var voxel_xy = Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
			_set_voxel_cell(voxel.grid_pos, voxel.level, slice.material, edge, voxel_xy, slice.face)


## Render a junction column (BAKE-FIX-02: mirror-at-the-column implementation)
## By default: mirrors the neighboring wall voxel's atom (D-BAKE-2)
## If override_material is set and facade_enabled=false: renders flat material-only (D-BAKE-3)
## If override_material is set and facade_enabled=true: mirrors the override material's boundary atom (D-BAKE-3)
func _render_junction_column(column: JunctionResolver.JunctionColumn, registry: EdgeRegistry = null) -> void:
	# FIX-VOXEL-HEIGHT-01: multiply storey counts by LEVELS_PER_STOREY to expand to level-space
	_ensure_voxel_layers(column.start_storey * GeometryCoords.LEVELS_PER_STOREY + column.storey_count * GeometryCoords.LEVELS_PER_STOREY)

	# Determine actual material to use (override if set, otherwise derived)
	var actual_material = column.override_material if column.override_material != "" else column.material
	
	for level_offset in range(column.storey_count * GeometryCoords.LEVELS_PER_STOREY):
		var level: int = column.start_storey * GeometryCoords.LEVELS_PER_STOREY + level_offset
		
		# Case 1: No facade (render flat material-only)
		if not column.facade_enabled:
			_set_voxel_cell(column.voxel_pos, level, actual_material)
		# Case 2: With facade (mirror neighbor's atom with H-flip)
		else:
			# BAKE-FIX-06: Find neighboring wall voxel and mirror its atom
			var neighbor_info = _find_neighbor_wall_voxel(column, registry)
			
			if neighbor_info:
				var neighbor_edge: Edge = neighbor_info["edge"]
				var neighbor_voxel: Voxel = neighbor_info["voxel"]
				
				# Resolve the neighbor voxel's baked atom (if baking enabled)
				var source_id: int = -1
				var atlas_coords: Vector2i = Vector2i.ZERO
				var alternative_id: int = 0
				
				if _bake_config == null:
					_bake_config = load("res://godot/scripts/systems/bake_config.gd")
				if _baked_lookup == null:
					_baked_lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()
				
				if _bake_config and _bake_config.enabled and neighbor_edge:
					# Get the voxel's local position within its slice
					var voxel_xy = Vector2i(neighbor_voxel.grid_pos.x % 8, neighbor_voxel.grid_pos.y % 8)
					var slice = registry.get_slice(neighbor_edge.slice_a_id) if registry.get_slice(neighbor_edge.slice_a_id) and neighbor_voxel in registry.get_slice(neighbor_edge.slice_a_id).voxels else registry.get_slice(neighbor_edge.slice_b_id)
					
					if slice:
						var result = _baked_lookup.resolve(neighbor_edge, slice.face, voxel_xy)
						if result and result.source_id_int >= 0:
							source_id = result.source_id_int
							atlas_coords = result.atlas_coords
							# TEST (no-flip hypothesis): also skip flip here — alternative_id stays 0
				
				# TEST (no-flip hypothesis): fallback / no baked atom to mirror — use the
				# canonical, unflipped tile (alternative_id stays 0). Flipping a generic
				# material tile that isn't an actual mirrored neighbor atom serves no
				# purpose and, per pixel-symmetry probe, visibly shifts the silhouette
				# because the source art (voxel_<material>.png) isn't mirror-symmetric.
				if source_id < 0:
					source_id = MATERIALS.find(actual_material)
					if source_id == -1:
						source_id = 0
					atlas_coords = Vector2i.ZERO
				
				# Set the cell with H-flipped alternative
				var layer: TileMapLayer = _voxel_layers[level]
				layer.set_cell(column.voxel_pos, source_id, atlas_coords, alternative_id)
			else:
				# No neighbor found: render flat material-only
				_set_voxel_cell(column.voxel_pos, level, actual_material)


## Set a voxel cell on the appropriate layer
## SEAM: Tries baked lookup first (if enabled and edge provided), falls back to material-only
func _set_voxel_cell(grid_pos: Vector2i, level: int, material_name: String,
                     edge = null, voxel_xy: Vector2i = Vector2i.ZERO,
                     slice_face: int = 0) -> void:
	if level < 0 or level >= _voxel_layers.size():
		push_warning("VoxelRenderer._set_voxel_cell: level %d out of range [0, %d)" % [level, _voxel_layers.size()])
		return

	var layer: TileMapLayer = _voxel_layers[level]
	var source_id: int = -1
	var atlas_coords: Vector2i = Vector2i.ZERO
	var alternative_id: int = 0

	# SEAM: Try baked lookup first (using cached instances)
	if _bake_config == null:
		_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	if _baked_lookup == null:
		_baked_lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()

	if _bake_config and _bake_config.enabled and edge != null:
		var result = _baked_lookup.resolve(edge, slice_face, voxel_xy)

		if result and result.source_id_int >= 0:
			source_id = result.source_id_int
			atlas_coords = result.atlas_coords
			alternative_id = result.alternative_id

	# Fallback: material-only path
	if source_id < 0:
		source_id = MATERIALS.find(material_name)
		if source_id == -1:
			source_id = 0  # Fallback to concrete
		atlas_coords = Vector2i.ZERO

	layer.set_cell(grid_pos, source_id, atlas_coords, alternative_id)




## BAKE-FIX-06: Find the neighbor wall voxel adjacent to a junction column
## Given the junction column and edge registry, finds the voxel belonging to one of
## the forming edges that is adjacent (not diagonal) to the column voxel.
## Returns: {"edge": Edge, "voxel": Voxel} or {} (empty dict) if not found
func _find_neighbor_wall_voxel(column: JunctionResolver.JunctionColumn, registry: EdgeRegistry) -> Dictionary:
	if not registry:
		return {}
	
	# Reconstruct the elbow GU from the diagonal cell (used for validation)
	var _elbow_gu = column.gu_cell - Face.delta(column.face_a) - Face.delta(column.face_b)
	
	# Get edges that created this junction
	var edge_a = registry.get_edge(column.edge_a_id) if column.edge_a_id else null
	var edge_b = registry.get_edge(column.edge_b_id) if column.edge_b_id else null
	
	if not edge_a or not edge_b:
		return {}
	
	# Get slices for both edges
	var slices_a = registry.slices_of_edge(edge_a.id)
	var slices_b = registry.slices_of_edge(edge_b.id)
	
	# Look for a voxel in slice_a or slice_b that is adjacent (not diagonal) to column.voxel_pos
	var candidate_slices = []
	candidate_slices.append_array(slices_a)
	candidate_slices.append_array(slices_b)
	
	var closest_voxel: Voxel = null
	var closest_edge: Edge = null
	var closest_distance: float = 999999.0
	
	for slice in candidate_slices:
		if slice and slice.voxels.size() > 0:
			for voxel in slice.voxels:
				if not voxel.visible:
					continue
				
				# Check if voxel is adjacent (not diagonal) to column.voxel_pos
				var dx = abs(voxel.grid_pos.x - column.voxel_pos.x)
				var dy = abs(voxel.grid_pos.y - column.voxel_pos.y)
				
				# Adjacent means exactly one of dx, dy is 1, the other is 0 (4-neighbor connectivity)
				if (dx == 1 and dy == 0) or (dx == 0 and dy == 1):
					var distance = sqrt(dx * dx + dy * dy)
					if distance < closest_distance:
						closest_distance = distance
						closest_voxel = voxel
						closest_edge = edge_a if slice in slices_a else edge_b
	
	if closest_voxel and closest_edge:
		return {"edge": closest_edge, "voxel": closest_voxel}
	
	return {}


## Process dirty slices only (TIC optimization)
func process_dirty(registry: EdgeRegistry) -> void:
	var dirty_slices := registry.dirty_slices()

	if dirty_slices.is_empty():
		return

	# Update cells for dirty voxels
	for slice in dirty_slices:
		# Try to get edge from registry
		var edge = registry.get_edge(slice.edge_id) if registry.has_method("get_edge") else null

		for voxel in slice.voxels:
			if voxel.dirty:
				# Update cell state based on voxel visibility
				if voxel.visible:
					var voxel_xy = Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
					_set_voxel_cell(voxel.grid_pos, voxel.level, slice.material, edge, voxel_xy, slice.face)
				else:
					# Clear cell
					if voxel.level < _voxel_layers.size():
						_voxel_layers[voxel.level].erase_cell(voxel.grid_pos)

		# Clear all dirty flags in slice
		slice.clear_all_dirty()


## Ensure layers exist up to storey count (E1 equation from SLICE-00)
func _ensure_voxel_layers(storey_count: int) -> void:
	while _voxel_layers.size() < storey_count:
		var level := _voxel_layers.size()
		var layer := TileMapLayer.new()
		layer.tile_set = _tileset
		layer.name = "voxel_layer_%d" % level
		
		# E1 equation from Transform Canon (SLICE-00)
		# Compensation between floor grid (256×128 tiles) and voxel grid (32×16 tiles):
		# TILE_OFFSET = (floor_half_w − voxel_half_w, floor_half_h) = (128−16, 64) = (112, 64).
		# NOTE: the pre-2026-07-02 value (112, 56) subtracted voxel_half_h on Y as well —
		# an 8px error, empirically measured and corrected via DEBUG-02 ruler + nudge session
		# (residual now zero). Do not "restore symmetry" to (112, 56); the asymmetry is correct.
		const TILE_OFFSET: Vector2 = Vector2(112.0, 64.0)
		layer.position = Vector2(
			_visual_grid_offset.x + TILE_OFFSET.x + debug_nudge.x,
			_visual_grid_offset.y + TILE_OFFSET.y + debug_nudge.y - GeometryCoords.VOXEL_STEP_PX * float(level)
		)
		
		# Set rendering parameters
		layer.y_sort_origin = 1
		layer.z_index = _wall_base_z_index + level
		layer.visible = true
		
		# Add to scene tree
		add_child(layer)
		_voxel_layers.append(layer)


## Render a VoxelProp's footprint as a full solid fill (v1: whole-storey granularity only;
## sub-storey/partial-layer rendering is deferred to the destruction phase — see PROP-01 Item 0-A).
func render_prop(gu_cell: Vector2i, start_storey: int, prop_def) -> void:
	var material_name: String = prop_def.material_zones.get("default", "concrete")
	for footprint_offset in prop_def.footprint_gus:
		render_block(gu_cell + footprint_offset, start_storey, prop_def.storeys, material_name)


## Clear all layers and voxels
func clear() -> void:
	for layer in _voxel_layers:
		layer.clear()


func _to_string() -> String:
	return "VoxelRenderer{layers=%d, tileset=%s}" % [_voxel_layers.size(), "valid" if _tileset else "null"]
