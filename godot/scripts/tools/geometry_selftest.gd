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
	
	# GROUP: JunctionResolver — V-junction corner detection (fix for the
	# missing-column bug: register_edge() was never called, so resolve()
	# always iterated an empty edge list; and _edge_covers_corner used a
	# distance heuristic that over-counted and suppressed real corners).
	print("\nGROUP: JunctionResolver — V-junction detection")
	var JunctionResolverClass = load("res://godot/scripts/geometry/junction_resolver.gd")
	var EdgeClass = load("res://godot/scripts/geometry/edge.gd")
	var EdgeRegistryClass = load("res://godot/scripts/geometry/edge_registry.gd")
	var SliceGeneratorClass = load("res://godot/scripts/geometry/slice_generator.gd")

	# Positive case: an L — wall on the SE face of (2,2) [border with (3,2)]
	# turning into the SW face of (3,2) [border with (3,3)]. The two edges
	# share GU (3,2) as the elbow. Hand-verified: they share voxel vertex
	# (24,23); of the 4 corner GUs around that vertex, (3,2) is touched by
	# both edges (fully covered — no gap) and (2,2) is touched by exactly
	# one (the visual notch the V-junction column must fill).
	var l_registry = EdgeRegistryClass.new()
	var l_edge_a = EdgeClass.between(Vector2i(2, 2), Vector2i(3, 2), 1)  # SE face of (2,2)
	var l_edge_b = EdgeClass.between(Vector2i(3, 2), Vector2i(3, 3), 1)  # SW face of (3,2)
	SliceGeneratorClass.generate([l_edge_a, l_edge_b], l_registry)
	var l_columns = JunctionResolverClass.resolve(l_registry)
	total_count += 1
	if l_columns.size() == 1 and l_columns[0].gu_cell == Vector2i(2, 2):
		pass_count += 1
		print("  ✓ L-corner (elbow at GU 3,2) produces exactly 1 column at GU (2,2)")
		print("    └─ voxel_pos=%s, storey_count=%d" % [l_columns[0].voxel_pos, l_columns[0].storey_count])
	else:
		print("  ✗ L-corner produced %d column(s) — expected exactly 1 at GU (2,2)" % l_columns.size())
		for col in l_columns:
			print("    └─ gu_cell=%s, voxel_pos=%s" % [col.gu_cell, col.voxel_pos])

	# Print summary
	print("\n" + separator)
	print("SUMMARY: %d / %d checks PASS" % [pass_count, total_count])
	print(separator + "\n")
	
	# Exit with success if all pass
	quit(0 if pass_count == total_count else 1)
