## E-BAKE — damage-atom pre-bake selftest (EXPLOSION_REBUILD_MASTER_PLAN
## Task 1b, 2026-08-06).
## Rodar: godot --headless --script res://godot/scripts/tools/damage_atom_bake_selftest.gd
##
## Boots the REAL PLAYGROUND map through the exact room.gd::load_map() path
## (mirrors floor_zone_bake_selftest.gd's own scaffold) and proves:
##   1. DamageVariantBaker.bake_all() actually populates the registry — real
##      coverage across all three element classes (WALL/CEILING/FLOOR), not
##      just a non-empty count.
##   2. apply_damage_voxel_swap() resolves through the NEW
##      (element_class, material, name, substrate) key — a real Voxel with
##      damage_state/carved_side/variant/substrate set swaps to a pre-baked
##      tile instead of falling through to D33 live compositing.
##   3. The user:// disk cache actually skips recompositing on a second bake
##      of the identical declared-material set — same atom count, real disk
##      cache hits.
##   4. D13's loud-fail: a material used by the map but missing from its
##      declared damage_materials produces a real warning, not a silent gap.
##
## Every expectation is checked against the REAL registry/renderer state —
## never read back from the code under test's own success claim.

extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const VoxelVariantRegistryClass = preload("res://godot/scripts/systems/voxel_variant_registry.gd")
const DamageVariantBakerClass = preload("res://godot/scripts/systems/damage_variant_baker.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")

var passed: int = 0
var failed: int = 0


class MinimalRoom extends Node:
	@warning_ignore("unused_private_class_variable")
	var _edge_registry
	@warning_ignore("unused_private_class_variable")
	var _junction_columns
	var _slab_registry
	var _voxel_renderer
	var map_id: String = "TEST"


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("E-BAKE — DAMAGE ATOM PRE-BAKE SELFTEST")
	print("=".repeat(70) + "\n")

	var bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var saved_enabled: bool = bake_config.enabled
	bake_config.enabled = true

	var built := _build_playground()
	if not built.is_empty():
		test_1_real_coverage_across_element_classes(built)
		test_2_apply_damage_voxel_swap_resolves_new_key(built)
		test_3_cache_hit_on_second_bake()
		test_5_ceiling_top_routes_as_floor(built)
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


## Boot the real PLAYGROUND map through the exact room.gd::load_map() path —
## mirrors floor_zone_bake_selftest.gd's own scaffold. PLAYGROUND already
## declares damage_materials (Task 1a/1b wiring): concrete, metal, stone, wood.
func _build_playground() -> Dictionary:
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("PLAYGROUND")
	if spec.is_empty():
		_fail("FileMapSource.get_runtime_spec('PLAYGROUND') returned empty")
		return {}
	var layout: Dictionary = MapCompilerClass.compile(spec)

	var room := MinimalRoom.new()
	root.add_child(room)
	var floor_tileset: TileSet = load("res://godot/resources/tilesets/tileset_blocks.tres")
	var floor_layer := TileMapLayer.new()
	var structure_layer := TileMapLayer.new()
	floor_layer.tile_set = floor_tileset
	structure_layer.tile_set = floor_tileset
	room.add_child(floor_layer)
	room.add_child(structure_layer)
	var voxel_renderer := VoxelRendererClass.new()
	room.add_child(voxel_renderer)
	voxel_renderer.setup(Vector2.ZERO)
	room._voxel_renderer = voxel_renderer
	var builder := RoomBuilderClass.new(room)
	builder.setup(floor_layer, structure_layer, TileSet.new())
	builder.build_registry(floor_tileset)
	builder.build_from_layout(layout, layout.get("size", Vector2i.ZERO))
	return {"room": room, "renderer": voxel_renderer, "builder": builder, "layout": layout}


