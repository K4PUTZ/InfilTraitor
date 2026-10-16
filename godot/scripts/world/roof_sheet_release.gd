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
## Keys: claims (PackedInt32Array), keys (Dictionary Vector3i -> true: x, y, level), columns (Dictionary Vector2i -> true), held (Dictionary Vector2i -> true), level (the roof's lowest level), x0, z0, w, d
## (voxel columns), material.
## `ignore`: voxels (Vector3i x, y, level) to treat as already gone when deciding what holds the sheet (the other cloths one blast is letting go in the same batch).
## HANDLE-FREE (ROOF_MASTER_PLAN v0.45): the roof's voxels are CLAIMS of the store (`claims`, and `keys` Vector3i -> true), never `Voxel` objects: asking a slab for its
## `voxels` turns the whole container back into objects (~1 KB each on the Moto, kept for good: 14 MB for ten stalls). A `Voxel` handle is made only for what a release
## destroys (`Room._release_prepare`).
static func collect(room: Node, roof: Dictionary, ignore: Dictionary = {}) -> Dictionary:
	var slabs: SlabRegistry = room._slab_registry
	var store: VoxelStore = VoxelStore.active
	if slabs == null or store == null:
		return {}
	var material: String = String(roof["material"])
	var origin: Vector2i = roof["gu_cell"]
	var size: Vector2i = roof["size"]
	var base_level: int = GeometryCoords.storey_level_base(int(roof["storeys"]))
	var claims := PackedInt32Array()
	var columns: Dictionary = {}
	var keys: Dictionary = {}
	var low: int = 1 << 30
	for dx in range(size.x):
		for dy in range(size.y):
			for level_offset in range(2):
				var slab: Slab = slabs.get_slab(Slab.make_id(origin + Vector2i(dx, dy), Slab.Role.CEILING, base_level + level_offset))
				if slab == null or slab.material != material or slab.pane_id != "":
					continue
				var first: int = slab.claim_offset()
				if first < 0:
					continue
				for i in range(slab.voxel_count()):
					var claim: int = first + i
					if ((store.state[claim] >> 1) & 3) == Voxel.DamageState.DESTROYED:
						continue
					var k: int = claim * 3
					claims.append(claim)
					columns[Vector2i(store.xyz[k], store.xyz[k + 1])] = true
					keys[Vector3i(store.xyz[k], store.xyz[k + 1], store.xyz[k + 2])] = true
					low = mini(low, store.xyz[k + 2])
	if claims.is_empty():
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
	var walk_keys: Dictionary = keys
	if not ignore.is_empty():
		walk_keys = keys.duplicate()
		walk_keys.merge(ignore)
	for key: Vector3i in keys:
		for d: Vector3i in NEIGHBOURS:
			var n: Vector3i = key + d
			if keys.has(n) or ignore.has(n):
				continue
			var dmg: int = grid.damage_at(n)
			if dmg > -1 and dmg != Voxel.DamageState.DESTROYED and _is_grounded(grid, n, walk_keys, ground, grounded):
				held[Vector2i(key.x, key.y)] = true
				if d.z < 0:
					held_below[Vector2i(key.x, key.y)] = true
				if d.z == 0:
					var dirs: Array = held_dirs.get(Vector2i(key.x, key.y), [])
					dirs.append(Vector2i(d.x, d.y))
					held_dirs[Vector2i(key.x, key.y)] = dirs
	return {"claims": claims, "keys": keys, "columns": columns, "held": held, "held_dirs": held_dirs, "held_below": held_below, "level": low, "x0": lo.x, "z0": lo.y, "w": hi.x - lo.x + 1, "d": hi.y - lo.y + 1, "material": material}


