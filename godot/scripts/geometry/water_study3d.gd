## WaterStudy3D — M6 WATER STUDY (2026-10-17): ONE flat sheet over a rectangle of the floor, drawn by `water_study3d.gdshader` in the look
## the `mode` picks. Dev only (flag `WATER_STUDY=0..3`), nothing simulated and nothing saved: it exists so the Director can judge how
## water could READ (flat tint / stipple / surface / both) before a mechanism is chosen (`MATERIALS_MASTER_PLAN` §6).
class_name WaterStudy3D
extends RefCounted

const SHADER: Shader = preload("res://godot/shaders/water_study3d.gdshader")
## Above the floor top, below the contact shadows and decals' own lifts.
const LIFT: float = 0.03

var _node: MeshInstance3D = null


## `rect` in RAW GU (the board's own grid, buffer included); `level` the floor-top level; `flow` the unit direction of the water.
func attach(board: Node3D, rect: Rect2, level: int, mode: int, flow: Vector2) -> void:
	detach()
	if board == null or not board.has_method("ground_level"):
		push_error("[WaterStudy3D] attach: the board has no ground_level()")
		return
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var y: float = float(level + 1 - int(board.call("ground_level"))) * unit + LIFT
	var verts := PackedVector3Array([
		Vector3(rect.position.x, y, rect.position.y), Vector3(rect.end.x, y, rect.position.y),
		Vector3(rect.end.x, y, rect.end.y), Vector3(rect.position.x, y, rect.end.y)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("mode", clampi(mode, 0, 3))
	material.set_shader_parameter("rect_min", rect.position)
	material.set_shader_parameter("rect_max", rect.end)
	material.set_shader_parameter("flow_dir", flow.normalized())
	_node = MeshInstance3D.new()
	_node.name = "WaterStudy3D"
	_node.mesh = mesh
	_node.material_override = material
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board.add_child(_node)


func detach() -> void:
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null
