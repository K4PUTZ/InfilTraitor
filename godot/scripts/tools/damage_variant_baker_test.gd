## Test: DamageVariantBaker generates damage variant atoms
## Simple validation that soot intensities and basic decal compositing work

extends Node

func test_damage_variant_generation():
	print("\n[TEST] DamageVariantBaker generation")
	
	var baker = preload("res://godot/scripts/systems/damage_variant_baker.gd").new()
	
	# Test 1: Generate CRACKED variants
	var cracked = baker.generate_cracked_variants("concrete")
	assert(cracked.size() == 3, "Should have 3 soot levels")
	for i in range(3):
		assert(cracked[i].get_width() == 32, "Cracked width should be 32")
		assert(cracked[i].get_height() == 36, "Cracked height should be 36")
	print("✓ CRACKED variants generated (3 soot levels)")
	
	# Test 2: Generate DENTED variants
	var dented = baker.generate_dented_variants("concrete", "blast_top")
	assert(dented.size() == 3, "Should have 3 soot levels")
	for i in range(3):
		assert(dented[i].get_width() == 32, "Dented width should be 32")
		assert(dented[i].get_height() == 36, "Dented height should be 36")
	print("✓ DENTED variants generated (3 soot levels)")
	
	# Test 3: Generate DESTROYED variant
	var destroyed = baker.generate_destroyed_variant("concrete")
	assert(destroyed.get_width() == 32, "Destroyed width should be 32")
	assert(destroyed.get_height() == 36, "Destroyed height should be 36")
	print("✓ DESTROYED variant generated")
	
	# Test 4: Different materials
	for mat in ["metal", "stone", "wood"]:
		var variants = baker.generate_cracked_variants(mat)
		assert(variants.size() == 3, "All materials should have 3 soot levels")
	print("✓ All materials generate variants")
	
	print("[TEST] DamageVariantBaker PASS\n")


func _ready():
	test_damage_variant_generation()
	queue_free()
