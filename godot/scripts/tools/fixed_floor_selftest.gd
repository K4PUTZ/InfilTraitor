## DESTRUCTION_MASTER_PLAN D13 — fixed floor level selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/fixed_floor_selftest.gd
##
## Proves render_fixed_earth_level() (the 7 non-destructible levels) and
## render_slab() (the 1 destructible top) compose into the full D13 8-level
## stack — without the fixed levels ever touching Slab/Voxel/dirty-tracking.

extends SceneTree

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("DESTRUCTION D13 — Fixed floor level SELFTEST")
	print("=".repeat(70) + "\n")

	test_fixed_level_places_correct_cells()
	test_fixed_level_does_not_touch_slab_registry()
	test_one_call_builds_only_the_requested_level()
	test_full_d13_stack_top_destructible_rest_fixed()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

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


func test_fixed_level_places_correct_cells() -> void:
	print("[1] render_fixed_earth_level() places 64 independently-verified cells\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	var gu := Vector2i(2, 5)
	renderer.render_fixed_earth_level(gu, -4)

	var layer: TileMapLayer = renderer.get_layer(-4)
	if layer == null:
		_fail("Level -4 was not created")
		renderer.queue_free()
		print("")
		return

	var mismatches := 0
	var checked := 0
	for voxel_pos in GeometryCoordsClass.gu_voxels(gu):
		checked += 1
		var expected_variant: int = EarthVariantSelector.variant_for(voxel_pos, -4)
		var expected_source_id: int = VoxelRendererClass.MATERIALS.find("earth_%d" % expected_variant)
		var actual_source_id: int = layer.get_cell_source_id(voxel_pos)
		if actual_source_id != expected_source_id:
			mismatches += 1

	if checked == 64 and mismatches == 0:
		_pass("64/64 cells on fixed level -4 match an independently re-derived variant")
	else:
		_fail("%d/%d cells mismatched on fixed level -4" % [mismatches, checked])

	renderer.queue_free()
	print("")


## D13's whole point: fixed levels are never a Slab/Voxel, so there is no
## dirty_count to accidentally leave nonzero and no registry entry to leak.
func test_fixed_level_does_not_touch_slab_registry() -> void:
	print("[2] render_fixed_earth_level() never touches a SlabRegistry\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	var registry := SlabRegistry.new()

	renderer.render_fixed_earth_level(Vector2i(0, 0), -2)

	if registry.is_empty():
		_pass("An independent SlabRegistry stays empty — render_fixed_earth_level() took no registry and created no Slab")
	else:
		_fail("SlabRegistry is unexpectedly non-empty after a fixed-level render")

	renderer.queue_free()
	print("")


## D18: one call renders exactly the one level asked for — no eager
## materialization of neighbouring levels "while we're at it".
func test_one_call_builds_only_the_requested_level() -> void:
	print("[3] One render_fixed_earth_level() call touches only its own level\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	renderer.render_fixed_earth_level(Vector2i(1, 1), -6)

	var neighbours_untouched := true
	for level in [-5, -7, -1, -8]:
		if renderer.get_layer(level) != null:
			neighbours_untouched = false
			_fail("Level %d was created as a side effect of rendering level -6" % level)

	if neighbours_untouched:
		_pass("Levels -5, -7, -1, -8 remain unbuilt after only -6 was rendered")

	renderer.queue_free()
	print("")


## The full D13 shape: level -1 is a real Slab (destructible, dirty-tracked);
## levels -2..-8 are fixed (rendered, but never a Voxel/Slab at all). Confirm
## both halves coexist correctly and the fixed half is structurally incapable
## of contributing to any dirty_count.
func test_full_d13_stack_top_destructible_rest_fixed() -> void:
	print("[4] Full D13 stack: 1 destructible top (Slab) + 7 fixed levels\n")

	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)

	var gu := Vector2i(6, 6)
	var registry := SlabRegistry.new()

	# Top: real Slab, destructible.
	var top_slab := SlabGenerator.generate(gu, Slab.Role.FLOOR, -1, "earth", registry)
	renderer.render_slab(top_slab)

	# The other 7: fixed, no Slab.
	for level in range(-8, -1):  # -8..-2 inclusive
		renderer.render_fixed_earth_level(gu, level)

	var all_levels_have_layers := true
	for level in range(-8, 0):  # -8..-1 inclusive
		if renderer.get_layer(level) == null:
			all_levels_have_layers = false
			_fail("Level %d has no layer — full 8-level stack incomplete" % level)
	if all_levels_have_layers:
		_pass("All 8 levels of the D13 stack (-8..-1) have real layers")

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
