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
## What IS state, and why each one:
##
##   · `base_damage`  — `Room._base_damage`, every damaged voxel in BASE space.
##     This is already the authoritative record (VL-PERSIST writes it on every
##     committed damage so a checkpoint restore can replay it), which makes it
##     the right thing to save and means no new bookkeeping had to be invented.
##   · `floor_shards` — G6: where broken glass came to rest, in BASE coords, with
##     its pile depth. Scenario state like the rest: it is what the level looks
##     like after a fight, and it dies with the checkpoint.
##   · `glass_remnants` — G4: the glass that stayed stuck to a frame, in BASE
##     coords. ⚠️ POSITION ONLY, and that is the whole design: the fragment's shape
##     is a hash of this key and its anchor is a READ of the live geometry, so
##     there is nothing view-space to save and nothing that a quarter turn can
##     make wrong.
##   · `glass_rim_shards` — CRACK-06: the same, but clinging to the pane's own
##     torn glass edge rather than a batten. A separate list for a separate anchor
##     rule, same POSITION-ONLY design.
##   · `soot` — `Room._soot_map` (SOOT-STAMP, 2026-09-22): every scorched cell's
##     tone, in BASE coords. Soot is stamped once by the event that makes it and is
##     no longer derivable from the damage, so it has to be saved like the rest.
##
## Both are plain nested arrays/ints by the time they get here, so the whole file
## is JSON and stays diffable and hand-editable — the same reasoning MAPFILE uses.

