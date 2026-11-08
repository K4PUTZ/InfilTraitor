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
##
## A TRIPO AGENT (MOVEMENT MV-4, first slice, 2026-11-05; THE AGENT'S DEFAULT since 2026-11-08, the male unless `TRIPO_FIGURE=female`,
## `none` = the old rig; guards are never affected: the soldier keeps the white rig, the officer wears the old agent's `agent_live.glb`).
## The agent wears that LIGHT Agent instead (`TripoFigure`: 65 Mixamo joints, the dressed set, the coat two-sided, its emblem, the legs pushing it) and
## plays the game set's clips: `idle` on its own clock while the actor stands, the move clip (`TRIPO_MOVE`, `walk` by default)
## while it walks, phased by the GROUND it covers (one pass of the clip per its `travel_m`), so the feet do not slide at any step
## length. Facing (D44, D47's snap), position and gravity are this node's, unchanged. THE PISTOL (2026-11-08): with `weapon` `_pistol` and `grip` `_aimed` the aim layer
## (`ActorAimPose3D`, `AIM_STOPS`) takes the arms from the clip through the draw (fists at the sternum, the gun comes out of the coat) to a two-handed aim, and back on cancel.
## Not yet on that figure: the other weapons in the hand (the shotgun and the rifle stand through the aim), crouched and prone, the throw (a Tripo actor stands through it; the
## throw still releases on the sprite's clock), the clip transitions (a snap, D47's default) and the corrective coat keys (`ACTOR` D103, only on the base).
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
	## The field officer (2026-11-08): the old agent's model, promoted when the Tripo figure became the agent.
	"_officer": "agent_live.glb",
}
## `ActorPose.weapon` (a bake suffix) -> the rig's weapon name. The rifle has no grip in `p2_grip_spike.GRIPS`, so it
## holds the shotgun, as the frame bake already does.
const WEAPON_BY_SUFFIX := {"": "shotgun", "_pistol": "pistol", "_rifle": "shotgun"}
## D61: a GU is 1.60 m, and a GU is one world unit; the rig is authored in metres.
const METRES_TO_UNITS: float = 1.0 / 1.6
## The 2D contact shadow's colour when the actor's script declares none.
const DEFAULT_SHADOW := Color(0.0, 0.0, 0.0, 0.28)
const TripoFigureRef = preload("res://godot/scripts/geometry/tripo_figure.gd")
## Dev flags of the Tripo slice: which Agent every actor wears ("" = the r3d_live rig), and the clip it moves with.
const TRIPO_FIGURE_FLAG := "TRIPO_FIGURE"
## The Agent is the male LIGHT figure unless the flag says `female`; `none` puts the old r3d_live rig back on the agent (comparisons).
const AGENT_FIGURE_DEFAULT := "male"
const TRIPO_FIGURE_NONE := "none"
const TRIPO_MOVE_FLAG := "TRIPO_MOVE"
const TRIPO_MOVE_DEFAULT := "walk"
const TRIPO_IDLE := "idle"
## THE AIM LAYER (MOVEMENT, 2026-11-08): while the actor holds the pistol AIMED the arms are pulled from whatever clip plays toward the pose
## `pose_aim_pistol` (`TripoFigure.POSES`, `ActorAimPose3D`); the pistol is in the right hand only then, and comes out as the fist rises
## (Director: no holster, it leaves the coat). `AIM_RAISE_S` / `AIM_LOWER_S` are the weight's travel; the gun shows from `PISTOL_SHOWN_FROM` of it.
const ActorAimPoseRef = preload("res://godot/scripts/geometry/actor_aim_pose3d.gd")
## The path of the raise: the idle arms, then the fists at the sternum (`draw_pistol`, at half way: the gun appears here, out of the coat), then the aim.
const AIM_STOPS: Array = [["draw_pistol", 0.5], ["aim_pistol", 1.0]]
const AIM_RAISE_S: float = 0.36
const AIM_LOWER_S: float = 0.24
const PISTOL_SHOWN_FROM: float = 0.5
## The gun grows from this share of its size over the next `PISTOL_GROW` of the path, so it comes out of the coat instead of popping.
const PISTOL_FROM_SCALE: float = 0.35
const PISTOL_GROW: float = 0.12

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
var _stand_y: float = NAN            ## the height the feet rest at now (eased toward `Board3DLive.stand_height`)
var _yaw: float = 0.0                ## the body's yaw toward its grid facing (the head's clamp is relative to it)
var _front_yaw: float = 0.0          ## added to `_yaw` on the model: 0 for the r3d_live rig (front -Z), PI for a Tripo Agent (front +Z)
var _tripo: String = ""              ## the Tripo Agent this actor wears ("" = the r3d_live rig)
var _tripo_move: String = ""         ## the clip it moves with
var _tripo_units: float = 1.0        ## world units per metre of the 1 m Tripo export (its scale on the board)
var _aim: ActorAimPoseRef = null      ## the aim layer of a Tripo Agent (null: its game set carries no aim pose)
var _aim_t: float = 0.0              ## how far the aim has travelled, 0 (down) to 1 (held)
var _pistol: Node3D = null           ## the pistol in the right hand (hidden until the fists reach the sternum)
var _pistol_holder: Node3D = null    ## carries the placement (the pose's, blended between the stops) and the grow-in scale
var _pistol_stops: Array = []        ## [[weight, placement {bone, pos, quat, scale}], ...] one per aim stop, from the poses' `props` meta
var _walked: float = 0.0             ## ground covered while walking, world units: the move clip's phase
var _move_pass: float = 0.0          ## world units of ground one pass of the move clip covers
var _last_ground := Vector2(NAN, NAN)
var _idle_t: float = 0.0             ## the idle clip's own clock
const FALL_GU_S: float = 3.0          ## how fast an actor drops onto lower ground (GU of height a second)
const CLIMB_GU_S: float = 1.5         ## and climbs back up
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
## R3D-LOOK item 7 (Director, 2026-10-05): the reveal silhouette takes its colour from the actor's FACTION, so a revealed guard and a
## revealed agent never read alike. Per faction: the two stripe colours and the outline. Unknown ids keep the shader's own lilac.
const REVEAL_PALETTES: Dictionary = {
	&"agent": {"stripe_a": Color(0.86, 0.96, 1.0), "stripe_b": Color(0.16, 0.28, 0.38), "outline_color": Color(1.0, 1.0, 1.0)},
	&"agency": {"stripe_a": Color(0.46, 0.64, 1.0), "stripe_b": Color(0.08, 0.14, 0.40), "outline_color": Color(0.30, 0.56, 1.0)},
	&"militia": {"stripe_a": Color(1.0, 0.52, 0.36), "stripe_b": Color(0.40, 0.10, 0.06), "outline_color": Color(1.0, 0.34, 0.18)},
	&"corporation": {"stripe_a": Color(1.0, 0.84, 0.30), "stripe_b": Color(0.38, 0.28, 0.04), "outline_color": Color(1.0, 0.74, 0.12)},
	&"network": {"stripe_a": Color(0.46, 0.96, 0.62), "stripe_b": Color(0.06, 0.30, 0.14), "outline_color": Color(0.28, 0.90, 0.46)},
}
var reveal_faction: StringName = &"":
	set(value):
		reveal_faction = value
		_apply_reveal_palette()
