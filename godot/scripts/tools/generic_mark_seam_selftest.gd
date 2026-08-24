## D33 Part 4b — the real render-seam selftest for the generic/vector-mark
## fallback compositor, sibling to decal_seam_selftest.gd (3a),
## half_voxel_seam_selftest.gd (3b), floor_sunk_seam_selftest.gd (3c) and
## ceiling_carve_seam_selftest.gd (3d). Those four all stub a REAL baked atom
## in; this suite deliberately runs with BakeConfig OFF (the release canon —
## see PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 4's own risk note) so
## every one of Part 3's branches misses by construction, proving the NEW
## fallback catches every shape instead of reaching the last-resort
## composites/-backed MATERIALS.find().
## Rodar: godot --headless --script res://godot/scripts/tools/generic_mark_seam_selftest.gd
extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("D33 PART 4b — GENERIC MARK SEAM SELFTEST (BakeConfig OFF)")
	print("=".repeat(70) + "\n")

	test_plan_parser_recognizes_old_flat_names()
	test_flat_mark_resolves_with_bake_off()
	test_flat_mark_dented_has_a_true_alpha_cut_cracked_does_not()
	test_full_voxel_cracked_resolves_with_bake_off()
	test_half_voxel_wall_resolves_with_bake_off()
	test_half_voxel_variant_threading_is_not_collapsed()
	test_floor_sunk_resolves_with_bake_off()
	test_ceiling_resolves_with_bake_off_no_decal_needed()
	test_composite_is_idempotent()
	test_non_impact_material_is_unaffected()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ GENERIC MARK SEAM SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ GENERIC MARK SEAM SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func _new_renderer_bake_off() -> VoxelRenderer:
	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	renderer._ensure_voxel_layers(1)   ## LEVEL-RENUMBER: the ground wall level, now GeometryCoords.PLAYABLE_LEVEL
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")
	renderer._bake_config.enabled = false
	return renderer


func test_plan_parser_recognizes_old_flat_names() -> void:
	print("[1] _generic_flat_mark_plan() recognizes the OLD non-suffixed names, exact-match only\n")

	var dented := VoxelRendererClass._generic_flat_mark_plan("concrete_dented")
	if dented.get("base_material") == "concrete" and dented.get("mark_family") == "bullet" and dented.get("dented") == true:
		_pass("concrete_dented -> bullet, dented=true")
	else:
		_fail("concrete_dented resolved wrong: %s" % dented)

	var cracked := VoxelRendererClass._generic_flat_mark_plan("stone_cracked")
	if cracked.get("base_material") == "stone" and cracked.get("mark_family") == "bullet" and cracked.get("dented") == false:
		_pass("stone_cracked -> bullet, dented=false")
	else:
		_fail("stone_cracked resolved wrong: %s" % cracked)

	var blast_dented := VoxelRendererClass._generic_flat_mark_plan("wood_blast_dented")
	if blast_dented.get("base_material") == "wood" and blast_dented.get("mark_family") == "blast" and blast_dented.get("dented") == true:
		_pass("wood_blast_dented -> blast, dented=true")
	else:
		_fail("wood_blast_dented resolved wrong: %s" % blast_dented)

	var blast_cracked := VoxelRendererClass._generic_flat_mark_plan("metal_blast_cracked")
	if blast_cracked.get("base_material") == "metal" and blast_cracked.get("mark_family") == "blast" and blast_cracked.get("dented") == false:
		_pass("metal_blast_cracked -> blast, dented=false")
	else:
		_fail("metal_blast_cracked resolved wrong: %s" % blast_cracked)

	## Side-suffixed decal-family names are a DIFFERENT plan's job (exact
	## match only — "_blast_dented" must not accidentally prefix-match
	## "_blast_dented_left_0").
	var side_suffixed := VoxelRendererClass._generic_flat_mark_plan("concrete_bullet_dented_left_0")
	if side_suffixed.is_empty():
		_pass("a side-suffixed decal-family name returns {} — that's _half_voxel_decal_plan's job")
	else:
		_fail("side-suffixed name was NOT supposed to resolve here: %s" % side_suffixed)

	var clean := VoxelRendererClass._generic_flat_mark_plan("concrete")
	if clean.is_empty():
		_pass("a clean material name returns {}")
	else:
		_fail("clean material resolved unexpectedly: %s" % clean)

	print("")


func test_flat_mark_resolves_with_bake_off() -> void:
	print("[2] A full-voxel non-suffixed DENTED mark resolves via the generic compositor with BakeConfig OFF\n")
	var renderer := _new_renderer_bake_off()
	var pos := Vector2i(1, 1)

	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_dented", null, Vector2i.ZERO, 0)
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("concrete_dented")
	if got != -1 and got != generic_id:
		_pass("resolved via the generic vector compositor (source_id %d), not the composites/ id (%d)" % [got, generic_id])
	else:
		_fail("expected the generic compositor to resolve this, got %d (composites/ id is %d)" % [got, generic_id])

	renderer.queue_free()
	print("")


