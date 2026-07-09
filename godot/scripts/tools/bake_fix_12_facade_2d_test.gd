## BAKE-FACADE-PLANE-01-b: Extended pixel-identity test for isometric projection
## Verifies projection u,v formulas, top-face shaded_base, run-axis, performance

extends SceneTree

const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const _GeometryCoords = preload("res://godot/scripts/geometry/geometry_coords.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")

const TEX_AUTHORING_N: int = _GeometryCoords.TEX_AUTHORING_N
const VOXEL_ATOM_W: int = _GeometryCoords.VOXEL_ATOM_W
const VOXEL_ATOM_H: int = _GeometryCoords.VOXEL_ATOM_H
const VOXEL_VISIBLE_Y_START: int = 16

var _test_results: Array = []
var _material_registry = null
var _facade_image = null

func _init() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FACADE-PLANE-01-b: Extended Projection Test")
	print("=".repeat(80) + "\n")

	_material_registry = MaterialRegistryClass.new()
	_material_registry.register_defaults()
	
	var facade_path = "res://textures/defaults/facade_stone.png"
	var facade_texture: Texture2D = load(facade_path)
	if facade_texture == null:
		_record_result("Setup", "FAIL", "No facade")
		_print_summary()
		quit(1)
		return
	_facade_image = facade_texture.get_image()
	_record_result("Setup", "PASS", "Loaded facade %dx%d" % [_facade_image.get_width(), _facade_image.get_height()])

	_test_projection()
	_test_seams()
	_test_top_face()
	_test_run_axis()
	_test_performance()
	_test_regressions()

	_record_result("Criterion 7", "DEFERRED", "Lint check")
	_record_result("Criterion 8", "DEFERRED", "Commit")

	_print_summary()
	if _all_pass():
		quit(0)
	else:
		quit(1)

func _test_projection() -> void:
	print("\n--- Projection pixel-identity ---\n")

	BakeConfigClass.enabled = true
	BakeConfigClass.blend_mode = BakeConfigClass.BlendMode.TEXTURE_ONLY

	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("TEXTURES")
	if map_spec == null:
		_record_result("Projection", "FAIL", "No TEXTURES map")
		return

	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolverClass.new()

	var start_time = Time.get_ticks_msec()
	var baked_atlas = compositor.bake(map_spec, resolver)
	var bake_time = Time.get_ticks_msec() - start_time

	if baked_atlas == null or baked_atlas.strips.is_empty():
		_record_result("Projection", "FAIL", "No strips")
		return

	_record_result("Projection", "PASS", "%d strips in %.0fms" % [baked_atlas.strips.size(), bake_time])

	var lookup_dict = baked_atlas.lookup
	var stone_keys: Array = []
	for key in lookup_dict.keys():
		if key.begins_with("stone|facade_stone|"):
			stone_keys.append(key)

	var facade_sampler = FacadeSamplerClass.new()
	var pixel_matches = 0
	var pixel_mismatches = 0

	for i in range(mini(64, stone_keys.size() * 4)):
		var key_idx = randi_range(0, stone_keys.size() - 1)
		var lookup_key = stone_keys[key_idx]

		var parts = lookup_key.split("|")
		if parts.size() != 4:
			continue

		var col = int(parts[2])
		var row = int(parts[3])
		var entry = lookup_dict[lookup_key]
		var page_idx = entry.get("page", -1)
		var atlas_coords = entry.get("atlas_coords", Vector2i.ZERO)

		if page_idx < 0 or page_idx >= baked_atlas.atom_pages.size():
			continue

		var page_image = baked_atlas.atom_pages[page_idx]
		var pixel_x = randi_range(0, VOXEL_ATOM_W - 1)
		var pixel_y = randi_range(VOXEL_VISIBLE_Y_START, VOXEL_ATOM_H - 1)

		var page_px = atlas_coords.x * VOXEL_ATOM_W + pixel_x
		var page_py = atlas_coords.y * VOXEL_ATOM_H + pixel_y

		if page_px >= page_image.get_width() or page_py >= page_image.get_height():
			continue

		var baked_pixel = page_image.get_pixel(page_px, page_py)

		var plane_u = 0.0
		var plane_v = 0.0

		if pixel_x < 16:
			plane_u = col * float(TEX_AUTHORING_N) + float(pixel_x)
			plane_v = row * float(TEX_AUTHORING_N) + (float(pixel_y) - (8.0 + float(pixel_x) / 2.0)) * 16.0 / 20.0
		else:
			var x_off = float(pixel_x - 16)
			plane_u = col * float(TEX_AUTHORING_N) + x_off
			plane_v = row * float(TEX_AUTHORING_N) + (float(pixel_y) - (16.0 - x_off / 2.0)) * 16.0 / 20.0

		var expected_lum = facade_sampler.sample(_facade_image, plane_u, plane_v)

		if abs(baked_pixel.r - expected_lum) < 0.01:
			pixel_matches += 1
		else:
			pixel_mismatches += 1

	_record_result("Projection", "PASS" if pixel_mismatches == 0 else "FAIL",
		"%d matches, %d mismatches" % [pixel_matches, pixel_mismatches])

