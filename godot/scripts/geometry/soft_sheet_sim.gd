## SoftSheetSim — a roof of cloth as a grid of nodes under gravity, as pure deterministic maths.
##
## ROOF_MASTER_PLAN v0.28 (the bending study, `tools/research/cloth_lab/`): one node per grid point, three springs (STRETCH keeps the
## lengths, SHEAR keeps the diagonals, BEND resists three nodes in a row leaving a straight line), solved with PROJECTIVE DYNAMICS
## (Bouaziz et al. 2014), implicit Euler. The bend energy `1/2 w |a - 2b + c|^2` is quadratic in the positions, so a stiff bend is solved
## exactly in a GLOBAL linear step (one fixed banded matrix, factored once); only the lengths are iterated, locally. XPBD was tried first and
## is WRONG for bending (a 65-node strip came out 60x too soft); the lab's `validate_pd.py` holds the proof, and the selftest holds the same
## two gates (a clamped strip against the exact discrete beam, a hung chain against the catenary).
##
## SPACE. World units are GU (1.0 = one game unit; the board voxel is 1/8), y up, `origin` = the world position of node (0, 0), nodes at
## `origin + (i * hx, 0, j * hz)` at rest (the sheet is flat and horizontal when it is released: a roof). Mass density is 1, so a node weighs
## `hx * hz` and `GRAVITY` is the only force. The material is ONE length, `lb` = the elastogravity length `(B / weight-per-area)^(1/3)`: canvas
## ~ 0.12 GU. NODES ARE COARSE (about one per 0.33 GU): a literal node per voxel costs ~0.5 s a step in GDScript; the skin (`SoftSheet3D`) draws
## the voxel resolution. No Godot object is touched here: it runs on any thread.
##
## FIXED STEPS (`STEP`, 1/30 s of SIMULATED time): `advance(delta)` runs whole steps, so the result at a given simulated time does not depend on
## the frame rate (the draw interpolates between the last two steps, `positions_lerped`). No randomness anywhere: the same sheet falls the same way.
class_name SoftSheetSim
extends RefCounted

## GU per second squared: the engine's own (`PropFragmentSim.GRAVITY`).
static var GRAVITY: float = 8.0
static var STEP: float = 1.0 / 30.0
## The local projections per step; 4 at STEP 1/30 against the lab's reference (12 at 1/60): RMS 0.07 GU on the awning (6: 0.06, 3: 0.08), and a
## step that costs ~25 ms on the Moto (6: 35 ms) where one step has 33 ms of simulated time to be paid in.
static var ITERATIONS: int = 4
const MAX_STEPS_PER_ADVANCE: int = 2
## A hard stop (simulated seconds): whatever still moves is called settled.
static var MAX_SIM_TIME: float = 12.0
## Settled = no node faster than this (GU/s) for `SETTLE_TIME` seconds.
static var SETTLE_SPEED: float = 0.08
static var SETTLE_TIME: float = 0.6
## How far above the floor / outside a box the cloth rests (its thickness), and how much of a node's sideways travel the floor takes.
static var CONTACT_MARGIN: float = 0.01
static var BOX_MARGIN: float = 0.02
static var FLOOR_FRICTION: float = 0.6

var nx: int = 0
var nz: int = 0
var hx: float = 0.125
var hz: float = 0.125
var origin: Vector3 = Vector3.ZERO
var time: float = 0.0
var floor_y: float = 0.0

## Per node, 3 floats (x, y, z) at index `(i * nz + j) * 3`.
var pos: PackedFloat64Array = PackedFloat64Array()
var prev: PackedFloat64Array = PackedFloat64Array()   ## the positions before the last step (for the interpolated draw)
var vel: PackedFloat64Array = PackedFloat64Array()
var pinned: PackedByteArray = PackedByteArray()

var _dt: float = 1.0 / 30.0
var _iterations: int = 6
var _gravity: float = 8.0
var _mass: float = 0.015625
var _drag: float = 1.0
var _boxes: Array = []   ## AABB, GU
var _acc: float = 0.0
var _quiet: float = 0.0
var _steps: int = 0

