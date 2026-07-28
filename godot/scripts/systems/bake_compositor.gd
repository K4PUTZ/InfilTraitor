## BakeCompositor — Continuous-plane facade baking (OVERLORD-FIX-01)
##
## Model (replaces every previous half-face/strip scheme):
## A wall run is ONE continuous inclined plane on screen. Each atom carries a
## 32-texel-wide window of that plane, anchored at u = col*16 — consecutive
## atoms' windows OVERLAP by 16 texels on purpose: the occluded halves carry
## the same plane content as the neighbor that covers them, so every visible
## mix of atom fragments (sawtooth overlaps included) is seamless by
## construction. Runs exist in two screen directions, so atoms are baked per
## direction (dir 0: plane descends screen-right; dir 1: mirrored, descends
## screen-left) and direction is part of the lookup key.
##
## Per atom (col, row, dir), side-face content at atom pixel (x, y):
##   dir 0:  u = col*16 + x          y_top(x) = 8 + x/2
##   dir 1:  u = col*16 + (31 - x)   y_top(x) = 8 + (31 - x)/2
##   v = (31 - row)*16 + (y - y_top(x)) * 16/20      (row 31 = top storey)
## Equivalently (what the code does): pre-scale the facade ×20/16 vertically,
## shear it ±x/2 once per direction ("plane image" P), and every atom is an
## axis-aligned 32×28 crop of P at (x0, (31-row)*20 + col*8 + V_MARGIN),
## pasted at atom-local (0, 8) — the x-terms cancel exactly, so composition
## is pure blit_rect with no per-pixel sampling.
##
## RGB in pages is pure facade luminance (grayscale); blend modes are applied
## at registration time via per-tile modulate (TEXTURE_ONLY = white,
## MULTIPLY = material base color). Top faces are baked as material color.
## Alpha = canonical voxel silhouette via blit_rect_mask + an exact byte-level
## fixup of the antialiased (partial-alpha) pixels (B3: alpha verbatim).

class_name BakeCompositor

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")
const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")

const TEX_AUTHORING_N: int = GeometryCoordsClass.TEX_AUTHORING_N   # 16
const VOXEL_ATOM_W: int = GeometryCoordsClass.VOXEL_ATOM_W         # 32
const VOXEL_ATOM_H: int = GeometryCoordsClass.VOXEL_ATOM_H         # 36
const VOXEL_VISIBLE_Y_START: int = 16

## Facade plane: 64 columns × 32 rows of 16-texel windows (1024×512 px source)
const SHEET_COLS: int = 64
const SHEET_ROWS: int = 32
const FACADE_W: int = 1024
const FACADE_H: int = 512

## Plane image geometry (see header). WRAP_W: 32 extra mirrored columns so the
## col=63 atom's 32-texel window can cross the period boundary without a seam.
const PLANE_W: int = FACADE_W + 32          # 1056
const V_MARGIN: int = 32                    # mirrored vertical margin
const SCALED_H: int = 640                   # 512 * 20/16
const PLANE_H: int = 1232                   # V_MARGIN + SCALED_H + PLANE_W/2 + V_MARGIN

## Atlas page: 2048 atoms per sheet → 128 cols × 16 rows of 32×36 tiles
const PAGE_W: int = 4096
const PAGE_TILE_COLS: int = 128
const PAGE_H: int = 576                     # (64*32/128) tile rows × 36 px

const VOXEL_MATERIALS = ["concrete", "metal", "stone", "wood",
	"ground_grass", "ground_concrete", "ground_dirt", "ground_gravel", "ground_sand"]
const VOXEL_BASE_PATH = "res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_"

## MasterStrip kept for API compatibility (strips dictionary consumers);
## atoms are no longer individually materialized on the hot path.
class MasterStrip extends RefCounted:
	var material_id: String
	var facade_id: String
	var atoms: Array

	func _init(p_material_id: String, p_facade_id: String) -> void:
		material_id = p_material_id
		facade_id = p_facade_id
		atoms = []

## BakedAtlas — output of the compositor
class BakedAtlas extends RefCounted:
	var strips: Dictionary          # "mat|fac" → MasterStrip (legacy)
	var atom_pages: Array           # Array[Image], one per (combo, dir)
	var page_modulates: Array       # Array[Color], parallel to atom_pages
	var lookup: Dictionary          # "mat|fac|col|row|dir" → {page, atlas_coords}

	func _init() -> void:
		strips = {}
		atom_pages = []
		page_modulates = []
		lookup = {}

var _material_registry = null
var _voxel_atoms: Dictionary = {}          # material_id → Image (32×36)
var _alpha_aa_lists: Dictionary = {}       # material_id → Array[[x, y, alpha_byte]]
var _diamond_overlays: Dictionary = {}     # material_id → Image (top-face paint)

## Session caches (survive map reloads via room_builder's persistent instance)
var _plane_cache: Dictionary = {}          # facade_id → {0: Image, 1: Image}
var _plane_top_cache: Dictionary = {}      # facade_id → {0: Image, 1: Image}
var _roof_plane_top_cache: Dictionary = {} # facade_id → Image (ROOF-BAKE-02c)
var _page_cache: Dictionary = {}           # "mat|fac|dir" / "ROOF|mat|fac" → {page, coords, frag}

## v4: ROOF-SIDE-01 — roof atom right half-face mirrored from the left
## v5: ROOF-SIDE-02 — roof atom side halves painted only when border-exposed
## v6: ROOF-SIDE-03 — roof atom right half sampled from the dir-1 wall plane
##     (transposed fold), so slab SE faces run in the same direction as the
##     wall below; roof key y-fold widened 32 → 64 to carry it
## v7: ROOF-SIDE-04 — v5 reverted: EVERY roof atom paints both side halves
##     again (Director, 2026-07-18). The masking cured a misdiagnosis (the
##     real lid was v6's direction bug) and left slabs hollow — interior
##     faces are visible whenever occlusion ghosts the front walls, and
##     destruction will expose them for real. Solid atoms cost nothing at
##     draw time; the once-suspected draw-order stomp never reproduced.
## v8: JUNCTION-MIRROR-02 — junction half-crops honor the mirror fold's
##     reflection: a raw column in a reflected segment (e.g. −1, one before
##     the run start) samples the plane MIRRORED in texture space instead of
##     verbatim, so lateral V-junction columns mirror the adjacent wall
##     column instead of repeating it
const BAKE_CODE_VERSION: int = 8
const BAKE_CACHE_PATH: String = "user://bake_cache/"
const BAKE_CACHE_FORMAT_VERSION: int = 2
const BAKE_CACHE_EXTENSION: String = ".bin"

func _init() -> void:
	_load_real_voxel_atoms()

func set_material_registry(registry) -> void:
	_material_registry = registry

## Clear session caches (map switches keep pages — they are map-independent —
## but marker-facade toggles and tests need a full reset)
func clear_cache() -> void:
	_plane_cache.clear()
	_plane_top_cache.clear()
	_roof_plane_top_cache.clear()
	_page_cache.clear()
	print("[BAKE] Session cache cleared")

func clear_disk_cache() -> void:
	var cache_dir: String = BAKE_CACHE_PATH
	var global_dir: String = ProjectSettings.globalize_path(cache_dir)
	if DirAccess.dir_exists_absolute(global_dir):
		DirAccess.remove_absolute(global_dir)
	print("[BAKE] Disk cache cleared")

