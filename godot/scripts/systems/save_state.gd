extends RefCounted
class_name SaveState

## SAVE-01 — the persistence seam for what a mission does to the map.
##
## Director, 2026-08-26: *"Precisamos atrelar isso ao save game (acho que já temos
## alguma coisa, senão já era bom deixar o encanamento preparado)."* There was
## nothing — no save system of any kind existed in this project. This is the
## plumbing, not the feature: it serialises and restores the state a reload has to
## bring back, and nothing else. No slots, no UI, no autosave policy; those are
## the Director's calls and are not guessed at here.
##
## ⚠️ **WHAT IS STATE AND WHAT IS A CACHE — and the incremental soot map is a
## CACHE.** §13.2's index (`Room._soot_index_cache`) looks like the obvious thing
## to persist and must never be: it is a derived answer keyed by live `Voxel`
## object references, so a saved copy would deserialise into pointers at objects
## that no longer exist. It is rebuilt from the board on the first snapshot after
## a load, which is exactly what `Room.invalidate_soot_index()` arranges. Saving a
## cache is how a save file starts disagreeing with the world it describes.
##
## What IS state, and why each one:
##
##   · `base_damage`  — `Room._base_damage`, every damaged voxel in BASE space.
##     This is already the authoritative record (VL-PERSIST writes it on every
##     committed damage so a perspective rotation can replay it), which makes it
##     the right thing to save and means no new bookkeeping had to be invented.
##   · `crater_floor_soot` — scorch on revealed crater-floor cells, which hang on
##     no Voxel and so cannot be re-derived from the board.
##
## Both are plain nested arrays/ints by the time they get here, so the whole file
## is JSON and stays diffable and hand-editable — the same reasoning MAPFILE uses.

## Bumped when the shape below changes. A loader that meets a version it does not
## know FAILS LOUDLY (B6) rather than silently restoring a partial world.
const FORMAT_VERSION: int = 1


## Room -> a plain Dictionary ready for JSON.
##
## `_base_damage` is keyed by Vector3i and JSON has no such thing, so each entry
## becomes `[x, y, z, ...payload]`. Flat arrays rather than objects because the
## payload is already a positional array in `record_voxel_damage_to_base()` and
## re-labelling it here would create a second schema to keep in step.
static func capture(room) -> Dictionary:
	var damage: Array = []
	for key in room._base_damage.keys():
		var payload: Array = room._base_damage[key]
		damage.append([key.x, key.y, key.z] + payload)
	var craters: Array = []
	for level in room._crater_floor_soot.keys():
		for cell in room._crater_floor_soot[level].keys():
			craters.append([int(level), cell.x, cell.y,
				int(room._crater_floor_soot[level][cell])])
	return {
		"version": FORMAT_VERSION,
		## The map a save belongs to. A loader that restores damage into the WRONG
		## map would scatter holes at coordinates that mean nothing there, so the id
		## travels with the record even though nothing checks it yet.
		"map_id": room.map_id,
		"base_damage": damage,
		"crater_floor_soot": craters,
	}


## Restore into a Room. Returns true on success; loud-fails and returns false
## otherwise, per B6 — a half-restored map is worse than a refused load.
##
## ⚠️ CALL ORDER. The caller must have BUILT the map already: this writes damage
## records, and `Room.load_map()` invalidates the soot index on its way in, so
## restoring before the build would have the index thrown away underneath it.
## ⚠️ VALIDATION IS SEPARATE FROM REPORTING, and a selftest is the reason.
##
## `restore()` must loud-fail on a bad file (B6). But `run_selftests.py` treats any
## `push_error` in the log as a failure — correctly, that is the whole point of it
## being the arbiter — so a test that exercises the refusal path would report the
## suite as broken while proving it works. Splitting the CHECK out makes the
## refusals testable without emitting anything, and leaves `restore()` as loud as
## the rule requires.
##
## Returns "" when the data is loadable, otherwise the reason.
static func validate(data: Dictionary) -> String:
	var version: int = int(data.get("version", -1))
	if version != FORMAT_VERSION:
		return "format version %d, expected %d" % [version, FORMAT_VERSION]
	for e in data.get("base_damage", []):
		if typeof(e) != TYPE_ARRAY or (e as Array).size() < 4:
			return "malformed base_damage entry: %s" % [e]
	for c in data.get("crater_floor_soot", []):
		if typeof(c) != TYPE_ARRAY or (c as Array).size() < 4:
			return "malformed crater_floor_soot entry: %s" % [c]
	return ""


static func restore(room, data: Dictionary) -> bool:
	var problem: String = validate(data)
	if problem != "":
		push_error("[SaveState] refusing to restore: %s" % problem)
		return false
	## Cleared only AFTER validation passes: a refused load must leave the world
	## it was going to replace exactly as it found it.
	room._base_damage.clear()
	for e in data.get("base_damage", []):
		room._base_damage[Vector3i(int(e[0]), int(e[1]), int(e[2]))] = \
			(e as Array).slice(3)
	room._crater_floor_soot.clear()
	for c in data.get("crater_floor_soot", []):
		var level: int = int(c[0])
		if not room._crater_floor_soot.has(level):
			room._crater_floor_soot[level] = {}
		room._crater_floor_soot[level][Vector2i(int(c[1]), int(c[2]))] = int(c[3])
	## The cache is NOT restored — it is rebuilt. See the class note.
	room.invalidate_soot_index("save restored")
	return true


## Convenience: the whole thing to disk and back. `user://` rather than `res://`
## because a shipped build cannot write into its own package.
static func save_to_file(room, path: String = "user://save_01.json") -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveState] cannot open %s for writing: %d"
			% [path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(capture(room), "\t"))
	f.close()
	return true


static func load_from_file(room, path: String = "user://save_01.json") -> bool:
	if not FileAccess.file_exists(path):
		push_error("[SaveState] no save at %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[SaveState] cannot open %s for reading: %d"
			% [path, FileAccess.get_open_error()])
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveState] %s is not a JSON object" % path)
		return false
	return restore(room, parsed)


## SAVE-01 — the clear half of the Director's *"lembrar de limpar em caso de
## reset, morte, etc"*. Everything a fresh mission must not inherit, in one place
## so a new persisted field has exactly one place to be forgotten from.
static func clear_run_state(room) -> void:
	room._base_damage.clear()
	room._crater_floor_soot.clear()
	## SS-1 (`SOOT_STORAGE_REFORM`) — the scorch store is registered for forgetting
	## the moment it exists, not when it is first SAVED (that is SS-4). This
	## function's whole reason for being is *"so a new persisted field has exactly
	## one place to be forgotten from"*, and the Director's save model makes the
	## omission the dangerous half: scenario state dies with the level (*"acabou a
	## fase, acabou o save"*), so a store left behind reappears as the previous
	## level's crater — silently, and only on the second level anyone plays.
	room._soot_map.clear()
	room.invalidate_soot_index("run state cleared")
