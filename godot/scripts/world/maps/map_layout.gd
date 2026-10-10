## MapLayout — a map's spatial anchors (CAPTURE_RAILS_MASTER_PLAN §3-§4): the `layout` section's points of interest, regions and
## objectives, plus everything DERIVED from the rest of the map (bounds, the buffer ring, the compass, the agent's start, the exits,
## the safe zone) — one object that answers "where is X" for the camera, the overlay, a take and the future scenario editor.
##
## COORDINATES. The file speaks INNER GU (rule 7); `MapCompiler` shifts every point and box by the buffer into the compiled
## `layout` (RAW GU), which is what this object holds. A point is `Vector3(x, y, z)`: `x`, `y` in GU on the 1/8 lattice (cell `i`
## spans `[i, i+1)`), `z` in STOREYS above the playable ground (relative, never an absolute level: rule 9). `to_world()` is the only
## conversion to the 3D board (one GU = one world unit, raw x -> world x, raw y -> world z, a storey = one world y unit x
## `Board3DLive.VERTICAL_SCALE`); `to_section()` goes back to the file through `MapCompiler.raw_to_inner()`, the only inverse.
##
## ONE AUTHORITY EACH. The agent's start stays in `actors`, the access points in `legacy_compiler` / `LevelGraph` (read here through
## the compiled `exit_cells`; the key `layout.exits` is RESERVED until they move, CR-7), the bounds in `board`.
##
## LIFECYCLE. Built by `Room.load_map()` from the compiled layout and REPLACED on every load (F2 included); nothing in it changes
## with a rotation (base coordinates); nothing of it is saved in a checkpoint (static map data — an objective's progress, when the
## mission system exists, is state keyed by the objective's `id`).
class_name MapLayout
extends RefCounted

const MapCompilerRef = preload("res://godot/scripts/world/maps/map_compiler.gd")
const MapCompassRef = preload("res://godot/scripts/world/maps/map_compass.gd")
const MapEnvelopeRef = preload("res://godot/scripts/world/maps/map_envelope.gd")

## One storey in world y units: `Board3DLive.VERTICAL_SCALE`, fed by `Room` when the board starts (this file must stay loadable by
## headless tools, which cannot parse the board's script). 1.0 is the board's own default.
static var vertical_scale: float = 1.0

const SECTION_KEYS: Array[String] = ["v", "envelope", "poi", "regions", "objectives"]
const RESERVED_KEYS: Array[String] = ["exits"]
## DESIGN_MASTER_PLAN §14.2's objective list. Data only: no gameplay reads it until the mission system exists (rule 6: no text here).
const OBJECTIVE_KINDS: Array[String] = ["reach_terminal", "neutralise", "undetected", "recover_item", "escort", "sabotage", "survive"]
## Names an `id` may not take: they resolve to derived or LIVE anchors.
const RESERVED_NAMES: Array[String] = ["map", "map_ring", "agent_start", "agent",
	"corner_n", "corner_e", "corner_s", "corner_w", "side_nw", "side_ne", "side_se", "side_sw"]
const SAFE_ZONE_DEPTH: int = 2   ## DESIGN §14.1: a 2-tile safe zone on the entry edge
## How high `@map` reaches when the map declares nothing taller: one playable storey.
const MIN_STOREYS: float = 1.0

var playable_rect: Rect2i = Rect2i()   ## raw GU
var buffer: int = 0
var map_size: Vector2i = Vector2i.ZERO   ## raw GU, ring included
var tallest_storeys: float = MIN_STOREYS
var agent_start_cell: Vector2i = Vector2i.ZERO   ## raw GU
var exit_cells: Array[Vector2i] = []   ## raw GU
var envelope: Dictionary = {}   ## the map's override of the envelope file (inner, as authored)
## id -> {id, at: Vector3 (raw), tags}
var poi: Dictionary = {}
## id -> {id, min: Vector3, max: Vector3 (raw), tags}
var regions: Dictionary = {}
## id -> {id, kind, at: Vector3 (raw) | region: String, tags}
var objectives: Dictionary = {}
## CAPTURE_RAILS CR-3 — the `capture` section (dev only): id -> rail `{id, keys: Array}`, id -> take `{id, profile, rail, steps, at_key,
## after_hold, length, seed}`. A rail key's explicit `centre` is raw GU (shifted by MapCompiler).
var rails: Dictionary = {}
var takes: Dictionary = {}
## Insertion order per kind, so `to_section()` writes the file back in the order it was read (a stable diff for the editor).
var _order: Dictionary = {"poi": [], "regions": [], "objectives": []}


