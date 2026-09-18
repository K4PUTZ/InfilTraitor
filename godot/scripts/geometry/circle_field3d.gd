## CircleField3D — many camera-facing discs on the 3D board, in ONE draw call, depth-tested.
##
## RENDER3D R3D-4e-1. The 3D twin of `CircleField` (PERF-P7b): the same clients, the same
## begin/push/flush/clear frame, but each disc has a WORLD position (`ParticleMath`), so a wall in front
## of it hides it. The disc mesh is one quad built once; a frame ships only a transform and a colour
## per instance, exactly as the 2D field does with its circle fan — the cost P7b measured (CPU
## submission per vertex) stays solved, and a quad is four vertices where the fan was 192.
##
## ⚠️ `custom_aabb` IS SET, AND FOR THE SAME REASON AS THE 2D FIELD. Godot derives a MultiMesh's
## culling bounds from its BASE MESH, here a 2×2 quad at the origin; the instances carry the real
## positions and are not in that box, so without this box every disc far from the origin is culled and
## whole effects vanish silently (P7b lost particles that way for weeks).
##
## ⚠️ DRAW ORDER. Instances draw in push order (as the 2D field's do), which under MIX blending IS part
## of the picture. Between FIELDS the order is the node's distance to the camera, which is not what
## the 2D z-order meant, so each field takes a `priority` (material render priority) that stands in
## for it.
class_name CircleField3D
extends RefCounted

const ParticleMathRef = preload("res://godot/scripts/geometry/particle_math.gd")
const SHADER_MIX := "res://godot/shaders/particle_disc3d.gdshader"
const SHADER_ADD := "res://godot/shaders/particle_disc3d_add.gdshader"
## 12 floats of TRANSFORM_3D (three rows of four) + 4 of colour, the layout `MultiMesh.buffer`
## expects with `use_colors` on.
const FLOATS_PER_INSTANCE: int = 16

var _board: Node3D = null
var _node: MultiMeshInstance3D = null
var _mm: MultiMesh = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0
var _cam: Basis = Basis.IDENTITY
var _ppu: float = 1.0


func attach(parent: Node3D, additive: bool, feather: float = 0.0, priority: int = 0) -> void:
	if _node != null:
		return
	_board = parent
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)  ## a unit-radius disc: an instance's scale IS its radius
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_ADD if additive else SHADER_MIX)
	mat.set_shader_parameter("feather", clampf(feather, 0.0, 1.0))
	mat.render_priority = priority
	_node = MultiMeshInstance3D.new()
	_node.name = "CircleField3D"
	_node.multimesh = _mm
	_node.material_override = mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(_node)


## Start a frame. `cam` and `px_per_unit` are the board camera's, read once here rather than per disc.
func begin(capacity: int, cam: Basis, px_per_unit: float) -> void:
	_count = 0
	_cam = cam
	_ppu = px_per_unit
	var need: int = capacity * FLOATS_PER_INSTANCE
	if _buf.size() < need:
		_buf.resize(need)


## Start a frame on the board this field was attached to: its camera and scale, read once.
func begin_on_board(capacity: int) -> void:
	begin(capacity, _board.call("camera_basis"), _board.call("px_per_unit"))


## One disc. `anchor_3d`/`anchor_2d` are where the particle was emitted (3D, and the 2D point that
## projects to); `pos_2d` and `radius_px` are its ordinary 2D simulation state. No allocation.
func push(anchor_3d: Vector3, anchor_2d: Vector2, pos_2d: Vector2, radius_px: float, color: Color) -> void:
	var p: Vector3 = ParticleMathRef.to_world(anchor_3d, anchor_2d, pos_2d, _cam, _ppu)
	var b: Basis = ParticleMathRef.disc_basis(_cam, radius_px, _ppu)
	var o: int = _count * FLOATS_PER_INSTANCE
	_buf[o] = b.x.x
	_buf[o + 1] = b.y.x
	_buf[o + 2] = b.z.x
	_buf[o + 3] = p.x
	_buf[o + 4] = b.x.y
	_buf[o + 5] = b.y.y
	_buf[o + 6] = b.z.y
	_buf[o + 7] = p.y
	_buf[o + 8] = b.x.z
	_buf[o + 9] = b.y.z
	_buf[o + 10] = b.z.z
	_buf[o + 11] = p.z
	_buf[o + 12] = color.r
	_buf[o + 13] = color.g
	_buf[o + 14] = color.b
	_buf[o + 15] = color.a
	_count += 1


## Publish the frame: ONE engine call for every disc pushed. `instance_count` first, and the buffer
## sliced to exactly the live instances — the same rule the 2D field learned.
func flush() -> void:
	if _mm == null:
		return
	if _count == 0:
		_mm.instance_count = 0
		return
	_mm.instance_count = _count
	_mm.buffer = _buf.slice(0, _count * FLOATS_PER_INSTANCE)


func clear() -> void:
	_count = 0
	if _mm != null:
		_mm.instance_count = 0


func live_count() -> int:
	return _count


## For tests: the raw instance buffer of the frame just pushed.
func buffer() -> PackedFloat32Array:
	return _buf
