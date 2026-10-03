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
## The materials whose surface was declared `material@paint`: the ones `repaint()` recolours.
var _painted_mats: Array[ShaderMaterial] = []
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
	_mat.shader = BoardLook.graded_shader(SHADER_PATH)
	_mat.set_shader_parameter("albedo", albedo)
	_mesh_node.material_override = _mat
	add_child(_mesh_node)
	position = Vector3(x, y, z)
	board.call("register_prop_light_material", _mat)


## A real model (glTF/GLB) instead of a box: turned by `rotation_deg`, scaled uniformly to fit inside `fit_size` (world
## units), centred on the cell horizontally and standing on its base. COLOUR AND DETAIL COME FROM OUR MATERIAL REGISTRY, never from
## the model (`ACTOR` D66): each surface is looked up by the name of the material it was authored with in `surface_materials`
## (falling back to `default_material`), and becomes one board-lit material carrying that registry material's colour and, when it
## has one, its facade. A pistol's grip and slide read as two materials; all of them are registered with the board, so the light and
## the soot reach them exactly as they reach the box.
func setup_model(board: Node3D, path: String, rotation_deg: Vector3, fit_size: Vector3, cell: Vector2i, level: int,
		surface_materials: Dictionary = {}, default_material: String = "generic") -> void:
	if build_model(board, path, rotation_deg, fit_size, surface_materials, default_material).is_empty():
		return
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var ground_level: int = board.call("ground_level")
	position = Vector3((float(cell.x) + 0.5) * unit, float(level + 1 - ground_level) * unit, (float(cell.y) + 0.5) * unit)


## The model's parts and board-lit materials, NOT placed: a node that moves freely (a thrown grenade, a spinning pickup) positions
## itself. Returns the fitted model (`size`, standing on local Y = 0, centred on X/Z), or an empty dictionary when it did not load.
func build_model(board: Node3D, path: String, rotation_deg: Vector3, fit_size: Vector3,
		surface_materials: Dictionary = {}, default_material: String = "generic") -> Dictionary:
	_board = board
	var model: Dictionary = PropModelFit.fit(path, rotation_deg, fit_size)
	if not bool(model["ok"]):
		return {}
	var surface_names: Array = model["surfaces"]
	var surface_index: int = 0
	for part: Dictionary in model["parts"]:
		var mesh: Mesh = part["mesh"]
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.transform = part["xf"]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in range(mesh.get_surface_count()):
			var authored: String = String(surface_names[surface_index]) if surface_index < surface_names.size() else ""
			surface_index += 1
			var spec: Dictionary = PaintPalette.split_spec(String(surface_materials.get(authored, default_material)))
			var m := _material_for(String(spec["material"]))
			if not String(spec["paint"]).is_empty():
				m.set_shader_parameter("albedo", PaintPalette.color_of(String(spec["paint"])))
				_painted_mats.append(m)
			node.set_surface_override_material(s, m)
			_extra_mats.append(m)
			board.call("register_prop_light_material", m)
		add_child(node)
	return model


## Recolour every painted surface (`material@paint`) with paint `paint_id`: one shader parameter write each.
func repaint(paint_id: String) -> void:
	var colour: Color = PaintPalette.color_of(paint_id)
	for m in _painted_mats:
		m.set_shader_parameter("albedo", colour)


## One board-lit material for a registry material id (through its fallback chain): its colour, and its facade when it has one.
func _material_for(material_id: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BoardLook.graded_shader(SHADER_PATH)
	## Not the bare `Registries` identifier: a script that names an autoload does not compile under a `--script` selftest.
	var registries: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Registries")
	var definition = registries.get_material_registry().resolve(material_id) if registries != null else null
	m.set_shader_parameter("albedo", definition.base_color if definition != null else Color(0.55, 0.55, 0.55))
	if definition != null and definition.has_facade:
		var facade: Texture2D = _board.call("material_facade_texture", definition.id)
		if facade != null:
			m.set_shader_parameter("facade", facade)
			m.set_shader_parameter("has_facade", 1.0)
	return m


func _exit_tree() -> void:
	if is_instance_valid(_board):
		if _mat != null:
			_board.call("unregister_prop_light_material", _mat)
		for m in _extra_mats:
			_board.call("unregister_prop_light_material", m)