## Bumped when the shape below changes. A loader that meets a version it does not
## know FAILS LOUDLY (B6) rather than silently restoring a partial world.
const FORMAT_VERSION: int = 3
## v3 (R3D-8 step 4) adds `base_damage_claims`; v1 and v2 still restore, their cells replaying one record onto every claim.
## v1 (before SOOT-STAMP) still restores: its `crater_floor_soot` is ignored, so a v1
## save comes back without scorch rather than refusing to load.
const OLDEST_READABLE_VERSION: int = 1


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
	## R3D-8 step 4 — `[x, y, z, tag, ...payload]` per claim.
	var claim_damage: Array = []
	for key in room._base_damage_claims.keys():
		var by_tag: Dictionary = room._base_damage_claims[key]
		for tag in by_tag.keys():
			claim_damage.append([key.x, key.y, key.z, int(tag)] + (by_tag[tag] as Array))
	var soot: Array = []
	var shards: Array = []
	for key in room._base_shards.keys():
		shards.append([key.x, key.y, key.z, int(room._base_shards[key])])
	var remnants: Array = []
	for rk in room._base_remnants.keys():
		remnants.append([rk.x, rk.y, rk.z])
	var rim_shards: Array = []
	for sk in room._base_rim_shards.keys():
		rim_shards.append([sk.x, sk.y, sk.z])
	for level in room._soot_map.keys():
		var stored: Dictionary = room._soot_map[level]
		for cell in stored.keys():
			soot.append([int(level), cell.x, cell.y, int(stored[cell])])
	## R3D-PROPS — what a blast leaves of a prop that is not voxel state, in BASE coords: the Tier 4 props that shattered
	## (`[base_gu_x, base_gu_y]`) and every piece of ground debris (`[id, base_x, base_y, level, material, variant,
	## r, g, b, a, rot]`, the position in base VOXEL units, the tint already soot-darkened).
	var shattered_props: Array = []
	for pk in room._base_shattered_props.keys():
		shattered_props.append([pk.x, pk.y])
	var debris: Array = []
	for did in room._base_debris.keys():
		var d: Dictionary = room._base_debris[did]
		var bp: Vector2 = d["base"]
		var tint: Color = d["tint"]
		debris.append([String(did), bp.x, bp.y, int(d["level"]), String(d["material"]), int(d["variant"]),
			tint.r, tint.g, tint.b, tint.a, float(d["rot"])])
	## P2: the piles of charred fragments ([base_gu_x, base_gu_y, y0, [material per zone], [[col_x, col_y, level, mult, zone], ...], division]; the columns are in the fragment lattice, `division` per board voxel, 1 in an old save). Still-falling
	## fragments are run to their end first so their pile is in the record.
	if room.has_method("_finish_running_prop_fragments"):
		room._finish_running_prop_fragments()
	var prop_piles: Array = []
	for gk in room._base_prop_piles.keys():
		var pile: Dictionary = room._base_prop_piles[gk]
		var recs: Array = []
		for r: Dictionary in pile["records"]:
			var cc: Vector2i = r["col"]
			recs.append([cc.x, cc.y, int(r["level"]), float(r["mult"]), int(r.get("zone", 0))])
		prop_piles.append([gk.x, gk.y, float(pile["y0"]), pile["zone_materials"], recs, int(pile.get("div", 1))])
	return {
		"version": FORMAT_VERSION,
		## The map a save belongs to. A loader that restores damage into the WRONG
		## map would scatter holes at coordinates that mean nothing there, so the id
		## travels with the record even though nothing checks it yet.
		"map_id": room.map_id,
		"base_damage": damage,
		"base_damage_claims": claim_damage,
		"soot": soot,
		## R3D-PROPS — an OLD save has neither key and reads as "nothing shattered, no debris": the honest restore.
		"shattered_props": shattered_props,
		"prop_piles": prop_piles,
		"debris": debris,
		## G6 — `[base_x, base_y, level, count]` per pile. ⚠️ The COUNT travels, not
		## a flag: it is what decides how heavy the pile reads, and a save that
		## dropped it would restore every pile at a single shard's weight.
		"floor_shards": shards,
		## G4 — `[base_x, base_y, level]` per remnant. No fourth field on purpose:
		## see the class note. ⚠️ FORMAT_VERSION is NOT bumped, for the same reason
		## `pane_primed` did not bump it — an old save has no key, `get()` reads it
		## as "nothing is stuck to a frame", and that is both true and the safe
		## direction to be wrong in.
		"glass_remnants": remnants,
	## CRACK-06 — `[base_x, base_y, level]` per rim shard, same no-fourth-field,
	## no-version-bump rule as `glass_remnants`: an old save has no key and `get()`
	## reads it as "nothing clinging to a torn edge".
	"glass_rim_shards": rim_shards,
		## GLASS G-D15 / V-D — the panes a rifle round pierced without taking
		## (`Room._pane_primed`). A flat array of pane_ids: the value is always
		## `true`, so storing it would be storing a constant.
		##
		## ⚠️ FORMAT_VERSION is deliberately NOT bumped. `validate()` rejects a
		## version mismatch outright, and an OLD save simply has no `pane_primed`
		## key — `data.get("pane_primed", [])` reads it as "nothing was primed",
		## which is both true and the safe direction to be wrong in. A bump would
		## refuse every save written before today to gain nothing.
		"pane_primed": room._pane_primed.keys(),
	}


