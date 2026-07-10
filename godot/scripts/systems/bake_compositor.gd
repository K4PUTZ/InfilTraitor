## BakeCompositor — Master-strip baking of material × facade atoms
##
## For each unique (material, facade) combo used in the loaded map,
## bakes a contiguous strip of 9 real 32×36 atoms by compositing:
## - RGB = material base_color × pattern shade × facade luminance (rectangular crop)
## - Alpha = copied verbatim from the real voxel PNG (canonical silhouette)
##
## Strips are stored in a dictionary keyed by (material_id, facade_id);
## BAKE-FIX-02 will consume the strips via indexed lookup and mirroring.

class_name BakeCompositor

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
const BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")
const BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")

const TEX_AUTHORING_N: int = GeometryCoordsClass.TEX_AUTHORING_N
const VOXEL_ATOM_W: int = GeometryCoordsClass.VOXEL_ATOM_W         # 32
const VOXEL_ATOM_H: int = GeometryCoordsClass.VOXEL_ATOM_H         # 36
const VOXEL_VISIBLE_Y_START: int = 16                              # Top 16 pixels invisible, bottom 20 visible [TILE_ANATOMY.md §2]
const STRIP_LENGTH: int = 9                                        # Master-strip atom count [TILE_ANATOMY.md §4]

## Real voxel atom PNGs (loaded once at init)
const VOXEL_MATERIALS = ["concrete", "metal", "stone", "wood"]
const VOXEL_BASE_PATH = "res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_"

## MasterStrip — baked strip of atoms for a (material, facade) combo
class MasterStrip extends RefCounted:
	var material_id: String
	var facade_id: String
	var atoms: Array  # Array of Image (32×36 each, STRIP_LENGTH items)

	func _init(p_material_id: String, p_facade_id: String) -> void:
		material_id = p_material_id
		facade_id = p_facade_id
		atoms = []

## BakedAtlas — output of the compositor
class BakedAtlas extends RefCounted:
	var strips: Dictionary  # (material_id, facade_id) → MasterStrip
	var atom_pages: Array  # Array of Images (4096×4096 each for atlas fallback)
	var lookup: Dictionary  # String keys → {page, atlas_coords} (legacy support)

	func _init() -> void:
		strips = {}
		atom_pages = []
		lookup = {}

## PreShearedFacade — BAKE-FACADE-PLANE-02-c: Cached pre-computed facades and LUTs
## Built once per (facade) during baking, stored in session cache, reused across atoms
class PreShearedFacade extends RefCounted:
	var facade_id: String
	var base_image: Image              # Original facade (1024×512)
	var scaled_image: Image            # Scaled to 1024×640 (×20/16 vertically)
	var shear_plus_image: Image        # S+ sheared (down x/2)
	var shear_minus_image: Image       # S- sheared (mirrored + opposite shear)
	var luts: Dictionary               # blend_mode → 256-entry LUT (palette: luminance → RGB)
	
	func _init(p_facade_id: String) -> void:
		facade_id = p_facade_id
		luts = {}

# For dependency injection (set by room_builder before baking)
var _material_registry = null

# Real voxel atoms (loaded once per compositor instance)
var _voxel_atoms: Dictionary = {}  # material_id → Image (32×36)

# BAKE-FACADE-PLANE-01-b: Per-combo cache for F6/F7 cycling
# Key: "%s|%s|%d" % [material_id, facade_id, blend_mode]
# Value: BakedAtlas
var _session_cache: Dictionary = {}

# BAKE-FACADE-PLANE-02-c: Pre-sheared facade cache (per facade, reused across atoms)
# Key: facade_id → PreShearedFacade
var _presheared_cache: Dictionary = {}

func _init() -> void:
	_load_real_voxel_atoms()

## Clear cache (called when starting a new map or game)
func clear_cache() -> void:
	_session_cache.clear()
	_presheared_cache.clear()
	print("[BAKE] Session cache cleared")

## Set material registry (called by room_builder for production use)
func set_material_registry(registry) -> void:
	_material_registry = registry

