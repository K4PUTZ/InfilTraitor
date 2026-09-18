## GroundCanvas3D — a 2D overlay's flat drawing, re-issued on the 3D board's ground plane.
##
## RENDER3D R3D-5b. The ground-plane gameplay overlays (movement range, path preview, the selection
## diamond, ...) draw in 2D canvas pixels on top of everything, so under a 3D board they paint over the
## actors and the props (the Director saw the movement outline cut the agent's hat and a grenade). This
## keeps each overlay's own drawing code and changes only WHERE it lands.
##
## HOW: it has the four `CanvasItem` calls those overlays use — `draw_colored_polygon`, `draw_line`,
## `draw_polyline`, `draw_circle` — so an overlay draws into it exactly as it draws into itself
## (`var c = _ground if _ground != null else self`). Each call is tessellated in 2D (a line becomes a
## quad `width` px thick, measured on SCREEN, as the 2D line was), every vertex is carried onto the
## ground plane by the board's own 2D→ground affine, and one `ArrayMesh` per redraw is published.
##
## WHY THE LOOK DOES NOT CHANGE: the ground plane maps to the screen affinely, so a vertex placed on the
## ground from a 2D point projects back to that very pixel. What changes is depth: a tile behind a wall
## is hidden by it, and the agent's billboard, which stands in front of the floor, covers the tile under
## his feet. `ground_canvas3d_selftest` proves the pixel identity through the real camera.
##
## LAYERING. 2D `z_index` decided which overlay sat over which; here `priority` (material render
## priority) does, and each canvas sits at its own `lift` above the floor so coplanar overlays never
## z-fight the floor or each other.
class_name GroundCanvas3D
extends RefCounted

const SHADER_MIX := "res://godot/shaders/ground_overlay3d.gdshader"
const SHADER_MUL := "res://godot/shaders/ground_overlay3d_mul.gdshader"
const CIRCLE_SEGMENTS: int = 48

var _board: Node3D = null
var _node: MeshInstance3D = null
var _mesh: ArrayMesh = null
var _verts: PackedVector3Array = PackedVector3Array()
var _cols: PackedColorArray = PackedColorArray()
var _idx: PackedInt32Array = PackedInt32Array()
var _xf: Transform2D = Transform2D.IDENTITY
var _to_gu: Transform2D = Transform2D.IDENTITY
var _origin_2d: Vector2 = Vector2.ZERO
var _lift: float = 0.01
var _owner: CanvasItem = null


## `multiply` selects the MUL blend (TileOverlay's shadows and cones).
func attach(board: Node3D, priority: int, lift: float, multiply: bool = false) -> void:
	if _node != null:
		return
	_board = board
	_lift = lift
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_MUL if multiply else SHADER_MIX)
	mat.render_priority = priority
	_mesh = ArrayMesh.new()
	_node = MeshInstance3D.new()
	_node.name = "GroundCanvas3D"
	_node.mesh = _mesh
	_node.material_override = mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_node.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	_node.visible = false
	board.add_child(_node)


## Follow the 2D overlay's own visibility: a hidden overlay is not drawn, so its `_draw()` never runs to
## clear the mesh, and the last frame's geometry would stay on the board.
func follow_visibility_of(owner: CanvasItem) -> void:
	_owner = owner
	if not owner.visibility_changed.is_connected(_sync_visibility):
		owner.visibility_changed.connect(_sync_visibility)


func _sync_visibility() -> void:
	if _node != null and is_instance_valid(_owner):
		_node.visible = _owner.is_visible_in_tree() and _mesh.get_surface_count() > 0


## Start a redraw. `owner` supplies the 2D transform its local points are drawn in.
func begin(owner: CanvasItem) -> void:
	_verts.clear()
	_cols.clear()
	_idx.clear()
	_xf = owner.get_global_transform()
	_to_gu = _board.call("ground_affine")
	_origin_2d = _board.call("ground_origin")


## Publish what was drawn since `begin()`: one surface, or none.
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


## Draw nothing: an overlay's early-out path (no cells, nothing selected).
func clear() -> void:
	begin_empty()
	end()


func begin_empty() -> void:
	_verts.clear()
	_cols.clear()
	_idx.clear()


func vertices() -> PackedVector3Array:
	return _verts


func colors() -> PackedColorArray:
	return _cols


func detach() -> void:
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null


## --- the CanvasItem calls the overlays use -----------------------------------------------------

func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var base: int = _verts.size()
	for p: Vector2 in points:
		_add_vertex(p, color)
	if points.size() == 3 or points.size() == 4:
		## A triangle or a convex quad (every diamond): a fan, no triangulation needed.
		for i: int in range(1, points.size() - 1):
			_idx.append_array(PackedInt32Array([base, base + i, base + i + 1]))
		return
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	for i: int in tri:
		_idx.append(base + i)


## The per-vertex-colour polygon (the fog's feathered diamonds): each vertex carries its own colour, and
## the GPU interpolates it across the triangle exactly as the 2D canvas did.
func draw_polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
	if points.size() < 3 or colors.size() != points.size():
		return
	var base: int = _verts.size()
	for i: int in range(points.size()):
		_add_vertex(points[i], colors[i])
	if points.size() <= 4:
		for i: int in range(1, points.size() - 1):
			_idx.append_array(PackedInt32Array([base, base + i, base + i + 1]))
		return
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	for i: int in tri:
		_idx.append(base + i)


## `antialiased` is accepted for signature parity and ignored.
func draw_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0, _antialiased: bool = false) -> void:
	var d: Vector2 = to - from
	if d.length_squared() < 1e-9:
		return
	var half: Vector2 = Vector2(-d.y, d.x).normalized() * (maxf(width, 1.0) * 0.5)
	var base: int = _verts.size()
	_add_vertex(from - half, color)
	_add_vertex(from + half, color)
	_add_vertex(to + half, color)
	_add_vertex(to - half, color)
	_idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func draw_polyline(points: PackedVector2Array, color: Color, width: float = 1.0, antialiased: bool = false) -> void:
	for i: int in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, width, antialiased)


func draw_circle(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in range(CIRCLE_SEGMENTS):
		var a: float = TAU * float(i) / float(CIRCLE_SEGMENTS)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	var base: int = _verts.size()
	_add_vertex(center, color)
	for p: Vector2 in pts:
		_add_vertex(p, color)
	for i: int in range(CIRCLE_SEGMENTS):
		_idx.append_array(PackedInt32Array([base, base + 1 + i, base + 1 + (i + 1) % CIRCLE_SEGMENTS]))


func _add_vertex(local_2d: Vector2, color: Color) -> void:
	var gu: Vector2 = _to_gu * ((_xf * local_2d) - _origin_2d)
	_verts.append(Vector3(gu.x + 0.5, _lift, gu.y + 0.5))
	_cols.append(color)
