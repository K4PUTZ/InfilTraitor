## Geometry Module — Voxel Renderer: TileMapLayer-based voxel wall rendering
## Port from room.gd voxel functions, honoring Transform Canon
## Extends Node2D to add to scene tree
extends Node2D
class_name VoxelRenderer

var PropDefClass = preload("res://godot/scripts/systems/prop_def.gd")

## TileSet source ID for voxels
const VOXEL_SOURCE_ID: int = 0

## Materials to load (in order). source_id == array index (see
## _build_voxel_tileset() and _set_voxel_cell()'s MATERIALS.find() fallback),
## so appending never disturbs the first 4 wall materials' existing ids.
##
## DESTRUCTION D2/D4: "earth_0".."earth_7" are the floor/slab palette —
## EarthVariantSelector.variant_for() picks one by index, matching
## generate_voxel.py's voxel_earth_N.png naming exactly (VOXEL_ASSET_TEMPLATE
## below is generic over material_name, so these load through the identical
## path the 4 wall materials already use — no new loader, per D2). They never
## go through the baked-lookup branch: floor voxels have no edge (D1), so
## _set_voxel_cell's `edge` argument is always null for them, same as any
## other material-only fallback placement.
const MATERIALS: Array[String] = [
	"concrete", "metal", "stone", "wood",
	"earth_0", "earth_1", "earth_2", "earth_3", "earth_4", "earth_5", "earth_6", "earth_7",
]

## Voxel asset path template
const VOXEL_ASSET_TEMPLATE: String = "res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_%s.png"

## OCC-08 — Three-ring ghost, rings by EDGE-GRAPH hop distance (supersedes OCC-05's
## flat single alpha, Director decision 2026-07-14).
##
## A ghost is an ALTERNATIVE TILE, not a new texture: Godot's TileData carries a
## `modulate` per alternative, and alternatives reuse the same atlas region. A ghost
## therefore costs *not one extra pixel* of texture memory, and nothing per fragment —
## which is why this needs no sign-off against the mobile budget (D12).
##
## History: O6 shipped three alpha rings by VOXEL distance from the agent — serrated
## in practice, adjacent faces of the same wall landing in different rings. OCC-05
## flattened to one alpha to kill that. OCC-08 brings rings back, but the ring index
## now comes from OcclusionSet's EDGE-GRAPH hop distance (0/1/2 hops from a triggering
## edge, walked along the wall's own connectivity) instead of Euclidean voxel distance
## — an entire edge (and its whole slice tower) shares one ring, so there is no
## per-voxel patchwork to serrate in the first place. Definition is carried by
## OcclusionWireframeOverlay regardless of ring — see that script. Ghosting a cell is
## still just changing the last argument of set_cell(); Voxel.visible is never
## touched (O1) — occlusion is VIEW, not STATE.
const GHOST_ALT_IDS: Array[int] = [1, 2, 3]        ## ring 0, 1, 2 → alternative id
const GHOST_ALPHAS: Array[float] = [0.04, 0.08, 0.16]

## Cells currently ghosted → Array of {"level": int, "prev_alt": int}, so a cell leaving
## the occluded set is restored to EXACTLY the alternative it had. We remember what was
## there rather than re-deriving what "should" be there: re-running the bake lookup here
## would be a second live copy of the placement decision, and it would diverge from the
## real one the moment bake config changed.
var _ghosted_cells: Dictionary = {}

## Z-index base for wall layers (from room.gd context)
var _wall_base_z_index: int = 10

## Array of TileMapLayers [level_0, level_1, ...] — walls/blocks/props, unchanged
## by D17. Positive levels only; never touched by the floor work below.
var _voxel_layers: Array[TileMapLayer] = []

## DESTRUCTION D17/D18: floor/background layers, keyed by their true (negative)
## level. A SEPARATE dictionary rather than folding into _voxel_layers above —
## on purpose, not an oversight: GDScript's `array[-1]` means "last element",
## not "grow downward", so unifying storage would mean every one of
## _voxel_layers' many existing 0-indexed callers (walls, junctions, props,
## occlusion) would need to learn to ignore negative keys. Keeping floor levels
## in their own dictionary means ALL of that positive-level code needs zero
## changes — D17's whole point. get_layer()/_set_voxel_cell() are the two
## routing points that make the split invisible to every other caller.
## Never contiguous-from-zero (D18: lazy reveal) — a level exists here only
## once something has actually built it.
var _negative_voxel_layers: Dictionary = {}

