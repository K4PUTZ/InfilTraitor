## TripoFigure — what the game needs to wear a Tripo Agent (MOVEMENT MV-4, `ACTOR` D85 / D91 / D94 / D95; first slice 2026-11-05).
##
## ONE AUTHORITY for the two readers of a Tripo Agent: `ActorMesh3D` (an actor on the board) and `ActorViabilityBench` (the
## handset measurement). Both dress the figure the same way and play the same clips, so a measurement is of what the game draws.
##
## THE FIGURE is `ASSETS/MODELS/official/AGENT_<FIG>[_LIGHT].glb` (`build_agents.sh`): 65 Mixamo joints, a 1 m figure facing +Z,
## each garment its own piece. The DRESSED set hides the pieces `tripo_dress` leaves beside their coat-cut variants; the coat is
## drawn two-sided, carries its emblem (D95) and is pushed by the legs (D94).
##
## THE CLIPS come from the bank (`ASSETS/ANIMATIONS/bank/<figure>/<id>.glb`, `tripo_anim_bank.py`), which stores ROTATIONS plus the
## Hips' translation divided by the hip height (MOVEMENT §1.3). `bank_clip()` is the one place that decodes that: the Hips back in
## the figure's own metres, IN PLACE (the clip's straight travel taken out, the sway and the bob kept), the travel of one pass of
## the clip kept as its `travel_m` metadata, which is what the game walks a clip by (one pass per `travel_m` of ground: no slide).
## The bank is held out of the APK (`export_presets.cfg`), so the clips the game plays are written once per figure into one
## `AnimationLibrary` (`GAME_LIBRARY`) by `godot/scripts/tools/tripo_game_clips.gd`, loaded once and shared by every actor of that
## figure (MOVEMENT §6: one library, one skeleton).
class_name TripoFigure
extends RefCounted

const TripoPoseKitRef = preload("res://godot/scripts/geometry/tripo_pose_kit.gd")
const AimSequenceRef = preload("res://godot/scripts/geometry/aim_sequence.gd")

const FIGURES: PackedStringArray = ["female", "male"]
const RIG := "res://ASSETS/MODELS/official/AGENT_%s.glb"
## the pieces tripo_dress leaves BESIDE their masked variants (the undressed ones): the dressed set hides them
const UNDRESSED_PIECES: Array[String] = ["Outfit_Shirt", "Outfit_Trousers", "Outfit_Belt", "Body_Hair", "Icosphere"]
## the other state: no coat, no hat, the plain shirt / trousers / belt and the open hair (the clean base, D89)
const DRESSED_ONLY_PIECES: Array[String] = ["Outfit_Coat", "Outfit_Hat", "Body_Hair_Hat", "Outfit_Shirt_Coated", "Outfit_Trousers_Coated", "Outfit_Belt_Coated"]
## The agent stands 9.8 voxels of 0.20 m (CHARACTER_MASTER_PLAN §4.7); Tripo exports a 1 m figure standing on y = 0 (hat included).
const STAND_HEIGHT_M: float = 1.96
## World units (GU) per figure unit: the figure stands STAND_HEIGHT_M tall and a GU is 1.6 m (D61). What a held model is
## scaled by in the hand, and so the one size a weapon has everywhere (HERITAGE T2 W2).
const WORLD_SCALE: float = STAND_HEIGHT_M / 1.6
## Tripo's figure faces +Z (glTF's front); `ActorMesh3D.yaw_for_direction()` turns a front of -Z.
const FRONT_YAW: float = PI
const COAT_SHADER_PATH := "res://godot/shaders/actor_coat3d.gdshader"   ## ACTOR D94: the coat, two-sided
## ACTOR D95: the art is `res://ASSETS/emblems/<id>.png`; a file of that name in `user://textures/emblems/` replaces it. The police face
## (Director, 2026-11-06): a first shield + star in the shirt's blue, the factions' symbols still owed (the skull was `emblem_ref_skull`).
const EMBLEM_ID := "emblem_police"
## The leather pieces' matte sheen (CHARACTER §7a, 2026-11-06): the strength the board-lit shader adds on the key light's highlight.
## [strength, power]: the coat's matte leather (Director: "Suave está bom") on the trousers too; the shoes glossier, a tighter highlight.
const SHEEN: Dictionary = {"Outfit_Coat": [0.15, 6.0], "Outfit_Hat": [0.09, 6.0], "Outfit_Shoes": [0.45, 18.0]}
const MIXAMO_PREFIXES: PackedStringArray = ["mixamorig:", "mixamorig_", ""]

