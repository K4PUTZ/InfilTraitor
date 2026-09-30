## Selftest — slots, several models per slot, the validator and the fallback chain (PROP_PIPELINE_PLAN PP1, `ACTOR` D66/D69).
## In-memory registry and box models only (no disk, no ASSETS, no autoload).
extends SceneTree

var passed: int = 0
var failed: int = 0

const FAMILIES := {"wood": "wood", "plywood": "wood", "metal": "metal", "rubber": "rubber", "generic": "generic", "glass": "glass"}


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("Prop slots SELFTEST")
	print("=".repeat(70) + "\n")
	_test_validator()
	_test_resolution_and_fallback()
	_test_several_models_and_slot_placements()
	print("\nRESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _pass(m: String) -> void:
	passed += 1
	print("  ✓ " + m)


func _fail(m: String) -> void:
	failed += 1
	print("  ✗ " + m)


func _check(cond: bool, m: String) -> void:
	if cond:
		_pass(m)
	else:
		_fail(m)


func _slot(extra: Dictionary = {}) -> SlotDef:
	var d := {"id": "table", "footprint_gus": [[0, 0]], "max_size": [1.0, 0.8, 0.8], "mesh_tier": 4,
		"gameplay": {"cover": "half", "destructible": false}, "default_model": "good_table", "generic_material": "generic",
		"budget": {"max_triangles": 100, "max_surfaces": 2}, "allowed_families": ["wood", "metal", "generic"]}
	d.merge(extra, true)
	return SlotDef.from_json(d)


func _family(m: String) -> String:
	return String(FAMILIES.get(m, "generic"))


func _prop(id: String, size: Array, extra: Dictionary = {}) -> PropDef:
	var d := {"id": id, "mesh_tier": 4, "mesh_size": size, "material_zones": {"default": "wood"}, "footprint_gus": [[0, 0]],
		"storeys": 1, "gameplay": {"cover": "full", "destructible": true}, "slot": "table"}
	d.merge(extra, true)
	return PropDef.from_json(d)


func _registry() -> PropRegistry:
	var r := PropRegistry.new()
	r.family_of = _family
	r.register_slot(_slot())
	r.register(_prop("good_table", [0.9, 0.6, 0.6]))
	r.register(_prop("huge_table", [2.0, 0.6, 0.6]))                 ## bigger than the slot's box
	r.register(_prop("rubber_table", [0.9, 0.6, 0.6], {"surface_materials": {"": "rubber"}}))   ## a family the slot does not allow
	r.register(_prop("ghost_slot_table", [0.9, 0.6, 0.6], {"slot": "nowhere"}))
	return r


func _test_validator() -> void:
	print("[1] PropValidator: each rule on its own")
	var slot := _slot()
	var ok_stats := {"ok": true, "size": Vector3(0.9, 0.6, 0.6), "triangles": 50, "surfaces": ["a"], "finite": true}
	var def := {"slot": "table", "mesh_size": Vector3(0.9, 0.6, 0.6), "mesh_tier": 4, "footprint": [Vector2i.ZERO], "surface_materials": {}}
	var fam := Callable(self, "_family")
	_check(PropValidator.validate(def, slot, ok_stats, fam).is_empty(), "a model inside every limit has no problems")
	var big := def.duplicate()
	big["mesh_size"] = Vector3(1.5, 0.6, 0.6)
	_check(PropValidator.validate(big, slot, ok_stats, fam).size() == 1, "oversize: a box larger than the slot's is one problem")
	var tris := ok_stats.duplicate()
	tris["triangles"] = 101
	_check(PropValidator.validate(def, slot, tris, fam).size() == 1, "too many triangles: 101 > 100")
	var surf := ok_stats.duplicate()
	surf["surfaces"] = ["a", "b", "c"]
	_check(PropValidator.validate(def, slot, surf, fam).size() == 1, "too many surfaces: 3 > 2")
	var nan := ok_stats.duplicate()
	nan["finite"] = false
	_check(PropValidator.validate(def, slot, nan, fam).size() == 1, "NaN: a non-finite vertex is one problem")
	var unknown := def.duplicate()
	unknown["surface_materials"] = {"typo": "wood"}
	_check(PropValidator.validate(unknown, slot, ok_stats, fam).size() == 1, "unknown zone: a mapping for a surface the model lacks")
	var bad_family := def.duplicate()
	bad_family["surface_materials"] = {"a": "rubber"}
	_check(PropValidator.validate(bad_family, slot, ok_stats, fam).size() == 1, "family not allowed: rubber in a wood/metal slot")
	var tier := def.duplicate()
	tier["mesh_tier"] = 3
	var foot := def.duplicate()
	foot["footprint"] = [Vector2i(0, 0), Vector2i(1, 0)]
	_check(PropValidator.validate(tier, slot, ok_stats, fam).size() == 1 and PropValidator.validate(foot, slot, ok_stats, fam).size() == 1,
		"the slot owns the tier and the footprint: a model cannot change them")
	_check(PropValidator.validate(def, slot, {"ok": false, "surfaces": []}, fam).size() == 1, "a model that could not be loaded is one problem")
	print("")


func _test_resolution_and_fallback() -> void:
	print("[2] the fallback chain: model -> slot default -> slot generic -> generic box")
	var r := _registry()
	var fits: Dictionary = r.resolve_placement("good_table")
	_check(fits["def"].id == "good_table" and fits["fallback"] == "", "a model that fits is used as it is")
	var huge: Dictionary = r.resolve_placement("huge_table")
	_check(huge["def"].id == "good_table" and huge["fallback"] == "slot_default" and huge["problems"].size() > 0,
		"a model that does not fit becomes the slot's default, with its problem recorded")
	var rubber: Dictionary = r.resolve_placement("rubber_table")
	_check(rubber["def"].id == "good_table" and rubber["fallback"] == "slot_default", "a disallowed material family also falls to the default")
	## The default itself is bad: the slot's generic.
	var r2 := PropRegistry.new()
	r2.family_of = _family
	r2.register_slot(_slot({"default_model": "huge_table"}))
	r2.register(_prop("huge_table", [2.0, 0.6, 0.6]))
	var g: Dictionary = r2.resolve_placement("huge_table")
	_check(g["fallback"] == "slot_generic" and g["def"].id == "generic_table" and g["def"].mesh_size == Vector3(1.0, 0.8, 0.8)
		and g["def"].material_zones["default"] == "generic" and g["def"].mesh_tier == 4 and g["def"].model_path == "",
		"when the default is bad too: the slot's generic (a plain box of the slot's size, generic material, no model)")
	var ghost: Dictionary = r.resolve_placement("ghost_slot_table")
	_check(ghost["fallback"] == "generic" and ghost["def"].mesh_size == Vector3(0.9, 0.6, 0.6) and ghost["def"].slot == "",
		"a prop naming a slot that does not exist: the generic box of its own size")
	_check(r.resolve_placement("nothing_at_all")["def"] == null, "a name matching no prop and no slot resolves to null (the caller skips it loudly)")
	print("")


func _test_several_models_and_slot_placements() -> void:
	print("[3] several models of one slot, placed by slot, gameplay from the slot")
	var r := PropRegistry.new()
	r.family_of = _family
	r.register_slot(_slot({"default_model": ""}))
	for id in ["c_table", "a_table", "b_table"]:
		r.register(_prop(id, [0.9, 0.6, 0.6]))
	var ids: Array = []
	for m in r.models_for_slot("table"):
		ids.append(m.id)
	_check(ids == ["a_table", "b_table", "c_table"], "models_for_slot lists all three, sorted by id")
	var picks: Dictionary = {}
	for n in range(24):
		picks[r.resolve_placement("table", "cell %d" % n)["def"].id] = true
	_check(picks.size() >= 2, "a placement by slot picks among the models by the placement's salt (%d of 3 seen in 24 cells)" % picks.size())
	_check(r.resolve_placement("table", "cell 7")["def"].id == r.resolve_placement("table", "cell 7")["def"].id,
		"the same salt always gives the same model")
	var with_default := _registry()
	_check(with_default.resolve_placement("table", "whatever")["def"].id == "good_table", "a slot with a default model places that model")
	var placed: Dictionary = with_default.resolve_placement("good_table")
	_check(placed["gameplay"] == {"cover": "half", "destructible": false},
		"the gameplay is the SLOT's (half cover), not the model's own (full cover, destructible)")
	var empty := PropRegistry.new()
	empty.family_of = _family
	empty.register_slot(_slot({"default_model": ""}))
	_check(empty.resolve_placement("table")["fallback"] == "slot_generic", "a slot with no model at all still places its generic: no hole in a scene")
	print("")
