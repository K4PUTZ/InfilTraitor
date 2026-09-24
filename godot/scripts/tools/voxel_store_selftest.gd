## RENDER3D R3D-1b Test: the shadow `VoxelStore` holds what the objects hold.
##
## WHAT THIS PINS, each against `BoardProbe`'s own dump of the OBJECTS, so a check reads
## "the store says what the objects say" rather than "the store says what this test
## expects":
##
##  1. A built store dumps identically to the objects — a banded slice, slabs, a junction
##     column, a cell two slices claim, and a slab whose voxels are out of box order (which
##     must be found irregular and served by a table, not by the arithmetic).
##  2. A damage write through `Voxel.set_damage()` lands in the store: dumps identical,
##     and the derived grid follows (destroyed → not occupied).
##  3. A cell two claims hold: destroying the first hands ownership to the second while
##     the cell stays occupied; destroying both empties it. Grid rebuilt from the claims
##     agrees at each step.
##  4. A write into the out-of-order slab lands on the right claim.
##  5. A write the store cannot place is COUNTED: a voxel of a container the store never
##     saw. A container-less projection (`WorldDelta.project_voxel()`) is not a claim and
##     is not counted.
##  6. `occupancy_dict_after()`, the cook's predicted occupancy, works per CLAIM: a cell two
##     claims hold stays occupied while one of them is gone and empties when both are, a
##     cell one claim holds empties with it, and the store itself is not written (R3D-13:
##     the per-cell predecessor emptied a box corner at the first claim destroyed, which put
##     the cook's light 21 and 13 cells from a full relight on PLAYGROUND).
extends SceneTree

const BoardProbeClass = preload("res://godot/scripts/systems/board_probe.gd")

const OUT_DIR: String = "user://voxel_store_selftest"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("RENDER3D R3D-1b — VoxelStore SELFTEST")
	print("=".repeat(70) + "\n")

	var fixture: Dictionary = _build_fixture()
	var store: VoxelStore = VoxelStore.build(fixture["edge_registry"], fixture["slab_registry"],
		fixture["columns"])
	if store == null:
		_check(false, "[TEST 1] VoxelStore.build returned null")
	else:
		VoxelStore.active = store
		test_build_matches_objects(fixture, store)
		test_write_mirrors(fixture, store)
		test_collision_ownership(fixture, store)
		test_irregular_write(fixture, store)
		test_unplaceable_writes_counted(store)
		test_occupancy_after(fixture, store)
	VoxelStore.active = null
	_cleanup()
	print("\nVoxelStore SELFTEST: %s (%d passed, %d failed)\n"
		% ["PASS" if failed == 0 else "FAIL", passed, failed])
	quit(1 if failed > 0 else 0)


# ── fixture ──────────────────────────────────────────────────────────────────

func _build_fixture() -> Dictionary:
	var base: int = GeometryCoords.storey_level_base(0)
	var slab_registry := SlabRegistry.new()
	var slab := Slab.new(Slab.make_id(Vector2i(1, 1), Slab.Role.FLOOR, 79), Vector2i(1, 1),
		Slab.Role.FLOOR, 79, "concrete")
	for y in range(2):
		for x in range(2):
			slab.voxels.append(Voxel.new(Vector2i(8 + x, 8 + y), 79, slab))
	slab_registry.register_slab(slab)
	## Out of box order on purpose: (1,0) before (0,0).
	var shuffled := Slab.new(Slab.make_id(Vector2i(2, 1), Slab.Role.FLOOR, 79), Vector2i(2, 1),
		Slab.Role.FLOOR, 79, "earth")
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		shuffled.voxels.append(Voxel.new(Vector2i(16, 8) + offset, 79, shuffled))
	slab_registry.register_slab(shuffled)

	var edge_registry := EdgeRegistry.new()
	## A row along x at y = 8, two levels, with a brick band on the second.
	var row := Slice.new("SLICE_1_1_NE", Vector2i(1, 1), 1, "EDGE_1_1_NE", 1, "glass", 0)
	row.material_bands = {1: "brick"}
	for rel in range(2):
		for x in range(4):
			row.voxels.append(Voxel.new(Vector2i(8 + x, 8), base + rel, row))
	edge_registry.register_slice(row)
	## A column along y at x = 8 — its first cell, (8, 8), is also the row's first cell.
	var col := Slice.new("SLICE_1_1_NW", Vector2i(1, 1), 0, "EDGE_1_1_NW", 1, "glass", 0)
	col.material_bands = {1: "brick"}
	for rel in range(2):
		for y in range(3):
			col.voxels.append(Voxel.new(Vector2i(8, 8 + y), base + rel, col))
	edge_registry.register_slice(col)

	var column := JunctionResolver.JunctionColumn.new(Vector2i(3, 3), Vector2i(24, 24), 1, 0, "metal")

	var plane := Image.create(4, 4, false, Image.FORMAT_RG8)
	plane.fill(Color8(124, 255, 0, 255))
	return {"slab": slab, "shuffled": shuffled, "row": row, "col": col, "column": column,
		"columns": [column], "slab_registry": slab_registry, "edge_registry": edge_registry,
		"planes": {80: plane}}


