## tripo_pose_dump — what a Blender pose session starts from (MOVEMENT, 2026-11-08; `tools/persistent/pose_lab.py` runs it).
##
## For one figure it writes into a folder:
##   <figure>_rest.json            every bone of the LIGHT rig: name (Mixamo, no prefix), parent, the REST rotation / origin in skeleton space, as Godot reads them. Blender needs it to
##                                 turn a Godot local rotation into a pose bone and back without guessing the importer's bone frames.
##   <figure>_idle.json            every bone's LOCAL rotation in the idle clip at t = 0, or at the `--idle-frame=N` asked (24 fps clip frames; MOVEMENT 2026-11-12: frame 145 is the
##                                 one whose coat lies farthest from the legs, female and male) (the pose a layer sits on): Blender shows the bones a pose does not name as the game has them.
##   <figure>_<id>_start.json      the pose `id` as the game plays it TODAY (the Director's file when there is one, else the solved pose): `TripoFigure.pose_to_json()`.
##
## Usage (from the repo root):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script godot/scripts/tools/tripo_pose_dump.gd -- <figure> <out_dir> [<pose id> ...]
## With no pose id, every pose of `TripoFigure.POSES` is written. `--idle-frame=N` may stand anywhere after the out_dir.
extends SceneTree

const TripoFigureRef = preload("res://godot/scripts/geometry/tripo_figure.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2 or not TripoFigureRef.FIGURES.has(args[0]):
		push_error("[tripo_pose_dump] usage: -- <female|male> <out_dir> [pose id ...]")
		quit(1)
		return
	var idle_time: float = 0.0
	var plain: PackedStringArray = PackedStringArray()
	for a: String in args:
		if a.begins_with("--idle-frame="):
			idle_time = float(a.substr("--idle-frame=".length())) / 24.0
		else:
			plain.append(a)
	args = plain
	var figure: String = args[0]
	var out_dir: String = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ids: PackedStringArray = args.slice(2) if args.size() > 2 else PackedStringArray(TripoFigureRef.POSES.keys())
	var fails: int = _write_rest(figure, out_dir)
	fails += _write_idle(figure, out_dir, idle_time)
	for id: String in ids:
		fails += _write_pose(figure, id, out_dir)
	quit(1 if fails > 0 else 0)


func _write_rest(figure: String, out_dir: String) -> int:
	var scene := load(TripoFigureRef.rig_path(figure, true)) as PackedScene
	if scene == null:
		push_error("[tripo_pose_dump] cannot load %s" % TripoFigureRef.rig_path(figure, true))
		return 1
	var holder := scene.instantiate()
	var skeletons: Array[Node] = holder.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		holder.free()
		push_error("[tripo_pose_dump] the rig has no skeleton")
		return 1
	var skeleton := skeletons[0] as Skeleton3D
	var rows: Array = []
	for i in range(skeleton.get_bone_count()):
		var g: Transform3D = skeleton.get_bone_global_rest(i)
		var q: Quaternion = g.basis.orthonormalized().get_rotation_quaternion()
		var parent: int = skeleton.get_bone_parent(i)
		rows.append({
			"name": _short(skeleton.get_bone_name(i)),
			"parent": _short(skeleton.get_bone_name(parent)) if parent >= 0 else "",
			"rest_quat": [q.x, q.y, q.z, q.w],
			"rest_origin": [g.origin.x, g.origin.y, g.origin.z],
		})
	holder.free()
	return _save(out_dir.path_join("%s_rest.json" % figure), {"format": "infiltraitor-rest", "v": 1, "figure": figure, "bones": rows})


func _write_idle(figure: String, out_dir: String, time: float) -> int:
	var rig: Dictionary = TripoFigureRef._rig(figure)
	var idle: Animation = TripoFigureRef._load_bank_animation(figure, "idle")
	if rig.is_empty() or idle == null:
		return 1
	var skeleton := rig["skeleton"] as Skeleton3D
	var rots: Dictionary = TripoFigureRef.TripoPoseKitRef.bone_rotations(skeleton, idle, time)
	var bones: Dictionary = {}
	for i in range(skeleton.get_bone_count()):
		var q: Quaternion = rots[i] if rots.has(i) else skeleton.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
		bones[_short(skeleton.get_bone_name(i))] = [q.x, q.y, q.z, q.w]
	var hips: int = TripoFigureRef.TripoPoseKitRef.find_bone(skeleton, "Hips")
	var clip: Animation = TripoFigureRef.bank_clip(figure, "idle", skeleton.get_bone_rest(hips).origin)
	var at: Vector3 = skeleton.get_bone_rest(hips).origin
	for t in range(clip.get_track_count()):
		if clip.track_get_type(t) == Animation.TYPE_POSITION_3D:
			at = clip.position_track_interpolate(t, time)
	(rig["holder"] as Node).free()
	return _save(out_dir.path_join("%s_idle.json" % figure), {"format": "infiltraitor-idle", "v": 1, "figure": figure, "bones": bones, "hips_pos": [at.x, at.y, at.z]})


func _write_pose(figure: String, id: String, out_dir: String) -> int:
	var pose: Animation = TripoFigureRef.bank_pose(figure, id)
	if pose == null:
		return 1
	var data: Dictionary = TripoFigureRef.pose_to_json(figure, id, pose)
	data["source"] = String(pose.get_meta("source", "?"))
	return _save(out_dir.path_join("%s_%s_start.json" % [figure, id]), data)


func _short(bone: String) -> String:
	for prefix: String in TripoFigureRef.MIXAMO_PREFIXES:
		if not prefix.is_empty() and bone.begins_with(prefix):
			return bone.trim_prefix(prefix)
	return bone


func _save(path: String, data: Dictionary) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[tripo_pose_dump] cannot write %s" % path)
		return 1
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("[tripo_pose_dump] wrote %s" % path)
	return 0
