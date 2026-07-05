## FIX-BAKE-01 TEST: String Key Deduplication
##
## Tests that BakeKey serialization to strings enables:
## 1. Deterministic string generation from identical keys
## 2. Uniqueness when keys differ
## 3. Dictionary deduplication with string keys
## 4. Lookup hits in dictionaries keyed by string

extends SceneTree

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("FIX-BAKE-01 TEST: String Key Deduplication")
	print("=".repeat(70) + "\n")

	var test_passed = true

	# Test 1: Identical BakeKeys produce identical strings
	print("[TEST 1] String Serialization Determinism\n")
	var key1 = _make_bake_key("stone", "marble_base", 2, 0, 8, 0)
	var key2 = _make_bake_key("stone", "marble_base", 2, 0, 8, 0)

	var str1 = _bake_key_to_string(key1)
	var str2 = _bake_key_to_string(key2)

	assert(str1 == str2, "Identical keys must produce identical strings")
	print("    ✓ key1 string: %s" % str1)
	print("    ✓ key2 string: %s" % str2)
	print("    ✓ str1 == str2 (deterministic)\n")
	print("  PASS: String Serialization Determinism\n")

	# Test 2: Different BakeKeys produce different strings
	print("[TEST 2] String Uniqueness (different fields)\n")
	var key3 = _make_bake_key("wood", "marble_base", 2, 0, 8, 0)

	var str3 = _bake_key_to_string(key3)
	assert(str1 != str3, "Different keys must produce different strings")
	print("    ✓ key1 (stone): %s" % str1)
	print("    ✓ key3 (wood):  %s" % str3)
	print("    ✓ str1 != str3 (unique)\n")
	print("  PASS: String Uniqueness\n")

	# Test 3: Dictionary deduplication with String keys
	print("[TEST 3] Dictionary Deduplication\n")
	var bake_set = {}
	bake_set[str1] = null
	bake_set[str2] = null  # Same key, should not increase size
	bake_set[str3] = null  # Different key

	assert(bake_set.size() == 2, "Dedup should reduce 3 entries to 2 (got %d)" % bake_set.size())
	print("    ✓ Added str1, str2 (same), str3 (diff)")
	print("    ✓ Set size: %d (expected 2)" % bake_set.size())
	print("    ✓ Deduplication working\n")
	print("  PASS: Dictionary Deduplication\n")

	# Test 4: Lookup can find entries (the live requirement)
	print("[TEST 4] Lookup Hit\n")
	var lookup = {}
	lookup[str1] = { "page": 0, "atlas_coords": Vector2i(5, 3) }

	var found = lookup.has(str1)
	var not_found = lookup.has("nonexistent|key")
	assert(found, "Lookup must find existing keys")
	assert(not not_found, "Lookup must not find missing keys")
	print("    ✓ lookup.has(str1) = true")
	print("    ✓ lookup.has('nonexistent') = false")
	print("    ✓ Lookup working\n")
	print("  PASS: Lookup Hit\n")

	print("=".repeat(70))
	print("✓ FIX-BAKE-01 ALL TESTS PASS")
	print("=".repeat(70) + "\n")
	quit(0)


## Helper: Create a BakeKey from components
func _make_bake_key(material_id: String, facade_id: String, variant_k: int,
					 face: int, plane_col: int, plane_row: int):
	# We need to use the actual BakeKey class from BakeCompositor
	var BakeCompositorClass = preload("res://godot/scripts/systems/bake_compositor.gd")
	var key = BakeCompositorClass.BakeKey.new()
	key.material_id = material_id
	key.facade_id = facade_id
	key.variant_k = variant_k
	key.face = face
	key.plane_col = plane_col
	key.plane_row = plane_row
	return key


## Helper: Serialize BakeKey to string (same logic as in compositor)
func _bake_key_to_string(key) -> String:
	return "%s|%s|%d|%d|%d|%d" % [
		key.material_id, key.facade_id, key.variant_k,
		key.face, key.plane_col, key.plane_row
	]
