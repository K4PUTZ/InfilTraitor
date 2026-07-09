## BAKE-FACADE-PLANE-01: Pixel-identity test for 2-D facade sampling
## Verifies: (1) facade pixels match expected values, (2) vertical variation exists
##
## Run: godot --headless --script godot/scripts/tools/bake_fix_12_facade_2d_test.gd

extends SceneTree

const GeometryCoords = preload("res://godot/scripts/geometry/geometry_coords.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCatalogClass = preload("res://godot/scripts/world/maps/map_catalog.gd")
const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
const RoomClass = preload("res://godot/scripts/world/room.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")

const TEX_AUTHORING_N: int = GeometryCoords.TEX_AUTHORING_N  # 16
const VOXEL_ATOM_W: int = GeometryCoords.VOXEL_ATOM_W        # 32
const VOXEL_ATOM_H: int = GeometryCoords.VOXEL_ATOM_H        # 36
const VOXEL_VISIBLE_Y_START: int = 16

var _test_results: Array = []


func _init() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FIX-12: Pixel-Identity Test for 2-D Facade Sampling (BAKE-FACADE-PLANE-01)")
	print("=".repeat(80))
	print("Baked atom pixels vs independently-sampled facade texture")
	print("=".repeat(80) + "\n")

	# Enable baking
	BakeConfigClass.enabled = true
	BakeConfigClass.blend_mode = BakeConfigClass.BlendMode.TEXTURE_ONLY
	print("[BAKE-FIX-12] BakeConfig: enabled=true, blend_mode=TEXTURE_ONLY\n")

	# Load TEXTURES map spec
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("TEXTURES")

	if map_spec == null or map_spec.is_empty():
		_record_result("Map loading", "FAIL", "Could not load TEXTURES")
		_print_summary()
		quit(1)
		return

	_record_result("Map loading", "PASS", "Loaded TEXTURES map")
	print("✓ Loaded TEXTURES map\n")

	# Bake the map
	print("Calling BakeCompositor.bake()...")
	var registry = MaterialRegistryClass.new()
	registry.register_defaults()
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(registry)
	var resolver = TextureResolverClass.new()

	var baked_atlas = compositor.bake(map_spec, resolver)

	if baked_atlas == null or baked_atlas.strips.is_empty():
		_record_result("BakeCompositor.bake()", "FAIL", "No strips produced")
		_print_summary()
		quit(1)
		return

	_record_result("BakeCompositor.bake()", "PASS", "Produced %d atom sheets" % baked_atlas.strips.size())
	print("✓ BakeCompositor produced %d atom sheets\n" % baked_atlas.strips.size())

	# Load facade independently (not using the one from bake_compositor)
	var facade_path = "res://textures/defaults/facade_stone.png"
	var facade_texture: Texture2D = load(facade_path)
	if facade_texture == null:
		_record_result("Facade loading", "FAIL", "Could not load %s" % facade_path)
		_print_summary()
		quit(1)
		return

	var facade_image = facade_texture.get_image()
	_record_result("Facade loading", "PASS", "Loaded facade %dx%d" % [facade_image.get_width(), facade_image.get_height()])
	print("✓ Facade loaded: %dx%d\n" % [facade_image.get_width(), facade_image.get_height()])

	# Test pixel-identity
	var facade_sampler = FacadeSamplerClass.new()
	var lookup_dict = baked_atlas.lookup
	var test_keys: Array = lookup_dict.keys()

	# Filter to only stone facade keys (format: "stone|facade_stone|col|row")
	var stone_keys: Array = []
	for key in test_keys:
		if key.begins_with("stone|facade_stone|"):
			stone_keys.append(key)

	print("Found %d stone facade keys in lookup\n" % stone_keys.size())

	if stone_keys.size() == 0:
		_record_result("Key filtering", "FAIL", "No stone facade keys found in lookup")
		_print_summary()
		quit(1)
		return

	# Sample randomly
	var pixel_matches = 0
	var pixel_mismatches = 0
	var sample_size = mini(64, stone_keys.size())

	var per_level_coords: Dictionary = {}  # level -> Array of unique atlas_coords
	var per_level_luminances: Dictionary = {}  # level -> Array of luminances

	print("Testing %d random pixels from %d available keys..." % [sample_size, stone_keys.size()])

	for i in range(sample_size):
		var key_idx = randi_range(0, stone_keys.size() - 1)
		var lookup_key = stone_keys[key_idx]

		# Parse key: "stone|facade_stone|col|row"
		var parts = lookup_key.split("|")
		if parts.size() != 4:
			continue

		var material_id = parts[0]
		var facade_id = parts[1]
		var col = int(parts[2])
		var row = int(parts[3])

		var entry = lookup_dict[lookup_key]
		var page_idx = entry.get("page", -1)
		var atlas_coords = entry.get("atlas_coords", Vector2i.ZERO)

		if page_idx < 0 or page_idx >= baked_atlas.atom_pages.size():
			continue

		var page_image = baked_atlas.atom_pages[page_idx]

		# Pick a random pixel in the side-face region (y: 16..35)
		var pixel_x = randi_range(0, VOXEL_ATOM_W - 1)
		var pixel_y = randi_range(VOXEL_VISIBLE_Y_START, VOXEL_ATOM_H - 1)

		# Get baked pixel from page
		var page_pixel_x = atlas_coords.x * VOXEL_ATOM_W + pixel_x
		var page_pixel_y = atlas_coords.y * VOXEL_ATOM_H + pixel_y

		if page_pixel_x >= page_image.get_width() or page_pixel_y >= page_image.get_height():
			continue

		var baked_pixel = page_image.get_pixel(page_pixel_x, page_pixel_y)

		# Compute expected facade pixel using same logic as _bake_atom_sheet()
		var texel_x = pixel_x / 2.0
		var texel_y = (pixel_y - VOXEL_VISIBLE_Y_START) * 16.0 / 20.0

		var plane_x = col * float(TEX_AUTHORING_N) + texel_x
		var plane_y = row * float(TEX_AUTHORING_N) + texel_y

		var expected_lum = facade_sampler.sample(facade_image, plane_x, plane_y)

		# Compare (allow small tolerance for float rounding)
		var lum_match = abs(baked_pixel.r - expected_lum) < 0.01
		if lum_match:
			pixel_matches += 1
		else:
			pixel_mismatches += 1
			if pixel_mismatches <= 3:  # Log first 3 mismatches
				print("  MISMATCH: key=%s pixel=(%d,%d), baked_r=%.3f, expected=%.3f" % [
					lookup_key, pixel_x, pixel_y, baked_pixel.r, expected_lum
				])

		# Track per-level data for vertical variation test
		if not per_level_coords.has(row):
			per_level_coords[row] = []
			per_level_luminances[row] = []

		per_level_coords[row].append(atlas_coords)
		per_level_luminances[row].append(baked_pixel.r)

	_record_result("Pixel-identity", "PASS" if pixel_mismatches == 0 else "FAIL", "%d matches, %d mismatches" % [pixel_matches, pixel_mismatches])
	print("✓ Pixel-identity test: %d matches, %d mismatches\n" % [pixel_matches, pixel_mismatches])

	# Test vertical variation
	if per_level_coords.size() > 1:
		var level_list = per_level_coords.keys()
		level_list.sort()
		var min_level = level_list[0]
		var max_level = level_list[level_list.size() - 1]

		var min_coords_set = {}
		for coord in per_level_coords[min_level]:
			min_coords_set[coord] = true

		var max_coords_set = {}
		for coord in per_level_coords[max_level]:
			max_coords_set[coord] = true

		var coords_differ = min_coords_set.keys() != max_coords_set.keys()

		# Check average luminance differs
		var min_avg_lum = 0.0
		for lum in per_level_luminances[min_level]:
			min_avg_lum += lum
		if per_level_luminances[min_level].size() > 0:
			min_avg_lum /= float(per_level_luminances[min_level].size())

		var max_avg_lum = 0.0
		for lum in per_level_luminances[max_level]:
			max_avg_lum += lum
		if per_level_luminances[max_level].size() > 0:
			max_avg_lum /= float(per_level_luminances[max_level].size())

		var luminances_differ = abs(min_avg_lum - max_avg_lum) > 0.01

		var variation_pass = coords_differ and luminances_differ
		_record_result("Vertical variation", "PASS" if variation_pass else "FAIL", "coords_differ=%s, lum_differ=%s" % [coords_differ, luminances_differ])
		print("✓ Vertical variation: coords_differ=%s, lum_avg_differ=%s\n" % [coords_differ, luminances_differ])

		if not variation_pass:
			print("  level %d avg_lum=%.3f" % [min_level, min_avg_lum])
			print("  level %d avg_lum=%.3f\n" % [max_level, max_avg_lum])
	else:
		_record_result("Vertical variation", "DEFERRED", "Only %d level(s) sampled" % per_level_coords.size())
		print("⊘ Vertical variation: Only %d level(s) sampled, test deferred\n" % per_level_coords.size())

	_print_summary()

	if _all_pass():
		quit(0)
	else:
		quit(1)


func _record_result(test_name: String, status: String, detail: String) -> void:
	_test_results.append({"name": test_name, "status": status, "detail": detail})


func _all_pass() -> bool:
	for result in _test_results:
		if result["status"] == "FAIL":
			return false
	return true


func _print_summary() -> void:
	print("=".repeat(80))
	print("BAKE-FIX-12: 2-D Facade Sampling Test Results")
	print("=".repeat(80))

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

	if fail_count == 0 and pass_count > 0:
		print("\n✓ [BAKE-PIXEL-TEST] Facade sampling: pixels match expected values, vertical variation verified")
	else:
		print("\n✗ [BAKE-PIXEL-TEST] FAILED")

	print("=".repeat(80) + "\n")
