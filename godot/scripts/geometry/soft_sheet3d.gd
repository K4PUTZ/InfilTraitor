## SoftSheet3D — a soft roof (cloth) falling under gravity: the draw of one `SoftSheetSim`, in ONE draw call.
##
## ROOF_MASTER_PLAN v0.28. The simulation owns a COARSE node grid; this node uploads its positions every frame as a tiny float texture (one texel a
## node, `nodes`) and a fine mesh (a vertex per `step` voxels) is put on the bicubic surface through them in the vertex shader (`soft_sheet3d.gdshader`):
## the cost per frame is the sim's step plus ~170 texels, never a skinned mesh in GDScript. The mesh covers the roof's voxel columns (a column the
## roof did not have is not drawn), its colour is the tone each roof voxel had at the release (the board's light and soot, baked in), its texture
## the material's facade mapped as the board maps a roof's top face.
##
## It is HIDDEN until `reveal()`: the roof's voxels leave the board in a remesh a frame or two after the sheet is built, and the cloth must appear
## in the very frame the chunks swap (`Room.release_roof_sheet`), or the roof would show twice or not at all.
##
## THREADED (`skin.threaded`, the dev flag `SOFT_SHEET_THREAD`): ONE long task on the `WorkerThreadPool` steps the sim back to back for as long as real time is
## owed (the main thread says how many steps real time has earned; the worker publishes a copy of each finished step under a mutex), and the frame
## draws the last published step interpolated over one step. The frame never waits for the sim; if a step costs more than its own simulated time (the
## Moto: 35 ms against 33 ms with 6 iterations) the cloth falls in slow motion, the frame rate does not move. Off, the steps run in `_process`.
##
## COST IS MEASURED HERE: every step the sim runs is timed, and when it settles one `[SOFT-SHEET]` line says how many, how long each took on
## average and at worst (the number the Moto round reads), and how many frames the cloth was alive.
class_name SoftSheet3D
extends Node3D

const SHADER_PATH := "res://godot/shaders/soft_sheet3d.gdshader"

## Emitted once, when the simulation has settled (or hit its time limit).
signal settled()

var _board: Node3D = null
var _sim: SoftSheetSim = null
var _mesh_node: MeshInstance3D = null
var _arrays: Array = []           ## the skin's surface arrays, kept to repaint the vertex colours (`scorch`)
var _mat: ShaderMaterial = null
var _image: Image = null
var _texture: ImageTexture = null
var _lerped: PackedFloat32Array = PackedFloat32Array()
var _texels: PackedFloat32Array = PackedFloat32Array()
var _done: bool = false
var _label: String = ""

# the cost, for the handset round
var _step_usec: int = 0
var _step_count: int = 0
var _step_worst: int = 0
var _frames: int = 0
var _frame_usec: int = 0
var _real_seconds: float = 0.0

# threaded mode
var _threaded: bool = false
var _task: int = -1
var _mutex: Mutex = Mutex.new()
var _stop: bool = false          ## guarded by `_mutex`: the worker's way out
var _owed_steps: int = 0         ## guarded: how many steps real time has earned so far
var _done_steps: int = 0         ## guarded: how many the worker has finished
var _worker_usec: int = 0        ## guarded: the time they took
var _worker_worst: int = 0       ## guarded
var _worker_settled: bool = false   ## guarded
var _pub_prev: PackedFloat64Array = PackedFloat64Array()   ## guarded: the last finished step's two ends
var _pub_pos: PackedFloat64Array = PackedFloat64Array()
var _seen_steps: int = 0         ## main thread only: the step count the last frame drew
var _front_age: float = 0.0      ## main thread only: game seconds since a new step first showed


## `skin`: x0, z0 (the first voxel column), w, d (voxel columns), step (voxels per skin quad), mask (Dictionary Vector2i(gx, gy) -> true),
## color (Callable(gx, gy) -> Color, linear, alpha 1: the material colour times the roof voxel's tone), y_top (GU: the roof's top face),
## material (id of the facade), label.
func setup(board: Node3D, sim: SoftSheetSim, skin: Dictionary) -> void:
	_board = board
	_sim = sim
	_label = String(skin.get("label", ""))
	_threaded = bool(skin.get("threaded", false))
	_pub_prev = sim.pos.duplicate()
	_pub_pos = sim.pos.duplicate()
	_image = Image.create(sim.nz, sim.nx, false, Image.FORMAT_RGBAF)   ## nz wide, nx tall: the sim's own node order, texel (j, i)
	_texture = ImageTexture.create_from_image(_image)
	_texels.resize(sim.nx * sim.nz * 4)
	_mat = ShaderMaterial.new()
	_mat.shader = BoardLook.graded_shader(SHADER_PATH)
	_mat.set_shader_parameter("nodes", _texture)
	_mat.set_shader_parameter("node_count", Vector2i(sim.nx, sim.nz))
	var facade_id: String = String(skin.get("material", ""))
	if facade_id != "" and is_instance_valid(_board):
		var facade: Texture2D = _board.call("material_facade_texture", facade_id)
		if facade != null:
			_mat.set_shader_parameter("facade", facade)
			_mat.set_shader_parameter("has_facade", 1.0)
	_mesh_node = MeshInstance3D.new()
	_mesh_node.mesh = _build_mesh(sim, skin)
	_mesh_node.material_override = _mat
	_mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_node)
	_upload(0.0)
	visible = false
	set_process(false)