# ---------------------------------------------------------------------------------------------------------------------------------
# Building

## From `MapCompiler.compile()`'s result (raw GU throughout). `MapLayoutClass.new().load_compiled(compiled)`: an instance method,
## because a NEW class_name is invisible to headless runs until the editor rebuilds its cache (consumers preload this file).
func load_compiled(compiled: Dictionary) -> RefCounted:
	var ml = self
	ml.playable_rect = compiled.get("playable_rect", Rect2i())
	ml.buffer = int(compiled.get("buffer", 0))
	ml.map_size = compiled.get("size", Vector2i.ZERO)
	ml.agent_start_cell = compiled.get("agent_start_cell", Vector2i.ZERO)
	for c in compiled.get("exit_cells", []):
		ml.exit_cells.append(Vector2i(c))
	var raw: Dictionary = compiled.get("layout", {})
	ml.tallest_storeys = maxf(MIN_STOREYS, float(raw.get("tallest_storeys", MIN_STOREYS)))
	ml.envelope = (raw.get("envelope", {}) as Dictionary).duplicate(true)
	for p: Dictionary in raw.get("poi", []):
		ml._put("poi", p.duplicate(true))
	for r: Dictionary in raw.get("regions", []):
		ml._put("regions", r.duplicate(true))
	for o: Dictionary in raw.get("objectives", []):
		ml._put("objectives", o.duplicate(true))
	var cap: Dictionary = compiled.get("capture", {})
	for r: Dictionary in cap.get("rails", []):
		ml.rails[str(r["id"])] = r.duplicate(true)
	for t: Dictionary in cap.get("takes", []):
		ml.takes[str(t["id"])] = t.duplicate(true)
	return ml


# ---------------------------------------------------------------------------------------------------------------------------------
# Capture: rails and takes, authored or DEFAULT (§7.5: any map has framed captures with no authored data)

const DEFAULT_HOLD: int = 60
const DEFAULT_MOVE: int = 45


## A rail by id; `overview`, `region:<id>` and `poi:<id>` exist on every map (built on the fly, never stored). {} when unknown.
func rail(id: String) -> Dictionary:
	if rails.has(id):
		return rails[id]
	if id == "overview":
		var keys: Array = []
		for v: String in ["N", "E", "S", "W"]:
			keys.append({"frame": "wide", "target": "@map", "view": v, "move": 0 if keys.is_empty() else DEFAULT_MOVE * 2,
				"hold": DEFAULT_HOLD})
		return {"id": id, "keys": keys}
	if id.begins_with("region:") and regions.has(id.trim_prefix("region:")):
		var rid: String = id.trim_prefix("region:")
		var keys2: Array = [{"frame": "wide", "target": "@" + rid, "hold": DEFAULT_HOLD}]
		var box: AABB = resolve(rid)["box"]
		for pid in _order["poi"]:
			var at: Vector3 = poi[pid]["at"]
			if ("detail" in (poi[pid].get("tags", []) as Array)) and box.grow(0.01).has_point(Vector3(at.x, at.z, at.y)):
				keys2.append({"frame": "detail", "target": "@" + str(pid), "move": DEFAULT_MOVE, "hold": DEFAULT_HOLD})
		return {"id": id, "keys": keys2}
	if id.begins_with("poi:") and poi.has(id.trim_prefix("poi:")):
		return {"id": id, "keys": [{"frame": "detail", "target": "@" + id.trim_prefix("poi:"), "hold": DEFAULT_HOLD}]}
	return {}


## A take by id; a rail id that resolves (authored or default) is also a take with no event, the length of its keys.
func take(id: String) -> Dictionary:
	if takes.has(id):
		return takes[id]
	var r: Dictionary = rail(id)
	if r.is_empty():
		return {}
	var length: int = 0
	for k: Dictionary in r["keys"]:
		length += int(k.get("move", 0)) + int(k.get("hold", 0))
	return {"id": id, "profile": "engine", "rail": id, "steps": [], "at_key": 0, "after_hold": 0, "length": length + 2, "seed": 1}


