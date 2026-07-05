## mapfile_integration_test.gd — Validate FileMapSource and MapCatalog integration

extends SceneTree

const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCatalogClass = preload("res://godot/scripts/world/maps/map_catalog.gd")

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("MAPFILE INTEGRATION TEST")
	print("=".repeat(70) + "\n")

	var all_ok = true

	# Test 1: FileMapSource.list_available()
	print("[TEST 1] FileMapSource.list_available()\n")
	var file_source = FileMapSourceClass.new()
	var available = file_source.list_available()
	print("  Found %d maps:" % available.size())
	for map_id in available.keys():
		print("    - %s: %s" % [map_id, available[map_id]])
	
	if available.has("PLAYGROUND") and available.has("SIGMA_01"):
		print("  ✓ Both golden files found")
	else:
		print("  ✗ Missing golden files")
		all_ok = false
	print()

	# Test 2: MapCatalog.list_map_ids()
	print("[TEST 2] MapCatalog.list_map_ids()\n")
	var ids = MapCatalogClass.list_map_ids()
	print("  Catalog has %d IDs" % ids.size())
	for id in ids:
		print("    - %s" % id)
	if ids.has("PLAYGROUND") and ids.has("SIGMA_01"):
		print("  ✓ Golden files in catalog")
	else:
		print("  ✗ Golden files not in catalog")
		all_ok = false
	print()

	# Test 3: Load PLAYGROUND via MapCatalog
	print("[TEST 3] MapCatalog.get_spec('PLAYGROUND')\n")
	var pg_spec = MapCatalogClass.get_spec("PLAYGROUND")
	if pg_spec.has("id") and pg_spec["id"] == "PLAYGROUND":
		print("  ✓ Loaded PLAYGROUND spec")
		if pg_spec.has("inner_size") and pg_spec.has("buffer"):
			print("  ✓ Has required fields (inner_size, buffer)")
		else:
			print("  ✗ Missing required fields")
			all_ok = false
	else:
		print("  ✗ Failed to load PLAYGROUND")
		all_ok = false
	print()

	# Test 4: Load SIGMA_01 via MapCatalog
	print("[TEST 4] MapCatalog.get_spec('SIGMA_01')\n")
	var sigma_spec = MapCatalogClass.get_spec("SIGMA_01")
	if sigma_spec.has("id") and sigma_spec["id"] == "SIGMA_01":
		print("  ✓ Loaded SIGMA_01 spec")
		if sigma_spec.has("dividers") and sigma_spec.has("patrols"):
			print("  ✓ Has legacy_compiler fields (dividers, patrols)")
		else:
			print("  ✗ Missing legacy_compiler fields")
			all_ok = false
	else:
		print("  ✗ Failed to load SIGMA_01")
		all_ok = false
	print()

	# Test 5: Collision precedence (user:// wins over res://)
	print("[TEST 5] User collision precedence\n")
	print("  Creating test file: user://maps/PLAYGROUND.map.json")
	
	# Create user version of PLAYGROUND
	var test_json = """
{
	"format": "infiltraitor-map",
	"schema_version": 3,
	"id": "PLAYGROUND",
	"meta": {"title": "USER_VERSION"},
	"sections": {
		"board": {"v": 1, "inner_size": [5, 5], "buffer": 1, "floor_tile": "floor_SE"},
		"walls": {"v": 2, "edges": []},
		"blocks": {"v": 1, "items": []},
		"props": {"v": 1, "items": []},
		"actors": {"v": 1, "agent_start": [0, 0], "guards": []},
		"legacy_compiler": {}
	}
}"""
	var user_maps_dir = "user://maps"
	if not DirAccess.dir_exists_absolute(user_maps_dir):
		DirAccess.make_dir_recursive_absolute(user_maps_dir)
	
	var file = FileAccess.open("user://maps/PLAYGROUND.map.json", FileAccess.WRITE)
	file.store_string(test_json)
	file.close()
	
	# Refresh file source and check if user:// is found
	var new_file_source = FileMapSourceClass.new()
	var new_available = new_file_source.list_available()
	if new_available.has("PLAYGROUND"):
		if new_available["PLAYGROUND"] == "user://maps/PLAYGROUND.map.json":
			print("  ✓ User version takes precedence (user://maps/PLAYGROUND.map.json)")
		else:
			print("  ✗ Wrong path returned: %s" % new_available["PLAYGROUND"])
			all_ok = false
	else:
		print("  ✗ PLAYGROUND not found after user version created")
		all_ok = false
	
	# Cleanup user file
	DirAccess.remove_absolute("user://maps/PLAYGROUND.map.json")
	print()

	print("=".repeat(70))
	if all_ok:
		print("MAPFILE INTEGRATION: ALL TESTS PASS")
	else:
		print("MAPFILE INTEGRATION: SOME TESTS FAILED")
	print("=".repeat(70) + "\n")
	quit(0 if all_ok else 1)
