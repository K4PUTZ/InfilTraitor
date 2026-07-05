## mapfile_roundtrip_test.gd — Comprehensive round-trip and migration testing
##
## Tests:
## 1. Basic round-trip: save spec -> load -> verify structural equality
## 2. Tolerant round-trip: unknown section preservation (M3)
## 3. Migration RED (missing migration fails loudly) + GREEN (migration present succeeds)

extends SceneTree

var MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")
var MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")
var MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("MAPFILE ROUNDTRIP TEST")
	print("=".repeat(70) + "\n")

	var all_pass = true

	if not _test_basic_roundtrip():
		all_pass = false
	if not _test_tolerant_unknown_section():
		all_pass = false
	if not _test_migration_red_then_green():
		all_pass = false
	if not _test_nested_directory_save():
		all_pass = false

	print("\n" + "=".repeat(70))
	if all_pass:
		print("MAPFILE ROUNDTRIP: ALL TESTS PASS")
	else:
		print("MAPFILE ROUNDTRIP: SOME TESTS FAILED")
	print("=".repeat(70) + "\n")
	quit(0 if all_pass else 1)

## Test 1: Basic round-trip
func _test_basic_roundtrip() -> bool:
	print("[TEST 1] Basic round-trip: save → load → structural equality\n")

	var spec = {
		"id": "TEST_MAP",
		"meta": {"title": "Test", "author": "Test"},
		"sections": {
			"board": {"inner_size": [20, 15], "buffer": 1, "floor_tile": "floor_SE"},
			"walls": {"edges": [{"a": [5, 5], "b": [10, 10], "material": "stone"}]},
			"blocks": {"items": []},
			"props": {"items": []},
			"actors": {"agent_start": [1, 1], "guards": []}
		},
		"procedural": null,
		"patches": []
	}

	var registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)
	var service = MapFileServiceClass.new(registry)

	var temp_path = "user://test_roundtrip.map.json"
	var save_result = service.save_file(temp_path, spec)
	if not save_result["ok"]:
		print("  ✗ Save failed: %s" % save_result["errors"])
		return false
	print("  ✓ Saved to %s" % temp_path)

	var load_result = service.load_file(temp_path)
	if not load_result["ok"]:
		print("  ✗ Load failed: %s" % load_result["errors"])
		return false
	print("  ✓ Loaded from disk")

	var loaded_spec = load_result["spec"]
	
	# Verify structural equality (field-by-field, not JSON text)
	if loaded_spec["id"] != spec["id"]:
		print("  ✗ ID mismatch: %s != %s" % [loaded_spec["id"], spec["id"]])
		return false
	
	# Note: JSON parse converts all numbers to float, so we compare numerically
	var loaded_board_size = loaded_spec["sections"]["board"]["inner_size"]
	var orig_board_size = spec["sections"]["board"]["inner_size"]
	if loaded_board_size.size() != orig_board_size.size():
		print("  ✗ Board inner_size array length mismatch")
		return false
	for i in range(orig_board_size.size()):
		if int(loaded_board_size[i]) != orig_board_size[i]:
			print("  ✗ Board inner_size[%d] mismatch: %s != %s" % [i, loaded_board_size[i], orig_board_size[i]])
			return false
	
	if loaded_spec["sections"]["walls"]["edges"].size() != spec["sections"]["walls"]["edges"].size():
		print("  ✗ Walls edges count mismatch")
		return false

	# Clean up
	DirAccess.remove_absolute(temp_path)
	print("  ✓ Structural equality verified")
	print("  PASS: basic_roundtrip\n")
	return true

