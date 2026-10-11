## GlassSupport — GLASS_MASTER_PLAN G-S1, G-D50 / G-D51 / G-D52 (Director, 2026-10-09): which surviving glass no longer stands.
##
## PURE: it reads the packed `VoxelStore` and returns claims; it writes nothing. `Room.schedule_glass_collapse()` stages the fall.
##
## THE RULE.
##   · G-D50 — a pane voxel stands when it is connected, through glass, to something that HOLDS it: a non-glass material touching
##     it in the pane's own plane (the floor under it, a frame, a wall, a band) — glass holds glass, cracked or pristine. A piece
##     connected to nothing falls: the floating remnants a second grenade left behind (2026-10-09).
##   · G-D51 — a glass column with nothing under it hangs off its neighbours for about ONE GU (`CANTILEVER_VOXELS`) from the nearest
##     held column; height adds pressure (`HEIGHT_PRESSURE` voxels of reach lost per level above the pane's bottom), and a hashed
##     jitter keeps the break line from being a ruler. Both sides count: a column held from neither side falls.
## THE MODEL. A 0-1 walk over the pane's voxels in its own plane: a VERTICAL step costs 0 (a column hangs from, or stands on, its own
## glass), a LATERAL step costs 1. Sources are the held voxels. A voxel's cost is how far, sideways, it is from a held column.
## Unreached, or past its own reach, it falls; the walk is redone on what is left until nothing more goes (a column that only stood
## through a falling one goes too).
## THE ORDER (G-D52): farthest from the support first, lower before higher — `score` = cost + DOWN_WEIGHT x levels below the top.
class_name GlassSupport

## One GU, in voxels: how far glass hangs sideways off the nearest held column. `static var` (Rule 1): a balance dial.
static var CANTILEVER_VOXELS: float = 8.0
## Voxels of sideways reach lost per level above the pane's lowest glass (one storey = 8 levels: -2.4 voxels at 0.3).
static var HEIGHT_PRESSURE: float = 0.3
## The hashed jitter of each voxel's reach, +-voxels (B4 FNV-1a on the base cell, so a rebuild picks the same line).
static var REACH_JITTER: float = 1.5
## A voxel nothing reaches scores as this far, so the disconnected pieces fall first.
const UNREACHED_COST: float = 1000.0
const DOWN_WEIGHT: float = 0.25
const MAX_PASSES: int = 4


## A copy of what the walk reads, taken on the main thread (cheap: a few packed-array copies) so `unsupported()` can run on the
## WorkerThreadPool while the game goes on: on the Moto the walk is several hundred ms, which must not land in a frame.
class Snap:
	var claims: int
	var pane: PackedByteArray
	var state: PackedByteArray
	var xyz: PackedInt32Array
	var owner: PackedInt32Array
	var occ: PackedByteArray
	var mat: PackedByteArray
	var glass_mat: PackedByteArray
	var x0: int
	var y0: int
	var l0: int
	var w: int
	var h: int
	var plane: int

	func cell_index(x: int, y: int, level: int) -> int:
		return ((level - l0) * h + (y - y0)) * w + (x - x0)


static func snapshot(store: VoxelStore) -> Snap:
	var s := Snap.new()
	s.claims = store.claims
	s.pane = store.pane.duplicate()
	s.state = store.state.duplicate()
	s.xyz = store.xyz.duplicate()
	s.owner = store.owner.duplicate()
	s.occ = store.occ.duplicate()
	s.mat = store.mat.duplicate()
	s.glass_mat.resize(store.material_ids.size())
	for i: int in range(store.material_ids.size()):
		s.glass_mat[i] = 1 if GlassMaterials.is_glass(store.material_ids[i]) else 0
	s.x0 = store.x0
	s.y0 = store.y0
	s.l0 = store.l0
	s.w = store.w
	s.h = store.h
	s.plane = store.plane
	return s


