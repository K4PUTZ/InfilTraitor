## RENDER3D R3D-0 Test: the BoardProbe dump format.
##
## Run: python3 tools/persistent/run_selftests.py --only board_probe
##
## WHAT THIS PINS — the writer half. The comparison lives in
## `tools/persistent/board_probe.py diff` and is proven on the real path (the gate's
## control: a grenade must move the dump). This pins that the writer puts each fact
## where that tool reads it, and that nothing else moves:
##
##  1. Two dumps of an unchanged world are the same bytes.
##  2. One damaged voxel changes exactly one line — its container's — and the four
##     state bytes of that voxel decode to the damage written, while every other
##     voxel's bytes stay put (assert identity, not absence).
##  3. A banded slice carries its material PER VOXEL: the band's level reads the band's
##     material, the level beside it reads the base.
##  4. One plane texel changes exactly one line — that level's `P` record.
##  5. A value a byte cannot hold aborts the write loudly and leaves no file. A wrapped
##     byte would match a voxel it does not match.

extends SceneTree

const BoardProbeClass = preload("res://godot/scripts/systems/board_probe.gd")

const OUT_DIR: String = "user://board_probe_selftest"
const BAND_LEVEL_REL: int = 1

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("RENDER3D R3D-0 — BoardProbe SELFTEST")
	print("=".repeat(70) + "\n")

	var fixture: Dictionary = _build_fixture()
	var dump_a: String = _write(fixture, "a")
	test_repeatable(fixture, dump_a)
	var dump_c: String = test_one_damage_moves_one_line(fixture, dump_a)
	test_banded_material_per_voxel(dump_a)
	test_plane_texel_moves_its_line(fixture, dump_c)
	test_out_of_range_aborts(fixture)

	_cleanup()
	VoxelStore.active = null
	print("\nBoardProbe SELFTEST: %s (%d passed, %d failed)\n"
		% ["PASS" if failed == 0 else "FAIL", passed, failed])
	quit(1 if failed > 0 else 0)


# ── fixture ──────────────────────────────────────────────────────────────────

func _build_fixture() -> Dictionary:
	var slab_registry := SlabRegistry.new()
	var slabs: Array = []
	for spec: Array in [[Vector2i(1, 1), "concrete"], [Vector2i(2, 1), "earth"]]:
		var gu: Vector2i = spec[0]
		var slab := Slab.new(Slab.make_id(gu, Slab.Role.FLOOR, 79), gu, Slab.Role.FLOOR, 79, spec[1])
		for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			slab.voxels.append(Voxel.new(gu * 8 + offset, 79, slab))
		slab_registry.register_slab(slab)
		slabs.append(slab)

	var edge_registry := EdgeRegistry.new()
	var slice := Slice.new("SLICE_1_1_SE", Vector2i(1, 1), 2, "EDGE_1_1_SE", 1, "glass", 0)
	slice.material_bands = {BAND_LEVEL_REL: "brick"}
	var base: int = GeometryCoords.storey_level_base(0)
	for rel in range(2):
		for position in range(4):
			slice.voxels.append(Voxel.new(Vector2i(8 + position, 8), base + rel, slice))
	edge_registry.register_slice(slice)

	var plane := Image.create(4, 4, false, Image.FORMAT_RG8)
	plane.fill(Color8(124, 255, 0, 255))
	## RENDER3D R3D-1d: Voxel has no state of its own any more — a VoxelStore over this
	## fixture is what test_one_damage_moves_one_line()'s set_damage() call writes into.
	VoxelStore.active = VoxelStore.build(edge_registry, slab_registry, [])
	return {"slabs": slabs, "slab_registry": slab_registry, "slice": slice,
		"edge_registry": edge_registry, "planes": {80: plane}}


func _write(fixture: Dictionary, name: String) -> String:
	var path: String = ProjectSettings.globalize_path("%s/%s.txt" % [OUT_DIR, name])
	var summary: Dictionary = BoardProbeClass.write(path, name, fixture["edge_registry"],
		fixture["slab_registry"], [], fixture["planes"], Vector2i(64, 64), {"fixture": true})
	if summary.is_empty():
		return ""
	return FileAccess.get_file_as_string(path)


# ── tests ────────────────────────────────────────────────────────────────────

func test_repeatable(fixture: Dictionary, dump_a: String) -> void:
	var dump_b: String = _write(fixture, "a")
	var lines: PackedStringArray = dump_a.split("\n", false)
	var ok: bool = not dump_a.is_empty() and dump_a == dump_b \
		and lines[lines.size() - 1] == "END voxels=16 containers=3 materials=4 levels=1"
	_check(ok, "[TEST 1] an unchanged world dumps the same bytes, last line '%s'"
		% (lines[lines.size() - 1] if lines.size() > 0 else "missing"))


