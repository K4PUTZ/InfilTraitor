## D33 Part 3d — the real render-seam selftest for ceiling DENTED marks,
## sibling to decal_seam_selftest.gd (3a), half_voxel_seam_selftest.gd (3b),
## and floor_sunk_seam_selftest.gd (3c). This is the last one — Part 3 is
## complete after this suite passes.
## Rodar: godot --headless --script res://godot/scripts/tools/ceiling_carve_seam_selftest.gd
extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")

var passed: int = 0
var failed: int = 0


class _StubBakedLookup:
	var result: BakedTileLookupClass.TileLookupResult
	var last_flat_material_id: String = ""
	func resolve(_edge, _face: int, _voxel_xy: Vector2i, _level: int = 0, _column_in_run: int = -1) -> BakedTileLookupClass.TileLookupResult:
		return result
	func resolve_flat(material_id: String, _local_pos: Vector2i, _surface_class: int = 0) -> BakedTileLookupClass.TileLookupResult:
		last_flat_material_id = material_id
		return result


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("D33 PART 3d — CEILING CARVE SEAM SELFTEST")
	print("=".repeat(70) + "\n")

	test_plan_parser_recognizes_ceiling_case()
	test_set_voxel_cell_end_to_end_picks_the_ceiling_composite()
	test_resolve_flat_receives_the_real_material_directly()
	test_floor_still_resolves_when_both_could_apply()
	test_no_baked_atom_falls_through_to_generic()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ CEILING CARVE SEAM SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ CEILING CARVE SEAM SELFTEST FAILED\n")
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
	renderer._ensure_voxel_layers(1)   ## LEVEL-RENUMBER: the ground wall level, now GeometryCoords.PLAYABLE_LEVEL
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


func _stub_baked_ceiling(renderer: VoxelRenderer, tint: Color) -> _StubBakedLookup:
	var page := _fake_baked_substrate()
	var source_id := renderer.register_baked_atlas_page(page, [Vector2i(0, 0)], tint)
	var result := BakedTileLookupClass.TileLookupResult.new(source_id, Vector2i(0, 0), 0)
	var stub := _StubBakedLookup.new()
	stub.result = result
	renderer._baked_lookup = stub
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")
	renderer._bake_config.enabled = true
	return stub


func test_plan_parser_recognizes_ceiling_case() -> void:
	print("[1] _ceiling_carve_plan() recognizes <material>_blast_dented_bottom only\n")

	var concrete := VoxelRendererClass._ceiling_carve_plan("concrete_blast_dented_bottom")
	if concrete.get("base_material") == "concrete":
		_pass("concrete_blast_dented_bottom -> base_material=concrete")
	else:
		_fail("resolved wrong: %s" % concrete)

	var floor_case := VoxelRendererClass._ceiling_carve_plan("earth_blast_dented_top_0")
	if floor_case.is_empty():
		_pass("floor (_top_N) returns {} — that's Part 3c's plan")
	else:
		_fail("floor was NOT supposed to resolve here: %s" % floor_case)

	var wall_case := VoxelRendererClass._ceiling_carve_plan("concrete_bullet_dented_left_0")
	if wall_case.is_empty():
		_pass("wall DENTED returns {} — that's Part 3b's plan")
	else:
		_fail("wall DENTED was NOT supposed to resolve here: %s" % wall_case)

	var not_impact := VoxelRendererClass._ceiling_carve_plan("concrete")
	if not_impact.is_empty():
		_pass("a clean material name returns {}")
	else:
		_fail("clean material resolved unexpectedly: %s" % not_impact)

	print("")


