## FacadeSampler Selftest (T1, Pure Math, Headless)

extends SceneTree

var FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")

class MockEdge:
	var id: String
	func _init(p_id: String) -> void:
		id = p_id
	func key_string() -> String:
		return id

func _init() -> void:
	print("\n" + "=".repeat(60))
	print("BAKE-03 SELFTEST: FacadeSampler")
	print("=".repeat(60) + "\n")
	
	var all_pass = true
	if not _test_mirror_1d_boundaries():
		all_pass = false
	if not _test_mirror_1d_seams():
		all_pass = false
	if not _test_mirror_2d_quad():
		all_pass = false
	if not _test_fnv1a_determinism():
		all_pass = false
	if not _test_window_origin_run():
		all_pass = false
	if not _test_window_origin_isolated():
		all_pass = false
	if not _test_sample_synthetic_facade():
		all_pass = false
	
	print("\n" + "=".repeat(60))
	if all_pass:
		print("BAKE-03 SELFTEST: 7 / 7 PASS")
		print("=".repeat(60) + "\n")
		print("✓ SELFTEST PASS")
	else:
		print("BAKE-03 SELFTEST: FAILED")
		print("=".repeat(60) + "\n")
		print("✗ SELFTEST FAIL")
	quit()

func _test_mirror_1d_boundaries() -> bool:
	print("[TEST 1] mirror_1d_boundaries\n")
	var sampler = FacadeSamplerClass.new()
	var success = true
	var tests = [
		[0.0, 4, 0.0],
		[1.0, 4, 1.0],
		[3.0, 4, 3.0],
		[4.0, 4, 0.0],
		[5.0, 4, 3.0],
		[-1.0, 4, 1.0],
		[-4.0, 4, 0.0],
	]
	for test in tests:
		var result = sampler._mirror_1d(test[0], test[1])
		if abs(result - test[2]) < 0.0001:
			print("    ✓ mirror_1d(%.1f, %d) = %.1f" % [test[0], test[1], result])
		else:
			print("    ✗ mirror_1d(%.1f, %d) = %.1f (expected %.1f)" % [test[0], test[1], result, test[2]])
			success = false
	if success:
		print("  PASS: mirror_1d_boundaries\n")
	else:
		print("  FAIL: mirror_1d_boundaries\n")
	return success

func _test_mirror_1d_seams() -> bool:
	print("[TEST 2] mirror_1d_seams\n")
	var sampler = FacadeSamplerClass.new()
	var success = true
	var S = 64
	for i in range(10):
		var k1 = float(i) * 3.7
		var k2 = k1 + 2.0 * float(S)
		var val1 = sampler._mirror_1d(k1, S)
		var val2 = sampler._mirror_1d(k2, S)
		if abs(val1 - val2) < 0.0001:
			print("    ✓ Period 2S: mirror(%.1f) == mirror(%.1f)" % [k1, k2])
		else:
			print("    ✗ Period mismatch: mirror(%.1f)=%.1f vs mirror(%.1f)=%.1f" % [k1, val1, k2, val2])
			success = false
	if success:
		print("  PASS: mirror_1d_seams\n")
	else:
		print("  FAIL: mirror_1d_seams\n")
	return success

func _test_mirror_2d_quad() -> bool:
	print("[TEST 3] mirror_2d_quad\n")
	var sampler = FacadeSamplerClass.new()
	var success = true
	var corners = [[0.0, 0.0], [63.0, 0.0], [63.0, 31.0], [0.0, 31.0]]
	for corner in corners:
		var mirrored = sampler._mirror_2d(corner[0], corner[1], 64, 32)
		print("    ✓ mirror_2d(%.0f, %.0f) = (%d, %d)" % [corner[0], corner[1], mirrored.x, mirrored.y])
		if mirrored.x < 0 or mirrored.x >= 64 or mirrored.y < 0 or mirrored.y >= 32:
			print("    ✗ Out of bounds: (%d, %d)" % [mirrored.x, mirrored.y])
			success = false
	if success:
		print("  PASS: mirror_2d_quad\n")
	else:
		print("  FAIL: mirror_2d_quad\n")
	return success

func _test_fnv1a_determinism() -> bool:
	print("[TEST 4] fnv1a_determinism\n")
	var sampler = FacadeSamplerClass.new()
	var success = true
	var test_inputs = ["edge_0x12ab:facade_stone_base", "edge_0xffff:facade_wood_brick", "edge_isolated_0:facade_metal"]
	for input_str in test_inputs:
		var hash1 = sampler._fnv1a_hash(input_str)
		var hash2 = sampler._fnv1a_hash(input_str)
		if hash1 == hash2:
			print("    ✓ FNV-1a('%s') = 0x%08x (deterministic)" % [input_str, hash1 & 0xFFFFFFFF])
		else:
			print("    ✗ FNV-1a not deterministic: 0x%08x vs 0x%08x" % [hash1, hash2])
			success = false
	if success:
		print("  PASS: fnv1a_determinism\n")
	else:
		print("  FAIL: fnv1a_determinism\n")
	return success