static var _warned_family: Dictionary = {}
static var _warned_action: Dictionary = {}


## Drive this mesh from `source`. Returns false (and logs) when the rig cannot be loaded, leaving nothing half-built.
func setup_actor(board: Node3D, source: ActorPose) -> bool:
	## Only the AGENT (family "") wears the Tripo figure; a guard keeps the rig of its own family (soldier, officer).
	var tripo: String = _dev_value(TRIPO_FIGURE_FLAG, AGENT_FIGURE_DEFAULT) if source.frame_family.is_empty() else ""
	if tripo == TRIPO_FIGURE_NONE:
		tripo = ""
	if not tripo.is_empty():
		if not TripoFigureRef.FIGURES.has(tripo):
			push_error("[ActorMesh3D] %s=%s: expected one of %s" % [TRIPO_FIGURE_FLAG, tripo, TripoFigureRef.FIGURES])
			return false
		if not _load_tripo(board, tripo, _dev_value(TRIPO_MOVE_FLAG, TRIPO_MOVE_DEFAULT)):
			return false
	else:
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


## The Tripo Agent `figure` (LIGHT), dressed and board-lit, with the game set of its clips on its player (`TripoFigure`). False
## (loud) when the figure or its clips are missing, leaving nothing half-built.
func _load_tripo(board: Node3D, figure: String, move_clip: String) -> bool:
	var path: String = TripoFigureRef.rig_path(figure, true)
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("[ActorMesh3D] cannot load the Tripo Agent %s (run build_agents.sh)" % path)
		return false
	var lib: AnimationLibrary = TripoFigureRef.library(figure)
	if lib == null:
		return false
	for clip: String in [TRIPO_IDLE, move_clip]:
		if not lib.has_animation(clip):
			push_error("[ActorMesh3D] the %s game clips have no '%s' (have %s)" % [figure, clip, lib.get_animation_list()])
			return false
	var body := scene.instantiate() as Node3D
	var players := body.find_children("*", "AnimationPlayer", true, false)
	var skeletons := body.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		push_error("[ActorMesh3D] %s has no AnimationPlayer or no skeleton" % path)
		body.free()
		return false
	_board = board
	_body = body
	_tripo = figure
	_tripo_move = move_clip
	_front_yaw = TripoFigureRef.FRONT_YAW
	_tripo_units = TripoFigureRef.STAND_HEIGHT_M * METRES_TO_UNITS
	_move_pass = TripoFigureRef.travel_m(lib.get_animation(move_clip)) * _tripo_units
	if _move_pass <= 0.0:
		push_warning("[ActorMesh3D] the %s clip '%s' covers no ground: it will play frozen while the actor walks" % [figure, move_clip])
	_body.scale = Vector3.ONE * _tripo_units
	add_child(_body)
	_apply_board_light(_body)
	TripoFigureRef.hide_pieces(_body, false)
	_skeleton = skeletons[0] as Skeleton3D
	_head_bone = TripoFigureRef.find_bone(_skeleton, "Head")
	_build_aim_layer(lib, figure)   ## before the head turn: a skeleton's modifiers run in child order
	if _head_bone >= 0:
		_head = HeadTurnRef.new()
		_head.set("bone_name", _skeleton.get_bone_name(_head_bone))
		_skeleton.add_child(_head)
	TripoFigureRef.dress_coat(_body, _skeleton, true, true)
	_player = players[0] as AnimationPlayer
	_player.add_animation_library(TripoFigureRef.LIBRARY_NAME, lib)
	_player.speed_scale = 0.0  ## seeked, never played
	return true


