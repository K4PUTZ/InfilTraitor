## DESTRUCTION_MASTER_PLAN Part 2 — consumer wave selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/slab_render_selftest.gd
##
## Proves SlabGenerator builds real Voxels and that the floor's two Slabs are independent containers.
## R3D-END: the three tests that read the TILE each voxel was placed as (the earth-variant hash round trip, the re-render
## idempotence, the carved floor-dent asset) went with the 2D board; the 3D board draws the store, not those tiles.

extends SceneTree

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION Part 2 — Slab render consumer SELFTEST")
	print("=".repeat(70) + "\n")

	test_slab_generator_produces_64_voxels()
	test_d13_two_layer_floor_independent_containers()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ SLAB RENDER SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ SLAB RENDER SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func test_slab_generator_produces_64_voxels() -> void:
	print("[1] SlabGenerator.generate() — 64 voxels, correct grid positions\n")

	var registry := SlabRegistry.new()
	var gu := Vector2i(2, 2)
	var slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_TOP_LEVEL, "earth", registry)

	if slab.voxels.size() == 64:
		_pass("Generated Slab has 64 voxels (VOXELS_PER_UNIT_AXIS^2)")
	else:
		_fail("Expected 64 voxels, got %d" % slab.voxels.size())

	var expected_positions: Array = GeometryCoordsClass.gu_voxels(gu)
	var actual_positions: Array = []
	for voxel in slab.voxels:
		actual_positions.append(voxel.grid_pos)

	var positions_match := true
	for pos in expected_positions:
		if not actual_positions.has(pos):
			positions_match = false
	if positions_match:
		_pass("All 64 voxel grid_pos match GeometryCoords.gu_voxels(gu) exactly")
	else:
		_fail("Voxel positions don't match gu_voxels(gu)")

	if registry.get_slab(slab.id) == slab:
		_pass("Slab registered in SlabRegistry under its own id")
	else:
		_fail("Slab not retrievable from registry by id")

	print("")


## D13: floor is TWO Slabs at the same gu_cell (destructible top, fixed
## bottom) — not one. Prove they're genuinely independent containers: marking
## the top dirty must never touch the bottom's dirty_count, matching the same
## cross-contamination check Part 1 already proved for Slice vs. Slab.
func test_d13_two_layer_floor_independent_containers() -> void:
	print("[4] D13 — destructible top Slab and fixed bottom Slab are independent containers\n")

	var registry := SlabRegistry.new()
	var gu := Vector2i(4, 4)
	## OCC-FIX-03c (2026-09-01) — LEVEL-RENUMBER RESIDUE, and the two labels had
	## swapped with it: the DESTRUCTIBLE floor level is FLOOR_TOP_LEVEL and the one
	## under it is FLOOR_DEEP_LEVEL (GeometryCoords' own ground-stack block). The
	## literal `1` was the pre-renumber destructible level and now sits 78 levels
	## below the ground stack; the test passed anyway because all it needs is two
	## distinct levels at one GU.
	var top_slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_TOP_LEVEL, "earth", registry)
	var bottom_slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_DEEP_LEVEL, "earth", registry)

	## RENDER3D R3D-1d: `Voxel` has no state of its own — set_damage() below needs an
	## active store built over this fixture's registry.
	VoxelStore.active = VoxelStore.build(EdgeRegistry.new(), registry, [])

	if top_slab.id != bottom_slab.id:
		_pass("Top and bottom Slabs at the same GU have distinct ids (%s vs %s)" % [top_slab.id, bottom_slab.id])
	else:
		_fail("Top and bottom Slabs collided on the same id")

	top_slab.voxels[0].set_damage(Voxel.DamageState.DESTROYED)

	if top_slab.dirty_count == 1 and bottom_slab.dirty_count == 0:
		_pass("Damaging the destructible (top) Slab left the fixed (bottom) Slab's dirty_count at 0")
	else:
		_fail("Cross-contamination: top.dirty_count=%d, bottom.dirty_count=%d" % [top_slab.dirty_count, bottom_slab.dirty_count])

	if registry.dirty_slabs().size() == 1 and registry.dirty_slabs()[0] == top_slab:
		_pass("SlabRegistry.dirty_slabs() reports only the destructible top slab, never the deep one")
	else:
		_fail("dirty_slabs() reported the wrong set: %s" % [registry.dirty_slabs()])

	print("")