## Load real voxel atom PNGs (32×36) for alpha copying (B3) and precompute
## per-material derived data: antialiased-pixel list + top-face diamond overlay
func _load_real_voxel_atoms() -> void:
	for material in VOXEL_MATERIALS:
		var path = VOXEL_BASE_PATH + material + ".png"
		var texture: Texture2D = load(path)
		if texture == null:
			push_error("[BAKE] Failed to load texture resource: %s" % path)
			continue
		var img = texture.get_image()
		if img == null:
			push_error("[BAKE] Failed to get image from texture: %s" % path)
			continue
		if img.get_width() != VOXEL_ATOM_W or img.get_height() != VOXEL_ATOM_H:
			push_error("[BAKE] Voxel atom %s has wrong size: %dx%d" % [path, img.get_width(), img.get_height()])
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img = img.duplicate()
			img.convert(Image.FORMAT_RGBA8)
		_voxel_atoms[material] = img
		_alpha_aa_lists[material] = _build_aa_list(img)
		print("[BAKE] Loaded voxel atom: %s (32×36, %d AA pixels)" % [material, _alpha_aa_lists[material].size()])

## Pixels with partial alpha (0 < a < 255): blit_rect_mask rounds them to
## opaque, so they get an exact byte-level fixup after page composition (B3)
func _build_aa_list(img: Image) -> Array:
	var out: Array = []
	for y in range(VOXEL_ATOM_H):
		for x in range(VOXEL_ATOM_W):
			var a := int(round(img.get_pixel(x, y).a * 255.0))
			if a > 0 and a < 255:
				out.append([x, y, a])
	return out

## Top-face overlay: opaque material color inside the top diamond (above the
## side-face top edges y = 8 + x/2 (left) / 24 − x/2 (right)), transparent
## elsewhere. Painted over the plane crop; the silhouette mask clips the rest.
func _get_diamond_overlay(material_id: String, base_color: Color) -> Image:
	if _diamond_overlays.has(material_id):
		return _diamond_overlays[material_id]
	var img := Image.create(VOXEL_ATOM_W, VOXEL_ATOM_H, false, Image.FORMAT_RGBA8)
	for y in range(VOXEL_ATOM_H):
		for x in range(VOXEL_ATOM_W):
			var edge: float = (8.0 + float(x) / 2.0) if x < 16 else (24.0 - float(x) / 2.0)
			if float(y) < edge:
				img.set_pixel(x, y, Color(base_color.r, base_color.g, base_color.b, 1.0))
	_diamond_overlays[material_id] = img
	return img

## Main entry point
func bake(map_spec: Dictionary, resolver) -> BakedAtlas:
	var atlas_result = BakedAtlas.new()
	var combos = _extract_unique_combos(map_spec, resolver)
	print("[BAKE] Found %d unique (material, facade) combos" % combos.size())
	if combos.size() == 0:
		# ROOF-BAKE-02c: a wall-less map can still have roofs (blocks only) —
		# compose their dedicated pages before returning.
		_compose_roof_pages(atlas_result, map_spec.get("roofs", []), {}, resolver, _get_material_registry(), BakeConfigClass.blend_mode)
		print("[BAKE] No wall combos; roof-only bake produced %d lookup entries" % atlas_result.lookup.size())
		return atlas_result

	# Build real placement usage per combo so sparse maps compose only the
	# (col, row) atoms that can ever be queried by lookup.resolve().
	var combo_usage := _extract_combo_usage(map_spec)

	# Resolve facade images
	var facades_by_id = {}
	for combo in combos:
		var facade_id = combo[1]
		if not facades_by_id.has(facade_id):
			var resolved = resolver.resolve(facade_id)
			if resolved != null and resolved.tier != resolver.Tier.NONE:
				facades_by_id[facade_id] = resolved.image

	# OVERLORD-PROBE-01: substitute every facade with the synthetic marker
	if BakeConfigClass.debug_marker_facade:
		var marker := _generate_marker_facade()
		for facade_id in facades_by_id.keys():
			facades_by_id[facade_id] = marker
		print("[BAKE] ⚠ MARKER FACADE ACTIVE — all facades replaced by diagnostic pattern")

	var registry = _get_material_registry()
	var blend_mode: int = BakeConfigClass.blend_mode
	if blend_mode == BakeConfigClass.BlendMode.OVERLAY_EXPERIMENTAL \
			or blend_mode == BakeConfigClass.BlendMode.LINEAR_LIGHT:
		print("[BAKE] ⚠ Blend mode %d rendered as TEXTURE_ONLY (LUT page variants pending)" % blend_mode)

	var start_time = Time.get_ticks_msec()
	for combo in combos:
		var material_id: String = combo[0]
		var facade_id: String = combo[1]
		var facade = facades_by_id.get(facade_id)
		if facade == null:
			print("[BAKE] Skipping %s|%s: facade not resolved" % [material_id, facade_id])
			continue
		var material = registry.get_material(material_id) if registry else null
		if material == null:
			push_error("[BAKE] Material '%s' not found" % material_id)
			continue

		# Per-tile modulate realizes the blend mode on grayscale pages.
		# MATERIAL_ONLY placement short-circuits to the generic atlas, so its
		# modulate here is irrelevant; TEXTURE_ONLY (and, for now, the two
		# experimental modes) = white; MULTIPLY = lifted base_color.
		var modulate := _modulate_for_mode(blend_mode, material)

		for dir in range(2):
			var cache_key := "%s|%s|%d" % [material_id, facade_id, dir]
			var entry = _page_cache.get(cache_key)
			if entry == null:
				var usage_cells: Array = combo_usage.get("%s|%s" % [material_id, facade_id], [])
				entry = _compose_sheet_page(material_id, facade_id, facade, dir, material.base_color, usage_cells)
				_page_cache[cache_key] = entry
				print("[BAKE] Composed sheet %s (2048 atoms)" % cache_key)
			else:
				print("[BAKE] cache HIT for sheet %s" % cache_key)

			var page_idx: int = atlas_result.atom_pages.size()
			atlas_result.atom_pages.append(entry["page"])
			atlas_result.page_modulates.append(modulate)
			for frag_key in entry["frag"]:
				atlas_result.lookup["%s|%s|%s|%d" % [material_id, facade_id, frag_key, dir]] = {
					"page": page_idx,
					"atlas_coords": entry["frag"][frag_key],
				}

		# Materialize dir-0 atoms for the strips API (tests verify per-atom
		# alpha/content against canon). Sliced from the FINAL page, so they
		# carry exactly what placement renders — post-mask, post-AA-fixup.
		var strip := MasterStrip.new(material_id, facade_id)
		var dir0_entry = _page_cache["%s|%s|0" % [material_id, facade_id]]
		var dir0_page: Image = dir0_entry["page"]
		for atom_idx in range(SHEET_COLS * SHEET_ROWS):
			var rx := (atom_idx % PAGE_TILE_COLS) * VOXEL_ATOM_W
			var ry := int(float(atom_idx) / float(PAGE_TILE_COLS)) * VOXEL_ATOM_H
			strip.atoms.append(dir0_page.get_region(Rect2i(rx, ry, VOXEL_ATOM_W, VOXEL_ATOM_H)))
		atlas_result.strips["%s|%s" % [material_id, facade_id]] = strip

	# OVERLORD-FIX-02: junction columns — each half-face continues its leg's
	# plane instead of restarting a facade window (Director spec 2026-07-10).
	# Map-dependent, so composed per bake() (not session-cached); small count.
	_compose_junction_pages(atlas_result, map_spec.get("junction_specs", []), facades_by_id, registry, blend_mode)

	# ROOF-BAKE-02c: dedicated roof page family (isotropic top projection,
	# structure-local keys) — see _compose_roof_pages
	_compose_roof_pages(atlas_result, map_spec.get("roofs", []), facades_by_id, resolver, registry, blend_mode)

	print("[BAKE] Baked %d combos × 2 directions in %.1f ms" % [combos.size(), Time.get_ticks_msec() - start_time])
	return atlas_result

