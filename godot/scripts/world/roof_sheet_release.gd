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
	var held_below: Dictionary = {}   ## column -> true: a support UNDER the roof (a post's head, a wall's top), no side to lock toward: the margin goes all round it
	var held_dirs: Dictionary = {}   ## column -> Array of Vector2i: the horizontal offsets at which a support stands (a wall BESIDE the roof; a post or wall top under it has none)
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
				if d.z < 0:
					held_below[Vector2i(key.x, key.y)] = true
				if d.z == 0:
					var dirs: Array = held_dirs.get(Vector2i(key.x, key.y), [])
					dirs.append(Vector2i(d.x, d.y))
					held_dirs[Vector2i(key.x, key.y)] = dirs
	return {"voxels": voxels, "columns": columns, "held": held, "held_dirs": held_dirs, "held_below": held_below, "level": low, "x0": lo.x, "z0": lo.y, "w": hi.x - lo.x + 1, "d": hi.y - lo.y + 1, "material": material}


## A support HOLDS the roof only while it stands on the ground (`StructuralSupport.is_grounded`, R-D12: the walk a post without a foot fails).
static func _is_grounded(grid: ClaimGrid, start: Vector3i, roof_keys: Dictionary, ground: int, memo: Dictionary) -> bool:
	return StructuralSupport.is_grounded(grid, start, roof_keys, ground, memo)


## ROOF_MASTER_PLAN v0.31 (Director, 2026-10-16: the cloth went THROUGH the wall's top; "falta a colisão entre os materiais"): what the cloth must not enter, read
## from the voxels that really stand around the roof (a wall's voxels reach past its GU, and its cap rows past that: the layout's boxes know only the GU)
## as an OCCUPANCY GRID the sim can answer by cell: a standing voxel that is not the roof's own, `pad` voxels around the roof's rectangle, from the ground
## plane to a little above the roof. A grid, not boxes: adjacent boxes with margins push a node from one into the next and it never gets out.
## Returns {bits (1 = solid), x0, y0 (voxel columns), l0 (a level), w, h, nl}.
static func solid_grid(info: Dictionary, ground_level: int, pad: int = 6) -> Dictionary:
	var store: VoxelStore = VoxelStore.active
	if store == null:
		return {}
	var roof: Dictionary = {}
	for v: Voxel in info["voxels"]:
		roof[Vector3i(v.grid_pos.x, v.grid_pos.y, v.level)] = true
	var x_lo: int = maxi(int(info["x0"]) - pad, store.x0)
	var x_hi: int = mini(int(info["x0"]) + int(info["w"]) + pad, store.x0 + store.w - 1)
	var y_lo: int = maxi(int(info["z0"]) - pad, store.y0)
	var y_hi: int = mini(int(info["z0"]) + int(info["d"]) + pad, store.y0 + store.h - 1)
	var l_lo: int = maxi(ground_level, store.l0)
	var l_hi: int = mini(int(info["level"]) + 2, store.l0 + store.nl - 1)
	var w: int = x_hi - x_lo + 1
	var h: int = y_hi - y_lo + 1
	var nl: int = l_hi - l_lo + 1
	var bits := PackedByteArray()
	bits.resize(w * h * nl)
	for level in range(l_lo, l_hi + 1):
		for y in range(y_lo, y_hi + 1):
			for x in range(x_lo, x_hi + 1):
				if store.occ[store.cell_index(x, y, level)] != 0 and not roof.has(Vector3i(x, y, level)):
					bits[((level - l_lo) * h + (y - y_lo)) * w + (x - x_lo)] = 1
	return {"bits": bits, "x0": x_lo, "y0": y_lo, "l0": l_lo, "w": w, "h": h, "nl": nl}


