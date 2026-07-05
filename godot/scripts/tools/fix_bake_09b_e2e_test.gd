## FIX-BAKE-09b: Real End-to-End Lookup-Hit Test with Enabled Baking
##
## Exercises Items 1, 2, 3, 4, 5 together:
## (a) Enable baking (BakeConfig.enabled = true)
## (b) Build wall descriptors using BakePolicy (real Edge instances)
## (c) Use material that exists in MaterialRegistry
## (d) Run compositor.bake() and verify pages > 0
## (e) Call BakedTileLookup.resolve() with the same real Edge
## (f) Assert BAKED_ATLAS hit (not generic fallback)
## (g) Verify key parity between compositor and lookup derivations

extends SceneTree

var EdgeClass = preload("res://godot/scripts/geometry/edge.gd")
var BakePolicyClass = preload("res://godot/scripts/systems/bake_policy.gd")
var BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
var BakedTileLookupClass = preload("res://godot/scripts/systems/baked_tile_lookup.gd")
var BakeConfigClass = preload("res://godot/scripts/systems/bake_config.gd")
var FacadeSamplerClass = preload("res://godot/scripts/systems/facade_sampler.gd")
var MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")

var _prev_enabled: bool

func _init() -> void:
	print("\n" + "=".repeat(60))
	print("FIX-BAKE-09b: Real E2E Lookup-Hit Test (Baking Enabled)")
	print("=".repeat(60) + "\n")

	# Save and enable baking
	_prev_enabled = BakeConfigClass.enabled
	BakeConfigClass.enabled = true
	print("[SETUP] BakeConfig.enabled = true (was %s)\n" % _prev_enabled)

	var all_pass = true

	# Test: Lookup hit via real Edge with baking enabled
	if not _test_lookup_hit_real_edge():
		all_pass = false

	# Restore baking state
	BakeConfigClass.enabled = _prev_enabled
	print("[CLEANUP] BakeConfig.enabled = %s (restored)\n" % _prev_enabled)

	print("=".repeat(60))
	if all_pass:
		print("FIX-BAKE-09b E2E TEST: PASS")
		print("=".repeat(60) + "\n")
		print("✓ END-TO-END PASS")
	else:
		print("FIX-BAKE-09b E2E TEST: FAIL")
		print("=".repeat(60) + "\n")
		print("✗ END-TO-END FAIL")

	quit(0 if all_pass else 1)