## The aim layer and the pistol in the right hand of a Tripo Agent, from the game set's `pose_aim_pistol`. Missing pose or model: said loudly, the agent
## simply does not aim (it stands through it, as before).
func _build_aim_layer(lib: AnimationLibrary, figure: String) -> void:
	var stops: Array = []
	for stop: Array in AIM_STOPS:
		var pose_id: String = TripoFigureRef.POSE_PREFIX + String(stop[0])
		if not lib.has_animation(pose_id):
			push_warning("[ActorMesh3D] the %s game set has no '%s': the agent will not aim (run godot/scripts/tools/tripo_game_clips.gd)" % [figure, pose_id])
			return
		stops.append([float(stop[1]), lib.get_animation(pose_id)])
	var layer: ActorAimPoseRef = ActorAimPoseRef.new()
	_skeleton.add_child(layer)
	if not layer.load_stops(_skeleton, stops):
		layer.queue_free()
		return
	_aim = layer
	_build_pistol(stops)


## The pistol in the hand: its placement comes from the poses (`props` meta: the Director's, set in Blender, or the default), one per stop, blended between the stops
## like the arms are. Missing model or bone: said loudly, the agent aims empty-handed.
func _build_pistol(stops: Array) -> void:
	_pistol_stops.clear()
	for stop: Array in stops:
		var props: Dictionary = (stop[1] as Animation).get_meta("props", {})
		_pistol_stops.append([float(stop[0]), props["pistol"] if props.has("pistol") else TripoFigureRef.prop_default("pistol")])
	var bone_name: String = String((_pistol_stops[_pistol_stops.size() - 1][1] as Dictionary)["bone"])
	var hand: int = TripoFigureRef.find_bone(_skeleton, bone_name)
	var model_path: String = String(TripoFigureRef.PROP_MODELS["pistol"])
	var scene := load(model_path) as PackedScene
	if hand < 0 or scene == null:
		push_error("[ActorMesh3D] no bone '%s' or no pistol model (%s): the agent aims empty-handed" % [bone_name, model_path])
		_pistol_stops.clear()
		return
	var attach := BoneAttachment3D.new()
	attach.name = "PistolHand"
	attach.bone_name = _skeleton.get_bone_name(hand)
	_skeleton.add_child(attach)
	var holder := Node3D.new()   ## its transform is the pose's placement of the model's scene root, times the grow-in
	attach.add_child(holder)
	holder.add_child(scene.instantiate() as Node3D)
	_apply_board_light(attach)
	attach.visible = false
	_pistol = attach
	_pistol_holder = holder


