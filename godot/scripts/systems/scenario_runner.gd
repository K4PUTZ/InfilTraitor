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
##   throw <index> <x,y>                  RETIRE-2: dev grenade #index THROWN to the GU x,y through the real
##                                        throw (the agent's release, the arc, the landing hop, the roll, the
##                                        fuse, the blast); returns at once, so follow it with `frames`/`capture_at`
##   aim <x,y>                            RETIRE-2D: the grenade targeting preview on a GU (the perimeter, the dome, the arc, the shrapnel
##                                        rays, the footprint and the virtual grenade), as a player aiming; stays open
##   canvas_check <name>                  RETIRE-2D: prints `[CANVAS-CHECK] <name> examined=N canvas=M <names>`: how many overlays that
##                                        have a 3D target there are, and which of them are painting the 2D canvas instead
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
##   probe <name>                         RENDER3D R3D-0: a `BoardProbe` dump of the
##                                        voxel state to probes/<name>.txt (same dir
##                                        as capture); compare with board_probe.py
##   alloc objects|packed|bytes <count>   RENDER3D R3D-0 instrument: hold <count>
##                                        `Voxel` objects / packed int32 cells / bytes
##                                        until quit, for --mem-poll to read
##   container_stats <name>               R3D-CLAIMS C2: prints how many released containers were converted back to full
##                                        `Voxel` objects and how many single handles were made (`VoxelContainer.Stats`)
##   probe_store <name>                   RENDER3D R3D-1b: the same dump, read from the
##                                        shadow `VoxelStore` (`VOXEL_STORE=1`)
##   shoot <guard index>                  R3D-1b gate: a shot through the menu entry points
##                                        needs that guard to exist (GLASS has none: the step aborts the scenario)
##   reload                               R3D-1b gate: F2's `load_map()` on the current map
##   save_restore                         R3D-1b gate: SaveState capture → reload → restore
##   perspective N|E|S|W                  R3D-1b gate: a rotation through `_set_perspective()`
##   view_mode dev|light|heat|numbers|ruler   flips one analysis aid, through the same toggles the HUD and the
##                                        F-keys reach (the dev overlays under a camera yaw need a scenario to
##                                        switch them on; call it again to flip it back)
##   pick_check <name>                    touch picking in the CURRENT view: the centre of every on-screen cell
##                                        goes through the real pick (`_screen_to_tile`) and must come back as that
##                                        cell (or the standing prop that covers it); prints `[PICK-CHECK]`
##                                        (tools/persistent/pick_gate.py reads it)
##   world_check <name>                   the maths the air overlays (tracer, throw arc, aim dome, lamps) stand on, in the
##                                        CURRENT view: where `WorldCanvas3D.lift()` puts fixed points (world state, must
##                                        not move with the view) and whether `screen_axes()` is what the camera really
##                                        does to a grid step; prints `[WORLD-CHECK]` (tools/persistent/world_gate.py)
##   relight                              R3D-13: the map-wide light repaint on the CURRENT world,
##                                        in place — what a rotation or a restore runs, without
##                                        either (a probe before and after names what the
##                                        incremental light left different from a full relight)
##   passages <label>                     RENDER3D R3D-1c: every edge's passage class, as a
##                                        count and a digest
##   occ_bench <x,y> <x,y> <reps>         R3D-7 instrument: put the agent on the two cells in turn <reps>
##                                        times through the real occlusion path (`_recompute_occlusion`),
##                                        one frame apart, and print the set / 3D cutaway / total cost
##   place_guard <i> <x,y>                R3D-7: guard <i> onto a cell (position only), vision refreshed
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
	"mark": -1, "window": 1, "capture": 1, "detonate": 1, "quit": 0,
	"probe": 1, "alloc": 2, "capture_at": 3, "throw": 2, "aim": 1, "canvas_check": 1,
	"probe_store": 1, "shoot": 1, "reload": 0, "save_restore": 0, "perspective": 1, "relight": 0, "view_mode": 1,
	"container_stats": 1, "gfx_census": 1, "gpu_alloc": 1, "passages": 1, "mirror_check": 1, "ground_check": 1, "pick_check": 1, "world_check": 1, "occ_bench": 3, "place_guard": 2, "decal_wall": 2,
	"profile": -1, "hud": 1, "frame": -1, "frame_check": 1, "still": -1, "shake": 1, "rail": 1, "take": 1,
}
## CAPTURE_RAILS §7.5 — the cell arguments an `@id` may name, by op and token index (0 = the op). `substitute_anchors()` turns each
## into the anchor's raw ground cell BEFORE parsing, so the event and the camera read the same anchor.
const CELL_TOKENS: Dictionary = {"throw": [2], "aim": [1], "centre": [1], "place_guard": [2], "decal_wall": [2], "occ_bench": [1, 2]}
## CAPTURE_RAILS (§8.1): framing modes and views of `frame` / `still`.
const FRAME_MODES: PackedStringArray = ["wide", "detail", "fit"]
const VIEWS: PackedStringArray = ["N", "E", "S", "W"]
const ScenarioDrawRef = preload("res://godot/scripts/systems/scenario_draw.gd")  ## waits for a drawn frame, never forever (an occluded harness window draws nothing)
const VIEW_MODES: PackedStringArray = ["dev", "light", "heat", "numbers", "ruler", "layout"]
const FRAMINGS: PackedStringArray = ["portrait", "landscape", "desktop"]
const ALLOC_KINDS: PackedStringArray = ["objects", "packed", "bytes"]
const BEAT_TOKEN_PATTERN: String = "^[A-Za-z0-9_]+$"


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
## first step that cannot (reported loudly, marked `scenario.abort`, and on a desktop the process exits with code 1).
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
			## A desktop harness waits for the process to end, and an aborted scenario never reaches its `quit`: it sat there
			## until the harness's own timeout (measured: `shoot 0` on GLASS, which has no guard, hung a capture for 120 s).
			## So it ends with a non-zero code. A handset keeps running: the device harness reads the log and force-stops.
			if not OS.has_feature("mobile"):
				print("[SCENARIO] ABORT at step %d/%d — exiting with code 1" % [i + 1, steps.size()])
				room.get_tree().quit(1)
			return
	Telemetry.event("scenario.end")