const BANK_CLIP := "res://ASSETS/ANIMATIONS/bank/%s/%s.glb"
const GAME_LIBRARY := "res://ASSETS/ANIMATIONS/game/agent_%s.res"
## The clips the game set carries (the three the corrective keys were made on, `ACTOR` D103).
const GAME_CLIPS: PackedStringArray = ["idle", "walk", "run"]
## POSES (MOVEMENT, 2026-11-08): a POSE is a handful of bone rotations, ONE KEY: the target a layer blends toward (`ActorAimPose3D`), so raising a weapon,
## lowering it and putting it away need no clip of their own and cost no credit. Each comes from a frame of a bank clip (`clip`, `time`, for the `bones` listed:
## Mixamo names without prefix) and/or is solved in code (`TripoPoseKit`). They live in the game set as `pose_<id>`: rotation tracks with one key at 0, never played.
const POSE_PREFIX := "pose_"
const FINGER_BONES: PackedStringArray = [
	"LeftHandIndex1", "LeftHandIndex2", "LeftHandMiddle1", "LeftHandMiddle2", "LeftHandPinky1", "LeftHandPinky2",
	"LeftHandRing1", "LeftHandRing2", "LeftHandThumb1", "LeftHandThumb2",
	"RightHandIndex1", "RightHandIndex2", "RightHandMiddle1", "RightHandMiddle2", "RightHandPinky1", "RightHandPinky2",
	"RightHandRing1", "RightHandRing2", "RightHandThumb1", "RightHandThumb2",
]
## `two_hand_aim`: the ARMS are not copied from the clip but SOLVED (`TripoPoseKit`): both wrists `reach` ahead of the middle of the shoulders (the figure's own
## units, 1 = its height), `height` above that line, `gap` apart, the elbows bent down and `pole` out. The clip then only lends the fingers' grip. (The `fire`
## frame itself is a long-gun hold, its hands 30 cm apart and its torso twisted: kept for the day a rifle needs it; a pistol wants the hands together.)
## `hand_pitch`: degrees the fingers point UP from forward (a hand folded at the wrist). `draw_pistol` is the beat between the idle arms and the aim: both fists at
## the sternum, elbows out, where the gun comes out of the coat.
const POSES: Dictionary = {
	"draw_pistol": {"clip": "fire", "time": 0.5, "bones": FINGER_BONES, "props": ["pistol"], "two_hand_aim": {"reach": 0.07, "height": -0.075, "gap": 0.05, "pole": 0.9, "hand_pitch": 50.0}},
	"aim_pistol": {"clip": "fire", "time": 0.5, "bones": FINGER_BONES, "props": ["pistol"], "two_hand_aim": {"reach": 0.255, "height": 0.02, "gap": 0.044, "pole": 0.4}},
	## The Director's in-between (2026-11-09), two fifths of the way from the draw to the aim: his file when he has posed it, else this plain blend.
	"mid_pistol": {"between": ["draw_pistol", "aim_pistol"], "at": 0.4},
	## Derived, never posed or stored (`_between_pose`): that in-between with the front foot off the floor (`lift`: the rig's own units, Blender's metres on the 1 m figure); `travel` = the stops the foot goes between.
	"step_pistol": {"between": ["mid_pistol", "aim_pistol"], "at": 0.0, "travel": ["draw_pistol", "aim_pistol"], "foot": "LeftFoot", "lift": 0.02},
}
## A foot that travels less than this between the two stops of a derived pose stays on the floor (the figure's units).
const STEP_MIN_TRAVEL: float = 0.02
## THE DIRECTOR'S POSE FILE (2026-11-08): a pose posed BY HAND in Blender (`tools/persistent/pose_lab.py`) is `ASSETS/ANIMATIONS/poses/<figure>/<id>.json` and REPLACES the
## solved one: {"bones": {Mixamo name without prefix: [x, y, z, w]}, "props": {prop id: {"bone", "pos", "quat", "scale"}}}. Rotations are the bone's LOCAL rotation as Godot reads
## it (what `Skeleton3D.get_bone_pose_rotation` answers); a prop's transform is relative to the bone's own frame, applied to the model's scene root.
const POSE_FILE := "res://ASSETS/ANIMATIONS/poses/%s/%s.json"
## The props a pose may carry (the model in hand). The default placement is what the pose has until somebody places it by hand. A weapon's model IS its held size, fixed once by the
## Director with a figure holding it (2026-11-09; the same proportion goes to `props/<weapon>_prop.json`'s `mesh_size`): the pistol glb has no node transform and measures 0.147 long, 0.070
## tall, 0.019 thick in the figure's own units (barrel +X, sights +Y, flank +Z), so a placement's `scale` is 1.0.
## HERITAGE T2 W1 (2026-11-11): a prop the figure holds is a WEAPON, and its model and default hand placement are that
## weapon's row (`weapons/<id>.json` "model"); there is no table of them here any more.
## The library's name on an actor's AnimationPlayer: its clips play as `bank/<id>`.
const LIBRARY_NAME := &"bank"
const HIPS := "Hips"
const TRAVEL_META := &"travel_m"

