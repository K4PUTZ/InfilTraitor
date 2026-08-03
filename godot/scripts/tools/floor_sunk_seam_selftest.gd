## D33 Part 3c — the real render-seam selftest for floor-sunk DENTED marks,
## sibling to decal_seam_selftest.gd (3a) and half_voxel_seam_selftest.gd (3b).
## Rodar: godot --headless --script res://godot/scripts/tools/floor_sunk_seam_selftest.gd
extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")

var passed: int = 0
var failed: int = 0


## Implements BOTH resolve() and resolve_flat() — floor damage always calls
## resolve_flat(zone_material, voxel_xy), never resolve(), but the stub
## covers both so a wiring mistake that calls the wrong one still gets a
## real (if wrong) TileLookupResult back instead of a null-crash masking it.
class _StubBakedLookup:
	var result: BakedTileLookupClass.TileLookupResult
	var last_flat_material_id: String = ""
	func resolve(_edge, _face: int, _voxel_xy: Vector2i, _level: int = 0, _column_in_run: int = -1) -> BakedTileLookupClass.TileLookupResult:
		return result
	func resolve_flat(material_id: String, _local_pos: Vector2i) -> BakedTileLookupClass.TileLookupResult:
		last_flat_material_id = material_id
		return result


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("D33 PART 3c — FLOOR SUNK SEAM SELFTEST")
	print("=".repeat(70) + "\n")

	test_plan_parser_recognizes_floor_sunk_case()
	test_set_voxel_cell_end_to_end_picks_the_floor_composite()
	test_resolve_flat_receives_the_real_zone_material_not_the_pseudo_name()
	test_empty_zone_material_falls_through_to_generic()
	test_no_baked_atom_falls_through_to_generic()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ FLOOR SUNK SEAM SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ FLOOR SUNK SEAM SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func _new_renderer() -> VoxelRenderer:
	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	renderer._ensure_voxel_layers(1)
	return renderer