func test_flat_mark_dented_has_a_true_alpha_cut_cracked_does_not() -> void:
	print("[3] The full-voxel DENTED mark carries a true alpha=0 hole at its centre; CRACKED does not\n")
	## Director constraint (2026-08-03): only DENTED-with-no-known-side needs
	## the true cut (nothing else conveys "material is gone" for a full
	## voxel); CRACKED is ink-only. Verified against real composited pixels,
	## not just "it resolved to some id" — a wrong PNG (e.g. cracked reused
	## for dented) would still pass every id-level check in this file.
	var renderer := _new_renderer_bake_off()

	renderer._set_voxel_cell(Vector2i(2, 2), GeometryCoords.PLAYABLE_LEVEL, "concrete_dented", null, Vector2i.ZERO, 0)
	var dented_entry := renderer.get_damage_composite_cache().resolve("2,2,%d,concrete_dented" % GeometryCoords.PLAYABLE_LEVEL)
	var dented_page := renderer.get_damage_composite_cache().get_page_image(0)
	var dented_origin: Vector2i = dented_entry["atlas_coords"] * Vector2i(32, 36)
	## Top-face centre (16, 8) — _MARK_CENTER in generate_voxel.py / the
	## authoring canvas centre projected through FACE_TOP.
	var dented_center := dented_page.get_pixel(dented_origin.x + 16, dented_origin.y + 8)

	renderer._set_voxel_cell(Vector2i(3, 3), GeometryCoords.PLAYABLE_LEVEL, "concrete_cracked", null, Vector2i.ZERO, 0)
	var cracked_entry := renderer.get_damage_composite_cache().resolve("3,3,%d,concrete_cracked" % GeometryCoords.PLAYABLE_LEVEL)
	var cracked_page := renderer.get_damage_composite_cache().get_page_image(0)
	var cracked_origin: Vector2i = cracked_entry["atlas_coords"] * Vector2i(32, 36)
	var cracked_center := cracked_page.get_pixel(cracked_origin.x + 16, cracked_origin.y + 8)

	if dented_center.a < 0.05:
		_pass("DENTED centre pixel is transparent (a=%.3f) — the true alpha-cut hole" % dented_center.a)
	else:
		_fail("DENTED centre pixel is NOT transparent (a=%.3f) — missing the alpha-cut hole" % dented_center.a)

	if cracked_center.a > 0.5:
		_pass("CRACKED centre pixel is opaque (a=%.3f) — ink only, no cut" % cracked_center.a)
	else:
		_fail("CRACKED centre pixel is unexpectedly transparent (a=%.3f)" % cracked_center.a)

	renderer.queue_free()
	print("")


func test_full_voxel_cracked_resolves_with_bake_off() -> void:
	print("[4] Decal-family full-voxel CRACKED shapes (bullet_cracked_left, blast_cracked_all) resolve via the generic compositor with BakeConfig OFF\n")
	## Real gap found via a real bake-OFF capture on PLAYGROUND (not just this
	## suite): _full_voxel_decal_plan()'s CRACKED shapes were not reused by
	## ANY of the first four generic branches (_generic_flat_mark_plan is
	## exact-match on the OLD non-suffixed names only; the other three don't
	## recognize "_cracked" at all), so a real "concrete_blast_cracked_all_0"
	## resolved to source_id -1 mid-render, falling all the way through to
	## composites/ — exactly what Part 4c is supposed to make unreachable.
	## _composite_generic_full_voxel_cracked() closes that gap.
	var renderer := _new_renderer_bake_off()

	renderer._set_voxel_cell(Vector2i(10, 10), GeometryCoords.PLAYABLE_LEVEL, "concrete_bullet_cracked_left_0", null, Vector2i.ZERO, 0)
	var bullet_got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(Vector2i(10, 10))
	var bullet_generic_id: int = VoxelRendererClass.MATERIALS.find("concrete_bullet_cracked_left_0")
	if bullet_got != -1 and bullet_got != bullet_generic_id:
		_pass("bullet_cracked_left resolved via the generic compositor (source_id %d), not the composites/ id (%d)" % [bullet_got, bullet_generic_id])
	else:
		_fail("bullet_cracked_left resolved to %d, expected the generic compositor (composites/ id is %d)" % [bullet_got, bullet_generic_id])

	renderer._set_voxel_cell(Vector2i(11, 11), GeometryCoords.PLAYABLE_LEVEL, "concrete_blast_cracked_all_1", null, Vector2i.ZERO, 0)
	var blast_got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(Vector2i(11, 11))
	var blast_generic_id: int = VoxelRendererClass.MATERIALS.find("concrete_blast_cracked_all_1")
	if blast_got != -1 and blast_got != blast_generic_id:
		_pass("blast_cracked_all resolved via the generic compositor (source_id %d), not the composites/ id (%d)" % [blast_got, blast_generic_id])
	else:
		_fail("blast_cracked_all resolved to %d, expected the generic compositor (composites/ id is %d)" % [blast_got, blast_generic_id])

	renderer.queue_free()
	print("")


