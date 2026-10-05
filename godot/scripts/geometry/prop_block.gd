## Geometry Module — PropBlock: one destructible prop's solid voxel fill, one GU cell wide.
## R3D-PROPS Tier 1/2 (crates and other square props render through the SAME `VoxelStore`
## mechanism as a wall — this is that mechanism's container, mirroring Slice's minimal
## contract (id, material, voxels, dirty bookkeeping) since `VoxelStore._fill()` reads
## containers duck-typed, not by class: any object with those fields fills the same way.
## v1 scope matches `PropDef`'s own doc ("whole-storey granularity only"): one fixed
## material, a solid box, no per-voxel bitmask (PROP-01 Item 0-A defers that).
class_name PropBlock
extends VoxelContainer

var id: String
var material: String
## The floor level the prop stands on (the vertical reference of a blast ring); -1 = use the block's own lowest voxel.
var floor_level: int = -1


func _init(p_id: String, p_material: String):
	id = p_id
	material = p_material


func _to_string() -> String:
	return "PropBlock{id='%s', material='%s', voxel_count=%d, dirty=%d}" % [
		id, material, voxel_count(), dirty_count
	]
