## PropFragments3D — the voxel fragments of one broken prop, in ONE draw call, depth-tested, lit by the board's planes.
##
## PROPS_TIER4_PLAN P2 / `ACTOR` D67. While a `PropFragmentSim` runs, this node moves the cubes every frame; when the sim is done
## it keeps only the landed ones as a static pile. `make_pile()` builds the same thing from saved records (a rotation rebuilds the
## board and drops every node, so the pile is laid back from `Room._base_prop_piles`).
##
## ONE MultiMesh of a board-size cube (1/8 GU), the `ShardField3D` precedent: `custom_aabb` set (a MultiMesh's bounds come from its
## base mesh, so without it every cube away from the node origin is culled). The material is the board's prop shader with
## `use_color`: the cell planes give it light and soot, the per-instance colour gives it the prop's material colour, each cube's small
## brightness variation and its charring. The colour is handed over in linear (vertex colour is linear, the shader's `albedo` is sRGB).
class_name PropFragments3D
extends Node3D

const SHADER_PATH := "res://godot/shaders/prop_mesh3d.gdshader"
const FLOATS_PER_INSTANCE: int = 16   ## 12 of transform + 4 of colour

## Emitted once, when the simulation has finished: the pile as records ({"column", "level", "mult"}; see `_pile_records`).
signal settled(records: Array)

var _board: Node3D = null
var _mm: MultiMesh = null
var _node: MultiMeshInstance3D = null
var _mat: ShaderMaterial = null
var _sim: PropFragmentSim = null
var _base: Color = Color(0.6, 0.6, 0.6)
var _buf: PackedFloat32Array = PackedFloat32Array()
var _voxel: float = 0.125
var _y0: float = 0.0
var _finished: bool = false


## A live one: steps `sim` every frame until it is done.
func setup(board: Node3D, sim: PropFragmentSim, base_color: Color) -> void:
	_board = board
	_sim = sim
	_base = base_color
	_voxel = sim.voxel
	_y0 = sim.origin.y
	_build(sim.count)
	_upload()
	set_process(true)


## A static pile from records. `y0` is the floor's world height under it.
static func make_pile(board: Node3D, records: Array, y0: float, base_color: Color) -> PropFragments3D:
	var node := PropFragments3D.new()
	node._board = board
	node._base = base_color
	node._y0 = y0
	node._finished = true
	node._build(records.size())
	for i in range(records.size()):
		var r: Dictionary = records[i]
		var col: Vector2i = r["column"]
		var centre := Vector3((float(col.x) + 0.5) * node._voxel, y0 + (float(int(r["level"])) + 0.5) * node._voxel,
			(float(col.y) + 0.5) * node._voxel)
		node._write(i, Transform3D(Basis.IDENTITY, centre), node._colour(float(r["mult"])))
	node._mm.buffer = node._buf
	node.set_process(false)
	return node


func is_finished() -> bool:
	return _finished


## Runs a live simulation to its end NOW (a rotation is about to rebuild the board: the pile has to be recorded first).
func finish_now() -> void:
	if _sim == null or _finished:
		return
	var guard: int = 0
	while not _sim.is_done() and guard < 400:
		_sim.advance(PropFragmentSim.STEP)
		guard += 1
	_finalize()


func _process(delta: float) -> void:
	if _sim == null or _finished:
		return
	_sim.advance(delta)
	if _sim.is_done():
		_finalize()
	else:
		_upload()


func _exit_tree() -> void:
	if is_instance_valid(_board) and _mat != null:
		_board.call("unregister_prop_light_material", _mat)


func _build(n: int) -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * _voxel
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = cube
	_mm.custom_aabb = AABB(Vector3(-1.0e5, -1.0e5, -1.0e5), Vector3(2.0e5, 2.0e5, 2.0e5))
	_mm.instance_count = n
	_buf = PackedFloat32Array()
	_buf.resize(n * FLOATS_PER_INSTANCE)
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	_mat.set_shader_parameter("albedo", Color.WHITE)
	_mat.set_shader_parameter("use_color", 1.0)
	_mat.set_shader_parameter("soot_affects", 0.0)   ## the fragment carries its own charred tone
	_node = MultiMeshInstance3D.new()
	_node.multimesh = _mm
	_node.material_override = _mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_node)
	if is_instance_valid(_board):
		_board.call("register_prop_light_material", _mat)


## The linear instance colour for a multiplier on the material colour.
func _colour(mult: float) -> Color:
	return Color(_base.r * mult, _base.g * mult, _base.b * mult, 1.0).srgb_to_linear()


func _write(i: int, xf: Transform3D, c: Color) -> void:
	var o: int = i * FLOATS_PER_INSTANCE
	var b: Basis = xf.basis
	_buf[o + 0] = b.x.x
	_buf[o + 1] = b.y.x
	_buf[o + 2] = b.z.x
	_buf[o + 3] = xf.origin.x
	_buf[o + 4] = b.x.y
	_buf[o + 5] = b.y.y
	_buf[o + 6] = b.z.y
	_buf[o + 7] = xf.origin.y
	_buf[o + 8] = b.x.z
	_buf[o + 9] = b.y.z
	_buf[o + 10] = b.z.z
	_buf[o + 11] = xf.origin.z
	_buf[o + 12] = c.r
	_buf[o + 13] = c.g
	_buf[o + 14] = c.b
	_buf[o + 15] = c.a


func _upload() -> void:
	var sim: PropFragmentSim = _sim
	for i in range(sim.count):
		if sim.state[i] == PropFragmentSim.State.GONE:
			_write(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), sim.pos[i]), Color(0.0, 0.0, 0.0, 1.0))
			continue
		var mult: float = sim.jitter[i] * lerpf(1.0, sim.tone[i], sim.char_amount(i))
		_write(i, Transform3D(sim.rotation_of(i), sim.pos[i]), _colour(mult))
	_mm.buffer = _buf


## Keep only what landed, as a static pile, and tell the world.
func _finalize() -> void:
	_finished = true
	set_process(false)
	var sim: PropFragmentSim = _sim
	var records: Array = []
	for i in range(sim.count):
		if sim.state[i] == PropFragmentSim.State.LANDED:
			records.append({"column": sim.column[i], "level": sim.level[i],
				"mult": sim.jitter[i] * lerpf(1.0, sim.tone[i], sim.char_amount(i))})
	_mm.instance_count = records.size()
	_buf = PackedFloat32Array()
	_buf.resize(records.size() * FLOATS_PER_INSTANCE)
	for i in range(records.size()):
		var r: Dictionary = records[i]
		var col: Vector2i = r["column"]
		var centre := Vector3((float(col.x) + 0.5) * _voxel, _y0 + (float(int(r["level"])) + 0.5) * _voxel, (float(col.y) + 0.5) * _voxel)
		_write(i, Transform3D(Basis.IDENTITY, centre), _colour(float(r["mult"])))
	_mm.buffer = _buf
	settled.emit(records)
