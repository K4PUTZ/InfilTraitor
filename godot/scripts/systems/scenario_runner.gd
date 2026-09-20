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
##   capture_at <beat> <offset> <name>    RENDER3D R3D-0: ARM a capture for INSIDE the
##                                        next blast — taken <offset> after the Room
##                                        names <beat> (`Room.blast_beat`). The beat
##                                        is written with `_` for a space
##                                        (`SOOT_FADE`); the offset is frames (`2f`)
##                                        or seconds of process delta (`1.5s`) — the
##                                        clock the consequence channel and the
##                                        embers age on, so a 2D and a 3D run at
##                                        very different frame times photograph the
##                                        same moment of the effect. Arm it BEFORE
##                                        `detonate`, which returns only once the
##                                        blast is over.
##   drop2d                               DIAG-23 instrument: clear the hidden 2D
##                                        board's cells under a 3D board (RENDER3D=1)
##   probe <name>                         RENDER3D R3D-0: a `BoardProbe` dump of the
##                                        voxel state to probes/<name>.txt (same dir
##                                        as capture); compare with board_probe.py
##   alloc objects|packed|bytes <count>   RENDER3D R3D-0 instrument: hold <count>
##                                        `Voxel` objects / packed int32 cells / bytes
##                                        until quit, for --mem-poll to read
##   probe_store <name>                   RENDER3D R3D-1b: the same dump, read from the
##                                        shadow `VoxelStore` (`VOXEL_STORE=1`)
##   shoot <guard index>                  R3D-1b gate: a shot through the menu entry points
##   reload                               R3D-1b gate: F2's `load_map()` on the current map
##   save_restore                         R3D-1b gate: SaveState capture → reload → restore
##   perspective N|E|S|W                  R3D-1b gate: a rotation through `_set_perspective()`
##   passages <label>                     RENDER3D R3D-1c: every edge's passage class, as a
##                                        count and a digest
##   occupancy_compare <label>            RENDER3D R3D-1c: the light field's occupancy from
##                                        placed tiles vs from the store, per level
##   store_spike <reps>                   RENDER3D R3D-1a: build every candidate voxel store
##                                        layout from the live registries, check each
##                                        against today's objects, and time the three hot
##                                        readers `reps` times (`StoreLayoutSpike`)
##   occ_bench <x,y> <x,y> <reps>         R3D-7 instrument: put the agent on the two cells in turn <reps>
##                                        times through the real occlusion path (`_recompute_occlusion`),
##                                        one frame apart, and print the set / 3D cutaway / total cost
##   quit                                end the process (the harness waits on it)
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
	"mark": -1, "window": 1, "capture": 1, "detonate": 1, "drop2d": 0, "quit": 0,
	"probe": 1, "alloc": 2, "capture_at": 3, "store_spike": 1,
	"probe_store": 1, "shoot": 1, "reload": 0, "save_restore": 0, "perspective": 1,
	"occupancy_compare": 1, "passages": 1, "occ_bench": 3,
}
const FRAMINGS: PackedStringArray = ["portrait", "landscape", "desktop"]
const ALLOC_KINDS: PackedStringArray = ["objects", "packed", "bytes"]
const BEAT_TOKEN_PATTERN: String = "^[A-Za-z0-9_]+$"
const StoreLayoutSpikeClass = preload("res://godot/scripts/spikes/store_layout_spike.gd")


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
		"capture", "probe", "probe_store", "occupancy_compare", "passages":
			if not arg.is_valid_filename() or arg.contains("."):
				return "%s takes a file name (letters, digits, _ or -)" % op
			step["name"] = arg
		"occ_bench":
			for k: int in [1, 2]:
				var xy: PackedStringArray = tokens[k].split(",")
				if xy.size() != 2 or not xy[0].is_valid_int() or not xy[1].is_valid_int():
					return "occ_bench takes two cells as x,y"
				step["cell%d" % k] = Vector2i(int(xy[0]), int(xy[1]))
			if not tokens[3].is_valid_int() or int(tokens[3]) < 1:
				return "occ_bench takes a repetition count >= 1"
			step["reps"] = int(tokens[3])
		"capture_at":
			if RegEx.create_from_string(BEAT_TOKEN_PATTERN).search(arg) == null:
				return "capture_at takes a beat name (letters, digits, _ for a space)"
			var offset: String = tokens[2].to_lower()
			var amount: String = offset.left(-1)
			if offset.ends_with("f") and amount.is_valid_int() and int(amount) >= 0:
				step["frames"] = int(amount)
			elif offset.ends_with("s") and amount.is_valid_float() and float(amount) >= 0.0:
				step["seconds"] = float(amount)
			else:
				return "capture_at takes an offset in frames (2f) or seconds (1.5s), >= 0"
			if not tokens[3].is_valid_filename() or tokens[3].contains("."):
				return "capture_at takes a file name (letters, digits, _ or -)"
			step["beat"] = arg.to_upper().replace("_", " ")
			step["name"] = tokens[3]
		"detonate":
			if not arg.is_valid_int() or int(arg) < 0:
				return "detonate takes a dev grenade index >= 0"
			step["index"] = int(arg)
		"shoot":
			if not arg.is_valid_int() or int(arg) < 0:
				return "shoot takes a guard index >= 0"
			step["index"] = int(arg)
		"perspective":
			if not ["N", "E", "S", "W"].has(arg.to_upper()):
				return "perspective takes N, E, S or W"
			step["direction"] = arg.to_upper()
		"store_spike":
			if not arg.is_valid_int() or int(arg) < 1:
				return "store_spike takes a repetition count >= 1"
			step["reps"] = int(arg)
		"alloc":
			if not ALLOC_KINDS.has(arg):
				return "alloc takes objects, packed or bytes"
			if not tokens[2].is_valid_int() or int(tokens[2]) <= 0:
				return "alloc takes a count > 0"
			step["kind"] = arg
			step["count"] = int(tokens[2])
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
			var problem: String = _save_capture(room, str(step["name"]))
			if not problem.is_empty():
				return _fail(step, problem)
		"capture_at":
			if not room.has_signal("blast_beat"):
				return _fail(step, "Room has no blast_beat signal")
			## Once per runner: the listener is bound, so `is_connected()` against the
			## unbound method would never match and a second arm would connect twice.
			if not _listening:
				room.connect("blast_beat", _on_blast_beat.bind(room))
				_listening = true
			_armed.append({"step": step, "state": "armed"})
		"probe":
			if not room.has_method("scenario_board_probe"):
				return _fail(step, "Room has no scenario_board_probe()")
			var probe_path: String = _output_path("probes", "%s.txt" % step["name"])
			var summary: Dictionary = room.call("scenario_board_probe", probe_path, step["name"])
			if summary.is_empty():
				return _fail(step, "no dump was written (see the error above)")
		"alloc":
			_alloc(step)
		"probe_store":
			if not room.has_method("scenario_board_probe_store"):
				return _fail(step, "Room has no scenario_board_probe_store()")
			var store_path: String = _output_path("probes", "%s.txt" % step["name"])
			if (room.call("scenario_board_probe_store", store_path, step["name"]) as Dictionary).is_empty():
				return _fail(step, "no store dump was written (see the error above)")
		"passages":
			if not room.has_method("scenario_passages"):
				return _fail(step, "Room has no scenario_passages()")
			if not bool(room.call("scenario_passages", str(step["name"]))):
				return _fail(step, "no passages were computed (see the error above)")
		"occupancy_compare":
			if not room.has_method("scenario_occupancy_compare"):
				return _fail(step, "Room has no scenario_occupancy_compare()")
			if int(room.call("scenario_occupancy_compare", str(step["name"]))) < 0:
				return _fail(step, "no comparison was made (see the error above)")
		"shoot", "reload", "save_restore", "perspective":
			var method: String = "scenario_" + str(step["op"])
			if not room.has_method(method):
				return _fail(step, "Room has no %s()" % method)
			var ok: bool = false
			match str(step["op"]):
				"shoot":
					ok = await room.call(method, int(step["index"]))
				"perspective":
					ok = await room.call(method, str(step["direction"]))
				_:
					ok = await room.call(method)
			if not ok:
				return _fail(step, "%s() did not complete (see the error above)" % method)
		"store_spike":
			var summary: Dictionary = await StoreLayoutSpikeClass.new().run(room, int(step["reps"]))
			if summary.is_empty():
				return _fail(step, "the spike built nothing (see the error above)")
		"detonate":
			if not room.has_signal("scenario_detonation_done") or not room.has_method("scenario_detonate"):
				return _fail(step, "Room has no scenario_detonate()")
			var done: Signal = Signal(room, "scenario_detonation_done")
			room.call_deferred("scenario_detonate", int(step["index"]))
			var detonated: bool = await done
			if not detonated:
				return _fail(step, "the detonation did not complete (see the error above)")
		"occ_bench":
			if not room.has_method("scenario_occ_bench"):
				return _fail(step, "Room has no scenario_occ_bench()")
			await room.call("scenario_occ_bench", step["cell1"], step["cell2"], int(step["reps"]))
		"drop2d":
			if not room.has_method("scenario_drop_2d_board"):
				return _fail(step, "Room has no scenario_drop_2d_board()")
			if not bool(room.call("scenario_drop_2d_board")):
				return _fail(step, "the 2D board was not dropped (see the error above)")
			## One drawn frame, so the cleared quadrants have left the renderer before
			## the next step measures anything.
			await RenderingServer.frame_post_draw
		"quit":
			## Loud, not skipped: a capture that never fired is a missing picture a
			## pair would otherwise be compared against in silence.
			for arm: Dictionary in _armed:
				if str(arm["state"]) != "taken":
					push_error("[ScenarioRunner] '%s' was %s at quit — beat '%s' %s" % [
						arm["step"]["text"], arm["state"], arm["step"]["beat"],
						"never named" if str(arm["state"]) == "armed" else "named, capture not taken"])
			## `quit()` is deferred, so `run()` still reaches its own `scenario.end`
			## after this step — emitting one here as well wrote it twice.
			room.get_tree().quit(0)
	return true