## Runtime TileSet
var _tileset: TileSet

## Source ids registered by register_baked_atlas_page() — one full set per rebuild
## (every view rotation re-bakes). Unlike the four MATERIALS sources (built once,
## permanent), these are transient: clear() removes them so a rebuild doesn't leave
## the previous rotation's pages (and their minted ghosts) orphaned in _tileset
## forever. Left unpruned, source_count grows without bound across rotations.
var _baked_source_ids: Array[int] = []

## Visual grid offset (isometric screen space)
var _visual_grid_offset: Vector2

## DEBUG-02: Accumulated nudge offset (pixels). Applied to all layers for real-time measurement.
var debug_nudge: Vector2 = Vector2.ZERO

## Cached baking components (Item 7: caching hot-path objects)
var _bake_config = null       # Script ref, loaded once
var _baked_lookup = null      # BakedTileLookup instance, created once

## BAKE-DIAG-01: placement counters, reset at the top of each render() call
var _diag_total_cells: int = 0
var _diag_baked_hits: int = 0
var _diag_generic_fallbacks: int = 0
var _diag_null_edge_cells: int = 0
var _diag_slice_count: int = 0


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


## Register a baked atlas page as a source on this renderer's own TileSet.
## BAKE-LIVE-VERIFY-01-b Part 3: Fixes BUG B — pages now go on the right tileset.
## BAKE-DIAG-01: also fixes BUG C — a TileSetAtlasSource has zero valid tiles until
## create_tile() is called per atlas coordinate (mirrors what _build_voxel_tileset()
## already does for the material-only sources). Without this, set_cell() on this
## source silently no-ops visually: the cell records source_id/atlas_coords, the
## placement-side counters see a "baked hit", but nothing draws — which is exactly
## why every wall vanished with bake enabled while the lookup/placement counters
## reported 100% success.
## atlas_coords_used: every (col, row) the compositor actually wrote pixel data to.
## tile_modulate: per-tile tint realizing the blend mode on grayscale baked pages
## (OVERLORD-FIX-01: TEXTURE_ONLY = white, MULTIPLY = material base color).
## Returns the assigned source_id.
func register_baked_atlas_page(page_image: Image, atlas_coords_used: Array = [], tile_modulate: Color = Color.WHITE) -> int:
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(page_image)
	source.texture_region_size = Vector2i(32, 36)  # GeometryCoords.VOXEL_ATOM_W/H [BAKE-FIX-01]

	var source_id := _tileset.get_next_source_id()
	_tileset.add_source(source, source_id)
	_baked_source_ids.append(source_id)

	for coords in atlas_coords_used:
		if source.get_tile_at_coords(coords) != Vector2i(-1, -1):
			continue
		source.create_tile(coords)
		var tile_data: TileData = source.get_tile_data(coords, 0)
		if tile_data != null:
			tile_data.texture_origin = GeometryCoords.voxel_texture_origin()
			tile_data.modulate = tile_modulate
			## OCC-02: ghosts for baked cells, derived from THIS page's modulate.
			_mint_ghost_alternatives(source, coords, tile_modulate)

	return source_id


