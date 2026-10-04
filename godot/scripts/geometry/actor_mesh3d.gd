## ActorMesh3D — an actor as a live skinned mesh on the 3D board (RENDER3D R3D-ACTORS, `ACTOR` D64).
##
## THE MESH SHOWS, `ActorPose` DECIDES (step 3, the bridge). The contract the retired `ActorBillboard3D` kept: the sprite still
## owns every decision — facing (D44's four, D47's snap at the GU boundary), posture, grip, weapon, the walk's progress,
## the throw and the head's grid angle — and this node reads them each frame through `ActorPose.mesh_state()` and turns
## them into a yaw, an action and a time. Nothing in the actor's logic knows which of the two draws it.
##
## THE RIG is `tools/asset_generation/r3d_live_rig_export.py`'s: one skinned mesh, every motion a keyed action
## (`<posture>_<weapon>_<grip>`, `walk_<weapon>`, `throw_raise_<weapon>`, `throw_release_<weapon>`), the weapons on
## `hand_R` and the grenade on `hand_L` as `BoneAttachment3D`s. An action is never PLAYED: it is SEEKED to the fraction
## the sprite is at, so the walk stays locked to the step's progress (one cycle per GU, D61) and the throw to the sprite's
## own clock, which is what fires `throw_released`.
##
## LIT the board's way (`actor_mesh3d.gdshader`: no Godot light, one cell-plane fetch; Moto: 9 walking rigs +1.0 ms),
## its materials kept in sync by `Board3DLive.register_prop_light_material()` exactly as a prop's are.
##
## PLACED in BASE world coordinates: the feet are the sprite's 2D position through `Board3DLive.ground_point()` (the N
## lattice in every view), the yaw is the base grid step's, so a camera yaw turns the figure with the board for free.
class_name ActorMesh3D
extends Node3D

const SHADER_PATH := "res://godot/shaders/actor_mesh3d.gdshader"
const SILHOUETTE_SHADER_PATH := "res://godot/shaders/actor_mesh_silhouette3d.gdshader"
## After the world's opaque geometry and the cutaway fill (10), before the cutaway lines (127): the billboard's slot.
const SILHOUETTE_PRIORITY := 20
const SHADOW_SHADER := "res://godot/shaders/ground_overlay3d.gdshader"
## Above the floor, under every ground overlay's lift (0.01+).
const SHADOW_LIFT: float = 0.005
const HeadTurnRef = preload("res://godot/scripts/geometry/actor_head_turn3d.gd")
const RIG_DIR := "res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/"
## `ActorPose.frame_family` -> the rig exported from that model. A family with no rig of its own falls back to the
## agent's, loudly, once.
const RIG_BY_FAMILY := {
	"": "agent_live.glb",
	"_enemy_white": "agent_live_enemy_white.glb",
}
## `ActorPose.weapon` (a bake suffix) -> the rig's weapon name. The rifle has no grip in `p2_grip_spike.GRIPS`, so it
## holds the shotgun, as the frame bake already does.
const WEAPON_BY_SUFFIX := {"": "shotgun", "_pistol": "pistol", "_rifle": "shotgun"}
## D61: a GU is 1.60 m, and a GU is one world unit; the rig is authored in metres.
const METRES_TO_UNITS: float = 1.0 / 1.6
## The 2D contact shadow's colour when the actor's script declares none.
const DEFAULT_SHADOW := Color(0.0, 0.0, 0.0, 0.28)

var _board: Node3D = null
var _source: ActorPose = null
var _body: Node3D = null
var _materials: Array[ShaderMaterial] = []
var _player: AnimationPlayer = null
var _head: SkeletonModifier3D = null
var _weapons: Dictionary = {}       ## weapon name -> Node3D under hand_R
var _grenade: Node3D = null
var _action: String = ""
var _skeleton: Skeleton3D = null
var _head_bone: int = -1
## Gameplay decides WHO is revealed (vision, skills and progress are gameplay, not physics); this only draws it: every
## part of the mesh an opaque wall covers becomes a striped silhouette (`actor_mesh_silhouette3d.gdshader`, chained as
## the `next_pass` of each board-lit surface). Off, nothing extra is drawn or allocated.
var reveal_behind_walls: bool = false:
	set(value):
		reveal_behind_walls = value
		_apply_reveal()
## Added to the silhouette's stripe scroll, in stripes (the billboard's knob of the same name).
var silhouette_phase: float = 0.0:
	set(value):
		silhouette_phase = value
		if _silhouette != null:
			_silhouette.set_shader_parameter("phase", value)
var _silhouette: ShaderMaterial = null
static var _warned_family: Dictionary = {}
static var _warned_action: Dictionary = {}


