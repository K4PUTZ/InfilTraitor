## FluidContainer — a body of liquid takes the shape of WHAT HOLDS IT (Director, 2026-10-19: "o corpo liquido precisa se espalhar pelo recipiente, ao inves de
## ter uma dimensao pre-definida"; "tome as melhores decisoes com o objetivo de fazer o liquido funcionar por construcao e nao por definicao"). A map no longer
## types a rectangle, walls, roofs, a bore's floor or grates: it names the liquid, a SEED (a point in the pool, or where a pipe pours) and how high the liquid
## may stand (`brim`, voxels over the floor top, default 0: the floor's edge, i.e. a pit holds up to its rim). Everything else is READ from the voxels:
##
## - A voxel COLUMN's floor `F` is the top of the lowest run of solid voxels in it (a pit's bed, the floor slab, a pipe's lower shell); its `ceiling` is the
##   first solid over the air above `F` (a pipe's roof), if any within `CEILING_REACH` levels.
## - The body is a FLOOD over columns from the seed: a column joins when its floor is under the brim (the pool fills the pit, wall to wall) or when it lies
##   strictly DOWNHILL of a column already in (water runs down a chute, a pipe's bore onto the channel), or LEVEL with it under a roof (along a bore), and
##   always only where the two columns' AIR meets (water on one floor fits under the other's roof: a thin pipe shell keeps the bore apart from the floor under
##   the pipe's belly, though the columns touch). A pit
##   wall, a curb, a divider, a pipe's shell are simply columns whose floor stands too high: nothing types them.
## - The flood's columns are gathered into the plane's cells (`cell` GU, 4 x 4 columns at 0.5): a cell is in the body when any of its columns is; its ground
##   is the lowest of their floors, its ceiling the lowest of their roofs; a cell whose columns are partly blocked BETWEEN open ones (a grating's bars) lets
##   a liquid through by its fluidity (`FluidPlane.GRATE_*`), as the old typed grates did. Cells outside the body are walls: a body never spills (17/10 ruling).
##
## The plane it builds is an ordinary `FluidPlane` (ground and depth over the body's lowest floor `base`, `dig` = how far that lies under the floor top); the
## sheet, the falls and the rules draw and read it as before. When the world changes (a blast, an acid, a fall), `refresh` re-reads the columns of the
## touched cells, so a curb that goes lets the water in by construction. PURE: the world is a Callable(x, y, level) -> bool (solid), so a selftest builds one.
class_name FluidContainer
extends RefCounted

const FluidPlaneRef = preload("res://godot/scripts/systems/fluid_plane.gd")

const CEILING_REACH: int = 24          ## levels over a column's floor a roof may stand and still be a roof (a pipe's bore), 3 storeys
const MAX_COLUMNS: int = 65536         ## the flood's cap (FluidPlane.MAX_CELLS x 16): a container that does not close is cut and said
const NONE: int = -1073741824     ## "no such level"

var solid: Callable                    ## (x: int, y: int, level: int) -> bool
var low_level: int = 0                 ## the lowest level a column is read from
var high_level: int = 0                ## the highest
var per_gu: int = 8                    ## voxel columns a GU
var leaked: bool = false               ## the flood hit its cap: the container is not closed
var max_columns: int = MAX_COLUMNS
var region: Dictionary = {}            ## Vector2i column -> true: the flood
var _floor: Dictionary = {}            ## Vector2i column -> absolute floor level (the level just over the lowest solid run; NONE = no solid at all)
var _ceil: Dictionary = {}             ## Vector2i column -> absolute level of the roof's underside (NONE = open sky within reach)


func setup(solid_at: Callable, lowest: int, highest: int, columns_per_gu: int = 8) -> void:
	solid = solid_at
	low_level = lowest
	high_level = highest
	per_gu = columns_per_gu
	region.clear()
	_floor.clear()
	_ceil.clear()
	leaked = false


## The floor of a column: the level just over the top of its lowest run of solid voxels (NONE when the column holds nothing).
func floor_of(col: Vector2i) -> int:
	if _floor.has(col):
		return int(_floor[col])
	var f: int = NONE
	var c: int = NONE
	var lv: int = low_level
	while lv <= high_level and not bool(solid.call(col.x, col.y, lv)):
		lv += 1
	if lv <= high_level:
		while lv <= high_level and bool(solid.call(col.x, col.y, lv)):
			lv += 1
		f = lv
		var top: int = mini(high_level, f + CEILING_REACH)
		var up: int = f
		while up <= top and not bool(solid.call(col.x, col.y, up)):
			up += 1
		if up <= top:
			c = up
	_floor[col] = f
	_ceil[col] = c
	return f


func ceiling_of(col: Vector2i) -> int:
	floor_of(col)
	return int(_ceil[col])


## The flood from the seed column. `brim_level` is the absolute level the liquid may stand up to (the pool rule).
func flood(seed_col: Vector2i, brim_level: int) -> void:
	region.clear()
	leaked = false
	if floor_of(seed_col) == NONE:
		return
	var queue: Array[Vector2i] = [seed_col]
	region[seed_col] = true
	var head: int = 0
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		if region.size() >= max_columns:
			leaked = true
			break
		var c: Vector2i = queue[head]
		head += 1
		var fc: int = floor_of(c)
		for d: Vector2i in steps:
			var n: Vector2i = c + d
			if region.has(n):
				continue
			var fn: int = floor_of(n)
			if fn == NONE:
				continue
			## the two columns' AIR must meet: water standing on c's floor fits under n's roof, and n's floor lies under c's roof (a pipe's thin shell
			## separates the bore from the floor under its belly, though the two columns touch)
			var cn: int = ceiling_of(n)
			var cc: int = ceiling_of(c)
			if (cn != NONE and fc >= cn) or (cc != NONE and fn >= cc):
				continue
			var joins: bool = fn < brim_level or fn < fc or (fn == fc and cn != NONE and cc != NONE)
			if joins:
				region[n] = true
				queue.append(n)