## OCC-02: mint the three ghost alternatives for one tile of one source.
##
## Called from BOTH tile-creation paths — the four material sources AND every baked atlas
## page registered at runtime. That is not optional: BakeConfig.enabled is true by dev
## default, so most wall cells are placed on baked pages. A ghost minted only on the
## material sources would do nothing on a normal boot.
##
## Two traps, both learned the hard way and both silent:
##
##  - create_alternative_tile() returns a BLANK TileData. It inherits nothing. If
##    texture_origin is not re-applied, every ghosted cell jumps 10 px the instant it
##    ghosts (same family as BAKE-DIAG-01: cells "placed" but wrong on screen).
##  - the ghost's modulate must derive from the tile's BASE modulate, not white. Baked
##    pages are tinted per page (white under TEXTURE_ONLY, the material colour under
##    MULTIPLY). A ghost hardcoding Color(1,1,1,a) would silently recolour every baked
##    wall it touched.
##
## No existence probe: `source` is always freshly created by both call sites (a brand
## new TileSetAtlasSource per register_baked_atlas_page() call, or one of the four
## material sources built exactly once in _build_voxel_tileset()), and each caller
## already dedupes coords before calling in. A source+coords pair therefore never
## reaches this function twice — probing "does alt_id already exist?" via
## get_tile_data() was always false and only served to make Godot log a spurious
## ERROR per tile (TileSetAtlasSource logs on any miss, not just push a null).
func _mint_ghost_alternatives(source: TileSetAtlasSource, coords: Vector2i, base_modulate: Color) -> void:
	for ring in range(GHOST_ALT_IDS.size()):
		var alt_id: int = GHOST_ALT_IDS[ring]
		source.create_alternative_tile(coords, alt_id)
		var ghost_data: TileData = source.get_tile_data(coords, alt_id)
		if ghost_data == null:
			push_error("[OCC-08] Failed to create ghost alternative %d at %s" % [alt_id, coords])
			continue
		ghost_data.texture_origin = GeometryCoords.voxel_texture_origin()
		var ghost_modulate := base_modulate
		ghost_modulate.a = GHOST_ALPHAS[ring]
		ghost_data.modulate = ghost_modulate


## Getter for voxel layer at given level (for diagnostics). D17: negative
## levels (floor/background) route to _negative_voxel_layers; this is the
## single point that makes the split storage invisible to every caller.
func get_layer(level: int) -> TileMapLayer:
	if level < 0:
		return _negative_voxel_layers.get(level)
	if level >= _voxel_layers.size():
		return null
	return _voxel_layers[level]


## Number of voxel layers currently built (for OcclusionWireframeOverlay's per-column
## height scan — see get_layer()'s docstring for why callers must not assume LEVELS_PER_STOREY).
## Positive (wall) levels only, unchanged by D17 — occlusion's column scan has
## no reason to know about floor levels below it.
func get_layer_count() -> int:
	return _voxel_layers.size()


## Getter for the runtime TileSet (for diagnostics/tests — e.g. reading TileData.flip_h)
func get_tileset() -> TileSet:
	return _tileset


## OCC-03: Get the highest z_index across all voxel layers (used to render agent above all geometry).
## Returns: z_index of the topmost voxel layer, or WALL_BASE_Z_INDEX if no layers yet.
func get_max_voxel_z_index() -> int:
	if _voxel_layers.is_empty():
		return _wall_base_z_index
	# Each layer has z_index = _wall_base_z_index + level
	# Topmost layer is at index (_voxel_layers.size() - 1)
	return _wall_base_z_index + (_voxel_layers.size() - 1)


## Cells placed by the last render() pass. Reset at the top of every render().
## The B6 loud-fail guard in RoomBuilder reads this: a registry with slices that
## places zero cells means the render path did not run, and the game must not
## boot into a silently empty world. See OCC-FIX-01.
func get_placed_cell_count() -> int:
	return _diag_total_cells


## DEBUG-02: Apply real-time positional offset to all voxel layers.
## Accumulates nudges and shifts existing layers; new layers inherit the offset.
func apply_debug_nudge(delta: Vector2) -> void:
	debug_nudge += delta
	for layer in _voxel_layers:
		layer.position += delta
	for layer in _negative_voxel_layers.values():
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
			## OCC-02: ghosts for the generic (non-baked) path. Base modulate is white here.
			_mint_ghost_alternatives(atlas_source, Vector2i.ZERO, tile_data.modulate)


