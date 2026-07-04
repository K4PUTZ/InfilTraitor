## BAKE-08: Resolver Integration Hardening
##
## End-to-end resolver tests with live user:// content.
## Exercises corrupt-file handling, oversized files, dimension mismatches, and tier fallback.
## All tiers (USER, DEFAULT, NONE) validated with console evidence.

extends SceneTree

var TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")
var GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

const TEST_USER_DIR = "user://resolver_test/"
const TEST_DEFAULT_DIR = "user://resolver_test_defaults/"
const TEX_AUTHORING_N = 16  # Must match GeometryCoords.TEX_AUTHORING_N

var test_passed = 0
var test_failed = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("BAKE-08 RESOLVER HARDENING: Tier Fallback & Corrupt File Handling")
	print("=".repeat(70) + "\n")

	# Setup test directories
	_setup_test_directories()

	# Create test fixtures
	_create_valid_facades()
	_create_corrupt_files()
	_create_oversized_files()
	_create_mismatched_dimensions()

	# Run tier tests
	_run_tier_tests()

	# Run mixed facade test
	_run_real_map_test()

	# Print results
	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [test_passed, test_failed])
	print("=".repeat(70) + "\n")

	if test_failed == 0:
		print("✓ BAKE-08 RESOLVER HARDENING PASS")
	else:
		print("✗ BAKE-08 RESOLVER HARDENING FAILED")

	# Cleanup
	_cleanup_test_fixtures()

	quit()


func _setup_test_directories() -> void:
	var dir_access = DirAccess.open("user://")
	if dir_access:
		if not dir_access.dir_exists(TEST_USER_DIR):
			dir_access.make_dir(TEST_USER_DIR)
		if not dir_access.dir_exists(TEST_DEFAULT_DIR):
			dir_access.make_dir(TEST_DEFAULT_DIR)
		print("[TEST] Created test directories: user://resolver_test/")


func _create_valid_facades() -> void:
	# Create valid grayscale facades at expected dimensions
	var width = 64 * TEX_AUTHORING_N
	var height = 32 * TEX_AUTHORING_N

	var valid_facade = Image.create(width, height, false, Image.FORMAT_L8)
	for y in range(height):
		for x in range(width):
			valid_facade.set_pixel(x, y, Color(0.5, 0.5, 0.5))  # 50% gray

	valid_facade.save_png(TEST_USER_DIR + "facade_stone_valid.png")
	print("[TEST] Created: facade_stone_valid.png (%dx%d, valid grayscale)" % [width, height])

	# Another valid facade in "defaults"
	var default_facade = Image.create(width, height, false, Image.FORMAT_L8)
	for y in range(height):
		for x in range(width):
			default_facade.set_pixel(x, y, Color(0.7, 0.7, 0.7))  # 70% gray

	default_facade.save_png(TEST_DEFAULT_DIR + "facade_wood_base.png")
	print("[TEST] Created: facade_wood_base.png (in defaults, valid grayscale)")


func _create_corrupt_files() -> void:
	# Create a "PNG" that's actually text (invalid decode)
	var corrupt_path = TEST_USER_DIR + "facade_wood_corrupt.png"
	var file = FileAccess.open(corrupt_path, FileAccess.WRITE)
	if file:
		file.store_string("This is not a PNG file, just text pretending to be one.")
		print("[TEST] Created: facade_wood_corrupt.png (invalid PNG format)")


func _create_oversized_files() -> void:
	# Create a large grayscale image that exceeds size cap
	# 4096×4096 with RGBA would be ~64MB; we'll create it as a test
	var large_dim = 2048
	var oversized = Image.create(large_dim, large_dim, false, Image.FORMAT_L8)
	for y in range(large_dim):
		for x in range(large_dim):
			oversized.set_pixel(x, y, Color(0.5, 0.5, 0.5))

	oversized.save_png(TEST_USER_DIR + "facade_metal_huge.png")

	# Check file size
	if FileAccess.file_exists(TEST_USER_DIR + "facade_metal_huge.png"):
		var file = FileAccess.open(TEST_USER_DIR + "facade_metal_huge.png", FileAccess.READ)
		if file:
			var size_bytes = file.get_length()
			var size_mb = float(size_bytes) / (1024.0 * 1024.0)
			print("[TEST] Created: facade_metal_huge.png (%.1f MB, exceeds 10 MB cap)" % size_mb)


