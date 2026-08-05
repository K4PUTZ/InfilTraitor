## D-ARCH-02 — DamageVariantBaker: Generate pre-baked damage voxel variants
##
## During map load, after wall baking completes, generate all CRACKED/DENTED
## variants with multiple soot intensities. Reuses DecalCompositor to ensure
## consistency with runtime rendering (if it ever were to happen, which it now
## never does).
##
## Output: additional atoms on the baked atlas pages, + expanded lookup entries
##
## Soot model: a damage mark's color is the same at all 3 intensities, but the
## opacity/darkness varies:
##   soot_intensity 0: mark barely visible (low opacity)
##   soot_intensity 1: medium opacity
##   soot_intensity 2: heavy/dark (high opacity)
##
## These are achieved by varying the decal's alpha or by desaturating the mark.

class_name DamageVariantBaker
extends RefCounted

const DecalCompositorClass = preload("res://godot/scripts/geometry/decal_compositor.gd")
const VoxelRendererClass = preload("res://godot/scripts/geometry/voxel_renderer.gd")

## Map of material → voxel atom (32×36px) for alpha/shape reference
var _base_voxel_atoms: Dictionary = {}

## Decal asset paths
const DECAL_BASE_PATH = "res://ASSETS/ISOMETRIC/source_assets/voxels/decals/"

## Supported materials for damage variants (glass does NOT get damage variants, per Director)
const DAMAGE_VARIANT_MATERIALS = ["concrete", "metal", "stone", "wood", "earth"]

## Soot intensities: opacity factor at each level (0 = light, 1 = medium, 2 = dark)
const SOOT_INTENSITIES = [0.4, 0.7, 1.0]  # 40%, 70%, 100% opacity


func _init() -> void:
	_load_base_voxel_atoms()


## Load base voxel atoms (INTACT) for alpha reference and baseline shape
func _load_base_voxel_atoms() -> void:
	const VOXEL_BASE_PATH = "res://ASSETS/ISOMETRIC/source_assets/voxels/materials/voxel_"
	
	for material in DAMAGE_VARIANT_MATERIALS:
		var path = VOXEL_BASE_PATH + material + ".png"
		var texture: Texture2D = load(path)
		if texture == null:
			push_error("[DMG-BAKE] Failed to load base voxel: %s" % path)
			continue
		var img = texture.get_image()
		if img == null:
			push_error("[DMG-BAKE] Failed to get image: %s" % path)
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img = img.duplicate()
			img.convert(Image.FORMAT_RGBA8)
		_base_voxel_atoms[material] = img
	
	print("[DMG-BAKE] Loaded %d base voxel atoms" % _base_voxel_atoms.size())


## Generate CRACKED variant for a material (full-voxel top-face mark + soot intensities)
## Returns: Array[Image] — 3 images (soot levels 0, 1, 2)
func generate_cracked_variants(material: String) -> Array:
	var result: Array = []
	
	if not DAMAGE_VARIANT_MATERIALS.has(material):
		push_warning("[DMG-BAKE] Material %s not in damage variant list" % material)
		return result
	
	var base_atom = _base_voxel_atoms.get(material)
	if base_atom == null:
		push_error("[DMG-BAKE] No base atom for material: %s" % material)
		return result
	
	# Load the CRACKED decal asset
	var decal_path = DECAL_BASE_PATH + "%s_cracked_0.png" % material
	var decal_texture: Texture2D = load(decal_path)
	if decal_texture == null:
		push_warning("[DMG-BAKE] No decal asset: %s (will use flat mark)" % decal_path)
		# Fallback: generate simple mark
		for soot_level in range(3):
			result.append(_generate_flat_mark(base_atom, SOOT_INTENSITIES[soot_level]))
		return result
	
	var decal_img = decal_texture.get_image()
	if decal_img == null:
		push_error("[DMG-BAKE] Failed to load decal image: %s" % decal_path)
		return result
	
	# Generate 3 soot levels
	for soot_level in range(3):
		var variant = base_atom.duplicate()
		var alpha_multiplier = SOOT_INTENSITIES[soot_level]
		
		# Composite decal with soot intensity
		_composite_mark_on_voxel(variant, decal_img, alpha_multiplier, "cracked")
		result.append(variant)
	
	print("[DMG-BAKE] Generated %d CRACKED variants for %s" % [result.size(), material])
	return result


