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
## to stay separable against (VoxelRenderer.bucket_luminance and its
## FLOOR_DEPTH_DIM). Either side can be retuned in good faith and silently
## destroy the guarantee — soot to 0.20 is exactly what broke it originally — so
## both sides are read from their real owners here, and the shader constants are
## PARSED from the shader file rather than copied, so a value changed there fails
## this test instead of drifting.
##
## FACE-SOOT-01 (2026-08-01) moved soot OUT of the light bucket and into this
## same shader, as a per-face multiplier (`soot_face_mult`). The scan follows it:
## the incoming colour is now bucket x depth only, and every one of the 64
## per-face ring COMBINATIONS is swept, because two faces at different soot rings
## are a collapse risk this test could not previously even express.
##
## A headless run has no rasteriser, so this reproduces the shader's arithmetic
## rather than sampling real pixels: quantised 8-bit output for each of the
## three faces. That is a deliberate, stated substitution — the real-pixel
## evidence for this feature is the capture cited in the session record.

extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const VoxelLightFieldClass = preload("res://godot/scripts/systems/lighting/voxel_light_field.gd")
const SHADER_PATH := "res://godot/shaders/voxel_face_shading.gdshader"

## FACE-READ-03 made the guarantee unconditional (residue classes mod 3 cannot
## collide), so there is no longer a dark range the test has to exempt. The
## constant is kept at 0 as the assertion that NOTHING is exempt — if a future
## mechanism reintroduces a blind spot, this is where it has to be argued for.
const BLACK_CEILING := 0

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
	print("  shader constants: top=%.4f se=%.4f sw=%.4f residue_sep=%.1f soot=%s\n"
		% [uniforms["face_top"], uniforms["face_se"], uniforms["face_sw"],
		uniforms["face_residue_sep"], uniforms["soot_face_mult"]])

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
	for name in ["face_top", "face_se", "face_sw", "face_residue_sep"]:
		var re := RegEx.new()
		re.compile("uniform\\s+float\\s+%s\\s*(?::[^=]*)?=\\s*([0-9.]+)" % name)
		var m := re.search(text)
		if m == null:
			return {}
		out[name] = float(m.get_string(1))
	## FACE-SOOT-01: the ring -> multiplier table, parsed the same way. Index 3 is
	## "clean" and must be 1.0, or an untouched voxel would be tinted by a table
	## it is not supposed to be subject to at all.
	var vre := RegEx.new()
	vre.compile("uniform\\s+vec4\\s+soot_face_mult\\s*=\\s*vec4\\(([^)]*)\\)")
	var vm := vre.search(text)
	if vm == null:
		return {}
	var mults: Array[float] = []
	for part in vm.get_string(1).split(","):
		mults.append(float(part.strip_edges()))
	if mults.size() != 4:
		return {}
	out["soot_face_mult"] = mults
	return out


## The shader's fragment arithmetic for one face, quantised to 8 bits.
## `soot` is soot_face_mult[ring] for THIS face (FACE-SOOT-01) — 1.0 when clean.
## `residue` mirrors the face_residue_sep uniform: > 0 forces the value onto this
## face's own residue class mod 3 (FACE-READ-03), 0 leaves it raw.
func _face_value(c: float, factor: float, sep_index: float, residue: float,
		soot: float = 1.0) -> int:
	var q: int = int(round(255.0 * maxf(c * factor * soot, 0.0)))
	if residue <= 0.0:
		return q
	var adj: int = q - posmod(q - int(sep_index), 3)
	if adj < 0:
		adj += 3
	return adj


## Sweep every art pixel against the real darkening canon and count how often
## the three faces collapse. Returns {"total", "collapsed", "worst_visible"} —
## worst_visible is the brightest top-face value that still collapsed, which is
## the number that actually matters: a collapse at 2/255 is invisible, a
## collapse at 38/255 is a flat-looking mid-tone voxel.
func _scan(uniforms: Dictionary, residue: float) -> Dictionary:
	var renderer := VoxelRendererClass.new()
	var factors: Array = [uniforms["face_top"], uniforms["face_se"], uniforms["face_sw"]]
	var mult: Array = uniforms["soot_face_mult"]

	var total: int = 0
	var collapsed: int = 0
	var worst_visible: int = 0
	## FACE-SOOT-01: soot is no longer part of the incoming colour — it is a
	## PER-FACE multiply inside the shader, so the sweep runs over every one of
	## the 64 (top, se, sw) ring combinations the code space can deliver.
	for art in range(4, 256):
		for lum in renderer.bucket_luminance:
			for depth in VoxelRendererClass.FLOOR_DEPTH_DIM:
				var c: float = (float(art) / 255.0) * lum * depth
				for code in range(64):
					var rings := VoxelLightFieldClass.decode_face_soot(code)
					var v0: int = _face_value(c, factors[0], 0.0, residue, mult[rings.x])
					var v1: int = _face_value(c, factors[1], 1.0, residue, mult[rings.y])
					var v2: int = _face_value(c, factors[2], 2.0, residue, mult[rings.z])
					total += 1
					if v0 == v1 or v1 == v2 or v0 == v2:
						collapsed += 1
						worst_visible = maxi(worst_visible, maxi(v0, maxi(v1, v2)))
	renderer.free()
	return {"total": total, "collapsed": collapsed, "worst_visible": worst_visible}


