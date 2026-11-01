## CoatPush3D — the legs push the coat (ACTOR D94, 2026-11-01): feeds `coat_push.gdshaderinc` its capsules every frame. A `SkeletonModifier3D` for the same reason as
## `ActorHeadTurn3D`: it reads the skeleton AFTER the AnimationPlayer has posed it this frame. It writes no bone: the shader moves the coat's vertices (each one along the
## direction baked into the model, to the far side of the leg capsules its ray crosses), so the pose is a function of the current pose alone, with no state a yaw snap of
## the grid could whip. The maths and the why are in `tools/asset_generation/tripo/coat_push.py`; `tripo_coat_push.py` bakes the vertex data and the capsule radii
## (the coat's `coat_push` property, which arrives as `extras` metadata) into the Agent.
##
## Use: `CoatPush3D.attach(skeleton, coat)`, `coat` being the figure's `Outfit_Coat` MeshInstance3D; its material must be a ShaderMaterial of a shader that includes
## `coat_push.gdshaderinc` (`actor_mesh3d.gdshader` does), one material per figure (the capsules are per figure).
class_name CoatPush3D
extends SkeletonModifier3D

const MIXAMO_PREFIXES: PackedStringArray = ["mixamorig:", "mixamorig_", ""]
## the capsules, left leg then right: [start joint, end joint, radius key in the spec]
const LEG: Array = [["UpLeg", "Leg", "r_thigh"], ["Leg", "Foot", "r_shin"], ["Foot", "ToeBase", "r_foot"]]
const SIDES: PackedStringArray = ["Left", "Right"]
const CULL_MARGIN_M: float = 0.4   ## the push moves a vertex up to ~30 cm past the skinned bounds

var _skeleton: Skeleton3D = null
var _materials: Array[ShaderMaterial] = []
var _from: PackedInt32Array = []
var _to: PackedInt32Array = []
var _hips: int = -1
var _hips_rest: Basis = Basis.IDENTITY
var _radius: PackedFloat32Array = []
var _cap_a: PackedVector4Array = []
var _cap_b: PackedVector4Array = []


## The `coat_push` numbers baked into `coat` (they arrive as the piece's `extras` metadata), or {} when it carries none.
static func spec_of(coat: MeshInstance3D) -> Dictionary:
	if not coat.has_meta("extras"):
		return {}
	var extras: Variant = coat.get_meta("extras")
	if not (extras is Dictionary) or not (extras as Dictionary).has("coat_push"):
		return {}
	var parsed: Variant = JSON.parse_string(str((extras as Dictionary)["coat_push"]))
	return parsed as Dictionary if parsed is Dictionary else {}


## Makes `skeleton`'s coat (`coat`: the MeshInstance3D of `Outfit_Coat`) pushed out of the legs; returns false (and says why) when the model lacks the data.
static func attach(skeleton: Skeleton3D, coat: MeshInstance3D) -> bool:
	var spec: Dictionary = spec_of(coat)
	if spec.is_empty():
		push_error("[CoatPush3D] %s carries no `coat_push` data (run tripo_coat_push.py)" % coat.name)
		return false
	var modifier := CoatPush3D.new()
	if not modifier._configure(skeleton, coat, spec):
		modifier.free()
		return false
	skeleton.add_child(modifier)
	return true


func _configure(skeleton: Skeleton3D, coat: MeshInstance3D, spec: Dictionary) -> bool:
	_skeleton = skeleton
	_hips = _find(skeleton, "Hips")
	if _hips < 0:
		push_error("[CoatPush3D] the rig has no Hips")
		return false
	_hips_rest = skeleton.get_bone_global_rest(_hips).basis
	var delta: float = float(spec.get("delta", 0.0))
	for side: String in SIDES:
		for leg: Array in LEG:
			var from_bone: int = _find(skeleton, side + String(leg[0]))
			var to_bone: int = _find(skeleton, side + String(leg[1]))
			if from_bone < 0 or to_bone < 0 or not spec.has(String(leg[2])):
				push_error("[CoatPush3D] no %s%s -> %s for the capsules" % [side, leg[0], leg[1]])
				return false
			_from.append(from_bone)
			_to.append(to_bone)
			_radius.append(float(spec[String(leg[2])]) + delta)
	_cap_a.resize(_from.size())
	_cap_b.resize(_from.size())
	var material: ShaderMaterial = (coat.material_override if coat.material_override != null else coat.get_active_material(0)) as ShaderMaterial
	if material == null or material.shader == null or not material.shader.code.contains("coat_push"):
		push_error("[CoatPush3D] %s's material is not a ShaderMaterial that includes coat_push.gdshaderinc" % coat.name)
		return false
	_materials.append(material)
	material.set_shader_parameter("push_on", 1.0)
	material.set_shader_parameter("push_tent", Vector4(float(spec.get("w_min", 0.03)), float(spec.get("w_max", 0.12)), float(spec.get("k_w", 0.5)), 0.0))
	coat.extra_cull_margin = CULL_MARGIN_M
	return true


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = _skeleton
	if not is_instance_valid(skeleton) or _hips < 0:
		return
	for i in range(_from.size()):
		var a: Vector3 = skeleton.get_bone_global_pose(_from[i]).origin
		var b: Vector3 = skeleton.get_bone_global_pose(_to[i]).origin
		_cap_a[i] = Vector4(a.x, a.y, a.z, _radius[i])
		_cap_b[i] = Vector4(b.x, b.y, b.z, 0.0)
	var turn: Basis = skeleton.get_bone_global_pose(_hips).basis * _hips_rest.inverse()
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("push_cap_a", _cap_a)
		material.set_shader_parameter("push_cap_b", _cap_b)
		material.set_shader_parameter("push_pelvis", turn)


## The importer may keep the colon of `mixamorig:Hips` or turn it into an underscore: try both, then the bare name.
static func _find(skeleton: Skeleton3D, bone_name: String) -> int:
	for prefix: String in MIXAMO_PREFIXES:
		var idx: int = skeleton.find_bone(prefix + bone_name)
		if idx >= 0:
			return idx
	return -1
