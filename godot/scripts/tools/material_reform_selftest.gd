## E-MAT — material reform selftest (EXPLOSION_REBUILD_MASTER_PLAN Task 1a,
## D19/D20/D21, 2026-08-06).
## Rodar: godot --headless --script res://godot/scripts/tools/material_reform_selftest.gd
##
## Proves the two halves of the reform independently:
##   1. BEHAVIOR is unified — one row per material (MaterialRegistry +
##      MaterialResistanceTable), the old duplicate `ground_concrete` row is
##      gone, not merely shadowed.
##   2. RENDERING follows the MATERIAL, not the surface — D34/E-SEAM-01
##      (Director, 2026-08-08) **reversed D20's original answer here.** D20
##      sent every floor down the photographic `slab_` path, so a concrete
##      floor and a concrete wall were literally different art and could
##      never read as the same material. The rule now: `has_facade == true`
##      -> the floor bakes through the SAME `facade_<id>` its wall and roof
##      do (grayscale + multiply); `has_facade == false` -> the photographic
##      `slab_<id>` exception, kept on purpose for organic ground. Tests 3-5
##      below assert the new contract; they asserted the opposite before, and
##      were rewritten rather than relaxed.
##   3. The projection that made the merge free — D34 extends a 1024x512 wall
##      facade to the isotropic 1024x1024 a horizontal surface addresses by
##      MIRRORED VERTICAL REPEAT, never by resize (tests 6-7).
## Every expectation is computed independently (own expected values), never
## read back from the code under test.

extends SceneTree

const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("E-MAT — MATERIAL REFORM SELFTEST")
	print("=".repeat(70) + "\n")

	test_1_one_registered_row_per_material()
	test_2_old_duplicate_row_is_gone_not_shadowed()
	test_3_texture_identity_is_material_keyed()
	test_4_floor_and_wall_share_one_modulate()
	test_5_both_families_bake_in_one_session()
	test_6_horizontal_plane_is_mirrored_not_stretched()
	test_7_roof_and_floor_specs_merge_their_cells()
	test_8_earth_is_a_buildable_material()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ MATERIAL REFORM SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ MATERIAL REFORM SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## D19: concrete keeps exactly the values its WALL row always had (0.3/0.15/
## 0.1, crack_factor 0.1 closing D10's gap) — this is now ALSO what a
## concrete floor reads, by construction (one row, not two agreeing by luck).
func test_1_one_registered_row_per_material() -> void:
	print("[1] MaterialResistanceTable has exactly one 'concrete' row (D19)\n")

	var destroy := MaterialResistanceTableClass.destroy_factor("concrete")
	var dent := MaterialResistanceTableClass.dent_factor("concrete")
	var crack := MaterialResistanceTableClass.crack_factor("concrete")

	if is_equal_approx(destroy, 0.3) and is_equal_approx(dent, 0.15) and is_equal_approx(crack, 0.1):
		_pass("concrete: destroy=%.2f dent=%.2f crack=%.2f (matches the historical wall row; a floor built from concrete now reads the SAME numbers)" % [destroy, dent, crack])
	else:
		_fail("concrete: destroy=%.2f dent=%.2f crack=%.2f, expected 0.30/0.15/0.10" % [destroy, dent, crack])

	var registry := MaterialRegistryClass.new()
	registry.load_from_disk()
	var concrete_count := 0
	for id in registry.list_materials():
		if id == "concrete":
			concrete_count += 1
	if concrete_count == 1:
		_pass("MaterialRegistry has exactly one 'concrete' entry")
	else:
		_fail("MaterialRegistry has %d 'concrete' entries, expected 1" % concrete_count)

	print("")


