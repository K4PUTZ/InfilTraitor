## CaptureController — the camera and the screen while a CAPTURE drives them (CAPTURE_RAILS_MASTER_PLAN §5-§6). Dev tooling: created
## on first use by `Room.capture()` (a scenario op), never in play.
##
## - `apply_profile()`: the framing, the window, the HUD (through the facade, R5), and CAPTURE MODE — gameplay may no longer move the
##   camera (`CameraController.capture_locked`: focus_on, the enemy-phase tween, a re-centre, the player's drag / pinch are refused,
##   logged once each). The shake stays unless `set_shake(false)`.
## - `frame()`: anchors -> world boxes (`MapLayout`) -> a pose (`CaptureFramer`) -> the camera (`Room.set_capture_view()`).
## - `frame_check()`: the last framed boxes through the REAL camera (`Board3DLive.screen_of_world()`), so the framer is checked against
##   the board, not against itself.
extends Node

const CaptureFramerRef = preload("res://godot/scripts/systems/capture/capture_framer.gd")
const CaptureProfilesRef = preload("res://godot/scripts/systems/capture/capture_profiles.gd")
const MapLayoutRef = preload("res://godot/scripts/world/maps/map_layout.gd")

var room: Node = null
var profile: Dictionary = {}
var active: bool = false
## What the last `frame()` aimed at: {targets: Array[String], boxes: Array[AABB] (world), mode, view, pose}.
var last_frame: Dictionary = {}
const TITLE_BAR_PX: int = 28   ## macOS title bar: the window's OUTER height is its size plus this


func setup(p_room: Node) -> void:
	room = p_room


## Returns "" or the error.
func apply_profile(name: String, shape: String = "") -> String:
	var p: Dictionary = CaptureProfilesRef.resolve(name, shape)
	if not p["ok"]:
		return str(p["error"])
	profile = p
	room.call("set_framing", p["framing"], "capture")
	var win: Vector2i = p["window"]
	## `CAPTURE_WINDOW_FIXED=1`: the harness owns the window (`capture.py` passes `--resolution`; Movie Maker needs one size for the whole
	## file), so the profile does not resize it.
	if win.x > 0 and not DevFlags.on("CAPTURE_WINDOW_FIXED") and not OS.has_feature("mobile") and not DisplayServer.is_touchscreen_available():
		## §5.2: never a silently smaller capture. The OS clamps a window to the usable screen (a 1920 x 1080 display minus the menu
		## bar and the title bar cannot hold a 1920 x 1080 window); then the largest window of the SAME aspect that fits is used and
		## said loudly, so the frame is the profile's shape, smaller — and the log says by how much.
		var usable: Vector2i = DisplayServer.screen_get_usable_rect().size - Vector2i(0, TITLE_BAR_PX)
		var fit: Vector2i = win
		if win.x > usable.x or win.y > usable.y:
			var k: float = minf(float(usable.x) / float(win.x), float(usable.y) / float(win.y))
			fit = Vector2i(int(floor(float(win.x) * k / 8.0)) * 8, int(floor(float(win.y) * k / 8.0)) * 8)
			push_warning("[CaptureController] profile %s wants a %s window; the screen's usable area is %s: using %s (same aspect)"
				% [name, win, usable, fit])
			print("[CAPTURE] WARNING window %s does not fit the screen (usable %s): using %s, same aspect" % [win, usable, fit])
		DisplayServer.window_set_size(fit)
		DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect().position + Vector2i(0, TITLE_BAR_PX))
	set_hud(bool(p["hud"]))
	_lock(true)
	print("[CAPTURE] profile %s (%s): framing %s, window %s (got %s), hud %s, turn %s" % [name, p["shape"], p["framing"], win,
		DisplayServer.window_get_size(), "on" if p["hud"] else "off", p["turn"]])
	return ""


func set_hud(on: bool) -> void:
	var hud: Object = room.get("_hud_controller")
	if hud != null and hud.has_method("set_capture_hidden"):
		hud.call("set_capture_hidden", not on)


func set_shake(on: bool) -> void:
	var cc: Object = room.get("_camera_controller")
	if cc != null:
		cc.set("capture_shake", on)
		if not on:
			cc.call("stop_shake")


func _lock(on: bool) -> void:
	active = on
	var cc: Object = room.get("_camera_controller")
	if cc != null:
		cc.set("capture_locked", on)