func test_half_voxel_wall_resolves_with_bake_off() -> void:
	print("[5] A half-voxel wall DENTED mark (bullet, LEFT) resolves via the generic compositor with BakeConfig OFF\n")
	var renderer := _new_renderer_bake_off()
	var pos := Vector2i(4, 4)

	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_bullet_dented_left_0", null, Vector2i.ZERO, 0)
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("concrete_bullet_dented_left_0")
	if got != -1 and got != generic_id:
		_pass("resolved via the generic half-voxel compositor (source_id %d), not the composites/ id (%d)" % [got, generic_id])
	else:
		_fail("expected the generic half-voxel compositor to resolve this, got %d (composites/ id is %d)" % [got, generic_id])

	renderer.queue_free()
	print("")


func test_half_voxel_variant_threading_is_not_collapsed() -> void:
	print("[6] Regression guard: three DENTED variants place three distinct tiles, not one collapsed onto grid_pos\n")
	## The real bug this guards against (found while building this suite):
	## _composite_generic_half_voxel()/_composite_generic_floor_sunk()
	## initially picked a variant from a grid_pos hash instead of the plan's
	## own already-parsed variant, so three DIFFERENT variant NAMES at the
	## SAME cell collapsed onto the SAME generic decal. Fixed to reuse
	## plan["variant"]; this test would have caught it.
	var renderer := _new_renderer_bake_off()
	var pos := Vector2i(5, 5)
	var tiles: Dictionary = {}
	for variant in range(3):
		renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_bullet_dented_left_%d" % variant, null, Vector2i.ZERO, 0)
		var layer := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL)
		var tile := Vector3i(layer.get_cell_source_id(pos), layer.get_cell_atlas_coords(pos).x, layer.get_cell_atlas_coords(pos).y)
		tiles[tile] = true

	if tiles.size() == 3:
		_pass("three variants at the same cell placed 3 distinct (source_id, atlas_coords) tiles")
	else:
		_fail("three variants collapsed onto %d distinct tile(s) — the variant-threading bug is back" % tiles.size())

	renderer.queue_free()
	print("")


func test_floor_sunk_resolves_with_bake_off() -> void:
	print("[7] A floor-sunk DENTED mark resolves via the generic compositor with BakeConfig OFF\n")
	var renderer := _new_renderer_bake_off()
	var pos := Vector2i(6, 6)

	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "earth_blast_dented_top_2", null, Vector2i.ZERO, 0, true, "grass")
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("earth_blast_dented_top_2")
	if got != -1 and got != generic_id:
		_pass("resolved via the generic floor compositor (source_id %d), not the composites/ id (%d)" % [got, generic_id])
	else:
		_fail("expected the generic floor compositor to resolve this, got %d (composites/ id is %d)" % [got, generic_id])

	renderer.queue_free()
	print("")


func test_ceiling_resolves_with_bake_off_no_decal_needed() -> void:
	print("[8] A ceiling DENTED mark resolves via the generic compositor with BakeConfig OFF — no decal asset involved\n")
	var renderer := _new_renderer_bake_off()
	var pos := Vector2i(7, 7)

	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "stone_blast_dented_bottom", null, Vector2i.ZERO, 0, true)
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("stone_blast_dented_bottom")
	if got != -1 and got != generic_id:
		_pass("resolved via the generic ceiling compositor (source_id %d), not the composites/ id (%d)" % [got, generic_id])
	else:
		_fail("expected the generic ceiling compositor to resolve this, got %d (composites/ id is %d)" % [got, generic_id])

	renderer.queue_free()
	print("")


func test_composite_is_idempotent() -> void:
	print("[9] A repeat _set_voxel_cell() call for the same cell hits the cache, not a re-composite\n")
	var renderer := _new_renderer_bake_off()
	var pos := Vector2i(8, 8)

	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_dented", null, Vector2i.ZERO, 0)
	var first_id := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_dented", null, Vector2i.ZERO, 0)
	var second_id := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)

	if first_id == second_id and renderer.get_damage_composite_cache().size() == 1:
		_pass("repeat call hit the cache (still 1 entry, same source_id %d)" % first_id)
	else:
		_fail("repeat call re-composited instead of hitting the cache")

	renderer.queue_free()
	print("")


func test_non_impact_material_is_unaffected() -> void:
	print("[10] A clean (non-impact-mark) material name never enters this path\n")
	var renderer := _new_renderer_bake_off()
	var pos := Vector2i(9, 9)

	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "concrete", null, Vector2i.ZERO, 0)
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var expected: int = VoxelRendererClass.MATERIALS.find("concrete")
	if got == expected:
		_pass("a clean material name resolves straight to its own MATERIALS id (%d), untouched" % expected)
	else:
		_fail("clean material resolved to %d, expected %d" % [got, expected])

	renderer.queue_free()
	print("")
