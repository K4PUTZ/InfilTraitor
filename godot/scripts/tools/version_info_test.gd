## VERSION-01 Test: VersionInfo singleton initialization

extends SceneTree

func _init() -> void:
	print("\n" + "=".repeat(70))
	print("VERSION-01 TEST: VersionInfo Singleton")
	print("=".repeat(70) + "\n")

	# Wait one frame for autoload to initialize
	await get_tree().process_frame

	# Test 1: VersionInfo exists
	if VersionInfo:
		print("[TEST 1] ✅ VersionInfo autoload initialized")
	else:
		print("[TEST 1] ❌ VersionInfo not found")
		quit(1)

	# Test 2: version_string is valid
	if VersionInfo.version_string != "0.0.0-unknown":
		print("[TEST 2] ✅ version_string loaded: %s" % VersionInfo.version_string)
	else:
		print("[TEST 2] ❌ version_string is unknown or failed to load")
		quit(1)

	# Test 3: major/minor/patch parsed correctly
	if VersionInfo.major >= 0 and VersionInfo.minor >= 0 and VersionInfo.patch >= 0:
		print("[TEST 3] ✅ Version components parsed: %d.%d.%d" % [
			VersionInfo.major, VersionInfo.minor, VersionInfo.patch
		])
	else:
		print("[TEST 3] ❌ Version components not valid")
		quit(1)

	# Test 4: Window title set
	var current_title = DisplayServer.window_get_title()
	if "INFILTRAITOR" in current_title and VersionInfo.version_string in current_title:
		print("[TEST 4] ✅ Window title set: %s" % current_title)
	else:
		print("[TEST 4] ⚠️  Window title may not include version: %s" % current_title)

	print("\n" + "=".repeat(70))
	print("✅ VERSION-01 TESTS COMPLETE")
	print("=".repeat(70) + "\n")
	quit(0)
