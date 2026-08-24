## D33 Part 3a — the real render-seam selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/decal_seam_selftest.gd
##
## Parts 1/2 proved the cache and the compositor in isolation. This suite
## proves the SEAM (PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md §5 Part 3a):
## VoxelRenderer._full_voxel_decal_plan() (name parsing) and
## _composite_full_voxel_decal() (substrate read + tint + compose + cache),
## wired into the real _set_voxel_cell(), against a REAL registered baked
## page and the REAL decal_bullet_concrete_0.png art (not a synthetic
## placeholder — Part 3a's whole point is compositing onto what the wall
## around it actually shows). _baked_lookup is stubbed (a small duck-typed
## fake, not the real BakedTileLookup) so this test doesn't have to stand up
## a full EdgeRegistry/facade bake just to control what "the wall's baked
## atom" resolves to — that machinery is what the bake selftests already
## cover; this one owns what D33 added on top of it.
extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")

var passed: int = 0
var failed: int = 0


## Duck-typed stand-in for BakedTileLookup: resolve() always returns whatever
## `result` was set to, regardless of the arguments — this suite controls
## the wall's "substrate" directly rather than deriving it from a real map.
class _StubBakedLookup:
	var result: BakedTileLookupClass.TileLookupResult
	func resolve(_edge, _face: int, _voxel_xy: Vector2i, _level: int = 0, _column_in_run: int = -1) -> BakedTileLookupClass.TileLookupResult:
		return result


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("D33 PART 3a — DECAL SEAM SELFTEST")
	print("=".repeat(70) + "\n")

	test_plan_parser_recognizes_full_voxel_cases()
	test_composite_applies_tint_and_pastes_the_real_decal()
	test_composite_is_idempotent()
	test_set_voxel_cell_end_to_end_picks_the_composite()
	test_dented_and_non_impact_names_are_unaffected()
	test_no_baked_atom_falls_through_to_generic()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ DECAL SEAM SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ DECAL SEAM SELFTEST FAILED\n")
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