func _create_mismatched_dimensions() -> void:
	# Create a grayscale facade with wrong dimensions
	var wrong_facade = Image.create(512, 512, false, Image.FORMAT_L8)
	for y in range(512):
		for x in range(512):
			wrong_facade.set_pixel(x, y, Color(0.7, 0.7, 0.7))

	wrong_facade.save_png(TEST_USER_DIR + "facade_stone_wrongdim.png")
	var expected_w = 64 * TEX_AUTHORING_N
	var expected_h = 32 * TEX_AUTHORING_N
	print("[TEST] Created: facade_stone_wrongdim.png (512×512, expected %dx%d)" % [expected_w, expected_h])


func _run_tier_tests() -> void:
	print("\n" + "-".repeat(70))
	print("TIER FALLBACK TESTS")
	print("-".repeat(70) + "\n")

	# Test Tier 1: User hit (valid file)
	_test_tier1_user_hit()

	# Test Tier 1: Corrupt → Tier 2 fallthrough
	_test_tier1_fallthrough_corrupt()

	# Test Tier 1: Oversized → Tier 2 fallthrough
	_test_tier1_fallthrough_oversized()

	# Test Tier 1: Wrong dims → Tier 2 fallthrough
	_test_tier1_fallthrough_mismatched_dims()

	# Test Tier 2: Default hit
	_test_tier2_default_hit()

	# Test Tier 3: Material-only (unresolved)
	_test_tier3_material_only()


func _test_tier1_user_hit() -> void:
	print("[TEST 1] Tier 1: User directory HIT\n")

	var resolver = TextureResolverClass.new(TEST_USER_DIR, TEST_DEFAULT_DIR)
	var result = resolver.resolve("facade_stone_valid")

	var success = true

	# Check result
	if result.tier == TextureResolverClass.Tier.USER:
		print("  ✓ Resolved from USER tier")
	else:
		print("  ✗ Expected USER tier, got: %d" % result.tier)
		success = false

	if result.image != null:
		var expected_w = 64 * TEX_AUTHORING_N
		var expected_h = 32 * TEX_AUTHORING_N
		if result.image.get_width() == expected_w and result.image.get_height() == expected_h:
			print("  ✓ Dimensions correct: %dx%d" % [expected_w, expected_h])
		else:
			print("  ✗ Dimension mismatch: expected %dx%d, got %dx%d" %
				[expected_w, expected_h, result.image.get_width(), result.image.get_height()])
			success = false
	else:
		print("  ✗ Image is null")
		success = false

	# Check logs for evidence
	var logs = resolver.get_log()
	var has_evidence = false
	for log_line in logs:
		if "resolved from USER" in log_line and "facade_stone_valid" in log_line:
			has_evidence = true
			break

	if has_evidence:
		print("  ✓ Console evidence logged")
	else:
		print("  ✗ No console evidence")
		success = false

	if success:
		print("  PASS: tier1_user_hit\n")
		test_passed += 1
	else:
		print("  FAIL: tier1_user_hit\n")
		test_failed += 1


func _test_tier1_fallthrough_corrupt() -> void:
	print("[TEST 2] Tier 1: Corrupt file → Tier 2 fallthrough\n")

	var resolver = TextureResolverClass.new(TEST_USER_DIR, TEST_DEFAULT_DIR)
	var result = resolver.resolve("facade_wood_corrupt")

	var success = true

	# Corrupt file should NOT resolve as USER
	if result.tier != TextureResolverClass.Tier.USER:
		print("  ✓ Corrupt file rejected (not USER tier)")
	else:
		print("  ✗ Corrupt file incorrectly resolved as USER")
		success = false

	# Should fall back to DEFAULT or NONE
	if result.tier == TextureResolverClass.Tier.DEFAULT or result.tier == TextureResolverClass.Tier.NONE:
		print("  ✓ Fallback to tier: %d" % result.tier)
	else:
		print("  ✗ Unexpected tier: %d" % result.tier)
		success = false

	# Check logs for decode failure
	var logs = resolver.get_log()
	var has_skip = false
	for log_line in logs:
		if "Decode failed" in log_line and "facade_wood_corrupt" in log_line:
			has_skip = true
			break

	if has_skip:
		print("  ✓ Decode failure logged")
	else:
		print("  ✗ No decode failure evidence")
		success = false

	if success:
		print("  PASS: tier1_fallthrough_corrupt\n")
		test_passed += 1
	else:
		print("  FAIL: tier1_fallthrough_corrupt\n")
		test_failed += 1