## OVERLORD-FIX-02: compose junction atoms. A junction voxel's LEFT half-face
## (SW-facing, normal +y) is coplanar with the X-axis leg (dir 0 plane); its
## RIGHT half-face (SE-facing, normal +x) is coplanar with the Y-axis leg
## (dir 1 plane). Each half is cropped from its leg's plane at the junction's
## own projected column — one past the run's end, so mirrored-repeat delivers
## the "mirror the last column" continuation naturally.
## spec: {voxel_pos, material_id, facade_id, col_x, col_y, level_start, level_end}
func _compose_junction_pages(atlas_result: BakedAtlas, junction_specs: Array, facades_by_id: Dictionary, registry, blend_mode: int) -> void:
	if junction_specs.is_empty():
		return

	# Group by combo so each page has a uniform material (uniform modulate)
	var by_combo: Dictionary = {}
	for spec in junction_specs:
		var combo_key: String = "%s|%s" % [spec["material_id"], spec["facade_id"]]
		if not by_combo.has(combo_key):
			by_combo[combo_key] = []
		by_combo[combo_key].append(spec)

	for combo_key in by_combo:
		var specs: Array = by_combo[combo_key]
		var parts = combo_key.split("|")
		var material_id: String = parts[0]
		var facade_id: String = parts[1]
		var facade = facades_by_id.get(facade_id)
		var material = registry.get_material(material_id) if registry else null
		if facade == null or material == null:
			push_error("[BAKE] Junction combo %s unresolved — columns fall back to mirror path" % combo_key)
			continue

		var plane0 := _get_plane(facade_id, facade, 0)
		var plane1 := _get_plane(facade_id, facade, 1)
		var plane_top0 := _get_plane_top(facade_id, facade, 0)
		var plane_source0 := _get_plane_source(facade, 0)
		var x_off0: int = plane_source0.get_height() - 1
		var canonical: Image = _voxel_atoms.get(material_id)
		var overlay := _get_diamond_overlay(material_id, material.base_color)
		var top_mask := overlay.get_region(Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START))
		var atom_full := Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_ATOM_H)

		var atom_count := 0
		for spec in specs:
			atom_count += int(spec["level_end"]) - int(spec["level_start"])
		var tile_rows := int(ceil(float(atom_count) / float(PAGE_TILE_COLS)))
		var page := Image.create(PAGE_W, maxi(tile_rows, 1) * VOXEL_ATOM_H, false, Image.FORMAT_RGBA8)
		var coords_used: Array = []
		var atom_idx := 0

		for spec in specs:
			var raw_col_x: int = int(spec["col_x"])
			var raw_col_y: int = int(spec["col_y"])
			# TOP-JUNCTION-06: fold ONCE into the sheet period, then use the folded
			# column for BOTH the horizontal crop and the shear term — exactly what
			# _compose_sheet_page() does for straight runs, where `col` is inside
			# [0, SHEET_COLS) by construction and appears in x0 and y0 alike.
			# room_builder projects a junction onto its leg's run axis as an
			# UNBOUNDED distance (OVERLORD-FIX-02, correct by design), and the
			# straight-run neighbour at that same distance samples
			# _mirror_index_1d(distance, 64) (BakedTileLookup._compute_facade_key).
			# Sampling the folded column is therefore what makes the junction
			# continuous with its own neighbours — and bounds-safety falls out for
			# free: folded ∈ [0, 64) ⇒ source x ∈ [0, 1024] ⇒ always inside PLANE_W.
			# The raw value (TOP-JUNCTION-04) is self-consistent but unbounded, so
			# blit_rect silently clipped it out of the plane (blank side face) or,
			# for col == 64, read the mirrored wrap strip at the wrong shear
			# (displaced side face).
			var col_x := _mirror_index(raw_col_x, SHEET_COLS)
			var col_y := _mirror_index(raw_col_y, SHEET_COLS)
			# JUNCTION-MIRROR-02: a raw column in a reflected fold segment
			# (e.g. −1, one before the run start; or a long perimeter's far
			# corner) must sample its plane crop MIRRORED — the fold alone
			# repeats the adjacent wall column verbatim (the Director's
			# red-circled lateral V-junction seam).
			var reflected_x := _is_reflected_fold(raw_col_x, SHEET_COLS)
			var reflected_y := _is_reflected_fold(raw_col_y, SHEET_COLS)
			var vp: Vector2i = spec["voxel_pos"]
			var blank_px: int = 0
			for level in range(int(spec["level_start"]), int(spec["level_end"])):
				var row := _mirror_index(level, SHEET_ROWS)
				var atom_content := Image.create(VOXEL_ATOM_W, VOXEL_ATOM_H, false, Image.FORMAT_RGBA8)
				# LEFT half ← X-leg (dir 0) plane, left half of its window
				# (mirrored in texture space when the fold reflected — JM-02)
				var y0_x: int = (SHEET_ROWS - 1 - row) * 20 + col_x * 8 + V_MARGIN
				if reflected_x:
					_blit_half_mirrored(atom_content, plane0, col_x * TEX_AUTHORING_N, y0_x, 0, 0)
				else:
					atom_content.blit_rect(plane0, Rect2i(col_x * TEX_AUTHORING_N, y0_x, 16, 28), Vector2i(0, 8))
				# RIGHT half ← Y-leg (dir 1) plane, right half of its window
				# (mirrored in texture space when the fold reflected — JM-02)
				var y0_y: int = (SHEET_ROWS - 1 - row) * 20 + col_y * 8 + V_MARGIN
				if reflected_y:
					_blit_half_mirrored(atom_content, plane1, FACADE_W - col_y * TEX_AUTHORING_N + 16, y0_y, 16, 1)
				else:
					atom_content.blit_rect(plane1, Rect2i(FACADE_W - col_y * TEX_AUTHORING_N + 16, y0_y, 16, 28), Vector2i(16, 8))
				if BakeConfigClass.facade_tops:
					var u0: int = col_x * TEX_AUTHORING_N
					var v0: int = row * TEX_AUTHORING_N
					var sx0: int = u0 - v0 + x_off0
					var sy0: int = int((float(u0) + float(v0)) / 2.0) + V_MARGIN
					var top_crop := plane_top0.get_region(Rect2i(sx0 - 16, sy0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START))
					if top_crop != null:
						atom_content.blit_rect_mask(top_crop, top_mask, Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START), Vector2i.ZERO)
				else:
					atom_content.blend_rect(overlay, atom_full, Vector2i.ZERO)

				# TOP-JUNCTION-06: holes = pixels the canonical silhouette says are
				# solid but that no plane crop reached. A non-zero count means a
				# half-face crop fell outside the plane image and blit_rect
				# silently clipped it (the serrated-silhouette defect). The one
				# survivor is atom pixel (0, 7) on col-0 atoms, canon alpha 4/255:
				# _compose_sheet_page produces it identically on every straight
				# run (64 occurrences in a TEXTURES bake), so junctions now match
				# the shipping reference exactly rather than deviating from it.
				if BakeConfigClass.debug_bake_set_dump and canonical != null:
					for hy in range(VOXEL_ATOM_H):
						for hx in range(VOXEL_ATOM_W):
							if canonical.get_pixel(hx, hy).a > 0.0 and atom_content.get_pixel(hx, hy).a == 0.0:
								blank_px += 1

				var tile_col := atom_idx % PAGE_TILE_COLS
				var tile_row := int(float(atom_idx) / float(PAGE_TILE_COLS))
				var tile_pos := Vector2i(tile_col * VOXEL_ATOM_W, tile_row * VOXEL_ATOM_H)
				if canonical != null:
					page.blit_rect_mask(atom_content, canonical, atom_full, tile_pos)
				else:
					page.blit_rect(atom_content, atom_full, tile_pos)

				var atlas_coords := Vector2i(tile_col, tile_row)
				coords_used.append([atlas_coords, tile_pos])
				atlas_result.lookup["JUNCTION|%d|%d|%d" % [vp.x, vp.y, level]] = {
					"page": atlas_result.atom_pages.size(),
					"atlas_coords": atlas_coords,
				}
				atom_idx += 1

			if BakeConfigClass.debug_bake_set_dump:
				print("[BAKE-DIAG] junction vp=%s mat=%s col_x=%d col_y=%d blank_side_px=%d" % [
					vp, material_id, raw_col_x, raw_col_y, blank_px
				])

		# B3 alpha fixup on the junction page (same rule as sheet pages)
		if canonical != null:
			var aa_list: Array = _alpha_aa_lists.get(material_id, [])
			if not aa_list.is_empty():
				var data: PackedByteArray = page.get_data()
				var page_w := page.get_width()
				for entry in coords_used:
					var tp: Vector2i = entry[1]
					for aa in aa_list:
						data[((tp.y + aa[1]) * page_w + tp.x + aa[0]) * 4 + 3] = aa[2]
				page.set_data(page.get_width(), page.get_height(), false, Image.FORMAT_RGBA8, data)

		atlas_result.atom_pages.append(page)
		atlas_result.page_modulates.append(_modulate_for_mode(blend_mode, material))
		print("[BAKE] Composed junction page: %s (%d atoms)" % [combo_key, atom_idx])