## ROOF_MASTER_PLAN v0.43 — VERTICAL sheets. A wall of cloth or cardboard (a half-thickness panel, a block's one-layer shell) is a plane of voxels at one coordinate `w`
## along an axis, `nu` voxels long and `levels` tall. `wall_entities()` finds them once, at load: every standing voxel of a soft, non-glass `Slice`, grouped by (axis, w,
## material) and by 4-connectedness in (along, level); an entity keeps its ORIGINAL rectangle (a hole can split a wall in two: it is still one cloth). `collect_wall()` is what
## stands of it now, as an info dictionary with the roofs' keys (voxels, columns, held, level, x0, z0, w, d, material) plus `plane`: the cloth lattice's origin and one-voxel steps
## in GU. Its cells are (along, down) = Vector2i(u - u0, top level - level), so row 0 is the top; the sim's node `j` runs down the same way.
static func wall_entities(room: Node) -> Array:
	var out: Array = []
	var store: VoxelStore = VoxelStore.active
	if store == null:
		return out
	var cells: Dictionary = {}   ## Vector3i(axis, w, material id) -> {Vector2i(u, level) -> claim}
	var materials: Dictionary = {}
	for ci in range(store.container_count()):
		var slice: Slice = store.containers[ci] as Slice
		if slice == null or not SoftSheetPresets.has(slice.material) or slice.pane_id != "":
			continue
		var first: int = slice.claim_offset()
		var count: int = slice.voxel_count()
		if first < 0 or count == 0:
			continue
		var lo := Vector2i(1 << 30, 1 << 30)
		var hi := Vector2i(-(1 << 30), -(1 << 30))
		for claim in range(first, first + count):
			var k: int = claim * 3
			lo = Vector2i(mini(lo.x, store.xyz[k]), mini(lo.y, store.xyz[k + 1]))
			hi = Vector2i(maxi(hi.x, store.xyz[k]), maxi(hi.y, store.xyz[k + 1]))
		var axis: int = 0 if hi.x == lo.x else (1 if hi.y == lo.y else -1)   ## 0: the plane is x = const (the wall runs along y); 1: y = const
		if axis < 0:
			continue   ## a slice more than one voxel thick is not a sheet
		var mid: int = materials.get(slice.material, materials.size())
		materials[slice.material] = mid
		var key := Vector3i(axis, lo.x if axis == 0 else lo.y, mid)
		var plane: Dictionary = cells.get(key, {})
		for claim in range(first, first + count):
			var k: int = claim * 3
			plane[Vector2i(store.xyz[k + 1] if axis == 0 else store.xyz[k], store.xyz[k + 2])] = claim
		cells[key] = plane
	for key: Vector3i in cells:
		var plane: Dictionary = cells[key]
		var material: String = ""
		for m: String in materials:
			if int(materials[m]) == key.z:
				material = m
		var seen: Dictionary = {}
		for start: Vector2i in plane:
			if seen.has(start):
				continue
			var component: Array = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				component.append(c)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if plane.has(c + d) and not seen.has(c + d):
						seen[c + d] = true
						stack.append(c + d)
			var lo_c := Vector2i(1 << 30, 1 << 30)
			var hi_c := Vector2i(-(1 << 30), -(1 << 30))
			var claims := PackedInt32Array()
			for c: Vector2i in component:
				lo_c = Vector2i(mini(lo_c.x, c.x), mini(lo_c.y, c.y))
				hi_c = Vector2i(maxi(hi_c.x, c.x), maxi(hi_c.y, c.y))
				claims.append(int(plane[c]))
			out.append({"kind": "wall", "material": material, "axis": key.x, "w": key.y, "u0": lo_c.x, "nu": hi_c.x - lo_c.x + 1, "lo": lo_c.y, "hi": hi_c.y,
				"id": "wall|%d|%d|%d|%d|%d|%s" % [key.x, key.y, lo_c.x, lo_c.y, hi_c.y, material], "claims": claims})
	return out


static func collect_wall(room: Node, entity: Dictionary, ignore: Dictionary = {}) -> Dictionary:
	var store: VoxelStore = VoxelStore.active
	if store == null:
		return {}
	var axis: int = int(entity["axis"])
	var w: int = int(entity["w"])
	var u0: int = int(entity["u0"])
	var hi_level: int = int(entity["hi"])
	var claims := PackedInt32Array()
	var columns: Dictionary = {}
	var keys: Dictionary = {}
	var lo_v := Vector2i(1 << 30, 1 << 30)
	var hi_v := Vector2i(-(1 << 30), -(1 << 30))
	for claim: int in entity["claims"]:
		if ((store.state[claim] >> 1) & 3) == Voxel.DamageState.DESTROYED:
			continue
		var k: int = claim * 3
		var x: int = store.xyz[k]
		var y: int = store.xyz[k + 1]
		var level: int = store.xyz[k + 2]
		claims.append(claim)
		var u: int = y if axis == 0 else x
		columns[Vector2i(u - u0, hi_level - level)] = true
		keys[Vector3i(x, y, level)] = true
		lo_v = Vector2i(mini(lo_v.x, x), mini(lo_v.y, y))
		hi_v = Vector2i(maxi(hi_v.x, x), maxi(hi_v.y, y))
	if claims.is_empty():
		return {}
	var grid: ClaimGrid = ClaimGrid.of_store(store)
	var ground: int = room._voxel_board.ground_plane_level()
	var grounded: Dictionary = {}
	var held: Dictionary = {}
	var walk_keys: Dictionary = keys
	if not ignore.is_empty():
		walk_keys = keys.duplicate()
		walk_keys.merge(ignore)
	## What holds a hanging sheet: a standing, grounded voxel that is not its own beside it (a post, a perpendicular wall), in front of or behind it, or ABOVE it (a
	## roof, a rail). NOT below: the floor under the bottom row is where the cloth hangs to, not what holds it.
	var dirs: Array[Vector3i] = [Vector3i(0, 0, 1)]
	if axis == 0:
		dirs.append_array([Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)])
	else:
		dirs.append_array([Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)])
	for key: Vector3i in keys:
		for d: Vector3i in dirs:
			var n: Vector3i = key + d
			if keys.has(n) or ignore.has(n):
				continue
			var dmg: int = grid.damage_at(n)
			if dmg > -1 and dmg != Voxel.DamageState.DESTROYED and _is_grounded(grid, n, walk_keys, ground, grounded):
				var u: int = key.y if axis == 0 else key.x
				held[Vector2i(u - u0, hi_level - key.z)] = true
				break
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var top_y: float = float(hi_level + 1 - ground) * unit
	var nu: int = int(entity["nu"])
	var levels: int = hi_level - int(entity["lo"]) + 1
	var origin: Vector3
	var eu: Vector3
	if axis == 0:   ## x = const: the wall runs along voxel y, which is world z
		origin = Vector3((float(w) + 0.5) * unit, top_y, float(u0) * unit)
		eu = Vector3(0, 0, unit)
	else:
		origin = Vector3(float(u0) * unit, top_y, (float(w) + 0.5) * unit)
		eu = Vector3(unit, 0, 0)
	return {"kind": "wall", "claims": claims, "keys": keys, "columns": columns, "held": held, "held_dirs": {}, "held_below": {}, "level": hi_level, "x0": lo_v.x, "z0": lo_v.y,
		"w": hi_v.x - lo_v.x + 1, "d": hi_v.y - lo_v.y + 1, "material": String(entity["material"]), "nu": nu, "levels": levels, "axis": axis, "wc": w, "u0": u0,
		"plane": {"origin": origin, "eu": eu, "ev": Vector3(0, -unit, 0)}}


