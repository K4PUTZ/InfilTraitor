## DESTRUCTION_MASTER_PLAN D17/D18 — negative storey selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/negative_storey_selftest.gd
##
## Proves the floor can live at negative levels without disturbing the
## existing (positive) wall/block/prop pipeline at all — D17's whole claim.
## R3D-END (END-1): [4] and [5] (register_block_levels() / register_slab() placed cells) went with the 2D board (it read placed TILES; no tile is written any more).
## END-4: [6] (`_set_voxel_cell()` on an unensured level) went with the placement. The rest stays until END-6 turns the level layers into arithmetic.

extends SceneTree

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const VoxelBoardClass = preload("res://godot/scripts/geometry/voxel_board.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION D17/D18 — Negative storey SELFTEST")
	print("=".repeat(70) + "\n")

	test_negative_layer_creation_and_lookup()
	test_negative_level_position_and_zindex_formula()
	test_lazy_not_contiguous()

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
	print("[1] _ensure_floor_level() creates a real, retrievable layer\n")

	var renderer := VoxelBoardClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	var below: int = GeometryCoords.FLOOR_TOP_LEVEL

	if renderer.has_level(below):
		_fail("has_level(floor top) should be false before anything ensures it")
	else:
		_pass("has_level(floor top) is false before it's ensured (nothing pre-created)")

	renderer._ensure_floor_level(below)
	if renderer.has_level(below):
		_pass("has_level(floor top) is true after ensuring it")
	else:
		_fail("has_level(floor top) still false after ensuring it")

	var built_before: int = renderer.level_keys().size()
	renderer._ensure_floor_level(below)
	if renderer.level_keys().size() == built_before and renderer.has_level(below):
		_pass("Ensuring the same sub-ground level again is a no-op (one level, not two)")
	else:
		_fail("Second ensure call built another level")

	renderer.queue_free()
	print("")


## The position/z-index formula must produce sane, sign-correct results for
## negative levels — position moves further "down" (higher Y) via the same
## formula walls use; z_index lands in the legacy floor slot (level + 1,
## Z-SLOT-01) so floors stay under the overlay ecosystem. Both live in
## `level_origin()` / `level_z_index()`, not a parallel copy.
func test_negative_level_position_and_zindex_formula() -> void:
	print("[2] Negative level position/z-index — same formula, sign-correct result\n")

	var renderer := VoxelBoardClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO, 10)

	## LEVEL-RENUMBER — the same two layers, named by what they ARE rather than by
	## a sign: the wall base is PLAYABLE_LEVEL and the floor top is one below it.
	renderer._ensure_wall_levels(1)                            # the wall base
	renderer._ensure_level(GeometryCoords.FLOOR_TOP_LEVEL)      # the floor top

	var level0_y: float = renderer.level_origin(GeometryCoords.PLAYABLE_LEVEL).y
	var level_neg1_y: float = renderer.level_origin(GeometryCoords.FLOOR_TOP_LEVEL).y
	var level0_z: int = renderer.level_z_index(GeometryCoords.PLAYABLE_LEVEL)
	var level_neg1_z: int = renderer.level_z_index(GeometryCoords.FLOOR_TOP_LEVEL)

	# VOXEL_STEP_PX * level, position.y = ... - VOXEL_STEP_PX * level.
	# level -1 => -VOXEL_STEP_PX * -1 = +VOXEL_STEP_PX => Y increases (moves down).
	if level_neg1_y > level0_y:
		_pass("Level -1's screen Y is below level 0's (floor sits below the wall base, as expected)")
	else:
		_fail("Level -1 should be visually BELOW level 0: y=%f vs y=%f" % [level_neg1_y, level0_y])

	## Z-SLOT-01 (2026-07-16): negative levels no longer share the wall formula's
	## z band — they render in the LEGACY FLOOR SLOT (z = level + 1, floor top -1
	## at z=0) so the floor-painted overlay ecosystem (shadows z=1 .. selection
	## z=7) draws above the floor and below the walls again. Walls keep
	## wall_base_z_index + level. See _build_voxel_layer_node.
	## The floor slot is still `relative + 1` and the wall band still
	## `wall_base + relative`; only the origin of `relative` moved.
	if level_neg1_z == 0 and level0_z == 10:
		_pass("z_index: level 0 = %d (wall_base + level), level -1 = %d (floor slot: level + 1)" % [level0_z, level_neg1_z])
	else:
		_fail("z_index mismatch: level0=%d (want 10) level_neg1=%d (want 0)" % [level0_z, level_neg1_z])

	renderer.queue_free()
	print("")


## D18: negative levels are never auto-filled contiguously — ensuring -3
## must NOT silently create -1 and -2 along the way.
func test_lazy_not_contiguous() -> void:
	## LEVEL-RENUMBER — the same D18 contract, addressed from the ground stack.
	## The three levels are the floor top and the two beneath it, which is what
	## `-1 / -2 / -3` used to name.
	print("[3] Lazy reveal — ensuring the third ground level does not create the two above it\n")

	var renderer := VoxelBoardClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	var top: int = GeometryCoords.FLOOR_TOP_LEVEL

	renderer._ensure_floor_level(top - 2)

	if not renderer.has_level(top) and not renderer.has_level(top - 1):
		_pass("The floor top and the level below it remain unbuilt after only the third was ensured")
	else:
		_fail("Ensuring the third ground level leaked into building the two above it — violates D18's lazy contract")

	if renderer.has_level(top - 2):
		_pass("The third ground level itself exists, as requested")
	else:
		_fail("The third ground level was not created despite being explicitly ensured")

	renderer.queue_free()
	print("")

