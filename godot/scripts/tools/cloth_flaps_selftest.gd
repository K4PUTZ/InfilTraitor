## Selftest — ClothFlaps3D (ROOF_MASTER_PLAN v0.30): a flap is thrown UP with the blast and falls to hang from the rim, in that order, and the mesh the
## node rebuilds each frame has the quads it should. The pose is a function of time only, so it is asserted without a board.
extends SceneTree

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("ClothFlaps3D SELFTEST")
	print("=".repeat(70) + "\n")
	var flaps := ClothFlaps3D.new()
	var flap: Dictionary = {"hinge": Vector3(2.0, 2.0, 3.0), "dir": Vector2(1.0, 0.0), "length": 0.5, "width": 0.25, "delay": 0.0, "rise": 0.25, "fall": 0.7,
		"tone": Color(0.3, 0.3, 0.3), "burn": 1.0, "thickness": 0.04}
	_check(is_zero_approx(flaps._angle(flap, -0.1)) and is_zero_approx(flaps._angle(flap, 0.0)), "before its start a flap lies flat on the roof plane")
	var peak: float = -99.0
	var peak_at: float = 0.0
	var t: float = 0.0
	while t < 2.5:
		var a: float = flaps._angle(flap, t)
		if a > peak:
			peak = a
			peak_at = t
		t += 0.01
	_check(absf(peak - ClothFlaps3D.RISE_ANGLE) < 0.02 and absf(peak_at - 0.25) < 0.03, "it rises to %.0f deg at the end of its rise (%.2f s)" % [rad_to_deg(peak), peak_at])
	_check(flaps._angle(flap, 0.12) > 0.0 and flaps._angle(flap, 0.12) < peak, "the rise is eased, not a jump")
	_check(flaps._angle(flap, 0.6) < peak and flaps._angle(flap, 0.6) > ClothFlaps3D.HANG_ANGLE, "then it comes down through the middle of the fall")
	_check(absf(flaps._angle(flap, 6.0) - ClothFlaps3D.HANG_ANGLE) < 0.01, "and ends hanging at %.0f deg from the rim (%.1f deg at 6 s)" % [rad_to_deg(ClothFlaps3D.HANG_ANGLE), rad_to_deg(flaps._angle(flap, 6.0))])
	flaps.add_flaps([flap], null)
	flaps._process(0.5)
	var surface_arrays: Array = (flaps._mesh as ImmediateMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	## the top (SEGMENTS quads), the underside and the two long edges (3 more per segment) and the tip: 6 vertices a quad
	var quads: int = ClothFlaps3D.SEGMENTS * 4 + 1
	_check(verts.size() == quads * 6, "one flap with thickness is %d quads = %d vertices (got %d)" % [quads, quads * 6, verts.size()])
	var far: float = 0.0
	for v in verts:
		far = maxf(far, Vector2(v.x - 2.0, v.z - 3.0).length())
	_check(far > 0.1 and far < 0.55, "the strip reaches into the hole by %.2f GU (its length is 0.50)" % far)
	flaps.free()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(ok: bool, m: String) -> void:
	if ok:
		passed += 1
		print("  ✓ " + m)
	else:
		failed += 1
		print("  ✗ " + m)