## Restore into a Room. Returns true on success; loud-fails and returns false
## otherwise, per B6 — a half-restored map is worse than a refused load.
##
## ⚠️ CALL ORDER. The caller must have BUILT the map already: this writes damage
## records and the soot map, and `Room.load_map()` clears both on its way in, so
## restoring before the build would have them thrown away underneath it.
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
	if version < OLDEST_READABLE_VERSION or version > FORMAT_VERSION:
		return "format version %d, expected %d..%d" % [version, OLDEST_READABLE_VERSION, FORMAT_VERSION]
	for e in data.get("base_damage", []):
		if typeof(e) != TYPE_ARRAY or (e as Array).size() < 4:
			return "malformed base_damage entry: %s" % [e]
	for c in data.get("base_damage_claims", []):
		if typeof(c) != TYPE_ARRAY or (c as Array).size() < 5:
			return "malformed base_damage_claims entry: %s" % [c]
	for c in data.get("soot", []):
		if typeof(c) != TYPE_ARRAY or (c as Array).size() < 4:
			return "malformed soot entry: %s" % [c]
	for pid in data.get("pane_primed", []):
		if typeof(pid) != TYPE_STRING or String(pid) == "":
			return "malformed pane_primed entry: %s" % [pid]
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
	room._base_damage_claims.clear()
	for c in data.get("base_damage_claims", []):
		var ckey := Vector3i(int(c[0]), int(c[1]), int(c[2]))
		if not room._base_damage_claims.has(ckey):
			room._base_damage_claims[ckey] = {}
		(room._base_damage_claims[ckey] as Dictionary)[int(c[3])] = (c as Array).slice(4)
	## G6 — an OLD save simply has no `floor_shards` key, and `get()` reads that as
	## "no glass on the floor", which is the honest restore rather than a refusal.
	room._base_shards.clear()
	for sh in data.get("floor_shards", []):
		room._base_shards[Vector3i(int(sh[0]), int(sh[1]), int(sh[2]))] = int(sh[3])
	## G4 — same "an old save simply has no key" rule as the piles above it.
	room._base_remnants.clear()
	for rm in data.get("glass_remnants", []):
		room._base_remnants[Vector3i(int(rm[0]), int(rm[1]), int(rm[2]))] = true
	## CRACK-06 — same rule as the remnants above.
	room._base_rim_shards.clear()
	for sh in data.get("glass_rim_shards", []):
		room._base_rim_shards[Vector3i(int(sh[0]), int(sh[1]), int(sh[2]))] = true
	room._soot_map.clear()
	for c in data.get("soot", []):
		var level: int = int(c[0])
		if not room._soot_map.has(level):
			room._soot_map[level] = {}
		room._soot_map[level][Vector2i(int(c[1]), int(c[2]))] = int(c[3])
	room._pane_primed.clear()
	for pid in data.get("pane_primed", []):
		room._pane_primed[String(pid)] = true
	room._base_shattered_props.clear()
	for sp in data.get("shattered_props", []):
		room._base_shattered_props[Vector2i(int(sp[0]), int(sp[1]))] = true
	room._base_prop_piles.clear()
	for pp in data.get("prop_piles", []):
		var pile_records: Array = []
		for rr in pp[4]:
			pile_records.append({"col": Vector2i(int(rr[0]), int(rr[1])), "level": int(rr[2]), "mult": float(rr[3]), "zone": int(rr[4])})
		var zone_materials: Array = []
		for zm in pp[3]:
			zone_materials.append(String(zm))
		room._base_prop_piles[Vector2i(int(pp[0]), int(pp[1]))] = {"y0": float(pp[2]), "zone_materials": zone_materials,
			"records": pile_records, "div": int(pp[5]) if pp.size() > 5 else 1}
	room._base_debris.clear()
	for dd in data.get("debris", []):
		room._base_debris[String(dd[0])] = {"base": Vector2(float(dd[1]), float(dd[2])), "level": int(dd[3]),
			"material": String(dd[4]), "variant": int(dd[5]),
			"tint": Color(float(dd[6]), float(dd[7]), float(dd[8]), float(dd[9])), "rot": float(dd[10])}
	## The cache is NOT restored — it is rebuilt. See the class note.
	room.project_soot_store()
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
	room._base_damage_claims.clear()
	## G-D15 / V-D — a primed pane is a promise made to THIS run. A fresh mission
	## must not inherit a window that shatters to the first pistol shot.
	room._pane_primed.clear()
	## The soot map. This function's whole reason for being is *"so a new persisted
	## field has exactly one place to be forgotten from"*, and the Director's save
	## model makes the omission the dangerous half: scenario state dies with the
	## level (*"acabou a fase, acabou o save"*), so a map left behind reappears as
	## the previous level's crater — silently, and only on the second level anyone
	## plays.
	room._soot_map.clear()
	## R3D-PROPS — a fresh mission must not inherit last level's shattered tables or the debris on its floor.
	room._base_shattered_props.clear()
	room._base_debris.clear()
	room._base_prop_piles.clear()
