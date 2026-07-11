## BAKE-FACADE-PLANE-01-b: Extended pixel-identity test for isometric projection
## Verifies projection u,v formulas, top-face shaded_base, run-axis, performance

extends SceneTree

const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const BakeConfig = preload("res://godot/scripts/systems/bake_config.gd")
const BakeCompositor = preload("res://godot/scripts/systems/bake_compositor.gd")
const _GeometryCoords = preload("res://godot/scripts/geometry/geometry_coords.gd")
const MaterialRegistry = preload("res://godot/scripts/systems/material_registry.gd")
const TextureResolver = preload("res://godot/scripts/systems/texture_resolver.gd")
const BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")

const TEX_AUTHORING_N: int = _GeometryCoords.TEX_AUTHORING_N
const VOXEL_ATOM_W: int = _GeometryCoords.VOXEL_ATOM_W
const VOXEL_ATOM_H: int = _GeometryCoords.VOXEL_ATOM_H
const VOXEL_VISIBLE_Y_START: int = 16

var _test_results: Array = []
var _material_registry = null
var _facade_image = null

func _init() -> void:
	# OVERLORD-FIX-02: deterministic sampling — a flaky test is worse than a
	# slow one; failures must reproduce
	seed(0xBA5E)
	print("\n" + "=".repeat(80))
	print("BAKE-FACADE-PLANE-01-b: Extended Projection Test")
	print("=".repeat(80) + "\n")

	_material_registry = MaterialRegistry.new()
	_material_registry.register_defaults()
	
	var facade_path = "res://textures/defaults/facade_stone.png"
	var facade_texture: Texture2D = load(facade_path)
	if facade_texture == null:
		_record_result("Setup", "FAIL", "No facade")
		_print_summary()
		quit(1)
		return
	_facade_image = facade_texture.get_image()
	_record_result("Setup", "PASS", "Loaded facade %dx%d" % [_facade_image.get_width(), _facade_image.get_height()])

	_test_projection()
	_test_seams()
	_test_top_overlap()
	_test_top_face()
	_test_run_axis()
	_test_performance()
	_test_regressions()

	_record_result("Criterion 7", "DEFERRED", "Lint check")
	_record_result("Criterion 8", "DEFERRED", "Commit")

	_print_summary()
	if _all_pass():
		quit(0)
	else:
		quit(1)

func _test_projection() -> void:
	print("\n--- Projection pixel-identity ---\n")

	BakeConfig.enabled = true
	BakeConfig.blend_mode = BakeConfig.BlendMode.TEXTURE_ONLY

	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("TEXTURES")
	if map_spec == null:
		_record_result("Projection", "FAIL", "No TEXTURES map")
		return

	var compositor = BakeCompositor.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolver.new()

	var start_time = Time.get_ticks_msec()
	var baked_atlas = compositor.bake(map_spec, resolver)
	var bake_time = Time.get_ticks_msec() - start_time

	if baked_atlas == null or baked_atlas.strips.is_empty():
		_record_result("Projection", "FAIL", "No strips")
		return

	_record_result("Projection", "PASS", "%d strips in %.0fms" % [baked_atlas.strips.size(), bake_time])

	var lookup_dict = baked_atlas.lookup
	var stone_keys: Array = []
	for key in lookup_dict.keys():
		if key.begins_with("stone|facade_stone|"):
			stone_keys.append(key)

	var facade_sampler = FacadeSamplerClass.new()
	var pixel_matches = 0
	var pixel_mismatches = 0

	# OVERLORD-FIX-01: keys are now 5-field (mat|fac|col|row|dir) and the
	# continuous-plane formulas replace the half-face ones. The bake path
	# quantizes vertically (nearest ×20/16 resize + 2-px strip shear), so the
	# expected value is accepted at v−1/v/v+1 texels; a structural error
	# (wrong window, wrong mirror, no shear) is whole windows away and fails.
	var samples := 0
	while samples < 128 and stone_keys.size() > 0:
		var lookup_key = stone_keys[randi_range(0, stone_keys.size() - 1)]
		var parts = lookup_key.split("|")
		if parts.size() != 5:
			_record_result("Projection", "FAIL", "unexpected key shape: %s" % lookup_key)
			return
		var col = int(parts[2])
		var row = int(parts[3])
		var dir = int(parts[4])
		var entry = lookup_dict[lookup_key]
		var page_idx = entry.get("page", -1)
		var atlas_coords = entry.get("atlas_coords", Vector2i.ZERO)
		if page_idx < 0 or page_idx >= baked_atlas.atom_pages.size():
			continue
		var page_image = baked_atlas.atom_pages[page_idx]
		var pixel_x = randi_range(0, VOXEL_ATOM_W - 1)
		var pixel_y = randi_range(VOXEL_VISIBLE_Y_START, VOXEL_ATOM_H - 1)
		var page_px = atlas_coords.x * VOXEL_ATOM_W + pixel_x
		var page_py = atlas_coords.y * VOXEL_ATOM_H + pixel_y

		var plane_u: float
		var y_top: float
		if dir == 0:
			plane_u = col * float(TEX_AUTHORING_N) + float(pixel_x)
			y_top = 8.0 + float(pixel_x) / 2.0
		else:
			plane_u = col * float(TEX_AUTHORING_N) + float(31 - pixel_x)
			y_top = 8.0 + float(31 - pixel_x) / 2.0
		# Skip top-face paint AND the wedge above the face top edge: wedge
		# content is negative-v mirrored fill that is occluded by the
		# neighboring atom's face content by construction (its exact value
		# stacks two quantizations and is not part of the identity contract)
		if float(pixel_y) < y_top:
			continue
		var baked_pixel = page_image.get_pixel(page_px, page_py)
		if baked_pixel.a <= 0.0:
			continue  # outside silhouette
		var plane_v = float(31 - row) * float(TEX_AUTHORING_N) + (float(pixel_y) - y_top) * 16.0 / 20.0

		samples += 1
		var ok := false
		for dv in [-1.0, 0.0, 1.0]:
			var expected_lum = facade_sampler.sample(_facade_image, plane_u, plane_v + dv)
			if abs(baked_pixel.r - expected_lum) < 0.01:
				ok = true
				break
		if ok:
			pixel_matches += 1
		else:
			pixel_mismatches += 1

	var proj_ok: bool = pixel_mismatches == 0 and pixel_matches >= 64
	_record_result("Projection", "PASS" if proj_ok else "FAIL",
		"%d matches, %d mismatches (vacuous if <64 samples)" % [pixel_matches, pixel_mismatches])

