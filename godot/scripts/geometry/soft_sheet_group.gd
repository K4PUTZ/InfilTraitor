## SoftSheetGroup — the cloths one blast lets go, stepped TOGETHER and stitched where they touch.
##
## ROOF_MASTER_PLAN v0.43 (Director, 2026-10-17: "pano em contato com pano gruda (costura)"): a quitanda's roof and its three walls are one piece of cloth sewn along
## the seams, not four sheets that fall on their own. Each sheet keeps its own `SoftSheetSim` (a grid, its own banded factor); the group steps them all, and after
## drives the SEAMS: a boundary node of a later sheet (a wall's top edge) is tied to the nearest point of an earlier sheet's boundary (the roof's rim), so the two edges stay
## one edge. A seam is ONE-WAY: the earlier sheet is the master, the later sheet's sewn nodes are KINEMATIC (`SoftSheetSim.make_kinematic`: pinned in its solve, moved here before
## every step), so it hangs from the rim instead of fighting it and a roof and its walls settle together. The wall's weight does not load the roof.
##
## THE WORKER lives here (it used to live in `SoftSheet3D`): ONE long task on the `WorkerThreadPool` steps the whole group back to back for as long as real time is
## owed and publishes a copy of every sheet's last step under a mutex; each `SoftSheet3D` draws its own sheet's copy. A lone sheet is a group of one.
class_name SoftSheetGroup
extends RefCounted

## How close (GU) a boundary node must be to another sheet's boundary to be sewn to it: the wall's plane is half a voxel inside the roof's edge, the roof rests a hair above.
static var SEAM_TOLERANCE: float = 0.14

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
	var driven: Dictionary = {}   ## sim index -> {node: true}
	for later in range(1, sims.size()):
		var sim_b: SoftSheetSim = sims[later]
		for earlier in range(later):
			var sim_a: SoftSheetSim = sims[earlier]
			var ring_a: PackedInt32Array = boundary_nodes(sim_a)
			for nb in boundary_nodes(sim_b):
				var hit: Dictionary = _nearest_on_ring(sim_a.pos, ring_a, _node(sim_b.pos, nb))
				if float(hit["d"]) <= tol and sim_b.pinned[nb] != 1 and not (driven.get(later, {}) as Dictionary).has(nb):
					seams.append({"a": later, "nb": nb, "c": earlier, "k0": int(hit["k0"]), "k1": int(hit["k1"]), "t": float(hit["t"])})
					var nodes: Dictionary = driven.get(later, {})
					nodes[nb] = true
					driven[later] = nodes
	## The sewn nodes of a later sheet are driven by the earlier one: pinned in its solve, moved here (`_drive`).
	for later: int in driven:
		var list := PackedInt32Array()
		for n in (driven[later] as Dictionary):
			list.append(int(n))
		(sims[later] as SoftSheetSim).make_kinematic(list)
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
	for i in range(sims.size()):
		_drive(i)
		(sims[i] as SoftSheetSim).step()
		_drive_prev(i)


## Writes the sewn nodes of sheet `i` where their masters are (the earlier sheets, already stepped this round) and gives them the master's velocity. A seam is ONE-WAY, the sheet added
## first (the roof) drives a later one (a wall's top edge): tying both ends to each other, position-based or in the solve, made two stiff sheets of unequal mass ring against each
## other at 3-5 GU/s for ever. A wall's weight does not load the roof's rim: a seam that follows is better than one that fights.
func _drive(i: int) -> void:
	for seam: Dictionary in seams:
		if int(seam["a"]) != i:
			continue
		var sa: SoftSheetSim = sims[i]
		var sc: SoftSheetSim = sims[int(seam["c"])]
		var t: float = float(seam["t"])
		var k0: int = int(seam["k0"])
		var k1: int = int(seam["k1"])
		var q: Vector3 = (1.0 - t) * _node(sc.pos, k0) + t * _node(sc.pos, k1)
		var o: int = int(seam["nb"]) * 3
		sa.pos[o] = q.x
		sa.pos[o + 1] = q.y
		sa.pos[o + 2] = q.z


## After the step the driven nodes' `prev` follows their master's, so the draw interpolates the seam like the roof it hangs from.
func _drive_prev(i: int) -> void:
	for seam: Dictionary in seams:
		if int(seam["a"]) != i:
			continue
		var sa: SoftSheetSim = sims[i]
		var sc: SoftSheetSim = sims[int(seam["c"])]
		var t: float = float(seam["t"])
		var q: Vector3 = (1.0 - t) * _node(sc.prev, int(seam["k0"])) + t * _node(sc.prev, int(seam["k1"]))
		var o: int = int(seam["nb"]) * 3
		sa.prev[o] = q.x
		sa.prev[o + 1] = q.y
		sa.prev[o + 2] = q.z


## The whole group, back to back, until nothing moves faster than `speed` GU/s for `hold` seconds or `max_seconds` of simulated time (a cloth laid down again after a
## checkpoint: the sheets let go together settle together, seams and all). No Godot object is touched: a worker may run it. Returns the steps run.
func settle_now(max_seconds: float = 10.0, speed: float = 0.10, hold: float = 0.4) -> int:
	var run: int = 0
	var quiet: float = 0.0
	while sim_time() < max_seconds:
		step()
		run += 1
		var fastest: float = 0.0
		for sim: SoftSheetSim in sims:
			fastest = maxf(fastest, sim._fastest)
		quiet = quiet + SoftSheetSim.STEP if fastest < speed else 0.0
		if quiet >= hold:
			break
	for sim: SoftSheetSim in sims:
		for k in range(sim.vel.size()):
			sim.vel[k] = 0.0
		sim.prev = sim.pos.duplicate()
	return run


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
