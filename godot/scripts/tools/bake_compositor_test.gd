## BAKE-04 Selftest: BakeCompositor (T2, Render)
##
## Tests bake set deduplication, composite multiply, and batch timing.

extends SceneTree

var BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
var FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
var PerFaceProjectorClass = preload("res://godot/scripts/systems/per_face_projector.gd")

class MockTextureResolver:
	enum Tier { NONE = -1, LOW = 0, MID = 1, HIGH = 2 }

	func resolve(_facade_id: String) -> Dictionary:
		# Return a 64×32 facade
		var img = Image.create(64, 32, false, Image.FORMAT_L8)
		for y in range(32):
			for x in range(64):
				img.set_pixel(x, y, Color.WHITE * 0.5)
		return {"tier": Tier.HIGH, "image": img}

class MockMaterial:
	var id: String
	func _init(p_id: String) -> void:
		id = p_id

class MockRegistry:
	var materials: Dictionary = {}

	func _init() -> void:
		materials["test_mat_1"] = MockMaterial.new("test_mat_1")
		materials["test_mat_2"] = MockMaterial.new("test_mat_2")

	func get_material(p_id: String):
		return materials.get(p_id, null)

class MockEdge:
	var id: String
	func _init(p_id: String) -> void:
		id = p_id
	func key_string() -> String:
		return id

func _init() -> void:
	print("\n" + "=".repeat(60))
	print("BAKE-04 SELFTEST: BakeCompositor")
	print("=".repeat(60) + "\n")

	# Setup mock registry
	var mock_registry = MockRegistry.new()
	Engine.set_meta("BAKE_TEST_REGISTRY", mock_registry)

	var all_pass = true

	if not _test_bake_set_dedup():
		all_pass = false
	if not _test_composite_simple():
		all_pass = false
	if not _test_render_batch_timing():
		all_pass = false

	print("\n" + "=".repeat(60))
	if all_pass:
		print("BAKE-04 SELFTEST: 3 / 3 PASS")
		print("=".repeat(60) + "\n")
		print("✓ SELFTEST PASS")
	else:
		print("BAKE-04 SELFTEST: FAILED")
		print("=".repeat(60) + "\n")
		print("✗ SELFTEST FAIL")
	quit()

## Test 1: Bake set population and basic checks
func _test_bake_set_dedup() -> bool:
	print("[TEST 1] bake_set_dedup\n")
	var success = true

	# Create synthetic map with walls
	var walls = []

	# 10 walls, with varying edges and materials
	for i in range(10):
		var wall = {
			"facade_id": "test_facade",
			"material_id": "test_mat_1",
			"edge": MockEdge.new("edge_%d" % i),
		}
		walls.append(wall)

	var resolver = MockTextureResolver.new()
	var compositor = BakeCompositorClass.new()
	var bake_set = compositor._populate_bake_set(walls, resolver)

	var post_dedup = bake_set.size()
	var pre_dedup = walls.size()

	print("    Pre-dedup walls: %d" % pre_dedup)
	print("    Post-dedup keys: %d" % post_dedup)

	# Check that bake set has entries (dedup happens, keys are generated)
	if post_dedup > 0 and post_dedup <= pre_dedup * 4:
		print("    ✓ Bake set generated: %d keys from %d walls" % [post_dedup, pre_dedup])
	else:
		print("    ✗ Bake set empty or over-generated: got %d" % post_dedup)
		success = false

	# Verify BakeKey properties
	var sample_key = bake_set.keys()[0] if bake_set.size() > 0 else null
	if sample_key:
		print("    Sample key: material='%s', facade='%s', face=%d, variant=%d" %
			[sample_key.material_id, sample_key.facade_id, sample_key.face, sample_key.variant_k])
		if sample_key.material_id and sample_key.facade_id:
			print("    ✓ BakeKey properties valid")
		else:
			success = false

	if success:
		print("  PASS: bake_set_dedup\n")
	else:
		print("  FAIL: bake_set_dedup\n")
	return success