## `targets`: anchor references (`@big_pane`, `glass_wing`, `@map`…). `view`: N/E/S/W or "" for the current one. Returns "" or the error.
func frame(targets: Array, mode: String, view: String = "") -> String:
	var ml: RefCounted = room.get("map_layout")
	var live: Node = room.call("board3d")
	if ml == null or live == null:
		return "[CaptureController] frame needs the map layout and the 3D board"
	if not active:
		_lock(true)
	if not view.is_empty() and view != str(room.get("_view_direction")):
		room.call("_set_perspective", view)
	var boxes: Array = []
	for t in targets:
		var r: Dictionary = ml.call("resolve", str(t), room)
		if not r["ok"]:
			return str(r["error"])
		boxes.append(MapLayoutRef.to_world_box(r["box"]))
	var yaw: float = float(CaptureFramerRef.VIEW_YAW.get(str(room.get("_view_direction")), 0.0))
	live.set("capture_yaw", NAN)
	var pose: Dictionary = _pose(boxes, mode, yaw)
	room.call("set_capture_view", pose["ground_centre"], pose["zoom"])
	last_frame = {"targets": targets, "boxes": boxes, "mode": mode, "view": str(room.get("_view_direction")), "pose": pose}
	print("[CAPTURE] frame %s %s view %s: centre (%.2f, %.2f) zoom %.3f%s" % [mode, " ".join(PackedStringArray(targets)),
		last_frame["view"], pose["ground_centre"].x, pose["ground_centre"].y, pose["zoom"], "" if pose["fits"] else " (CLAMPED: does not fit)"])
	return ""


## Projects the last framed boxes' corners through the real camera, after a drawn frame. Returns the report line's fields.
func frame_check(name: String) -> Dictionary:
	var live: Node = room.call("board3d")
	if last_frame.is_empty() or live == null:
		return {"ok": false, "error": "[CaptureController] frame_check: nothing framed yet"}
	var rect: Rect2 = live.get_viewport().get_visible_rect()
	var margin: float = INF
	var inside: bool = true
	for box: AABB in last_frame["boxes"]:
		var bx: AABB = box
		if str(last_frame["mode"]) == "detail":
			bx = CaptureFramerRef._grow_to_min(bx)
		for i: int in range(8):
			var s: Vector2 = live.call("screen_of_world", bx.get_endpoint(i))
			var m: float = minf(minf(s.x - rect.position.x, rect.end.x - s.x), minf(s.y - rect.position.y, rect.end.y - s.y))
			margin = minf(margin, m)
			inside = inside and m >= -0.5
	var line: String = "[FRAME-CHECK] %s target=%s view=%s inside=%s margin=%.1f px canvas=%s" % [name,
		" ".join(PackedStringArray(last_frame["targets"])), last_frame["view"], "yes" if inside else "no", margin, rect.size]
	print(line)
	return {"ok": true, "inside": inside, "margin": margin, "line": line}


func _pose(boxes: Array, mode: String, yaw: float) -> Dictionary:
	var live: Node = room.call("board3d")
	var canvas: Vector2 = live.get_viewport().get_visible_rect().size
	return CaptureFramerRef.frame(boxes, mode, yaw, canvas, float(live.call("px_per_unit")))


func _boxes(targets: Array) -> Dictionary:
	var ml: RefCounted = room.get("map_layout")
	var boxes: Array = []
	for t in targets:
		var r: Dictionary = ml.call("resolve", str(t), room)
		if not r["ok"]:
			return {"ok": false, "error": str(r["error"])}
		boxes.append(MapLayoutRef.to_world_box(r["box"]))
	return {"ok": true, "boxes": boxes}


# ---------------------------------------------------------------------------------------------------------------------------------
# Rails (CAPTURE_RAILS §7.3-§7.4)

## Indices of the keys whose HOLD has started in the current rail (a take fires its steps on one of them).
var holds_started: Array = []
var rail_frame: int = 0
var rail_done: bool = true

const EASE_FN: Dictionary = {"linear": 0, "in_out": 1, "out": 2}


static func _ease(t: float, kind: String) -> float:
	match kind:
		"linear":
			return t
		"out":
			return 1.0 - (1.0 - t) * (1.0 - t)
	return t * t * (3.0 - 2.0 * t)


