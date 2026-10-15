## ClothFlaps3D — the ragged flaps a blast leaves around the hole of a cloth roof: they are thrown UP with the explosion and then fall back, ending as tabs
## that hang from the rim (ROOF_MASTER_PLAN v0.30, Director 2026-10-16: "as bordas irregulares sobem no momento da explosão, e em seguida caem").
##
## A flap is a strip of `SEGMENTS` quads hinged at one point of the hole's rim, pointing into the hole. Its pose is a function of time only (rise, fall,
## a damped bounce, then hang); ONE `ImmediateMesh` rebuilt each frame draws all of them in one call, for as long as any flap moves (a second or two). If the
## roof is let go (`follow`), each hinge rides the falling cloth (`SoftSheet3D.sample`) instead of the roof plane, and the flaps keep moving until it settles.
class_name ClothFlaps3D
extends Node3D

const SHADER_PATH := "res://godot/shaders/cloth_flap3d.gdshader"
const SEGMENTS: int = 5
const RISE_ANGLE: float = deg_to_rad(68.0)
const HANG_ANGLE: float = deg_to_rad(-78.0)

var _mesh: ImmediateMesh = ImmediateMesh.new()
var _node: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _flaps: Array = []
var _time: float = 0.0
var _sheet: SoftSheet3D = null
var _unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)


## `facade`: the cloth's facade texture (or null). `flaps`: Array of {hinge: Vector3 (GU, world), dir: Vector2 (unit, horizontal, into the hole), length, width (GU),
## delay (s), rise (s), fall (s), tone: Color (linear), burn: float 0..1 (how hot its edge glows)}.
func add_flaps(flaps: Array, facade: Texture2D) -> void:
	if _node == null:
		_mat = ShaderMaterial.new()
		_mat.shader = BoardLook.graded_shader(SHADER_PATH)
		if facade != null:
			_mat.set_shader_parameter("facade", facade)
			_mat.set_shader_parameter("has_facade", 1.0)
		_node = MeshInstance3D.new()
		_node.mesh = _mesh
		_node.material_override = _mat
		_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_node.custom_aabb = AABB(Vector3(-1000.0, -50.0, -1000.0), Vector3(2000.0, 100.0, 2000.0))
		add_child(_node)
	for f in flaps:
		var flap: Dictionary = f
		flap["t0"] = _time + float(flap["delay"])
		_flaps.append(flap)
	set_process(true)


## From now on the hinges ride `sheet` (a roof that let go); they stay on the plane they were hinged on until then.
func follow(sheet: SoftSheet3D) -> void:
	_sheet = sheet
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	var moving: bool = false
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in _flaps:
		var flap: Dictionary = f
		var age: float = _time - float(flap["t0"])
		var theta: float = _angle(flap, age)
		if age < float(flap["rise"]) + float(flap["fall"]) + 1.2:
			moving = true
		_emit(flap, theta, age)
	_mesh.surface_end()
	if _sheet != null and is_instance_valid(_sheet) and not _sheet.is_settled():
		moving = true
	if not moving:
		set_process(false)


## The lift angle of a flap `age` seconds after it was thrown: eased up, eased down past flat to hanging, with a damped bounce on the way.
func _angle(flap: Dictionary, age: float) -> float:
	if age <= 0.0:
		return 0.0
	var rise: float = float(flap["rise"])
	var fall: float = float(flap["fall"])
	if age < rise:
		var u: float = age / rise
		return RISE_ANGLE * (1.0 - (1.0 - u) * (1.0 - u))
	var u: float = clampf((age - rise) / fall, 0.0, 1.0)
	var eased: float = u * u
	var theta: float = lerpf(RISE_ANGLE, HANG_ANGLE, eased)
	if u >= 1.0:
		var after: float = age - rise - fall
		theta += 0.18 * sin(after * 14.0) * exp(-after * 4.0)
	return theta


func _emit(flap: Dictionary, theta: float, age: float) -> void:
	var hinge: Vector3 = flap["hinge"]
	if _sheet != null and is_instance_valid(_sheet):
		hinge = _sheet.sample(hinge.x, hinge.z)
	var d2: Vector2 = flap["dir"]
	var along := Vector3(d2.x, 0.0, d2.y)
	var across := Vector3(-d2.y, 0.0, d2.x)
	var length: float = float(flap["length"])
	var half: float = 0.5 * float(flap["width"])
	var tone: Color = flap["tone"]
	_heat = float(flap["burn"]) * clampf(1.0 - age / 3.0, 0.0, 1.0)
	var prev_l: Vector3 = hinge - across * half
	var prev_r: Vector3 = hinge + across * half
	var at: Vector3 = hinge
	var seg_len: float = length / float(SEGMENTS)
	for k in range(SEGMENTS):
		## The strip curls along its length (its tip lags the hinge's lift), and narrows toward the tip: a tongue, not a rectangle.
		var phi: float = theta + CURL * float(k) / float(SEGMENTS)
		at += (along * cos(phi) + Vector3.UP * sin(phi)) * seg_len
		var taper: float = half * (1.0 - 0.45 * float(k + 1) / float(SEGMENTS))
		var cur_l: Vector3 = at - across * taper
		var cur_r: Vector3 = at + across * taper
		var v0: float = float(k) / float(SEGMENTS)
		var v1: float = float(k + 1) / float(SEGMENTS)
		_vertex(prev_l, tone, v0)
		_vertex(prev_r, tone, v0)
		_vertex(cur_r, tone, v1)
		_vertex(prev_l, tone, v0)
		_vertex(cur_r, tone, v1)
		_vertex(cur_l, tone, v1)
		prev_l = cur_l
		prev_r = cur_r


## How far (radians) the strip's far end bends past its hinge's angle: negative = toward the ground, so a tab in the air and one hanging both droop at the tip.
const CURL: float = -0.6
var _heat: float = 0.0


func _vertex(p: Vector3, tone: Color, v: float) -> void:
	_mesh.surface_set_color(Color(tone.r, tone.g, tone.b, _heat * v))
	_mesh.surface_set_uv(Vector2(v, 0.0))
	_mesh.surface_set_uv2(Vector2(p.x / _unit, p.z / _unit))
	_mesh.surface_add_vertex(p)