func _test_lookup_hit_real_edge() -> bool:
	print("[TEST] Lookup-hit via real Edge (Items 1–5)")
	print()

	var material_id = "stone"  # Use stone (must exist in MaterialRegistry)

	# Create a real Edge instance (test data)
	var edge = EdgeClass.between(Vector2i(0, 0), Vector2i(1, 0), 1, material_id)
	print("  Created Edge: %s" % edge.id)
	print("    key_string: %s" % edge.key_string())
	print("    material: %s" % edge.material)

	# Build wall descriptor (Item 1: same as room_builder._bake_textures)
	var facade_id = BakePolicyClass.facade_for_material(material_id)
	var wall_desc = {
		"material_id": material_id,
		"facade_id": facade_id,
		"edge": edge,
	}
	print("  Wall descriptor:")
	print("    material_id: %s" % wall_desc["material_id"])
	print("    facade_id: %s" % wall_desc["facade_id"])

	# Build map spec (compositor looks for "wall_tiles" or "room_geometry.walls")
	var map_spec = {
		"wall_tiles": [wall_desc],  # New format
		"room_geometry": {
			"walls": [wall_desc]  # Old format fallback
		},
	}

	# Create and populate a real material registry with the test material
	var registry = MaterialRegistryClass.new()
	var pattern = MaterialRegistryClass.PatternAlgorithm.new()
	var mat_def = MaterialRegistryClass.MaterialDef.new(material_id, Color.GRAY, pattern)
	registry.register(mat_def)
	Engine.set_meta("GLOBAL_MATERIAL_REGISTRY", registry)

	# Create a mock resolver that returns valid images and FULL tier
	var resolver = _create_mock_resolver_full()

	# Run compositor.bake() (Item 1: baking enabled, real materials)
	var compositor = BakeCompositorClass.new()
	var baked_atlas = null
	var success = true

	baked_atlas = compositor.bake(map_spec, resolver)
	if baked_atlas == null:
		baked_atlas = BakeCompositorClass.BakedAtlas.new()

	print("  Baked atlas pages: %d" % baked_atlas.pages.size())
	print("  Baked atlas lookup entries: %d" % baked_atlas.lookup.size())

	# Item 1 assertions: pages and lookup must be populated
	if baked_atlas.pages.size() == 0:
		push_error("ASSERTION FAILED: baked_atlas.pages.size() == 0 (bake set was empty)")
		print("  ✗ FAIL: No pages produced by bake()")
		success = false
		return success

	if baked_atlas.lookup.size() == 0:
		push_error("ASSERTION FAILED: baked_atlas.lookup.size() == 0")
		print("  ✗ FAIL: No lookup entries produced by bake()")
		success = false
		return success

	print("  ✓ Baked atlas has pages and lookup entries\n")

	# Simulate bake registration (set Engine metas)
	var source_ids = {0: 999}  # Mock: page 0 → source_id 999
	Engine.set_meta("GLOBAL_BAKED_ATLAS", baked_atlas)
	Engine.set_meta("BAKED_ATLAS_SOURCE_IDS", source_ids)
	Engine.set_meta("BAKE_TIMESTAMP", Time.get_ticks_msec())

	# Now call BakedTileLookup.resolve() with the same real Edge (Item 1c: baked hit test)
	var lookup = BakedTileLookupClass.new()

	# Variant seeding should be unified via BakePolicy (Item 4 from FIX-09)
	var variant_expected = BakePolicyClass.variant_for(edge, material_id)
	print("  Variant (unified seeding): %d" % variant_expected)

	# Try to resolve — must hit BAKED_ATLAS or test fails
	var result = lookup.resolve(edge, 0, Vector2i.ZERO)  # face NE, voxel (0,0)

	if result == null:
		push_error("ASSERTION FAILED: resolve() returned null")
		print("  ✗ FAIL: Lookup returned null")
		success = false
		Engine.remove_meta("GLOBAL_BAKED_ATLAS")
		Engine.remove_meta("BAKED_ATLAS_SOURCE_IDS")
		Engine.remove_meta("BAKE_TIMESTAMP")
		return success

	print("  Lookup result:")
	print("    source_id_int: %d" % result.source_id_int)
	print("    source_id (string): %s" % result.source_id)
	print("    atlas_coords: %s" % result.atlas_coords)

	# Item 1: Hard assertion — BAKED_ATLAS hit is mandatory when baking is enabled
	if not result.source_id.begins_with("BAKED_ATLAS_"):
		push_error("BAKED HIT ASSERTION FAILED: expected BAKED_ATLAS_*, got '%s'" % result.source_id)
		print("  ✗ FAIL: Expected baked hit, got generic fallback (keys do not match)")
		print("      This indicates the bake set and resolve path have different keys.")
		success = false
	else:
		print("  ✓ BAKED HIT: %s @ %s (source_id_int=%d)" % [result.source_id, result.atlas_coords, result.source_id_int])
		if result.source_id_int != 999:
			push_error("source_id_int mismatch: expected 999, got %d" % result.source_id_int)
			success = false
		else:
			print("  ✓ source_id_int matches mock mapping (999)")

	print()

	# Item 2: Real key-parity check (replace the tautology)
	print("  [CONSISTENCY] Verifying key parity (compositor vs lookup):")

	# Compositor-side key derivation (mirror _populate_bake_set)
	var sampler = FacadeSamplerClass.new()
	var origin = sampler.get_window_origin_isolated_texels(edge, facade_id)
	var comp_key = BakeCompositorClass.BakeKey.new()
	comp_key.material_id = material_id
	comp_key.facade_id = facade_id
	comp_key.variant_k = BakePolicyClass.variant_for(edge, material_id)
	comp_key.face = 0
	comp_key.plane_col = origin.x
	comp_key.plane_row = origin.y
	var comp_key_str = compositor._bake_key_to_string(comp_key)

	# Lookup-side key derivation (its own reconstruction)
	var lookup_key = lookup._make_bake_key(edge, 0, Vector2i.ZERO)
	var lookup_key_str = lookup._bake_key_to_string(lookup_key)

	print("    Compositor key: %s" % comp_key_str)
	print("    Lookup key:     %s" % lookup_key_str)

	if comp_key_str != lookup_key_str:
		push_error("KEY PARITY ASSERTION FAILED: keys differ")
		print("    ✗ FAIL: Keys differ (seeding mismatch)")
		success = false
	else:
		print("    ✓ Key parity: identical derivation on both sides")

	# Clean up
	if Engine.has_meta("GLOBAL_BAKED_ATLAS"):
		Engine.remove_meta("GLOBAL_BAKED_ATLAS")
	if Engine.has_meta("BAKED_ATLAS_SOURCE_IDS"):
		Engine.remove_meta("BAKED_ATLAS_SOURCE_IDS")
	if Engine.has_meta("BAKE_TIMESTAMP"):
		Engine.remove_meta("BAKE_TIMESTAMP")
	if Engine.has_meta("GLOBAL_MATERIAL_REGISTRY"):
		Engine.remove_meta("GLOBAL_MATERIAL_REGISTRY")

	if success:
		print("\n  PASS: lookup_hit_real_edge\n")
	else:
		print("\n  FAIL: lookup_hit_real_edge\n")

	return success




## Mock resolver with FULL tier and proper-sized images (as a class with methods)
class MockResolver:
	var Tier = {"NONE": -1, "PARTIAL": 0, "FULL": 1}

	func resolve(_facade_id: String):
		# Return FULL tier with proper 64N×32N image
		var N = 16
		var img = Image.create(64 * N, 32 * N, false, Image.FORMAT_RGB8)
		# Fill with gray gradient for visibility
		for x in range(img.get_width()):
			for y in range(img.get_height()):
				var shade = int((x + y) % 256)
				img.set_pixel(x, y, Color(shade / 255.0, shade / 255.0, shade / 255.0, 1.0))
		return {"tier": 1, "image": img}  # tier 1 = FULL


func _create_mock_resolver_full():
	return MockResolver.new()