## Luma lift applied to the MULTIPLY modulate (Director, 2026-07-10: MULTIPLY
## is the chosen blend — keeps the voxel's original color — but reads a touch
## dark since facade luminance averages well below 1.0; the lift compensated).
## VL-01 (Director, 2026-07-23): brightness authority moved to the light-bucket
## system (VoxelRenderer.bucket_luminance) — lift retired to 0.0, kept as a
## tunable var in case MULTIPLY needs compensation again.
var multiply_luma_lift: float = 0.0

## Per-tile modulate realizing the blend mode on grayscale baked pages.
## Floor-zone materials (MaterialDef.full_color) are photographic sources —
## forcing WHITE regardless of blend_mode is the entire mechanism that keeps
## their real RGB instead of tinting by base_color (BAKE_SYSTEM_REFERENCE.md
## B2's floor/ground exception).
func _modulate_for_mode(blend_mode: int, material) -> Color:
	if material.full_color:
		return Color.WHITE
	if blend_mode == BakeConfigClass.BlendMode.MULTIPLY:
		return material.base_color.lightened(multiply_luma_lift)
	return Color.WHITE

## Mirrored-repeat index fold (matches BakedTileLookup._mirror_index_1d)
func _mirror_index(index: int, period: int) -> int:
	var period_2x := period * 2
	var k2 := index % period_2x
	if k2 < 0:
		k2 += period_2x
	if k2 >= period:
		k2 = period_2x - k2 - 1
	return k2


## JUNCTION-MIRROR-02: true iff the mirrored-repeat fold REFLECTS at this
## index (odd period segment). _mirror_index() gives the source column but
## drops this bit — and reflected content must be sampled mirrored, or a
## junction column at raw −1 repeats fold-0 verbatim instead of mirroring it.
func _is_reflected_fold(index: int, period: int) -> bool:
	var period_2x := period * 2
	var k2 := index % period_2x
	if k2 < 0:
		k2 += period_2x
	return k2 >= period


## JUNCTION-MIRROR-02: blit one 16px half-face crop MIRRORED in texture
## space. A plain flip_x of the pre-sheared crop would flip the screen shear
## too; instead each destination column takes the mirrored source column
## with its vertical shear delta compensated, so the face keeps its own
## slope while the texture runs mirrored. `shear_shift(x)` must be the same
## formula _get_plane() sheared that dir's source with.
func _blit_half_mirrored(dest: Image, plane: Image, x0: int, y0: int, dest_x: int, dir: int) -> void:
	for i in range(16):
		var x_src: int = x0 + 15 - i
		var shift_src: int = (x_src >> 1) if dir == 0 else ((PLANE_W - 1 - x_src) >> 1)
		var shift_dst: int = ((x0 + i) >> 1) if dir == 0 else ((PLANE_W - 1 - (x0 + i)) >> 1)
		var delta: int = shift_src - shift_dst
		dest.blit_rect(plane, Rect2i(x_src, y0 + delta, 1, 28), Vector2i(dest_x + i, 8))


## ROOF-SIDE-03: collapse a period-64 mirrored fold to its period-32 band
## index — the 20px sheet band formulas only span SHEET_ROWS (32) bands.
## Equals _mirror_index(fold64, 32) for fold64 in 0..63; kept as its own
## named step because roof atoms carry fold64 on BOTH axes and each half
## re-derives the 32-band index from a different axis.
func _band_index(fold64: int) -> int:
	return fold64 if fold64 < SHEET_ROWS else (SHEET_COLS - 1 - fold64)

func _get_plane_source(facade: Image, dir: int) -> Image:
	# S: facade scaled ×20/16 vertically (nearest), grayscale source (B2).
	# The RGB8 round-trip flattens any alpha the facade PNG carries to 255:
	# the facade is a luminance source only — silhouette alpha comes solely
	# from the canonical voxel atom (B3), never from facade pixels.
	var scaled: Image = facade.duplicate()
	scaled.convert(Image.FORMAT_RGB8)
	scaled.convert(Image.FORMAT_RGBA8)
	scaled.resize(FACADE_W, SCALED_H, Image.INTERPOLATE_NEAREST)

	# S_ext: + mirrored horizontal wrap strip + mirrored vertical margins
	var s_ext := Image.create(PLANE_W, V_MARGIN + SCALED_H + V_MARGIN, false, Image.FORMAT_RGBA8)
	s_ext.blit_rect(scaled, Rect2i(0, 0, FACADE_W, SCALED_H), Vector2i(0, V_MARGIN))
	var flipped_x: Image = scaled.duplicate()
	flipped_x.flip_x()
	s_ext.blit_rect(flipped_x, Rect2i(0, 0, PLANE_W - FACADE_W, SCALED_H), Vector2i(FACADE_W, V_MARGIN))
	var flipped_y: Image = s_ext.duplicate()
	flipped_y.flip_y()
	var total_h := V_MARGIN + SCALED_H + V_MARGIN
	s_ext.blit_rect(flipped_y, Rect2i(0, total_h - 2 * V_MARGIN, PLANE_W, V_MARGIN), Vector2i(0, 0))
	s_ext.blit_rect(flipped_y, Rect2i(0, V_MARGIN, PLANE_W, V_MARGIN), Vector2i(0, total_h - V_MARGIN))

	if dir == 1:
		var mirrored := s_ext.duplicate()
		mirrored.flip_x()
		return mirrored
	return s_ext

## Build the plane image P for one direction (see header math), via blits only.
## P(x, y) = S_ext(x, y − floor(x/2))               dir 0
## P(x, y) = M_ext(x, y − floor((PLANE_W−1 − x)/2)) dir 1 (M = mirrored S)
func _get_plane(facade_id: String, facade: Image, dir: int) -> Image:
	if _plane_cache.has(facade_id) and _plane_cache[facade_id].has(dir):
		return _plane_cache[facade_id][dir]

	var source := _get_plane_source(facade, dir)

	# Shear via 2-px column strips (shift constant within each even pair)
	var plane := Image.create(PLANE_W, PLANE_H, false, Image.FORMAT_RGBA8)
	var src_h := source.get_height()
	for x in range(0, PLANE_W, 2):
		var shift: int
		if dir == 0:
			shift = x >> 1
		else:
			shift = (PLANE_W - 1 - x) >> 1
		plane.blit_rect(source, Rect2i(x, 0, 2, src_h), Vector2i(x, shift))

	if not _plane_cache.has(facade_id):
		_plane_cache[facade_id] = {}
	_plane_cache[facade_id][dir] = plane
	return plane

