## TripoPoseKit — authoring a POSE for a Tripo Agent in code, from where the hands go (MOVEMENT, 2026-11-08). No clip, no credit.
##
## A pose is a handful of bone rotations (`TripoFigure.POSES`, laid over the playing clip by `ActorAimPose3D`). Some come from a bank clip frame (the fingers'
## grip); the ARMS are SOLVED: given where each wrist goes and how each hand is turned, a two-bone IK (law of cosines, an elbow pole) gives the upper arm and the
## forearm, and the hand takes the asked orientation. Everything is computed on the rig's REST data by plain forward kinematics (skeleton space: +Z the front, +X the
## figure's left, +Y up), not on a posed node: the Skeleton3D caches its global poses and a headless tool cannot trust them, and the math is checkable against numbers.
##
## The twist of each bone about its own axis is kept from the IDLE pose: the elbow's bend-plane normal, measured on the idle arm and carried in each bone's local
## frame, is laid onto the new bend plane (a TRIAD), so a bent arm never rolls the way a shortest-arc rotation would.
class_name TripoPoseKit
extends RefCounted

const SIDES: PackedStringArray = ["Right", "Left"]
const MIXAMO_PREFIXES: PackedStringArray = ["mixamorig:", "mixamorig_", ""]


## The importer may keep the colon of `mixamorig:Hips` or turn it into an underscore: try both, then the bare name (`TripoFigure.find_bone`'s rule; this file
## cannot preload that one, it preloads this).
static func find_bone(skeleton: Skeleton3D, bone_name: String) -> int:
	for prefix: String in MIXAMO_PREFIXES:
		var idx: int = skeleton.find_bone(prefix + bone_name)
		if idx >= 0:
			return idx
	return -1


## Rotations of the bones an Animation keys, at `time`: bone index -> Quaternion. A bone it does not key keeps its rest rotation in the FK below.
static func bone_rotations(skeleton: Skeleton3D, anim: Animation, time: float) -> Dictionary:
	var rots: Dictionary = {}
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var idx: int = skeleton.find_bone(String(anim.track_get_path(t)).get_slice(":", 1))
		if idx >= 0:
			rots[idx] = anim.rotation_track_interpolate(t, time)
	return rots


## The global transform (skeleton space) of `bone` under `rots`, from the rest origins. `cache` is per call-site: one dictionary per pose evaluated.
static func bone_global(skeleton: Skeleton3D, bone: int, rots: Dictionary, cache: Dictionary) -> Transform3D:
	if cache.has(bone):
		return cache[bone]
	var rest: Transform3D = skeleton.get_bone_rest(bone)
	var local := Transform3D(Basis(rots[bone] as Quaternion) if rots.has(bone) else rest.basis.orthonormalized(), rest.origin)
	var parent: int = skeleton.get_bone_parent(bone)
	var global: Transform3D = bone_global(skeleton, parent, rots, cache) * local if parent >= 0 else local
	cache[bone] = global
	return global


## A rotation taking the bone-local pair (axis, normal) onto the world pair (axis, normal): the axis exactly, the normal as near as the axis allows.
static func triad(local_axis: Vector3, local_normal: Vector3, world_axis: Vector3, world_normal: Vector3) -> Basis:
	var la: Vector3 = local_axis.normalized()
	var ln: Vector3 = (local_normal - la * local_normal.dot(la)).normalized()
	var wa: Vector3 = world_axis.normalized()
	var wn: Vector3 = (world_normal - wa * world_normal.dot(wa)).normalized()
	return Basis(wa, wn, wa.cross(wn)) * Basis(la, ln, la.cross(ln)).inverse()


