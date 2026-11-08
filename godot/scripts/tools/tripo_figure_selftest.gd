## tripo_figure_selftest — MOVEMENT MV-4, first slice: what a Tripo actor reads before it is drawn. The drawing is checked by capture; this pins
## what a capture cannot see: that each figure's GAME SET exists, holds the clips the game plays and is the bank decoded today (a stale set
## would play yesterday's clip with no error), that every clip is IN PLACE (the grid moves the actor, a drifting Hips would walk it off its
## cell) with the Hips at the figure's own height, that the travel the walk is phased by is there, and that the rig answers the bones and
## pieces the game asks it for. Since 2026-11-08 also the POSES (`TripoFigure.POSES`, `pose_<id>` in the game set): present, the bank-and-solver output of today,
## the wrists where the spec puts them, and the aim layer (`ActorAimPose3D`) neutral at weight 0 and exactly the pose at the stops.
extends SceneTree

const TripoFigureRef = preload("res://godot/scripts/geometry/tripo_figure.gd")
const AimPoseRef = preload("res://godot/scripts/geometry/actor_aim_pose3d.gd")
const TripoPoseKitRef = preload("res://godot/scripts/geometry/tripo_pose_kit.gd")
const DRIFT_MAX_M: float = 0.001     ## the Hips' ground offset, last key against the first, after the decode (the 1 m figure)
const MATCH_MAX_M: float = 0.0001    ## the game set against a fresh decode of the bank, per Hips key

var _fails: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("TRIPO-FIGURE SELFTEST")
	print("=".repeat(70) + "\n")
	for figure: String in TripoFigureRef.FIGURES:
		_test_figure(figure)
	print("")
	if _fails == 0:
		print("[TRIPO-FIGURE] RESULT: PASS — all checks passed")
		quit(0)
	else:
		print("[TRIPO-FIGURE] RESULT: FAIL — %d check(s) failed" % _fails)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("[TRIPO-FIGURE] ✅ %s" % label)
	else:
		print("[TRIPO-FIGURE] ❌ %s" % label)
		_fails += 1


func _hips_track(anim: Animation) -> int:
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(t)).ends_with(TripoFigureRef.HIPS):
			return t
	return -1


func _test_figure(figure: String) -> void:
	var scene := load(TripoFigureRef.rig_path(figure, true)) as PackedScene
	_check(scene != null, "%s: the LIGHT Agent loads" % figure)
	if scene == null:
		return
	var body := scene.instantiate() as Node3D
	var skeletons: Array[Node] = body.find_children("*", "Skeleton3D", true, false)
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	_check(skeleton != null and skeleton.get_bone_count() == 65, "%s: one skeleton of 65 Mixamo joints" % figure)
	if skeleton == null:
		body.free()
		return
	for bone: String in ["Hips", "Head", "LeftUpLeg", "RightFoot"]:
		_check(TripoFigureRef.find_bone(skeleton, bone) >= 0, "%s: the rig answers the bone %s" % [figure, bone])
	_check(TripoFigureRef.coat_of(body) != null, "%s: the rig has its coat" % figure)
	TripoFigureRef.hide_pieces(body, false)
	var shown: Array[String] = []
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			shown.append(String(mi.name))
	var undressed_shown: Array[String] = []
	for piece: String in TripoFigureRef.UNDRESSED_PIECES:
		if shown.has(piece):
			undressed_shown.append(piece)
	_check(undressed_shown.is_empty() and shown.has("Outfit_Coat") and shown.has("Outfit_Shirt_Coated"), "%s: the dressed set hides the undressed pieces (%s shown)" % [figure, shown])
	var hips_rest: Vector3 = skeleton.get_bone_rest(TripoFigureRef.find_bone(skeleton, TripoFigureRef.HIPS)).origin
	body.free()
	var lib: AnimationLibrary = TripoFigureRef.library(figure)
	_check(lib != null, "%s: the game set loads (%s)" % [figure, TripoFigureRef.GAME_LIBRARY % figure])
	if lib == null:
		return
	for id: String in TripoFigureRef.GAME_CLIPS:
		_test_clip(figure, id, lib, hips_rest)
	var walk_m: float = TripoFigureRef.travel_m(lib.get_animation("walk"))
	var run_m: float = TripoFigureRef.travel_m(lib.get_animation("run"))
	_check(TripoFigureRef.travel_m(lib.get_animation("idle")) < 0.05, "%s: the idle covers no ground" % figure)
	_check(walk_m > 1.0 and run_m > walk_m, "%s: the walk covers ground (%.3f m a pass), the run more (%.3f m)" % [figure, walk_m, run_m])
	for pose_id: String in TripoFigureRef.POSES:
		_test_pose(figure, pose_id, lib)
	_test_aim_layer(figure, lib)
	_test_pose_file(figure)


