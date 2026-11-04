## ActorViabilityBench — can the engine carry a richer character model? (dev-only, CHARACTER_MASTER_PLAN viability test, 2026-10-20)
##
## Spawns `count` copies of a candidate rig on the live 3D board, lit the board's way (`actor_mesh3d.gdshader`, exactly the
## conversion `ActorMesh3D._apply_board_light()` does), so a handset run measures the real material, the real skinning and the
## real draw-call count of the candidate against the shipped agent:
##   `agent` — `agent_live.glb`, its own `walk_shotgun` action looping (the baseline: 11 080 tris, 20 joints).
##   `agent_<light|full>_<female|male>[_nocoat]` — the Tripo Agents of ACTOR D87 / D91 (`ASSETS/MODELS/official/AGENT_<FIG>[_LIGHT].glb`): 65 Mixamo joints, the
##             DRESSED set only (coat, hat, the coated shirt / trousers / belt, the hat's hair), each piece its own surface. They stand in their
##             rest pose with the material's flat albedo (the palette and the painted head live in Blender's look, not in the glb): this measures
##             triangles, joints, surfaces and draw calls, the T4 question (light vs full on the Moto), not how they look.
## Scenario op (`scenario_runner.gd`): `actor_bench <agent|agent_*> <count>`. Not a gameplay path, not part of any save.
## The Quaternius modes (`quat`, `hero_*`) and the costume suffixes that went with them left on 2026-11-04: ACTOR D85 retired that line. The code is in git history,
## the models in `ARCHIVE/hero_sources/`; the D70-D72 prototype shaders they drove stay in `godot/shaders/`, unwired, for when those features reach the Tripo Agents.
extends RefCounted

const SHADER_PATH := "res://godot/shaders/actor_mesh3d.gdshader"
const EMBLEM_ID := "emblem_ref_skull"   ## ACTOR D95: the default art is `res://ASSETS/emblems/emblem_ref_skull.png`; a file of that name in `user://textures/emblems/` replaces it
const COAT_SHADER_PATH := "res://godot/shaders/actor_coat3d.gdshader"   ## ACTOR D94: the coat, two-sided
const AGENT_RIG := "res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/agent_live.glb"
const OFFICIAL_RIG := "res://ASSETS/MODELS/official/AGENT_%s.glb"
## the pieces tripo_dress leaves BESIDE their masked variants (the undressed ones): the dressed set hides them
const UNDRESSED_PIECES: Array[String] = ["Outfit_Shirt", "Outfit_Trousers", "Outfit_Belt", "Body_Hair", "Icosphere"]
## the other state: no coat, no hat, the plain shirt / trousers / belt and the open hair (the clean base, D89)
const DRESSED_ONLY_PIECES: Array[String] = ["Outfit_Coat", "Outfit_Hat", "Body_Hair_Hat", "Outfit_Shirt_Coated", "Outfit_Trousers_Coated", "Outfit_Belt_Coated"]
## Mixamo bone -> (swing axis, degrees, phase) for the official Agents' synthetic motion (skinning cost does not depend on the pose)
const OFFICIAL_SWING := {
	"LeftUpLeg": [Vector3.RIGHT, 28.0, 0.0], "RightUpLeg": [Vector3.RIGHT, 28.0, PI], "LeftLeg": [Vector3.RIGHT, 18.0, 0.0], "RightLeg": [Vector3.RIGHT, 18.0, PI],
	"LeftArm": [Vector3.RIGHT, 22.0, PI], "RightArm": [Vector3.RIGHT, 22.0, 0.0], "Spine1": [Vector3.UP, 6.0, 0.0],
}
## The agent stands 9.8 voxels of 0.20 m (CHARACTER_MASTER_PLAN §4.7); the candidate is scaled to the same height.
const STAND_HEIGHT_M: float = 1.96
const METRES_TO_UNITS: float = 1.0 / 1.6