## One arm. `idle_rots` is the pose the layer sits on (chest, clavicle and the idle arm for the twist reference); `target` the wrist's place and `hand` the hand's
## global orientation, both skeleton space; `pole` the direction the elbow bends toward. Returns {"Arm", "ForeArm", "Hand"} -> local Quaternion, or {} (loud).
static func solve_arm(skeleton: Skeleton3D, side: String, idle_rots: Dictionary, target: Vector3, hand: Basis, pole: Vector3) -> Dictionary:
	var clav: int = find_bone(skeleton, side + "Shoulder")
	var arm: int = find_bone(skeleton, side + "Arm")
	var fore: int = find_bone(skeleton, side + "ForeArm")
	var hand_bone: int = find_bone(skeleton, side + "Hand")
	if clav < 0 or arm < 0 or fore < 0 or hand_bone < 0:
		push_error("[TripoPoseKit] the rig lacks the %s arm chain" % side)
		return {}
	var cache: Dictionary = {}
	var g_clav: Basis = bone_global(skeleton, clav, idle_rots, cache).basis.orthonormalized()
	var g_arm0: Transform3D = bone_global(skeleton, arm, idle_rots, cache)
	var g_fore0: Transform3D = bone_global(skeleton, fore, idle_rots, cache)
	var g_hand0: Transform3D = bone_global(skeleton, hand_bone, idle_rots, cache)
	var shoulder: Vector3 = g_arm0.origin
	var v1: Vector3 = skeleton.get_bone_rest(fore).origin   ## the elbow in the upper arm's frame
	var v2: Vector3 = skeleton.get_bone_rest(hand_bone).origin   ## the wrist in the forearm's frame
	var l1: float = v1.length()
	var l2: float = v2.length()
	## The hinge: the idle arm's bend-plane normal, in each bone's own frame.
	var n0: Vector3 = (g_fore0.origin - shoulder).cross(g_hand0.origin - g_fore0.origin).normalized()
	var n_arm: Vector3 = g_arm0.basis.orthonormalized().transposed() * n0
	var n_fore: Vector3 = g_fore0.basis.orthonormalized().transposed() * n0
	var to_target: Vector3 = target - shoulder
	var reach: float = clampf(to_target.length(), absf(l1 - l2) + 0.002, l1 + l2 - 0.002)
	var d: Vector3 = to_target.normalized()
	var wrist: Vector3 = shoulder + d * reach
	var cos_a: float = clampf((l1 * l1 + reach * reach - l2 * l2) / (2.0 * l1 * reach), -1.0, 1.0)
	var sin_a: float = sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var side_dir: Vector3 = (pole - d * pole.dot(d)).normalized()
	var elbow: Vector3 = shoulder + (d * cos_a + side_dir * sin_a) * l1
	var n_new: Vector3 = (elbow - shoulder).cross(wrist - elbow).normalized()
	var g_arm: Basis = triad(v1, n_arm, elbow - shoulder, n_new)
	var g_fore: Basis = triad(v2, n_fore, wrist - elbow, n_new)
	return {
		"Arm": (g_clav.transposed() * g_arm).get_rotation_quaternion(),
		"ForeArm": (g_arm.transposed() * g_fore).get_rotation_quaternion(),
		"Hand": (g_fore.transposed() * hand.orthonormalized()).get_rotation_quaternion(),
		"reach": reach, "wanted": to_target.length(),
	}


