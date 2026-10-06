## GroundTransitions3D — the feathered border between two organic ground materials (R3D-SURFACES transitions, 2026-10-06).
##
## The floor of a map is a grid of GUs, and each GU wears one material, so where grass meets dirt the eye sees a ruler-straight line. For
## every floor GU that touches (edge or corner) a GU of a DIFFERENT organic ground, this puts one flat quad over it that wears the
## neighbour's photographic plane with an alpha feathered by `ground_transition3d.gdshader`: 0.5 on the shared edge, 0 one band-width
## away, the iso-line moved in and out by a world-space noise. The neighbour does the same with this GU's photo, so both sides show the
## same mix at the edge and no priority between materials is needed.
##
## WHICH pairs: both materials declare a `photo` floor (`MaterialDef.surface_floor`), i.e. organic ground. A human material
## (concrete, tile) keeps today's hard GU edge; a regular, right-angled transition for those is the same mechanism with no noise and
## is not built yet. An undeclared GU (the "earth" sentinel) is not a target.
##
## COSMETIC, like `GroundDecals3D`: the map declares it, nothing saves it, and a quad whose GU lost any floor-top voxel ends
## (`refresh()`, from `Room.bump_world_revision()`), so a crater never wears a feather floating over it.
class_name GroundTransitions3D
extends RefCounted

const SHADER_PATH: String = "res://godot/shaders/ground_transition3d.gdshader"
## Band width on each side of the shared edge, in GU (Director 2026-10-06: one GU of each material, two in all).
static var WIDTH_GU: float = 1.0
## How far the world noise moves the iso-line, as a fraction of the band, and the noise's period in GU.
static var NOISE_AMOUNT: float = 0.35
static var NOISE_PERIOD_GU: float = 2.5
const LIFT: float = 0.012
const PRIORITY: int = 1
const NOISE_SIZE: int = 256
const NOISE_SEED: int = 7

## Bit of each neighbour in the vertex flags the shader reads: W, E, N, S, NW, NE, SW, SE.
const NEIGHBOURS: Array = [
	[Vector2i(-1, 0), 1], [Vector2i(1, 0), 2], [Vector2i(0, -1), 4], [Vector2i(0, 1), 8],
	[Vector2i(-1, -1), 16], [Vector2i(1, -1), 32], [Vector2i(-1, 1), 64], [Vector2i(1, 1), 128],
]

var _board: Node3D = null
var _level: int = 0
var _nodes: Dictionary = {}      ## target material -> MeshInstance3D
var _materials: Dictionary = {}  ## target material -> ShaderMaterial
var _quads: Dictionary = {}      ## Vector3i(gx, gy, index of target) -> {"cell", "target", "flags"}
var _targets: Array = []         ## the target material of each index used in a quad key
var _noise_tex: ImageTexture = null


## `gu_material` is the floor material of every declared GU (raw GU coordinates, ring included); `is_organic` answers whether a
## material takes part (`Callable(String) -> bool`). `level` is the floor-top level the quads lie on.
func attach(board: Node3D, gu_material: Dictionary, is_organic: Callable, level: int) -> void:
	detach()
	_board = board
	_level = level
	var by_target: Dictionary = {}   ## target -> Array of quad dictionaries
	for cell: Vector2i in gu_material:
		var own: String = gu_material[cell]
		if own == "" or not is_organic.call(own):
			continue
		var flags_of: Dictionary = {}  ## neighbour material -> bits
		for nb: Array in NEIGHBOURS:
			var other: String = String(gu_material.get(cell + (nb[0] as Vector2i), ""))
			if other == "" or other == own or not is_organic.call(other):
				continue
			flags_of[other] = int(flags_of.get(other, 0)) | int(nb[1])
		for target: String in flags_of:
			if not by_target.has(target):
				by_target[target] = []
			(by_target[target] as Array).append({"cell": cell, "target": target, "flags": flags_of[target]})
	for target: String in by_target:
		var material: ShaderMaterial = _make_material(target)
		if material == null:
			push_error("[GroundTransitions3D] no photographic plane for '%s': its borders stay hard" % target)
			continue
		_materials[target] = material
		var node := MeshInstance3D.new()
		node.name = "GroundTransitions3D_%s" % target
		node.material_override = material
		node.mesh = ArrayMesh.new()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
		board.add_child(node)
		_nodes[target] = node
		for quad: Dictionary in by_target[target]:
			var cell: Vector2i = quad["cell"]
			_quads[Vector3i(cell.x, cell.y, _target_index(target))] = quad
		_rebuild(target)


