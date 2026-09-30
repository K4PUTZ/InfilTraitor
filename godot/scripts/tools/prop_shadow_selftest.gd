## Selftest — PropShadow (PROPS_TIER4_PLAN P6): a voxel set becomes a soft floor shadow, thrown along the key light, deterministic.
extends SceneTree

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("PropShadow SELFTEST")
	print("=".repeat(70) + "\n")
	_test_direction_and_extent()
	_test_shape_keeps_legs()
	_test_empty_and_determinism()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(cond: bool, m: String) -> void:
	if cond:
		passed += 1
		print("  ✓ " + m)
	else:
		failed += 1
		print("  ✗ " + m)


## The centre of mass of the shadow, in voxels, and its covered area (voxels^2).
func _mass(built: Dictionary) -> Dictionary:
	var image: Image = built["image"]
	var origin: Vector2 = built["origin"]
	var tp: float = float(PropShadow.TEXELS_PER_VOXEL)
	var sum := Vector2.ZERO
	var total: float = 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var a: float = image.get_pixel(x, y).r
			sum += Vector2(float(x) + 0.5, float(y) + 0.5) * a
			total += a
	return {"centre": origin + sum / total / tp, "area": total / (tp * tp)}


func _test_direction_and_extent() -> void:
	print("[1] a voxel on the floor and one up in the air: the shadow falls along the key light")
	var shift: Vector2 = PropShadow.shift_per_voxel()
	var low: Dictionary = _mass(PropShadow.build_image([Vector3i(10, 0, 10)]))
	var high: Dictionary = _mass(PropShadow.build_image([Vector3i(10, 6, 10)]))
	var d: Vector2 = (high["centre"] as Vector2) - (low["centre"] as Vector2)
	var want: Vector2 = shift * 6.0
	_check(d.distance_to(want) < 0.35, "6 voxels up throws the shadow %s away from the floor one (expected %s)" % [d, want])
	_check(shift.x > 0.0 and shift.y < 0.0, "the light comes from -x, +z: shadows fall toward +x, -z (%s per voxel of height)" % shift)
	var column: Dictionary = _mass(PropShadow.build_image([Vector3i(10, 0, 10), Vector3i(10, 1, 10), Vector3i(10, 2, 10), Vector3i(10, 3, 10)]))
	_check(float(column["area"]) > float(low["area"]) * 2.0, "a tall column's shadow is a streak, longer than a single voxel's (%.1f vs %.1f voxels^2)" % [column["area"], low["area"]])
	print("")


func _test_shape_keeps_legs() -> void:
	print("[2] a table throws a top and thin legs, not a block")
	var table: Array = []
	for x in range(8):
		for z in range(5):
			table.append(Vector3i(x, 4, z))
	for leg in [Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 4), Vector2i(7, 4)]:
		for y in range(4):
			table.append(Vector3i(leg.x, y, leg.y))
	var block: Array = []
	for x in range(8):
		for z in range(5):
			for y in range(5):
				block.append(Vector3i(x, y, z))
	var t: Dictionary = _mass(PropShadow.build_image(table))
	var b: Dictionary = _mass(PropShadow.build_image(block))
	_check(float(t["area"]) < float(b["area"]), "the table's shadow is smaller than the same box's (%.1f < %.1f voxels^2)" % [t["area"], b["area"]])
	_check(float(t["area"]) > 40.0, "but bigger than its own top plate's 40 voxels^2 (the legs add streaks): %.1f" % t["area"])
	print("")


func _test_empty_and_determinism() -> void:
	print("[3] empty in, nothing out; same in, same bytes out")
	_check(PropShadow.build_image([]).is_empty(), "no voxels: no shadow")
	var cells: Array = [Vector3i(3, 0, 3), Vector3i(3, 1, 3), Vector3i(4, 0, 3)]
	var a: Dictionary = PropShadow.build_image(cells)
	var b: Dictionary = PropShadow.build_image(cells)
	_check((a["image"] as Image).get_data() == (b["image"] as Image).get_data() and a["origin"] == b["origin"], "deterministic")
	var maximum: int = 0
	for v in (a["image"] as Image).get_data():
		maximum = maxi(maximum, int(v))
	_check(maximum > 200, "the core of the shadow is solid (max texel %d) and its edge is soft" % maximum)
	print("")
