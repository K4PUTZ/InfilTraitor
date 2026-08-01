## FACE-READ-02 selftest — the "never three identical faces" guarantee.
## Run: godot --headless --script res://godot/scripts/tools/voxel_face_separation_selftest.gd
##
## Director, 2026-08-01: *"forçar a fuligem de destruição e tiros a seguir o
## mesmo princípio de nunca deixar um voxel existir com as 3 faces totalmente
## iguais [...] garantir que as 3 faces tem uma micro diferença."*
##
## The property under test is a CONTRACT BETWEEN TWO FILES that are tuned
## independently: the shader's per-face constants
## (godot/shaders/voxel_face_shading.gdshader) and the darkening canon they have
## to stay separable against (VoxelRenderer.bucket_luminance, its
## FLOOR_DEPTH_DIM, and VoxelLightField.soot_darkening). Either side can be
## retuned in good faith and silently destroy the guarantee — soot to 0.20 is
## exactly what broke it originally — so both sides are read from their real
## owners here, and the shader constants are PARSED from the shader file rather
## than copied, so a value changed there fails this test instead of drifting.
##
## A headless run has no rasteriser, so this reproduces the shader's arithmetic
## rather than sampling real pixels: quantised 8-bit output for each of the
## three faces. That is a deliberate, stated substitution — the real-pixel
## evidence for this feature is the capture cited in the session record.

extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const VoxelLightFieldClass = preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")
const SHADER_PATH := "res://godot/shaders/voxel_face_shading.gdshader"

## A voxel whose brightest face is at or below this is black on screen; the
## guarantee is not claimed there, and the test says so out loud rather than
## quietly sweeping the range it cannot hold.
const BLACK_CEILING := 2

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("FACE-READ-02 — per-face separation SELFTEST")
	print("=".repeat(70) + "\n")

	var uniforms := _parse_shader_uniforms()
	if uniforms.is_empty():
		_fail("Could not parse the face constants out of %s" % SHADER_PATH)
		_finish()
		return
	print("  shader constants: top=%.4f se=%.4f sw=%.4f min_sep=%.5f (%.2f/255)\n"
		% [uniforms["face_top"], uniforms["face_se"], uniforms["face_sw"],
		uniforms["face_min_sep"], uniforms["face_min_sep"] * 255.0])

	test_three_faces_never_identical(uniforms)
	test_guarantee_depends_on_the_separation_term(uniforms)
	test_sooted_dark_voxel_is_separable(uniforms)

	_finish()


func _finish() -> void:
	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ FACE SEPARATION SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ FACE SEPARATION SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## Read the shader's own default uniform values, so this test measures the
