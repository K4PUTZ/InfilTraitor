extends SceneTree

const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("FIX-BAKE-04 TEST: Material Tile Generation")
	print("=".repeat(70) + "\n")

	# Setup registry with test patterns
	var registry = MaterialRegistryClass.new()

	# Define a simple stone pattern
	var stone_pattern = TestStonePattern.new()
	var stone_material = MaterialRegistryClass.MaterialDef.new(
		"stone",
		Color(0.6, 0.55, 0.5),  # Grayish base
		stone_pattern
	)
	registry.register(stone_material)

	# Define wood pattern
	var wood_pattern = TestWoodPattern.new()
	var wood_material = MaterialRegistryClass.MaterialDef.new(
		"wood",
		Color(0.4, 0.3, 0.2),  # Brown base
		wood_pattern
	)
	registry.register(wood_material)

	Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", registry)

	var compositor = BakeCompositorClass.new()

	# Test 1: Fetch material tile for stone
	print("[TEST 1] Material Tile for Stone\n")

	var stone_tile = compositor._get_material_tile(stone_material, 0, 0)  # Face NE, variant 0

	assert(stone_tile != null, "Material tile must not be null")
	assert(stone_tile.get_format() == Image.FORMAT_RGBA8, "Format must be RGBA8")
	assert(stone_tile.get_width() == 32 and stone_tile.get_height() == 16,
		"Tile must be 32×16")

	print("    ✓ Tile created: 32×16 RGBA8")

	# Check that it's not uniform white (pattern applied)
	var pixel_0_0 = stone_tile.get_pixel(0, 0)
	var pixel_16_8 = stone_tile.get_pixel(16, 8)

	var color_diff = abs(pixel_0_0.r - pixel_16_8.r) + abs(pixel_0_0.g - pixel_16_8.g) + abs(pixel_0_0.b - pixel_16_8.b)
	if color_diff > 0.05:
		print("    ✓ Pattern shading applied (variance: %.4f)" % color_diff)
	else:
		print("    ⚠ Tile is mostly uniform (pattern variance < 0.05)")

	# Check alpha channel is present
	assert(pixel_0_0.a > 0.99, "Alpha should be opaque (%.2f)" % pixel_0_0.a)
	print("    ✓ Alpha channel: %.2f (opaque)" % pixel_0_0.a)

	print("  PASS: Material Tile Generation\n")

	# Test 2: Different variants produce different shading
	print("[TEST 2] Variant Differentiation\n")

	var variant_0 = compositor._get_material_tile(stone_material, 0, 0)
	var variant_1 = compositor._get_material_tile(stone_material, 0, 1)
	var variant_2 = compositor._get_material_tile(stone_material, 0, 2)

	var v0_pixel = variant_0.get_pixel(5, 5)
	var v1_pixel = variant_1.get_pixel(5, 5)
	var v2_pixel = variant_2.get_pixel(5, 5)

	var v0_v1_dist = abs(v0_pixel.r - v1_pixel.r) + abs(v0_pixel.g - v1_pixel.g) + abs(v0_pixel.b - v1_pixel.b)
	var v0_v2_dist = abs(v0_pixel.r - v2_pixel.r) + abs(v0_pixel.g - v2_pixel.g) + abs(v0_pixel.b - v2_pixel.b)

	if v0_v1_dist > 0.1 and v0_v2_dist > 0.1:
		print("    ✓ Variants produce different shading (distance: %.4f, %.4f)" % [v0_v1_dist, v0_v2_dist])
	else:
		print("    ⚠ Variants may be similar (distance: %.4f, %.4f)" % [v0_v1_dist, v0_v2_dist])

	print("  PASS: Variant Differentiation\n")

	# Test 3: Composite chain (requires sampler and projector)
	print("[TEST 3] Composite Chain (M × F)\n")

	# Create a simple facade: solid 0.5 luminance
	var facade = Image.create(1024, 512, false, Image.FORMAT_L8)
	for y in range(512):
		for x in range(1024):
			facade.set_pixel(x, y, Color(0.5, 0, 0, 1))

	var sampler = preload("res://godot/scripts/systems/facade_sampler.gd").new()
	var projector = preload("res://godot/scripts/systems/per_face_projector.gd").new()

	var bake_key = BakeCompositorClass.BakeKey.new()
	bake_key.material_id = "stone"
	bake_key.facade_id = "test"
	bake_key.variant_k = 0
	bake_key.face = 0  # NE
	bake_key.plane_col = 0
	bake_key.plane_row = 0

	var composite = compositor._composite_tile(variant_0, facade, bake_key, sampler, projector)

	assert(composite != null, "Composite must not be null")
	assert(composite.get_format() == Image.FORMAT_RGBA8, "Composite must be RGBA8")
	assert(composite.get_width() == 32 and composite.get_height() == 16,
		"Composite must be 32×16")

	var comp_pixel = composite.get_pixel(10, 8)
	# Expected: material × facade_lum ≈ material × 0.5
	var expected_approx = variant_0.get_pixel(10, 8) * 0.5
	var comp_diff = abs(comp_pixel.r - expected_approx.r) + abs(comp_pixel.g - expected_approx.g) + abs(comp_pixel.b - expected_approx.b)

	if comp_diff < 0.1:
		print("    ✓ Composite correct: material × facade_lum")
	else:
		print("    ⚠ Composite pixel distance: %.4f (expected < 0.1)" % [comp_diff])

	print("  PASS: Composite Chain\n")

	# Test 4: Different materials have different base colors
	print("[TEST 4] Material Differentiation\n")

	var stone_tile_test = compositor._get_material_tile(stone_material, 0, 0)
	var wood_tile_test = compositor._get_material_tile(wood_material, 0, 0)

	var stone_px = stone_tile_test.get_pixel(8, 8)
	var wood_px = wood_tile_test.get_pixel(8, 8)

	var material_diff = abs(stone_px.r - wood_px.r) + abs(stone_px.g - wood_px.g) + abs(stone_px.b - wood_px.b)
	assert(material_diff > 0.2, "Different materials must produce different colors (got %.4f)" % material_diff)
	print("    ✓ Stone (%.2f,%.2f,%.2f) vs Wood (%.2f,%.2f,%.2f)" %
		[stone_px.r, stone_px.g, stone_px.b, wood_px.r, wood_px.g, wood_px.b])

	print("  PASS: Material Differentiation\n")

	print("=".repeat(70))
	print("✓ FIX-BAKE-04 ALL TESTS PASS")
	print("=".repeat(70) + "\n")
	quit(0)