class Rig:
	var skeleton: Skeleton3D
	var player: AnimationPlayer
	var swing_bones: Array = []   ## [bone index, axis, radians, phase, rest rotation]
	var phase: float = 0.0

## Drives `tick()` once per frame without anything outside this file knowing about it.
class Ticker extends Node:
	var step: Callable
	func _process(_delta: float) -> void:
		step.call(float(Time.get_ticks_msec()) / 1000.0)

const CoatPushRef = preload("res://godot/scripts/geometry/coat_push3d.gd")   ## ACTOR D94: the legs push the coat (the shader half is in `actor_mesh3d.gdshader`)
const BANK_CLIP: String = "res://ASSETS/ANIMATIONS/bank/%s/%s.glb"
static var _rigs: Array = []
static var _ticker: Ticker = null


## Spawn `count` rigs of `model` near the agent's figure; return the stats line (also printed).
static func spawn(room: Node, model: String, count: int) -> String:
	var board: Node3D = room.call("board3d")
	if board == null:
		push_error("[ActorViabilityBench] no 3D board")
		return ""
	var origin := Vector3.ZERO
	var agent: Object = room.get("agent")
	if agent != null and agent.get("sprite") != null and (agent.sprite as Node).has_meta("figure3d"):
		origin = (agent.sprite.get_meta("figure3d") as Node3D).position
	if not is_instance_valid(_ticker):
		_ticker = Ticker.new()
		_ticker.step = tick
		board.add_child(_ticker)
	var bank_clip: String = ""       ## `..._clip_<id>`: play a bank clip (`ASSETS/ANIMATIONS/bank/<figure>/<id>.glb`) on an official Agent, in place (MV-4's first slice)
	var clip_at: int = model.find("_clip_")
	if clip_at >= 0:
		bank_clip = model.substr(clip_at + 6)
		model = model.substr(0, clip_at)
	var pushed: bool = not model.ends_with("_nopush")   ## `_nopush` : the legs do not push the coat (ACTOR D94's A / B)
	model = model.trim_suffix("_nopush")
	var emblem: bool = not model.ends_with("_noemblem")   ## `_noemblem` (after `_nopush`'s place): the coat without its emblem (ACTOR D95's A / B)
	model = model.trim_suffix("_noemblem")
	var nohair: bool = model.ends_with("_nohair")   ## `_nohair` (before `_alone`): hide the hat's hair, to tell what shows through a gap at the collar
	model = model.trim_suffix("_nohair")
	var alone: bool = model.ends_with("_alone")   ## `_alone`: hide the room's own agent figure (it stands beside the bench in captures and gets in the way of a diagnosis)
	model = model.trim_suffix("_alone")
	if alone:
		var others: Array = [agent]
		others.append_array(room.get("_guards") as Array)
		for other: Variant in others:
			if other != null and is_instance_valid(other) and other.get("sprite") != null and (other.sprite as Node).has_meta("figure3d"):
				(other.sprite.get_meta("figure3d") as Node3D).scale = Vector3.ZERO   # `visible` is rewritten every frame by the room; a zero scale is not
	var hidden: Array[String] = []
	var facing_k: int = -1            ## `_f0` .. `_f3`: the four BASE grid facings the game uses (ActorMesh3D.yaw_for_direction: multiples of 90 degrees), seen from the camera on the diagonal = 3/4 views; none = facing the camera
	for k in range(4):
		if model.ends_with("_f%d" % k):
			facing_k = k
			model = model.trim_suffix("_f%d" % k)
	var official: bool = model.begins_with("agent_")   ## agent_<light|full>_<female|male>[_nocoat]
	var nocoat: bool = false     ## no coat, no hat: the clean base
	var tint: bool = false       ## a colour per piece (black coat, white shirt...) so a garment poking through another is SEEN
	var unmasked: bool = false   ## the coat and hat over the WHOLE shirt / trousers / belt, not the coat-cut variants (a diagnostic of the mask under the coat)
	while official:              ## these three combine, in any order: `actor_video.py` appends `_tint` to a model that may already end in `_nocoat`
		if model.ends_with("_nocoat"):
			nocoat = true
			model = model.trim_suffix("_nocoat")
		elif model.ends_with("_tint"):
			tint = true
			model = model.trim_suffix("_tint")
		elif model.ends_with("_unmasked"):
			unmasked = true
			model = model.trim_suffix("_unmasked")
		else:
			break
	var path: String = AGENT_RIG
	if official:
		var parts: PackedStringArray = model.split("_")
		if parts.size() != 3 or not ["light", "full"].has(parts[1]) or not ["female", "male"].has(parts[2]):
			push_error("[ActorViabilityBench] %s: expected agent_<light|full>_<female|male>" % model)
			return ""
		path = OFFICIAL_RIG % (parts[2].to_upper() + ("_LIGHT" if parts[1] == "light" else ""))
		hidden.append_array(DRESSED_ONLY_PIECES if nocoat else UNDRESSED_PIECES)
		if unmasked:
			hidden = ["Outfit_Shirt_Coated", "Outfit_Trousers_Coated", "Outfit_Belt_Coated", "Body_Hair", "Icosphere"]
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("[ActorViabilityBench] cannot load %s (run `Godot --headless --import` once)" % path)
		return ""
	var tris: int = 0
	var joints: int = 0
	var materials: int = 0
	for i in range(count):
		var body := scene.instantiate() as Node3D
		var holder := Node3D.new()
		holder.name = "BenchRig_%s_%d" % [model, i]
		## a 3 x 3 block, all inside a portrait view
		holder.position = origin + Vector3(1.4 + float(i % 3) * 1.0, 0.0, 1.4 + floorf(float(i) / 3.0) * 1.0)
		board.add_child(holder)
		holder.add_child(body)
		if official:
			body.scale = Vector3.ONE * STAND_HEIGHT_M * METRES_TO_UNITS   ## Tripo exports a 1 m figure standing on z = 0 (hat included)
			body.rotation.y = PI * 0.25 if facing_k < 0 else float(facing_k) * PI * 0.5
		else:
			body.scale = Vector3.ONE * METRES_TO_UNITS
		var converted: Dictionary = {}
		_apply_board_light(board, body, converted)
		if tint:
			_tint_pieces(board, body)
		if nohair:
			hidden.append("Body_Hair_Hat")
		for piece_name: String in hidden:
			for node in body.find_children(piece_name, "MeshInstance3D", true, false):
				(node as Node3D).visible = false
		var rig := Rig.new()
		var skeletons := body.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			rig.skeleton = skeletons[0] as Skeleton3D
			if official and pushed and not nocoat:
				var coats: Array[Node] = body.find_children("Outfit_Coat*", "MeshInstance3D", true, false)
				if not coats.is_empty():   ## the coat is drawn two-sided (`actor_coat3d.gdshader`): a pushed face turned away would show the trousers behind it
					var coat_mat := (((coats[0] as MeshInstance3D).material_override if (coats[0] as MeshInstance3D).material_override != null else (coats[0] as MeshInstance3D).get_active_material(0)) as ShaderMaterial)
					if coat_mat != null:
						coat_mat.shader = BoardLook.graded_shader(COAT_SHADER_PATH)
						var on_emblem: bool = CoatEmblem.apply(coat_mat, EMBLEM_ID if emblem else "")   ## ACTOR D95: the logo through the tier ladder (user folder over default)
						if i == 0:
							print("[ACTOR-BENCH] coat emblem: %s" % (EMBLEM_ID if on_emblem else "none"))
				var on: bool = not coats.is_empty() and CoatPushRef.attach(rig.skeleton, coats[0] as MeshInstance3D)
				if i == 0:
					print("[ACTOR-BENCH] coat push: %s" % ("the legs push the coat" if on else "OFF (no data / no shader)"))
		var players := body.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			rig.player = players[0] as AnimationPlayer
		if official and rig.skeleton != null and bank_clip != "" and _play_bank_clip(rig, model.split("_")[2], bank_clip, float(i) * 0.13):
			pass
		elif official and rig.skeleton != null:   ## a LIVE skeleton in place (the actions travel: `dive` runs out of the view): a synthetic sine on the Mixamo bones
			rig.phase = float(i) * 0.9
			for bone_name: String in OFFICIAL_SWING:
				var idx := _mixamo_bone(rig.skeleton, bone_name)
				if idx >= 0:
					var sw: Array = OFFICIAL_SWING[bone_name]
					rig.swing_bones.append([idx, sw[0], deg_to_rad(float(sw[1])), float(sw[2]), rig.skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()])
		elif model == "agent" and rig.player != null and rig.player.has_animation("walk_shotgun"):
			rig.player.play("walk_shotgun")
			rig.player.seek(float(i) * 0.07, true)
			rig.player.get_animation("walk_shotgun").loop_mode = Animation.LOOP_LINEAR
		_rigs.append(rig)
		if i == 0:
			joints = rig.skeleton.get_bone_count() if rig.skeleton != null else 0
			materials = converted.size()
			for mi in body.find_children("*", "MeshInstance3D", true, false):
				var mesh: Mesh = (mi as MeshInstance3D).mesh
				if not (mi as MeshInstance3D).visible:
					continue   ## a hidden variant is not drawn
				for s in range(mesh.get_surface_count()):
					var arrays := mesh.surface_get_arrays(s)
					var idx_arr: Variant = arrays[Mesh.ARRAY_INDEX]
					tris += int(float((idx_arr as PackedInt32Array).size()) / 3.0) if idx_arr != null else 0
	var line := "[ACTOR-BENCH] %s x%d: %d tris and %d joints and %d material(s) per rig" % [model, count, tris, joints, materials]
	print(line)
	return line


