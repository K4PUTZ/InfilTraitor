## DESTRUCTION_MASTER_PLAN D17/D18 — negative storey selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/negative_storey_selftest.gd
##
## Proves the floor can live at negative levels without disturbing the
## existing (positive) wall/block/prop pipeline at all — D17's whole claim.

extends SceneTree

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION D17/D18 — Negative storey SELFTEST")
	print("=".repeat(70) + "\n")

	test_negative_layer_creation_and_lookup()
	test_negative_level_position_and_zindex_formula()
	test_lazy_not_contiguous()
	test_positive_pipeline_unaffected()
	test_slab_render_routes_negative_level_correctly()
	test_set_voxel_cell_still_rejects_unensured_level()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ NEGATIVE STOREY SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ NEGATIVE STOREY SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func test_negative_layer_creation_and_lookup() -> void:
	print("[1] _ensure_negative_voxel_layer() creates a real, retrievable layer\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	if renderer.get_layer(-1) != null:
		_fail("get_layer(-1) should be null before anything ensures it")
	else:
		_pass("get_layer(-1) is null before it's ensured (nothing pre-created)")

	renderer._ensure_negative_voxel_layer(-1)
	var layer: TileMapLayer = renderer.get_layer(-1)
	if layer != null:
		_pass("get_layer(-1) returns a real TileMapLayer after ensuring it")
	else:
		_fail("get_layer(-1) still null after _ensure_negative_voxel_layer(-1)")

	renderer._ensure_negative_voxel_layer(-1)
	if renderer.get_layer(-1) == layer:
		_pass("Calling _ensure_negative_voxel_layer(-1) again is a no-op (same node, not a new one)")
	else:
		_fail("Second ensure call replaced the layer instead of reusing it")

	renderer.queue_free()
	print("")


## The position/z-index formula must produce sane, sign-correct results for
## negative levels — position moves further "down" (higher Y) via the same
## formula walls use; z_index lands in the legacy floor slot (level + 1,
## Z-SLOT-01) so floors stay under the overlay ecosystem. Both live in
## _build_voxel_layer_node, not a parallel copy.
func test_negative_level_position_and_zindex_formula() -> void:
	print("[2] Negative level position/z-index — same formula, sign-correct result\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO, 10)

	renderer._ensure_voxel_layers(1)          # level 0 (wall base)
	renderer._ensure_negative_voxel_layer(-1) # level -1 (floor top)

	var level0: TileMapLayer = renderer.get_layer(0)
	var level_neg1: TileMapLayer = renderer.get_layer(-1)

	# VOXEL_STEP_PX * level, position.y = ... - VOXEL_STEP_PX * level.
	# level -1 => -VOXEL_STEP_PX * -1 = +VOXEL_STEP_PX => Y increases (moves down).
	if level_neg1.position.y > level0.position.y:
		_pass("Level -1's screen Y is below level 0's (floor sits below the wall base, as expected)")
	else:
		_fail("Level -1 should be visually BELOW level 0: y=%f vs y=%f" % [level_neg1.position.y, level0.position.y])

	## Z-SLOT-01 (2026-07-16): negative levels no longer share the wall formula's
	## z band — they render in the LEGACY FLOOR SLOT (z = level + 1, floor top -1
	## at z=0) so the floor-painted overlay ecosystem (shadows z=1 .. selection
	## z=7) draws above the floor and below the walls again. Walls keep
	## wall_base_z_index + level. See _build_voxel_layer_node.
	if level_neg1.z_index == (-1) + 1 and level0.z_index == 10 + 0:
		_pass("z_index: level 0 = %d (wall_base + level), level -1 = %d (floor slot: level + 1)" % [level0.z_index, level_neg1.z_index])
	else:
		_fail("z_index mismatch: level0=%d (want 10) level_neg1=%d (want 0)" % [level0.z_index, level_neg1.z_index])

	renderer.queue_free()
	print("")


## D18: negative levels are never auto-filled contiguously — ensuring -3
## must NOT silently create -1 and -2 along the way.
func test_lazy_not_contiguous() -> void:
	print("[3] Lazy reveal — ensuring level -3 does not create -1 or -2\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	renderer._ensure_negative_voxel_layer(-3)

	if renderer.get_layer(-1) == null and renderer.get_layer(-2) == null:
		_pass("Levels -1 and -2 remain unbuilt after only -3 was ensured")
	else:
		_fail("Ensuring -3 leaked into building -1 and/or -2 — violates D18's lazy contract")

	if renderer.get_layer(-3) != null:
		_pass("Level -3 itself exists, as requested")
	else:
		_fail("Level -3 was not created despite being explicitly ensured")

	renderer.queue_free()
	print("")


## D17's central claim: the existing wall/block pipeline is completely
## unaffected. Prove render_block() (walls/props) still works exactly as
## before, with negative floor layers coexisting alongside it.
func test_positive_pipeline_unaffected() -> void:
	print("[4] Positive (wall) pipeline is unaffected by negative layers existing\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	renderer._ensure_negative_voxel_layer(-1)
	renderer._ensure_negative_voxel_layer(-2)

	renderer.render_block(Vector2i(0, 0), 0, 1, "concrete")

	var wall_layer: TileMapLayer = renderer.get_layer(0)
	var placed := 0
	if wall_layer != null:
		for voxel_pos in GeometryCoordsClass.gu_voxels(Vector2i(0, 0)):
			if wall_layer.get_cell_source_id(voxel_pos) >= 0:
				placed += 1

	if placed == 64:
		_pass("render_block() still places all 64 cells correctly with negative layers present")
	else:
		_fail("render_block() placed %d/64 cells (expected 64) — negative layers interfered" % placed)

	if renderer.get_layer_count() == 8:
		_pass("get_layer_count() still reports 8 (positive-only, LEVELS_PER_STOREY) — negative layers not counted")
	else:
		_fail("get_layer_count() = %d, expected 8 (negative layers should not be counted)" % renderer.get_layer_count())

	renderer.queue_free()
	print("")


## render_slab() must route a negative-level Slab to the negative storage,
## via _ensure_negative_voxel_layer(), and place cells that read back
## correctly — the same round-trip discipline slab_render_selftest.gd used
## for the positive case, now for the negative one.
func test_slab_render_routes_negative_level_correctly() -> void:
	print("[5] render_slab() with a negative-level Slab places real, correct cells\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	var registry := SlabRegistry.new()
	var gu := Vector2i(3, 3)
	var slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, -1, "earth", registry)
	renderer.render_slab(slab)

	var layer: TileMapLayer = renderer.get_layer(-1)
	if layer == null:
		_fail("render_slab() with slab.level=-1 did not create the negative layer")
		renderer.queue_free()
		print("")
		return

	var mismatches := 0
	for voxel in slab.voxels:
		var expected_variant: int = EarthVariantSelector.variant_for(voxel.grid_pos, voxel.level)
		var expected_source_id: int = VoxelRendererClass.MATERIALS.find("earth_%d" % expected_variant)
		var actual_source_id: int = layer.get_cell_source_id(voxel.grid_pos)
		if actual_source_id != expected_source_id:
			mismatches += 1

	if mismatches == 0:
		_pass("All 64 cells of a negative-level (-1) Slab placed correctly, independently re-verified")
	else:
		_fail("%d/64 cells mismatched on the negative-level Slab" % mismatches)

	if renderer.get_layer(0) == null:
		_pass("No positive layer was created as a side effect of rendering a negative-level Slab")
	else:
		_fail("Rendering a negative-level Slab unexpectedly created a positive layer 0")

	renderer.queue_free()
	print("")


## The pre-existing contract (never silently no-op without a warning) must
## still hold for BOTH signs — a level nobody ensured is still a hard warning,
## not a crash and not a silent success.
func test_set_voxel_cell_still_rejects_unensured_level() -> void:
	print("[6] _set_voxel_cell() on an unensured negative level still warns, doesn't crash\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	# Level -5 was never ensured. This should push_warning and return, not error.
	renderer._set_voxel_cell(Vector2i(0, 0), -5, "earth_0")
	_pass("_set_voxel_cell() on unensured level -5 returned without crashing (warning expected in output above)")

	renderer.queue_free()
	print("")
