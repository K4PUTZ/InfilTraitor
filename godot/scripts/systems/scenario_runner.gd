## ScenarioRunner — a measured session a finger does not have to perform.
##
## TEL-06a (DEVICE_DIAGNOSTICS_MASTER_PLAN §14). The benchmark detonates by
## calling `detonate_active()` directly, so it never ran the framing, zoom or pan
## a player does, and DIAG-16 (§10.16) showed those decide the board's cost more
## than the blast does. A scenario is a list of the steps a human would take,
## written as DATA and run through the same Room entry points the HUD and the
## camera gestures reach.
##
## FORMAT — one `DevFlags` value, `SCENARIO`, steps separated by `;` (or newlines):
##
##     SCENARIO=framing portrait; centre agent; zoom 0.5; wait 20; mark z050; quit
##
##   framing portrait|landscape|desktop   M portrait, M landscape (§13 Q5 (a)), or D
##   zoom <z>                             through the camera's own clamp
##   centre agent | centre <x>,<y>        camera onto the agent or a GU
##   wait <seconds>                       real time
##   frames <n>                           rendered frames
##   mark <label>                         a `scenario.mark` boundary for the analyzer
##   window <W>x<H>                       desktop only: emulate a phone's aspect
##   detonate <index>                     dev grenade #index, camera on it, menu path;
##                                        waits for the blast to end (TEL-06b)
##   capture <name>                       the root viewport to captures/<name>.png
##                                        (the external files dir on Android)
##   quit                                 end the process (the harness waits on it)
##
## EVERY STEP IS ON THE TIMELINE as `scenario.step`, which is what lets one analyzer
## cut windows out of a scripted run and a hand run the same way.
##
## ⚠️ LOUD ON A BAD SCENARIO. `parse()` rejects the WHOLE scenario on the first bad
## step rather than skipping it. A skipped `zoom` would leave every later window
## measuring the previous zoom under a mark that names a different one — a table
## that is wrong and looks right.
##
## TEL-06b adds the action steps (aim, confirm, end turn) once the analyzer exists.
extends Node

## op -> how many arguments it takes. `mark` takes the rest of the line.
const ARITY: Dictionary = {
	"framing": 1, "zoom": 1, "centre": 1, "wait": 1, "frames": 1,
	"mark": -1, "window": 1, "capture": 1, "detonate": 1, "quit": 0,
}
const FRAMINGS: PackedStringArray = ["portrait", "landscape", "desktop"]


## `{"steps": Array, "error": String}` — `error` is empty exactly when the whole
## scenario is valid, and `steps` is empty whenever it is not.
static func parse(text: String) -> Dictionary:
	var steps: Array = []
	for chunk in text.replace("\n", ";").split(";", false):
		var raw: String = chunk.strip_edges()
		if raw.is_empty():
			continue
		var tokens: PackedStringArray = raw.split(" ", false)
		var op: String = tokens[0].to_lower()
		var arg: String = tokens[1] if tokens.size() > 1 else ""
		var step: Dictionary = {"op": op, "text": raw}
		var err: String = ""
		if not ARITY.has(op):
			err = "unknown step '%s'" % op
		elif int(ARITY[op]) >= 0 and tokens.size() - 1 != int(ARITY[op]):
			err = "'%s' takes %d argument(s), got %d" % [op, int(ARITY[op]), tokens.size() - 1]
		else:
			err = _parse_args(op, arg, tokens, step)
		if not err.is_empty():
			return {"steps": [], "error": "step %d '%s': %s" % [steps.size() + 1, raw, err]}
		steps.append(step)
	if steps.is_empty():
		return {"steps": [], "error": "no steps"}
	return {"steps": steps, "error": ""}


## Run parsed steps against a Room. Returns when the last step has run, or at the
## first step that cannot (reported loudly, and marked `scenario.abort`).
func run(room: Node, steps: Array) -> void:
	Telemetry.event("scenario.start", {"steps": steps.size()})
	print("[SCENARIO] %d step(s)" % steps.size())
	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		Telemetry.event("scenario.step", {"i": i + 1, "step": str(step["text"])})
		print("[SCENARIO] %d/%d %s" % [i + 1, steps.size(), step["text"]])
		var ok: bool = await _execute(room, step)
		if not ok:
			Telemetry.event("scenario.abort", {"i": i + 1})
			return
	Telemetry.event("scenario.end")


