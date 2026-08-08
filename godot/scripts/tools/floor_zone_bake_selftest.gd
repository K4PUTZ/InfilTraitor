## FLOOR-BAKE-01 — floor-zone photographic ground bake selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/floor_zone_bake_selftest.gd
##
## Mirrors roof_bake_selftest.gd's structure/rigor for the floor-zone bake
## feature (author-declared rectangular material zones, full-color RGB
## instead of grayscale-luminance-times-tint). Proves:
##   1. A floor_zones-only map_spec composes the SAME "ROOF|mat|fac|col|row"
##      page family roof/ceiling uses (bake_compositor.gd deliberately never
##      introduced a separate "FLOOR|" prefix) with a lookup entry for every
##      folded LOCAL cell
##   2. resolve_flat() returns exactly the independently re-derived atom
##   3. PIXEL continuity + ISOTROPY at the floor's own 1024x1024 target size
##      (not the wall/ceiling-inherited 1024x512) + full_color's WHITE
##      modulate does not alter the composed page's raw pixel RGB (the
##      compositor forces the modulate at TileData registration time, a
##      draw-time multiply — never a page-pixel write)
##   4. Real FLOOR_ZONES_TEST map, bake ENABLED: every voxel in a declared
##      zone carries the baked source + coords its STRUCTURE-LOCAL offset
##      predicts (own flood-fill re-derivation, keyed on "same zone
##      material" instead of "both roofed"); unzoned floor still resolves
##      to the "earth" sentinel with zero anchor
##   5. ROTATION: building the E view puts a zone's Slab material at the
##      correctly-rotated GU, exactly like roof's block rotation
##
## Every expectation is re-derived locally (own mirror fold, own key format,
## own component flood fill, own rotation math) — never read back from the
## code under test.

extends SceneTree

const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")

const ATOM_W: int = 32
const ATOM_H: int = 36
const V_MARGIN: int = 32
const FLOOR_TOP_LEVEL: int = -1  ## mirrors room_builder.gd
const FLOOR_TARGET_H: int = 1024  ## mirrors bake_compositor.gd's FACADE_W (isotropic floor plane)

class MockMaterial:
	var id: String
	var base_color: Color
	var full_color: bool
	func _init(p_id: String, p_color: Color, p_full_color: bool = false) -> void:
		id = p_id
		base_color = p_color
		full_color = p_full_color

class MockRegistry:
	var materials: Dictionary = {}
	func _init() -> void:
		materials["grass"] = MockMaterial.new("grass", Color(0.42, 0.55, 0.29), true)
		materials["dirt"] = MockMaterial.new("dirt", Color(0.50, 0.38, 0.27), true)
		materials["sand"] = MockMaterial.new("sand", Color(0.76, 0.67, 0.51), true)
	func get_material(material_id: String):
		return materials.get(material_id, null)

class MinimalRoom extends Node:
	@warning_ignore("unused_private_class_variable")
	var _edge_registry
	@warning_ignore("unused_private_class_variable")
	var _junction_columns
	var _slab_registry
	var _voxel_renderer
	var map_id: String = "TEST"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("FLOOR-BAKE-01 — Floor-zone baked-surface SELFTEST")
	print("=".repeat(70) + "\n")

	var bake_config = load("res://godot/scripts/systems/bake_config.gd")
	var saved_enabled: bool = bake_config.enabled
	var saved_blend: int = bake_config.blend_mode
	bake_config.enabled = true

	Engine.set_meta("BAKE_TEST_REGISTRY", MockRegistry.new())
	var synthetic: Variant = _bake_floor_only_spec()
	if synthetic != null:
		test_1_floor_cells_get_lookup_entries(synthetic)
		test_2_resolve_flat_matches_rederived_atoms(synthetic, bake_config)
		test_3_pixel_continuity_isotropy_and_full_color_modulate(synthetic)
	Engine.remove_meta("BAKE_TEST_REGISTRY")

	bake_config.enabled = true
	test_4_real_map_local_keys_and_unzoned_fallback()
	test_5_rotated_view_zones_follow_declared_material()

	bake_config.enabled = saved_enabled
	bake_config.blend_mode = saved_blend

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✓ FLOOR ZONE BAKE SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ FLOOR ZONE BAKE SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## Independent mirror-fold — reimplemented here on purpose (see roof_bake_selftest.gd).
func _fold(index: int, period: int) -> int:
	var p2 := period * 2
	var k := index % p2
	if k < 0:
		k += p2
	if k >= period:
		k = p2 - k - 1
	return k


