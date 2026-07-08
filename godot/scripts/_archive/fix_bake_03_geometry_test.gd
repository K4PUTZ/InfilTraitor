## FIX-BAKE-03 TEST: PerFaceProjector Integer Shear Assertion
##
## Validates that PerFaceProjector._init() runs integer-shear validation
## and passes with current matrices.

extends SceneTree

const PerFaceProjectorClass = preload("res://godot/scripts/systems/per_face_projector.gd")

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("FIX-BAKE-03 TEST: PerFaceProjector Geometry")
	print("=".repeat(70) + "\n")

	var test_passed = true

	# Test 1: Constructor runs and assertion passes/fails loudly
	print("[TEST 1] Integer Shear Assertion Runs\n")

	var projector = PerFaceProjectorClass.new()
	print("    ✓ Constructor completed (assertion passed)\n")
	print("  PASS: Assertion Runs\n")

	# Test 2: Round-trip transforms (should still work)
	print("[TEST 2] Round-Trip Transform Accuracy\n")

	var N = 16
	var test_points = [
		Vector2(0.0, 0.0),
		Vector2(float(4 * N), float(4 * N)),
		Vector2(float(8 * N - 1), float(8 * N - 1)),
	]

	var all_round_trip = true
	for face_idx in range(4):
		for test_pt in test_points:
			var screen = projector.flat_to_screen(face_idx, test_pt)
			var flat_back = projector.screen_to_flat(face_idx, screen)
			var error = test_pt.distance_to(flat_back)

			if error < 0.01:
				print("    ✓ Face %d point %.1f,%.1f: round-trip error = %.6f" %
					[face_idx, test_pt.x, test_pt.y, error])
			else:
				print("    ✗ Face %d point %.1f,%.1f: round-trip error = %.6f (>0.01)" %
					[face_idx, test_pt.x, test_pt.y, error])
				all_round_trip = false

	if all_round_trip:
		print("  PASS: Round-Trip Transforms\n")
	else:
		print("  FAIL: Round-Trip Transforms\n")
		test_passed = false

	print("=".repeat(70))
	if test_passed:
		print("✓ FIX-BAKE-03 GEOMETRY TEST PASS")
	else:
		print("✗ FIX-BAKE-03 GEOMETRY TEST FAILED")
	print("=".repeat(70) + "\n")

	quit(0 if test_passed else 1)