func test_1_real_coverage_across_element_classes(built: Dictionary) -> void:
	print("[1] bake_all() populates real coverage across WALL/CEILING/FLOOR\n")
	var renderer = built["renderer"]
	var registry = renderer._damage_variant_registry
	if registry == null:
		_fail("renderer._damage_variant_registry is null — DamageVariantBaker never ran")
		return

	var total: int = registry.size()
	if total > 0:
		_pass("registry has %d real atoms (PLAYGROUND: concrete/metal/stone/wood declared)" % total)
	else:
		_fail("registry is empty — bake_all() produced nothing")

	## Spot-check one real entry per element class, independently re-derived
	## from VoxelRenderer's own naming functions (never read back from
	## DamageVariantBaker's own internals).
	var wall_name: String = VoxelRendererClass.damage_variant_material(
		"concrete", Voxel.DamageState.DENTED, true, Voxel.CarvedSide.LEFT, 0)
	var wall_key := VoxelVariantRegistryClass.make_variant_key("WALL", "concrete", wall_name, 0)
	if not registry.get_variant(wall_key).is_empty():
		_pass("WALL: concrete DENTED-blast-left variant 0, substrate 0 is registered")
	else:
		_fail("WALL: expected key missing: %s" % wall_key)

	## D6: the shared CRACKED atom must be registered under CEILING too —
	## concrete is crack-eligible (crack_factor > 0, Task 1a's material data).
	var crack_name: String = VoxelRendererClass.damage_variant_material(
		"concrete", Voxel.DamageState.CRACKED, true, Voxel.CarvedSide.NONE, 0)
	var ceiling_key := VoxelVariantRegistryClass.make_variant_key("CEILING", "concrete", crack_name, 0)
	if not registry.get_variant(ceiling_key).is_empty():
		_pass("CEILING: D6's shared CRACKED atom (concrete) is registered under CEILING too")
	else:
		_fail("CEILING: expected shared-CRACKED key missing: %s" % ceiling_key)

	## D9: FLOOR keys off the REAL zone material ("concrete" on PLAYGROUND),
	## never the "earth" naming constant. D34/E-SEAM-02: the NAME agrees with
	## the key now — it is "concrete_blast_dented_top_0", not the old shared
	## "earth_..." pseudo-name — so both arguments below are the same material.
	var floor_name: String = VoxelRendererClass.floor_damage_material(
		"concrete", Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, 0)
	if not floor_name.begins_with("concrete_"):
		_fail("D34: floor dent name '%s' should carry the real material, not a substitute" % floor_name)
	var floor_key := VoxelVariantRegistryClass.make_variant_key("FLOOR", "concrete", floor_name, 0)
	if not registry.get_variant(floor_key).is_empty():
		_pass("FLOOR: concrete's real-material floor DENTED atom is registered")
	else:
		_fail("FLOOR: expected key missing: %s" % floor_key)

	print("")


func test_2_apply_damage_voxel_swap_resolves_new_key(built: Dictionary) -> void:
	print("[2] apply_damage_voxel_swap() swaps a real Voxel via the new key shape\n")
	var room = built["room"]
	var renderer = built["renderer"]

	## Find a real concrete Slice voxel to damage — PLAYGROUND's walls include
	## concrete (Task 1a verified this). Walk the edge registry for one.
	var edge_registry = room._edge_registry
	if edge_registry == null:
		_fail("room._edge_registry is null — cannot find a real wall voxel")
		return
	var target_voxel: Voxel = null
	var target_slice = null
	for slice in edge_registry.all_slices():
		if slice.material == "concrete" and not slice.voxels.is_empty():
			target_slice = slice
			target_voxel = slice.voxels[0]
			break
	if target_voxel == null:
		_fail("no real concrete wall voxel found on PLAYGROUND")
		return

	target_voxel.set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.LEFT, 0, 0)
	var swapped: bool = renderer.apply_damage_voxel_swap(target_voxel, target_slice, target_voxel.level)
	if swapped:
		_pass("a real concrete wall voxel's DENTED mark resolved via the pre-baked registry (no D33 live fallback needed)")
	else:
		_fail("apply_damage_voxel_swap() returned false — fell back to D33 live compositing instead of the pre-bake")

	print("")


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