## D19/D20: "ground_concrete" must not resolve as if it were still a
## registered id — a stale caller gets the table's DEFAULT (unregistered)
## values, not the old ground-specific row (0.5/0.2/0.0). dent_factor is the
## discriminating field: the old row's dent (0.2) differs from today's
## DEFAULT_DENT_FACTOR (0.0), so a miss and a leftover shadow row are
## distinguishable — destroy_factor alone could not tell them apart (both
## happen to be 0.5).
func test_2_old_duplicate_row_is_gone_not_shadowed() -> void:
	print("[2] 'ground_concrete' is gone, not merely shadowed by 'concrete' (D19)\n")

	var dent := MaterialResistanceTableClass.dent_factor("ground_concrete")
	if is_equal_approx(dent, MaterialResistanceTableClass.DEFAULT_DENT_FACTOR):
		_pass("dent_factor('ground_concrete') = %.2f — the table's DEFAULT, proving no row survives under the old id (a leftover row would read 0.20)" % dent)
	else:
		_fail("dent_factor('ground_concrete') = %.2f — a duplicate row is still alive under the retired id" % dent)

	var registry := MaterialRegistryClass.new()
	registry.load_from_disk()
	var stray_ground_ids: Array = []
	for id in registry.list_materials():
		if String(id).begins_with("ground_"):
			stray_ground_ids.append(id)
	if stray_ground_ids.is_empty():
		_pass("MaterialRegistry carries no 'ground_*' ids")
	else:
		_fail("MaterialRegistry still carries ground_* ids: %s" % [stray_ground_ids])

	print("")


## D34: the SLAB family is chosen by the MATERIAL's own has_facade, not by
## surface alone. Both expectations are hardcoded here on purpose and the
## registry is asserted to agree — that way a silent edit to materials/*.json
## fails this test instead of quietly redefining the contract it encodes.
func test_3_texture_identity_is_material_keyed() -> void:
	print("[3] (material, surface_class, has_facade) -> texture id (D34, supersedes D20)\n")

	var registry := MaterialRegistryClass.new()
	registry.load_from_disk()

	for row in [["concrete", true], ["grass", false]]:
		var mid: String = row[0]
		var expected_has_facade: bool = row[1]
		var md = registry.get_material(mid)
		if md == null:
			_fail("MaterialRegistry has no '%s' entry" % mid)
			continue
		if md.has_facade != expected_has_facade:
			_fail("materials/%s.json has_facade=%s, this test's contract expects %s" % [
				mid, md.has_facade, expected_has_facade])
			continue

		var slice_id := BakePolicyClass.texture_for_material(
			mid, BakePolicyClass.SurfaceClass.SLICE, md.has_facade)
		var slab_id := BakePolicyClass.texture_for_material(
			mid, BakePolicyClass.SurfaceClass.SLAB, md.has_facade)
		var expected_slab: String = "facade_%s" % mid if expected_has_facade else "slab_%s" % mid

		if slice_id == "facade_%s" % mid and slab_id == expected_slab:
			_pass("%s (has_facade=%s): SLICE -> '%s', SLAB -> '%s'" % [mid, md.has_facade, slice_id, slab_id])
		else:
			_fail("%s: SLICE -> '%s', SLAB -> '%s', expected 'facade_%s'/'%s'" % [
				mid, slice_id, slab_id, mid, expected_slab])

	## The whole point, stated as its own assertion: a structural material's
	## floor and wall must be the SAME texture id, and an organic one's must
	## not. Deriving both from the same call is what makes B1 hold.
	var concrete_wall := BakePolicyClass.texture_for_material("concrete", BakePolicyClass.SurfaceClass.SLICE, true)
	var concrete_floor := BakePolicyClass.texture_for_material("concrete", BakePolicyClass.SurfaceClass.SLAB, true)
	var grass_floor := BakePolicyClass.texture_for_material("grass", BakePolicyClass.SurfaceClass.SLAB, false)
	if concrete_wall == concrete_floor and grass_floor != concrete_floor:
		_pass("concrete floor == concrete wall ('%s'); grass floor stays photographic ('%s')" % [
			concrete_floor, grass_floor])
	else:
		_fail("wall='%s' floor='%s' grass='%s' — structural floor must equal its wall" % [
			concrete_wall, concrete_floor, grass_floor])

	print("")


