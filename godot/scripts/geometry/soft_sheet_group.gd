## SoftSheetGroup — the cloths one blast lets go, stepped TOGETHER and stitched where they touch.
##
## ROOF_MASTER_PLAN v0.43 (Director, 2026-10-17: "pano em contato com pano gruda (costura)"): a quitanda's roof and its three walls are one piece of cloth sewn along
## the seams, not four sheets that fall on their own. Each sheet keeps its own `SoftSheetSim` (a grid, its own banded factor); the group steps them all, and after
## every step projects the SEAMS: a boundary node of one sheet is tied to the nearest point of another sheet's boundary (a node, or a point between two), so the
## two edges stay one edge. Position-based, mass-weighted, a node that is pinned never moves; the correction is also given to the velocity, so a seam carries the
## momentum of what hangs from it. A seam is a Gauss-Seidel coupling between solves, not part of one: it lags by a fraction of a step, which the stiff stitching
## and two relaxation rounds keep below a centimetre.
##
## THE WORKER lives here (it used to live in `SoftSheet3D`): ONE long task on the `WorkerThreadPool` steps the whole group back to back for as long as real time is
## owed and publishes a copy of every sheet's last step under a mutex; each `SoftSheet3D` draws its own sheet's copy. A lone sheet is a group of one.
class_name SoftSheetGroup
extends RefCounted

## How close (GU) a boundary node must be to another sheet's boundary to be sewn to it: the wall's plane is half a voxel inside the roof's edge, the roof rests a hair above.
static var SEAM_TOLERANCE: float = 0.14
static var SEAM_ROUNDS: int = 2

var sims: Array = []     ## SoftSheetSim
var seams: Array = []    ## {a: sim index of the node, nb: its node, c: sim index of the target sheet, k0, k1: the target's two nodes, t: where between them}

var _mutex: Mutex = Mutex.new()
var _task: int = -1
var _stop: bool = false
var _owed: int = 0
var _done: int = 0
var _usec: int = 0
var _worst: int = 0
var _settled: bool = false
var _pub_prev: Array = []
var _pub_pos: Array = []
var _acc: float = 0.0


func add(sim: SoftSheetSim) -> int:
	sims.append(sim)
	_pub_prev.append(sim.pos.duplicate())
	_pub_pos.append(sim.pos.duplicate())
	return sims.size() - 1


func index_of(sim: SoftSheetSim) -> int:
	return sims.find(sim)


## The nodes on the four edges of a sheet, in walking order round it (a closed polyline).
static func boundary_nodes(sim: SoftSheetSim) -> PackedInt32Array:
	var ring := PackedInt32Array()
	for i in range(sim.nx):
		ring.append(i * sim.nz)
	for j in range(1, sim.nz):
		ring.append((sim.nx - 1) * sim.nz + j)
	for i in range(sim.nx - 2, -1, -1):
		ring.append(i * sim.nz + sim.nz - 1)
	for j in range(sim.nz - 2, 0, -1):
		ring.append(j)
	return ring


static func _node(positions: PackedFloat64Array, n: int) -> Vector3:
	return Vector3(positions[n * 3], positions[n * 3 + 1], positions[n * 3 + 2])


## The closest point to `p` on the closed polyline `ring` (node indices into `positions`): {d, k0, k1, t}.
static func _nearest_on_ring(positions: PackedFloat64Array, ring: PackedInt32Array, p: Vector3) -> Dictionary:
	var best: Dictionary = {"d": 1.0e9, "k0": -1, "k1": -1, "t": 0.0}
	for r in range(ring.size()):
		var a: Vector3 = _node(positions, ring[r])
		var b: Vector3 = _node(positions, ring[(r + 1) % ring.size()])
		var ab: Vector3 = b - a
		var len_sq: float = ab.length_squared()
		var t: float = clampf((p - a).dot(ab) / maxf(len_sq, 1.0e-12), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * t)
		if d < float(best["d"]):
			best = {"d": d, "k0": ring[r], "k1": ring[(r + 1) % ring.size()], "t": t}
	return best


