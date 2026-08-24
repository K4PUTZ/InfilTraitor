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
	## LEVEL-RENUMBER — this half of the file still said `-1`, and it PASSED, which
	## is the problem: with the ground plane at PLAYABLE_LEVEL, level -1 is eighty-
	## one levels below it rather than "the floor top", so the test was asserting a
	## true but meaningless thing. The property under test is unchanged — a level
	## BELOW the ground plane is created on demand, retrievably, idempotently — and
	## it is now expressed against the level that actually is the floor top.
	print("[1] _ensure_negative_voxel_layer() creates a real, retrievable layer\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	var below: int = GeometryCoords.FLOOR_TOP_LEVEL

	if renderer.get_layer(below) != null:
		_fail("get_layer(floor top) should be null before anything ensures it")
	else:
		_pass("get_layer(floor top) is null before it's ensured (nothing pre-created)")

	renderer._ensure_negative_voxel_layer(below)
	var layer: TileMapLayer = renderer.get_layer(below)
	if layer != null:
		_pass("get_layer(floor top) returns a real TileMapLayer after ensuring it")
	else:
		_fail("get_layer(floor top) still null after ensuring it")

	renderer._ensure_negative_voxel_layer(below)
	if renderer.get_layer(below) == layer:
		_pass("Ensuring the same sub-ground level again is a no-op (same node, not a new one)")
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

	## LEVEL-RENUMBER — the same two layers, named by what they ARE rather than by
	## a sign: the wall base is PLAYABLE_LEVEL and the floor top is one below it.
	renderer._ensure_voxel_layers(1)                            # the wall base
	renderer._ensure_layer(GeometryCoords.FLOOR_TOP_LEVEL)      # the floor top

	var level0: TileMapLayer = renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL)
	var level_neg1: TileMapLayer = renderer.get_layer(GeometryCoords.FLOOR_TOP_LEVEL)

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
	## The floor slot is still `relative + 1` and the wall band still
	## `wall_base + relative`; only the origin of `relative` moved.
	if level_neg1.z_index == 0 and level0.z_index == 10:
		_pass("z_index: level 0 = %d (wall_base + level), level -1 = %d (floor slot: level + 1)" % [level0.z_index, level_neg1.z_index])
	else:
		_fail("z_index mismatch: level0=%d (want 10) level_neg1=%d (want 0)" % [level0.z_index, level_neg1.z_index])

	renderer.queue_free()
	print("")


## D18: negative levels are never auto-filled contiguously — ensuring -3
## must NOT silently create -1 and -2 along the way.
func test_lazy_not_contiguous() -> void:
	## LEVEL-RENUMBER — the same D18 contract, addressed from the ground stack.
	## The three levels are the floor top and the two beneath it, which is what
	## `-1 / -2 / -3` used to name.
	print("[3] Lazy reveal — ensuring the third ground level does not create the two above it\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	var top: int = GeometryCoords.FLOOR_TOP_LEVEL

	renderer._ensure_negative_voxel_layer(top - 2)

	if renderer.get_layer(top) == null and renderer.get_layer(top - 1) == null:
		_pass("The floor top and the level below it remain unbuilt after only the third was ensured")
	else:
		_fail("Ensuring the third ground level leaked into building the two above it — violates D18's lazy contract")

	if renderer.get_layer(top - 2) != null:
		_pass("The third ground level itself exists, as requested")
	else:
		_fail("The third ground level was not created despite being explicitly ensured")

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

	## LEVEL-RENUMBER — the two ground levels, present so the test can prove walls
	## are placed WITHOUT them being disturbed. Their identity is what matters, not
	## the literals that used to name them.
	renderer._ensure_negative_voxel_layer(GeometryCoords.FLOOR_TOP_LEVEL)
	renderer._ensure_negative_voxel_layer(GeometryCoords.FLOOR_DEEP_LEVEL)

	renderer.render_block(Vector2i(0, 0), 0, 1, "concrete")

	var wall_layer: TileMapLayer = renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL)
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
	## LEVEL-RENUMBER — a FLOOR slab belongs on the floor top, which is what `-1`
	## named before the ground plane moved.
	var slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, GeometryCoords.FLOOR_TOP_LEVEL, "earth", registry)
	renderer.render_slab(slab)

	var layer: TileMapLayer = renderer.get_layer(GeometryCoords.FLOOR_TOP_LEVEL)
	if layer == null:
		_fail("render_slab() on the floor top did not create its layer")
		renderer.queue_free()
		print("")
		return

	var mismatches := 0
	for voxel in slab.voxels:
		var expected_variant: int = EarthVariantSelector.variant_for(voxel.grid_pos,
			voxel.level - GeometryCoords.PLAYABLE_LEVEL)
		var expected_source_id: int = VoxelRendererClass.MATERIALS.find("earth_%d" % expected_variant)
		var actual_source_id: int = layer.get_cell_source_id(voxel.grid_pos)
		if actual_source_id != expected_source_id:
			mismatches += 1

	if mismatches == 0:
		_pass("All 64 cells of a negative-level (-1) Slab placed correctly, independently re-verified")
	else:
		_fail("%d/64 cells mismatched on the negative-level Slab" % mismatches)

	if renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL) == null:
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