## The root viewport as it was last drawn, to captures/<name>.png. Returns why it was
## not saved, or "" when it was. Call after `RenderingServer.frame_post_draw`.
func _save_capture(room: Node, file_stem: String) -> String:
	var image: Image = room.get_viewport().get_texture().get_image()
	var path: String = _output_path("captures", "%s.png" % file_stem)
	var err: int = image.save_png(path)
	if err != OK:
		return "could not save %s (error %d)" % [path, err]
	Telemetry.event("scenario.capture", {"path": path})
	print("[SCENARIO] captured %s" % path)
	return ""


## `capture_at` steps, in the order armed: `{"step": Dictionary, "state": "armed" |
## "counting" | "taken" | "failed"}`. Each fires once, on the first matching beat
## after it was armed.
var _armed: Array = []
var _listening: bool = false


func _on_blast_beat(beat: String, room: Node) -> void:
	for arm: Dictionary in _armed:
		if str(arm["state"]) == "armed" and beat.to_upper() == str(arm["step"]["beat"]):
			arm["state"] = "counting"
			_take_armed(room, arm)


## Not awaited by the beat: it counts frames or process delta alongside the blast and
## whatever step the runner is on, then captures the frame it lands on.
func _take_armed(room: Node, arm: Dictionary) -> void:
	var step: Dictionary = arm["step"]
	var tree: SceneTree = room.get_tree()
	var frames: int = 0
	var elapsed: float = 0.0
	if step.has("frames"):
		while frames < int(step["frames"]):
			await tree.process_frame
			frames += 1
			elapsed += tree.root.get_process_delta_time()
	else:
		while elapsed < float(step["seconds"]):
			await tree.process_frame
			frames += 1
			elapsed += tree.root.get_process_delta_time()
	await RenderingServer.frame_post_draw
	if not is_instance_valid(room):
		arm["state"] = "failed"
		push_error("[ScenarioRunner] '%s': the Room went away before the capture" % step["text"])
		return
	var problem: String = _save_capture(room, str(step["name"]))
	if not problem.is_empty():
		arm["state"] = "failed"
		push_error("[ScenarioRunner] '%s': %s" % [step["text"], problem])
		return
	arm["state"] = "taken"
	print("[SCENARIO] %s — %d frame(s), %.3f s after '%s'" % [
		step["name"], frames, elapsed, step["beat"]])