func _dumps_identical(fixture: Dictionary, store: VoxelStore, name: String) -> bool:
	var objects_path: String = ProjectSettings.globalize_path("%s/%s_o.txt" % [OUT_DIR, name])
	var store_path: String = ProjectSettings.globalize_path("%s/%s_s.txt" % [OUT_DIR, name])
	var a: Dictionary = BoardProbeClass.write(objects_path, name, fixture["edge_registry"],
		fixture["slab_registry"], fixture["columns"], fixture["planes"], Vector2i(64, 64), {})
	var b: Dictionary = BoardProbeClass.write_store(store_path, name, store, fixture["planes"],
		Vector2i(64, 64), {})
	if a.is_empty() or b.is_empty():
		print("  ✗ a dump could not be written (%s / %s)" % [not a.is_empty(), not b.is_empty()])
		return false
	var text_a: String = FileAccess.get_file_as_string(objects_path)
	var text_b: String = FileAccess.get_file_as_string(store_path)
	if text_a != text_b:
		var la: PackedStringArray = text_a.split("\n")
		var lb: PackedStringArray = text_b.split("\n")
		for i in range(mini(la.size(), lb.size())):
			if la[i] != lb[i]:
				print("  first differing line %d:\n    objects %s\n    store   %s" % [i, la[i].left(120), lb[i].left(120)])
				break
		return false
	return true


# ── tests ────────────────────────────────────────────────────────────────────

func test_build_matches_objects(fixture: Dictionary, store: VoxelStore) -> void:
	var ok: bool = store.claims == 4 + 4 + 8 + 6 + 8 and store.irregular_containers() == 1 \
		and store.multi_cells() == 2 and store.grid_mismatches() == 0 \
		and _dumps_identical(fixture, store, "t1")
	_check(ok, "[TEST 1] built: %d claims, %d irregular, %d multi-claim cell(s), grid mismatches %d — dump identical to the objects'"
		% [store.claims, store.irregular_containers(), store.multi_cells(), store.grid_mismatches()])


func test_write_mirrors(fixture: Dictionary, store: VoxelStore) -> void:
	## RENDER3D R3D-1d: `Voxel.set_damage()` writes straight into `VoxelStore` now —
	## there is no separate shadow-mirror step to count, so this no longer checks
	## `writes_mirrored` (that counter now only moves through `store.mirror()` called
	## directly, exercised below in test_unplaceable_writes_counted).
	var slab: Slab = fixture["slab"]
	var v: Voxel = slab.voxels[3]
	v.set_damage(Voxel.DamageState.DESTROYED, true, Voxel.CarvedSide.NONE, 2, 1)
	var cell: int = store.cell_index(v.grid_pos.x, v.grid_pos.y, v.level)
	var claim: int = store.claim_of(v)
	var ok: bool = claim >= 0 and store.state[claim] == VoxelStore.state_byte(v) \
		and store.aux[claim] == (2 | (1 << 4)) and store.occ[cell] == 0 \
		and store.grid_mismatches() == 0 \
		and _dumps_identical(fixture, store, "t2")
	_check(ok, "[TEST 2] a destroy lands in the store: state %d, aux %d, occupied %d — dump identical"
		% [store.state[claim] if claim >= 0 else -1, store.aux[claim] if claim >= 0 else -1,
		store.occ[cell]])


func test_collision_ownership(fixture: Dictionary, store: VoxelStore) -> void:
	var row: Slice = fixture["row"]
	var col: Slice = fixture["col"]
	## (8, 8) at the base level, in both slices. Which one the store claimed first follows
	## `EdgeRegistry.all_slices()`'s order, which this test does not assume.
	var first: Voxel = row.voxels[0]
	var second: Voxel = col.voxels[0]
	if store.claim_of(second) < store.claim_of(first):
		first = col.voxels[0]
		second = row.voxels[0]
	var cell: int = store.cell_index(8, 8, first.level)
	var before_owner: int = store.owner[cell]
	first.set_damage(Voxel.DamageState.DESTROYED, true, Voxel.CarvedSide.NONE, 0, 0)
	var handed: bool = store.owner[cell] == store.claim_of(second) and store.occ[cell] == 1
	second.set_damage(Voxel.DamageState.DESTROYED, false, Voxel.CarvedSide.NONE, 0, 0)
	var emptied: bool = store.owner[cell] == store.claim_of(first) and store.occ[cell] == 0
	var ok: bool = before_owner == store.claim_of(first) and handed and emptied \
		and store.grid_mismatches() == 0 and _dumps_identical(fixture, store, "t3")
	_check(ok, "[TEST 3] two claims of one cell: owner first → second (still occupied %s) → first, empty (%s); grid mismatches %d — dump identical"
		% [handed, emptied, store.grid_mismatches()])


