## BombRegistry — Bomb definitions catalog (two-tier: res:// + user://).
## Line-for-line the PropRegistry pattern (godot/scripts/systems/prop_registry.gd):
## user-tier bombs override res:// bombs on id collision.
class_name BombRegistry

const RES_BOMBS_DIR := "res://bombs"
const USER_BOMBS_DIR := "user://bombs"

var registry: Dictionary = {}  # id → BombDef


## Register a bomb definition
func register(bomb_def) -> void:
	_apply_ring_cap(bomb_def)
	registry[bomb_def.id] = bomb_def
	print("[BombRegistry] Registered: %s (rings: %d)" %
		[bomb_def.id, bomb_def.ring_multipliers.size()])


## Get a bomb by ID; returns null if not found
func get_bomb(p_id: String):
	return registry.get(p_id, null)


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


## DIAG-19 (DEVICE_DIAGNOSTICS §15.2) — `BLAST_MAX_RING=<n>`, an instrument: every
## per-ring table of the bomb is cut to rings 0..n, so a detonation touches fewer
## voxels with the same falloff shape. The flag is read through the DevFlags NODE,
## not the global name, so a `--script` tool that loads this registry without
## autoloads still parses and simply gets no cap.
func _apply_ring_cap(bomb_def) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var flags: Node = tree.root.get_node_or_null("DevFlags") if tree != null else null
	if flags == null:
		return
	var cap: int = flags.num("BLAST_MAX_RING", -1)
	if cap < 0:
		return
	var keep: int = cap + 1
	for field: String in ["ring_multipliers", "destroy_ring_weights", "dent_ring_weights",
			"crack_ring_weights", "soot_ring_tones", "smoke_ring_weights"]:
		var rings: Array = bomb_def.get(field)
		if rings.size() > keep:
			rings.resize(keep)
	print("[BombRegistry] BLAST_MAX_RING=%d — %s cut to %d ring(s)" % [cap, bomb_def.id, keep])