## D34 reverses test 4's original claim. The old contract wanted concrete's
## floor to be WHITE (photographic) while its wall was tinted; that is exactly
## what made the two unable to read as one material. Now a structural
## material's floor page and wall page are the same id, so they necessarily
## carry the SAME tinted modulate — and only the organic `slab_` family stays
## WHITE. _modulate_for_mode() itself is unchanged (it still keys on the
## `slab_` prefix); what changed is which ids reach it.
func test_4_floor_and_wall_share_one_modulate() -> void:
	print("[4] A structural material's floor and wall carry one modulate; organic ground stays WHITE (D34)\n")

	var compositor := BakeCompositorClass.new()
	var registry := MaterialRegistryClass.new()
	registry.load_from_disk()
	compositor.set_material_registry(registry)
	var concrete = registry.get_material("concrete")
	var grass = registry.get_material("grass")
	if concrete == null or grass == null:
		_fail("MaterialRegistry missing 'concrete' or 'grass' — cannot test modulate")
		return

	var blend_mode := 0  # BakeConfig.BlendMode.MULTIPLY
	var wall_id := BakePolicyClass.texture_for_material("concrete", BakePolicyClass.SurfaceClass.SLICE, concrete.has_facade)
	var floor_id := BakePolicyClass.texture_for_material("concrete", BakePolicyClass.SurfaceClass.SLAB, concrete.has_facade)
	var grass_id := BakePolicyClass.texture_for_material("grass", BakePolicyClass.SurfaceClass.SLAB, grass.has_facade)

	var wall_modulate: Color = compositor._modulate_for_mode(blend_mode, concrete, wall_id)
	var floor_modulate: Color = compositor._modulate_for_mode(blend_mode, concrete, floor_id)
	var grass_modulate: Color = compositor._modulate_for_mode(blend_mode, grass, grass_id)

	if wall_modulate != Color.WHITE and floor_modulate == wall_modulate:
		_pass("concrete: wall and floor both tinted %s — one material, one look" % wall_modulate)
	else:
		_fail("concrete: wall=%s floor=%s — expected both tinted and equal" % [wall_modulate, floor_modulate])

	if grass_modulate == Color.WHITE:
		_pass("grass: '%s' -> WHITE, the photographic exception survives (B2)" % grass_id)
	else:
		_fail("grass: '%s' -> %s, expected WHITE" % [grass_id, grass_modulate])

	print("")


## End-to-end: bake BOTH families in one session with the real compositor,
## real resolver and real on-disk assets — a structural material through
## `facade_` and an organic one through `slab_`. D34 changed what this test
## proves: the old version asserted concrete produced two distinct pages (one
## per surface), which is precisely the split the Director removed. What must
## hold now is that the two FAMILIES still coexist without colliding, and that
## each carries its own modulate.
func test_5_both_families_bake_in_one_session() -> void:
	print("[5] facade_ and slab_ families bake side by side, each with its own modulate (D34 gate)\n")

	var compositor := BakeCompositorClass.new()
	var registry := MaterialRegistryClass.new()
	registry.load_from_disk()
	compositor.set_material_registry(registry)
	var resolver := TextureResolverClass.new()
	var cells: Array = []
	for y in range(4):
		for x in range(4):
			cells.append(Vector2i(x, y))

	var map_spec := {
		"roofs": [
			{"material_id": "concrete", "facade_id": "facade_concrete", "cells": cells},
			{"material_id": "grass", "facade_id": "slab_grass", "cells": cells},
		],
		"map_id": "MATERIAL_REFORM_TEST",
	}
	var atlas = compositor.bake(map_spec, resolver)
	if atlas == null:
		_fail("bake() returned null")
		return

	var structural_entry = atlas.lookup.get("ROOF|concrete|facade_concrete|0|0")
	var organic_entry = atlas.lookup.get("ROOF|grass|slab_grass|0|0")
	if structural_entry == null or organic_entry == null:
		_fail("missing lookup entries: concrete=%s grass=%s" % [structural_entry, organic_entry])
		return
	_pass("both families composed real lookup entries (facade_concrete AND slab_grass)")

	var structural_page: Image = atlas.atom_pages[int(structural_entry.get("page"))]
	var organic_page: Image = atlas.atom_pages[int(organic_entry.get("page"))]
	if structural_page != organic_page:
		_pass("the two families are distinct Images (%dx%d vs %dx%d)" % [
			structural_page.get_width(), structural_page.get_height(),
			organic_page.get_width(), organic_page.get_height()])
	else:
		_fail("both families landed on the SAME Image — collision")

	var structural_modulate: Color = atlas.page_modulates[int(structural_entry.get("page"))]
	var organic_modulate: Color = atlas.page_modulates[int(organic_entry.get("page"))]
	if structural_modulate != Color.WHITE and organic_modulate == Color.WHITE:
		_pass("registered modulates: facade_concrete=%s (tinted), slab_grass=WHITE — matches test 4" % structural_modulate)
	else:
		_fail("registered modulates: concrete=%s grass=%s — expected tinted/WHITE" % [
			structural_modulate, organic_modulate])

	print("")


