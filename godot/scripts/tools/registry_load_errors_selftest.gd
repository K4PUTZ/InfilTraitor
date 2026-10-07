## AUDIT 2026-10-07 — the catalogues read their rows through `JsonFile`: a row that does not parse, has no `id`, or carries a vector
## field of the wrong shape is reported WITH its path (push_error + the registry's `load_errors`), never dropped in silence; a bomb past
## `BombDef.MAX_RING` is cut, loudly. Red before this: a broken `user://bombs/*.json` printed only Godot's path-less
## "Parse JSON failed. Error at line 0", and an id-less row printed nothing.
## (1) the SHIPPED data loads with zero errors in every catalogue; (2) broken user-tier rows are each reported and the good rows survive.
extends SceneTree

var _failures: int = 0
var _made_dirs: Array[String] = []
var _made_files: Array[String] = []


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _write(path: String, text: String) -> void:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		_made_dirs.append(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	_made_files.append(path)


func _mentions(errors: Array, needle: String) -> bool:
	for e in errors:
		if String(e).contains(needle):
			return true
	return false


func _init() -> void:
	print("\n== REGISTRY LOAD ERRORS SELFTEST ==\n")
	print("[1] the shipped catalogues load clean\n")
	var bombs := BombRegistry.new()
	bombs.load_from_disk()
	var weapons := WeaponRegistry.new()
	weapons.load_from_disk()
	var props := PropRegistry.new()
	props.load_from_disk()
	var materials := MaterialRegistry.new()
	materials.load_from_disk()
	MaterialResistanceTable.destroy_factor("concrete")
	_check(bombs.load_errors.is_empty() and bombs.registry.has("frag_grenade"), "bombs: 0 errors, frag_grenade present (%s)" % [bombs.load_errors])
	_check(weapons.load_errors.is_empty() and weapons.registry.size() > 0, "weapons: 0 errors, %d rows (%s)" % [weapons.registry.size(), weapons.load_errors])
	_check(props.load_errors.is_empty() and props.registry.size() > 0, "props and slots: 0 errors, %d props (%s)" % [props.registry.size(), props.load_errors])
	_check(materials.load_errors.is_empty() and materials.registry.size() > 10, "materials: 0 errors, %d rows (%s)" % [materials.registry.size(), materials.load_errors])
	_check(MaterialResistanceTable.load_errors.is_empty(), "resistance table: 0 errors (%s)" % [MaterialResistanceTable.load_errors])

	print("\n[2] broken user-tier rows are reported, by path\n")
	_write("user://bombs/selftest_broken.json", "{ \"id\": \"selftest_broken\", oops")
	_write("user://bombs/selftest_noid.json", "{\"ring_multipliers\": [1.0]}")
	var wide := []
	for i in range(40):
		wide.append(1.0)
	_write("user://bombs/selftest_wide.json", JSON.stringify({"id": "selftest_wide", "ring_multipliers": wide}))
	_write("user://props/selftest_badrot.json", JSON.stringify({"id": "selftest_badrot", "model_rotation_deg": [90.0], "mesh_size": "big"}))
	var bombs2 := BombRegistry.new()
	bombs2.load_from_disk()
	_check(_mentions(bombs2.load_errors, "selftest_broken.json"), "a bomb row that does not parse is reported with its path")
	_check(_mentions(bombs2.load_errors, "selftest_noid.json"), "a bomb row with no id is reported with its path")
	_check(bombs2.registry.has("frag_grenade"), "the shipped grenade still loads beside them")
	_check(bombs2.registry.has("selftest_wide") and bombs2.registry["selftest_wide"].ring_multipliers.size() == BombDef.MAX_RING + 1,
		"a 40-ring bomb is cut to MAX_RING %d" % BombDef.MAX_RING)
	_check(_mentions(bombs2.load_errors, "past MAX_RING"), "and the cut is reported")
	var props2 := PropRegistry.new()
	props2.load_from_disk()
	_check(props2.registry.has("selftest_badrot"), "a prop with a malformed vector still loads whole")
	if props2.registry.has("selftest_badrot"):
		_check(props2.registry["selftest_badrot"].model_rotation_deg == Vector3.ZERO, "its bad model_rotation_deg falls back to zero")
		_check(props2.registry["selftest_badrot"].mesh_size == Vector3.ONE, "its bad mesh_size falls back to one")
	_check(_mentions(props2.load_errors, "model_rotation_deg") and _mentions(props2.load_errors, "mesh_size"), "both bad fields are reported")

	for path in _made_files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for dir in _made_dirs:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