## Render all slices and junction columns from registry
## Creates cells in layers based on voxel positions and levels
func render(registry: EdgeRegistry, junction_columns: Array = []) -> void:
	# BAKE-DIAG-01: reset placement counters for this render pass
	_diag_total_cells = 0
	_diag_baked_hits = 0
	_diag_generic_fallbacks = 0
	_diag_null_edge_cells = 0

	_diag_slice_count = 0
	# Iterate all slices and render their voxels
	for slice in registry.all_slices():
		_diag_slice_count += 1
		# Try to get edge from registry (if available)
		var edge = registry.get_edge(slice.edge_id) if registry.has_method("get_edge") else null
		_render_slice(slice, edge)

	# Render junction columns.
	# INFILTRAITOR_SKIP_JUNCTIONS=1 renders the map with the filler columns
	# omitted — diff two captures to see exactly which pixels on screen belong
	# to junction columns and nothing else. This is how TOP-JUNCTION-06's
	# follow-up isolated their real screen footprint; keep it, it is the only
	# cheap way to answer "is this column doing anything?" for a given map.
	if OS.get_environment("INFILTRAITOR_SKIP_JUNCTIONS") != "1":
		for column in junction_columns:
			_render_junction_column(column, registry)


## BAKE-DIAG-01: prints a summary of the last render() pass — how many cells were
## placed, how many hit the baked lookup vs fell back to generic material, and the
## live tileset source count. Called by room_builder when BakeConfig.debug_bake_set_dump
## is on. This is the placement-side counterpart to the compositor/registration prints,
## and is what actually tells us whether baked results reach the screen at all.
func print_render_diagnostics() -> void:
	print("[BAKE-DIAG] render() summary: %d slices, %d cells placed (%d baked hits, %d generic fallbacks, %d cells with null edge)" % [
		_diag_slice_count, _diag_total_cells, _diag_baked_hits, _diag_generic_fallbacks, _diag_null_edge_cells
	])
	print("[BAKE-DIAG] voxel_renderer tileset source_count=%d, _baked_lookup=%s, _bake_config.enabled=%s" % [
		_tileset.get_source_count() if _tileset else -1,
		("set" if _baked_lookup != null else "NULL"),
		(_bake_config.enabled if _bake_config else "unloaded")
	])


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
			# OVERLORD-FIX-02: dedicated junction atoms — each half-face
			# CONTINUES its adjacent leg's plane. Try first; the legacy
			# neighbor-mirror path below remains the fallback.
			if _bake_config == null:
				_bake_config = load("res://godot/scripts/systems/bake_config.gd")
			if _baked_lookup == null:
				_baked_lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()
			if _bake_config and _bake_config.enabled:
				var junction_result = _baked_lookup.resolve_junction(column.voxel_pos, level)
				if junction_result and junction_result.source_id_int >= 0:
					_diag_total_cells += 1
					_diag_baked_hits += 1
					_voxel_layers[level].set_cell(column.voxel_pos, junction_result.source_id_int, junction_result.atlas_coords, 0)
					continue

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
						var result = _baked_lookup.resolve(neighbor_edge, slice.face, voxel_xy, level)
						if result and result.source_id_int >= 0:
							source_id = result.source_id_int
							atlas_coords = result.atlas_coords
							_diag_baked_hits += 1
							# TEST (no-flip hypothesis): also skip flip here — alternative_id stays 0

				_diag_total_cells += 1
				# TEST (no-flip hypothesis): fallback / no baked atom to mirror — use the
				# canonical, unflipped tile (alternative_id stays 0). Flipping a generic
				# material tile that isn't an actual mirrored neighbor atom serves no
				# purpose and, per pixel-symmetry probe, visibly shifts the silhouette
				# because the source art (voxel_<material>.png) isn't mirror-symmetric.
				if source_id < 0:
					_diag_generic_fallbacks += 1
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
	# D17: get_layer() routes negative levels to _negative_voxel_layers — the
	# caller must have ensured the layer first (_ensure_voxel_layers() for
	# level >= 0, _ensure_negative_voxel_layer() for level < 0), same contract
	# as before, now honored for both signs instead of hard-rejecting negative.
	var layer: TileMapLayer = get_layer(level)
	if layer == null:
		push_warning("VoxelRenderer._set_voxel_cell: level %d has no layer — call _ensure_voxel_layers()/_ensure_negative_voxel_layer() first" % level)
		return

	var source_id: int = -1
	var atlas_coords: Vector2i = Vector2i.ZERO
	var alternative_id: int = 0

	# SEAM: Try baked lookup first (using cached instances)
	if _bake_config == null:
		_bake_config = load("res://godot/scripts/systems/bake_config.gd")
	if _baked_lookup == null:
		_baked_lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()

	_diag_total_cells += 1
	if edge == null:
		_diag_null_edge_cells += 1

	if _bake_config and _bake_config.enabled and edge != null:
		var result = _baked_lookup.resolve(edge, slice_face, voxel_xy, level)

		if result and result.source_id_int >= 0:
			source_id = result.source_id_int
			atlas_coords = result.atlas_coords
			alternative_id = result.alternative_id
			_diag_baked_hits += 1

	# Fallback: material-only path
	if source_id < 0:
		_diag_generic_fallbacks += 1
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