## D34's projection change, on a synthetic source small enough to verify every
## pixel by hand. Mirrored repeat must (a) reach the target height, (b) keep
## NATIVE pixels — a resize would blend or duplicate rows and fail the exact
## equality below — and (c) reflect with a repeated edge row, matching
## BakeCompositor._mirror_index()'s own fold semantics (index 63 and 64 both
## fold to 63), so the plane agrees with the cell-level fold that samples it.
func test_6_horizontal_plane_is_mirrored_not_stretched() -> void:
	print("[6] A short source reaches the isotropic target by mirrored repeat, not resize (D34)\n")

	var compositor := BakeCompositorClass.new()
	var src := Image.create(2, 4, false, Image.FORMAT_RGBA8)
	for y in range(4):
		for x in range(2):
			src.set_pixel(x, y, Color(float(y) / 4.0, 0.0, 0.0, 1.0))

	var out: Image = compositor._mirror_tile_v(src, 8)
	if out.get_height() != 8 or out.get_width() != 2:
		_fail("expected 2x8, got %dx%d" % [out.get_width(), out.get_height()])
		return
	_pass("2x4 source extended to 2x8")

	## Expected row order derived here, not read from the code under test:
	## band 0 = rows 0,1,2,3 then band 1 = the flip, rows 3,2,1,0.
	var expected_rows: Array[int] = [0, 1, 2, 3, 3, 2, 1, 0]
	var mismatches: Array[String] = []
	for y in range(8):
		var got: Color = out.get_pixel(0, y)
		var want: Color = src.get_pixel(0, expected_rows[y])
		if not is_equal_approx(got.r, want.r):
			mismatches.append("y=%d got r=%.4f want r=%.4f (src row %d)" % [y, got.r, want.r, expected_rows[y]])
	if mismatches.is_empty():
		_pass("row order is 0,1,2,3,3,2,1,0 — reflected with a repeated edge row, pixels exact (no resampling)")
	else:
		_fail("mirrored rows wrong: %s" % ", ".join(mismatches))

	## And the real consequence: a 1024x512 wall facade now yields the SAME
	## isotropic plane height the floor path already produced (V_MARGIN +
	## 1024 + V_MARGIN = 1088, the number floor_zone_bake_selftest pinned),
	## which is what lets a roof and a floor share one page at all.
	var facade := Image.create(BakeCompositorClass.FACADE_W, BakeCompositorClass.FACADE_H, false, Image.FORMAT_RGBA8)
	facade.fill(Color(0.5, 0.5, 0.5, 1.0))
	var plane: Image = compositor._get_roof_plane_source(facade)
	var expected_h: int = 2 * BakeCompositorClass.V_MARGIN + BakeCompositorClass.FACADE_W
	if plane.get_height() == expected_h:
		_pass("a 1024x512 facade builds the isotropic plane (height %d) — roof and floor now agree" % expected_h)
	else:
		_fail("plane height %d, expected %d" % [plane.get_height(), expected_h])

	print("")


