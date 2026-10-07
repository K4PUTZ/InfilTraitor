## AUDIT 2026-10-07 — a prop's `model` is loaded with `load()` + `instantiate()` (`PropModelFit`), and `PropRegistry` reads prop JSON from
## `user://props/` too. A scene there can carry an embedded GDScript, so a player-supplied prop could run code (PROP_PIPELINE_PLAN: a
## player's file never goes through `ResourceLoader`). The loader must refuse anything but a shipped glTF/GLB under `res://`, and must
## refuse it BEFORE loading. The attack here is real: a `.tscn` in `user://` whose script raises a flag in `_init()`.
extends SceneTree

const PropModelFitClass = preload("res://godot/scripts/geometry/prop_model_fit.gd")

const EVIL_PATH := "user://selftest_prop_model_path.tscn"
const FLAG := &"selftest_prop_model_path_ran"
const SHIPPED_MODEL := "res://ASSETS/props/wooden_table_02/wooden_table_02_1k.gltf"

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _init() -> void:
	print("\n== PROP MODEL PATH SELFTEST ==\n")
	var scene_text := "\n".join([
		"[gd_scene load_steps=2 format=3]",
		"",
		"[sub_resource type=\"GDScript\" id=\"s\"]",
		"script/source = \"extends Node3D\nfunc _init():\n\tEngine.set_meta(&\\\"%s\\\", true)\n\"" % FLAG,
		"",
		"[node name=\"Evil\" type=\"Node3D\"]",
		"script = SubResource(\"s\")",
		""])
	var f := FileAccess.open(EVIL_PATH, FileAccess.WRITE)
	f.store_string(scene_text)
	f.close()

	## Control: the attack file is a working payload when loaded directly (otherwise a refusal proves nothing).
	var direct := load(EVIL_PATH) as PackedScene
	if direct != null:
		direct.instantiate().free()
	_check(Engine.has_meta(FLAG), "control: the payload runs when the scene is loaded and instantiated directly")
	if Engine.has_meta(FLAG):
		Engine.remove_meta(FLAG)

	PropModelFitClass.clear_cache()
	var evil: Dictionary = PropModelFitClass.fit(EVIL_PATH, Vector3.ZERO, Vector3.ONE)
	_check(not bool(evil.get("ok", true)), "a user:// scene as a prop model is refused")
	_check(not Engine.has_meta(FLAG), "and its script never ran")
	_check(not PropModelFitClass.is_allowed_model_path("res://ASSETS/props/x.tscn"), "a res:// scene is not a model either")
	_check(not PropModelFitClass.is_allowed_model_path("user://props/x.glb"), "a user:// GLB is refused (the .iprop route is the player's)")
	_check(PropModelFitClass.is_allowed_model_path(SHIPPED_MODEL), "a shipped res:// glTF is allowed")

	var real: Dictionary = PropModelFitClass.fit(SHIPPED_MODEL, Vector3.ZERO, Vector3.ONE)
	_check(bool(real.get("ok", false)), "the shipped table model still fits")

	PropModelFitClass.clear_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EVIL_PATH))
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