func _put(kind: String, entry: Dictionary) -> void:
	var table: Dictionary = _table(kind)
	var id: String = str(entry["id"])
	if not table.has(id):
		(_order[kind] as Array).append(id)
	table[id] = entry


func _table(kind: String) -> Dictionary:
	match kind:
		"poi":
			return poi
		"regions":
			return regions
	return objectives


# ---------------------------------------------------------------------------------------------------------------------------------
# Derived anchors

func bounds_box() -> AABB:
	return AABB(Vector3(playable_rect.position.x, 0.0, playable_rect.position.y),
		Vector3(playable_rect.size.x, tallest_storeys, playable_rect.size.y))


func bounds_ring_box() -> AABB:
	return AABB(Vector3.ZERO, Vector3(map_size.x, tallest_storeys, map_size.y))


## Every access cell with the side it opens through. `role` is "unknown" until the access points move here (CR-7): the legacy field
## has no main / secondary / secret.
func exits() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Vector2i in exit_cells:
		out.append({"cell": c, "side": MapCompassRef.side_facing(c, playable_rect), "role": "unknown"})
	return out


## DESIGN §14.1's encounter-free band along the entry side, in raw GU (a box one storey high).
func safe_zone(entry_side: String) -> AABB:
	var band: Rect2i = MapCompassRef.band(entry_side, playable_rect, SAFE_ZONE_DEPTH)
	return AABB(Vector3(band.position.x, 0.0, band.position.y), Vector3(band.size.x, 1.0, band.size.y))


# ---------------------------------------------------------------------------------------------------------------------------------
# Resolution: any reference -> a box in raw GU space (x, y on the plan, z in storeys)

## `ref` is an id or a reserved name, with or without a leading `@`. LIVE names (`agent`, `guard_<i>`) need the Room. Returns
## `{ok, box: AABB (raw GU: x, z-storeys as the AABB's y, y as the AABB's z), point: Vector3 (raw GU, x/y/z), kind, error}`.
## The AABB uses the WORLD axis order (x, height, y) so `to_world_box()` is a scale, never a swizzle the caller can get wrong.
func resolve(ref: String, room: Object = null) -> Dictionary:
	var name: String = ref.trim_prefix("@")
	if poi.has(name):
		var at: Vector3 = poi[name]["at"]
		if poi[name].has("extent"):
			var ext: Vector3 = poi[name]["extent"]
			var half := Vector3(ext.x, ext.y, ext.z) * 0.5
			var r0: Dictionary = _box_result(at - half, at + half, "poi")
			r0["point"] = at
			return r0
		return _point_result(at, "poi")
	if regions.has(name):
		var r: Dictionary = regions[name]
		return _box_result(r["min"], r["max"], "region")
	if objectives.has(name):
		var o: Dictionary = objectives[name]
		if o.has("region"):
			var inner: Dictionary = resolve(str(o["region"]), room)
			inner["kind"] = "objective"
			return inner
		return _point_result(o["at"], "objective")
	match name:
		"map":
			return _aabb_result(bounds_box(), "map")
		"map_ring":
			return _aabb_result(bounds_ring_box(), "map_ring")
		"agent_start":
			return _point_result(Vector3(agent_start_cell.x + 0.5, agent_start_cell.y + 0.5, 0.0), "agent_start")
		"agent":
			if room == null or room.get("agent") == null:
				return _fail("@agent is LIVE and needs the Room")
			var ac: Vector2i = room.get("agent").cell
			return _point_result(Vector3(ac.x + 0.5, ac.y + 0.5, 0.0), "agent")
	if name.begins_with("corner_"):
		var c: Vector2 = MapCompassRef.corner(name.trim_prefix("corner_").to_upper(), playable_rect)
		return _point_result(Vector3(c.x, c.y, 0.0), "corner")
	if name.begins_with("side_"):
		var side: String = name.trim_prefix("side_").to_upper()
		var band: Rect2i = MapCompassRef.band(side, playable_rect, 1)
		if band.size == Vector2i.ZERO:
			return _fail("unknown side in '%s'" % ref)
		return _box_result(Vector3(band.position.x, band.position.y, 0.0), Vector3(band.end.x, band.end.y, tallest_storeys), "side")
	if name.begins_with("guard_") and name.trim_prefix("guard_").is_valid_int():
		var i: int = name.trim_prefix("guard_").to_int()
		if room == null or not room.has_method("guard_cell"):
			return _fail("@%s is LIVE and needs the Room" % name)
		var gc: Variant = room.call("guard_cell", i)
		if not (gc is Vector2i):
			return _fail("@%s: no such guard" % name)
		return _point_result(Vector3(gc.x + 0.5, gc.y + 0.5, 0.0), "guard")
	return _fail("'%s' names no anchor of this map" % ref)