# constraints (every one is `w/2 |c_a x_a + c_b x_b (+ c_c x_c) - target|^2`)
var _ea: PackedInt32Array = PackedInt32Array()      ## edges: node a (the length is `x_a - x_b`)
var _eb: PackedInt32Array = PackedInt32Array()
var _ew: PackedFloat64Array = PackedFloat64Array()
var _er: PackedFloat64Array = PackedFloat64Array()  ## rest length
var _ta: PackedInt32Array = PackedInt32Array()      ## bend triples (a, b, c): `a - 2b + c` goes to zero
var _tb: PackedInt32Array = PackedInt32Array()
var _tc: PackedInt32Array = PackedInt32Array()
var _tw: PackedFloat64Array = PackedFloat64Array()

# the factored system, over the FREE nodes only
var _free_of: PackedInt32Array = PackedInt32Array()   ## node -> free index, -1 if pinned
var _free_nodes: PackedInt32Array = PackedInt32Array()
var _nf: int = 0
var _bw: int = 0
var _l: PackedFloat64Array = PackedFloat64Array()     ## banded Cholesky: row r holds columns r - bw .. r at `r * (bw + 1) + (c - r + bw)`
var _rhs_const: PackedFloat64Array = PackedFloat64Array()   ## the pinned nodes' share of the right-hand side (3 per free node), constant forever
var _xs: PackedFloat64Array = PackedFloat64Array()
var _rx: PackedFloat64Array = PackedFloat64Array()
var _ry: PackedFloat64Array = PackedFloat64Array()
var _rz: PackedFloat64Array = PackedFloat64Array()
var _inertia_x: PackedFloat64Array = PackedFloat64Array()
var _inertia_y: PackedFloat64Array = PackedFloat64Array()
var _inertia_z: PackedFloat64Array = PackedFloat64Array()


## `p`: nx, nz (ints >= 1), hx, hz (GU), origin (Vector3), material ({lb, k_stretch, k_shear, drag}), pins (PackedByteArray, 1 = held by
## a wall, size nx * nz; at least one), floor_y (GU, default 0), boxes (Array of AABB: the walls the cloth cannot enter).
## Optional: dt, iterations, gravity (a selftest compares against the lab's 1/60 and 12), initial (PackedFloat64Array, 3 per node: the start
## positions, when the sheet does not start flat on the grid).
func _init(p: Dictionary) -> void:
	nx = int(p["nx"])
	nz = int(p["nz"])
	hx = float(p["hx"])
	hz = float(p["hz"])
	origin = p["origin"]
	floor_y = float(p.get("floor_y", 0.0))
	_boxes = p.get("boxes", [])
	_dt = float(p.get("dt", STEP))
	_iterations = int(p.get("iterations", ITERATIONS))
	_gravity = float(p.get("gravity", GRAVITY))
	var row: Dictionary = p["material"]
	_drag = float(row.get("drag", 1.0))
	var n: int = nx * nz
	_mass = hx * hz
	pinned = p.get("pins", PackedByteArray())
	pinned.resize(n)
	pos.resize(n * 3)
	vel.resize(n * 3)
	for i in range(nx):
		for j in range(nz):
			var o: int = (i * nz + j) * 3
			pos[o] = origin.x + float(i) * hx
			pos[o + 1] = origin.y
			pos[o + 2] = origin.z + float(j) * hz
	## A sheet that starts somewhere else than flat (a selftest's chain 3.2 GU between pins for a 4.0 GU length; a roof that is not flat): the rest
	## LENGTHS stay `hx` / `hz`, only the start moves.
	if p.has("initial"):
		pos = p["initial"]
		assert(pos.size() == n * 3)
	prev = pos.duplicate()
	_build_constraints(float(row.get("k_stretch", 3000.0)), float(row.get("k_shear", 60.0)), _gravity * pow(float(row.get("lb", 0.12)), 3.0))
	_factor()


func node_index(i: int, j: int) -> int:
	return i * nz + j


