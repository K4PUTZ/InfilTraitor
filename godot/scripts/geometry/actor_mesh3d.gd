## ActorMesh3D — an actor as a live skinned mesh on the 3D board (RENDER3D R3D-ACTORS, `ACTOR` D64).
##
## Step 1 promoted what R3D-SPIKE-3D measured (`Spike3D`, deleted here): the rig exported by
## `tools/asset_generation/r3d_live_rig_export.py` (one joined mesh, the rig, the walk as the `walk` action), every surface
## lit the board's way by `actor_mesh3d.gdshader` (no Godot light, one cell-plane fetch; Moto: 9 walking rigs +1.0 ms), its
## materials kept in sync by `Board3DLive.register_prop_light_material()` exactly as a prop's are.
##
## Placed in BASE world coordinates (one GU is one world unit, the ground's top is Y = 0, the same point
## `Board3DLive.ground_point()` hands a billboard), so a camera yaw turns it with the board for free.
## Nothing drives it from gameplay yet: facing, posture and the walk/stop decisions are step 3's bridge from `AgentSprite`.
class_name ActorMesh3D
extends Node3D

const SHADER_PATH := "res://godot/shaders/actor_mesh3d.gdshader"
const AGENT_GLB := "res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/agent_live_walk.glb"
## D61: one walk cycle per GU in 0.56 s; the action is authored at 32 frames at 30 fps (the export's FPS).
const WALK_SPEED: float = (32.0 / 30.0) / 0.56
## D61: a GU is 1.60 m, and a GU is one world unit; the rig is authored in metres.
const METRES_TO_UNITS: float = 1.0 / 1.6

var _board: Node3D = null
var _materials: Array[ShaderMaterial] = []
var _player: AnimationPlayer = null


## `gu` is the gameplay cell the actor stands on; `yaw_deg` turns the body about the vertical axis. Returns false (and logs)
## when the rig cannot be loaded, leaving nothing half-built.
func setup(board: Node3D, gu: Vector2i, yaw_deg: float, glb_path: String = AGENT_GLB) -> bool:
	var scene := load(glb_path) as PackedScene
	if scene == null:
		push_error("[ActorMesh3D] cannot load the rig %s (re-run tools/asset_generation/r3d_live_rig_export.py)" % glb_path)
		return false
	_board = board
	var body := scene.instantiate() as Node3D
	body.scale = Vector3.ONE * METRES_TO_UNITS
	body.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	add_child(body)
	_apply_board_light(body)
	var players := body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_player = players[0] as AnimationPlayer
	position = Vector3(float(gu.x) + 0.5, 0.0, float(gu.y) + 0.5)
	return true


## Loops the rig's `walk` action at D61's speed. False when the rig carries no `walk`.
func play_walk() -> bool:
	if _player == null or not _player.has_animation(&"walk"):
		push_warning("[ActorMesh3D] the rig has no 'walk' action; the mesh stays in its rest pose")
		return false
	_player.get_animation(&"walk").loop_mode = Animation.LOOP_LINEAR
	_player.speed_scale = WALK_SPEED
	_player.play(&"walk")
	return true


## Every surface becomes one board-lit material carrying the model's own albedo colour and texture (one per source material,
## shared across surfaces), registered with the board so the light rebuilds reach it.
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
	if is_instance_valid(_board):
		for m in _materials:
			_board.call("unregister_prop_light_material", m)
