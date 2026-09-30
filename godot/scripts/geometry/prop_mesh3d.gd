## PropMesh3D — a static prop as a real mesh on the 3D board.
##
## RENDER3D R3D-PROPS (`ACTOR` D65: static props are meshes, destructible ones are voxels — a
## destructible prop like `crate_full` already renders through the store, rule 8, no new path here).
## Lit the board's way (`prop_mesh3d.gdshader`, promoted from R3D-SPIKE-3D's measured spike): no
## Godot light, one cell-plane fetch, kept in sync by `Board3DLive.register_prop_light_material()`.
##
## Placement uses the same voxel-grid convention `Board3DLive._emit_quad()` uses for a TOP face: one
## world unit is `GeometryCoords.VOXELS_PER_UNIT_AXIS` voxels, and a level's top sits at
## `(level + 1 - ground_level)` world-Y units. A mesh's own local origin is assumed centred
## horizontally and resting on Y=0 (its base), so it is placed directly on the level's top face with
## no extra offset.
class_name PropMesh3D
extends Node3D

const SHADER_PATH := "res://godot/shaders/prop_mesh3d.gdshader"

var _board: Node3D = null
var _mat: ShaderMaterial = null
var _extra_mats: Array[ShaderMaterial] = []
var _mesh_node: MeshInstance3D = null


## `cell` is a voxel cell (x, y); `level` is the voxel level the prop rests ON TOP of. `mesh` is
## assumed centred on its own origin (every `PrimitiveMesh` is), so `mesh_half_height` (world units)
## lifts it from resting-on-Y=0 to centred-on-Y=0.
func setup(board: Node3D, mesh: Mesh, cell: Vector2i, level: int, albedo: Color,
		mesh_half_height: float) -> void:
	_board = board
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var ground_level: int = board.call("ground_level")
	var x: float = (float(cell.x) + 0.5) * unit
	var z: float = (float(cell.y) + 0.5) * unit
	var y: float = float(level + 1 - ground_level) * unit
	_mesh_node = MeshInstance3D.new()
	_mesh_node.mesh = mesh
	_mesh_node.position = Vector3(0.0, mesh_half_height, 0.0)
	_mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	_mat.set_shader_parameter("albedo", albedo)
	_mesh_node.material_override = _mat
	add_child(_mesh_node)
	position = Vector3(x, y, z)
	board.call("register_prop_light_material", _mat)


## A real model (glTF/GLB) instead of a box: turned by `rotation_deg`, scaled uniformly to fit inside `fit_size` (world
## units), centred on the cell horizontally and standing on its base. Every surface becomes one lit material that keeps
## the colour (and texture) the model was authored with, so a pistol's grip and slide read as two colours; all of them
## are registered with the board, so the light and the soot reach them exactly as they reach the box.
func setup_model(board: Node3D, path: String, rotation_deg: Vector3, fit_size: Vector3, cell: Vector2i, level: int) -> void:
	_board = board
	var model: Dictionary = PropModelFit.fit(path, rotation_deg, fit_size)
	if not bool(model["ok"]):
		return
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var ground_level: int = board.call("ground_level")
	for part: Dictionary in model["parts"]:
		var mesh: Mesh = part["mesh"]
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.transform = part["xf"]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in range(mesh.get_surface_count()):
			var m := _lit_material_from(mesh.surface_get_material(s))
			node.set_surface_override_material(s, m)
			_extra_mats.append(m)
			board.call("register_prop_light_material", m)
		add_child(node)
	position = Vector3((float(cell.x) + 0.5) * unit, float(level + 1 - ground_level) * unit, (float(cell.y) + 0.5) * unit)


## One board-lit material carrying a source material's albedo colour and texture.
func _lit_material_from(source: Material) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH)
	var colour := Color(0.6, 0.6, 0.6)
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		colour = base.albedo_color
		if base.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", base.albedo_texture)
			m.set_shader_parameter("has_tex", 1.0)
	m.set_shader_parameter("albedo", colour)
	return m


func _exit_tree() -> void:
	if is_instance_valid(_board):
		if _mat != null:
			_board.call("unregister_prop_light_material", _mat)
		for m in _extra_mats:
			_board.call("unregister_prop_light_material", m)
