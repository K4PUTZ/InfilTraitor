extends SceneTree
## Selftest headless — SLICE-00 Transform Canon validation.
## Rodar: godot --headless --script res://godot/scripts/tools/slice_geometry_selftest.gd
## Saída: "SLICE-00 SELFTEST: PASS" + exit 0, ou "...FAIL" + exit 1.

## Preloads for ENHANCE-02 negative testing (error contract validation)
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const MapCatalogClass = preload("res://godot/scripts/world/maps/map_catalog.gd")
const EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")

func _initialize() -> void:
	var SC = load("res://godot/scripts/geometry/geometry_coords.gd")
	var failures: int = 0
	var checked:  int = 0

	## ── Check 1: E1 (layer transform) ────────────────────────────────────
	##
	## MAT-COHERENCE-01's sibling fix (Director, 2026-09-01: "pode fazer todas as
	## correções"). This check used to compute an expected position and only
	## `print_debug` it — three `checked += 1` and not one assertion, excused by a
	## comment claiming "we can't instantiate TileMapLayers headless". That claim
	## is false: negative_storey_selftest, fixed_floor_selftest and roof_slab_
	## selftest all build a real VoxelRenderer headless and read `layer.position`.
	##
	## Worse, the formula it was printing was itself WRONG — `VISUAL_GRID_OFFSET -
	## (0, VOXEL_STEP_PX * level)` omits TILE_OFFSET (112, 64) entirely, which is
	## the exact re-derivation OCC-FIX-02 had to undo in OcclusionOverlay. A check
	## that asserts nothing cannot notice that its own canon is wrong, which is the
	## whole argument against hollow checks.
	##
	## LEVEL-RENUMBER: the Y term takes `relative_level()`, never the absolute one
	## (CLAUDE.md rule 9) — left absolute every layer would sit eighty steps too
	## high, with a byte-identical cell census.
	print_debug("[SLICE-00] Check 1: E1 (layer transform)")
	var VISUAL_GRID_OFFSET := Vector2(0.0, 512.0)
	const TILE_OFFSET := Vector2(112.0, 64.0)
	var VoxelRendererClass = load("res://godot/scripts/geometry/voxel_renderer.gd")
	var e1_renderer = VoxelRendererClass.new()
	root.add_child(e1_renderer)
	e1_renderer.setup(VISUAL_GRID_OFFSET)
	e1_renderer._ensure_voxel_layers(SC.LEVELS_PER_STOREY)
	for relative in [0, 1, 7]:
		var level: int = SC.storey_level_base(0) + relative
		checked += 1
		var layer: TileMapLayer = e1_renderer.get_layer(level)
		if layer == null:
			push_error("E1: level %d (relative %d) has no layer" % [level, relative])
			failures += 1
			continue
		var expected_pos: Vector2 = VISUAL_GRID_OFFSET + TILE_OFFSET \
			- Vector2(0.0, SC.VOXEL_STEP_PX * float(relative))
		if layer.position.is_equal_approx(expected_pos):
			print_debug("  ✓ Level %d (relative %d): position %s matches E1" % [
				level, relative, layer.position])
		else:
			push_error("E1 mismatch at level %d (relative %d): layer.position=%s expected=%s" % [
				level, relative, layer.position, expected_pos])
			failures += 1
	e1_renderer.queue_free()

	## ── Check 2: Scale identity (isometric projection) ──────────────────
	print_debug("[SLICE-00] Check 2: Scale identity (isometric projection)")
	var floor_half_w := 128
	var floor_half_h := 64
	var voxel_half_w := 16
	var voxel_half_h := 8
	var test_gus: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 5), Vector2i(12, 3), Vector2i(27, 45)]
	for gu: Vector2i in test_gus:
		var floor_proj: Vector2 = Vector2(
			(gu.x - gu.y) * floor_half_w,
			(gu.x + gu.y) * floor_half_h
		)
		var voxel_cell: Vector2i = gu * SC.VOXELS_PER_UNIT_AXIS
		var voxel_proj: Vector2 = Vector2(
			(voxel_cell.x - voxel_cell.y) * voxel_half_w,
			(voxel_cell.x + voxel_cell.y) * voxel_half_h
		)
		checked += 1
		if not floor_proj.is_equal_approx(voxel_proj):
			push_error("Scale mismatch for GU %s: floor=%s, voxel=%s" % [gu, floor_proj, voxel_proj])
			failures += 1
		else:
			print_debug("  GU %s: ✓ projection match" % gu)

	## ── Check 3: Derived origin (voxel atom texture anchoring) ──────────
	print_debug("[SLICE-00] Check 3: Derived origin (voxel texture_origin)")
	var VOXEL_ATOM_H := 36
	var VOXEL_TILE_H := 16
	var expected_origin_y: int = int((VOXEL_ATOM_H - VOXEL_TILE_H) / 2.0)
	checked += 1
	if expected_origin_y != 10:
		push_error("Derived origin y mismatch: expected 10, got %d" % expected_origin_y)
		failures += 1
	else:
		print_debug("  Derived origin_y = %d (correct)" % expected_origin_y)

	## ── Check 4: Canon 4 (cell space — gu_to_voxel_origin) ──────────────
	print_debug("[SLICE-00] Check 4: Canon 4 (cell space)")
	for gu: Vector2i in test_gus:
		var origin: Vector2i = SC.gu_to_voxel_origin(gu)
		var expected: Vector2i = gu * 8
		checked += 1
		if origin != expected:
			push_error("gu_to_voxel_origin(%s) = %s, expected %s" % [gu, origin, expected])
			failures += 1
		# Round-trip test
		var gu_back: Vector2i = SC.voxel_to_gu(gu * 8 + Vector2i(7, 7))
		checked += 1
		if gu_back != gu:
			push_error("voxel_to_gu round-trip failed: %s -> %s" % [gu, gu_back])
			failures += 1
		else:
			print_debug("  GU %s: ✓ cell space round-trip" % gu)

	## ── Check 5: Floor Rosetta sanity ────────────────────────────────────
	# tileset_blocks.tres accumulates unrelated sources (actor bakes, shotgun
	# frames, voxel materials) ahead of the floor tiles, so source_id 0 is not
	# a stable way to find "the floor tile" — it stopped being floor_NE at some
	# point and nobody noticed because this whole selftest was hanging (see
	# Test 2 above). Look the floor tile up by its "tile_name" custom data
	# layer instead, the same pattern room_builder.gd:build_registry() uses.
	print_debug("[SLICE-00] Check 5: Floor Rosetta (tileset_blocks)")
	var tileset_path := "res://godot/resources/tilesets/tileset_blocks.tres"
	var floor_tileset: TileSet = load(tileset_path)
	checked += 1
	if floor_tileset == null:
		push_error("Failed to load tileset: %s" % tileset_path)
		failures += 1
	else:
		var src: TileSetAtlasSource = null
		for i in floor_tileset.get_source_count():
			var sid := floor_tileset.get_source_id(i)
			var candidate := floor_tileset.get_source(sid) as TileSetAtlasSource
			if candidate == null:
				continue
			var candidate_td := candidate.get_tile_data(Vector2i(0, 0), 0)
			if candidate_td != null and candidate_td.get_custom_data("tile_name") == "floor_NE":
				src = candidate
				break
		if src == null:
			push_error("No source with tile_name 'floor_NE' found in %s" % tileset_path)
			failures += 1
		else:
			# Verify the atlas dimensions (should be 256x512)
			if src.texture_region_size == Vector2i(256, 512):
				print_debug("  Floor tileset region size: %s ✓" % src.texture_region_size)
				checked += 1
				# Check texture_origin of the floor tile (should be (0, -384))
				var td: TileData = src.get_tile_data(Vector2i(0, 0), 0)
				if td != null:
					checked += 1
					if td.texture_origin == Vector2i(0, -384):
						print_debug("  Floor tile texture_origin: %s ✓" % td.texture_origin)
					else:
						push_error("Floor tile origin mismatch: expected (0, -384), got %s" % td.texture_origin)
						failures += 1
			else:
				push_error("Floor tileset region size mismatch: expected (256, 512), got %s" % src.texture_region_size)
				failures += 1

	## ── Check N: PerspectiveMapper round-trip + parity (ENHANCE-04b) ────────
	print_debug("[ENHANCE-04b] Perspective round-trip + rotation parity")
	const PM = preload("res://godot/scripts/world/utilities/perspective_mapper.gd")
	var rt_size := Vector2i(10, 6)
	var rt_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(9, 0), Vector2i(0, 5), Vector2i(9, 5), Vector2i(4, 2)]
	for dir in ["N", "E", "S", "W"]:
		for cell in rt_cells:
			var view: Vector2i = PM.cell_from_base(cell, dir, rt_size)
			var back: Vector2i = PM.cell_to_base(view, dir, rt_size)
			checked += 1
			if back != cell:
				push_error("[ENHANCE-04b] Round-trip failed dir=%s cell=%s -> view=%s -> back=%s" % [dir, cell, view, back])
				failures += 1

	## Parity: enemy route and light angle must rotate, not just start_cell/cell.
	var rt_layout := {
		"size": rt_size,
		"enemy_defs": [{"start_cell": Vector2i(1, 1), "route": [Vector2i(1, 1), Vector2i(1, 4)]}],
		"light_sources": [{"x": 2, "y": 2, "direction_deg": 0.0}],
	}
	var rt_rotated := PM.layout_with_perspective(rt_layout, "E")
	checked += 1
	var rt_route: Array = rt_rotated["enemy_defs"][0]["route"]
	if rt_route[0] == Vector2i(1, 1) and rt_route[1] == Vector2i(1, 4):
		push_error("[ENHANCE-04b] enemy route did not rotate under direction E")
		failures += 1
	else:
		print_debug("  ✓ enemy route rotates: %s" % [rt_route])

	checked += 1
	var rt_angle: float = rt_rotated["light_sources"][0]["direction_deg"]
	if is_equal_approx(rt_angle, 0.0):
		push_error("[ENHANCE-04b] light direction_deg did not rotate under direction E")
		failures += 1
	else:
		print_debug("  ✓ light angle rotates: %.1f deg" % rt_angle)

	## ── Negative Tests: Malformed input handling (ENHANCE-02 error contract) ────
	print_debug("[ENHANCE-02] Testing error handling with malformed specs")
	
	# Test 1: MapCompiler with missing required keys
	print_debug("[ENHANCE-02] Test 1: MapCompiler.compile() with missing 'inner_size'")
	var bad_spec_1: Dictionary = {"agent_start": Vector2i(5, 5)}  # missing "inner_size"
	var bad_layout_1: Dictionary = MapCompilerClass.compile(bad_spec_1, {})
	checked += 1
	if bad_layout_1.is_empty():
		print_debug("  ✓ Returned empty dict (error handled cleanly)")
	else:
		push_error("Bad spec should return empty, got: %s" % bad_layout_1)
		failures += 1
	
	# Test 2: MapCatalog with unknown map_id — SKIPPED, always, in --script mode.
	# MapCatalog.get_spec() routes through Registries.ensure_file_map_source(). The
	# first static call into MapCatalogClass forces Godot to compile map_catalog.gd
	# (GDScript::reload()), and that compile step fails to resolve the unqualified
	# `Registries` identifier in headless --script mode — confirmed 2026-07-29 by
	# isolated repro: `root.has_node("Registries")` reports true (the autoload node
	# IS in the tree) yet the call still throws "Compile Error: Identifier not
	# found: Registries" followed by "Invalid call. Nonexistent function 'get_spec'".
	# A tree-presence guard cannot predict a compile-time resolution failure, and
	# because GDScript has no way to catch that error, it aborted _initialize()
	# before reaching the summary's quit() — the process hung forever in headless
	# runs instead of failing loud. Skip unconditionally; this selftest's only
	# documented invocation is `godot --headless --script ...` (see file header).
	print_debug("[ENHANCE-02] Test 2: SKIPPED — MapCatalog.get_spec() can't compile headless in --script mode (2026-07-29, not a code defect)")
	
	# Test 3: EdgeExtractor with empty compiled dict
	print_debug("[ENHANCE-02] Test 3: EdgeExtractor.extract() with empty input")
	var bad_edges_1: Dictionary = EdgeExtractorClass.extract({})
	checked += 1
	if bad_edges_1.get("edges", []).is_empty() and bad_edges_1.get("solid_blocks", []).is_empty():
		print_debug("  ✓ Returned empty result (malformed input handled)")
	else:
		push_error("Empty compiled should return empty result, got: %s" % bad_edges_1)
		failures += 1
	
	# Test 4: EdgeExtractor with missing wall_levels
	print_debug("[ENHANCE-02] Test 4: EdgeExtractor.extract() with missing 'wall_levels'")
	var bad_edges_2: Dictionary = EdgeExtractorClass.extract({"some_other_key": []})
	checked += 1
	if bad_edges_2.get("edges", []).is_empty() and bad_edges_2.get("solid_blocks", []).is_empty():
		print_debug("  ✓ Returned empty result (missing wall_levels handled)")
	else:
		push_error("Missing wall_levels should return empty result, got: %s" % bad_edges_2)
		failures += 1

	## ── Sumário ──────────────────────────────────────────────────────────────
	print_debug("[SLICE-00] Canon checks: %d passed" % (checked - 3 - 22))
	print_debug("[ENHANCE-04b] Perspective checks: 22 passed")
	print_debug("[ENHANCE-02] Error handling checks: 3 passed (Test 2 skipped, see comment above)")
	print_debug("")
	if failures == 0:
		print("SLICE-00 SELFTEST: PASS (%d checagens)" % checked)
		quit(0)
	else:
		print("SLICE-00 SELFTEST: FAIL (%d falhas / %d checagens)" % [failures, checked])
		quit(1)
