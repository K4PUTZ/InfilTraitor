## JsonFile — the one way a catalogue reads a JSON row from disk, loudly (B6).
##
## AUDIT 2026-10-07: the five catalogues (`MaterialRegistry`, `MaterialResistanceTable`, `PropRegistry` props and slots,
## `BombRegistry`, `WeaponRegistry`) dropped a row that did not parse or had no `id` without saying which file: Godot's own
## `Parse JSON failed. Error at line 0` names no path, and an id-less row said nothing at all. A typo in `bombs/frag_grenade.json`
## made the grenade vanish; a broken material row fell to the generic look, silently wrong. Every failure here is `push_error`'d WITH
## the path and appended to the caller's `errors`, so a selftest (`registry_load_errors_selftest`) and a future mod validator can read it.
##
## The same goes for the vector fields a row carries: `[1.0]` where three numbers are expected used to abort `from_json()` half-way
## with a SCRIPT ERROR (the rest of the row unread); `vector3()` / `vector2i()` fall back to the default and say so.
class_name JsonFile


## The JSON object in `path`, or `{}` after a loud error. `owner` names the catalogue in the message ("BombRegistry").
static func read_object(path: String, owner: String, errors: Array) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail(errors, "[%s] cannot open %s (error %d): the row is skipped" % [owner, path, FileAccess.get_open_error()])
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail(errors, "[%s] %s is not valid JSON (line %d: %s): the row is skipped"
			% [owner, path, json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail(errors, "[%s] %s is not a JSON object: the row is skipped" % [owner, path])
	return json.data


## The row's `id`, or "" after a loud error: a row with no id cannot be registered and must not vanish quietly.
static func require_id(row: Dictionary, path: String, owner: String, errors: Array) -> String:
	var id := String(row.get("id", ""))
	if id.is_empty():
		_fail(errors, "[%s] %s has no \"id\": the row is skipped" % [owner, path])
	return id


## `value` as a Vector3 when it is an array of at least three numbers, else `fallback` and a loud error naming `what`.
static func vector3(value: Variant, fallback: Vector3, what: String, errors: Array) -> Vector3:
	if value is Array and (value as Array).size() >= 3 and _all_numbers(value as Array, 3):
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	_fail(errors, "[JsonFile] %s must be [x, y, z] numbers, got %s: using %s" % [what, str(value), fallback])
	return fallback


## `value` as a Vector2i when it is an array of at least two numbers, else `fallback` and a loud error naming `what`.
static func vector2i(value: Variant, fallback: Vector2i, what: String, errors: Array) -> Vector2i:
	if value is Array and (value as Array).size() >= 2 and _all_numbers(value as Array, 2):
		return Vector2i(int(value[0]), int(value[1]))
	_fail(errors, "[JsonFile] %s must be [x, y] numbers, got %s: using %s" % [what, str(value), fallback])
	return fallback


static func _all_numbers(values: Array, count: int) -> bool:
	for i in range(count):
		if typeof(values[i]) != TYPE_FLOAT and typeof(values[i]) != TYPE_INT:
			return false
	return true


static func _fail(errors: Array, message: String) -> Dictionary:
	push_error(message)
	errors.append(message)
	return {}