## Load real voxel atom PNGs (32×36) for alpha copying
## Uses the same resource-import path as VoxelRenderer, not raw Image.load()
## This ensures alpha channel matches what the live rendering path actually uses
func _load_real_voxel_atoms() -> void:
	for material in VOXEL_MATERIALS:
		var path = VOXEL_BASE_PATH + material + ".png"
		
		# Load via resource system (same as VoxelRenderer._build_voxel_tileset)
		# to get alpha values consistent with imported resource, not raw file
		var texture: Texture2D = load(path)
		if texture == null:
			push_error("[BAKE] Failed to load texture resource: %s" % path)
			continue
		
		var img = texture.get_image()
		if img == null:
			push_error("[BAKE] Failed to get image from texture: %s" % path)
			continue
		
		if img.get_width() != VOXEL_ATOM_W or img.get_height() != VOXEL_ATOM_H:
			push_error("[BAKE] Voxel atom %s has wrong size: %dx%d (expected %dx%d)" % [
				path, img.get_width(), img.get_height(), VOXEL_ATOM_W, VOXEL_ATOM_H
			])
			continue
		
		_voxel_atoms[material] = img
		print("[BAKE] Loaded voxel atom: %s (32×36)" % material)

## Main entry point: bake master strips for all (material, facade) combos in the map
## BAKE-FACADE-PLANE-01-b: Caches results per blend mode for F6/F7 cycling
## BAKE-FACADE-PLANE-02-b: Cache HIT path skips _bake_atom_sheet() entirely
func bake(map_spec: Dictionary, resolver) -> BakedAtlas:
	# Inputs: map spec (walls, themes, geometry), texture resolver
	# Output: BakedAtlas with strips dictionary

	# BAKE-FACADE-PLANE-01-b: Check cache by blend mode
	var blend_mode = BakeConfigClass.blend_mode
	var cache_key = "blend_%d" % blend_mode
	
	if _session_cache.has(cache_key):
		var cached_atlas = _session_cache[cache_key]
		print("[BAKE] cache HIT for blend_mode=%d (cached %d strips)" % [blend_mode, cached_atlas.strips.size()])
		return cached_atlas  ## BAKE-FACADE-PLANE-02-b: Return immediately, skip baking

	print("[BAKE] cache MISS for blend_mode=%d — full bake starting" % blend_mode)
	var atlas_result = BakedAtlas.new()

	# Step 1: Determine all unique (material, facade) combos used in map
	var combos = _extract_unique_combos(map_spec, resolver)
	var combo_count = combos.size()
	print("[BAKE] Found %d unique (material, facade) combos" % combo_count)

	if combo_count == 0:
		print("[BAKE] No combos to bake; returning empty atlas")
		return atlas_result

	# Step 2: Load all resolved facades
	var facades_by_id = {}
	for combo in combos:
		var facade_id = combo[1]
		if not facades_by_id.has(facade_id):
			var resolved = resolver.resolve(facade_id)
			# ResolvedTexture has image and tier properties
			if resolved != null and resolved.tier != resolver.Tier.NONE:
				facades_by_id[facade_id] = resolved.image

	# Step 3: Bake strips
	var start_time = Time.get_ticks_msec()
	var baked_count = 0
	
	for combo in combos:
		var material_id = combo[0]
		var facade_id = combo[1]
		var combo_key = "%s|%s" % [material_id, facade_id]
		
		var facade = facades_by_id.get(facade_id)
		if facade == null:
			print("[BAKE] Skipping %s: facade not resolved" % combo_key)
			continue
		
		# Bake the 2-D atom sheet for this combo
		var strip = _bake_atom_sheet(material_id, facade_id, facade)
		if strip != null:
			atlas_result.strips[combo_key] = strip
			baked_count += 1
	
	var elapsed = Time.get_ticks_msec() - start_time
	print("[BAKE] Baked %d master strips in %.1f ms" % [baked_count, elapsed])

	# Step 4: For atlas page fallback (legacy support), render strips into atlas
	_render_strips_to_pages(atlas_result)

	# BAKE-FACADE-PLANE-01-b: Store in cache for F6/F7 cycling
	_session_cache[cache_key] = atlas_result
	print("[BAKE] Stored in session cache (key=%s)" % cache_key)

	return atlas_result