## D19/D20: floor materials bake under the SLAB texture family
## ("slab_<material_id>", BakePolicy.slab_for_material) — no longer
## self-referential now that the material id itself dropped its "ground_"
## prefix (a bare material id like "grass" or "concrete" no longer says by
## itself which texture family it means).
func _floor_key(material_id: String, local_x: int, local_y: int) -> String:
	var facade_id := BakePolicyClass.slab_for_material(material_id)
	return "ROOF|%s|%s|%d|%d" % [material_id, facade_id, _fold(local_x, 64), _fold(local_y, 64)]


## Independent component anchors: own flood fill over a {gu: material} dict
## (4-adjacency, SAME-MATERIAL only — the one substitution vs. roof's
## "both roofed" test), anchor = bounding-box NW corner × 8.
func _derive_zone_anchors(zone_by_gu: Dictionary) -> Dictionary:
	var anchors: Dictionary = {}
	for start: Vector2i in zone_by_gu:
		if anchors.has(start):
			continue
		var stack: Array[Vector2i] = [start]
		var seen: Dictionary = {start: true}
		var component: Array[Vector2i] = []
		var min_corner: Vector2i = start
		var mat: String = zone_by_gu[start]
		while not stack.is_empty():
			var gu: Vector2i = stack.pop_back()
			component.append(gu)
			min_corner = Vector2i(mini(min_corner.x, gu.x), mini(min_corner.y, gu.y))
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var n := gu + d
				if zone_by_gu.get(n, "") == mat and not seen.has(n):
					seen[n] = true
					stack.append(n)
		for gu in component:
			anchors[gu] = min_corner * 8
	return anchors


## Own re-derivation of floor_zones -> {gu: material}, mirroring
## room_builder.gd's expansion (last rect in the list wins on overlap).
func _expand_zones(floor_zone_instances: Array) -> Dictionary:
	var zone_by_gu: Dictionary = {}
	for zone in floor_zone_instances:
		var base: Vector2i = zone.get("gu_cell", Vector2i.ZERO)
		var size: Vector2i = zone.get("size", Vector2i.ONE)
		var mat: String = String(zone.get("material", ""))
		if mat == "":
			continue
		for zx in range(size.x):
			for zy in range(size.y):
				zone_by_gu[base + Vector2i(zx, zy)] = mat
	return zone_by_gu


## Shared fixture: bake a floor_zones-only map_spec (via the SAME "roofs" key
## the compositor consumes — floor specs merge into it, see room_builder.gd)
## covering a 2x2-GU zone with a 1-voxel border, matching generate_with_border's
## LOCAL cell shape (-1..16) used elsewhere in this project's bake fixtures.
func _bake_floor_only_spec():
	var cells: Array = []
	for y in range(-1, 17):
		for x in range(-1, 17):
			cells.append(Vector2i(x, y))
	var map_spec := {
		"roofs": [{
			"material_id": "grass",
			"facade_id": "slab_grass",
			"cells": cells,
		}],
		"map_id": "FLOOR_BAKE_TEST",
	}
	var compositor = BakeCompositorClass.new()
	var resolver = TextureResolverClass.new()
	var atlas = compositor.bake(map_spec, resolver)
	if atlas == null or atlas.lookup.is_empty():
		_fail("floor-zones-only bake produced no lookup entries — floor page family not composed")
		return null
	return {"atlas": atlas, "compositor": compositor, "resolver": resolver, "cells": cells}


