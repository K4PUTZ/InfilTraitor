## PropBillboard3D — a 2D prop's sprites (a body and, optionally, its ground shadow), drawn in the 3D
## board.
##
## RENDER3D R3D-4d. The sibling of `ActorBillboard3D` for objects that are not a standing figure: the
## thrown grenade, which tumbles in the screen plane and flies above its ground point, and the
## showcase props. A MIRROR again — the prop's own script keeps deciding what is shown and where.
##
## THE TWO KINDS OF QUAD, chosen per sprite by the shader its own material uses:
##  - a BODY is a quad PARALLEL TO THE CAMERA. An actor is tall and needs true depth at every height
##    (ActorBillboard3D); a grenade is small, and what it does is rotate in the screen plane, which a
##    camera-parallel quad does exactly. Its centre sits above its ground point by the flight height,
##    so it passes walls by real depth.
##  - a SHADOW (`object_ground_shadow.gdshader`) is a quad ON THE GROUND. The ground plane maps to the
##    screen affinely, so the shadow's three screen corners become three ground points and the quad
##    is exact, squash and all; walls cover it, and it never needs a lift over the floor.
##
## HIDING THE 2D. Not `visible = false`: the game uses a prop's `visible` as logic (the throw code
## hides a detonated grenade with it), so it must keep meaning that. Each sprite's material is swapped
## for `hidden_2d.gdshader` (its original is kept, and read here for the light uniforms) and put back
## when this leaves the tree — but only if no newer billboard has taken the sprite over.
class_name PropBillboard3D
extends Node3D

const BODY_SHADER := "res://godot/shaders/actor_billboard3d.gdshader"
const SHADOW_SHADER := "res://godot/shaders/prop_shadow3d.gdshader"
const HIDDEN_SHADER := "res://godot/shaders/hidden_2d.gdshader"
const SHADOW_SHADER_ID := "object_ground_shadow"
const COS_ELEVATION := 0.8660254
## A body a hair toward the camera, so the sole of a resting prop is not cut by the tilted floor.
const BODY_LIFT := 0.05
## A shadow above the floor top, in world units.
const GROUND_LIFT := 0.02
const LAYER_EPSILON := 0.002
const MIRRORED_PARAMS: Array[String] = [
	"light_dir", "light_intensity", "ambient", "specular_strength", "saturation", "contrast",
]

var _board: Node3D = null
var _source: Sprite2D = null
var _hidden: ShaderMaterial = null
var _body_mesh: QuadMesh = null
var _ground_mesh: ArrayMesh = null
var _body_shader: Shader = null
var _shadow_shader: Shader = null
## Sprite2D instance id -> {"node", "orig": Material, "shadow": bool, "mesh", "mat", "tex"}.
var _entries: Dictionary = {}


func setup(board: Node3D, source: Sprite2D) -> void:
	_board = board
	_source = source
	_body_shader = load(BODY_SHADER)
	_shadow_shader = load(SHADOW_SHADER)
	_hidden = ShaderMaterial.new()
	_hidden.shader = load(HIDDEN_SHADER)
	_body_mesh = QuadMesh.new()
	_body_mesh.size = Vector2.ONE
	_ground_mesh = _make_ground_mesh()
	process_priority = 100
	name = "PropBillboard_%s" % source.name


func _exit_tree() -> void:
	for key: int in _entries:
		var entry: Dictionary = _entries[key]
		var node: Sprite2D = entry["node"] as Sprite2D
		if is_instance_valid(node) and node.material == _hidden:
			node.material = entry["orig"]
	if is_instance_valid(_source) and _source.has_meta("prop_billboard3d") \
			and _source.get_meta("prop_billboard3d") == self:
		_source.remove_meta("prop_billboard3d")