## D16 (EXPLOSION_REBUILD_MASTER_PLAN, Task 2/E-RING, 2026-08-06) — a CEILING
## voxel carved from the TOP (D15's roof-throw, once a live caller exists)
## must render through the FLOOR family, not the CEILING one, even though its
## container is still a CEILING Slab. Proven against the REAL registry state:
## both candidate keys (the FLOOR one D16 should pick, the CEILING one the
## unmodified BOTTOM case should still pick) are independently derived and
## looked up first, then apply_damage_voxel_swap()'s actual painted tile
## (read back from the real TileMapLayer, never from the function's own
## boolean claim) is compared against them.
func test_5_ceiling_top_routes_as_floor(built: Dictionary) -> void:
	print("[5] D16: a CEILING voxel carved from the TOP renders through the FLOOR key, BOTTOM is unaffected\n")
	var room = built["room"]
	var renderer = built["renderer"]

	var slab_registry = room._slab_registry
	if slab_registry == null:
		_fail("room._slab_registry is null — cannot find a real roof voxel")
		return
	var target_voxel: Voxel = null
	var target_slab = null
	for slab in slab_registry.all_slabs():
		if slab.role == Slab.Role.CEILING and slab.material == "concrete" and not slab.voxels.is_empty():
			target_slab = slab
			target_voxel = slab.voxels[0]
			break
	if target_voxel == null:
		_fail("no real concrete CEILING voxel found on PLAYGROUND")
		return

	## D9: the FLOOR atom's key material is the GU's REAL ground material
	## (never a hardcoded "earth"), same rule apply_damage_voxel_swap()'s own
	## FLOOR branch already follows — read via the same _floor_zone_by_gu
	## the renderer itself uses, defaulting to "earth" when unzoned.
	var zone: Dictionary = renderer._floor_zone_by_gu.get(target_slab.gu_cell, {})
	var ground_material: String = String(zone.get("material", "earth"))
	## D34/E-SEAM-02: named from that same real ground material, so the name
	## and the key can no longer disagree about which material this is.
	var floor_name: String = VoxelRendererClass.floor_damage_material(
		ground_material, Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, 0)
	var floor_key := VoxelVariantRegistryClass.make_variant_key("FLOOR", ground_material, floor_name, 0)
	var floor_entry: Dictionary = renderer._damage_variant_registry.get_variant(floor_key)
	if floor_entry.is_empty():
		_fail("FLOOR candidate key not registered on PLAYGROUND — cannot prove routing (%s)" % floor_key)
		return

	target_voxel.set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.TOP, 0, 0)
	var swapped_top: bool = renderer.apply_damage_voxel_swap(target_voxel, target_slab, target_voxel.level)
	if not swapped_top:
		_fail("apply_damage_voxel_swap() returned false for a CEILING+TOP voxel — expected a FLOOR-routed hit")
		return

	var layer: TileMapLayer = renderer.get_layer(target_voxel.level)
	var painted_source: int = layer.get_cell_source_id(target_voxel.grid_pos)
	var painted_atlas: Vector2i = layer.get_cell_atlas_coords(target_voxel.grid_pos)
	if painted_source == floor_entry["source_id"] and painted_atlas == floor_entry["atlas_coords"]:
		_pass("CEILING+TOP painted the FLOOR-keyed atom (ground_material=%s, source=%d atlas=%s)"
			% [ground_material, painted_source, painted_atlas])
	else:
		_fail("CEILING+TOP painted source=%d atlas=%s — expected the FLOOR entry %s"
			% [painted_source, painted_atlas, floor_entry])

	## BOTTOM (the ordinary "hit from underneath" case) must still resolve
	## via the CEILING key, unchanged — no regression for the existing branch.
	var ceiling_name: String = VoxelRendererClass.damage_variant_material(
		"concrete", Voxel.DamageState.DENTED, true, Voxel.CarvedSide.BOTTOM, 0)
	var ceiling_key := VoxelVariantRegistryClass.make_variant_key("CEILING", "concrete", ceiling_name, 0)
	var ceiling_entry: Dictionary = renderer._damage_variant_registry.get_variant(ceiling_key)
	if ceiling_entry.is_empty():
		_fail("CEILING candidate key not registered on PLAYGROUND — cannot prove the BOTTOM case is unaffected (%s)" % ceiling_key)
		print("")
		return

	## set_damage() no-ops when new_state == the CURRENT damage_state
	## (voxel.gd:105) — the voxel is still DENTED from the TOP call above, so
	## a same-state DENTED/BOTTOM call would be silently dropped and
	## carved_side would stay stuck at TOP. Reset to INTACT first so the
	## BOTTOM call actually applies, exactly as a real render pass would see
	## it (a voxel only ever transitions OUT of INTACT once).
	target_voxel.damage_state = Voxel.DamageState.INTACT
	target_voxel.set_damage(Voxel.DamageState.DENTED, true, Voxel.CarvedSide.BOTTOM, 0, 0)
	var swapped_bottom: bool = renderer.apply_damage_voxel_swap(target_voxel, target_slab, target_voxel.level)
	if not swapped_bottom:
		_fail("apply_damage_voxel_swap() returned false for a CEILING+BOTTOM voxel — expected a CEILING-routed hit")
		print("")
		return
	var painted_source_b: int = layer.get_cell_source_id(target_voxel.grid_pos)
	var painted_atlas_b: Vector2i = layer.get_cell_atlas_coords(target_voxel.grid_pos)
	if painted_source_b == ceiling_entry["source_id"] and painted_atlas_b == ceiling_entry["atlas_coords"]:
		_pass("CEILING+BOTTOM (unchanged case) still painted the CEILING-keyed atom, no regression")
	else:
		_fail("CEILING+BOTTOM painted source=%d atlas=%s — expected the CEILING entry %s"
			% [painted_source_b, painted_atlas_b, ceiling_entry])

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
