## Geometry Module — Slab Generator: creates Slabs and Voxels for one GU's
## horizontal footprint (floor/ceiling/interior). Mirrors SliceGenerator, but
## a Slab has no Edge to derive from — it's just a GU cell, a role and a level.
class_name SlabGenerator


## Generate one Slab (64 voxels, one GU footprint at one level) and register
## it in the given SlabRegistry. D13: floor is two such Slabs at the same
## gu_cell — role FLOOR at the destructible level, role FLOOR at the fixed
## bedrock level below it — not one 8x2x8 Slab; each level is its own
## container so the bedrock level can never be marked dirty (nothing ever
## calls set_visible/set_damage on voxels in a Slab destruction never touches).
static func generate(gu_cell: Vector2i, role: int, level: int, material: String, registry: SlabRegistry) -> Slab:
	var slab_id := "SLAB_%d_%d_%s_%d" % [gu_cell.x, gu_cell.y, Slab.role_name(role), level]
	var slab := Slab.new(slab_id, gu_cell, role, level, material)

	for voxel_pos in GeometryCoords.gu_voxels(gu_cell):
		var voxel := Voxel.new(voxel_pos, level, slab)
		slab.voxels.append(voxel)

	registry.register_slab(slab)
	return slab