func node_position(i: int, j: int) -> Vector3:
	var o: int = (i * nz + j) * 3
	return Vector3(pos[o], pos[o + 1], pos[o + 2])


## Runs whole steps for `delta` seconds of real time (at most `MAX_STEPS_PER_ADVANCE`: a hitch never spirals). The leftover is `alpha()`.
func advance(delta: float) -> int:
	_acc += minf(delta, _dt * float(MAX_STEPS_PER_ADVANCE))
	var ran: int = 0
	while _acc >= _dt and ran < MAX_STEPS_PER_ADVANCE:
		step()
		_acc -= _dt
		ran += 1
	return ran


## How far into the next step the draw is (0..1), for `positions_lerped`.
func alpha() -> float:
	return clampf(_acc / _dt, 0.0, 1.0)


func is_settled() -> bool:
	return _quiet >= SETTLE_TIME or time >= MAX_SIM_TIME


func steps_run() -> int:
	return _steps


## The positions `alpha` of the way from the last step's start to its end, 3 floats per node, into `out` (resized).
func positions_lerped(a: float, out: PackedFloat32Array) -> void:
	out.resize(pos.size())
	for k in range(pos.size()):
		out[k] = prev[k] + (pos[k] - prev[k]) * a


# ---------------------------------------------------------------------------------------------------------------------------------
# the step

func step() -> void:
	var n: int = nx * nz
	var dt: float = _dt
	var fall: float = dt * dt * _gravity
	var inertia: float = _mass / (dt * dt)
	prev = pos.duplicate()
	# the inertial prediction, and the first guess of the solve
	for node in range(n):
		var o: int = node * 3
		if pinned[node] == 1:
			_xs[o] = pos[o]
			_xs[o + 1] = pos[o + 1]
			_xs[o + 2] = pos[o + 2]
		else:
			_xs[o] = pos[o] + dt * vel[o]
			_xs[o + 1] = pos[o + 1] + dt * vel[o + 1] - fall
			_xs[o + 2] = pos[o + 2] + dt * vel[o + 2]
	for r in range(_nf):
		var o2: int = _free_nodes[r] * 3
		_inertia_x[r] = inertia * _xs[o2]
		_inertia_y[r] = inertia * _xs[o2 + 1]
		_inertia_z[r] = inertia * _xs[o2 + 2]
	for _it in range(_iterations):
		for r in range(_nf):
			_rx[r] = _inertia_x[r] + _rhs_const[r * 3]
			_ry[r] = _inertia_y[r] + _rhs_const[r * 3 + 1]
			_rz[r] = _inertia_z[r] + _rhs_const[r * 3 + 2]
		# the lengths: every edge goes to its rest length along its current direction
		for e in range(_ew.size()):
			var a: int = _ea[e] * 3
			var b: int = _eb[e] * 3
			var dx: float = _xs[a] - _xs[b]
			var dy: float = _xs[a + 1] - _xs[b + 1]
			var dz: float = _xs[a + 2] - _xs[b + 2]
			var len_sq: float = dx * dx + dy * dy + dz * dz
			var f: float = _ew[e] * _er[e] / sqrt(maxf(len_sq, 1.0e-24))
			var ra: int = _free_of[_ea[e]]
			var rb: int = _free_of[_eb[e]]
			if ra >= 0:
				_rx[ra] += f * dx
				_ry[ra] += f * dy
				_rz[ra] += f * dz
			if rb >= 0:
				_rx[rb] -= f * dx
				_ry[rb] -= f * dy
				_rz[rb] -= f * dz
		_solve3()
		for r in range(_nf):
			var o3: int = _free_nodes[r] * 3
			_xs[o3] = _rx[r]
			_xs[o3 + 1] = _ry[r]
			_xs[o3 + 2] = _rz[r]
	_collide()
	var damp: float = exp(-_drag * dt)
	var fastest: float = 0.0
	for node in range(n):
		if pinned[node] == 1:
			continue
		var o4: int = node * 3
		var vx: float = (_xs[o4] - pos[o4]) / dt * damp
		var vy: float = (_xs[o4 + 1] - pos[o4 + 1]) / dt * damp
		var vz: float = (_xs[o4 + 2] - pos[o4 + 2]) / dt * damp
		vel[o4] = vx
		vel[o4 + 1] = vy
		vel[o4 + 2] = vz
		fastest = maxf(fastest, vx * vx + vy * vy + vz * vz)
		pos[o4] = _xs[o4]
		pos[o4 + 1] = _xs[o4 + 1]
		pos[o4 + 2] = _xs[o4 + 2]
	time += dt
	_steps += 1
	_quiet = _quiet + dt if sqrt(fastest) < SETTLE_SPEED else 0.0


