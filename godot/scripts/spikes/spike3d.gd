## Spike3D — R3D-SPIKE-3D (RENDER3D v1.19): real 3D lights on the board (S1) and live actor meshes (S2).
##
## A SPIKE, NOT A FEATURE. It answers two cost/look questions on the Moto and is deleted after the Director
## decides. Nothing here changes a default: every path is behind a DevFlag.
##
##   LIGHT3D=noshadow|near|all   S1 — the board's faces are lit by one OmniLight3D per map lamp instead of the
##                               CPU light buckets (`Board3DLive.LIT3D`); soot, tone and depth dim stay. "near"
##                               casts shadows from the NEAR_SHADOWS lamps closest to the agent, "all" from every one.
##   ACTOR_MESH=<n>              S2 — n live instances of the real agent rig (`agent_base.glb`), placed one GU off
##                               the agent and the guards (so billboard and mesh can be compared side by side), with
##                               a few bones swung every frame. The GLB has NO animation (it was authored for the
##                               frame bake), so the swing stands in for one: it exercises the same skinning cost.
##                               Without LIGHT3D the meshes get lamps of their own on layer 2 (no shadows), the
##                               hybrid that leaves the board on its buckets.
class_name Spike3D
extends Node3D

## `tools/asset_generation/r3d_live_rig_export.py`: one joined mesh, the rig, and the real walk as the `walk` action.
const AGENT_GLB := "res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/agent_live_walk.glb"
## D61: one walk cycle per GU at 0.56 s; the action is 32 frames at 30 fps.
const WALK_SPEED: float = (32.0 / 30.0) / 0.56
const NEAR_SHADOWS: int = 4
## A lamp hangs just under one storey (one world unit).
const LAMP_HEIGHT: float = 0.9
## D61: a GU is 1.60 m, and a GU is one world unit.
const METRES_TO_UNITS: float = 1.0 / 1.6
const ACTOR_LAYER: int = 2

var _skeletons: Array = []
var _bones: Array = []
var _t: float = 0.0


## PROP_MESH=<n> PROP_KIND=light|heavy — n STATIC meshes (no skeleton) around the agent: `light` is one
## single-mesh CC0 rifle scaled to furniture size (the cheap end), `heavy` the posed static agent statue
## (~7.6k tris in many parts, the expensive end). No real prop asset exists yet.
const PROP_LIGHT := "res://ASSETS/ISOMETRIC/source_assets/imported_models/quaternius_ultimate_guns_pack/extracted/Assault Rifle.glb"
const PROP_HEAVY := "res://ASSETS/ISOMETRIC/source_assets/imported_models/agent/agent_posed_shotgun_lowered.glb"


func add_props(room: Node, board: Node3D, count: int, kind: String) -> void:
	var scene := load(PROP_HEAVY if kind == "heavy" else PROP_LIGHT) as PackedScene
	if scene == null:
		push_error("[Spike3D] cannot load the %s prop" % kind)
		return
	var agent_cell: Vector2i = room.get("agent").cell
	var meshes: int = 0
	var tris: int = 0
	var placed: int = 0
	var ring: int = 2
	while placed < count:
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if placed >= count or (abs(dx) != ring and abs(dy) != ring) or (dx + dy) % 2 != 0:
					continue
				var body := scene.instantiate() as Node3D
				body.position = _cell_point(board, agent_cell + Vector2i(dx, dy))
				body.scale = Vector3.ONE * (0.5 if kind != "heavy" else METRES_TO_UNITS)
				body.rotation_degrees = Vector3(0.0, 30.0 * float(placed), 0.0)
				add_child(body)
				for mi in body.find_children("*", "MeshInstance3D", true, false):
					var m := mi as MeshInstance3D
					m.layers = 1 << (ACTOR_LAYER - 1)
					meshes += 1
					if m.mesh != null:
						for s in range(m.mesh.get_surface_count()):
							var idx: PackedInt32Array = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
							tris += idx.size() / 3
				placed += 1
		ring += 1
	print("[SPIKE3D] static props: %d %s instance(s), %d MeshInstance3D, %d tris total" % [count, kind, meshes, tris])


static func apply(room: Node, board: Node3D, light_mode: String, mesh_count: int) -> Spike3D:
	var spike := Spike3D.new()
	spike.name = "Spike3D"
	board.add_child(spike)
	spike._build(room, board, light_mode, mesh_count)
	return spike


