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


## D1-ROOF border fix: a roof sized to exactly its GU's 8x8 footprint only
## covers the wall's OWN-side slice — SliceGenerator puts slice_a on gu_a's
## own boundary column, slice_b on gu_b's, one voxel further out in the
## NEIGHBOUR GU (see slice_voxel_positions()). A same-size roof therefore
## looks unfinished at every wall it caps. Fix, per Director (2026-07-16):
## the roof's footprint genuinely grows — a real, tracked Slab covering the
## wider area, not a cosmetic untracked fill. A synthetic non-owned border
## would be a second truth that has to be remembered and reconciled later;
## a wider real Slab is still exactly one truth, just a bigger one.
##
## Per-SIDE border, not a uniform one: a multi-GU structure's own INTERNAL
## GU-GU seams have no wall and must not each grow a border toward each
## other — that would be guaranteed self-overlap between two Slabs of the
## SAME structure, every time, not the rare cross-structure case Director
## judged acceptable to leave undefended. Callers building a multi-cell
## structure pass 0 for whichever sides face another cell of that same
## structure; every side defaults to 1 (the common single-GU case needs no
## per-side reasoning at the call site at all).
static func generate_with_border(
	gu_cell: Vector2i, role: int, level: int, material: String, registry: SlabRegistry,
	border_west: int = 1, border_east: int = 1, border_north: int = 1, border_south: int = 1
) -> Slab:
	var slab_id := "SLAB_%d_%d_%s_%d" % [gu_cell.x, gu_cell.y, Slab.role_name(role), level]
	var slab := Slab.new(slab_id, gu_cell, role, level, material)

	var base_origin: Vector2i = GeometryCoords.gu_to_voxel_origin(gu_cell)
	var x_start: int = base_origin.x - border_west
	var x_end: int = base_origin.x + GeometryCoords.VOXELS_PER_UNIT_AXIS + border_east
	var y_start: int = base_origin.y - border_north
	var y_end: int = base_origin.y + GeometryCoords.VOXELS_PER_UNIT_AXIS + border_south

	for y in range(y_start, y_end):
		for x in range(x_start, x_end):
			var voxel := Voxel.new(Vector2i(x, y), level, slab)
			slab.voxels.append(voxel)

	registry.register_slab(slab)
	return slab
