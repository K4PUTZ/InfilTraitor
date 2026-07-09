## Compare two ways of loading voxel PNGs
extends SceneTree

var VOXEL_ASSET_TEMPLATE: String = "res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_%s.png"

func _init() -> void:
	print("\n" + "=".repeat(80))
	print("DEBUG: Comparing voxel PNG loading methods")
	print("=".repeat(80) + "\n")
	
	var materials = ["concrete", "metal", "stone", "wood"]
	var test_x = 14
	var test_y = 0
	
	for mat in materials:
		print("\nMaterial: %s" % mat)
		print("-".repeat(40))
		
		# Method 1: Raw Image.load() (BakeCompositor's method)
		var raw_path = VOXEL_ASSET_TEMPLATE % mat
		var raw_img = Image.new()
		var error = raw_img.load(raw_path)
		var raw_alpha = 0.0
		if error == OK:
			var pix = raw_img.get_pixel(test_x, test_y)
			raw_alpha = pix.a
			print("  Raw Image.load():     alpha(14,0) = %.4f" % raw_alpha)
		else:
			print("  Raw Image.load():     FAILED (code %d)" % error)
		
		# Method 2: load() + get_image() (pixel-diff tool's method)
		var texture_path = VOXEL_ASSET_TEMPLATE % mat
		var texture: Texture2D = load(texture_path)
		var imported_alpha = 0.0
		if texture != null:
			var imported_img = texture.get_image()
			if imported_img != null:
				var pix = imported_img.get_pixel(test_x, test_y)
				imported_alpha = pix.a
				print("  load() + get_image(): alpha(14,0) = %.4f" % imported_alpha)
			else:
				print("  load() + get_image(): get_image() returned null")
		else:
			print("  load() + get_image(): load() returned null")
		
		if raw_alpha != imported_alpha:
			print("  ⚠ MISMATCH: raw (%.4f) vs imported (%.4f)" % [raw_alpha, imported_alpha])
	
	print("\n" + "=".repeat(80))
	quit()
