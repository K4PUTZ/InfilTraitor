## Selftest — VoxModel (the `.vox` parser) and VoxPropBuilder (scale, material, hollow, centre). Pure: bytes built in memory.
extends SceneTree

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("VoxModel / VoxPropBuilder SELFTEST")
	print("=".repeat(70) + "\n")
	_test_round_trip()
	_test_hostile_files()
	_test_builder()
	_test_register_blocks()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(cond: bool, m: String) -> void:
	if cond:
		passed += 1
		print("  ✓ " + m)
	else:
		failed += 1
		print("  ✗ " + m)


func _cube(n: int, colour: int = 1) -> Array:
	var cells: Array = []
	for z in range(n):
		for y in range(n):
			for x in range(n):
				cells.append(Vector4i(x, y, z, colour))
	return cells


func _test_round_trip() -> void:
	print("[1] write -> parse keeps the model")
	var palette := PackedColorArray([Color8(200, 40, 40), Color8(40, 40, 200)])
	var cells: Array = [Vector4i(0, 0, 0, 1), Vector4i(1, 0, 0, 2), Vector4i(2, 3, 4, 1)]
	var m := VoxModel.parse(VoxModel.write(Vector3i(3, 4, 5), cells, palette))
	_check(m.is_ok() and m.size == Vector3i(3, 4, 5) and m.voxels.size() == 3, "size and voxel count survive")
	_check(m.voxels[2] == Vector4i(2, 3, 4, 1) and m.palette[1] == Color8(40, 40, 200), "a voxel and a palette colour survive")
	print("")


## Every prefix of a valid file, random corruptions and absurd claims: each must end in an error or a model, in bounded time.
func _test_hostile_files() -> void:
	print("[2] hostile and broken files never crash or allocate past the caps")
	var good: PackedByteArray = VoxModel.write(Vector3i(4, 4, 4), _cube(4), PackedColorArray([Color.RED]))
	var all_safe: bool = true
	for cut in range(0, good.size(), 7):
		var m := VoxModel.parse(good.slice(0, cut))
		if m.voxels.size() > VoxModel.MAX_VOXELS:
			all_safe = false
	_check(all_safe, "every 7th truncation of a valid file parses without a crash (%d bytes)" % good.size())
	var bad_magic := good.duplicate()
	bad_magic[0] = 0x58
	_check(not VoxModel.parse(bad_magic).is_ok(), "a wrong magic is an error, not a model")
	var huge := good.duplicate()
	## The XYZI count field: 4 G voxels claimed in a tiny chunk.
	var at: int = -1
	for i in range(good.size() - 4):
		if good[i] == 0x58 and good[i + 1] == 0x59 and good[i + 2] == 0x5A and good[i + 3] == 0x49:   ## "XYZI"
			at = i
			break
	huge.encode_u32(at + 12, 0xFFFFFFF0)
	var hm := VoxModel.parse(huge)
	_check(not hm.is_ok() and hm.voxels.is_empty(), "a file claiming 4 G voxels is rejected before any allocation (%s)" % hm.error)
	var big_dim := good.duplicate()
	var s_at: int = -1
	for i in range(good.size() - 4):
		if good[i] == 0x53 and good[i + 1] == 0x49 and good[i + 2] == 0x5A and good[i + 3] == 0x45:   ## "SIZE"
			s_at = i
			break
	big_dim.encode_u32(s_at + 12, 100000)
	_check(not VoxModel.parse(big_dim).is_ok(), "a model size of 100000 is over the cap")
	var out_of_box: PackedByteArray = VoxModel.write(Vector3i(2, 2, 2), [Vector4i(0, 0, 0, 1), Vector4i(9, 9, 9, 1)], PackedColorArray([Color.RED]))
	_check(VoxModel.parse(out_of_box).voxels.size() == 1, "a voxel outside the declared box is dropped, the rest kept")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var survived: bool = true
	for trial in range(60):
		var fuzz := good.duplicate()
		for _j in range(6):
			fuzz[rng.randi_range(0, fuzz.size() - 1)] = rng.randi_range(0, 255)
		var fm := VoxModel.parse(fuzz)
		if fm.voxels.size() > VoxModel.MAX_VOXELS:
			survived = false
	_check(survived, "60 files with 6 random bytes changed each: no crash, never over the voxel cap")
	print("")