static func _parse_args(op: String, arg: String, tokens: PackedStringArray,
		step: Dictionary) -> String:
	match op:
		"framing":
			if not FRAMINGS.has(arg):
				return "framing takes portrait, landscape or desktop"
			step["framing"] = arg
		"zoom":
			if not arg.is_valid_float() or float(arg) <= 0.0:
				return "zoom takes a positive number"
			step["zoom"] = float(arg)
		"centre":
			if arg == "agent":
				step["cell"] = "agent"
			else:
				var parts: PackedStringArray = arg.split(",")
				if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
					return "centre takes 'agent' or a GU as x,y"
				step["cell"] = Vector2i(int(parts[0]), int(parts[1]))
		"wait":
			if not arg.is_valid_float() or float(arg) < 0.0:
				return "wait takes a number of seconds >= 0"
			step["seconds"] = float(arg)
		"frames":
			if not arg.is_valid_int() or int(arg) < 0:
				return "frames takes a whole number >= 0"
			step["frames"] = int(arg)
		"mark":
			if tokens.size() < 2:
				return "mark takes a label"
			step["label"] = "_".join(tokens.slice(1))
		"window":
			var size: PackedStringArray = arg.to_lower().split("x")
			if size.size() != 2 or not size[0].is_valid_int() or not size[1].is_valid_int() \
					or int(size[0]) <= 0 or int(size[1]) <= 0:
				return "window takes WxH in pixels"
			step["size"] = Vector2i(int(size[0]), int(size[1]))
		"capture":
			if not arg.is_valid_filename() or arg.contains("."):
				return "capture takes a file name (letters, digits, _ or -)"
			step["name"] = arg
		"detonate":
			if not arg.is_valid_int() or int(arg) < 0:
				return "detonate takes a dev grenade index >= 0"
			step["index"] = int(arg)
	return ""


func _execute(room: Node, step: Dictionary) -> bool:
	match str(step["op"]):
		"framing":
			if not room.has_method("set_framing"):
				return _fail(step, "Room has no set_framing()")
			room.call("set_framing", step["framing"], "scenario")
		"zoom":
			if not room.has_method("set_camera_zoom"):
				return _fail(step, "Room has no set_camera_zoom()")
			room.call("set_camera_zoom", step["zoom"], "scenario")
		"centre":
			if not room.has_method("centre_camera_on"):
				return _fail(step, "Room has no centre_camera_on()")
			room.call("centre_camera_on", step["cell"])
		"wait":
			await room.get_tree().create_timer(float(step["seconds"])).timeout
		"frames":
			for _f in range(int(step["frames"])):
				await room.get_tree().process_frame
		"mark":
			Telemetry.event("scenario.mark", {"label": step["label"]})
		"window":
			if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
				## The OS window IS the screen on a handheld; there is nothing to resize.
				push_warning("[ScenarioRunner] '%s' ignored on a handheld" % step["text"])
			else:
				DisplayServer.window_set_size(step["size"])
				await room.get_tree().process_frame
		"capture":
			await RenderingServer.frame_post_draw
			var image: Image = room.get_viewport().get_texture().get_image()
			var dir: String = DevFlags.external_files_dir()
			if dir.is_empty():
				dir = ProjectSettings.globalize_path("user://")
			var path: String = "%s/captures/%s.png" % [dir.trim_suffix("/"), step["name"]]
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var err: int = image.save_png(path)
			if err != OK:
				return _fail(step, "could not save %s (error %d)" % [path, err])
			Telemetry.event("scenario.capture", {"path": path})
			print("[SCENARIO] captured %s" % path)
		"detonate":
			if not room.has_signal("scenario_detonation_done") or not room.has_method("scenario_detonate"):
				return _fail(step, "Room has no scenario_detonate()")
			var done: Signal = Signal(room, "scenario_detonation_done")
			room.call_deferred("scenario_detonate", int(step["index"]))
			var detonated: bool = await done
			if not detonated:
				return _fail(step, "the detonation did not complete (see the error above)")
		"quit":
			## `quit()` is deferred, so `run()` still reaches its own `scenario.end`
			## after this step — emitting one here as well wrote it twice.
			room.get_tree().quit(0)
	return true


func _fail(step: Dictionary, detail: String) -> bool:
	push_error("[ScenarioRunner] step '%s': %s" % [step["text"], detail])
	return false
