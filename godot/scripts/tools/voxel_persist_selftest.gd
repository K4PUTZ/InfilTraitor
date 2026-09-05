## VL-PERSIST selftest — the coordinate math destruction persistence relies on.
## Run: godot --headless --script res://godot/scripts/tools/voxel_persist_selftest.gd
##
## Destruction is recorded in BASE (N-frame) voxel coords and re-applied per view
## by PerspectiveMapper.cell_to_base / cell_from_base at 8× the GU resolution
## (base_size × VOXELS_PER_UNIT_AXIS). Two properties must hold or holes land on
## the wrong voxels after a rotation:
##   1. cell_from_base and cell_to_base are exact inverses at voxel scale.
##   2. A voxel's rotation is consistent with its owning GU's rotation — the 8×8
##      quadrant rotates coherently, so a voxel stays inside its rotated GU.
##   3. GLASS §16.6 — the GEOMETRY the coordinates point at rotates too. Properties
##      1 and 2 were green for months while every half-thickness PANEL stood still
##      through a quarter turn, because `layout_with_perspective()` never rotated
##      `panel_instances`. A coordinate test cannot see that: the key was right,
##      the pane was not there.

extends SceneTree

const PM = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const SliceGeneratorClass = preload("res://godot/scripts/geometry/slice_generator.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("VL-PERSIST — voxel base↔view coordinate SELFTEST")
	print("=".repeat(70) + "\n")

	test_voxel_roundtrip_all_directions()
	test_voxel_stays_in_rotated_gu()
	test_panel_rotates_with_the_map()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ VL-PERSIST SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ VL-PERSIST SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## Property 1: exact inverses at voxel scale, every direction, including edges.
func test_voxel_roundtrip_all_directions() -> void:
	print("[1] Voxel base↔view round-trip is exact (8× GU scale)\n")
	var vox_size := Vector2i(26, 18) * GeometryCoordsClass.VOXELS_PER_UNIT_AXIS  # 208×144
	var samples := [
		Vector2i(0, 0), Vector2i(vox_size.x - 1, vox_size.y - 1),
		Vector2i(24, 28), Vector2i(48, 40), Vector2i(100, 50), Vector2i(207, 0),
	]
	var ok := true
	for dir in ["N", "E", "S", "W"]:
		for v in samples:
			var base: Vector2i = PM.cell_to_base(v, dir, vox_size)
			var back: Vector2i = PM.cell_from_base(base, dir, vox_size)
			if back != v:
				_fail("dir=%s v=%s → base=%s → back=%s" % [dir, v, base, back])
				ok = false
	if ok:
		_pass("cell_to_base∘cell_from_base = identity for all sampled voxels/dirs")
	print("")


## Property 2: a voxel rotates INTO its GU's rotated cell. Take a GU, rotate it
## via the GU-scale mapper; rotate each of its 64 voxels via the voxel-scale
## mapper; every rotated voxel must fall inside the rotated GU's 8×8 quadrant.
func test_voxel_stays_in_rotated_gu() -> void:
	print("[2] A voxel rotates into its GU's rotated cell (quadrant coherence)\n")
	var gu_size := Vector2i(26, 18)
	var vox_size := gu_size * GeometryCoordsClass.VOXELS_PER_UNIT_AXIS
	var n := GeometryCoordsClass.VOXELS_PER_UNIT_AXIS
	var test_gus := [Vector2i(3, 5), Vector2i(0, 0), Vector2i(25, 17), Vector2i(12, 9)]
	var ok := true
	for dir in ["E", "S", "W"]:
		for gu in test_gus:
			var gu_rot: Vector2i = PM.cell_from_base(gu, dir, gu_size)
			for ox in range(n):
				for oy in range(n):
					var vbase := Vector2i(gu.x * n + ox, gu.y * n + oy)
					var vrot: Vector2i = PM.cell_from_base(vbase, dir, vox_size)
					var vrot_gu := Vector2i(vrot.x / n, vrot.y / n)
					if vrot_gu != gu_rot:
						_fail("dir=%s gu=%s voxel_off=(%d,%d) → gu=%s (expected %s)" % [
							dir, gu, ox, oy, vrot_gu, gu_rot])
						ok = false
	if ok:
		_pass("all 64 voxels of every tested GU land inside the rotated GU cell")
	print("")


## Property 3: GLASS §16.6 — a PANEL is a point PLUS a face, and both rotate.
##
## ⚠️ THIS ASSERTS AN IDENTITY, NOT AN ABSENCE. "the panel entry changed" would
## pass for a gu_cell rotated with the face left alone — the silent half of the
## same defect, which puts the pane in the right GU facing the wrong way. What is
## checked is that the rotated panel's voxel PLANE is exactly the rotation of the
## original panel's voxel plane, which is the only statement `_reapply_base_damage()`
## actually depends on.
func test_panel_rotates_with_the_map() -> void:
	print("[3] A half-thickness PANEL rotates with the map, face included (§16.6)\n")
	var gu_size := Vector2i(26, 18)
	var vox_size := gu_size * GeometryCoordsClass.VOXELS_PER_UNIT_AXIS
	var faces := {"NW": Face.NW, "NE": Face.NE, "SE": Face.SE, "SW": Face.SW}
	var test_gus := [Vector2i(3, 5), Vector2i(0, 0), Vector2i(25, 17), Vector2i(14, 9)]

	var panels: Array[Dictionary] = []
	for gu in test_gus:
		for fname in faces:
			panels.append({"gu_cell": gu, "face": fname, "material": "glass", "storeys": 3})
	var layout := {"size": gu_size, "panel_instances": panels}

	var ok := true
	for dir in ["N", "E", "S", "W"]:
		var mapped: Dictionary = PM.layout_with_perspective(layout, dir)
		var out: Array = mapped.get("panel_instances", [])
		if out.size() != panels.size():
			_fail("dir=%s — %d panel(s) out of %d in" % [dir, out.size(), panels.size()])
			ok = false
			continue
		for i in range(panels.size()):
			var src: Dictionary = panels[i]
			var dst: Dictionary = out[i]
			var gu: Vector2i = src["gu_cell"]
			var face_in: int = faces[String(src["face"])]
			var face_out_name := String(dst.get("face", ""))
			if not faces.has(face_out_name):
				_fail("dir=%s gu=%s face=%s → %r is not a face" % [dir, gu, src["face"], face_out_name])
				ok = false
				continue
			## The plane the rotated panel actually builds its voxels on...
			var got: Array = SliceGeneratorClass.slice_voxel_positions(
				dst["gu_cell"], faces[face_out_name])
			## ...against the rotation of the plane the original one built.
			var want: Array = []
			for v in SliceGeneratorClass.slice_voxel_positions(gu, face_in):
				want.append(PM.cell_from_base(v, dir, vox_size))
			got.sort()
			want.sort()
			if got != want:
				_fail("dir=%s gu=%s face=%s → gu=%s face=%s: plane %s, expected %s" % [
					dir, gu, src["face"], dst["gu_cell"], face_out_name,
					got.slice(0, 2), want.slice(0, 2)])
				ok = false
	if ok:
		_pass("%d panel placements × 4 directions land on the rotated voxel plane"
			% panels.size())
	print("")