## Build the top-face plane T for one direction via the two-pass shear from the
## prompt. The mapping contract is:
##   T(u − v + X_OFF, (u + v)/2 + Y_MARGIN) == S_ext(u, v)
func _get_plane_top(facade_id: String, facade: Image, dir: int) -> Image:
	if _plane_top_cache.has(facade_id) and _plane_top_cache[facade_id].has(dir):
		return _plane_top_cache[facade_id][dir]

	var source := _get_plane_source(facade, dir)
	var x_off: int = source.get_height() - 1
	var width: int = source.get_width() + x_off
	var height: int = int(ceil(float(source.get_width() + source.get_height()) / 2.0)) + V_MARGIN + 1
	var plane_top := Image.create(width, height, false, Image.FORMAT_RGBA8)

	for v in range(source.get_height()):
		for u in range(source.get_width()):
			var dst_x: int = u - v + x_off
			var dst_y: int = int((float(u) + float(v)) / 2.0) + V_MARGIN
			plane_top.set_pixel(dst_x, dst_y, source.get_pixel(u, v))

	if not _plane_top_cache.has(facade_id):
		_plane_top_cache[facade_id] = {}
	_plane_top_cache[facade_id][dir] = plane_top
	return plane_top

## ROOF-BAKE-02c: roof plane source — the facade laid flat 1:1, NO ×20/16
## vertical pre-scale. The wall source's pre-scale exists because wall levels
## are 20 px tall against 16-texel authoring rows; on a horizontal surface
## both axes are ground axes at 16 texels per voxel, so the wall source reads
## 25% stretched along y. Unscaled, the 64×32 sheet windows cover the
## 1024×512 facade EXACTLY — full period, isotropic. Same S_ext recipe as
## _get_plane_source dir 0 otherwise (grayscale flatten, mirrored wrap strip,
## mirrored vertical margins).
## `target_h` defaults to FACADE_H (512, the wall/ceiling facade's own
## anisotropic height) for backward compat. Floor-zone bake passes FACADE_W
## (1024) instead — resolve_flat() folds BOTH axes at period SHEET_COLS=64,
## so a floor source wants a genuinely isotropic 1024x1024 plane, not the
## wall facade's inherited 2:1 aspect.
func _get_roof_plane_source(facade: Image, target_h: int = FACADE_H) -> Image:
	var flat: Image = facade.duplicate()
	flat.convert(Image.FORMAT_RGB8)
	flat.convert(Image.FORMAT_RGBA8)
	if flat.get_width() != FACADE_W or flat.get_height() != target_h:
		flat.resize(FACADE_W, target_h, Image.INTERPOLATE_NEAREST)

	var s_ext := Image.create(PLANE_W, V_MARGIN + target_h + V_MARGIN, false, Image.FORMAT_RGBA8)
	s_ext.blit_rect(flat, Rect2i(0, 0, FACADE_W, target_h), Vector2i(0, V_MARGIN))
	var flipped_x: Image = flat.duplicate()
	flipped_x.flip_x()
	s_ext.blit_rect(flipped_x, Rect2i(0, 0, PLANE_W - FACADE_W, target_h), Vector2i(FACADE_W, V_MARGIN))
	var flipped_y: Image = s_ext.duplicate()
	flipped_y.flip_y()
	var total_h := V_MARGIN + target_h + V_MARGIN
	s_ext.blit_rect(flipped_y, Rect2i(0, total_h - 2 * V_MARGIN, PLANE_W, V_MARGIN), Vector2i(0, 0))
	s_ext.blit_rect(flipped_y, Rect2i(0, V_MARGIN, PLANE_W, V_MARGIN), Vector2i(0, total_h - V_MARGIN))
	return s_ext


## ROOF-BAKE-02c: roof top plane — the same two-pass isometric projection as
## _get_plane_top (identical mapping contract, identical crop formula in the
## consumer) built from the UNSCALED roof source. One image per facade (no
## direction: a horizontal surface has none).
func _get_roof_plane_top(facade_id: String, facade: Image, target_h: int = FACADE_H) -> Image:
	if _roof_plane_top_cache.has(facade_id):
		return _roof_plane_top_cache[facade_id]

	var source := _get_roof_plane_source(facade, target_h)
	var x_off: int = source.get_height() - 1
	var width: int = source.get_width() + x_off
	var height: int = int(ceil(float(source.get_width() + source.get_height()) / 2.0)) + V_MARGIN + 1
	var plane_top := Image.create(width, height, false, Image.FORMAT_RGBA8)

	for v in range(source.get_height()):
		for u in range(source.get_width()):
			var dst_x: int = u - v + x_off
			var dst_y: int = int((float(u) + float(v)) / 2.0) + V_MARGIN
			plane_top.set_pixel(dst_x, dst_y, source.get_pixel(u, v))

	_roof_plane_top_cache[facade_id] = plane_top
	return plane_top


## ROOF-BAKE-02c: compose the roof page family. One page per (material,
## facade) combo; atoms keyed "ROOF|mat|fac|col|row" where (col, row) is the
## mirrored fold of the STRUCTURE-LOCAL voxel offset (cells arrive local from
## room_builder; the fold happens here, in the module that owns sheet
## periods). Atom content: top diamond from the isotropic roof plane, side
## faces from the dir-0 wall plane at the same fold (kept textured — border
## voxels show them; the Director judges their final treatment separately).
func _compose_roof_pages(atlas_result: BakedAtlas, roof_specs: Array, facades_by_id: Dictionary, resolver, registry, blend_mode: int) -> void:
	for roof in roof_specs:
		if typeof(roof) != TYPE_DICTIONARY:
			continue
		var material_id: String = String(roof.get("material_id", ""))
		var facade_id: String = String(roof.get("facade_id", ""))
		if facade_id == "":
			continue
		var facade = facades_by_id.get(facade_id)
		if facade == null and resolver != null:
			var resolved = resolver.resolve(facade_id)
			if resolved != null and resolved.tier != resolver.Tier.NONE:
				facade = resolved.image
				facades_by_id[facade_id] = facade
		var material = registry.get_material(material_id) if registry else null
		if facade == null or material == null:
			push_error("[BAKE] Roof combo %s|%s unresolved — roof falls back to generic atlas" % [material_id, facade_id])
			continue

		var cache_key := "ROOF|%s|%s" % [material_id, facade_id]
		var entry = _page_cache.get(cache_key)
		if entry == null:
			entry = _compose_roof_page(material_id, facade_id, facade, material.base_color, roof.get("cells", []), material.full_color)
			_page_cache[cache_key] = entry
			print("[BAKE] Composed roof page %s (%d atoms)" % [cache_key, entry["frag"].size()])
		else:
			print("[BAKE] cache HIT for roof page %s" % cache_key)

		var page_idx: int = atlas_result.atom_pages.size()
		atlas_result.atom_pages.append(entry["page"])
		atlas_result.page_modulates.append(_modulate_for_mode(blend_mode, material))
		for frag_key in entry["frag"]:
			atlas_result.lookup["ROOF|%s|%s|%s" % [material_id, facade_id, frag_key]] = {
				"page": page_idx,
				"atlas_coords": entry["frag"][frag_key],
			}


