## BakedTileLookup — Single lookup seam for placement path (BAKE-FIX-02: run-aware)
##
## Insertion point between placement code and tile source selection.
## Query for a voxel face → either baked atlas or generic material atlas.
## BAKE-FIX-02: Walks master-strip dictionary with mirroring for boundary cases.
## Features a fallback chain: baked → generic material atlas.

class_name BakedTileLookup

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")

const TEX_AUTHORING_N: int = GeometryCoordsClass.TEX_AUTHORING_N

# For testing: can inject a mock BakeConfig
var _bake_config = null
var _bake_config_ref = null  # Cache BakeConfig class reference

# BAKE-FIX-02: Run information (edge_id -> run) for strip walking
var _edge_run_map: Dictionary = {}  # edge.id -> {"edges": [], "min_edge": Edge, ...}

## Result of a tile lookup query
class TileLookupResult:
	var source_id_int: int       # Integer tileset source id (for set_cell)
	var source_id: String        # String identifier (for debugging; deprecated)
	var atlas_coords: Vector2i   # (col, row) within that source
	var alternative_id: int      # For future use (always 0 for now)

	func _init(p_source_id_int: int, p_source_id: String, p_atlas_coords: Vector2i, p_alternative_id: int = 0) -> void:
		source_id_int = p_source_id_int
		source_id = p_source_id
		atlas_coords = p_atlas_coords
		alternative_id = p_alternative_id


## Set mock config for testing (optional)
func set_test_config(config) -> void:
	_bake_config = config


## BAKE-FIX-02: Register run information for later lookup during placement
## Called by room_builder after grouping edges into runs
func register_runs(runs: Array) -> void:
	_edge_run_map.clear()
	for run in runs:
		var edges = run.get("edges", [])
		for edge in edges:
			_edge_run_map[edge.id] = run


## Main resolve function: placement calls this once per set_cell()
## BAKE-FIX-02: Now run-aware for strip walking with mirroring
func resolve(edge, face: int, voxel_xy: Vector2i) -> TileLookupResult:
	# If baking is disabled, always use generic material atlas
	var baking_enabled = false
	if _bake_config:
		baking_enabled = _bake_config.is_enabled() if _bake_config.has_method("is_enabled") else _bake_config.enabled
	else:
		# Use global BakeConfig (cache the class reference)
		if _bake_config_ref == null:
			_bake_config_ref = load("res://godot/scripts/systems/bake_config.gd")
		baking_enabled = _bake_config_ref.enabled if _bake_config_ref else false

	if not baking_enabled:
		return _resolve_generic(edge, face, voxel_xy)

	# BAKE-FIX-02: Try run-aware baked lookup
	var baked_result = _resolve_baked_strip(edge, face, voxel_xy)
	if baked_result != null:
		return baked_result

	# Fallback to generic
	return _resolve_generic(edge, face, voxel_xy)


