## Geometry Module — PropBlock: one destructible prop's solid voxel fill, one GU cell wide.
## R3D-PROPS Tier 1/2 (crates and other square props render through the SAME `VoxelStore`
## mechanism as a wall — this is that mechanism's container, mirroring Slice's minimal
## contract (id, material, voxels, dirty bookkeeping) since `VoxelStore._fill()` reads
## containers duck-typed, not by class: any object with those fields fills the same way.
## v1 scope matches `PropDef`'s own doc ("whole-storey granularity only"): one fixed
## material, a solid box, no per-voxel bitmask (PROP-01 Item 0-A defers that).
class_name PropBlock

var id: String
var material: String
var voxels: Array[Voxel] = []
var dirty_count: int = 0


func _init(p_id: String, p_material: String):
	id = p_id
	material = p_material


func increment_dirty() -> void:
	dirty_count += 1


func decrement_dirty() -> void:
	if dirty_count > 0:
		dirty_count -= 1


func _to_string() -> String:
	return "PropBlock{id='%s', material='%s', voxel_count=%d, dirty=%d}" % [
		id, material, voxels.size(), dirty_count
	]