## Drive this mesh from `source`. Returns false (and logs) when the rig cannot be loaded, leaving nothing half-built.
func setup_actor(board: Node3D, source: ActorPose) -> bool:
	var family: String = source.frame_family
	var file: String = String(RIG_BY_FAMILY.get(family, ""))
	if file.is_empty():
		file = String(RIG_BY_FAMILY[""])
		if not _warned_family.has(family):
			_warned_family[family] = true
			push_warning("[ActorMesh3D] no live rig for family '%s' — it wears the agent's (export one with P2_MODEL)" % family)
	if not _load_rig(board, RIG_DIR + file):
		return false
	_source = source
	_build_contact_shadow(source.get_parent())
	name = "Mesh_%s" % (source.get_parent().name if source.get_parent() != null else source.name)
	process_priority = 100  ## after the actor has moved and the sprite has decided, this frame
	_sync()
	return true


func _load_rig(board: Node3D, path: String) -> bool:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("[ActorMesh3D] cannot load the rig %s (run tools/asset_generation/r3d_live_rig_export.py)" % path)
		return false
	var body := scene.instantiate() as Node3D
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("[ActorMesh3D] %s has no AnimationPlayer — re-export the rig" % path)
		body.free()
		return false
	_board = board
	_body = body
	_body.scale = Vector3.ONE * METRES_TO_UNITS
	add_child(_body)
	_apply_board_light(_body)
	_player = players[0] as AnimationPlayer
	_player.speed_scale = 0.0  ## seeked, never played
	var skeletons := _body.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
		_head_bone = _skeleton.find_bone("head")
		_head = HeadTurnRef.new()
		(skeletons[0] as Skeleton3D).add_child(_head)
	for attachment in _body.find_children("*", "BoneAttachment3D", true, false):
		var bone: String = (attachment as BoneAttachment3D).bone_name
		for child in attachment.get_children():
			if bone == "hand_R" and String(child.name).begins_with("Weapon_"):
				_weapons[String(child.name).trim_prefix("Weapon_")] = child
			elif bone == "hand_L":
				_grenade = child
	return true


func _process(_delta: float) -> void:
	if not is_instance_valid(_source) or not is_instance_valid(_board):
		queue_free()
		return
	_sync()


func _sync() -> void:
	var parent: Node = _source.get_parent()
	visible = parent == null or (parent is CanvasItem and (parent as CanvasItem).is_visible_in_tree())
	if not visible:
		return
	## The pose node sits at its actor's origin, so the actor's 2D position IS where the feet are.
	position = _board.call("ground_point", (parent as Node2D).global_position)
	var state: Dictionary = _source.mesh_state()
	var step: Vector2i = state["step"]
	var body_yaw: float = _body.rotation.y
	if step != Vector2i.ZERO:
		body_yaw = yaw_for_direction(Vector2(step))
		_body.rotation.y = body_yaw
	var weapon: String = String(WEAPON_BY_SUFFIX.get(String(state["weapon"]), "shotgun"))
	for held: String in _weapons:
		(_weapons[held] as Node3D).visible = held == weapon
	var throw_seq: String = state["throw"]
	var u: float = 0.0
	var action: String
	if throw_seq != "":
		action = "throw_%s_%s" % [throw_seq, weapon]
		u = float(state["throw_u"])
	elif float(state["walk"]) >= 0.0:
		action = "walk_%s" % weapon
		u = float(state["walk"])
	else:
		action = "%s_%s_%s" % [state["posture"], weapon, "aimed" if String(state["grip"]) == "_aimed" else "lowered"]
	if _grenade != null:
		_grenade.visible = throw_seq == ActorPose.THROW_RAISE \
			or (throw_seq == ActorPose.THROW_RELEASE and u < ActorPose.THROW_RELEASE_FRACTION)
	_show_or_fallback(action, u, weapon)
	if _head != null:
		var head: float = float(state["head"])
		var posture: String = state["posture"]
		if is_nan(head) or posture == "prone":
			_head.set("yaw", 0.0)
		else:
			## A grid angle: 0 = North (0, -1), +90 = East (1, 0), the guard's `vision_angle` convention.
			var rad: float = deg_to_rad(head)
			var want: float = yaw_for_direction(Vector2(sin(rad), -cos(rad)))
			var limit: float = deg_to_rad(ActorPose.HEAD_YAW_LIMIT_DEG)
			_head.set("yaw", clampf(wrapf(want - body_yaw, -PI, PI), -limit, limit))


## Where the head is above the feet in 2D canvas pixels on the N lattice (what `ActorPose.head_offset_px()` answers,
## and the agent's muzzle and throw origin are built on): the rig's `head` bone in its current pose, carried onto the
## lattice through the BASE view's basis, so it does not change when the camera turns. Standing, it reads about -165 px
## where the bake's head socket read -168.6 (the bone's head is the base of the skull, the socket a little above it).
func head_offset_px() -> Vector2:
	if _skeleton == null or _head_bone < 0:
		return Vector2.ZERO
	var head: Vector3 = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone)).origin
	var d: Vector3 = head - global_position
	var lattice: Basis = _board.call("lattice_basis")
	var ppu: float = _board.call("px_per_unit")
	return Vector2(d.dot(lattice.x), -d.dot(lattice.y)) * ppu


