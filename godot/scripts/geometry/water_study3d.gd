## WaterStudy3D — M6 WATER STUDY (2026-10-17): ONE flat sheet over a rectangle of the floor, drawn by `water_study3d.gdshader` in the look
## a KIND picks. Dev only (flag `WATER_STUDY=<kind>`, `WATER_RAIN=<0..1>`, rain works on ANY kind: the Director's rule of 2026-10-17, every water exposed to rain gets it), nothing simulated and nothing saved: it exists so the Director can judge how
## water could READ (flat tint / stipple / surface / both) before a mechanism is chosen (`MATERIALS_MASTER_PLAN` §6).
class_name WaterStudy3D
extends RefCounted

const SHADER: Shader = preload("res://godot/shaders/water_study3d.gdshader")
## Above the floor top, below the contact shadows and decals' own lifts.
const LIFT: float = 0.03
## The looks. `waste` is the Director's pick of 2026-10-17 (stipple + surface, softened: it reads as dirty water with bacteria, so it is
## the discard / sewer water); `clean` is the same without the dots and clearer, for treated / pure water. The three others are the first
## round's looks, kept for comparison. `mode`: 0 flat tint, 1 stipple, 2 surface, 3 both (see the shader).
const KINDS: Dictionary = {
	"flat": {"mode": 0},
	"stipple": {"mode": 1},
	"surface": {"mode": 2},
	"waste": {"mode": 3},
	## Caribbean shallows: very clear, light blue-green, no bubbles; the channel shows its own depth (the curbs' shade on the water, deeper
	## blue in the middle) and the sun's caustics on the bed.
	"caribe": {"mode": 2, "bubble_amount": 0.0, "caustics": 1.0, "depth_shade": 1.0,
			"deep_color": Color(0.0, 0.52, 0.78, 0.26), "shallow_color": Color(0.3, 0.92, 0.96, 0.1), "light_color": Color(0.95, 1.0, 1.0, 1.0)},
	## Sewage: brown and murky (the bed does not show), a green scum drifting on it, big bubbles, dark specks of dirt, slow and thick.
	"esgoto": {"mode": 3, "detail_strength": 0.9, "scum": 1.0, "flow_speed": 0.14, "stipple_alive": 0.72, "oil": 1.0,
			"deep_color": Color(0.22, 0.14, 0.06, 0.93), "shallow_color": Color(0.38, 0.27, 0.12, 0.88), "light_color": Color(0.72, 0.64, 0.38, 1.0),
			"dirt_color": Color(0.1, 0.06, 0.02, 1.0), "scum_color": Color(0.24, 0.34, 0.1, 1.0)},
	"clean": {"mode": 2, "deep_color": Color(0.05, 0.3, 0.38, 0.3), "shallow_color": Color(0.3, 0.64, 0.7, 0.18), "light_color": Color(0.9, 1.0, 1.0, 1.0)},
}

var _node: MeshInstance3D = null


## `rect` in RAW GU (the board's own grid, buffer included); `level` the floor-top level; `flow` the unit direction of the water.
func attach(board: Node3D, rect: Rect2, level: int, kind: String, flow: Vector2, rain: float = 0.0) -> void:
	detach()
	if board == null or not board.has_method("ground_level"):
		push_error("[WaterStudy3D] attach: the board has no ground_level()")
		return
	if not KINDS.has(kind):
		push_error("[WaterStudy3D] unknown kind '%s' (known: %s)" % [kind, str(KINDS.keys())])
		return
	var look: Dictionary = KINDS[kind]
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
	material.set_shader_parameter("mode", int(look["mode"]))
	material.set_shader_parameter("rain", clampf(rain, 0.0, 1.0))
	for key: String in ["bubble_amount", "caustics", "depth_shade", "detail_strength", "scum", "flow_speed", "stipple_alive", "oil"]:
		if look.has(key):
			material.set_shader_parameter(key, look[key])
	for key: String in ["deep_color", "shallow_color", "light_color", "dirt_color", "scum_color"]:
		if look.has(key):
			material.set_shader_parameter(key, look[key])
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
