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

# For dependency injection (set by room_builder before baking)
var _material_registry = null

# Real voxel atoms (loaded once per compositor instance)
var _voxel_atoms: Dictionary = {}  # material_id → Image (32×36)

func _init() -> void:
	_load_real_voxel_atoms()

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
func bake(map_spec: Dictionary, resolver) -> BakedAtlas:
	# Inputs: map spec (walls, themes, geometry), texture resolver
	# Output: BakedAtlas with strips dictionary

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

## Bake 2-D atom sheet for (material, facade) — replaces 1-D master-strip (BAKE-FACADE-PLANE-01)
## Each atom at (col, row) samples its corresponding region from the facade plane
func _bake_atom_sheet(material_id: String, facade_id: String, facade: Image) -> MasterStrip:
	var strip = MasterStrip.new(material_id, facade_id)
	var registry = _get_material_registry()
	var material = registry.get_material(material_id)

	if material == null:
		push_error("[BAKE] Material '%s' not found" % material_id)
		return null

	var facade_sampler = FacadeSamplerClass.new()
	var atom_count = 0

	# Bake 64×32 atoms (full facade plane) — BAKE-FACADE-PLANE-01: 2-D sheet replaces 1-D strip
	for sheet_row in range(32):  # 32 vertical rows (levels/storeys)
		for sheet_col in range(64):  # 64 horizontal columns
			var atom_img = Image.create(VOXEL_ATOM_W, VOXEL_ATOM_H, false, Image.FORMAT_RGBA8)

			# For each pixel in the 32×36 atom
			for pixel_y in range(VOXEL_ATOM_H):
				for pixel_x in range(VOXEL_ATOM_W):
					# Get the canonical voxel alpha from the real atom PNG (B3 untouched)
					var canonical_alpha = _get_canonical_alpha(material_id, pixel_x, pixel_y)

					# BAKE-FACADE-PLANE-01: 2-D facade sampling
					# Atom at sheet position (sheet_col, sheet_row) samples facade rect at
					# [origin + (sheet_col*16, sheet_row*16), 16×16 texels]
					var facade_lum = 1.0  # Default if out of bounds

					# Top face (rows 0..15): uniform (no facade detail)
					if pixel_y < VOXEL_VISIBLE_Y_START:
						facade_lum = 1.0  # Neutral, no texture
					# Side face (rows 16..35): sample facade rect
					else:
						# Map atom pixel to facade texel coordinates
						# Atom width 32px → 16 texels; Atom side height 20px → 16 texels
						var texel_x = pixel_x / 2.0
						var texel_y = (pixel_y - VOXEL_VISIBLE_Y_START) * 16.0 / 20.0

						# Facade plane position (sheet_col, sheet_row) → absolute facade texel coords
						var plane_x = sheet_col * float(TEX_AUTHORING_N) + texel_x
						var plane_y = sheet_row * float(TEX_AUTHORING_N) + texel_y

						# Sample via FacadeSampler (mirrored-repeat addressing)
						facade_lum = facade_sampler.sample(facade, plane_x, plane_y)

					# Apply pattern shade
					var voxel_xy = Vector2i(pixel_x % 8, pixel_y % 8)
					var seed_val = (sheet_col << 16) | (sheet_row << 8) | (pixel_y * VOXEL_ATOM_W + pixel_x)
					var pattern_shade = material.pattern_algorithm.shade(voxel_xy, 0, seed_val)

					# Blend: shaded_base × facade_lum per BakeConfig.blend_mode
					var shaded_base: Color = material.base_color * pattern_shade
					var rgb: Color = _apply_blend(shaded_base, facade_lum)

					# Composite with canonical alpha
					var pixel = Color(rgb.r, rgb.g, rgb.b, canonical_alpha)
					atom_img.set_pixel(pixel_x, pixel_y, pixel)

			strip.atoms.append(atom_img)
			atom_count += 1

	print("[BAKE] Baked atom sheet: %s × %s (64×32 = %d atoms, 32×36 each)" % [material_id, facade_id, atom_count])
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
func _render_strips_to_pages(atlas_result: BakedAtlas) -> void:
	var page_idx = 0
	var tiles_per_page_x = int(4096.0 / float(VOXEL_ATOM_W))  # 128
	var _tiles_per_page_y = int(4096.0 / float(VOXEL_ATOM_H))  # ~113

	for strip_key in atlas_result.strips.keys():
		var strip = atlas_result.strips[strip_key]

		# Parse material_id and facade_id from strip_key (format: "material_id|facade_id")
		var key_parts = strip_key.split("|")
		if key_parts.size() != 2:
			push_error("[BAKE] Malformed strip key: %s" % strip_key)
			continue
		var material_id = key_parts[0]
		var facade_id = key_parts[1]

		# Allocate page if needed
		while atlas_result.atom_pages.size() <= page_idx:
			atlas_result.atom_pages.append(Image.create(4096, 4096, false, Image.FORMAT_RGBA8))

		# Place atom sheet into the page and populate lookup dictionary
		# BAKE-FACADE-PLANE-01: Iterate sheet positions (64×32 = 2048 atoms)
		var atom_idx = 0
		for sheet_row in range(32):
			for sheet_col in range(64):
				if atom_idx >= strip.atoms.size():
					push_error("[BAKE] Atom index %d exceeds strip size %d" % [atom_idx, strip.atoms.size()])
					break

				var atom_img = strip.atoms[atom_idx]
				var tile_x = (atom_idx % tiles_per_page_x) * VOXEL_ATOM_W
				var tile_y_in_page = int(float(atom_idx) / float(tiles_per_page_x)) * VOXEL_ATOM_H

				# Copy atom pixels into page
				for y in range(VOXEL_ATOM_H):
					for x in range(VOXEL_ATOM_W):
						atlas_result.atom_pages[page_idx].set_pixel(
							tile_x + x, tile_y_in_page + y, atom_img.get_pixel(x, y)
						)

				# Populate lookup dictionary with 2-D facade keys
				# Key format (BAKE-FACADE-PLANE-01): "%s|%s|%d|%d" % [material_id, facade_id, col, row]
				var lookup_key = "%s|%s|%d|%d" % [material_id, facade_id, sheet_col, sheet_row]
				var atlas_coords = Vector2i(int(float(tile_x) / float(VOXEL_ATOM_W)), int(float(tile_y_in_page) / float(VOXEL_ATOM_H)))

				atlas_result.lookup[lookup_key] = {
					"page": page_idx,
					"atlas_coords": atlas_coords
				}

				atom_idx += 1

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