## The ground cell a reference stands on (a point's cell, a box's centre cell), raw GU — what a scenario step's `@id` becomes.
func ground_cell(ref: String, room: Object = null) -> Dictionary:
	var r: Dictionary = resolve(ref, room)
	if not r["ok"]:
		return r
	var p: Vector3 = r["point"]
	return {"ok": true, "cell": Vector2i(floori(p.x), floori(p.y)), "error": ""}


func _point_result(at: Vector3, kind: String) -> Dictionary:
	return {"ok": true, "box": AABB(Vector3(at.x, at.z, at.y), Vector3.ZERO), "point": at, "kind": kind, "error": ""}


func _box_result(mn: Vector3, mx: Vector3, kind: String) -> Dictionary:
	var box := AABB(Vector3(mn.x, mn.z, mn.y), Vector3(mx.x - mn.x, mx.z - mn.z, mx.y - mn.y))
	var c: Vector3 = box.get_center()
	return {"ok": true, "box": box, "point": Vector3(c.x, c.z, c.y), "kind": kind, "error": ""}


func _aabb_result(box: AABB, kind: String) -> Dictionary:
	var c: Vector3 = box.get_center()
	return {"ok": true, "box": box, "point": Vector3(c.x, c.z, c.y), "kind": kind, "error": ""}


func _fail(message: String) -> Dictionary:
	return {"ok": false, "box": AABB(), "point": Vector3.ZERO, "kind": "", "error": "[MapLayout] " + message}


# ---------------------------------------------------------------------------------------------------------------------------------
# World conversion (the ONLY one)

## A raw GU point (x, y on the plan, z in storeys) -> the 3D board's world space.
static func to_world(point: Vector3) -> Vector3:
	return Vector3(point.x, point.z * vertical_scale, point.y)


## A box from `resolve()` (already in world axis order, x / storeys / y) -> world space.
static func to_world_box(box: AABB) -> AABB:
	var vs: float = vertical_scale
	return AABB(Vector3(box.position.x, box.position.y * vs, box.position.z), Vector3(box.size.x, box.size.y * vs, box.size.z))


# ---------------------------------------------------------------------------------------------------------------------------------
# Mutation (the future editor's API) and the way back to the file

func add_poi(id: String, at_raw: Vector3, tags: Array = []) -> bool:
	if not _free_id(id):
		return false
	_put("poi", {"id": id, "at": at_raw, "tags": tags.duplicate()})
	return true


func add_region(id: String, min_raw: Vector3, max_raw: Vector3, tags: Array = []) -> bool:
	if not _free_id(id):
		return false
	_put("regions", {"id": id, "min": min_raw, "max": max_raw, "tags": tags.duplicate()})
	return true


## Moves a POI to a point, or a region by a delta (its size kept). Returns false for an unknown id.
func move(id: String, to_or_delta: Vector3) -> bool:
	if poi.has(id):
		poi[id]["at"] = to_or_delta
		return true
	if regions.has(id):
		regions[id]["min"] = (regions[id]["min"] as Vector3) + to_or_delta
		regions[id]["max"] = (regions[id]["max"] as Vector3) + to_or_delta
		return true
	push_error("[MapLayout] move: no poi or region '%s'" % id)
	return false


func remove(id: String) -> bool:
	for kind: String in ["poi", "regions", "objectives"]:
		var table: Dictionary = _table(kind)
		if table.has(id):
			table.erase(id)
			(_order[kind] as Array).erase(id)
			return true
	push_error("[MapLayout] remove: no anchor '%s'" % id)
	return false


