## QuadField3D — many camera-facing rectangles on the 3D board, in ONE draw call, depth-tested.
##
## RENDER3D R3D-4e-3. The base of `CircleField3D` (discs) and the field for everything the VFX draw as a
## line or a polygon: spark and shrapnel streaks, rotated debris chips. A rectangle is a centre and two
## half-extent vectors in 2D SCREEN space; `ParticleMath` carries all three into the world, so a line is
## a thin rectangle and a chip is a rotated one, with no per-shape code.
##
## Everything `CircleField3D`'s header says holds here: one quad built once, only a transform and a
## colour per instance per frame, `custom_aabb` set (a MultiMesh's bounds come from its base mesh, and
## without the box every instance far from the origin is culled), instances draw in push order, and
## `priority` stands in for the 2D z-order between fields.
class_name QuadField3D
extends RefCounted

const ParticleMathRef = preload("res://godot/scripts/geometry/particle_math.gd")
const SHADER_RECT := "res://godot/shaders/particle_quad3d.gdshader"
## 12 floats of TRANSFORM_3D (three rows of four) + 4 of colour.
const FLOATS_PER_INSTANCE: int = 16

var _board: Node3D = null
var _node: MultiMeshInstance3D = null
var _mm: MultiMesh = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0
var _cam: Basis = Basis.IDENTITY
var _ppu: float = 1.0


## Solid rectangles.
func attach_rect(parent: Node3D, priority: int = 0) -> void:
	_attach_shader(parent, SHADER_RECT, -1.0, priority)


## `feather` < 0 means the shader has no such uniform.
func _attach_shader(parent: Node3D, shader_path: String, feather: float, priority: int) -> void:
	if _node != null:
		return
	_board = parent
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)  ## half-extents 1: an instance's basis IS its half-extents
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	if feather >= 0.0:
		mat.set_shader_parameter("feather", clampf(feather, 0.0, 1.0))
	mat.render_priority = priority
	_node = MultiMeshInstance3D.new()
	_node.name = "QuadField3D"
	_node.multimesh = _mm
	_node.material_override = mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_node.visible = false  ## shown by the first flush() that has something to draw
	parent.add_child(_node)


## Start a frame. `cam` and `px_per_unit` are the board camera's, read once here rather than per quad.
func begin(capacity: int, cam: Basis, px_per_unit: float) -> void:
	_count = 0
	_cam = cam
	_ppu = px_per_unit
	var need: int = capacity * FLOATS_PER_INSTANCE
	if _buf.size() < need:
		_buf.resize(need)


## Start a frame on the board this field was attached to.
func begin_on_board(capacity: int) -> void:
	begin(capacity, _board.call("camera_basis"), _board.call("px_per_unit"))


## One rectangle centred at the particle position `pos_2d`, with half-extents `ax_2d` and `ay_2d` (2D
## screen vectors). No allocation.
func push_axes(anchor_3d: Vector3, anchor_2d: Vector2, pos_2d: Vector2,
		ax_2d: Vector2, ay_2d: Vector2, color: Color) -> void:
	_write(ParticleMathRef.quad_basis(ax_2d, ay_2d, _cam, _ppu),
		ParticleMathRef.to_world(anchor_3d, anchor_2d, pos_2d, _cam, _ppu), color)


## A straight line of `width_px` from `p0_2d` to `p1_2d` — the 2D `draw_line`, as a thin rectangle.
## A zero-length line is a square of the line's width (the dot a resting spark draws).
func push_line(anchor_3d: Vector3, anchor_2d: Vector2, p0_2d: Vector2, p1_2d: Vector2,
		width_px: float, color: Color) -> void:
	var half: Vector2 = (p1_2d - p0_2d) * 0.5
	var half_w: float = width_px * 0.5
	var ay: Vector2
	if half.length_squared() < 1e-6:
		half = Vector2(half_w, 0.0)
		ay = Vector2(0.0, half_w)
	else:
		ay = Vector2(-half.y, half.x).normalized() * half_w
	push_axes(anchor_3d, anchor_2d, (p0_2d + p1_2d) * 0.5, half, ay, color)


func _write(b: Basis, p: Vector3, color: Color) -> void:
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


## Publish the frame: ONE engine call for every quad pushed. `instance_count` first, and the buffer
## sliced to exactly the live instances.
func flush() -> void:
	if _mm == null:
		return
	## An empty field is HIDDEN, not just empty: measured on the Moto, each idle MultiMesh with zero
	## instances still cost a draw call (+6 draws across the VFX fields).
	_node.visible = _count > 0
	if _count == 0:
		_mm.instance_count = 0
		return
	_mm.instance_count = _count
	_mm.buffer = _buf.slice(0, _count * FLOATS_PER_INSTANCE)


func clear() -> void:
	_count = 0
	if _mm != null:
		_mm.instance_count = 0
		_node.visible = false


func live_count() -> int:
	return _count


## For tests: the raw instance buffer of the frame just pushed.
func buffer() -> PackedFloat32Array:
	return _buf