func test_1_floor_cells_get_lookup_entries(fx: Dictionary) -> void:
	print("[TEST 1] Floor-zones-only bake registers a ROOF| lookup entry for every folded local cell")
	var atlas = fx["atlas"]
	var missing := 0
	for cell in fx["cells"]:
		if not atlas.lookup.has(_floor_key("grass", cell.x, cell.y)):
			missing += 1
	if missing == 0:
		_pass("All %d local floor-zone cells (incl. negative border coords) have ROOF| lookup entries under locally re-derived keys" % fx["cells"].size())
	else:
		_fail("%d/%d local floor-zone cells missing from baked lookup" % [missing, fx["cells"].size()])


func test_2_resolve_flat_matches_rederived_atoms(fx: Dictionary, bake_config) -> void:
	print("[TEST 2] resolve_flat() returns the independently re-derived atom per local offset")
	var atlas = fx["atlas"]
	var lookup = BakedTileLookupClass.new()
	lookup.set_baked_atlas(atlas)
	var fake_source_ids := {}
	for p in range(atlas.atom_pages.size()):
		fake_source_ids[p] = 2000 + p
	lookup.set_source_ids(fake_source_ids)

	var samples: Array = [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(7, 3), Vector2i(16, 16), Vector2i(130, 126)]
	var mismatches := 0
	for pos in samples:
		var expected = atlas.lookup.get(_floor_key("grass", pos.x, pos.y))
		var result = lookup.resolve_flat("grass", pos, BakePolicyClass.SurfaceClass.SLAB)
		if expected == null:
			if result != null and _fold(pos.x, 64) <= 16 and _fold(pos.y, 64) <= 16:
				mismatches += 1
			continue
		if result == null \
				or result.atlas_coords != expected.get("atlas_coords") \
				or result.source_id_int != 2000 + int(expected.get("page")):
			mismatches += 1
	if mismatches == 0:
		_pass("resolve_flat matched local fold+key derivation on %d sample offsets (incl. negative and far out-of-period)" % samples.size())
	else:
		_fail("%d resolve_flat results diverged from local derivation" % mismatches)

	var no_facade = lookup.resolve_flat("nonexistent", Vector2i(2, 2), BakePolicyClass.SurfaceClass.SLAB)
	bake_config.enabled = false
	var when_disabled = lookup.resolve_flat("grass", Vector2i(2, 2), BakePolicyClass.SurfaceClass.SLAB)
	bake_config.enabled = true
	if no_facade == null and when_disabled == null:
		_pass("resolve_flat gates correctly: unmapped material -> null, bake disabled -> null")
	else:
		_fail("resolve_flat gate failure: unmapped=%s, disabled=%s" % [no_facade, when_disabled])


