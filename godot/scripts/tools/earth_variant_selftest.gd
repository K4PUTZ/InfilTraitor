## DESTRUCTION_MASTER_PLAN D2/D4 — EarthVariantSelector selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/earth_variant_selftest.gd
##
## This is the "core, isolated, verified before anything consumes it" prompt:
## no VoxelRenderer/TileSet/Slab wiring here on purpose — that's the next wave.

extends SceneTree

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION D2/D4 — EarthVariantSelector SELFTEST")
	print("=".repeat(70) + "\n")

	test_determinism()
	test_range()
	test_not_constant()
	test_distribution_uses_all_variants()
	test_assets_loadable_and_canon_sized()
	test_fnv1a_static_call_matches_instance_call()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ EARTH VARIANT SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ EARTH VARIANT SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## D5's whole invariant rests on this: same input, same output, always.
func test_determinism() -> void:
	print("[1] Determinism — same (pos, level) always returns the same index\n")

	var samples: Array = [
		[Vector2i(0, 0), 0], [Vector2i(5, 3), 0], [Vector2i(41, 17), 4], [Vector2i(-3, 8), 2],
	]
	var all_stable := true
	for sample in samples:
		var pos: Vector2i = sample[0]
		var level: int = sample[1]
		var first: int = EarthVariantSelector.variant_for(pos, level)
		for _i in range(5):
			var again: int = EarthVariantSelector.variant_for(pos, level)
			if again != first:
				all_stable = false
				_fail("variant_for(%s, %d) unstable: %d then %d" % [pos, level, first, again])

	if all_stable:
		_pass("All sampled positions return a stable index across repeated calls")

	print("")


## The index must be a valid palette slot — an out-of-range index is a
## silent-fail waiting to happen the moment something indexes an 8-element array with it.
func test_range() -> void:
	print("[2] Range — every index falls in [0, VARIANT_COUNT)\n")

	var all_in_range := true
	for x in range(-20, 20):
		for level in range(2):
			var idx: int = EarthVariantSelector.variant_for(Vector2i(x, x * 3 - 7), level)
			if idx < 0 or idx >= EarthVariantSelector.VARIANT_COUNT:
				all_in_range = false
				_fail("variant_for returned out-of-range index %d at x=%d level=%d" % [idx, x, level])

	if all_in_range:
		_pass("40 sampled positions all returned indices in [0, %d)" % EarthVariantSelector.VARIANT_COUNT)

	print("")


## A selector that always returns the same variant regardless of position
## would pass determinism trivially and still be useless — this is the
## "not a stub" check.
func test_not_constant() -> void:
	print("[3] Not a constant function — different positions can differ\n")

	var seen: Dictionary = {}
	for x in range(30):
		seen[EarthVariantSelector.variant_for(Vector2i(x, 0), 0)] = true

	if seen.size() > 1:
		_pass("30 positions along one row produced %d distinct variant indices" % seen.size())
	else:
		_fail("All 30 sampled positions produced the same index — selector is degenerate")

	print("")


## Coarse distribution sanity: across enough positions, all 8 slots should
## get used at least once. Not a statistical rigor test — just proof the
## hash isn't quietly favoring one or two indices only.
func test_distribution_uses_all_variants() -> void:
	print("[4] Distribution — all %d variants get selected across a real GU-sized area\n" % EarthVariantSelector.VARIANT_COUNT)

	var seen: Dictionary = {}
	for x in range(8):
		for y in range(8):
			seen[EarthVariantSelector.variant_for(Vector2i(x, y), 0)] = true

	if seen.size() == EarthVariantSelector.VARIANT_COUNT:
		_pass("All %d variants appeared across one 8x8 GU footprint (64 voxels)" % EarthVariantSelector.VARIANT_COUNT)
	else:
		_fail("Only %d/%d variants appeared across 64 voxels: %s" % [seen.size(), EarthVariantSelector.VARIANT_COUNT, seen.keys()])

	print("")


## The placeholder assets generate_voxel.py just produced must actually exist
## at the exact paths/dimensions the selector and (later) VoxelRenderer expect
## — same canon as the four material atoms (32x36, matching VOXEL_ATOM_W/H).
func test_assets_loadable_and_canon_sized() -> void:
	print("[5] All %d earth voxel atoms load at canon size (32x36)\n" % EarthVariantSelector.VARIANT_COUNT)

	var all_ok := true
	for i in range(EarthVariantSelector.VARIANT_COUNT):
		var path := EarthVariantSelector.variant_asset_path(i)
		var img := Image.new()
		var err := img.load(path)
		if err != OK:
			all_ok = false
			_fail("Failed to load %s (err=%d)" % [path, err])
			continue
		if img.get_width() != 32 or img.get_height() != 36:
			all_ok = false
			_fail("%s is %dx%d, expected 32x36" % [path, img.get_width(), img.get_height()])

	if all_ok:
		_pass("All %d voxel_earth_N.png atoms load at 32x36 (VOXEL_ATOM_W/H canon)" % EarthVariantSelector.VARIANT_COUNT)

	print("")


## B4 says the FNV-1a algorithm gets ONE owner. Prove the static-call
## refactor didn't fork it: calling through the class name (new caller,
## EarthVariantSelector) and through an instance (old caller, bake_selftest.gd's
## B4 test) must agree, and both must match the pinned test vector already in
## bake_selftest.gd's test_B4_fnv1a_determinism().
func test_fnv1a_static_call_matches_instance_call() -> void:
	print("[6] FacadeSampler._fnv1a_hash — static call agrees with instance call (single algorithm, B4)\n")

	var instance := FacadeSampler.new()
	var test_strings := ["edge_0", "facade_marble", "run_corner", "0,0,0"]
	var all_match := true
	for s in test_strings:
		var via_static: int = FacadeSampler._fnv1a_hash(s)
		var via_instance: int = instance._fnv1a_hash(s)
		if via_static != via_instance:
			all_match = false
			_fail("Mismatch for '%s': static=0x%08x instance=0x%08x" % [s, via_static, via_instance])

	if all_match:
		_pass("Static and instance calls agree on %d pinned strings — one algorithm, not two" % test_strings.size())

	print("")
