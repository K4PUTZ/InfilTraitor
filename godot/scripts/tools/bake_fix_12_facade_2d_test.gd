## BAKE-FACADE-PLANE-01-b: Extended pixel-identity test for isometric projection
## Verifies projection u,v formulas, top-face shaded_base, run-axis, performance

extends SceneTree

const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const _GeometryCoords = preload("res://godot/scripts/geometry/geometry_coords.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")
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

	_material_registry = MaterialRegistryClass.new()
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
	_test_top_face()
	_test_junction_top_face()
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

	BakeConfigClass.enabled = true
	BakeConfigClass.blend_mode = BakeConfigClass.BlendMode.TEXTURE_ONLY

	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("TEXTURES")
	if map_spec == null:
		_record_result("Projection", "FAIL", "No TEXTURES map")
		return

	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolverClass.new()

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
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var atlas = compositor.bake(FileMapSourceClass.new().get_runtime_spec("TEXTURES"), TextureResolverClass.new())

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

func _test_top_face() -> void:
	print("\n--- Top-face composed transform ---\n")
	BakeConfigClass.blend_mode = BakeConfigClass.BlendMode.TEXTURE_ONLY
	BakeConfigClass.facade_tops = true
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var atlas = compositor.bake(FileMapSourceClass.new().get_runtime_spec("TEXTURES"), TextureResolverClass.new())

	var lookup = atlas.lookup
	var top_matches = 0
	var top_mismatches = 0
	var top_samples = 0
	var atom_count = 0
	var x_off := 0
	var y_margin := 32

	for key in lookup.keys():
		if not key.begins_with("stone|"):
			continue
		var entry = lookup[key]
		var page_idx = entry.get("page", -1)
		var coords = entry.get("atlas_coords", Vector2i.ZERO)
		if page_idx < 0 or page_idx >= atlas.atom_pages.size():
			continue
		var page_image = atlas.atom_pages[page_idx]
		var parts = key.split("|")
		if parts.size() < 5:
			continue
		var col = int(parts[2])
		var row = int(parts[3])
		var dir = int(parts[4])
		atom_count += 1

		var source := _build_s_ext_for_test(_facade_image, dir)
		x_off = source.get_height() - 1
		var overlay := compositor._get_diamond_overlay("stone", Color.WHITE)
		var top_mask := overlay.get_region(Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START))
		var sample_positions: Array = []
		for py in range(VOXEL_VISIBLE_Y_START):
			for px in range(VOXEL_ATOM_W):
				if top_mask.get_pixel(px, py).a > 0.0:
					sample_positions.append([px, py])
		if sample_positions.is_empty():
			continue
		for sample_idx in range(min(24, sample_positions.size())):
			var pos: Array = sample_positions[(sample_idx * 7 + sample_idx * 3) % sample_positions.size()]
			var px: int = int(pos[0])
			var py: int = int(pos[1])
			var ppx = coords.x * VOXEL_ATOM_W + px
			var ppy = coords.y * VOXEL_ATOM_H + py
			if ppx >= page_image.get_width() or ppy >= page_image.get_height():
				continue
			var pixel = page_image.get_pixel(ppx, ppy)
			if pixel.a <= 0.0:
				continue
			var u0: int = col * 16
			var v0: int = row * 16
			var sx0: int = u0 - v0 + x_off
			var sy0: int = int((float(u0) + float(v0)) / 2.0) + y_margin
			var tx: int = sx0 - 16 + px
			var ty: int = sy0 + py
			var u: int = int(round((float(tx) - float(x_off) + 2.0 * float(ty - y_margin)) / 2.0))
			var v: int = int(round(2.0 * float(ty - y_margin) - float(u)))
			if u < 0 or u >= source.get_width() or v < 0 or v >= source.get_height():
				continue
			var matched := false
			for du in [-1, 0, 1]:
				for dv in [-1, 0, 1]:
					var cu := int(clampi(u + du, 0, source.get_width() - 1))
					var cv := int(clampi(v + dv, 0, source.get_height() - 1))
					var expected_lum := source.get_pixel(cu, cv).r
					if abs(pixel.r - expected_lum) < 0.01:
						matched = true
						break
				if matched:
					break
			top_samples += 1
			if matched:
				top_matches += 1
			else:
				top_mismatches += 1

	_record_result("Top-face", "PASS" if top_mismatches == 0 and top_samples >= 64 and atom_count >= 16 else "FAIL",
			"%d samples, %d matches, %d mismatches across %d atoms" % [top_samples, top_matches, top_mismatches, atom_count])

