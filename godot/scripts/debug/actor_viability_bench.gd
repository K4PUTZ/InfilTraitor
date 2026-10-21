## ActorViabilityBench — can the engine carry a richer character model? (dev-only, CHARACTER_MASTER_PLAN viability test, 2026-10-20)
##
## Spawns `count` copies of a candidate rig on the live 3D board, lit the board's way (`actor_mesh3d.gdshader`, exactly the
## conversion `ActorMesh3D._apply_board_light()` does), so a handset run measures the real material, the real skinning and the
## real draw-call count of the candidate against the shipped agent:
##   `agent` — `agent_live.glb`, its own `walk_shotgun` action looping (the baseline: 11 080 tris, 20 joints).
##   `quat`  — the lean Quaternius Superhero (CC0): ~14 k tris, 65 joints, no animation in the free pack, so its limbs are
##             swung by a SYNTHETIC sine on the leg / arm / spine bones. Skinning cost does not depend on the pose, which is
##             what this measures; the motion is NOT a walk cycle and says nothing about animation quality.
##   `hero_naked` / `hero_split` / `hero_joined` — the same body re-exported WITH the Universal Animation Library's 43 actions (same 65
##             bone names, so they drop in) and, in `split` / `joined`, a placeholder outfit skinned to the same skeleton: jacket,
##             trousers, shoes, hat, tie, backpack + 2 gadget pouches, as separate pieces (`split`, 12 surfaces) or merged by material
##             (`joined`, 6). They play `Walk_Formal_Loop` and march along a lane (a video needs them to move; the walk's speed is NOT
##             matched to the stride, so foot sliding is unjudged).
## Scenario op (`scenario_runner.gd`): `actor_bench <agent|quat|hero_naked|hero_split|hero_joined> <count>`. Not a gameplay path, not part of any save.
extends RefCounted

const SHADER_PATH := "res://godot/shaders/actor_mesh3d.gdshader"
const CLOTH_SHADER_PATH := "res://godot/shaders/actor_cloth3d.gdshader"   ## D70 prototype: the costume's cloth gets a soft sheen
const CLOTH_MATERIALS: PackedStringArray = ["Suit_Black", "Coat_Fabric", "Shirt_Fabric", "Tie_Silk"]
const EYE_SHADER_PATH := "res://godot/shaders/actor_mask_eye3d.gdshader"      ## D71 prototype: the mask's lit eyes
const HALO_SHADER_PATH := "res://godot/shaders/actor_mask_halo3d.gdshader"
## D77 (v5): the hat's crown IS the mask, so the masked agent wears no hat, and his hair and beard are under the shell
const MASK_PIECES: Array[String] = ["Mask_Shell", "Mask_Band", "Mask_Jaw", "Mask_Eyes", "Mask_Halo"]
const HAT_UPRIGHT: Array[String] = ["Outfit_HatCrown", "Outfit_HatBrim", "Outfit_HatBand"]
const FACE_HAIR: Array[String] = ["Face_Hair", "Face_Beard"]
const EYES_ON_SECONDS: float = 0.7
const CLOAK_SHADER_PATH := "res://godot/shaders/actor_cloak3d.gdshader"   ## D72 prototype: `hero_*_cloak` draws the figures as the faint ghost, crouched
const AGENT_RIG := "res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/agent_live.glb"
const QUAT_RIG := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/superhero_male_lean.glb"
## The agent stands 9.8 voxels of 0.20 m (CHARACTER_MASTER_PLAN §4.7); the candidate is scaled to the same height.
const HERO_RIG := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_universal_base/%s.glb"
const HERO_HEIGHT_M: float = 1.83            ## the body's top of head, measured from its bones / mesh (feet at 0)
const HERO_WALK := "Walk_Formal"   ## the import strips the `_Loop` suffix and loops it
const LANE_GU: float = 9.0
const LANE_SPEED_GU_S: float = 1.2
const STAND_HEIGHT_M: float = 1.96
const METRES_TO_UNITS: float = 1.0 / 1.6
const SPACING_GU: float = 1.25
const PER_ROW: int = 6
## UE-mannequin bone -> (swing axis, degrees, phase) for the synthetic motion.
const SWING := {
	"thigh_l": [Vector3.RIGHT, 28.0, 0.0], "thigh_r": [Vector3.RIGHT, 28.0, PI],
	"calf_l": [Vector3.RIGHT, 18.0, 0.0], "calf_r": [Vector3.RIGHT, 18.0, PI],
	"upperarm_l": [Vector3.RIGHT, 22.0, PI], "upperarm_r": [Vector3.RIGHT, 22.0, 0.0],
	"spine_02": [Vector3.UP, 6.0, 0.0],
}

