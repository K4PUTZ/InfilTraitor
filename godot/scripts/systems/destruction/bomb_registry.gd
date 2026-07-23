## BombRegistry — Bomb definitions catalog (two-tier: res:// + user://).
## Line-for-line the PropRegistry pattern (godot/scripts/systems/prop_registry.gd):
## user-tier bombs override res:// bombs on id collision.
class_name BombRegistry

const RES_BOMBS_DIR := "res://bombs"
const USER_BOMBS_DIR := "user://bombs"

var registry: Dictionary = {}  # id → BombDef


## Register a bomb definition
func register(bomb_def) -> void:
	registry[bomb_def.id] = bomb_def
	print("[BombRegistry] Registered: %s (rings: %d)" %
		[bomb_def.id, bomb_def.ring_multipliers.size()])


## Get a bomb by ID; returns null if not found
func get_bomb(p_id: String):
	return registry.get(p_id, null)


## List all bomb IDs
func list_bombs() -> Array:
	return registry.keys()


## Get bomb count
func count() -> int:
	return registry.size()


## Load bombs from both tiers (res:// then user://; user wins on collision)
func load_from_disk() -> void:
	_scan_dir(RES_BOMBS_DIR)
	_scan_dir(USER_BOMBS_DIR)


## Scan a directory and register all .json files as BombDef
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
					var BombDefClass = load("res://godot/scripts/systems/destruction/bomb_def.gd")
					var bomb_def = BombDefClass.from_json(parsed)
					if not bomb_def.id.is_empty():
						register(bomb_def)
		fname = dir.get_next()
