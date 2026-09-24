## ROOF-BAKE-01/02 — roof/ceiling baked-surface selftest.
## Rodar: godot --headless --script res://godot/scripts/tools/roof_bake_selftest.gd
##
## Proves the ROOF-BAKE-02 contract end-to-end:
##   1. A roofs-only map_spec composes the dedicated roof page family with a
##      "ROOF|mat|fac|col|row" lookup entry for every (folded) LOCAL cell
##   2. resolve_flat() returns exactly the independently re-derived atom
##   3. PIXEL continuity + ISOTROPY: placed atom top-diamonds equal a direct
##      read of the roof plane (built from the UNSCALED facade — no wall
##      ×20/16 pre-scale) at the projected offset
##   4. (R3D-END, END-1: deleted. It read the baked TILE every roof voxel was placed as on a real load; the load no
##      longer bakes and no tile is written. [1]-[3] drive the compositor directly and go with it at END-4.)
##   5. ROTATION (02a): building the E view puts a roof Slab of the right
##      material at every block's ROTATED position
##
## Every expectation is re-derived locally (own mirror fold, own key format,
## own component flood fill, own rotation math) — never read back from the
## code under test.

extends SceneTree

const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const RoomBuilderClass = preload("res://godot/scripts/world/builders/room_builder.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const PerspectiveMapperClass = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")

const ATOM_W: int = 32
const ATOM_H: int = 36
const V_MARGIN: int = 32
const ROOF_LEVEL_COUNT: int = 2  ## mirrors room_builder.gd's placeholder

class MockMaterial:
	var id: String
	var base_color: Color
	var full_color: bool = false  ## mirrors MaterialRegistry.MaterialDef's floor-bake flag
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
	## Assigned duck-typed by room_builder during build_from_layout — the
	## "unused" reading is a false positive.
	@warning_ignore("unused_private_class_variable")
	var _edge_registry
	@warning_ignore("unused_private_class_variable")
	var _junction_columns
	var _slab_registry
	var _voxel_renderer
	@warning_ignore("unused_private_class_variable")
	var _wall_height_edges
	var map_id: String = "TEST"

var passed: int = 0
var failed: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("ROOF-BAKE-01/02 — Roof baked-surface SELFTEST")
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
		test_3_pixel_continuity_and_isotropy(synthetic)
	Engine.remove_meta("BAKE_TEST_REGISTRY")

	bake_config.enabled = true
	test_5_rotated_view_roofs_follow_structures()

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


## ROOF-SIDE-03: both axes fold at period 64 (the SE half consumes y as a
## dir-1 run position). ROOF-SIDE-04: no side-exposure mask — every atom
## paints both side halves (solid slabs).
func _roof_key(material_id: String, local_x: int, local_y: int) -> String:
	return "ROOF|%s|facade_%s|%d|%d" % [material_id, material_id, _fold(local_x, 64), _fold(local_y, 64)]


## Independent component anchors: own flood fill over the occupied-GU set of
## solid_block_instances (4-adjacency), anchor = bounding-box NW corner × 8.
func _derive_anchors(solid_block_instances: Array) -> Dictionary:
	var occupied: Dictionary = {}
	for b in solid_block_instances:
		var gu: Vector2i = b.get("gu_cell", Vector2i.ZERO)
		var size: Vector2i = b.get("size", Vector2i.ONE)
		for ox in range(size.x):
			for oy in range(size.y):
				occupied[gu + Vector2i(ox, oy)] = true
	var anchors: Dictionary = {}
	for start: Vector2i in occupied:
		if anchors.has(start):
			continue
		var stack: Array[Vector2i] = [start]
		var seen: Dictionary = {start: true}
		var component: Array[Vector2i] = []
		var min_corner: Vector2i = start
		while not stack.is_empty():
			var gu: Vector2i = stack.pop_back()
			component.append(gu)
			min_corner = Vector2i(mini(min_corner.x, gu.x), mini(min_corner.y, gu.y))
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var n := gu + d
				if occupied.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		for gu in component:
			anchors[gu] = min_corner * 8
	return anchors


