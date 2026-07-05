## mapfile_export_golden.gd — One-off export script to generate golden .map.json files
## from code-defined maps (PLAYGROUND and SIGMA_01). Run headless once; validates
## round-trip fidelity before finishing.

extends SceneTree

const PlaygroundMapClass = preload("res://godot/scripts/world/maps/definitions/playground_map.gd")
const Sigma01MapClass = preload("res://godot/scripts/world/maps/definitions/sigma_01_map.gd")
const MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")
const MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")
const MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")

func _init() -> void:
	var maps_to_export = [
		{"id": "PLAYGROUND", "getter": func() -> Dictionary: return PlaygroundMapClass.spec()},
		{"id": "SIGMA_01", "getter": func() -> Dictionary: return Sigma01MapClass.spec()},
	]

	var registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)
	var service = MapFileServiceClass.new(registry)
	var file_source = FileMapSourceClass.new()

	var all_ok = true
	for map_def in maps_to_export:
		var map_id: String = map_def["id"]
		var original_spec: Dictionary = map_def["getter"].call()
		
		print("\n[EXPORT] Processing map '%s'..." % map_id)

		# Convert code-defined spec to file-spec format:
		# - board section: inner_size, buffer, floor_tile
		# - actors section: agent_start, guards (patrols converted to arrays)
		# - legacy_compiler section: everything else for MapCompiler (Vector2i→[x,y])
		var file_spec: Dictionary = {
			"id": map_id,
			"meta": {},
			"sections": {
				"board": {
					"inner_size": [original_spec["inner_size"].x, original_spec["inner_size"].y],
					"buffer": original_spec["buffer"],
					"floor_tile": original_spec["floor_tile"]
				},
				"actors": {
					"agent_start": [original_spec["agent_start"].x, original_spec["agent_start"].y],
					"guards": _convert_patrols_to_arrays(original_spec.get("patrols", []))
				},
				"legacy_compiler": {}
			}
		}

		# Pack everything else into legacy_compiler bridge, converting Vector2i to arrays
		for key in original_spec.keys():
			if key not in ["id", "inner_size", "buffer", "floor_tile", "agent_start", "patrols"]:
				file_spec["sections"]["legacy_compiler"][key] = _convert_to_json_compatible(original_spec[key])

		var file_path = "res://maps/%s.map.json" % map_id
		
		# Save
		var save_result = service.save_file(file_path, file_spec)
		if not save_result["ok"]:
			push_error("[EXPORT] Failed to save '%s': %s" % [file_path, save_result["errors"]])
			all_ok = false
			continue
		print("[EXPORT] Saved to %s" % file_path)

		# Round-trip: reload and diff against original
		var reloaded = file_source.get_runtime_spec(map_id)
		if reloaded.is_empty():
			push_error("[EXPORT] Round-trip: failed to reload '%s'" % map_id)
			all_ok = false
			continue

		# Field-by-field diff against original_spec
		var diff_ok = _verify_round_trip(map_id, original_spec, reloaded)
		if not diff_ok:
			all_ok = false

	if all_ok:
		print("\n[EXPORT] ✓ All golden exports succeeded with verified round-trip")
		quit(0)
	else:
		print("\n[EXPORT] ✗ Export failed verification")
		quit(1)

## Convert Vector2i array to plain [x, y] arrays for JSON
func _convert_patrols_to_arrays(patrols: Array) -> Array:
	var result: Array = []
	for route in patrols:
		var route_arrays: Array = []
		for waypoint in route:
			if typeof(waypoint) == TYPE_VECTOR2I:
				route_arrays.append([waypoint.x, waypoint.y])
			elif typeof(waypoint) == TYPE_ARRAY:
				route_arrays.append(waypoint)
			else:
				route_arrays.append(waypoint)
		result.append(route_arrays)
	return result

## Recursively convert Vector2i and other types to JSON-compatible formats
func _convert_to_json_compatible(value) -> Variant:
	if typeof(value) == TYPE_VECTOR2I:
		return [value.x, value.y]
	elif typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value:
			result.append(_convert_to_json_compatible(item))
		return result
	elif typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key in value.keys():
			result[key] = _convert_to_json_compatible(value[key])
		return result
	else:
		return value

