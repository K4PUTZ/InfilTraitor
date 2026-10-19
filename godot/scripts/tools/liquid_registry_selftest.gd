## M6 — `LiquidRegistry` and the `liquids` map section: every `liquids/*.json` loads clean, a placement's overrides win and are clamped, an unknown
## control / liquid is refused loudly, every control's range holds a value its own default uses, and PIPE_LAB's body reaches the compiler.
extends SceneTree

const LiquidRegistryClass = preload("res://godot/scripts/systems/liquid_registry.gd")
const FileMapSourceClass = preload("res://godot/scripts/world/maps/file_map_source.gd")
const MapCompilerClass = preload("res://godot/scripts/world/maps/map_compiler.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== LIQUID REGISTRY SELFTEST ==\n")
	LiquidRegistryClass.reload()
	_check(LiquidRegistryClass.load_errors.is_empty(), "every liquids/*.json loads with no error (%s)" % str(LiquidRegistryClass.load_errors))
	var ids: PackedStringArray = LiquidRegistryClass.ids()
	_check(ids.size() >= 17, "the catalogue holds the looks of the study (%d liquids)" % ids.size())
	for id: String in ["waste", "esgoto", "clean", "caribe", "biohazard", "toxic", "nuclear", "lava_gold", "lava_crust", "lava_viscous",
			"petroleo", "acido", "lama", "criogenico", "areia_movedica"]:
		_check(LiquidRegistryClass.has(id) and not (LiquidRegistryClass.resolve(id) as Dictionary).is_empty(), "'%s' resolves" % id)
	var base: Dictionary = LiquidRegistryClass.resolve("esgoto")
	var more: Dictionary = LiquidRegistryClass.resolve("esgoto", {"bubble_amount": 2.0, "flow_speed": 0.9, "deep_color": [0.1, 0.2, 0.3]})
	_check(float(more["bubble_amount"]) == 2.0 and float(more["flow_speed"]) == 0.9, "an override of a control wins over the file")
	_check((more["deep_color"] as Color).is_equal_approx(Color(0.1, 0.2, 0.3, 1.0)) and (base["deep_color"] as Color).a < 1.0, "a colour override takes 3 numbers (alpha 1) and leaves the file's own untouched")
	var clamped: Dictionary = LiquidRegistryClass.resolve("clean", {"flow_speed": 99.0, "oil": -3.0})
	_check(float(clamped["flow_speed"]) == 1.5 and float(clamped["oil"]) == 0.0, "an out-of-range value is clamped into its range (loudly)")
	var errors: Array = []
	var coerced: Dictionary = LiquidRegistryClass.coerce({"nonsense": 1, "froth": "lots", "scum_color": [2, 0, 0], "junk": 0.5}, "test", errors)
	_check(errors.size() == 3 and coerced.size() == 1 and float(coerced["junk"]) == 0.5, "an unknown control, a word where a number goes and a colour out of 0..1 are each refused, the good one stays (%d errors)" % errors.size())
	_check((LiquidRegistryClass.resolve("no_such_liquid") as Dictionary).is_empty(), "an unknown liquid answers {} (loudly)")
	_check(float(LiquidRegistryClass.resolve("criogenico")["time_scale"]) == 0.0, "ice is frozen (time_scale 0)")
	var lava: Dictionary = LiquidRegistryClass.gameplay("lava_gold")
	var toxic: Dictionary = LiquidRegistryClass.gameplay("toxic")
	_check(float(lava["exposure"]["deep"]) >= 1.0 and float(lava["exposure"]["shallow"]) < float(lava["exposure"]["deep"]), "lava kills in the deep at once and less on top")
	_check(float(toxic["exposure"]["deep"]) > float(toxic["exposure"]["shallow"]) and float(toxic["exposure"]["shallow"]) > 0.0, "toxic waste hurts more the deeper it is (and a little on top)")
	var harmless_deep: bool = true
	for id: String in ["clean", "caribe", "waste", "esgoto", "lama"]:
		var g: Dictionary = LiquidRegistryClass.gameplay(id)
		harmless_deep = harmless_deep and not g.has("exposure")
	_check(harmless_deep, "water, sewage and mud are never lethal by exposure (they slow, make noise, leave footprints)")
	_check((LiquidRegistryClass.gameplay("petroleo") as Dictionary).get("flammable", false) == true and (LiquidRegistryClass.gameplay("clean") as Dictionary).get("extinguishes", false) == true, "oil burns and clean water puts out fire")
	for key: String in LiquidRegistryClass.PARAMS:
		var spec: Array = LiquidRegistryClass.PARAMS[key]
		_check(String(spec[3]) != "" and float(spec[1]) <= float(spec[2]), "control '%s' has a description and a sane range" % key)
	var spec_map: Dictionary = FileMapSourceClass.new().get_runtime_spec("PIPE_LAB")
	_check((spec_map.get("liquids", []) as Array).size() == 1, "PIPE_LAB's `liquids` reaches the runtime spec")
	var layout: Dictionary = MapCompilerClass.compile(spec_map)
	var bodies: Array = layout.get("liquid_instances", [])
	var offset := Vector2(layout.get("playable_rect", Rect2i()).position)
	_check(bodies.size() == 1 and (bodies[0]["fluid"]["seed"] as Vector2) == Vector2(12.0, 1.4) + offset and (bodies[0]["flow"] as Vector2) == Vector2(0, 1),
		"MapCompiler shifts the seed by the buffer and keeps the flow (the body's shape is read from the world at load)")
	var bad_spec: Dictionary = spec_map.duplicate(true)
	bad_spec["liquids"] = [{"zone": [1, 1, 0, 3], "kind": "caribe"}, {"zone": [1, 1, 2, 2]}, {"zone": [2, 2, 3, 1], "kind": "lama"}]
	var good: Array = MapCompilerClass.compile(bad_spec).get("liquid_instances", [])
	_check(good.size() == 1 and (good[0]["flow"] as Vector2) == Vector2(1, 0), "a zero-size body and one with no kind are refused (loudly); a wide body flows along x")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