func test_irregular_write(fixture: Dictionary, store: VoxelStore) -> void:
	var shuffled: Slab = fixture["shuffled"]
	var v: Voxel = shuffled.voxels[1]   ## (16, 8): array index 1, box index 0
	v.set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, 1, 2)
	var claim: int = store.claim_of(v)
	var ok: bool = claim >= 0 and store.xyz[claim * 3] == 16 and store.xyz[claim * 3 + 1] == 8 \
		and store.state[claim] == VoxelStore.state_byte(v) and store.writes_misplaced == 0 \
		and _dumps_identical(fixture, store, "t4")
	_check(ok, "[TEST 4] a write into the out-of-order slab lands on claim %d at (%d,%d) — dump identical"
		% [claim, store.xyz[claim * 3] if claim >= 0 else -1, store.xyz[claim * 3 + 1] if claim >= 0 else -1])


func test_unplaceable_writes_counted(store: VoxelStore) -> void:
	## RENDER3D R3D-1d: `Voxel.set_damage()` is no longer how a write reaches
	## `mirror()` — it writes through `claim` directly and refuses (push_error, no
	## state change) when `claim < 0`, exactly what `lost` and `projection` are.
	## `mirror()` itself is exercised directly here — the entry point the OLD shadow
	## write path used, kept as `BoardProbe`'s own drift check, still countable on
	## demand.
	var stranger := Slab.new("SLAB_9_9_FLOOR_79", Vector2i(9, 9), Slab.Role.FLOOR, 79, "concrete")
	var lost := Voxel.new(Vector2i(72, 72), 79, stranger)
	stranger.voxels.append(lost)
	var lost_claim_before: int = lost.claim
	lost.set_damage(Voxel.DamageState.DESTROYED, false, Voxel.CarvedSide.NONE, 0, 0)
	var refused: bool = lost.claim == lost_claim_before and lost.claim < 0 \
		and lost.damage_state == Voxel.DamageState.INTACT

	## A projection has no container, and `mirror()` skips it without counting
	## (voxel.gd's container_id() == 0 guard) — never a "we lost this write" case.
	var projection := Voxel.new(Vector2i(8, 8), 79, null)
	projection.damage_state = Voxel.DamageState.DESTROYED
	var mirrored_before: int = store.writes_mirrored
	store.mirror(lost)
	store.mirror(projection)
	var ok: bool = refused and store.writes_unknown_container == 1 \
		and store.writes_mirrored == mirrored_before
	_check(ok, "[TEST 5] set_damage() on an unclaimed voxel refuses loudly (no state change); mirror() still counts it (%d); a projection is skipped (mirrored %d → %d)"
		% [store.writes_unknown_container, mirrored_before, store.writes_mirrored])


func test_occupancy_after(fixture: Dictionary, store: VoxelStore) -> void:
	var row: Slice = fixture["row"]
	var col: Slice = fixture["col"]
	## (8, 8) on the row's second level: both slices claim it, and TEST 3 left it alone.
	var a: Voxel = row.voxels[4]
	var b: Voxel = col.voxels[3]
	var lone: Voxel = row.voxels[5]   ## (9, 8), one claim
	var level: int = a.level
	var shared := Vector2i(8, 8)
	var here: bool = a.grid_pos == shared and b.grid_pos == shared and b.level == level \
		and lone.grid_pos == Vector2i(9, 8) and lone.level == level
	var whole: Dictionary = store.occupancy_dict()
	var none_gone: Dictionary = store.occupancy_dict_after({})
	var one_gone: Dictionary = store.occupancy_dict_after({store.claim_of(a): true})
	var both_gone: Dictionary = store.occupancy_dict_after({store.claim_of(a): true, store.claim_of(b): true})
	var lone_gone: Dictionary = store.occupancy_dict_after({store.claim_of(lone): true})
	var same_as_real: bool = none_gone[level].size() == whole[level].size()
	var survives: bool = (one_gone[level] as Dictionary).has(shared)
	var empties: bool = not (both_gone[level] as Dictionary).has(shared)
	var lone_empties: bool = not (lone_gone[level] as Dictionary).has(lone.grid_pos) \
		and (lone_gone[level] as Dictionary).has(shared)
	var untouched: bool = store.occ[store.cell_index(8, 8, level)] == 1 and store.grid_mismatches() == 0
	_check(here and same_as_real and survives and empties and lone_empties and untouched,
		"[TEST 6] occupancy_dict_after(): no claim gone = the real occupancy (%s); one of two claims gone keeps the cell (%s); both gone empties it (%s); a lone claim gone empties its cell only (%s); the store is unwritten (%s)"
		% [same_as_real, survives, empties, lone_empties, untouched])


# ── helpers ──────────────────────────────────────────────────────────────────

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("  ✓ %s" % message)
	else:
		failed += 1
		print("  ✗ %s" % message)


func _cleanup() -> void:
	var dir: String = ProjectSettings.globalize_path(OUT_DIR)
	for file_name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute("%s/%s" % [dir, file_name])
	DirAccess.remove_absolute(dir)