static var _libraries: Dictionary = {}


## The rig of `figure` ("female" | "male"), the game's LIGHT one or the FULL one.
static func rig_path(figure: String, light: bool) -> String:
	return RIG % (figure.to_upper() + ("_LIGHT" if light else ""))


## The importer may keep the colon of `mixamorig:Hips` or turn it into an underscore: try both, then the bare name.
static func find_bone(skeleton: Skeleton3D, bone_name: String) -> int:
	for prefix: String in MIXAMO_PREFIXES:
		var idx: int = skeleton.find_bone(prefix + bone_name)
		if idx >= 0:
			return idx
	return -1


## Hide the pieces the dressed set (or, `nocoat`, the clean base) does not wear.
static func hide_pieces(body: Node, nocoat: bool) -> void:
	for piece_name: String in (DRESSED_ONLY_PIECES if nocoat else UNDRESSED_PIECES):
		for node in body.find_children(piece_name, "MeshInstance3D", true, false):
			(node as Node3D).visible = false


## The figure's coat (its `Outfit_Coat*` piece), or null.
static func coat_of(body: Node) -> MeshInstance3D:
	var coats: Array[Node] = body.find_children("Outfit_Coat*", "MeshInstance3D", true, false)
	return coats[0] as MeshInstance3D if not coats.is_empty() else null


## Dress the coat of a figure whose surfaces are already board-lit ShaderMaterials (`ActorMesh3D._apply_board_light()`): drawn
## two-sided, the emblem laid on it (`emblem`), the legs pushing it (`push`). Returns {"emblem": bool, "push": bool}: what took.
static func dress_coat(body: Node, skeleton: Skeleton3D, emblem: bool, push: bool) -> Dictionary:
	var took: Dictionary = {"emblem": false, "push": false}
	var coat: MeshInstance3D = coat_of(body)
	if coat == null:
		return took
	var coat_mat := (coat.material_override if coat.material_override != null else coat.get_active_material(0)) as ShaderMaterial
	if coat_mat != null:   ## a pushed face turned away would show the trousers behind it
		coat_mat.shader = BoardLook.graded_shader(COAT_SHADER_PATH)
		took["emblem"] = CoatEmblem.apply(coat_mat, EMBLEM_ID if emblem else "")
		apply_sides(coat, coat_mat)
	if push and skeleton != null:
		took["push"] = CoatPush3D.attach(skeleton, coat)
	apply_sheen(body)
	return took


## The coat's two walls (`coat_sides`, baked by tripo_coat_sides.py as the piece's `extras`): a face seen from its back takes the other wall's colour.
## A coat without the data keeps one colour per face, and says so once.
static func apply_sides(coat: MeshInstance3D, mat: ShaderMaterial) -> void:
	var extras: Variant = coat.get_meta("extras") if coat.has_meta("extras") else null
	var parsed: Variant = null
	if extras is Dictionary and (extras as Dictionary).has("coat_sides"):
		parsed = JSON.parse_string(str((extras as Dictionary)["coat_sides"]))
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("outer") or not (parsed as Dictionary).has("lining"):
		push_warning("[TripoFigure] %s carries no `coat_sides` data (run tripo_coat_sides.py): a lining a pose pushes out shows its own colour" % coat.name)
		mat.set_shader_parameter("sides_on", 0.0)
		return
	var sides := parsed as Dictionary
	mat.set_shader_parameter("side_outer", Color.html(str(sides["outer"])))
	mat.set_shader_parameter("side_lining", Color.html(str(sides["lining"])))
	mat.set_shader_parameter("sides_on", 1.0)


