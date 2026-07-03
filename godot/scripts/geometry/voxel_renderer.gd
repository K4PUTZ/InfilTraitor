## Geometry Module — Voxel Renderer: TileMapLayer-based voxel wall rendering
## Port from room.gd voxel functions, honoring Transform Canon
## Extends Node2D to add to scene tree
extends Node2D
class_name VoxelRenderer

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


## Setup: builds tileset and prepares for rendering
func setup(visual_grid_offset: Vector2, wall_base_z_index: int = 10) -> void:
	_visual_grid_offset = visual_grid_offset
	_wall_base_z_index = wall_base_z_index
	_build_voxel_tileset()


## Getter for voxel layer at given level (for diagnostics)
func get_layer(level: int) -> TileMapLayer:
	if level < 0 or level >= _voxel_layers.size():
		return null
	return _voxel_layers[level]


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
		_render_slice(slice)
	
	# Render junction columns
	for column in junction_columns:
		_render_junction_column(column)


## Render a solid block (SLICE-02: A-T2)
## Fills all 64 voxel positions of a GU across [start_level, start_level + storey_span).
## start_level=0 reproduces the old ground-anchored behavior; start_level>0 supports
## floating geometry (ceiling props, chandeliers, hanging objects — any block that
## doesn't start at floor 0).
func render_block(gu_cell: Vector2i, start_level: int, storey_span: int, material_name: String) -> void:
	_ensure_voxel_layers(start_level + storey_span)
	
	# Get all voxel positions in this GU
	var voxel_positions: Array[Vector2i] = GeometryCoords.gu_voxels(gu_cell)
	
	# Render each voxel at each level in the span
	for level in range(start_level, start_level + storey_span):
		for voxel_pos in voxel_positions:
			_set_voxel_cell(voxel_pos, level, material_name)


## Render a single slice's voxels
func _render_slice(slice: Slice) -> void:
	# Ensure we have enough layers
	_ensure_voxel_layers(slice.storey_count)
	
	# For each voxel in the slice, set_cell at the appropriate layer
	for voxel in slice.voxels:
		if voxel.visible:
			_set_voxel_cell(voxel.grid_pos, voxel.level, slice.material)


## Render a junction column
func _render_junction_column(column: JunctionResolver.JunctionColumn) -> void:
	_ensure_voxel_layers(column.storey_count)

	# Render a 2×2 block of voxels for better visibility, centered at corner
	# This makes the column more prominent without breaking the geometry
	for level in range(column.storey_count):
		for dx in range(2):
			for dy in range(2):
				var voxel_pos := Vector2i(column.voxel_pos.x + dx, column.voxel_pos.y + dy)
				_set_voxel_cell(voxel_pos, level, "concrete")


## Set a voxel cell on the appropriate layer
func _set_voxel_cell(grid_pos: Vector2i, level: int, material_name: String) -> void:
	if level < 0 or level >= _voxel_layers.size():
		push_warning("VoxelRenderer._set_voxel_cell: level %d out of range [0, %d)" % [level, _voxel_layers.size()])
		return
	
	# Find material index
	var mat_index := MATERIALS.find(material_name)
	if mat_index == -1:
		mat_index = 0  # Fallback to concrete
	
	var layer: TileMapLayer = _voxel_layers[level]
	layer.set_cell(grid_pos, mat_index, Vector2i.ZERO)


## Process dirty slices only (TIC optimization)
func process_dirty(registry: EdgeRegistry) -> void:
	var dirty_slices := registry.dirty_slices()
	
	if dirty_slices.is_empty():
		return
	
	# Update cells for dirty voxels
	for slice in dirty_slices:
		for voxel in slice.voxels:
			if voxel.dirty:
				# Update cell state based on voxel visibility
				if voxel.visible:
					_set_voxel_cell(voxel.grid_pos, voxel.level, slice.material)
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


## Clear all layers and voxels
func clear() -> void:
	for layer in _voxel_layers:
		layer.clear()


func _to_string() -> String:
	return "VoxelRenderer{layers=%d, tileset=%s}" % [_voxel_layers.size(), "valid" if _tileset else "null"]