## Put the bank clip `id` of `figure` on the rig's own player, looping and in place (the Hips keep their height, lose their travel and sit over the holder). False when it cannot (loud).
static func _play_bank_clip(rig: Rig, figure: String, id: String, offset_s: float) -> bool:
	var path: String = BANK_CLIP % [figure, id]
	if not ResourceLoader.exists(path):   ## MV-1 §3: the other figure's clip, retargeted by rotations, only as a MARKED fallback
		var other: String = "male" if figure == "female" else "female"
		push_warning("[ActorViabilityBench] %s has no %s clip %s: FALLBACK to the %s one" % [figure, id, path, other])
		path = BANK_CLIP % [other, id]
	var scene := load(path) as PackedScene
	if scene == null or rig.player == null:
		push_error("[ActorViabilityBench] no bank clip %s (or the rig has no player)" % path)
		return false
	var holder := scene.instantiate()
	var src: Array = holder.find_children("*", "AnimationPlayer", true, false)
	if src.is_empty():
		holder.free()
		push_error("[ActorViabilityBench] %s holds no animation" % path)
		return false
	var anim: Animation = ((src[0] as AnimationPlayer).get_animation((src[0] as AnimationPlayer).get_animation_list()[0])).duplicate()
	var src_rest: Vector3 = Vector3.ZERO
	var src_skeletons: Array = holder.find_children("*", "Skeleton3D", true, false)
	if not src_skeletons.is_empty():
		src_rest = (src_skeletons[0] as Skeleton3D).get_bone_rest((src_skeletons[0] as Skeleton3D).find_bone("mixamorig_Hips")).origin
	holder.free()
	anim.loop_mode = Animation.LOOP_LINEAR
	## The bank stores the Hips as rest + (offset from rest) / hip height (`tripo_anim_bank.py`): put it back in this figure's metres, and in place.
	var hips_idx: int = _mixamo_bone(rig.skeleton, "Hips")
	var rest: Vector3 = rig.skeleton.get_bone_rest(hips_idx).origin
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with("mixamorig_Hips"):
			for k in range(anim.track_get_key_count(t)):
				var v: Vector3 = anim.track_get_key_value(t, k)
				var off: Vector3 = (v - src_rest) * rest.y
				anim.track_set_key_value(t, k, Vector3(rest.x, rest.y + off.y, rest.z))
	var lib: AnimationLibrary = rig.player.get_animation_library("") if rig.player.has_animation_library("") else null
	if lib == null:
		lib = AnimationLibrary.new()
		rig.player.add_animation_library("", lib)
	if lib.has_animation("bank_clip"):
		lib.remove_animation("bank_clip")
	lib.add_animation("bank_clip", anim)
	rig.player.play("bank_clip")
	rig.player.seek(offset_s, true)
	return true


