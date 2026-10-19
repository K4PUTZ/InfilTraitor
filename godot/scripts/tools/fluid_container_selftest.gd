## FluidContainer (2026-10-19) — a body of liquid takes the shape of what holds it, read from voxel columns: a pit fills wall to wall, a divider splits it,
## a raised pipe's bore pours down into the pit below (a fall), a grating's bars hold back a thick liquid, an unclosed container is cut and said, and a
## breached divider lets the liquid in after `refresh`. The worlds are synthetic (a set of solid voxels) laid out the way the game's are: the floor slabs at
## levels 78-79, a pit's bed at 79 - dig, the floor top at 80.
extends SceneTree

const ContainerClass = preload("res://godot/scripts/systems/fluid_container.gd")
const PlaneClass = preload("res://godot/scripts/systems/fluid_plane.gd")

const FLOOR: int = 80
var _failures: int = 0
var _solid: Dictionary = {}


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		print("  ✗ FAILED: %s" % label)
		_failures += 1


func _is_solid(x: int, y: int, level: int) -> bool:
	return _solid.has(Vector3i(x, y, level))


## The floor slabs over a box of GU, and a pit dug `dig` levels over `pit` (GU): its bed at FLOOR - dig - 1... the bed voxel is at 79 - dig.
func _world(box: Rect2i, pits: Array, dig: int = 4) -> void:
	_solid.clear()
	for x in range(box.position.x * 8, box.end.x * 8):
		for y in range(box.position.y * 8, box.end.y * 8):
			var in_pit: bool = false
			for pit: Rect2i in pits:
				if pit.has_point(Vector2i(x >> 3, y >> 3)):
					in_pit = true
			if in_pit:
				_solid[Vector3i(x, y, 79 - dig)] = true
			else:
				_solid[Vector3i(x, y, 78)] = true
				_solid[Vector3i(x, y, 79)] = true


func _container(cell: float, fluidity: float, seed_gu: Vector2, brim_level: int = FLOOR) -> Array:
	var box = ContainerClass.new()
	box.setup(Callable(self, "_is_solid"), 70, 110)
	box.flood(Vector2i(floori(seed_gu.x * 8.0), floori(seed_gu.y * 8.0)), brim_level)
	var info: Dictionary = {}
	var plane = box.build_plane(cell, fluidity, brim_level, info)
	return [box, plane, info]


