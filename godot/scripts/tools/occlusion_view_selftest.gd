## R3D-ROT — the cutaway under a view is the cutaway of the TURNED world.
## Run: python3 tools/persistent/run_selftests.py --only occlusion_view_selftest
##
## The claim: `OcclusionSet` keyed in BASE coordinates with `view = E` gives exactly what the same set gives in the N view
## over the map turned a quarter turn (cells, agent and size), once its columns are turned back. Asserted for E, S and W,
## on a fixture with both near and far columns around the agent, comparing every column's ring and level span.
## A pillar in front of the agent from the east is NOT in front of him from the north, so a view the set ignores fails it.
extends SceneTree

const GeometryCoordsMod = preload("res://godot/scripts/geometry/geometry_coords.gd")
const OcclusionSetMod = preload("res://godot/scripts/systems/occlusion_set.gd")
const FIXTURE_LEVELS: int = 6
const GU_SIZE := Vector2i(20, 12)

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("OCCLUSION-VIEW — the cutaway of a turned view equals the turned world's SELFTEST")
	print("=".repeat(70) + "\n")
	var voxel_size: Vector2i = GU_SIZE * GeometryCoordsMod.VOXELS_PER_UNIT_AXIS
	var agent := Vector2i(9, 5)
	var columns: Array[Vector2i] = []
	var centre: Vector2i = GeometryCoordsMod.gu_to_voxel_origin(agent) + Vector2i(4, 4)
	## Columns on all four diagonals of the agent (a diagonal is a line of constant screen x in SOME view) at two distances,
	## plus a few off-line ones, so every view has its own near columns and the others' are far or off to the side.
	for k: int in [5, 9]:
		for sign: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			columns.append(centre + sign * k)
	for off: Vector2i in [Vector2i(7, 3), Vector2i(-3, 8), Vector2i(2, -9), Vector2i(-8, -2)]:
		columns.append(centre + off)
	var base_result: Dictionary = _run(columns, agent, "N", GU_SIZE, voxel_size)
	_check(base_result.size() > 0, "the N fixture occludes something (%d column(s)); a vacuous fixture proves nothing" % base_result.size())
	for dir: String in ["E", "S", "W"]:
		var view_result: Dictionary = _run(columns, agent, dir, GU_SIZE, voxel_size)
		var turned_size: Vector2i = Vector2i(GU_SIZE.y, GU_SIZE.x) if dir != "S" else GU_SIZE
		var turned_voxel: Vector2i = turned_size * GeometryCoordsMod.VOXELS_PER_UNIT_AXIS
		var turned_columns: Array[Vector2i] = []
		for c: Vector2i in columns:
			turned_columns.append(PerspectiveMapper.turn_from_base(c, dir, voxel_size))
		var turned_agent: Vector2i = PerspectiveMapper.turn_from_base(agent, dir, GU_SIZE)
		var control: Dictionary = _run(turned_columns, turned_agent, "N", turned_size, turned_voxel)
		var control_base: Dictionary = {}
		for c: Vector2i in control:
			control_base[PerspectiveMapper.cell_to_base(c, dir, voxel_size)] = control[c]
		_check(view_result == control_base,
			"%s: %d column(s) with the view vs %d from the turned world (must be the same set, ring and span)"
			% [dir, view_result.size(), control_base.size()])
		_check(dir == "S" or view_result != base_result or base_result.is_empty(),
			"%s: the set is not just the N set (the view is read)" % dir)
	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	quit(0 if failed == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  ✓ PASS: ", msg)
	else:
		failed += 1
		print("  ✗ FAIL: ", msg)


func _run(columns: Array[Vector2i], agent: Vector2i, view: String, gu_size: Vector2i, voxel_size: Vector2i) -> Dictionary:
	var slices: Array = []
	for cell: Vector2i in columns:
		var slice := Slice.new("S_%d_%d" % [cell.x, cell.y], GeometryCoordsMod.voxel_to_gu(cell), 0,
			"E_%d_%d" % [cell.x, cell.y], 1)
		for level_offset in range(FIXTURE_LEVELS):
			slice.voxels.append(Voxel.new(cell, GeometryCoordsMod.storey_level_base(0) + level_offset, slice))
		slices.append(slice)
	var set = OcclusionSetMod.new()
	set.memo_enabled = false
	set.view = view
	set.base_voxel_size = voxel_size
	set.base_gu_size = gu_size
	var origins: Array[Vector2i] = [agent]
	set.recompute(origins, slices, gu_size)
	return set.get_occluded_cells()
