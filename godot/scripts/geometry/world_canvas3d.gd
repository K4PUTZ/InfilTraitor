## WorldCanvas3D — a 2D overlay's drawing that has HEIGHT (a tracer, a throw arc, a lamp), as world geometry on the 3D
## board.
##
## R3D-WORLD. `GroundCanvas3D` lifts what lies on the floor; it cannot place a point above it, because a 2D canvas point
## folds height into screen y and the floor beneath it is lost. The overlays that draw in the air already know that floor
## (a muzzle is above the agent's feet, an arc sample above the lerp of its two ground ends), so they hand this canvas
## the pair and it asks the board for the world point: `Board3DLive.particle_origin()`, the VFX's own rule, through the
## BASE view's basis (`lattice_basis()`), so the point is world state and stays put when the view turns.
##
## LINES are ribbons `width_px` wide (2D canvas pixels, as the 2D call took them) turned to face the LIVE camera; they are
## rebuilt when the view changes (`Board3DLive.view_changed` asks the owner to redraw). Depth-tested by default, so a
## wall hides what is behind it; `on_top` draws over everything, the way the 2D overlay did.
class_name WorldCanvas3D
extends RefCounted

const SHADER := "res://godot/shaders/ground_overlay3d.gdshader"
const CIRCLE_SEGMENTS: int = 24

var _board: Node3D = null
var _node: MeshInstance3D = null
var _mesh: ArrayMesh = null
var _owner: CanvasItem = null
var _verts := PackedVector3Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var _cam := Basis.IDENTITY
var _ppu: float = 1.0
var _xf := Transform2D.IDENTITY


func attach(board: Node3D, owner: CanvasItem, priority: int = 0, on_top: bool = false) -> void:
	if _node != null:
		return
	_board = board
	_owner = owner
	var mat := ShaderMaterial.new()
	var shader: Shader = load(SHADER)
	if on_top:
		shader = shader.duplicate()
		shader.code = shader.code.replace("render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;",
			"render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;")
	mat.shader = shader
	mat.render_priority = priority
	_mesh = ArrayMesh.new()
	_node = MeshInstance3D.new()
	_node.name = "WorldCanvas3D"
	_node.mesh = _mesh
	_node.material_override = mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_node.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	_node.visible = false
	board.add_child(_node)
	if board.has_signal("view_changed") and not board.is_connected("view_changed", _on_view_changed):
		board.connect("view_changed", _on_view_changed)
	## A hidden overlay never runs `_draw()` to clear its mesh, so its visibility is followed directly.
	if not owner.visibility_changed.is_connected(_sync_visibility):
		owner.visibility_changed.connect(_sync_visibility)


func _sync_visibility() -> void:
	if _node != null and is_instance_valid(_owner):
		_node.visible = _owner.is_visible_in_tree() and _mesh.get_surface_count() > 0


func _on_view_changed(_direction: String) -> void:
	if is_instance_valid(_owner):
		_owner.queue_redraw()


func detach() -> void:
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null


func begin() -> void:
	_verts.clear()
	_cols.clear()
	_idx.clear()
	_cam = _board.call("camera_basis")
	_ppu = _board.call("px_per_unit")
	_xf = _owner.get_global_transform() if is_instance_valid(_owner) else Transform2D.IDENTITY


func end() -> void:
	_mesh.clear_surfaces()
	if _idx.is_empty():
		_node.visible = false
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _cols
	arrays[Mesh.ARRAY_INDEX] = _idx
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_node.visible = _owner == null or _owner.is_visible_in_tree()


func clear() -> void:
	begin_empty()
	if _mesh != null:
		_mesh.clear_surfaces()
	if _node != null:
		_node.visible = false


func begin_empty() -> void:
	_verts.clear()
	_cols.clear()
	_idx.clear()


## The world point a 2D canvas point stands for, given the 2D point of the floor beneath it (both in the owner's own
## coordinates, the ones its `_draw()` uses).
func lift(point_2d: Vector2, floor_2d: Vector2) -> Vector3:
	return _board.call("particle_origin", _xf * point_2d, _xf * floor_2d)


