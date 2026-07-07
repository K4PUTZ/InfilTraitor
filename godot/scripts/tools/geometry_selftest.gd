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
	
	# GROUP: EdgeExtractor — solidblock_ exposure culling against wall_ tiles
	# (JUNCTION-01b Part 1: a divider butting flush into a wall must not
	# expose a spurious face on that side — see edge_extractor.gd header).
	print("\nGROUP: EdgeExtractor — solidblock/wall flush-contact culling")
	var EdgeExtractorClass = load("res://godot/scripts/geometry/edge_extractor.gd")
	var JunctionResolverClass2 = load("res://godot/scripts/geometry/junction_resolver.gd")
	var EdgeRegistryClass2 = load("res://godot/scripts/geometry/edge_registry.gd")
	var SliceGeneratorClass2 = load("res://godot/scripts/geometry/slice_generator.gd")

	# Case A — a 3-cell divider (x=1,2,3 @ y=1) boxed in by a west wall at
	# x=0 and an east wall at x=4 (both 3 rows tall, y=0..2). This is the
	# real T-junction shape from sigma_01_map.gd's divider A meeting the
	# perimeter wall: flush solid contact on both ends. Must produce ZERO
	# columns anywhere — the joint is fully solid, nothing to fill.
	var t_wall_levels: Array = [[
		{"cell": Vector2i(0, 0), "tile_name": "wall_NW"},
		{"cell": Vector2i(0, 1), "tile_name": "wall_NW"},
		{"cell": Vector2i(0, 2), "tile_name": "wall_NW"},
		{"cell": Vector2i(4, 0), "tile_name": "wall_SE"},
		{"cell": Vector2i(4, 1), "tile_name": "wall_SE"},
		{"cell": Vector2i(4, 2), "tile_name": "wall_SE"},
		{"cell": Vector2i(1, 1), "tile_name": "solidblock_concrete"},
		{"cell": Vector2i(2, 1), "tile_name": "solidblock_concrete"},
		{"cell": Vector2i(3, 1), "tile_name": "solidblock_concrete"},
	]]
	var t_extraction: Dictionary = EdgeExtractorClass.extract({"wall_levels": t_wall_levels})
	var t_reg = EdgeRegistryClass2.new()
	SliceGeneratorClass2.generate(t_extraction["edges"], t_reg)
	var t_junction_columns = JunctionResolverClass2.resolve(t_reg)
	total_count += 1
	if t_junction_columns.is_empty():
		pass_count += 1
		print("  ✓ Divider flush against walls on both ends (true T) produces 0 columns")
	else:
		print("  ✗ Divider flush against walls produced %d bogus column(s), expected 0: %s" % [t_junction_columns.size(), t_junction_columns])

	# Case B — the same divider shape, but free-standing (no walls at
	# either end, e.g. stopping next to an open gate on both sides). Each
	# end is a genuine free corner and needs 2 filler columns (one per
	# side), 4 total. Hand-derived: west end at (1,1) → columns at (0,0)
	# and (0,2); east end at (2,1)... wait, at (2,1) with only 2 cells —
	# use the 2-cell divider (x=1,2 @ y=1) so each cell IS an end:
	# (1,1) faces {NW,NE,SW} → columns (0,0),(0,2); (2,1) faces
	# {NE,SE,SW} → columns (3,0),(3,2).
	var free_wall_levels: Array = [[
		{"cell": Vector2i(1, 1), "tile_name": "solidblock_concrete"},
		{"cell": Vector2i(2, 1), "tile_name": "solidblock_concrete"},
	]]
	var free_extraction: Dictionary = EdgeExtractorClass.extract({"wall_levels": free_wall_levels})
	var free_reg = EdgeRegistryClass2.new()
	SliceGeneratorClass2.generate(free_extraction["edges"], free_reg)
	var free_columns = JunctionResolverClass2.resolve(free_reg)
	var free_cells := {}
	for col in free_columns:
		free_cells[col.gu_cell] = true
	var expected_free := [Vector2i(0, 0), Vector2i(0, 2), Vector2i(3, 0), Vector2i(3, 2)]
	var free_ok: bool = free_columns.size() == 4
	for e in expected_free:
		if not free_cells.has(e):
			free_ok = false
	total_count += 1
	if free_ok:
		pass_count += 1
		print("  ✓ Free-standing 2-cell divider produces exactly 4 columns at both ends: %s" % free_columns)
	else:
		print("  ✗ Free-standing divider produced %d column(s): %s — expected 4 at (0,0),(0,2),(3,0),(3,2)" % [free_columns.size(), free_columns])

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

	# Case 4 — X-junction regression guard: all 4 faces of (2,2) occupied
	# (4-way intersection, all genuinely open). Must still produce 0
	# columns — out of scope by design (see junction_resolver.gd class doc
	# comment).
	var x_registry = EdgeRegistryClass.new()
	var x_west = EdgeClass.between(Vector2i(1, 2), Vector2i(2, 2), 1)   # NW face
	var x_east = EdgeClass.between(Vector2i(2, 2), Vector2i(3, 2), 1)   # SE face
	var x_north = EdgeClass.between(Vector2i(2, 1), Vector2i(2, 2), 1)  # NE face
	var x_south = EdgeClass.between(Vector2i(2, 2), Vector2i(2, 3), 1)  # SW face
	SliceGeneratorClass.generate([x_west, x_east, x_north, x_south], x_registry)
	var x_columns = JunctionResolverClass.resolve(x_registry)
	total_count += 1
	if x_columns.is_empty():
		pass_count += 1
		print("  ✓ X-junction (all 4 faces at 2,2) produces 0 columns (out of scope)")
	else:
		print("  ✗ X-junction produced %d column(s), expected 0: %s" % [x_columns.size(), x_columns])

	# Case 5 — material propagation: a metal corner must produce a column
	# in "metal", not the old hardcoded "concrete" default.
	var metal_registry = EdgeRegistryClass.new()
	var metal_north = EdgeClass.between(Vector2i(2, 1), Vector2i(2, 2), 1, "metal")  # NE face of (2,2)
	var metal_west = EdgeClass.between(Vector2i(1, 2), Vector2i(2, 2), 1, "metal")   # NW face of (2,2)
	SliceGeneratorClass.generate([metal_north, metal_west], metal_registry)
	var metal_columns = JunctionResolverClass.resolve(metal_registry)
	total_count += 1
	if metal_columns.size() == 1 and metal_columns[0].material == "metal":
		pass_count += 1
		print("  ✓ Metal corner produces a column with material 'metal': %s" % metal_columns[0])
	else:
		print("  ✗ Metal corner produced wrong material/count: %s — expected 1 column with material 'metal'" % [metal_columns])

	# Print summary
	print("\n" + separator)
	print("SUMMARY: %d / %d checks PASS" % [pass_count, total_count])
	print(separator + "\n")
	
	# Exit with success if all pass
	quit(0 if pass_count == total_count else 1)
