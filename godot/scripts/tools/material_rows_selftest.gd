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
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