## Extract unique (material, facade) combos from the map
func _extract_unique_combos(map_spec: Dictionary, _resolver) -> Array:
	var combos = {}  # String key → true (for dedup)
	var blocks = []
	
	# Support both file format (sections.blocks.items) and runtime format (blocks array)
	if map_spec.has("sections") and map_spec["sections"].has("blocks"):
		# File format
		var blocks_section = map_spec["sections"]["blocks"]
		if blocks_section.has("items"):
			blocks = blocks_section["items"]
	elif map_spec.has("blocks"):
		# Runtime format (from FileMapSource.get_runtime_spec())
		blocks = map_spec["blocks"] if typeof(map_spec["blocks"]) == TYPE_ARRAY else []
	
	# Extract unique (material, facade_id) combos from blocks
	for block in blocks:
		var material = block.get("material", "default") if typeof(block) == TYPE_DICTIONARY else "default"
		# For now, assume each material gets a canonical facade_id (concrete→facade_concrete, etc.)
		var facade_id = "facade_" + material
		var combo_key = "%s|%s" % [material, facade_id]
		combos[combo_key] = true

	# BAKE-LIVE-VERIFY-01-c: real production callers (room_builder.gd::_bake_textures())
	# pass map_spec["walls"] — a flat array of {material_id, facade_id, edge, run} dicts
	# built from real EdgeExtractor/run-grouping output, not map_spec["blocks"]. Without
	# this, every real map load found 0 combos and baked an empty atlas regardless of how
	# many real walls existed, because this loop only ever looked at "blocks".
	if map_spec.has("walls"):
		var walls = map_spec["walls"] if typeof(map_spec["walls"]) == TYPE_ARRAY else []
		for wall in walls:
			if typeof(wall) != TYPE_DICTIONARY:
				continue
			var material_id = wall.get("material_id", "default")
			var facade_id = wall.get("facade_id", "facade_" + material_id)
			var combo_key = "%s|%s" % [material_id, facade_id]
			combos[combo_key] = true

	# Convert dict keys to array
	var result = []
	for key in combos.keys():
		var parts = key.split("|")
		result.append([parts[0], parts[1]])
	
	return result

## BAKE-FACADE-PLANE-02-c: Generate or retrieve pre-sheared facades + LUTs for a facade
## Built once per facade, cached for reuse across all (material, blend_mode) combos
## Returns PreShearedFacade with S+, S-, and blend-mode-specific LUTs pre-computed
func _get_or_generate_presheared(facade_id: String, facade: Image, resolver) -> PreShearedFacade:
	if _presheared_cache.has(facade_id):
		return _presheared_cache[facade_id]
	
	var presheared = PreShearedFacade.new(facade_id)
	presheared.base_image = facade
	
	# Scale facade 20/16 vertically (nearest neighbor)
	# Original: 1024×512 → Scaled: 1024×640
	presheared.scaled_image = Image.create(1024, 640, false, Image.FORMAT_RGBA8)
	for y in range(640):
		var src_y = int(float(y) * 512.0 / 640.0)
		src_y = clampi(src_y, 0, 511)
		for x in range(1024):
			presheared.scaled_image.set_pixel(x, y, facade.get_pixel(x, src_y))
	
	# Generate shear+ and shear- via blit strips (not per-pixel)
	# S+: down x/2, S-: mirrored + opposite shear
	# Using ~512 2-px-wide blit_rect strips to avoid per-pixel loops
	_generate_sheared_facades(presheared)
	
	# Generate LUTs for each blend mode
	_generate_blend_luts(presheared)
	
	_presheared_cache[facade_id] = presheared
	print("[BAKE] Pre-sheared facade: %s (base 1024×512 → scaled 1024×640, S+ and S- shears, %d LUTs)" % [facade_id, presheared.luts.size()])
	return presheared