## Sews every sheet's boundary to the boundary of each EARLIER sheet it touches (the roof is added first, then the walls): from the positions the sheets have now.
func sew(tolerance: float = -1.0) -> int:
	var tol: float = SEAM_TOLERANCE if tolerance < 0.0 else tolerance
	seams.clear()
	for later in range(1, sims.size()):
		var sim_b: SoftSheetSim = sims[later]
		for earlier in range(later):
			var sim_a: SoftSheetSim = sims[earlier]
			var ring_a: PackedInt32Array = boundary_nodes(sim_a)
			for nb in boundary_nodes(sim_b):
				var hit: Dictionary = _nearest_on_ring(sim_a.pos, ring_a, _node(sim_b.pos, nb))
				if float(hit["d"]) <= tol:
					seams.append({"a": later, "nb": nb, "c": earlier, "k0": int(hit["k0"]), "k1": int(hit["k1"]), "t": float(hit["t"])})
	return seams.size()


## The nodes of a sheet being built (`initial` positions, `nx` x `nz`) that lie on the boundary of a sheet that STAYS where it is (`statics`, SoftSheetSim at rest): they are
## sewn to something that does not move, so they are pinned where they are. Sets those entries of `pins` to 1 and returns how many it added.
static func pin_to_statics(initial: PackedFloat64Array, nx: int, nz: int, pins: PackedByteArray, statics: Array, tolerance: float = -1.0) -> int:
	var tol: float = SEAM_TOLERANCE if tolerance < 0.0 else tolerance
	var added: int = 0
	var ring := PackedInt32Array()
	for i in range(nx):
		ring.append(i * nz)
	for j in range(1, nz):
		ring.append((nx - 1) * nz + j)
	for i in range(nx - 2, -1, -1):
		ring.append(i * nz + nz - 1)
	for j in range(nz - 2, 0, -1):
		ring.append(j)
	var box := AABB(_node(initial, 0), Vector3.ZERO)   ## where this sheet is: a static one that is nowhere near is not even looked at (a level with forty cloths)
	for n in range(nx * nz):
		box = box.expand(_node(initial, n))
	box = box.grow(tol)
	for other: SoftSheetSim in statics:
		var box_o := AABB(_node(other.pos, 0), Vector3.ZERO)
		for n in range(other.nx * other.nz):
			box_o = box_o.expand(_node(other.pos, n))
		if not box.intersects(box_o):
			continue
		var ring_o: PackedInt32Array = boundary_nodes(other)
		for n in ring:
			if pins[n] == 1:
				continue
			var hit: Dictionary = _nearest_on_ring(other.pos, ring_o, _node(initial, n))
			if float(hit["d"]) <= tol:
				pins[n] = 1
				added += 1
	return added


func step() -> void:
	for sim: SoftSheetSim in sims:
		sim.step()
	_stitch()


func _stitch() -> void:
	if seams.is_empty():
		return
	for _round in range(SEAM_ROUNDS):
		for seam: Dictionary in seams:
			var sa: SoftSheetSim = sims[int(seam["a"])]
			var sc: SoftSheetSim = sims[int(seam["c"])]
			var nb: int = int(seam["nb"])
			var k0: int = int(seam["k0"])
			var k1: int = int(seam["k1"])
			var t: float = float(seam["t"])
			var w_b: float = 0.0 if sa.pinned[nb] == 1 else 1.0 / sa._mass
			var w_0: float = 0.0 if sc.pinned[k0] == 1 else 1.0 / sc._mass
			var w_1: float = 0.0 if sc.pinned[k1] == 1 else 1.0 / sc._mass
			var denom: float = w_b + (1.0 - t) * (1.0 - t) * w_0 + t * t * w_1
			if denom < 1.0e-12:
				continue
			var pb: Vector3 = _node(sa.pos, nb)
			var q: Vector3 = (1.0 - t) * _node(sc.pos, k0) + t * _node(sc.pos, k1)
			var lam: Vector3 = (pb - q) / denom
			_nudge(sa, nb, -w_b * lam)
			_nudge(sc, k0, (1.0 - t) * w_0 * lam)
			_nudge(sc, k1, t * w_1 * lam)