## The leather's sheen on every piece SHEEN names (its board-lit ShaderMaterial, a coat-cut variant included).
static func apply_sheen(body: Node) -> void:
	for node in body.find_children("Outfit_*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var key: String = String(mi.name).get_slice(".", 0)
		if not SHEEN.has(key) or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat := mi.get_active_material(s) as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("sheen", float(SHEEN[key][0]))
				mat.set_shader_parameter("sheen_power", float(SHEEN[key][1]))


## The game set of `figure`, loaded once and shared; null (loud) when it was never written.
static func library(figure: String) -> AnimationLibrary:
	if _libraries.has(figure):
		return _libraries[figure] as AnimationLibrary
	var path: String = GAME_LIBRARY % figure
	var lib: AnimationLibrary = load(path) as AnimationLibrary if ResourceLoader.exists(path) else null
	if lib == null:
		push_error("[TripoFigure] no game clips at %s (run godot/scripts/tools/tripo_game_clips.gd)" % path)
		return null
	_libraries[figure] = lib
	return lib


## The ground one pass of `anim` covers, in the figure's own metres (its 1 m export); 0 for a clip that stays in place.
static func travel_m(anim: Animation) -> float:
	return float(anim.get_meta(TRAVEL_META, 0.0)) if anim != null else 0.0


## The bank clip `id` of `figure`, decoded for a figure whose Hips rest at `hips_rest` (its own skeleton's): the Hips in that
## figure's metres and in place, looping, its travel kept as `travel_m`. A clip the figure lacks falls back to the other figure's,
## LOUDLY (MOVEMENT §3: a retarget by rotations is only a marked fallback). Null (loud) when there is none.
static func bank_clip(figure: String, id: String, hips_rest: Vector3) -> Animation:
	var path: String = BANK_CLIP % [figure, id]
	if not ResourceLoader.exists(path):
		var other: String = "male" if figure == "female" else "female"
		push_warning("[TripoFigure] %s has no %s clip %s: FALLBACK to the %s one" % [figure, id, path, other])
		path = BANK_CLIP % [other, id]
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_error("[TripoFigure] no bank clip %s" % path)
		return null
	var holder := scene.instantiate()
	var players: Array[Node] = holder.find_children("*", "AnimationPlayer", true, false)
	var skeletons: Array[Node] = holder.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		holder.free()
		push_error("[TripoFigure] %s holds no animation or no skeleton" % path)
		return null
	var src_player := players[0] as AnimationPlayer
	var anim: Animation = src_player.get_animation(src_player.get_animation_list()[0]).duplicate(true) as Animation
	var src_skeleton := skeletons[0] as Skeleton3D
	var hips_idx: int = find_bone(src_skeleton, HIPS)
	var src_rest: Vector3 = src_skeleton.get_bone_rest(hips_idx).origin if hips_idx >= 0 else Vector3.ZERO
	holder.free()
	anim.loop_mode = Animation.LOOP_LINEAR
	var hips_track: int = -1
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(t)).ends_with(HIPS):
			hips_track = t
	if hips_track < 0 or anim.track_get_key_count(hips_track) == 0:
		push_error("[TripoFigure] %s has no Hips translation track" % path)
		return null
	## The bank stores the Hips as rest + (offset from rest) / hip height: put the offset back in this figure's metres.
	var keys: int = anim.track_get_key_count(hips_track)
	var offsets: Array[Vector3] = []
	for k in range(keys):
		var stored: Vector3 = anim.track_get_key_value(hips_track, k)
		offsets.append((stored - src_rest) * hips_rest.y)
	## In place: the straight line from the first key's ground position to the last one's is the clip's travel (the grid moves
	## the actor); what swings about that line (the sway, the surge of a stride) and the height (the bob) are the clip's own.
	var first: Vector3 = offsets[0]
	var drift: Vector3 = offsets[keys - 1] - first
	drift.y = 0.0
	var span: float = anim.track_get_key_time(hips_track, keys - 1) - anim.track_get_key_time(hips_track, 0)
	for k in range(keys):
		var along: float = (anim.track_get_key_time(hips_track, k) - anim.track_get_key_time(hips_track, 0)) / span if span > 0.0 else 0.0
		var off: Vector3 = offsets[k] - drift * along
		anim.track_set_key_value(hips_track, k, Vector3(hips_rest.x + off.x - first.x, hips_rest.y + off.y, hips_rest.z + off.z - first.z))
	anim.set_meta(TRAVEL_META, drift.length())
	return anim


