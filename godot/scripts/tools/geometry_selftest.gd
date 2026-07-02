## Geometry Module — Selftest: minimal validation
## Headless selftest
## Usage: godot --headless --script geometry_selftest.gd
extends SceneTree


func _ready():
	var separator = "============================================================"
	print("\n" + separator)
	print("GEOMETRY MODULE SELFTEST")
	print(separator + "\n")
	
	var pass_count = 0
	var total_count = 0
	
	# Check file structure (all geometry module files exist)
	print("GROUP: File Structure")
	var required_files = [
		"res://godot/scripts/geometry/geometry_coords.gd",
		"res://godot/scripts/geometry/face.gd",
		"res://godot/scripts/geometry/edge.gd",
		"res://godot/scripts/geometry/slice.gd",
		"res://godot/scripts/geometry/voxel.gd",
		"res://godot/scripts/geometry/edge_registry.gd",
		"res://godot/scripts/geometry/edge_extractor.gd",
		"res://godot/scripts/geometry/slice_generator.gd",
		"res://godot/scripts/geometry/junction_resolver.gd",
		"res://godot/scripts/geometry/high_wall.gd",
		"res://godot/scripts/geometry/voxel_renderer.gd",
	]
	
	for file_path in required_files:
		total_count += 1
		if ResourceLoader.exists(file_path):
			pass_count += 1
			print("  ✓ %s" % file_path.get_file())
		else:
			print("  ✗ MISSING: %s" % file_path)
	
	# Try loading each class
	print("\nGROUP: Class Loading")
	var classes = {
		"GeometryCoords": "res://godot/scripts/geometry/geometry_coords.gd",
		"Face": "res://godot/scripts/geometry/face.gd",
		"Edge": "res://godot/scripts/geometry/edge.gd",
		"Slice": "res://godot/scripts/geometry/slice.gd",
		"Voxel": "res://godot/scripts/geometry/voxel.gd",
		"EdgeRegistry": "res://godot/scripts/geometry/edge_registry.gd",
		"EdgeExtractor": "res://godot/scripts/geometry/edge_extractor.gd",
		"SliceGenerator": "res://godot/scripts/geometry/slice_generator.gd",
		"JunctionResolver": "res://godot/scripts/geometry/junction_resolver.gd",
		"HighWallGroup": "res://godot/scripts/geometry/high_wall.gd",
		"VoxelRenderer": "res://godot/scripts/geometry/voxel_renderer.gd",
	}
	
	for name_key in classes:
		total_count += 1
		var class_path = classes[name_key]
		var cls = load(class_path)
		if cls != null:
			pass_count += 1
			print("  ✓ %s loaded" % name_key)
		else:
			print("  ✗ %s failed to load" % name_key)
	
	# Print summary
	print("\n" + separator)
	print("SUMMARY: %d / %d checks PASS" % [pass_count, total_count])
	print(separator + "\n")
	
	# Exit with success if all pass
	quit(0 if pass_count == total_count else 1)