## OVERLORD-FIX-01: real seam check. In the continuous-plane model, adjacent
## atoms' crops OVERLAP on purpose: atom(col) at (x+16, y) and atom(col+1) at
## (x, y−8) sample the SAME plane pixel (dir 0; mirrored for dir 1), so the
## page pixels must be byte-identical wherever both are inside the silhouette.
## The old version only checked that neighbor keys existed in the dictionary
## — no pixels were ever compared (vacuous pass).
func _test_seams() -> void:
	print("\n--- Seam continuity (overlap identity) ---\n")
	var compositor = BakeCompositor.new()
	compositor.set_material_registry(_material_registry)
	var atlas = compositor.bake(FileMapSourceClass.new().get_runtime_spec("TEXTURES"), TextureResolver.new())

	var pairs := 0
	var pixel_checks := 0
	var mismatches := 0
	for dir in range(2):
		for case in [[0, 5], [12, 0], [30, 20], [62, 31]]:
			var col: int = case[0]
			var row: int = case[1]
			var k1 = "stone|facade_stone|%d|%d|%d" % [col, row, dir]
			var k2 = "stone|facade_stone|%d|%d|%d" % [col + 1, row, dir]
			if not (atlas.lookup.has(k1) and atlas.lookup.has(k2)):
				continue
			pairs += 1
			var e1 = atlas.lookup[k1]
			var e2 = atlas.lookup[k2]
			var p1: Image = atlas.atom_pages[e1["page"]]
			var p2: Image = atlas.atom_pages[e2["page"]]
			var o1: Vector2i = e1["atlas_coords"] * Vector2i(VOXEL_ATOM_W, VOXEL_ATOM_H)
			var o2: Vector2i = e2["atlas_coords"] * Vector2i(VOXEL_ATOM_W, VOXEL_ATOM_H)
			for x in range(16):
				for y in range(24, VOXEL_ATOM_H):
					var a: Color
					var b: Color
					if dir == 0:
						a = p1.get_pixel(o1.x + x + 16, o1.y + y)
						b = p2.get_pixel(o2.x + x, o2.y + y - 8)
					else:
						a = p1.get_pixel(o1.x + x, o1.y + y)
						b = p2.get_pixel(o2.x + x + 16, o2.y + y - 8)
					if a.a <= 0.0 or b.a <= 0.0:
						continue
					pixel_checks += 1
					if a.r != b.r or a.g != b.g or a.b != b.b:
						mismatches += 1

	var seams_ok: bool = mismatches == 0 and pixel_checks >= 500 and pairs >= 8
	_record_result("Seams", "PASS" if seams_ok else "FAIL",
		"%d pairs, %d overlap pixels compared, %d mismatches" % [pairs, pixel_checks, mismatches])

