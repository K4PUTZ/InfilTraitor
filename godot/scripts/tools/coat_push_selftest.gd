## coat_push_selftest — ACTOR D94, the legs push the coat. The drawing is checked by capture; this pins what a capture cannot see: that every shipped Agent carries the data the
## vertex shader reads (the `coat_push` numbers on the coat, COLOR and UV2 on the coat's vertices, nothing on the other pieces: a piece with no colour reads (1,1,1,1) and is never
## pushed), that `CoatPush3D` refuses a model without it, and that it feeds the shader what the skeleton says (a capsule's joints follow their bones, the pelvis turn is the identity at rest).
extends SceneTree

const CoatPushRef = preload("res://godot/scripts/geometry/coat_push3d.gd")
const AGENT_PATH := "res://ASSETS/MODELS/official/AGENT_%s.glb"
const AGENTS: PackedStringArray = ["MALE", "FEMALE", "MALE_LIGHT", "FEMALE_LIGHT"]
const SHADER_PATH := "res://godot/shaders/actor_mesh3d.gdshader"
const SPEC_KEYS: PackedStringArray = ["r_thigh", "r_shin", "r_foot", "delta", "w_min", "w_max", "k_w"]

var _fails: int = 0


func _init() -> void:
	_run()   # a coroutine: the pose checks wait for the skeleton's own update, which happens in a frame


func _run() -> void:
	print("\n" + "=".repeat(70))
	print("COAT-PUSH SELFTEST")
	print("=".repeat(70) + "\n")
	for agent: String in AGENTS:
		_test_agent(agent)
	_test_refusal()
	await _test_feeds_the_shader()
	print("")
	if _fails == 0:
		print("[COAT-PUSH] RESULT: PASS — all checks passed")
		quit(0)
	else:
		print("[COAT-PUSH] RESULT: FAIL — %d check(s) failed" % _fails)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("[COAT-PUSH] ✅ %s" % label)
	else:
		print("[COAT-PUSH] ❌ %s" % label)
		_fails += 1


func _instance(agent: String) -> Node3D:
	var scene := load(AGENT_PATH % agent) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _piece(body: Node, piece: String) -> MeshInstance3D:
	var found: Array[Node] = body.find_children(piece, "MeshInstance3D", true, false)
	return found[0] as MeshInstance3D if not found.is_empty() else null


func _test_agent(agent: String) -> void:
	var body: Node3D = _instance(agent)
	_check(body != null, "%s loads" % agent)
	if body == null:
		return
	var coat: MeshInstance3D = _piece(body, "Outfit_Coat*")
	_check(coat != null, "%s has its coat" % agent)
	if coat == null:
		body.free()
		return
	var spec: Dictionary = CoatPushRef.spec_of(coat)
	var missing: Array[String] = []
	for key: String in SPEC_KEYS:
		if not spec.has(key) or float(spec[key]) <= 0.0:
			missing.append(key)
	_check(missing.is_empty(), "%s: the coat carries its `coat_push` numbers (missing %s)" % [agent, missing])
	if not spec.is_empty():
		_check(float(spec["r_thigh"]) > 0.04 and float(spec["r_thigh"]) < 0.1 and float(spec["r_shin"]) < float(spec["r_thigh"]) and float(spec["delta"]) < 0.02,
			"%s: the capsules are leg-sized (thigh %.3f, shin %.3f, foot %.3f, offset %.3f m)" % [agent, spec["r_thigh"], spec["r_shin"], spec["r_foot"], spec["delta"]])
	var arrays: Array = coat.mesh.surface_get_arrays(0)
	var colors: Variant = arrays[Mesh.ARRAY_COLOR]
	var dirs: Variant = arrays[Mesh.ARRAY_TEX_UV2]
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	_check(colors is PackedColorArray and (colors as PackedColorArray).size() == count and dirs is PackedVector2Array and (dirs as PackedVector2Array).size() == count,
		"%s: every one of the coat's %d vertices has a colour (mask, rest push) and a UV2 (direction)" % [agent, count])
	if colors is PackedColorArray and dirs is PackedVector2Array:
		var pushed: int = 0
		var unit: bool = true
		var rest_ok: bool = true
		for i in range(count):
			var c: Color = (colors as PackedColorArray)[i]
			if c.r < 0.5:
				pushed += 1
				unit = unit and absf((dirs as PackedVector2Array)[i].length() - 1.0) < 0.02
			rest_ok = rest_ok and c.g >= 0.0 and c.g <= 1.0
		_check(pushed > count / 10 and pushed < count * 3 / 4, "%s: %d of %d coat vertices are pushed (the skirt, not the whole coat)" % [agent, pushed, count])
		_check(unit, "%s: a pushed vertex's direction is a unit vector" % agent)
		_check(rest_ok, "%s: the rest push is a fraction" % agent)
	var trousers: MeshInstance3D = _piece(body, "Outfit_Trousers_Coated")
	if trousers != null:
		_check(trousers.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] == null, "%s: the trousers carry no colour (so the shader never pushes them)" % agent)
	body.free()


