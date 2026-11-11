## DIAG-01 Test: the DevFlags seam.
##
## ⚠️ RUNS AS A SCENE, not as a `--script` SceneTree — `DevFlags` is an autoload,
## and Godot registers autoload names as parse-time globals only when a MAIN
## SCENE runs. Under `--script` this file would fail to LOAD, not merely fail its
## assertions. `run_selftests.py` knows to launch a `*_selftest.tscn` that way.
## (`version_info_selftest` carries the same warning for the same reason.)
##
## ⚠️ `SceneTree.quit(code)` is DEFERRED, so every failing branch must `return`
## as well — otherwise a later `quit(0)` OVERWRITES the failure's exit code and
## the suite reports PASS.
##
## WHAT THIS PINS, and why each one is here rather than assumed:
##
##  1. The autoload exists and answers.
##  2. **The environment wins over the file.** This is the property that makes
##     the seam safe to introduce at all: desktop behaviour has to stay
##     bit-identical, so a stale flags file must never override what a developer
##     typed on the command line.
##  3. An unset flag returns the caller's fallback, and `on()` is false — the
##     project's `== "1"` convention, not "any non-empty value".
##  4. `num()` refuses a non-integer instead of silently yielding 0. A flag typo
##     that reads as zero is the kind of defect that passes for the whole life of
##     the bug.

extends Node

const FLAG_ENV: String = "INFILTRAITOR_SELFTEST_DEVFLAG"
const FLAG_NAME: String = "SELFTEST_DEVFLAG"

var _failed: bool = false


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("DIAG-01 TEST: DevFlags")
	print("=".repeat(70) + "\n")

	## One frame, so the autoload's own _ready() has certainly run.
	await get_tree().process_frame

	if not _test_autoload_present():
		get_tree().quit(1)
		return
	if not _test_environment_wins():
		get_tree().quit(1)
		return
	if not _test_unset_is_fallback():
		get_tree().quit(1)
		return
	if not _test_num_rejects_garbage():
		get_tree().quit(1)
		return
	if not _test_registry():
		get_tree().quit(1)
		return

	print("\n✅ DIAG-01 SELFTEST PASS\n")
	get_tree().quit(0)


func _test_autoload_present() -> bool:
	if DevFlags == null:
		print("[TEST 1] ❌ DevFlags autoload not found")
		return false
	print("[TEST 1] ✅ DevFlags autoload initialized (source: '%s')"
		% DevFlags.source_path())
	return true


## The whole point of the resolution order. Set the real environment variable and
## require that it is what comes back — if the file ever won, every existing
## `INFILTRAITOR_X=1 godot ...` invocation in the docs and the capture harness
## would become a suggestion rather than an instruction.
func _test_environment_wins() -> bool:
	OS.set_environment(FLAG_ENV, "1")
	var on_now: bool = DevFlags.on(FLAG_NAME)
	var raw: String = DevFlags.value(FLAG_NAME, "unset")
	OS.set_environment(FLAG_ENV, "")
	if not on_now or raw != "1":
		print("[TEST 2] ❌ environment not honoured — on()=%s value()='%s'"
			% [on_now, raw])
		return false
	print("[TEST 2] ✅ the environment resolves first (on()=true, value()='1')")
	return true


func _test_unset_is_fallback() -> bool:
	var value: String = DevFlags.value("SELFTEST_DEVFLAG_NEVER_SET", "fallback")
	var on_now: bool = DevFlags.on("SELFTEST_DEVFLAG_NEVER_SET")
	if value != "fallback" or on_now:
		print("[TEST 3] ❌ unset flag misbehaved — value()='%s' on()=%s"
			% [value, on_now])
		return false
	print("[TEST 3] ✅ an unset flag returns its fallback and is not on()")
	return true


## A flag that is set to something meaningless must not read as 0 — that is a
## defect that passes silently for as long as the typo survives.
func _test_num_rejects_garbage() -> bool:
	OS.set_environment(FLAG_ENV, "not-a-number")
	var n: int = DevFlags.num(FLAG_NAME, 620)
	OS.set_environment(FLAG_ENV, "")
	if n != 620:
		print("[TEST 4] ❌ num() returned %d for a non-integer; expected the fallback 620" % n)
		return false
	print("[TEST 4] ✅ num() rejects a non-integer and keeps the fallback (620)")
	return true


## HERITAGE T3 (2026-11-11) — the registry: a registered name is known, an unregistered one is not (and
## `known()` reports it loudly), and a read with no fallback of its own gets the registry's default.
## `FLAME_STYLE` is used because its default ("both") is not empty, so "the default" and "nothing" differ.
func _test_registry() -> bool:
	if not DevFlag.known(FLAG_NAME):
		print("[TEST 5] ❌ '%s' is registered but known() says no" % FLAG_NAME)
		return false
	print("[TEST 5] (the next ERROR line is expected: an unregistered name is reported)")
	if DevFlag.known("SELFTEST_NOT_A_REGISTERED_FLAG"):
		print("[TEST 5] ❌ an unregistered name was accepted")
		return false
	if not OS.get_environment("INFILTRAITOR_FLAME_STYLE").is_empty():
		print("[TEST 5] ⚠️ FLAME_STYLE is set in this environment: the default check is skipped")
	elif DevFlag.value("FLAME_STYLE") != "both":
		print("[TEST 5] ❌ value() with no fallback read '%s', not the registry's default 'both'"
			% DevFlag.value("FLAME_STYLE"))
		return false
	if DevFlag.value("FLAME_STYLE", "x") != "x" and OS.get_environment("INFILTRAITOR_FLAME_STYLE").is_empty():
		print("[TEST 5] ❌ a caller's fallback did not win over the registry's default")
		return false
	print("[TEST 5] ✅ the registry knows its flags, refuses an unknown one, and supplies the default")
	return true

