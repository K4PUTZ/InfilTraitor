## ActorRecoil3D — the kick of a shot on a Tripo Agent's arms (MOVEMENT, 2026-11-12).
##
## A LAYER after the aim (`ActorAimPose3D`): on `kick()` the arms, forearms and wrists of BOTH arms pitch up about the gun's own lateral axis
## (taken at the kick), fast, then ease back to wherever the aim layer holds them. Nothing is stored between shots: the envelope is a function of
## the time since the kick, and at zero it leaves the skeleton untouched. Two-handed: each joint takes the same world rotation on both sides, so
## the hands rise together and the grip holds. Procedural on purpose: an upper-body reaction of a quarter second needs no clip (the in-house rule
## of 2026-11-08: credits are for whole-body motion).
##
## A `SkeletonModifier3D` added after the aim layer and before the head turn (children of a skeleton run in order).
class_name ActorRecoil3D
extends SkeletonModifier3D

const TripoFigureRef = preload("res://godot/scripts/geometry/tripo_figure.gd")

## Peak pitch per joint, degrees, ADDED down the chain (the wrist's total is the sum of its parents'). Stats are `var` (rule 1).
var arm_deg: float = 1.5
var forearm_deg: float = 3.0
var hand_deg: float = 7.0
## The envelope: up in `rise_s`, back to rest by `rise_s + settle_s` (an ease-out, so the settle reads as the arms finding the aim again).
var rise_s: float = 0.035
var settle_s: float = 0.26

var _chain: Array = []                 ## [[bone, degrees], ...] parent before child
var _axis: Vector3 = Vector3.ZERO      ## skeleton space, the pitch axis of this kick
var _since: float = INF                ## seconds since the kick


## Resolves the six joints on `skeleton` (Mixamo names, either prefix). False (loud) when an arm is missing.
func setup(skeleton: Skeleton3D) -> bool:
	_chain.clear()
	for side: String in ["Right", "Left"]:
		for joint: Array in [["Arm", arm_deg], ["ForeArm", forearm_deg], ["Hand", hand_deg]]:
			var idx: int = TripoFigureRef.find_bone(skeleton, side + String(joint[0]))
			if idx < 0:
				push_error("[ActorRecoil3D] no bone '%s%s': the shot has no kick" % [side, joint[0]])
				_chain.clear()
				return false
			_chain.append([idx, float(joint[1])])
	return true


## A shot: `axis_global` is the gun's lateral axis in global space (a positive turn about it raises the barrel).
func kick(axis_global: Vector3) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or axis_global.length_squared() < 1e-8:
		return
	_axis = (skeleton.global_basis.orthonormalized().inverse() * axis_global).normalized()
	_since = 0.0


## 0..1 at `t` seconds after the kick.
func envelope(t: float) -> float:
	if t < 0.0 or t >= rise_s + settle_s:
		return 0.0
	if t < rise_s:
		return smoothstep(0.0, rise_s, t)
	var u: float = (t - rise_s) / settle_s
	return pow(1.0 - u, 2.0)


func _process_modification_with_delta(delta: float) -> void:
	if _since == INF:
		return
	_since += delta
	var skeleton: Skeleton3D = get_skeleton()
	var e: float = envelope(_since)
	if e <= 0.0:
		_since = INF
		return
	if skeleton != null:
		apply_to(skeleton, e)


## The kick at envelope `e` on `skeleton` (a selftest passes its own rig).
func apply_to(skeleton: Skeleton3D, e: float) -> void:
	for link: Array in _chain:
		var bone: int = int(link[0])
		var turn := Quaternion(_axis, deg_to_rad(float(link[1]) * e))
		var parent: int = skeleton.get_bone_parent(bone)
		var gp: Quaternion = skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		## The global turn expressed in the parent's frame, then the joint's own rotation: the joint (and what hangs from it) turns about its own pivot.
		skeleton.set_bone_pose_rotation(bone, (gp.inverse() * turn * gp) * skeleton.get_bone_pose_rotation(bone))
