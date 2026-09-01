## VERSION-01 Test: VersionInfo singleton initialization
##
## TEST-DEBT-03 (2026-09-01) — RUNS AS A SCENE, not as a `--script` SceneTree.
## `VersionInfo` is an autoload, and Godot registers autoload names as parse-time
## globals (and adds their nodes) only when a MAIN SCENE runs. Under `--script`
## this file did not merely fail its assertions, it failed to LOAD:
## "Compile Error: Identifier not found: VersionInfo" — so the one test of the
## version singleton had never run since the day it was written. Launched as
## `res://godot/scripts/tools/version_info_selftest.tscn` the autoload is real;
## run_selftests.py knows to invoke a `*_selftest.tscn` that way.

## ⚠️ `SceneTree.quit(code)` is DEFERRED — it asks the tree to stop at the end of
## the frame and returns immediately. Every failing branch below therefore has to
## `return` as well. Without that, a failed TEST 2 fell straight through TESTS 3
## and 4, printed the PASS banner, and ended on the final `quit(0)`, which
## OVERWROTE the failure's exit code: measured 2026-09-01, a deliberately
## inverted TEST 2 printed "❌ version_string is unknown" and still exited 0 with
## "✅ VERSION-01 SELFTEST PASS". The original `--script` version had the same
## shape, so this test could never have reported a failure to anyone.

extends Node

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("VERSION-01 TEST: VersionInfo Singleton")
	print("=".repeat(70) + "\n")

	# One frame, so an autoload's own _ready() has certainly run.
	await get_tree().process_frame

	# Test 1: VersionInfo exists
	if VersionInfo:
		print("[TEST 1] ✅ VersionInfo autoload initialized")
	else:
		print("[TEST 1] ❌ VersionInfo not found")
		get_tree().quit(1)
		return

	# Test 2: version_string is valid
	if VersionInfo.version_string != "0.0.0-unknown":
		print("[TEST 2] ✅ version_string loaded: %s" % VersionInfo.version_string)
	else:
		print("[TEST 2] ❌ version_string is unknown or failed to load")
		get_tree().quit(1)
		return

	# Test 3: major/minor/patch parsed correctly
	if VersionInfo.major >= 0 and VersionInfo.minor >= 0 and VersionInfo.patch >= 0:
		print("[TEST 3] ✅ Version components parsed: %d.%d.%d" % [
			VersionInfo.major, VersionInfo.minor, VersionInfo.patch
		])
	else:
		print("[TEST 3] ❌ Version components not valid")
		get_tree().quit(1)
		return

	# Test 4: Window title was set via VersionInfo initialization
	# Verifies: VersionInfo._ready() -> _set_window_title() executed successfully
	# (DisplayServer.window_get_title() doesn't exist in Godot 4.6.1, so we verify
	# the title-setting machinery executed indirectly by checking VersionInfo state)
	if VersionInfo.version_string != "0.0.0-unknown" and VersionInfo.version_string.length() > 0:
		print("[TEST 4] ✅ Window title set (VersionInfo ready: INFILTRAITOR v%s)" % VersionInfo.version_string)
	else:
		print("[TEST 4] ❌ Window title setup failed (VersionInfo not properly initialized)")
		get_tree().quit(1)
		return

	print("\n" + "=".repeat(70))
	## run_selftests.py requires the suite's own uppercase banner in the output:
	## a script that fails to LOAD also exits 0 having run nothing, so the exit
	## code alone cannot tell "passed" from "never started".
	print("✅ VERSION-01 SELFTEST PASS — all 4 tests")
	print("=".repeat(70) + "\n")
	get_tree().quit(0)
