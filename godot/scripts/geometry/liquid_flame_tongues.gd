## LiquidFlameTongues — tongues of flame (labaredas) over a burning liquid (M6 F5, experiment of 2026-10-18).
##
## One `MultiMeshInstance3D` for a whole body: `PER_CELL` Y-billboarded teardrop quads for every plane cell, drawn by `liquid_flame3d.gdshader` (the shape and colour are
## the shader's, from scrolling noise). A cell's quads grow with its `LiquidFire.visual` level and collapse to nothing at 0, so a front sweeps and a put-out cell dies
## away exactly as the sheet's glow does. The instance data is rewritten as one buffer, only while something burns. PURELY VISUAL; real time.
class_name LiquidFlameTongues
extends MultiMeshInstance3D

const SHADER: Shader = preload("res://godot/shaders/liquid_flame3d.gdshader")
const PER_CELL: int = 3
const FLOATS: int = 16     ## a 3D transform (12) + custom data (4) per instance
const LIFT: float = 0.03

var fire: RefCounted = null
var _buf: PackedFloat32Array = PackedFloat32Array()
var _cells: PackedInt32Array = PackedInt32Array()     ## the plane cell of each instance, in order
var _seeds: PackedFloat32Array = PackedFloat32Array()  ## per instance: seed, width scale, height scale
var _live: bool = false


func setup(burn: RefCounted, base_y: float, flame_width: float, flame_height: float) -> void:
	fire = burn
	var plane = fire.plane
	name = "LiquidFlameTongues"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.center_offset = Vector3(0.0, 0.5, 0.0)      ## the foot is the origin
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("flame_width", flame_width)
	material.set_shader_parameter("flame_height", flame_height)
	var base: Color = fire.base_color
	material.set_shader_parameter("base_color", base)
	quad.material = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	var count: int = 0
	for r in range(1, plane.rows - 1):
		for c in range(1, plane.cols - 1):
			count += PER_CELL
	mm.instance_count = count
	multimesh = mm
	_buf.resize(count * FLOATS)
	_buf.fill(0.0)
	_cells.resize(count)
	_seeds.resize(count * 3)
	var k: int = 0
	var half: float = plane.cell_gu * 0.5
	for r in range(1, plane.rows - 1):
		for c in range(1, plane.cols - 1):
			var i: int = plane.index(c, r)
			var centre: Vector2 = fire.centre_of(i)
			for n in range(PER_CELL):
				var h: float = _hash(float(i) * 7.31 + float(n) * 3.17)
				var at := Vector2(centre.x + (_hash(h * 91.7) - 0.5) * 2.0 * half, centre.y + (_hash(h * 13.3) - 0.5) * 2.0 * half)
				var o: int = k * FLOATS
				_buf[o] = 1.0
				_buf[o + 5] = 1.0
				_buf[o + 10] = 1.0
				_buf[o + 3] = at.x
				_buf[o + 7] = base_y + LIFT
				_buf[o + 11] = at.y
				_cells[k] = i
				_seeds[k * 3] = h
				_seeds[k * 3 + 1] = 0.7 + 0.6 * _hash(h * 5.1)
				## a roofed cell's flame is capped by the headroom under the roof (a pipe's bore holds it down)
				var room_scale: float = minf(1.0, float(fire.headroom_gu[i]) / maxf(flame_height, 0.01))
				_seeds[k * 3 + 2] = (0.6 + 0.7 * _hash(h * 8.9)) * maxf(room_scale, 0.12)
				k += 1
	multimesh.buffer = _buf
	custom_aabb = AABB(Vector3(plane.origin.x, base_y - 0.1, plane.origin.y), Vector3(float(plane.cols) * plane.cell_gu, flame_height * 1.6, float(plane.rows) * plane.cell_gu))


static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)


## One frame: the buffer follows the fire's visual levels. Does nothing while nothing burns and everything is already dark.
func update_frame() -> void:
	if fire == null:
		return
	if fire.hot_cells.is_empty() and not _live:
		return
	var any: bool = false
	for k in range(_cells.size()):
		var level: float = fire.visual[_cells[k]]
		var o: int = k * FLOATS
		_buf[o + 12] = level
		_buf[o + 13] = _seeds[k * 3]
		_buf[o + 14] = _seeds[k * 3 + 1]
		_buf[o + 15] = _seeds[k * 3 + 2]
		if level > 0.0:
			any = true
	_live = any
	multimesh.buffer = _buf
