## BakedTileLookup — Single lookup seam for placement path
##
## Insertion point between placement code and tile source selection.
## Query for a voxel face → either baked atlas or generic material atlas.
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


## Main resolve function: placement calls this once per set_cell()
## For now, master-strip baking (BAKE-FIX-02) is not yet integrated.
## Always falls back to generic material atlas.
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

	# Master-strip integration (BAKE-FIX-02) will go here
	# For now, fall back to generic
	return _resolve_generic(edge, face, voxel_xy)


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