## ROOF-BAKE-02c: compose one roof page. Mirrors _compose_sheet_page's atom
## recipe (side crop + masked top crop + canonical silhouette + B3 AA fixup)
## with the top sourced from the isotropic roof plane; page sized to the atom
## count like junction pages (roof usage is sparse by nature).
func _compose_roof_page(material_id: String, facade_id: String, facade: Image, base_color: Color, cells: Array, is_floor_bake: bool = false) -> Dictionary:
	# Floor-zone bake wants an isotropic 1024x1024 top source (see
	# _get_roof_plane_source's doc comment); ceiling/roof keeps the
	# wall-inherited 1024x512. Side faces (below) are unaffected either way —
	# v1 deliberately leaves them on the wall-style plane (see plan doc).
	var top_target_h: int = FACADE_W if is_floor_bake else FACADE_H
	# ROOF-SIDE-04: every atom paints BOTH side halves — slabs are SOLID.
	# Interior side faces are visible whenever occlusion ghosts the front
	# walls, and destruction will expose them for real (v5's border-only
	# masking left slabs hollow; see BAKE_CODE_VERSION history).
	# ROOF-SIDE-03: BOTH axes fold at period 64 (SHEET_COLS) — the right
	# half's transposed dir-1 crop consumes y as a run position, which a
	# period-32 fold cannot carry (fold32 is derivable from fold64, never
	# the reverse). The 32-band indices each half needs are re-derived from
	# the 64-folds via _band_index().
	var folded_seen: Dictionary = {}
	var folded_cells: Array = []
	for cell in cells:
		var pos: Vector2i = cell
		var folded := Vector2i(_mirror_index(pos.x, SHEET_COLS), _mirror_index(pos.y, SHEET_COLS))
		if not folded_seen.has(folded):
			folded_seen[folded] = true
			folded_cells.append(folded)

	var plane := _get_plane(facade_id, facade, 0)
	var plane1 := _get_plane(facade_id, facade, 1)  # ROOF-SIDE-03: SE half source
	var roof_top := _get_roof_plane_top(facade_id, facade, top_target_h)
	var roof_source := _get_roof_plane_source(facade, top_target_h)
	var x_off: int = roof_source.get_height() - 1
	var canonical: Image = _voxel_atoms.get(material_id)
	if canonical == null:
		push_error("[BAKE] B6: no canonical voxel atom for '%s' — roof page %s|%s will render unmasked rectangles" % [
			material_id, material_id, facade_id])
	var overlay := _get_diamond_overlay(material_id, base_color)
	var top_mask := overlay.get_region(Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START))
	var atom_full := Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_ATOM_H)

	var tile_rows := int(ceil(float(folded_cells.size()) / float(PAGE_TILE_COLS)))
	var page := Image.create(PAGE_W, maxi(tile_rows, 1) * VOXEL_ATOM_H, false, Image.FORMAT_RGBA8)
	var frag: Dictionary = {}
	var coords_used: Array = []
	var atom_idx := 0

	for folded in folded_cells:
		var col: int = folded.x   # fold64 of local x
		var row: int = folded.y   # fold64 of local y (ROOF-SIDE-03)
		var row_band: int = _band_index(row)   # 32-band index for left/top math
		var col_band: int = _band_index(col)   # 32-band index for the SE half

		var atom_content := Image.create(VOXEL_ATOM_W, VOXEL_ATOM_H, false, Image.FORMAT_RGBA8)
		# LEFT (SW-facing) half: dir-0 wall plane at the same fold — the run
		# position along the SW edge is x, exactly the wall sheet's own
		# (col, row) roles, so this half always ran in the wall's direction.
		var side_y0: int = (SHEET_ROWS - 1 - row_band) * 20 + col * 8 + V_MARGIN
		atom_content.blit_rect(plane, Rect2i(col * TEX_AUTHORING_N, side_y0, VOXEL_ATOM_W, 28), Vector2i(0, 8))
		# ROOF-SIDE-03 (2026-07-17, Director's diagram): the RIGHT (SE-facing)
		# half must run in the same direction as the dir-1 wall face below it.
		# ROOF-SIDE-01's mirror of the left half had the right shear but the
		# wrong progression: along the SE edge only y advances, and the dir-0
		# crop never consumes y as a run position. Transpose the roles — run
		# position = y (dir-1 sheet formula x0 = FACADE_W − y·16, right half
		# at +16), 20px band index = x, ·8 half-step stagger = y — the exact
		# math _compose_sheet_page uses for dir-1 wall atoms.
		var side_y0_r: int = (SHEET_ROWS - 1 - col_band) * 20 + row * 8 + V_MARGIN
		var x0_r: int = FACADE_W - row * TEX_AUTHORING_N
		atom_content.blit_rect(plane1, Rect2i(x0_r + 16, side_y0_r, 16, 28), Vector2i(16, 8))
		# Top diamond: isotropic roof plane at the projected local position
		var u0: int = col * TEX_AUTHORING_N
		var v0: int = row * TEX_AUTHORING_N
		var sx0: int = u0 - v0 + x_off
		var sy0: int = int((float(u0) + float(v0)) / 2.0) + V_MARGIN
		var top_crop := roof_top.get_region(Rect2i(sx0 - 16, sy0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START))
		if top_crop != null:
			atom_content.blit_rect_mask(top_crop, top_mask, Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START), Vector2i.ZERO)

		var tile_col := atom_idx % PAGE_TILE_COLS
		var tile_row := int(float(atom_idx) / float(PAGE_TILE_COLS))
		var tile_pos := Vector2i(tile_col * VOXEL_ATOM_W, tile_row * VOXEL_ATOM_H)
		if canonical != null:
			page.blit_rect_mask(atom_content, canonical, atom_full, tile_pos)
		else:
			page.blit_rect(atom_content, atom_full, tile_pos)

		var atlas_coords := Vector2i(tile_col, tile_row)
		frag["%d|%d" % [col, row]] = atlas_coords
		coords_used.append(tile_pos)
		atom_idx += 1

	# B3 alpha fixup (exact canonical byte at every partial-alpha pixel)
	if canonical != null:
		var aa_list: Array = _alpha_aa_lists.get(material_id, [])
		if not aa_list.is_empty():
			var data: PackedByteArray = page.get_data()
			var page_w := page.get_width()
			for tp in coords_used:
				for aa in aa_list:
					data[((tp.y + aa[1]) * page_w + tp.x + aa[0]) * 4 + 3] = aa[2]
			page.set_data(page.get_width(), page.get_height(), false, Image.FORMAT_RGBA8, data)

	return {"page": page, "coords": coords_used, "frag": frag}