## D34 made a structural material's roof combo and its floor combo IDENTICAL,
## so room_builder must union their cells before the compositor sees them —
## two specs on one cache key would silently drop the second one's cells.
## Verified directly on the merge function rather than through a full build.
func test_7_roof_and_floor_specs_merge_their_cells() -> void:
	print("[7] Roof and floor specs on one combo union their cells, they do not overwrite (D34)\n")

	## _merge_horizontal_specs() is pure (dict in, array out) and touches no
	## `room` state, so a null room is enough to construct the builder here —
	## no scene, no map load.
	var builder := RoomBuilderClass.new(null)
	var roof_specs: Array = [{
		"material_id": "concrete", "facade_id": "facade_concrete",
		"cells": [Vector2i(0, 0), Vector2i(1, 0)],
	}]
	var floor_specs: Array = [
		{
			"material_id": "concrete", "facade_id": "facade_concrete",
			"cells": [Vector2i(1, 0), Vector2i(2, 0)],
		},
		{
			"material_id": "grass", "facade_id": "slab_grass",
			"cells": [Vector2i(5, 5)],
		},
	]

	var merged: Array = builder._merge_horizontal_specs(roof_specs, floor_specs)
	if merged.size() != 2:
		_fail("expected 2 merged combos (concrete, grass), got %d" % merged.size())
		return
	_pass("3 specs across 2 combos merged into 2 specs")

	var concrete_spec: Dictionary = {}
	var grass_spec: Dictionary = {}
	for spec: Dictionary in merged:
		if String(spec["material_id"]) == "concrete":
			concrete_spec = spec
		elif String(spec["material_id"]) == "grass":
			grass_spec = spec

	## Union of {(0,0),(1,0)} and {(1,0),(2,0)} is 3 distinct cells — the
	## shared (1,0) must appear once, and neither surface's own cell may be lost.
	var concrete_cells: Array = concrete_spec.get("cells", [])
	var have := {}
	for cell in concrete_cells:
		have[cell] = true
	var want_all: bool = have.has(Vector2i(0, 0)) and have.has(Vector2i(1, 0)) and have.has(Vector2i(2, 0))
	if concrete_cells.size() == 3 and want_all:
		_pass("concrete: roof's (0,0) and floor's (2,0) both survive, shared (1,0) deduped — 3 cells")
	else:
		_fail("concrete cells = %s, expected exactly (0,0),(1,0),(2,0)" % [concrete_cells])

	if String(grass_spec.get("facade_id", "")) == "slab_grass" and grass_spec.get("cells", []).size() == 1:
		_pass("grass: floor-only combo passes through untouched on the photographic family")
	else:
		_fail("grass spec = %s" % [grass_spec])

	print("")