## The floor and the walls: a node inside is put back out along the way of least penetration; the floor also takes part of the sideways
## travel (the cloth does not skate).
func _collide() -> void:
	var lo_y: float = floor_y + CONTACT_MARGIN
	for node in range(nx * nz):
		if pinned[node] == 1:
			continue
		var o: int = node * 3
		if _xs[o + 1] < lo_y:
			_xs[o + 1] = lo_y
			_xs[o] += FLOOR_FRICTION * (prev[o] - _xs[o])
			_xs[o + 2] += FLOOR_FRICTION * (prev[o + 2] - _xs[o + 2])
		for box: AABB in _boxes:
			var lx: float = box.position.x - BOX_MARGIN
			var ly: float = box.position.y - BOX_MARGIN
			var lz: float = box.position.z - BOX_MARGIN
			var ux: float = box.end.x + BOX_MARGIN
			var uy: float = box.end.y + BOX_MARGIN
			var uz: float = box.end.z + BOX_MARGIN
			var x: float = _xs[o]
			var y: float = _xs[o + 1]
			var z: float = _xs[o + 2]
			if x <= lx or x >= ux or y <= ly or y >= uy or z <= lz or z >= uz:
				continue
			# penetration depth to each of the six faces; the smallest wins
			var best: float = x - lx
			var face: int = 0
			var d: float = ux - x
			if d < best:
				best = d
				face = 3
			d = y - ly
			if d < best:
				best = d
				face = 1
			d = uy - y
			if d < best:
				best = d
				face = 4
			d = z - lz
			if d < best:
				best = d
				face = 2
			d = uz - z
			if d < best:
				best = d
				face = 5
			match face:
				0: _xs[o] = lx
				1: _xs[o + 1] = ly
				2: _xs[o + 2] = lz
				3: _xs[o] = ux
				4: _xs[o + 1] = uy
				_: _xs[o + 2] = uz


# ---------------------------------------------------------------------------------------------------------------------------------
# the system: built once

func _build_constraints(k_stretch: float, k_shear: float, bend: float) -> void:
	for i in range(nx):
		for j in range(nz):
			var id: int = i * nz + j
			if i + 1 < nx:
				_add_edge(id, id + nz, k_stretch * hz / hx, hx)
			if j + 1 < nz:
				_add_edge(id, id + 1, k_stretch * hx / hz, hz)
			if i + 1 < nx and j + 1 < nz and k_shear > 0.0:
				var diagonal: float = sqrt(hx * hx + hz * hz)
				_add_edge(id, id + nz + 1, k_shear, diagonal)
				_add_edge(id + nz, id + 1, k_shear, diagonal)
			if bend > 0.0:
				if i + 2 < nx:
					_add_bend(id, id + nz, id + 2 * nz, bend * hz / (hx * hx * hx))
				if j + 2 < nz:
					_add_bend(id, id + 1, id + 2, bend * hx / (hz * hz * hz))


func _add_edge(a: int, b: int, w: float, rest: float) -> void:
	_ea.append(a)
	_eb.append(b)
	_ew.append(w)
	_er.append(rest)


func _add_bend(a: int, b: int, c: int, w: float) -> void:
	_ta.append(a)
	_tb.append(b)
	_tc.append(c)
	_tw.append(w)


