## DESTRUCTION_MASTER_PLAN — roof/ceiling ("laje") geometry selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/roof_slab_selftest.gd
##
## Proves the "2+ levels, ALL destructible, existing wall material" roof
## model this session's Director asked for: unlike the floor (1 destructible
## Slab + 7 fixed non-Slab levels, D13), a roof is N independent Slabs, one
## per level, each fully destructible — falls out of calling the EXISTING
## SlabGenerator N times, zero new geometry classes needed. No bake system
## involved yet (Director's call: geometry first, bake as a later
## experiment) — render_slab_solid() places one fixed wall material per
## voxel, the same way render_block() already does for a whole block, just
## through Slab/Voxel so every level is independently dirty-tracked.

extends SceneTree

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION — Roof/Ceiling ('Laje') SELFTEST")
	print("=".repeat(70) + "\n")

	test_multi_level_roof_is_n_independent_slabs()
	test_render_slab_solid_uses_fixed_material_no_hash()
	test_each_roof_level_independently_destructible()
	test_roof_positioned_above_a_block_uses_the_blocks_own_material()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ ROOF SLAB SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ ROOF SLAB SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## "2 ou mais slabs de altura" — a 3-level roof is just 3 calls to the
## EXISTING SlabGenerator.generate(), one per level. No new class needed.
func test_multi_level_roof_is_n_independent_slabs() -> void:
	print("[1] N-level roof = N independent Slab instances (no new geometry class)\n")

	var registry := SlabRegistry.new()
	var gu := Vector2i(4, 4)
	var roof_levels: Array[Slab] = []
	for level in range(8, 11):  # 3 levels: 8, 9, 10 (sitting above a 1-storey block, levels 0-7)
		roof_levels.append(SlabGenerator.generate(gu, Slab.Role.CEILING, level, "wood", registry))

	if roof_levels.size() == 3:
		_pass("3 Slab instances created for a 3-level roof")
	else:
		_fail("Expected 3 Slab instances, got %d" % roof_levels.size())

	var distinct_ids: Dictionary = {}
	for slab in roof_levels:
		distinct_ids[slab.id] = true
	if distinct_ids.size() == 3:
		_pass("All 3 roof-level Slabs have distinct ids (%s)" % [distinct_ids.keys()])
	else:
		_fail("Roof-level Slabs collided on id: only %d distinct" % distinct_ids.size())

	if registry.all_slabs().size() == 3:
		_pass("SlabRegistry holds all 3 roof-level Slabs")
	else:
		_fail("SlabRegistry has %d slabs, expected 3" % registry.all_slabs().size())

	print("")