## Compose one page for (material, facade, dir).
## When usage_cells is provided, only the referenced (col, row) atoms are
## composed and cropped; otherwise the full 64×32 sweep is used.
## Pure region ops per atom: 1 crop blit + 1 diamond blend + 1 masked blit,
## then a single byte-level pass fixing the antialiased alpha pixels (B3).
func _compose_sheet_page(material_id: String, facade_id: String, facade: Image, dir: int, base_color: Color, usage_cells: Array = []) -> Dictionary:
	var plane := _get_plane(facade_id, facade, dir)
	var canonical: Image = _voxel_atoms.get(material_id)
	if canonical == null:
		# B6 loud-fail: without the canonical atom there is no silhouette —
		# atoms would render as full 32×36 rectangles. Never silent.
		push_error("[BAKE] B6: no canonical voxel atom for '%s' — sheet %s|%s|%d will render unmasked rectangles" % [
			material_id, material_id, facade_id, dir])
	var overlay := _get_diamond_overlay(material_id, base_color)
	var plane_top := _get_plane_top(facade_id, facade, dir)
	var plane_source := _get_plane_source(facade, dir)
	var x_off: int = plane_source.get_height() - 1
	var page := Image.create(PAGE_W, PAGE_H, false, Image.FORMAT_RGBA8)
	var frag: Dictionary = {}   # "col|row" → atlas_coords
	var coords: Array = []
	var min_col: int = PAGE_TILE_COLS
	var max_col: int = -1
	var min_row: int = PAGE_TILE_COLS
	var max_row: int = -1

	var atom_full := Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_ATOM_H)
	var top_mask := overlay.get_region(Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START))
	var atom_idx := 0
	var cells_to_render: Array = []
	if usage_cells != null and not usage_cells.is_empty():
		for cell in usage_cells:
			if cell is Vector2i:
				cells_to_render.append(cell)
			elif cell is Array and cell.size() >= 2:
				cells_to_render.append(Vector2i(int(cell[0]), int(cell[1])))
	else:
		for row in range(SHEET_ROWS):
			for col in range(SHEET_COLS):
				cells_to_render.append(Vector2i(col, row))

	for cell in cells_to_render:
		var col: int = int(cell.x)
		var row: int = int(cell.y)
		var x0: int
		if dir == 0:
			x0 = col * TEX_AUTHORING_N
		else:
			x0 = FACADE_W - col * TEX_AUTHORING_N
		var y0: int = (SHEET_ROWS - 1 - row) * 20 + col * 8 + V_MARGIN

		var atom_content := Image.create(VOXEL_ATOM_W, VOXEL_ATOM_H, false, Image.FORMAT_RGBA8)
		atom_content.blit_rect(plane, Rect2i(x0, y0, VOXEL_ATOM_W, 28), Vector2i(0, 8))
		if BakeConfigClass.facade_tops:
			var u0: int = col * TEX_AUTHORING_N
			var v0: int = row * TEX_AUTHORING_N
			var sx0: int = u0 - v0 + x_off
			var sy0: int = int((float(u0) + float(v0)) / 2.0) + V_MARGIN
			var top_crop := plane_top.get_region(Rect2i(sx0 - 16, sy0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START))
			if top_crop != null:
				atom_content.blit_rect_mask(top_crop, top_mask, Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_VISIBLE_Y_START), Vector2i.ZERO)
		else:
			atom_content.blend_rect(overlay, atom_full, Vector2i.ZERO)

		var tile_col := atom_idx % PAGE_TILE_COLS
		var tile_row := int(float(atom_idx) / float(PAGE_TILE_COLS))
		var tile_pos := Vector2i(tile_col * VOXEL_ATOM_W, tile_row * VOXEL_ATOM_H)
		if canonical != null:
			page.blit_rect_mask(atom_content, canonical, atom_full, tile_pos)
		else:
			page.blit_rect(atom_content, atom_full, tile_pos)

		var atlas_coords := Vector2i(tile_col, tile_row)
		frag["%d|%d" % [col, row]] = atlas_coords
		coords.append(atlas_coords)
		min_col = mini(min_col, tile_col)
		max_col = maxi(max_col, tile_col)
		min_row = mini(min_row, tile_row)
		max_row = maxi(max_row, tile_row)
		atom_idx += 1

	# B3 alpha fixup: write the exact canonical alpha byte at every partial-
	# alpha pixel of every atom (masked blit rounded them to opaque)
	if canonical != null:
		var aa_list: Array = _alpha_aa_lists.get(material_id, [])
		if not aa_list.is_empty():
			var data: PackedByteArray = page.get_data()
			for fix_idx in range(SHEET_COLS * SHEET_ROWS):
				var fix_x := (fix_idx % PAGE_TILE_COLS) * VOXEL_ATOM_W
				var fix_y := int(float(fix_idx) / float(PAGE_TILE_COLS)) * VOXEL_ATOM_H
				for aa in aa_list:
					var idx: int = ((fix_y + aa[1]) * PAGE_W + fix_x + aa[0]) * 4 + 3
					data[idx] = aa[2]
			page.set_data(PAGE_W, PAGE_H, false, Image.FORMAT_RGBA8, data)

	var crop_x0: int = min_col * VOXEL_ATOM_W
	var crop_y0: int = min_row * VOXEL_ATOM_H
	var crop_w: int = (max_col - min_col + 1) * VOXEL_ATOM_W if coords.size() > 0 else VOXEL_ATOM_W
	var crop_h: int = (max_row - min_row + 1) * VOXEL_ATOM_H if coords.size() > 0 else VOXEL_ATOM_H
	var crop_rect := Rect2i(crop_x0, crop_y0, crop_w, crop_h)
	var cropped_page := page.get_region(crop_rect)
	var remapped_frag: Dictionary = {}
	for frag_key in frag:
		var atlas_coords: Vector2i = frag[frag_key]
		remapped_frag[frag_key] = Vector2i(atlas_coords.x - min_col, atlas_coords.y - min_row)

	return {"page": cropped_page, "coords": coords, "frag": remapped_frag, "crop_rect": crop_rect}

## Extract unique (material, facade) combos from the map
func _extract_combo_usage(map_spec: Dictionary) -> Dictionary:
	var usage_by_combo: Dictionary = {}
	# ROOF-BAKE-01: no early return on missing "walls" — a roofs-only
	# map_spec (headless tests) still contributes usage below.
	var walls = map_spec.get("walls", []) if typeof(map_spec.get("walls", [])) == TYPE_ARRAY else []
	for wall in walls:
		if typeof(wall) != TYPE_DICTIONARY:
			continue
		var material_id = String(wall.get("material_id", "default"))
		var facade_id = String(wall.get("facade_id", "facade_" + material_id))
		var combo_key := "%s|%s" % [material_id, facade_id]
		if not usage_by_combo.has(combo_key):
			usage_by_combo[combo_key] = {}
		var seen: Dictionary = usage_by_combo[combo_key]

		var edge = wall.get("edge")
		var run = wall.get("run")
		if edge == null or run == null:
			continue

		var position_in_run := _get_edge_position_in_run(edge, run)
		if position_in_run < 0:
			continue

		var col_start := position_in_run * 8
		var col_end := col_start + 7
		var start_level := 0
		var storey_count := 1
		if edge.has_method("get_start_storey"):
			start_level = int(edge.get_start_storey()) * GeometryCoordsClass.LEVELS_PER_STOREY
		elif "start_storey" in edge:
			start_level = int(edge.start_storey) * GeometryCoordsClass.LEVELS_PER_STOREY
		if edge.has_method("get_storey_count"):
			storey_count = int(edge.get_storey_count())
		elif "storey_count" in edge:
			storey_count = int(edge.storey_count)

		var end_level := start_level + (storey_count * GeometryCoordsClass.LEVELS_PER_STOREY)
		for row in range(start_level, end_level):
			for col in range(col_start, col_end + 1):
				var cell_key := "%d|%d" % [col, row]
				if not seen.has(cell_key):
					seen[cell_key] = true

	var result: Dictionary = {}
	for combo_key in usage_by_combo:
		var seen: Dictionary = usage_by_combo[combo_key]
		var cells: Array = []
		for cell_key in seen.keys():
			var parts := String(cell_key).split("|")
			if parts.size() >= 2:
				cells.append(Vector2i(int(parts[0]), int(parts[1])))
		result[combo_key] = cells
	return result

func _get_edge_position_in_run(edge, run: Dictionary) -> int:
	var edges = run.get("edges", [])
	for i in range(edges.size()):
		if edges[i].id == edge.id:
			return i
	return -1

func _extract_unique_combos(map_spec: Dictionary, _resolver) -> Array:
	var combos = {}
	var blocks = []
	if map_spec.has("sections") and map_spec["sections"].has("blocks"):
		var blocks_section = map_spec["sections"]["blocks"]
		if blocks_section.has("items"):
			blocks = blocks_section["items"]
	elif map_spec.has("blocks"):
		blocks = map_spec["blocks"] if typeof(map_spec["blocks"]) == TYPE_ARRAY else []
	for block in blocks:
		var material = block.get("material", "default") if typeof(block) == TYPE_DICTIONARY else "default"
		combos["%s|facade_%s" % [material, material]] = true
	# Real production callers pass map_spec["walls"] (see room_builder._bake_textures)
	if map_spec.has("walls"):
		var walls = map_spec["walls"] if typeof(map_spec["walls"]) == TYPE_ARRAY else []
		for wall in walls:
			if typeof(wall) != TYPE_DICTIONARY:
				continue
			var material_id = wall.get("material_id", "default")
			var facade_id = wall.get("facade_id", "facade_" + material_id)
			combos["%s|%s" % [material_id, facade_id]] = true
	# (ROOF-BAKE-02c: roofs no longer contribute WALL-sheet combos — they get
	# a dedicated page family via _compose_roof_pages(), isotropic projection.)
	var result = []
	for key in combos.keys():
		var parts = key.split("|")
		result.append([parts[0], parts[1]])
	return result