## Renames an anchor, and every objective that named the old id as its region. (CR-3 extends it to the `@id`s of `capture`.)
func rename(old_id: String, new_id: String) -> bool:
	if not _free_id(new_id):
		return false
	for kind: String in ["poi", "regions", "objectives"]:
		var table: Dictionary = _table(kind)
		if table.has(old_id):
			var entry: Dictionary = table[old_id]
			entry["id"] = new_id
			table.erase(old_id)
			table[new_id] = entry
			var order: Array = _order[kind]
			order[order.find(old_id)] = new_id
			for o: Dictionary in objectives.values():
				if str(o.get("region", "")) == old_id:
					o["region"] = new_id
			## CR-3: every `@old` of the capture section follows (rail targets, take steps).
			for r: Dictionary in rails.values():
				for k: Dictionary in r.get("keys", []):
					var tg: Variant = k.get("target", "")
					if tg is Array:
						k["target"] = (tg as Array).map(func(x): return "@" + new_id if str(x).trim_prefix("@") == old_id else x)
					elif str(tg).trim_prefix("@") == old_id:
						k["target"] = "@" + new_id
			for t: Dictionary in takes.values():
				var steps: Array = []
				for st in t.get("steps", []):
					steps.append(_rename_token(str(st), old_id, new_id))
				t["steps"] = steps
			return true
	push_error("[MapLayout] rename: no anchor '%s'" % old_id)
	return false


static func _rename_token(step: String, old_id: String, new_id: String) -> String:
	var tokens: PackedStringArray = step.split(" ")
	for i: int in range(tokens.size()):
		if tokens[i] == "@" + old_id:
			tokens[i] = "@" + new_id
	return " ".join(tokens)


func _free_id(id: String) -> bool:
	var problems: Array = []
	_check_id(id, {}, problems)
	if poi.has(id) or regions.has(id) or objectives.has(id):
		problems.append("id '%s' is already used" % id)
	for p in problems:
		push_error("[MapLayout] %s" % p)
	return problems.is_empty()


## The `layout` section in INNER GU, ready for the section owner to write — the inverse of `MapCompiler._compile_layout()`.
func to_section() -> Dictionary:
	var out: Dictionary = {"v": 1}
	if not envelope.is_empty():
		out["envelope"] = envelope.duplicate(true)
	var poi_out: Array = []
	for id in _order["poi"]:
		var p: Dictionary = poi[id]
		var prow: Dictionary = {"id": id, "at": _point_to_file(p["at"]), "tags": (p.get("tags", []) as Array).duplicate()}
		if p.has("extent"):
			var e: Vector3 = p["extent"]
			prow["extent"] = [e.x, e.y, e.z]
		poi_out.append(prow)
	var reg_out: Array = []
	for id in _order["regions"]:
		var r: Dictionary = regions[id]
		reg_out.append({"id": id, "box": {"min": _point_to_file(r["min"]), "max": _point_to_file(r["max"])},
			"tags": (r.get("tags", []) as Array).duplicate()})
	var obj_out: Array = []
	for id in _order["objectives"]:
		var o: Dictionary = objectives[id]
		var row: Dictionary = {"id": id, "kind": o["kind"], "tags": (o.get("tags", []) as Array).duplicate()}
		if o.has("region"):
			row["region"] = o["region"]
		else:
			row["at"] = _point_to_file(o["at"])
		obj_out.append(row)
	out["poi"] = poi_out
	out["regions"] = reg_out
	out["objectives"] = obj_out
	return out


func _point_to_file(raw: Vector3) -> Array:
	var inner: Vector2 = MapCompilerRef.raw_to_inner(Vector2(raw.x, raw.y), buffer)
	return [inner.x, inner.y, raw.z]


# ---------------------------------------------------------------------------------------------------------------------------------
# Validation of the section as authored (INNER GU). Called by `MapFileService` at load (errors make the map fail to load) and by the
# selftest over every shipped map. `sections` is the whole file's `sections` (the board size and the tallest geometry come from it).