func _test_refusal() -> void:
	var body: Node3D = _instance("MALE_LIGHT")
	var skeleton := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var trousers: MeshInstance3D = _piece(body, "Outfit_Trousers_Coated")
	_check(not CoatPushRef.attach(skeleton, trousers), "a piece without `coat_push` data is refused (the push_error above is on purpose)")
	var coat: MeshInstance3D = _piece(body, "Outfit_Coat*")
	_check(not CoatPushRef.attach(skeleton, coat), "a coat whose material is not the shader that includes the push is refused (the push_error above is on purpose)")
	body.free()


## Frames for the skeleton to pose itself (it recomputes its global poses, and runs its modifiers, in the frame after a pose is set).
func _settle() -> void:
	for i in range(3):
		await process_frame


func _test_feeds_the_shader() -> void:
	var body: Node3D = _instance("MALE_LIGHT")
	root.add_child(body)   # the skeleton updates (and runs its modifiers) only inside the tree
	var skeleton := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var coat: MeshInstance3D = _piece(body, "Outfit_Coat*")
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	coat.material_override = material
	_check(CoatPushRef.attach(skeleton, coat), "a coat whose material uses actor_mesh3d.gdshader is attached")
	_check(is_equal_approx(float(material.get_shader_parameter("push_on")), 1.0), "the material is switched on")
	var spec: Dictionary = CoatPushRef.spec_of(coat)
	var thigh_l: int = CoatPushRef._find(skeleton, "LeftUpLeg")
	var knee_l: int = CoatPushRef._find(skeleton, "LeftLeg")
	await _settle()
	var cap_a: PackedVector4Array = material.get_shader_parameter("push_cap_a")
	var cap_b: PackedVector4Array = material.get_shader_parameter("push_cap_b")
	_check(cap_a.size() == 6 and cap_b.size() == 6, "six capsules (thigh, shin, foot of each leg) are handed over by the skeleton's own update")
	var hip: Vector3 = skeleton.get_bone_global_pose(thigh_l).origin
	var knee: Vector3 = skeleton.get_bone_global_pose(knee_l).origin
	_check(Vector3(cap_a[0].x, cap_a[0].y, cap_a[0].z).is_equal_approx(hip) and Vector3(cap_b[0].x, cap_b[0].y, cap_b[0].z).is_equal_approx(knee),
		"the left thigh's capsule runs from its hip joint to its knee, in the skeleton's space")
	_check(is_equal_approx(cap_a[0].w, float(spec["r_thigh"]) + float(spec["delta"])), "its radius is the thigh's plus the cloth's offset (%.3f)" % cap_a[0].w)
	var turn: Basis = material.get_shader_parameter("push_pelvis")
	_check(turn.is_equal_approx(Basis.IDENTITY), "the pelvis has not turned at rest")
	skeleton.set_bone_pose_rotation(thigh_l, skeleton.get_bone_pose_rotation(thigh_l) * Quaternion(Vector3.RIGHT, deg_to_rad(40.0)))
	await _settle()
	cap_b = material.get_shader_parameter("push_cap_b")
	var knee_after: Vector3 = skeleton.get_bone_global_pose(knee_l).origin
	_check(knee_after.distance_to(knee) > 0.05 and Vector3(cap_b[0].x, cap_b[0].y, cap_b[0].z).is_equal_approx(knee_after),
		"turn the thigh 40 degrees and the capsule's knee end follows its bone (moved %.3f m)" % knee_after.distance_to(knee))
	var hips: int = CoatPushRef._find(skeleton, "Hips")
	skeleton.set_bone_pose_rotation(hips, skeleton.get_bone_pose_rotation(hips) * Quaternion(Vector3.RIGHT, deg_to_rad(30.0)))
	await _settle()
	turn = material.get_shader_parameter("push_pelvis")
	_check(not turn.is_equal_approx(Basis.IDENTITY), "turn the pelvis and the shader is told it turned")
	body.free()