func test_set_voxel_cell_end_to_end_picks_the_ceiling_composite() -> void:
	print("[2] The real _set_voxel_cell() seam picks the ceiling composite for a _dented_bottom mark\n")
	var renderer := _new_renderer()
	_stub_baked_ceiling(renderer, Color(0.55, 0.55, 0.6, 1.0))
	var grid_pos := Vector2i(5, 5)

	renderer._set_voxel_cell(grid_pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_blast_dented_bottom", null, Vector2i.ZERO, 0, true)

	var layer := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL)
	var placed_source_id := layer.get_cell_source_id(grid_pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("concrete_blast_dented_bottom")

	if placed_source_id != -1 and placed_source_id != generic_id:
		_pass("placed source_id (%d) is neither -1 nor the generic composites/ id (%d)" % [placed_source_id, generic_id])
	else:
		_fail("placed source_id (%d) fell back to generic (%d) instead of the ceiling composite" % [placed_source_id, generic_id])

	## Idempotency, same discipline as 3a/3b/3c.
	renderer._set_voxel_cell(grid_pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_blast_dented_bottom", null, Vector2i.ZERO, 0, true)
	if layer.get_cell_source_id(grid_pos) == placed_source_id and renderer.get_damage_composite_cache().size() == 1:
		_pass("a repeat call hit the cache (still 1 entry)")
	else:
		_fail("a repeat call re-composited instead of hitting the cache")

	renderer.queue_free()
	print("")


func test_resolve_flat_receives_the_real_material_directly() -> void:
	print("[3] resolve_flat() is called with \"wood\", extracted straight from the name (no zone_material needed)\n")
	var renderer := _new_renderer()
	var stub := _stub_baked_ceiling(renderer, Color.WHITE)

	## Deliberately NOT passing zone_material — ceiling recovers the real
	## material from the pseudo-name itself, unlike floor.
	renderer._set_voxel_cell(Vector2i(1, 1), GeometryCoords.PLAYABLE_LEVEL, "wood_blast_dented_bottom", null, Vector2i.ZERO, 0, true)

	if stub.last_flat_material_id == "wood":
		_pass("resolve_flat() received \"wood\", extracted from the name — no zone_material threading needed")
	else:
		_fail("resolve_flat() received %s instead of \"wood\"" % stub.last_flat_material_id)

	renderer.queue_free()
	print("")


func test_floor_still_resolves_when_both_could_apply() -> void:
	print("[4] Ceiling and floor plans never collide — a floor mark still resolves through 3c\n")
	var renderer := _new_renderer()
	_stub_baked_ceiling(renderer, Color(0.5, 0.6, 0.4, 1.0))
	var pos := Vector2i(2, 2)

	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "earth_blast_dented_top_0", null, Vector2i.ZERO, 0, true, "grass")
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("earth_blast_dented_top_0")
	if got != -1 and got != generic_id:
		_pass("a floor mark still composites via 3c (source_id %d) even with the ceiling branch tried first" % got)
	else:
		_fail("a floor mark fell back to generic (%d) — 3c may have regressed" % generic_id)

	renderer.queue_free()
	print("")


func test_no_baked_atom_falls_through_to_generic() -> void:
	print("[5] A ceiling DENTED mark with no baked atom now falls through to D33 Part 4b's generic vector compositor, not all the way to composites/\n")
	## D33 Part 4b (2026-08-03) changed what "falls through" means here: a
	## no-baked-atom miss used to reach only the last-resort composites/-backed
	## MATERIALS.find() id; now _composite_generic_ceiling() (purely
	## string-driven, no baked dependency) resolves it first, onto the flat
	## atom. Not a regression — see half_voxel_seam_selftest.gd's identical
	## fix and PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 4b.
	var renderer := _new_renderer()
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")
	renderer._bake_config.enabled = true
	var miss_stub := _StubBakedLookup.new()
	miss_stub.result = BakedTileLookupClass.TileLookupResult.new(-1, Vector2i.ZERO, 0)
	renderer._baked_lookup = miss_stub

	var pos := Vector2i(7, 7)
	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "stone_blast_dented_bottom", null, Vector2i.ZERO, 0, true)
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("stone_blast_dented_bottom")
	if got != -1 and got != generic_id:
		_pass("no baked atom -> resolves via the generic vector compositor (source_id %d), not the composites/ id (%d)" % [got, generic_id])
	else:
		_fail("expected the generic vector compositor to resolve this, got %d (composites/ id is %d)" % [got, generic_id])

	renderer.queue_free()
	print("")