func test_one_damage_moves_one_line(fixture: Dictionary, dump_a: String) -> String:
	var slab: Slab = fixture["slabs"][0]
	slab.voxels[2].set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.LEFT, 2, 1)
	var dump_c: String = _write(fixture, "c")
	var changed: Array = _changed_lines(dump_a, dump_c)
	if changed.size() != 1 or not str(changed[0][1]).begins_with("C slab %s " % slab.id):
		_check(false, "[TEST 2] one damaged voxel changed %d line(s): %s" % [changed.size(), changed])
		return dump_c
	var before: PackedByteArray = _state_bytes(str(changed[0][0]))
	var after: PackedByteArray = _state_bytes(str(changed[0][1]))
	## visible 1 | DENTED 3 << 1 | blast 1 << 3 | LEFT 3 << 4 = 63
	var expected_flags: int = 1 | (Voxel.DamageState.DENTED << 1) | (1 << 3) \
		| (Voxel.CarvedSide.LEFT << 4)
	var others_unchanged: bool = true
	for i in range(16):
		if (i < 8 or i > 11) and before[i] != after[i]:
			others_unchanged = false
	var ok: bool = after.size() == 16 and after[8] == expected_flags and after[9] == 2 \
		and after[10] == 1 and after[11] == before[11] and others_unchanged
	_check(ok, "[TEST 2] one DENTED voxel moves only its slab's line; its bytes %s → %s (flags expected %d)"
		% [before.slice(8, 12), after.slice(8, 12), expected_flags])
	return dump_c


func test_banded_material_per_voxel(dump_a: String) -> void:
	var materials: Dictionary = {}
	var slice_state: PackedByteArray = PackedByteArray()
	for line: String in dump_a.split("\n", false):
		var parts: PackedStringArray = line.split(" ")
		if parts[0] == "M":
			materials[int(parts[1])] = parts[2]
		elif parts[0] == "C" and parts[1] == "slice":
			slice_state = Marshalls.base64_to_raw(parts[5])
	## Voxel #0 is rel level 0 (base material), #4 is rel level 1 (the band).
	var ok: bool = slice_state.size() == 32 \
		and materials.get(slice_state[3], "") == "glass" \
		and materials.get(slice_state[4 * 4 + 3], "") == "brick"
	_check(ok, "[TEST 3] the banded slice reads glass at rel 0 and brick at rel %d (materials %s)"
		% [BAND_LEVEL_REL, materials])


func test_plane_texel_moves_its_line(fixture: Dictionary, dump_c: String) -> void:
	(fixture["planes"][80] as Image).set_pixel(1, 2, Color8(60, 7, 0, 255))
	var dump_d: String = _write(fixture, "d")
	var changed: Array = _changed_lines(dump_c, dump_d)
	var ok: bool = changed.size() == 1 and str(changed[0][1]).begins_with("P 80 4 4 ")
	_check(ok, "[TEST 4] one plane texel moves only its level's P line (%d line(s) changed)"
		% changed.size())


func test_out_of_range_aborts(fixture: Dictionary) -> void:
	## RENDER3D R3D-1d: `Voxel` no longer holds a raw, unbounded `damage_variant` field —
	## VoxelStore.set_damage() is the only writer, and it aborts loudly on an
	## out-of-range value instead of ever storing one (see its own docstring). That is
	## the seam this test now exercises directly.
	var voxel: Voxel = (fixture["slabs"][1] as Slab).voxels[0]
	print("  (an ERROR from [VoxelStore] follows — expected)")
	var store: VoxelStore = VoxelStore.active
	var rejected: bool = not store.set_damage(voxel.claim, Voxel.DamageState.DENTED,
		false, Voxel.CarvedSide.NONE, 300, 0)
	_check(rejected and voxel.damage_variant == 0,
		"[TEST 5] variant 300 is rejected and the claim is unchanged")


# ── helpers ──────────────────────────────────────────────────────────────────

## [[line in a, line in b], ...] for every line index where the two dumps differ. Line 0,
## the `BOARDPROBE <version> <label>` header, is skipped: it names the dump, and each
## dump here is written under its own label.
func _changed_lines(a: String, b: String) -> Array:
	var la: PackedStringArray = a.split("\n", false)
	var lb: PackedStringArray = b.split("\n", false)
	var out: Array = []
	for i in range(1, maxi(la.size(), lb.size())):
		var x: String = la[i] if i < la.size() else ""
		var y: String = lb[i] if i < lb.size() else ""
		if x != y:
			out.append([x, y])
	return out


func _state_bytes(c_line: String) -> PackedByteArray:
	var parts: PackedStringArray = c_line.split(" ")
	return Marshalls.base64_to_raw(parts[5]) if parts.size() == 6 else PackedByteArray()


func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("%s ✅" % message)
	else:
		failed += 1
		print("%s ❌" % message)


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open(OUT_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT_DIR))