## The plane of the flood: cells of `cell_gu`, one rim ring of walls, ground and ceilings over the body's lowest floor. Returns null for an empty flood.
## Also answers `base` (the absolute level of the lowest floor: ground 0) and `rect` (the body's cells, raw GU) through `info`.
func build_plane(cell_gu: float, fluidity: float, brim_level: int, info: Dictionary) -> RefCounted:
	if region.is_empty():
		return null
	var cols_per_cell: int = maxi(int(round(cell_gu * float(per_gu))), 1)
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	var base: int = 1 << 30
	for col: Vector2i in region:
		var cell := Vector2i(floori(float(col.x) / float(cols_per_cell)), floori(float(col.y) / float(cols_per_cell)))
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
		base = mini(base, floor_of(col))
	var width: int = hi.x - lo.x + 1 + 2
	var height: int = hi.y - lo.y + 1 + 2
	var size_gu: float = float(cols_per_cell) / float(per_gu)
	var plane = FluidPlaneRef.new()
	var origin := Vector2(float(lo.x - 1), float(lo.y - 1)) * size_gu
	plane.setup(width, height, size_gu, origin, fluidity)
	plane.ground.fill(FluidPlaneRef.WALL)
	plane.surface_cap = float(brim_level - base)
	info["base"] = base
	info["cols_per_cell"] = cols_per_cell
	info["rect"] = Rect2(Vector2(float(lo.x), float(lo.y)) * size_gu, Vector2(float(width - 2), float(height - 2)) * size_gu)
	for r in range(1, height - 1):
		for c in range(1, width - 1):
			_read_cell(plane, c, r, Vector2i(lo.x - 1 + c, lo.y - 1 + r), cols_per_cell, base)
	return plane


## One cell from its columns (see the header): in the body when any column is in the flood; ground = their lowest floor; ceiling = their lowest roof; a
## partly blocked cell (a column NOT in the flood with flood columns on both sides of it, along x or y) is a grating.
func _read_cell(plane: RefCounted, c: int, r: int, cell: Vector2i, cols_per_cell: int, base: int) -> void:
	var i: int = plane.index(c, r)
	var g: int = 1 << 30
	var roof: int = 1 << 30
	var inside: int = 0
	var bars: int = 0
	for dy in range(cols_per_cell):
		for dx in range(cols_per_cell):
			var col := Vector2i(cell.x * cols_per_cell + dx, cell.y * cols_per_cell + dy)
			if region.has(col):
				inside += 1
				g = mini(g, floor_of(col))
				var cc: int = ceiling_of(col)
				if cc != NONE:
					roof = mini(roof, cc)
			elif (region.has(col + Vector2i(1, 0)) and region.has(col - Vector2i(1, 0))) or (region.has(col + Vector2i(0, 1)) and region.has(col - Vector2i(0, 1))):
				bars += 1
	if inside == 0:
		plane.ground[i] = FluidPlaneRef.WALL
		return
	plane.ground[i] = minf(float(g - base), FluidPlaneRef.WALL - 0.01)
	plane.ceiling[i] = float(roof - base) if roof < (1 << 30) else 1.0e9
	var pass_fraction: float = 1.0
	if bars > 0:
		pass_fraction = clampf((plane.fluidity - FluidPlaneRef.GRATE_MIN_FLUIDITY) / (FluidPlaneRef.GRATE_FULL_FLUIDITY - FluidPlaneRef.GRATE_MIN_FLUIDITY), 0.0, 1.0)
	plane.set_cell_pass(i, pass_fraction)


## The world changed under these voxel columns (a blast, an acid, a fall): their floors and roofs are read again, a column now under the brim next to the body
## joins it (a breached curb), and every cell holding one of them is rebuilt. Only inside the plane's grid: a body does not grow past the box it was born in.
func refresh(plane: RefCounted, columns: Array, brim_level: int, info: Dictionary) -> int:
	var cols_per_cell: int = int(info["cols_per_cell"])
	var base: int = int(info["base"])
	var origin_cell := Vector2i(floori(round(plane.origin.x * float(per_gu)) / float(cols_per_cell)), floori(round(plane.origin.y * float(per_gu)) / float(cols_per_cell)))
	var cells: Dictionary = {}
	for col: Vector2i in columns:
		_floor.erase(col)
		_ceil.erase(col)
		var cell := Vector2i(floori(float(col.x) / float(cols_per_cell)), floori(float(col.y) / float(cols_per_cell))) - origin_cell
		if cell.x >= 1 and cell.y >= 1 and cell.x <= plane.cols - 2 and cell.y <= plane.rows - 2:
			cells[cell] = true
	if cells.is_empty():
		return 0
	## a column freed under the brim beside the body joins it (a few passes: a breach a few voxels wide)
	for _pass in range(4):
		var grew: bool = false
		for col: Vector2i in columns:
			if region.has(col):
				if floor_of(col) == NONE:
					region.erase(col)
				continue
			var f: int = floor_of(col)
			if f != NONE and f < brim_level:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if region.has(col + d):
						region[col] = true
						grew = true
						break
		if not grew:
			break
	plane.finish_tick()
	for cell: Vector2i in cells:
		_read_cell(plane, cell.x, cell.y, cell + origin_cell, cols_per_cell, base)
	plane.mark_ground_changed()
	return cells.size()
