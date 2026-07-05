## BakePolicy — Shared deterministic rules for texture baking
##
## Ensures the bake pass and lookup pass use identical:
## - Facade assignment (material ID → facade ID)
## - Variant seeding (edge + material → [0, 4) variant)

class_name BakePolicy

## v1 facade assignment: one default facade per material.
## Authorial per-wall overrides come later via map spec.
const DEFAULT_FACADES := {
	"concrete": "facade_concrete",
	"stone": "facade_stone",
	"wood": "facade_wood",
	"metal": "facade_metal",
}

## Map material ID to facade ID (v1 policy).
## Empty string → compositor/lookup gracefully skip (fallback to generic).
static func facade_for_material(material_id: String) -> String:
	return DEFAULT_FACADES.get(material_id, "")


## Deterministic variant selection. Stable across runs: NEVER uses instance identity.
static func variant_for(edge, material_id: String) -> int:
	var edge_key: String = edge.key_string() if edge.has_method("key_string") else str(edge)
	return abs(("%s_%s" % [edge_key, material_id]).hash()) % 4