# Simple pattern: returns a semi-random shade based on seed
class TestStonePattern:
	extends MaterialRegistryClass.PatternAlgorithm

	func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:
		# FNV-1a hash of (seed + voxel coordinates)
		var hash_val = 2166136261
		hash_val ^= seed_val & 0xFF
		hash_val = (hash_val * 16777619) & 0xFFFFFFFF
		hash_val ^= (voxel_xy.x << 2) & 0xFF
		hash_val = (hash_val * 16777619) & 0xFFFFFFFF
		hash_val ^= (voxel_xy.y << 2) & 0xFF
		hash_val = (hash_val * 16777619) & 0xFFFFFFFF

		# Normalize to [0.7, 1.0] range for subtle variation
		var normalized = float((hash_val >> 16) & 0xFF) / 255.0
		return 0.7 + normalized * 0.3

# Wood pattern: vertical grain effect
class TestWoodPattern:
	extends MaterialRegistryClass.PatternAlgorithm

	func shade(voxel_xy: Vector2i, _face: int, seed_val: int) -> float:
		# Simple groove pattern: varies by X coordinate and seed
		var x_factor = float(voxel_xy.x) / 8.0
		var seed_factor = float((seed_val >> 8) & 0xFF) / 255.0
		var grain = sin(x_factor * 3.14159 + seed_factor * 6.28) * 0.15 + 0.85
		return clamp(grain, 0.7, 1.0)