func _fake_baked_substrate() -> Image:
	var img := Image.create(32, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(36):
		for x in range(32):
			var inside: bool
			if y < 16:
				var dx: float = abs(x - 16) / 16.0
				var dy: float = abs(y - 8) / 8.0
				inside = (dx + dy) <= 1.0
			else:
				inside = true
			if inside:
				img.set_pixel(x, y, Color(0.5, 0.5, 0.5, 1.0))
	return img


func _stub_baked_floor(renderer: VoxelRenderer, tint: Color) -> _StubBakedLookup:
	var page := _fake_baked_substrate()
	var source_id := renderer.register_baked_atlas_page(page, [Vector2i(0, 0)], tint)
	var result := BakedTileLookupClass.TileLookupResult.new(source_id, Vector2i(0, 0), 0)
	var stub := _StubBakedLookup.new()
	stub.result = result
	renderer._baked_lookup = stub
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")
	renderer._bake_config.enabled = true
	return stub


func test_plan_parser_recognizes_floor_sunk_case() -> void:
	print("[1] _floor_sunk_decal_plan() recognizes earth_blast_dented_top_N only\n")

	var floor_plan := VoxelRendererClass._floor_sunk_decal_plan("earth_blast_dented_top_1")
	if floor_plan.get("decal_family") == "dent" and floor_plan.get("variant") == 1:
		_pass("earth_blast_dented_top_1 -> family=dent, variant=1")
	else:
		_fail("floor sunk plan resolved wrong: %s" % floor_plan)

	var ceiling_case := VoxelRendererClass._floor_sunk_decal_plan("earth_blast_dented_bottom")
	if ceiling_case.is_empty():
		_pass("ceiling (_dented_bottom) returns {} — a further increment, not this one")
	else:
		_fail("ceiling was NOT supposed to resolve here: %s" % ceiling_case)

	var wall_case := VoxelRendererClass._floor_sunk_decal_plan("concrete_blast_dented_left_0")
	if wall_case.is_empty():
		_pass("a wall DENTED name returns {} — that's Part 3b's plan")
	else:
		_fail("wall DENTED was NOT supposed to resolve here: %s" % wall_case)

	print("")


func test_set_voxel_cell_end_to_end_picks_the_floor_composite() -> void:
	print("[2] The real _set_voxel_cell() seam picks the floor composite when zone_material is given\n")
	var renderer := _new_renderer()
	_stub_baked_floor(renderer, Color(0.5, 0.6, 0.4, 1.0))
	var grid_pos := Vector2i(6, 2)

	renderer._set_voxel_cell(grid_pos, 0, "earth_blast_dented_top_0", null, Vector2i.ZERO, 0, true, "ground_grass")

	var layer := renderer.get_layer(0)
	var placed_source_id := layer.get_cell_source_id(grid_pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("earth_blast_dented_top_0")

	if placed_source_id != -1 and placed_source_id != generic_id:
		_pass("placed source_id (%d) is neither -1 nor the generic composites/ id (%d)" % [placed_source_id, generic_id])
	else:
		_fail("placed source_id (%d) fell back to generic (%d) instead of the floor composite" % [placed_source_id, generic_id])

	## Idempotency, same discipline as 3a/3b.
	renderer._set_voxel_cell(grid_pos, 0, "earth_blast_dented_top_0", null, Vector2i.ZERO, 0, true, "ground_grass")
	if layer.get_cell_source_id(grid_pos) == placed_source_id and renderer.get_damage_composite_cache().size() == 1:
		_pass("a repeat call hit the cache (still 1 entry)")
	else:
		_fail("a repeat call re-composited instead of hitting the cache")

	renderer.queue_free()
	print("")


func test_resolve_flat_receives_the_real_zone_material_not_the_pseudo_name() -> void:
	print("[3] resolve_flat() is called with \"ground_grass\", never \"earth_blast_dented_top_0\"\n")
	var renderer := _new_renderer()
	var stub := _stub_baked_floor(renderer, Color.WHITE)

	renderer._set_voxel_cell(Vector2i(1, 1), 0, "earth_blast_dented_top_2", null, Vector2i.ZERO, 0, true, "ground_concrete")

	if stub.last_flat_material_id == "ground_concrete":
		_pass("resolve_flat() received the real zone material (\"ground_concrete\")")
	else:
		_fail("resolve_flat() received %s instead of the real zone material" % stub.last_flat_material_id)

	renderer.queue_free()
	print("")


func test_empty_zone_material_falls_through_to_generic() -> void:
	print("[4] zone_material=\"\" (unzoned/plain earth) still falls through to generic, no crash\n")
	var renderer := _new_renderer()
	_stub_baked_floor(renderer, Color.WHITE)
	var pos := Vector2i(3, 3)

	## No zone_material passed (default "") — matches a plain, never-baked
	## earth floor, which has no facade to preserve in the first place.
	renderer._set_voxel_cell(pos, 0, "earth_blast_dented_top_0", null, Vector2i.ZERO, 0, true)
	var got := renderer.get_layer(0).get_cell_source_id(pos)
	var expected: int = VoxelRendererClass.MATERIALS.find("earth_blast_dented_top_0")
	if got == expected:
		_pass("no zone_material -> generic composites/ id (%d), unchanged from before D33" % expected)
	else:
		_fail("expected fallback to generic id %d, got %d" % [expected, got])

	renderer.queue_free()
	print("")


func test_no_baked_atom_falls_through_to_generic() -> void:
	print("[5] A floor DENTED mark with no baked zone available still falls through cleanly\n")
	var renderer := _new_renderer()
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")
	renderer._bake_config.enabled = true
	var miss_stub := _StubBakedLookup.new()
	miss_stub.result = BakedTileLookupClass.TileLookupResult.new(-1, Vector2i.ZERO, 0)
	renderer._baked_lookup = miss_stub

	var pos := Vector2i(8, 8)
	renderer._set_voxel_cell(pos, 0, "earth_blast_dented_top_1", null, Vector2i.ZERO, 0, true, "ground_sand")
	var got := renderer.get_layer(0).get_cell_source_id(pos)
	var expected: int = VoxelRendererClass.MATERIALS.find("earth_blast_dented_top_1")
	if got == expected:
		_pass("no baked zone -> falls through to the generic composites/ id (%d), no crash" % expected)
	else:
		_fail("expected fallback to generic id %d, got %d" % [expected, got])

	renderer.queue_free()
	print("")