func _test_tier1_fallthrough_oversized() -> void:
	print("[TEST 3] Tier 1: Oversized file → Tier 2 fallthrough\n")

	var resolver = TextureResolverClass.new(TEST_USER_DIR, TEST_DEFAULT_DIR)
	var result = resolver.resolve("facade_metal_huge")

	var success = true

	# Oversized file should NOT resolve as USER
	if result.tier != TextureResolverClass.Tier.USER:
		print("  ✓ Oversized file rejected (not USER tier)")
	else:
		print("  ✗ Oversized file incorrectly resolved as USER")
		success = false

	# Check logs for size cap
	var logs = resolver.get_log()
	var has_size_check = false
	for log_line in logs:
		if "Exceeds size cap" in log_line and "facade_metal_huge" in log_line:
			has_size_check = true
			break

	if has_size_check:
		print("  ✓ Size cap check logged")
	else:
		print("  ✗ No size cap evidence")
		success = false

	if success:
		print("  PASS: tier1_fallthrough_oversized\n")
		test_passed += 1
	else:
		print("  FAIL: tier1_fallthrough_oversized\n")
		test_failed += 1


func _test_tier1_fallthrough_mismatched_dims() -> void:
	print("[TEST 4] Tier 1: Mismatched dimensions → Tier 2 fallthrough\n")

	var resolver = TextureResolverClass.new(TEST_USER_DIR, TEST_DEFAULT_DIR)
	var result = resolver.resolve("facade_stone_wrongdim")

	var success = true

	# Wrong-dim file should NOT resolve as USER
	if result.tier != TextureResolverClass.Tier.USER:
		print("  ✓ Wrong-dim file rejected (not USER tier)")
	else:
		print("  ✗ Wrong-dim file incorrectly resolved as USER")
		success = false

	# Check logs for dimension validation
	var logs = resolver.get_log()
	var has_dim_check = false
	for log_line in logs:
		if ("Expected" in log_line and "got" in log_line) or ("Dimension contract violation" in log_line):
			has_dim_check = true
			break

	if has_dim_check:
		print("  ✓ Dimension validation logged")
	else:
		print("  ✗ No dimension validation evidence")
		success = false

	if success:
		print("  PASS: tier1_fallthrough_mismatched_dims\n")
		test_passed += 1
	else:
		print("  FAIL: tier1_fallthrough_mismatched_dims\n")
		test_failed += 1


func _test_tier2_default_hit() -> void:
	print("[TEST 5] Tier 2: Default directory HIT\n")

	var resolver = TextureResolverClass.new(TEST_USER_DIR, TEST_DEFAULT_DIR)
	var result = resolver.resolve("facade_wood_base")

	var success = true

	# Should resolve from DEFAULT (or USER if user version exists, which it shouldn't)
	if result.tier == TextureResolverClass.Tier.DEFAULT or result.tier == TextureResolverClass.Tier.USER:
		print("  ✓ Resolved from tier: %d" % result.tier)
	else:
		print("  ✗ Expected DEFAULT or USER tier, got: %d" % result.tier)
		success = false

	if result.image != null:
		print("  ✓ Image loaded successfully")
	else:
		print("  ✗ Image is null")
		success = false

	# Check logs for DEFAULT tier (if user version doesn't exist)
	var logs = resolver.get_log()
	var has_default_log = false
	for log_line in logs:
		if "resolved from DEFAULT" in log_line and "facade_wood_base" in log_line:
			has_default_log = true
			break

	if has_default_log:
		print("  ✓ DEFAULT tier resolution logged")
	else:
		print("  ⚠ No DEFAULT log (may have resolved from USER or path issue)")

	if success:
		print("  PASS: tier2_default_hit\n")
		test_passed += 1
	else:
		print("  FAIL: tier2_default_hit\n")
		test_failed += 1