## Shared fixture: bake a roofs-only map_spec (no walls at all) covering a
## 2×2-GU roof with a 1-voxel border — LOCAL cells (-1..16), negative coords
## included, exactly the shape generate_with_border() + anchoring produces.
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
		_fail("roofs-only bake produced no lookup entries — roof page family not composed")
		return null
	return {"atlas": atlas, "compositor": compositor, "resolver": resolver, "cells": cells}


func test_1_roof_cells_get_lookup_entries(fx: Dictionary) -> void:
	print("[TEST 1] Roofs-only bake registers a ROOF| lookup entry for every folded local cell")
	var atlas = fx["atlas"]
	var missing := 0
	for cell in fx["cells"]:
		if not atlas.lookup.has(_roof_key("concrete", cell.x, cell.y)):
			missing += 1
	if missing == 0:
		_pass("All %d local roof cells (incl. negative border coords) have ROOF| lookup entries under locally re-derived keys" % fx["cells"].size())
	else:
		_fail("%d/%d local roof cells missing from baked lookup" % [missing, fx["cells"].size()])


func test_2_resolve_flat_matches_rederived_atoms(fx: Dictionary, bake_config) -> void:
	print("[TEST 2] resolve_flat() returns the independently re-derived atom per local offset")
	var atlas = fx["atlas"]
	var lookup = BakedTileLookupClass.new()
	lookup.set_baked_atlas(atlas)
	var fake_source_ids := {}
	for p in range(atlas.atom_pages.size()):
		fake_source_ids[p] = 1000 + p
	lookup.set_source_ids(fake_source_ids)

	# ROOF-SIDE-03: far sample folds under period 64 on BOTH axes —
	# (130, 126) → (2, 1), an interior fixture cell.
	var samples: Array = [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(7, 3), Vector2i(16, 16), Vector2i(130, 126)]
	var mismatches := 0
	for pos in samples:
		var expected = atlas.lookup.get(_roof_key("concrete", pos.x, pos.y))
		var result = lookup.resolve_flat("concrete", pos)
		if expected == null:
			if result != null and _fold(pos.x, 64) <= 16 and _fold(pos.y, 64) <= 16:
				mismatches += 1  # entry should have existed via fold
			continue
		if result == null \
				or result.atlas_coords != expected.get("atlas_coords") \
				or result.source_id_int != 1000 + int(expected.get("page")):
			mismatches += 1
	if mismatches == 0:
		_pass("resolve_flat matched local fold+key derivation on %d sample offsets (incl. negative and far out-of-period)" % samples.size())
	else:
		_fail("%d resolve_flat results diverged from local derivation" % mismatches)

	var no_facade = lookup.resolve_flat("earth_3", Vector2i(2, 2))
	bake_config.enabled = false
	var when_disabled = lookup.resolve_flat("concrete", Vector2i(2, 2))
	bake_config.enabled = true
	if no_facade == null and when_disabled == null:
		_pass("resolve_flat gates correctly: unmapped material → null, bake disabled → null")
	else:
		_fail("resolve_flat gate failure: unmapped=%s, disabled=%s" % [no_facade, when_disabled])


