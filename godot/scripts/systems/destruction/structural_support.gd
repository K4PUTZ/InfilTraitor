## StructuralSupport — what has NO SUPPORT falls (ROOF_MASTER_PLAN R-D12, Director 2026-10-16: "todo elemento do mundo sem sustentação cai, independente da natureza
## ou do material"). PURE: it reads a `ClaimGrid` and answers; nothing here writes the world.
##
## SUPPORT (R-D12; G3 refines ruling 1, Director 2026-10-17: "cola lateral por material"): a standing voxel is HELD when a path of standing voxels (six faces) leads from it
## to the GROUND PLANE (or to a cell anchored by design). Contact UP and DOWN is free glue; each SIDEWAYS step costs 1 / `support_reach` of the material (concrete hangs
## 8 GU, wood 3, plywood 2, cardboard 1 GU; `MaterialResistanceTable.support_reach`) and a path may cost 1.0 in all: what hangs further than its material allows lets go.
## `is_grounded` below is the old full-glue question (the cloth's held rule); `unsupported` is the weighted one. A post whose foot a blast took is a chain with no end at the ground; a voxel left floating in the air has no chain at all.
## The walk is memoised across every voxel it meets, so a wall (thousands of voxels) is walked once; it goes downhill first (the way to the ground).
##
## G1 (the first stage) asks it about PROPS and posts only (`Room.schedule_structural_support`); G2 folds roofs and glass into the same walk, G3 walls.
class_name StructuralSupport
extends RefCounted

const NEIGHBOURS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## Whether the standing voxel at `start` is connected to the ground plane (`ground`: its level) through standing voxels. `skip` (Dictionary Vector3i -> true) names
## cells the walk must not enter (a roof's own voxels, when the question is what holds the ROOF). `memo` (Dictionary Vector3i -> bool) is shared between calls.
static func is_grounded(grid: ClaimGrid, start: Vector3i, skip: Dictionary, ground: int, memo: Dictionary) -> bool:
	if memo.has(start):
		return bool(memo[start])
	var seen: Dictionary = {start: true}
	var stack: Array[Vector3i] = [start]
	var found: bool = false
	while not stack.is_empty():
		var k: Vector3i = stack.pop_back()
		if k.z <= ground or (memo.has(k) and bool(memo[k])):
			found = true
			break
		for d: Vector3i in NEIGHBOURS:   ## level -1 is LAST so it is popped FIRST: the walk goes down
			var n: Vector3i = k + d
			if seen.has(n) or skip.has(n):
				continue
			var dmg: int = grid.damage_at(n)
			if dmg < 0 or dmg == Voxel.DamageState.DESTROYED:
				continue
			seen[n] = true
			stack.append(n)
	for k: Vector3i in seen:
		memo[k] = found
	return found


## The lateral budget, quantised: a path costs `BUDGET` in all; one sideways step costs `round(BUDGET / reach)`.
const BUDGET: int = 1920   ## divisible by every reach in use (6, 8, 12, 16, 24, 96): a step costs a whole number
## How far past the asked voxels the walk looks sideways (voxels): the longest reach there is (`DEFAULT_SUPPORT_REACH`) plus a margin. Standing cells on the window's rim are taken as grounded
## (the world was stable before the event: only what the event reached can have lost its support). Vertically the walk goes `UP_MARGIN` levels past the highest asked voxel.
const LATERAL_MARGIN: int = 100
const UP_MARGIN: int = 40

static var _step_cost_cache: Dictionary = {}   ## material id -> int


static func step_cost(material: String) -> int:
	if not _step_cost_cache.has(material):
		_step_cost_cache[material] = int(round(float(BUDGET) / MaterialResistanceTable.support_reach(material)))
	return int(_step_cost_cache[material])