func _init() -> void:
	print("\n== FLUID CONTAINER SELFTEST ==\n")
	## 1. a 2 x 2 GU pit dug 4 in a floor: the body is the pit, wall to wall
	_world(Rect2i(0, 0, 6, 6), [Rect2i(2, 2, 2, 2)])
	var made: Array = _container(0.5, 1.0, Vector2(3.0, 3.0))
	var box = made[0]
	var plane = made[1]
	var info: Dictionary = made[2]
	_check(box.region.size() == 256 and not box.leaked, "the flood fills the pit's 16 x 16 columns and stops at its walls (%d)" % box.region.size())
	_check(plane != null and plane.cols == 6 and plane.rows == 6 and (info["rect"] as Rect2) == Rect2(2, 2, 2, 2), "the plane is the pit: 4 x 4 cells + a rim, rect %s" % str(info.get("rect")))
	_check(int(info["base"]) == 76 and is_equal_approx(plane.surface_cap, 4.0), "its ground is the bed (base %d), it may stand up to the floor top (cap %.1f)" % [int(info["base"]), plane.surface_cap])
	var walls: int = 0
	for i in range(plane.cols * plane.rows):
		if plane.ground[i] >= PlaneClass.WALL:
			walls += 1
	_check(walls == 20, "the rim ring is walls, the inside is ground 0 (%d walls)" % walls)
	## 2. a divider (one voxel thick, to the floor top) across a 4 x 2 pit at x = 4 GU: a seed on the left fills the left half only
	_world(Rect2i(0, 0, 8, 6), [Rect2i(2, 2, 4, 2)])
	for y in range(16, 32):
		for lv in range(76, 80):
			_solid[Vector3i(32, y, lv)] = true
	made = _container(0.5, 1.0, Vector2(3.0, 3.0))
	box = made[0]
	info = made[2]
	_check(box.region.size() == 256 and (info["rect"] as Rect2) == Rect2(2, 2, 2, 2), "a divider splits the pit: the left body is the left 2 x 2 (%d columns, %s)" % [box.region.size(), str(info["rect"])])
	var right: Array = _container(0.5, 1.0, Vector2(5.0, 3.0))
	_check((right[0] as RefCounted).region.size() == 240 and (right[2]["rect"] as Rect2) == Rect2(4, 2, 2, 2), "and the right one its side, the divider's column excluded (%d columns)" % (right[0] as RefCounted).region.size())
	## 6. a breach: the divider goes; `refresh` lets the left body into the right half's columns
	var left_plane = made[1]
	var touched: Array = []
	for y in range(16, 32):
		for lv in range(76, 80):
			_solid.erase(Vector3i(32, y, lv))
		touched.append(Vector2i(32, y))
	var redone: int = box.refresh(left_plane, touched, FLOOR, info)
	_check(redone == 0, "a body does not grow past the box it was born in (the divider was outside the left body's grid: %d cell(s))" % redone)
	## 6b. a pillar standing in a pit (to the floor top) is a wall inside the body's grid; when it is destroyed, `refresh` turns its cells into ground
	_world(Rect2i(0, 0, 8, 6), [Rect2i(2, 2, 4, 2)])
	for x in range(32, 40):
		for y in range(16, 24):
			for lv in range(76, 80):
				_solid[Vector3i(x, y, lv)] = true
	made = _container(0.5, 1.0, Vector2(2.5, 2.5))
	box = made[0]
	plane = made[1]
	info = made[2]
	var pillar: Vector2i = plane.cell_of(Vector2(4.5, 2.5))
	var before_ground: float = plane.ground[plane.index(pillar.x, pillar.y)]
	touched = []
	for x in range(32, 40):
		for y in range(16, 24):
			for lv in range(76, 80):
				_solid.erase(Vector3i(x, y, lv))
			touched.append(Vector2i(x, y))
	redone = box.refresh(plane, touched, FLOOR, info)
	_check(before_ground >= PlaneClass.WALL and redone == 4 and plane.ground[plane.index(pillar.x, pillar.y)] == 0.0,
			"a pillar in the pit is a wall; destroyed, its 4 cells become ground through refresh (%d)" % redone)
	## 3. a RAISED pipe pouring into a pit: the bore's floor 2 over the floor top, its roof 12 over that; the seed is in the bore
	_world(Rect2i(0, 0, 6, 10), [Rect2i(2, 4, 2, 4)])
	for x in range(16, 32):
		for y in range(8, 32):
			var v: float = absf(float(x) + 0.5 - 24.0)
			if v > 6.0:
				for lv in range(80, 96):   ## the shell's sides, floor to top
					_solid[Vector3i(x, y, lv)] = true
			else:
				for lv in range(80, 82):   ## the shell under the bore
					_solid[Vector3i(x, y, lv)] = true
				_solid[Vector3i(x, y, 94)] = true   ## its roof
	made = _container(0.5, 1.0, Vector2(3.0, 1.5))
	box = made[0]
	plane = made[1]
	info = made[2]
	var bore_cell: Vector2i = plane.cell_of(Vector2(3.0, 2.0))
	var pit_cell: Vector2i = plane.cell_of(Vector2(3.0, 5.0))
	var bi: int = plane.index(bore_cell.x, bore_cell.y)
	var pi: int = plane.index(pit_cell.x, pit_cell.y)
	_check(plane.ground[pi] == 0.0 and is_equal_approx(plane.ground[bi], 6.0) and is_equal_approx(plane.ceiling[bi], 18.0),
			"the bore is read from the voxels: ground %.1f, roof %.1f over the pit's bed (ground %.1f)" % [plane.ground[bi], plane.ceiling[bi], plane.ground[pi]])
	var floor_beside: Vector2i = plane.cell_of(Vector2(1.5, 5.0))
	_check(not plane.in_grid(floor_beside.x, floor_beside.y) or plane.ground[plane.index(floor_beside.x, floor_beside.y)] >= PlaneClass.WALL,
			"the floor beside the pit is not water: the pool stops at the brim")
	plane.add_source(Rect2(2.5, 1.0, 1.0, 0.5), 2.0)
	var falls: int = 0
	for _t in range(8):
		plane.begin_tick()
		for _r in range(plane.rounds_per_tick()):
			plane.step_rounds(1)
			falls = maxi(falls, plane.falls().size())
	var in_pit: float = 0.0
	for i in plane.cells_in(Rect2(2, 4, 2, 4)):
		in_pit += plane.depth[i]
	_check(falls > 0 and in_pit > 1.0, "water poured in the bore falls into the pit (%d fall edge(s), %.2f voxels in the pit)" % [falls, in_pit])
	## 4. a grating's bars across a pit (every other column in one row): a thick liquid is held back there, water passes
	_world(Rect2i(0, 0, 6, 8), [Rect2i(2, 2, 2, 4)])
	for x in range(16, 32, 2):
		for lv in range(76, 80):
			_solid[Vector3i(x, 33, lv)] = true
	var thick: Array = _container(0.5, 0.35, Vector2(3.0, 2.5))
	var thin: Array = _container(0.5, 1.0, Vector2(3.0, 2.5))
	var tp = thick[1]
	var grate_cell: Vector2i = tp.cell_of(Vector2(3.0, 4.1))
	var gi: int = tp.index(grate_cell.x, grate_cell.y)
	_check(tp._perm[gi * 4 + 2] < 0.5 and (thin[1] as RefCounted)._perm[gi * 4 + 2] == 1.0, "the bars' cell holds back a thick liquid (%.2f), water passes it (1.0)" % tp._perm[gi * 4 + 2])
	_check((thick[0] as RefCounted).region.size() > 16 * 30, "the flood passes between the bars (%d columns)" % (thick[0] as RefCounted).region.size())
	## 5. a container that does not close: a brim over the floor top on an open floor is cut at the cap and said
	_world(Rect2i(0, 0, 12, 12), [])
	var open = ContainerClass.new()
	open.setup(Callable(self, "_is_solid"), 70, 110)
	open.max_columns = 2000
	open.flood(Vector2i(40, 40), FLOOR + 1)
	_check(open.leaked and open.region.size() == 2000, "an open floor under a brim above it floods to the cap and is flagged (%d columns)" % open.region.size())
	print("\n== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