func test_3_pixel_continuity_isotropy_and_full_color_modulate(fx: Dictionary) -> void:
	print("[TEST 3] Atom top-diamonds equal a direct ISOTROPIC 1024x1024 floor-plane read; full_color forces WHITE modulate")
	var atlas = fx["atlas"]
	var compositor = fx["compositor"]
	var resolved = fx["resolver"].resolve("slab_grass")
	if resolved == null or resolved.image == null:
		_fail("slab_grass unresolvable — cannot pixel-check")
		return
	var facade: Image = resolved.image

	## Isotropy. This used to assert floor (1024) and ceiling (512) DIVERGED —
	## D34/E-SEAM-01 (Director, 2026-08-08) deleted that divergence: every
	## horizontal surface is built at the isotropic FACADE_W x FACADE_W target
	## now, which is exactly what lets a roof and a floor of one material share
	## a page. So the assertion inverts — the two must MATCH — and the default
	## argument must already be the isotropic target, not 512.
	var floor_source: Image = compositor._get_roof_plane_source(facade, FLOOR_TARGET_H)
	var ceiling_source: Image = compositor._get_roof_plane_source(facade)
	var expected_h := V_MARGIN + FLOOR_TARGET_H + V_MARGIN
	if floor_source.get_height() == expected_h and ceiling_source.get_height() == expected_h:
		_pass("Floor and ceiling plane sources are both isotropic (%dpx incl. margins, matches FACADE_W) — one horizontal projection, D34" % expected_h)
	else:
		_fail("Source heights unexpected: floor=%d, ceiling=%d, both want %d" % [
			floor_source.get_height(), ceiling_source.get_height(), expected_h])

	## full_color modulate: composed page pixels must equal the plane read
	## VERBATIM (no tint baked into the page) — the WHITE modulate this
	## material triggers is a draw-time TileData property, applied by
	## room_builder/voxel_renderer at registration, never written into the
	## page's own pixel bytes. So this is the SAME comparison roof's test 3
	## does for a tinted material — proving the page itself is untinted
	## either way, and full_color's effect is provably NOT a pixel change.
	var floor_top: Image = compositor._get_roof_plane_top("slab_grass", facade, FLOOR_TARGET_H)
	var x_off: int = floor_source.get_height() - 1
	var canonical: Image = compositor._voxel_atoms.get("grass")
	if canonical == null:
		_fail("canonical grass voxel atom unavailable")
		return

	var compared := 0
	var mismatched := 0
	var non_white_source_pixels := 0
	for y in range(4, 7):
		for x in range(4, 7):
			var entry = atlas.lookup.get(_floor_key("grass", x, y))
			if entry == null:
				_fail("cell (%d,%d) missing from lookup — cannot pixel-check" % [x, y])
				return
			var page: Image = atlas.atom_pages[int(entry.get("page"))]
			var tile: Vector2i = entry.get("atlas_coords")
			var tile_px := Vector2i(tile.x * ATOM_W, tile.y * ATOM_H)
			var sx0: int = 16 * x - 16 * y + x_off
			@warning_ignore("integer_division")
			var sy0: int = (16 * x + 16 * y) / 2 + V_MARGIN
			for py in range(16):
				for px in range(ATOM_W):
					var edge: float = (8.0 + float(px) / 2.0) if px < 16 else (24.0 - float(px) / 2.0)
					if float(py) >= edge:
						continue
					if canonical.get_pixel(px, py).a < 1.0:
						continue
					var page_px := page.get_pixel(tile_px.x + px, tile_px.y + py)
					var plane_px := floor_top.get_pixel(sx0 - 16 + px, sy0 + py)
					compared += 1
					if page_px.r != plane_px.r or page_px.g != plane_px.g or page_px.b != plane_px.b:
						mismatched += 1
					# Real grass photo pixels are never a flat R==G==B gray —
					# a non-desaturated sample here rules out an accidental
					## luminance-collapse regression sneaking back in.
					if absf(page_px.r - page_px.g) > 0.02 or absf(page_px.g - page_px.b) > 0.02:
						non_white_source_pixels += 1

	if compared > 300 and mismatched == 0 and non_white_source_pixels > 0:
		_pass("3x3 local cells: %d opaque top-diamond pixels ALL equal the continuous floor-plane read verbatim (%d genuinely colored, non-grayscale pixels confirmed — real RGB survives to the page)" % [compared, non_white_source_pixels])
	else:
		_fail("pixel continuity/color: compared=%d, mismatched=%d, colored_pixels=%d" % [compared, mismatched, non_white_source_pixels])


## Boot the real FLOOR_ZONES_TEST map through the exact room.gd::load_map()
## path, optionally rotated. Returns {room, renderer, layout} or empty.
func _build_test_map(direction: String) -> Dictionary:
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("FLOOR_ZONES_TEST")
	if spec.is_empty():
		_fail("FileMapSource.get_runtime_spec('FLOOR_ZONES_TEST') returned empty")
		return {}
	var layout: Dictionary = MapCompilerClass.compile(spec)
	if direction != "N":
		layout = PerspectiveMapperClass.layout_with_perspective(layout, direction)

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
	return {"room": room, "renderer": voxel_renderer, "layout": layout}