## The raw bank clip `id` of `figure` (no Hips decoding): a clip the figure lacks falls back to the other figure's, loudly (both share the 65 Mixamo
## joints and the bank stores rotations, MOVEMENT §1.3). Null (loud) when there is none.
static func _load_bank_animation(figure: String, id: String) -> Animation:
	var path: String = BANK_CLIP % [figure, id]
	if not ResourceLoader.exists(path):
		var other: String = "male" if figure == "female" else "female"
		push_warning("[TripoFigure] %s has no %s clip %s: FALLBACK to the %s one" % [figure, id, path, other])
		path = BANK_CLIP % [other, id]
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_error("[TripoFigure] no bank clip %s" % path)
		return null
	var holder := scene.instantiate()
	var players: Array[Node] = holder.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		holder.free()
		push_error("[TripoFigure] %s holds no animation" % path)
		return null
	var src_player := players[0] as AnimationPlayer
	var anim: Animation = src_player.get_animation(src_player.get_animation_list()[0]).duplicate(true) as Animation
	holder.free()
	return anim


## The pose `id` of `figure`: the Director's file when there is one (`POSE_FILE`), else the solved one. A one-key Animation whose meta `source` says which and whose meta
## `props` carries the model-in-hand placements. Null (loud) when it cannot be built.
static func bank_pose(figure: String, id: String) -> Animation:
	var path: String = POSE_FILE % [figure, id]
	if FileAccess.file_exists(path):
		return _pose_from_file(figure, id, path)
	if (POSES.get(id, {}) as Dictionary).has("between"):
		return _between_pose(figure, id, POSES[id])
	return solved_pose(figure, id)


## The foot of a derived pose's row off the floor, when it travels between the row's stops (`travel`, default its `between`). False (loud) when the rig lacks the foot.
static func _lift_stepping_foot(figure: String, id: String, spec: Dictionary, skeleton: Skeleton3D, rots: Dictionary, a: Dictionary, b: Dictionary, hips_a: Variant, hips_b: Variant) -> bool:
	var foot: int = TripoPoseKitRef.find_bone(skeleton, String(spec["foot"]))
	if foot < 0:
		push_error("[TripoFigure] the pose '%s' of %s lifts '%s', which the rig lacks" % [id, figure, spec["foot"]])
		return false
	var first: Dictionary = a
	var last: Dictionary = b
	var hips_first: Variant = hips_a
	var hips_last: Variant = hips_b
	if spec.has("travel"):
		var from: Animation = bank_pose(figure, String((spec["travel"] as Array)[0]))
		var to: Animation = bank_pose(figure, String((spec["travel"] as Array)[1]))
		first = TripoPoseKitRef.bone_rotations(skeleton, from, 0.0)
		last = TripoPoseKitRef.bone_rotations(skeleton, to, 0.0)
		hips_first = _hips_place(from)
		hips_last = _hips_place(to)
	var at_a: Vector3 = TripoPoseKitRef.bone_global(skeleton, foot, first, {}).origin + (hips_first as Vector3 if hips_first != null else Vector3.ZERO)
	var at_b: Vector3 = TripoPoseKitRef.bone_global(skeleton, foot, last, {}).origin + (hips_last as Vector3 if hips_last != null else Vector3.ZERO)
	if Vector2(at_b.x - at_a.x, at_b.z - at_a.z).length() >= STEP_MIN_TRAVEL and not TripoPoseKitRef.lift_foot(skeleton, foot, rots, float(spec["lift"])):
		push_warning("[TripoFigure] the pose '%s' of %s: the leg of %s cannot lift, the foot stays down" % [id, figure, spec["foot"]])
	return true


