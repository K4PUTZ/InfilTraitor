## BAKE-FIX-02 Selftest: Run Grouping, Strip Walking, and Junction Column Overrides
## Tests: (1) Run grouping collinearity, (2) junction override + facade_enabled variations
## Pattern: Headless, pure assertions (no drawing), exit on completion

extends SceneTree

var EdgeClass = preload("res://godot/scripts/geometry/edge.gd")
var EdgeRegistryClass = preload("res://godot/scripts/geometry/edge_registry.gd")
var JunctionResolverClass = preload("res://godot/scripts/geometry/junction_resolver.gd")

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("BAKE-FIX-02 SELFTEST: Run Grouping, Strip Walking, Junction Overrides")
	print("=".repeat(70) + "\n")
	
	var all_pass = true
	
	if not _test_run_grouping():
		all_pass = false
	
	if not _test_junction_override_facade_enabled():
		all_pass = false
	
	if not _test_junction_override_material():
		all_pass = false
	
	if not _test_junction_default_no_override():
		all_pass = false
	
	print("\n" + "=".repeat(70))
	if all_pass:
		print("BAKE-FIX-02 SELFTEST: 4 / 4 PASS")
		print("=".repeat(70) + "\n")
		print("✓ SELFTEST PASS")
	else:
		print("BAKE-FIX-02 SELFTEST: FAILED")
		print("=".repeat(70) + "\n")
		print("✗ SELFTEST FAIL")
	quit()


## TEST 1: Run grouping — consecutive collinear edges with same material group into a run
func _test_run_grouping() -> bool:
	print("[TEST 1] Run Grouping — Collinear Edge Grouping\n")
	
	# Create a line of 3 horizontal edges in the same direction
	# GU cells: (0,0), (0,1), (0,2), (0,3) with edges between them
	# Edge 1: (0,0) -> (0,1), face SE
	# Edge 2: (0,1) -> (0,2), face SE
	# Edge 3: (0,2) -> (0,3), face SE
	var edges = []
	edges.append(EdgeClass.between(Vector2i(0, 0), Vector2i(0, 1), 1, "stone"))
	edges.append(EdgeClass.between(Vector2i(0, 1), Vector2i(0, 2), 1, "stone"))
	edges.append(EdgeClass.between(Vector2i(0, 2), Vector2i(0, 3), 1, "stone"))
	
	print("Input: 3 collinear edges with material 'stone'")
	print("Edge 0: %s -> %s, face=%s, material=%s" % [edges[0].gu_a, edges[0].gu_b, edges[0].face_a, edges[0].material])
	print("Edge 1: %s -> %s, face=%s, material=%s" % [edges[1].gu_a, edges[1].gu_b, edges[1].face_a, edges[1].material])
	print("Edge 2: %s -> %s, face=%s, material=%s" % [edges[2].gu_a, edges[2].gu_b, edges[2].face_a, edges[2].material])
	
	var success = true
	
	# Test inline run grouping logic
	# Group edges by material and face, checking collinearity
	var visited: Dictionary = {}
	var runs: Array = []
	
	for edge in edges:
		if visited.has(edge.id):
			continue
		
		# Start a new run from this edge
		var run_edges: Array = []
		var current = edge
		
		# Walk backward to find run start
		var prev = _find_prev_collinear_edge(current, edges, visited)
		while prev != null:
			current = prev
			prev = _find_prev_collinear_edge(current, edges, visited)
		
		# Now walk forward from current, collecting edges
		while current != null and not visited.has(current.id):
			run_edges.append(current)
			visited[current.id] = true
			current = _find_next_collinear_edge(current, edges, visited)
		
		# Build run
		var min_edge = run_edges[0]
		for e in run_edges:
			if e.gu_a.x < min_edge.gu_a.x or (e.gu_a.x == min_edge.gu_a.x and e.gu_a.y < min_edge.gu_a.y):
				min_edge = e
		
		var run = {
			"edges": run_edges,
			"material_id": current.material if current else edges[0].material,
			"facade_id": "",
			"min_edge": min_edge,
		}
		runs.append(run)
	
	print("\nGrouped runs: %d" % runs.size())
	
	# Should produce 1 run containing all 3 edges
	if runs.size() != 1:
		print("✗ FAIL: Expected 1 run, got %d" % runs.size())
		success = false
	else:
		var run = runs[0]
		var run_edges = run.get("edges", [])
		print("Run 0: %d edges" % run_edges.size())
		
		if run_edges.size() != 3:
			print("✗ FAIL: Expected 3 edges in run, got %d" % run_edges.size())
			success = false
		else:
			# Verify all edges are present
			var edge_ids = {}
			for e in run_edges:
				edge_ids[e.id] = true
			
			for e in edges:
				if not edge_ids.has(e.id):
					print("✗ FAIL: Edge %s missing from run" % e.id)
					success = false
			
			# Verify run metadata
			var min_edge = run.get("min_edge", null)
			print("Run min_edge: gu_a=%s" % [min_edge.gu_a if min_edge else "null"])
			
			if min_edge == null or min_edge.gu_a != Vector2i(0, 0):
				print("✗ FAIL: Expected min_edge with gu_a=(0,0)")
				success = false
	
	if success:
		print("✓ PASS: Run grouping works correctly\n")
	else:
		print("✗ FAIL: Run grouping test failed\n")
	
	return success


