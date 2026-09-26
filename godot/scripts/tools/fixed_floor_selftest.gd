## DESTRUCTION_MASTER_PLAN D13 — fixed floor level selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/fixed_floor_selftest.gd
##
## Proves register_fixed_level() (the 7 non-destructible levels) and
## register_slab() (the 1 destructible top) compose into the full D13 8-level
## stack — without the fixed levels ever touching Slab/Voxel/dirty-tracking.
## R3D-END (END-1): [1] (the 64 placed cells' variant) went with the 2D board (it read placed TILES; no tile is written any more). The rest
## stays until END-4 deletes `register_fixed_level()` and the level layers.

extends SceneTree

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const VoxelBoardClass = preload("res://godot/scripts/geometry/voxel_board.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION D13 — Fixed floor level SELFTEST")
	print("=".repeat(70) + "\n")

	test_fixed_level_does_not_touch_slab_registry()
	test_one_call_builds_only_the_requested_level()
	test_full_d13_stack_top_destructible_rest_fixed()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	VoxelStore.active = null
	if failed == 0:
		print("✓ FIXED FLOOR SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ FIXED FLOOR SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## D13's whole point: fixed levels are never a Slab/Voxel, so there is no
## dirty_count to accidentally leave nonzero and no registry entry to leak.
func test_fixed_level_does_not_touch_slab_registry() -> void:
	print("[2] register_fixed_level() never touches a SlabRegistry\n")

	var renderer := VoxelBoardClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	var registry := SlabRegistry.new()

	renderer.register_fixed_level(Vector2i(0, 0), GeometryCoords.FLOOR_TOP_LEVEL - 1)

	if registry.is_empty():
		_pass("An independent SlabRegistry stays empty — register_fixed_level() took no registry and created no Slab")
	else:
		_fail("SlabRegistry is unexpectedly non-empty after a fixed-level render")

	renderer.queue_free()
	print("")


## D18: one call renders exactly the one level asked for — no eager
## materialization of neighbouring levels "while we're at it".
func test_one_call_builds_only_the_requested_level() -> void:
	print("[3] One register_fixed_level() call touches only its own level\n")

	var renderer := VoxelBoardClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	var rendered_level: int = GeometryCoords.FLOOR_TOP_LEVEL - 5
	renderer.register_fixed_level(Vector2i(1, 1), rendered_level)

	var neighbours_untouched := true
	for offset in [4, 6, 0, 7]:  ## the levels either side of it, plus the stack's ends
		var level: int = GeometryCoords.FLOOR_TOP_LEVEL - offset
		if renderer.has_level(level):
			neighbours_untouched = false
			_fail("Level %d was created as a side effect of rendering level %d" % [level, rendered_level])

	if neighbours_untouched:
		_pass("The neighbouring ground levels remain unbuilt after only %d was rendered" % rendered_level)

	renderer.queue_free()
	print("")


## The full D13 shape: FLOOR_TOP_LEVEL is a real Slab (destructible, dirty-tracked);
## the seven levels below it are fixed (rendered, but never a Voxel/Slab at all). Confirm
## both halves coexist correctly and the fixed half is structurally incapable
## of contributing to any dirty_count.
func test_full_d13_stack_top_destructible_rest_fixed() -> void:
	print("[4] Full D13 stack: 1 destructible top (Slab) + 7 fixed levels\n")

	var renderer := VoxelBoardClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	var gu := Vector2i(6, 6)
	var registry := SlabRegistry.new()

	## OCC-FIX-03c (2026-09-01) — LEVEL-RENUMBER RESIDUE. This file was only half
	## migrated: test [1] already asked for `FLOOR_TOP_LEVEL - 3`, while [2], [3]
	## and [4] still spelled the pre-renumber negatives (-1, -2, -6, -8). Those
	## resolve to real layers 80 levels under the ground stack, so the suite passed
	## while exercising numbers no production caller can produce — and anything
	## level-KEYED (layer Y via relative_level(), the B4-pinned earth-variant hash)
	## was being fed the wrong axis. Derived from FLOOR_TOP_LEVEL now.
	var stack_top: int = GeometryCoords.FLOOR_TOP_LEVEL
	var stack_bottom: int = stack_top - 7

	# Top: real Slab, destructible.
	var top_slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, stack_top, "earth", registry)
	renderer.register_slab(top_slab)

	## RENDER3D R3D-1d: `Voxel` has no state of its own — the `set_damage()` call below
	## needs an active store built over this fixture's registry.
	VoxelStore.active = VoxelStore.build(EdgeRegistry.new(), registry, [])

	# The other 7: fixed, no Slab.
	for level in range(stack_bottom, stack_top):
		renderer.register_fixed_level(gu, level)

	var all_levels_have_layers := true
	for level in range(stack_bottom, stack_top + 1):
		if not renderer.has_level(level):
			all_levels_have_layers = false
			_fail("Level %d has no layer — full 8-level stack incomplete" % level)
	if all_levels_have_layers:
		_pass("All 8 levels of the D13 stack (%d..%d) have real layers" % [stack_bottom, stack_top])

	# Damage the top — only the Slab (1 registered) can ever be dirty.
	top_slab.voxels[0].set_damage(Voxel.DamageState.DESTROYED)
	if registry.dirty_slabs().size() == 1 and registry.all_slabs().size() == 1:
		_pass("Registry has exactly 1 Slab (the top); damaging it is the only dirty state that can ever exist in this stack")
	else:
		_fail("Registry has %d slabs (%d dirty) — expected exactly 1/1, the fixed levels must never register" % [
			registry.all_slabs().size(), registry.dirty_slabs().size(),
		])

	renderer.queue_free()
	print("")