func _process(_delta: float) -> void:
	if not is_instance_valid(_source) or not is_instance_valid(_board):
		queue_free()
		return
	var ppu: float = _board.call("px_per_unit")
	var cam: Basis = _board.call("camera_basis")
	var height_px: float = 0.0
	if _source.has_method("billboard_height_px"):
		height_px = _source.call("billboard_height_px")
	var anchor_2d: Vector2 = _source.global_position
	var ground: Vector3 = _board.call("ground_point", anchor_2d + Vector2(0.0, height_px))
	var toward: Vector3 = cam.z
	var index: int = 0
	for node: Sprite2D in _sprite_nodes():
		var entry: Dictionary = _entry_for(node)
		var mesh: MeshInstance3D = entry["mesh"]
		var tex: Texture2D = node.texture
		var shown: bool = tex != null and node.is_visible_in_tree()
		mesh.visible = shown
		if not shown:
			continue
		var xf: Transform2D = node.global_transform
		var size: Vector2 = tex.get_size()
		if entry["shadow"]:
			var top_left: Vector3 = _board.call("ground_point", xf * node.offset)
			var top_right: Vector3 = _board.call("ground_point", xf * (node.offset + Vector2(size.x, 0.0)))
			var bottom_left: Vector3 = _board.call("ground_point", xf * (node.offset + Vector2(0.0, size.y)))
			mesh.global_transform = Transform3D(
				Basis(top_right - top_left, bottom_left - top_left, Vector3.UP),
				top_left + Vector3.UP * GROUND_LIFT)
		else:
			var centre_2d: Vector2 = xf * (node.offset + size * 0.5)
			var d: Vector2 = (centre_2d - anchor_2d) / ppu
			var centre: Vector3 = ground + Vector3.UP * (height_px / (ppu * COS_ELEVATION)) \
				+ cam.x * d.x - cam.y * d.y + toward * (BODY_LIFT + LAYER_EPSILON * float(index))
			## 2D basis vectors (screen px, y down) onto the camera's plane; the quad's +Y is the
			## texture's up, hence the sign.
			var axis_x: Vector3 = (cam.x * xf.x.x - cam.y * xf.x.y) * (size.x / ppu)
			var axis_y: Vector3 = -(cam.x * xf.y.x - cam.y * xf.y.y) * (size.y / ppu)
			mesh.global_transform = Transform3D(Basis(axis_x, axis_y, cam.z), centre)
			index += 1
		_mirror_material(entry)


## The body and every Sprite2D child, in draw order.
func _sprite_nodes() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child: Node in _source.get_children():
		if child is Sprite2D and (child as Sprite2D).show_behind_parent:
			out.append(child as Sprite2D)  ## behind the body: the shadow
	out.append(_source)
	for child: Node in _source.get_children():
		if child is Sprite2D and not (child as Sprite2D).show_behind_parent:
			out.append(child as Sprite2D)
	return out


func _entry_for(node: Sprite2D) -> Dictionary:
	var key: int = node.get_instance_id()
	if _entries.has(key):
		return _entries[key]
	var orig: Material = node.material
	var shader_path: String = ""
	if orig is ShaderMaterial and (orig as ShaderMaterial).shader != null:
		shader_path = (orig as ShaderMaterial).shader.resource_path
	var is_shadow: bool = shader_path.contains(SHADOW_SHADER_ID)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _ground_mesh if is_shadow else _body_mesh
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _shadow_shader if is_shadow else _body_shader
	mesh.material_override = mat
	add_child(mesh)
	node.material = _hidden
	var entry: Dictionary = {"node": node, "orig": orig, "shadow": is_shadow,
		"mesh": mesh, "mat": mat, "tex": null, "normal": null}
	_entries[key] = entry
	return entry


func _mirror_material(entry: Dictionary) -> void:
	var node: Sprite2D = entry["node"]
	var mat: ShaderMaterial = entry["mat"]
	var src: ShaderMaterial = entry["orig"] as ShaderMaterial
	if entry["tex"] != node.texture:
		entry["tex"] = node.texture
		mat.set_shader_parameter("tex" if entry["shadow"] else "albedo_tex", node.texture)
	if src == null:
		return
	if entry["shadow"]:
		for param: String in ["blur_px", "strength"]:
			var value: Variant = src.get_shader_parameter(param)
			if value != null and mat.get_shader_parameter(param) != value:
				mat.set_shader_parameter(param, value)
		return
	var normal: Variant = src.get_shader_parameter("normal_tex")
	if normal != null and entry["normal"] != normal:
		entry["normal"] = normal
		mat.set_shader_parameter("normal_tex", normal)
	for param: String in MIRRORED_PARAMS:
		var value: Variant = src.get_shader_parameter(param)
		if value != null and mat.get_shader_parameter(param) != value:
			mat.set_shader_parameter(param, value)


## A unit square in XY (0..1, both ways) whose UV equals its position: the ground quad's basis columns
## are the shadow's top-right and bottom-left edges, so UV (0,0) is the texture's top-left.
static func _make_ground_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
