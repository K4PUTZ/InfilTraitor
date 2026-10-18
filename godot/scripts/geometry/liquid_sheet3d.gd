## LiquidSheet3D — the sheet of one body of liquid (M6, `MATERIALS_MASTER_PLAN` §6): ONE mesh over the body's interior, drawn by
## `water_study3d.gdshader` in the look the liquid's controls say.
##
## Two shapes. STATIC (no plane): a flat quad, the whole rectangle wet, as the study drew it. DRIVEN (a `FluidPlane`): a grid of vertices, one per
## cell corner, whose HEIGHT is the plane's depth there (a voxel is 1/8 GU) and whose vertex alpha is the wetness (a dry cell draws nothing, the
## shore fades in over the first voxel). The plane is the turn's truth; the sheet EASES toward it every frame so a tick moves the level
## smoothly, and the look itself (waves, bubbles, flow) keeps looping in real time whether or not the game is paused.
class_name LiquidSheet3D
extends MeshInstance3D

const SHADER: Shader = preload("res://godot/shaders/water_study3d.gdshader")
const UNIT: float = 1.0 / 8.0          ## one voxel of depth in world units (GU)
const EASE_PER_SECOND: float = 2.5
const LIFT: float = 0.03              ## above the floor top, below the contact shadows and decals' own lifts
const WET_VOXELS: float = 0.5          ## the depth at which a vertex is fully opaque

const FRAMES_PER_TICK: int = 10         ## a turn's rounds are spread over about this many frames (M6 F8)
var fire: RefCounted = null           ## a `LiquidFire` of this body (or null): its burning cells are drawn as flames
var _fire_version: int = -1
var use_thread: bool = true            ## the plane's rounds run on a worker thread (dev flag FLUID_THREAD=0 puts them back on the main thread, a few a frame)
var plane: RefCounted = null           ## a FluidPlane, or null for a static sheet
var auto_tick_seconds: float = 0.0     ## dev: tick the plane by itself every N seconds of real time (0 = only when told)

var _rect: Rect2 = Rect2()             ## the interior, raw GU
var _base_y: float = 0.0
var _shown: PackedFloat32Array = PackedFloat32Array()   ## the eased depth per interior cell
var _clock: float = 0.0
var _dirty: bool = true


func setup(rect: Rect2, base_y: float, params: Dictionary, flow: Vector2, fluid_plane: RefCounted) -> void:
	_rect = rect
	_base_y = base_y
	plane = fluid_plane
	if plane != null:
		plane.threaded = use_thread
	name = "LiquidSheet3D"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for key: String in params:
		material.set_shader_parameter(key, params[key])
	material.set_shader_parameter("rect_min", rect.position)
	material.set_shader_parameter("rect_max", rect.end)
	material.set_shader_parameter("flow_dir", flow.normalized() if flow.length() > 0.0 else Vector2(0.0, 1.0))
	material_override = material
	if plane != null:
		_shown.resize((plane.cols - 2) * (plane.rows - 2))
		_shown.fill(0.0)
	_rebuild()
	set_process(plane != null)


## One turn of the liquid (the caller's TIC, or the dev auto-tick).
func _exit_tree() -> void:
	if plane != null:
		plane.finish_tick()    ## a worker must not outlive the node that owns the plane


func tick() -> void:
	if plane != null:
		plane.begin_tick()    ## the rounds run a few a frame in `_process`; the rules read the committed depths
		_dirty = true


## Skip the easing: show the plane's depths now (a capture, a loaded level).
func snap() -> void:
	if plane == null:
		return
	for i in range(_shown.size()):
		_shown[i] = _target(i)
	_rebuild()


func _process(delta: float) -> void:
	if plane == null:
		return
	if auto_tick_seconds > 0.0:
		_clock += delta
		while _clock >= auto_tick_seconds:
			_clock -= auto_tick_seconds
			tick()
	if fire != null and fire.version != _fire_version:
		_dirty = true
	if plane.has_pending():
		plane.step_rounds(maxi(int(ceil(float(plane.rounds_per_tick()) / float(FRAMES_PER_TICK))), 1))
		_dirty = true
	if not _dirty:
		return
	var step: float = clampf(delta * EASE_PER_SECOND, 0.0, 1.0)
	var moving: bool = false
	for i in range(_shown.size()):
		var target: float = _target(i)
		if absf(target - _shown[i]) > 0.002:
			_shown[i] = lerpf(_shown[i], target, step)
			moving = true
		else:
			_shown[i] = target
	_rebuild()
	_dirty = moving


func _target(i: int) -> float:
	var interior_cols: int = plane.cols - 2
	return plane.depth[plane.index(1 + i % interior_cols, 1 + i / interior_cols)]


## The fire at a vertex: the share of the four cells around it that burn (the plane's interior cell (c, r) is grid cell (c + 1, r + 1)).
func _flame_at(vc: int, vr: int) -> float:
	if fire == null:
		return 0.0
	var sum: float = 0.0
	var count: int = 0
	for dr in range(-1, 1):
		for dc in range(-1, 1):
			var c: int = vc + dc
			var r: int = vr + dr
			if c >= 0 and r >= 0 and c < plane.cols - 2 and r < plane.rows - 2:
				sum += float(fire.burning[plane.index(c + 1, r + 1)])
				count += 1
	return sum / float(maxi(count, 1))


func _rebuild() -> void:
	if fire != null:
		_fire_version = fire.version
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	if plane == null:
		for corner: Vector2 in [_rect.position, Vector2(_rect.end.x, _rect.position.y), _rect.end, Vector2(_rect.position.x, _rect.end.y)]:
			verts.append(Vector3(corner.x, _base_y, corner.y))
			colors.append(Color(0, 0, 0, 1))
		indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
	else:
		var icols: int = plane.cols - 2
		var irows: int = plane.rows - 2
		var cell: float = plane.cell_gu
		for vr in range(irows + 1):
			for vc in range(icols + 1):
				var sum: float = 0.0
				var count: int = 0
				for dr in range(-1, 1):
					for dc in range(-1, 1):
						var cc: int = vc + dc
						var rr: int = vr + dr
						if cc >= 0 and rr >= 0 and cc < icols and rr < irows:
							sum += _shown[rr * icols + cc]
							count += 1
				var level: float = sum / float(maxi(count, 1))
				verts.append(Vector3(_rect.position.x + float(vc) * cell, _base_y + level * UNIT, _rect.position.y + float(vr) * cell))
				colors.append(Color(_flame_at(vc, vr), 0.0, 0.0, clampf(level / WET_VOXELS, 0.0, 1.0)))
		for r in range(irows):
			for c in range(icols):
				var a: int = r * (icols + 1) + c
				var b: int = a + 1
				var d: int = a + icols + 1
				var e: int = d + 1
				indices.append_array(PackedInt32Array([a, b, e, a, e, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = new_mesh
