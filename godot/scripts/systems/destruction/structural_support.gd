## StructuralSupport — what has NO SUPPORT falls (ROOF_MASTER_PLAN R-D12, Director 2026-10-16: "todo elemento do mundo sem sustentação cai, independente da natureza
## ou do material"). PURE: it reads a `ClaimGrid` and answers; nothing here writes the world.
##
## SUPPORT = full glue (R-D12 ruling 1): a standing voxel is HELD when a path of standing voxels (six faces) leads from it to the GROUND PLANE, whatever the material
## of each. A post whose foot a blast took is a chain with no end at the ground; a voxel left floating in the air has no chain at all.
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


## Among `seeds` (Array of Vector3i: standing voxels to ask about) the ones with no support: key -> how many steps they are from where something was just broken
## (`broken`: Dictionary Vector3i -> true, the cells destroyed by the event that asked), the order of a short cascade. A seed that is not standing is ignored.
static func unsupported(grid: ClaimGrid, ground: int, seeds: Array, broken: Dictionary) -> Dictionary:
	var memo: Dictionary = {}
	var loose: Dictionary = {}
	for key: Vector3i in seeds:
		var dmg: int = grid.damage_at(key)
		if dmg < 0 or dmg == Voxel.DamageState.DESTROYED:
			continue
		if not is_grounded(grid, key, {}, ground, memo):
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