func detach() -> void:
	for target in _nodes:
		if is_instance_valid(_nodes[target]):
			_nodes[target].queue_free()
	if _board != null and is_instance_valid(_board) and _board.has_method("unregister_overlay_material"):
		for target in _materials:
			_board.call("unregister_overlay_material", _materials[target])
	_nodes.clear()
	_materials.clear()
	_quads.clear()
	_targets.clear()
	_board = null


func count() -> int:
	return _quads.size()


## After every committed mutation: `has_floor(x, z)` answers whether a floor-top voxel still stands on that voxel cell. A quad whose
## GU lost any of its 8 x 8 ends.
func refresh(has_floor: Callable) -> void:
	var gone: Array = []
	for key: Vector3i in _quads:
		var cell: Vector2i = _quads[key]["cell"]
		var whole: bool = true
		for x in range(cell.x * 8, cell.x * 8 + 8):
			for z in range(cell.y * 8, cell.y * 8 + 8):
				if not has_floor.call(x, z):
					whole = false
					break
			if not whole:
				break
		if not whole:
			gone.append(key)
	var touched: Dictionary = {}
	for key: Vector3i in gone:
		touched[_quads[key]["target"]] = true
		_quads.erase(key)
	for target in touched:
		_rebuild(target)


func _target_index(target: String) -> int:
	var i: int = _targets.find(target)
	if i < 0:
		_targets.append(target)
		i = _targets.size() - 1
	return i


func _make_material(target: String) -> ShaderMaterial:
	var surface: Texture2D = _board.call("material_surface_texture", target)
	if surface == null:
		return null
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BoardLook.apply_grade((load(SHADER_PATH) as Shader).code)
	material.shader = shader
	material.render_priority = PRIORITY
	material.set_shader_parameter("surface_tex", surface)
	var macro: Texture2D = _board.call("surface_macro_texture")
	if macro != null:
		material.set_shader_parameter("surface_macro", macro)
	material.set_shader_parameter("edge_noise", _edge_noise())
	material.set_shader_parameter("band", WIDTH_GU)
	material.set_shader_parameter("noise_amount", NOISE_AMOUNT)
	material.set_shader_parameter("noise_period", NOISE_PERIOD_GU)
	_board.call("register_overlay_material", material)
	return material


## The world noise that moves the iso-line: generated in the engine (seamless FastNoiseLite, a fixed seed), so there is no art file to
## lose and every run of every machine draws the same border.
func _edge_noise() -> ImageTexture:
	if _noise_tex == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = NOISE_SEED
		noise.frequency = 0.02
		noise.fractal_octaves = 2
		var image: Image = noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE, false, false, 0.1, true)
		image.convert(Image.FORMAT_L8)
		_noise_tex = ImageTexture.create_from_image(image)
	return _noise_tex


func _rebuild(target: String) -> void:
	var node: MeshInstance3D = _nodes.get(target, null)
	if node == null or not is_instance_valid(node):
		return
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var ground_level: int = _board.call("ground_level")
	var y: float = float(_level + 1 - ground_level) * unit + LIFT
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for key: Vector3i in _quads:
		var quad: Dictionary = _quads[key]
		if quad["target"] != target:
			continue
		var cell: Vector2i = quad["cell"]
		var col := Color(float(int(quad["flags"])) / 255.0, 0.0, 0.0, 1.0)
		var a := Vector3(cell.x, y, cell.y)
		var b := Vector3(cell.x + 1, y, cell.y)
		var d := Vector3(cell.x + 1, y, cell.y + 1)
		var e := Vector3(cell.x, y, cell.y + 1)
		verts.append_array(PackedVector3Array([a, b, d, a, d, e]))
		uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]))
		cols.append_array(PackedColorArray([col, col, col, col, col, col]))
	var mesh: ArrayMesh = node.mesh
	mesh.clear_surfaces()
	if verts.is_empty():
		node.visible = false
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.visible = true