func _verify_round_trip(map_id: String, original: Dictionary, reloaded: Dictionary) -> bool:
	var ok = true
	var required_keys = ["id", "inner_size", "buffer", "floor_tile", "agent_start"]
	
	for key in required_keys:
		if key == "id":
			if reloaded.get("id") != map_id:
				push_error("[EXPORT] Round-trip %s: id mismatch (expected '%s', got '%s')" % [map_id, map_id, reloaded.get("id")])
				ok = false
		elif key == "inner_size":
			if reloaded.get("inner_size") != original["inner_size"]:
				push_error("[EXPORT] Round-trip %s: inner_size mismatch (expected %s, got %s)" % [map_id, original["inner_size"], reloaded.get("inner_size")])
				ok = false
		elif key == "buffer":
			if int(reloaded.get("buffer")) != original["buffer"]:
				push_error("[EXPORT] Round-trip %s: buffer mismatch (expected %d, got %d)" % [map_id, original["buffer"], reloaded.get("buffer")])
				ok = false
		elif key == "floor_tile":
			if reloaded.get("floor_tile") != original["floor_tile"]:
				push_error("[EXPORT] Round-trip %s: floor_tile mismatch (expected '%s', got '%s')" % [map_id, original["floor_tile"], reloaded.get("floor_tile")])
				ok = false
		elif key == "agent_start":
			if reloaded.get("agent_start") != original["agent_start"]:
				push_error("[EXPORT] Round-trip %s: agent_start mismatch (expected %s, got %s)" % [map_id, original["agent_start"], reloaded.get("agent_start")])
				ok = false

	# Check patrols/guards bridge — JSON coercion: Vector2i becomes [x, y]
	var original_patrols = original.get("patrols", [])
	var reloaded_patrols = reloaded.get("patrols", [])
	if not _compare_patrols(original_patrols, reloaded_patrols):
		push_error("[EXPORT] Round-trip %s: patrols mismatch" % map_id)
		ok = false

	# Check all other legacy_compiler fields — also subject to JSON coercion
	for key in original.keys():
		if key not in ["id", "inner_size", "buffer", "floor_tile", "agent_start", "patrols"]:
			if not _compare_field_with_coercion(original.get(key), reloaded.get(key)):
				push_error("[EXPORT] Round-trip %s: field '%s' mismatch" % [map_id, key])
				ok = false

	if ok:
		print("[EXPORT] ✓ Round-trip verified for '%s'" % map_id)
	return ok

## Compare patrols array accounting for JSON Vector2i coercion ([x, y]) and numeric coercion
func _compare_patrols(original: Array, reloaded: Array) -> bool:
	if original.size() != reloaded.size():
		return false
	
	for i in range(original.size()):
		var orig_route = original[i]
		var reload_route = reloaded[i]
		
		if orig_route.size() != reload_route.size():
			return false
		
		for j in range(orig_route.size()):
			if not _compare_field_with_coercion(orig_route[j], reload_route[j]):
				return false
	
	return true

## Compare fields recursively, accounting for JSON numeric coercion (Vector2i→[x,y], int/float conversion)
func _compare_field_with_coercion(original, reloaded) -> bool:
	var orig_type = typeof(original)
	var reload_type = typeof(reloaded)
	
	# Handle numeric coercion (int ↔ float)
	if (orig_type in [TYPE_INT, TYPE_FLOAT]) and (reload_type in [TYPE_INT, TYPE_FLOAT]):
		return float(original) == float(reloaded)
	
	# Handle Vector2i vs Array coercion
	if orig_type == TYPE_VECTOR2I and reload_type == TYPE_ARRAY:
		return reloaded.size() == 2 and int(reloaded[0]) == original.x and int(reloaded[1]) == original.y
	if orig_type == TYPE_ARRAY and reload_type == TYPE_VECTOR2I:
		return original.size() == 2 and int(original[0]) == reloaded.x and int(original[1]) == reloaded.y
	
	# Type mismatch (not numeric coercion)
	if orig_type != reload_type:
		return false
	
	# Dictionary comparison
	if orig_type == TYPE_DICTIONARY:
		if original.size() != reloaded.size():
			return false
		for key in original.keys():
			if not reloaded.has(key):
				return false
			if not _compare_field_with_coercion(original[key], reloaded[key]):
				return false
		return true
	
	# Array comparison
	if orig_type == TYPE_ARRAY:
		if original.size() != reloaded.size():
			return false
		for i in range(original.size()):
			if not _compare_field_with_coercion(original[i], reloaded[i]):
				return false
		return true
	
	# Primitive comparison (int, string, bool, etc.)
	return original == reloaded
