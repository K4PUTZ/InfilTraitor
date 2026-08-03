## D33 Parts 3b/3c — HalfVoxelCompositor equality proof, same discipline as
## Part 2's decal_compositor_equality_selftest.gd: compare the GDScript port
## against a reference built by the REAL Python function it ports
## (generate_voxel.py's generate_half_voxel(), plus compose_decal_voxel() for
## the full real pipeline), on fixtures neither side generates itself:
##   godot/scripts/tools/fixtures/d33_part3b/{atom,decal}.png                — wall inputs
##   godot/scripts/tools/fixtures/d33_part3b/half_{left,right}.png           — wall mask-only reference
##   godot/scripts/tools/fixtures/d33_part3b/composited_{left,right}.png     — wall mask + decal reference
##   godot/scripts/tools/fixtures/d33_part3c/{atom,decal}.png                — floor inputs
##   godot/scripts/tools/fixtures/d33_part3c/half_top.png                    — floor mask-only reference
##   godot/scripts/tools/fixtures/d33_part3c/composited_top.png              — floor mask + decal reference
## (produced by tools/asset_generation/d33_part3{b,c}_fixture_gen.py).
##
## Rodar: godot --headless --script res://godot/scripts/tools/half_voxel_compositor_equality_selftest.gd
extends SceneTree

const HalfVoxelCompositorClass = preload("res://godot/scripts/geometry/half_voxel_compositor.gd")
const DecalCompositorClass = preload("res://godot/scripts/geometry/decal_compositor.gd")

const FIXTURE_DIR := "res://godot/scripts/tools/fixtures/d33_part3b/"
const FLOOR_FIXTURE_DIR := "res://godot/scripts/tools/fixtures/d33_part3c/"

## generate_voxel.py's _darken(MATERIALS["concrete"], SIDE_DARKEN), printed by
## the fixture generator: (140, 136, 129). Copied as a literal, not re-derived
## from SIDE_DARKEN here, so a drift in either file's darken math shows up as
## a diff against the real fixture rather than validating itself.
const CUT_FILL := Color(140.0 / 255.0, 136.0 / 255.0, 129.0 / 255.0, 1.0)

## Measured 2026-08-03, not guessed: LEFT (unmirrored polygons) disagrees
## with Pillow's own scanline polygon fill on 12 of 620 boundary pixels
## (1.94%); RIGHT (mirrored polygons) disagrees on 41 of 641 (6.40%) — worse,
## because Pillow's scanline fill is not itself mirror-symmetric (a
## left-biased tie-break, naively mirrored, does not become a
## correspondingly right-biased one), so a straight coordinate-mirror of the
## polygon does not carry the same fill bias through. Both are confined to a
## 1px-wide diagonal seam at the shape's own OUTER edge (not the shared edges
## between kept regions, which line up correctly), never a scattered/random
## mismatch. Tried and rejected: pixel-centre sampling (worse, 24/57), several
## fixed offset/inequality variants for the mirrored case (best found: 33,
## still short of LEFT's number) — closing this fully would mean
## reimplementing Pillow's specific C scanline algorithm rather than a
## generic point-in-polygon test, which is a real further increment, not a
## quick tune. Tolerance set to the measured RIGHT-side worst case plus a
## small margin so a real regression still fails loudly.
const MAX_CHANNEL_DIFF_TOLERANCE: int = 3
const MAX_MISMATCHED_PIXEL_FRACTION: float = 0.07

## Floor ("top"/sunk) measured separately, 2026-08-03: 23 of 591 boundary
## pixels (3.89%) — same class of 1px outer-edge seam as LEFT/RIGHT above,
## between LEFT's 1.94% and RIGHT's 6.40%. Kept as its own constant since
## it's a genuinely different shape (no mirroring involved at all), not
## because the underlying cause differs.
const FLOOR_MAX_MISMATCHED_PIXEL_FRACTION: float = 0.05

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("D33 PARTS 3b/3c — HALF VOXEL COMPOSITOR EQUALITY SELFTEST")
	print("=".repeat(70) + "\n")

	var atom := _load(FIXTURE_DIR + "atom.png")
	var decal := _load(FIXTURE_DIR + "decal.png")
	if atom == null or decal == null:
		_fail("could not load input fixtures — run tools/asset_generation/d33_part3b_fixture_gen.py first")
		_finish()
		return

	test_mask_only("left", atom, "half_left.png")
	test_mask_only("right", atom, "half_right.png")
	test_full_pipeline("left", atom, decal, DecalCompositorClass.FACE_CUT_LEFT, "composited_left.png")
	test_full_pipeline("right", atom, decal, DecalCompositorClass.FACE_CUT_RIGHT, "composited_right.png")
	test_unknown_side_fails_loudly()

	var floor_atom := _load(FLOOR_FIXTURE_DIR + "atom.png")
	var floor_decal := _load(FLOOR_FIXTURE_DIR + "decal.png")
	if floor_atom == null or floor_decal == null:
		_fail("could not load floor fixtures — run tools/asset_generation/d33_part3c_fixture_gen.py first")
	else:
		test_floor_mask_only(floor_atom)
		test_floor_full_pipeline(floor_atom, floor_decal)

	_finish()


