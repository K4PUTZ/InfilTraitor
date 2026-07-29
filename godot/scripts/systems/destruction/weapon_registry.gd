## WeaponRegistry — Weapon definitions catalog (two-tier: res:// + user://).
## WEAPON_MASTER_PLAN Part 1 (D7). Line-for-line the BombRegistry pattern
## (which is itself line-for-line PropRegistry): user-tier weapons override
## res:// weapons on id collision, and a new weapons/*.json needs ZERO code
## changes to appear.
class_name WeaponRegistry

const RES_WEAPONS_DIR := "res://weapons"
const USER_WEAPONS_DIR := "user://weapons"

var registry: Dictionary = {}  # id → WeaponDef


## Register a weapon definition
func register(weapon_def) -> void:
	registry[weapon_def.id] = weapon_def
	print("[WeaponRegistry] Registered: %s (%s, %d steps)" %
		[weapon_def.id, weapon_def.delivery, weapon_def.step_multipliers.size()])


## Get a weapon by ID; returns null if not found
func get_weapon(p_id: String):
	return registry.get(p_id, null)


## Get weapon count
func count() -> int:
	return registry.size()


## Load weapons from both tiers (res:// then user://; user wins on collision)
func load_from_disk() -> void:
	_scan_dir(RES_WEAPONS_DIR)
	_scan_dir(USER_WEAPONS_DIR)


## Scan a directory and register all .json files as WeaponDef
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
					var WeaponDefClass = load("res://godot/scripts/systems/destruction/weapon_def.gd")
					var weapon_def = WeaponDefClass.from_json(parsed)
					if not weapon_def.id.is_empty():
						register(weapon_def)
		fname = dir.get_next()
