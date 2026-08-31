## GLASS_MASTER_PLAN G1 — glass transparency routing selftest.
## Rodar: python3 tools/persistent/run_selftests.py --only glass_transparency
##
## G1 moves glass cells off the opaque `_layers` and onto their own MUL + ADD
## blend sublayers (glass_shading.gdshaderinc), so the background shows through
## (G-D1). This suite is the round-trip proof of that routing on the REAL
## `_set_voxel_cell()` seam every render path funnels through — not a fixture that
## only exercises the happy branch.
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
		## An INTERIOR SW voxel (pos 2) → the SW-specific flat pane atom.
		var src: int = gpane.get_cell_source_id(Vector2i(26, 31))
		var want: int = r._glass_pane_source.get(Face.SW, -1)
		if src == want and src >= 0:
			_pass("an interior SW glass cell uses the SW pane atom source (id %d)" % src)
		else:
			_fail("interior SW glass cell source id %d, expected SW source %d" % [src, want])
		## A PERIMETER SW voxel (pos 0) → the cube atom (1-voxel thickness).
		var edge_src: int = gpane.get_cell_source_id(Vector2i(24, 31))
		if edge_src == r._glass_cube_source and edge_src >= 0:
			_pass("a perimeter glass cell uses the cube atom (id %d)" % edge_src)
		else:
			_fail("perimeter glass cell source id %d, expected cube %d" % [edge_src, r._glass_cube_source])
		var ids := {}
		for f in [Face.SW, Face.SE, Face.NW, Face.NE]:
			ids[r._glass_pane_source.get(f, -1)] = true
		if ids.size() == 4 and not ids.has(-1):
			_pass("all four faces have a distinct pane atom source")
		else:
			_fail("face sources not all distinct/present: %s" % [r._glass_pane_source])

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