## A DERIVED pose (a `POSES` row with `between`, Director 2026-11-09): every bone at `at` (default half way) along the slerp between two stops, so the layer goes through it without changing the arms' path
## (`ActorAimPose3D`, a passing stop), and the leg of `foot` bent so its ankle rides `lift` higher there: a step instead of a slide. Built from the two stops, so a re-posed aim carries it along.
## A foot that does not travel between them (`STEP_MIN_TRAVEL`) stays down. Null (loud) when a stop or the rig is missing.
static func _between_pose(figure: String, id: String, spec: Dictionary) -> Animation:
	var ends: Array = spec["between"]
	var at: float = float(spec.get("at", 0.5))
	var from: Animation = bank_pose(figure, String(ends[0]))
	var to: Animation = bank_pose(figure, String(ends[1]))
	var rig := _rig(figure)
	if from == null or to == null or rig.is_empty():
		if not rig.is_empty():
			(rig["holder"] as Node).free()
		push_error("[TripoFigure] the pose '%s' of %s has no stops or rig to sit between" % [id, figure])
		return null
	var holder := rig["holder"] as Node
	var skeleton := rig["skeleton"] as Skeleton3D
	var a: Dictionary = TripoPoseKitRef.bone_rotations(skeleton, from, 0.0)
	var b: Dictionary = TripoPoseKitRef.bone_rotations(skeleton, to, 0.0)
	var mid: Dictionary = {}
	for bone: int in a:
		mid[bone] = (a[bone] as Quaternion).slerp(b[bone] as Quaternion, at) if b.has(bone) else a[bone]
	for bone: int in b:
		if not a.has(bone):
			mid[bone] = b[bone]
	var hips_a: Variant = _hips_place(from)
	var hips_b: Variant = _hips_place(to)
	if spec.has("foot") and not _lift_stepping_foot(figure, id, spec, skeleton, mid, a, b, hips_a, hips_b):
		holder.free()
		return null
	var pose := Animation.new()
	pose.length = 0.1
	pose.set_meta("source", "between")
	pose.set_meta("props", {})
	var skeleton_path: NodePath = holder.get_path_to(skeleton)
	for bone: int in mid:
		var track: int = pose.add_track(Animation.TYPE_ROTATION_3D)
		pose.track_set_path(track, NodePath("%s:%s" % [skeleton_path, skeleton.get_bone_name(bone)]))
		pose.rotation_track_insert_key(track, 0.0, mid[bone] as Quaternion)
	if hips_a != null and hips_b != null:
		var track: int = pose.add_track(Animation.TYPE_POSITION_3D)
		pose.track_set_path(track, NodePath("%s:%s" % [skeleton_path, skeleton.get_bone_name(TripoPoseKitRef.find_bone(skeleton, HIPS))]))
		pose.position_track_insert_key(track, 0.0, (hips_a as Vector3).lerp(hips_b as Vector3, at))
	holder.free()
	return pose


## Where a one-key pose places the Hips, null when it does not.
static func _hips_place(pose: Animation) -> Variant:
	for t in range(pose.get_track_count()):
		if pose.track_get_type(t) == Animation.TYPE_POSITION_3D and pose.track_get_key_count(t) > 0:
			return pose.track_get_key_value(t, 0)
	return null


## The default placement of the prop `prop` in its bone's frame: {bone, pos, quat, scale}. The model's barrel (+X) lies along the fingers (the hand's +Y), its sights (+Y) toward the
## thumb (the hand's +X) and its flank (+Z) onto the back of the hand (-Z).
static func prop_default(prop: String) -> Dictionary:
	var w: WeaponDef = WeaponRegistry.shared().get_weapon(prop)
	if w == null or w.model_path == "":
		push_error("[TripoFigure] '%s' is not a weapon with a model (weapons/%s.json \"model\")" % [prop, prop])
		return {}
	var basis := Basis(Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0))
	return {"bone": w.hand_bone, "pos": w.hand_pos, "quat": basis.get_rotation_quaternion(), "scale": w.hand_scale}


## Props held in a pose that are not weapons (MOVEMENT 2026-11-12: the grenade of the throw timeline).
const HELD_PROPS: Dictionary = {"grenade": "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_grenade/Grenade.glb"}


## The model of the prop `prop` (a weapon, or one of `HELD_PROPS`), "" when it has none.
static func prop_model(prop: String) -> String:
	if HELD_PROPS.has(prop):
		return String(HELD_PROPS[prop])
	var w: WeaponDef = WeaponRegistry.shared().get_weapon(prop)
	return w.model_path if w != null else ""


