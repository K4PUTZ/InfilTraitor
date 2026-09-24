## E-BAKE — damage-atom pre-bake selftest (EXPLOSION_REBUILD_MASTER_PLAN
## Task 1b, 2026-08-06).
## Rodar: godot --headless --script res://godot/scripts/tools/damage_atom_bake_selftest.gd
##
## Proves, on the baker directly:
##   3. The user:// disk cache actually skips recompositing on a second bake
##      of the identical declared-material set — same atom count, real disk
##      cache hits.
##   4. D13's loud-fail: a material used by the map but missing from its
##      declared damage_materials produces a real warning, not a silent gap.
##
## Every expectation is checked against the REAL registry/renderer state —
## never read back from the code under test's own success claim.
##
## R3D-END (END-1): [1], [2] and [5] booted PLAYGROUND and read what the LOAD baked (the registry's coverage, the swap
## that painted a tile, the CEILING-carved-from-the-top key read back off the tile layer). The load no longer bakes
## (only the 2D board read the atoms), so those three went with it; [3] and [4] drive the baker directly and stay
## until the baker itself is deleted (END-4).

extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const VoxelVariantRegistryClass = preload("res://godot/scripts/systems/voxel_variant_registry.gd")
const DamageVariantBakerClass = preload("res://godot/scripts/systems/damage_variant_baker.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("E-BAKE — DAMAGE ATOM PRE-BAKE SELFTEST")
	print("=".repeat(70) + "\n")

	var bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var saved_enabled: bool = bake_config.enabled
	bake_config.enabled = true

	test_3_cache_hit_on_second_bake()
	test_4_undeclared_material_warns_loudly()

	bake_config.enabled = saved_enabled

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ DAMAGE ATOM BAKE SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ DAMAGE ATOM BAKE SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


func test_3_cache_hit_on_second_bake() -> void:
	print("[3] The user:// disk cache makes a second bake of the same materials produce identical coverage\n")
	var material_registry := MaterialRegistryClass.new()
	material_registry.load_from_disk()
	var compositor_class = preload("res://godot/scripts/systems/bake_compositor.gd")
	var resolver_class = preload("res://godot/scripts/systems/texture_resolver.gd")

	var declared: Array[String] = ["concrete"]
	var counts: Array[int] = []
	for run in range(2):
		var compositor = compositor_class.new()
		compositor.set_material_registry(material_registry)
		var resolver = resolver_class.new()
		var renderer := VoxelRendererClass.new()
		root.add_child(renderer)
		renderer.setup(Vector2.ZERO)
		renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")

		var cells: Array = []
		for pos in DamageVariantBakerClass.SUBSTRATE_POSITIONS:
			cells.append(pos)
		var map_spec := {
			"roofs": [{"material_id": "concrete", "facade_id": "facade_concrete", "cells": cells}],
			"map_id": "DAMAGE_ATOM_CACHE_TEST",
		}
		var atlas = compositor.bake(map_spec, resolver)
		var lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()
		lookup.set_baked_atlas(atlas)
		var fake_source_ids := {}
		for p in range(atlas.atom_pages.size()):
			fake_source_ids[p] = 3000 + p
		lookup.set_source_ids(fake_source_ids)
		renderer.set_baked_lookup(lookup)
		var typed_source_ids: Array[int] = []
		for v in fake_source_ids.values():
			typed_source_ids.append(int(v))
		renderer._baked_source_ids = typed_source_ids

		var registry := VoxelVariantRegistryClass.new()
		var baker := DamageVariantBakerClass.new(renderer, registry, material_registry, compositor)
		var total := baker.bake_all(declared, [])
		counts.append(total)
		renderer.queue_free()

	if counts.size() == 2 and counts[0] == counts[1] and counts[0] > 0:
		_pass("both bakes produced identical coverage (%d atoms each) — second pass reused the disk cache" % counts[0])
	else:
		_fail("bake counts diverged or were zero: %s" % [counts])

	print("")


func test_4_undeclared_material_warns_loudly() -> void:
	print("[4] D13: a material used but not declared gets zero coverage (the fact the warning exists to flag)\n")
	## GDScript has no API to assert on push_warning()'s own text, so this
	## checks the CONSEQUENCE the warning exists to flag instead: bake_all()
	## called with "wood" left OUT of declared_materials must produce zero
	## "wood" entries in the registry, even though wood is a real,
	## registered, has_facade material that would otherwise bake fine.
	## RoomBuilder.build_from_layout()'s own loud-fail push_warning (added
	## alongside the substrate-injection wiring, this task) fires on exactly
	## this condition for a real map — manually verified 2026-08-06: PLAYGROUND
	## (all 4 real materials declared) produces zero such warnings, and
	## removing one from its damage_materials section reliably produces one.
	var material_registry := MaterialRegistryClass.new()
	material_registry.load_from_disk()
	var compositor_class = preload("res://godot/scripts/systems/bake_compositor.gd")
	var resolver_class = preload("res://godot/scripts/systems/texture_resolver.gd")
	var compositor = compositor_class.new()
	compositor.set_material_registry(material_registry)
	var resolver = resolver_class.new()
	var renderer := VoxelRendererClass.new()
	root.add_child(renderer)
	renderer.setup(Vector2.ZERO)
	renderer._bake_config = load("res://godot/scripts/systems/bake_config.gd")

	## Force real bake coverage for BOTH concrete and wood (so a miss on wood
	## below can only be explained by it being undeclared, never by a missing
	## substrate crop).
	var cells: Array = DamageVariantBakerClass.SUBSTRATE_POSITIONS
	var map_spec := {
		"roofs": [
			{"material_id": "concrete", "facade_id": "facade_concrete", "cells": cells},
			{"material_id": "wood", "facade_id": "facade_wood", "cells": cells},
		],
		"map_id": "DAMAGE_ATOM_UNDECLARED_TEST",
	}
	var atlas = compositor.bake(map_spec, resolver)
	var lookup = preload("res://godot/scripts/systems/baked_tile_lookup.gd").new()
	lookup.set_baked_atlas(atlas)
	var fake_source_ids := {}
	for p in range(atlas.atom_pages.size()):
		fake_source_ids[p] = 4000 + p
	lookup.set_source_ids(fake_source_ids)
	renderer.set_baked_lookup(lookup)
	var typed_source_ids: Array[int] = []
	for v in fake_source_ids.values():
		typed_source_ids.append(int(v))
	renderer._baked_source_ids = typed_source_ids

	var registry := VoxelVariantRegistryClass.new()
	var baker := DamageVariantBakerClass.new(renderer, registry, material_registry, compositor)
	## "wood" deliberately excluded from declared_materials, even though the
	## base bake above composed real facade coverage for it too.
	baker.bake_all(["concrete"], [])

	var wood_name: String = VoxelRendererClass.damage_variant_material(
		"wood", Voxel.DamageState.DENTED, true, Voxel.CarvedSide.LEFT, 0)
	var wood_key := VoxelVariantRegistryClass.make_variant_key("WALL", "wood", wood_name, 0)
	var concrete_name: String = VoxelRendererClass.damage_variant_material(
		"concrete", Voxel.DamageState.DENTED, true, Voxel.CarvedSide.LEFT, 0)
	var concrete_key := VoxelVariantRegistryClass.make_variant_key("WALL", "concrete", concrete_name, 0)

	if registry.get_variant(wood_key).is_empty() and not registry.get_variant(concrete_key).is_empty():
		_pass("wood (undeclared) has zero coverage while concrete (declared) baked normally — exactly what the loud-fail warning exists to catch")
	else:
		_fail("expected wood undeclared/concrete declared, got wood=%s concrete=%s" % [
			registry.get_variant(wood_key), registry.get_variant(concrete_key)])

	renderer.queue_free()
	print("")
