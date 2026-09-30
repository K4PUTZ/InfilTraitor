## Geometry Module — MeshPropInstance: one Tier 3/4 prop's placement record.
## R3D-PROPS Tier 3/4 (small/medium non-destructible props with cosmetic soot/smoke by
## proximity, and medium/large organic props that swap for a fragment-cube VFX burst on
## impact) never become `VoxelStore` state — rule 8 does not apply to them, there is no
## voxel here to place. This is the data `Board3DLive` reads to build one `PropMesh3D` per
## instance and `Room` reads to resolve a blast's proximity effect against.
class_name MeshPropInstance

var id: String
var cell: Vector2i
var level: int
var material_id: String
var mesh_tier: int          ## 3 (cosmetic-only) or 4 (shatters on a close-enough hit)
var mesh_size: Vector3      ## world units (1.0 = 1 GU), the box the mesh occupies
var surface_materials: Dictionary = {}   ## model surface (authored material name) -> registry material id
var model_path: String = ""            ## a real model to draw instead of the box (see PropDef.model_path)
var model_rotation_deg: Vector3 = Vector3.ZERO
var shattered: bool = false ## Tier 4 only: true once spawn_prop_shatter() has fired for it


func _init(p_id: String, p_cell: Vector2i, p_level: int, p_material_id: String,
		p_mesh_tier: int, p_mesh_size: Vector3) -> void:
	id = p_id
	cell = p_cell
	level = p_level
	material_id = p_material_id
	mesh_tier = p_mesh_tier
	mesh_size = p_mesh_size


func _to_string() -> String:
	return "MeshPropInstance{id='%s', cell=%s, tier=%d, material='%s', shattered=%s}" % [
		id, cell, mesh_tier, material_id, shattered
	]