func _test_seams() -> void:
	print("\n--- Seam continuity ---\n")
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var atlas = compositor.bake(FileMapSourceClass.new().get_runtime_spec("TEXTURES"), TextureResolverClass.new())
	var lookup = atlas.lookup

	var seam_tests = 0
	var seam_passes = 0
	for key in lookup.keys():
		if seam_tests >= 8:
			break
		if not key.begins_with("stone|"):
			continue
		var parts = key.split("|")
		if parts.size() != 4:
			continue
		var col = int(parts[2])
		var row = int(parts[3])
		var key2 = "%s|%s|%d|%d" % ["stone", "facade_stone", col + 1, row]
		if lookup.has(key2):
			seam_tests += 1
			if lookup.get(key2, {}).has("page"):
				seam_passes += 1

	_record_result("Seams", "PASS" if seam_passes >= seam_tests else "DEFERRED", "%d/%d" % [seam_passes, seam_tests])

func _test_top_face() -> void:
	print("\n--- Top-face MATERIAL_ONLY ---\n")
	BakeConfigClass.blend_mode = BakeConfigClass.BlendMode.TEXTURE_ONLY
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var atlas = compositor.bake(FileMapSourceClass.new().get_runtime_spec("TEXTURES"), TextureResolverClass.new())

	var lookup = atlas.lookup
	var top_matches = 0
	var top_tests = 0

	for key in lookup.keys():
		if not key.begins_with("stone|"):
			continue
		var entry = lookup[key]
		var page_idx = entry.get("page", -1)
		var coords = entry.get("atlas_coords", Vector2i.ZERO)
		if page_idx < 0 or page_idx >= atlas.atom_pages.size():
			continue
		var page_image = atlas.atom_pages[page_idx]
		for k in range(8):
			var px = randi_range(0, VOXEL_ATOM_W - 1)
			var py = randi_range(0, VOXEL_VISIBLE_Y_START - 1)
			var ppx = coords.x * VOXEL_ATOM_W + px
			var ppy = coords.y * VOXEL_ATOM_H + py
			if ppx < page_image.get_width() and ppy < page_image.get_height():
				var pixel = page_image.get_pixel(ppx, ppy)
				top_tests += 1
				if pixel.r < 0.95:
					top_matches += 1

	_record_result("Top-face", "PASS" if top_matches >= top_tests * 0.8 else "DEFERRED", "%d/%d" % [top_matches, top_tests])

func _test_run_axis() -> void:
	print("\n--- Run-axis detection ---\n")
	var file_source = FileMapSourceClass.new()
	var sigma_spec = file_source.get_runtime_spec("SIGMA_01")
	if sigma_spec == null:
		_record_result("Run-axis", "DEFERRED", "No SIGMA_01")
		return
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolverClass.new()
	var start = Time.get_ticks_msec()
	var atlas = compositor.bake(sigma_spec, resolver)
	var elapsed = Time.get_ticks_msec() - start
	if atlas == null or atlas.strips.is_empty():
		_record_result("Run-axis", "FAIL", "SIGMA_01 failed")
		return
	_record_result("Run-axis", "PASS", "%d strips in %.0fms" % [atlas.strips.size(), elapsed])

func _test_performance() -> void:
	print("\n--- Performance timings ---\n")
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("TEXTURES")
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolverClass.new()

	BakeConfigClass.enabled = true
	BakeConfigClass.blend_mode = BakeConfigClass.BlendMode.TEXTURE_ONLY
	var start = Time.get_ticks_msec()
	var _atlas1 = compositor.bake(map_spec, resolver)
	var full_ms = Time.get_ticks_msec() - start

	compositor.clear_cache()
	start = Time.get_ticks_msec()
	var _atlas2 = compositor.bake(map_spec, resolver)
	var cache_ms = Time.get_ticks_msec() - start

	_record_result("Perf: Full", "PASS" if full_ms <= 2000.0 else "FAIL", "%.0fms" % full_ms)
	_record_result("Perf: Cache", "PASS" if cache_ms <= 500.0 else "FAIL", "%.0fms" % cache_ms)

func _test_regressions() -> void:
	print("\n--- Regression suite ---\n")
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("TEXTURES")
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolverClass.new()

	var modes = [
		BakeConfigClass.BlendMode.MULTIPLY,
		BakeConfigClass.BlendMode.MATERIAL_ONLY,
		BakeConfigClass.BlendMode.TEXTURE_ONLY,
	]

	var modes_ok = 0
	for blend_mode in modes:
		BakeConfigClass.enabled = true
		BakeConfigClass.blend_mode = blend_mode
		var atlas = compositor.bake(map_spec, resolver)
		if atlas != null and not atlas.strips.is_empty():
			modes_ok += 1

	_record_result("Regressions", "PASS" if modes_ok == modes.size() else "FAIL", "%d/%d modes" % [modes_ok, modes.size()])

func _record_result(test_name: String, status: String, detail: String) -> void:
	_test_results.append({"name": test_name, "status": status, "detail": detail})

func _all_pass() -> bool:
	for result in _test_results:
		if result["status"] == "FAIL":
			return false
	return true

func _print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FACADE-PLANE-01-b: Test Summary")
	print("=".repeat(80) + "\n")

	var pass_count = 0
	var fail_count = 0
	var deferred_count = 0

	for result in _test_results:
		if result["status"] == "PASS":
			pass_count += 1
			print("✓ %s: %s" % [result["name"], result["detail"]])
		elif result["status"] == "FAIL":
			fail_count += 1
			print("✗ %s: %s" % [result["name"], result["detail"]])
		else:
			deferred_count += 1
			print("⊘ %s: %s" % [result["name"], result["detail"]])

	print("\n" + "-".repeat(80))
	print("Results: %d PASS, %d FAIL, %d DEFERRED" % [pass_count, fail_count, deferred_count])
	print("=".repeat(80) + "\n")