## Test 2: Tolerant round-trip (unknown section preservation)
func _test_tolerant_unknown_section() -> bool:
	print("[TEST 2] Tolerant round-trip: unknown section preservation (M3)\n")

	# Hand-craft JSON with unknown section
	var json_text = """{
	"format": "infiltraitor-map",
	"schema_version": 3,
	"id": "TEST_UNKNOWN",
	"meta": {},
	"sections": {
		"board": {"v": 1, "inner_size": [20, 15], "buffer": 1, "floor_tile": "floor_SE"},
		"walls": {"v": 2, "edges": []},
		"blocks": {"v": 1, "items": []},
		"props": {"v": 1, "items": []},
		"actors": {"v": 1, "agent_start": [0, 0], "guards": []},
		"future_section": {"v": 1, "mystery_field": true, "some_data": [1, 2, 3]}
	}
}"""

	var temp_path = "user://test_unknown_section.map.json"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	file.store_string(json_text)
	file.close()
	print("  ✓ Written test file with unknown section")

	var registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)
	var service = MapFileServiceClass.new(registry)

	var load_result = service.load_file(temp_path)
	if not load_result["ok"]:
		print("  ✗ Load failed: %s" % load_result["errors"])
		return false
	print("  ✓ Loaded file with unknown section")

	var loaded_spec = load_result["spec"]
	if not loaded_spec["sections"].has("future_section"):
		print("  ✗ Unknown section was stripped!")
		return false
	var unknown = loaded_spec["sections"]["future_section"]
	# JSON converts all numbers to float
	var some_data_int = []
	for val in unknown.get("some_data", []):
		some_data_int.append(int(val))
	if unknown.get("mystery_field") != true or some_data_int != [1, 2, 3]:
		print("  ✗ Unknown section data corrupted: mystery_field=%s, some_data=%s" % [unknown.get("mystery_field"), some_data_int])
		return false
	print("  ✓ Unknown section preserved verbatim")

	# Now save and reload to verify round-trip
	var save_result = service.save_file(temp_path, loaded_spec)
	if not save_result["ok"]:
		print("  ✗ Re-save failed: %s" % save_result["errors"])
		return false
	print("  ✓ Re-saved with unknown section intact")

	var reload_result = service.load_file(temp_path)
	if not reload_result["ok"]:
		print("  ✗ Re-load failed: %s" % reload_result["errors"])
		return false
	var reloaded_spec = reload_result["spec"]
	if not reloaded_spec["sections"].has("future_section"):
		print("  ✗ Unknown section lost on second round-trip")
		return false
	print("  ✓ Unknown section survived second round-trip")

	DirAccess.remove_absolute(temp_path)
	print("  PASS: tolerant_unknown_section\n")
	return true

