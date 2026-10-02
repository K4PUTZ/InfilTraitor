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
## `draw_set_transform()`: the overlay's local transform, applied to every point drawn after it (identity by default).
var _local: Transform2D = Transform2D.IDENTITY
## `draw_string()` calls of this redraw: `[text, local point, font size, color]`, published as `Label3D`s by `end()`.
var _labels: Array = []
var _label_nodes: Array[Label3D] = []


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
		_node.visible = _owner.is_visible_in_tree() and (_mesh.get_surface_count() > 0 or not _labels.is_empty())


## Start a redraw. `owner` supplies the 2D transform its local points are drawn in.
func begin(owner: CanvasItem) -> void:
	_verts.clear()
	_cols.clear()
	_idx.clear()
	_labels.clear()
	_local = Transform2D.IDENTITY
	_xf = owner.get_global_transform()
	_to_gu = _board.call("ground_affine")
	_origin_2d = _board.call("ground_origin")


## Publish what was drawn since `begin()`: one surface, or none.
func end() -> void:
	_mesh.clear_surfaces()
	_publish_labels()
	if _idx.is_empty():
		_node.visible = _owner == null or (_owner.is_visible_in_tree() and not _labels.is_empty())
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
	_labels.clear()


func vertices() -> PackedVector3Array:
	return _verts


func colors() -> PackedColorArray:
	return _cols


func detach() -> void:
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null
	_label_nodes.clear()


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


## `CanvasItem.draw_set_transform()`: every point drawn after this is `position + rotate(scale * point, rotation)`.
func draw_set_transform(position: Vector2 = Vector2.ZERO, rotation: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	_local = Transform2D(rotation, scale, 0.0, position)


## `CanvasItem.draw_rect()`: a filled rectangle is a quad; an outline is four lines `width` thick (1 when unset).
func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, _antialiased: bool = false) -> void:
	var a: Vector2 = rect.position
	var b: Vector2 = Vector2(rect.end.x, rect.position.y)
	var c: Vector2 = rect.end
	var d: Vector2 = Vector2(rect.position.x, rect.end.y)
	if filled:
		draw_colored_polygon(PackedVector2Array([a, b, c, d]), color)
		return
	var w: float = 1.0 if width < 0.0 else width
	draw_line(a, b, color, w)
	draw_line(b, c, color, w)
	draw_line(c, d, color, w)
	draw_line(d, a, color, w)


## `CanvasItem.draw_string()`: text cannot be tessellated into the ground mesh, so each call becomes a `Label3D` at the
## point's ground position (published by `end()`), billboarded so it reads from every view. `font` is accepted for
## signature parity: the label uses the engine's default font. A `width` / alignment is ignored (the 2D call with
## width -1 ignores them too).
func draw_string(_font: Font, pos: Vector2, text: String, _alignment: int = 0, _width: float = -1.0,
		font_size: int = 16, color: Color = Color.WHITE) -> void:
	if text.is_empty():
		return
	_labels.append([text, pos, font_size, color])


func _publish_labels() -> void:
	## One `Label3D` per string, reused across redraws: the pool only grows.
	while _label_nodes.size() < _labels.size():
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
		label.shaded = false
		label.double_sided = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_node.add_child(label)
		_label_nodes.append(label)
	## Metres per screen pixel on the ground: the affine's area scale, so the text grows with the board as 2D text did.
	var px: float = sqrt(absf(_to_gu.determinant()))
	for i: int in range(_label_nodes.size()):
		var label: Label3D = _label_nodes[i]
		if i >= _labels.size():
			label.visible = false
			continue
		var row: Array = _labels[i]
		var gu: Vector2 = _to_gu * ((_xf * (_local * (row[1] as Vector2))) - _origin_2d)
		label.text = row[0]
		label.font_size = int(row[2])
		label.pixel_size = px
		label.modulate = row[3]
		label.position = Vector3(gu.x + 0.5, _lift + 0.02, gu.y + 0.5)
		label.visible = true


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
	var gu: Vector2 = _to_gu * ((_xf * (_local * local_2d)) - _origin_2d)
	_verts.append(Vector3(gu.x + 0.5, _lift, gu.y + 0.5))
	_cols.append(color)
