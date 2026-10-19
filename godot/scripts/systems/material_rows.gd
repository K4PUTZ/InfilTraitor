## MaterialRows — reads the material rows (`<tier>/<id>/<id>.json`) and resolves SECONDARY materials, for every reader of a row.
##
## A SECONDARY material (Director, 2026-10-18: "materiais primarios -> objetos secundarios herdam os mesmos stats, mas tem uma textura particular") is a
## row that names its primary with `"inherits": "<id>"`: it takes every column of the primary it does not set itself (the balance numbers, the
## family, the tags, the colour, the surfaces), and keeps its OWN texture (`has_facade`, `facade_from`, `facade_mean`, `pattern_algorithm` are never
## inherited: the art is what makes it a separate row). An iron grating is `steel_dark` for a grenade, a shot, fire and support, and wears iron.
## The chain may be several deep; a missing primary or a cycle is loud (the row is still loaded, with what it set itself).
##
## Both readers of a row go through here (`MaterialRegistry`, `MaterialResistanceTable`), so a secondary is the same material to the renderer
## and to destruction. Pure static functions over plain Dictionaries: no autoload, safe in selftests.
class_name MaterialRows
extends RefCounted

const JsonFileRef = preload("res://godot/scripts/systems/json_file.gd")

## Columns that belong to the TEXTURE of a row, never taken from its primary.
const OWN_ONLY: PackedStringArray = ["id", "inherits", "has_facade", "facade_from", "facade_mean", "pattern_algorithm"]
const MAX_DEPTH: int = 8


## The raw rows of one tier, id -> Dictionary (the folder walk is one level and name-matched: `concrete/concrete.json`). A row that exists must read.
static func read_tier(dir_path: String, owner: String, errors: Array) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var row_path := dir_path.path_join(entry).path_join(entry + ".json")
			if FileAccess.file_exists(row_path):
				var parsed: Dictionary = JsonFileRef.read_object(row_path, owner, errors)
				if not parsed.is_empty():
					var id: String = JsonFileRef.require_id(parsed, row_path, owner, errors)
					if not id.is_empty():
						out[id] = parsed
		entry = dir.get_next()
	return out


## Every row of both tiers (user wins on an id collision), each secondary merged over its primary.
static func load_all(res_dir: String, user_dir: String, owner: String, errors: Array) -> Dictionary:
	var raw: Dictionary = read_tier(res_dir, owner, errors)
	raw.merge(read_tier(user_dir, owner, errors), true)
	return resolve(raw, owner, errors)


## `raw` with every `inherits` resolved. Pure: the input is not modified.
static func resolve(raw: Dictionary, owner: String, errors: Array) -> Dictionary:
	var out: Dictionary = {}
	for id: String in raw:
		out[id] = _merged(id, raw, owner, errors)
	return out


static func _merged(id: String, raw: Dictionary, owner: String, errors: Array) -> Dictionary:
	var row: Dictionary = (raw[id] as Dictionary).duplicate(true)
	var seen: Dictionary = {id: true}
	var parent_id: String = String(row.get("inherits", ""))
	var primary: String = id
	var depth: int = 0
	while not parent_id.is_empty():
		if seen.has(parent_id) or depth >= MAX_DEPTH:
			_fail(errors, "[%s] material '%s': `inherits` loops through '%s'; the row keeps only what it sets itself" % [owner, id, parent_id])
			break
		if not raw.has(parent_id):
			_fail(errors, "[%s] material '%s' inherits '%s', which is not a registered material; the row keeps only what it sets itself" % [owner, id, parent_id])
			break
		seen[parent_id] = true
		primary = parent_id
		var parent: Dictionary = raw[parent_id]
		for key: String in parent:
			if not row.has(key) and not OWN_ONLY.has(key):
				row[key] = parent[key]
		parent_id = String(parent.get("inherits", ""))
		depth += 1
	row["primary"] = primary
	return row


static func _fail(errors: Array, message: String) -> void:
	push_error(message)
	errors.append(message)

## Give every secondary the entry of its primary in `table` (a Dictionary keyed by material id, or an Array[String] of ids). An entry a secondary
## already has is its own and is kept. Returns the entries added.
static func alias_secondaries(table) -> int:
	var added: int = 0
	var primaries: Dictionary = primary_map()
	for sid: String in primaries:
		var primary: String = primaries[sid]
		if primary == sid:
			continue
		if table is Dictionary:
			if not (table as Dictionary).has(sid) and (table as Dictionary).has(primary):
				table[sid] = table[primary]
				added += 1
		elif table is Array:
			if (table as Array).has(primary) and not (table as Array).has(sid):
				(table as Array).append(sid)
				added += 1
	return added


static var _primary_cache: Dictionary = {}
static var _primary_loaded: bool = false


## id -> primary for every row of both tiers (a primary maps to itself). Read once, quietly: the registries already reported a bad row.
static func primary_map() -> Dictionary:
	if _primary_loaded:
		return _primary_cache
	_primary_loaded = true
	var quiet: Array = []
	var raw: Dictionary = read_tier("res://ASSETS/materials", "MaterialRows", quiet)
	raw.merge(read_tier("user://materials", "MaterialRows", quiet), true)
	for id: String in raw:
		var primary: String = id
		var seen: Dictionary = {id: true}
		var next: String = String((raw[id] as Dictionary).get("inherits", ""))
		while not next.is_empty() and raw.has(next) and not seen.has(next):
			seen[next] = true
			primary = next
			next = String((raw[next] as Dictionary).get("inherits", ""))
		_primary_cache[id] = primary
	return _primary_cache


## The primary of a material id (itself for a primary or an unknown id). For a behaviour asked by name (`== "metal"`), never for its texture.
static func primary_of(id: String) -> String:
	return String(primary_map().get(id, id))
