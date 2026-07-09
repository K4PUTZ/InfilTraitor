## Debug script to trace metal alpha differences at specific pixel
extends SceneTree

var VOXEL_ATOM_W: int = 32
var VOXEL_ATOM_H: int = 36

func _init() -> void:
	print("\n" + "=".repeat(80))
	print("DEBUG: Metal Alpha Analysis")
	print("=".repeat(80) + "\n")
	
	# Load the metal voxel PNG
	var metal_path = "res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_metal.png"
	var metal_img = Image.new()
	var error = metal_img.load(metal_path)
	
	if error != OK:
		print("✗ Failed to load metal PNG: %s (code %d)" % [metal_path, error])
		quit()
	
	print("[LOADED] Metal voxel PNG: %dx%d" % [metal_img.get_width(), metal_img.get_height()])
	print("[FORMAT] Image format: %s" % metal_img.get_format())
	print()
	
	# Check pixel (14, 0) which is the first mismatch location reported
	var test_x = 14
	var test_y = 0
	
	print("Sampling pixel (%d, %d):" % [test_x, test_y])
	print("-".repeat(40))
	
	var pixel = metal_img.get_pixel(test_x, test_y)
	print("  RGBA: (%.4f, %.4f, %.4f, %.4f)" % [pixel.r, pixel.g, pixel.b, pixel.a])
	print("  Alpha as stored: %.4f" % pixel.a)
	print()
	
	# Sample a grid of pixels to find alpha distribution
	print("Alpha channel scan (first 5×5 region):")
	print("-".repeat(40))
	for y in range(min(5, metal_img.get_height())):
		var row = ""
		for x in range(min(5, metal_img.get_width())):
			var p = metal_img.get_pixel(x, y)
			row += "[%.2f] " % p.a
		print(row)
	print()
	
	# Check if metal has any non-zero alpha in the upper 16 pixels (invisible region)
	var invisible_alphas = []
	for y in range(16):  # Invisible region
		for x in range(VOXEL_ATOM_W):
			var p = metal_img.get_pixel(x, y)
			if p.a > 0.0:
				invisible_alphas.append({"x": x, "y": y, "alpha": p.a})
	
	print("Non-zero alpha pixels in invisible region (0-15):")
	if invisible_alphas.size() > 0:
		print("  Found %d pixels with alpha > 0" % invisible_alphas.size())
		for item in invisible_alphas.slice(0, min(10, invisible_alphas.size())):
			print("    (%d, %d): %.4f" % [item["x"], item["y"], item["alpha"]])
		if invisible_alphas.size() > 10:
			print("    ... and %d more" % (invisible_alphas.size() - 10))
	else:
		print("  All invisible pixels have alpha=0 (as expected)")
	print()
	
	# Compare all 4 materials
	print("Comparing alpha at pixel (14, 0) across all materials:")
	print("-".repeat(40))
	
	var materials = ["concrete", "metal", "stone", "wood"]
	for mat in materials:
		var path = "res://ASSETS/ISOMETRIC/source_assets/voxels/voxel_%s.png" % mat
		var img = Image.new()
		var err = img.load(path)
		if err == OK:
			var pix = img.get_pixel(14, 0)
			print("  %s: %.4f" % [mat, pix.a])
		else:
			print("  %s: LOAD ERROR" % mat)
	print()
	
	print("=".repeat(80))
	quit()