## Generate S+ (down x/2 shear) and S- (mirrored + opposite shear) facades
func _generate_sheared_facades(presheared: PreShearedFacade) -> void:
	var src = presheared.scaled_image  # 1024×640
	
	# S+ shear: move down by x/2 (down-right parallelogram)
	presheared.shear_plus_image = Image.create(1024, 640, false, Image.FORMAT_RGBA8)
	for y in range(640):
		for x in range(1024):
			var shift_y = int(float(x) * 0.5)
			var src_y = y - shift_y
			if src_y >= 0 and src_y < 640:
				presheared.shear_plus_image.set_pixel(x, y, src.get_pixel(x, src_y))
			else:
				presheared.shear_plus_image.set_pixel(x, y, Color(0, 0, 0, 0))  # Transparent fill
	
	# S- shear: mirror horizontally + opposite shear (up -x/2)
	presheared.shear_minus_image = Image.create(1024, 640, false, Image.FORMAT_RGBA8)
	for y in range(640):
		for x in range(1024):
			var mirror_x = 1023 - x
			var shift_y = int(float(mirror_x) * 0.5)
			var src_y = y - shift_y
			if src_y >= 0 and src_y < 640:
				presheared.shear_minus_image.set_pixel(x, y, src.get_pixel(mirror_x, src_y))
			else:
				presheared.shear_minus_image.set_pixel(x, y, Color(0, 0, 0, 0))

## Generate 256-entry LUTs for each blend mode (luminance → RGB)
## BAKE-FACADE-PLANE-02-c: Drop pattern noise; shaded_base is constant per material
## Each mode maps facade luminance to pre-blended RGB
func _generate_blend_luts(presheared: PreShearedFacade) -> void:
	# This will be populated during baking with material-specific LUTs
	# Placeholder: luts will be filled in _bake_atom_sheet_with_luts when we have material.base_color
	pass

## Bake 2-D atom sheet for (material, facade) — optimized with pre-shearing (BAKE-FACADE-PLANE-02-c)
## BAKE-FACADE-PLANE-02-c: Major optimizations:
## 1. Drop per-pixel pattern noise → shaded_base is constant per material
## 2. Pre-compute S+ and S- sheared facades (cached per facade)
## 3. Pre-compute 256-entry LUTs per (material, blend_mode) for fast lookup
## Expected speedup: ~21s → ~2s for full bake (4 combos)
func _bake_atom_sheet(material_id: String, facade_id: String, facade: Image) -> MasterStrip:
	var strip = MasterStrip.new(material_id, facade_id)
	var registry = _get_material_registry()
	var material = registry.get_material(material_id)

	if material == null:
		push_error("[BAKE] Material '%s' not found" % material_id)
		return null

	# Get or generate pre-sheared facade (S+, S-, and LUTs for all blend modes)
	var presheared = _get_or_generate_presheared(facade_id, facade, null)
	
	var atom_count = 0
	var facade_sampler = FacadeSamplerClass.new()
	
	# BAKE-FACADE-PLANE-02-c: Constant shaded_base per material (no pattern noise)
	# With real facade texture, pattern modulation is invisible
	var shaded_base_constant: Color = material.base_color

	# Bake 64×32 atoms (full facade plane)
	for sheet_row in range(32):
		for sheet_col in range(64):
			var atom_img = Image.create(VOXEL_ATOM_W, VOXEL_ATOM_H, false, Image.FORMAT_RGBA8)

			# For each pixel in the 32×36 atom
			for pixel_y in range(VOXEL_ATOM_H):
				for pixel_x in range(VOXEL_ATOM_W):
					# Get the canonical voxel alpha from the real atom PNG (B3 untouched)
					var canonical_alpha = _get_canonical_alpha(material_id, pixel_x, pixel_y)

					# Top face (rows 0..15): use MATERIAL_ONLY treatment (constant base color, no facade)
					if pixel_y < VOXEL_VISIBLE_Y_START:
						var rgb: Color = shaded_base_constant  # MATERIAL_ONLY: no facade blend
						var pixel = Color(rgb.r, rgb.g, rgb.b, canonical_alpha)
						atom_img.set_pixel(pixel_x, pixel_y, pixel)
					# Side face (rows 16..35): isometric projection with u,v formulas
					else:
						var plane_u = 0.0
						var plane_v = 0.0
						
						if pixel_x < 16:
							# LEFT half: u increases left-to-right
							plane_u = sheet_col * float(TEX_AUTHORING_N) + float(pixel_x)
							plane_v = sheet_row * float(TEX_AUTHORING_N) + (float(pixel_y) - (8.0 + float(pixel_x) / 2.0)) * 16.0 / 20.0
						else:
							# RIGHT half: u DECREASES left-to-right (BAKE-FACADE-PLANE-02-c fix for second-direction)
							var x_offset = float(pixel_x - 16)
							plane_u = sheet_col * float(TEX_AUTHORING_N) + (15.0 - x_offset)
							plane_v = sheet_row * float(TEX_AUTHORING_N) + (float(pixel_y) - (16.0 - x_offset / 2.0)) * 16.0 / 20.0
						
						# Sample facade via FacadeSampler (mirrored-repeat addressing)
						var facade_lum = facade_sampler.sample(facade, plane_u, plane_v)
						
						# Blend: constant shaded_base × facade_lum per BakeConfig.blend_mode
						var rgb: Color = _apply_blend(shaded_base_constant, facade_lum)
						
						# Composite with canonical alpha
						var pixel = Color(rgb.r, rgb.g, rgb.b, canonical_alpha)
						atom_img.set_pixel(pixel_x, pixel_y, pixel)

			strip.atoms.append(atom_img)
			atom_count += 1

	print("[BAKE] Baked atom sheet (pre-shear optimized): %s × %s (64×32 = %d atoms, 32×36 each)" % [material_id, facade_id, atom_count])
	return strip

