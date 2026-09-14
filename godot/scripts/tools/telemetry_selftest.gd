## TEL-01 Test: the Telemetry timeline.
##
## ⚠️ RUNS AS A SCENE, not as a `--script` SceneTree — `Telemetry`, `DevFlags` and
## `VersionInfo` are autoloads, which exist as globals only when a MAIN SCENE runs
## (see `dev_flags_selftest` for the same warning). `run_selftests.py` launches
## `telemetry_selftest.tscn` that way.
##
## ⚠️ `SceneTree.quit(code)` is DEFERRED, so every failing branch also returns.
##
## WHAT THIS PINS, and why each one is here rather than assumed:
##
##  1. Disarmed by default. A build without `TELEMETRY=1` must write nothing —
##     otherwise every measurement ever taken without the flag carries its cost.
##  2. The logcat line's exact shape. `bench_analyze.py` (TEL-07) splits on
##     spaces, so a value with a space in it, or a vector printed as `(3, 4)`,
##     silently shifts every field after it.
##  3. The file sink round-trips: the session header comes first, `seq` has no
##     gaps, the clock never runs backwards, and a vector arrives as an array.
##     A gap in `seq` is how the analyzer counts DROPPED lines, so a sink that
##     skips numbers on its own would report losses that never happened.
##  4. A channel filter drops what it should and never drops `session`.
##  5. Counters belong to one window: taking them resets them.

extends Node

var _failed: bool = false


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("TEL-01 TEST: Telemetry")
	print("=".repeat(70) + "\n")

	## One frame, so every autoload's own _ready() has certainly run.
	await get_tree().process_frame

	if not _test_disarmed_by_default():
		get_tree().quit(1)
		return
	if not _test_line_shape():
		get_tree().quit(1)
		return
	if not _test_file_round_trip():
		get_tree().quit(1)
		return
	if not _test_channel_filter():
		get_tree().quit(1)
		return
	if not _test_counters():
		get_tree().quit(1)
		return

	print("\n✅ TEL-01 SELFTEST PASS\n")
	get_tree().quit(0)


func _test_disarmed_by_default() -> bool:
	if Telemetry == null:
		print("[TEST 1] ❌ Telemetry autoload not found")
		return false
	if DevFlags.on("TELEMETRY"):
		print("[TEST 1] ❌ TELEMETRY is set in this environment — the default cannot be tested")
		return false
	var before: int = int(Telemetry.stats()["events"])
	Telemetry.event("input.tap", {"cell": Vector2i(1, 1)})
	if Telemetry.enabled or Telemetry.wants("input.tap") \
			or int(Telemetry.stats()["events"]) != before:
		print("[TEST 1] ❌ Telemetry wrote while disarmed (enabled=%s)" % Telemetry.enabled)
		return false
	print("[TEST 1] ✅ disarmed by default — an event costs nothing and writes nothing")
	return true


func _test_line_shape() -> bool:
	var line: String = Telemetry.format_line(7, 120, 5000, "input.tap",
		{"cell": Vector2i(3, 4), "zoom": 0.5, "note": "a b", "ok": true,
		"centre": Vector2(10.25, -2.0)})
	var expected: String = "[TEL] 7 120 5000 input.tap cell=3,4 zoom=0.500 note=a_b ok=1 centre=10.2,-2.0"
	if line != expected:
		print("[TEST 2] ❌ line shape\n    got:      %s\n    expected: %s" % [line, expected])
		return false
	print("[TEST 2] ✅ logcat line: %s" % line)
	return true


func _test_file_round_trip() -> bool:
	var path: String = ProjectSettings.globalize_path("user://telemetry_selftest/tel.jsonl")
	Telemetry.start(PackedStringArray(), path, false)
	if Telemetry.file_path() != path:
		print("[TEST 3] ❌ file sink did not open at %s" % path)
		Telemetry.stop()
		return false
	Telemetry.event("input.tap", {"cell": Vector2i(3, 4)})
	Telemetry.event("view.framing", {"canvas": Vector2i(390, 873), "zoom": 0.5})
	Telemetry.event("frame.window", {"ms": 18.6})
	Telemetry.stop()

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("[TEST 3] ❌ cannot read back %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	var records: Array = []
	while not file.eof_reached():
		var raw: String = file.get_line().strip_edges()
		if raw.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(raw)
		if typeof(parsed) != TYPE_DICTIONARY:
			print("[TEST 3] ❌ not a JSON object: %s" % raw)
			file.close()
			return false
		records.append(parsed)
	file.close()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.get_base_dir())

	var kinds: Array = records.map(func(r: Dictionary) -> String: return str(r["kind"]))
	if kinds != ["session", "input.tap", "view.framing", "frame.window"]:
		print("[TEST 3] ❌ records came back as %s" % [kinds])
		return false
	var last_t: float = -1.0
	for i in range(records.size()):
		var record: Dictionary = records[i]
		if int(record["seq"]) != i + 1:
			print("[TEST 3] ❌ seq %d at position %d — a gap reads as a dropped line"
				% [int(record["seq"]), i])
			return false
		if float(record["t_us"]) < last_t:
			print("[TEST 3] ❌ the clock ran backwards at seq %d" % int(record["seq"]))
			return false
		last_t = float(record["t_us"])
	if str(records[0].get("version", "")) != VersionInfo.version_string:
		print("[TEST 3] ❌ session header version '%s' != VersionInfo '%s'"
			% [records[0].get("version", ""), VersionInfo.version_string])
		return false
	var canvas: Variant = records[2].get("canvas")
	if typeof(canvas) != TYPE_ARRAY or canvas != [390.0, 873.0]:
		print("[TEST 3] ❌ a Vector2i field arrived as %s, not [390, 873]" % [canvas])
		return false
	print("[TEST 3] ✅ file sink: session first, seq 1..4 without gaps, clock monotonic, vectors as arrays")
	return true


func _test_channel_filter() -> bool:
	Telemetry.start(PackedStringArray(["input"]), "", false)
	var ok: bool = Telemetry.wants("input.tap") and not Telemetry.wants("view.framing") \
		and Telemetry.wants("session")
	var before: int = int(Telemetry.stats()["events"])
	Telemetry.event("view.framing", {"zoom": 0.5})
	var dropped: bool = int(Telemetry.stats()["events"]) == before
	Telemetry.stop()
	if not ok or not dropped:
		print("[TEST 4] ❌ channel filter — wants ok=%s, filtered event dropped=%s" % [ok, dropped])
		return false
	print("[TEST 4] ✅ TEL_CHANNELS=input keeps input.* and session, drops view.*")
	return true


func _test_counters() -> bool:
	Telemetry.start(PackedStringArray(), "", false)
	Telemetry.count("touch")
	Telemetry.count("touch", 2)
	var first: Dictionary = Telemetry.take_counters()
	var second: Dictionary = Telemetry.take_counters()
	Telemetry.stop()
	Telemetry.count("touch")
	var disarmed: Dictionary = Telemetry.take_counters()
	if first != {"touch": 3} or not second.is_empty() or not disarmed.is_empty():
		print("[TEST 5] ❌ counters — first %s, second %s, while disarmed %s"
			% [first, second, disarmed])
		return false
	print("[TEST 5] ✅ counters sum within a window, reset when taken, ignored when disarmed")
	return true