## OCC-02/OCC-08 — apply the occluded-cell set as ghosts. THE single entry point.
##
## `occluded`: Vector2i (voxel COLUMN) → ring index, straight from OcclusionSet.
## OCC-08: the ring is an EDGE-GRAPH hop distance (0/1/2) from a triggering edge, not
## a voxel distance — every voxel belonging to the same edge shares one ring, so
## there is no per-voxel patchwork within a single wall to serrate. Every level of a
## ghosted column is ghosted: a wall covering the agent covers him from his feet to
## over his head, and the upper layers draw above him regardless of y-sort.
##
## Full restore, then full re-apply. The set is a few dozen columns and this runs on agent
## step / view change / map load — never per frame. Diffing would buy nothing and would
## add a second notion of "what is currently ghosted".
##
## O1: this never writes Voxel.visible, never sets a dirty flag, never persists. A ghost
## is a tile alternative and nothing more. If occlusion ever hid a voxel instead, a
## DESTROYED voxel would come back to life the moment the player rotated the camera over
## a crater — and that bug only reproduces under rotation, so it would survive for months.
func apply_occlusion(occluded: Dictionary) -> void:
	_restore_ghosted_cells()

	for cell in occluded.keys():
		var entry = occluded[cell]
		## OCC-10: min_level is where GHOSTING STARTS — the edge's own base band
		## (OcclusionSet.BASE_VISIBLE_LEVELS) sits below it and is never touched
		## here at all, left at its original full-opacity tile (Director's call:
		## the base always reads as solid footprint; only the rest ghosts).
		var min_level: int = int(entry.get("min_level", 0))
		## OCC-21 dropped tile-alternative ghosting for erase+wireframe-fill (see
		## below) — `entry["ring"]` is no longer read here; ring-based visuals now
		## live entirely in occlusion_slice_panel.gd/occlusion_wireframe_overlay.gd.
		var restore_records: Array = []

		for level in range(min_level, _voxel_layers.size()):
			var layer: TileMapLayer = _voxel_layers[level]
			var source_id: int = layer.get_cell_source_id(cell)
			if source_id == -1:
				continue  ## nothing placed at this level of the column

			var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
			var prev_alt: int = layer.get_cell_alternative_tile(cell)

			## OCC-21 (2026-07-14): ERASE occluded cells entirely instead of ghosting.
			## The wireframe fill is now the sole visual representation. Store full
			## placement data (source, atlas, alt) for complete restoration later.
			restore_records.append({
				"level": level,
				"source_id": source_id,
				"atlas_coords": atlas_coords,
				"prev_alt": prev_alt
			})
			layer.erase_cell(cell)

		if not restore_records.is_empty():
			_ghosted_cells[cell] = restore_records


