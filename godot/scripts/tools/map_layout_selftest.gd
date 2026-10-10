## CAPTURE_RAILS CR-1 — the map's anchors: `MapCompass` (derived from the rectangle), the `layout` section's validation (red on every
## kind of bad file, green on the shipped maps), the compile path on the REAL GLASS map (inner -> raw by the buffer, in MapCompiler
## only), `MapLayout.resolve()` for authored, derived and reserved names, the world conversion, the editor's mutation API and the
## round trip back to the file (`to_section()` == the section as authored), and the envelope file's warnings.
extends SceneTree

const MapCompassClass = preload("res://godot/scripts/world/maps/map_compass.gd")
const MapLayoutClass = preload("res://godot/scripts/world/maps/map_layout.gd")
const MapEnvelopeClass = preload("res://godot/scripts/world/maps/map_envelope.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapSectionRegistryClass = preload("res://godot/scripts/world/maps/persistence/map_section_registry.gd")
const MapSectionsV1Class = preload("res://godot/scripts/world/maps/persistence/map_sections_v1.gd")
const MapFileServiceClass = preload("res://godot/scripts/world/maps/persistence/map_file_service.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== MAP LAYOUT SELFTEST (CAPTURE_RAILS CR-1) ==\n")
	_compass()
	_envelope()
	_validation_red_green()
	_shipped_maps_load()
	_glass_compiled()
	_mutation_and_round_trip()
	print("\n%s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _compass() -> void:
	print("[1] MapCompass is derived from the rectangle")
	var r := Rect2i(Vector2i(5, 5), Vector2i(26, 18))   ## GLASS: inner 26 x 18, buffer 5
	_check(MapCompassClass.corner("N", r) == Vector2(5, 5) and MapCompassClass.corner("S", r) == Vector2(31, 23)
		and MapCompassClass.corner("E", r) == Vector2(31, 5) and MapCompassClass.corner("W", r) == Vector2(5, 23),
		"corners N/E/S/W are the rectangle's vertices (the far ones at `end`)")
	_check(MapCompassClass.side_of(Vector2i(5, 12), r) == "NW" and MapCompassClass.side_of(Vector2i(12, 5), r) == "NE"
		and MapCompassClass.side_of(Vector2i(30, 12), r) == "SE" and MapCompassClass.side_of(Vector2i(12, 22), r) == "SW",
		"sides follow the glossary: NW = x-min, NE = y-min, SE = x-max, SW = y-max")
	_check(MapCompassClass.side_of(Vector2i(12, 12), r) == "" and MapCompassClass.side_of(Vector2i(0, 0), r) == "",
		"an interior or outside cell lies on no side")
	_check(MapCompassClass.side_facing(Vector2i(12, 4), r) == "NE" and MapCompassClass.side_facing(Vector2i(31, 12), r) == "SE",
		"a cell just outside a side faces that side (an access cell in the wall ring)")
	_check(MapCompassClass.side_cells("SW", r).size() == 26 and MapCompassClass.band("NE", r, 2) == Rect2i(5, 5, 26, 2),
		"side_cells and the 2-deep band have the expected extents")


func _envelope() -> void:
	print("[2] the envelope file is THE authority")
	_check(MapEnvelopeClass.footprint() == Vector2i(18, 36) and MapEnvelopeClass.reserve() == Vector2i(24, 48)
		and MapEnvelopeClass.compose_storeys() == 3 and MapEnvelopeClass.playable_storeys() == 1,
		"maps/_spec/segment_envelope.json reads footprint 18x36, reserve 24x48, 1 + 3 storeys")
	_check(int(MapEnvelopeClass.for_map({"compose_storeys": 5})["compose_storeys"]) == 5, "a map's own envelope overrides the file")
	var warnings: Array = []
	MapLayoutClass.validate_section({"v": 1}, {"board": {"inner_size": [30, 50], "buffer": 5},
		"blocks": {"items": [{"gu": [1, 1], "storeys": 6}]}}, [], warnings)
	_check(warnings.size() == 2, "a 30x50 map with 6-storey geometry gets two WARNINGS (reserve, compose), never an error (%d)" % warnings.size())


func _validation_red_green() -> void:
	print("[3] validation: red on each bad shape, green on a good one")
	var board: Dictionary = {"board": {"inner_size": [26, 18], "buffer": 5}}
	var good: Dictionary = {"v": 1,
		"poi": [{"id": "a", "at": [1.5, 2.125, 0.5], "tags": ["detail"]}, {"id": "b", "at": [-5, 23]}],
		"regions": [{"id": "r", "box": {"min": [0, 0, 0], "max": [4, 4, 2]}}],
		"objectives": [{"id": "o", "kind": "reach_terminal", "region": "r"}, {"id": "o2", "kind": "sabotage", "at": [3, 3]}]}
	var errors: Array = []
	MapLayoutClass.validate_section(good, board, errors, [])
	_check(errors.is_empty(), "a good section has no error (%s)" % str(errors))
	var bad: Array = [
		[{"exits": []}, "the reserved key `exits`"],
		[{"spawns": []}, "an unknown key"],
		[{"poi": [{"id": "a", "at": [1, 1]}, {"id": "a", "at": [2, 2]}]}, "a duplicate id"],
		[{"poi": [{"id": "agent_start", "at": [1, 1]}]}, "a reserved name"],
		[{"poi": [{"id": "guard_3", "at": [1, 1]}]}, "a guard_<i> name"],
		[{"poi": [{"id": "Big Pane", "at": [1, 1]}]}, "an id outside [a-z0-9_]"],
		[{"poi": [{"id": "a", "at": [1.1, 1]}]}, "a point off the 1/8 lattice"],
		[{"poi": [{"id": "a", "at": [40, 1]}]}, "a point outside the map + ring"],
		[{"poi": [{"id": "a", "at": [1, 1, -1]}]}, "a point below the ground"],
		[{"regions": [{"id": "r", "box": {"min": [4, 0, 0], "max": [4, 4, 2]}}]}, "a box with min == max on an axis"],
		[{"objectives": [{"id": "o", "kind": "win", "at": [1, 1]}]}, "an unknown objective kind"],
		[{"objectives": [{"id": "o", "kind": "survive", "region": "nowhere"}]}, "an objective naming no region"],
		[{"poi": [{"id": "a", "at": [1, 1], "tags": "glass"}]}, "tags that are not an array"],
	]
	for row: Array in bad:
		var e: Array = []
		MapLayoutClass.validate_section(row[0], board, e, [])
		_check(not e.is_empty(), "RED: %s is an error (%s)" % [row[1], e[0] if not e.is_empty() else "none"])


func _shipped_maps_load() -> void:
	print("[4] every shipped map still loads through MapFileService; GLASS and PLAYGROUND carry anchors")
	var registry = MapSectionRegistryClass.new()
	MapSectionsV1Class.register_all(registry)
	var service = MapFileServiceClass.new(registry)
	var dir := DirAccess.open("res://maps")
	var checked: int = 0
	var failed: Array = []
	for f: String in dir.get_files():
		if not f.ends_with(".map.json"):
			continue
		checked += 1
		var res: Dictionary = service.load_file("res://maps/" + f)
		if not res["ok"]:
			failed.append("%s: %s" % [f, str(res["errors"])])
	_check(failed.is_empty() and checked > 0, "%d map(s) load, none fails (%s)" % [checked, str(failed)])
	for id: String in ["GLASS", "PLAYGROUND"]:
		var res: Dictionary = service.load_file("res://maps/%s.map.json" % id)
		var lay: Dictionary = res["spec"].get("sections", {}).get("layout", {}) if res["ok"] else {}
		_check((lay.get("poi", []) as Array).size() >= 3 and (lay.get("regions", []) as Array).size() >= 3,
			"%s carries its anchors (%d poi, %d regions)" % [id, (lay.get("poi", []) as Array).size(), (lay.get("regions", []) as Array).size()])


func _glass_compiled() -> RefCounted:
	print("[5] the REAL GLASS map, compiled: inner -> raw in MapCompiler only")
	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("GLASS")
	var compiled: Dictionary = MapCompilerClass.compile(spec)
	var ml = MapLayoutClass.new().load_compiled(compiled)
	_check(ml.buffer == 5 and ml.playable_rect == Rect2i(5, 5, 26, 18), "playable rect raw 5,5 26x18 (%s)" % ml.playable_rect)
	var pane: Dictionary = ml.resolve("@big_pane")
	_check(pane["ok"] and pane["point"] == Vector3(18.0, 15.0, 1.5), "@big_pane (inner 13, 10, 1.5) resolves raw (18, 15, 1.5): %s" % pane["point"])
	var wing: Dictionary = ml.resolve("glass_wing")
	_check(wing["ok"] and wing["box"] == AABB(Vector3(8, 0, 8), Vector3(20, 3, 13)),
		"a region's box is raw, in world axis order (x, storeys, y): %s" % wing["box"])
	_check(is_equal_approx(ml.tallest_storeys, 3.0), "@map is as tall as GLASS's tallest pane (3 storeys): %.2f" % ml.tallest_storeys)
	var m: Dictionary = ml.resolve("@map")
	_check(m["ok"] and m["box"] == AABB(Vector3(5, 0, 5), Vector3(26, 3, 18)), "@map is the playable rectangle, ground to 3 storeys")
	var a: Dictionary = ml.resolve("agent_start")
	_check(a["ok"] and a["point"] == Vector3(18.5, 18.5, 0.0), "@agent_start is read from `actors` (inner 13,13 -> raw centre 18.5): %s" % a["point"])
	_check(ml.resolve("corner_s")["point"] == Vector3(31, 23, 0) and ml.resolve("side_sw")["ok"], "corners and sides resolve")
	_check(not ml.resolve("@nowhere")["ok"] and not ml.resolve("@agent")["ok"], "an unknown id and a LIVE name without the Room fail, loudly-shaped")
	_check(ml.ground_cell("@throw_front")["cell"] == Vector2i(18, 16), "@throw_front's ground cell is raw (18, 16)")
	_check(MapLayoutClass.to_world(Vector3(18, 15, 1.5)).is_equal_approx(Vector3(18, 1.5, 15)),
		"to_world: raw x -> x, raw y -> world z, storeys -> world y (VERTICAL_SCALE 1)")
	_check(ml.exits().size() == ml.exit_cells.size(), "exits() reads the compiled access cells (%d)" % ml.exit_cells.size())
	_check(ml.safe_zone("SW") == AABB(Vector3(5, 0, 21), Vector3(26, 1, 2)), "the safe zone is a 2-GU band along the entry side")
	return ml


func _mutation_and_round_trip() -> void:
	print("[6] the editor's API and the way back to the file")
	var spec: Dictionary = FileMapSourceClass.new().get_runtime_spec("GLASS")
	var authored: Dictionary = spec["layout"]
	var ml = MapLayoutClass.new().load_compiled(MapCompilerClass.compile(spec))
	_check(_normal(ml.to_section()) == _normal(authored), "to_section() gives back the section as authored (inner GU)")
	_check(ml.add_poi("probe", Vector3(10, 10, 0)) and not ml.add_poi("probe", Vector3(11, 11, 0)) and not ml.add_poi("map", Vector3.ZERO),
		"add_poi refuses a used id and a reserved name")
	ml.add_region("zone_a", Vector3(6, 6, 0), Vector3(8, 8, 1))
	ml.objectives["obj"] = {"id": "obj", "kind": "survive", "region": "zone_a", "tags": []}
	(ml._order["objectives"] as Array).append("obj")
	_check(ml.rename("zone_a", "zone_b") and str(ml.objectives["obj"]["region"]) == "zone_b", "rename rewrites the objectives that named it")
	_check(ml.move("zone_b", Vector3(1, 0, 0)) and ml.resolve("zone_b")["box"].position.x == 7.0, "move shifts a region")
	_check(ml.remove("probe") and not ml.resolve("probe")["ok"], "remove drops an anchor")
	var sec: Dictionary = ml.to_section()
	var errors: Array = []
	MapLayoutClass.validate_section(sec, {"board": {"inner_size": [26, 18], "buffer": 5}}, errors, [])
	_check(errors.is_empty(), "the edited section is still a valid file (%s)" % str(errors))


## Points normalised to three floats, so `[13.5, 11.5]` and `[13.5, 11.5, 0.0]` compare equal.
func _normal(section: Dictionary) -> String:
	var out: Dictionary = {}
	for key in ["poi", "regions", "objectives"]:
		var rows: Array = []
		for row: Dictionary in section.get(key, []):
			var r: Dictionary = row.duplicate(true)
			if r.has("at"):
				r["at"] = _p(r["at"])
			if r.has("box"):
				r["box"] = {"min": _p(r["box"]["min"]), "max": _p(r["box"]["max"])}
			if not r.has("tags"):
				r["tags"] = []
			rows.append(r)
		out[key] = rows
	return JSON.stringify(out, "", true)


func _p(v: Array) -> Array:
	return [float(v[0]), float(v[1]), float(v[2]) if v.size() == 3 else 0.0]
