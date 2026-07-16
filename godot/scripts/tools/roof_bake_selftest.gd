## ROOF-BAKE-01 — roof/ceiling baked-surface selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/roof_bake_selftest.gd
##
## Proves the bake system extends to HORIZONTAL surfaces (roof slabs) through
## the existing mechanism: the compositor's top-face plane (_get_plane_top) is
## an isometric projection of a flat 2-D grid — T(u−v, (u+v)/2) — that walls
## consume as (column_in_run, level) and roofs consume as (voxel_x, voxel_y).
## Four suites:
##   1. A roofs-only map_spec bakes lookup entries for every (folded) roof cell
##   2. resolve_flat() returns exactly the independently re-derived atom
##   3. PIXEL continuity: placed atom top-diamonds equal a direct read of the
##      continuous plane_top image at the projected offset — seamlessness is
##      therefore by construction, verified on real pixels, not reasoning
##   4. Real PLAYGROUND map, bake ENABLED: every roof voxel cell carries the
##      baked source + atlas coords its position independently predicts
##
## Every expectation is re-derived locally (own mirror-fold implementation,
## own key formatting) — never read back from the code under test.

extends SceneTree

const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

const ATOM_W: int = 32
const ATOM_H: int = 36
const V_MARGIN: int = 32
const ROOF_LEVEL_COUNT: int = 2  ## mirrors room_builder.gd's placeholder

class MockMaterial:
	var id: String
	var base_color: Color
	func _init(p_id: String, p_color: Color) -> void:
		id = p_id
		base_color = p_color

class MockRegistry:
	var materials: Dictionary = {}
	func _init() -> void:
		materials["concrete"] = MockMaterial.new("concrete", Color(0.6, 0.6, 0.6))
		materials["stone"] = MockMaterial.new("stone", Color(0.6, 0.55, 0.5))
		materials["wood"] = MockMaterial.new("wood", Color(0.5, 0.3, 0.1))
		materials["metal"] = MockMaterial.new("metal", Color(0.7, 0.7, 0.75))
	func get_material(material_id: String):
		return materials.get(material_id, null)

class MinimalRoom extends Node:
	var _edge_registry
	var _junction_columns
	var _slab_registry
	var _voxel_renderer
	var map_id: String = "TEST"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("ROOF-BAKE-01 — Roof baked-surface SELFTEST")
	print("=".repeat(70) + "\n")

	var bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var saved_enabled: bool = bake_config.enabled
	var saved_blend: int = bake_config.blend_mode
	bake_config.enabled = true

	Engine.set_meta("BAKE_TEST_REGISTRY", MockRegistry.new())
	var synthetic: Variant = _bake_roofs_only_spec()
	if synthetic != null:
		test_1_roof_cells_get_lookup_entries(synthetic)
		test_2_resolve_flat_matches_rederived_atoms(synthetic, bake_config)
		test_3_pixel_continuity_against_plane_top(synthetic)
	Engine.remove_meta("BAKE_TEST_REGISTRY")

	bake_config.enabled = true
	test_4_real_playground_roofs_are_baked()

	bake_config.enabled = saved_enabled
	bake_config.blend_mode = saved_blend

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ ROOF BAKE SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ ROOF BAKE SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## Independent mirror-fold — reimplemented here on purpose; must NOT call the
## production fold so a production fold bug cannot self-verify.
func _fold(index: int, period: int) -> int:
	var p2 := period * 2
	var k := index % p2
	if k < 0:
		k += p2
	if k >= period:
		k = p2 - k - 1
	return k


func _roof_key(material_id: String, x: int, y: int) -> String:
	return "%s|facade_%s|%d|%d|0" % [material_id, material_id, _fold(x, 64), _fold(y, 32)]


## Shared fixture: bake a roofs-only map_spec (no walls at all) covering a
## 2×2-GU roof with a 1-voxel border — cells (-1..16) × (-1..16), negative
## coords included, exactly the shape generate_with_border() produces.
func _bake_roofs_only_spec():
	var cells: Array = []
	for y in range(-1, 17):
		for x in range(-1, 17):
			cells.append(Vector2i(x, y))
	var map_spec := {
		"roofs": [{
			"material_id": "concrete",
			"facade_id": "facade_concrete",
			"cells": cells,
		}],
		"map_id": "ROOF_BAKE_TEST",
	}
	var compositor = BakeCompositorClass.new()
	var resolver = TextureResolverClass.new()
	var atlas = compositor.bake(map_spec, resolver)
	if atlas == null or atlas.lookup.is_empty():
		_fail("roofs-only bake produced no lookup entries — combo/usage extraction ignored the roofs section")
		return null
	return {"atlas": atlas, "compositor": compositor, "resolver": resolver, "cells": cells}