func _test_junction_top_face() -> void:
	print("\n--- Junction top-face crops ---\n")
	BakeConfigClass.blend_mode = BakeConfigClass.BlendMode.TEXTURE_ONLY
	BakeConfigClass.facade_tops = true
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var map_spec = FileMapSourceClass.new().get_runtime_spec("TEXTURES")
	if map_spec == null:
		_record_result("Junction Top-face", "FAIL", "No TEXTURES map")
		return

	var junction_specs: Array = []
	var junction_by_pos: Dictionary = {}
	for idx in range(4):
		var spec := {
			"voxel_pos": Vector2i(10 + idx, 6 + idx),
			"material_id": "stone",
			"facade_id": "facade_stone",
			"col_x": 8 + idx * 6,
			"col_y": 12 + idx * 5,
			"level_start": 0,
			"level_end": 4,
		}
		junction_specs.append(spec)
		junction_by_pos[spec["voxel_pos"]] = spec
	map_spec = map_spec.duplicate(true)
	map_spec["junction_specs"] = junction_specs

	var atlas = compositor.bake(map_spec, TextureResolverClass.new())
	var plane_top = compositor._get_plane_top("facade_stone", _facade_image, 0)
	var plane_source = compositor._get_plane_source(_facade_image, 0)
	var x_off: int = plane_source.get_height() - 1
	var overlay := compositor._get_diamond_overlay("stone", Color.WHITE)
	var top_mask := overlay.get_region(Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START))
	var samples := 0
	var matches := 0
	var mismatches := 0
	var atoms_tested := 0

	for key in atlas.lookup.keys():
		if not key.begins_with("JUNCTION|"):
			continue
		var parts = key.split("|")
		if parts.size() != 4:
			continue
		var voxel_pos := Vector2i(int(parts[1]), int(parts[2]))
		var spec = junction_by_pos.get(voxel_pos)
		if spec == null:
			continue
		var entry = atlas.lookup[key]
		var page_idx = entry.get("page", -1)
		var coords = entry.get("atlas_coords", Vector2i.ZERO)
		if page_idx < 0 or page_idx >= atlas.atom_pages.size():
			continue
		var page_image = atlas.atom_pages[page_idx]
		var level := int(parts[3])
		var row := compositor._mirror_index(level, BakeCompositorClass.SHEET_ROWS)
		var u0: int = int(spec["col_x"]) * 16
		var v0: int = row * 16
		var sx0: int = u0 - v0 + x_off
		var sy0: int = int((float(u0) + float(v0)) / 2.0) + BakeCompositorClass.V_MARGIN
		var sample_positions: Array = [
			[16, 0], [12, 1], [20, 2], [8, 3], [24, 4], [4, 5], [16, 6], [12, 7],
		]
		atoms_tested += 1
		for pos in sample_positions:
			var px: int = int(pos[0])
			var py: int = int(pos[1])
			if top_mask.get_pixel(px, py).a <= 0.0:
				continue
			var ppx: int = coords.x * VOXEL_ATOM_W + px
			var ppy: int = coords.y * VOXEL_ATOM_H + py
			if ppx >= page_image.get_width() or ppy >= page_image.get_height():
				continue
			var pixel = page_image.get_pixel(ppx, ppy)
			if pixel.a <= 0.0:
				continue
			var expected_px := plane_top.get_pixel(sx0 - 16 + px, sy0 + py)
			samples += 1
			if abs(pixel.r - expected_px.r) < 0.01 and abs(pixel.g - expected_px.g) < 0.01 and abs(pixel.b - expected_px.b) < 0.01 and abs(pixel.a - expected_px.a) < 0.01:
				matches += 1
			else:
				mismatches += 1

	_record_result("Junction Top-face", "PASS" if mismatches == 0 and samples >= 32 and atoms_tested >= 4 else "FAIL",
			"%d samples, %d matches, %d mismatches across %d atoms" % [samples, matches, mismatches, atoms_tested])

func _build_s_ext_for_test(facade: Image, dir: int) -> Image:
	var scaled := facade.duplicate()
	scaled.convert(Image.FORMAT_RGB8)
	scaled.convert(Image.FORMAT_RGBA8)
	scaled.resize(1024, 640, Image.INTERPOLATE_NEAREST)

	var plane_w := 1056
	var v_margin := 32
	var scaled_h := 640
	var s_ext := Image.create(plane_w, v_margin + scaled_h + v_margin, false, Image.FORMAT_RGBA8)
	s_ext.blit_rect(scaled, Rect2i(0, 0, 1024, scaled_h), Vector2i(0, v_margin))
	var flipped_x := scaled.duplicate()
	flipped_x.flip_x()
	s_ext.blit_rect(flipped_x, Rect2i(0, 0, plane_w - 1024, scaled_h), Vector2i(1024, v_margin))
	var flipped_y := s_ext.duplicate()
	flipped_y.flip_y()
	var total_h := v_margin + scaled_h + v_margin
	s_ext.blit_rect(flipped_y, Rect2i(0, total_h - 2 * v_margin, plane_w, v_margin), Vector2i(0, 0))
	s_ext.blit_rect(flipped_y, Rect2i(0, v_margin, plane_w, v_margin), Vector2i(0, total_h - v_margin))

	if dir == 1:
		var mirrored := s_ext.duplicate()
		mirrored.flip_x()
		return mirrored
	return s_ext

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
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolverClass.new()

	BakeConfigClass.enabled = true
	BakeConfigClass.blend_mode = BakeConfigClass.BlendMode.TEXTURE_ONLY
	compositor.clear_cache()
	var start = Time.get_ticks_msec()
	var _atlas1 = compositor.bake(map_spec, resolver)
	var full_ms = Time.get_ticks_msec() - start

	start = Time.get_ticks_msec()
	var _atlas2 = compositor.bake(map_spec, resolver)
	var cache_ms = Time.get_ticks_msec() - start

	_record_result("Perf: Full", "PASS" if full_ms <= 2000.0 else "FAIL", "%.0fms" % full_ms)
	_record_result("Perf: Cache", "PASS" if cache_ms <= 500.0 else "FAIL", "%.0fms" % cache_ms)

func _test_regressions() -> void:
	print("\n--- Regression suite ---\n")
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("TEXTURES")
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_material_registry)
	var resolver = TextureResolverClass.new()

	var modes = [
		BakeConfigClass.BlendMode.MULTIPLY,
		BakeConfigClass.BlendMode.MATERIAL_ONLY,
		BakeConfigClass.BlendMode.TEXTURE_ONLY,
	]

	var modes_ok = 0
	for blend_mode in modes:
		BakeConfigClass.enabled = true
		BakeConfigClass.blend_mode = blend_mode
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