## A 32x36 substrate matching generate_voxel_atom()'s own silhouette (opaque
## cube, transparent corners) so B3 has real geometry to clamp against, filled
## with a flat mid-gray — standing in for a grayscale baked facade page,
## exactly what BakeCompositor's TEXTURE_ONLY/MULTIPLY pages actually store.
func _fake_baked_substrate() -> Image:
	var img := Image.create(32, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	## Top diamond (y=0..15) and the two lateral faces (y=16..35) — same
	## silhouette shape _paste_decal's own clip test relies on; approximated
	## with straight fills since exact diamond edges aren't this test's
	## concern (DecalCompositor's own equality selftest already proves the
	## real geometry against the real Python silhouette).
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


## Registers `_fake_baked_substrate()` as a real page on `renderer` with a
## tinted modulate (never white — a bug that silently skipped the tint
## multiply would still pass a white-modulate test), and stubs `_baked_lookup`
## to resolve any query to that one tile. Returns the stub's fixed result.
func _stub_baked_wall(renderer: VoxelRenderer, tint: Color) -> BakedTileLookupClass.TileLookupResult:
	var page := _fake_baked_substrate()
	var source_id := renderer.register_baked_atlas_page(page, [Vector2i(0, 0)], tint)
	var result := BakedTileLookupClass.TileLookupResult.new(source_id, Vector2i(0, 0), 0)
	var stub := _StubBakedLookup.new()
	stub.result = result
	renderer._baked_lookup = stub
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")
	renderer._bake_config.enabled = true
	return result


func test_plan_parser_recognizes_full_voxel_cases() -> void:
	print("[1] _full_voxel_decal_plan() recognizes exactly the full-voxel shapes\n")

	var left := VoxelRendererClass._full_voxel_decal_plan("concrete_bullet_cracked_left_0")
	if left.get("base_material") == "concrete" and left.get("decal_family") == "bullet" \
			and left.get("variant") == 0 and left.get("targets") == [VoxelRendererClass.DecalCompositorClass.FACE_SW]:
		_pass("bullet LEFT -> FACE_SW, family=bullet, variant=0")
	else:
		_fail("bullet LEFT resolved wrong: %s" % left)

	var right := VoxelRendererClass._full_voxel_decal_plan("metal_bullet_cracked_right_2")
	if right.get("targets") == [VoxelRendererClass.DecalCompositorClass.FACE_SE_MIRRORED] and right.get("variant") == 2:
		_pass("bullet RIGHT -> FACE_SE_MIRRORED (the mirrored target, not plain FACE_SE)")
	else:
		_fail("bullet RIGHT resolved wrong: %s" % right)

	var blast := VoxelRendererClass._full_voxel_decal_plan("stone_blast_cracked_all_1")
	var expected_targets := [VoxelRendererClass.DecalCompositorClass.FACE_TOP,
		VoxelRendererClass.DecalCompositorClass.FACE_SW, VoxelRendererClass.DecalCompositorClass.FACE_SE]
	if blast.get("decal_family") == "crack" and blast.get("targets") == expected_targets:
		_pass("blast CRACKED -> all three faces, raw family 'crack' (not 'cracked')")
	else:
		_fail("blast CRACKED resolved wrong: %s" % blast)

	var dented := VoxelRendererClass._full_voxel_decal_plan("concrete_bullet_dented_left_0")
	if dented.is_empty():
		_pass("DENTED (half-voxel, Part 3b) returns {} — not this slice's job")
	else:
		_fail("DENTED was NOT supposed to resolve here: %s" % dented)

	var clean := VoxelRendererClass._full_voxel_decal_plan("concrete")
	if clean.is_empty():
		_pass("a clean base material name returns {}")
	else:
		_fail("a clean material name resolved a plan: %s" % clean)
	print("")


func test_composite_applies_tint_and_pastes_the_real_decal() -> void:
	print("[2] The composite tints the substrate correctly AND actually pastes the real decal\n")
	var renderer := _new_renderer()
	var tint := Color(0.8, 0.3, 0.3, 1.0)
	_stub_baked_wall(renderer, tint)

	var plan := VoxelRendererClass._full_voxel_decal_plan("concrete_bullet_cracked_left_0")
	## LEAK-GATE-01: named so it can be freed — a bare Object is not refcounted
	## and an inline Object.new() argument survives to exit.
	var edge_stub := Object.new()
	var entry := renderer._composite_full_voxel_decal(
		plan, "concrete_bullet_cracked_left_0", edge_stub, 0, Vector2i.ZERO, 0, Vector2i(5, 5))
	edge_stub.free()

	if entry.is_empty():
		_fail("composite returned {} — expected a real entry (decal_bullet_concrete_0.png must exist on disk)")
		print("")
		renderer.queue_free()
		return

	## Read the page Image DamageCompositeCache itself blits into
	## (get_page_image()), not TileSetAtlasSource.texture.get_image() —
	## confirmed by hand (windowed, real GPU driver) that the texture round
	## trip is correct, but ImageTexture.update() does not propagate to a
	## get_image() readback under --headless's dummy rendering driver
	## (same documented limitation as auto_screenshot.py's own "why not
	## --headless"). run_selftests.py always runs headless, so this suite
	## verifies the actual blitted pixels the cache owns, not a round trip
	## through a renderer that can't rasterize in this process anyway.
	var page: Image = renderer.get_damage_composite_cache().get_page_image(0)
	var atlas_px: Vector2i = entry["atlas_coords"] * Vector2i(32, 36)

	## Far corner of the lateral face (SE, y=34) — inside the substrate's
	## silhouette, far from FACE_SW where this decal lands, so it should show
	## the TINTED substrate untouched by the decal: 0.5 * 0.8 = 0.4, not the
	## flat 0.5 gray (would mean the tint multiply was skipped) and not some
	## other value (would mean double-tinting or a wrong channel).
	var far_px := page.get_pixel(atlas_px.x + 30, atlas_px.y + 34)
	if absf(far_px.r - 0.4) < 0.02 and absf(far_px.g - 0.15) < 0.02 and absf(far_px.b - 0.15) < 0.02:
		_pass("untouched region shows the tinted substrate (0.4, 0.15, 0.15), not flat gray or double-tinted")
	else:
		_fail("untouched region is %s, expected ~(0.40, 0.15, 0.15) from tint (0.8,0.3,0.3) x gray 0.5" % far_px)

	## FACE_SW spans roughly x=[0,16] y=[16,36] in atom space — sample its
	## centre and require it to differ from the flat tinted gray, proving a
	## real decal (not a no-op pass-through) landed there.
	var decal_px := page.get_pixel(atlas_px.x + 8, atlas_px.y + 26)
	if not decal_px.is_equal_approx(Color(0.4, 0.15, 0.15, 1.0)):
		_pass("FACE_SW centre (%s) differs from the flat tinted substrate — the real decal was pasted" % decal_px)
	else:
		_fail("FACE_SW centre is exactly the flat tinted substrate — no decal reached it")

	## B3: outside the substrate's silhouette (its own alpha was 0 there —
	## e.g. the extreme top-left corner) must stay transparent in the result.
	var corner_px := page.get_pixel(atlas_px.x, atlas_px.y)
	if is_zero_approx(corner_px.a):
		_pass("a corner outside the substrate's silhouette stayed transparent (B3)")
	else:
		_fail("a corner outside the silhouette gained alpha %.3f — B3 violated" % corner_px.a)

	renderer.queue_free()
	print("")


func test_composite_is_idempotent() -> void:
	print("[3] Calling the same composite twice is a cache hit, not a re-composite\n")
	var renderer := _new_renderer()
	_stub_baked_wall(renderer, Color(0.7, 0.7, 0.7, 1.0))
	var plan := VoxelRendererClass._full_voxel_decal_plan("concrete_blast_cracked_all_0")
	var edge_stub := Object.new()

	var first := renderer._composite_full_voxel_decal(
		plan, "concrete_blast_cracked_all_0", edge_stub, 0, Vector2i.ZERO, 0, Vector2i(2, 2))
	var cache := renderer.get_damage_composite_cache()
	var size_after_first := cache.size()
	var second := renderer._composite_full_voxel_decal(
		plan, "concrete_blast_cracked_all_0", edge_stub, 0, Vector2i.ZERO, 0, Vector2i(2, 2))

	if not first.is_empty() and first == second and cache.size() == size_after_first:
		_pass("repeat call returned the identical cached entry, cache size unchanged (%d)" % cache.size())
	else:
		_fail("repeat call did not hit the cache: first=%s second=%s size=%d->%.d" % [
			first, second, size_after_first, cache.size()])

	edge_stub.free()  ## LEAK-GATE-01: bare Object is not refcounted — free it or it leaks to exit
	renderer.queue_free()
	print("")


func test_set_voxel_cell_end_to_end_picks_the_composite() -> void:
	print("[4] The real _set_voxel_cell() seam picks the composite for a full-voxel CRACKED mark\n")
	var renderer := _new_renderer()
	_stub_baked_wall(renderer, Color(0.6, 0.6, 0.65, 1.0))
	var edge_stub := Object.new()
	var grid_pos := Vector2i(7, 3)

	renderer._set_voxel_cell(grid_pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_bullet_cracked_left_1", edge_stub, Vector2i.ZERO, 0)

	var layer := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL)
	var placed_source_id := layer.get_cell_source_id(grid_pos)
	var generic_concrete_id: int = VoxelRendererClass.MATERIALS.find("concrete_bullet_cracked_left_1")

	if placed_source_id != -1 and placed_source_id != generic_concrete_id:
		_pass("placed source_id (%d) is neither -1 nor the generic composites/ fallback id (%d)" % [
			placed_source_id, generic_concrete_id])
	else:
		_fail("placed source_id (%d) fell back to the generic path (generic id %d) instead of compositing" % [
			placed_source_id, generic_concrete_id])

	edge_stub.free()  ## LEAK-GATE-01: bare Object is not refcounted — free it or it leaks to exit
	renderer.queue_free()
	print("")


## NOTE: wall-DENTED left/right (e.g. "concrete_bullet_dented_left_1") is
## deliberately NOT the example here any more — D33 Part 3b (same session)
## wired exactly that shape through its own half-voxel composite path, so it
## no longer falls through to generic. That's Part 3b's own seam selftest's
## job to prove (half_voxel_seam_selftest.gd); this test's job is narrower:
## confirm Part 3a's full-voxel path doesn't reach into shapes NEITHER 3a nor
## 3b covers yet (floor "_dented_top", ceiling "_dented_bottom") or into
## plain clean materials.
func test_dented_and_non_impact_names_are_unaffected() -> void:
	print("[5] A material-real '_blast_dented_top' name is a REAL floor dent now (D34) and composites, instead of falling to flat concrete\n")
	## D34/E-SEAM-02 (Director, 2026-08-08) INVERTED this assertion, and the
	## test's own stated premise is what changed: it read "concrete_blast_
	## dented_top_N is not a name any real caller ever constructs — floor_
	## damage_material() always substitutes IMPACT_FLOOR_MATERIAL". That
	## substitution is gone. A concrete floor now names its dent after itself
	## and wears `decal_dent_concrete_*`, the same art its walls already use,
	## so this shape must RESOLVE rather than fall through to the last-resort
	## flat-concrete id. `earth` survives only as the fallback family for
	## materials with no decal art of their own.
	var renderer := _new_renderer()
	_stub_baked_wall(renderer, Color(0.6, 0.6, 0.65, 1.0))
	var edge_stub := Object.new()

	var floor_pos := Vector2i(1, 1)
	renderer._set_voxel_cell(floor_pos, GeometryCoords.PLAYABLE_LEVEL, "concrete_blast_dented_top_1", edge_stub, Vector2i.ZERO, 0)
	var floor_source_id := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(floor_pos)
	var flat_concrete_id: int = VoxelRendererClass.MATERIALS.find("concrete")
	if floor_source_id != -1 and floor_source_id != flat_concrete_id:
		_pass("concrete's own floor dent composites (source_id %d), not the last-resort flat concrete (%d)" % [
			floor_source_id, flat_concrete_id])
	else:
		_fail("expected a real composited atom, got %d (flat concrete is %d)" % [
			floor_source_id, flat_concrete_id])

	edge_stub.free()  ## LEAK-GATE-01: bare Object is not refcounted — free it or it leaks to exit
	renderer.queue_free()
	print("")


func test_no_baked_atom_falls_through_to_generic() -> void:
	print("[6] A CRACKED mark with no baked atom now falls through to D33 Part 4b's generic vector compositor, not all the way to composites/\n")
	## D33 Part 4b (2026-08-03) changed what "falls through" means here:
	## _composite_generic_full_voxel_cracked() (purely string-driven, no
	## baked dependency — reuses _full_voxel_decal_plan() itself) now resolves
	## it before the last-resort composites/-backed MATERIALS.find() is ever
	## reached. Found via a real bake-OFF capture on PLAYGROUND: this exact
	## shape (blast_cracked_all) was the one real gap Part 4b's first pass
	## missed — see generic_mark_seam_selftest.gd's own test [4]. Not a
	## regression — same category as ceiling/half_voxel/floor_sunk's own
	## identical fixes.
	var renderer := _new_renderer()
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")
	renderer._bake_config.enabled = true
	var miss_stub := _StubBakedLookup.new()
	miss_stub.result = BakedTileLookupClass.TileLookupResult.new(-1, Vector2i.ZERO, 0)
	renderer._baked_lookup = miss_stub

	var pos := Vector2i(9, 9)
	var edge_stub := Object.new()  ## LEAK-GATE-01: named so it can be freed
	renderer._set_voxel_cell(pos, GeometryCoords.PLAYABLE_LEVEL, "stone_blast_cracked_all_0", edge_stub, Vector2i.ZERO, 0)
	edge_stub.free()
	var got := renderer.get_layer(GeometryCoords.PLAYABLE_LEVEL).get_cell_source_id(pos)
	var generic_id: int = VoxelRendererClass.MATERIALS.find("stone_blast_cracked_all_0")
	if got != -1 and got != generic_id:
		_pass("no baked atom -> resolves via the generic vector compositor (source_id %d), not the composites/ id (%d)" % [got, generic_id])
	else:
		_fail("expected the generic vector compositor to resolve this, got %d (composites/ id is %d)" % [got, generic_id])

	renderer.queue_free()
	print("")