func _test_window_origin_run() -> bool:
	print("[TEST 5] window_origin_run\n")
	var sampler = FacadeSamplerClass.new()
	var success = true
	var edge = MockEdge.new("edge_test_run_0")
	var origin = sampler.get_window_origin_run(edge, "facade_stone_base")
	if origin.x >= 0 and origin.x < 64:
		print("    ✓ Origin X in range: %d" % origin.x)
	else:
		print("    ✗ Origin X out of range: %d" % origin.x)
		success = false
	if origin.y >= 0 and origin.y < 32:
		print("    ✓ Origin Y in range: %d" % origin.y)
	else:
		print("    ✗ Origin Y out of range: %d" % origin.y)
		success = false
	var origin2 = sampler.get_window_origin_run(edge, "facade_stone_base")
	if origin == origin2:
		print("    ✓ Origin deterministic: (%d, %d)" % [origin.x, origin.y])
	else:
		print("    ✗ Origin not deterministic: (%d, %d) vs (%d, %d)" % [origin.x, origin.y, origin2.x, origin2.y])
		success = false
	if success:
		print("  PASS: window_origin_run\n")
	else:
		print("  FAIL: window_origin_run\n")
	return success

func _test_window_origin_isolated() -> bool:
	print("[TEST 6] window_origin_isolated\n")
	var sampler = FacadeSamplerClass.new()
	var success = true
	var edge = MockEdge.new("edge_test_isolated_0")
	var origin = sampler.get_window_origin_isolated(edge, "facade_stone_base")
	if origin.x >= 0 and origin.x < 64:
		print("    ✓ Origin X in range: %d" % origin.x)
	else:
		print("    ✗ Origin X out of range: %d" % origin.x)
		success = false
	if origin.y >= 0 and origin.y < 32:
		print("    ✓ Origin Y in range: %d" % origin.y)
	else:
		print("    ✗ Origin Y out of range: %d" % origin.y)
		success = false
	var origin_wood = sampler.get_window_origin_isolated(edge, "facade_wood_base")
	if origin != origin_wood:
		print("    ✓ Different facades hash differently: stone=(%d,%d), wood=(%d,%d)" % [origin.x, origin.y, origin_wood.x, origin_wood.y])
	else:
		print("    ✗ Different facades should hash differently")
		success = false
	if success:
		print("  PASS: window_origin_isolated\n")
	else:
		print("  FAIL: window_origin_isolated\n")
	return success

func _test_sample_synthetic_facade() -> bool:
	print("[TEST 7] sample_synthetic_facade\n")
	var facade = Image.create(64, 32, false, Image.FORMAT_L8)
	for y in range(32):
		for x in range(64):
			facade.set_pixel(x, y, Color.WHITE)
	facade.set_pixel(0, 0, Color(0.2, 0.2, 0.2))
	facade.set_pixel(63, 0, Color(0.5, 0.5, 0.5))
	facade.set_pixel(63, 31, Color(0.8, 0.8, 0.8))
	facade.set_pixel(0, 31, Color(0.3, 0.3, 0.3))
	var sampler = FacadeSamplerClass.new()
	var success = true
	var val_00 = sampler.sample(facade, 0.0, 0.0)
	var val_63_0 = sampler.sample(facade, 63.0, 0.0)
	var val_63_31 = sampler.sample(facade, 63.0, 31.0)
	var val_0_31 = sampler.sample(facade, 0.0, 31.0)
	if abs(val_00 - 0.2) < 0.05:
		print("    ✓ Corner (0, 0): %.2f ≈ 0.20" % val_00)
	else:
		print("    ✗ Corner (0, 0): %.2f (expected 0.20)" % val_00)
		success = false
	if abs(val_63_0 - 0.5) < 0.05:
		print("    ✓ Corner (63, 0): %.2f ≈ 0.50" % val_63_0)
	else:
		print("    ✗ Corner (63, 0): %.2f (expected 0.50)" % val_63_0)
		success = false
	if abs(val_63_31 - 0.8) < 0.05:
		print("    ✓ Corner (63, 31): %.2f ≈ 0.80" % val_63_31)
	else:
		print("    ✗ Corner (63, 31): %.2f (expected 0.80)" % val_63_31)
		success = false
	if abs(val_0_31 - 0.3) < 0.05:
		print("    ✓ Corner (0, 31): %.2f ≈ 0.30" % val_0_31)
	else:
		print("    ✗ Corner (0, 31): %.2f (expected 0.30)" % val_0_31)
		success = false
	var val_64_0 = sampler.sample(facade, 64.0, 0.0)
	if abs(val_64_0 - 0.2) < 0.05:
		print("    ✓ Wrap (64, 0): %.2f ≈ 0.20 (matches (0, 0))" % val_64_0)
	else:
		print("    ✗ Wrap (64, 0): %.2f (expected 0.20)" % val_64_0)
		success = false
	var val_65_0 = sampler.sample(facade, 65.0, 0.0)
	if abs(val_65_0 - 0.5) < 0.05:
		print("    ✓ Reflect (65, 0): %.2f ≈ 0.50 (matches (63, 0))" % val_65_0)
	else:
		print("    ✗ Reflect (65, 0): %.2f (expected 0.50)" % val_65_0)
		success = false
	if success:
		print("  PASS: sample_synthetic_facade\n")
	else:
		print("  FAIL: sample_synthetic_facade\n")
	return success