## The key's pose at `yaw`: {ground_centre, zoom} (or {error}).
func _key_pose(k: Dictionary, yaw: float) -> Dictionary:
	var mode: String = str(k.get("frame", "wide"))
	if mode == "explicit":
		var c: Array = k["centre"]
		return {"ground_centre": Vector2(float(c[0]), float(c[1])), "zoom": float(k["zoom"])}
	var targets: Array = k["target"] if k.get("target", null) is Array else [k.get("target", "@map")]
	var b: Dictionary = _boxes(targets)
	if not b["ok"]:
		return {"error": b["error"]}
	return _pose(b["boxes"], mode, yaw)


## Applies one interpolated pose. Orbit: the camera takes any yaw; the LOGICAL view follows the nearest quarter (one honest snap of
## the face tones / cutaway / actor light at each half-way, §7.4).
func _apply(centre: Vector2, zoom: float, yaw: float, orbiting: bool) -> void:
	var live: Node = room.call("board3d")
	live.set("capture_yaw", yaw if orbiting else NAN)
	var nearest: String = CaptureFramerRef.VIEW_YAW.keys()[int(roundf(fposmod(yaw, 360.0) / 90.0)) % 4]
	if nearest != str(room.get("_view_direction")):
		if orbiting:
			print("[RAIL] orbit view switch %s -> %s at frame %d" % [room.get("_view_direction"), nearest, rail_frame])
		room.call("_set_perspective", nearest)
	room.call("set_capture_view", centre, zoom)


## Plays a rail to its end, one pose per drawn frame. Returns "" or the error.
func play_rail(rail: Dictionary) -> String:
	if rail.is_empty():
		return "[CaptureController] no such rail"
	var live: Node = room.call("board3d")
	if room.get("map_layout") == null or live == null:
		return "[CaptureController] a rail needs the map layout and the 3D board"
	if not active:
		_lock(true)
	holds_started = []
	rail_frame = 0
	rail_done = false
	var tree: SceneTree = room.get_tree()
	var cam: Camera2D = room.get("camera")
	var g: Vector3 = live.call("ground_point", cam.get_screen_center_position())
	var cur_centre := Vector2(g.x, g.z)
	var cur_zoom: float = cam.zoom.x
	var cur_yaw: float = float(CaptureFramerRef.VIEW_YAW.get(str(room.get("_view_direction")), 0.0))
	var keys: Array = rail["keys"]
	for i: int in range(keys.size()):
		var k: Dictionary = keys[i]
		var view: String = str(k.get("view", room.get("_view_direction")))
		var turn: String = str(k.get("turn", ""))
		if turn.is_empty():
			turn = str(profile.get("turn", "cut"))
		var move: int = int(k.get("move", 0))
		var hold: int = int(k.get("hold", 0))
		var follow: bool = bool(k.get("follow", false))
		var end_yaw: float = float(CaptureFramerRef.VIEW_YAW[view])
		var delta: float = wrapf(end_yaw - fposmod(cur_yaw, 360.0), -180.0, 180.0)
		var orbit: bool = turn == "orbit" and move > 0 and not is_zero_approx(delta)
		if not orbit:
			cur_yaw = end_yaw
		var target_yaw: float = cur_yaw + (delta if orbit else 0.0)
		var end_pose: Dictionary = _key_pose(k, end_yaw)
		if end_pose.has("error"):
			rail_done = true
			return str(end_pose["error"])
		for f: int in range(1, move + 1):
			var t: float = _ease(float(f) / float(move), str(k.get("ease", "in_out")))
			if follow:
				end_pose = _key_pose(k, end_yaw)
			var z: float = exp(lerpf(log(cur_zoom), log(float(end_pose["zoom"])), t))
			_apply(cur_centre.lerp(end_pose["ground_centre"], t), z, lerpf(cur_yaw, target_yaw, t), orbit)
			rail_frame += 1
			await tree.process_frame
		_apply(end_pose["ground_centre"], end_pose["zoom"], end_yaw, false)
		print("[RAIL] %s key %d frame %d pose centre (%.2f, %.2f) zoom %.3f view %s" % [rail.get("id", "?"), i, rail_frame,
			end_pose["ground_centre"].x, end_pose["ground_centre"].y, end_pose["zoom"], view])
		holds_started.append(i)
		for _f: int in range(hold):
			if follow:
				end_pose = _key_pose(k, end_yaw)
				_apply(end_pose["ground_centre"], end_pose["zoom"], end_yaw, false)
			rail_frame += 1
			await tree.process_frame
		cur_centre = end_pose["ground_centre"]
		cur_zoom = float(end_pose["zoom"])
		cur_yaw = end_yaw
	rail_done = true
	return ""