func test_1_roof_cells_get_lookup_entries(fx: Dictionary) -> void:
	print("[TEST 1] Roofs-only bake registers a lookup entry for every folded roof cell")
	var atlas = fx["atlas"]
	var missing := 0
	for cell in fx["cells"]:
		if not atlas.lookup.has(_roof_key("concrete", cell.x, cell.y)):
			missing += 1
	if missing == 0:
		_pass("All %d roof cells (incl. negative border coords) have baked lookup entries under locally re-derived keys" % fx["cells"].size())
	else:
		_fail("%d/%d roof cells missing from baked lookup" % [missing, fx["cells"].size()])


func test_2_resolve_flat_matches_rederived_atoms(fx: Dictionary, bake_config) -> void:
	print("[TEST 2] resolve_flat() returns the independently re-derived atom per position")
	var atlas = fx["atlas"]
	var lookup = BakedTileLookupClass.new()
	lookup.set_baked_atlas(atlas)
	var fake_source_ids := {}
	for p in range(atlas.atom_pages.size()):
		fake_source_ids[p] = 1000 + p
	lookup.set_source_ids(fake_source_ids)

	var samples: Array = [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(7, 3), Vector2i(16, 16), Vector2i(130, 70)]
	var mismatches := 0
	for pos in samples:
		var expected = atlas.lookup.get(_roof_key("concrete", pos.x, pos.y))
		var result = lookup.resolve_flat("concrete", pos)
		if expected == null:
			# (130, 70) folds to (2, 6) — present only if some raw cell folded there
			if result != null and _fold(pos.x, 64) <= 16 and _fold(pos.y, 32) <= 16:
				mismatches += 1  # entry should have existed via fold
			continue
		if result == null \
				or result.atlas_coords != expected.get("atlas_coords") \
				or result.source_id_int != 1000 + int(expected.get("page")):
			mismatches += 1
	if mismatches == 0:
		_pass("resolve_flat matched local fold+key derivation on %d sample positions (incl. negative and far out-of-period)" % samples.size())
	else:
		_fail("%d resolve_flat results diverged from local derivation" % mismatches)

	# Gates: no facade mapping → null; disabled → null
	var no_facade = lookup.resolve_flat("earth_3", Vector2i(2, 2))
	bake_config.enabled = false
	var when_disabled = lookup.resolve_flat("concrete", Vector2i(2, 2))
	bake_config.enabled = true
	if no_facade == null and when_disabled == null:
		_pass("resolve_flat gates correctly: unmapped material → null, bake disabled → null")
	else:
		_fail("resolve_flat gate failure: unmapped=%s, disabled=%s" % [no_facade, when_disabled])


func test_3_pixel_continuity_against_plane_top(fx: Dictionary) -> void:
	print("[TEST 3] Placed atom top-diamonds equal a direct plane_top read at the projected offset")
	var atlas = fx["atlas"]
	var compositor = fx["compositor"]
	var resolved = fx["resolver"].resolve("facade_concrete")
	if resolved == null or resolved.image == null:
		_fail("facade_concrete unresolvable — cannot pixel-check")
		return
	var facade: Image = resolved.image
	var plane_top: Image = compositor._get_plane_top("facade_concrete", facade, 0)
	var plane_source: Image = compositor._get_plane_source(facade, 0)
	var x_off: int = plane_source.get_height() - 1
	var canonical: Image = compositor._voxel_atoms.get("concrete")
	if canonical == null:
		_fail("canonical concrete voxel atom unavailable")
		return

	var compared := 0
	var mismatched := 0
	var luminances := {}
	for y in range(4, 7):
		for x in range(4, 7):
			var entry = atlas.lookup.get(_roof_key("concrete", x, y))
			if entry == null:
				_fail("cell (%d,%d) missing from lookup — cannot pixel-check" % [x, y])
				return
			var page: Image = atlas.atom_pages[int(entry.get("page"))]
			var tile: Vector2i = entry.get("atlas_coords")
			var tile_px := Vector2i(tile.x * ATOM_W, tile.y * ATOM_H)
			var sx0: int = 16 * x - 16 * y + x_off
			var sy0: int = (16 * x + 16 * y) / 2 + V_MARGIN
			for py in range(16):
				for px in range(ATOM_W):
					var edge: float = (8.0 + float(px) / 2.0) if px < 16 else (24.0 - float(px) / 2.0)
					if float(py) >= edge:
						continue  # outside the top diamond
					if canonical.get_pixel(px, py).a < 1.0:
						continue  # AA rim pixels carry fixed-up alpha, skip
					var page_px := page.get_pixel(tile_px.x + px, tile_px.y + py)
					var plane_px := plane_top.get_pixel(sx0 - 16 + px, sy0 + py)
					compared += 1
					luminances[snappedf(plane_px.r, 0.004)] = true
					if page_px.r != plane_px.r or page_px.g != plane_px.g or page_px.b != plane_px.b:
						mismatched += 1

	if compared > 500 and mismatched == 0 and luminances.size() >= 2:
		_pass("3×3 roof cells: %d opaque top-diamond pixels ALL equal the continuous plane_top read (%d distinct luminances — not a blank-vs-blank match)" % [compared, luminances.size()])
	else:
		_fail("pixel continuity: compared=%d, mismatched=%d, distinct_luminances=%d" % [compared, mismatched, luminances.size()])


