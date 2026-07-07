## MaterialAtlasGenerator — Generate material voxel atlas at boot
##
## Generates a texture atlas containing all material tiles (K=4 variants per material,
## one per face orientation). Output: Image pages saved to user://debug/ for inspection.

class_name MaterialAtlasGenerator

const GeometryCoordsClass = preload("res://godot/scripts/geometry/geometry_coords.gd")
const PerFaceProjectorClass = preload("res://godot/scripts/systems/per_face_projector.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")

## Atlas generation result
class AtlasResult:
	var pages: Array[Image] = []
	var tile_lookup: Dictionary = {}  # key format: "material_id:face:variant" → {"page": int, "atlas_coords": Vector2i}
	
	func _init() -> void:
		pass

## Generate material atlas from registry
func generate_atlas(registry: MaterialRegistryClass, N: int, face_variants: Array) -> AtlasResult:
	print("\n[MaterialAtlasGenerator] Starting atlas generation")
	print("  Materials: %d" % registry.count())
	print("  Faces: %d" % face_variants.size())
	print("  Variants per material: 4")
	
	var result = AtlasResult.new()
	var materials = registry.list_materials()
	var num_tiles = materials.size() * face_variants.size() * 4  # 4 variants per material
	
	print("  Total tiles: %d" % num_tiles)
	
	# Render each tile
	var tile_index = 0
	for material_id in materials:
		var material = registry.get_material(material_id)
		
		for face in face_variants:
			for variant_k in range(4):
				# Render material tile
				var tile_image = _render_material_tile(material, face, variant_k, N)
				
				# Store in result
				result.pages.append(tile_image)
				var lookup_key = "%s:%d:%d" % [material_id, face, variant_k]
				result.tile_lookup[lookup_key] = {
					"page": tile_index,
					"atlas_coords": Vector2i(0, 0)
				}
				
				tile_index += 1
	
	print("[MaterialAtlasGenerator] Atlas complete: %d tiles in %d pages" % [num_tiles, result.pages.size()])
	
	# Save debug dump
	_save_debug_dump(result, materials)
	
	return result

## Render a single material voxel tile (32×16 screen-space isometric)
func _render_material_tile(material: MaterialRegistryClass.MaterialDef, face: int, variant_k: int, N: int) -> Image:
	var tile = Image.create(32, 16, false, Image.FORMAT_RGB8)
	var projector = PerFaceProjectorClass.new()
	
	for screen_y in range(16):
		for screen_x in range(32):
			var screen_pos = Vector2(float(screen_x), float(screen_y))
			
			# Check if this pixel is inside the voxel face (silhouette)
			if not projector.is_inside_voxel(face, screen_pos):
				# Outside the voxel face boundary; set to black
				tile.set_pixel(screen_x, screen_y, Color(0, 0, 0, 1))
				continue
			
			# Map screen → flat texture space
			var flat_pos = projector.screen_to_flat(face, screen_pos)
			var voxel_xy = Vector2i(int(flat_pos.x / float(N)), int(flat_pos.y / float(N)))
			
			# Get pattern shade multiplier (deterministic per voxel)
			var seed_val = _hash_variant(material.id, variant_k)
			var shade = material.pattern_algorithm.shade(voxel_xy, face, seed_val)
			
			# Clamp shade to [0, 1]
			shade = clampf(shade, 0.0, 1.0)
			
			# Apply to base color
			var colored_pixel = material.base_color * Color(shade, shade, shade, 1.0)
			tile.set_pixel(screen_x, screen_y, colored_pixel)
	
	return tile

## Generate deterministic seed from material ID and variant
func _hash_variant(material_id: String, variant_k: int) -> int:
	var hash_val = 0
	for c in material_id:
		hash_val = ((hash_val << 5) + hash_val) ^ (c as int)
	hash_val ^= variant_k * 12345
	return hash_val

## Save debug dump of atlas pages
func _save_debug_dump(result: AtlasResult, _materials: Array) -> void:
	# Create debug directory
	var debug_dir = "user://debug"
	if not DirAccess.dir_exists_absolute(debug_dir):
		DirAccess.make_dir_absolute(debug_dir)
	
	print("[MaterialAtlasGenerator] Saving debug dump to %s" % debug_dir)
	
	for i in range(result.pages.size()):
		var page = result.pages[i]
		var filename = "%s/material_atlas_tile_%03d.png" % [debug_dir, i]
		var error = page.save_png(filename)
		if error == OK:
			print("  ✓ Saved: %s (%dx%d)" % [filename, page.get_width(), page.get_height()])
		else:
			print("  ✗ Failed to save: %s (error %d)" % [filename, error])
