## BakedTileLookup — Single lookup seam for placement path
##
## Insertion point between placement code and tile source selection.
## Query for a voxel face → either baked atlas or generic material atlas.
## Features a fallback chain: baked → generic material atlas.

class_name BakedTileLookup

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")

const TEX_AUTHORING_N: int = GeometryCoordsClass.TEX_AUTHORING_N

# For testing: can inject a mock BakeConfig
var _bake_config = null

## Result of a tile lookup query
class TileLookupResult:
	var source_id: String        # Identifier for the TileSetAtlasSource
	var atlas_coords: Vector2i   # (col, row) within that source
	var alternative_id: int      # For future use (always 0 for now)

	func _init(p_source_id: String, p_atlas_coords: Vector2i, p_alternative_id: int = 0) -> void:
		source_id = p_source_id
		atlas_coords = p_atlas_coords
		alternative_id = p_alternative_id


## Set mock config for testing (optional)
func set_test_config(config) -> void:
	_bake_config = config


## Main resolve function: placement calls this once per set_cell()
func resolve(edge, face: int, voxel_xy: Vector2i) -> TileLookupResult:
	# If baking is disabled, always use generic material atlas
	var baking_enabled = false
	if _bake_config:
		baking_enabled = _bake_config.is_enabled() if _bake_config.has_method("is_enabled") else _bake_config.enabled
	else:
		# Use global BakeConfig
		var bc = load("res://godot/scripts/systems/bake_config.gd")
		baking_enabled = bc.enabled if bc else false

	if not baking_enabled:
		return _resolve_generic(edge, face, voxel_xy)

	# Build bake key for this voxel face
	var bake_key = _make_bake_key(edge, face, voxel_xy)

	# Lookup in baked atlas
	var baked_atlas = _get_baked_atlas()
	if baked_atlas and baked_atlas.lookup.has(bake_key):
		var baked_coords = baked_atlas.lookup[bake_key]
		return TileLookupResult.new(
			"BAKED_ATLAS_%d" % baked_coords["page"],
			baked_coords["atlas_coords"],
			0
		)

	# Key not in baked set; fall back to generic material atlas
	return _resolve_generic(edge, face, voxel_xy)


## Reconstruct BakeKey from placement arguments
## Must match BakeCompositor's key construction exactly
func _make_bake_key(edge, face: int, _voxel_xy: Vector2i) -> BakeCompositorClass.BakeKey:
	# Get owning wall (backreference)
	var wall = edge.get_owning_wall()

	var material_id = "default"
	var facade_id = ""

	# Try to get values from wall (supports both real and mock objects)
	if wall.has_method("get_material_id"):
		material_id = wall.get_material_id()
	elif wall.has_method("get") and wall is Dictionary:
		material_id = wall.get("material_id", "default")

	if wall.has_method("get_facade_id"):
		facade_id = wall.get_facade_id()
	elif wall.has_method("get") and wall is Dictionary:
		facade_id = wall.get("facade_id", "")

	# Get window origin using FacadeSampler
	var sampler = FacadeSamplerClass.new()
	var origin = sampler.get_window_origin_isolated(edge, facade_id)

	# Determine variant (seeded by edge + material)
	var seed_str = str(edge.key_string() if edge.has_method("key_string") else edge) + "_" + material_id
	var seed_val = hash(seed_str)
	var variant_k = abs(seed_val) % 4

	# Construct BakeKey
	var key = BakeCompositorClass.BakeKey.new()
	key.material_id = material_id
	key.facade_id = facade_id
	key.variant_k = variant_k
	key.face = face
	key.plane_col = int(float(int(origin.x)) / float(TEX_AUTHORING_N))
	key.plane_row = int(float(int(origin.y)) / float(TEX_AUTHORING_N))

	return key


## Fallback: resolve using generic material atlas
func _resolve_generic(edge, face: int, voxel_xy: Vector2i) -> TileLookupResult:
	var wall = edge.get_owning_wall()
	var material_id = "default"

	if wall.has_method("get_material_id"):
		material_id = wall.get_material_id()
	elif wall.has_method("get") and wall is Dictionary:
		material_id = wall.get("material_id", "default")

	# Seed variant by voxel position
	var seed_str = str(edge.key_string() if edge.has_method("key_string") else edge) + "_" + material_id + "_" + str(voxel_xy.x) + "_" + str(voxel_xy.y)
	var seed_val = hash(seed_str)
	var variant_k = abs(seed_val) % 4

	# Lookup in GLOBAL_MATERIAL_ATLAS
	var material_atlas = _get_material_atlas()
	if material_atlas:
		var atlas_coords = material_atlas.get_coords(material_id, face, variant_k)
		return TileLookupResult.new(
			material_atlas.source_id,
			atlas_coords,
			0
		)

	# Fallback: return white placeholder
	return TileLookupResult.new("GENERIC_MATERIAL_SOURCE", Vector2i(0, 0), 0)


## Get global baked atlas (if populated)
func _get_baked_atlas():
	if Engine.has_meta("GLOBAL_BAKED_ATLAS"):
		return Engine.get_meta("GLOBAL_BAKED_ATLAS")
	return null


## Get global material atlas
func _get_material_atlas():
	if Engine.has_meta("GLOBAL_MATERIAL_ATLAS"):
		return Engine.get_meta("GLOBAL_MATERIAL_ATLAS")
	return null