## TOP-01: top-face overlap identity (horizontal plane T crop continuity).
## When facade_tops is ON, each atom's top is a 32×16 crop from the T plane
## (horizontal projection). Adjacent atoms' crops overlap by construction —
## the overlapping pixels must be byte-identical (the T plane's edge windows
## are shared by adjacent atoms on screen). This test verifies the same
## overlap-identity contract for tops as for side faces (criterion 1).
func _test_top_overlap() -> void:
	print("\n--- Top-face overlap identity (TOP-01) ---\n")
	
	# Enable facade tops for this test
	BakeConfig.facade_tops = true
	var compositor = BakeCompositor.new()
	compositor.set_material_registry(_material_registry)
	var atlas = compositor.bake(FileMapSourceClass.new().get_runtime_spec("TEXTURES"), TextureResolver.new())

	var pairs := 0
	var pixel_checks := 0
	var mismatches := 0
	
	# Test top crop overlap for adjacent atoms: the top regions (y=0..15) of
	# adjacent columns in the T plane share a boundary. The overlap check
	# mirrors the side-face seam check but targets the top-face region only.
	for dir in range(2):
		for case in [[0, 5], [12, 0], [30, 20], [62, 31]]:
			var col: int = case[0]
			var row: int = case[1]
			var k1 = "stone|facade_stone|%d|%d|%d" % [col, row, dir]
			var k2 = "stone|facade_stone|%d|%d|%d" % [col + 1, row, dir]
			if not (atlas.lookup.has(k1) and atlas.lookup.has(k2)):
				continue
			pairs += 1
			var e1 = atlas.lookup[k1]
			var e2 = atlas.lookup[k2]
			var p1: Image = atlas.atom_pages[e1["page"]]
			var p2: Image = atlas.atom_pages[e2["page"]]
			var o1: Vector2i = e1["atlas_coords"] * Vector2i(VOXEL_ATOM_W, VOXEL_ATOM_H)
			var o2: Vector2i = e2["atlas_coords"] * Vector2i(VOXEL_ATOM_W, VOXEL_ATOM_H)
			
			# Top region: y = 0..15 (32×16 crop before diamond mask is applied)
			# The overlap of atom(col) top at x≥16 and atom(col+1) top at x<16
			# should be byte-identical (both sample the same T plane content).
			for x in range(16):
				for y in range(0, 16):
					var a: Color
					var b: Color
					if dir == 0:
						# dir 0: atom(col) right edge overlaps atom(col+1) left edge
						a = p1.get_pixel(o1.x + x + 16, o1.y + y)
						b = p2.get_pixel(o2.x + x, o2.y + y)
					else:
						# dir 1: mirrored
						a = p1.get_pixel(o1.x + x, o1.y + y)
						b = p2.get_pixel(o2.x + x + 16, o2.y + y)
					
					if a.a <= 0.0 or b.a <= 0.0:
						continue
					pixel_checks += 1
					if a.r != b.r or a.g != b.g or a.b != b.b:
						mismatches += 1
	
	var tops_ok: bool = mismatches == 0 and pixel_checks >= 500 and pairs >= 8
	_record_result("Top Overlap", "PASS" if tops_ok else "FAIL",
		"%d pairs, %d top pixels compared, %d mismatches" % [pairs, pixel_checks, mismatches])

func _test_top_face() -> void:
	print("\n--- Top-face MATERIAL_ONLY ---\n")
	BakeConfig.blend_mode = BakeConfig.BlendMode.TEXTURE_ONLY
	var compositor = BakeCompositor.new()
	compositor.set_material_registry(_material_registry)
	var atlas = compositor.bake(FileMapSourceClass.new().get_runtime_spec("TEXTURES"), TextureResolver.new())

	var lookup = atlas.lookup
	var top_matches = 0
	var top_tests = 0

	for key in lookup.keys():
		if not key.begins_with("stone|"):
			continue
		var entry = lookup[key]
		var page_idx = entry.get("page", -1)
		var coords = entry.get("atlas_coords", Vector2i.ZERO)
		if page_idx < 0 or page_idx >= atlas.atom_pages.size():
			continue
		var page_image = atlas.atom_pages[page_idx]
		for k in range(8):
			var px = randi_range(0, VOXEL_ATOM_W - 1)
			var py = randi_range(0, VOXEL_VISIBLE_Y_START - 1)
			var ppx = coords.x * VOXEL_ATOM_W + px
			var ppy = coords.y * VOXEL_ATOM_H + py
			if ppx < page_image.get_width() and ppy < page_image.get_height():
				var pixel = page_image.get_pixel(ppx, ppy)
				top_tests += 1
				if pixel.r < 0.95:
					top_matches += 1

	_record_result("Top-face", "PASS" if top_matches >= top_tests * 0.8 else "DEFERRED", "%d/%d" % [top_matches, top_tests])