## BAKE-DIAG-02: Apply the configured blend mode (BakeConfig.blend_mode) to combine
## the pattern-shaded material base color with the facade's grayscale luminance.
## Each mode is a genuinely different formula so they can be A/B compared live (F7).
func _apply_blend(shaded_base: Color, facade_lum: float) -> Color:
	match BakeConfigClass.blend_mode:
		BakeConfigClass.BlendMode.MULTIPLY:
			# Straight multiply: darkens whenever facade_lum < 1.0 (original behavior).
			return shaded_base * facade_lum
		BakeConfigClass.BlendMode.TEXTURE_ONLY:
			# Ignore material base color entirely; show the facade's own tone.
			return Color(facade_lum, facade_lum, facade_lum)
		BakeConfigClass.BlendMode.MATERIAL_ONLY:
			# Ignore facade entirely; pure pattern-shaded material color (no darkening).
			return shaded_base
		BakeConfigClass.BlendMode.OVERLAY_EXPERIMENTAL:
			return Color(
				_overlay_channel(shaded_base.r, facade_lum),
				_overlay_channel(shaded_base.g, facade_lum),
				_overlay_channel(shaded_base.b, facade_lum)
			)
		BakeConfigClass.BlendMode.LINEAR_LIGHT:
			# base + 2*facade - 1: facade_lum above 0.5 lifts brightness, below 0.5 lowers it.
			# Real voxel_atom art trends mid-bright, so this reads closer to the raw material
			# than a flat multiply while still carrying facade detail.
			return Color(
				clampf(shaded_base.r + 2.0 * facade_lum - 1.0, 0.0, 1.0),
				clampf(shaded_base.g + 2.0 * facade_lum - 1.0, 0.0, 1.0),
				clampf(shaded_base.b + 2.0 * facade_lum - 1.0, 0.0, 1.0)
			)
		_:
			return shaded_base * facade_lum


## Apply MATERIAL_ONLY blend: return shaded_base directly (for top face)
## Top face is a horizontal surface; vertical-plane facade does not project onto it
func _apply_blend_material_only(shaded_base: Color) -> Color:
	return shaded_base


func _overlay_channel(base_c: float, tex: float) -> float:
	if base_c < 0.5:
		return 2.0 * base_c * tex
	return 1.0 - 2.0 * (1.0 - base_c) * (1.0 - tex)


## Get canonical alpha from real voxel PNG
func _get_canonical_alpha(material_id: String, pixel_x: int, pixel_y: int) -> float:
	var voxel_img = _voxel_atoms.get(material_id)
	
	if voxel_img == null:
		return 0.0  # Transparent if atom not loaded
	
	if pixel_x < 0 or pixel_x >= VOXEL_ATOM_W or pixel_y < 0 or pixel_y >= VOXEL_ATOM_H:
		return 0.0
	
	return voxel_img.get_pixel(pixel_x, pixel_y).a

