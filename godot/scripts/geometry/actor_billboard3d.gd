## ActorBillboard3D — one AgentSprite, drawn as depth-tested billboards in the 3D board.
##
## RENDER3D R3D-4b. R3D-4a (2026-09-18) measured the billboard against a depth-composited 2D sprite
## and the Director ratified the billboard: on the Moto g04s it costs +0.4 ms against +9.9 ms, and
## it is the only one of the two that lets glass tint an actor standing behind it.
##
## A MIRROR, NOT A REWRITE. `AgentSprite` keeps deciding WHAT is shown — facing, posture, walk and
## throw frame, head layer, grip, and the light uniforms the room's lights drive. This node only
## changes WHERE THE PIXELS LAND: each frame it reads the body `Sprite2D` and every layer child, and
## places one quad per visible one. Nothing in the 2D actor's logic knows this exists, which is what
## keeps D44's four facings and D47's GU-boundary snap intact: they are decisions of the source, and
## the quad is placed from the source's own resolved offset and anchor.
##
## PLACEMENT. The source's `global_position` is the actor's FEET (the sprite's offset is `-anchor`).
## That 2D point becomes a 3D ground point through the board's own 2D→GU map, and every quad is
## offset from it in the CAMERA's plane by its pixel distance from the feet, so the figure keeps the
## bake's exact pixel geometry at every zoom (the camera's ortho size already carries it).
##
## DEPTH — A VERTICAL PLANE, NOT A CAMERA-PARALLEL ONE. R3D-4a measured a quad parallel to the camera,
## whose depth is the feet's at every height. It fails in two ways the first live capture showed: a
## glass pane BEHIND the actor tints his hat (at head height the pane is nearer the camera than his
## feet plane), and the tilted floor cuts his shoes off (below the anchor row the floor is nearer than
## the quad). So each quad stands in the world — vertical, facing the camera's azimuth — and is
## stretched by 1/cos(30°) so its pixels stay 1:1 on screen; depth is then correct at every height,
## the head nearer than the feet by height × sin(30°), as a body's is.
##
## FEET LIFT. A vertical plane still puts the sole a few pixels BELOW the anchor row under the floor
## (the shoes reach forward). The quad is slid toward the camera along the view axis, which moves it
## in depth and not at all on screen; the slope of the view raises it by lift × sin(30°). Default
## 0.15 units, `ACTORS3D_BIAS` to tune. Too much and legs show through a wall the actor stands
## behind (R3D-4a: 0.5 did).
##
## Layers (head, hat, weapon) sit a hair in front of the body in index order, because Godot draws a
## child after its parent and a coplanar alpha-scissor quad would z-fight instead.
##
## The 2D source is hidden (`visible = false` on the AgentSprite ONLY) and keeps processing: it still
## owns the frame state. Its parent's visibility is honoured here, so a guard the fog hides in 2D is
## hidden in 3D too.
class_name ActorBillboard3D
extends Node3D

const SHADER_PATH := "res://godot/shaders/actor_billboard3d.gdshader"
## Per layer, toward the camera, in world units. Far below one texel (1/181) and far above the depth
## buffer's resolution over the board's range.
const LAYER_EPSILON := 0.002
## Uniforms copied from the source's canvas material each frame. The shader names match, on purpose.
const MIRRORED_PARAMS: Array[String] = [
	"light_dir", "light_intensity", "ambient", "specular_strength", "saturation", "contrast",
]

const COS_ELEVATION := 0.8660254  ## cos(30°): a vertical extent projects to this fraction on screen

var _lift: float = 0.15
var _board: Node3D = null
var _source: AgentSprite = null
var _quad_mesh: QuadMesh = null
var _shader: Shader = null
## Sprite2D instance id -> {"mesh": MeshInstance3D, "mat": ShaderMaterial, "tex": Texture2D}.
var _quads: Dictionary = {}


