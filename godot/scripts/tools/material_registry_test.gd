## MaterialRegistry Selftest (T1 & T2)
##
## Validates:
## 1. Pattern determinism (same input → same output)
## 2. Atlas generation (correct tile count and page creation)
## 3. Tile lookup consistency
## 4. Material registration

extends SceneTree

var MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
var StonePatternClass = preload("res://godot/scripts/systems/stone_pattern.gd")
var WoodPatternClass = preload("res://godot/scripts/systems/wood_pattern.gd")
var MetalPatternClass = preload("res://godot/scripts/systems/metal_pattern.gd")
var MaterialAtlasGeneratorClass = preload("res://godot/scripts/systems/material_atlas_generator.gd")
var PerFaceProjectorClass = preload("res://godot/scripts/systems/per_face_projector.gd")

func _init() -> void:
	print("\n" + "=".repeat(60))
	print("BAKE-02 SELFTEST: MaterialRegistry & Pattern Algorithms")
	print("=".repeat(60) + "\n")
	
	var all_pass = true
	
	# Test 1: Pattern determinism
	if not _test_pattern_determinism():
		all_pass = false
	
	# Test 2: Material registration
	if not _test_material_registration():
		all_pass = false
	
	# Test 3: Atlas generation
	if not _test_atlas_generation():
		all_pass = false
	
	# Test 4: Tile lookup
	if not _test_tile_lookup():
		all_pass = false
	
	print("\n" + "=".repeat(60))
	if all_pass:
		print("BAKE-02 SELFTEST: 4 / 4 PASS")
		print("=".repeat(60) + "\n")
		print("✓ SELFTEST PASS")
	else:
		print("BAKE-02 SELFTEST: FAILED")
		print("=".repeat(60) + "\n")
		print("✗ SELFTEST FAIL")
	
	quit()

## Test 1: Pattern determinism
func _test_pattern_determinism() -> bool:
	print("[TEST 1] Pattern determinism\n")
	
	var stone = StonePatternClass.new()
	var wood = WoodPatternClass.new()
	var metal = MetalPatternClass.new()
	
	var voxel = Vector2i(5, 7)
	var face = PerFaceProjectorClass.Face.NE
	var seed_val = 12345
	
	var success = true
	
	# Test each pattern twice
	for pattern_name in ["stone", "wood", "metal"]:
		var pattern
		if pattern_name == "stone":
			pattern = stone
		elif pattern_name == "wood":
			pattern = wood
		else:
			pattern = metal
		
		var shade1 = pattern.shade(voxel, face, seed_val)
		var shade2 = pattern.shade(voxel, face, seed_val)
		
		if abs(shade1 - shade2) < 0.0001:
			print("    ✓ %s deterministic: %.4f == %.4f" % [pattern_name, shade1, shade2])
		else:
			print("    ✗ %s NOT deterministic: %.4f != %.4f" % [pattern_name, shade1, shade2])
			success = false
	
	if success:
		print("  PASS: pattern_determinism\n")
	else:
		print("  FAIL: pattern_determinism\n")
	
	return success

## Test 2: Material registration
func _test_material_registration() -> bool:
	print("[TEST 2] Material registration\n")
	
	var registry = MaterialRegistryClass.new()
	
	# Register three materials
	var stone_mat = MaterialRegistryClass.MaterialDef.new("stone", Color(0.7, 0.7, 0.7), StonePatternClass.new())
	var wood_mat = MaterialRegistryClass.MaterialDef.new("wood", Color(0.6, 0.35, 0.15), WoodPatternClass.new())
	var metal_mat = MaterialRegistryClass.MaterialDef.new("metal", Color(0.5, 0.55, 0.6), MetalPatternClass.new())
	
	registry.register(stone_mat)
	registry.register(wood_mat)
	registry.register(metal_mat)
	
	var success = true
	
	# Check count
	if registry.count() == 3:
		print("    ✓ Material count: %d" % registry.count())
	else:
		print("    ✗ Expected 3 materials, got %d" % registry.count())
		success = false
	
	# Check retrieval
	var retrieved = registry.get_material("wood")
	if retrieved != null and retrieved.id == "wood":
		print("    ✓ Material retrieval works")
	else:
		print("    ✗ Material retrieval failed")
		success = false
	
	# Check list
	var materials = registry.list_materials()
	if materials.size() == 3 and "stone" in materials:
		print("    ✓ Material list: %s" % str(materials))
	else:
		print("    ✗ Material list invalid: %s" % str(materials))
		success = false
	
	if success:
		print("  PASS: material_registration\n")
	else:
		print("  FAIL: material_registration\n")
	
	return success

