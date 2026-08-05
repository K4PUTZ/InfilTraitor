## VoxelVariantRegistry — Pre-fabricated damage variant lookup (D-ARCH-01)
##
## Stores and resolves all pre-baked damage voxel variants created during map load.
## Eliminates runtime decal compositing: all DENTED/CRACKED/DESTROYED variants are
## pre-created with multiple soot intensities, stored on the atlas, and swapped by ID
## during detonation.
##
## Registry structure:
## - key: (voxel_pos.x, voxel_pos.y, level, edge_id, material_id)
## - value: {
##     intact_id: source_id,
##     destroyed_id: source_id,
##     cracked_ids: [source_id × 3 soot],          # 3 intensity levels
##     dented_ids: {
##       "blast_top_0": [source_id × 3 soot],
##       "blast_left_2": [source_id × 3 soot],
##       ...,
##       "bullet_0": [source_id × 3 soot],
##     }
##   }
##
## At detonation time, lookup returns the correct ID (+ random soot intensity).
## On camera rotation, re-apply using the same voxel_pos (deterministic seed for soot).

class_name VoxelVariantRegistry

## All pre-baked damage variants for a single map load
var _variant_cache: Dictionary = {}  # (x, y, level, edge_id, mat) → variant data

## Fallback when no variant found (shouldn't happen if baking worked)
var _fallback_intact_id: int = -1


func _init() -> void:
	_variant_cache.clear()
	_fallback_intact_id = -1


## Register an intact voxel variant (base baked atom).
## Called during map load after baking completes.
func register_intact(cell_key: String, source_id: int, atlas_coords: Vector2i) -> void:
	if not _variant_cache.has(cell_key):
		_variant_cache[cell_key] = {}
	_variant_cache[cell_key]["intact_id"] = source_id
	_variant_cache[cell_key]["intact_coords"] = atlas_coords
	
	# Remember one ID for fallback
	if _fallback_intact_id < 0:
		_fallback_intact_id = source_id


## Register a DESTROYED variant (hole/invisible).
func register_destroyed(cell_key: String, source_id: int, atlas_coords: Vector2i) -> void:
	if not _variant_cache.has(cell_key):
		_variant_cache[cell_key] = {}
	_variant_cache[cell_key]["destroyed_id"] = source_id
	_variant_cache[cell_key]["destroyed_coords"] = atlas_coords


## Register CRACKED variants (3 soot intensities).
## soot_variants: array of 3 source IDs (no soot, medium, heavy)
func register_cracked(cell_key: String, soot_variants: Array) -> void:
	if not _variant_cache.has(cell_key):
		_variant_cache[cell_key] = {}
	_variant_cache[cell_key]["cracked_ids"] = soot_variants.duplicate()


## Register DENTED variants for one side/cause (bullet or blast + direction).
## soot_variants: array of 3 source IDs
## key_name: e.g. "blast_top_0", "blast_left_2", "bullet_0"
func register_dented(cell_key: String, key_name: String, soot_variants: Array) -> void:
	if not _variant_cache.has(cell_key):
		_variant_cache[cell_key] = {}
	if not _variant_cache[cell_key].has("dented_ids"):
		_variant_cache[cell_key]["dented_ids"] = {}
	_variant_cache[cell_key]["dented_ids"][key_name] = soot_variants.duplicate()


## Resolve INTACT voxel ID at a cell
func get_intact(cell_key: String) -> int:
	if _variant_cache.has(cell_key):
		var entry = _variant_cache[cell_key]
		if entry.has("intact_id"):
			return entry["intact_id"]
	return _fallback_intact_id


## Resolve DESTROYED voxel ID at a cell (hole/invisible)
func get_destroyed(cell_key: String) -> int:
	if _variant_cache.has(cell_key):
		var entry = _variant_cache[cell_key]
		if entry.has("destroyed_id"):
			return entry["destroyed_id"]
	return -1  # No destroyed variant


## Resolve CRACKED voxel ID with random soot intensity
func get_cracked(cell_key: String, soot_seed: int = 0) -> int:
	if _variant_cache.has(cell_key):
		var entry = _variant_cache[cell_key]
		if entry.has("cracked_ids"):
			var variants: Array = entry["cracked_ids"]
			if variants.size() > 0:
				var soot_idx = posmod(soot_seed, variants.size())
				return variants[soot_idx]
	return -1


## Resolve DENTED voxel ID with random soot intensity.
## damage_variant_name: "blast_top_0", "blast_left_2", "bullet_0", etc.
func get_dented(cell_key: String, damage_variant_name: String, soot_seed: int = 0) -> int:
	if _variant_cache.has(cell_key):
		var entry = _variant_cache[cell_key]
		if entry.has("dented_ids"):
			var dented_dict: Dictionary = entry["dented_ids"]
			if dented_dict.has(damage_variant_name):
				var variants: Array = dented_dict[damage_variant_name]
				if variants.size() > 0:
					var soot_idx = posmod(soot_seed, variants.size())
					return variants[soot_idx]
	return -1


## Deterministic soot seed for a voxel (used on rotation to keep marks consistent)
static func soot_seed_for_position(voxel_pos: Vector2i, level: int, variant_id: int = 0) -> int:
	return hash(Vector3i(voxel_pos.x, voxel_pos.y, level)) + variant_id


## Make a cell key from position/level/edge/material
static func make_cell_key(voxel_pos: Vector2i, level: int, edge_id: String, material_id: String) -> String:
	return "%d_%d_%d_%s_%s" % [voxel_pos.x, voxel_pos.y, level, edge_id, material_id]


## Clear all variants (map change)
func clear() -> void:
	_variant_cache.clear()
	_fallback_intact_id = -1
