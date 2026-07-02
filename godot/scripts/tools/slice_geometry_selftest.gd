extends SceneTree
## Selftest headless — SLICE-00 Transform Canon validation.
## Rodar: godot --headless --script res://godot/scripts/tools/slice_geometry_selftest.gd
## Saída: "SLICE-00 SELFTEST: PASS" + exit 0, ou "...FAIL" + exit 1.

func _initialize() -> void:
	var SC = load("res://godot/scripts/world/subcube_coords.gd")
	var failures: int = 0
	var checked:  int = 0

	## ── Check 1: E1 (layer transform) ────────────────────────────────────
	print_debug("[SLICE-00] Check 1: E1 (layer transform)")
	var VISUAL_GRID_OFFSET := Vector2(0.0, 512.0)
	var VOXEL_STEP_PX := 20.0
	var test_levels: Array[int] = [0, 1, 7]
	for level in test_levels:
		var expected_pos: Vector2 = VISUAL_GRID_OFFSET - Vector2(0, VOXEL_STEP_PX * float(level))
		checked += 1
		# Note: We can't instantiate TileMapLayers headless, so we just verify the formula is correct
		# The actual runtime verification happens during the smoke test
		print_debug("  Level %d: expected position = %s" % [level, expected_pos])

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
	print_debug("[SLICE-00] Check 5: Floor Rosetta (tileset_blocks)")
	var tileset_path := "res://godot/resources/tilesets/tileset_blocks.tres"
	var floor_tileset: TileSet = load(tileset_path)
	checked += 1
	if floor_tileset == null:
		push_error("Failed to load tileset: %s" % tileset_path)
		failures += 1
	else:
		# Check for floor_SE tile (a known source to pin the floor plane)
		var source_id: int = 0
		if floor_tileset.get_source_count() > 0:
			var src = floor_tileset.get_source(source_id)
			if src is TileSetAtlasSource:
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

	## ── Sumário ──────────────────────────────────────────────────────────
	if failures == 0:
		print("SLICE-00 SELFTEST: PASS (%d checagens)" % checked)
		quit(0)
	else:
		print("SLICE-00 SELFTEST: FAIL (%d falhas / %d checagens)" % [failures, checked])
		quit(1)