func _build(room: Node, board: Node3D, light_mode: String, mesh_count: int) -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.57, 0.62)
	environment.ambient_light_energy = 0.55
	env.environment = environment
	add_child(env)

	var sources: Array = room.get("_current_light_sources")
	var agent_cell: Vector2i = room.get("agent").cell
	var lamps: Array = []
	## The layout's lamps are dictionaries in the map's own shape: x, y, radius, intensity.
	for source in sources:
		if not (source is Dictionary):
			continue
		lamps.append({"cell": Vector2i(int(source.get("x", 0)), int(source.get("y", 0))),
			"radius": float(source.get("radius", 5)), "intensity": float(source.get("intensity", 1.0))})
	lamps.sort_custom(func(a, b) -> bool:
		return Vector2(a["cell"] - agent_cell).length() < Vector2(b["cell"] - agent_cell).length())
	var shadowed: int = 0
	var lit_board: bool = light_mode != ""
	## PROP_NOLAMPS=1: the props get NO real lamps (ambient only), to separate the geometry's cost from the
	## per-pixel light's.
	var props_lit: bool = int(DevFlags.value("PROP_MESH", "0")) > 0 and DevFlags.value("PROP_NOLAMPS", "0") != "1"
	if lit_board or mesh_count > 0 or props_lit:
		for i in range(lamps.size()):
			var source: Dictionary = lamps[i]
			var light := OmniLight3D.new()
			light.position = _cell_point(board, source["cell"]) + Vector3(0.0, LAMP_HEIGHT, 0.0)
			light.omni_range = float(source["radius"]) + 1.0
			light.light_energy = 1.6 * float(source["intensity"])
			light.light_color = Color(1.0, 0.94, 0.82)
			light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
			if not lit_board:
				light.light_cull_mask = 1 << (ACTOR_LAYER - 1)
			var cast: bool = lit_board and (light_mode == "all" or (light_mode == "near" and i < NEAR_SHADOWS))
			light.shadow_enabled = cast
			if cast:
				shadowed += 1
			add_child(light)
	print("[SPIKE3D] lights: mode=%s lamps=%d shadowed=%d board_lit=%s" % [
		light_mode if lit_board else "(actors only)", lamps.size(), shadowed, lit_board])

	var prop_count: int = int(DevFlags.value("PROP_MESH", "0"))
	if prop_count > 0:
		add_props(room, board, prop_count, DevFlags.value("PROP_KIND", "light"))
	if mesh_count <= 0:
		return
	var scene := load(AGENT_GLB) as PackedScene
	if scene == null:
		push_error("[Spike3D] cannot load %s" % AGENT_GLB)
		return
	var anchors: Array[Vector2i] = [agent_cell]
	for guard in room.get("_guards"):
		if guard != null and is_instance_valid(guard):
			anchors.append(guard.cell)
	var meshes: int = 0
	var surfaces: int = 0
	for i in range(mesh_count):
		var cell: Vector2i = anchors[i % anchors.size()] + Vector2i(1, 0)
		var body := scene.instantiate() as Node3D
		body.scale = Vector3.ONE * METRES_TO_UNITS
		body.position = _cell_point(board, cell)
		body.rotation_degrees = Vector3(0.0, 45.0 + 90.0 * float(i % 4), 0.0)
		add_child(body)
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).layers = 1 << (ACTOR_LAYER - 1)
			meshes += 1
			if (mi as MeshInstance3D).mesh != null:
				surfaces += (mi as MeshInstance3D).mesh.get_surface_count()
		var players := body.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			var player := players[0] as AnimationPlayer
			var anim_name: StringName = &"walk" if player.has_animation(&"walk") else player.get_animation_list()[0]
			player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			player.speed_scale = WALK_SPEED
			player.play(anim_name)
			player.seek(float(i) * 0.1, true)
			continue
		for sk in body.find_children("*", "Skeleton3D", true, false):
			var skeleton := sk as Skeleton3D
			var picked: Array = []
			for b in range(skeleton.get_bone_count()):
				var bone_name := skeleton.get_bone_name(b).to_lower()
				if bone_name.contains("thigh") or bone_name.contains("upper") or bone_name.contains("leg") \
						or bone_name.contains("arm") or bone_name.contains("shin") or bone_name.contains("fore"):
					picked.append(b)
			if picked.is_empty():
				for b in range(mini(6, skeleton.get_bone_count())):
					picked.append(b)
			_skeletons.append(skeleton)
			_bones.append(picked)
	print("[SPIKE3D] actor meshes: %d instance(s), %d MeshInstance3D, %d surface(s), %d procedurally swung skeleton(s), %d bone(s) each (0 = the real walk plays)" % [
		mesh_count, meshes, surfaces, _skeletons.size(), (_bones[0] as Array).size() if not _bones.is_empty() else 0])


func _cell_point(board: Node3D, cell: Vector2i) -> Vector3:
	var p2: Vector2 = board.get("_cell_to_world").call(cell)
	return board.ground_point(p2)


func _process(delta: float) -> void:
	_t += delta
	var swing: float = sin(_t * TAU * 0.9) * 0.45
	for s in range(_skeletons.size()):
		var skeleton: Skeleton3D = _skeletons[s]
		var picked: Array = _bones[s]
		for k in range(picked.size()):
			var b: int = picked[k]
			var rest: Quaternion = skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
			var sign_k: float = 1.0 if k % 2 == 0 else -1.0
			skeleton.set_bone_pose_rotation(b, rest * Quaternion(Vector3.RIGHT, swing * sign_k))
