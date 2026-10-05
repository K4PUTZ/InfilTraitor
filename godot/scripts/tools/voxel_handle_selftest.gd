## R3D-CLAIMS C1 Test: a claim reached WITHOUT its persistent object.
##
## `VoxelStore.voxel_of(claim)` builds a transient `Voxel` from the store's own arrays. R3D-CLAIMS removes the ~296 000 persistent
## wrappers (~990 B each on the Moto), so everything that today holds one has to be able to ask for it again, and the new one has
## to be INTERCHANGEABLE with the old: same cell, level, container, state, and the same dirty bit. What this pins, against the
## persistent objects of a real fixture (a banded slice, a slice sharing a corner cell, slabs, a junction column):
##
##  1. EVERY claim: `voxel_of()` answers the persistent voxel's grid_pos, level, claim, container id and state, and
##     `container_of()` is the container that holds it.
##  2. A write through a HANDLE is the persistent voxel's: damage, visibility, and the dirty bit (the container's `dirty_count`
##     moves once), and a clear through the PERSISTENT voxel clears the handle's.
##  3. Two handles of one claim share their dirty bit (it used to be per wrapper: that was the bug-in-waiting).
##  4. A claimless voxel (a detached fixture) keeps its own dirty flag and never touches the store's bits.
##  5. Mutation control: the check of (1) FAILS when a handle is built for the wrong claim.
extends SceneTree

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("R3D-CLAIMS C1 — voxel handle SELFTEST")
	print("=".repeat(70) + "\n")
	var fixture: Dictionary = _build_fixture()
	var store: VoxelStore = VoxelStore.build(fixture["edge_registry"], fixture["slab_registry"], fixture["columns"])
	if store == null:
		_check(false, "VoxelStore.build returned null")
	else:
		VoxelStore.active = store
		test_every_claim_matches(store)
		test_write_through_handle(store)
		test_handles_share_dirty(store)
		test_claimless_voxel_keeps_its_own_flag(store)
		test_mutation_control(store)
	VoxelStore.active = null
	print("\nvoxel handle SELFTEST: %s (%d passed, %d failed)\n" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	quit(1 if failed > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	if ok:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)


func _build_fixture() -> Dictionary:
	var base: int = GeometryCoords.storey_level_base(0)
	var slab_registry := SlabRegistry.new()
	var slab := Slab.new(Slab.make_id(Vector2i(1, 1), Slab.Role.FLOOR, 79), Vector2i(1, 1), Slab.Role.FLOOR, 79, "concrete")
	for y in range(2):
		for x in range(2):
			slab.voxels.append(Voxel.new(Vector2i(8 + x, 8 + y), 79, slab))
	slab_registry.register_slab(slab)
	var roof := Slab.new(Slab.make_id(Vector2i(4, 1), Slab.Role.CEILING, base + 4), Vector2i(4, 1), Slab.Role.CEILING, base + 4, "glass")
	for x in range(2):
		roof.voxels.append(Voxel.new(Vector2i(32 + x, 8), base + 4, roof))
	slab_registry.register_slab(roof)
	var edge_registry := EdgeRegistry.new()
	var row := Slice.new("SLICE_1_1_NE", Vector2i(1, 1), 1, "EDGE_1_1_NE", 1, "glass", 0)
	row.material_bands = {1: "brick"}
	for rel in range(2):
		for x in range(4):
			row.voxels.append(Voxel.new(Vector2i(8 + x, 8), base + rel, row))
	edge_registry.register_slice(row)
	var col := Slice.new("SLICE_1_1_NW", Vector2i(1, 1), 0, "EDGE_1_1_NW", 1, "glass", 0)
	col.material_bands = {1: "brick"}
	for rel in range(2):
		for y in range(3):
			col.voxels.append(Voxel.new(Vector2i(8, 8 + y), base + rel, col))
	edge_registry.register_slice(col)
	var column := JunctionResolver.JunctionColumn.new(Vector2i(3, 3), Vector2i(24, 24), 1, 0, "metal")
	return {"slab": slab, "roof": roof, "row": row, "col": col, "column": column, "columns": [column],
		"slab_registry": slab_registry, "edge_registry": edge_registry}


## The persistent voxel of a claim, found through the container's own order (not through the store's `voxel_of`).
func _persistent(store: VoxelStore, claim: int) -> Voxel:
	var ci: int = store.claim_container[claim]
	var range_: Vector2i = store.container_claims(ci)
	return store.containers[ci].voxels[claim - range_.x]


func _same(store: VoxelStore, claim: int, handle: Voxel) -> bool:
	var p: Voxel = _persistent(store, claim)
	return handle.grid_pos == p.grid_pos and handle.level == p.level and handle.claim == p.claim \
		and handle.container_id() == p.container_id() and handle.visible == p.visible \
		and handle.damage_state == p.damage_state


func test_every_claim_matches(store: VoxelStore) -> void:
	print("[TEST 1] every claim: the handle is the persistent voxel\n")
	var wrong: int = 0
	var wrong_container: int = 0
	for claim in range(store.claims):
		if not _same(store, claim, store.voxel_of(claim)):
			wrong += 1
		if store.container_of(claim).get_instance_id() != _persistent(store, claim).container_id():
			wrong_container += 1
	_check(store.claims > 0 and wrong == 0, "all %d claims: grid_pos, level, claim, container id, state agree (%d wrong)" % [store.claims, wrong])
	_check(wrong_container == 0, "`container_of()` is the container that holds each claim (%d wrong)" % wrong_container)


func test_write_through_handle(store: VoxelStore) -> void:
	print("[TEST 2] a write through a handle is the persistent voxel's\n")
	var claim: int = 5
	var p: Voxel = _persistent(store, claim)
	var container: Object = store.container_of(claim)
	var before: int = container.dirty_count
	var h: Voxel = store.voxel_of(claim)
	h.set_damage(Voxel.DamageState.DESTROYED)
	_check(p.damage_state == Voxel.DamageState.DESTROYED and not p.visible, "damage and visibility written through the handle read back on the persistent voxel")
	_check(p.dirty and h.dirty and store.dirty_bits[claim] == 1, "the dirty bit is set once, in the store, and both read it")
	_check(container.dirty_count == before + 1, "the container's dirty_count moved once (%d -> %d)" % [before, container.dirty_count])
	p.clear_dirty()
	_check(not h.dirty and store.dirty_bits[claim] == 0 and container.dirty_count == before, "a clear through the persistent voxel clears the handle's bit and the count")
	p.set_damage(Voxel.DamageState.INTACT)
	p.clear_dirty()


func test_handles_share_dirty(store: VoxelStore) -> void:
	print("[TEST 3] two handles of one claim share their dirty bit\n")
	var a: Voxel = store.voxel_of(7)
	var b: Voxel = store.voxel_of(7)
	var container: Object = store.container_of(7)
	var before: int = container.dirty_count
	a.set_visible(false)
	_check(b.dirty and container.dirty_count == before + 1, "the second handle sees the first one's dirty bit; the count moved once")
	b.set_visible(true)
	_check(container.dirty_count == before + 1, "a second write on the same claim does not count again")
	a.clear_dirty()
	_check(not b.dirty and container.dirty_count == before, "clearing through one handle clears the other")


func test_claimless_voxel_keeps_its_own_flag(store: VoxelStore) -> void:
	print("[TEST 4] a claimless voxel keeps its own dirty flag\n")
	var bits_before: int = 0
	for b in store.dirty_bits:
		bits_before += b
	var lone := Voxel.new(Vector2i(1, 1), 79, null)
	lone.dirty = true
	var bits_after: int = 0
	for b in store.dirty_bits:
		bits_after += b
	_check(lone.dirty and bits_after == bits_before, "the flag is its own and the store's bits are untouched")
	lone.dirty = false
	_check(not lone.dirty, "and it clears")


func test_mutation_control(store: VoxelStore) -> void:
	print("[TEST 5] the check fails for a handle of the WRONG claim\n")
	_check(not _same(store, 3, store.voxel_of(4)), "a handle built for claim 4 is not claim 3's voxel (the comparison can fail)")