## A pose read from the Director's JSON (see `POSE_FILE`). Every bone is checked against the rig and a bad row is said loudly with its path; null when nothing usable is in it.
static func _pose_from_file(figure: String, id: String, path: String) -> Animation:
	var errors: Array = []
	var row: Dictionary = JsonFile.read_object(path, "TripoFigure", errors)
	var rig := _rig(figure)
	if row.is_empty() or rig.is_empty():
		if not rig.is_empty():
			(rig["holder"] as Node).free()
		return null
	var holder := rig["holder"] as Node
	var skeleton := rig["skeleton"] as Skeleton3D
	var pose := Animation.new()
	pose.length = 0.1
	pose.set_meta("source", "file")
	var bones: Dictionary = row.get("bones", {})
	for name: String in bones:
		var idx: int = TripoPoseKitRef.find_bone(skeleton, name)
		var q: Array = bones[name] as Array if bones[name] is Array else []
		if idx < 0 or q.size() != 4:
			push_error("[TripoFigure] %s: bone '%s' is %s: skipped" % [path, name, "not in the rig" if idx < 0 else "not [x, y, z, w]"])
			continue
		var track: int = pose.add_track(Animation.TYPE_ROTATION_3D)
		pose.track_set_path(track, NodePath("%s:%s" % [holder.get_path_to(skeleton), skeleton.get_bone_name(idx)]))
		pose.rotation_track_insert_key(track, 0.0, Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized())
	if row.has("hips_pos"):   ## a whole-body stance places the Hips too
		var hips: int = TripoPoseKitRef.find_bone(skeleton, "Hips")
		var at: Vector3 = JsonFile.vector3(row.get("hips_pos"), Vector3.ZERO, "%s hips_pos" % path, errors)
		var track: int = pose.add_track(Animation.TYPE_POSITION_3D)
		pose.track_set_path(track, NodePath("%s:%s" % [holder.get_path_to(skeleton), skeleton.get_bone_name(hips)]))
		pose.position_track_insert_key(track, 0.0, at)
	var props: Dictionary = {}
	var rows: Dictionary = row.get("props", {})
	for prop: String in rows:
		var p: Dictionary = rows[prop] as Dictionary if rows[prop] is Dictionary else {}
		if prop_model(prop) == "" or TripoPoseKitRef.find_bone(skeleton, String(p.get("bone", ""))) < 0:
			push_error("[TripoFigure] %s: prop '%s' is unknown or on a bone the rig lacks: skipped" % [path, prop])
			continue
		var pos: Vector3 = JsonFile.vector3(p.get("pos"), Vector3.ZERO, "%s prop %s pos" % [path, prop], errors)
		var qq: Array = p.get("quat", []) as Array if p.get("quat") is Array else []
		if qq.size() != 4:
			push_error("[TripoFigure] %s: prop '%s' has no quat [x, y, z, w]: skipped" % [path, prop])
			continue
		props[prop] = {"bone": String(p["bone"]), "pos": pos, "quat": Quaternion(float(qq[0]), float(qq[1]), float(qq[2]), float(qq[3])).normalized(), "scale": float(p.get("scale", 1.0))}
	pose.set_meta("props", props)
	holder.free()
	if pose.get_track_count() == 0:
		push_error("[TripoFigure] %s holds no usable bone" % path)
		return null
	return pose


## `pose` as the JSON the Director's file uses (see `POSE_FILE`), bones by Mixamo name without prefix. For the dump that starts a Blender session and for the selftest.
static func pose_to_json(figure: String, id: String, pose: Animation) -> Dictionary:
	var bones: Dictionary = {}
	var hips_pos: Array = []
	for t in range(pose.get_track_count()):
		if pose.track_get_type(t) == Animation.TYPE_POSITION_3D:
			var at: Vector3 = pose.track_get_key_value(t, 0)
			hips_pos = [at.x, at.y, at.z]
		if pose.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var name: String = String(pose.track_get_path(t)).get_slice(":", 1)
		for prefix: String in MIXAMO_PREFIXES:
			if not prefix.is_empty() and name.begins_with(prefix):
				name = name.trim_prefix(prefix)
				break
		var q: Quaternion = pose.track_get_key_value(t, 0)
		bones[name] = [q.x, q.y, q.z, q.w]
	var props: Dictionary = {}
	var have: Dictionary = pose.get_meta("props", {})
	for prop: String in have:
		var p: Dictionary = have[prop]
		var pos: Vector3 = p["pos"]
		var qq: Quaternion = p["quat"]
		props[prop] = {"bone": p["bone"], "pos": [pos.x, pos.y, pos.z], "quat": [qq.x, qq.y, qq.z, qq.w], "scale": p["scale"]}
	var out: Dictionary = {"format": "infiltraitor-pose", "v": 1, "figure": figure, "id": id, "bones": bones, "props": props}
	if not hips_pos.is_empty():
		out["hips_pos"] = hips_pos
	return out