## Advance the synthetic motion (the official Agents with no clip; an AnimationPlayer drives itself).
static func tick(time_s: float) -> void:
	for rig: Rig in _rigs:
		if rig.skeleton == null or rig.swing_bones.is_empty():
			continue
		for entry: Array in rig.swing_bones:
			var angle: float = sin(time_s * 5.5 + float(entry[3]) + rig.phase) * float(entry[2])
			rig.skeleton.set_bone_pose_rotation(int(entry[0]), (entry[4] as Quaternion) * Quaternion(entry[1], angle))


static func report_render(tag: String) -> void:
	print("[ACTOR-BENCH] %s: draw calls %d, primitives %d, objects %d" % [tag,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])


## A colour per piece of the official Agents (the glb carries one flat material); keeps the board's light and registers each copy with it.
const PIECE_TINT := {"Outfit_Coat": Color(0.05, 0.05, 0.06), "Outfit_Hat": Color(0.05, 0.05, 0.06), "Outfit_Shirt": Color(1, 1, 1), "Outfit_Shirt_Coated": Color(1, 1, 1),
	"Outfit_Trousers": Color(0.12, 0.2, 0.55), "Outfit_Trousers_Coated": Color(0.12, 0.2, 0.55), "Outfit_Tie": Color(0.8, 0.1, 0.1),
	"Outfit_Belt": Color(0.9, 0.55, 0.1), "Outfit_Belt_Coated": Color(0.9, 0.55, 0.1), "Outfit_Buckle": Color(0.9, 0.9, 0.2), "Outfit_Shoes": Color(0.1, 0.1, 0.1),
	"Body_Hair": Color(0.35, 0.2, 0.1), "Body_Hair_Hat": Color(0.35, 0.2, 0.1), "Body_Head": Color(0.85, 0.6, 0.5), "Body_Hands": Color(0.85, 0.6, 0.5)}


static func _tint_pieces(board: Node3D, body: Node) -> void:
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var key: String = str(m.name).split(".")[0]
		var src := m.get_active_material(0) as ShaderMaterial
		if src == null or not PIECE_TINT.has(key):
			continue
		var sm := src.duplicate() as ShaderMaterial
		var textured: Variant = src.get_shader_parameter("has_tex")
		## a piece that carries its own texture (tripo_coat_regions, tripo_surface; embedded in the GLB) is drawn as it is: the tint would multiply it
		sm.set_shader_parameter("albedo", Color.WHITE if (textured != null and float(textured) > 0.5) else PIECE_TINT[key])
		board.call("register_prop_light_material", sm)
		m.material_override = sm


## The importer may keep the colon of `mixamorig:Hips` or turn it into an underscore: try both, then the bare name.
static func _mixamo_bone(skeleton: Skeleton3D, bone_name: String) -> int:
	for prefix in ["mixamorig:", "mixamorig_", ""]:
		var idx := skeleton.find_bone(prefix + bone_name)
		if idx >= 0:
			return idx
	return -1


static func _apply_board_light(board: Node3D, body: Node, converted: Dictionary) -> void:
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
				board.call("register_prop_light_material", sm)
			m.set_surface_override_material(s, converted[src])
