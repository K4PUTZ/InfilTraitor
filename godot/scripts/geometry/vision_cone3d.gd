## VisionCone3D — a guard's smooth vision cone, drawn on the 3D board's ground plane.
##
## RENDER3D R3D-4c. The 2D cone was painted at z −4 under everything the 2D board drew above it, so a
## wall covered it. Under `RENDER3D=1` the 2D canvas draws over the 3D board, so left in 2D the cone
## would paint across walls and over the actors. Here it is a triangle fan on the ground, a hair above
## it, depth-tested: geometry covers it, actors stand over it.
##
## ONE AUTHORITY. The polygon is the guard's own (`_draw_vision_smooth_body` — LOS cuts, fov, range,
## the fade to alpha 0 at the rim). The guard publishes it through `vision_smooth_ready` while
## `vision_3d` is on; this only re-expresses each 2D point on the ground.
class_name VisionCone3D
extends MeshInstance3D

## Above the floor top, in world units: enough to win the depth test against it, far below a texel.
const GROUND_LIFT := 0.02

var _board: Node3D = null
var _guard: Node2D = null
var _mesh: ArrayMesh = null


func setup(board: Node3D, guard: Node2D) -> void:
	_board = board
	_guard = guard
	name = "Cone_%s" % guard.name
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	guard.vision_3d = true
	guard.vision_smooth_ready.connect(_on_polygon)
	guard.refresh_vision_smooth()


func _exit_tree() -> void:
	if not is_instance_valid(_guard):
		return
	if _guard.vision_smooth_ready.is_connected(_on_polygon):
		_guard.vision_smooth_ready.disconnect(_on_polygon)
	## A reload's NEW cone has already taken over the guard; only the current owner hands it back.
	if _guard.has_meta("cone3d") and _guard.get_meta("cone3d") == self:
		_guard.vision_3d = false
		_guard.refresh_vision_smooth()


## Follows the guard's own visibility (the fog hides a guard, and his cone with him).
func _process(_delta: float) -> void:
	if not is_instance_valid(_guard) or not is_instance_valid(_board):
		queue_free()
		return
	visible = _guard.is_visible_in_tree()


func _on_polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
	if points.size() < 3 or not is_instance_valid(_board):
		return
	var origin: Vector2 = _guard.global_position
	var vertices := PackedVector3Array()
	for p: Vector2 in points:
		vertices.append((_board.call("ground_point", origin + p) as Vector3) + Vector3.UP * GROUND_LIFT)
	## The 2D polygon is a fan: point 0 is the guard, the rest run around the rim.
	var indices := PackedInt32Array()
	for i: int in range(1, points.size() - 1):
		indices.append_array(PackedInt32Array([0, i, i + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	if _mesh == null:
		_mesh = ArrayMesh.new()
		mesh = _mesh
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