func _fail(step: Dictionary, detail: String) -> bool:
	push_error("[ScenarioRunner] step '%s': %s" % [step["text"], detail])
	return false


## Where a step's file goes, its directory created: the app's external files dir on
## Android (the one place `adb pull` and a release APK both reach), `user://` elsewhere.
func _output_path(subdir: String, file_name: String) -> String:
	var dir: String = DevFlags.external_files_dir()
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://")
	var path: String = "%s/%s/%s" % [dir.trim_suffix("/"), subdir, file_name]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return path


## What `alloc` allocated, held for the life of the runner, so the memory stays in the
## process through every later `wait` and `mark` until `quit`.
var _held: Array = []


## RENDER3D R3D-0 — the per-object cost of a `Voxel`, measured on the device.
##
## - `objects` holds N real `Voxel`s in typed arrays of 64, the way `Slice` and `Slab`
##   hold them.
## - `packed` holds the same count as one `PackedInt32Array`, written — what a packed
##   store pays for a 4-byte cell.
## - `bytes` holds N bytes, written: the POSITIVE control. PSS moves in pages and a poll
##   is noisy, and `packed`'s ~0.8 MB for PLAYGROUND sits inside that noise, so it can
##   only show the instrument does not invent memory. A known size shows it sees memory
##   at all.
##
## ⚠️ `OS.get_static_memory_usage()` reads 0 on an Android release build — a null
## instrument, not a zero — so it is printed only when it reads something. On the
## device the number is `device_run.py --mem-poll` across the step's marks.
func _alloc(step: Dictionary) -> void:
	var count: int = int(step["count"])
	var static_before: int = OS.get_static_memory_usage()
	var t0: int = Time.get_ticks_usec()
	match str(step["kind"]):
		"objects":
			var chunk: Array[Voxel] = []
			for i in range(count):
				chunk.append(Voxel.new(Vector2i(i, 0), 0, null))
				if chunk.size() == 64:
					_held.append(chunk)
					chunk = []
			if not chunk.is_empty():
				_held.append(chunk)
		"packed":
			var cells := PackedInt32Array()
			cells.resize(count)
			cells.fill(1)
			_held.append(cells)
		"bytes":
			var raw := PackedByteArray()
			raw.resize(count)
			raw.fill(1)
			_held.append(raw)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var static_after: int = OS.get_static_memory_usage()
	var delta: int = -1
	var delta_text: String = "static memory unavailable (reads 0)"
	if static_before > 0 or static_after > 0:
		delta = static_after - static_before
		delta_text = "static memory %+.1f MB, %.0f B per item" \
			% [float(delta) / 1048576.0, float(delta) / float(count)]
	print("[SCENARIO] alloc %s %d — %.0f ms, %s" % [step["kind"], count, ms, delta_text])
	Telemetry.event("scenario.alloc",
		{"kind": step["kind"], "count": count, "ms": ms, "static_delta": delta})
