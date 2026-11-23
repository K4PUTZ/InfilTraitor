## ActorRecoil3D — the kick of a shot on a Tripo Agent's upper body (MOVEMENT, 2026-11-12; the long guns' kick 2026-11-22).
##
## A LAYER after the aim (`ActorAimPose3D`): on `kick()` the joints of the shot's PROFILE pitch up about the gun's own lateral axis (taken at the
## kick), fast, then ease back to wherever the aim layer holds them. Nothing is stored between shots: the envelope is a function of the time since
## the kick, and at zero it leaves the skeleton untouched. Each joint takes the same world rotation on both sides, so the hands rise together and
## the grip holds. Procedural on purpose: an upper-body reaction of a fraction of a second needs no clip (the in-house rule of 2026-11-08: credits
## are for whole-body motion).
##
## THE PROFILES (`profiles`, chosen by `ActorMesh3D.fire_kick()` from the hold family and the stance):
## - "pistol" (2026-11-12): the arms, forearms and wrists; the gun also kicks in the hand (`gun_deg` up about its grip, `gun_back` along the barrel).
## - "shotgun:hip" / "shotgun:aimed" (2026-11-22, the Director: the long gun's two shots get a recoil): the TRUNK rocks back (Spine, Spine1, Spine2:
##   everything above turns with it, both arms and the gun, so the hands stay on the gun) and the arms add the muzzle's climb. At the hip the arms
##   take more of it (no shoulder behind the butt); aimed, the trunk does (the butt in the shoulder, the head going with the cheek on the stock).
##   The gun does not move in the hands; it settles slower than the pistol.
## A profile's joint degrees ADD down the chain (the wrist's total is the sum of its parents'). Stats are `var` (rule 1).
##
## A `SkeletonModifier3D` added after the aim layer and before the head turn (children of a skeleton run in order).
class_name ActorRecoil3D
extends SkeletonModifier3D

const TripoFigureRef = preload("res://godot/scripts/geometry/tripo_figure.gd")

## The chain, parent before child: [joint key in a profile, Mixamo bone name without its side, the sides it is found on].
const CHAIN: Array = [
	["spine", "Spine", [""]],
	["spine1", "Spine1", [""]],
	["spine2", "Spine2", [""]],
	["arm", "Arm", ["Right", "Left"]],
	["forearm", "ForeArm", ["Right", "Left"]],
	["hand", "Hand", ["Right", "Left"]],
]
## Peak pitch per joint (degrees), the envelope (up in `rise_s`, back to rest by `rise_s + settle_s`, an ease-out so the settle reads as the body
## finding the aim again) and the gun's own kick in the hand (degrees up about its grip, model units back along the barrel).
var profiles: Dictionary = {
	"pistol": {"spine": 0.0, "spine1": 0.0, "spine2": 0.0, "arm": 1.5, "forearm": 3.0, "hand": 7.0,
		"rise_s": 0.035, "settle_s": 0.26, "gun_deg": 6.0, "gun_back": 0.012},
	"shotgun:hip": {"spine": 1.5, "spine1": 2.0, "spine2": 2.5, "arm": 1.5, "forearm": 2.5, "hand": 4.0,
		"rise_s": 0.045, "settle_s": 0.4, "gun_deg": 0.0, "gun_back": 0.0},
	"shotgun:aimed": {"spine": 2.0, "spine1": 3.0, "spine2": 4.0, "arm": 0.5, "forearm": 1.0, "hand": 2.0,
		"rise_s": 0.045, "settle_s": 0.45, "gun_deg": 0.0, "gun_back": 0.0},
}

var _chain: Array = []                 ## [[bone, joint key], ...] parent before child
var _profile: Dictionary = {}          ## the profile of the last kick
var _axis: Vector3 = Vector3.ZERO      ## skeleton space, the pitch axis of this kick
var _since: float = INF                ## seconds since the kick


## Resolves the chain's nine joints on `skeleton` (Mixamo names, either prefix). False (loud) when one is missing.
func setup(skeleton: Skeleton3D) -> bool:
	_chain.clear()
	_profile = profiles["pistol"]
	for link: Array in CHAIN:
		for side: String in link[2]:
			var idx: int = TripoFigureRef.find_bone(skeleton, side + String(link[1]))
			if idx < 0:
				push_error("[ActorRecoil3D] no bone '%s%s': the shot has no kick" % [side, link[1]])
				_chain.clear()
				return false
			_chain.append([idx, String(link[0])])
	return true


## The profile a shot of `family` from `stance` kicks with: "family:stance", else "family", else the pistol's.
func profile_for(family: String, stance: String) -> String:
	var key: String = "%s:%s" % [family, stance]
	if profiles.has(key):
		return key
	return family if profiles.has(family) else "pistol"


## A shot: `axis_global` is the gun's lateral axis in global space (a positive turn about it raises the barrel); `profile` a key of `profiles`.
func kick(axis_global: Vector3, profile: String = "pistol") -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or axis_global.length_squared() < 1e-8:
		return
	if not profiles.has(profile):
		push_warning("[ActorRecoil3D] no recoil profile '%s': the pistol's is used" % profile)
		profile = "pistol"
	_profile = profiles[profile]
	_axis = (skeleton.global_basis.orthonormalized().inverse() * axis_global).normalized()
	_since = 0.0


## The gun's own kick in the hand for the last shot: degrees up about its grip, model units back along the barrel.
func gun_kick_deg() -> float:
	return float(_profile.get("gun_deg", 0.0))


func gun_kick_back() -> float:
	return float(_profile.get("gun_back", 0.0))


## 0..1 at `t` seconds after the kick.
func envelope(t: float) -> float:
	var rise: float = float(_profile.get("rise_s", 0.035))
	var settle: float = float(_profile.get("settle_s", 0.26))
	if t < 0.0 or t >= rise + settle:
		return 0.0
	if t < rise:
		return smoothstep(0.0, rise, t)
	var u: float = (t - rise) / settle
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
		var deg: float = float(_profile.get(String(link[1]), 0.0))
		if deg == 0.0:
			continue
		var bone: int = int(link[0])
		var turn := Quaternion(_axis, deg_to_rad(deg * e))
		var parent: int = skeleton.get_bone_parent(bone)
		var gp: Quaternion = skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		## The global turn expressed in the parent's frame, then the joint's own rotation: the joint (and what hangs from it) turns about its own pivot.
		skeleton.set_bone_pose_rotation(bone, (gp.inverse() * turn * gp) * skeleton.get_bone_pose_rotation(bone))