func test_3_pixel_continuity_and_isotropy(fx: Dictionary) -> void:
	print("[TEST 3] Atom top-diamonds equal a direct ISOTROPIC roof-plane read at the projected offset")
	var atlas = fx["atlas"]
	var compositor = fx["compositor"]
	var resolved = fx["resolver"].resolve("facade_concrete", "concrete")
	if resolved == null or resolved.image == null:
		_fail("facade_concrete unresolvable — cannot pixel-check")
		return
	var facade: Image = resolved.image

	## Isotropy. D34/E-SEAM-01 (Director, 2026-08-08) RAISED this expectation:
	## the roof source used to be the facade at its own 512 height + margins
	## (576 tall), which addresses only 32 of the 64 cell rows resolve_flat()
	## folds to — the rows past that simply had no texels, invisible until now
	## only because roof structures are small (a 3 GU block is 24 voxels).
	## It is now the isotropic 1024 + margins (1088), reached by MIRRORED
	## VERTICAL REPEAT of the same facade, so pixels stay native. Still
	## unrelated to the wall source's ×20/16 pre-scale (32 + 640 + 32 = 704).
	var roof_source: Image = compositor._get_roof_plane_source(facade)
	var wall_source: Image = compositor._get_plane_source(facade, 0)
	if roof_source.get_height() == 1088 and wall_source.get_height() == 704:
		_pass("Roof plane source is the isotropic mirrored facade (1088 px incl. margins) — covers all 64 cell rows, unlike the wall source (704 px)")
	else:
		_fail("Source heights unexpected: roof=%d (want 1088), wall=%d (want 704)" % [roof_source.get_height(), wall_source.get_height()])

	var roof_top: Image = compositor._get_roof_plane_top("facade_concrete", facade)
	var x_off: int = roof_source.get_height() - 1
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
			@warning_ignore("integer_division")  # mirrors the production crop formula
			var sy0: int = (16 * x + 16 * y) / 2 + V_MARGIN
			for py in range(16):
				for px in range(ATOM_W):
					var edge: float = (8.0 + float(px) / 2.0) if px < 16 else (24.0 - float(px) / 2.0)
					if float(py) >= edge:
						continue  # outside the top diamond
					if canonical.get_pixel(px, py).a < 1.0:
						continue  # AA rim pixels carry fixed-up alpha, skip
					var page_px := page.get_pixel(tile_px.x + px, tile_px.y + py)
					var plane_px := roof_top.get_pixel(sx0 - 16 + px, sy0 + py)
					compared += 1
					luminances[snappedf(plane_px.r, 0.004)] = true
					if page_px.r != plane_px.r or page_px.g != plane_px.g or page_px.b != plane_px.b:
						mismatched += 1

	if compared > 500 and mismatched == 0 and luminances.size() >= 2:
		_pass("3×3 local cells: %d opaque top-diamond pixels ALL equal the continuous roof-plane read (%d distinct luminances — not a blank-vs-blank match)" % [compared, luminances.size()])
	else:
		_fail("pixel continuity: compared=%d, mismatched=%d, distinct_luminances=%d" % [compared, mismatched, luminances.size()])


## Boot the real PLAYGROUND through the exact room.gd::load_map() path,
## optionally rotated. Returns {room, renderer, layout} or empty on failure.
func _build_playground(direction: String) -> Dictionary:
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("PLAYGROUND")
	if spec.is_empty():
		_fail("FileMapSource.get_runtime_spec('PLAYGROUND') returned empty")
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


func test_5_rotated_view_roofs_follow_structures() -> void:
	print("[TEST 5] E view (02a): every block's roof Slab exists at its ROTATED position with its material")
	var file_source := FileMapSourceClass.new()
	var spec: Dictionary = file_source.get_runtime_spec("PLAYGROUND")
	var base_layout: Dictionary = MapCompilerClass.compile(spec)
	var base_blocks: Array = base_layout.get("solid_block_instances", [])
	var base_size: Vector2i = base_layout.get("size", Vector2i.ZERO)

	var built := _build_playground("E")
	if built.is_empty():
		return
	var room: MinimalRoom = built["room"]

	## Own rotation math (E = 90° CW): base (x, y) → (h−1−y, x); a rectangle's
	## rotated NW corner = (h − y0 − sy, x0), size swaps.
	var missing := 0
	var wrong_material := 0
	for b in base_blocks:
		var gu: Vector2i = b.get("gu_cell", Vector2i.ZERO)
		var size: Vector2i = b.get("size", Vector2i.ONE)
		var storeys: int = int(b.get("storeys", 1))
		var material: String = String(b.get("material", "concrete"))
		var rot_gu := Vector2i(base_size.y - gu.y - size.y, gu.x)
		var rot_size := Vector2i(size.y, size.x)
		var base_level: int = GeometryCoordsClass.storey_level_base(storeys)
		for rx in range(rot_size.x):
			for ry in range(rot_size.y):
				var slab_id := "SLAB_%d_%d_%s_%d" % [rot_gu.x + rx, rot_gu.y + ry, Slab.role_name(Slab.Role.CEILING), base_level]
				var slab: Slab = room._slab_registry.get_slab(slab_id)
				if slab == null:
					missing += 1
					continue
				if slab.material != material:
					wrong_material += 1

	if missing == 0 and wrong_material == 0 and base_blocks.size() > 0:
		_pass("All %d blocks have a roof Slab at their independently-rotated E-view position with the correct material" % [base_blocks.size()])
	else:
		_fail("E view: %d rotated block-GUs missing a roof Slab, %d with wrong material" % [missing, wrong_material])

	room.queue_free()