## The two-handed aim: both wrists ahead of the chest at the same distance (`reach`, the figure's own units, from the middle of the shoulders), `height` above
## that line, `gap` apart, each hand's thumb up and its palm toward the other (the right one's fingers along +Z, lifted `hand_pitch` degrees), the elbows bent down and a
## little out (`pole`).
## Writes the six rotation tracks into `pose`; false (loud) when something is missing.
static func solve_two_hand_aim(skeleton: Skeleton3D, idle: Animation, pose: Animation, spec: Dictionary) -> bool:
	var idle_rots: Dictionary = bone_rotations(skeleton, idle, 0.0)
	var cache: Dictionary = {}
	var s_right: Vector3 = bone_global(skeleton, find_bone(skeleton, "RightArm"), idle_rots, cache).origin
	var s_left: Vector3 = bone_global(skeleton, find_bone(skeleton, "LeftArm"), idle_rots, cache).origin
	var centre: Vector3 = (s_right + s_left) * 0.5 + Vector3(0.0, float(spec["height"]), float(spec["reach"]))
	var half: float = float(spec["gap"]) * 0.5
	## The right hand: fingers forward (+Y -> +Z), thumb up (+X -> +Y), palm toward the figure's left (+Z -> +X). The left is its mirror in the figure's mid-plane, and the
	## rig's own left hand frame is the right one's mirrored with one sign flipped, which `mirror * basis * flip` states.
	var right_hand := Basis(Vector3.RIGHT, -deg_to_rad(float(spec.get("hand_pitch", 0.0)))) \
		* Basis(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0))
	var mirror := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))
	var rest_r: Basis = bone_global(skeleton, find_bone(skeleton, "RightHand"), {}, {}).basis.orthonormalized()
	var rest_l: Basis = bone_global(skeleton, find_bone(skeleton, "LeftHand"), {}, {}).basis.orthonormalized()
	var turn_r: Basis = right_hand * rest_r.transposed()   ## the rotation from the right hand's rest to the asked pose
	var turn_l: Basis = mirror * turn_r * mirror           ## the same turn, mirrored
	var pole_out: float = float(spec["pole"])
	var solved: Dictionary = {
		"Right": solve_arm(skeleton, "Right", idle_rots, centre + Vector3(-half, 0.0, 0.0), right_hand, Vector3(-pole_out, -1.0, -0.15)),
		"Left": solve_arm(skeleton, "Left", idle_rots, centre + Vector3(half, 0.0, 0.0), turn_l * rest_l, Vector3(pole_out, -1.0, -0.15)),
	}
	var wrote: int = 0
	for side: String in SIDES:
		var arm: Dictionary = solved[side]
		if arm.is_empty():
			return false
		for bone: String in ["Arm", "ForeArm", "Hand"]:
			var name: String = skeleton.get_bone_name(find_bone(skeleton, side + bone))
			var track: int = -1
			for t in range(pose.get_track_count()):
				if String(pose.track_get_path(t)).get_slice(":", 1) == name:
					track = t
			if track < 0:
				track = pose.add_track(Animation.TYPE_ROTATION_3D)
				pose.track_set_path(track, NodePath("Armature/Skeleton3D:" + name))
				pose.rotation_track_insert_key(track, 0.0, arm[bone] as Quaternion)
			else:
				pose.track_set_key_value(track, 0, arm[bone] as Quaternion)
			wrote += 1
		if float(arm["wanted"]) > float(arm["reach"]) + 0.003:
			push_warning("[TripoPoseKit] the %s hand cannot reach its place: %.3f wanted, %.3f possible (the arm is straight)" % [side, arm["wanted"], arm["reach"]])
	return wrote == 6


## Where the wrists and the aim go under `pose` laid over the idle pose: [right wrist, left wrist, the aim direction] in skeleton space (the aim: from the middle
## of the shoulders to the middle of the wrists). For the selftest and for anyone adding a pose.
static func wrists_under(skeleton: Skeleton3D, idle: Animation, pose: Animation) -> Array[Vector3]:
	var rots: Dictionary = bone_rotations(skeleton, idle, 0.0)
	rots.merge(bone_rotations(skeleton, pose, 0.0), true)
	var cache: Dictionary = {}
	var rh: Vector3 = bone_global(skeleton, find_bone(skeleton, "RightHand"), rots, cache).origin
	var lh: Vector3 = bone_global(skeleton, find_bone(skeleton, "LeftHand"), rots, cache).origin
	var ra: Vector3 = bone_global(skeleton, find_bone(skeleton, "RightArm"), rots, cache).origin
	var la: Vector3 = bone_global(skeleton, find_bone(skeleton, "LeftArm"), rots, cache).origin
	return [rh, lh, (((rh + lh) - (ra + la)) * 0.5).normalized()]
