## D33 Part 3b — the real render-seam selftest for half-voxel DENTED marks,
## sibling to decal_seam_selftest.gd (Part 3a, full-voxel CRACKED).
## Rodar: godot --headless --script res://godot/scripts/tools/half_voxel_seam_selftest.gd
extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")

var passed: int = 0
var failed: int = 0


class _StubBakedLookup:
	var result: BakedTileLookupClass.TileLookupResult
	func resolve(_edge, _face: int, _voxel_xy: Vector2i, _level: int = 0, _column_in_run: int = -1) -> BakedTileLookupClass.TileLookupResult:
		return result


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("D33 PART 3b — HALF VOXEL SEAM SELFTEST")
	print("=".repeat(70) + "\n")

	test_plan_parser_recognizes_dented_wall_cases()
	test_flat_material_side_color_is_cached_and_nonwhite()
	test_set_voxel_cell_end_to_end_picks_the_half_voxel_composite()
	test_cracked_still_goes_through_full_voxel_path_not_half()
	test_floor_and_ceiling_dented_are_unaffected()
	test_no_baked_atom_falls_through_to_generic()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ HALF VOXEL SEAM SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ HALF VOXEL SEAM SELFTEST FAILED\n")
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


func _stub_baked_wall(renderer: VoxelRenderer, tint: Color) -> void:
	var page := _fake_baked_substrate()
	var source_id := renderer.register_baked_atlas_page(page, [Vector2i(0, 0)], tint)
	var result := BakedTileLookupClass.TileLookupResult.new(source_id, Vector2i(0, 0), 0)
	var stub := _StubBakedLookup.new()
	stub.result = result
	renderer._baked_lookup = stub
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")
	renderer._bake_config.enabled = true


func test_plan_parser_recognizes_dented_wall_cases() -> void:
	print("[1] _half_voxel_decal_plan() recognizes bullet/blast DENTED left/right\n")

	var bl := VoxelRendererClass._half_voxel_decal_plan("concrete_bullet_dented_left_0")
	if bl.get("base_material") == "concrete" and bl.get("decal_family") == "bullet" \
			and bl.get("side") == "left" and bl.get("target") == VoxelRendererClass.DecalCompositorClass.FACE_CUT_LEFT:
		_pass("bullet DENTED left -> side=left, family=bullet, FACE_CUT_LEFT")
	else:
		_fail("bullet DENTED left resolved wrong: %s" % bl)

	var br := VoxelRendererClass._half_voxel_decal_plan("metal_bullet_dented_right_2")
	if br.get("side") == "right" and br.get("target") == VoxelRendererClass.DecalCompositorClass.FACE_CUT_RIGHT and br.get("variant") == 2:
		_pass("bullet DENTED right -> side=right, FACE_CUT_RIGHT, variant=2")
	else:
		_fail("bullet DENTED right resolved wrong: %s" % br)

	var bd := VoxelRendererClass._half_voxel_decal_plan("stone_blast_dented_left_1")
	if bd.get("decal_family") == "dent" and bd.get("side") == "left":
		_pass("blast DENTED left -> raw family 'dent' (not 'blast'), side=left")
	else:
		_fail("blast DENTED left resolved wrong: %s" % bd)

	## What must NOT resolve here: CRACKED (full-voxel, Part 3a's job).
	var cracked := VoxelRendererClass._half_voxel_decal_plan("concrete_bullet_cracked_left_0")
	if cracked.is_empty():
		_pass("a CRACKED name returns {} — that's Part 3a's plan, not this one")
	else:
		_fail("CRACKED was NOT supposed to resolve here: %s" % cracked)

	## Floor/ceiling — a further increment, not this slice.
	var floor_case := VoxelRendererClass._half_voxel_decal_plan("concrete_blast_dented_top_0")
	var ceiling_case := VoxelRendererClass._half_voxel_decal_plan("concrete_blast_dented_bottom")
	if floor_case.is_empty() and ceiling_case.is_empty():
		_pass("floor (_top) and ceiling (_bottom) DENTED both return {} — not this slice's job")
	else:
		_fail("floor/ceiling resolved unexpectedly: floor=%s ceiling=%s" % [floor_case, ceiling_case])

	print("")