## render_slab_solid() must place slab.material directly, no per-voxel
## variant selection — the whole point for a roof matching its structure's
## material 1:1.
func test_render_slab_solid_uses_fixed_material_no_hash() -> void:
	print("[2] render_slab_solid() places ONE fixed material, no hash\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	var registry := SlabRegistry.new()
	var gu := Vector2i(1, 1)
	var slab := SlabGenerator.generate(gu, Slab.Role.CEILING, 8, "stone", registry)
	renderer.render_slab_solid(slab)

	var layer: TileMapLayer = renderer.get_layer(8)
	var expected_source_id: int = VoxelRendererClass.MATERIALS.find("stone")
	var mismatches := 0
	var checked := 0
	for voxel_pos in GeometryCoordsClass.gu_voxels(gu):
		checked += 1
		if layer.get_cell_source_id(voxel_pos) != expected_source_id:
			mismatches += 1

	if checked == 64 and mismatches == 0:
		_pass("All 64 cells placed with 'stone' (source_id=%d), zero variance across the GU" % expected_source_id)
	else:
		_fail("%d/%d cells did not match the fixed 'stone' material" % [mismatches, checked])

	renderer.queue_free()
	print("")


## D13's floor had exactly ONE destructible level by design (D5/D6's shallow-
## dig constraint). A roof is different on purpose: ALL levels destructible,
## independently. Prove damaging one level's Slab never touches another's.
func test_each_roof_level_independently_destructible() -> void:
	print("[3] Every roof level is independently destructible (unlike the floor's fixed levels)\n")

	var registry := SlabRegistry.new()
	var gu := Vector2i(2, 2)
	var level_8 := SlabGenerator.generate(gu, Slab.Role.CEILING, 8, "concrete", registry)
	var level_9 := SlabGenerator.generate(gu, Slab.Role.CEILING, 9, "concrete", registry)
	var level_10 := SlabGenerator.generate(gu, Slab.Role.CEILING, 10, "concrete", registry)

	level_9.voxels[0].set_damage(Voxel.DamageState.DESTROYED)

	if level_9.dirty_count == 1 and level_8.dirty_count == 0 and level_10.dirty_count == 0:
		_pass("Damaging level 9 left levels 8 and 10 untouched (dirty_count 0 each)")
	else:
		_fail("Cross-contamination: level8=%d level9=%d level10=%d" % [
			level_8.dirty_count, level_9.dirty_count, level_10.dirty_count,
		])

	level_8.voxels[0].set_damage(Voxel.DamageState.DESTROYED)
	level_10.voxels[0].set_damage(Voxel.DamageState.DESTROYED)

	if registry.dirty_slabs().size() == 3:
		_pass("All 3 levels can be independently dirty simultaneously (3/3 registered as dirty)")
	else:
		_fail("Expected all 3 levels dirty, registry reports %d" % registry.dirty_slabs().size())

	print("")


## "posicionar sobre as estruturas quadradas que já estão presentes... usando
## a mesma arte das paredes que tem o mesmo material" — simulate a real block
## (material "wood", occupying storey 0 = levels 0-7) and place a 2-level
## roof starting at level 8, using the BLOCK's own material, not a hardcoded one.
func test_roof_positioned_above_a_block_uses_the_blocks_own_material() -> void:
	print("[4] Roof positioned above a simulated block, matching its material\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	# Simulate the block itself via the existing, proven wall-material path.
	var block_gu := Vector2i(7, 3)
	var block_material := "wood"
	renderer.render_block(block_gu, 0, 1, block_material)  # storey 0 = levels 0-7

	# Roof starts immediately above the block's top level (7 -> roof at 8, 9).
	var block_top_level := 7
	var registry := SlabRegistry.new()
	var roof_slabs: Array[Slab] = []
	for level in range(block_top_level + 1, block_top_level + 3):  # 8, 9
		var roof_slab := SlabGenerator.generate(block_gu, Slab.Role.CEILING, level, block_material, registry)
		roof_slabs.append(roof_slab)
		renderer.render_slab_solid(roof_slab)

	var block_layer: TileMapLayer = renderer.get_layer(0)
	var roof_layer_8: TileMapLayer = renderer.get_layer(8)
	var roof_layer_9: TileMapLayer = renderer.get_layer(9)

	var sample_voxel: Vector2i = GeometryCoordsClass.gu_voxels(block_gu)[0]
	var wood_id: int = VoxelRendererClass.MATERIALS.find("wood")

	if block_layer.get_cell_source_id(sample_voxel) == wood_id \
	and roof_layer_8.get_cell_source_id(sample_voxel) == wood_id \
	and roof_layer_9.get_cell_source_id(sample_voxel) == wood_id:
		_pass("Block (level 0) and both roof levels (8, 9) all render 'wood' — material matches the structure below")
	else:
		_fail("Material mismatch between block and roof — block=%d roof8=%d roof9=%d expected=%d" % [
			block_layer.get_cell_source_id(sample_voxel), roof_layer_8.get_cell_source_id(sample_voxel),
			roof_layer_9.get_cell_source_id(sample_voxel), wood_id,
		])

	if roof_slabs.size() == 2 and registry.all_slabs().size() == 2:
		_pass("Roof is 2 independent Slabs, both registered")
	else:
		_fail("Expected 2 roof Slabs registered, got %d" % registry.all_slabs().size())

	renderer.queue_free()
	print("")
