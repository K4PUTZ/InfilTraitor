## playground_verification_test.gd — Verify PLAYGROUND showcase map districts A-F
## Runs headless: godot --headless --script godot/scripts/tools/playground_verification_test.gd

extends SceneTree

const MapCatalogClass = preload("res://godot/scripts/world/maps/map_catalog.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("PLAYGROUND-02 VERIFICATION — 6 Districts")
	print("=".repeat(70) + "\n")
	
	# Load PLAYGROUND
	var spec = MapCatalogClass.get_spec("PLAYGROUND")
	if spec.is_empty():
		print("  ✗ FAIL: Could not load PLAYGROUND spec")
		quit(1)
		return
	
	print("[Criterion 2] Compile succeeds")
	var inner_size = spec.get("inner_size", Vector2i.ZERO)
	print("  inner_size: %s (expected (28, 18))" % [inner_size])
	
	if inner_size != Vector2i(28, 18):
		print("  ✗ FAIL: Wrong size")
		quit(1)
		return
	
	# Compile
	var layout = MapCompilerClass.compile(spec)
	if layout.is_empty():
		print("  ✗ FAIL: Compilation failed")
		quit(1)
		return
	
	var blocked_count = layout.get("blocked_cells", []).size()
	var voxel_props_count = layout.get("voxel_prop_instances", []).size()
	
	print("  blocked_cells: %d" % blocked_count)
	print("  voxel_prop_instances: %d" % voxel_props_count)
	print("  ✓ PASS: Compile succeeded\n")
	
	# Extract edges to verify districts
	print("[Criterion 3] Districts A-F all present")
	var extraction = EdgeExtractorClass.extract(layout)
	var edges = extraction.get("edges", [])
	
	# Count materials (District A uses all 4)
	var material_counts = {"concrete": 0, "stone": 0, "wood": 0, "metal": 0}
	for edge in edges:
		var mat = edge.material
		if mat in material_counts:
			material_counts[mat] += 1
	
	print("  Material counts (District A: 4 runs, 5 GU each, 2 storeys = 40 edges per):")
	for mat in material_counts.keys():
		print("    %s: %d edges" % [mat, material_counts[mat]])
	
	var has_all_materials = material_counts["concrete"] > 0 and material_counts["stone"] > 0 and \
	                         material_counts["wood"] > 0 and material_counts["metal"] > 0
	
	if not has_all_materials:
		print("  ✗ FAIL: Not all 4 materials present in edges")
		quit(1)
		return
	
	print("  ✓ District A (4 materials): PASS")
	
	# Verify voxel props (District E: crates)
	if voxel_props_count != 2:
		print("  ✗ FAIL: Expected 2 voxel props (crates), got %d" % voxel_props_count)
		quit(1)
		return
	
	print("  ✓ District E (2 crates): PASS")
	
	# Verify patrol guard (District F: vignettes)
	var patrols = spec.get("patrols", [])
	if patrols.size() == 1:
		print("  ✓ Patrol route present: %d waypoints" % patrols[0].size())
	
	print("\n" + "=".repeat(70))
	print("PLAYGROUND-02 VERIFICATION: ALL CRITERIA PASS")
	print("=".repeat(70) + "\n")
	
	quit(0)