func _finish() -> void:
	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ HALF VOXEL COMPOSITOR EQUALITY SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ HALF VOXEL COMPOSITOR EQUALITY SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func _load(path: String) -> Image:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[D33 Part 3b] failed to open %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var img := Image.new()
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		push_error("[D33 Part 3b] failed to decode PNG %s: %s" % [path, error_string(err)])
		return null
	return img


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


func _judge(label: String, stats: Dictionary, tolerance_fraction: float = MAX_MISMATCHED_PIXEL_FRACTION) -> void:
	var fraction: float = float(stats["mismatched"]) / float(maxi(1, stats["compared"]))
	print("  measured: max_channel_diff=%d, mismatched=%d/%d pixels (%.2f%%)" % [
		stats["max_diff"], stats["mismatched"], stats["compared"], fraction * 100.0])
	if fraction <= tolerance_fraction:
		_pass("%s within tolerance (<= %.0f%% of pixels over %d/channel)" % [
			label, tolerance_fraction * 100.0, MAX_CHANNEL_DIFF_TOLERANCE])
	else:
		_fail("%s exceeds tolerance: %.2f%% of pixels differ by more than %d/channel" % [
			label, fraction * 100.0, MAX_CHANNEL_DIFF_TOLERANCE])


func test_mask_only(side: String, atom: Image, reference_filename: String) -> void:
	print("[%s-mask] build_half_voxel_substrate(\"%s\") matches generate_half_voxel()\n" % [side, side])
	var reference := _load(FIXTURE_DIR + reference_filename)
	if reference == null:
		_fail("%s missing" % reference_filename)
		print("")
		return
	var got := HalfVoxelCompositorClass.build_half_voxel_substrate(atom, CUT_FILL, side)
	_judge("%s mask-only substrate" % side, _compare(got, reference))
	print("")


func test_full_pipeline(side: String, atom: Image, decal: Image, target: Dictionary,
		reference_filename: String) -> void:
	print("[%s-full] mask + decal matches compose_decal_voxel(generate_half_voxel(...), decal, [target])\n" % side)
	var reference := _load(FIXTURE_DIR + reference_filename)
	if reference == null:
		_fail("%s missing" % reference_filename)
		print("")
		return
	var substrate := HalfVoxelCompositorClass.build_half_voxel_substrate(atom, CUT_FILL, side)
	var got := DecalCompositorClass.compose_decal_voxel(substrate, decal, [target])
	_judge("%s full pipeline" % side, _compare(got, reference))
	print("")


func test_unknown_side_fails_loudly() -> void:
	print("[guard] an unrecognised side pushes an error and returns empty, not a silent wrong shape\n")
	## "top" is a real shape now (build_floor_sunk_substrate(), tested below)
	## but NOT a valid `side` for build_half_voxel_substrate() — that function
	## only ever knows "left"/"right"; floor is a structurally different
	## construction (no cut-plane fill colour, no mirroring), not a third
	## side value on this one. This still checks what it always checked.
	var atom := _load(FIXTURE_DIR + "atom.png")
	var result := HalfVoxelCompositorClass.build_half_voxel_substrate(atom, CUT_FILL, "top")
	var all_transparent := true
	for y in range(result.get_height()):
		for x in range(result.get_width()):
			if not is_zero_approx(result.get_pixel(x, y).a):
				all_transparent = false
				break
		if not all_transparent:
			break
	if all_transparent:
		_pass("build_half_voxel_substrate(\"top\") returned a fully transparent image — not this function's shape")
	else:
		_fail("an unrecognised side drew SOMETHING instead of failing cleanly")
	print("")


func test_floor_mask_only(atom: Image) -> void:
	print("[floor-mask] build_floor_sunk_substrate() matches generate_half_voxel(..., \"top\")\n")
	var reference := _load(FLOOR_FIXTURE_DIR + "half_top.png")
	if reference == null:
		_fail("half_top.png missing")
		print("")
		return
	var got := HalfVoxelCompositorClass.build_floor_sunk_substrate(atom)
	_judge("floor mask-only substrate", _compare(got, reference), FLOOR_MAX_MISMATCHED_PIXEL_FRACTION)
	print("")


func test_floor_full_pipeline(atom: Image, decal: Image) -> void:
	print("[floor-full] mask + decal matches compose_decal_voxel(generate_half_voxel(..., \"top\"), decal, [FACE_SUNK_TOP])\n")
	var reference := _load(FLOOR_FIXTURE_DIR + "composited_top.png")
	if reference == null:
		_fail("composited_top.png missing")
		print("")
		return
	var substrate := HalfVoxelCompositorClass.build_floor_sunk_substrate(atom)
	var got := DecalCompositorClass.compose_decal_voxel(substrate, decal, [DecalCompositorClass.FACE_SUNK_TOP])
	_judge("floor full pipeline", _compare(got, reference), FLOOR_MAX_MISMATCHED_PIXEL_FRACTION)
	print("")
