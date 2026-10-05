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
##  6. RELEASED containers (`VoxelStore.build(..., release_objects = true)`, C2): the persistent objects are gone, `voxel_at(i)` makes
##     ONE handle per claim and keeps it, `voxels` converts the container back to full objects that REUSE the handles already made
##     and match the cells the fixture was built with, `Stats` counts the conversion, and `clear_all_dirty()` clears the store's
##     bits without making a handle.
##  7. CELLS (C4): the generators fill `add_cell()` and make NO object; the store reads the cells; reading `voxels` before the store
##     turns the container into objects and `Stats.from_cells` counts it; after a store has bound it the objects carry
##     `claim = offset + i`; a released container keeps its cells, so a SECOND store built over it answers the same cells.
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
	test_released_containers()
	VoxelStore.active = null
	test_cells_mode()
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


func test_released_containers() -> void:
	print("[TEST 6] released containers: handles made on request, one per claim\n")
	var fixture: Dictionary = _build_fixture()
	var expected: Dictionary = {}   ## container id -> Array of Vector3i, as the fixture built them
	for key in ["slab", "roof", "row", "col", "column"]:
		var c: Object = fixture[key]
		var cells: Array = []
		for v in c.voxels:
			cells.append(Vector3i(v.grid_pos.x, v.grid_pos.y, v.level))
		expected[key] = cells
	var store: VoxelStore = VoxelStore.build(fixture["edge_registry"], fixture["slab_registry"], fixture["columns"], [], true)
	VoxelStore.active = store
	VoxelContainer.Stats.reset()
	var row: Slice = fixture["row"]
	_check(row.is_released() and row.voxel_count() == (expected["row"] as Array).size(), "the row slice is released and still counts its %d voxels without making any" % row.voxel_count())
	_check(VoxelContainer.Stats.handles == 0, "no handle was made by counting")
	var a: Voxel = row.voxel_at(3)
	var b: Voxel = row.voxel_at(3)
	var c: Voxel = store.voxel_of(row.claim_offset() + 3)
	_check(a == b and a == c, "voxel_at(3) twice and voxel_of(claim) are ONE object (a Dictionary keyed by Voxel stays consistent)")
	_check(VoxelContainer.Stats.handles == 1, "exactly one handle was made (%d)" % VoxelContainer.Stats.handles)
	_check(Vector3i(a.grid_pos.x, a.grid_pos.y, a.level) == (expected["row"] as Array)[3], "the handle is the cell the fixture built at index 3")
	a.set_damage(Voxel.DamageState.DESTROYED)
	_check(row.dirty_count == 1 and store.dirty_bits[row.claim_offset() + 3] == 1, "a write through the handle counts once on the released container")
	## Converting to full reuses the handle already made, and every voxel matches the fixture's cells.
	var all: Array = row.voxels
	_check(not row.is_released() and VoxelContainer.Stats.converted == 1, "reading `voxels` converts the container (Stats.converted = %d)" % VoxelContainer.Stats.converted)
	var same_cells: bool = all.size() == (expected["row"] as Array).size()
	for i in range(all.size()):
		if Vector3i(all[i].grid_pos.x, all[i].grid_pos.y, all[i].level) != (expected["row"] as Array)[i]:
			same_cells = false
	_check(same_cells, "all %d voxels carry the cells the fixture built, in order" % all.size())
	_check(all[3] == a, "the conversion reused the handle already made for index 3")
	_check(all[3].damage_state == Voxel.DamageState.DESTROYED and all[3].dirty, "state and dirty survive the conversion (they are the store's)")
	## clear_all_dirty on a released container does not make handles.
	var slab: Slab = fixture["slab"]
	slab.voxel_at(0).set_visible(false)
	var made: int = VoxelContainer.Stats.handles
	slab.clear_all_dirty()
	_check(slab.dirty_count == 0 and store.dirty_bits[slab.claim_offset()] == 0 and VoxelContainer.Stats.handles == made, "clear_all_dirty() cleared the store's bits and made no handle")
	## Every container of the store is released, and they all count their voxels.
	var total: int = 0
	var all_released: bool = true
	for container in store.containers:
		if container is VoxelContainer:
			total += (container as VoxelContainer).voxel_count()
			if not (container as VoxelContainer).is_released() and container != row:
				all_released = false
	_check(all_released and total == store.claims, "every other container is released and the counts add up to the store's %d claims" % store.claims)


func test_cells_mode() -> void:
	print("[TEST 7] cells mode: generators make no object\n")
	var registry := SlabRegistry.new()
	var slab: Slab = SlabGenerator.generate(Vector2i(2, 3), Slab.Role.FLOOR, 79, "concrete", registry)
	var origin: Vector2i = GeometryCoords.gu_to_voxel_origin(Vector2i(2, 3))
	_check(slab.has_cells_only() and slab.voxel_count() == 64, "a generated slab holds 64 cells and no object")
	_check(slab.cell_at(0) == Vector3i(origin.x, origin.y, 79) and slab.cell_at(63) == Vector3i(origin.x + 7, origin.y + 7, 79), "the first and last cell are the GU's corners, in the generator's order")
	var packed: PackedInt32Array = slab.cells_packed()
	_check(packed.size() == 64 * 3, "cells_packed() has 3 ints a voxel (%d)" % packed.size())
	VoxelContainer.Stats.reset()
	var edge_registry := EdgeRegistry.new()
	var store: VoxelStore = VoxelStore.build(edge_registry, registry, [])
	VoxelStore.active = store
	_check(store.claims == 64 and slab.claim_offset() == 0 and slab.has_cells_only(), "a store built over it reads the cells (64 claims) and the container still holds no object")
	_check(VoxelContainer.Stats.from_cells == 0, "building the store turned nothing into objects")
	var v: Voxel = slab.voxels[5]
	_check(VoxelContainer.Stats.from_cells == 1, "reading `voxels` turned the container into objects (Stats.from_cells = 1)")
	_check(v.claim == 5 and v.grid_pos == Vector2i(origin.x + 5, origin.y) and v.level == 79, "an object made after the store bound the container IS its claim (claim 5, the right cell)")
	v.set_damage(Voxel.DamageState.DESTROYED)
	_check(store.has_cell(origin.x + 5, origin.y, 79) == false, "and a write through it reaches the store's grid")
	## A released container keeps its cells, so a second store over it reads the same cells.
	var registry2 := SlabRegistry.new()
	var slab2: Slab = SlabGenerator.generate(Vector2i(2, 3), Slab.Role.FLOOR, 79, "concrete", registry2)
	var cells_before: PackedInt32Array = slab2.cells_packed().duplicate()
	var store_a: VoxelStore = VoxelStore.build(EdgeRegistry.new(), registry2, [], [], true)
	_check(slab2.is_released() and slab2.cells_packed() == cells_before, "released: no object, the cells are kept intact")
	var store_b: VoxelStore = VoxelStore.build(EdgeRegistry.new(), registry2, [], [], true)
	VoxelStore.active = store_b
	_check(store_b.claims == 64 and store_a.claims == 64 and slab2.voxel_at(7).grid_pos == Vector2i(origin.x + 7, origin.y),
		"a second store built over the released container reads the same 64 cells, and its handles are the right cells")
