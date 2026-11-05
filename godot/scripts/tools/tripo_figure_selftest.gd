## tripo_figure_selftest — MOVEMENT MV-4, first slice: what a Tripo actor reads before it is drawn. The drawing is checked by capture; this pins
## what a capture cannot see: that each figure's GAME SET exists, holds the clips the game plays and is the bank decoded today (a stale set
## would play yesterday's clip with no error), that every clip is IN PLACE (the grid moves the actor, a drifting Hips would walk it off its
## cell) with the Hips at the figure's own height, that the travel the walk is phased by is there, and that the rig answers the bones and
## pieces the game asks it for.
extends SceneTree

const TripoFigureRef = preload("res://godot/scripts/geometry/tripo_figure.gd")
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