## Among `seeds` (Array of Vector3i: standing voxels to ask about) the ones with no support: key -> how many steps they are from where something was just broken
## (`broken`: Dictionary Vector3i -> true, the cells destroyed by the event that asked), the order of a short cascade. A seed that is not standing is ignored.
## `report_all`: also name every other standing voxel the walk found around the seeds that is loose (the universal pass: a wall with its foot gone, not only the asked ones).
static func unsupported(grid: ClaimGrid, ground: int, seeds: Array, broken: Dictionary, report_all: bool = false) -> Dictionary:
	var loose: Dictionary = {}
	if seeds.is_empty():
		return loose
	var lo := Vector3i(1 << 30, 1 << 30, 0)
	var hi := Vector3i(-(1 << 30), -(1 << 30), 0)
	var top: int = ground
	for key: Vector3i in seeds:
		lo = Vector3i(mini(lo.x, key.x), mini(lo.y, key.y), 0)
		hi = Vector3i(maxi(hi.x, key.x), maxi(hi.y, key.y), 0)
		top = maxi(top, key.z)
	lo -= Vector3i(LATERAL_MARGIN, LATERAL_MARGIN, 0)
	hi += Vector3i(LATERAL_MARGIN, LATERAL_MARGIN, 0)
	top += UP_MARGIN
	## 1. discover the standing structure around the seeds (a cell at the ground, an anchored one or one on the window's rim is a SOURCE: nothing is expanded below it)
	var cost_of: Dictionary = {}   ## Vector3i -> step cost of its material (standing cells found)
	var empty: Dictionary = {}
	var sources: Array[Vector3i] = []
	var stack: Array[Vector3i] = []
	for key: Vector3i in seeds:
		if cost_of.has(key):
			continue
		var c: int = grid.standing_step_cost(key)
		if c < 0:
			continue
		cost_of[key] = c
		stack.append(key)
	var asked: Array[Vector3i] = []
	asked.assign(cost_of.keys())
	while not stack.is_empty():
		var k: Vector3i = stack.pop_back()
		if k.z <= ground or grid.anchored.has(k):
			sources.append(k)
			if k.z <= ground:
				continue
		for d: Vector3i in NEIGHBOURS:
			var n: Vector3i = k + d
			if cost_of.has(n) or empty.has(n):
				continue
			var c: int = grid.standing_step_cost(n)
			if c < 0:
				empty[n] = true
				continue
			cost_of[n] = c
			if n.x < lo.x or n.x > hi.x or n.y < lo.y or n.y > hi.y or n.z > top:
				sources.append(n)   ## the rim: assumed held
				continue
			stack.append(n)
	## 2. the cheapest sideways cost from a source to each cell (a bucket queue: costs are small integers)
	var dist: Dictionary = {}
	var buckets: Dictionary = {0: []}   ## cost -> cells, made on demand
	for k: Vector3i in sources:
		dist[k] = 0
		(buckets[0] as Array).append(k)
	for b in range(BUDGET + 1):
		if not buckets.has(b):
			continue
		var list: Array = buckets[b]
		var i: int = 0
		while i < list.size():
			var k: Vector3i = list[i]
			i += 1
			if int(dist[k]) < b:
				continue
			for d: Vector3i in NEIGHBOURS:
				var n: Vector3i = k + d
				if not cost_of.has(n):
					continue
				var nd: int = b if d.z != 0 else b + maxi(int(cost_of[k]), int(cost_of[n]))
				if nd <= BUDGET and nd < int(dist.get(n, BUDGET + 1)):
					dist[n] = nd
					if not buckets.has(nd):
						buckets[nd] = []
					(buckets[nd] as Array).append(n)
	for key: Vector3i in (cost_of.keys() if report_all else asked):
		if not dist.has(key):
			loose[key] = -1
	## the cascade: steps within the loose set from a voxel touching a broken cell (the ones with none start after the rest)
	var frontier: Array[Vector3i] = []
	for key: Vector3i in loose:
		for d: Vector3i in NEIGHBOURS:
			if broken.has(key + d):
				loose[key] = 0
				frontier.append(key)
				break
	var head: int = 0
	while head < frontier.size():
		var k: Vector3i = frontier[head]
		head += 1
		for d: Vector3i in NEIGHBOURS:
			var n: Vector3i = k + d
			if loose.has(n) and int(loose[n]) < 0:
				loose[n] = int(loose[k]) + 1
				frontier.append(n)
	var deepest: int = 0
	for key: Vector3i in loose:
		deepest = maxi(deepest, int(loose[key]))
	for key: Vector3i in loose:
		if int(loose[key]) < 0:
			loose[key] = deepest + 1
	return loose
