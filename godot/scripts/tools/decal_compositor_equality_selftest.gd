## D33 Part 2 — the equality proof the plan calls "the single highest-risk
## step" (PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 2). Compares
## DecalCompositor's GDScript output against a reference composited by the
## REAL Python function it ports (generate_voxel.py's compose_decal_voxel),
## on fixtures neither side generates itself:
##   godot/scripts/tools/fixtures/d33_part2/{substrate,decal}.png       — inputs
##   godot/scripts/tools/fixtures/d33_part2/reference_{lateral,top}.png — Python output
## (produced by tools/asset_generation/d33_part2_fixture_gen.py, which calls
## the real _paste_decal/compose_decal_voxel unmodified).
##
## Rodar: godot --headless --script res://godot/scripts/tools/decal_compositor_equality_selftest.gd
##
## Tolerance is MEASURED here, not assumed: DecalCompositor's own doc comment
## names two real sources of divergence (Lanczos implementation differences,
## Python round-half-to-even vs Godot's round-half-up at 8-bit quantization).
## The thresholds below are the actual measured worst case on this fixture,
## recorded so a future regression shows up as a real failure instead of a
## silently loosened bound.
extends SceneTree

const DecalCompositorClass = preload("res://godot/scripts/geometry/decal_compositor.gd")

const FIXTURE_DIR := "res://godot/scripts/tools/fixtures/d33_part2/"

## DecalCompositor.FACE_SE / FACE_TOP — the same constants Part 3's real
## wiring uses (single source of truth, added when Part 3a needed named face
## targets rather than the literal tuples this selftest originally carried).
## Still a valid equality check either way: the ground truth
## (reference_lateral/top.png) was rendered by generate_voxel.py's
## INDEPENDENTLY-DEFINED _FACE_SE/_FACE_TOP, so a future bug in
## DecalCompositor's own constants would still show up as a diff against that
## fixture, not get silently validated against itself.
const FACE_SE := DecalCompositorClass.FACE_SE
const FACE_TOP := DecalCompositorClass.FACE_TOP

## Measured 2026-08-03 on this exact fixture: max_channel_diff=1 (of 255),
## 0 of 911 compared pixels differ at all past that — the Lanczos/rounding
## divergences named in DecalCompositor's doc comment turned out to matter far
## less than expected on this soft-edged decal. These constants are that real
## first measurement plus a small margin, not the guess that preceded it
## (which was 12 / 5% — kept here in this comment, not in the code, as the
## record of what was assumed before it was checked).
const MAX_CHANNEL_DIFF_TOLERANCE: int = 3
const MAX_MISMATCHED_PIXEL_FRACTION: float = 0.0  # of the substrate's opaque pixels

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("D33 PART 2 — DECAL COMPOSITOR EQUALITY SELFTEST")
	print("=".repeat(70) + "\n")

	var substrate := _load(FIXTURE_DIR + "substrate.png")
	var decal := _load(FIXTURE_DIR + "decal.png")
	if substrate == null or decal == null:
		_fail("could not load input fixtures — run tools/asset_generation/d33_part2_fixture_gen.py first")
		_finish()
		return

	test_lateral_face(substrate, decal)
	test_top_face(substrate, decal)
	test_b3_clamp_never_exceeds_substrate_silhouette(substrate, decal)

	_finish()


func _finish() -> void:
	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ DECAL COMPOSITOR EQUALITY SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ DECAL COMPOSITOR EQUALITY SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## Reads the PNG's raw bytes and decodes them directly, deliberately not via
## Image.load_from_file()/ResourceLoader — those route fixture PNGs through
## the imported-resource pipeline and warn "will not work on export" (true,
## and irrelevant here: these fixtures exist only for this headless selftest,
## never for a shipped build, but the warning is real and this avoids it
## rather than tolerating it).
func _load(path: String) -> Image:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[D33 Part 2] failed to open %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var img := Image.new()
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		push_error("[D33 Part 2] failed to decode PNG %s: %s" % [path, error_string(err)])
		return null
	return img


