## AUDIT 2026-10-07 — the checkpoint save is written through `SaveState.write_text_atomic()`: a sibling `.tmp` renamed over the
## old file, so a kill mid-write never leaves a truncated save (the checkpoint is the only state that survives the app being killed).
extends SceneTree

const SaveStateClass = preload("res://godot/scripts/systems/save_state.gd")

const PATH := "user://selftest_save_state_file.json"

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _init() -> void:
	print("\n== SAVE STATE FILE SELFTEST ==\n")
	_check(SaveStateClass.write_text_atomic(PATH, "{\"a\": 1}"), "a first save is written")
	_check(_read(PATH) == "{\"a\": 1}", "and reads back exactly")
	_check(SaveStateClass.write_text_atomic(PATH, "{\"a\": 2}"), "a second save replaces it")
	_check(_read(PATH) == "{\"a\": 2}", "and the new content is what is on disk")
	_check(not FileAccess.file_exists(PATH + ".tmp"), "no .tmp is left behind")
	## A write that cannot happen (a directory that does not exist) fails loudly and leaves the old save alone.
	_check(not SaveStateClass.write_text_atomic("user://no_such_dir_selftest/save.json", "x"), "a write into a missing directory fails")
	_check(_read(PATH) == "{\"a\": 2}", "and the existing save is untouched")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
