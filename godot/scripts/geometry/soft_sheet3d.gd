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
## How long a column takes to burn from the first darkening to black (`Room.CHAR_FADE_S`), and the vertex format that carries the second it starts.
const BURN_SECONDS: float = 1.4
const CUSTOM_FLAGS: int = (Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

## Emitted once, when the simulation has settled (or hit its time limit).
signal settled()

var _board: Node3D = null
var _sim: SoftSheetSim = null
var _mesh_node: MeshInstance3D = null
var _mask: Dictionary = {}          ## the roof's voxel columns the skin covers (Vector2i -> true)
var _burn_clock: float = 0.0        ## seconds since `reveal()`: what the shader's burn front reads
var _burn_end: float = 0.0          ## when the last column has finished burning (0 = nothing burns)
var _settle_clock: float = -1.0    ## seconds since the cloth came to rest (-1 before): what the fire that spreads over it when it parks reads
var _burn_b_end: float = 0.0        ## how long after it parks the last of that fire is out (0 = none)
var _arrays: Array = []           ## the skin's surface arrays, kept to repaint the vertex colours (`scorch`)
var _mat: ShaderMaterial = null
var _image: Image = null
var _texture: ImageTexture = null
var _lerped: PackedFloat32Array = PackedFloat32Array()
var _texels: PackedFloat32Array = PackedFloat32Array()
var _done: bool = false
var _resting: bool = false          ## drawn at rest from the load (`show_at_rest`), not yet cut or let go
var _xy: Dictionary = {}            ## a wall's voxel columns (board x, y), empty for a roof
var _gus: Dictionary = {}           ## the roof GUs the skin covers (made on first use)
var _label: String = ""

# the cost, for the handset round
var _step_usec: int = 0
var _step_count: int = 0
var _step_worst: int = 0
var _frames: int = 0
var _frame_usec: int = 0
var _real_seconds: float = 0.0

# threaded mode: the worker lives in the sheet's `SoftSheetGroup` (a lone sheet is a group of one; sheets sewn together share one)
var _threaded: bool = false
var _group: SoftSheetGroup = null
var _index: int = 0              ## this sheet's place in the group
var _pub_prev: PackedFloat64Array = PackedFloat64Array()   ## the last finished step's two ends, this sheet's copy
var _pub_pos: PackedFloat64Array = PackedFloat64Array()
var _seen_steps: int = 0         ## main thread only: the step count the last frame drew
var _front_age: float = 0.0      ## main thread only: game seconds since a new step first showed


## `skin`: x0, z0 (the first voxel column), w, d (voxel columns), step (voxels per skin quad), mask (Dictionary Vector2i(gx, gy) -> true),
## color (Callable(gx, gy) -> Color, linear, alpha 1: the material colour times the roof voxel's tone), y_top (GU: the roof's top face),
## material (id of the facade), label.
func setup(board: Node3D, sim: SoftSheetSim, skin: Dictionary, group: SoftSheetGroup = null) -> void:
	_board = board
	_sim = sim
	if group == null:
		group = SoftSheetGroup.new()
		group.add(sim)
	_group = group
	_index = group.index_of(sim)
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
	_mask = skin["mask"]
	_xy = skin.get("xy", {})
	_gus = skin.get("gus", {})   ## a wall names its GUs itself (its mask is in the sheet's own (along, down) cells, not board columns)
	_mat.set_shader_parameter("clock", 0.0)
	_mat.set_shader_parameter("settle_clock", -1.0)
	_mat.set_shader_parameter("noise_tex", noise_texture())
	_mat.set_shader_parameter("thickness", float(skin.get("thickness", 0.0)))
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
		_group.start()   ## once, whichever sheet of the group is revealed first


## ROOF_MASTER_PLAN v0.41 (Director, 2026-10-16: the cloth is part of the world from the first frame, not a flat plane until the blast): the sheet is drawn AT REST,
## from a sim that `SoftSheetSim.settle_now()` already brought to rest. Nothing steps, nothing is uploaded again; `burning` runs the shader's clocks for the
## cloth a blast has just cut a hole in (the opening's edge burns, the fire spreads a little, soot stays), exactly as when a fallen cloth parks.
func show_at_rest(burning: bool = false, finished: bool = false) -> void:
	_resting = true
	_done = true
	visible = true
	_upload(0.0)
	_settle_clock = 0.0 if (burning and _burn_b_end > 0.0) else -1.0
	set_process(burning and (_burn_end > 0.0 or _burn_b_end > 0.0))
	if finished and burning:
		## a cloth that already burned and was cut again (a bullet): its fires are out and the soot is what stays, not the fire again from the start
		_burn_clock = _burn_end + 2.0
		_settle_clock = _burn_b_end + 2.0
		_mat.set_shader_parameter("clock", _burn_clock)
		_mat.set_shader_parameter("settle_clock", _settle_clock)
		set_process(false)
	if is_instance_valid(_board):
		_board.call("sheet_reveal_state", self)   ## the agent may already be under this roof


## A cloth that was LET GO before a checkpoint, brought back lying where it fell (`Room._show_fallen`): drawn still, soot finished, and NOT hidden with a roof (it is
## on the floor, not up in the roof's place).
func show_settled() -> void:
	_resting = false
	_done = true
	visible = true
	_upload(0.0)
	if _burn_end > 0.0 or _burn_b_end > 0.0:
		_burn_clock = _burn_end + 2.0
		_settle_clock = _burn_b_end + 2.0
		_mat.set_shader_parameter("clock", _burn_clock)
		_mat.set_shader_parameter("settle_clock", _settle_clock)
	set_process(false)


## A cloth shown at rest from the load (not yet cut by a blast, nor let go): the cutaway hides it with its roof (`set_revealed`).
func is_resting() -> bool:
	return _resting


func sim() -> SoftSheetSim:
	return _sim


## The cutaway opened the roof this cloth is (the agent is under it): a resting cloth hides while its roof is revealed, as the voxel roof did.
func set_revealed(revealed: bool) -> void:
	if _resting:
		visible = not revealed


## The roof GUs (a GU = 8 x 8 voxel columns) this cloth covers: what the cutaway's revealed set is compared with.
func covers_any_gu(gus: Dictionary) -> bool:
	if _gus.is_empty():
		for column: Vector2i in _mask:
			_gus[Vector2i(column.x >> 3, column.y >> 3)] = true
	for gu: Vector2i in _gus:
		if gus.has(gu):
			return true
	return false


## A WALL sheet (a vertical one) and the board columns its voxels stand in: the cutaway ghosts those, and the cloth hides with them.
## Where the nodes are now (3 floats each): the last step the worker finished (a checkpoint saves it).
func current_positions() -> PackedFloat64Array:
	if _group == null:
		return _sim.pos.duplicate()
	var snap: Dictionary = _group.snapshot()
	return ((snap["pos"] as Array)[_index] as PackedFloat64Array).duplicate()


func is_wall() -> bool:
	return not _xy.is_empty()


func covers_any_column(columns: Dictionary) -> bool:
	for column: Vector2i in _xy:
		if columns.has(column):
			return true
	return false


func is_done() -> bool:
	return _done


## The nodes' last positions (3 floats each), for a future checkpoint record.
func node_positions() -> PackedFloat64Array:
	return _sim.pos


func _process(delta: float) -> void:
	if _burn_end > 0.0:
		_burn_clock += delta
		_mat.set_shader_parameter("clock", _burn_clock)
	if _done and _burn_b_end > 0.0:
		_settle_clock += delta
		_mat.set_shader_parameter("settle_clock", _settle_clock)
	if _done and _burn_clock > _burn_end and _settle_clock > _burn_b_end:
		set_process(false)
	if _sim == null or _done:
		return
	var t0: int = Time.get_ticks_usec()
	_real_seconds += delta
	if _threaded:
		_process_threaded(delta)
	else:
		var ran: int = _group.advance(delta) if _index == 0 else 0   ## the first sheet steps the whole group
		var spent: int = Time.get_ticks_usec() - t0
		if ran > 0:
			_step_usec += spent
			_step_count += ran
			_step_worst = maxi(_step_worst, spent / ran)
		_upload(_group.alpha())
		if _group.is_settled():
			_finish()
	_frames += 1
	_frame_usec += Time.get_ticks_usec() - t0


## One frame with the sim on a worker: tell it how many steps the GAME's time has earned (the sum of the frames' deltas, not the wall clock: a
## frame-by-frame capture runs at a fixed delta however long a frame takes to render), draw what it last published.
func _process_threaded(delta: float) -> void:
	_group.owe(_real_seconds)
	var snap: Dictionary = _group.snapshot()
	var prev: PackedFloat64Array = (snap["prev"] as Array)[_index]
	var pos: PackedFloat64Array = (snap["pos"] as Array)[_index]
	_pub_prev = prev
	_pub_pos = pos
	var done: int = int(snap["done"])
	var finished: bool = bool(snap["finished"])
	if done != _seen_steps:
		_seen_steps = done
		_front_age = 0.0
	else:
		_front_age += delta
	_upload_arrays(prev, pos, clampf(_front_age / SoftSheetSim.STEP, 0.0, 1.0))
	if finished:
		_finish()


func _exit_tree() -> void:
	if _group != null:
		_group.stop()


func _finish() -> void:
	_done = true
	_settle_clock = 0.0 if _burn_b_end > 0.0 else -1.0
	set_process(_burn_end > _burn_clock or _burn_b_end > 0.0)   ## a cloth still burning, or about to catch where it parks, keeps its clocks running after it has come to rest
	if _threaded:
		_group.stop()
		var snap: Dictionary = _group.snapshot()
		_step_count = int(snap["done"])
		_step_usec = int(snap["usec"])
		_step_worst = int(snap["worst"])
		_pub_pos = (snap["pos"] as Array)[_index]
		_upload_arrays(_pub_pos, _pub_pos, 0.0)
	else:
		_upload(0.0)
	print("[SOFT-SHEET] %s settled after %d step(s), %.1f s simulated in %.1f s of real time, %d drawn frame(s), %s: sim %.2f ms a step on average, %.2f ms at worst; this node %.2f ms a frame on the main thread (%d nodes)"
		% [_label, _step_count, _group.sim_time(), _real_seconds, _frames, "worker thread" if _threaded else "main thread",
		float(_step_usec) / 1000.0 / maxf(float(_step_count), 1.0), float(_step_worst) / 1000.0,
		float(_frame_usec) / 1000.0 / maxf(float(_frames), 1.0), _sim.nx * _sim.nz])
	settled.emit()


## Where the cloth is, now, over the world point (x, z) in GU: the bilinear blend of the four nodes around it (the last drawn step). Clamped to the sheet.
func sample(x: float, z: float) -> Vector3:
	var fi: float = clampf((x - _sim.origin.x) / _sim.hx, 0.0, float(_sim.nx - 1))
	var fj: float = clampf((z - _sim.origin.z) / _sim.hz, 0.0, float(_sim.nz - 1))
	var i0: int = mini(int(fi), _sim.nx - 2)
	var j0: int = mini(int(fj), _sim.nz - 2)
	var a: float = fi - float(i0)
	var b: float = fj - float(j0)
	var out := Vector3.ZERO
	for di in range(2):
		for dj in range(2):
			var w: float = (a if di == 1 else 1.0 - a) * (b if dj == 1 else 1.0 - b)
			var n: int = ((i0 + di) * _sim.nz + (j0 + dj)) * 3
			out += w * Vector3(_lerped[n], _lerped[n + 1], _lerped[n + 2])
	return out


## Whether the skin covers the roof column `cell` (a voxel column): what a fire still creeping across the cloth asks.
func covers(cell: Vector2i) -> bool:
	return _mask.has(cell)


## Where the cloth is now, over the CENTRE of the roof column `cell`.
func column_point(cell: Vector2i) -> Vector3:
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	return sample((float(cell.x) + 0.5) * unit, (float(cell.y) + 0.5) * unit)


## One 64 x 64 RGB texture of smooth value noise for the shader's ragged fire fronts and soot patches, built once per run (lattice of 8 cells, wrapping).
static var _noise_texture: ImageTexture = null


static func noise_texture() -> ImageTexture:
	if _noise_texture != null:
		return _noise_texture
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var cells: Array = [8, 5, 11]   ## per channel: how many lattice cells across (a different scale each, so the channels differ)
	var lattices: Array = []
	for ch in range(3):
		var n: int = int(cells[ch])
		var g: PackedFloat32Array = PackedFloat32Array()
		g.resize(n * n)
		for k in range(n * n):
			g[k] = float(FacadeSampler._fnv1a_hash("CLOTHNOISE|%d|%d" % [ch, k]) % 1000) / 1000.0
		lattices.append(g)
	for y in range(64):
		for x in range(64):
			var color := Color()
			for ch in range(3):
				var n: int = int(cells[ch])
				var g: PackedFloat32Array = lattices[ch]
				var fx: float = float(x) / 64.0 * float(n)
				var fy: float = float(y) / 64.0 * float(n)
				var ix: int = int(floor(fx))
				var iy: int = int(floor(fy))
				var tx: float = fx - float(ix)
				var ty: float = fy - float(iy)
				tx = tx * tx * (3.0 - 2.0 * tx)
				ty = ty * ty * (3.0 - 2.0 * ty)
				var v00: float = g[(iy % n) * n + (ix % n)]
				var v10: float = g[(iy % n) * n + ((ix + 1) % n)]
				var v01: float = g[((iy + 1) % n) * n + (ix % n)]
				var v11: float = g[((iy + 1) % n) * n + ((ix + 1) % n)]
				var v: float = lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), ty)
				if ch == 0:
					color.r = v
				elif ch == 1:
					color.g = v
				else:
					color.b = v
			image.set_pixel(x, y, color)
	_noise_texture = ImageTexture.create_from_image(image)
	return _noise_texture


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
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays, [], {}, CUSTOM_FLAGS)
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
	var plane: Dictionary = skin.get("plane", {})
	var qa: int = int(ceil(float(w) / float(step)))
	var qb: int = int(ceil(float(d) / float(step)))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var ignite := PackedFloat32Array()   ## per vertex, 2 floats: the second its column starts to burn (1e9 = never) and 1 for a SKIRT vertex: CUSTOM0.xy, read by the shader
	var burn: Dictionary = skin.get("burn", {})
	var burn_b: Dictionary = skin.get("burn_b", {})   ## column -> seconds AFTER the cloth parks that it catches
	var soot_final: Dictionary = skin.get("soot_final", {})   ## column -> the tone it ends (1 = clean, 0 = black)
	var custom1 := PackedFloat32Array()
	var has_fire: bool = not (burn.is_empty() and burn_b.is_empty() and soot_final.is_empty())   ## a cloth at rest, untouched, has none: its vertices need no neighbour walk
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	for a in range(qa + 1):
		for b in range(qb + 1):
			var ox: int = mini(a * step, w)
			var oz: int = mini(b * step, d)
			if plane.is_empty():
				verts.append(Vector3(float(x0 + ox) * unit, y_top, float(z0 + oz) * unit))
			else:
				## a WALL: the lattice lies in the sheet's own plane, `plane.eu` along the wall and `plane.ev` down it (one voxel step each, in GU)
				verts.append((plane["origin"] as Vector3) + (plane["eu"] as Vector3) * float(ox) + (plane["ev"] as Vector3) * float(oz))
			uvs.append(Vector2(float(ox) * unit / sim.hx, float(oz) * unit / sim.hz))
			uv2s.append(Vector2(float(x0 + ox), float(z0 + oz)))
			colors.append(colour.call(x0 + mini(ox, w - 1), z0 + mini(oz, d - 1)))
			## Per vertex the 4 columns around it say how much of it burns (a WEIGHT, 0..1, interpolated: a time of "never" like 1e9 cannot be, it made a
			## chequerboard of the lattice), when it starts, and the tone it ends.
			var when: float = 1.0e9
			var delay_b: float = 1.0e9
			var final_tone: float = 1.0
			var n_a: int = 0
			var n_b: int = 0
			for dx in range(-1 if has_fire else 0, 1 if has_fire else 0):
				for dz in range(-1, 1):
					var cell_v := Vector2i(x0 + ox + dx, z0 + oz + dz)
					if burn.has(cell_v):
						when = minf(when, float(burn[cell_v]))
						n_a += 1
					if burn_b.has(cell_v):
						delay_b = minf(delay_b, float(burn_b[cell_v]))
						n_b += 1
					if soot_final.has(cell_v):
						final_tone = minf(final_tone, float(soot_final[cell_v]))
			ignite.append(when if n_a > 0 else 0.0)
			ignite.append(0.0)
			custom1.append(delay_b if n_b > 0 else 0.0)
			custom1.append(final_tone)
			custom1.append(float(n_a) / 4.0)
			custom1.append(float(n_b) / 4.0)
			if n_a > 0:
				_burn_end = maxf(_burn_end, when + BURN_SECONDS)
			if n_b > 0:
				_burn_b_end = maxf(_burn_b_end, delay_b + BURN_SECONDS)
			if when < 1.0e8:
				_burn_end = maxf(_burn_end, when + BURN_SECONDS)
	var indices := PackedInt32Array()
	var covered_quads: Dictionary = {}
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
			covered_quads[Vector2i(a, b)] = true
	## The SKIRT (ROOF_MASTER_PLAN v0.31, Director: "não ficar parecendo uma folha de papel"): along every boundary of the skin (the hole's rim, the free edges) a strip
	## whose far side the vertex shader hangs `thickness` below the cloth along its normal, so the cloth shows an edge. Same UV / colour as the vertex it copies.
	var edges: Array = []   ## [top vertex index, top vertex index] per boundary edge
	for q: Vector2i in covered_quads:
		var v00: int = q.x * (qb + 1) + q.y
		var v10: int = (q.x + 1) * (qb + 1) + q.y
		var v01: int = q.x * (qb + 1) + q.y + 1
		var v11: int = (q.x + 1) * (qb + 1) + q.y + 1
		if not covered_quads.has(q + Vector2i(-1, 0)):
			edges.append([v00, v01])
		if not covered_quads.has(q + Vector2i(1, 0)):
			edges.append([v10, v11])
		if not covered_quads.has(q + Vector2i(0, -1)):
			edges.append([v00, v10])
		if not covered_quads.has(q + Vector2i(0, 1)):
			edges.append([v01, v11])
	var copies: Dictionary = {}
	for edge in edges:
		var tops: Array = edge
		var lows: Array = []
		for t in tops:
			var vi: int = int(t)
			if not copies.has(vi):
				copies[vi] = verts.size()
				verts.append(verts[vi])
				uvs.append(uvs[vi])
				uv2s.append(uv2s[vi])
				colors.append(colors[vi])
				ignite.append(ignite[vi * 2])
				ignite.append(1.0)
				for q in range(4):
					custom1.append(custom1[vi * 4 + q])
			lows.append(int(copies[vi]))
		indices.append_array([int(tops[0]), int(tops[1]), int(lows[1]), int(tops[0]), int(lows[1]), int(lows[0])])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_CUSTOM0] = ignite
	arrays[Mesh.ARRAY_CUSTOM1] = custom1
	arrays[Mesh.ARRAY_INDEX] = indices
	_arrays = arrays
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, CUSTOM_FLAGS)
	var reach: float = maxf(float(w), float(d)) * unit + 2.0
	if plane.is_empty():
		mesh.custom_aabb = AABB(Vector3(float(x0) * unit - reach, -0.5, float(z0) * unit - reach), Vector3(2.0 * reach + float(w) * unit, y_top + 1.5, 2.0 * reach + float(d) * unit))
	else:
		mesh.custom_aabb = AABB((plane["origin"] as Vector3) - Vector3(reach, reach + 2.0, reach), Vector3(2.0 * reach, 2.0 * reach + 3.0, 2.0 * reach))
	return mesh
