## ObjectMesh3D — a free-moving object (a thrown grenade, a spinning pickup, a probe) as a real mesh on the 3D board.
##
## RETIRE-2 of R3D-RETIRE-2D. `ACTOR` D65: static props are meshes. This replaces the `Sprite2D` props that reached the board
## through `PropBillboard3D` from baked frames: the model brings the geometry, OUR material registry the colour (D66, through
## `PropMesh3D.build_model`), and the board's cell planes the light, so a prop is lit and sooted like the walls around it.
##
## THE 2D CONTRACT IS KEPT, THE 2D NODE IS NOT. The thrown grenade's flight is authored in 2D screen space (`ThrowArcOverlay`'s
## parabola, the landing hop, the roll) and is driven by the controller each frame. Those callers keep handing this node the
## same two numbers they handed the sprite: `screen_position` (where the object is drawn, lifted off the floor by its flight) and
## `flight_px` (how far above its own ground point that is). The ground point under it is `screen_position + (0, flight_px)`;
## `Board3DLive.particle_origin()` turns the pair into the world point, height included, so nothing in the flight is re-derived.
##
## The object stands on its base at that point. It is turned about its CENTRE (`set_tumble`) and about the vertical (`yaw`), and its
## contact shadow lies on the ground under it, sharper and smaller as it nears the floor.
class_name ObjectMesh3D
extends Node3D

const SHADOW_SHADER := "res://godot/shaders/ground_overlay3d.gdshader"
## Above the floor, under every ground overlay's lift (0.01+).
const SHADOW_LIFT: float = 0.005
const SHADOW_SEGMENTS: int = 12
const COS_ELEVATION: float = 0.8660254

## Where the object is drawn, in 2D world pixels (the old sprite's `position`): its base, lifted off the floor by `flight_px`.
var screen_position: Vector2 = Vector2.ZERO:
	set(value):
		screen_position = value
		_place()
## How far above its own ground point the base is, in 2D pixels (>= 0).
var flight_px: float = 0.0:
	set(value):
		flight_px = maxf(value, 0.0)
		_place()
## Turn about the vertical axis, radians (a pickup's spin, a facing).
var yaw: float = 0.0:
	set(value):
		yaw = value
		_apply_rotation()

var _board: Node3D = null
var _prop: PropMesh3D = null
var _pivot: Node3D = null
var _shadow: MeshInstance3D = null
var _model_size: Vector3 = Vector3.ZERO
var _tumble: float = 0.0
var _tumble_axis: Vector3 = Vector3.RIGHT
var _shadow_half: float = 0.0


## Build the model and its shadow on `board`. `shadow_half_gu` is the shadow's radius on the floor, in world units (0 = none).
## Returns false (and leaves nothing half-built) when the model does not load.
func setup_object(board: Node3D, path: String, rotation_deg: Vector3, fit_size: Vector3, surface_materials: Dictionary,
		default_material: String, shadow_half_gu: float) -> bool:
	_board = board
	_pivot = Node3D.new()
	_prop = PropMesh3D.new()
	_pivot.add_child(_prop)
	var model: Dictionary = _prop.build_model(board, path, rotation_deg, fit_size, surface_materials, default_material)
	if model.is_empty():
		push_error("[ObjectMesh3D] %s did not load; the object is not drawn" % path)
		_pivot.free()
		_pivot = null
		_prop = null
		return false
	_model_size = model["size"]
	## The model stands on Y = 0; the pivot is its centre, so a tumble turns it about itself, not about its feet.
	_prop.position = Vector3(0.0, -_model_size.y * 0.5, 0.0)
	_pivot.position = Vector3(0.0, _model_size.y * 0.5, 0.0)
	add_child(_pivot)
	_shadow_half = shadow_half_gu
	if _shadow_half > 0.0:
		_shadow = MeshInstance3D.new()
		_shadow.name = "ObjectShadow"
		_shadow.mesh = ArrayMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = load(SHADOW_SHADER)
		_shadow.material_override = mat
		_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		board.add_child(_shadow)
		set_shadow(0.55, 0.0, 1.0)
	visibility_changed.connect(_sync_shadow_visibility)
	_place()
	return true


## Turn about the object's centre: `angle` radians about the horizontal `axis` (the grenade rolls about the axis
## perpendicular to its travel). Reset by `set_tumble(0.0)`.
func set_tumble(angle: float, axis: Vector3 = Vector3.RIGHT) -> void:
	_tumble = angle
	_tumble_axis = axis
	_apply_rotation()


## The horizontal axis a roll along the 2D screen direction `dir` turns about: perpendicular to the travel on the ground.
func roll_axis_for(dir: Vector2) -> Vector3:
	if _board == null or dir.length_squared() < 0.000001:
		return Vector3.RIGHT
	var origin: Vector3 = _board.call("ground_point", Vector2.ZERO)
	var ahead: Vector3 = _board.call("ground_point", dir.normalized() * 100.0) - origin
	ahead.y = 0.0
	if ahead.length_squared() < 0.000001:
		return Vector3.RIGHT
	return Vector3.UP.cross(ahead.normalized()).normalized()


## `strength` the shadow's centre alpha, `softness` 0 (a hard edge) to 1 (it fades to nothing at the rim), `scale` its radius
## as a fraction of the one given to `setup_object`.
func set_shadow(strength: float, softness: float, scale: float) -> void:
	if _shadow == null:
		return
	var half: float = _shadow_half * scale
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.append(Vector3(0.0, SHADOW_LIFT, 0.0))
	cols.append(Color(0.0, 0.0, 0.0, strength))
	for i in range(SHADOW_SEGMENTS):
		var a: float = TAU * float(i) / float(SHADOW_SEGMENTS)
		verts.append(Vector3(cos(a) * half, SHADOW_LIFT, sin(a) * half))
		cols.append(Color(0.0, 0.0, 0.0, strength * (1.0 - softness)))
	var idx := PackedInt32Array()
	for i in range(SHADOW_SEGMENTS):
		idx.append_array([0, 1 + i, 1 + (i + 1) % SHADOW_SEGMENTS])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = _shadow.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Recolour the painted surfaces (`material@paint` in the surface map) with paint `paint_id`.
func repaint(paint_id: String) -> void:
	if _prop != null:
		_prop.repaint(paint_id)


## Draw every surface with `material` instead of the registry materials (the virtual grenade's "planned" look).
func set_override_material(material: Material) -> void:
	if _prop == null:
		return
	for mi in _prop.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = material


## The object's height in world units.
func model_height() -> float:
	return _model_size.y


## The top-centre of the object in 2D world pixels (where the fireball blooms from, where a context menu hangs): `screen_position`
## raised by the model's height, vertical units carrying the camera's cos 30.
func top_world_2d() -> Vector2:
	if _board == null:
		return screen_position
	return screen_position - Vector2(0.0, _model_size.y * float(_board.call("px_per_unit")) * COS_ELEVATION)


func _place() -> void:
	if _board == null:
		return
	var ground_2d: Vector2 = screen_position + Vector2(0.0, flight_px)
	position = _board.call("particle_origin", screen_position, ground_2d)
	if _shadow != null:
		_shadow.position = _board.call("ground_point", ground_2d)


func _apply_rotation() -> void:
	if _pivot == null:
		return
	_pivot.basis = Basis(Vector3.UP, yaw) * Basis(_tumble_axis, _tumble)


func _sync_shadow_visibility() -> void:
	if _shadow != null:
		_shadow.visible = visible


func _exit_tree() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.queue_free()