## Moves a free node by `delta` and gives the move to its velocity (the seam carries momentum).
func _nudge(sim: SoftSheetSim, node: int, delta: Vector3) -> void:
	if sim.pinned[node] == 1:
		return
	var o: int = node * 3
	sim.pos[o] += delta.x
	sim.pos[o + 1] += delta.y
	sim.pos[o + 2] += delta.z
	var inv_dt: float = 1.0 / SoftSheetSim.STEP
	sim.vel[o] += delta.x * inv_dt
	sim.vel[o + 1] += delta.y * inv_dt
	sim.vel[o + 2] += delta.z * inv_dt


func is_settled() -> bool:
	for sim: SoftSheetSim in sims:
		if not sim.is_settled():
			return false
	return true


## The simulated time of the slowest sheet.
func sim_time() -> float:
	var t: float = 0.0
	for sim: SoftSheetSim in sims:
		t = maxf(t, sim.time)
	return t


# ---------------------------------------------------------------------------------------------------------------------------------
# the main-thread path (SOFT_SHEET_THREAD=0): whole steps for the time that passed, at most two a frame

func advance(delta: float) -> int:
	_acc += minf(delta, SoftSheetSim.STEP * float(SoftSheetSim.MAX_STEPS_PER_ADVANCE))
	var ran: int = 0
	while _acc >= SoftSheetSim.STEP and ran < SoftSheetSim.MAX_STEPS_PER_ADVANCE:
		step()
		_acc -= SoftSheetSim.STEP
		ran += 1
	return ran


func alpha() -> float:
	return clampf(_acc / SoftSheetSim.STEP, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------------------------------------------
# the worker

## Starts the worker once, however many sheets are revealed.
func start() -> void:
	if _task != -1:
		return
	_task = WorkerThreadPool.add_task(_worker_loop, false, "SoftSheetGroup")


func stop() -> void:
	if _task == -1:
		return
	_mutex.lock()
	_stop = true
	_mutex.unlock()
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1


## Real game time the sheets have lived: how many steps it has earned (every sheet reports the same clock; the largest wins).
func owe(seconds: float) -> void:
	_mutex.lock()
	_owed = maxi(_owed, int(seconds / SoftSheetSim.STEP))
	_mutex.unlock()


## {done, finished, prev: Array of PackedFloat64Array, pos: Array, usec, worst}: the last finished step, copied under the lock.
func snapshot() -> Dictionary:
	_mutex.lock()
	var out: Dictionary = {"done": _done, "finished": _settled, "prev": _pub_prev, "pos": _pub_pos, "usec": _usec, "worst": _worst}
	_mutex.unlock()
	return out


func _worker_loop() -> void:
	while true:
		_mutex.lock()
		var stop_now: bool = _stop
		var owed: bool = _done < _owed
		_mutex.unlock()
		if stop_now:
			return
		if not owed:
			OS.delay_usec(2000)
			continue
		var t0: int = Time.get_ticks_usec()
		step()
		var spent: int = Time.get_ticks_usec() - t0
		var prev: Array = []
		var pos: Array = []
		for sim: SoftSheetSim in sims:
			prev.append(sim.prev.duplicate())
			pos.append(sim.pos.duplicate())
		var settled_now: bool = is_settled()
		_mutex.lock()
		_pub_prev = prev
		_pub_pos = pos
		_done += 1
		_usec += spent
		_worst = maxi(_worst, spent)
		_settled = settled_now
		_mutex.unlock()
		if settled_now:
			return