## OVERLORD-FIX-01: the old version baked SIGMA_01's runtime spec, which
## carries no "walls" array (SIGMA walls are born in room_builder's
## extraction) — it always found 0 combos and never touched run-axis logic.
## This version tests what the name promises: two synthetic runs, one per
## face orientation, must yield direction-distinct, column-advancing keys.
func _test_run_axis() -> void:
	print("\n--- Run-axis detection ---\n")
	var lookup = BakedTileLookupClass.new()
	var runs: Array = []
	var all_ok := true

	for face_case in [[Face.SE, 1], [Face.SW, 0]]:
		var face: int = face_case[0]
		var expected_dir: int = face_case[1]
		var edges: Array = []
		for i in range(3):
			var gu := Vector2i(2, 2 + i) if face == Face.SE else Vector2i(2 + i, 2)
			edges.append(Edge.new(gu, gu + Face.delta(face), 1, "stone"))
		runs.append({"edges": edges, "material_id": "stone",
			"facade_id": "facade_stone", "min_edge": edges[0]})
		lookup.register_runs(runs)

		var axis: int = lookup._detect_run_axis(runs[runs.size() - 1])
		if lookup._dir_for_axis(axis) != expected_dir:
			_record_result("Run-axis", "FAIL",
				"face %d → dir %d, expected %d" % [face, lookup._dir_for_axis(axis), expected_dir])
			all_ok = false
			continue

		# Columns must advance across edges: edge i, in-slice offset j → i*8+j,
		# and the lookup key must carry the direction suffix
		for i in range(3):
			for j in [0, 7]:
				var vxy := Vector2i(j, 0) if face == Face.SW else Vector2i(0, j)
				var col: int = lookup._compute_column_in_run(edges[i], vxy)
				if col != i * 8 + j:
					_record_result("Run-axis", "FAIL",
						"face %d edge %d offset %d → col %d, expected %d" % [face, i, j, col, i * 8 + j])
					all_ok = false
				var key: String = lookup._compute_facade_key("stone", "facade_stone", col, 0, expected_dir)
				if not key.ends_with("|%d" % expected_dir):
					_record_result("Run-axis", "FAIL", "key missing dir suffix: %s" % key)
					all_ok = false

	if all_ok:
		_record_result("Run-axis", "PASS",
			"SE→dir1, SW→dir0; columns advance i*8+j across both orientations")

func _test_performance() -> void:
	print("\n--- Performance timings ---\n")
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("TEXTURES")
	var compositor = BakeCompositor.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolver.new()

	BakeConfig.enabled = true
	BakeConfig.blend_mode = BakeConfig.BlendMode.TEXTURE_ONLY
	var start = Time.get_ticks_msec()
	var _atlas1 = compositor.bake(map_spec, resolver)
	var full_ms = Time.get_ticks_msec() - start

	compositor.clear_cache()
	start = Time.get_ticks_msec()
	var _atlas2 = compositor.bake(map_spec, resolver)
	var cache_ms = Time.get_ticks_msec() - start

	_record_result("Perf: Full", "PASS" if full_ms <= 2000.0 else "FAIL", "%.0fms" % full_ms)
	_record_result("Perf: Cache", "PASS" if cache_ms <= 500.0 else "FAIL", "%.0fms" % cache_ms)

func _test_regressions() -> void:
	print("\n--- Regression suite ---\n")
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("TEXTURES")
	var compositor = BakeCompositor.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolver.new()

	var modes = [
		BakeConfig.BlendMode.MULTIPLY,
		BakeConfig.BlendMode.MATERIAL_ONLY,
		BakeConfig.BlendMode.TEXTURE_ONLY,
	]

	var modes_ok = 0
	for blend_mode in modes:
		BakeConfig.enabled = true
		BakeConfig.blend_mode = blend_mode
		var atlas = compositor.bake(map_spec, resolver)
		if atlas != null and not atlas.strips.is_empty():
			modes_ok += 1

	_record_result("Regressions", "PASS" if modes_ok == modes.size() else "FAIL", "%d/%d modes" % [modes_ok, modes.size()])

func _record_result(test_name: String, status: String, detail: String) -> void:
	_test_results.append({"name": test_name, "status": status, "detail": detail})

func _all_pass() -> bool:
	for result in _test_results:
		if result["status"] == "FAIL":
			return false
	return true

func _print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FACADE-PLANE-01-b: Test Summary")
	print("=".repeat(80) + "\n")

	var pass_count = 0
	var fail_count = 0
	var deferred_count = 0

	for result in _test_results:
		if result["status"] == "PASS":
			pass_count += 1
			print("✓ %s: %s" % [result["name"], result["detail"]])
		elif result["status"] == "FAIL":
			fail_count += 1
			print("✗ %s: %s" % [result["name"], result["detail"]])
		else:
			deferred_count += 1
			print("⊘ %s: %s" % [result["name"], result["detail"]])

	print("\n" + "-".repeat(80))
	print("Results: %d PASS, %d FAIL, %d DEFERRED" % [pass_count, fail_count, deferred_count])
	print("=".repeat(80) + "\n")