## A ribbon from `a` to `b`, `width_px` canvas pixels wide, facing the camera.
func line(a: Vector3, b: Vector3, color: Color, width_px: float) -> void:
	var d: Vector3 = b - a
	if d.length_squared() < 1e-12:
		return
	var side: Vector3 = d.cross(_cam.z)
	if side.length_squared() < 1e-12:
		side = _cam.x
	side = side.normalized() * (maxf(width_px, 1.0) * 0.5 / _ppu)
	var base: int = _verts.size()
	_verts.append_array(PackedVector3Array([a - side, a + side, b + side, b - side]))
	for _i in range(4):
		_cols.append(color)
	_idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func polyline(points: PackedVector3Array, color: Color, width_px: float) -> void:
	for i: int in range(points.size() - 1):
		line(points[i], points[i + 1], color, width_px)


## A camera-facing disc of `radius_px` canvas pixels.
func disc(centre: Vector3, radius_px: float, color: Color) -> void:
	var r: float = radius_px / _ppu
	var base: int = _verts.size()
	_verts.append(centre)
	_cols.append(color)
	for i: int in range(CIRCLE_SEGMENTS):
		var a: float = TAU * float(i) / float(CIRCLE_SEGMENTS)
		_verts.append(centre + (_cam.x * cos(a) + _cam.y * sin(a)) * r)
		_cols.append(color)
	for i: int in range(CIRCLE_SEGMENTS):
		_idx.append_array(PackedInt32Array([base, base + 1 + i, base + 1 + (i + 1) % CIRCLE_SEGMENTS]))


## A convex polygon, as a fan.
func polygon(points: PackedVector3Array, color: Color) -> void:
	if points.size() < 3:
		return
	var base: int = _verts.size()
	for p: Vector3 in points:
		_verts.append(p)
		_cols.append(color)
	for i: int in range(1, points.size() - 1):
		_idx.append_array(PackedInt32Array([base, base + i, base + i + 1]))


## A camera-facing circle outline of `radius_px`, `width_px` thick.
func ring(centre: Vector3, radius_px: float, color: Color, width_px: float) -> void:
	var r: float = radius_px / _ppu
	var pts := PackedVector3Array()
	for i: int in range(CIRCLE_SEGMENTS + 1):
		var a: float = TAU * float(i) / float(CIRCLE_SEGMENTS)
		pts.append(centre + (_cam.x * cos(a) + _cam.y * sin(a)) * r)
	polyline(pts, color, width_px)


## `px` canvas pixels of screen HEIGHT as a world offset: a vertical extent projects to cos 30 of its length (D26).
func up(px: float) -> Vector3:
	return Vector3.UP * (px / (_ppu * 0.8660254))



## --- SCREEN MODE: a 2D drawing that has no floor of its own (a dome's outline, a star of rays) -------------------
##
## The overlay keeps drawing in 2D canvas pixels around an anchor; each point is placed on the LIVE camera's plane through
## the anchor's world point, at its pixel offset, so it lands on the very pixel the 2D canvas would have drawn it at in
## view N and on the right one in every other view. What the overlay derives from grid directions must then be derived
## with the view's axes (`screen_axes()`), or the shape is N's shape seen from elsewhere.

var _screen_anchor3 := Vector3.ZERO
var _screen_anchor2 := Vector2.ZERO


func begin_screen(anchor3: Vector3, anchor2: Vector2) -> void:
	begin()
	_screen_anchor3 = anchor3
	_screen_anchor2 = anchor2


## The screen pixels one world unit along grid x and along grid y move by, in the live view: `IsoProjection.AXIS_X` /
## `AXIS_Y` in view N, turned with the camera in the others.
func screen_axes() -> Array[Vector2]:
	var cam: Basis = _board.call("camera_basis")
	var ppu: float = _board.call("px_per_unit")
	return [Vector2(cam.x.x, -cam.y.x) * ppu, Vector2(cam.x.z, -cam.y.z) * ppu]


func _sp(p: Vector2) -> Vector3:
	var d: Vector2 = p - _screen_anchor2
	return _screen_anchor3 + _cam.x * (d.x / _ppu) - _cam.y * (d.y / _ppu)


func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var base: int = _verts.size()
	for p: Vector2 in points:
		_verts.append(_sp(p))
		_cols.append(color)
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	if tri.is_empty():
		for i: int in range(1, points.size() - 1):
			_idx.append_array(PackedInt32Array([base, base + i, base + i + 1]))
		return
	for i: int in tri:
		_idx.append(base + i)


func draw_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	line(_sp(from), _sp(to), color, width)


func draw_polyline(points: PackedVector2Array, color: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	for i: int in range(points.size() - 1):
		line(_sp(points[i]), _sp(points[i + 1]), color, width)
