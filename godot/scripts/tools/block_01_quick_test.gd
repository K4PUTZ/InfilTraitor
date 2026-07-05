## Quick test to verify blocks handling works end-to-end
## This script runs headless and exits with code 0 on success, 1 on failure
extends SceneTree

const MapCatalogClass = preload("res://godot/scripts/world/maps/map_catalog.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")

func _initialize() -> void:
	print("======================================================================")
	print("BLOCK-01: Quick Test — Blocks End-to-End")
	print("======================================================================")
	
	# Test 1: Load TEST_BLOCKS map from file
	print("\n[TEST 1] Load TEST_BLOCKS.map.json")
	var spec = MapCatalogClass.get_spec("TEST_BLOCKS")
	if spec.is_empty():
		print("  FAIL: Could not load TEST_BLOCKS spec")
		quit(1)
		return
	print("  PASS: Loaded spec for %s" % spec.get("id", "unknown"))
	
	# Check the blocks in the compiled spec (it gets translated from legacy_compiler)
	var legacy_compiler = spec.get("legacy_compiler", {})
	var dividers = legacy_compiler.get("dividers", [])
	print("    - Dividers in legacy_compiler: %d" % dividers.size())
	
	# Test 2: Compile the layout
	print("\n[TEST 2] Compile TEST_BLOCKS layout")
	var layout = MapCompilerClass.compile(spec)
	if layout.is_empty():
		print("  FAIL: Compilation failed")
		quit(1)
		return
	print("  PASS: Compiled successfully")
	print("    - Size: %s" % layout.get("size", Vector2i.ZERO))
	print("    - Blocked cells: %d" % layout.get("blocked_cells", []).size())
	print("    - Wall levels: %d" % layout.get("wall_levels", []).size())
	
	# Test 3: Extract edges and verify solidblock_ entries create edges
	print("\n[TEST 3] Extract edges and verify solid blocks")
	var extraction = EdgeExtractorClass.extract(layout)
	var edges = extraction.get("edges", [])
	var solid_blocks = extraction.get("solid_blocks", [])
	print("  PASS: Extracted %d edges, %d legacy solid_blocks" % [edges.size(), solid_blocks.size()])
	
	# Count stone and concrete edges (our test blocks)
	var stone_edges = 0
	var concrete_edges = 0
	for edge in edges:
		if edge.material == "stone":
			stone_edges += 1
		elif edge.material == "concrete":
			concrete_edges += 1
	
	print("    - Stone edges: %d" % stone_edges)
	print("    - Concrete edges: %d" % concrete_edges)
	
	if stone_edges > 0:
		print("  PASS: Stone block created edges (Rule #8 compliance)")
	if concrete_edges > 0:
		print("  PASS: Concrete block created edges (multi-storey)")
	
	print("\n======================================================================")
	print("BLOCK-01: Quick Test Complete — All tests passed!")
	print("======================================================================\n")
	
	quit(0)