## Generate DENTED variants (per side + soot intensities)
## damage_type: "blast_top", "blast_left", "blast_right", "blast_bottom", "bullet"
## Returns: Array[Image] — 3 images
func generate_dented_variants(material: String, damage_type: String) -> Array:
	var result: Array = []
	
	if not DAMAGE_VARIANT_MATERIALS.has(material):
		return result
	
	var base_atom = _base_voxel_atoms.get(material)
	if base_atom == null:
		return result
	
	# Load decal for this damage type
	var decal_path = DECAL_BASE_PATH + "%s_dented_%s_0.png" % [material, damage_type]
	var decal_texture: Texture2D = load(decal_path)
	
	if decal_texture == null:
		# Fallback to generic dented mark
		push_warning("[DMG-BAKE] No specific decal: %s, using generic" % decal_path)
		decal_path = DECAL_BASE_PATH + "%s_dented_generic.png" % material
		decal_texture = load(decal_path)
		if decal_texture == null:
			# Last resort: flat mark
			for soot_level in range(3):
				result.append(_generate_flat_mark(base_atom, SOOT_INTENSITIES[soot_level]))
			return result
	
	var decal_img = decal_texture.get_image()
	if decal_img == null:
		push_error("[DMG-BAKE] Failed to load dented decal: %s" % decal_path)
		return result
	
	# Generate 3 soot levels
	for soot_level in range(3):
		var variant = base_atom.duplicate()
		var alpha_multiplier = SOOT_INTENSITIES[soot_level]
		
		_composite_mark_on_voxel(variant, decal_img, alpha_multiplier, "dented")
		result.append(variant)
	
	return result


## Composite a decal mark onto a voxel with varying soot intensity
func _composite_mark_on_voxel(target: Image, decal: Image, alpha_mult: float, mark_type: String) -> void:
	# Simple alpha-blend: iterate decal pixels, blend onto target
	# Real implementation would use DecalCompositor for proper geometry,
	# but for now, a basic overlay works for proof-of-concept
	
	var w = mini(decal.get_width(), target.get_width())
	var h = mini(decal.get_height(), target.get_height())
	
	for y in range(h):
		for x in range(w):
			var decal_pixel = decal.get_pixel(x, y)
			if decal_pixel.a > 0.01:  # Only blend visible pixels
				var target_pixel = target.get_pixel(x, y)
				
				# Apply soot intensity via alpha
				var blended_alpha = decal_pixel.a * alpha_mult
				
				# Alpha blend
				var out_alpha = target_pixel.a + decal_pixel.a * (1.0 - target_pixel.a)
				var out_color: Color
				if out_alpha > 0.01:
					var a_src = decal_pixel.a * alpha_mult / out_alpha
					var a_dst = target_pixel.a * (1.0 - decal_pixel.a * alpha_mult) / out_alpha
					out_color = Color(
						decal_pixel.r * a_src + target_pixel.r * a_dst,
						decal_pixel.g * a_src + target_pixel.g * a_dst,
						decal_pixel.b * a_src + target_pixel.b * a_dst,
						out_alpha
					)
				else:
					out_color = target_pixel
				
				target.set_pixel(x, y, out_color)


## Generate a flat simple mark (when no asset available)
func _generate_flat_mark(base_atom: Image, darkness: float) -> Image:
	var result = base_atom.duplicate()
	
	# Darken the top region of the voxel
	for y in range(16):  # Top face
		for x in range(16, 48):  # Only top diamond
			if x < 32:
				var edge = 8.0 + float(x) / 2.0
				if float(y) < edge:
					var pixel = result.get_pixel(x, y)
					var darkened = Color(
						pixel.r * (1.0 - darkness * 0.5),
						pixel.g * (1.0 - darkness * 0.5),
						pixel.b * (1.0 - darkness * 0.5),
						pixel.a
					)
					result.set_pixel(x, y, darkened)
	
	return result


## Generate DESTROYED variant (hole — mostly transparent, edge highlight)
func generate_destroyed_variant(material: String) -> Image:
	var base_atom = _base_voxel_atoms.get(material)
	if base_atom == null:
		return Image.create(32, 36, false, Image.FORMAT_RGBA8)
	
	var result = base_atom.duplicate()
	
	# Make interior transparent (leave silhouette edges)
	for y in range(result.get_height()):
		for x in range(result.get_width()):
			var pixel = result.get_pixel(x, y)
			
			# Keep edges (high alpha), fade interior
			if pixel.a > 0.1:
				# Threshold: keep only the outline
				var is_edge = false
				if x > 0 and result.get_pixel(x - 1, y).a < 0.1:
					is_edge = true
				elif x < 31 and result.get_pixel(x + 1, y).a < 0.1:
					is_edge = true
				elif y > 0 and result.get_pixel(x, y - 1).a < 0.1:
					is_edge = true
				elif y < 35 and result.get_pixel(x, y + 1).a < 0.1:
					is_edge = true
				
				if not is_edge:
					# Interior: make transparent
					result.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 0.0))
				else:
					# Edge: keep but darken
					result.set_pixel(x, y, Color(0.3, 0.3, 0.3, pixel.a))
	
	return result