func setup(board: Node3D, source: AgentSprite, lift: float = 0.15) -> void:
	_lift = lift
	_board = board
	_source = source
	_shader = load(SHADER_PATH)
	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2.ONE
	process_priority = 100  ## after the actor has moved this frame
	name = "Billboard_%s" % (source.get_parent().name if source.get_parent() != null else source.name)
	source.visible = false


func _exit_tree() -> void:
	if is_instance_valid(_source):
		_source.visible = true


func _process(_delta: float) -> void:
	if not is_instance_valid(_source) or not is_instance_valid(_board):
		queue_free()
		return
	var parent: Node = _source.get_parent()
	var actor_visible: bool = parent == null or (parent is CanvasItem and (parent as CanvasItem).is_visible_in_tree())
	var ppu: float = _board.call("px_per_unit")
	var cam: Basis = _board.call("camera_basis")
	var feet_2d: Vector2 = _source.global_position
	var feet_3d: Vector3 = _board.call("ground_point", feet_2d)
	var toward: Vector3 = cam.z  ## toward the viewer, along the view axis
	## A world-vertical plane facing the camera's azimuth: x is the camera's own right, y is up.
	var right: Vector3 = cam.x
	var up := Vector3.UP
	var facing: Vector3 = right.cross(up)  ## points at the viewer
	var lifted: Vector3 = feet_3d + toward * _lift
	var index: int = 0
	for node: Sprite2D in _sprite_nodes():
		var entry: Dictionary = _entry_for(node)
		var mesh: MeshInstance3D = entry["mesh"]
		var tex: Texture2D = node.texture
		var shown: bool = actor_visible and tex != null and (node == _source or node.visible)
		mesh.visible = shown
		if not shown:
			continue
		var xf: Transform2D = node.global_transform
		var size_px: Vector2 = tex.get_size() * xf.get_scale()
		var centre_2d: Vector2 = xf * (node.offset + tex.get_size() * 0.5)
		var d: Vector2 = (centre_2d - feet_2d) / ppu
		var centre: Vector3 = lifted + right * d.x - up * (d.y / COS_ELEVATION) \
			+ toward * (LAYER_EPSILON * float(index))
		mesh.global_transform = Transform3D(
			Basis(right * (size_px.x / ppu), up * (size_px.y / (ppu * COS_ELEVATION)), facing), centre)
		_mirror_material(node, entry)
		index += 1


## The body and every Sprite2D child, in draw order (a child draws after its parent).
func _sprite_nodes() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = [_source]
	for child: Node in _source.get_children():
		if child is Sprite2D:
			out.append(child as Sprite2D)
	return out


func _entry_for(node: Sprite2D) -> Dictionary:
	var key: int = node.get_instance_id()
	if _quads.has(key):
		return _quads[key]
	var mesh := MeshInstance3D.new()
	mesh.name = "Quad_%s" % node.name
	mesh.mesh = _quad_mesh
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	var entry: Dictionary = {"mesh": mesh, "mat": mat, "tex": null, "normal": null}
	_quads[key] = entry
	return entry


## Only writes what changed: this runs every frame per actor, and the light moves once a turn.
func _mirror_material(node: Sprite2D, entry: Dictionary) -> void:
	var mat: ShaderMaterial = entry["mat"]
	if entry["tex"] != node.texture:
		entry["tex"] = node.texture
		mat.set_shader_parameter("albedo_tex", node.texture)
	var src: ShaderMaterial = node.material as ShaderMaterial
	if src == null:
		return
	var normal: Variant = src.get_shader_parameter("normal_tex")
	if normal != null and entry["normal"] != normal:
		entry["normal"] = normal
		mat.set_shader_parameter("normal_tex", normal)
	for param: String in MIRRORED_PARAMS:
		var value: Variant = src.get_shader_parameter(param)
		if value != null and mat.get_shader_parameter(param) != value:
			mat.set_shader_parameter(param, value)
