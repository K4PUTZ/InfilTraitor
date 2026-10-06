## R3D-SURFACES tags — the closed vocabulary, the material tags and the patch rules (`res://surfaces/rules.json`), against the real
## material files and the art on disk: every tag a material declares is in the vocabulary, every patch kind that has art has a rule,
## and the rule says what the catalog says (no leaf in the desert, a leaf on grass, nothing for a kind with no rule).
extends SceneTree

const SurfaceRulesClass = preload("res://godot/scripts/systems/surface_rules.gd")
const MaterialRegistryClass = preload("res://godot/scripts/systems/material_registry.gd")

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== SURFACE RULES SELFTEST ==\n")
	_check(SurfaceRulesClass.vocabulary().size() > 0, "the vocabulary loads (%d tags)" % SurfaceRulesClass.vocabulary().size())
	var registry = MaterialRegistryClass.new()
	registry.load_from_disk()
	var tagged: int = 0
	for id: String in registry.registry:
		var tags: PackedStringArray = registry.registry[id].tags
		tagged += 1 if not tags.is_empty() else 0
		for tag in tags:
			_check(SurfaceRulesClass.vocabulary().has(tag), "%s's tag '%s' is in the vocabulary" % [id, tag])
	_check(tagged >= 10, "at least 10 materials are tagged (%d)" % tagged)
	var dir := DirAccess.open("res://ASSETS/materials/_generic/decals")
	var kinds: Dictionary = {}
	if dir != null:
		for f in dir.get_files():
			if f.begins_with("decal_patch_") and f.ends_with("_0.png"):
				kinds[f.trim_prefix("decal_patch_").trim_suffix("_0.png")] = true
	_check(not kinds.is_empty(), "there is patch art on disk (%s)" % str(kinds.keys()))
	for kind: String in kinds:
		_check(SurfaceRulesClass.has_rule(kind), "the patch kind '%s' has a rule" % kind)
	var grass: PackedStringArray = registry.registry["grass"].tags
	var sand: PackedStringArray = registry.registry["sand"].tags
	_check(SurfaceRulesClass.reason_against("leaf", grass) == "", "a leaf may lie on grass")
	_check(SurfaceRulesClass.reason_against("leaf", sand) != "", "a leaf may NOT lie on sand (arid): '%s'" % SurfaceRulesClass.reason_against("leaf", sand))
	_check(SurfaceRulesClass.reason_against("no_such_kind", grass) != "", "a kind with no rule is never allowed")
	_check(SurfaceRulesClass.checked_tags("test", ["soil", "no_such_tag"]).size() == 1, "an unknown tag is dropped (and reported loudly)")
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
