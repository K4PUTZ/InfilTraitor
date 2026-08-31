## GLASS_MASTER_PLAN G1 — glass transparency routing selftest.
## Rodar: python3 tools/persistent/run_selftests.py --only glass_transparency
##
## G1 moves glass cells off the opaque `_layers` and onto their own MUL + ADD
## blend sublayers (glass_shading.gdshaderinc), so the background shows through
## (G-D1). This suite is the round-trip proof of that routing on the REAL
## `_set_voxel_cell()` seam every render path funnels through — not a fixture that
## only exercises the happy branch.
##
## GLASS G1 GEOMETRY (2026-08-31) — it also pins the face-culling rule: an
## interior voxel gets the main-only atom (mask 0), the frontmost column gets
## main+side (mask 1), the top level main+top (mask 2), and `_glass_face_mask()`
## returns those bits. 16 atom sources (4 faces × 4 masks), all distinct.
##
## What each test catches, worst first:
##
##   1. A glass voxel that STILL lands on the opaque layer — the pane would be a
##      solid cube again, G1 undone with no error.
##   2. A glass sublayer built for a level that has no glass — a wasted layer
##      pair, and a sign the lazy-build guard slipped.
##   3. A concrete voxel that got routed to the glass sublayers — the one test
##      that proves the `material_name == "glass"` gate is not catching
##      everything.
##   4. A destroyed glass voxel left drawn on a sublayer — the pane keeps a
##      shard that was shot out.
##   5. Intact glass dropped from `build_occupancy()` — the light field would
##      stop seeing the pane the moment G1 landed (this suite pins it BLOCKS
##      light exactly as before; whether it should transmit is a later call).

extends SceneTree

const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")
const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")

var passed: int = 0
var failed: int = 0
var _fixtures: Array = []


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("GLASS G1 — TRANSPARENCY ROUTING SELFTEST")
	print("=".repeat(70) + "\n")

	test_glass_voxel_lands_on_the_sublayers_not_the_opaque_layer()
	test_sublayers_are_lazy_only_glass_levels_get_them()
	test_concrete_is_untouched_by_the_glass_gate()
	test_destroyed_glass_clears_the_pane()
	test_intact_glass_still_blocks_light()

	print("\n" + "=".repeat(70))
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	print("=".repeat(70) + "\n")
	if failed == 0:
		print("✓ GLASS G1 TRANSPARENCY SELFTEST PASS\n")
		quit(0)
	else:
		print("✗ GLASS G1 TRANSPARENCY SELFTEST FAILED\n")
		quit(1)


func _pass(msg: String) -> void:
	print("  ✓ %s" % msg)
	passed += 1


func _fail(msg: String) -> void:
	print("  ✗ %s" % msg)
	failed += 1


## A slice on the SW face (varies in x, matching the fixture's `24 + pos`), its 8
## face voxels populated at `level`. `storeys` sets how many level-bands
## `_render_slice()` ensures opaque layers for.
func _make_slice(id: String, material: String, level: int, storeys: int = 1) -> Slice:
	var slice := Slice.new(id, Vector2i(3, 3), Face.SW, "", storeys, material)
	for pos in range(8):
		var v := Voxel.new(Vector2i(24 + pos, 31), level, slice)
		slice.voxels.append(v)
	_fixtures.append(slice)
	return slice


func _fresh_renderer() -> VoxelRenderer:
	var r := VoxelRendererClass.new()
	root.add_child(r)
	r.setup(Vector2.ZERO)
	return r


func test_glass_voxel_lands_on_the_sublayers_not_the_opaque_layer() -> void:
	print("[1] a glass voxel is on the MUL+ADD sublayers and NOT on `_layers`\n")
	var r := _fresh_renderer()
	var level: int = GeometryCoords.PLAYABLE_LEVEL
	var registry := EdgeRegistry.new()
	registry.register_slice(_make_slice("SLICE_GLASS", "glass", level))
	r.render(registry)

	var opaque: TileMapLayer = r.get_layer(level)
	var opaque_glass_cells: int = 0
	if opaque != null:
		opaque_glass_cells = opaque.get_used_cells().size()
	if opaque_glass_cells == 0:
		_pass("opaque layer at the glass level holds ZERO cells")
	else:
		_fail("opaque layer still holds %d glass cell(s) — G1 undone" % opaque_glass_cells)

	var gpane: TileMapLayer = r._glass_layers.get(level)
	var pane_cells: int = gpane.get_used_cells().size() if gpane != null else -1
	if pane_cells == 8:
		_pass("the glass pane layer holds all 8 glass cells")
	else:
		_fail("glass pane layer cell count %d (expected 8)" % pane_cells)

	if gpane != null:
		## GLASS G1 GEOMETRY — an INTERIOR SW voxel (pos 2, not the front column,
		## not the top level) → mask 0, the SW main-only atom.
		var main_src: int = int(r._glass_atom_source.get(Face.SW, {}).get(0, -1))
		var src: int = gpane.get_cell_source_id(Vector2i(26, 31))
		if src == main_src and src >= 0:
			_pass("an interior SW glass cell uses the SW main-only atom (id %d)" % src)
		else:
			_fail("interior SW glass cell source id %d, expected SW mask-0 %d" % [src, main_src])
		## The FRONTMOST column (pos 7, x31) → mask 1, the SW main+side atom —
		## a distinct source that carries the dim side sliver.
		var side_src: int = int(r._glass_atom_source.get(Face.SW, {}).get(1, -1))
		var front_src: int = gpane.get_cell_source_id(Vector2i(31, 31))
		if front_src == side_src and front_src >= 0 and front_src != main_src:
			_pass("the frontmost SW column uses the SW main+side atom (id %d)" % front_src)
		else:
			_fail("frontmost SW cell source id %d, expected SW mask-1 %d" % [front_src, side_src])
		## Four faces × four masks, all present and all distinct.
		var ids := {}
		var missing := false
		for fc in [Face.SW, Face.SE, Face.NW, Face.NE]:
			for m in range(4):
				var sid: int = int(r._glass_atom_source.get(fc, {}).get(m, -1))
				if sid < 0:
					missing = true
				ids[sid] = true
		if ids.size() == 16 and not missing:
			_pass("all 16 glass atom sources (4 faces × 4 masks) are distinct and present")
		else:
			_fail("glass atom sources not all distinct/present: %s" % [r._glass_atom_source])
		## The face mask itself: top level sets bit 1, frontmost column bit 0.
		var top_level: int = GeometryCoords.PLAYABLE_LEVEL + 7
		var m_interior: int = r._glass_face_mask(Vector2i(26, 31), GeometryCoords.PLAYABLE_LEVEL, Face.SW, top_level)
		var m_front: int = r._glass_face_mask(Vector2i(31, 31), GeometryCoords.PLAYABLE_LEVEL, Face.SW, top_level)
		var m_top: int = r._glass_face_mask(Vector2i(26, 31), top_level, Face.SW, top_level)
		var m_corner: int = r._glass_face_mask(Vector2i(31, 31), top_level, Face.SW, top_level)
		if m_interior == 0 and m_front == 1 and m_top == 2 and m_corner == 3:
			_pass("_glass_face_mask: interior 0, front column 1, top level 2, corner 3")
		else:
			_fail("_glass_face_mask masks wrong: interior %d front %d top %d corner %d" % [m_interior, m_front, m_top, m_corner])

	## The rasterising container: a BackBufferCopy sits over the glass.
	if r._glass_backbuffer != null and r._glass_backbuffer is BackBufferCopy:
		_pass("a BackBufferCopy container was built for the glass")
	else:
		_fail("no BackBufferCopy container — the pane would double-tint on overlap")

	r.queue_free()
	print("")


