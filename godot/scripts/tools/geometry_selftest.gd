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
	
	# GROUP: JunctionResolver — V-junction corner detection (JUNCTION-02
	# rewrite: the previous voxel-vertex approach silently picked the wrong
	# diagonal cell — see junction_resolver.gd header. Both cases below were
	# re-derived from plain GU-grid adjacency, independent of the
	# implementation under test.
	print("\nGROUP: JunctionResolver — V-junction detection")
	var JunctionResolverClass = load("res://godot/scripts/geometry/junction_resolver.gd")
	var EdgeClass = load("res://godot/scripts/geometry/edge.gd")
	var EdgeRegistryClass = load("res://godot/scripts/geometry/edge_registry.gd")
	var SliceGeneratorClass = load("res://godot/scripts/geometry/slice_generator.gd")

	# Case 1 — matches the reported screenshot: a rectangular room's actual
	# top-left interior corner. Cell (2,2) has a wall on its NE face (north
	# perimeter, vs 2,1) and its NW face (west perimeter, vs 1,2). The open
	# diagonal notch — outside both walls — is (1,1).
	var corner_registry = EdgeRegistryClass.new()
	var north_wall = EdgeClass.between(Vector2i(2, 1), Vector2i(2, 2), 1)  # NE face of (2,2)
	var west_wall = EdgeClass.between(Vector2i(1, 2), Vector2i(2, 2), 1)   # NW face of (2,2)
	SliceGeneratorClass.generate([north_wall, west_wall], corner_registry)
	var corner_columns = JunctionResolverClass.resolve(corner_registry)
	total_count += 1
	if corner_columns.size() == 1 and corner_columns[0].gu_cell == Vector2i(1, 1):
		pass_count += 1
		print("  ✓ Room corner (walls at 2,2) produces exactly 1 column at GU (1,1): %s" % corner_columns[0])
	else:
		print("  ✗ Room corner produced %d column(s): %s — expected exactly 1 at GU (1,1)" % [corner_columns.size(), corner_columns])

	# Case 2 — an elbow one step over: SE face of (2,2) turning into SW face
	# of (3,2). Cross-checked by hand against plain 2×2-block grid adjacency:
	# (2,2)/(3,2) share their far edge with (2,3)/(3,3), so the cell diagonal
	# to elbow (3,2) is (2,3) — NOT (2,2). (JUNCTION-01's test asserted (2,2)
	# here; that assertion was wrong, a byproduct of the same vertex-bucket
	# bug this rewrite removes — corrected now.)
	var l_registry = EdgeRegistryClass.new()
	var l_edge_a = EdgeClass.between(Vector2i(2, 2), Vector2i(3, 2), 1)  # SE face of (2,2)
	var l_edge_b = EdgeClass.between(Vector2i(3, 2), Vector2i(3, 3), 1)  # SW face of (3,2)
	SliceGeneratorClass.generate([l_edge_a, l_edge_b], l_registry)
	var l_columns = JunctionResolverClass.resolve(l_registry)
	total_count += 1
	if l_columns.size() == 1 and l_columns[0].gu_cell == Vector2i(2, 3):
		pass_count += 1
		print("  ✓ L-corner (elbow at GU 3,2) produces exactly 1 column at GU (2,3): %s" % l_columns[0])
	else:
		print("  ✗ L-corner produced %d column(s): %s — expected exactly 1 at GU (2,3)" % [l_columns.size(), l_columns])

	# Negative case: straight wall through a cell (opposite faces) — a
	# corridor passing through (2,2), not a turn. Must NOT produce a column.
	var straight_registry = EdgeRegistryClass.new()
	var s_edge_a = EdgeClass.between(Vector2i(1, 2), Vector2i(2, 2), 1)  # NW face of (2,2)
	var s_edge_b = EdgeClass.between(Vector2i(2, 2), Vector2i(3, 2), 1)  # SE face of (2,2)
	SliceGeneratorClass.generate([s_edge_a, s_edge_b], straight_registry)
	var straight_columns = JunctionResolverClass.resolve(straight_registry)
	total_count += 1
	if straight_columns.is_empty():
		pass_count += 1
		print("  ✓ Straight-through wall (opposite faces) produces 0 columns")
	else:
		print("  ✗ Straight-through wall produced %d column(s), expected 0: %s" % [straight_columns.size(), straight_columns])

	# Print summary
	print("\n" + separator)
	print("SUMMARY: %d / %d checks PASS" % [pass_count, total_count])
	print(separator + "\n")
	
	# Exit with success if all pass
	quit(0 if pass_count == total_count else 1)