## BAKE-FIX-02: Resolve using baked strip dictionary with run-aware mirroring
## Returns null if baked atlas not available; caller will use fallback
func _resolve_baked_strip(edge, face: int, voxel_xy: Vector2i) -> TileLookupResult:
	# Get the baked atlas and lookup dictionary
	var baked_atlas = _get_baked_atlas()
	if baked_atlas == null:
		return null
	
	var lookup_dict = baked_atlas.get("lookup", {}) if baked_atlas is Dictionary else baked_atlas.lookup
	if lookup_dict.is_empty():
		return null
	
	# Get material and facade for this edge
	var material_id = "default"
	if edge.has_method("get_material_id"):
		material_id = edge.get_material_id()
	elif "material" in edge:
		material_id = edge.material
	
	var facade_id = BakePolicyClass.facade_for_material(material_id)
	
	# Get run for this edge (if available)
	var run = _edge_run_map.get(edge.id, null)
	if run == null:
		# Edge not in any run - treat as isolated or use generic
		return null
	
	# Get run's min edge and compute window origin
	var min_edge = run.get("min_edge", null)
	if min_edge == null:
		return null
	
	var facade_sampler = FacadeSamplerClass.new()
	var window_origin_texels = facade_sampler.get_window_origin_run_texels(min_edge, facade_id)
	
	# Compute position within run and walk the strip dictionary
	var position_in_run = _get_edge_position_in_run(edge, run)
	if position_in_run < 0:
		return null
	
	# For now, compute the plane column/row for the voxel in the strip
	# This will be replaced with more sophisticated strip walking once BAKE-FIX-01 dictionary is available
	var variant_k = abs(hash(str(edge.key_string()) + str(voxel_xy))) % 4
	
	# Build lookup key: "%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]
	# For now, use position_in_run as plane_col (simplified)
	var plane_col = (window_origin_texels.x / TEX_AUTHORING_N + position_in_run) % (64 * TEX_AUTHORING_N)
	var plane_row = window_origin_texels.y / TEX_AUTHORING_N
	
	var lookup_key = "%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]
	
	if lookup_dict.has(lookup_key):
		var entry = lookup_dict[lookup_key]
		var page_idx = entry.get("page", -1)
		var atlas_coords = entry.get("atlas_coords", Vector2i.ZERO)
		
		if page_idx >= 0:
			var source_id = _get_baked_atlas_source_id(page_idx)
			if source_id >= 0:
				return TileLookupResult.new(source_id, "BAKED_ATLAS_%d" % page_idx, atlas_coords, 0)
	
	return null


## Get the position of an edge within its run (0 = first edge, 1 = second, etc.)
func _get_edge_position_in_run(edge, run: Dictionary) -> int:
	var edges = run.get("edges", [])
	for i in range(edges.size()):
		if edges[i].id == edge.id:
			return i
	return -1


## Fallback: resolve using generic material atlas
func _resolve_generic(edge, face: int, voxel_xy: Vector2i) -> TileLookupResult:
	var material_id = "default"

	if edge.has_method("get_material_id"):
		material_id = edge.get_material_id()
	elif "material" in edge:
		material_id = edge.material

	# Seed variant by voxel position
	var seed_str = str(edge.key_string() if edge.has_method("key_string") else edge) + "_" + material_id + "_" + str(voxel_xy.x) + "_" + str(voxel_xy.y)
	var seed_val = hash(seed_str)
	var variant_k = abs(seed_val) % 4

	# Lookup in GLOBAL_MATERIAL_ATLAS
	var material_atlas = _get_material_atlas()
	if material_atlas:
		var atlas_coords = material_atlas.get_coords(material_id, face, variant_k)
		return TileLookupResult.new(
			material_atlas.source_id_int if material_atlas.has("source_id_int") else 0,
			material_atlas.source_id if material_atlas.has("source_id") else "MATERIAL_SOURCE",
			atlas_coords,
			0
		)

	# Fallback: return material index 0
	return TileLookupResult.new(
		0,
		"MATERIAL_ATLAS",
		Vector2i(0, 0),
		0
	)


## Get baked atlas source id (int) for a given page
func _get_baked_atlas_source_id(page_idx: int) -> int:
	# Fallback to legacy Engine.get_meta for test/production compatibility
	if Engine.has_meta("BAKED_ATLAS_SOURCE_IDS"):
		var test_source_ids = Engine.get_meta("BAKED_ATLAS_SOURCE_IDS")
		return test_source_ids.get(page_idx, -1)
	
	return -1


## Get global baked atlas (if populated)
func _get_baked_atlas():
	# Check legacy Engine.get_meta for test/production compatibility
	if Engine.has_meta("GLOBAL_BAKED_ATLAS"):
		return Engine.get_meta("GLOBAL_BAKED_ATLAS")
	
	return null


## Get global material atlas
func _get_material_atlas():
	if Engine.has_meta("GLOBAL_MATERIAL_ATLAS"):
		return Engine.get_meta("GLOBAL_MATERIAL_ATLAS")
	return null