## The pistol's placement at `weight` of the aim path: the stops' placements blended with the same easing the arms use (`ActorAimPose3D`): position and scale lerped,
## rotation slerped; before the first stop it is the first one.
func _pistol_placement(weight: float) -> Transform3D:
	var k: int = 0
	while k < _pistol_stops.size() - 1 and weight > float(_pistol_stops[k][0]):
		k += 1
	var to: Dictionary = _pistol_stops[k][1]
	var from: Dictionary = to if k == 0 else _pistol_stops[k - 1][1]
	var from_w: float = 0.0 if k == 0 else float(_pistol_stops[k - 1][0])
	var t: float = smoothstep(0.0, 1.0, clampf((weight - from_w) / (float(_pistol_stops[k][0]) - from_w), 0.0, 1.0)) if k > 0 else 1.0
	var q: Quaternion = (from["quat"] as Quaternion).slerp(to["quat"] as Quaternion, t)
	var s: float = lerpf(float(from["scale"]), float(to["scale"]), t)
	return Transform3D(Basis(q).scaled(Vector3.ONE * s), (from["pos"] as Vector3).lerp(to["pos"] as Vector3, t))


## The aim layer's weight this frame: toward 1 while the pistol is held aimed and standing, toward 0 otherwise (the raise and the lowering are the same
## travel read both ways), eased; the gun is drawn only once the fist is up.
func _update_aim(state: Dictionary) -> void:
	if _aim == null:
		return
	var want: bool = String(state["weapon"]) == "_pistol" and String(state["grip"]) == "_aimed" and String(state["posture"]) == "standing"
	var target: float = 1.0 if want else 0.0
	_aim_t = move_toward(_aim_t, target, get_process_delta_time() / (AIM_RAISE_S if want else AIM_LOWER_S))
	_aim.weight = _aim_t
	if _pistol != null:
		_pistol.visible = _aim_t >= PISTOL_SHOWN_FROM
		var grow: float = lerpf(PISTOL_FROM_SCALE, 1.0, clampf((_aim_t - PISTOL_SHOWN_FROM) / PISTOL_GROW, 0.0, 1.0))
		_pistol_holder.transform = _pistol_placement(_aim_t) * Transform3D(Basis.from_scale(Vector3.ONE * grow), Vector3.ZERO)


## A dev flag through `DevFlags` (the APK's overrides file), or the environment when the autoload is absent (a bare script run).
func _dev_value(flag_name: String, fallback: String) -> String:
	var flags: Node = get_node_or_null("/root/DevFlags")
	if flags == null:
		var from_env: String = OS.get_environment("INFILTRAITOR_" + flag_name)
		return from_env if not from_env.is_empty() else fallback
	return String(flags.call("value", flag_name, fallback))


