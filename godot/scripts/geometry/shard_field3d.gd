## ShardField3D — the glass rain's shards on the 3D board, in ONE draw call, depth-tested.
##
## RENDER3D R3D-4e-4. The 3D twin of `ShardField`: a MultiMesh of quads, each carrying its shape's atlas
## cell in the instance custom data, so 3000 shards are one draw call. Unlike the other 3D fields it
## takes a WORLD position per shard, not an anchor + a 2D displacement: a shard travels between two real
## 3D points (its pane and its landing), and interpolating them in 3D puts it at the right depth all the
## way, where carrying a 2D displacement would drift a scattered landing off the floor it lands on.
##
## `custom_aabb` is set for the reason `CircleField3D`'s header gives: culling bounds come from the base
## mesh, so without the box every shard far from the origin is culled.
class_name ShardField3D
extends RefCounted

const ParticleMathRef = preload("res://godot/scripts/geometry/particle_math.gd")
const ShardShapes = preload("res://godot/scripts/systems/destruction/glass_shard_shapes.gd")
const SHADER_PATH := "res://godot/shaders/glass_shard_field3d.gdshader"
## 12 floats of TRANSFORM_3D + 4 of colour + 4 of custom data.
const FLOATS_PER_INSTANCE: int = 20

static var _atlas: ImageTexture = null

var _board: Node3D = null
var _node: MultiMeshInstance3D = null
var _mm: MultiMesh = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0
var _cam: Basis = Basis.IDENTITY
var _ppu: float = 1.0


static func atlas_texture() -> ImageTexture:
	if _atlas == null:
		_atlas = ImageTexture.create_from_image(ShardShapes.atlas_image())
	return _atlas


func attach(parent: Node3D, priority: int = 0) -> void:
	if _node != null:
		return
	_board = parent
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)  ## half-extents 1
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = quad
	_mm.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("atlas", atlas_texture())
	mat.set_shader_parameter("atlas_cells", float(ShardShapes.ids().size()))
	mat.render_priority = priority
	_node = MultiMeshInstance3D.new()
	_node.name = "ShardField3D"
	_node.multimesh = _mm
	_node.material_override = mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(_node)


## The field lives on the board, but its owner (one rain event) does not: the owner frees it when it goes.
func detach() -> void:
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null
	_mm = null


func begin_on_board(capacity: int) -> void:
	_count = 0
	_cam = _board.call("camera_basis")
	_ppu = _board.call("px_per_unit")
	var need: int = capacity * FLOATS_PER_INSTANCE
	if _buf.size() < need:
		_buf.resize(need)


## One shard at the world position `pos`. `size_px`, `rot`, `flip`, `flop` are the 2D field's own: the
## basis is the 2D rotation/flip of a `size_px` square, carried into the camera's plane.
func push(pos: Vector3, size_px: float, rot: float, shape_index: int, color: Color,
		flip: bool = false, flop: bool = false) -> void:
	var sx: float = -size_px if flip else size_px
	var sy: float = -size_px if flop else size_px
	var c: float = cos(rot)
	var s: float = sin(rot)
	## The 2D field's columns, halved (its quad spans ±0.5, this one ±1).
	var b: Basis = ParticleMathRef.quad_basis(
		Vector2(c * sx, s * sx) * 0.5, Vector2(-s * sy, c * sy) * 0.5, _cam, _ppu)
	var o: int = _count * FLOATS_PER_INSTANCE
	_buf[o] = b.x.x
	_buf[o + 1] = b.y.x
	_buf[o + 2] = b.z.x
	_buf[o + 3] = pos.x
	_buf[o + 4] = b.x.y
	_buf[o + 5] = b.y.y
	_buf[o + 6] = b.z.y
	_buf[o + 7] = pos.y
	_buf[o + 8] = b.x.z
	_buf[o + 9] = b.y.z
	_buf[o + 10] = b.z.z
	_buf[o + 11] = pos.z
	_buf[o + 12] = color.r
	_buf[o + 13] = color.g
	_buf[o + 14] = color.b
	_buf[o + 15] = color.a
	_buf[o + 16] = float(shape_index)
	_buf[o + 17] = 0.0
	_buf[o + 18] = 0.0
	_buf[o + 19] = 0.0
	_count += 1


func flush() -> void:
	if _mm == null:
		return
	if _count == 0:
		_mm.instance_count = 0
		return
	_mm.instance_count = _count
	_mm.buffer = _buf.slice(0, _count * FLOATS_PER_INSTANCE)


func live_count() -> int:
	return 0 if _mm == null else _mm.instance_count


func clear() -> void:
	_count = 0
	if _mm != null:
		_mm.instance_count = 0
