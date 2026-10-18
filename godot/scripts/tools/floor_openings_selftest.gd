## R3D-SURFACES SM-6b — `FloorOpenings` and its path into the floor: which cells an opening carves (slats with a frame, a bare shaft, a multi-GU
## rectangle), that `SlabGenerator` really builds slabs WITHOUT them on both floor levels, and that the section reaches the compiler on the real gallery map.
extends SceneTree

const FloorOpeningsClass = preload("res://godot/scripts/geometry/floor_openings.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== FLOOR OPENINGS SELFTEST ==\n")
	var gu := Vector2i(10, 20)
	var slats: Dictionary = FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(1, 1), "pattern": "slats", "axis": "x", "pitch": 2})
	var carved: Dictionary = FloorOpeningsClass.carved_cells(slats, gu)
	_check(carved.size() == 18, "a 1 x 1 GU slat opening along x carves 3 gap rows x 6 interior columns = 18 of 64 cells (%d)" % carved.size())
	var origin := GeometryCoords.gu_to_voxel_origin(gu)
	var frame_kept := true
	for i in range(8):
		for edge: Vector2i in [Vector2i(i, 0), Vector2i(i, 7), Vector2i(0, i), Vector2i(7, i)]:
			frame_kept = frame_kept and not carved.has(origin + edge)
	_check(frame_kept, "the one-voxel frame around the opening is never carved")
	var rows: Dictionary = {}
	for cell: Vector2i in carved:
		rows[cell.y - origin.y] = true
	_check(rows.keys().size() == 3 and rows.has(1) and rows.has(3) and rows.has(5), "the gaps are the odd rows 1, 3, 5: bars on 0, 2, 4, 6 and the frame")
	var along_z: Dictionary = FloorOpeningsClass.carved_cells(FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(1, 1), "pattern": "slats", "axis": "z"}), gu)
	var cols: Dictionary = {}
	for cell: Vector2i in along_z:
		cols[cell.x - origin.x] = true
	_check(along_z.size() == 18 and cols.has(1) and cols.has(3) and cols.has(5), "along z the gaps are the odd COLUMNS instead")
	var pitch3: Dictionary = FloorOpeningsClass.carved_cells(FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(1, 1), "pattern": "slats", "pitch": 3}), gu)
	_check(pitch3.size() == 24, "pitch 3 is a bar every 3 voxels, so the gaps are rows 1, 2, 4, 5: 4 rows x 6 columns = 24 (%d)" % pitch3.size())
	var open: Dictionary = FloorOpeningsClass.carved_cells(FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(1, 1), "pattern": "open"}), gu)
	_check(open.size() == 64, "an `open` shaft carves the whole GU, frame included (%d)" % open.size())
	var wide: Dictionary = FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(3, 3), "pattern": "slats"})
	var middle: Dictionary = FloorOpeningsClass.carved_cells(wide, gu + Vector2i(1, 1))
	_check(middle.size() == 32, "the middle GU of a 3 x 3 opening has no frame: 4 gap rows x 8 columns = 32 (%d)" % middle.size())
	_check(FloorOpeningsClass.carved_cells(wide, gu + Vector2i(3, 0)).is_empty(), "a GU outside the rectangle carves nothing")

	var registry := SlabRegistry.new()
	var plain: Slab = SlabGenerator.generate(Vector2i(1, 1), Slab.Role.FLOOR, GeometryCoords.FLOOR_TOP_LEVEL, "steel_dark", registry)
	var holed_top: Slab = SlabGenerator.generate(gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_TOP_LEVEL, "steel_dark", registry, carved)
	var holed_deep: Slab = SlabGenerator.generate(gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_DEEP_LEVEL, "steel_dark", registry, carved)
	_check(plain.voxel_count() == 64, "an ordinary floor slab is 64 cells")
	_check(holed_top.voxel_count() == 64 - 18 and holed_deep.voxel_count() == 64 - 18, "the opening's slabs are built WITHOUT the carved cells on both levels (%d and %d)" % [holed_top.voxel_count(), holed_deep.voxel_count()])

	var bad: Dictionary = FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(0, 1), "pattern": "slats"})
	_check(bad.is_empty(), "a zero-size opening is refused (loudly)")
	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("SURFACES_GALLERY")
	_check((spec.get("floor_openings", []) as Array).size() == 4, "the gallery's `floor_openings` reaches the runtime spec (4)")
	var layout: Dictionary = MapCompilerClass.compile(spec)
	var instances: Array = layout.get("floor_opening_instances", [])
	var offset := Vector2i(layout.get("playable_rect", Rect2i()).position)
	var first: Array = (spec["floor_openings"][0] as Dictionary)["gu"]
	_check(instances.size() == 4 and (instances[0]["gu_cell"] as Vector2i) == Vector2i(int(first[0]), int(first[1])) + offset, "MapCompiler forwards them shifted by the buffer (%s)" % str(offset))
	var bad_spec: Dictionary = spec.duplicate(true)
	bad_spec["floor_openings"] = [{"gu": [3, 3], "size": [2, 2], "pattern": "diamond"}, {"gu": [3, 3], "size": [2, 2], "pattern": "open"}]
	_check((MapCompilerClass.compile(bad_spec).get("floor_opening_instances", []) as Array).size() == 1, "an unknown pattern is refused (loudly), the good one stays")
	## DIG: the shell under a deeper opening.
	var all_in := func(_c: Vector2i) -> bool: return true
	_check(FloorOpeningsClass.shell_cells(FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(1, 1), "pattern": "open"}), all_in).is_empty(), "dig 2 (default) builds no shell")
	_check(FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(1, 1), "pattern": "open", "dig": 9}).is_empty(), "dig beyond the cosmetic stack is refused")
	var pit: Dictionary = FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(2, 1), "pattern": "open", "dig": 5})
	var shell: Dictionary = FloorOpeningsClass.shell_cells(pit, all_in)
	var bed_level: int = GeometryCoords.FLOOR_TOP_LEVEL - 5
	_check(shell.has(bed_level) and not shell.has(bed_level - 1) and shell.has(GeometryCoords.FLOOR_DEEP_LEVEL - 1) and not shell.has(GeometryCoords.FLOOR_DEEP_LEVEL), "the shell runs from the bed (%d) to the level under the deep slab, no further" % bed_level)
	_check((shell[bed_level] as Dictionary).size() == 16 * 8 + (16 + 8) * 2 + 4, "the bed is the 16 x 8 footprint plus its one-voxel ring (%d)" % (shell[bed_level] as Dictionary).size())
	_check((shell[bed_level + 1] as Dictionary).size() == (16 + 8) * 2 + 4, "a wall level is the ring alone (%d)" % (shell[bed_level + 1] as Dictionary).size())
	var edge_only := func(c: Vector2i) -> bool: return c.x >= 0 and c.y >= 0
	var corner: Dictionary = FloorOpeningsClass.shell_cells(FloorOpeningsClass.normalise({"gu_cell": Vector2i(0, 0), "size": Vector2i(1, 1), "pattern": "open", "dig": 4}), edge_only)
	_check(not (corner[GeometryCoords.FLOOR_TOP_LEVEL - 4] as Dictionary).has(Vector2i(-1, 0)), "the ring never leaves the map")
	var slat_pit: Dictionary = FloorOpeningsClass.normalise({"gu_cell": gu, "size": Vector2i(1, 1), "pattern": "slats", "dig": 4})
	_check(FloorOpeningsClass.footprint_cells(slat_pit).size() == 36, "a slats pit is the interior inside the frame, 6 x 6 (%d)" % FloorOpeningsClass.footprint_cells(slat_pit).size())
	var shell_slab: Slab = SlabGenerator.generate_cells(gu, Slab.Role.FLOOR, bed_level, "concrete", registry, shell[bed_level])
	_check(shell_slab != null and shell_slab.voxel_count() > 0 and shell_slab.voxel_count() <= 64, "SlabGenerator.generate_cells builds the shell slab of a GU (%d cells)" % shell_slab.voxel_count())
	_check(SlabGenerator.generate_cells(Vector2i(50, 50), Slab.Role.FLOOR, bed_level, "concrete", registry, shell[bed_level]) == null, "a GU the shell does not touch gets no slab")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
