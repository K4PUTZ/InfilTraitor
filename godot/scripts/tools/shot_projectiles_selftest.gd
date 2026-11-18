## MOVEMENT §11.6 step 5 (2026-11-17) — ShotProjectiles3D's record: a stuck body round-trips through the save, a body whose voxel is
## destroyed falls to the floor and lies level (its record follows, its host is gone), another voxel's destruction leaves it alone, and below the device's density the record is kept while nothing is drawn.
## WHY a selftest: on PLAYGROUND no blast or shot in reach takes the dart's own voxel (measured 2026-11-17: the signal arrives with the
## same key form, the voxels it named were 1 to 6 apart), so the fall is pinned here.
extends SceneTree

const ShotProjectilesRef = preload("res://godot/scripts/geometry/shot_projectiles3d.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== SHOT PROJECTILES SELFTEST ==\n")
	var board := Node3D.new()   ## no stand_height: the floor is y = 0
	root.add_child(board)
	var shots = ShotProjectilesRef.of(board)
	_check(shots != null and shots == ShotProjectilesRef.of(board), "one node per board")

	## A probe stuck in a wall at height 0.6, its tip axis along +X tilted down a little.
	var tilt := Basis(Vector3.FORWARD, -0.3)
	var x := Transform3D(tilt.scaled(Vector3.ONE * 2.0), Vector3(3.0, 0.6, 4.0))
	var arr: Array = ShotProjectilesRef._xform_to_array(x)
	var recs: Array = [{"k": "probe", "w": "taser", "p": "", "t": arr, "h": [10, 20, 84]},
		{"k": "probe", "w": "taser", "p": "", "t": arr, "h": [11, 20, 84]}]
	shots.restore(recs)
	_check(shots.stuck_count() == 2, "two records restored")
	var saved: Array = shots.records_for_save()
	_check(saved.size() == 2 and saved[0]["h"] == [10, 20, 84] and (saved[0]["t"] as Array).size() == 12, "the save carries host and transform")
	_check(ShotProjectilesRef._array_to_xform(saved[0]["t"]).is_equal_approx(x), "the transform round-trips exactly")

	shots.on_voxel_destroyed(Vector2i(99, 99), 84)
	_check(shots.records_for_save()[0]["h"] == [10, 20, 84], "another voxel's destruction leaves it bitten")

	shots.on_voxel_destroyed(Vector2i(10, 20), 84)
	for _i in range(200):
		shots._process(1.0 / 60.0)
	var after: Array = shots.records_for_save()
	var fallen: Transform3D = ShotProjectilesRef._array_to_xform(after[0]["t"])
	_check((after[0]["h"] as Array).is_empty(), "its host is gone from the record")
	_check(absf(fallen.origin.y) < 0.001, "it fell to the floor (y %.4f)" % fallen.origin.y)
	_check(absf(fallen.basis.x.normalized().y) < 0.001, "it lies level (axis y %.4f)" % fallen.basis.x.normalized().y)
	_check(is_equal_approx(fallen.basis.x.length(), 2.0), "its scale is kept")
	_check(after[1]["h"] == [11, 20, 84] and ShotProjectilesRef._array_to_xform(after[1]["t"]).is_equal_approx(x), "the other one did not move")

	CosmeticDensity.factor = CosmeticDensity.TIER_LOW
	shots.restore(recs)
	_check(shots.stuck_count() == 2 and shots.get_child_count() == 0, "low density: the records kept, nothing drawn")
	CosmeticDensity.factor = CosmeticDensity.TIER_HIGH
	shots.restore(recs)
	_check(shots.get_child_count() == 2, "high density: both drawn")

	board.free()
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
