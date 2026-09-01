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

## OCC-FIX-03c (2026-09-01) — LEVEL-RENUMBER RESIDUE. Every fixture below used to
## spell its levels as 8, 9, 10, back when a 1-storey block occupied levels 0..7.
## After the renumber a block at storey 0 occupies 80..87, so those literals put
## the "roof" SEVENTY-TWO LEVELS BELOW the block it is named for — test [4] read
## its block from `get_layer(PLAYABLE_LEVEL)` and its roof from `get_layer(8)` and
## still passed, because it only ever asserted material, never the spatial
## relation. The numbers are derived now, so a future renumber moves them all.
const CEILING_LEVEL: int = GeometryCoordsClass.PLAYABLE_LEVEL + GeometryCoordsClass.LEVELS_PER_STOREY

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
	test_border_expands_footprint_to_10x10_offset_by_minus_one()
	test_border_per_side_zero_skips_that_side_only()
	test_adjacent_multi_gu_roofs_do_not_self_overlap()

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
	for level in range(CEILING_LEVEL, CEILING_LEVEL + 3):  # 3 levels, sitting above a 1-storey block
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
	var slab := SlabGenerator.generate(gu, Slab.Role.CEILING, CEILING_LEVEL, "stone", registry)
	renderer.render_slab_solid(slab)

	var layer: TileMapLayer = renderer.get_layer(CEILING_LEVEL)
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
	var roof_lo := SlabGenerator.generate(gu, Slab.Role.CEILING, CEILING_LEVEL, "concrete", registry)
	var roof_mid := SlabGenerator.generate(gu, Slab.Role.CEILING, CEILING_LEVEL + 1, "concrete", registry)
	var roof_hi := SlabGenerator.generate(gu, Slab.Role.CEILING, CEILING_LEVEL + 2, "concrete", registry)

	roof_mid.voxels[0].set_damage(Voxel.DamageState.DESTROYED)

	if roof_mid.dirty_count == 1 and roof_lo.dirty_count == 0 and roof_hi.dirty_count == 0:
		_pass("Damaging the middle roof level left the one below and the one above untouched (dirty_count 0 each)")
	else:
		_fail("Cross-contamination: lo=%d mid=%d hi=%d" % [
			roof_lo.dirty_count, roof_mid.dirty_count, roof_hi.dirty_count,
		])

	roof_lo.voxels[0].set_damage(Voxel.DamageState.DESTROYED)
	roof_hi.voxels[0].set_damage(Voxel.DamageState.DESTROYED)

	if registry.dirty_slabs().size() == 3:
		_pass("All 3 levels can be independently dirty simultaneously (3/3 registered as dirty)")
	else:
		_fail("Expected all 3 levels dirty, registry reports %d" % registry.dirty_slabs().size())

	print("")


## "posicionar sobre as estruturas quadradas que já estão presentes... usando
## a mesma arte das paredes que tem o mesmo material" — simulate a real block
## (material "wood", occupying storey 0) and place a 2-level roof starting at the
## level immediately above it, using the BLOCK's own material, not a hardcoded one.
func test_roof_positioned_above_a_block_uses_the_blocks_own_material() -> void:
	print("[4] Roof positioned above a simulated block, matching its material\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	# Simulate the block itself via the existing, proven wall-material path.
	var block_gu := Vector2i(7, 3)
	var block_material := "wood"
	renderer.render_block(block_gu, 0, 1, block_material)  # storey 0

	## Roof starts immediately above the block's top level — DERIVED from the
	## storey the block was actually rendered at, never a transcribed number.
	var block_top_level: int = CEILING_LEVEL - 1
	var registry := SlabRegistry.new()
	var roof_slabs: Array[Slab] = []
	for level in range(block_top_level + 1, block_top_level + 3):
		var roof_slab := SlabGenerator.generate(block_gu, Slab.Role.CEILING, level, block_material, registry)
		roof_slabs.append(roof_slab)
		renderer.render_slab_solid(roof_slab)

	var block_layer: TileMapLayer = renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL)
	var roof_layer_lo: TileMapLayer = renderer.get_layer(CEILING_LEVEL)
	var roof_layer_hi: TileMapLayer = renderer.get_layer(CEILING_LEVEL + 1)

	var sample_voxel: Vector2i = GeometryCoordsClass.gu_voxels(block_gu)[0]
	var wood_id: int = VoxelRendererClass.MATERIALS.find("wood")

	if block_layer.get_cell_source_id(sample_voxel) == wood_id \
	and roof_layer_lo.get_cell_source_id(sample_voxel) == wood_id \
	and roof_layer_hi.get_cell_source_id(sample_voxel) == wood_id:
		_pass("Block (level %d) and both roof levels (%d, %d) all render 'wood' — material matches the structure below" % [
			GeometryCoords.PLAYABLE_LEVEL, CEILING_LEVEL, CEILING_LEVEL + 1,
		])
	else:
		_fail("Material mismatch between block and roof — block=%d roof_lo=%d roof_hi=%d expected=%d" % [
			block_layer.get_cell_source_id(sample_voxel), roof_layer_lo.get_cell_source_id(sample_voxel),
			roof_layer_hi.get_cell_source_id(sample_voxel), wood_id,
		])

	if roof_slabs.size() == 2 and registry.all_slabs().size() == 2:
		_pass("Roof is 2 independent Slabs, both registered")
	else:
		_fail("Expected 2 roof Slabs registered, got %d" % registry.all_slabs().size())

	renderer.queue_free()
	print("")


