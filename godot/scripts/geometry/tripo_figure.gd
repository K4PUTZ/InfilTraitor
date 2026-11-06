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

const FIGURES: PackedStringArray = ["female", "male"]
const RIG := "res://ASSETS/MODELS/official/AGENT_%s.glb"
## the pieces tripo_dress leaves BESIDE their masked variants (the undressed ones): the dressed set hides them
const UNDRESSED_PIECES: Array[String] = ["Outfit_Shirt", "Outfit_Trousers", "Outfit_Belt", "Body_Hair", "Icosphere"]
## the other state: no coat, no hat, the plain shirt / trousers / belt and the open hair (the clean base, D89)
const DRESSED_ONLY_PIECES: Array[String] = ["Outfit_Coat", "Outfit_Hat", "Body_Hair_Hat", "Outfit_Shirt_Coated", "Outfit_Trousers_Coated", "Outfit_Belt_Coated"]
## The agent stands 9.8 voxels of 0.20 m (CHARACTER_MASTER_PLAN §4.7); Tripo exports a 1 m figure standing on y = 0 (hat included).
const STAND_HEIGHT_M: float = 1.96
## Tripo's figure faces +Z (glTF's front); `ActorMesh3D.yaw_for_direction()` turns a front of -Z.
const FRONT_YAW: float = PI
const COAT_SHADER_PATH := "res://godot/shaders/actor_coat3d.gdshader"   ## ACTOR D94: the coat, two-sided
const EMBLEM_ID := "emblem_ref_skull"   ## ACTOR D95: the default art is `res://ASSETS/emblems/emblem_ref_skull.png`; a file of that name in `user://textures/emblems/` replaces it
## The leather pieces' matte sheen (CHARACTER §7a, 2026-11-06): the strength the board-lit shader adds on the key light's highlight.
## [strength, power]: the coat's matte leather (Director: "Suave está bom") on the trousers too; the shoes glossier, a tighter highlight.
const SHEEN: Dictionary = {"Outfit_Coat": [0.15, 6.0], "Outfit_Trousers": [0.15, 6.0], "Outfit_Hat": [0.09, 6.0], "Outfit_Shoes": [0.45, 18.0]}
const MIXAMO_PREFIXES: PackedStringArray = ["mixamorig:", "mixamorig_", ""]

const BANK_CLIP := "res://ASSETS/ANIMATIONS/bank/%s/%s.glb"
const GAME_LIBRARY := "res://ASSETS/ANIMATIONS/game/agent_%s.res"
## The clips the game set carries (the three the corrective keys were made on, `ACTOR` D103).
const GAME_CLIPS: PackedStringArray = ["idle", "walk", "run"]
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
	if push and skeleton != null:
		took["push"] = CoatPush3D.attach(skeleton, coat)
	apply_sheen(body)
	return took


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


## The game set of `figure` built from the bank, for a skeleton whose Hips rest at `hips_rest` (what the tool writes).
static func build_library(figure: String, hips_rest: Vector3) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for id: String in GAME_CLIPS:
		var anim: Animation = bank_clip(figure, id, hips_rest)
		if anim == null:
			return null
		lib.add_animation(id, anim)
	return lib