static func validate_section(section: Dictionary, sections: Dictionary, errors: Array, warnings: Array) -> void:
	var board: Dictionary = sections.get("board", {})
	var inner: Vector2i = JsonFile.vector2i(board.get("inner_size", [18, 36]), Vector2i(18, 36), "board.inner_size", errors)
	var buf: int = int(board.get("buffer", 5))
	for key: String in RESERVED_KEYS:
		if section.has(key):
			errors.append("layout.%s is reserved until the access points move here (CAPTURE_RAILS CR-7, MAP_MASTER_PLAN)" % key)
	for key in section.keys():
		if not SECTION_KEYS.has(str(key)) and not RESERVED_KEYS.has(str(key)):
			errors.append("layout: unknown key '%s' (known: %s)" % [key, ", ".join(SECTION_KEYS)])
	var lo := Vector2(-buf, -buf)
	var hi := Vector2(inner.x + buf, inner.y + buf)
	var ids: Dictionary = {}
	for p in section.get("poi", []):
		if not (p is Dictionary):
			errors.append("layout.poi: %s is not an object" % str(p))
			continue
		var id: String = str(p.get("id", ""))
		_check_id(id, ids, errors)
		_check_point(p.get("at", null), "layout.poi '%s'.at" % id, lo, hi, errors)
		if p.has("extent"):
			var ext: Variant = _check_point(p["extent"], "layout.poi '%s'.extent" % id, Vector2(0, 0), Vector2(hi.x - lo.x, hi.y - lo.y), errors)
			if ext is Vector3 and (ext.x <= 0.0 or ext.y <= 0.0 or (p["extent"] as Array).size() != 3 or ext.z <= 0.0):
				errors.append("layout.poi '%s'.extent must be [x, y, z], each > 0 (the size of the thing around `at`)" % id)
		_check_tags(p, "layout.poi '%s'" % id, errors)
	var region_ids: Dictionary = {}
	for r in section.get("regions", []):
		if not (r is Dictionary):
			errors.append("layout.regions: %s is not an object" % str(r))
			continue
		var id: String = str(r.get("id", ""))
		_check_id(id, ids, errors)
		region_ids[id] = true
		var box: Variant = r.get("box", null)
		if not (box is Dictionary):
			errors.append("layout.regions '%s' needs a box {min, max}" % id)
			continue
		var mn: Variant = _check_point(box.get("min", null), "layout.regions '%s'.min" % id, lo, hi, errors)
		var mx: Variant = _check_point(box.get("max", null), "layout.regions '%s'.max" % id, lo, hi, errors)
		if mn is Vector3 and mx is Vector3 and not (mn.x < mx.x and mn.y < mx.y and mn.z < mx.z):
			errors.append("layout.regions '%s': min %s must be below max %s on every axis" % [id, mn, mx])
		_check_tags(r, "layout.regions '%s'" % id, errors)
	for o in section.get("objectives", []):
		if not (o is Dictionary):
			errors.append("layout.objectives: %s is not an object" % str(o))
			continue
		var id: String = str(o.get("id", ""))
		_check_id(id, ids, errors)
		if not OBJECTIVE_KINDS.has(str(o.get("kind", ""))):
			errors.append("layout.objectives '%s': kind '%s' is not one of %s" % [id, o.get("kind", ""), ", ".join(OBJECTIVE_KINDS)])
		if o.has("region"):
			if not region_ids.has(str(o["region"])):
				errors.append("layout.objectives '%s': region '%s' is not a region of this map" % [id, o["region"]])
		else:
			_check_point(o.get("at", null), "layout.objectives '%s'.at" % id, lo, hi, errors)
		_check_tags(o, "layout.objectives '%s'" % id, errors)
	## Warnings: the envelope is a guide, never a limit.
	var env: Dictionary = MapEnvelopeRef.for_map(section.get("envelope", {}))
	var reserve: Vector2i = env["reserve"]
	if inner.x > reserve.x or inner.y > reserve.y:
		warnings.append("the map (%dx%d GU) is larger than the envelope reserve (%dx%d): outside what PB-3 measured; re-run pb3_study.py --only HEAVY"
			% [inner.x, inner.y, reserve.x, reserve.y])
	var tallest: float = MapCompilerRef.tallest_storeys_of(sections.get("blocks", {}).get("items", []), sections.get("panels", {}).get("items", []),
		sections.get("roofs", {}).get("items", []))
	var ceiling: int = int(env["playable_storeys"]) + int(env["compose_storeys"])
	if tallest > float(ceiling):
		warnings.append("geometry reaches %.0f storeys, above the envelope's %d (playable + compose)" % [tallest, ceiling])


