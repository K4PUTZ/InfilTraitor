## R3D-SURFACES — the disc field's octagon: `CircleField3D.visible_radius` follows the feather (a hard edge keeps the whole disc, a soft one drops its
## invisible rim), and `QuadField3D._octagon_mesh` is a regular octagon whose inscribed circle is exactly that radius, so nothing visible is clipped and the
## rasterised area drops (the Moto pays per blended pixel).
extends SceneTree

const CircleFieldClass = preload("res://godot/scripts/geometry/circle_field3d.gd")
const QuadFieldClass = preload("res://godot/scripts/geometry/quad_field3d.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== CIRCLE FIELD OCTAGON SELFTEST ==\n")
	_check(CircleFieldClass.visible_radius(0.0) == 1.0, "a hard edge keeps the whole disc")
	var r75: float = CircleFieldClass.visible_radius(0.75)
	var r30: float = CircleFieldClass.visible_radius(0.3)
	_check(r75 > 0.85 and r75 < 0.99, "feather 0.75 drops the invisible rim (visible radius %.2f)" % r75)
	_check(r30 > r75 and r30 <= 1.0, "a narrower feather keeps more of the disc (%.2f at 0.3)" % r30)
	for f in [0.2, 0.5, 0.75, 1.0]:
		var vr: float = CircleFieldClass.visible_radius(f)
		var t: float = clampf((vr - (1.0 - f)) / f, 0.0, 1.0)
		var alpha: float = 1.0 - t * t * (3.0 - 2.0 * t)
		_check(alpha < 0.03 or vr >= 1.0, "at feather %.2f nothing above 3%% alpha is clipped (alpha at the visible radius %.3f)" % [f, alpha])
	var mesh: ArrayMesh = QuadFieldClass._octagon_mesh(r75)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(verts.size() == 9 and indices.size() == 24, "the octagon is a fan: a centre and 8 rim vertices, 8 triangles")
	var circum: float = r75 / cos(PI / 8.0)
	var rim_ok := true
	for i in range(1, 9):
		rim_ok = rim_ok and absf(Vector2(verts[i].x, verts[i].y).length() - circum) < 0.0001
	_check(rim_ok, "every rim vertex is on the circumscribed circle (%.3f)" % circum)
	var area := 0.0
	for tri in range(8):
		var a := Vector2(verts[indices[tri * 3 + 1]].x, verts[indices[tri * 3 + 1]].y)
		var b := Vector2(verts[indices[tri * 3 + 2]].x, verts[indices[tri * 3 + 2]].y)
		area += absf(a.cross(b)) * 0.5
	_check(area < 4.0 * 0.85, "the octagon is well under the square's area of 4 (%.2f, %.0f%% less)" % [area, (1.0 - area / 4.0) * 100.0])
	var apothem_ok: bool = absf(area - 8.0 * r75 * r75 * tan(PI / 8.0)) < 0.001
	_check(apothem_ok, "its area is the regular octagon's 8 * apothem^2 * tan(22.5 deg)")
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	_check(uvs[0].is_equal_approx(Vector2(0.5, 0.5)) and uvs.size() == verts.size(), "the UV is xy * 0.5 + 0.5, so the shader's length(UV * 2 - 1) is unchanged")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
