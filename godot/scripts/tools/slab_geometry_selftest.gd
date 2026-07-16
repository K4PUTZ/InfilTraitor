## DESTRUCTION_MASTER_PLAN D1/Part 1 — Slab container selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/slab_geometry_selftest.gd
## Mirrors the Slice/EdgeRegistry contract Slab is built to match: dirty-count
## propagation from Voxel, clear-all, and the TIC-skip shape (dirty_slabs() returns
## only what's actually dirty, empty means truly free).

extends SceneTree

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION D1/Part 1 — Slab/SlabRegistry SELFTEST")
	print("=".repeat(70) + "\n")

	test_slab_identity_and_voxel_count()
	test_voxel_dirty_propagates_to_slab()
	test_clear_all_dirty_resets_count_and_flags()
	test_voxel_reuse_across_slice_and_slab()
	test_registry_dirty_skip_contract()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ SLAB SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ SLAB SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## D1: a Slab identifies a GU's horizontal voxel layer for one role (floor/
## ceiling/interior) at one level, and holds VOXELS_PER_UNIT_AXIS² voxels —
## same 64-voxel granularity as one storey-level of a Slice.
func test_slab_identity_and_voxel_count() -> void:
	print("[1] Slab identity and voxel count (64 = VOXELS_PER_UNIT_AXIS²)\n")

	var gu := Vector2i(3, 4)
	var slab := Slab.new("SLAB_3_4_FLOOR_0", gu, Slab.Role.FLOOR, 0, "concrete")

	for voxel_pos in GeometryCoords.gu_voxels(gu):
		slab.voxels.append(Voxel.new(voxel_pos, 0, slab))

	if slab.total_voxel_count() == 64:
		_pass("Slab holds 64 voxels for one GU at one level")
	else:
		_fail("Expected 64 voxels, got %d" % slab.total_voxel_count())

	if Slab.role_name(slab.role) == "FLOOR":
		_pass("Slab.role_name(FLOOR) == 'FLOOR'")
	else:
		_fail("role_name mismatch: %s" % Slab.role_name(slab.role))

	if slab.dirty_count == 0:
		_pass("Freshly built Slab starts with dirty_count == 0")
	else:
		_fail("Freshly built Slab should have dirty_count 0, got %d" % slab.dirty_count)

	print("")


## Mirrors Slice's contract: a child Voxel going dirty must increment its
## container's dirty_count exactly once, regardless of container type.
func test_voxel_dirty_propagates_to_slab() -> void:
	print("[2] Voxel.set_visible() propagates dirty to parent Slab\n")

	var gu := Vector2i(0, 0)
	var slab := Slab.new("SLAB_0_0_CEILING_8", gu, Slab.Role.CEILING, 8, "stone")
	var voxel := Voxel.new(Vector2i(0, 0), 8, slab)
	slab.voxels.append(voxel)

	voxel.set_visible(false)

	if slab.dirty_count == 1:
		_pass("dirty_count == 1 after one voxel goes dirty")
	else:
		_fail("Expected dirty_count 1, got %d" % slab.dirty_count)

	if voxel.dirty:
		_pass("Voxel.dirty == true")
	else:
		_fail("Voxel.dirty should be true")

	# Setting the same value again must be a no-op (Voxel.set_visible early-returns
	# on unchanged value) — dirty_count must NOT double-increment.
	voxel.set_visible(false)
	if slab.dirty_count == 1:
		_pass("Redundant set_visible(false) does not double-increment dirty_count")
	else:
		_fail("dirty_count changed on a no-op set: %d" % slab.dirty_count)

	print("")


## Mirrors Slice.clear_all_dirty(): the TIC's per-container reset must zero both
## the counter and every child Voxel's flag, not just one or the other.
func test_clear_all_dirty_resets_count_and_flags() -> void:
	print("[3] Slab.clear_all_dirty() resets counter and every child flag\n")

	var gu := Vector2i(1, 1)
	var slab := Slab.new("SLAB_1_1_FLOOR_0", gu, Slab.Role.FLOOR, 0, "wood")
	for voxel_pos in GeometryCoords.gu_voxels(gu):
		slab.voxels.append(Voxel.new(voxel_pos, 0, slab))

	# Damage 5 voxels (DESTROYED forces visible=false, same as Slice's contract)
	for i in range(5):
		slab.voxels[i].set_damage(Voxel.DamageState.DESTROYED)

	if slab.dirty_count == 5:
		_pass("dirty_count == 5 after damaging 5 voxels")
	else:
		_fail("Expected dirty_count 5, got %d" % slab.dirty_count)

	slab.clear_all_dirty()

	if slab.dirty_count == 0:
		_pass("dirty_count == 0 after clear_all_dirty()")
	else:
		_fail("dirty_count should be 0 after clear, got %d" % slab.dirty_count)

	var any_still_dirty := false
	for voxel in slab.voxels:
		if voxel.dirty:
			any_still_dirty = true
	if not any_still_dirty:
		_pass("No voxel left with dirty == true after clear_all_dirty()")
	else:
		_fail("At least one voxel still dirty after clear_all_dirty()")

	# Damage state itself is NOT touched by clear_all_dirty() — only the dirty
	# flag is a TIC-processing marker; damage_state is persistent game state.
	if slab.voxels[0].damage_state == Voxel.DamageState.DESTROYED:
		_pass("clear_all_dirty() does not revert damage_state (dirty flag != game state)")
	else:
		_fail("damage_state was incorrectly reverted by clear_all_dirty()")

	print("")