## The cloth appears and starts to fall (the step the board's chunks no longer hold the roof).
func reveal() -> void:
	visible = true
	set_process(true)
	if _threaded:
		_task = WorkerThreadPool.add_task(_worker_loop, false, "SoftSheet")


func is_done() -> bool:
	return _done


## The nodes' last positions (3 floats each), for a future checkpoint record.
func node_positions() -> PackedFloat64Array:
	return _sim.pos


func _process(delta: float) -> void:
	if _sim == null or _done:
		return
	var t0: int = Time.get_ticks_usec()
	_real_seconds += delta
	if _threaded:
		_process_threaded(delta)
	else:
		var ran: int = _sim.advance(delta)
		var spent: int = Time.get_ticks_usec() - t0
		if ran > 0:
			_step_usec += spent
			_step_count += ran
			_step_worst = maxi(_step_worst, spent / ran)
		_upload(_sim.alpha())
		if _sim.is_settled():
			_finish()
	_frames += 1
	_frame_usec += Time.get_ticks_usec() - t0


## One frame with the sim on a worker: tell it how many steps the GAME's time has earned (the sum of the frames' deltas, not the wall clock: a
## frame-by-frame capture runs at a fixed delta however long a frame takes to render), draw what it last published.
func _process_threaded(delta: float) -> void:
	_mutex.lock()
	_owed_steps = int(_real_seconds / SoftSheetSim.STEP)
	var prev: PackedFloat64Array = _pub_prev
	var pos: PackedFloat64Array = _pub_pos
	var done: int = _done_steps
	var finished: bool = _worker_settled
	_mutex.unlock()
	if done != _seen_steps:
		_seen_steps = done
		_front_age = 0.0
	else:
		_front_age += delta
	_upload_arrays(prev, pos, clampf(_front_age / SoftSheetSim.STEP, 0.0, 1.0))
	if finished:
		_finish()


## The worker: step while steps are owed, publish a copy of each, rest when caught up. Touches the sim and the guarded fields only.
func _worker_loop() -> void:
	while true:
		_mutex.lock()
		var stop: bool = _stop
		var owed: bool = _done_steps < _owed_steps
		_mutex.unlock()
		if stop:
			return
		if not owed:
			OS.delay_usec(2000)
			continue
		var t0: int = Time.get_ticks_usec()
		_sim.step()
		var spent: int = Time.get_ticks_usec() - t0
		var prev: PackedFloat64Array = _sim.prev.duplicate()
		var pos: PackedFloat64Array = _sim.pos.duplicate()
		var settled_now: bool = _sim.is_settled()
		_mutex.lock()
		_pub_prev = prev
		_pub_pos = pos
		_done_steps += 1
		_worker_usec += spent
		_worker_worst = maxi(_worker_worst, spent)
		_worker_settled = settled_now
		_mutex.unlock()
		if settled_now:
			return


func _stop_worker() -> void:
	if _task == -1:
		return
	_mutex.lock()
	_stop = true
	_mutex.unlock()
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1


func _exit_tree() -> void:
	_stop_worker()


func _finish() -> void:
	_done = true
	set_process(false)
	if _threaded:
		_stop_worker()
		_step_count = _done_steps
		_step_usec = _worker_usec
		_step_worst = _worker_worst
		_upload_arrays(_pub_pos, _pub_pos, 0.0)
	else:
		_upload(0.0)
	print("[SOFT-SHEET] %s settled after %d step(s), %.1f s simulated in %.1f s of real time, %d drawn frame(s), %s: sim %.2f ms a step on average, %.2f ms at worst; this node %.2f ms a frame on the main thread (%d nodes)"
		% [_label, _step_count, _sim.time, _real_seconds, _frames, "worker thread" if _threaded else "main thread",
		float(_step_usec) / 1000.0 / maxf(float(_step_count), 1.0), float(_step_worst) / 1000.0,
		float(_frame_usec) / 1000.0 / maxf(float(_frames), 1.0), _sim.nx * _sim.nz])
	settled.emit()


## True once the cloth has come to rest (and stays out of the simulation for good).
func is_settled() -> bool:
	return _done