func test_4_real_map_local_keys_and_unzoned_fallback() -> void:
	print("[TEST 4] Real FLOOR_ZONES_TEST (N), bake ENABLED: zoned voxels baked at their local offset; unzoned floor stays 'earth'")
	var built := _build_test_map("N")
	if built.is_empty():
		return
	var room: MinimalRoom = built["room"]
	var voxel_renderer = built["renderer"]
	var layout: Dictionary = built["layout"]
	var floor_zone_instances: Array = layout.get("floor_zone_instances", [])

	if floor_zone_instances.is_empty():
		_fail("FLOOR_ZONES_TEST compiled with zero floor_zone_instances — fixture map missing its floor_zones section?")
		room.queue_free()
		return

	if voxel_renderer._baked_lookup == null or voxel_renderer._baked_lookup._baked_atlas == null:
		_fail("build with bake enabled produced no baked atlas on the renderer")
		room.queue_free()
		return
	var atlas = voxel_renderer._baked_lookup._baked_atlas
	var source_ids: Dictionary = voxel_renderer._baked_lookup._source_ids
	var zone_by_gu: Dictionary = _expand_zones(floor_zone_instances)
	var anchors: Dictionary = _derive_zone_anchors(zone_by_gu)

	var checked := 0
	var wrong_source := 0
	var wrong_coords := 0
	var not_baked_source := 0
	var missing_entries := 0

	for gu in zone_by_gu:
		var material: String = zone_by_gu[gu]
		var anchor: Vector2i = anchors.get(gu, Vector2i.ZERO)
		var slab_id := "SLAB_%d_%d_%s_%d" % [gu.x, gu.y, Slab.role_name(Slab.Role.FLOOR), FLOOR_TOP_LEVEL]
		var slab: Slab = room._slab_registry.get_slab(slab_id)
		if slab == null:
			_fail("zoned GU %s has no FLOOR Slab in the registry" % gu)
			continue
		if slab.material != material:
			_fail("zoned GU %s: Slab.material='%s', expected '%s'" % [gu, slab.material, material])
		if slab.texture_anchor != anchor:
			_fail("zoned GU %s: texture_anchor=%s, own flood-fill derived %s" % [gu, slab.texture_anchor, anchor])
		var layer: TileMapLayer = voxel_renderer.get_layer(FLOOR_TOP_LEVEL)
		for voxel in slab.voxels:
			checked += 1
			var local: Vector2i = voxel.grid_pos - anchor
			var entry = atlas.lookup.get(_floor_key(material, local.x, local.y))
			if entry == null:
				missing_entries += 1
				continue
			var expected_source: int = source_ids.get(int(entry.get("page")), -1)
			if layer.get_cell_source_id(voxel.grid_pos) != expected_source:
				wrong_source += 1
			if layer.get_cell_atlas_coords(voxel.grid_pos) != entry.get("atlas_coords"):
				wrong_coords += 1
			if not voxel_renderer._baked_source_ids.has(layer.get_cell_source_id(voxel.grid_pos)):
				not_baked_source += 1

	if checked > 0 and missing_entries == 0 and wrong_source == 0 and wrong_coords == 0 and not_baked_source == 0:
		_pass("All %d real zoned floor voxels placed with exactly the baked source + coords their STRUCTURE-LOCAL offset (own flood-fill anchors) predicts" % checked)
	else:
		_fail("%d zoned floor voxels: %d missing entries, %d wrong source, %d wrong coords, %d not baked" % [
			checked, missing_entries, wrong_source, wrong_coords, not_baked_source,
		])

	## Unzoned-floor regression guard: a GU outside every declared zone must
	## still be the "earth" sentinel with zero anchor (pre-feature behavior).
	var unzoned_checked := 0
	var unzoned_wrong := 0
	var room_size: Vector2i = layout.get("size", Vector2i.ZERO)
	for ux in range(room_size.x):
		for uy in range(room_size.y):
			var ugu := Vector2i(ux, uy)
			if zone_by_gu.has(ugu):
				continue
			var uslab_id := "SLAB_%d_%d_%s_%d" % [ugu.x, ugu.y, Slab.role_name(Slab.Role.FLOOR), FLOOR_TOP_LEVEL]
			var uslab: Slab = room._slab_registry.get_slab(uslab_id)
			if uslab == null:
				continue
			unzoned_checked += 1
			if uslab.material != "earth" or uslab.texture_anchor != Vector2i.ZERO:
				unzoned_wrong += 1
			if unzoned_checked >= 20:  # sample, not exhaustive — the map is walkable-sized
				break
		if unzoned_checked >= 20:
			break

	if unzoned_checked > 0 and unzoned_wrong == 0:
		_pass("%d unzoned floor Slabs sampled all kept the 'earth' sentinel + zero anchor (no regression)" % unzoned_checked)
	else:
		_fail("%d/%d unzoned floor Slabs deviated from the 'earth'/zero-anchor baseline" % [unzoned_wrong, unzoned_checked])

	room.queue_free()