## Every visible glass PANE voxel that no longer stands, as [{"claim": int, "score": float}], highest score first (fall first).
## Pure on the snapshot: safe off the main thread.
static func unsupported(store: Snap) -> Array:
	if store == null:
		return []
	var glass_mat: PackedByteArray = store.glass_mat
	## The pane voxels by cell, each with its in-plane run step.
	var glass: Dictionary = {}   ## cell -> claim
	var run_step: Dictionary = {}   ## cell -> +-step along the pane
	var lo_level: int = 1 << 30
	for claim: int in range(store.claims):
		if store.pane[claim] == 0 or (store.state[claim] & 1) == 0:
			continue
		var k: int = claim * 3
		var cell: int = store.cell_index(store.xyz[k], store.xyz[k + 1], store.xyz[k + 2])
		if store.owner[cell] != claim:
			continue
		var face: int = int(store.pane[claim]) - 1
		glass[cell] = claim
		run_step[cell] = store.w if (face == 0 or face == 2) else 1
		lo_level = mini(lo_level, store.xyz[k + 2])
	if glass.is_empty():
		return []
	var falling: Dictionary = {}   ## cell -> score
	for _pass: int in range(MAX_PASSES):
		var cost: Dictionary = _walk(store, glass, run_step, glass_mat, falling)
		var more: int = 0
		for cell: int in glass:
			if falling.has(cell):
				continue
			var claim: int = glass[cell]
			var level: int = store.xyz[claim * 3 + 2]
			var c: float = float(cost.get(cell, UNREACHED_COST))
			if c < UNREACHED_COST and c <= _reach(store, claim, level - lo_level):
				continue
			falling[cell] = c
			more += 1
		if more == 0:
			break
	var top: int = -(1 << 30)
	for cell: int in falling:
		top = maxi(top, store.xyz[int(glass[cell]) * 3 + 2])
	var out: Array = []
	for cell: int in falling:
		var claim: int = glass[cell]
		out.append({"claim": claim, "score": float(falling[cell]) + DOWN_WEIGHT * float(top - store.xyz[claim * 3 + 2])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]) or (float(a["score"]) == float(b["score"]) and int(a["claim"]) < int(b["claim"])))
	return out


## The 0-1 walk: sideways cost from the nearest held voxel, through standing glass (`falling` excluded).
static func _walk(store: Snap, glass: Dictionary, run_step: Dictionary, glass_mat: PackedByteArray,
		falling: Dictionary) -> Dictionary:
	var cost: Dictionary = {}
	var front: Array = []   ## cost 0 frontier, then cost 1 appended to `next`
	for cell: int in glass:
		if falling.has(cell):
			continue
		if _held(store, cell, int(run_step[cell]), glass_mat):
			cost[cell] = 0.0
			front.append(cell)
	var current: float = 0.0
	while not front.is_empty():
		var next: Array = []
		var i: int = 0
		while i < front.size():
			var cell: int = front[i]
			i += 1
			if float(cost[cell]) < current:
				continue
			var rs: int = run_step[cell]
			for step: int in [store.plane, -store.plane]:   ## vertical: free
				var n: int = cell + step
				if glass.has(n) and not falling.has(n) and (not cost.has(n) or float(cost[n]) > current):
					cost[n] = current
					front.append(n)
			for step: int in [rs, -rs]:   ## lateral: one
				var n: int = cell + step
				if glass.has(n) and not falling.has(n) and (not cost.has(n) or float(cost[n]) > current + 1.0):
					cost[n] = current + 1.0
					next.append(n)
		front = next
		current += 1.0
	return cost


## A voxel is HELD when a visible non-glass claim touches it in the pane's plane: below (the floor), above (a head), or either side.
static func _held(store: Snap, cell: int, rs: int, glass_mat: PackedByteArray) -> bool:
	for step: int in [-store.plane, store.plane, rs, -rs]:
		var n: int = cell + step
		if n < 0 or n >= store.occ.size() or store.occ[n] == 0:
			continue
		var o: int = store.owner[n]
		if o >= 0 and (store.state[o] & 1) == 1 and glass_mat[store.mat[o]] == 0:
			return true
	return false


## How far sideways this voxel may hang: one GU, less the height pressure, plus its hashed jitter.
static func _reach(store: Snap, claim: int, height: int) -> float:
	var k: int = claim * 3
	var h: int = FacadeSampler._fnv1a_hash("GLASSREACH:%d,%d,%d" % [store.xyz[k], store.xyz[k + 1], store.xyz[k + 2]])
	var jitter: float = (float(h % 1000) / 999.0 * 2.0 - 1.0) * REACH_JITTER
	return maxf(CANTILEVER_VOXELS - HEIGHT_PRESSURE * float(height) + jitter, 1.0)