## ROOF_MASTER_PLAN v0.30 (Director, 2026-10-16: a cloth that has fallen does not react to explosions, "o máximo é pintar com mais fuligem"): a later blast
## at `at` (GU, world: x, y up, z) blackens the skin near it. Distance is to the cloth where it LIES (the settled node positions), not where the roof was;
## `radius` GU of reach, `strength` the darkest it gets (0..1 of the tone removed at the centre). A no-op for a cloth still falling. Repaints the vertex
## colours only: the sim, the shader and the node texture are not touched.
func scorch(at: Vector3, radius: float, strength: float) -> int:
	if not _done or _arrays.is_empty() or _mesh_node == null:
		return 0
	var uvs: PackedVector2Array = _arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = _arrays[Mesh.ARRAY_COLOR]
	var touched: int = 0
	for k in range(colors.size()):
		var i: int = clampi(roundi(uvs[k].x), 0, _sim.nx - 1)
		var j: int = clampi(roundi(uvs[k].y), 0, _sim.nz - 1)
		var n: int = (i * _sim.nz + j) * 3
		var d: float = Vector3(_sim.pos[n], _sim.pos[n + 1], _sim.pos[n + 2]).distance_to(at)
		if d >= radius:
			continue
		var f: float = 1.0 - d / radius
		var keep: float = 1.0 - strength * f * f
		var c: Color = colors[k]
		colors[k] = Color(c.r * keep, c.g * keep, c.b * keep, c.a)
		touched += 1
	if touched == 0:
		return 0
	_arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	mesh.custom_aabb = (_mesh_node.mesh as ArrayMesh).custom_aabb
	_mesh_node.mesh = mesh
	return touched


## The node positions `a` of the way through the current step, into the texture (the main-thread path).
func _upload(a: float) -> void:
	_sim.positions_lerped(a, _lerped)
	_write_texture()


## The same from two copies of a step's ends (the threaded path: the sim itself may be mid-step on the worker).
func _upload_arrays(from: PackedFloat64Array, to: PackedFloat64Array, a: float) -> void:
	_lerped.resize(to.size())
	for k in range(to.size()):
		_lerped[k] = from[k] + (to[k] - from[k]) * a
	_write_texture()


func _write_texture() -> void:
	var n: int = _sim.nx * _sim.nz
	for k in range(n):
		_texels[k * 4] = _lerped[k * 3]
		_texels[k * 4 + 1] = _lerped[k * 3 + 1]
		_texels[k * 4 + 2] = _lerped[k * 3 + 2]
		_texels[k * 4 + 3] = 1.0
	_image.set_data(_sim.nz, _sim.nx, false, Image.FORMAT_RGBAF, _texels.to_byte_array())
	_texture.update(_image)


## The fine mesh: vertices on a lattice of `step` voxels over the roof's rectangle; a quad is drawn when the roof had a voxel column under it.
## UV = the place in node units, UV2 = the rest position in voxels, COLOR = the tone of the column the vertex sits on. The positions are rest values
## (the shader moves them); the bounds are the whole reach of the cloth (it can hang to the floor and swing a span away).
func _build_mesh(sim: SoftSheetSim, skin: Dictionary) -> ArrayMesh:
	var x0: int = int(skin["x0"])
	var z0: int = int(skin["z0"])
	var w: int = int(skin["w"])
	var d: int = int(skin["d"])
	var step: int = maxi(int(skin.get("step", 2)), 1)
	var mask: Dictionary = skin["mask"]
	var colour: Callable = skin["color"]
	var y_top: float = float(skin["y_top"])
	var qa: int = int(ceil(float(w) / float(step)))
	var qb: int = int(ceil(float(d) / float(step)))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	for a in range(qa + 1):
		for b in range(qb + 1):
			var ox: int = mini(a * step, w)
			var oz: int = mini(b * step, d)
			var wx: float = float(x0 + ox) * unit
			var wz: float = float(z0 + oz) * unit
			verts.append(Vector3(wx, y_top, wz))
			uvs.append(Vector2((wx - sim.origin.x) / sim.hx, (wz - sim.origin.z) / sim.hz))
			uv2s.append(Vector2(float(x0 + ox), float(z0 + oz)))
			colors.append(colour.call(x0 + mini(ox, w - 1), z0 + mini(oz, d - 1)))
	var indices := PackedInt32Array()
	for a in range(qa):
		for b in range(qb):
			var covered: bool = false
			for gx in range(x0 + a * step, mini(x0 + (a + 1) * step, x0 + w)):
				for gz in range(z0 + b * step, mini(z0 + (b + 1) * step, z0 + d)):
					if mask.has(Vector2i(gx, gz)):
						covered = true
						break
				if covered:
					break
			if not covered:
				continue
			var i00: int = a * (qb + 1) + b
			var i10: int = (a + 1) * (qb + 1) + b
			var i01: int = a * (qb + 1) + b + 1
			var i11: int = (a + 1) * (qb + 1) + b + 1
			indices.append_array([i00, i10, i11, i00, i11, i01])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_arrays = arrays
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var reach: float = maxf(float(w), float(d)) * unit + 2.0
	mesh.custom_aabb = AABB(Vector3(float(x0) * unit - reach, -0.5, float(z0) * unit - reach), Vector3(2.0 * reach + float(w) * unit, y_top + 1.5, 2.0 * reach + float(d) * unit))
	return mesh
