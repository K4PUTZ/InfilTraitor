## R3D-SURFACES S2 — the `ground_decals` section, end to end on the real FLOOR_ZONES_TEST map: FileMapSource reads it,
## MapCompiler forwards `ground_decal_instances` shifted by the buffer, the voxel lattice (1/8 GU) holds, a variant is a stable pick,
## and a decal ends with the floor-top voxel under its footprint (and only then).
extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const GroundDecals3DClass = preload("res://godot/scripts/geometry/ground_decals3d.gd")

## `FloorPile3D._rebuild()` asks its board for the ground level; nothing else of Board3DLive is needed here.
class StubBoard extends Node3D:
	func ground_level() -> int:
		return GeometryCoords.PLAYABLE_LEVEL

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== GROUND DECALS SELFTEST (FLOOR_ZONES_TEST) ==\n")
	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("FLOOR_ZONES_TEST")
	_check((spec.get("ground_decals", []) as Array).size() == 3, "the `ground_decals` section reaches the runtime spec (3 items)")
	var layout: Dictionary = MapCompilerClass.compile(spec)
	var inst: Array = layout.get("ground_decal_instances", [])
	_check(inst.size() == 3, "MapCompiler forwards 3 ground_decal_instances")
	var offset := Vector2(layout.get("playable_rect", Rect2i()).position)
	_check(offset != Vector2.ZERO, "the board buffer is not zero (%s), so the shift is observable" % str(offset))
	if inst.size() == 3:
		_check(inst[0]["at"] == Vector2(6, 4) + offset, "corner decal [6,4] lands at %s" % str(Vector2(6, 4) + offset))
		_check(inst[1]["at"] == Vector2(3.5, 3.5) + offset and is_equal_approx(inst[1]["rot"], 0.6), "centre decal keeps its half-GU and rot")
		_check(int(inst[2]["variant"]) == 0 and int(inst[0]["variant"]) == -1, "an author's variant is kept, none means -1")
	_check(GroundDecals3DClass.art_paths("leaf").size() >= 1, "the `leaf` kind has art on disk")
	_check(GroundDecals3DClass.art_paths("no_such_kind").is_empty(), "an unknown kind has none (the loud-fail path)")
	var a: int = GroundDecals3DClass.pick_variant("leaf", Vector2(6, 6), -1, 3)
	_check(a == GroundDecals3DClass.pick_variant("leaf", Vector2(6, 6), -1, 3) and a >= 0 and a < 3, "a variant is a stable pick of the position (B4)")
	_check(GroundDecals3DClass.pick_variant("leaf", Vector2(6, 6), 7, 3) == 1, "an author's variant wraps onto the art that exists")

	## The voxel lattice (2026-10-06): a decal may sit on any 1/8 GU, and neighbouring voxels pick their variants independently.
	var voxel_spec: Dictionary = spec.duplicate(true)
	voxel_spec["ground_decals"] = [{"at": [3.125, 4.875], "kind": "leaf", "rot": 1.0}]
	var voxel_inst: Array = MapCompilerClass.compile(voxel_spec).get("ground_decal_instances", [])
	_check(voxel_inst.size() == 1 and voxel_inst[0]["at"] == Vector2(3.125, 4.875) + offset, "a decal at [3.125, 4.875] (1/8 GU) is accepted and shifted")
	var picks: Dictionary = {}
	for i in range(8):
		picks[GroundDecals3DClass.pick_variant("leaf", Vector2(6.0 + float(i) * 0.125, 6.0), -1, 3)] = true
	_check(picks.size() > 1, "eight neighbouring voxels do not all pick the same variant (%d distinct)" % picks.size())

	var board := StubBoard.new()
	root.add_child(board)
	var decals = GroundDecals3DClass.new()
	decals.attach(board, [{"at": Vector2(7, 7), "kind": "leaf", "variant": -1, "rot": 0.0}], GeometryCoords.FLOOR_TOP_LEVEL)
	_check(decals.count() == 1, "one placement is live")
	## The decal at (7, 7) covers GU 6.5..7.5 = voxel cells 52..59 on both axes.
	var floor_cells: Dictionary = {}
	for x in range(40, 72):
		for z in range(40, 72):
			floor_cells[Vector2i(x, z)] = true
	var has_floor := func(x: int, z: int) -> bool: return floor_cells.has(Vector2i(x, z))
	floor_cells.erase(Vector2i(51, 55))
	floor_cells.erase(Vector2i(55, 60))
	decals.refresh(has_floor)
	_check(decals.count() == 1, "floor missing just outside the footprint leaves it alone")
	floor_cells.erase(Vector2i(59, 52))
	decals.refresh(has_floor)
	_check(decals.count() == 0, "one missing floor voxel on the footprint's corner cell ends it")
	decals.detach()
	board.free()
	if _failures == 0:
		print("\n[SUCCESS] GROUND DECALS SELFTEST PASS — all checks")
		quit(0)
	else:
		print("\n[FAILURE] %d check(s) failed" % _failures)
		quit(1)
