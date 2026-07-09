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
		
		# Bake the master strip for this combo
		var strip = _bake_master_strip(material_id, facade_id, facade)
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
	
	# Convert dict keys to array
	var result = []
	for key in combos.keys():
		var parts = key.split("|")
		result.append([parts[0], parts[1]])
	
	return result

## Bake a single master strip for (material, facade)
func _bake_master_strip(material_id: String, facade_id: String, facade: Image) -> MasterStrip:
	var strip = MasterStrip.new(material_id, facade_id)
	var registry = _get_material_registry()
	var material = registry.get_material(material_id)
	
	if material == null:
		push_error("[BAKE] Material '%s' not found" % material_id)
		return null
	
	# Bake STRIP_LENGTH atoms
	for atom_idx in range(STRIP_LENGTH):
		var atom_img = Image.create(VOXEL_ATOM_W, VOXEL_ATOM_H, false, Image.FORMAT_RGBA8)
		
		# For each pixel in the 32×36 atom
		for pixel_y in range(VOXEL_ATOM_H):
			for pixel_x in range(VOXEL_ATOM_W):
				# Get the canonical voxel alpha from the real atom PNG
				var canonical_alpha = _get_canonical_alpha(material_id, pixel_x, pixel_y)
				
				# Sample facade at the position corresponding to this atom in the strip
				# Facade column: atom_idx * 32 + pixel_x (in texels)
				# Facade row: 16 (visible region start from TILE_ANATOMY.md)
				var facade_col_texels = atom_idx * TEX_AUTHORING_N + int(float(pixel_x) / (float(VOXEL_ATOM_W) / float(TEX_AUTHORING_N)))
				var facade_row_texels = VOXEL_VISIBLE_Y_START  # Start at visible region
				
				# Convert to facade pixel coordinates (facade is 1024×512, N=16, so each texel is 16×16 pixels)
				# Actually, simplify: facade is 64×32 tiles of 16×16 texels each
				# So each texel position maps directly to facade pixel position
				var facade_pixel_x = (facade_col_texels % (64 * TEX_AUTHORING_N))
				var facade_pixel_y = (facade_row_texels % (32 * TEX_AUTHORING_N))
				
				if facade_pixel_x < facade.get_width() and facade_pixel_y < facade.get_height():
					var facade_pixel = facade.get_pixel(facade_pixel_x, facade_pixel_y)
					var facade_lum = facade_pixel.v  # Grayscale luminance
					
					# Apply pattern shade
					var voxel_xy = Vector2i(pixel_x % 8, pixel_y % 8)
					var seed_val = (atom_idx << 16) + (pixel_y * VOXEL_ATOM_W + pixel_x)
					var pattern_shade = material.pattern_algorithm.shade(voxel_xy, 0, seed_val)
					
					# Composite: base_color × pattern × facade_lum
					var rgb = material.base_color * pattern_shade * facade_lum
					
					# Composite with canonical alpha
					var pixel = Color(rgb.r, rgb.g, rgb.b, canonical_alpha)
					atom_img.set_pixel(pixel_x, pixel_y, pixel)
				else:
					# Out of bounds: transparent
					atom_img.set_pixel(pixel_x, pixel_y, Color.TRANSPARENT)
		
		strip.atoms.append(atom_img)
	
	print("[BAKE] Baked strip: %s × %s (%d atoms, 32×36 each)" % [material_id, facade_id, STRIP_LENGTH])
	return strip

## Get canonical alpha from real voxel PNG
func _get_canonical_alpha(material_id: String, pixel_x: int, pixel_y: int) -> float:
	var voxel_img = _voxel_atoms.get(material_id)
	
	if voxel_img == null:
		return 0.0  # Transparent if atom not loaded
	
	if pixel_x < 0 or pixel_x >= VOXEL_ATOM_W or pixel_y < 0 or pixel_y >= VOXEL_ATOM_H:
		return 0.0
	
	return voxel_img.get_pixel(pixel_x, pixel_y).a

## Render strips into atlas pages for legacy support
func _render_strips_to_pages(atlas_result: BakedAtlas) -> void:
	# For now, just allocate one page per strip and place them sequentially
	# This is for tile registration in room_builder
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
		
		# Place strip atoms into the page and populate lookup dictionary
		for atom_idx in range(strip.atoms.size()):
			var atom_img = strip.atoms[atom_idx]
			var tile_x = (atom_idx % tiles_per_page_x) * VOXEL_ATOM_W
			var tile_y_in_page = int(float(atom_idx) / float(tiles_per_page_x)) * VOXEL_ATOM_H
			
			# Copy atom pixels into page
			for y in range(VOXEL_ATOM_H):
				for x in range(VOXEL_ATOM_W):
					atlas_result.atom_pages[page_idx].set_pixel(
						tile_x + x, tile_y_in_page + y, atom_img.get_pixel(x, y)
					)
			
			# Populate lookup dictionary: key → {page, atlas_coords}
			# Key format: "%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]
			# For master strips: variant_k=atom_idx, face=0, plane_col/row based on tile position
			var variant_k = atom_idx  # Each atom in the strip is a potential variant
			var face = 0  # Master strips apply to all faces; specialized variants set face explicitly
			var plane_col = int(float(tile_x) / float(VOXEL_ATOM_W))
			var plane_row = int(float(tile_y_in_page) / float(VOXEL_ATOM_H))
			
			var lookup_key = "%s|%s|%d|%d|%d|%d" % [material_id, facade_id, variant_k, face, plane_col, plane_row]
			var atlas_coords = Vector2i(plane_col, plane_row)
			
			atlas_result.lookup[lookup_key] = {
				"page": page_idx,
				"atlas_coords": atlas_coords
			}

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
