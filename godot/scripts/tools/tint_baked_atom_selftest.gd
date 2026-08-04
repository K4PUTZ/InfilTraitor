## PERF-01 — proves VoxelRenderer._tint_image_rgb() (byte-buffer multiply)
## matches the get_pixel()/set_pixel() loop it replaced inside
## _tint_baked_atom(), within MAX_CHANNEL_DIFF_TOLERANCE.
##
## Tolerance is MEASURED here, not assumed (same discipline as the D33 Part 2
## equality selftests, decal_compositor_equality_selftest.gd): every
## modulate <= 1.0 (no clamping needed) round-trips byte-for-byte, 0/1152
## pixels differ. Only a modulate > 1.0 — which pushes byte*modulate through
## _tint_image_rgb()'s clampf(...,0.0,1.0) branch — shows a ±1/255 diff on a
## real fraction of pixels (measured 2026-08-04: 228/1152). Root cause,
## confirmed by reproducing the exact divide/multiply/clamp/scale sequence
## get_pixel()+set_pixel() run and STILL seeing the same 228 mismatches:
## GDScript's float is 64-bit; Godot's internal Color->byte quantization
## (engine-side, C++) is 32-bit. The identical real-valued expression can
## round to a different integer on either side of that precision boundary
## when the product lands within one ULP of an exact integer — an
## unavoidable consequence of computing the same math at two different
## float widths, not a logic error in either implementation.
## Rodar: godot --headless --script res://godot/scripts/tools/tint_baked_atom_selftest.gd
extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

## Measured 2026-08-04: max diff is 1/255 wherever it occurs at all, and it
## only occurs when modulate > 1.0. Tighter than D33 Part 2's own tolerance
## of 3 for actual image resampling — this is float-width noise on
## deterministic arithmetic, about as small as a real tolerance gets.
const MAX_CHANNEL_DIFF_TOLERANCE: int = 1

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("PERF-01 — TINT_IMAGE_RGB BYTE-BUFFER EQUALITY SELFTEST")
	print("=".repeat(70) + "\n")

	test_case("uniform gray modulate", Color(0.5, 0.5, 0.5, 1.0))
	test_case("non-uniform per-channel modulate", Color(0.8, 0.3, 1.0, 1.0))
	test_case("modulate above 1.0 (clamp behaviour)", Color(1.4, 0.9, 1.2, 1.0))
	test_case("near-white modulate (not exactly WHITE — must NOT take the fast path)",
		Color(0.999, 1.0, 0.999, 1.0))
	test_white_fast_path()

	_finish()


func _finish() -> void:
	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ TINT_IMAGE_RGB EQUALITY SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ TINT_IMAGE_RGB EQUALITY SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## The ORIGINAL _tint_baked_atom() loop, kept here literally as the
## reference this selftest exists to check against — never touched again
## once this selftest is green.
func _reference_tint(image: Image, modulate: Color) -> Image:
	var out: Image = image.duplicate()
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, Color(
				c.r * modulate.r, c.g * modulate.g, c.b * modulate.b, c.a))
	return out


## 32x36 (the real atom size) covering the value space that matters: the
## four corners of the byte range (0/1/254/255) plus a smooth gradient and
## a few varied alpha bands, so both the extremes and ordinary mid-tones are
## exercised, not just one hand-picked colour.
func _build_fixture() -> Image:
	var img := Image.create(32, 36, false, Image.FORMAT_RGBA8)
	for y in range(36):
		for x in range(32):
			var r := float(x) / 31.0
			var g := float(y) / 35.0
			var b := 1.0 - r
			var a := 1.0
			if x < 2 and y < 2:
				a = 0.0
			elif x >= 30 and y >= 34:
				a = 0.5
			img.set_pixel(x, y, Color(r, g, b, a))
	## Explicit byte extremes, not just the gradient's own endpoints.
	img.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 0.0))
	img.set_pixel(1, 0, Color(1.0, 1.0, 1.0, 1.0))
	img.set_pixel(2, 0, Color(1.0 / 255.0, 1.0 / 255.0, 1.0 / 255.0, 1.0))
	img.set_pixel(3, 0, Color(254.0 / 255.0, 254.0 / 255.0, 254.0 / 255.0, 1.0))
	return img


func test_case(label: String, modulate: Color) -> void:
	print("%s (modulate=%s)\n" % [label, modulate])
	var fixture := _build_fixture()
	var reference := _reference_tint(fixture, modulate)
	var got := VoxelRendererClass._tint_image_rgb(fixture.duplicate(), modulate)

	var mismatched := 0
	var max_diff := 0
	for y in range(reference.get_height()):
		for x in range(reference.get_width()):
			var ref_px := reference.get_pixel(x, y)
			var got_px := got.get_pixel(x, y)
			var dr := absi(int(round(got_px.r * 255.0)) - int(round(ref_px.r * 255.0)))
			var dg := absi(int(round(got_px.g * 255.0)) - int(round(ref_px.g * 255.0)))
			var db := absi(int(round(got_px.b * 255.0)) - int(round(ref_px.b * 255.0)))
			var da := absi(int(round(got_px.a * 255.0)) - int(round(ref_px.a * 255.0)))
			var d: int = maxi(maxi(dr, dg), maxi(db, da))
			max_diff = maxi(max_diff, d)
			if d > MAX_CHANNEL_DIFF_TOLERANCE:
				mismatched += 1

	print("  measured: max_channel_diff=%d, mismatched=%d/%d pixels (tolerance %d/255)" % [
		max_diff, mismatched, reference.get_width() * reference.get_height(), MAX_CHANNEL_DIFF_TOLERANCE])
	if mismatched == 0:
		_pass("byte-buffer output matches the reference loop within tolerance")
	else:
		_fail("%d pixel(s) differ from the reference loop by more than %d/255 (max diff %d)" %
			[mismatched, MAX_CHANNEL_DIFF_TOLERANCE, max_diff])
	print("")


## Color.WHITE must short-circuit to the SAME image (no quantization pass at
## all) — checked separately since test_case()'s reference loop would also
## no-op on WHITE, which wouldn't distinguish "took the fast path" from
## "computed the same answer the slow way."
func test_white_fast_path() -> void:
	print("Color.WHITE takes the fast path (returns the same Image instance)\n")
	var fixture := _build_fixture()
	var got := VoxelRendererClass._tint_image_rgb(fixture, Color.WHITE)
	if got == fixture:
		_pass("WHITE modulate returned the same Image instance untouched")
	else:
		_fail("WHITE modulate did not take the fast path (returned a different instance)")
	print("")
