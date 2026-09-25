## E-MAT — material reform selftest (EXPLOSION_REBUILD_MASTER_PLAN Task 1a,
## D19/D20/D21, 2026-08-06).
## Rodar: godot --headless --script res://godot/scripts/tools/material_reform_selftest.gd
##
## Proves the two halves of the reform independently:
##   1. BEHAVIOR is unified — one row per material (MaterialRegistry +
##      MaterialResistanceTable), the old duplicate `ground_concrete` row is
##      gone, not merely shadowed.
##   2. TEXTURE IDENTITY follows the MATERIAL, not the surface — D34/E-SEAM-01
##      (Director, 2026-08-08) **reversed D20's original answer here.**
##      `has_facade == true` -> the floor names the SAME `facade_<id>` its wall
##      and roof do; `has_facade == false` -> the photographic `slab_<id>`
##      exception, kept on purpose for organic ground.
## R3D-END END-4: the tests that drove the compositor (the shared modulate, the two families baked in one session, the
## mirrored vertical repeat, the roof/floor spec merge) went with it, and so did the generic-atlas half of test 8.
## Every expectation is computed independently (own expected values), never
## read back from the code under test.

extends SceneTree

const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("E-MAT — MATERIAL REFORM SELFTEST")
	print("=".repeat(70) + "\n")

	test_1_one_registered_row_per_material()
	test_2_old_duplicate_row_is_gone_not_shadowed()
	test_3_texture_identity_is_material_keyed()
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


## D35/E-EARTH-01 (Director, 2026-08-08) — `earth` became a buildable material
## (walls, blocks, roofs), closing the gap D34 explicitly left open. Three
## things had to line up, and each fails in a different silent way if it does
## not, so each is asserted separately rather than inferred from one boot:
##   - the material row (has_facade + a real base_color, or its wall renders
##     WHITE-tinted)
##   - the canonical voxel atom (earth ships as 8 variants and has NO
##     `voxel_earth.png`, so a naive path build push_errors and B3 masking
##     silently degrades to unmasked rectangles)
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
	## ASSET_TREE_REFORM: the folder is not always the atom id — `earth_0` lives in
	## `earth/`. BakePolicy.material_folder_for_atom() owns that rule, and asking
	## it here is what keeps this test measuring the real lookup.
	var earth_path: String = "res://ASSETS/materials/%s/voxel_%s.png" % [
		BakePolicyClass.material_folder_for_atom(stem), stem]
	if stem != "earth" and ResourceLoader.exists(earth_path):
		_pass("canonical atom alias earth -> '%s' resolves to a real file" % stem)
	else:
		_fail("canonical atom for earth resolved to '%s' (%s), which does not exist" % [stem, earth_path])

	var earth_img: Image = load(earth_path).get_image() if ResourceLoader.exists(earth_path) else null
	var concrete_img: Image = load("res://ASSETS/materials/concrete/voxel_concrete.png").get_image()
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

	## (R3D-END END-4: the generic-atlas half — `VoxelRenderer.MATERIALS` carrying `earth` and `earth_0..7` — went with the atlas.)

	print("")