## `{text, error}`: every `@id` in a cell argument (CELL_TOKENS) becomes "x,y", the anchor's raw ground cell (`MapLayout.ground_cell`).
## Other `@` tokens (the targets of `frame` / `still`) are left for the op itself.
static func substitute_anchors(text: String, layout: RefCounted, room: Object = null) -> Dictionary:
	var out: PackedStringArray = []
	for chunk in text.replace("\n", ";").split(";", false):
		var tokens: PackedStringArray = chunk.strip_edges().split(" ", false)
		if tokens.is_empty():
			continue
		var op: String = tokens[0].to_lower()
		for idx in CELL_TOKENS.get(op, []):
			if int(idx) < tokens.size() and tokens[int(idx)].begins_with("@"):
				if layout == null:
					return {"text": "", "error": "'%s' names %s but the map has no layout" % [chunk.strip_edges(), tokens[int(idx)]]}
				var gc: Dictionary = layout.call("ground_cell", tokens[int(idx)], room)
				if not gc["ok"]:
					return {"text": "", "error": "'%s': %s" % [chunk.strip_edges(), gc["error"]]}
				tokens[int(idx)] = "%d,%d" % [gc["cell"].x, gc["cell"].y]
		out.append(" ".join(tokens))
	return {"text": "; ".join(out), "error": ""}


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
		"gpu_alloc":
			if not arg.is_valid_int() or int(arg) <= 0:
				return "gpu_alloc takes a whole number of MiB > 0"
			step["mib"] = int(arg)
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
		"profile":
			if tokens.size() < 2 or tokens.size() > 3:
				return "profile takes a profile name and an optional shape (portrait / landscape)"
			step["profile"] = arg
			step["shape"] = tokens[2] if tokens.size() == 3 else ""
		"rail", "take":
			if arg.is_empty():
				return "%s takes an id (authored, or overview / region:<id> / poi:<id>)" % op
			step["id"] = arg
		"hud", "shake":
			if not (arg == "on" or arg == "off"):
				return "%s takes on or off" % op
			step["on"] = arg == "on"
		"frame", "still":
			var rest: PackedStringArray = tokens.slice(1)
			if op == "still":
				if rest.size() < 1 or not rest[0].is_valid_filename() or rest[0].contains("."):
					return "still takes a file name, a mode, target(s) and an optional view (N/E/S/W/all)"
				step["name"] = rest[0]
				rest = rest.slice(1)
			if rest.size() < 2 or not FRAME_MODES.has(rest[0]):
				return "%s takes a mode (wide, detail, fit) and at least one target (@id, a region, @map)" % op
			step["mode"] = rest[0]
			rest = rest.slice(1)
			step["view"] = ""
			var last: String = rest[rest.size() - 1].to_upper()
			if rest.size() > 1 and (VIEWS.has(last) or (op == "still" and last == "ALL")):
				step["view"] = last
				rest = rest.slice(0, rest.size() - 1)
			step["targets"] = Array(rest)
			if step["mode"] != "fit" and rest.size() != 1:
				return "%s %s takes one target (fit takes several)" % [op, step["mode"]]
		"capture", "probe", "probe_store", "container_stats", "gfx_census", "passages", "mirror_check", "ground_check", "pick_check", "world_check", "canvas_check", "frame_check":
			if not arg.is_valid_filename() or arg.contains("."):
				return "%s takes a file name (letters, digits, _ or -)" % op
			step["name"] = arg
		"aim":
			var axy: PackedStringArray = arg.split(",")
			if axy.size() != 2 or not axy[0].is_valid_int() or not axy[1].is_valid_int():
				return "aim takes a GU as x,y"
			step["cell"] = Vector2i(int(axy[0]), int(axy[1]))
		"place_guard":
			if not arg.is_valid_int() or int(arg) < 0:
				return "place_guard takes a guard index >= 0 and a cell x,y"
			var gxy: PackedStringArray = tokens[2].split(",")
			if gxy.size() != 2 or not gxy[0].is_valid_int() or not gxy[1].is_valid_int():
				return "place_guard takes a guard index >= 0 and a cell x,y"
			step["index"] = int(arg)
			step["cell"] = Vector2i(int(gxy[0]), int(gxy[1]))
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
		"decal_wall":
			var wall_gu: PackedStringArray = tokens[2].split(",")
			if not arg.is_valid_identifier() or wall_gu.size() != 2 or not wall_gu[0].is_valid_int() or not wall_gu[1].is_valid_int():
				return "decal_wall takes a material id and a GU as x,y"
			step["material"] = arg
			step["cell"] = Vector2i(int(wall_gu[0]), int(wall_gu[1]))
		"throw":
			var target: PackedStringArray = tokens[2].split(",")
			if not arg.is_valid_int() or int(arg) < 0 or target.size() != 2 or not target[0].is_valid_int() \
					or not target[1].is_valid_int():
				return "throw takes a dev grenade index >= 0 and a GU as x,y"
			step["index"] = int(arg)
			step["cell"] = Vector2i(int(target[0]), int(target[1]))
		"shoot":
			if not arg.is_valid_int() or int(arg) < 0:
				return "shoot takes a guard index >= 0"
			step["index"] = int(arg)
		"view_mode":
			if not VIEW_MODES.has(arg.to_lower()):
				return "view_mode takes dev, light, heat, numbers, ruler or layout"
			step["mode"] = arg.to_lower()
		"perspective":
			if not ["N", "E", "S", "W"].has(arg.to_upper()):
				return "perspective takes N, E, S or W"
			step["direction"] = arg.to_upper()
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
		"gpu_alloc":
			## PB-2: a known GPU allocation, to read the driver's total against it.
			GfxCensus.gpu_alloc(int(step["mib"]))
		"gfx_census":
			## PERFORMANCE_BUDGET PB-2: who owns the graphics memory (textures, meshes, render targets by category).
			GfxCensus.report(room.get_tree().root, str(step["name"]))
		"container_stats":
			## R3D-CLAIMS C2: how many released containers had to be converted back to full objects, how many single handles were
			## made, and which containers (the first 64) — what reads the board whole shows here as a number, not as ~270 MB.
			var cstats = VoxelContainer.Stats
			print("[CONTAINER-STATS] %s — converted %d container(s) (%d voxels), %d single handle(s), first converted: %s" % [
				step["name"], cstats.converted, cstats.converted_voxels, cstats.handles, ", ".join(PackedStringArray(cstats.converted_ids.keys())).left(400)])
			var ranked: Array = cstats.callers.keys()
			ranked.sort_custom(func(a, b): return int(cstats.callers[a][1]) > int(cstats.callers[b][1]))
			for who in ranked.slice(0, 12):
				print("[CONTAINER-STATS]   %-62s %5d container(s) %8d voxel(s)" % [who, cstats.callers[who][0], cstats.callers[who][1]])
		"window":
			if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
				## The OS window IS the screen on a handheld; there is nothing to resize.
				push_warning("[ScenarioRunner] '%s' ignored on a handheld" % step["text"])
			else:
				DisplayServer.window_set_size(step["size"])
				await room.get_tree().process_frame
		"profile":
			var perr: String = room.call("capture").call("apply_profile", step["profile"], step["shape"])
			if not perr.is_empty():
				return _fail(step, perr)
			for _f in range(3):
				await room.get_tree().process_frame
		"hud":
			room.call("capture").call("set_hud", step["on"])
		"rail":
			var ml_r: RefCounted = room.get("map_layout")
			var rerr: String = await room.call("capture").call("play_rail", ml_r.call("rail", step["id"]) if ml_r != null else {})
			if not rerr.is_empty():
				return _fail(step, rerr)
		"take":
			return await _run_take(room, step)
		"shake":
			room.call("capture").call("set_shake", step["on"])
		"frame":
			var ferr: String = room.call("capture").call("frame", step["targets"], step["mode"], step["view"])
			if not ferr.is_empty():
				return _fail(step, ferr)
			await ScenarioDrawRef.next_drawn_frame(get_tree())
		"frame_check":
			await ScenarioDrawRef.next_drawn_frame(get_tree())
			var fc: Dictionary = room.call("capture").call("frame_check", step["name"])
			if not fc["ok"]:
				return _fail(step, str(fc["error"]))
		"still":
			var views: Array = VIEWS if step["view"] == "ALL" else [step["view"]]
			for v: String in views:
				var serr: String = room.call("capture").call("frame", step["targets"], step["mode"], v)
				if not serr.is_empty():
					return _fail(step, serr)
				for _f in range(2):
					await ScenarioDrawRef.next_drawn_frame(get_tree())
				room.call("capture").call("frame_check", "%s%s" % [step["name"], "_" + v if step["view"] == "ALL" else ""])
				var cap_err: String = _save_capture(room, "%s%s" % [step["name"], "_" + v if step["view"] == "ALL" else ""])
				if not cap_err.is_empty():
					return _fail(step, cap_err)
		"capture":
			await ScenarioDrawRef.next_drawn_frame(get_tree())
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
		"ground_check":
			if not room.has_method("scenario_ground_check"):
				return _fail(step, "Room has no scenario_ground_check()")
			if not bool(room.call("scenario_ground_check", str(step["name"]))):
				return _fail(step, "no ground check was made (see the error above)")
		"aim":
			if not room.has_method("scenario_aim"):
				return _fail(step, "Room has no scenario_aim()")
			if not bool(room.call("scenario_aim", step["cell"])):
				return _fail(step, "the aim did not start (see the error above)")
		"canvas_check":
			if not room.has_method("scenario_canvas_check"):
				return _fail(step, "Room has no scenario_canvas_check()")
			room.call("scenario_canvas_check", str(step["name"]))
		"world_check":
			if not room.has_method("scenario_world_check"):
				return _fail(step, "Room has no scenario_world_check()")
			if not bool(room.call("scenario_world_check", str(step["name"]))):
				return _fail(step, "the world check could not run (see the error above)")
		"pick_check":
			if not room.has_method("scenario_pick_check"):
				return _fail(step, "Room has no scenario_pick_check()")
			if not bool(room.call("scenario_pick_check", str(step["name"]))):
				return _fail(step, "the pick check could not run (see the error above)")
		"mirror_check":
			if not room.has_method("scenario_mirror_check"):
				return _fail(step, "Room has no scenario_mirror_check()")
			if not bool(room.call("scenario_mirror_check", str(step["name"]))):
				return _fail(step, "no mirror check was made (see the error above)")
		"passages":
			if not room.has_method("scenario_passages"):
				return _fail(step, "Room has no scenario_passages()")
			if not bool(room.call("scenario_passages", str(step["name"]))):
				return _fail(step, "no passages were computed (see the error above)")
		"shoot", "reload", "save_restore", "perspective", "relight", "view_mode":
			var method: String = "scenario_" + str(step["op"])
			if not room.has_method(method):
				return _fail(step, "Room has no %s()" % method)
			var ok: bool = false
			match str(step["op"]):
				"shoot":
					ok = await room.call(method, int(step["index"]))
				"perspective":
					ok = await room.call(method, str(step["direction"]))
				"view_mode":
					ok = await room.call(method, str(step["mode"]))
				_:
					ok = await room.call(method)
			if not ok:
				return _fail(step, "%s() did not complete (see the error above)" % method)
		"decal_wall":
			if not room.has_method("scenario_decal_wall"):
				return _fail(step, "Room has no scenario_decal_wall()")
			if not bool(await room.call("scenario_decal_wall", str(step["material"]), step["cell"])):
				return _fail(step, "no decal display was built (see the error above)")
		"throw":
			if not room.has_method("scenario_throw"):
				return _fail(step, "Room has no scenario_throw()")
			if not bool(room.call("scenario_throw", int(step["index"]), step["cell"])):
				return _fail(step, "the throw did not start (see the error above)")
		"detonate":
			if not room.has_signal("scenario_detonation_done") or not room.has_method("scenario_detonate"):
				return _fail(step, "Room has no scenario_detonate()")
			var done: Signal = Signal(room, "scenario_detonation_done")
			room.call_deferred("scenario_detonate", int(step["index"]))
			var detonated: bool = await done
			if not detonated:
				return _fail(step, "the detonation did not complete (see the error above)")
		"place_guard":
			if not room.has_method("scenario_place_guard"):
				return _fail(step, "Room has no scenario_place_guard()")
			if not bool(room.call("scenario_place_guard", int(step["index"]), step["cell"])):
				return _fail(step, "the guard was not placed (see the error above)")
		"occ_bench":
			if not room.has_method("scenario_occ_bench"):
				return _fail(step, "Room has no scenario_occ_bench()")
			await room.call("scenario_occ_bench", step["cell1"], step["cell2"], int(step["reps"]))
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
	await ScenarioDrawRef.next_drawn_frame(get_tree())
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


