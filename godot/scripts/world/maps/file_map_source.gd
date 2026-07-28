class_name FileMapSource
extends RefCounted

const RES_MAPS_DIR := "res://maps"
const USER_MAPS_DIR := "user://maps"

var registry: Variant
var service: Variant

func _init() -> void:
	var MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")
	var MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")
	var MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")
	
	registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)
	service = MapFileServiceClass.new(registry)

## Scan both directories; user:// wins on id collision. Returns {id: full_path}.
func list_available() -> Dictionary:
	var found: Dictionary = {}
	_scan_dir(RES_MAPS_DIR, found)   # res:// first...
	_scan_dir(USER_MAPS_DIR, found)  # ...user:// overwrites on collision (wins)
	return found

func _scan_dir(dir_path: String, found: Dictionary) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".map.json"):
			var full_path = dir_path.path_join(fname)
			var id = _peek_id(full_path)
			if id != "":
				found[id] = full_path
		fname = dir.get_next()

## Read just enough to get the id without full load/migrate (catalog listing is cheap).
func _peek_id(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return ""
	return parsed.get("id", "")

## Load a map_id's file (if any) and translate to the MapCompiler runtime spec shape.
## Returns {} if not found — caller (MapCatalog) treats that as "not a file map,
## fall through to code-defined maps."
func get_runtime_spec(map_id: String) -> Dictionary:
	var available = list_available()
	if not available.has(map_id):
		return {}

	var result = service.load_file(available[map_id])
	if not result["ok"]:
		push_error("[FileMapSource] Failed to load '%s': %s" % [map_id, result["errors"]])
		return {}

	return _translate_to_runtime_spec(result["spec"])

## The translator. See Item 0 for why this exists in two tiers (native + bridge).
func _translate_to_runtime_spec(file_spec: Dictionary) -> Dictionary:
	var sections = file_spec.get("sections", {})
	var runtime: Dictionary = {}

	runtime["id"] = file_spec.get("id", "")

	# --- Native translation (board, actors): these map cleanly today ---
	var board = sections.get("board", {})
	runtime["inner_size"] = Vector2i(board.get("inner_size", [28, 18])[0], board.get("inner_size", [28, 18])[1])
	runtime["buffer"] = int(board.get("buffer", 1))
	runtime["floor_tile"] = String(board.get("floor_tile", "floor_SE"))

	var actors = sections.get("actors", {})
	var agent_start = actors.get("agent_start", [1, 1])
	runtime["agent_start"] = Vector2i(int(agent_start[0]), int(agent_start[1]))

	# guards -> patrols: actors.guards[i] is an Array (each route is array of waypoints).
	# When loaded from JSON, waypoints are [x, y] arrays. MapCompiler._build_enemy_defs()
	# does Vector2i(raw) where raw is expected to be [x, y] or Vector2i.
	# Convert to ensure proper format.
	var guards = actors.get("guards", [])
	runtime["patrols"] = _convert_from_json_compatible(guards)

	# --- Bridge translation (legacy_compiler): everything MapCompiler needs that the
	# native sections can't express yet (rooms, dividers, props-in-compiler-shape,
	# lights, light_tracks, access_points, wall_height). Merge shallow: bridge keys
	# win only if native didn't already set them (native sections take priority as
	# they land in future prompts). IMPORTANT: Convert arrays [x,y] back to Vector2i
	# since MapCompiler expects Vector2i objects (JSON coercion side effect). ---
	var bridge = sections.get("legacy_compiler", {})
	for key in bridge.keys():
		if not runtime.has(key):
			# Reconvert Vector2i arrays from JSON back to proper Vector2i objects
			runtime[key] = _convert_from_json_compatible(bridge[key])

	# --- Blocks section: now translatable (BLOCK-01 implementation) -----------
	var blocks_section = sections.get("blocks", {})
	if blocks_section.get("items", []).size() > 0:
		runtime["blocks"] = _convert_from_json_compatible(blocks_section["items"])

	# --- Floor zones section: floor-zone bake, same shape as blocks ----------
	var floor_zones_section = sections.get("floor_zones", {})
	if floor_zones_section.get("items", []).size() > 0:
		runtime["floor_zones"] = _convert_from_json_compatible(floor_zones_section["items"])

	# --- Props section: now translatable (PROP-01 implementation) -----------
	var props_section = sections.get("props", {})
	if props_section.get("items", []).size() > 0:
		var voxel_props: Array = []
		for item in props_section["items"]:
			voxel_props.append(item)  # already {def, gu, vox_offset, rot} shape post JSON-coercion-reversal
		runtime["voxel_props"] = _convert_from_json_compatible(voxel_props)

	# --- Loud, non-blocking warning for sections that exist but have no translator yet ---
	for future_section in ["walls"]:
		var frag = sections.get(future_section, {})
		var items_key = "edges"
		if frag.get(items_key, []).size() > 0:
			push_warning("[FileMapSource] Map '%s' has non-empty '%s' section with no MapCompiler translation yet — ignored" %
				[runtime["id"], future_section])

	return runtime

## Recursively convert [x,y] arrays back to Vector2i (inverse of JSON coercion)
func _convert_from_json_compatible(value) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		# Check if this is a [x, y] pair (array of 2 ints)
		if value.size() == 2 and typeof(value[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(value[1]) in [TYPE_INT, TYPE_FLOAT]:
			return Vector2i(int(value[0]), int(value[1]))
		else:
			# Recursively convert array elements
			var result: Array = []
			for item in value:
				result.append(_convert_from_json_compatible(item))
			return result
	elif typeof(value) == TYPE_DICTIONARY:
		# Recursively convert dictionary values
		var result: Dictionary = {}
		for key in value.keys():
			result[key] = _convert_from_json_compatible(value[key])
		return result
	else:
		# Primitive types return as-is
		return value