## D1's whole point: Voxel is ONE class shared by Slice (wall) and Slab
## (floor/ceiling/interior). Prove both container types satisfy the exact same
## Voxel contract with no special-casing in Voxel itself.
func test_voxel_reuse_across_slice_and_slab() -> void:
	print("[4] Same Voxel class works unmodified under Slice AND Slab\n")

	var slice := Slice.new("SLICE_0_0_NW", Vector2i(0, 0), Face.NW, "EDGE_TEST", 1, "concrete")
	var slab := Slab.new("SLAB_0_0_FLOOR_0", Vector2i(0, 0), Slab.Role.FLOOR, 0, "concrete")

	var wall_voxel := Voxel.new(Vector2i(0, 0), 0, slice)
	var floor_voxel := Voxel.new(Vector2i(0, 0), 0, slab)
	slice.voxels.append(wall_voxel)
	slab.voxels.append(floor_voxel)

	wall_voxel.set_visible(false)
	floor_voxel.set_visible(false)

	if slice.dirty_count == 1 and slab.dirty_count == 1:
		_pass("Both Slice and Slab independently reach dirty_count == 1 via the same Voxel API")
	else:
		_fail("Slice.dirty_count=%d, Slab.dirty_count=%d (expected 1, 1)" % [slice.dirty_count, slab.dirty_count])

	# Single-writer sanity: marking the wall voxel dirty must never touch the
	# unrelated floor voxel's container, and vice versa.
	slice.clear_all_dirty()
	if slice.dirty_count == 0 and slab.dirty_count == 1:
		_pass("Clearing Slice does not affect the unrelated Slab (containers are independent)")
	else:
		_fail("Cross-contamination: slice.dirty_count=%d, slab.dirty_count=%d" % [slice.dirty_count, slab.dirty_count])

	print("")


## The TIC-skip contract SlabRegistry exists to serve: dirty_slabs() must return
## only slabs with dirty_count > 0, and an all-clean registry must report empty —
## the cheap early-out room.gd's _tic_slab_system() relies on every TIC.
func test_registry_dirty_skip_contract() -> void:
	print("[5] SlabRegistry.dirty_slabs() — the TIC-skip contract\n")

	var registry := SlabRegistry.new()
	var clean_slab := Slab.new("SLAB_CLEAN", Vector2i(0, 0), Slab.Role.FLOOR, 0, "concrete")
	var dirty_slab := Slab.new("SLAB_DIRTY", Vector2i(1, 0), Slab.Role.FLOOR, 0, "concrete")

	var clean_voxel := Voxel.new(Vector2i(0, 0), 0, clean_slab)
	var dirty_voxel := Voxel.new(Vector2i(8, 0), 0, dirty_slab)
	clean_slab.voxels.append(clean_voxel)
	dirty_slab.voxels.append(dirty_voxel)

	registry.register_slab(clean_slab)
	registry.register_slab(dirty_slab)

	if registry.dirty_slabs().is_empty():
		_pass("All-clean registry reports zero dirty slabs")
	else:
		_fail("Expected zero dirty slabs before any damage")

	dirty_voxel.set_damage(Voxel.DamageState.CRACKED)

	var dirty_result: Array = registry.dirty_slabs()
	if dirty_result.size() == 1 and dirty_result[0] == dirty_slab:
		_pass("dirty_slabs() returns exactly the one dirty slab, not the clean one")
	else:
		_fail("dirty_slabs() returned %d slabs, expected exactly [dirty_slab]" % dirty_result.size())

	if registry.all_slabs().size() == 2:
		_pass("all_slabs() still reports both registered slabs regardless of dirty state")
	else:
		_fail("all_slabs() size mismatch: %d" % registry.all_slabs().size())

	print("")