## CAPTURE_RAILS §7.5 — a whole take: its profile, its seed, its rail, and its steps fired when key `at_key` starts holding (+
## `after_hold` frames); returns once `length` frames have passed since the take began. The steps' `@id`s are the anchors' cells.
func _run_take(room: Node, step: Dictionary) -> bool:
	var ml: RefCounted = room.get("map_layout")
	var take: Dictionary = ml.call("take", step["id"]) if ml != null else {}
	if take.is_empty():
		return _fail(step, "no take '%s' on this map (authored, or overview / region:<id> / poi:<id>)" % step["id"])
	var cap: Node = room.call("capture")
	var shape: String = DevFlags.value("CAPTURE_SHAPE", "")
	## `CAPTURE_PROFILE` overrides the take's own (device_record.py --take plays a desktop take under `perf` on a handset).
	var perr: String = cap.call("apply_profile", DevFlags.value("CAPTURE_PROFILE", str(take.get("profile", "engine"))), shape)
	if not perr.is_empty():
		return _fail(step, perr)
	seed(int(take.get("seed", 1)))
	var sub: Dictionary = substitute_anchors("; ".join(PackedStringArray(take.get("steps", []))), ml, room)
	if not str(sub["error"]).is_empty():
		return _fail(step, sub["error"])
	var parsed: Dictionary = {"steps": [], "error": ""}
	if not str(sub["text"]).strip_edges().is_empty():
		parsed = parse(sub["text"])
		if not str(parsed["error"]).is_empty():
			return _fail(step, "take '%s': %s" % [step["id"], parsed["error"]])
	var tree: SceneTree = room.get_tree()
	for _f in range(3):
		await tree.process_frame
	var start: int = Engine.get_process_frames()
	print("[TAKE] %s: profile %s, rail %s, %d step(s) at key %d + %d frames, length %d frames, seed %d" % [step["id"], take.get("profile", "engine"),
		take.get("rail", ""), (parsed["steps"] as Array).size(), int(take.get("at_key", 0)), int(take.get("after_hold", 0)),
		int(take.get("length", 0)), int(take.get("seed", 1))])
	cap.call("play_rail", ml.call("rail", str(take.get("rail", ""))))
	if not (parsed["steps"] as Array).is_empty():
		while not (cap.get("holds_started") as Array).has(int(take.get("at_key", 0))):
			if bool(cap.get("rail_done")):
				return _fail(step, "take '%s': the rail ended before key %d" % [step["id"], int(take.get("at_key", 0))])
			await tree.process_frame
		for _f in range(int(take.get("after_hold", 0))):
			await tree.process_frame
		print("[TAKE] %s: steps fire at take frame %d" % [step["id"], Engine.get_process_frames() - start])
		for st: Dictionary in parsed["steps"]:
			print("[TAKE]   %s" % st["text"])
			if not await _execute(room, st):
				return false
	while Engine.get_process_frames() - start < int(take.get("length", 0)):
		await tree.process_frame
	print("[TAKE] %s: done at take frame %d" % [step["id"], Engine.get_process_frames() - start])
	return true