static func _check_id(id: String, seen: Dictionary, errors: Array) -> void:
	var re := RegEx.create_from_string("^[a-z0-9_]+$")
	if id.is_empty() or re.search(id) == null:
		errors.append("layout: id '%s' must match [a-z0-9_]+" % id)
	elif RESERVED_NAMES.has(id) or id.begins_with("guard_"):
		errors.append("layout: id '%s' is a reserved name" % id)
	elif seen.has(id):
		errors.append("layout: id '%s' is used twice" % id)
	seen[id] = true


## A point `[x, y]` or `[x, y, z]` on the 1/8 lattice, inside the map + ring, not below the ground. Returns the Vector3 or null.
static func _check_point(v: Variant, what: String, lo: Vector2, hi: Vector2, errors: Array) -> Variant:
	if not (v is Array) or not ((v as Array).size() == 2 or (v as Array).size() == 3):
		errors.append("%s must be [x, y] or [x, y, z], got %s" % [what, str(v)])
		return null
	for n in v:
		if not (n is float or n is int):
			errors.append("%s: %s is not a number" % [what, str(n)])
			return null
	var p := Vector3(float(v[0]), float(v[1]), float(v[2]) if (v as Array).size() == 3 else 0.0)
	for c: float in [p.x, p.y, p.z]:
		if not is_equal_approx(c * 8.0, roundf(c * 8.0)):
			errors.append("%s: %s is off the 1/8 lattice" % [what, str(v)])
			return null
	if p.x < lo.x or p.y < lo.y or p.x > hi.x or p.y > hi.y:
		errors.append("%s: %s lies outside the map and its buffer ring" % [what, str(v)])
		return null
	if p.z < 0.0:
		errors.append("%s: %s is below the ground" % [what, str(v)])
		return null
	return p


static func _check_tags(row: Dictionary, what: String, errors: Array) -> void:
	var tags: Variant = row.get("tags", [])
	if not (tags is Array):
		errors.append("%s: tags must be an array of strings" % what)
		return
	for t in tags:
		if not (t is String):
			errors.append("%s: tag %s is not a string" % [what, str(t)])


# ---------------------------------------------------------------------------------------------------------------------------------
# Validation of the `capture` section (CR-3), against the `layout` it names. Structure only: a take's steps are parsed by
# `ScenarioRunner` when the take runs (one parser; headless map tools cannot load it).

const KEY_FIELDS: Array[String] = ["frame", "target", "view", "move", "hold", "ease", "turn", "follow", "centre", "zoom"]
const TAKE_FIELDS: Array[String] = ["id", "profile", "rail", "steps", "at_key", "after_hold", "length", "seed", "note"]
const FRAME_MODES: Array[String] = ["wide", "detail", "fit", "explicit"]
const EASES: Array[String] = ["linear", "in_out", "out"]
const TURNS: Array[String] = ["cut", "orbit"]
const VIEWS: Array[String] = ["N", "E", "S", "W"]