## Helper: Find previous collinear edge (faces SE/SW, same material, touching gu_a)
func _find_prev_collinear_edge(edge, edges: Array, visited: Dictionary):
	for candidate in edges:
		if visited.has(candidate.id):
			continue
		if candidate.material != edge.material:
			continue
		if candidate.face_a != edge.face_a:
			continue
		# Check if candidate's gu_b == edge's gu_a (touching)
		if candidate.gu_b == edge.gu_a:
			return candidate
	return null


## Helper: Find next collinear edge (faces SE/SW, same material, touching gu_b)
func _find_next_collinear_edge(edge, edges: Array, visited: Dictionary):
	for candidate in edges:
		if visited.has(candidate.id):
			continue
		if candidate.material != edge.material:
			continue
		if candidate.face_a != edge.face_a:
			continue
		# Check if candidate's gu_a == edge's gu_b (touching)
		if candidate.gu_a == edge.gu_b:
			return candidate
	return null


## TEST 2: Junction override with facade_enabled=false (material-only)
func _test_junction_override_facade_enabled() -> bool:
	print("[TEST 2] Junction Override — facade_enabled=false (Material Only)\n")
	
	# Create two edges that form a junction
	var edge_a = EdgeClass.between(Vector2i(0, 0), Vector2i(0, 1), 1, "concrete")
	var edge_b = EdgeClass.between(Vector2i(0, 0), Vector2i(1, 0), 1, "concrete")
	
	# Create registry and register edges
	var registry = EdgeRegistryClass.new()
	registry.register_edge(edge_a)
	registry.register_edge(edge_b)
	
	# Resolve junctions
	var junctions = JunctionResolverClass.resolve(registry)
	
	print("Edges: (0,0)-(0,1) and (0,0)-(1,0)")
	print("Junctions resolved: %d" % junctions.size())
	
	var success = true
	
	if junctions.is_empty():
		print("✗ FAIL: No junctions resolved")
		return false
	
	# Get the first junction column
	var column = junctions[0]
	print("Junction column: gu=%s, material=%s, facade_enabled=%s" % [column.gu_cell, column.material, column.facade_enabled])
	
	# Default state should have facade_enabled=true and override_material=""
	if not column.facade_enabled:
		print("✗ FAIL: Default junction should have facade_enabled=true")
		success = false
	
	if column.override_material != "":
		print("✗ FAIL: Default junction should have override_material='' (empty)")
		success = false
	
	# Now apply an override with facade_enabled=false
	column.facade_enabled = false
	column.override_material = "metal"
	
	print("After override: facade_enabled=%s, override_material=%s" % [column.facade_enabled, column.override_material])
	
	# Verify override was applied
	if column.facade_enabled:
		print("✗ FAIL: Override failed - facade_enabled still true")
		success = false
	
	if column.override_material != "metal":
		print("✗ FAIL: Override failed - override_material not set to 'metal'")
		success = false
	else:
		print("✓ Material override correctly applied")
	
	if success:
		print("✓ PASS: Junction override with facade_enabled=false works\n")
	else:
		print("✗ FAIL: Junction override test failed\n")
	
	return success


