## ActorMesh3D — an actor as a live skinned mesh on the 3D board (RENDER3D R3D-ACTORS, `ACTOR` D64).
##
## THE MESH SHOWS, `AgentSprite` DECIDES (step 3, the bridge). The same contract `ActorBillboard3D` kept: the sprite still
## owns every decision — facing (D44's four, D47's snap at the GU boundary), posture, grip, weapon, the walk's progress,
## the throw and the head's grid angle — and this node reads them each frame through `AgentSprite.mesh_state()` and turns
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
const HeadTurnRef = preload("res://godot/scripts/geometry/actor_head_turn3d.gd")
const RIG_DIR := "res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/"
## `AgentSprite.frame_family` -> the rig exported from that model. A family with no rig of its own falls back to the
## agent's, loudly, once.
const RIG_BY_FAMILY := {
	"": "agent_live.glb",
	"_enemy_white": "agent_live_enemy_white.glb",
}
## `AgentSprite.weapon` (a bake suffix) -> the rig's weapon name. The rifle has no grip in `p2_grip_spike.GRIPS`, so it
## holds the shotgun, as the frame bake already does.
const WEAPON_BY_SUFFIX := {"": "shotgun", "_pistol": "pistol", "_rifle": "shotgun"}
## D61: a GU is 1.60 m, and a GU is one world unit; the rig is authored in metres.
const METRES_TO_UNITS: float = 1.0 / 1.6
## `AgentSprite.HEAD_YAW_LIMIT_DEG`: how far the head turns off the body.
const HEAD_YAW_LIMIT_DEG: float = 60.0
## `AgentSprite.THROW_RELEASE_FRACTION`: the grenade leaves the hand half way through the release.
const THROW_RELEASE_FRACTION: float = 0.5

var _board: Node3D = null
var _source: AgentSprite = null
var _body: Node3D = null
var _materials: Array[ShaderMaterial] = []
var _player: AnimationPlayer = null
var _head: SkeletonModifier3D = null
var _weapons: Dictionary = {}       ## weapon name -> Node3D under hand_R
var _grenade: Node3D = null
var _action: String = ""
## Gameplay decides WHO is revealed; this draws it (the `ActorBillboard3D` property of the same name, step 4).
var reveal_behind_walls: bool = false
static var _warned_family: Dictionary = {}


## Drive this mesh from `source`. Returns false (and logs) when the rig cannot be loaded, leaving nothing half-built.
func setup_actor(board: Node3D, source: AgentSprite) -> bool:
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
	source.visible = false  ## the 2D sprite keeps deciding (and processing); it no longer draws
	name = "Mesh_%s" % (source.get_parent().name if source.get_parent() != null else source.name)
	process_priority = 100  ## after the actor has moved and the sprite has decided, this frame
	_sync()
	return true


func _load_rig(board: Node3D, path: String) -> bool:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("[ActorMesh3D] cannot load the rig %s (run tools/asset_generation/r3d_live_rig_export.py)" % path)
		return false
	_board = board
	_body = scene.instantiate() as Node3D
	_body.scale = Vector3.ONE * METRES_TO_UNITS
	add_child(_body)
	_apply_board_light(_body)
	var players := _body.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("[ActorMesh3D] %s has no AnimationPlayer — re-export the rig" % path)
		return false
	_player = players[0] as AnimationPlayer
	_player.speed_scale = 0.0  ## seeked, never played
	var skeletons := _body.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
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
	position = _board.call("ground_point", _source.global_position)
	var state: Dictionary = _source.mesh_state()
	var step: Vector2i = state["step"]
	var body_yaw: float = rotation.y
	if step != Vector2i.ZERO:
		body_yaw = yaw_for_direction(Vector2(step))
		rotation.y = body_yaw
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
		_grenade.visible = throw_seq == "raise" or (throw_seq == "release" and u < THROW_RELEASE_FRACTION)
	_show(action, u)
	if _head != null:
		var head: float = float(state["head"])
		var posture: String = state["posture"]
		if is_nan(head) or posture == "prone":
			_head.set("yaw", 0.0)
		else:
			## A grid angle: 0 = North (0, -1), +90 = East (1, 0), the guard's `vision_angle` convention.
			var rad: float = deg_to_rad(head)
			var want: float = yaw_for_direction(Vector2(sin(rad), -cos(rad)))
			_head.set("yaw", clampf(wrapf(want - body_yaw, -PI, PI), -deg_to_rad(HEAD_YAW_LIMIT_DEG), deg_to_rad(HEAD_YAW_LIMIT_DEG)))


## The yaw that turns the rig's front (its local -Z: the toes and the knee pole) toward a BASE grid direction. Grid x is
## world +X, grid y is world +Z (`Board3DLive.ground_point()`).
static func yaw_for_direction(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)


func _show(action: String, u: float) -> void:
	if action != _action:
		if not _player.has_animation(action):
			push_error("[ActorMesh3D] the rig has no '%s' action — re-export it" % action)
			return
		_action = action
		_player.play(action)
	_player.seek(clampf(u, 0.0, 1.0) * _player.current_animation_length, true)


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


func _exit_tree() -> void:
	## Only if this mesh still owns the sprite: on a reload the NEW board's figure has already hidden it.
	if is_instance_valid(_source) and _source.has_meta("billboard3d") and _source.get_meta("billboard3d") == self:
		_source.visible = true
	if is_instance_valid(_board):
		for m in _materials:
			_board.call("unregister_prop_light_material", m)