## The Director's pose file (`TripoFigure.POSE_FILE`): a pose and a prop written as the JSON the Blender lab writes are read back as exactly that, from the file, with the prop's
## placement in the meta the game reads. A file in `user://` stands in for his: the real path is his, never written by a test.
func _test_pose_file(figure: String) -> void:
	var solved: Animation = TripoFigureRef.solved_pose(figure, "aim_pistol")
	_check(solved != null and solved.get_meta("source", "") == "solved" and (solved.get_meta("props", {}) as Dictionary).has("pistol"),
		"%s: a solved pose says so and carries its default pistol placement" % figure)
	if solved == null:
		return
	var data: Dictionary = TripoFigureRef.pose_to_json(figure, "aim_pistol", solved)
	var bones: Dictionary = data["bones"]
	var moved: Quaternion = Quaternion(Vector3.UP, 0.3)
	bones["RightForeArm"] = [moved.x, moved.y, moved.z, moved.w]
	var props: Dictionary = data["props"]
	props["pistol"]["pos"] = [0.0123, 0.0456, 0.0789]
	props["pistol"]["scale"] = 0.06
	var path: String = "user://tripo_pose_file_selftest.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var read: Animation = TripoFigureRef._pose_from_file(figure, "aim_pistol", path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(read != null and read.get_meta("source", "") == "file", "%s: a pose file is read and says it came from a file" % figure)
	if read == null:
		return
	_check(read.get_track_count() == solved.get_track_count(), "%s: the file's %d bones are all in the pose (%d)" % [figure, solved.get_track_count(), read.get_track_count()])
	var back: Dictionary = TripoFigureRef.pose_to_json(figure, "aim_pistol", read)
	var arm: Array = back["bones"]["RightForeArm"]
	_check(_qdiff(Quaternion(arm[0], arm[1], arm[2], arm[3]), moved) < 0.00001, "%s: the bone he moved comes back as he wrote it" % figure)
	var prop: Dictionary = (read.get_meta("props") as Dictionary)["pistol"]
	_check((prop["pos"] as Vector3).distance_to(Vector3(0.0123, 0.0456, 0.0789)) < 0.00001 and absf(float(prop["scale"]) - 0.06) < 0.00001 and prop["bone"] == "RightHand",
		"%s: the pistol's placement comes back as he wrote it (%s)" % [figure, prop])


## How far apart two rotations are, as the distance between their quaternions (the shorter of q and -q: the same rotation). `Quaternion.angle_to` is not used:
## its acos(2d²-1) leaves a floor of ~7e-4 rad between two IDENTICAL quaternions.
func _qdiff(a: Quaternion, b: Quaternion) -> float:
	return minf((a - b).length(), (a + b).length())


func _test_pose(figure: String, id: String, lib: AnimationLibrary) -> void:
	var key: String = TripoFigureRef.POSE_PREFIX + id
	_check(lib.has_animation(key), "%s: the game set has the pose '%s'" % [figure, key])
	if not lib.has_animation(key):
		return
	var pose: Animation = lib.get_animation(key)
	var spec: Dictionary = TripoFigureRef.POSES[id]
	var expected: int = (spec["bones"] as PackedStringArray).size() + (6 if spec.has("two_hand_aim") else 0)
	_check(pose.get_track_count() == expected, "%s %s: %d rotation tracks (the listed bones, and the six solved arm bones)" % [figure, id, expected])
	## The set is the bank and the solver run TODAY: a pose re-spec'd without re-running tripo_game_clips.gd fails here, not on the board.
	var fresh: Animation = TripoFigureRef.bank_pose(figure, id)
	var worst: float = INF
	if fresh != null and fresh.get_track_count() == pose.get_track_count():
		worst = 0.0
		for t in range(pose.get_track_count()):
			var name: String = String(pose.track_get_path(t)).get_slice(":", 1)
			for u in range(fresh.get_track_count()):
				if String(fresh.track_get_path(u)).get_slice(":", 1) == name:
					worst = maxf(worst, _qdiff(pose.track_get_key_value(t, 0) as Quaternion, fresh.track_get_key_value(u, 0) as Quaternion))
	_check(worst < 0.0001, "%s %s: the game set matches the pose built now (worst bone %.7f)" % [figure, id, worst])
	if not spec.has("two_hand_aim"):
		return
	var aim: Dictionary = spec["two_hand_aim"]
	var wrists: Array[Vector3] = TripoFigureRef.pose_wrists(figure, pose)
	_check(wrists.size() == 3, "%s %s: the pose can be laid over the idle torso" % [figure, id])
	if wrists.size() != 3:
		return
	var right: Vector3 = wrists[0]
	var left: Vector3 = wrists[1]
	var dir: Vector3 = wrists[2]
	_check(absf(right.y - left.y) < 0.001 and absf(right.z - left.z) < 0.001, "%s %s: both wrists at the same height and distance (%.4f / %.4f apart)" % [figure, id, right.y - left.y, right.z - left.z])
	_check(absf((left.x - right.x) - float(aim["gap"])) < 0.002, "%s %s: the wrists are the asked gap apart (%.4f, asked %.4f)" % [figure, id, left.x - right.x, float(aim["gap"])])
	var want_pitch: float = rad_to_deg(atan2(float(aim["height"]), float(aim["reach"])))
	var pitch: float = rad_to_deg(asin(dir.y))
	var yaw: float = rad_to_deg(atan2(dir.x, dir.z))
	_check(absf(yaw) < 0.5 and absf(pitch - want_pitch) < 1.0, "%s %s: aims straight ahead (yaw %.2f°) at the asked pitch (%.2f°, asked %.2f°)" % [figure, id, yaw, pitch, want_pitch])


