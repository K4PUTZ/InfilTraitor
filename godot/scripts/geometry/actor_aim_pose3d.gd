## ActorAimPose3D — a LAYER on a Tripo Agent: pulls a set of bones along a path of stored poses, on top of whatever clip is playing (MOVEMENT, 2026-11-08).
##
## WHY a layer and not a clip: the agent aims standing, walking into it or coming out of it; a clip per combination is a credit per combination, and the arms of a held
## aim do not depend on the legs. A STOP is a pose (`TripoFigure.POSES`, `pose_<id>` in the game set: rotation tracks, one key) at a `weight` along the path: the
## first stop is reached from the pose the player wrote this frame, each next one from the stop before. `weight` 0 leaves the skeleton untouched, 1 is the last stop;
## between two stops each bone takes a smoothed slerp, so the arms come to rest at every stop (a beat where the gun can appear). The caller moves `weight`: a raise and
## a lowering are the same path read forward and back.
##
## A `SkeletonModifier3D` for the same reason `ActorHeadTurn3D` is: it must run AFTER the AnimationPlayer has posed the skeleton this frame.
## Children of a skeleton run in order: add this one BEFORE the head turn, so the head reads the spine the aim left.
class_name ActorAimPose3D
extends SkeletonModifier3D

## 0..1 along the path of stops, set by the owner every frame.
var weight: float = 0.0
var _bones: PackedInt32Array = PackedInt32Array()
var _stop_at: PackedFloat32Array = PackedFloat32Array()   ## each stop's weight, ascending, the last one 1.0
var _stop_rots: Array = []                                  ## per stop: an Array[Quaternion] aligned with `_bones`
var _pos_bone: int = -1                                     ## the bone a whole-body pose also places (the Hips), -1 when no stop does
var _stop_pos: Array[Vector3] = []                          ## per stop, its place


## `stops`: [[weight, Animation], ...] ascending, the last weight 1.0. The bones are every stop's together (a hand-made aim keys the last finger joints, which the clip the draw
## comes from does not have). A bone a stop lacks keeps the stop before's rotation, or, before its first appearance, takes the next stop's that has it.
## A bone the skeleton lacks is skipped (said once). False (loud) when nothing resolved or the stops are not a path.
func load_stops(skeleton: Skeleton3D, stops: Array) -> bool:
	_bones.clear()
	_stop_at.clear()
	_stop_rots.clear()
	if stops.is_empty() or not is_equal_approx(float((stops[stops.size() - 1] as Array)[0]), 1.0):
		push_error("[ActorAimPose3D] the stops must end at weight 1")
		return false
	var previous: float = 0.0
	for stop: Array in stops:
		if float(stop[0]) <= previous:
			push_error("[ActorAimPose3D] the stops' weights must ascend")
			return false
		previous = float(stop[0])
	var per_stop: Array[Dictionary] = []
	var union: Dictionary = {}
	for stop: Array in stops:
		var here: Dictionary = _rotations(skeleton, stop[1] as Animation)
		per_stop.append(here)
		union.merge(here)
	if union.is_empty():
		push_error("[ActorAimPose3D] the poses have no bone this skeleton owns")
		return false
	_bones.append_array(PackedInt32Array(union.keys()))
	for i in range(stops.size()):
		var rots: Array[Quaternion] = []
		for bone: int in _bones:
			rots.append(_rotation_at(per_stop, i, bone))
		_stop_at.append(float((stops[i] as Array)[0]))
		_stop_rots.append(rots)
	_load_positions(skeleton, stops)
	return true


## The position track some stops carry (a whole-body stance moves the Hips; the idle under it must not show through). A stop without one keeps the nearest stop's, as a rotation does.
func _load_positions(skeleton: Skeleton3D, stops: Array) -> void:
	_pos_bone = -1
	_stop_pos.clear()
	var per_stop: Array = []
	for stop: Array in stops:
		var pose := stop[1] as Animation
		var here: Variant = null
		for t in range(pose.get_track_count()):
			if pose.track_get_type(t) == Animation.TYPE_POSITION_3D and pose.track_get_key_count(t) > 0:
				var idx: int = skeleton.find_bone(String(pose.track_get_path(t)).get_slice(":", 1))
				if idx >= 0:
					_pos_bone = idx
					here = pose.track_get_key_value(t, 0)
		per_stop.append(here)
	if _pos_bone < 0:
		return
	for i in range(per_stop.size()):
		var found: Variant = null
		for k in range(i, -1, -1):
			if found == null:
				found = per_stop[k]
		for k in range(i + 1, per_stop.size()):
			if found == null:
				found = per_stop[k]
		_stop_pos.append(found as Vector3)


## `bone` at stop `i`: its own key, else the nearest stop before that has one, else the nearest after.
func _rotation_at(per_stop: Array[Dictionary], i: int, bone: int) -> Quaternion:
	for k in range(i, -1, -1):
		if per_stop[k].has(bone):
			return per_stop[k][bone] as Quaternion
	for k in range(i + 1, per_stop.size()):
		if per_stop[k].has(bone):
			return per_stop[k][bone] as Quaternion
	return Quaternion.IDENTITY


## The rotation tracks of `pose` against `skeleton`: bone index -> Quaternion.
func _rotations(skeleton: Skeleton3D, pose: Animation) -> Dictionary:
	var out: Dictionary = {}
	for t in range(pose.get_track_count()):
		if pose.track_get_type(t) != Animation.TYPE_ROTATION_3D or pose.track_get_key_count(t) == 0:
			continue
		var bone_name: String = String(pose.track_get_path(t)).get_slice(":", 1)
		var idx: int = skeleton.find_bone(bone_name)
		if idx < 0:
			push_warning("[ActorAimPose3D] the skeleton has no bone '%s': the pose skips it" % bone_name)
			continue
		out[idx] = pose.track_get_key_value(t, 0) as Quaternion
	return out


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton != null:
		apply_to(skeleton)


## The whole modification, on a skeleton handed in (the engine's call above passes its own; a selftest passes a rig it holds, with no tree and no frame).
func apply_to(skeleton: Skeleton3D) -> void:
	if weight <= 0.0 or _bones.is_empty():
		return
	var stop: int = 0
	while stop < _stop_at.size() - 1 and weight > _stop_at[stop]:
		stop += 1
	var from_w: float = 0.0 if stop == 0 else _stop_at[stop - 1]
	var t: float = smoothstep(0.0, 1.0, clampf((weight - from_w) / (_stop_at[stop] - from_w), 0.0, 1.0))
	var to_rots: Array = _stop_rots[stop]
	for i in range(_bones.size()):
		var bone: int = _bones[i]
		var from_q: Quaternion = skeleton.get_bone_pose_rotation(bone) if stop == 0 else (_stop_rots[stop - 1] as Array)[i]
		skeleton.set_bone_pose_rotation(bone, from_q.slerp(to_rots[i], t))
	if _pos_bone >= 0:
		var from_p: Vector3 = skeleton.get_bone_pose_position(_pos_bone) if stop == 0 else _stop_pos[stop - 1]
		skeleton.set_bone_pose_position(_pos_bone, from_p.lerp(_stop_pos[stop], t))