## Director, 2026-07-16: a roof's footprint must genuinely grow to reach the
## wall's outer slice (SliceGenerator puts it one voxel into the neighbour
## GU) — 8x8 -> 10x10, origin shifted -1 voxel on both axes. A real, tracked
## Slab, not a cosmetic fill: "a verdade nunca precisa ser lembrada."
func test_border_expands_footprint_to_10x10_offset_by_minus_one() -> void:
	print("[5] generate_with_border() — default border=1 on all sides: 10x10, origin -1,-1\n")

	var registry := SlabRegistry.new()
	var gu := Vector2i(5, 5)
	var slab := SlabGenerator.generate_with_border(gu, Slab.Role.CEILING, CEILING_LEVEL, "concrete", registry)

	if slab.voxels.size() == 100:
		_pass("100 voxels (10x10), not 64 — the footprint genuinely grew")
	else:
		_fail("Expected 100 voxels, got %d" % slab.voxels.size())

	var expected_origin: Vector2i = GeometryCoordsClass.gu_to_voxel_origin(gu) - Vector2i(1, 1)
	var positions: Dictionary = {}
	for voxel in slab.voxels:
		positions[voxel.grid_pos] = true

	var origin_present := positions.has(expected_origin)
	var far_corner_present := positions.has(expected_origin + Vector2i(9, 9))
	if origin_present and far_corner_present:
		_pass("Footprint spans exactly [origin-1, origin+8] on both axes — corners %s and %s present" % [
			expected_origin, expected_origin + Vector2i(9, 9),
		])
	else:
		_fail("Expected corners missing: origin_present=%s far_corner_present=%s" % [origin_present, far_corner_present])

	print("")


## Per-side control is the actual point, not a nice-to-have: a side set to 0
## must be excluded, independently of the other 3 sides staying at 1.
func test_border_per_side_zero_skips_that_side_only() -> void:
	print("[6] generate_with_border() — per-side border, one side zeroed\n")

	var registry := SlabRegistry.new()
	var gu := Vector2i(0, 0)
	## West=0 (no border on the -x side), other 3 sides default to 1.
	var slab := SlabGenerator.generate_with_border(gu, Slab.Role.CEILING, CEILING_LEVEL, "concrete", registry, 0)

	## 9 wide (no west extension, +1 east) x 10 tall (+1 north, +1 south) = 90.
	if slab.voxels.size() == 90:
		_pass("90 voxels (9x10) — west border correctly suppressed, other 3 sides still expanded")
	else:
		_fail("Expected 90 voxels (west=0, others=1), got %d" % slab.voxels.size())

	var base_origin: Vector2i = GeometryCoordsClass.gu_to_voxel_origin(gu)
	var positions: Dictionary = {}
	for voxel in slab.voxels:
		positions[voxel.grid_pos] = true

	if not positions.has(base_origin - Vector2i(1, 0)):
		_pass("The west-border voxel (origin.x - 1) is genuinely absent")
	else:
		_fail("West-border voxel present despite border_west=0")

	if positions.has(base_origin - Vector2i(0, 1)):
		_pass("The north-border voxel (origin.y - 1) is present (border_north still defaults to 1)")
	else:
		_fail("North-border voxel missing even though border_north was not zeroed")

	print("")


## The whole reason per-side control exists: two GUs of the SAME multi-GU
## structure, adjacent to each other, must not grow borders toward one
## another — that would self-overlap deterministically, not rarely. Simulate
## room_builder.gd's own per-side computation for a 2x1 block.
func test_adjacent_multi_gu_roofs_do_not_self_overlap() -> void:
	print("[7] Two adjacent same-structure roof Slabs: zero self-overlap at the shared seam\n")

	var registry := SlabRegistry.new()
	var gu_left := Vector2i(10, 10)
	var gu_right := Vector2i(11, 10)  # block_size = Vector2i(2, 1), rx=0 and rx=1

	## Mirrors room_builder.gd's per-side computation for a 2x1 block:
	## left cell (rx=0): west=1 (true outer edge), east=0 (faces the right cell).
	## right cell (rx=1, last): west=0 (faces the left cell), east=1 (true outer edge).
	var slab_left := SlabGenerator.generate_with_border(gu_left, Slab.Role.CEILING, CEILING_LEVEL, "concrete", registry, 1, 0, 1, 1)
	var slab_right := SlabGenerator.generate_with_border(gu_right, Slab.Role.CEILING, CEILING_LEVEL, "concrete", registry, 0, 1, 1, 1)

	var left_positions: Dictionary = {}
	for voxel in slab_left.voxels:
		left_positions[voxel.grid_pos] = true
	var right_positions: Dictionary = {}
	for voxel in slab_right.voxels:
		right_positions[voxel.grid_pos] = true

	var overlap := 0
	for pos in left_positions.keys():
		if right_positions.has(pos):
			overlap += 1

	if overlap == 0:
		_pass("Zero shared voxel positions between the two adjacent same-structure roof Slabs")
	else:
		_fail("%d overlapping voxel positions between adjacent roof Slabs — self-overlap bug" % overlap)

	## Both still 9x10 = 90 (one side suppressed each, matching test 6's shape).
	if slab_left.voxels.size() == 90 and slab_right.voxels.size() == 90:
		_pass("Both cells are 90 voxels (9x10) — only their true outer sides expanded")
	else:
		_fail("Expected both at 90 voxels, got left=%d right=%d" % [slab_left.voxels.size(), slab_right.voxels.size()])

	print("")