## The `SoftSheetSim` parameters for what `collect()` found. `ground_level` is the board's ground plane (a level is derived, never typed);
## `blocks` the layout's solid blocks, of which the ones within the cloth's reach become walls it cannot enter.
static func sim_params(info: Dictionary, row: Dictionary, ground_level: int, blocks: Array, solid: Dictionary = {}) -> Dictionary:
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
	## ROOF_MASTER_PLAN v0.33 (Director, 2026-10-16): the cloth does not start to bend AT the wall. Beside a wall that holds it, the nodes within
	## `SUPPORT_MARGIN` of the wall are locked too (flat, at the support's height), and the fall begins past them: the stretch that conflicted with the
	## concrete is the stretch that no longer bends.
	var held_dirs: Dictionary = info.get("held_dirs", {})
	var margin: float = SoftSheetPresets.SUPPORT_MARGIN
	for c: Vector2i in held_dirs:
		for dir in held_dirs[c]:
			var off: Vector2i = dir
			## A side support is a WALL only when the same side holds a run of columns (3 or more): the end face of a wall, or its corner, touches one or
			## two columns and must not lock a margin out along the wall's line, into the air (Director, 2026-10-16: the corner at the wall's end).
			var perp := Vector2i(0, 1) if off.x != 0 else Vector2i(1, 0)
			var run: int = 1
			for sign_ in [-1, 1]:
				var k: int = 1
				while held_dirs.has(c + perp * sign_ * k) and (held_dirs[c + perp * sign_ * k] as Array).has(off):
					run += 1
					k += 1
			if run < 3:
				continue
			var s: float = -1.0 if (off.x > 0 or off.y > 0) else 1.0   ## the sheet runs away from the wall
			if off.x != 0:
				var face_x: float = float(c.x + (1 if off.x > 0 else 0)) * unit
				var cz: float = (float(c.y) + 0.5) * unit
				var j0: int = maxi(int(ceil((cz - 0.5 * hz - origin.z) / hz - 1.0e-6)), 0)
				var j1: int = mini(int(floor((cz + 0.5 * hz - origin.z) / hz + 1.0e-6)), nz - 1)
				for i in range(nx):
					var away: float = s * (origin.x + float(i) * hx - face_x)
					if away <= margin + 1.0e-6:   ## no lower bound: a node BEHIND the wall's face (the sheet's rectangle starts a voxel before the first roof column) is held too
						for jj in range(j0, j1 + 1):
							pins[i * nz + jj] = 1
			else:
				var face_z: float = float(c.y + (1 if off.y > 0 else 0)) * unit
				var cx: float = (float(c.x) + 0.5) * unit
				var i0: int = maxi(int(ceil((cx - 0.5 * hx - origin.x) / hx - 1.0e-6)), 0)
				var i1: int = mini(int(floor((cx + 0.5 * hx - origin.x) / hx + 1.0e-6)), nx - 1)
				for j in range(nz):
					var away: float = s * (origin.z + float(j) * hz - face_z)
					if away <= margin + 1.0e-6:   ## no lower bound: a node BEHIND the wall's face (the sheet's rectangle starts a voxel before the first roof column) is held too
						for ii in range(i0, i1 + 1):
							pins[ii * nz + j] = 1
	## ... and all round a support UNDER the roof (a post's head, a wall's top): the cloth lies on it flat out to the margin, in every direction.
	var held_below: Dictionary = info.get("held_below", {})
	for c: Vector2i in held_below:
		## A ledge that is part of a wall's attachment (a side support within 2 voxels) already has its margin, beside the wall: all round it would put a
		## flat tab of cloth in the air past the wall's END (the corner Director pointed at, 2026-10-16: the vertical and the horizontal support counted twice).
		var part_of_a_wall: bool = false
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				if held_dirs.has(c + Vector2i(dx, dz)):
					part_of_a_wall = true
		if part_of_a_wall:
			continue
		var bx0: float = float(c.x) * unit
		var bz0: float = float(c.y) * unit
		for i in range(nx):
			var dx: float = maxf(maxf(bx0 - (origin.x + float(i) * hx), (origin.x + float(i) * hx) - (bx0 + unit)), 0.0)
			for j in range(nz):
				var dz: float = maxf(maxf(bz0 - (origin.z + float(j) * hz), (origin.z + float(j) * hz) - (bz0 + unit)), 0.0)
				if maxf(dx, dz) <= margin + 1.0e-6:
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
	return {"nx": nx, "nz": nz, "hx": hx, "hz": hz, "origin": origin, "material": row, "pins": pins, "floor_y": 0.0, "boxes": boxes,
		"solid": solid, "ground_level": ground_level}