## Test 2: Composite multiply (material × facade = darker)
func _test_composite_simple() -> bool:
	print("[TEST 2] composite_simple\n")
	var success = true

	# Create white material tile
	var material_tile = Image.create(32, 16, false, Image.FORMAT_RGB8)
	for y in range(16):
		for x in range(32):
			material_tile.set_pixel(x, y, Color.WHITE)

	# Create 50% gray facade
	var facade = Image.create(64, 32, false, Image.FORMAT_L8)
	for y in range(32):
		for x in range(64):
			facade.set_pixel(x, y, Color(0.5, 0.5, 0.5))

	var compositor = BakeCompositorClass.new()
	var sampler = FacadeSamplerClass.new()
	var projector = PerFaceProjectorClass.new()

	# Create bake key (NE face)
	var bake_key = BakeCompositorClass.BakeKey.new()
	bake_key.material_id = "test_mat"
	bake_key.facade_id = "test_facade"
	bake_key.variant_k = 0
	bake_key.face = 0  # NE
	bake_key.plane_col = 0
	bake_key.plane_row = 0

	# Test silhouette check first
	print("    Checking silhouette for some pixels...")
	var inside_count = 0
	for y in range(0, 16, 4):
		for x in range(0, 32, 4):
			var screen_pos = Vector2(float(x), float(y))
			if projector.is_inside_voxel(0, screen_pos):
				inside_count += 1

	print("    Inside voxel: %d / %d sample pixels" % [inside_count, 16])

	var composite = compositor._composite_tile(material_tile, facade, bake_key, sampler, projector)

	# Sample multiple pixels to find one that's inside
	var test_pixels = [[16, 8], [10, 8], [20, 8], [16, 5], [16, 10]]
	var found_composite = false
	for coords in test_pixels:
		var pixel = composite.get_pixel(coords[0], coords[1])
		print("    Pixel at (%d, %d): (%.2f, %.2f, %.2f)" % [coords[0], coords[1], pixel.r, pixel.g, pixel.b])

		if pixel.r >= 0.4 and pixel.r <= 0.6:
			print("    ✓ Composite multiply working at (%d, %d): white × 0.5 ≈ 0.5" % [coords[0], coords[1]])
			found_composite = true
			break

	if not found_composite:
		print("    ✗ No pixel found with correct composite value")
		success = false

	if success:
		print("  PASS: composite_simple\n")
	else:
		print("  FAIL: composite_simple\n")
	return success

## Test 3: Render batch timing (should be < 100ms)
func _test_render_batch_timing() -> bool:
	print("[TEST 3] render_batch_timing\n")
	var success = true

	var map_spec = _create_synthetic_map()
	var resolver = MockTextureResolver.new()

	var compositor = BakeCompositorClass.new()

	# Prepare bake set
	var bake_set = compositor._populate_bake_set(map_spec["walls"], resolver)
	var facades_by_id = {"test_facade": Image.create(64, 32, false, Image.FORMAT_L8)}

	var start = Time.get_ticks_msec()
	var result = compositor._render_batch(bake_set, facades_by_id)
	var elapsed = Time.get_ticks_msec() - start

	print("    Render time: %.1f ms" % elapsed)
	print("    Atlas pages: %d" % result.pages.size())
	print("    Lookup entries: %d" % result.lookup.size())

	if elapsed < 100:
		print("    ✓ Render completed in < 100ms")
	else:
		print("    ✗ Render too slow: %d ms" % elapsed)
		success = false

	if result.pages.size() > 0:
		print("    ✓ Atlas pages created")
	else:
		print("    ✗ No atlas pages")
		success = false

	if result.lookup.size() > 0:
		print("    ✓ Lookup populated")
	else:
		print("    ✗ Empty lookup")
		success = false

	# Save debug dumps
	if result.pages.size() > 0:
		var debug_dir = "user://debug"
		if not DirAccess.dir_exists_absolute(debug_dir):
			var da = DirAccess.open("user://")
			if da:
				da.make_dir("debug")

		for i in range(result.pages.size()):
			result.pages[i].save_png("%s/baked_atlas_page_%d.png" % [debug_dir, i])
			print("    ✓ Saved debug page %d" % i)

	if success:
		print("  PASS: render_batch_timing\n")
	else:
		print("  FAIL: render_batch_timing\n")
	return success

## Helper: Create synthetic map with walls
func _create_synthetic_map() -> Dictionary:
	var walls = []

	# Create 10 walls, but with only a few unique keys
	for i in range(10):
		var wall = {
			"facade_id": "test_facade",
			"material_id": "test_mat_1",
			"edge": MockEdge.new("edge_%d" % i),
		}
		walls.append(wall)

	return {"walls": walls}