## Where the grenade in the raised hand is, in the world: the `hand_L` attachment's own origin, which the pose seeks every frame. Vector3(INF, INF, INF)
## ("none", the emitters' `NO_ANCHOR`) while that grenade is hidden (not in a throw's raise, or past the release).
func hand_grenade_world() -> Vector3:
	if _grenade == null or not _grenade.visible or not _grenade.is_inside_tree():
		return Vector3(INF, INF, INF)
	return _grenade.global_position


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
	var ground := Vector2(position.x, position.z)
	## GRAVITY (Director, 2026-10-18): the feet rest on what is under them (`Board3DLive.stand_height`: a pit's bed, a crater, a crust's plate, ice, a
	## quicksand), reached at a walking pace up and a falling one down, never snapped mid-step.
	var target: float = float(_board.call("stand_height", position, parent))
	if is_nan(_stand_y):
		_stand_y = target
	else:
		var dt: float = get_process_delta_time()
		_stand_y = move_toward(_stand_y, target, dt * (FALL_GU_S if target < _stand_y else CLIMB_GU_S))
	position.y += _stand_y
	var state: Dictionary = _source.mesh_state()
	var step: Vector2i = state["step"]
	if step != Vector2i.ZERO:
		_yaw = yaw_for_direction(Vector2(step))
	_body.rotation.y = _yaw + _front_yaw
	var body_yaw: float = _yaw
	if not _tripo.is_empty():
		_show_tripo(float(state["walk"]) >= 0.0, ground)
		_update_aim(state)
	else:
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


## The Tripo Agent's clip this frame: the move clip while the actor walks, phased by the ground it has covered (`ground`: the feet
## on the board, world units), so one pass of the clip takes exactly its `travel_m` of ground; the idle on its own clock otherwise.
## The change between the two is a snap (D47's default; the transitions are MOVEMENT's next step).
func _show_tripo(walking: bool, ground: Vector2) -> void:
	if walking and not is_nan(_last_ground.x):
		_walked += ground.distance_to(_last_ground)
	_last_ground = ground
	var clip: String = "%s/%s" % [TripoFigureRef.LIBRARY_NAME, _tripo_move if walking else TRIPO_IDLE]
	if clip != _action:
		_action = clip
		_player.play(clip)
	var length: float = _player.current_animation_length
	var t: float = 0.0
	if walking:
		if _move_pass > 0.0:
			t = fposmod(_walked / _move_pass, 1.0) * length
	else:
		_idle_t = fposmod(_idle_t + get_process_delta_time(), length)
		t = _idle_t
	_player.seek(t, true)


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


## M6 F5 — what a liquid left on the actor, drawn over its board light: `color` (alpha = how much, 0 clears it), `pulse` 1 makes it breathe (a fire).
func set_status_tint(color: Color, pulse: float) -> void:
	for m: ShaderMaterial in _materials:
		m.set_shader_parameter("status_tint", color)
		m.set_shader_parameter("status_pulse", pulse)


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
		_apply_reveal_palette()
	for m: ShaderMaterial in _materials:
		m.next_pass = _silhouette if reveal_behind_walls else null


func _apply_reveal_palette() -> void:
	if _silhouette == null:
		return
	var palette: Dictionary = REVEAL_PALETTES.get(reveal_faction, {})
	for key: String in ["stripe_a", "stripe_b", "outline_color"]:
		if palette.has(key):
			_silhouette.set_shader_parameter(key, palette[key])


func _exit_tree() -> void:
	## Only if this mesh still owns the sprite: on a reload the NEW board's figure has already hidden it.
	if is_instance_valid(_source) and _source.has_meta("figure3d") and _source.get_meta("figure3d") == self:
		var actor: Node = _source.get_parent()
		if actor != null and actor.has_method("set_board3d"):
			actor.call("set_board3d", null)
	if is_instance_valid(_board):
		for m in _materials:
			_board.call("unregister_prop_light_material", m)