static func validate_capture(section: Dictionary, layout_section: Dictionary, errors: Array) -> void:
	var anchors: Dictionary = {}
	for kind: String in ["poi", "regions", "objectives"]:
		for row in layout_section.get(kind, []):
			if row is Dictionary:
				anchors[str(row.get("id", ""))] = true
	for key in section.keys():
		if not ["v", "rails", "takes"].has(str(key)):
			errors.append("capture: unknown key '%s' (v, rails, takes)" % key)
	var rail_ids: Dictionary = {}
	var seen: Dictionary = {}
	for r in section.get("rails", []):
		if not (r is Dictionary):
			errors.append("capture.rails: %s is not an object" % str(r))
			continue
		var id: String = str(r.get("id", ""))
		_check_capture_id(id, anchors, seen, errors)
		rail_ids[id] = true
		var keys: Variant = r.get("keys", [])
		if not (keys is Array) or (keys as Array).is_empty():
			errors.append("capture.rails '%s' needs a non-empty keys array" % id)
			continue
		for i: int in range((keys as Array).size()):
			_check_key(keys[i], "capture.rails '%s' key %d" % [id, i], anchors, errors)
	for t in section.get("takes", []):
		if not (t is Dictionary):
			errors.append("capture.takes: %s is not an object" % str(t))
			continue
		var id: String = str(t.get("id", ""))
		_check_capture_id(id, anchors, seen, errors)
		for f in t.keys():
			if not TAKE_FIELDS.has(str(f)):
				errors.append("capture.takes '%s': unknown field '%s'" % [id, f])
		var rid: String = str(t.get("rail", ""))
		if not rail_ids.has(rid) and not (rid == "overview" or rid.begins_with("region:") or rid.begins_with("poi:")):
			errors.append("capture.takes '%s': rail '%s' is not a rail of this map (nor overview / region:<id> / poi:<id>)" % [id, rid])
		for f: String in ["at_key", "after_hold", "length", "seed"]:
			if t.has(f) and (not (t[f] is float or t[f] is int) or int(t[f]) < 0):
				errors.append("capture.takes '%s'.%s must be a whole number >= 0" % [id, f])
		if not (t.get("steps", []) is Array):
			errors.append("capture.takes '%s'.steps must be an array of scenario steps" % id)
		else:
			for st in t.get("steps", []):
				for tok: String in str(st).split(" ", false):
					if tok.begins_with("@") and not anchors.has(tok.trim_prefix("@")) and not _is_reserved_ref(tok.trim_prefix("@")):
						errors.append("capture.takes '%s': step '%s' names %s, which is no anchor of this map" % [id, st, tok])


static func _check_capture_id(id: String, anchors: Dictionary, seen: Dictionary, errors: Array) -> void:
	var re := RegEx.create_from_string("^[a-z0-9_]+$")
	if id.is_empty() or re.search(id) == null:
		errors.append("capture: id '%s' must match [a-z0-9_]+" % id)
	elif anchors.has(id) or seen.has(id) or RESERVED_NAMES.has(id) or id == "overview":
		errors.append("capture: id '%s' is already used (ids are unique across layout and capture)" % id)
	seen[id] = true


static func _is_reserved_ref(name: String) -> bool:
	return RESERVED_NAMES.has(name) or (name.begins_with("guard_") and name.trim_prefix("guard_").is_valid_int()) \
		or name.begins_with("corner_") or name.begins_with("side_")


static func _check_key(k: Variant, what: String, anchors: Dictionary, errors: Array) -> void:
	if not (k is Dictionary):
		errors.append("%s is not an object" % what)
		return
	for f in k.keys():
		if not KEY_FIELDS.has(str(f)):
			errors.append("%s: unknown field '%s'" % [what, f])
	var mode: String = str(k.get("frame", "wide"))
	if not FRAME_MODES.has(mode):
		errors.append("%s: frame '%s' is not one of %s" % [what, mode, ", ".join(FRAME_MODES)])
	if mode == "explicit":
		if not (k.get("centre", null) is Array) or not (k.get("zoom", null) is float or k.get("zoom", null) is int):
			errors.append("%s: explicit needs centre [x, y] and zoom" % what)
	else:
		var targets: Array = k["target"] if k.get("target", null) is Array else [k.get("target", "@map")]
		for tg in targets:
			var name: String = str(tg).trim_prefix("@")
			if not anchors.has(name) and not _is_reserved_ref(name):
				errors.append("%s: target '%s' is no anchor of this map" % [what, tg])
	if k.has("view") and not VIEWS.has(str(k["view"])):
		errors.append("%s: view '%s' is not N/E/S/W" % [what, k["view"]])
	if k.has("ease") and not EASES.has(str(k["ease"])):
		errors.append("%s: ease '%s' is not one of %s" % [what, k["ease"], ", ".join(EASES)])
	if k.has("turn") and not TURNS.has(str(k["turn"])):
		errors.append("%s: turn '%s' is not cut or orbit" % [what, k["turn"]])
	for f: String in ["move", "hold"]:
		if k.has(f) and (not (k[f] is float or k[f] is int) or int(k[f]) < 0 or not is_equal_approx(float(k[f]), roundf(float(k[f])))):
			errors.append("%s: %s must be a whole number of frames >= 0" % [what, f])
