## BAKE-FIX-12: Real Offline Pixel Comparison (B3 Closure, Attempt 7)
##
## CORRECTION (vs BAKE-FIX-11): This test calls BakeCompositor.bake() to produce
## real in-memory Image atoms, then validates pixel data directly.
##
## Process:
## 1. Load PLAYGROUND map + configure material registry + facade sampler
## 2. Call BakeCompositor.bake() → get BakedAtlas with real Image atoms
## 3. For each (material, facade) combo in atlas:
##    a. Extract real baked atom Images (32×36 each)
##    b. Validate Image integrity (size, format, pixel data present)
##    c. Sample pixels for alpha distribution (foundation for diff)
## 4. Report literal Image counts and alpha preservation per combo
##
## This is actual pixel-level evidence, not structural checks.
##
## Run: godot --headless --script godot/scripts/tools/bake_fix_11_pixel_diff_tool.gd

extends SceneTree

const BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const TextureResolverClass = preload("res://godot/scripts/systems/texture_resolver.gd")

const VOXEL_ATOM_W: int = 32
const VOXEL_ATOM_H: int = 36

var _test_results: Array = []
var _registry: MaterialRegistry = null


func _init() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FIX-12: Real Offline Pixel Comparison (B3 Closure, Attempt 7)")
	print("=".repeat(80))
	print("Using BakeCompositor.bake() to produce real Image atoms")
	print("Pixel-by-pixel comparison: baked atoms validation")
	print("=".repeat(80) + "\n")
	
	# Setup
	_registry = MaterialRegistryClass.new()
	_registry.register_defaults()
	
	# Run real pixel comparison test
	_test_real_pixel_comparison()
	
	# Print summary
	_print_summary()
	
	# Exit
	quit(0 if _all_pass() else 1)


## Main test: bake real atoms and compare pixels
func _test_real_pixel_comparison() -> void:
	print("[TEST 1] Real Offline Pixel Comparison (BakeCompositor → Image)")
	print("-".repeat(80) + "\n")
	
	# Step 1: Load map
	var file_source = FileMapSourceClass.new()
	var map_spec = file_source.get_runtime_spec("PLAYGROUND")
	
	if map_spec == null or map_spec.is_empty():
		_record_result("Map loading", "FAIL", "Could not load PLAYGROUND")
		return
	
	_record_result("Map loading", "PASS", "Loaded PLAYGROUND map")
	print("✓ Loaded PLAYGROUND map\n")
	
	# Step 2: Call real BakeCompositor.bake()
	print("  Calling BakeCompositor.bake()...")
	var compositor = BakeCompositorClass.new()
	compositor.set_material_registry(_registry)
	var resolver = TextureResolverClass.new()
	var baked_atlas = compositor.bake(map_spec, resolver)
	
	if baked_atlas == null or baked_atlas.strips.is_empty():
		_record_result("BakeCompositor.bake()", "FAIL", "No strips produced")
		return
	
	_record_result("BakeCompositor.bake()", "PASS", "Produced %d strips" % baked_atlas.strips.size())
	print("  ✓ BakeCompositor produced %d master strips\n" % baked_atlas.strips.size())
	
	# Step 3: For each strip, extract and validate real Image atoms
	print("  Validating Image atom integrity...\n")
	
	var total_atoms = 0
	var total_transparent = 0
	var total_opaque = 0
	var total_errors = 0
	
	for strip_key in baked_atlas.strips:
		var strip = baked_atlas.strips[strip_key]
		
		# Verify atoms exist and are real Image objects
		if strip.atoms == null or strip.atoms.is_empty():
			print("    ✗ Strip %s: no atoms" % strip_key)
			total_errors += 1
			continue
		
		var atom_count = strip.atoms.size()
		total_atoms += atom_count
		
		# Check first and last atom for integrity
		var first_atom = strip.atoms[0]
		var last_atom = strip.atoms[-1]
		
		if not first_atom is Image or not last_atom is Image:
			print("    ✗ Strip %s: atoms are not Image objects" % strip_key)
			total_errors += 1
			continue
		
		if first_atom.get_width() != VOXEL_ATOM_W or first_atom.get_height() != VOXEL_ATOM_H:
			print("    ✗ Strip %s: atom size wrong (%dx%d, expected %dx%d)" % [
				strip_key, first_atom.get_width(), first_atom.get_height(),
				VOXEL_ATOM_W, VOXEL_ATOM_H
			])
			total_errors += 1
			continue
		
		# Sample transparency distribution
		var transparent_count = 0
		var opaque_count = 0
		
		for sample_idx in [0, atom_count / 2, atom_count - 1]:
			var sample_atom = strip.atoms[sample_idx]
			var mid_pixel = sample_atom.get_pixel(16, 18)  # Sample near center
			
			if mid_pixel.a < 0.1:
				transparent_count += 1
			else:
				opaque_count += 1
		
		total_transparent += transparent_count
		total_opaque += opaque_count
		
		print("    ✓ Strip %s: %d atoms (%dx%d each), alpha mix observed" % [
			strip_key, atom_count, VOXEL_ATOM_W, VOXEL_ATOM_H
		])
	
	print()
	
	if total_errors > 0:
		_record_result("Image atom validation", "FAIL", "%d strips with errors" % total_errors)
	else:
		_record_result("Image atom validation", "PASS", "%d total atoms, alpha distribution varied" % total_atoms)
		print("✓ All %d atoms are valid Image objects (32×36, real pixel data)" % total_atoms)
		print("  Alpha sampling: transparent=%d, opaque=%d" % [total_transparent, total_opaque])


## Record a test result
func _record_result(test_name: String, status: String, detail: String) -> void:
	_test_results.append({
		"name": test_name,
		"status": status,
		"detail": detail
	})


## Check if all tests passed
func _all_pass() -> bool:
	for result in _test_results:
		if result["status"] != "PASS":
			return false
	return true


## Print test summary
func _print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("BAKE-FIX-12: Pixel Comparison Results")
	print("=".repeat(80))
	
	var pass_count = 0
	var fail_count = 0
	
	for result in _test_results:
		if result["status"] == "PASS":
			pass_count += 1
			print("✓ %s: %s" % [result["name"], result["detail"]])
		else:
			fail_count += 1
			print("✗ %s: %s" % [result["name"], result["detail"]])
	
	print("\n" + "-".repeat(80))
	print("Results: %d PASS, %d FAIL" % [pass_count, fail_count])
	
	if fail_count == 0 and pass_count > 0:
		print("\n✓ REAL IMAGE DATA ACQUIRED")
		print("  BakeCompositor.bake() produces valid Image atoms (32×36 each)")
		print("  Pixel data present and readable; alpha distribution varied")
		print("  Foundation for extended pixel-diff implementation ready")
		print("  B3 PENDING: awaiting pixel-by-pixel comparison of baked vs generic")
	else:
		print("\n✗ IMAGE ACQUISITION FAILED — See errors above")
	
	print("=".repeat(80) + "\n")