## OCC-02 — prove the restore is lossless, on the real map, not by argument.
##
## Snapshot every placed cell's (source, atlas, alternative) across every level; ghost the
## given set; release it; snapshot again; compare. Returns true iff the map is bit-identical
## afterwards.
##
## This is the invariant that matters most in the whole prompt. Ghosting runs on every agent
## step; if restore is lossy by even one alternative, the map degrades a little with each
## step the player takes — a corruption that accumulates invisibly and would be blamed on
## anything but occlusion months later.
func verify_ghost_roundtrip(occluded: Dictionary) -> bool:
	apply_occlusion({})          ## start from a clean, unghosted map
	var before := _snapshot_cells()
	apply_occlusion(occluded)
	apply_occlusion({})          ## release everything
	var after := _snapshot_cells()

	var ok := true
	if before.size() != after.size():
		push_error("[OCC-02] Round-trip changed the cell COUNT: %d → %d" % [before.size(), after.size()])
		ok = false
	else:
		for key in before.keys():
			if not after.has(key) or after[key] != before[key]:
				push_error("[OCC-02] Round-trip damaged cell %s: %s → %s" % [
					key, before[key], after.get(key, "<missing>")])
				ok = false
				break

	## Leave the map in the state the caller had: ghosts applied. A verification that
	## silently un-ghosts the world would make the very capture taken to prove ghosting
	## show none of it.
	apply_occlusion(occluded)
	return ok


## OCC-02: (level, cell) → [source_id, atlas_coords, alternative] for every placed cell.
func _snapshot_cells() -> Dictionary:
	var snap: Dictionary = {}
	for level in range(_voxel_layers.size()):
		var layer: TileMapLayer = _voxel_layers[level]
		for cell in layer.get_used_cells():
			snap[[level, cell]] = [
				layer.get_cell_source_id(cell),
				layer.get_cell_atlas_coords(cell),
				layer.get_cell_alternative_tile(cell),
			]
	return snap