## The banded Cholesky factor of (inertia + every spring's `w c c^T`) over the free nodes, and the pinned nodes' fixed share of the right-hand
## side. Nothing here moves again: the pinned nodes never do.
func _factor() -> void:
	var n: int = nx * nz
	_free_of.resize(n)
	_free_nodes = PackedInt32Array()
	for node in range(n):
		if pinned[node] == 1:
			_free_of[node] = -1
		else:
			_free_of[node] = _free_nodes.size()
			_free_nodes.append(node)
	_nf = _free_nodes.size()
	_bw = 2 * maxi(nz, 1)
	var width: int = _bw + 1
	_l.resize(_nf * width)
	_l.fill(0.0)
	_rhs_const.resize(_nf * 3)
	_rhs_const.fill(0.0)
	_xs.resize(n * 3)
	_rx.resize(_nf)
	_ry.resize(_nf)
	_rz.resize(_nf)
	_inertia_x.resize(_nf)
	_inertia_y.resize(_nf)
	_inertia_z.resize(_nf)
	var inertia: float = _mass / (_dt * _dt)
	for r in range(_nf):
		_l[r * width + _bw] += inertia
	for e in range(_ew.size()):
		_stamp([_ea[e], _eb[e]], [1.0, -1.0], _ew[e])
	for t in range(_tw.size()):
		_stamp([_ta[t], _tb[t], _tc[t]], [1.0, -2.0, 1.0], _tw[t])
	# banded Cholesky (lower): row i, columns i - bw .. i
	for i in range(_nf):
		var j0: int = maxi(0, i - _bw)
		for j in range(j0, i + 1):
			var s: float = _l[i * width + (j - i + _bw)]
			var k0: int = maxi(j0, maxi(0, j - _bw))
			for k in range(k0, j):
				s -= _l[i * width + (k - i + _bw)] * _l[j * width + (k - j + _bw)]
			if i == j:
				_l[i * width + _bw] = sqrt(maxf(s, 1.0e-30))
			else:
				_l[i * width + (j - i + _bw)] = s / _l[j * width + _bw]


## One spring `w/2 |sum c_k x_k - target|^2`: its matrix terms between free nodes, and (free, pinned) pairs go to the constant right-hand side.
func _stamp(ids: Array, coef: Array, w: float) -> void:
	var width: int = _bw + 1
	for p in range(ids.size()):
		var rp: int = _free_of[int(ids[p])]
		if rp < 0:
			continue
		for q in range(ids.size()):
			var cf: float = w * float(coef[p]) * float(coef[q])
			var rq: int = _free_of[int(ids[q])]
			if rq >= 0:
				if rq <= rp:
					_l[rp * width + (rq - rp + _bw)] += cf
			else:
				var o: int = int(ids[q]) * 3
				_rhs_const[rp * 3] -= cf * pos[o]
				_rhs_const[rp * 3 + 1] -= cf * pos[o + 1]
				_rhs_const[rp * 3 + 2] -= cf * pos[o + 2]


## L L^T x = rhs for the three coordinates at once (one pass over the factor): `_rx/_ry/_rz` in, the solution out.
func _solve3() -> void:
	var width: int = _bw + 1
	for i in range(_nf):
		var sx: float = _rx[i]
		var sy: float = _ry[i]
		var sz: float = _rz[i]
		var base: int = i * width + _bw - i
		for k in range(maxi(0, i - _bw), i):
			var lk: float = _l[base + k]
			sx -= lk * _rx[k]
			sy -= lk * _ry[k]
			sz -= lk * _rz[k]
		var d: float = _l[i * width + _bw]
		_rx[i] = sx / d
		_ry[i] = sy / d
		_rz[i] = sz / d
	for i in range(_nf - 1, -1, -1):
		var sx2: float = _rx[i]
		var sy2: float = _ry[i]
		var sz2: float = _rz[i]
		for k in range(i + 1, mini(_nf, i + _bw + 1)):
			var lk2: float = _l[k * width + (i - k + _bw)]
			sx2 -= lk2 * _rx[k]
			sy2 -= lk2 * _ry[k]
			sz2 -= lk2 * _rz[k]
		var d2: float = _l[i * width + _bw]
		_rx[i] = sx2 / d2
		_ry[i] = sy2 / d2
		_rz[i] = sz2 / d2