func test_flat_material_side_color_is_cached_and_nonwhite() -> void:
	print("[2] _flat_material_side_color() reads a real, cached, non-white tone\n")
	var renderer := _new_renderer()
	var first := renderer._flat_material_side_color("concrete")
	var second := renderer._flat_material_side_color("concrete")
	if first == second and first != Color.WHITE:
		_pass("concrete's flat side colour is stable across calls and not the WHITE default: %s" % first)
	else:
		_fail("flat side colour unstable or defaulted to WHITE: first=%s second=%s" % [first, second])
	renderer.queue_free()
	print("")


func test_set_voxel_cell_end_to_end_picks_the_half_voxel_composite() -> void:
	print("[3] The real _set_voxel_cell() seam picks the half-voxel composite for a DENTED mark\n")
	var renderer := _new_renderer()
	_stub_baked_wall(renderer, Color(0.6, 0.55, 0.5, 1.0))
	var edge_stub := Object.new()
	var grid_pos := Vector2i(4, 6)

	renderer._set_voxel_cell(grid_pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_bullet_dented_left_1", edge_stub, Vector2i.ZERO, 0)

	var layer := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL)
	var placed_source_id := layer.get_cell_source_id(grid_pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("concrete_bullet_dented_left_1")

	if placed_source_id != -1 and placed_source_id != generic_id:
		_pass("placed source_id (%d) is neither -1 nor the generic composites/ id (%d)" % [placed_source_id, generic_id])
	else:
		_fail("placed source_id (%d) fell back to generic (%d) instead of the half-voxel composite" % [placed_source_id, generic_id])

	## Idempotency, same as Part 3a's own check — a second identical call must
	## be a cache hit (same source_id/atlas_coords), not a fresh composite.
	renderer._set_voxel_cell(grid_pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_bullet_dented_left_1", edge_stub, Vector2i.ZERO, 0)
	var second_source_id := layer.get_cell_source_id(grid_pos)
	if second_source_id == placed_source_id and renderer.get_damage_composite_cache().size() == 1:
		_pass("a repeat _set_voxel_cell() call hit the cache (still 1 entry)")
	else:
		_fail("a repeat call re-composited: source_id %d -> %d, cache size %d" % [
			placed_source_id, second_source_id, renderer.get_damage_composite_cache().size()])

	edge_stub.free()  ## LEAK-GATE-01: bare Object is not refcounted — free it or it leaks to exit
	renderer.queue_free()
	print("")


func test_cracked_still_goes_through_full_voxel_path_not_half() -> void:
	print("[4] A CRACKED mark still resolves via Part 3a, never falls into the half-voxel branch\n")
	var renderer := _new_renderer()
	_stub_baked_wall(renderer, Color(0.6, 0.55, 0.5, 1.0))
	var pos := Vector2i(2, 2)

	var edge_stub := Object.new()  ## LEAK-GATE-01: named so it can be freed
	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_bullet_cracked_left_0", edge_stub, Vector2i.ZERO, 0)
	edge_stub.free()
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var generic_cracked_id: int = VoxelRendererClass.MATERIALS.find("concrete_bullet_cracked_left_0")

	if got != -1 and got != generic_cracked_id:
		_pass("CRACKED still composites (via 3a) — source_id %d, not the generic %d" % [got, generic_cracked_id])
	else:
		_fail("CRACKED fell back to generic (%d) — Part 3a regressed" % generic_cracked_id)

	renderer.queue_free()
	print("")


func test_floor_and_ceiling_dented_are_unaffected() -> void:
	print("[5] Floor (_dented_top) and ceiling (_dented_bottom) DENTED still take the pre-D33 path\n")
	var renderer := _new_renderer()
	_stub_baked_wall(renderer, Color(0.6, 0.55, 0.5, 1.0))
	var edge_stub := Object.new()

	## D34/E-SEAM-02 inverted this the same way decal_seam_selftest.gd's test
	## [5] was inverted, and for the same reason: floor_damage_material() no
	## longer substitutes "earth", so "concrete_blast_dented_top_0" is a real
	## name a real concrete floor now produces. It must composite through the
	## floor-sunk path. What this file actually tests is unaffected either way
	## — _half_voxel_decal_plan() still returns {} for a "_top_" name, so the
	## WALL branch correctly never claims it.
	var floor_pos := Vector2i(1, 1)
	renderer._set_voxel_cell(floor_pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_blast_dented_top_0", edge_stub, Vector2i.ZERO, 0)
	var floor_got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(floor_pos)
	var flat_concrete_id: int = VoxelRendererClass.MATERIALS.find("concrete")
	if floor_got != -1 and floor_got != flat_concrete_id:
		_pass("floor DENTED composites through the floor-sunk path (source_id %d), not the wall branch and not flat concrete (%d)" % [
			floor_got, flat_concrete_id])
	else:
		_fail("expected a real composited atom, got %d (flat concrete is %d)" % [
			floor_got, flat_concrete_id])

	## D33 Part 4b (2026-08-03) changed this one: _composite_generic_ceiling()
	## is purely name-driven (no edge/flat_baked gate, unlike Part 3d's baked
	## branch), so it now resolves a ceiling shape here too — even reached
	## with a non-null edge, which real gameplay never does (ROOF-BAKE-01/02c:
	## a ceiling cell always calls in with edge == null). The WALL half-voxel
	## branch this file is actually testing still correctly ignores it
	## (_half_voxel_decal_plan returns {} for "_blast_dented_bottom" — ceiling
	## is not, and never was, a bug in that branch). Not a regression.
	var ceiling_pos := Vector2i(3, 3)
	renderer._set_voxel_cell(ceiling_pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_blast_dented_bottom", edge_stub, Vector2i.ZERO, 0)
	var ceiling_got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(ceiling_pos)
	var ceiling_generic_id: int = VoxelRendererClass.MATERIALS.find("concrete_blast_dented_bottom")
	if ceiling_got != -1 and ceiling_got != ceiling_generic_id:
		_pass("ceiling DENTED resolves via Part 4b's generic ceiling compositor (source_id %d), not the wall branch and not the untouched generic id (%d)" % [ceiling_got, ceiling_generic_id])
	else:
		_fail("ceiling DENTED resolved to %d, expected the generic ceiling compositor to catch it (composites/ id is %d)" % [ceiling_got, ceiling_generic_id])

	edge_stub.free()  ## LEAK-GATE-01: bare Object is not refcounted — free it or it leaks to exit
	renderer.queue_free()
	print("")


func test_no_baked_atom_falls_through_to_generic() -> void:
	print("[6] A DENTED mark with no baked atom now falls through to D33 Part 4b's generic vector compositor, not all the way to composites/\n")
	## D33 Part 4b (2026-08-03) changed what "falls through" means here: a
	## no-baked-atom miss used to reach only the last-resort composites/-backed
	## MATERIALS.find() id; now _composite_generic_half_voxel() (purely
	## string-driven, no baked dependency) resolves it first, onto the flat
	## atom. Not a regression — see PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md
	## §5 Part 4b.
	var renderer := _new_renderer()
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")
	renderer._bake_config.enabled = true
	var miss_stub := _StubBakedLookup.new()
	miss_stub.result = BakedTileLookupClass.TileLookupResult.new(-1, Vector2i.ZERO, 0)
	renderer._baked_lookup = miss_stub

	var pos := Vector2i(9, 1)
	var edge_stub := Object.new()  ## LEAK-GATE-01: named so it can be freed
	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "wood_bullet_dented_right_0", edge_stub, Vector2i.ZERO, 0)
	edge_stub.free()
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("wood_bullet_dented_right_0")
	if got != -1 and got != generic_id:
		_pass("no baked atom -> resolves via the generic vector compositor (source_id %d), not the composites/ id (%d)" % [got, generic_id])
	else:
		_fail("expected the generic vector compositor to resolve this, got %d (composites/ id is %d)" % [got, generic_id])

	renderer.queue_free()
	print("")