func _test_builder() -> void:
	print("[3] VoxPropBuilder: hollow, scale, material, centre")
	var model := VoxModel.parse(VoxModel.write(Vector3i(4, 4, 4), _cube(4), PackedColorArray([Color8(255, 0, 0)])))
	var any := func(_i: int, _c: Color) -> String: return "wood"
	var r: Dictionary = VoxPropBuilder.build(model, 1, any, Vector2i(8, 8))
	## A solid 4x4x4 cube has 64 voxels; its surface is 64 - 2x2x2 = 56.
	_check(int(r["claims"]) == 56 and (r["materials"] as Dictionary).has("wood"), "a solid 4^3 cube hollows to its 56-voxel shell")
	var xs: Array = []
	for c: Vector3i in r["materials"]["wood"]:
		xs.append(c.x)
	_check(xs.min() == 2 and xs.max() == 5, "centred on an 8-voxel footprint (x spans 2..5)")
	var r2: Dictionary = VoxPropBuilder.build(model, 2, any, Vector2i(8, 8))
	_check(r2["size"] == Vector3i(8, 8, 8) and bool(r2["fits"]), "scale 2 makes it 8 x 8 x 8 and it fits an 8-voxel footprint")
	var r3: Dictionary = VoxPropBuilder.build(model, 3, any, Vector2i(8, 8))
	_check(not bool(r3["fits"]), "scale 3 (12 voxels) does not fit an 8-voxel footprint: the caller is told")
	var two := VoxModel.parse(VoxModel.write(Vector3i(2, 1, 1), [Vector4i(0, 0, 0, 1), Vector4i(1, 0, 0, 2)],
		PackedColorArray([Color8(255, 0, 0), Color8(0, 0, 255)])))
	var by_colour := func(i: int, _c: Color) -> String: return "red" if i == 1 else "blue"
	var r4: Dictionary = VoxPropBuilder.build(two, 1, by_colour, Vector2i(8, 8))
	_check((r4["materials"] as Dictionary).size() == 2 and r4["materials"]["red"].size() == 1 and r4["materials"]["blue"].size() == 1,
		"two palette colours become two materials")
	var again: Dictionary = VoxPropBuilder.build(model, 1, any, Vector2i(8, 8))
	_check(again["materials"] == r["materials"], "deterministic: the same model gives the same cells in the same order")
	print("")


## The build becomes PropBlocks: one per (GU, material), every voxel inside its block's GU, all standing on the prop's floor level.
func _test_register_blocks() -> void:
	print("[4] VoxelBoard.register_vox_prop: one block per GU and material")
	## A 12 x 6 x 4 slab of two colours spans TWO GUs (a prop that straddles a GU line): 2 materials x 2 GUs = 4 blocks.
	var cells: Array = []
	for z in range(4):
		for y in range(6):
			for x in range(12):
				cells.append(Vector4i(x, y, z, 1 if y < 3 else 2))
	var model := VoxModel.parse(VoxModel.write(Vector3i(12, 6, 4), cells, PackedColorArray([Color8(200, 0, 0), Color8(0, 0, 200)])))
	var by_colour := func(i: int, _c: Color) -> String: return "wood" if i == 1 else "metal"
	var build: Dictionary = VoxPropBuilder.build(model, 1, by_colour, Vector2i(16, 8))
	build["origin_gu"] = Vector2i.ZERO
	var def := PropDef.from_json({"id": "slab", "mesh_tier": 0, "footprint_gus": [[0, 0], [1, 0]], "vox_model": "x"})
	var board := VoxelBoard.new()
	board.register_vox_prop(Vector2i(3, 2), 0, def, build)
	var blocks: Array[PropBlock] = board.prop_blocks()
	var total: int = 0
	var single_gu: bool = true
	var floors_ok: bool = true
	var materials: Dictionary = {}
	for b: PropBlock in blocks:
		total += b.voxels.size()
		materials[b.material] = true
		var gu: Vector2i = GeometryCoords.voxel_to_gu(b.voxels[0].grid_pos)
		for v: Voxel in b.voxels:
			if GeometryCoords.voxel_to_gu(v.grid_pos) != gu:
				single_gu = false
		if b.floor_level != GeometryCoords.storey_level_base(0):
			floors_ok = false
	_check(total == int(build["claims"]), "every claim of the build is in a block (%d)" % total)
	_check(blocks.size() == 4 and materials.size() == 2, "2 materials x 2 GUs = 4 blocks (%d)" % blocks.size())
	_check(single_gu, "no block spans two GUs")
	_check(floors_ok, "every block knows the prop's floor level")
	var gus: Array = board.prop_gus()
	_check(gus.size() == 2, "prop_gus lists each GU once even with several blocks on it (%s)" % [gus])
	board.free()
	print("")