## OVERLORD-PROBE-01: synthetic diagnostic facade (grayscale, B2-compliant).
## Brightness staircase per 16-px column window + black window seams + white
## row lines (thick every 4th) — rendered walls reveal window order and shear.
func _generate_marker_facade() -> Image:
	var img := Image.create(FACADE_W, FACADE_H, false, Image.FORMAT_RGBA8)
	for i in range(SHEET_COLS):
		var lum := 0.20 + 0.70 * (float(i) / 63.0)
		img.fill_rect(Rect2i(i * 16, 0, 16, FACADE_H), Color(lum, lum, lum, 1.0))
	for i in range(SHEET_COLS):
		img.fill_rect(Rect2i(i * 16, 0, 1, FACADE_H), Color(0.0, 0.0, 0.0, 1.0))
	for j in range(SHEET_ROWS):
		var thickness := 2 if j % 4 == 0 else 1
		img.fill_rect(Rect2i(0, j * 16, FACADE_W, thickness), Color(1.0, 1.0, 1.0, 1.0))
	return img

## Get global material registry
func _get_material_registry():
	if Engine.has_meta("BAKE_TEST_REGISTRY"):
		return Engine.get_meta("BAKE_TEST_REGISTRY")
	if _material_registry != null:
		return _material_registry
	if Engine.has_meta("GLOBAL_MATERIAL_REGISTRY"):
		return Engine.get_meta("GLOBAL_MATERIAL_REGISTRY")
	return null


## FNV-1a 32-bit hash for cache key (BAKE-CACHE-01).
## OVERLORD cleanup (2026-07-11): this used to be a home-grown XOR/shift
## function *labeled* "FNV-1a" that was not FNV-1a (no multiply by the FNV
## prime) — a second, fake hash implementation living beside the real,
## B4-tested one in `FacadeSampler._fnv1a_hash()`. B4 pins FNV-1a
## determinism project-wide; a differently-named non-FNV hash calling
## itself FNV-1a is exactly the kind of drift that invariant exists to
## prevent. Same constants as the canonical implementation (offset basis
## 2166136261, prime 16777619) — one algorithm in the codebase, not two,
## just inlined here because it operates on bytes, not a String.
## Returns hex string; 32-bit key space is ample for a page-count cache.
func _fnv1a_64(data: PackedByteArray) -> String:
	var hash_val: int = 2166136261  # FNV offset basis (canon: facade_sampler.gd)
	var fnv_prime: int = 16777619
	for byte_val in data:
		hash_val ^= byte_val
		hash_val = (hash_val * fnv_prime) & 0xFFFFFFFF
	return "%08x" % hash_val

## Get cache key for a page: FNV-1a hash of facade bytes + material + dir + version
func _get_disk_cache_key(facade: Image, material_id: String, dir: int, crop_rect: Rect2i = Rect2i()) -> String:
	var facade_data: PackedByteArray = facade.get_data()
	var key_input: PackedByteArray = PackedByteArray()
	key_input.append_array(facade_data)
	key_input.append_array(material_id.to_utf8_buffer())
	key_input.push_back(dir)
	key_input.push_back(BAKE_CODE_VERSION)
	for value in [crop_rect.position.x, crop_rect.position.y, crop_rect.size.x, crop_rect.size.y]:
		key_input.push_back((value >> 24) & 0xFF)
		key_input.push_back((value >> 16) & 0xFF)
		key_input.push_back((value >> 8) & 0xFF)
		key_input.push_back(value & 0xFF)
	return _fnv1a_64(key_input)

func _encode_cache_image(page: Image) -> PackedByteArray:
	var raw := page.get_data()
	var header := PackedByteArray()
	header.append_array(PackedByteArray([0x49, 0x46, 0x43, 0x01]))
	header.append((BAKE_CACHE_FORMAT_VERSION >> 24) & 0xFF)
	header.append((BAKE_CACHE_FORMAT_VERSION >> 16) & 0xFF)
	header.append((BAKE_CACHE_FORMAT_VERSION >> 8) & 0xFF)
	header.append(BAKE_CACHE_FORMAT_VERSION & 0xFF)
	header.append((page.get_width() >> 24) & 0xFF)
	header.append((page.get_width() >> 16) & 0xFF)
	header.append((page.get_width() >> 8) & 0xFF)
	header.append(page.get_width() & 0xFF)
	header.append((page.get_height() >> 24) & 0xFF)
	header.append((page.get_height() >> 16) & 0xFF)
	header.append((page.get_height() >> 8) & 0xFF)
	header.append(page.get_height() & 0xFF)
	header.append(page.get_format())
	var payload := PackedByteArray()
	payload.append_array(header)
	payload.append_array(raw)
	return payload

func _decode_cache_image(data: PackedByteArray) -> Image:
	if data.size() < 16:
		return null
	if data[0] != 0x49 or data[1] != 0x46 or data[2] != 0x43 or data[3] != 0x01:
		return null
	var version := (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7]
	if version != BAKE_CACHE_FORMAT_VERSION:
		return null
	var width := (data[8] << 24) | (data[9] << 16) | (data[10] << 8) | data[11]
	var height := (data[12] << 24) | (data[13] << 16) | (data[14] << 8) | data[15]
	var format_id := data[16]
	var payload_start := 17
	var payload := data.slice(payload_start, data.size())
	var img := Image.create(width, height, false, format_id)
	if img == null:
		return null
	img.set_data(width, height, false, format_id, payload)
	return img

## Load page from disk cache; returns null on miss or corruption
func _disk_cache_load(cache_key: String) -> Image:
	var cache_file: String = BAKE_CACHE_PATH + cache_key + BAKE_CACHE_EXTENSION
	var global_path: String = ProjectSettings.globalize_path(cache_file)
	var legacy_path: String = ProjectSettings.globalize_path(BAKE_CACHE_PATH + cache_key + ".png")
	if FileAccess.file_exists(global_path):
		var file_data = FileAccess.get_file_as_bytes(global_path)
		if file_data == null or file_data.size() == 0:
			print("[BAKE] Disk cache MISS: file empty or unreadable %s" % global_path)
			return null
		var img := _decode_cache_image(file_data)
		if img == null:
			print("[BAKE] Disk cache MISS (unsupported format): %s" % global_path)
			return null
		print("[BAKE] Disk cache HIT: loaded %s" % cache_key)
		return img
	if FileAccess.file_exists(legacy_path):
		print("[BAKE] Disk cache MISS (legacy .png format): %s" % legacy_path)
		return null
	print("[BAKE] Disk cache MISS: file not found %s" % global_path)
	return null

## Save page to disk cache
func _disk_cache_save(cache_key: String, page: Image) -> void:
	var cache_dir: String = BAKE_CACHE_PATH
	var global_dir: String = ProjectSettings.globalize_path(cache_dir)
	if not DirAccess.dir_exists_absolute(global_dir):
		DirAccess.make_dir_absolute(global_dir)
	var path = global_dir + "/" + cache_key + BAKE_CACHE_EXTENSION
	var payload := _encode_cache_image(page)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[BAKE] Failed to save disk cache image: %s" % path)
		return
	file.store_buffer(payload)
	print("[BAKE] Disk cache saved: %s" % cache_key)