class Rig:
	var skeleton: Skeleton3D
	var player: AnimationPlayer
	var swing_bones: Array = []   ## [bone index, axis, radians, phase, rest rotation]
	var phase: float = 0.0
	var holder: Node3D
	var lane_start: Vector3
	var lane_offset: float = 0.0

## Drives `tick()` once per frame without anything outside this file knowing about it.
class Ticker extends Node:
	var step: Callable
	func _process(_delta: float) -> void:
		step.call(float(Time.get_ticks_msec()) / 1000.0)

static var _rigs: Array = []
static var _glow_mats: Array = []
static var _glow_t0: float = 0.0
static var _glow_hold: float = -1.0   ## >= 0 pins the eyes at that level (`_maskoff` pins them at 0, to photograph the lenses dark)
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
	var cloak: bool = model.ends_with("_cloak")
	model = model.trim_suffix("_cloak")
	## a costume file holds BOTH styles; the engine will show one (D70): `_black` hides the coat, `_normal` hides the gloves
	_glow_hold = -1.0
	if model.ends_with("_maskoff"):
		_glow_hold = 0.0
		model = model.trim_suffix("off")
	var hidden: Array[String] = []
	if model.ends_with("_shaved"):     ## the beard is optional (v5): `hero_<file>_normal_shaved`
		hidden.append("Face_Beard")
		model = model.trim_suffix("_shaved")
	var face_camera: bool = false      ## the mask view: stand still and look at the camera (the iso camera looks along the grid diagonal)
	if model.ends_with("_black"):
		hidden.append("Outfit_Coat")
		hidden.append_array(MASK_PIECES)
		model = model.trim_suffix("_black")
	elif model.ends_with("_normal"):
		hidden.append("Outfit_Gloves")
		hidden.append_array(MASK_PIECES)
		model = model.trim_suffix("_normal")
	elif model.ends_with("_mask"):      ## the black style with the hat's crown come down over the face as the mask, the eyes lit
		hidden.append("Outfit_Coat")
		hidden.append_array(HAT_UPRIGHT)
		hidden.append_array(FACE_HAIR)
		model = model.trim_suffix("_mask")
		face_camera = true
	var march: bool = model.ends_with("_march")  ## a video wants them walking along a lane; a measurement wants them still on the grid
	model = model.trim_suffix("_march")
	var hero: bool = model.begins_with("hero_")
	var path: String = HERO_RIG % model if hero else (QUAT_RIG if model == "quat" else AGENT_RIG)
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
		holder.position = origin + Vector3(2.0 + float(i % PER_ROW) * SPACING_GU, 0.0, 2.0 + float(i / PER_ROW) * SPACING_GU)
		if march:  ## one lane of figures, each staggered along it
			holder.position = origin + Vector3(-3.0, 0.0, 2.0 + float(i % 8) * 1.1)
		board.add_child(holder)
		holder.add_child(body)
		if hero:
			body.scale = Vector3.ONE * (STAND_HEIGHT_M / HERO_HEIGHT_M) * METRES_TO_UNITS
			body.rotation.y = PI * 0.25 if face_camera else PI * 0.5   ## the rig's front is +Z; march toward +X (grid east), or face the camera on the diagonal
		elif model == "quat":
			body.scale = Vector3.ONE * (STAND_HEIGHT_M / _mesh_height(body)) * METRES_TO_UNITS
			body.rotation.y = PI
		else:
			body.scale = Vector3.ONE * METRES_TO_UNITS
		var converted: Dictionary = {}
		_apply_board_light(board, body, converted, cloak)
		for piece_name: String in hidden:
			for node in body.find_children(piece_name, "MeshInstance3D", true, false):
				(node as Node3D).visible = false
		var rig := Rig.new()
		rig.holder = holder
		rig.lane_start = holder.position
		rig.lane_offset = float(i / 8) * 3.1 + float(i % 8) * 0.9 if march else -1.0
		var skeletons := body.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			rig.skeleton = skeletons[0] as Skeleton3D
		var players := body.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			rig.player = players[0] as AnimationPlayer
		if hero:
			var clip: String = "Crouch_Idle" if cloak else ("Idle" if face_camera else HERO_WALK)   ## the cloak works only crouched and still (D72)
			if rig.player == null or not rig.player.has_animation(clip):
				push_error("[ActorViabilityBench] %s has no %s" % [path, clip])
			else:
				rig.player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				rig.player.play(clip)
				rig.player.seek(float(i) * 0.11, true)
		elif model == "agent" and rig.player != null and rig.player.has_animation("walk_shotgun"):
			rig.player.play("walk_shotgun")
			rig.player.seek(float(i) * 0.07, true)
			rig.player.get_animation("walk_shotgun").loop_mode = Animation.LOOP_LINEAR
		elif model == "quat" and rig.skeleton != null:
			rig.phase = float(i) * 0.9
			for bone_name: String in SWING:
				var idx := rig.skeleton.find_bone(bone_name)
				if idx >= 0:
					var s: Array = SWING[bone_name]
					rig.swing_bones.append([idx, s[0], deg_to_rad(float(s[1])), float(s[2]), rig.skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()])
		_rigs.append(rig)
		if i == 0:
			joints = rig.skeleton.get_bone_count() if rig.skeleton != null else 0
			materials = converted.size()
			for mi in body.find_children("*", "MeshInstance3D", true, false):
				var mesh: Mesh = (mi as MeshInstance3D).mesh
				for s in range(mesh.get_surface_count()):
					var arrays := mesh.surface_get_arrays(s)
					var idx_arr: Variant = arrays[Mesh.ARRAY_INDEX]
					tris += (idx_arr as PackedInt32Array).size() / 3 if idx_arr != null else 0
	_glow_t0 = float(Time.get_ticks_msec()) / 1000.0 + 0.4
	var line := "[ACTOR-BENCH] %s x%d: %d tris and %d joints and %d material(s) per rig" % [model, count, tris, joints, materials]
	print(line)
	return line