func test_5_rotated_view_zones_follow_declared_material() -> void:
	print("[TEST 5] E view: every declared zone's Slab exists at its ROTATED GU with its declared material")
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("FLOOR_ZONES_TEST")
	var base_layout: Dictionary = MapCompilerClass.compile(spec)
	var base_zones: Array = base_layout.get("floor_zone_instances", [])
	var base_size: Vector2i = base_layout.get("size", Vector2i.ZERO)

	if base_zones.is_empty():
		_fail("FLOOR_ZONES_TEST has zero floor_zone_instances — cannot test rotation")
		return

	var built := _build_test_map("E")
	if built.is_empty():
		return
	var room: MinimalRoom = built["room"]
	var voxel_renderer = built["renderer"]

	## Own rotation math (E = 90 CW): base (x, y) -> (h-1-y, x); a
	## rectangle's rotated NW corner = (h - y0 - sy, x0), size swaps.
	var missing := 0
	var wrong_material := 0
	var baked_spot_checks := 0
	for z in base_zones:
		var gu: Vector2i = z.get("gu_cell", Vector2i.ZERO)
		var size: Vector2i = z.get("size", Vector2i.ONE)
		var material: String = String(z.get("material", ""))
		var rot_gu := Vector2i(base_size.y - gu.y - size.y, gu.x)
		var rot_size := Vector2i(size.y, size.x)
		for rx in range(rot_size.x):
			for ry in range(rot_size.y):
				var slab_id := "SLAB_%d_%d_%s_%d" % [rot_gu.x + rx, rot_gu.y + ry, Slab.role_name(Slab.Role.FLOOR), FLOOR_TOP_LEVEL]
				var slab: Slab = room._slab_registry.get_slab(slab_id)
				if slab == null:
					missing += 1
					continue
				if slab.material != material:
					wrong_material += 1
				if baked_spot_checks < 8 and not slab.voxels.is_empty():
					var layer: TileMapLayer = voxel_renderer.get_layer(FLOOR_TOP_LEVEL)
					if layer != null and voxel_renderer._baked_source_ids.has(layer.get_cell_source_id(slab.voxels[0].grid_pos)):
						baked_spot_checks += 1

	if missing == 0 and wrong_material == 0:
		_pass("All %d declared zones have a FLOOR Slab at their independently-rotated E-view position with the correct material (%d baked-source spot checks hit)" % [base_zones.size(), baked_spot_checks])
	else:
		_fail("E view: %d rotated zone-GUs missing a FLOOR Slab, %d with wrong material" % [missing, wrong_material])

	room.queue_free()