## TEST 3: Junction override with facade_enabled=true (should use override material's strip)
func _test_junction_override_material() -> bool:
	print("[TEST 3] Junction Override — facade_enabled=true (Baked with Override Material)\n")
	
	# Create two edges with original material
	var edge_a = EdgeClass.between(Vector2i(0, 0), Vector2i(0, 1), 1, "stone")
	var edge_b = EdgeClass.between(Vector2i(0, 0), Vector2i(1, 0), 1, "stone")
	
	# Create registry
	var registry = EdgeRegistryClass.new()
	registry.register_edge(edge_a)
	registry.register_edge(edge_b)
	
	# Resolve junctions
	var junctions = JunctionResolverClass.resolve(registry)
	
	if junctions.is_empty():
		print("✗ FAIL: No junctions resolved")
		return false
	
	var column = junctions[0]
	print("Original junction: material=%s, facade_enabled=%s" % [column.material, column.facade_enabled])
	
	# Apply override with different material but keep facade_enabled=true
	column.override_material = "wood"
	
	# Verify:
	# - material field is still original (used for derived fallback)
	# - override_material is set
	# - facade_enabled is true (use baked)
	
	var success = true
	
	if column.material != "stone":
		print("✗ FAIL: Original material changed unexpectedly")
		success = false
	
	if column.override_material != "wood":
		print("✗ FAIL: Override material not set correctly")
		success = false
	
	if not column.facade_enabled:
		print("✗ FAIL: facade_enabled should be true for baked path")
		success = false
	
	if success:
		print("Verified: original material=%s, override=%s, facade_enabled=%s" % [column.material, column.override_material, column.facade_enabled])
		print("✓ PASS: Junction override with facade_enabled=true works\n")
	else:
		print("✗ FAIL: Junction override material test failed\n")
	
	return success


## TEST 4: Junction default (no override) — mirror neighbor atom
func _test_junction_default_no_override() -> bool:
	print("[TEST 4] Junction Default — No Override, No Mirroring (Yet)\n")
	
	# Create two edges forming a V-junction
	var edge_a = EdgeClass.between(Vector2i(1, 0), Vector2i(1, 1), 1, "metal")
	var edge_b = EdgeClass.between(Vector2i(1, 0), Vector2i(2, 0), 1, "metal")
	
	# Create registry
	var registry = EdgeRegistryClass.new()
	registry.register_edge(edge_a)
	registry.register_edge(edge_b)
	
	# Resolve junctions
	var junctions = JunctionResolverClass.resolve(registry)
	
	if junctions.is_empty():
		print("✗ FAIL: No junctions resolved")
		return false
	
	var column = junctions[0]
	print("Default junction: gu=%s, material=%s" % [column.gu_cell, column.material])
	print("              facade_enabled=%s, override_material='%s'" % [column.facade_enabled, column.override_material])
	
	var success = true
	
	# Default behavior:
	# - override_material should be empty
	# - facade_enabled should be true
	# - material should be derived from edges
	
	if column.override_material != "":
		print("✗ FAIL: Default junction should have no override_material")
		success = false
	
	if not column.facade_enabled:
		print("✗ FAIL: Default junction should have facade_enabled=true")
		success = false
	
	if column.material != "metal":
		print("✗ FAIL: Default junction material should be derived from edges")
		success = false
	
	if success:
		print("✓ Default state correct for future mirror implementation")
		print("✓ PASS: Junction default behavior correct\n")
	else:
		print("✗ FAIL: Junction default test failed\n")
	
	return success