## OCC-02: put every ghosted cell back to the exact alternative it had before we touched
## it. Reading the remembered value — not recomputing it — is what keeps occlusion a pure
## view layer over whatever placement decided (baked or generic).
func _restore_ghosted_cells() -> void:
	for cell in _ghosted_cells.keys():
		for record in _ghosted_cells[cell]:
			var level: int = record["level"]
			if level >= _voxel_layers.size():
				continue
			var layer: TileMapLayer = _voxel_layers[level]
			## OCC-21: restore from saved placement data, not current layer state
			## (the cell was erased, so layer queries would return -1)
			layer.set_cell(cell, record["source_id"], record["atlas_coords"], record["prev_alt"])
	_ghosted_cells.clear()


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
## Build one properly-configured voxel TileMapLayer node for a given level —
## positive (wall) or negative (D17: floor/background). Shared by
## _ensure_voxel_layers() and _ensure_negative_voxel_layer() so the position/
## z-index formula has exactly one owner; the two callers differ only in
## WHERE they file the result (_voxel_layers vs _negative_voxel_layers),
## never in HOW a layer is built.
func _build_voxel_layer_node(level: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = _tileset
	layer.name = "voxel_layer_%d" % level

	# E1 equation from Transform Canon (SLICE-00)
	# Compensation between floor grid (256×128 tiles) and voxel grid (32×16 tiles):
	# TILE_OFFSET = (floor_half_w − voxel_half_w, floor_half_h) = (128−16, 64) = (112, 64).
	# NOTE: the pre-2026-07-02 value (112, 56) subtracted voxel_half_h on Y as well —
	# an 8px error, empirically measured and corrected via DEBUG-02 ruler + nudge session
	# (residual now zero). Do not "restore symmetry" to (112, 56); the asymmetry is correct.
	# Formula is sign-agnostic: a negative level correctly pushes the layer DOWN
	# on screen (subtracting a negative adds height), which is exactly D17's floor.
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
	return layer


func _ensure_voxel_layers(storey_count: int) -> void:
	while _voxel_layers.size() < storey_count:
		var level := _voxel_layers.size()
		_voxel_layers.append(_build_voxel_layer_node(level))


## D17/D18: negative levels are never contiguous-from-zero and rarely all
## exist at once — callers ensure exactly the one level they need (the top
## destructible floor level, always; deeper fixed/cosmetic levels only once
## something has actually dug down to them). No "ensure up to N" variant on
## purpose: that shape would invite building a contiguous run nobody asked
## for, which is precisely what D18 forbids.
func _ensure_negative_voxel_layer(level: int) -> void:
	if level >= 0:
		push_error("VoxelRenderer._ensure_negative_voxel_layer: level %d is not negative" % level)
		return
	if _negative_voxel_layers.has(level):
		return
	_negative_voxel_layers[level] = _build_voxel_layer_node(level)


## DESTRUCTION D1/D2/D4 — render one Slab's voxels. Each voxel independently
## picks its earth variant via EarthVariantSelector.variant_for(grid_pos,
## level) — deterministic, so this is idempotent: calling it again on the
## same Slab places the exact same cells (D5's "nothing to pop" property).
## Not wired to any real map data yet (no MapSpec integration) — this is the
## render-side half of Part 2's core, consumed directly by whatever builds a
## Slab (today: only slab_generator.gd's manual/test construction).
func render_slab(slab: Slab) -> void:
	if slab.voxels.is_empty():
		return
	# All of one Slab's voxels share slab.level (SlabGenerator.generate()'s
	# invariant) — one layer to ensure, not a min/max scan. D17: negative
	# (floor) levels route to the negative-only ensure function.
	if slab.level < 0:
		_ensure_negative_voxel_layer(slab.level)
	else:
		_ensure_voxel_layers(slab.level + 1)

	for voxel in slab.voxels:
		var variant_index: int = EarthVariantSelector.variant_for(voxel.grid_pos, voxel.level)
		var material_name: String = "earth_%d" % variant_index
		_set_voxel_cell(voxel.grid_pos, voxel.level, material_name)


## DESTRUCTION D13/D18 — render one FIXED floor level for one GU: no `Slab`,
## no `Voxel`, no dirty-tracking at all. D13's 7 non-destructible levels
## beneath the one real (Slab) destructible top are structurally incapable of
## ever being marked dirty precisely because they never go through Voxel in
## the first place — this function places cells directly, the same way
## render_block() does for wall material, just per-LEVEL (not per-storey) and
## through the earth-variant hash instead of one fixed material, so a fixed
## level reads as the same material family as the destructible level above it.
##
## D18: called once per level, on demand — never loops over a range itself.
## Whatever eventually decides "digging exposed level -4" (Part 3, not built
## yet) calls this once for that one level; nothing here assumes or builds a
## contiguous stack.
func render_fixed_earth_level(gu_cell: Vector2i, level: int) -> void:
	if level < 0:
		_ensure_negative_voxel_layer(level)
	else:
		_ensure_voxel_layers(level + 1)

	for voxel_pos in GeometryCoords.gu_voxels(gu_cell):
		var variant_index: int = EarthVariantSelector.variant_for(voxel_pos, level)
		_set_voxel_cell(voxel_pos, level, "earth_%d" % variant_index)


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
	for layer in _negative_voxel_layers.values():
		layer.clear()
	## OCC-02: the cells those records point at no longer exist. Keeping them would make
	## the next restore write stale alternatives into freshly-rebuilt geometry — the
	## rotation path (clear() + render()) goes through here every time.
	_ghosted_cells.clear()


## Remove every baked atlas source registered by the PREVIOUS bake pass, before the
## current one registers its own. Must run before register_baked_atlas_page() is called
## for a fresh pass — never from clear(), which runs AFTER _bake_textures() has already
## registered this pass's new sources (removing them there would delete what was just
## built). Without this, every view rotation left the prior rotation's pages (and their
## minted ghost alternatives) orphaned in _tileset forever: source_count grew without
## bound and every rotation re-triggered a full ghost-mint pass on top of the leak.
## The four MATERIALS sources (ids assigned once in _build_voxel_tileset()) are untouched.
func prune_baked_sources() -> void:
	for source_id in _baked_source_ids:
		if _tileset.has_source(source_id):
			_tileset.remove_source(source_id)
	_baked_source_ids.clear()


func _to_string() -> String:
	return "VoxelRenderer{layers=%d, negative_layers=%d, tileset=%s}" % [
		_voxel_layers.size(), _negative_voxel_layers.size(), "valid" if _tileset else "null"
	]