## The guarantee itself: wherever a voxel is visible at all, its three faces
## must quantise to three different 8-bit values.
func test_three_faces_never_identical(uniforms: Dictionary) -> void:
	print("[1] Three faces stay distinct — unconditionally, per-face soot included\n")
	var r := _scan(uniforms, uniforms["face_residue_sep"])
	var pct: float = 100.0 * float(r["collapsed"]) / float(r["total"])
	if int(r["collapsed"]) == 0:
		_pass("0/%d combinations collapse — no light, depth, colour or per-face soot merges two faces"
			% r["total"])
	else:
		_fail("a voxel renders two identical faces in %d/%d combinations (%.1f%%), brightest at %d/255"
			% [r["collapsed"], r["total"], pct, r["worst_visible"]])
	print("")


## Teeth: the same scan with the separation term switched off must fail loudly.
## Without this, a future edit setting face_min_sep to 0 would leave test 1
## passing on the multiplies alone and the guarantee would quietly evaporate —
## which is the exact state this feature was built to fix.
func test_guarantee_depends_on_the_separation_term(uniforms: Dictionary) -> void:
	print("[2] The guarantee comes from the residue enforcement, not from the multiplies\n")
	var off := _scan(uniforms, 0.0)
	var on := _scan(uniforms, uniforms["face_residue_sep"])
	if int(off["worst_visible"]) > BLACK_CEILING and int(off["collapsed"]) > int(on["collapsed"]):
		_pass("residue_sep=0 collapses %d/%d (worst visible %d/255) vs %d/%d with it — the test has teeth"
			% [off["collapsed"], off["total"], off["worst_visible"], on["collapsed"], on["total"]])
	else:
		_fail("removing residue_sep changed nothing (off=%s on=%s) — test 1 would pass vacuously"
			% [off["collapsed"], on["collapsed"]])
	print("")


## The concrete case the Director reported the principle against: a ring-0
## sooted voxel in the darkest light bucket, which rendered [4, 4, 4] before
## this term existed.
func test_sooted_dark_voxel_is_separable(uniforms: Dictionary) -> void:
	print("[3] The reported case: darkest bucket + ring-0 soot\n")
	var renderer := VoxelRendererClass.new()
	var mult: Array = uniforms["soot_face_mult"]
	var renderer_bucket0: float = renderer.bucket_luminance[0]
	## Ring 0 on every face, in the darkest light bucket — the exact combination
	## that rendered [4, 4, 4] before FACE-READ-02, now routed through
	## FACE-SOOT-01's per-face multiplier instead of the bucket.
	var c: float = (170.0 / 255.0) * renderer.bucket_luminance[0]
	var v0: int = _face_value(c, uniforms["face_top"], 0.0, uniforms["face_residue_sep"], mult[0])
	var v1: int = _face_value(c, uniforms["face_se"], 1.0, uniforms["face_residue_sep"], mult[0])
	var v2: int = _face_value(c, uniforms["face_sw"], 2.0, uniforms["face_residue_sep"], mult[0])
	var before0: int = _face_value(c, uniforms["face_top"], 0.0, 0.0, mult[0])
	var before1: int = _face_value(c, uniforms["face_se"], 1.0, 0.0, mult[0])
	var before2: int = _face_value(c, uniforms["face_sw"], 2.0, 0.0, mult[0])
	renderer.free()
	if v0 != v1 and v1 != v2 and v0 != v2:
		_pass("bucket %.2f x ring-0 soot %.2f: [%d, %d, %d] distinct (residue off: [%d, %d, %d])"
			% [renderer_bucket0, mult[0], v0, v1, v2, before0, before1, before2])
	else:
		_fail("the reported case still renders [%d, %d, %d]" % [v0, v1, v2])
	print("")