## The sim parameters of a wall (see `sim_params` for a roof): the lattice runs along the wall (`basis_u`) and DOWN it (`basis_v`); a node is pinned where a support
## stands against the cell it lies in. No locked margin: a post is one voxel, the cloth is tied to it, not laid on a wall's top.
static func sim_params_wall(info: Dictionary, row: Dictionary, ground_level: int, solid: Dictionary = {}) -> Dictionary:
	var unit: float = 1.0 / float(GeometryCoords.VOXELS_PER_UNIT_AXIS)
	var span_u: float = float(int(info["nu"])) * unit
	var span_v: float = float(int(info["levels"])) * unit
	var nx: int = SoftSheetPresets.nodes_for(span_u)
	var nz: int = SoftSheetPresets.nodes_for(span_v)
	var hx: float = span_u / float(nx - 1)
	var hz: float = span_v / float(nz - 1)
	var plane: Dictionary = info["plane"]
	var origin: Vector3 = plane["origin"]
	var eu: Vector3 = (plane["eu"] as Vector3).normalized()
	var pins := PackedByteArray()
	pins.resize(nx * nz)
	for c: Vector2i in info["held"]:
		var cu: float = (float(c.x) + 0.5) * unit
		var cv: float = (float(c.y) + 0.5) * unit
		var i0: int = maxi(int(ceil((cu - 0.5 * hx) / hx - 1.0e-6)), 0)
		var i1: int = mini(int(floor((cu + 0.5 * hx) / hx + 1.0e-6)), nx - 1)
		var j0: int = maxi(int(ceil((cv - 0.5 * hz) / hz - 1.0e-6)), 0)
		var j1: int = mini(int(floor((cv + 0.5 * hz) / hz + 1.0e-6)), nz - 1)
		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				pins[i * nz + j] = 1
	return {"nx": nx, "nz": nz, "hx": hx, "hz": hz, "origin": origin, "material": row, "pins": pins, "floor_y": 0.0, "boxes": [], "solid": solid, "ground_level": ground_level,
		"basis_u": eu, "basis_v": Vector3(0, -1, 0)}


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
	var roof: Dictionary = info["keys"]
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
	## A row of the store's grid that holds nothing (most of them: the air round a stall) is skipped in one call; the roof's own voxels are cleared afterwards.
	for level in range(l_lo, l_hi + 1):
		for y in range(y_lo, y_hi + 1):
			var base: int = store.cell_index(x_lo, y, level)
			if store.occ.slice(base, base + w).count(0) == w:
				continue
			var row: int = ((level - l_lo) * h + (y - y_lo)) * w - x_lo
			for x in range(x_lo, x_hi + 1):
				if store.occ[base + x - x_lo] != 0:
					bits[row + x] = 1
	for key: Vector3i in roof:
		if key.x >= x_lo and key.x <= x_hi and key.y >= y_lo and key.y <= y_hi and key.z >= l_lo and key.z <= l_hi:
			bits[((key.z - l_lo) * h + (key.y - y_lo)) * w + (key.x - x_lo)] = 0
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
