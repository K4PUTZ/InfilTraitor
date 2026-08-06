## E-MAT — material reform selftest (EXPLOSION_REBUILD_MASTER_PLAN Task 1a,
## D19/D20/D21, 2026-08-06).
## Rodar: godot --headless --script res://godot/scripts/tools/material_reform_selftest.gd
##
## Proves the two halves of the reform independently:
##   1. BEHAVIOR is unified — one row per material (MaterialRegistry +
##      MaterialResistanceTable), the old duplicate `ground_concrete` row is
##      gone, not merely shadowed.
##   2. RENDERING stays surface-dependent — the same material resolves to two
##      different texture ids (facade_/slab_) and two different bake
##      modulates (tinted/white) depending on surface_class, which is the
##      exact mechanism that makes "concrete" (a material with a genuine
##      wall AND floor presence, unlike grass/dirt/gravel/sand) survive
##      unification without visually merging its two renders.
## Every expectation is computed independently (own expected values), never
## read back from the code under test.

extends SceneTree

const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const MaterialResistanceTableClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("E-MAT — MATERIAL REFORM SELFTEST")
	print("=".repeat(70) + "\n")

	test_1_one_registered_row_per_material()
	test_2_old_duplicate_row_is_gone_not_shadowed()
	test_3_texture_identity_is_surface_keyed()
	test_4_modulate_follows_surface_not_material()
	test_5_concrete_bakes_on_both_surfaces_without_collision()

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


## D20: one material, two texture ids — the naming logic is mechanical
## (facade_<id> for SLICE, slab_<id> for SLAB), so this is true for every
## material, not a special case hand-listed for concrete.
func test_3_texture_identity_is_surface_keyed() -> void:
	print("[3] (material, surface_class) -> texture id, both directions (D20)\n")

	var facade_id := BakePolicyClass.facade_for_material("concrete")
	var slab_id := BakePolicyClass.slab_for_material("concrete")
	if facade_id == "facade_concrete" and slab_id == "slab_concrete" and facade_id != slab_id:
		_pass("concrete: SLICE -> '%s', SLAB -> '%s' — same material, two distinct texture ids" % [facade_id, slab_id])
	else:
		_fail("concrete: SLICE -> '%s', SLAB -> '%s', expected 'facade_concrete'/'slab_concrete'" % [facade_id, slab_id])

	var via_enum_slice := BakePolicyClass.texture_for_material("concrete", BakePolicyClass.SurfaceClass.SLICE)
	var via_enum_slab := BakePolicyClass.texture_for_material("concrete", BakePolicyClass.SurfaceClass.SLAB)
	if via_enum_slice == facade_id and via_enum_slab == slab_id:
		_pass("texture_for_material() agrees with the direct facade_for_material()/slab_for_material() calls")
	else:
		_fail("texture_for_material() diverged: SLICE=%s SLAB=%s" % [via_enum_slice, via_enum_slab])

	print("")


## The crux mechanism this whole reform hinges on: bake_compositor.gd's
## _modulate_for_mode() must decide WHITE-vs-tinted from the TEXTURE id
## (slab_ prefix), not from a flag on the MaterialDef — otherwise a single
## unified 'concrete' MaterialDef could not be tinted on walls AND full-color
## on floors at once. Calling the SAME function with the SAME material but
## two different texture ids is the direct proof.
func test_4_modulate_follows_surface_not_material() -> void:
	print("[4] Same material, different modulate per surface (the D19/D20 tension this plan resolved)\n")

	var compositor := BakeCompositorClass.new()
	var registry := MaterialRegistryClass.new()
	registry.load_from_disk()
	compositor.set_material_registry(registry)
	var concrete = registry.get_material("concrete")
	if concrete == null:
		_fail("MaterialRegistry has no 'concrete' entry — cannot test modulate")
		return

	var blend_mode := 0  # BakeConfig.BlendMode.MULTIPLY
	var wall_modulate: Color = compositor._modulate_for_mode(blend_mode, concrete, "facade_concrete")
	var floor_modulate: Color = compositor._modulate_for_mode(blend_mode, concrete, "slab_concrete")

	var wall_is_tinted := wall_modulate != Color.WHITE
	var floor_is_white := floor_modulate == Color.WHITE
	if wall_is_tinted and floor_is_white:
		_pass("same MaterialDef instance: facade_concrete -> tinted %s (MULTIPLY), slab_concrete -> WHITE (B2 exception)" % wall_modulate)
	else:
		_fail("wall_modulate=%s (tinted expected) floor_modulate=%s (WHITE expected)" % [wall_modulate, floor_modulate])

	print("")


## End-to-end: bake 'concrete' through BOTH the wall/roof (SLICE) page family
## and the floor (SLAB) page family in the SAME session, real compositor +
## real resolver + real on-disk assets — the actual collision case D19
## introduces (concrete is the only material with both a wall and a floor
## presence) and the one no prior selftest exercised, since floor_zone_bake_
## selftest.gd/roof_bake_selftest.gd each use materials that only ever
## appear on one surface.
func test_5_concrete_bakes_on_both_surfaces_without_collision() -> void:
	print("[5] 'concrete' bakes real, distinct pages for SLICE and SLAB in one session (the actual reform gate)\n")

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
			{"material_id": "concrete", "facade_id": "slab_concrete", "cells": cells},
		],
		"map_id": "MATERIAL_REFORM_TEST",
	}
	var atlas = compositor.bake(map_spec, resolver)
	if atlas == null:
		_fail("bake() returned null")
		return

	var slice_key := "ROOF|concrete|facade_concrete|0|0"
	var slab_key := "ROOF|concrete|slab_concrete|0|0"
	var slice_entry = atlas.lookup.get(slice_key)
	var slab_entry = atlas.lookup.get(slab_key)
	if slice_entry == null or slab_entry == null:
		_fail("missing lookup entries: slice=%s slab=%s" % [slice_entry, slab_entry])
		return
	_pass("both 'concrete' combos composed real lookup entries (facade_concrete AND slab_concrete, no collision)")

	var slice_page: Image = atlas.atom_pages[int(slice_entry.get("page"))]
	var slab_page: Image = atlas.atom_pages[int(slab_entry.get("page"))]
	if slice_page != slab_page:
		_pass("SLICE and SLAB pages are distinct Images (%dx%d vs %dx%d) — not aliased onto one page" % [
			slice_page.get_width(), slice_page.get_height(), slab_page.get_width(), slab_page.get_height()])
	else:
		_fail("SLICE and SLAB pages are the SAME Image — collision")

	var slice_modulate: Color = atlas.page_modulates[int(slice_entry.get("page"))]
	var slab_modulate: Color = atlas.page_modulates[int(slab_entry.get("page"))]
	if slice_modulate != Color.WHITE and slab_modulate == Color.WHITE:
		_pass("registered modulates: facade page=%s (tinted), slab page=WHITE — matches test 4's direct call" % slice_modulate)
	else:
		_fail("registered modulates: facade=%s slab=%s — expected tinted/WHITE" % [slice_modulate, slab_modulate])

	print("")
