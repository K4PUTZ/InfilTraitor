## TEL-06a Test: the scenario format.
##
## ⚠️ RUNS AS A SCENE — `scenario_runner.gd` names the `Telemetry` autoload, which
## exists as a global only when a MAIN SCENE runs (see `dev_flags_selftest`).
##
## ⚠️ `SceneTree.quit(code)` is DEFERRED, so every failing branch also returns.
##
## WHAT THIS PINS:
##
##  1. A realistic zoom ladder parses into exactly the steps written, arguments
##     typed (a zoom is a float, a GU is a Vector2i), newlines and a trailing `;`
##     tolerated.
##  2. **One bad step rejects the whole scenario**, and the error names the step.
##     The failure this prevents is quiet: a `zoom` that is skipped leaves every
##     later window measuring the previous zoom under a mark naming a new one.
##  3. Each argument check refuses the input it exists for — not merely "some
##     garbage" (assert identity, not absence).
##
## `run()` needs a Room, so it is exercised on the real path, not here.

extends Node

const ScenarioRunnerClass = preload("res://godot/scripts/systems/scenario_runner.gd")


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("TEL-06a TEST: scenario format")
	print("=".repeat(70) + "\n")
	await get_tree().process_frame

	if not _test_ladder_parses():
		get_tree().quit(1)
		return
	if not _test_bad_step_rejects_all():
		get_tree().quit(1)
		return
	if not _test_each_argument_check():
		get_tree().quit(1)
		return

	print("\n✅ TEL-06a SELFTEST PASS\n")
	get_tree().quit(0)


func _test_ladder_parses() -> bool:
	var text: String = "framing portrait; centre agent\nzoom 0.5; wait 20; mark z 050;" \
		+ " centre 12,7; frames 3; window 360x806; capture shot_1; detonate 1; drop2d;" \
		+ " probe after_0; alloc objects 64; alloc bytes 1048576;" \
		+ " capture_at soot_fade 2f fade_2; capture_at CONSEQUENCE 1.5s embers_15; quit;"
	var result: Dictionary = ScenarioRunnerClass.parse(text)
	var steps: Array = result["steps"]
	var ops: Array = steps.map(func(s: Dictionary) -> String: return str(s["op"]))
	var expected_ops: Array = ["framing", "centre", "zoom", "wait", "mark", "centre",
		"frames", "window", "capture", "detonate", "drop2d", "probe", "alloc", "alloc",
		"capture_at", "capture_at", "quit"]
	if not str(result["error"]).is_empty() or ops != expected_ops:
		print("[TEST 1] ❌ ladder — error '%s', ops %s" % [result["error"], ops])
		return false
	var typed: bool = steps[0]["framing"] == "portrait" and steps[1]["cell"] == "agent" \
		and typeof(steps[2]["zoom"]) == TYPE_FLOAT and is_equal_approx(steps[2]["zoom"], 0.5) \
		and is_equal_approx(steps[3]["seconds"], 20.0) and steps[4]["label"] == "z_050" \
		and steps[5]["cell"] == Vector2i(12, 7) and steps[6]["frames"] == 3 \
		and steps[7]["size"] == Vector2i(360, 806) and steps[8]["name"] == "shot_1" \
		and steps[9]["index"] == 1 and steps[11]["name"] == "after_0" \
		and steps[12]["kind"] == "objects" and steps[12]["count"] == 64 \
		and steps[13]["kind"] == "bytes" and steps[13]["count"] == 1048576 \
		and steps[14]["beat"] == "SOOT FADE" and steps[14]["frames"] == 2 \
		and not steps[14].has("seconds") and steps[14]["name"] == "fade_2" \
		and steps[15]["beat"] == "CONSEQUENCE" and typeof(steps[15]["seconds"]) == TYPE_FLOAT \
		and is_equal_approx(steps[15]["seconds"], 1.5) and not steps[15].has("frames") \
		and steps[15]["name"] == "embers_15"
	if not typed:
		print("[TEST 1] ❌ ladder arguments not typed as written: %s" % [steps])
		return false
	print("[TEST 1] ✅ a 17-step ladder parses in order with typed arguments")
	return true


func _test_bad_step_rejects_all() -> bool:
	var result: Dictionary = ScenarioRunnerClass.parse("zoom 0.5; wait 20; zoom abc; wait 20; quit")
	var error: String = result["error"]
	if not (result["steps"] as Array).is_empty() or not error.begins_with("step 3 'zoom abc'"):
		print("[TEST 2] ❌ a bad third step — steps %d, error '%s'"
			% [(result["steps"] as Array).size(), error])
		return false
	print("[TEST 2] ✅ one bad step rejects all five, naming it: %s" % error)
	return true


func _test_each_argument_check() -> bool:
	var cases: Dictionary = {
		"": "no steps",
		"teleport 3": "unknown step 'teleport'",
		"zoom": "'zoom' takes 1 argument(s), got 0",
		"zoom 0": "zoom takes a positive number",
		"wait -1": "wait takes a number of seconds >= 0",
		"frames 2.5": "frames takes a whole number >= 0",
		"framing sideways": "framing takes portrait, landscape or desktop",
		"centre 3;4": "centre takes 'agent' or a GU as x,y",
		"window 360by806": "window takes WxH in pixels",
		"quit now": "'quit' takes 0 argument(s), got 1",
		"mark": "mark takes a label",
		"capture a.b": "capture takes a file name (letters, digits, _ or -)",
		"detonate -1": "detonate takes a dev grenade index >= 0",
		"drop2d now": "'drop2d' takes 0 argument(s), got 1",
		"probe": "'probe' takes 1 argument(s), got 0",
		"probe a.b": "probe takes a file name (letters, digits, _ or -)",
		"alloc objects": "'alloc' takes 2 argument(s), got 1",
		"alloc voxels 10": "alloc takes objects, packed or bytes",
		"alloc packed 0": "alloc takes a count > 0",
		"capture_at LIGHT 2f": "'capture_at' takes 3 argument(s), got 2",
		"capture_at SOOT-FADE 2f x": "capture_at takes a beat name (letters, digits, _ for a space)",
		"capture_at LIGHT 2 x": "capture_at takes an offset in frames (2f) or seconds (1.5s), >= 0",
		"capture_at LIGHT 1.5f x": "capture_at takes an offset in frames (2f) or seconds (1.5s), >= 0",
		"capture_at LIGHT -1s x": "capture_at takes an offset in frames (2f) or seconds (1.5s), >= 0",
		"capture_at LIGHT 2f a.b": "capture_at takes a file name (letters, digits, _ or -)",
	}
	for text: String in cases:
		var error: String = ScenarioRunnerClass.parse(text)["error"]
		if not error.ends_with(str(cases[text])):
			print("[TEST 3] ❌ '%s' → '%s', expected to end with '%s'" % [text, error, cases[text]])
			return false
	print("[TEST 3] ✅ %d argument checks each refuse their own input" % cases.size())
	return true
