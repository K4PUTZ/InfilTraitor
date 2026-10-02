## SOOT-TRUTH — `Room._soot_map` is the one truth and the soot plane is its projection (2026-10-02).
##
## `board_probe.py roundtrip --with-store` found 3-7 soot texels after a SaveState restore on PLAYGROUND: the live plane
## and the restored plane (which projects the map) disagreed. Three writers had each broken the rule; this pins each:
##
##  1. A cell no voxel stands on takes no soot: a blast commits its destruction BEFORE it stamps, so its ember CHARRED rows
##     on the voxels it burnt away used to land in the map and outlive them.
##  2. Erasing a destroyed voxel's entry clears the PLANE in the same step (it only erased the map before, so the old tone
##     stayed on screen and a restore, which projects the map, then differed).
##  3. A cell another claim still stands on keeps its scorch (the cell is the soot's key; it is not orphaned).
##  4. `settle_soot()` gives every cell a blast stamped the map's tone, including one no wave carried, and is idempotent.
extends Node

const RoomScript: GDScript = preload("res://godot/scripts/world/room.gd")

var passed: int = 0
var failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("SOOT-TRUTH SELFTEST")
	print("=".repeat(70) + "\n")

	var base: int = GeometryCoords.storey_level_base(0)
	var registry := EdgeRegistry.new()
	## (8,8) is claimed by both slices; (9,8) by the row alone.
	var row := Slice.new("SLICE_1_1_NE", Vector2i(1, 1), 1, "EDGE_1_1_NE", 1, "brick", 0)
	for x in range(4):
		row.voxels.append(Voxel.new(Vector2i(8 + x, 8), base, row))
	registry.register_slice(row)
	var col := Slice.new("SLICE_1_1_NW", Vector2i(1, 1), 0, "EDGE_1_1_NW", 1, "brick", 0)
	for y in range(3):
		col.voxels.append(Voxel.new(Vector2i(8, 8 + y), base, col))
	registry.register_slice(col)
	var store: VoxelStore = VoxelStore.build(registry, SlabRegistry.new(), [])
	if store == null:
		_check(false, "VoxelStore.build returned null")
		get_tree().quit(1)
		return
	VoxelStore.active = store
	var room: Node2D = RoomScript.new()
	var board := VoxelBoard.new()
	room._voxel_board = board

	var clean: int = BlastCalculator.FACE_SOOT_CLEAN
	var char: int = BlastCalculator.FACE_SOOT_CHAR
	var single := Vector2i(9, 8)
	var shared := Vector2i(8, 8)
	var elsewhere := Vector2i(40, 40)

	## 1. A cell nothing stands on takes no soot.
	room.stamp_soot({base: {elsewhere: char, single: 2}})
	_check(not (room._soot_map.get(base, {}) as Dictionary).has(elsewhere),
		"[1] a cell no voxel stands on takes no soot")
	_check(int((room._soot_map.get(base, {}) as Dictionary).get(single, -1)) == 2, "[1] a standing cell takes its tone")

	## 2. Destroying the voxel erases its entry AND the plane.
	room._soot_map[base][single] = char
	board._write_cell_soot(base, single, BlastCalculator.soot_code(char))
	row.voxels[1].set_damage(Voxel.DamageState.DESTROYED, true, Voxel.CarvedSide.NONE, 0, 0)
	room._clear_orphaned_soot(single, base)
	_check(not (room._soot_map[base] as Dictionary).has(single), "[2] the destroyed voxel's map entry is gone")
	_check(board.cell_soot_at(base, single) == BlastCalculator.soot_code(clean),
		"[2] and its plane cell is clean in the same step (plane %d)" % board.cell_soot_at(base, single))

	## 3. A shared cell keeps its scorch while one claim stands, loses it with the last.
	room._soot_map[base][shared] = char
	board._write_cell_soot(base, shared, BlastCalculator.soot_code(char))
	row.voxels[0].set_damage(Voxel.DamageState.DESTROYED, true, Voxel.CarvedSide.NONE, 0, 0)
	room._clear_orphaned_soot(shared, base)
	_check((room._soot_map[base] as Dictionary).has(shared)
		and board.cell_soot_at(base, shared) == BlastCalculator.soot_code(char),
		"[3] a cell another claim stands on keeps its scorch (map and plane)")
	col.voxels[0].set_damage(Voxel.DamageState.DESTROYED, true, Voxel.CarvedSide.NONE, 0, 0)
	room._clear_orphaned_soot(shared, base)
	_check(not (room._soot_map[base] as Dictionary).has(shared)
		and board.cell_soot_at(base, shared) == BlastCalculator.soot_code(clean),
		"[3] the last claim gone: map and plane both clean")

	## 4. settle_soot: a stamped cell no wave painted takes the map's tone; a second settle moves nothing.
	var lone := Vector2i(10, 8)
	room.absorb_scorch({base: {lone: char}})
	board._write_cell_soot(base, lone, BlastCalculator.soot_code(clean))   ## what a missing wave leaves
	var moved: Dictionary = room.settle_soot()
	_check(moved.has(base) and board.cell_soot_at(base, lone) == BlastCalculator.soot_code(char),
		"[4] settle_soot paints the stamped cell with the map's CHARRED (plane %d)" % board.cell_soot_at(base, lone))
	_check(room.settle_soot().is_empty(), "[4] a second settle moves nothing")

	VoxelStore.active = null
	board.free()
	room.free()
	print("\nSOOT-TRUTH SELFTEST: %s (%d passed, %d failed)\n"
		% ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("  ✓ %s" % label)
	else:
		failed += 1
		print("  ✗ %s" % label)
