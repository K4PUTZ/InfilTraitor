## PropRegistry — Prop definitions catalog (two-tier: res:// + user://)
## User-tier props override res:// props on id collision, same pattern as MaterialRegistry
## and TextureResolver.

class_name PropRegistry

const RES_PROPS_DIR := "res://props"
const USER_PROPS_DIR := "user://props"

var registry: Dictionary = {}  # id → PropDef (stored as Dict due to class_name limitations)


func _init() -> void:
	pass


## Register a prop definition
func register(prop_def) -> void:
	registry[prop_def.id] = prop_def
	print("[PropRegistry] Registered: %s (footprint: %s, storeys: %d, cover: %s)" % 
		[prop_def.id, prop_def.footprint_gus, prop_def.storeys, prop_def.gameplay.get("cover", "none")])


## Get a prop by ID; returns null if not found
func get_prop(p_id: String):
	return registry.get(p_id, null)


## List all prop IDs
func list_props() -> Array:
	return registry.keys()


## Get prop count
func count() -> int:
	return registry.size()


## Load props from both tiers (res:// then user://; user wins on collision)
func load_from_disk() -> void:
	_scan_dir(RES_PROPS_DIR)
	_scan_dir(USER_PROPS_DIR)


## Scan a directory and register all .json files as PropDef
func _scan_dir(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var file = FileAccess.open(dir_path.path_join(fname), FileAccess.READ)
			if file:
				var text = file.get_as_text()
				file.close()
				var parsed = JSON.parse_string(text)
				if typeof(parsed) == TYPE_DICTIONARY:
					var PropDefClass = load("res://godot/scripts/systems/prop_def.gd")
					var prop_def = PropDefClass.from_json(parsed)
					if not prop_def.id.is_empty():
						register(prop_def)
		fname = dir.get_next()

