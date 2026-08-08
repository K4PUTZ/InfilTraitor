## VoxelVariantRegistry — Pre-fabricated damage-ATOM lookup
## (EXPLOSION_REBUILD_MASTER_PLAN Task 1b/E-BAKE, 2026-08-06, §3.1)
##
## Stores and resolves pre-baked damage-decal tile references created during
## map load. D-ARCH-01's per-CELL key (grid_pos, level, material) is gone —
## the atom-bake model's whole premise is that a damaged voxel shows a
## RANDOMLY CHOSEN facade crop for its material, not its own, so there is no
## cell dimension left to key on. The key is now purely about WHICH ATOM:
## (element_class, material, damage_material_name, substrate_variant).
## `damage_material_name` is the exact string VoxelRenderer.
## damage_variant_material()/floor_damage_material() computes for a given
## (damage_state, blast_sourced, carved_side, decal_variant) — the same
## functions VoxelRenderer.apply_damage_voxel_swap() calls to build its
## lookup key, so a hit and its D33 runtime-compositing fallback can never
## name a cell differently. `substrate_variant` is Voxel.damage_substrate,
## rolled once per mark and persisted (see Voxel's own doc).
##
## Soot is deliberately NOT part of this registry: soot is a per-cell
## modulate-alpha code (VoxelLightField.encode_face_soot()) applied by the
## light-repaint pass after any set_cell(), independent of which
## source_id/atlas_coords a cell shows. DESTROYED voxels are not registered
## either — Voxel.set_damage(DESTROYED) sets visible = false and the renderer
## erases the cell directly, never reaching a damage-variant lookup at all.

class_name VoxelVariantRegistry

## variant_key (String, see make_variant_key()) -> {source_id: int, atlas_coords: Vector2i}
var _variants: Dictionary = {}


func _init() -> void:
	_variants.clear()


## Register a pre-baked atom. `variant_key` must come from make_variant_key()
## with the same arguments get_variant() will be queried with.
func register(variant_key: String, source_id: int, atlas_coords: Vector2i) -> void:
	_variants[variant_key] = {
		"source_id": source_id,
		"atlas_coords": atlas_coords,
	}


## Resolve a pre-baked atom, or {} on a miss (registry not populated for this
## combination — caller falls through to D33 runtime compositing).
func get_variant(variant_key: String) -> Dictionary:
	return _variants.get(variant_key, {})


## Make an atom key from (element_class, material, damage_material_name,
## substrate_variant). `element_class` is "WALL"/"CEILING"/"FLOOR" — the
## same three the master plan's §3.1 key shape names.
static func make_variant_key(element_class: String, material: String,
		damage_material_name: String, substrate_variant: int) -> String:
	return "%s|%s|%s|%d" % [element_class, material, damage_material_name, substrate_variant]


## Clear all variants (map change).
func clear() -> void:
	_variants.clear()


## Total registered atoms — diagnostics/selftest only.
func size() -> int:
	return _variants.size()


## Every registered variant key — diagnostics/display only (ATOM-SHEET, the
## per-material atom display). Deliberately NOT part of the resolve path:
## nothing in rendering may iterate this registry, because a lookup is always
## by an exactly-computed key (see get_variant()'s own contract) and iterating
## would invite "find something close enough", which is how a wrong atom ends
## up on a voxel. Returns a copy, so a caller cannot mutate the registry
## through it.
func keys() -> Array:
	return _variants.keys()
