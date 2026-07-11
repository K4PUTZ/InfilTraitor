## TOP-SHEAR-01 — Standalone T-image verification
## Usage: godot --headless --path . --script godot/scripts/tools/top_shear_test.gd

extends SceneTree

const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")

const SAMPLE_COUNT: int = 256
const SEED_VALUE: int = 0x5A1E
const Y_MARGIN: int = 32

func _init() -> void:
	seed(SEED_VALUE)
	print("TOP-SHEAR-01 — T-image shear verification")
	print("=".repeat(80))

	var compositor = BakeCompositorClass.new()
	var facade := _make_facade()
	var source0 := _build_s_ext(facade, 0)
	var source1 := _build_s_ext(facade, 1)

	var legacy_mismatches := _score_legacy(source0)
	var dir0_mismatches := _score_plane(compositor, facade, 0, source0)
	var dir1_mismatches := _score_plane(compositor, facade, 1, source1)

	print("Legacy unsheared baseline mismatches: %d / %d" % [legacy_mismatches, SAMPLE_COUNT])
	print("Dir 0 mismatches: %d / %d" % [dir0_mismatches, SAMPLE_COUNT])
	print("Dir 1 mismatches: %d / %d" % [dir1_mismatches, SAMPLE_COUNT])

	if dir0_mismatches == 0 and dir1_mismatches == 0:
		print("TOP-SHEAR-01 PASS")
		quit(0)
	else:
		print("TOP-SHEAR-01 FAIL")
		quit(1)

func _make_facade() -> Image:
	var img := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	for y in range(512):
		for x in range(1024):
			var lum := float((x + 3 * y) % 256) / 255.0
			img.set_pixel(x, y, Color(lum, lum * 0.75, 0.5 + lum * 0.5, 1.0))
	return img

func _build_s_ext(facade: Image, dir: int) -> Image:
	var scaled := facade.duplicate()
	scaled.convert(Image.FORMAT_RGB8)
	scaled.convert(Image.FORMAT_RGBA8)
	scaled.resize(1024, 640, Image.INTERPOLATE_NEAREST)

	var plane_w := 1056
	var v_margin := 32
	var scaled_h := 640
	var s_ext := Image.create(plane_w, v_margin + scaled_h + v_margin, false, Image.FORMAT_RGBA8)
	s_ext.blit_rect(scaled, Rect2i(0, 0, 1024, scaled_h), Vector2i(0, v_margin))
	var flipped_x := scaled.duplicate()
	flipped_x.flip_x()
	s_ext.blit_rect(flipped_x, Rect2i(0, 0, plane_w - 1024, scaled_h), Vector2i(1024, v_margin))
	var flipped_y := s_ext.duplicate()
	flipped_y.flip_y()
	var total_h := v_margin + scaled_h + v_margin
	s_ext.blit_rect(flipped_y, Rect2i(0, total_h - 2 * v_margin, plane_w, v_margin), Vector2i(0, 0))
	s_ext.blit_rect(flipped_y, Rect2i(0, v_margin, plane_w, v_margin), Vector2i(0, total_h - v_margin))

	if dir == 1:
		var mirrored := s_ext.duplicate()
		mirrored.flip_x()
		return mirrored
	return s_ext

func _score_plane(compositor, facade: Image, dir: int, source: Image) -> int:
	var plane_top: Image = compositor._get_plane_top("top_test", facade, dir)
	if plane_top == null:
		print("[FAIL] _get_plane_top returned null for dir %d" % dir)
		return SAMPLE_COUNT

	var mismatches := 0
	for i in range(SAMPLE_COUNT):
		var u := randi_range(0, source.get_width() - 1)
		var v := randi_range(0, source.get_height() - 1)
		var dst_x := u - v + (source.get_height() - 1)
		var dst_y := int((float(u) + float(v)) / 2.0) + Y_MARGIN
		var expected: Color = source.get_pixel(u, v)
		var actual: Color = plane_top.get_pixel(dst_x, dst_y)
		if not _pixels_match(expected, actual):
			mismatches += 1
	return mismatches

func _score_legacy(source: Image) -> int:
	var img := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(source.get_height()):
		img.blit_rect(source, Rect2i(0, y, source.get_width(), 1), Vector2i(0, y))

	var mismatches := 0
	for i in range(SAMPLE_COUNT):
		var u := randi_range(0, source.get_width() - 1)
		var v := randi_range(0, source.get_height() - 1)
		var expected: Color = source.get_pixel(u, v)
		var actual: Color = img.get_pixel(u, v)
		if not _pixels_match(expected, actual):
			mismatches += 1
	return mismatches

func _pixels_match(a: Color, b: Color) -> bool:
	return abs(a.r - b.r) < 0.0001 and abs(a.g - b.g) < 0.0001 and abs(a.b - b.b) < 0.0001 and abs(a.a - b.a) < 0.0001