## The aim layer on a real skeleton: untouched at weight 0, the first stop at its weight, the last at 1 (read straight off the bones).
func _test_aim_layer(figure: String, lib: AnimationLibrary) -> void:
	var scene := load(TripoFigureRef.rig_path(figure, true)) as PackedScene
	var body := scene.instantiate() as Node3D
	var skeleton := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var draw: Animation = lib.get_animation(TripoFigureRef.POSE_PREFIX + "draw_pistol")
	var aim: Animation = lib.get_animation(TripoFigureRef.POSE_PREFIX + "aim_pistol")
	var layer = AimPoseRef.new()
	skeleton.add_child(layer)
	_check(layer.load_stops(skeleton, [[0.5, draw], [1.0, aim]]), "%s: the aim layer loads its two stops" % figure)
	var bone: int = TripoFigureRef.find_bone(skeleton, "RightForeArm")
	var rest: Quaternion = skeleton.get_bone_pose_rotation(bone)
	layer.weight = 0.0
	layer.apply_to(skeleton)
	_check(_qdiff(skeleton.get_bone_pose_rotation(bone), rest) < 0.00001, "%s: weight 0 leaves the arm as the clip wrote it" % figure)
	var stops: Array = [[0.5, draw], [1.0, aim]]
	for stop: Array in stops:
		layer.weight = float(stop[0])
		skeleton.reset_bone_poses()
		layer.apply_to(skeleton)
		var want: Quaternion = TripoPoseKitRef.bone_rotations(skeleton, stop[1] as Animation, 0.0)[bone]
		_check(_qdiff(skeleton.get_bone_pose_rotation(bone), want) < 0.0001, "%s: weight %.1f is exactly the pose" % [figure, float(stop[0])])
	body.free()


func _test_clip(figure: String, id: String, lib: AnimationLibrary, hips_rest: Vector3) -> void:
	_check(lib.has_animation(id), "%s: the game set has '%s'" % [figure, id])
	if not lib.has_animation(id):
		return
	var anim: Animation = lib.get_animation(id)
	var track: int = _hips_track(anim)
	_check(track >= 0 and anim.track_get_key_count(track) > 1, "%s %s: a Hips translation track" % [figure, id])
	if track < 0:
		return
	var keys: int = anim.track_get_key_count(track)
	var first: Vector3 = anim.track_get_key_value(track, 0)
	var last: Vector3 = anim.track_get_key_value(track, keys - 1)
	var drift: float = Vector2(last.x - first.x, last.z - first.z).length()
	_check(drift < DRIFT_MAX_M, "%s %s: in place (the Hips end %.5f m from where they start on the ground)" % [figure, id, drift])
	_check(absf(first.x - hips_rest.x) < DRIFT_MAX_M and absf(first.z - hips_rest.z) < DRIFT_MAX_M, "%s %s: the Hips start over their rest" % [figure, id])
	var low: float = INF
	var high: float = -INF
	for k in range(keys):
		var y: float = (anim.track_get_key_value(track, k) as Vector3).y
		low = minf(low, y)
		high = maxf(high, y)
	_check(low > hips_rest.y * 0.7 and high < hips_rest.y * 1.1, "%s %s: the Hips at the figure's own height (%.3f to %.3f m, rest %.3f)" % [figure, id, low, high, hips_rest.y])
	_check(anim.loop_mode == Animation.LOOP_LINEAR, "%s %s: loops" % [figure, id])
	## The set is the bank decoded TODAY: a clip re-banked without re-running tripo_game_clips.gd fails here, not on the board.
	var fresh: Animation = TripoFigureRef.bank_clip(figure, id, hips_rest)
	var fresh_track: int = _hips_track(fresh) if fresh != null else -1
	var worst: float = INF if fresh_track < 0 or fresh.track_get_key_count(fresh_track) != keys else 0.0
	if worst == 0.0:
		for k in range(keys):
			worst = maxf(worst, (anim.track_get_key_value(track, k) as Vector3).distance_to(fresh.track_get_key_value(fresh_track, k)))
	_check(worst < MATCH_MAX_M and fresh.get_track_count() == anim.get_track_count() and absf(fresh.length - anim.length) < 0.0001,
		"%s %s: the game set matches the bank decoded now (worst Hips key %.6f m)" % [figure, id, worst])