## Test 3: Migration RED (missing migration fails) + GREEN (migration succeeds)
func _test_migration_red_then_green() -> bool:
	print("[TEST 3] Migration RED (missing) + GREEN (present)\n")

	# RED: Create a broken registry without the v1->v2 migration for walls
	print("  [RED] Testing broken migration chain (missing v1->v2)...")
	var red_registry = MapSectionRegistryClass.new()
	
	# Register everything except walls, which we'll register WITHOUT the v1->v2 migration
	MapSectionsV1Class.register_board(red_registry)
	MapSectionsV1Class.register_blocks(red_registry)
	MapSectionsV1Class.register_props(red_registry)
	MapSectionsV1Class.register_actors(red_registry)
	
	# Register walls at v2 but with NO migrations (broken chain)
	var SectionOwner = red_registry.SectionOwner
	red_registry.register(SectionOwner.new(
		"walls",
		2,
		func(fragment: Dictionary) -> Dictionary: return { "edges": fragment.get("edges", []) },
		func(raw: Dictionary) -> Dictionary: return { "edges": raw.get("edges", []) },
		{},  # EMPTY: no migrations!
		func() -> Dictionary: return { "edges": [] }
	))
	
	# Craft a v1 walls section
	var json_text = """{
	"format": "infiltraitor-map",
	"schema_version": 3,
	"id": "TEST_MIGRATION",
	"meta": {},
	"sections": {
		"board": {"v": 1, "inner_size": [20, 15], "buffer": 1, "floor_tile": "floor_SE"},
		"walls": {"v": 1, "edges": [{"a": [5, 5], "b": [10, 10], "material": "stone"}]},
		"blocks": {"v": 1, "items": []},
		"props": {"v": 1, "items": []},
		"actors": {"v": 1, "agent_start": [0, 0], "guards": []}
	}
}"""

	var temp_path = "user://test_migration.map.json"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	file.store_string(json_text)
	file.close()

	var red_service = MapFileServiceClass.new(red_registry)
	var red_result = red_service.load_file(temp_path)
	
	if red_result["ok"]:
		print("  ✗ RED case should have failed but didn't!")
		DirAccess.remove_absolute(temp_path)
		return false
	if red_result["errors"].size() == 0:
		print("  ✗ RED case returned errors but they're empty!")
		DirAccess.remove_absolute(temp_path)
		return false
	
	# The error should indicate migration failure (the push_error is logged separately)
	var error_text = red_result["errors"][0]
	if "migration" not in error_text:
		print("  ✗ RED case wrong error: %s" % error_text)
		DirAccess.remove_absolute(temp_path)
		return false
	print("  ✓ RED correctly failed with: '%s'" % error_text)

	# GREEN: Now use the proper registry WITH the v1->v2 migration
	print("  [GREEN] Testing correct migration chain (with v1->v2)...")
	var green_registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(green_registry)  # This HAS the migration
	
	var green_service = MapFileServiceClass.new(green_registry)
	var green_result = green_service.load_file(temp_path)
	
	if not green_result["ok"]:
		print("  ✗ GREEN case failed: %s" % green_result["errors"])
		DirAccess.remove_absolute(temp_path)
		return false
	print("  ✓ GREEN correctly loaded")

	# Verify the migration actually ran: edge should have storeys=1 and section should be v2
	var loaded_spec = green_result["spec"]
	var walls_section = loaded_spec["sections"]["walls"]
	if walls_section["edges"].size() > 0:
		var first_edge = walls_section["edges"][0]
		if not first_edge.has("storeys"):
			print("  ✗ Migration didn't backfill storeys field")
			DirAccess.remove_absolute(temp_path)
			return false
		if first_edge["storeys"] != 1:
			print("  ✗ Migration set storeys=%s instead of 1" % first_edge["storeys"])
			DirAccess.remove_absolute(temp_path)
			return false
	print("  ✓ Migration correctly backfilled storeys=1")

	DirAccess.remove_absolute(temp_path)
	print("  PASS: migration_red_then_green\n")
	return true

## Test 4: Nested directory save (regression for directory creation fix in Item 5.2)
func _test_nested_directory_save() -> bool:
	print("[TEST 4] Nested directory save: user://maps/subtest/nested.map.json\n")

	var registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)
	var service = MapFileServiceClass.new(registry)

	# Create a simple spec
	var spec = {
		"id": "TEST_NESTED",
		"meta": {},
		"sections": {
			"board": {"inner_size": [10, 10], "buffer": 1, "floor_tile": "floor_SE"},
			"walls": {"edges": []},
			"blocks": {"items": []},
			"props": {"items": []},
			"actors": {"agent_start": [0, 0], "guards": []}
		}
	}

	# Save to nested path where parent directories don't exist yet
	var nested_path = "user://maps/subtest/nested.map.json"
	var save_result = service.save_file(nested_path, spec)
	
	if not save_result["ok"]:
		print("  ✗ Failed to save to nested path: %s" % save_result["errors"])
		return false
	print("  ✓ Saved to nested path: %s" % nested_path)

	# Verify file exists and is readable
	if not FileAccess.file_exists(nested_path):
		print("  ✗ File was not actually created at %s" % nested_path)
		return false
	print("  ✓ File exists at nested location")

	# Round-trip load to verify it's valid
	var load_result = service.load_file(nested_path)
	if not load_result["ok"]:
		print("  ✗ Failed to reload from nested path: %s" % load_result["errors"])
		DirAccess.remove_absolute(nested_path)
		return false
	print("  ✓ Successfully reloaded from nested path")

	# Cleanup
	DirAccess.remove_absolute(nested_path)
	# Clean up empty directory if possible
	var parent_dir = nested_path.get_base_dir()
	DirAccess.remove_absolute(parent_dir)
	
	print("  PASS: nested_directory_save\n")
	return true

