## E-MAT — material reform selftest (EXPLOSION_REBUILD_MASTER_PLAN Task 1a,
## D19/D20/D21, 2026-08-06).
## Rodar: godot --headless --script res://godot/scripts/tools/material_reform_selftest.gd
##
## Proves the two halves of the reform independently:
##   1. BEHAVIOR is unified — one row per material (MaterialRegistry +
##      MaterialResistanceTable), the old duplicate `ground_concrete` row is
##      gone, not merely shadowed.
##   2. The has_facade FLAG is the contract — D34/E-SEAM-01 (Director, 2026-08-08)
##      made texture identity follow the MATERIAL, not the surface (**reversing D20's
##      original answer**): `has_facade == true` -> wall, roof and floor share one
##      `facade_<id>`; `has_facade == false` -> organic ground (the photographic
##      `slab_<id>` exception). This test pins the flag in the data.
## R3D-END END-4: the tests that drove the compositor (the shared modulate, the two families baked in one session, the
## mirrored vertical repeat, the roof/floor spec merge) went with it, and so did the generic-atlas half of test 8.
## R3D-END cleanup (2026-09-26): `BakePolicy` (the policy that turned the flag into a texture id) and the voxel atoms were
## retired, so test 3 keeps only the flag and test 8 lost its canonical-atom checks (the alias, the alpha, the identity).
## Every expectation is computed independently (own expected values), never
## read back from the code under test.

extends SceneTree

const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("E-MAT — MATERIAL REFORM SELFTEST")
	print("=".repeat(70) + "\n")

	test_1_one_registered_row_per_material()
	test_2_old_duplicate_row_is_gone_not_shadowed()
	test_3_has_facade_flags_are_the_contract()
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


## D34: whether a material has a facade decides its texture family (see the header). The expectations are hardcoded
## here on purpose and the registry is asserted to agree — that way a silent edit to materials/*.json fails this
## test instead of quietly redefining the contract it encodes.
func test_3_has_facade_flags_are_the_contract() -> void:
	print("[3] has_facade per material (D34)\n")

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
		_pass("%s: has_facade=%s" % [mid, md.has_facade])

	print("")


## D35/E-EARTH-01 (Director, 2026-08-08) — `earth` became a buildable material
## (walls, blocks, roofs), closing the gap D34 explicitly left open. The material
## row has to be right or its wall renders WHITE-tinted, so both halves of it
## (has_facade and a real base_color) are asserted separately rather than
## inferred from one boot.
##
## Deliberately does NOT require `facade_earth.png` to exist: the art is the
## Director's, arrives separately, and a missing facade is the documented
## graceful path (TextureResolver -> Tier.NONE -> the material's flat base colour).
## (R3D-END cleanup: the canonical-atom checks — the alias, the alpha, the identity — went with the atoms.)
func test_8_earth_is_a_buildable_material() -> void:
	print("[8] earth is a first-class buildable material — the row (D35)\n")

	var registry := MaterialRegistryClass.new()
	registry.load_from_disk()
	var earth = registry.get_material("earth")
	if earth == null:
		_fail("MaterialRegistry has no 'earth' entry")
		return

	if earth.has_facade:
		_pass("earth declares has_facade — its wall/roof/floor all resolve 'facade_earth'")
	else:
		_fail("earth has_facade is false — it cannot be built with")

	## A material left at the WHITE default would multiply to no tint at all,
	## i.e. a grayscale wall. Any real colour is enough; this asserts it is not
	## the default rather than pinning the Director's exact value.
	if earth.base_color != Color.WHITE:
		_pass("earth carries a real base_color %s (not the WHITE default)" % earth.base_color)
	else:
		_fail("earth base_color is the WHITE default — MULTIPLY would leave it grayscale")

	print("")