## The pose `id` of `figure` (`POSES`) as a one-key Animation: the listed bones' rotations at one time of a bank clip, then its arms solved when the spec says so.
## Null (loud) when the clip is missing or the solve fails.
static func solved_pose(figure: String, id: String) -> Animation:
	if not POSES.has(id):
		push_error("[TripoFigure] no pose '%s' (have %s)" % [id, POSES.keys()])
		return null
	var spec: Dictionary = POSES[id]
	var src: Animation = _load_bank_animation(figure, String(spec["clip"]))
	if src == null:
		return null
	var pose := Animation.new()
	pose.length = 0.1
	var wanted: PackedStringArray = spec["bones"]
	for t in range(src.get_track_count()):
		if src.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone: String = String(src.track_get_path(t)).get_slice(":", 1)
		for prefix: String in MIXAMO_PREFIXES:
			if not prefix.is_empty() and bone.begins_with(prefix):
				bone = bone.trim_prefix(prefix)
				break
		if not wanted.has(bone):
			continue
		var track: int = pose.add_track(Animation.TYPE_ROTATION_3D)
		pose.track_set_path(track, src.track_get_path(t))
		pose.rotation_track_insert_key(track, 0.0, src.rotation_track_interpolate(t, float(spec["time"])))
	if pose.get_track_count() != wanted.size():
		push_warning("[TripoFigure] the pose '%s' of %s has %d of its %d bones (the clip lacks the rest: they keep whatever is playing)" % [id, figure, pose.get_track_count(), wanted.size()])
	if spec.has("two_hand_aim"):
		var rig := _rig(figure)
		var idle: Animation = _load_bank_animation(figure, "idle")
		var solved: bool = not rig.is_empty() and idle != null \
			and TripoPoseKitRef.solve_two_hand_aim(rig["skeleton"] as Skeleton3D, idle, pose, spec["two_hand_aim"])
		if not rig.is_empty():
			(rig["holder"] as Node).free()
		if not solved:
			push_error("[TripoFigure] the pose '%s' of %s could not be solved" % [id, figure])
			return null
	pose.set_meta("source", "solved")
	var props: Dictionary = {}
	for prop: String in spec.get("props", []):
		props[prop] = prop_default(prop)
	pose.set_meta("props", props)
	return pose


## The LIGHT rig of `figure` instantiated for reading its rest data: {holder, skeleton}; the caller frees the holder. {} (loud) when it cannot be read.
static func _rig(figure: String) -> Dictionary:
	var scene := load(rig_path(figure, true)) as PackedScene
	if scene == null:
		push_error("[TripoFigure] cannot load %s" % rig_path(figure, true))
		return {}
	var holder := scene.instantiate()
	var skeletons: Array[Node] = holder.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		holder.free()
		push_error("[TripoFigure] %s has no skeleton" % rig_path(figure, true))
		return {}
	return {"holder": holder, "skeleton": skeletons[0]}


## [right wrist, left wrist, aim direction] of `pose` laid over the idle pose (skeleton space, +Z the front): what the layer will show at weight 1. For the selftest.
static func pose_wrists(figure: String, pose: Animation) -> Array[Vector3]:
	var rig := _rig(figure)
	var idle: Animation = _load_bank_animation(figure, "idle")
	var out: Array[Vector3] = []
	if not rig.is_empty() and idle != null:
		out = TripoPoseKitRef.wrists_under(rig["skeleton"] as Skeleton3D, idle, pose)
	if not rig.is_empty():
		(rig["holder"] as Node).free()
	return out


## The game set of `figure` built from the bank, for a skeleton whose Hips rest at `hips_rest` (what the tool writes): the clips, then the poses.
static func build_library(figure: String, hips_rest: Vector3) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for id: String in GAME_CLIPS:
		var anim: Animation = bank_clip(figure, id, hips_rest)
		if anim == null:
			return null
		lib.add_animation(id, anim)
	for id: String in POSES:
		var pose: Animation = bank_pose(figure, id)
		if pose == null:
			return null
		lib.add_animation(POSE_PREFIX + id, pose)
	var timeline_ids: PackedStringArray = AimSequenceRef.pose_ids(figure, AimSequenceRef.PISTOL_DRAW)   ## the Director's timelines: one pose per keyed frame, each from its own file
	timeline_ids.append_array(AimSequenceRef.pose_ids(figure, AimSequenceRef.THROW_OVERHAND))
	for id: String in timeline_ids:
		var pose: Animation = bank_pose(figure, id)
		if pose == null:
			return null
		lib.add_animation(POSE_PREFIX + id, pose)
	return lib
