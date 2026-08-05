## DamageVariantBaker — D-ARCH-01 Phase 2
##
## Pre-bakes CRACKED/DENTED damage-decal variants for placed wall/ceiling/
## zoned-floor voxels at map-load time, driving the SAME compositor functions
## (VoxelRenderer._composite_full_voxel_decal() etc.) the D33 runtime path
## already uses for the identical inputs — same pixels, computed once here
## instead of lazily at detonation time. Results are registered into a
## VoxelVariantRegistry that VoxelRenderer.apply_damage_voxel_swap() consults
## before falling back to D33 runtime compositing.
##
## Scope is derived from what VoxelRenderer._set_voxel_cell()'s own dispatch
## actually reaches for each container type — not every theoretical
## combination:
##   - Wall Slice (edge != null): DENTED (bullet/blast, LEFT/RIGHT, 3
##     variants) + CRACKED (bullet LEFT/RIGHT, 3 variants, every material;
##     blast "_all_", 3 variants, only IMPACT_CRACK_MATERIALS).
##   - Ceiling Slab (role == CEILING): DENTED blast BOTTOM only, no variant —
##     _ceiling_carve_plan()/_composite_ceiling_carve() is a silhouette carve
##     with nothing to vary.
##   - Zoned-floor Slab (role == FLOOR, zoned): DENTED blast TOP only, 3
##     variants — _floor_sunk_decal_plan()/_composite_floor_sunk_decal(),
##     always the shared "earth" family (floor_damage_material()'s own rule)
##     regardless of the real zone material.
##   - INTERIOR slabs and plain (unzoned) earth floors are skipped entirely:
##     neither ever reaches the baked D33 path (_set_voxel_cell()'s
##     edge/flat_baked gates never admit them — edge is always null for
##     slabs, and flat_baked is false for INTERIOR and for an unzoned floor).
##     Both already render through the cheap generic/vector fallback (D33
##     Part 4b), so there is nothing expensive to pre-bake there.
##   - CRACKED never occurs on ceiling/floor Slabs in the real game (neither
##     asset family recognizes it), so it is never enumerated for them.
##
## Soot is never part of this: it is a per-cell modulate-alpha code
## (VoxelLightField.encode_face_soot()) applied by the light-repaint pass
## after any set_cell(), independent of which tile a cell shows.

class_name DamageVariantBaker
extends RefCounted

var _renderer: VoxelRenderer
var _registry: VoxelVariantRegistry


func _init(renderer: VoxelRenderer, registry: VoxelVariantRegistry) -> void:
	_renderer = renderer
	_registry = registry


## Bakes every reachable DENTED/CRACKED variant for one placed, visible wall
## voxel. Call once per voxel in a Slice.
func bake_wall_voxel(voxel: Voxel, slice: Slice, edge: Edge) -> void:
	var material: String = slice.material
	var voxel_xy := Vector2i(voxel.grid_pos.x % 8, voxel.grid_pos.y % 8)
	for name in _wall_variant_names(material):
		_bake_and_register(name, material, voxel.grid_pos, voxel.level,
			edge, slice.face, voxel_xy, false, "")


## Bakes the single reachable DENTED-bottom variant for one placed, visible
## ceiling voxel. Call once per voxel in a CEILING-role Slab.
func bake_ceiling_voxel(voxel: Voxel, slab: Slab) -> void:
	var name: String = VoxelRenderer.damage_variant_material(
		slab.material, Voxel.DamageState.DENTED, true, Voxel.CarvedSide.BOTTOM, 0)
	_bake_and_register(name, slab.material, voxel.grid_pos, voxel.level,
		null, 0, Vector2i.ZERO, true, "")


## Bakes the 3 reachable DENTED-top variants for one placed, visible zoned-
## floor voxel. `zone_material` is the real ground material (e.g.
## "ground_concrete") — needed to resolve the baked substrate; the registered
## name/key always use the shared "earth" family, matching
## VoxelRenderer.floor_damage_material()'s own rule. Call once per voxel in a
## FLOOR-role, zoned Slab.
func bake_zoned_floor_voxel(voxel: Voxel, slab: Slab) -> void:
	for variant in range(VoxelRenderer.IMPACT_DECAL_VARIANTS):
		var name: String = VoxelRenderer.floor_damage_material(
			Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, variant)
		_bake_and_register(name, VoxelRenderer.IMPACT_FLOOR_MATERIAL,
			voxel.grid_pos, voxel.level, null, 0,
			voxel.grid_pos - slab.texture_anchor, true, slab.material)


## Every reachable damage_variant_material() name for a wall material —
## mirrors _decal_material()'s own gating (_is_lateral_side() restriction,
## IMPACT_CRACK_MATERIALS) rather than re-deriving which combos are valid.
func _wall_variant_names(material: String) -> Array[String]:
	var names: Array[String] = []
	var sides := [Voxel.CarvedSide.LEFT, Voxel.CarvedSide.RIGHT]
	for variant in range(VoxelRenderer.IMPACT_DECAL_VARIANTS):
		for side in sides:
			names.append(VoxelRenderer.damage_variant_material(
				material, Voxel.DamageState.DENTED, false, side, variant))
			names.append(VoxelRenderer.damage_variant_material(
				material, Voxel.DamageState.DENTED, true, side, variant))
			names.append(VoxelRenderer.damage_variant_material(
				material, Voxel.DamageState.CRACKED, false, side, variant))
		if VoxelRenderer.IMPACT_CRACK_MATERIALS.has(material):
			names.append(VoxelRenderer.damage_variant_material(
				material, Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE, variant))
	return names


## Resolves one name through the same plan parsers _set_voxel_cell() uses —
## mutually exclusive by construction (see VoxelRenderer._full_voxel_decal_plan()'s
## own comment), so trying them is order-independent — and registers the
## composited result. A miss (no plan matched, or the composite function
## itself returned {} — missing decal asset, no baked atom here) leaves the
## registry without this entry; apply_damage_voxel_swap() then falls back to
## D33 runtime compositing for that one cell exactly as it does today.
func _bake_and_register(material_name: String, container_material: String,
		grid_pos: Vector2i, level: int, edge: Edge, slice_face: int, voxel_xy: Vector2i,
		flat_baked: bool, zone_material: String) -> void:
	var entry: Dictionary = {}
	if edge != null:
		var full_plan := VoxelRenderer._full_voxel_decal_plan(material_name)
		if not full_plan.is_empty():
			entry = _renderer._composite_full_voxel_decal(
				full_plan, material_name, edge, slice_face, voxel_xy, level, grid_pos)
		else:
			var half_plan := VoxelRenderer._half_voxel_decal_plan(material_name)
			if not half_plan.is_empty():
				entry = _renderer._composite_half_voxel_decal(
					half_plan, material_name, edge, slice_face, voxel_xy, level, grid_pos)
	elif flat_baked:
		var ceiling_plan := VoxelRenderer._ceiling_carve_plan(material_name)
		if not ceiling_plan.is_empty():
			entry = _renderer._composite_ceiling_carve(
				ceiling_plan, material_name, voxel_xy, level, grid_pos)
		elif zone_material != "":
			var floor_plan := VoxelRenderer._floor_sunk_decal_plan(material_name)
			if not floor_plan.is_empty():
				entry = _renderer._composite_floor_sunk_decal(
					floor_plan, material_name, zone_material, voxel_xy, level, grid_pos)

	if entry.is_empty():
		return

	var cell_key := VoxelVariantRegistry.make_cell_key(grid_pos, level, container_material)
	_registry.register(cell_key, material_name, entry["source_id"], entry["atlas_coords"])