func test_4_real_playground_roofs_are_baked() -> void:
	print("[TEST 4] Real PLAYGROUND map, bake ENABLED: every roof voxel carries its predicted baked tile")
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("PLAYGROUND")
	if spec.is_empty():
		_fail("FileMapSource.get_runtime_spec('PLAYGROUND') returned empty")
		return
	var layout: Dictionary = MapCompilerClass.compile(spec)
	var solid_block_instances: Array = layout.get("solid_block_instances", [])
	if solid_block_instances.is_empty():
		_fail("PLAYGROUND has no solid_block_instances — nothing to verify")
		return

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

	if voxel_renderer._baked_lookup == null or voxel_renderer._baked_lookup._baked_atlas == null:
		_fail("build with bake enabled produced no baked atlas on the renderer")
		room.queue_free()
		return
	var atlas = voxel_renderer._baked_lookup._baked_atlas
	var source_ids: Dictionary = voxel_renderer._baked_lookup._source_ids

	var checked := 0
	var wrong_source := 0
	var wrong_coords := 0
	var not_baked_source := 0
	var missing_entries := 0
	for block_instance in solid_block_instances:
		var gu_base: Vector2i = block_instance.get("gu_cell", Vector2i.ZERO)
		var size: Vector2i = block_instance.get("size", Vector2i.ONE)
		var storeys: int = int(block_instance.get("storeys", 1))
		var material: String = String(block_instance.get("material", "concrete"))
		var base_level: int = storeys * GeometryCoordsClass.LEVELS_PER_STOREY
		for rx in range(size.x):
			for ry in range(size.y):
				var gu := gu_base + Vector2i(rx, ry)
				for level in range(base_level, base_level + ROOF_LEVEL_COUNT):
					var slab_id := "SLAB_%d_%d_%s_%d" % [gu.x, gu.y, Slab.role_name(Slab.Role.CEILING), level]
					var slab: Slab = room._slab_registry.get_slab(slab_id)
					if slab == null:
						continue  # geometry coverage is roof_integration_selftest's job
					var layer: TileMapLayer = voxel_renderer.get_layer(level)
					for voxel in slab.voxels:
						checked += 1
						var entry = atlas.lookup.get(_roof_key(material, voxel.grid_pos.x, voxel.grid_pos.y))
						if entry == null:
							missing_entries += 1
							continue
						var expected_source: int = source_ids.get(int(entry.get("page")), -1)
						var placed_source: int = layer.get_cell_source_id(voxel.grid_pos)
						var placed_coords: Vector2i = layer.get_cell_atlas_coords(voxel.grid_pos)
						if placed_source != expected_source:
							wrong_source += 1
						if placed_coords != entry.get("atlas_coords"):
							wrong_coords += 1
						if not voxel_renderer._baked_source_ids.has(placed_source):
							not_baked_source += 1

	if checked > 0 and missing_entries == 0 and wrong_source == 0 and wrong_coords == 0 and not_baked_source == 0:
		_pass("All %d real roof voxels (both levels, %d blocks) placed with exactly the baked source + atlas coords their global (x, y) independently predicts" % [checked, solid_block_instances.size()])
	else:
		_fail("%d roof voxels checked: %d missing lookup entries, %d wrong source, %d wrong coords, %d not from a baked atlas source" % [
			checked, missing_entries, wrong_source, wrong_coords, not_baked_source,
		])

	room.queue_free()