func test_sublayers_are_lazy_only_glass_levels_get_them() -> void:
	print("[2] sublayers exist ONLY for levels that actually contain glass\n")
	var r := _fresh_renderer()
	var glass_level: int = GeometryCoords.PLAYABLE_LEVEL + 8
	var registry := EdgeRegistry.new()
	registry.register_slice(_make_slice("SLICE_CONCRETE_2", "concrete", GeometryCoords.PLAYABLE_LEVEL, 2))
	registry.register_slice(_make_slice("SLICE_GLASS_2", "glass", glass_level, 2))
	r.render(registry)

	var keys: Array = r.glass_level_keys()
	if keys == [glass_level]:
		_pass("glass_level_keys() == [%d] — one pane layer, at the glass level only" % glass_level)
	else:
		_fail("glass_level_keys() == %s, expected [%d]" % [keys, glass_level])
	r.queue_free()
	print("")


func test_concrete_is_untouched_by_the_glass_gate() -> void:
	print("[3] a concrete voxel still lands on the opaque layer, no sublayer\n")
	var r := _fresh_renderer()
	var level: int = GeometryCoords.PLAYABLE_LEVEL
	var registry := EdgeRegistry.new()
	registry.register_slice(_make_slice("SLICE_CONCRETE", "concrete", level))
	r.render(registry)

	var opaque: TileMapLayer = r.get_layer(level)
	var n: int = opaque.get_used_cells().size() if opaque != null else 0
	if n == 8:
		_pass("opaque layer holds all 8 concrete cells")
	else:
		_fail("opaque layer holds %d concrete cells, expected 8" % n)
	if r.glass_level_keys().is_empty():
		_pass("no glass sublayers were built for a glassless render")
	else:
		_fail("glass sublayers built with no glass on the map: %s" % [r.glass_level_keys()])
	r.queue_free()
	print("")


func test_destroyed_glass_clears_the_pane() -> void:
	print("[4] destroying a glass voxel erases it from the pane layer\n")
	var r := _fresh_renderer()
	var level: int = GeometryCoords.PLAYABLE_LEVEL
	var registry := EdgeRegistry.new()
	var slice := _make_slice("SLICE_GLASS_BREAK", "glass", level)
	registry.register_slice(slice)
	r.render(registry)

	var target: Voxel = slice.voxels[0]
	target.visible = false
	target.dirty = true
	slice.dirty_count = 1
	r.process_dirty(registry)

	var gpane: TileMapLayer = r._glass_layers.get(level)
	var src: int = gpane.get_cell_source_id(target.grid_pos) if gpane != null else 999
	if src == -1:
		_pass("the destroyed cell is gone from the pane layer")
	else:
		_fail("destroyed cell still present: src=%d" % src)

	var remaining: int = gpane.get_used_cells().size() if gpane != null else -1
	if remaining == 7:
		_pass("the other 7 glass cells are untouched")
	else:
		_fail("expected 7 surviving glass cells, got %d" % remaining)
	r.queue_free()
	print("")


func test_intact_glass_still_blocks_light() -> void:
	print("[5] build_occupancy() still reports intact glass as solid\n")
	var r := _fresh_renderer()
	var level: int = GeometryCoords.PLAYABLE_LEVEL
	var registry := EdgeRegistry.new()
	registry.register_slice(_make_slice("SLICE_GLASS_OCC", "glass", level))
	r.render(registry)

	var occ: Dictionary = r.build_occupancy()
	var at_level: Dictionary = occ.get(level, {})
	if at_level.size() == 8:
		_pass("build_occupancy() reports 8 solid cells at the glass level")
	else:
		_fail("build_occupancy() reports %d cells at the glass level, expected 8" % at_level.size())
	r.queue_free()
	print("")
