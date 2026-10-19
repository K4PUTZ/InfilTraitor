## SECONDARY MATERIALS (2026-10-18) — `MaterialRows`: a row that `inherits` a primary takes every column it does not set, never the texture
## columns; a missing primary and a cycle are loud; and on the real catalogue `iron_bar` is `steel_dark` to destruction and its own art to the renderer.
extends SceneTree

const MaterialRowsClass = preload("res://godot/scripts/systems/material_rows.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")
const ResistanceClass = preload("res://godot/scripts/systems/destruction/material_resistance_table.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== MATERIAL ROWS SELFTEST ==\n")
	var raw: Dictionary = {
		"metal": {"id": "metal", "destroy_factor": 0.05, "family": "metal", "base_color": [0.5, 0.5, 0.5], "has_facade": true, "facade_mean": 120.0},
		"bar": {"id": "bar", "inherits": "metal", "has_facade": true, "facade_mean": 150.0, "base_color": [0.6, 0.6, 0.6]},
		"bar_rusty": {"id": "bar_rusty", "inherits": "bar", "smoke_chance": 0.3},
		"orphan": {"id": "orphan", "inherits": "nothing_here", "destroy_factor": 0.9},
		"loop_a": {"id": "loop_a", "inherits": "loop_b"},
		"loop_b": {"id": "loop_b", "inherits": "loop_a"},
	}
	var errors: Array = []
	var rows: Dictionary = MaterialRowsClass.resolve(raw, "selftest", errors)
	var bar: Dictionary = rows["bar"]
	_check(float(bar.get("destroy_factor", -1.0)) == 0.05 and String(bar.get("family", "")) == "metal", "a secondary takes the primary's balance numbers and family")
	_check((bar["base_color"] as Array)[0] == 0.6, "a column the secondary sets is its own (base_color)")
	_check(float(bar["facade_mean"]) == 150.0 and String(bar["primary"]) == "metal", "the texture columns are never inherited; `primary` names the root")
	var rusty: Dictionary = rows["bar_rusty"]
	_check(float(rusty.get("destroy_factor", -1.0)) == 0.05 and String(rusty["primary"]) == "metal" and not rusty.has("facade_mean"), "a chain of two resolves to the root, still without its texture")
	_check(float(rows["orphan"]["destroy_factor"]) == 0.9 and String(rows["orphan"]["primary"]) == "orphan", "a missing primary keeps what the row sets itself")
	_check(errors.size() == 3, "the missing primary and both ends of the cycle are reported (%d errors)" % errors.size())
	_check(not raw["bar"].has("primary"), "the input rows are not modified")

	## The real catalogue: the first secondary, the iron of the PIPE_LAB bars.
	var registry = MaterialRegistryClass.new()
	registry.load_from_disk()
	var iron = registry.get_material("iron_bar")
	var steel = registry.get_material("steel_dark")
	_check(iron != null and steel != null, "iron_bar and steel_dark are registered")
	if iron != null and steel != null:
		_check(iron.inherits == "steel_dark" and registry.primary_of("iron_bar") == "steel_dark" and registry.primary_of("steel_dark") == "steel_dark", "iron_bar's primary is steel_dark")
		_check(iron.has_facade and not steel.has_facade, "iron_bar wears its own facade; steel_dark stays flat")
		_check(iron.destroy_factor == steel.destroy_factor and iron.family == steel.family, "the registry sees steel_dark's numbers on iron_bar")
	_check(ResistanceClass.destroy_factor("iron_bar") == ResistanceClass.destroy_factor("steel_dark")
			and ResistanceClass.smoke_chance("iron_bar") == ResistanceClass.smoke_chance("steel_dark"), "destruction sees steel_dark's numbers on iron_bar (MaterialResistanceTable)")
	## The behaviour tables: a secondary answers as its primary (a synthetic primary map, then the real one put back).
	var saved: Dictionary = MaterialRowsClass.primary_map().duplicate()
	MaterialRowsClass._primary_cache = {"wood": "wood", "plank": "wood", "plank_dark": "wood", "metal": "metal"}
	var speed: Dictionary = {"wood": 1.3, "metal": 0.7}
	var splinters: Array[String] = ["wood", "plywood"]
	var own: Dictionary = {"wood": 1.0, "plank_dark": 2.0}
	_check(MaterialRowsClass.alias_secondaries(speed) == 2 and float(speed["plank"]) == 1.3 and float(speed["plank_dark"]) == 1.3, "a Dictionary table gives each secondary its primary's entry")
	_check(MaterialRowsClass.alias_secondaries(splinters) == 2 and splinters.has("plank"), "an Array table lists each secondary of a listed primary")
	_check(MaterialRowsClass.alias_secondaries(own) == 1 and float(own["plank_dark"]) == 2.0, "an entry a secondary already has is its own")
	_check(MaterialRowsClass.primary_of("plank_dark") == "wood" and MaterialRowsClass.primary_of("unknown_x") == "unknown_x", "primary_of answers the root, an unknown id itself")
	MaterialRowsClass._primary_cache = saved
	## Coverage: every material table of the four behaviour classes is listed in SecondaryTables (a new table would otherwise skip secondaries in silence).
	var listed: String = FileAccess.get_file_as_string("res://godot/scripts/systems/secondary_tables.gd")
	var regex := RegEx.new()
	regex.compile("(?m)^static var ([A-Z_]+): (Dictionary|Array\\[String\\])")
	var missing: Array = []
	var found: int = 0
	for path: String in ["res://godot/scripts/systems/destruction/rubble_presets.gd", "res://godot/scripts/systems/destruction/shot_punch_table.gd",
			"res://godot/scripts/systems/destruction/soft_sheet_presets.gd", "res://godot/scripts/geometry/board3d_live.gd"]:
		for m: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			found += 1
			if not listed.contains("." + m.get_string(1) + ")"):
				missing.append(m.get_string(1))
	_check(found >= 40, "the coverage scan finds the tables (%d), so it cannot pass empty" % found)
	_check(missing.is_empty(), "every material-keyed table of RubblePresets / ShotPunchTable / SoftSheetPresets / Board3DLive is in SecondaryTables %s" % str(missing))
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
