## Geometry Module — Slab: horizontal voxel container (floor, ceiling, interior)
## DESTRUCTION_MASTER_PLAN D1: the container sibling of Slice for the horizontal
## plane. A wall voxel belongs to a Slice which belongs to an Edge; a floor/ceiling
## voxel has no edge, so it gets this container instead — same dirty-count/TIC-skip
## contract as Slice, none of the edge-specific fields (face, edge_id).
## Floor, ceiling and interior cutaway are ONE class: a ceiling is a Slab at a
## different level/role, not a different type. See voxel.gd's Voxel._parent_container
## for why Voxel is shared unmodified between Slice and Slab.
class_name Slab

enum Role { FLOOR, CEILING, INTERIOR }

var id: String                   ## canonical: "SLAB_%d_%d_%s_%d" % [gu_cell.x, gu_cell.y, role_name(role), level]
var gu_cell: Vector2i            ## the GU this slab belongs to
var role: int                    ## Role.FLOOR / CEILING / INTERIOR
var level: int                   ## the horizontal plane's level (D13: floor's destructible layer is 1 level, not a full storey)
var material: String             ## material type
var voxels: Array[Voxel] = []    ## all voxels in this slab (64 per level, VOXELS_PER_UNIT_AXIS²)
var dirty_count: int = 0         ## sum of child Voxel dirty flags


func _init(p_id: String, p_gu_cell: Vector2i, p_role: int, p_level: int, p_material: String = "concrete"):
	id = p_id
	gu_cell = p_gu_cell
	role = p_role
	level = p_level
	material = p_material


## Get voxel by index; returns null if out of bounds
func get_voxel(index: int) -> Voxel:
	if index < 0 or index >= voxels.size():
		return null
	return voxels[index]


## Total voxel count (64 per level, one storey's worth of a GU footprint)
func total_voxel_count() -> int:
	return voxels.size()


## Mark all voxels dirty and update counter
func mark_all_dirty() -> void:
	for voxel in voxels:
		if not voxel.dirty:
			voxel.dirty = true
			dirty_count += 1


## Called by child Voxel when it becomes dirty
func increment_dirty() -> void:
	dirty_count += 1


## Called by child Voxel when it clears dirty
func decrement_dirty() -> void:
	if dirty_count > 0:
		dirty_count -= 1


## Recursively clear all Voxel.dirty flags (TIC entry point from registry)
func clear_all_dirty() -> void:
	for voxel in voxels:
		if voxel.dirty:
			voxel.dirty = false
	dirty_count = 0


static func role_name(r: int) -> String:
	match r:
		Role.FLOOR:
			return "FLOOR"
		Role.CEILING:
			return "CEILING"
		Role.INTERIOR:
			return "INTERIOR"
		_:
			return "UNKNOWN"


func _to_string() -> String:
	return "Slab{id='%s', gu=%s, role=%s, level=%d, voxel_count=%d, dirty=%d}" % [
		id, gu_cell, role_name(role), level, voxels.size(), dirty_count
	]