## shipped constants instead of a copy that can drift away from them.
func _parse_shader_uniforms() -> Dictionary:
	var file := FileAccess.open(SHADER_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var out: Dictionary = {}
	for name in ["face_top", "face_se", "face_sw", "face_min_sep"]:
		var re := RegEx.new()
		re.compile("uniform\\s+float\\s+%s\\s*(?::[^=]*)?=\\s*([0-9.]+)" % name)
		var m := re.search(text)
		if m == null:
			return {}
		out[name] = float(m.get_string(1))
	return out


## The shader's fragment arithmetic for one face, quantised to 8 bits.
func _face_value(c: float, factor: float, sep_index: float, min_sep: float) -> int:
	return int(round(255.0 * maxf(c * factor - min_sep * sep_index, 0.0)))


## Sweep every art pixel against the real darkening canon and count how often
## the three faces collapse. Returns {"total", "collapsed", "worst_visible"} —
## worst_visible is the brightest top-face value that still collapsed, which is
## the number that actually matters: a collapse at 2/255 is invisible, a
## collapse at 38/255 is a flat-looking mid-tone voxel.
func _scan(uniforms: Dictionary, min_sep: float) -> Dictionary:
	var renderer := VoxelRendererClass.new()
	var field := VoxelLightFieldClass.new()
	var factors: Array = [uniforms["face_top"], uniforms["face_se"], uniforms["face_sw"]]

	var total: int = 0
	var collapsed: int = 0
	var worst_visible: int = 0
	for art in range(4, 256):
		for lum in renderer.bucket_luminance:
			for soot in ([1.0] as Array) + field.soot_darkening:
				for depth in VoxelRendererClass.FLOOR_DEPTH_DIM:
					var c: float = (float(art) / 255.0) * lum * float(soot) * depth
					var v0: int = _face_value(c, factors[0], 0.0, min_sep)
					var v1: int = _face_value(c, factors[1], 1.0, min_sep)
					var v2: int = _face_value(c, factors[2], 2.0, min_sep)
					total += 1
					if v0 == v1 or v1 == v2 or v0 == v2:
						collapsed += 1
						worst_visible = maxi(worst_visible, v0)
	renderer.free()
	return {"total": total, "collapsed": collapsed, "worst_visible": worst_visible}


## The guarantee itself: wherever a voxel is visible at all, its three faces
## must quantise to three different 8-bit values.
func test_three_faces_never_identical(uniforms: Dictionary) -> void:
	print("[1] Three faces stay distinct wherever the voxel is above black\n")
	var r := _scan(uniforms, uniforms["face_min_sep"])
	var pct: float = 100.0 * float(r["collapsed"]) / float(r["total"])
	if int(r["worst_visible"]) <= BLACK_CEILING:
		_pass("%d/%d combinations collapse (%.1f%%), and every one is at top face <= %d/255 — black on screen"
			% [r["collapsed"], r["total"], pct, r["worst_visible"]])
	else:
		_fail("a VISIBLE voxel renders identical faces: brightest collapsing top face is %d/255 (limit %d)"
			% [r["worst_visible"], BLACK_CEILING])
	print("")


## Teeth: the same scan with the separation term switched off must fail loudly.
## Without this, a future edit setting face_min_sep to 0 would leave test 1
## passing on the multiplies alone and the guarantee would quietly evaporate —
## which is the exact state this feature was built to fix.
func test_guarantee_depends_on_the_separation_term(uniforms: Dictionary) -> void:
	print("[2] The guarantee comes from the separation term, not from the multiplies\n")
	var off := _scan(uniforms, 0.0)
	var on := _scan(uniforms, uniforms["face_min_sep"])
	if int(off["worst_visible"]) > BLACK_CEILING and int(off["collapsed"]) > int(on["collapsed"]):
		_pass("min_sep=0 collapses %d/%d (worst visible %d/255) vs %d/%d with it — the test has teeth"
			% [off["collapsed"], off["total"], off["worst_visible"], on["collapsed"], on["total"]])
	else:
		_fail("removing min_sep changed nothing (off=%s on=%s) — test 1 would pass vacuously"
			% [off["collapsed"], on["collapsed"]])
	print("")


## The concrete case the Director reported the principle against: a ring-0
## sooted voxel in the darkest light bucket, which rendered [4, 4, 4] before
## this term existed.
func test_sooted_dark_voxel_is_separable(uniforms: Dictionary) -> void:
	print("[3] The reported case: darkest bucket + ring-0 soot\n")
	var renderer := VoxelRendererClass.new()
	var field := VoxelLightFieldClass.new()
	var c: float = (170.0 / 255.0) * renderer.bucket_luminance[0] * field.soot_darkening[0]
	var v0: int = _face_value(c, uniforms["face_top"], 0.0, uniforms["face_min_sep"])
	var v1: int = _face_value(c, uniforms["face_se"], 1.0, uniforms["face_min_sep"])
	var v2: int = _face_value(c, uniforms["face_sw"], 2.0, uniforms["face_min_sep"])
	var before0: int = _face_value(c, uniforms["face_top"], 0.0, 0.0)
	var before1: int = _face_value(c, uniforms["face_se"], 1.0, 0.0)
	var before2: int = _face_value(c, uniforms["face_sw"], 2.0, 0.0)
	renderer.free()
	if v0 != v1 and v1 != v2 and v0 != v2:
		_pass("bucket %.2f x soot %.2f: [%d, %d, %d] distinct (was [%d, %d, %d])"
			% [0.12, 0.20, v0, v1, v2, before0, before1, before2])
	else:
		_fail("the reported case still renders [%d, %d, %d]" % [v0, v1, v2])
	print("")