## Advance the synthetic motion (the quat rigs only; the agent's AnimationPlayer drives itself).
static func tick(time_s: float) -> void:
	## The eyes ramp on over EYES_ON_SECONDS and then breathe a little (the mask's lenses and their halo).
	var on: float = clampf((time_s - _glow_t0) / EYES_ON_SECONDS, 0.0, 1.0)
	var level: float = _glow_hold if _glow_hold >= 0.0 else on * (0.94 + 0.06 * sin(time_s * 3.3))
	for gm: ShaderMaterial in _glow_mats:
		gm.set_shader_parameter("intensity", level)
	for rig: Rig in _rigs:
		if rig.holder != null and rig.lane_offset >= 0.0 and rig.holder.name.contains("hero_"):
			rig.holder.position = rig.lane_start + Vector3(fposmod(time_s * LANE_SPEED_GU_S + rig.lane_offset, LANE_GU), 0.0, 0.0)
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


static func _mesh_height(body: Node3D) -> float:
	var top: float = -INF
	var bottom: float = INF
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var box: AABB = m.get_aabb()
		var to_body: Transform3D = body.global_transform.affine_inverse() * m.global_transform
		for corner in range(8):
			var p: Vector3 = to_body * box.get_endpoint(corner)
			top = maxf(top, p.y)
			bottom = minf(bottom, p.y)
	return maxf(top - bottom, 0.01)


static func _apply_board_light(board: Node3D, body: Node, converted: Dictionary, cloak: bool = false) -> void:
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in range(m.mesh.get_surface_count()):
			var src: Material = m.get_active_material(s)
			if not converted.has(src):
				var sm := ShaderMaterial.new()
				var cloth: bool = src != null and CLOTH_MATERIALS.has(src.resource_name)
				sm.shader = BoardLook.graded_shader(CLOAK_SHADER_PATH if cloak else (CLOTH_SHADER_PATH if cloth else SHADER_PATH))
				var std := src as BaseMaterial3D
				if std != null:
					sm.set_shader_parameter("albedo", std.albedo_color)
					if std.albedo_texture != null:
						sm.set_shader_parameter("albedo_tex", std.albedo_texture)
						sm.set_shader_parameter("has_tex", 1.0)
				if src != null and src.resource_name == "Mask_EyeGlow":
					sm.shader = load(EYE_SHADER_PATH)
					_glow_mats.append(sm)
				elif src != null and src.resource_name == "Mask_EyeHalo":
					sm.shader = load(HALO_SHADER_PATH)
					_glow_mats.append(sm)
				converted[src] = sm
				if not _glow_mats.has(sm):
					board.call("register_prop_light_material", sm)
			m.set_surface_override_material(s, converted[src])
