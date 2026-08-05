## VoxelVariantRegistry — Pre-fabricated damage variant lookup (D-ARCH-01)
##
## Stores and resolves pre-baked damage-decal tile references created during
## map load, keyed by the EXACT string VoxelRenderer.damage_variant_material()/
## floor_damage_material() computes for a given (material, damage_state,
## blast_sourced, carved_side, variant) combination — the same functions
## VoxelRenderer.apply_damage_voxel_swap() calls to build its lookup key, so a
## hit and its D33 runtime-compositing fallback can never name a cell
## differently.
##
## Soot is deliberately NOT part of this registry: soot is a per-cell
## modulate-alpha code (VoxelLightField.encode_face_soot()) applied by the
## light-repaint pass after any set_cell(), independent of which
## source_id/atlas_coords a cell shows. DESTROYED voxels are not registered
## either — Voxel.set_damage(DESTROYED) sets visible = false and the renderer
## erases the cell directly, never reaching a damage-variant lookup at all.

class_name VoxelVariantRegistry

## (grid_pos.x, grid_pos.y, level, container_material) ->
##   Dictionary[damage_material_name: String -> {source_id: int, atlas_coords: Vector2i}]
var _variant_cache: Dictionary = {}


func _init() -> void:
	_variant_cache.clear()


## Register a pre-baked CRACKED/DENTED variant. `damage_material_name` must be
## the exact string damage_variant_material()/floor_damage_material() would
## compute for this voxel's (damage_state, blast_sourced, carved_side,
## variant) — see apply_damage_voxel_swap()'s own derivation.
func register(cell_key: String, damage_material_name: String, source_id: int, atlas_coords: Vector2i) -> void:
	if not _variant_cache.has(cell_key):
		_variant_cache[cell_key] = {}
	_variant_cache[cell_key][damage_material_name] = {
		"source_id": source_id,
		"atlas_coords": atlas_coords,
	}


## Resolve a pre-baked variant, or {} on a miss (registry not populated for
## this cell/name — caller falls through to D33 runtime compositing).
func get_variant(cell_key: String, damage_material_name: String) -> Dictionary:
	if _variant_cache.has(cell_key):
		return _variant_cache[cell_key].get(damage_material_name, {})
	return {}


## Make a cell key from position/level/material. No edge_id dimension: edge
## only matters for the baked-atom LOOKUP resolution that already happened by
## bake time and is baked into the composited pixels themselves.
static func make_cell_key(voxel_pos: Vector2i, level: int, container_material: String) -> String:
	return "%d_%d_%d_%s" % [voxel_pos.x, voxel_pos.y, level, container_material]


## Clear all variants (map change).
func clear() -> void:
	_variant_cache.clear()


## Total registered (cell, damage_material_name) entries — diagnostics/selftest only.
func size() -> int:
	var total := 0
	for cell_key in _variant_cache:
		total += _variant_cache[cell_key].size()
	return total