## Test 3: Atlas generation
func _test_atlas_generation() -> bool:
	print("[TEST 3] Atlas generation\n")
	
	var registry = MaterialRegistryClass.new()
	registry.register(MaterialRegistryClass.MaterialDef.new("stone", Color(0.7, 0.7, 0.7), StonePatternClass.new()))
	registry.register(MaterialRegistryClass.MaterialDef.new("wood", Color(0.6, 0.35, 0.15), WoodPatternClass.new()))
	registry.register(MaterialRegistryClass.MaterialDef.new("metal", Color(0.5, 0.55, 0.6), MetalPatternClass.new()))
	
	var N = 16  # From BAKE-01
	var faces = [
		PerFaceProjectorClass.Face.NE,
		PerFaceProjectorClass.Face.SE,
		PerFaceProjectorClass.Face.SW,
		PerFaceProjectorClass.Face.NW
	]
	
	var generator = MaterialAtlasGeneratorClass.new()
	var atlas = generator.generate_atlas(registry, N, faces)
	
	var success = true
	
	# Expected: 3 materials × 4 faces × 4 variants = 48 tiles
	var expected_tiles = 3 * 4 * 4
	if atlas.tile_lookup.size() == expected_tiles:
		print("    ✓ Tile count: %d (expected %d)" % [atlas.tile_lookup.size(), expected_tiles])
	else:
		print("    ✗ Expected %d tiles, got %d" % [expected_tiles, atlas.tile_lookup.size()])
		success = false
	
	# Check that pages were created
	if atlas.pages.size() == expected_tiles:
		print("    ✓ Pages created: %d" % atlas.pages.size())
	else:
		print("    ✗ Expected %d pages, got %d" % [expected_tiles, atlas.pages.size()])
		success = false
	
	# Check page dimensions
	if atlas.pages.size() > 0:
		var page = atlas.pages[0]
		if page.get_width() == 32 and page.get_height() == 16:
			print("    ✓ Page dimensions: %dx%d" % [page.get_width(), page.get_height()])
		else:
			print("    ✗ Expected 32×16, got %dx%d" % [page.get_width(), page.get_height()])
			success = false
	
	if success:
		print("  PASS: atlas_generation\n")
	else:
		print("  FAIL: atlas_generation\n")
	
	return success

## Test 4: Tile lookup consistency
func _test_tile_lookup() -> bool:
	print("[TEST 4] Tile lookup consistency\n")
	
	var registry = MaterialRegistryClass.new()
	registry.register(MaterialRegistryClass.MaterialDef.new("stone", Color(0.7, 0.7, 0.7), StonePatternClass.new()))
	
	var faces = [PerFaceProjectorClass.Face.NE]
	var generator = MaterialAtlasGeneratorClass.new()
	var atlas = generator.generate_atlas(registry, 16, faces)
	
	var success = true
	
	# Query all combinations
	for material_id in ["stone"]:
		for face in faces:
			for variant_k in range(4):
				var lookup_key = "%s:%d:%d" % [material_id, face, variant_k]
				var coords = atlas.tile_lookup.get(lookup_key)
				
				if coords != null:
					print("    ✓ Found: %s face=%d variant=%d → page=%d" % 
						[material_id, face, variant_k, coords["page"]])
				else:
					print("    ✗ Missing: %s face=%d variant=%d" % [material_id, face, variant_k])
					success = false
	
	if success:
		print("  PASS: tile_lookup\n")
	else:
		print("  FAIL: tile_lookup\n")
	
	return success
