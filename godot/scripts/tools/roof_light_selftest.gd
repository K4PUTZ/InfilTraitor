## ROOF R-D1 / R-D3 / R-D4 (ROOF_MASTER_PLAN, 2026-10-11) — a lamp ABOVE a roof reaches the cells under it only through the roof's
## transmission at each voxel column: a hole lets it through whole, intact glass a restricted share, an opaque roof nothing; a lamp
## BELOW the roof is untouched; a map with no roofs is unchanged; the per-cell and the byte-map (map-wide) paths agree; and a change
## to a roof voxel makes its column below stale.
extends SceneTree

const VLF = preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")
const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _lamp(cell: Vector2i, height_class: int) -> LightSourceClass:
	var lamp = LightSourceClass.new()
	lamp.cell = cell
	lamp.height_class = height_class
	lamp.radius = 8
	lamp.visual_energy = 1.0
	lamp.active = true
	return lamp


## The roof over GU (1, 1) at storey 2; the floor row under it; roof voxels standing over column HOLDER and gone over column HOLE.
const FLOOR_CELLS: Array[Vector2i] = [Vector2i(10, 12), Vector2i(11, 12), Vector2i(12, 12), Vector2i(13, 12), Vector2i(14, 12), Vector2i(15, 12)]
const UNDER_ROOF := Vector2i(12, 12)
const UNDER_HOLE := Vector2i(14, 12)


func _occupancy(base: int) -> Dictionary:
	var occ: Dictionary = {}
	var floor_row: Dictionary = {}
	for c: Vector2i in FLOOR_CELLS:
		floor_row[c] = true
	occ[GeometryCoords.FLOOR_TOP_LEVEL] = floor_row
	for l: int in [base, base + 1]:
		var row: Dictionary = {}
		for c: Vector2i in FLOOR_CELLS:
			if c != UNDER_HOLE:
				row[c] = true
		occ[l] = row
	return occ


func _field(lights: Array, roof_material: String, base: int) -> VLF:
	var f := VLF.new()
	if roof_material != "":
		f.set_roofs([{"gu": Vector2i(1, 1), "level": base, "material": roof_material},
			{"gu": Vector2i(1, 1), "level": base + 1, "material": roof_material}])
	f.build(lights, [], base + 1, _occupancy(base))
	return f


func _init() -> void:
	print("\n== ROOF LIGHT SELFTEST ==\n")
	var base: int = GeometryCoords.storey_level_base(2)
	var floor_level: int = GeometryCoords.FLOOR_TOP_LEVEL
	var above: Array = [_lamp(Vector2i(1, 1), LightSourceClass.HEIGHT_OVERHEAD)]   ## anchors at the top wall level = the roof's top
	var below: Array = [_lamp(Vector2i(1, 1), LightSourceClass.HEIGHT_HUMAN)]

	var open := _field(above, "", base)
	var glass := _field(above, "glass", base)
	var concrete := _field(above, "concrete", base)
	var b_open: int = open.bucket_for(UNDER_ROOF, floor_level)
	var b_glass_roof: int = glass.bucket_for(UNDER_ROOF, floor_level)
	var b_glass_hole: int = glass.bucket_for(UNDER_HOLE, floor_level)
	var b_conc_roof: int = concrete.bucket_for(UNDER_ROOF, floor_level)
	var b_conc_hole: int = concrete.bucket_for(UNDER_HOLE, floor_level)
	print("  buckets: no roof %d | glass %d, its hole %d | concrete %d, its hole %d" % [b_open, b_glass_roof, b_glass_hole, b_conc_roof, b_conc_hole])
	_check(b_glass_hole == b_open and b_conc_hole == b_open, "a hole lets the lamp above through whole (R-D3 'full')")
	_check(b_glass_roof < b_open and b_glass_roof > b_conc_roof, "intact glass lets a restricted share through (R-D3)")
	_check(b_conc_roof < b_open, "an opaque roof keeps the lamp above out (R-D1)")

	var below_open := _field(below, "", base)
	var below_conc := _field(below, "concrete", base)
	_check(below_conc.bucket_for(UNDER_ROOF, floor_level) == below_open.bucket_for(UNDER_ROOF, floor_level),
		"a lamp below the roof (the room's own) is untouched")

	## The byte-map (map-wide) path gives the same buckets as the per-cell one.
	var fresh := _field(above, "glass", base)
	var bm: Dictionary = fresh.occupancy_byte_maps()
	var cells: Array = []
	for c: Vector2i in FLOOR_CELLS:
		cells.append(c)
	var bulk: PackedByteArray = fresh.buckets_for_level(floor_level, cells, bm["maps"], bm["origin"], bm["width"], bm["height"])
	var agree: bool = true
	for i: int in range(cells.size()):
		if int(bulk[i]) != glass.bucket_for(cells[i], floor_level):
			agree = false
			print("    cell %s: bulk %d vs per-cell %d" % [cells[i], bulk[i], glass.bucket_for(cells[i], floor_level)])
	_check(agree, "buckets_for_level() agrees with bucket_for() under a roof")

	## A roof voxel that goes stales its column below (and the hole then lets the lamp through).
	var occ2: Dictionary = _occupancy(base)
	(occ2[base] as Dictionary).erase(UNDER_ROOF)
	(occ2[base + 1] as Dictionary).erase(UNDER_ROOF)
	var changes: Array[Vector3i] = [Vector3i(UNDER_ROOF.x, UNDER_ROOF.y, base), Vector3i(UNDER_ROOF.x, UNDER_ROOF.y, base + 1)]
	glass.build(above, [], base + 1, occ2, {}, true, changes)
	_check(glass.stale_cells().has(Vector3i(UNDER_ROOF.x, UNDER_ROOF.y, floor_level)), "a roof voxel's change stales the floor cell under it")
	_check(glass.bucket_for(UNDER_ROOF, floor_level) == b_open, "after the incremental build, the new hole lets the lamp through whole")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
