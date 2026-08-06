## BakePolicy — Shared deterministic rules for texture baking
##
## Ensures the bake pass and lookup pass use identical:
## - Texture assignment (material ID + surface class → texture ID)
## - Variant seeding (edge + material → [0, 4) variant)
##
## D20 (EXPLOSION_REBUILD_MASTER_PLAN, 2026-08-06): texture identity is a
## (material, surface_class) pair, mechanically derived — no per-material
## dict to keep in sync, matching MAPFILE_REFERENCE.md's existing M6 prefix
## canon (`facade_<material>`). SLICE (walls/roofs, reprojected from the same
## source) always resolves to `facade_<id>`; SLAB (floor zones) always
## resolves to `slab_<id>` (renamed from the old `ground_<id>` — the material
## id itself no longer carries a `ground_` prefix, D19 unified it). A missing
## asset for either (e.g. a material with no wall facade) is handled the same
## way it always was: TextureResolver.resolve() falls back to Tier.NONE and
## every caller already treats that as "fall back to the generic atlas".

class_name BakePolicy

## SLICE = vertical face (walls, and roofs — a roof reprojects its material's
## own wall facade, D20's second correction: "ceiling" in the SLAB row below
## refers to the future damage-atom pool, not the base roof render).
## SLAB = horizontal face (floor zones only, today).
enum SurfaceClass { SLICE, SLAB }

## SLICE (vertical, walls/roofs) texture id for a material.
static func facade_for_material(material_id: String) -> String:
	return "facade_" + material_id


## SLAB (horizontal, floor zones) texture id for a material.
static func slab_for_material(material_id: String) -> String:
	return "slab_" + material_id


## (material_id, surface_class) → texture id, the one call sites that already
## know their surface_class should use instead of picking a function by hand.
static func texture_for_material(material_id: String, surface_class: int) -> String:
	if surface_class == SurfaceClass.SLAB:
		return slab_for_material(material_id)
	return facade_for_material(material_id)


## Deterministic variant selection. Stable across runs: NEVER uses instance identity.
static func variant_for(edge, material_id: String) -> int:
	var edge_key: String = edge.key_string() if edge.has_method("key_string") else str(edge)
	return abs(("%s_%s" % [edge_key, material_id]).hash()) % 4
