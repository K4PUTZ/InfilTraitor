#!/usr/bin/env -S /Applications/Godot.app/Contents/MacOS/Godot --headless --script
## BLOCK-01b Item 4: Real Baking E2E for Block-Derived Edges
## Tests that solid blocks reach the bake seam just like walls (Rule #8 compliance)
##
## Flow:
## (a) Enable baking
## (b) Create a block-derived edge via EdgeExtractor
## (c) Run compositor.bake() with the edge
## (d) Call BakedTileLookup.resolve() with the edge
## (e) Assert BAKED_ATLAS hit (not generic fallback) — Rule #8 compliance proven

extends SceneTree

var MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
var EdgeExtractorClass = preload("res://godot/scripts/geometry/edge_extractor.gd")
var BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")
var BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
var BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")
var BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
var MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
var TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")

var _prev_enabled: bool


func _initialize() -> void:
	print("======================================================================")
	print("BLOCK-01b: Item 4 — Real Baking E2E for Block-Derived Edges")
	print("======================================================================")
	print()
	
	# Save and enable baking
	_prev_enabled = BakeConfigClass.enabled
	BakeConfigClass.enabled = true
	print("[SETUP] BakeConfig.enabled = true\n")
	
	var test_pass = _test_block_baking_e2e()
	
	# Restore baking state
	BakeConfigClass.enabled = _prev_enabled
	print("[CLEANUP] BakeConfig.enabled = %s (restored)\n" % _prev_enabled)
	
	print("======================================================================")
	if test_pass:
		print("BLOCK-01b: Item 4 PASS — Blocks reach bake seam ✓ (Rule #8 compliance)")
	else:
		print("BLOCK-01b: Item 4 FAIL")
	print("======================================================================")
	print()
	
	quit(0 if test_pass else 1)


func _test_block_baking_e2e() -> bool:
	print("[TEST] Block-derived edges reach bake seam")
	
	# Create a minimal map with a single block (no perimeter noise)
	var wall_levels = [[
		{"cell": Vector2i(0, 0), "tile_name": "solidblock_stone"},
	]]
	var compiled = {"wall_levels": wall_levels}
	
	# Extract edges (blocks become real edges)
	var extraction = EdgeExtractorClass.extract(compiled)
	if extraction["edges"].size() == 0:
		print("  ✗ FAIL: No edges extracted from block")
		return false
	
	var block_edge = extraction["edges"][0]
	print("  Extracted edge from block:")
	print("    id: %s" % block_edge.id)
	print("    material: %s" % block_edge.material)
	print("    start_storey: %d, storey_count: %d" % [block_edge.start_storey, block_edge.storey_count])
	
	# Set up material registry with stone material
	var registry = MaterialRegistryClass.new()
	var pattern = MaterialRegistryClass.PatternAlgorithm.new()
	var mat_def = MaterialRegistryClass.MaterialDef.new("stone", Color.GRAY, pattern)
	registry.register(mat_def)
	Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", registry)
	
	# Build wall descriptor for the block edge
	var facade_id = BakePolicyClass.facade_for_material(block_edge.material)
	var wall_desc = {
		"material_id": block_edge.material,
		"facade_id": facade_id,
		"edge": block_edge,
	}
	
	# Map spec for compositor
	var map_spec = {
		"wall_tiles": [wall_desc],
		"room_geometry": {
			"walls": [wall_desc]
		},
	}
	
	# Create mock resolver
	var resolver = _create_mock_resolver()
	
	# Run baking compositor
	var compositor = BakeCompositorClass.new()
	var baked_atlas = compositor.bake(map_spec, resolver)
	
	if baked_atlas == null:
		baked_atlas = BakeCompositorClass.BakedAtlas.new()
	
	print("\n  Baked atlas results:")
	print("    pages: %d" % baked_atlas.pages.size())
	print("    lookup entries: %d" % baked_atlas.lookup.size())
	
	if baked_atlas.pages.size() == 0:
		print("  ✗ FAIL: No baked pages produced")
		Engine.remove_meta("GLOBAL_MATERIAL_REGISTRY")
		return false
	
	print("  ✓ Baked atlas pages generated")
	
	# Simulate bake registration
	var source_ids = {0: 999}
	Engine.set_meta("GLOBAL_BAKED_ATLAS", baked_atlas)
	Engine.set_meta("BAKED_ATLAS_SOURCE_IDS", source_ids)
	Engine.set_meta("BAKE_TIMESTAMP", Time.get_ticks_msec())
	
	# Resolve block edge via BakedTileLookup
	var lookup = BakedTileLookupClass.new()
	var result = lookup.resolve(block_edge, 0, Vector2i.ZERO)
	
	if result == null:
		print("  ✗ FAIL: Lookup returned null")
		_cleanup_bake_metas()
		return false
	
	print("\n  Lookup result for block edge:")
	print("    source_id: %s" % result.source_id)
	print("    atlas_coords: %s" % result.atlas_coords)
	
	# Key assertion: BAKED_ATLAS hit (Rule #8 proof)
	if result.source_id.begins_with("BAKED_ATLAS_"):
		print("  ✓ Block edge resolved to BAKED_ATLAS (Rule #8 compliance proven)")
		_cleanup_bake_metas()
		return true
	else:
		print("  ✗ FAIL: Expected BAKED_ATLAS hit, got '%s'" % result.source_id)
		print("    Block edge did NOT reach bake seam (Rule #8 failed)")
		_cleanup_bake_metas()
		return false


func _create_mock_resolver() -> Object:
	## Mock resolver that returns FULL tier with properly-sized image (64N×32N)
	return MockResolver.new()


## Mock resolver with FULL tier and proper-sized images
class MockResolver:
	var Tier = TextureResolver.Tier
	
	func resolve(_facade_id: String):
		# Return DEFAULT tier with proper 64N×32N image
		var N = 16
		var img = Image.create(64 * N, 32 * N, false, Image.FORMAT_RGB8)
		# Fill with gray gradient for visibility
		for x in range(img.get_width()):
			for y in range(img.get_height()):
				var shade = int((x + y) % 256)
				img.set_pixel(x, y, Color(shade / 255.0, shade / 255.0, shade / 255.0, 1.0))
		return {"tier": TextureResolver.Tier.DEFAULT, "image": img}


func _cleanup_bake_metas() -> void:
	Engine.remove_meta("GLOBAL_MATERIAL_REGISTRY")
	Engine.remove_meta("GLOBAL_BAKED_ATLAS")
	Engine.remove_meta("BAKED_ATLAS_SOURCE_IDS")
	Engine.remove_meta("BAKE_TIMESTAMP")