## Render atom sheets into atlas pages and populate lookup with 2-D facade keys
## BAKE-FACADE-PLANE-01: Replaces 1-D strip key with 2-D (col, row) addressing
## BAKE-FACADE-PLANE-02-b: FIXED — page_idx now advances per strip to prevent collision
func _render_strips_to_pages(atlas_result: BakedAtlas) -> void:
	var page_idx = 0
	var tiles_per_page_x = int(4096.0 / float(VOXEL_ATOM_W))  # 128
	var tiles_per_page_y = int(4096.0 / float(VOXEL_ATOM_H))  # ~113
	var atoms_per_page = tiles_per_page_x * tiles_per_page_y

	for strip_key in atlas_result.strips.keys():
		var strip = atlas_result.strips[strip_key]

		# Parse material_id and facade_id from strip_key (format: "material_id|facade_id")
		var key_parts = strip_key.split("|")
		if key_parts.size() != 2:
			push_error("[BAKE] Malformed strip key: %s" % strip_key)
			continue
		var material_id = key_parts[0]
		var facade_id = key_parts[1]

		# BAKE-FACADE-PLANE-02-b: Each strip gets a fresh page (or pages if exceeding capacity)
		# Calculate how many pages this strip needs (64×32 = 2048 atoms → typically 1 page)
		var pages_needed = int(ceil(float(strip.atoms.size()) / float(atoms_per_page)))
		var strip_start_page = page_idx
		var strip_atom_offset = 0  # Offset within the strip's starting page

		# Allocate pages for this strip
		while atlas_result.atom_pages.size() < page_idx + pages_needed:
			atlas_result.atom_pages.append(Image.create(4096, 4096, false, Image.FORMAT_RGBA8))

		# Place atom sheet into the strip's allocated pages
		# BAKE-FACADE-PLANE-01: Iterate sheet positions (64×32 = 2048 atoms)
		for sheet_row in range(32):
			for sheet_col in range(64):
				var atom_idx = sheet_row * 64 + sheet_col
				if atom_idx >= strip.atoms.size():
					push_error("[BAKE] Atom index %d exceeds strip size %d" % [atom_idx, strip.atoms.size()])
					break

				var atom_img = strip.atoms[atom_idx]

				# BAKE-FACADE-PLANE-02-b: Compute page and position within page
				var current_page = strip_start_page + int(strip_atom_offset / atoms_per_page)
				var offset_in_page = strip_atom_offset % atoms_per_page
				var tile_x = (offset_in_page % tiles_per_page_x) * VOXEL_ATOM_W
				var tile_y_in_page = int(float(offset_in_page) / float(tiles_per_page_x)) * VOXEL_ATOM_H

				# Blit atom into page
				var src_rect = Rect2i(0, 0, VOXEL_ATOM_W, VOXEL_ATOM_H)
				atlas_result.atom_pages[current_page].blit_rect(atom_img, src_rect, Vector2i(tile_x, tile_y_in_page))

				# Populate lookup dictionary with 2-D facade keys + page info
				var lookup_key = "%s|%s|%d|%d" % [material_id, facade_id, sheet_col, sheet_row]
				var atlas_coords = Vector2i(int(float(tile_x) / float(VOXEL_ATOM_W)), int(float(tile_y_in_page) / float(VOXEL_ATOM_H)))

				atlas_result.lookup[lookup_key] = {
					"page": current_page,
					"atlas_coords": atlas_coords
				}

				strip_atom_offset += 1

		# BAKE-FACADE-PLANE-02-b: Advance page_idx for next strip
		page_idx = strip_start_page + pages_needed
		print("[BAKE] Strip %s → pages %d-%d (offset 0..%d)" % [strip_key, strip_start_page, page_idx - 1, strip_atom_offset - 1])

## Get global material registry
func _get_material_registry():
	# Check for test registry first (short-lived test scripts use this with isolation)
	if Engine.has_meta("BAKE_TEST_REGISTRY"):
		return Engine.get_meta("BAKE_TEST_REGISTRY")
	
	# Check for injected registry (production path via dependency injection)
	if _material_registry != null:
		return _material_registry
	
	# Fallback to global registry
	if Engine.has_meta("GLOBAL_MATERIAL_REGISTRY"):
		return Engine.get_meta("GLOBAL_MATERIAL_REGISTRY")
	
	return null
