## ActorHeadTurn3D — turns a live rig's head about the vertical, on top of whatever action is playing (R3D-ACTORS, the
## mesh half of `AgentSprite`'s head layer). A `SkeletonModifier3D` because it has to run AFTER the AnimationPlayer has
## posed the skeleton this frame; a bone pose written from `_process` would be overwritten by the next seek.
##
## `yaw` is relative to the body (`ActorMesh3D` clamps it to `AgentSprite.HEAD_YAW_LIMIT_DEG`), about the skeleton's up
## axis, so a crouched figure whose neck is pitched still turns its head around the vertical rather than around its own
## tilted neck.
class_name ActorHeadTurn3D
extends SkeletonModifier3D

const HEAD_BONE := "head"

var yaw: float = 0.0
var _bone: int = -2


func _process_modification_with_delta(_delta: float) -> void:
	if is_zero_approx(yaw):
		return
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	if _bone == -2:
		_bone = skeleton.find_bone(HEAD_BONE)
		if _bone < 0:
			push_error("[ActorHeadTurn3D] the rig has no '%s' bone" % HEAD_BONE)
	if _bone < 0:
		return
	var parent: int = skeleton.get_bone_parent(_bone)
	var up := Vector3.UP
	if parent >= 0:
		up = (skeleton.get_bone_global_pose(parent).basis.inverse() * Vector3.UP).normalized()
	var turned := Quaternion(up, yaw) * skeleton.get_bone_pose_rotation(_bone)
	skeleton.set_bone_pose_rotation(_bone, turned)