## D35/E-EARTH-01 (Director, 2026-08-08) — `earth` became a buildable material
## (walls, blocks, roofs), closing the gap D34 explicitly left open. Three
## things had to line up, and each fails in a different silent way if it does
## not, so each is asserted separately rather than inferred from one boot:
##   - the material row (has_facade + a real base_color, or its wall renders
##     WHITE-tinted)
##   - the canonical voxel atom (earth ships as 8 variants and has NO
##     `voxel_earth.png`, so a naive path build push_errors and B3 masking
##     silently degrades to unmasked rectangles)
##   - the generic-atlas entry (bake-OFF is the SHIPPED canon; without it
##     MATERIALS.find("earth") is -1 and an earth wall paints flat concrete)
##
## Deliberately does NOT require `facade_earth.png` to exist: the art is the
## Director's, arrives separately, and a missing facade is the documented
## graceful path (TextureResolver -> Tier.NONE -> generic atlas). This test
## pins the plumbing that must be correct either way.
func test_8_earth_is_a_buildable_material() -> void:
	print("[8] earth is a first-class buildable material — row, canonical atom, generic atlas (D35)\n")

	var registry := MaterialRegistryClass.new()
	registry.load_from_disk()
	var earth = registry.get_material("earth")
	if earth == null:
		_fail("MaterialRegistry has no 'earth' entry")
		return

	if earth.has_facade:
		_pass("earth declares has_facade — its wall/roof/floor all resolve '%s'" % \
			BakePolicyClass.texture_for_material("earth", BakePolicyClass.SurfaceClass.SLICE, earth.has_facade))
	else:
		_fail("earth has_facade is false — it cannot be built with")

	## A material left at the WHITE default would multiply to no tint at all,
	## i.e. a grayscale wall. Any real colour is enough; this asserts it is not
	## the default rather than pinning the Director's exact value.
	if earth.base_color != Color.WHITE:
		_pass("earth carries a real base_color %s (not the WHITE default)" % earth.base_color)
	else:
		_fail("earth base_color is the WHITE default — MULTIPLY would leave it grayscale")

	## The canonical atom: alias resolves, file exists, and the alpha it
	## contributes really is interchangeable (B3's whole premise for the alias).
	var stem: String = BakePolicyClass.canonical_voxel_atom_for("earth")
	var earth_path: String = "res://ASSETS/ISOMETRIC/source_assets/voxels/materials/voxel_%s.png" % stem
	if stem != "earth" and ResourceLoader.exists(earth_path):
		_pass("canonical atom alias earth -> '%s' resolves to a real file" % stem)
	else:
		_fail("canonical atom for earth resolved to '%s' (%s), which does not exist" % [stem, earth_path])

	var earth_img: Image = load(earth_path).get_image() if ResourceLoader.exists(earth_path) else null
	var concrete_img: Image = load("res://ASSETS/ISOMETRIC/source_assets/voxels/materials/voxel_concrete.png").get_image()
	if earth_img != null and concrete_img != null:
		earth_img = earth_img.duplicate(); earth_img.convert(Image.FORMAT_RGBA8)
		concrete_img = concrete_img.duplicate(); concrete_img.convert(Image.FORMAT_RGBA8)
		var alpha_mismatches := 0
		for y in range(concrete_img.get_height()):
			for x in range(concrete_img.get_width()):
				if earth_img.get_pixel(x, y).a != concrete_img.get_pixel(x, y).a:
					alpha_mismatches += 1
		if alpha_mismatches == 0:
			_pass("earth's canonical alpha is identical to concrete's over all %d px — the alias is B3-safe" % \
				(concrete_img.get_width() * concrete_img.get_height()))
		else:
			_fail("earth's canonical alpha differs from concrete's on %d px — the alias breaks B3" % alpha_mismatches)

	## Identity must hold for everything else, or the alias is a landmine.
	for other in ["concrete", "metal", "stone", "wood", "grass"]:
		if BakePolicyClass.canonical_voxel_atom_for(other) != other:
			_fail("canonical_voxel_atom_for('%s') aliased unexpectedly to '%s'" % \
				[other, BakePolicyClass.canonical_voxel_atom_for(other)])
			return
	_pass("every other material's canonical atom is still identity")

	## Generic atlas (the bake-OFF / shipped path).
	var earth_index: int = VoxelRendererClass.MATERIALS.find("earth")
	if earth_index > 0:
		_pass("bare 'earth' is in MATERIALS at %d — a bake-OFF earth wall no longer falls to MATERIALS[0] ('%s')" % \
			[earth_index, VoxelRendererClass.MATERIALS[0]])
	else:
		_fail("MATERIALS.find('earth') = %d — a bake-OFF earth wall would paint flat %s" % \
			[earth_index, VoxelRendererClass.MATERIALS[0]])

	## The per-cell surface palette for UNZONED ground is a different thing and
	## must be untouched by D35 — regressing it would repaint every floor.
	var variants_intact := true
	for v in range(8):
		if not VoxelRendererClass.MATERIALS.has("earth_%d" % v):
			variants_intact = false
	if variants_intact:
		_pass("earth_0..earth_7 (EarthVariantSelector's unzoned-ground palette) are all still present")
	else:
		_fail("an earth_N variant went missing — unzoned floor rendering would regress")

	print("")
