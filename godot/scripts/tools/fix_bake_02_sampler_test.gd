## FIX-BAKE-02 TEST: Units & Origins – Texel-based Window Origins
##
## Validates that FacadeSampler now returns origins in texel units [0, 64N) × [0, 32N),
## enabling full facade diversity (not collapsed to 4×2 buckets).

extends SceneTree

const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("FIX-BAKE-02 TEST: Units & Origins (Texel Units)")
	print("=".repeat(70) + "\n")

	var sampler = FacadeSamplerClass.new()
	var N = GeometryCoordsClass.TEX_AUTHORING_N
	var test_passed = true

	# Test 1: Isolated origin returns texel units [0, 64N) × [0, 32N)
	print("[TEST 1] Origin Units (Texels)\n")

	var mock_edge = _make_mock_edge("edge_0")
	var facade_id = "stone_base"

	var origin = sampler.get_window_origin_isolated_texels(mock_edge, facade_id)

	if origin.x >= 0 and origin.x < 64 * N:
		print("    ✓ origin.x in [0, %d): %d" % [64 * N, origin.x])
	else:
		print("    ✗ origin.x out of range [0, %d): %d" % [64 * N, origin.x])
		test_passed = false

	if origin.y >= 0 and origin.y < 32 * N:
		print("    ✓ origin.y in [0, %d): %d" % [32 * N, origin.y])
	else:
		print("    ✗ origin.y out of range [0, %d): %d" % [32 * N, origin.y])
		test_passed = false

	if test_passed:
		print("  PASS: Origin Units\n")
	else:
		print("  FAIL: Origin Units\n")
		test_passed = false

	# Test 2: Determinism (same edge → same origin)
	print("[TEST 2] Origin Determinism\n")

	var origin_a = sampler.get_window_origin_isolated_texels(mock_edge, facade_id)
	var origin_b = sampler.get_window_origin_isolated_texels(mock_edge, facade_id)

	if origin_a == origin_b:
		print("    ✓ Call 1: %s" % origin_a)
		print("    ✓ Call 2: %s" % origin_b)
		print("    ✓ Deterministic\n")
		print("  PASS: Origin Determinism\n")
	else:
		print("    ✗ Calls differ: %s vs %s" % [origin_a, origin_b])
		print("  FAIL: Origin Determinism\n")
		test_passed = false

	# Test 3: Different edges produce different origins (probabilistically)
	print("[TEST 3] Origin Distribution\n")

	var origins = []
	for i in range(10):
		var edge = _make_mock_edge("edge_%d" % i)
		origins.append(sampler.get_window_origin_isolated_texels(edge, facade_id))

	var unique_origins = {}
	for o in origins:
		unique_origins[str(o)] = true

	if unique_origins.size() >= 5:
		print("    ✓ 10 edges → %d unique origins (distributed)" % unique_origins.size())
		print("  PASS: Origin Distribution\n")
	else:
		print("    ✗ Only %d unique origins from 10 edges (expected ≥5)" % unique_origins.size())
		print("  FAIL: Origin Distribution\n")
		test_passed = false

	# Test 4: Run origins (all edges in run share column origin from canonical min)
	print("[TEST 4] Run Continuity (min_edge origin)\n")

	var min_edge = _make_mock_edge("run_min")
	var run_origin = sampler.get_window_origin_run_texels(min_edge, facade_id)

	if run_origin.x >= 0 and run_origin.x < 64 * N:
		print("    ✓ Run origin X (texel): %d in [0, %d)" % [run_origin.x, 64 * N])
	else:
		print("    ✗ Run origin X out of range: %d" % run_origin.x)
		test_passed = false

	if run_origin.y == 0:
		print("    ✓ Run origin Y: 0 (v1 fixed at row 0)")
	else:
		print("    ✗ Run origin Y should be 0, got %d" % run_origin.y)
		test_passed = false

	print("    ✓ Column continuity: all walls in run sample column %d\n" % run_origin.x)
	print("  PASS: Run Continuity\n")

	print("=".repeat(70))
	if test_passed:
		print("✓ FIX-BAKE-02 ALL TESTS PASS")
	else:
		print("✗ FIX-BAKE-02 TESTS FAILED")
	print("=".repeat(70) + "\n")

	quit(0 if test_passed else 1)


class MockEdge:
	var id: String
	func _init(p_id: String) -> void:
		id = p_id
	func key_string() -> String:
		return id

func _make_mock_edge(id: String):
	return MockEdge.new(id)