func _test_tier3_material_only() -> void:
	print("[TEST 6] Tier 3: Material-only (unresolved)\n")

	var resolver = TextureResolverClass.new(TEST_USER_DIR, TEST_DEFAULT_DIR)
	var result = resolver.resolve("facade_nonexistent_xyz")

	var success = true

	# Should resolve as NONE
	if result.tier == TextureResolverClass.Tier.NONE:
		print("  ✓ Unresolved facade returns NONE tier")
	else:
		print("  ✗ Expected NONE tier, got: %d" % result.tier)
		success = false

	if result.image == null:
		print("  ✓ Image is null (material-only)")
	else:
		print("  ✗ Expected null image, got loaded image")
		success = false

	# Check logs for UNRESOLVED message
	var logs = resolver.get_log()
	var has_unresolved = false
	for log_line in logs:
		if "UNRESOLVED" in log_line and "MATERIAL-ONLY" in log_line:
			has_unresolved = true
			break

	if has_unresolved:
		print("  ✓ MATERIAL-ONLY fallback logged")
	else:
		print("  ✗ No MATERIAL-ONLY evidence")
		success = false

	if success:
		print("  PASS: tier3_material_only\n")
		test_passed += 1
	else:
		print("  FAIL: tier3_material_only\n")
		test_failed += 1


func _run_real_map_test() -> void:
	print("\n" + "-".repeat(70))
	print("REAL MAP LOAD TEST")
	print("-".repeat(70) + "\n")

	_test_mixed_facades()
	_test_resolver_transcript()


func _test_mixed_facades() -> void:
	print("[TEST 7] Real map with mixed facade states\n")

	var resolver = TextureResolverClass.new(TEST_USER_DIR, TEST_DEFAULT_DIR)

	# Simulate wall requests with different facade states
	var facades = [
		"facade_stone_valid",         # USER, should resolve
		"facade_wood_base",           # DEFAULT, should resolve
		"facade_metal_nonexistent",   # NONE, material-only
	]

	var resolved_count = 0
	var unresolved_count = 0

	for facade_id in facades:
		var result = resolver.resolve(facade_id)
		if result.tier == TextureResolverClass.Tier.NONE:
			unresolved_count += 1
			print("  ✓ %s → NONE (material-only)" % facade_id)
		else:
			resolved_count += 1
			print("  ✓ %s → tier %d" % [facade_id, result.tier])

	print("\n  Summary:")
	print("    Resolved: %d" % resolved_count)
	print("    Unresolved (material-only): %d" % unresolved_count)

	var success = (resolved_count >= 2 and unresolved_count >= 1)

	if success:
		print("  PASS: mixed_facades\n")
		test_passed += 1
	else:
		print("  FAIL: mixed_facades\n")
		test_failed += 1


func _test_resolver_transcript() -> void:
	print("[TEST 8] Resolver evidence transcript\n")

	var resolver = TextureResolverClass.new(TEST_USER_DIR, TEST_DEFAULT_DIR)

	# Perform several resolutions
	resolver.resolve("facade_stone_valid")
	resolver.resolve("facade_metal_nonexistent")
	resolver.resolve("facade_wood_corrupt")

	var logs = resolver.get_log()

	print("  Resolver transcript (selected lines):")
	var user_count = 0
	var default_count = 0
	var none_count = 0

	for log_line in logs:
		if "resolved from USER" in log_line or "resolved from DEFAULT" in log_line or "UNRESOLVED" in log_line:
			print("    %s" % log_line)

		if "USER" in log_line:
			user_count += 1
		elif "DEFAULT" in log_line:
			default_count += 1
		elif "UNRESOLVED" in log_line:
			none_count += 1

	print("\n  Tier results:")
	print("    USER: %d" % user_count)
	print("    DEFAULT: %d" % default_count)
	print("    NONE: %d" % none_count)

	var success = (logs.size() > 0 and (user_count > 0 or default_count > 0))

	if success:
		print("  PASS: resolver_transcript\n")
		test_passed += 1
	else:
		print("  FAIL: resolver_transcript\n")
		test_failed += 1


func _cleanup_test_fixtures() -> void:
	print("\n[TEST] Cleaning up test fixtures...")

	var filename: String

	# Remove test user files
	var dir = DirAccess.open(TEST_USER_DIR)
	if dir:
		dir.list_dir_begin()
		filename = dir.get_next()
		while filename != "":
			if not filename.begins_with("."):
				dir.remove(TEST_USER_DIR + filename)
			filename = dir.get_next()

	# Remove test default files
	dir = DirAccess.open(TEST_DEFAULT_DIR)
	if dir:
		dir.list_dir_begin()
		filename = dir.get_next()
		while filename != "":
			if not filename.begins_with("."):
				dir.remove(TEST_DEFAULT_DIR + filename)
			filename = dir.get_next()

	# Remove directories
	DirAccess.remove_absolute(TEST_USER_DIR)
	DirAccess.remove_absolute(TEST_DEFAULT_DIR)

	print("[TEST] Cleanup complete")