## The yaw that turns the rig's front (its local -Z: the toes and the knee pole) toward a BASE grid direction. Grid x is
## world +X, grid y is world +Z (`Board3DLive.ground_point()`).
static func yaw_for_direction(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)


func _show(action: String, u: float) -> void:
	if action != _action:
		if not _player.has_animation(action):
			if not _warned_action.has("!" + action):
				_warned_action["!" + action] = true
				push_error("[ActorMesh3D] the rig has no '%s' action, not even the fallback — re-export it" % action)
			return
		_action = action
		_player.play(action)
	_player.seek(clampf(u, 0.0, 1.0) * _player.current_animation_length, true)


## `_show()` for an action the rig may lack: a missing one is said ONCE (it would otherwise log every frame) and the
## figure falls back to standing with the lowered grip, which every rig has.
func _show_or_fallback(action: String, u: float, weapon: String) -> void:
	if _player.has_animation(action):
		_show(action, u)
		return
	if not _warned_action.has(action):
		_warned_action[action] = true
		push_warning("[ActorMesh3D] the rig has no '%s' action — showing standing; re-export it with r3d_live_rig_export.py" % action)
	_show("standing_%s_lowered" % weapon, 0.0)


## Every surface becomes one board-lit material carrying the model's own albedo colour and texture (one per source
## material, shared across surfaces), registered with the board so the light rebuilds reach it.
func _apply_board_light(body: Node) -> void:
	var converted: Dictionary = {}
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in range(m.mesh.get_surface_count()):
			var src: Material = m.get_active_material(s)
			if not converted.has(src):
				var sm := ShaderMaterial.new()
				sm.shader = BoardLook.graded_shader(SHADER_PATH)
				var std := src as BaseMaterial3D
				if std != null:
					sm.set_shader_parameter("albedo", std.albedo_color)
					if std.albedo_texture != null:
						sm.set_shader_parameter("albedo_tex", std.albedo_texture)
						sm.set_shader_parameter("has_tex", 1.0)
				converted[src] = sm
				_materials.append(sm)
				_board.call("register_prop_light_material", sm)
			m.set_surface_override_material(s, converted[src])


## R3D-WORLD — the actor's contact shadow, on the ground under the feet: the 2D diamond the actor drew
## (`ground_shadow_half_px`, `COLOR_SHADOW`), carried through the board's 2D -> ground map, so it is the same shape on the
## same floor in view N and stays under the feet in every other view. The actor's own 2D shadow is gone (RETIRE-2D); the actor
## is also handed the board for its dev-vision draws.
func _build_contact_shadow(actor: Node) -> void:
	if actor == null or not ("ground_shadow_half_px" in actor):
		return
	var half: Vector2 = actor.get("ground_shadow_half_px")
	var to_gu: Transform2D = _board.call("ground_affine")
	var constants: Dictionary = actor.get_script().get_script_constant_map() if actor.get_script() != null else {}
	var colour: Color = constants.get("COLOR_SHADOW", DEFAULT_SHADOW)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for p: Vector2 in [Vector2(0.0, -half.y), Vector2(half.x, 0.0), Vector2(0.0, half.y), Vector2(-half.x, 0.0)]:
		var g: Vector2 = to_gu.basis_xform(p)
		verts.append(Vector3(g.x, SHADOW_LIFT, g.y))
		cols.append(colour)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "ContactShadow"
	node.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADOW_SHADER)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	if actor.has_method("set_board3d"):
		actor.call("set_board3d", _board)


func _apply_reveal() -> void:
	if reveal_behind_walls and _silhouette == null:
		_silhouette = ShaderMaterial.new()
		_silhouette.shader = load(SILHOUETTE_SHADER_PATH)
		_silhouette.render_priority = SILHOUETTE_PRIORITY
		_silhouette.set_shader_parameter("phase", silhouette_phase)
	for m: ShaderMaterial in _materials:
		m.next_pass = _silhouette if reveal_behind_walls else null


func _exit_tree() -> void:
	## Only if this mesh still owns the sprite: on a reload the NEW board's figure has already hidden it.
	if is_instance_valid(_source) and _source.has_meta("figure3d") and _source.get_meta("figure3d") == self:
		var actor: Node = _source.get_parent()
		if actor != null and actor.has_method("set_board3d"):
			actor.call("set_board3d", null)
	if is_instance_valid(_board):
		for m in _materials:
			_board.call("unregister_prop_light_material", m)