## Returns {"max_diff": int, "mismatched": int, "compared": int} comparing
## `got` against `reference` over every pixel where the REFERENCE is not
## fully transparent (an untouched transparent corner agreeing on nothing
## meaningful there is not the claim this test makes).
func _compare(got: Image, reference: Image) -> Dictionary:
	var max_diff := 0
	var mismatched := 0
	var compared := 0
	for y in range(reference.get_height()):
		for x in range(reference.get_width()):
			var ref_px := reference.get_pixel(x, y)
			if is_zero_approx(ref_px.a) and is_zero_approx(got.get_pixel(x, y).a):
				continue
			compared += 1
			var got_px := got.get_pixel(x, y)
			var d := maxi(maxi(
				absi(int(round(got_px.r * 255.0)) - int(round(ref_px.r * 255.0))),
				absi(int(round(got_px.g * 255.0)) - int(round(ref_px.g * 255.0)))),
				maxi(absi(int(round(got_px.b * 255.0)) - int(round(ref_px.b * 255.0))),
				absi(int(round(got_px.a * 255.0)) - int(round(ref_px.a * 255.0)))))
			max_diff = maxi(max_diff, d)
			if d > MAX_CHANNEL_DIFF_TOLERANCE:
				mismatched += 1
	return {"max_diff": max_diff, "mismatched": mismatched, "compared": compared}


func test_lateral_face(substrate: Image, decal: Image) -> void:
	print("[1] Lateral face (_FACE_SE) matches the real Python compositor\n")
	var got := DecalCompositorClass.compose_decal_voxel(substrate, decal, [FACE_SE])
	var reference := _load(FIXTURE_DIR + "reference_lateral.png")
	if reference == null:
		_fail("reference_lateral.png missing")
		print("")
		return

	var stats := _compare(got, reference)
	var fraction: float = float(stats["mismatched"]) / float(maxi(1, stats["compared"]))
	print("  measured: max_channel_diff=%d, mismatched=%d/%d pixels (%.2f%%)" % [
		stats["max_diff"], stats["mismatched"], stats["compared"], fraction * 100.0])

	if fraction <= MAX_MISMATCHED_PIXEL_FRACTION:
		_pass("lateral face within tolerance (<= %.0f%% of pixels over %d/channel)" % [
			MAX_MISMATCHED_PIXEL_FRACTION * 100.0, MAX_CHANNEL_DIFF_TOLERANCE])
	else:
		_fail("lateral face exceeds tolerance: %.2f%% of pixels differ by more than %d/channel" % [
			fraction * 100.0, MAX_CHANNEL_DIFF_TOLERANCE])
	print("")


func test_top_face(substrate: Image, decal: Image) -> void:
	print("[2] Top face (_FACE_TOP) matches the real Python compositor\n")
	var got := DecalCompositorClass.compose_decal_voxel(substrate, decal, [FACE_TOP])
	var reference := _load(FIXTURE_DIR + "reference_top.png")
	if reference == null:
		_fail("reference_top.png missing")
		print("")
		return

	var stats := _compare(got, reference)
	var fraction: float = float(stats["mismatched"]) / float(maxi(1, stats["compared"]))
	print("  measured: max_channel_diff=%d, mismatched=%d/%d pixels (%.2f%%)" % [
		stats["max_diff"], stats["mismatched"], stats["compared"], fraction * 100.0])

	if fraction <= MAX_MISMATCHED_PIXEL_FRACTION:
		_pass("top face within tolerance (<= %.0f%% of pixels over %d/channel)" % [
			MAX_MISMATCHED_PIXEL_FRACTION * 100.0, MAX_CHANNEL_DIFF_TOLERANCE])
	else:
		_fail("top face exceeds tolerance: %.2f%% of pixels differ by more than %d/channel" % [
			fraction * 100.0, MAX_CHANNEL_DIFF_TOLERANCE])
	print("")


## B3, checked independently of pixel-value equality: even if the decal's
## COLOR math ever drifted, the SILHOUETTE must never expand past the
## substrate's own alpha — that is the invariant, not a side effect of
## matching Python closely enough.
func test_b3_clamp_never_exceeds_substrate_silhouette(substrate: Image, decal: Image) -> void:
	print("[3] B3 — the composite's silhouette never exceeds the substrate's own alpha\n")
	var got := DecalCompositorClass.compose_decal_voxel(substrate, decal, [FACE_SE, FACE_TOP])
	var violations := 0
	for y in range(substrate.get_height()):
		for x in range(substrate.get_width()):
			if is_zero_approx(substrate.get_pixel(x, y).a) and not is_zero_approx(got.get_pixel(x, y).a):
				violations += 1
	if violations == 0:
		_pass("no pixel outside the substrate's silhouette gained alpha (B3 holds)")
	else:
		_fail("%d pixel(s) outside the substrate's silhouette gained alpha — B3 violated" % violations)
	print("")
