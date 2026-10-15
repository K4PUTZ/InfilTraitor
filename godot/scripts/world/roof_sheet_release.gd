## RoofSheetRelease — what a soft roof IS, to be let go: its voxels, what holds it, the walls it can hang against, and the sheet it becomes.
##
## ROOF_MASTER_PLAN v0.28. Pure reads of the room's state (the slab registry, the voxel store, the layout); nothing is written here. `Room.release_roof_sheet()`
## does the writing: it destroys the voxels this collects, flushes the board and starts the `SoftSheet3D` this describes. The supports are the SAME rule as
## `DetonationPlanBuilder._roof_islands` (a roof voxel is HELD when a standing voxel that is not part of the roof touches it on one of six faces): a roof
## resting on a wall's top, against a block, under another roof. Those columns become the sheet's pinned nodes; with none, the whole roof falls.
class_name RoofSheetRelease
extends RefCounted

const NEIGHBOURS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## The roof entity `roof` ({gu_cell, size, storeys, material}, the layout's own) as a sheet to release, or {} when it has nothing standing.
## Keys: voxels (Array of Voxel), columns (Dictionary Vector2i -> true), held (Dictionary Vector2i -> true), level (the roof's lowest level), x0, z0, w, d
## (voxel columns), material.
static func collect(room: Node, roof: Dictionary) -> Dictionary:
	var slabs: SlabRegistry = room._slab_registry
	var store: VoxelStore = VoxelStore.active
	if slabs == null or store == null:
		return {}
	var material: String = String(roof["material"])
	var origin: Vector2i = roof["gu_cell"]
	var size: Vector2i = roof["size"]
	var base_level: int = GeometryCoords.storey_level_base(int(roof["storeys"]))
	var voxels: Array = []
	var columns: Dictionary = {}
	var keys: Dictionary = {}
	var low: int = 1 << 30
	for dx in range(size.x):
		for dy in range(size.y):
			for level_offset in range(2):
				var slab: Slab = slabs.get_slab(Slab.make_id(origin + Vector2i(dx, dy), Slab.Role.CEILING, base_level + level_offset))
				if slab == null or slab.material != material or slab.pane_id != "":
					continue
				for v: Voxel in slab.voxels:
					if VoxelStore.damage_of(v) == Voxel.DamageState.DESTROYED:
						continue
					voxels.append(v)
					columns[Vector2i(v.grid_pos.x, v.grid_pos.y)] = true
					keys[Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)] = true
					low = mini(low, v.level)
	if voxels.is_empty():
		return {}
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for c: Vector2i in columns:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var grid: ClaimGrid = ClaimGrid.of_store(store)
	var held: Dictionary = {}
	var ground: int = room._voxel_board.ground_plane_level()
	var grounded: Dictionary = {}   ## Vector3i -> bool, shared by every candidate support (a wall is asked once per voxel, not once per roof voxel)
	for v: Voxel in voxels:
		var key := Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)
		for d: Vector3i in NEIGHBOURS:
			var n: Vector3i = key + d
			if keys.has(n):
				continue
			var other: Voxel = grid.voxel_at(n)
			if other != null and VoxelStore.damage_of(other) != Voxel.DamageState.DESTROYED and _is_grounded(grid, n, keys, ground, grounded):
				held[Vector2i(key.x, key.y)] = true
				break
	return {"voxels": voxels, "columns": columns, "held": held, "level": low, "x0": lo.x, "z0": lo.y, "w": hi.x - lo.x + 1, "d": hi.y - lo.y + 1, "material": material}


## A support HOLDS the roof only while it stands on the ground: a post whose foot a blast took is a stump of floating voxels still touching the roof, and
## it must not keep holding it. Walks the standing voxels connected to `start` (never the roof's own), downhill first, until one stands at the ground plane or in the floor (not above it); the verdict is memoised for every voxel the walk met, so the walls (thousands of voxels) are walked once.
static func _is_grounded(grid: ClaimGrid, start: Vector3i, roof_keys: Dictionary, ground: int, memo: Dictionary) -> bool:
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
		for d: Vector3i in NEIGHBOURS:   ## the order puts level -1 LAST so it is popped FIRST: the walk goes down
			var n: Vector3i = k + d
			if seen.has(n) or roof_keys.has(n):
				continue
			var other: Voxel = grid.voxel_at(n)
			if other == null or VoxelStore.damage_of(other) == Voxel.DamageState.DESTROYED:
				continue
			seen[n] = true
			stack.append(n)
	for k: Vector3i in seen:
		memo[k] = found
	return found


## The `SoftSheetSim` parameters for what `collect()` found. `ground_level` is the board's ground plane (a level is derived, never typed);
## `blocks` the layout's solid blocks, of which the ones within the cloth's reach become walls it cannot enter.
static func sim_params(info: Dictionary, row: Dictionary, ground_level: int, blocks: Array) -> Dictionary:
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var span_x: float = float(int(info["w"])) * unit
	var span_z: float = float(int(info["d"])) * unit
	var nx: int = SoftSheetPresets.nodes_for(span_x)
	var nz: int = SoftSheetPresets.nodes_for(span_z)
	var hx: float = span_x / float(nx - 1)
	var hz: float = span_z / float(nz - 1)
	## The cloth rests on the TOP of what held the roof (the roof's lowest face, plus the cloth's own thickness): at the roof's top face it floated one
	## voxel above the wall and showed a gap there (Director, 2026-10-16).
	var y_top: float = float(int(info["level"]) - ground_level) * unit + SoftSheetSim.CONTACT_MARGIN
	var origin := Vector3(float(int(info["x0"])) * unit, y_top, float(int(info["z0"])) * unit)
	var pins := PackedByteArray()
	pins.resize(nx * nz)
	for c: Vector2i in info["held"]:
		var cx: float = (float(c.x) + 0.5) * unit
		var cz: float = (float(c.y) + 0.5) * unit
		var i0: int = maxi(int(ceil((cx - 0.5 * hx - origin.x) / hx - 1.0e-6)), 0)
		var i1: int = mini(int(floor((cx + 0.5 * hx - origin.x) / hx + 1.0e-6)), nx - 1)
		var j0: int = maxi(int(ceil((cz - 0.5 * hz - origin.z) / hz - 1.0e-6)), 0)
		var j1: int = mini(int(floor((cz + 0.5 * hz - origin.z) / hz + 1.0e-6)), nz - 1)
		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				pins[i * nz + j] = 1
	var reach: float = maxf(span_x, span_z) + 1.0
	var boxes: Array = []
	for b: Dictionary in blocks:
		var gu: Vector2i = b["gu_cell"]
		var bs: Vector2i = b["size"]
		var box := AABB(Vector3(float(gu.x), 0.0, float(gu.y)), Vector3(float(bs.x), float(int(b["storeys"])), float(bs.y)))
		if box.position.x > origin.x + span_x + reach or box.end.x < origin.x - reach or box.position.z > origin.z + span_z + reach or box.end.z < origin.z - reach:
			continue
		boxes.append(box)
	return {"nx": nx, "nz": nz, "hx": hx, "hz": hz, "origin": origin, "material": row, "pins": pins, "floor_y": 0.0, "boxes": boxes}
