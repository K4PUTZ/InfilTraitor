## FluidPlane — the gameplay TRUTH of a body of liquid: a grid of cells, each with a ground height and a depth, advanced a fixed number of
## rounds per TIC (a turn). M6 F1 (`MATERIALS_MASTER_PLAN` §6). PURE: no node, no store, no randomness; the same inputs give the same
## depths, so a prediction can replay it (`PREDICTION_MASTER_PLAN`) and a selftest can pin it.
##
## It is a height-field with MOMENTUM ("virtual pipes", Mei et al. 2007): each cell keeps four outflows (to +x, -x, +y, -y) that carry over
## from round to round, accelerate with the difference in surface height `H = ground + depth` and are damped by friction; a cell never gives
## away more than it holds. A wave therefore TRAVELS (a channel fills from its source toward its drain over several turns) instead of the slow
## diffusion of a plain equalising rule. `fluidity` (0..1, a liquid's `gameplay.fluidity`) is the whole difference between water and tar: it
## sets the acceleration and the friction, and below `GRATE_MIN_FLUIDITY` a GRATE blocks the liquid (the thin ones pass).
##
## UNITS. Depth and ground are in VOXELS of height (1 voxel = 1/8 GU; a curb two voxels high is `ground = 2`). A cell is `cell_gu` GU wide
## (0.25 = two voxels, so a curb rail is exactly one cell). A cell with `ground >= WALL` is solid: nothing enters it. The OUTER ring of the
## grid is the rim of the body: its cells have a ground (a curb), hold depth only above it, and anything they hold SPILLS out of the body every
## round (`spilled`), so a body whose level reaches its rim overflows instead of rising forever.
##
## It never writes the `VoxelStore` (rule 8) and a level is data the caller derives (rule 9).
class_name FluidPlane
extends RefCounted

const WALL: float = 8.0               ## a ground at or above this is a wall (a storey is 8 voxels)
const ROUNDS_PER_TICK: int = 24   ## at a 0.25 GU cell; see `rounds_per_tick()`
const GRATE_MIN_FLUIDITY: float = 0.2  ## a thinner liquid than this does not cross a grate
const GRATE_FULL_FLUIDITY: float = 0.8 ## from here on a grate costs the liquid nothing

var cols: int = 0
var rows: int = 0
var cell_gu: float = 0.25
var origin: Vector2 = Vector2.ZERO    ## the GU position of the grid's corner (cell 0, 0)
var fluidity: float = 1.0
var ground: PackedFloat32Array = PackedFloat32Array()
var depth: PackedFloat32Array = PackedFloat32Array()
var ceiling: PackedFloat32Array = PackedFloat32Array()   ## the height of a roof over the cell (a pipe's bore); a source stops pushing into a full cell
var spilled: float = 0.0              ## total depth that went over the rim since the start (a breach / overflow counter)
var _flux: PackedFloat32Array = PackedFloat32Array()    ## 4 per cell: +x, -x, +y, -y
var _perm: PackedFloat32Array = PackedFloat32Array()    ## 4 per cell: how much of an outflow a grate lets through (0..1)
var _sources: Array = []              ## {"cells": PackedInt32Array, "rate": float} depth added per cell per TIC
var _sinks: Array = []
var committed: PackedFloat32Array = PackedFloat32Array()   ## the depths the RULES read: the state after the last COMPLETE tick, changed only at a tick's start (never by frame timing)
var dig: float = 0.0   ## voxels the body's bed lies BELOW the floor top (a dug channel, `FloorOpenings` `dig`): ground and depth are measured from the bed, and the sheet is drawn `dig` lower
var surface_cap: float = 1.0e9   ## the highest the water may be DRAWN (voxels): the curbs that hold it. The depth under a pipe's roof (a source pushing into the bore) can stand higher than the curb outside; the sheet must not, or it hangs over the side (Director, 2026-10-18)
var threaded: bool = false    ## true: a tick's rounds run on a worker thread (`WorkerThreadPool`); the sheet reads the live depths while they change (a torn read is a pixel of water for a frame)
var rounds_scale: float = 1.0 ## a THICK liquid needs fewer rounds a turn (its flux is slow anyway): `from_body` sets it from the fluidity
var _task_id: int = -1
var _rounds_left: int = 0     ## rounds of an incremental tick still to run (`begin_tick`, `step_rounds`)
var _delta: PackedFloat32Array = PackedFloat32Array()   ## the round's scratch (kept between rounds so nothing is allocated in a tick)


func setup(width: int, height: int, cell_size_gu: float, grid_origin: Vector2, liquid_fluidity: float) -> void:
	cols = width
	rows = height
	cell_gu = cell_size_gu
	origin = grid_origin
	fluidity = clampf(liquid_fluidity, 0.0, 1.0)
	ground.resize(cols * rows)
	depth.resize(cols * rows)
	committed.resize(cols * rows)
	committed.fill(0.0)
	_rounds_left = 0
	ceiling.resize(cols * rows)
	_flux.resize(cols * rows * 4)
	_perm.resize(cols * rows * 4)
	ground.fill(0.0)
	depth.fill(0.0)
	ceiling.fill(1.0e9)
	_flux.fill(0.0)
	_perm.fill(1.0)
	spilled = 0.0
	_sources.clear()
	_sinks.clear()


func index(c: int, r: int) -> int:
	return r * cols + c


func in_grid(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < cols and r < rows


func is_rim(c: int, r: int) -> bool:
	return c == 0 or r == 0 or c == cols - 1 or r == rows - 1


## The cell holding a GU position (clamped into the grid).
func cell_of(gu: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor((gu.x - origin.x) / cell_gu)), 0, cols - 1), clampi(int(floor((gu.y - origin.y) / cell_gu)), 0, rows - 1))


## Every cell whose centre lies in `rect` (GU).
func cells_in(rect: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in range(rows):
		for c in range(cols):
			var centre := origin + Vector2((float(c) + 0.5) * cell_gu, (float(r) + 0.5) * cell_gu)
			if rect.has_point(centre):
				out.append(index(c, r))
	return out


func set_ground_rect(rect: Rect2, height: float) -> void:
	for i in cells_in(rect):
		ground[i] = height


func set_ceiling_rect(rect: Rect2, height: float) -> void:
	for i in cells_in(rect):
		ceiling[i] = height


func add_source(rect: Rect2, rate: float) -> void:
	_sources.append({"cells": cells_in(rect), "rate": maxf(rate, 0.0)})


## The player's valve: the rate of source `index` (0 = shut), a source being in the order it was added. False for an index that does not exist.
func set_source_rate(index: int, rate: float) -> bool:
	if index < 0 or index >= _sources.size():
		return false
	finish_tick()
	_sources[index]["rate"] = maxf(rate, 0.0)
	return true


func source_rate(index: int) -> float:
	return float(_sources[index]["rate"]) if index >= 0 and index < _sources.size() else 0.0


## A breach (a blast through a curb, a wall giving way): the ground of the cells in `rect` drops to `height`, so the liquid can leave.
func lower_ground(rect: Rect2, height: float) -> void:
	finish_tick()
	for i in cells_in(rect):
		ground[i] = minf(ground[i], height)


func add_sink(rect: Rect2, rate: float) -> void:
	_sinks.append({"cells": cells_in(rect), "rate": maxf(rate, 0.0)})


## A grate across the line at `at` GU on `axis` ("x": a vertical line, flow crosses it along x; "y": a horizontal line, flow crosses it along y).
## The liquid's fluidity decides what gets through.
func add_grate(axis: String, at: float) -> void:
	_set_grate(axis, at, clampf((fluidity - GRATE_MIN_FLUIDITY) / (GRATE_FULL_FLUIDITY - GRATE_MIN_FLUIDITY), 0.0, 1.0))


## The grate across `at` on `axis` is gone (an acid dissolved its bars, M6 F5): the line lets everything through.
func open_grate(axis: String, at: float) -> void:
	finish_tick()
	_set_grate(axis, at, 1.0)


func _set_grate(axis: String, at: float, pass_fraction: float) -> void:
	if axis == "y":
		var line: int = int(round((at - origin.y) / cell_gu))     ## the boundary between row line-1 and row line
		for c in range(cols):
			if line - 1 >= 0 and line < rows:
				_perm[index(c, line - 1) * 4 + 2] = pass_fraction
				_perm[index(c, line) * 4 + 3] = pass_fraction
	else:
		var line_x: int = int(round((at - origin.x) / cell_gu))
		for r in range(rows):
			if line_x - 1 >= 0 and line_x < cols:
				_perm[index(line_x - 1, r) * 4 + 0] = pass_fraction
				_perm[index(line_x, r) * 4 + 1] = pass_fraction


## The plane of a compiled `liquids` body (`MapCompiler`): the grid is the zone plus one rim cell on every side, `walls` and `roofs` set the
## ground and the ceiling over rects, then the sources, sinks and grates. `body.rect` is the interior in raw GU.
static func from_body(body: Dictionary, liquid_fluidity: float) -> RefCounted:
	var fluid: Dictionary = body["fluid"]
	var cell_size: float = float(fluid["cell"])
	var rect: Rect2 = body["rect"]
	var plane = load("res://godot/scripts/systems/fluid_plane.gd").new()
	var width: int = int(round(rect.size.x / cell_size)) + 2
	var height: int = int(round(rect.size.y / cell_size)) + 2
	plane.setup(width, height, cell_size, rect.position - Vector2(cell_size, cell_size), liquid_fluidity)
	plane.rounds_scale = lerpf(0.5, 1.0, clampf(liquid_fluidity, 0.0, 1.0))
	if float(fluid["rim"]) > 0.0:
		plane.surface_cap = float(fluid["rim"])    ## the rim is the curb that holds the body
	for r in range(height):
		for c in range(width):
			if plane.is_rim(c, r):
				plane.ground[plane.index(c, r)] = float(fluid["rim"])
	plane.dig = float(fluid.get("dig", 0.0))
	for raised: Dictionary in fluid.get("grounds", []):   ## floor left standing inside a dug body (a pipe's bore): ground = its height above the bed
		plane.set_ground_rect(raised["rect"], float(raised["height"]))
	for wall: Dictionary in fluid["walls"]:
		plane.set_ground_rect(wall["rect"], float(wall["height"]))
	for roof: Dictionary in fluid["roofs"]:
		plane.set_ceiling_rect(roof["rect"], float(roof["height"]))
	for src: Dictionary in fluid["sources"]:
		plane.add_source(src["rect"], float(src["rate"]))
	for snk: Dictionary in fluid["sinks"]:
		plane.add_sink(snk["rect"], float(snk["rate"]))
	for grate: Dictionary in fluid["grates"]:
		plane.add_grate(String(grate["axis"]), float(grate["at"]))
	var fill: float = float(fluid.get("fill", 0.0))   ## a still pool: the depth it holds when the map opens (no source needed), up to `fill` voxels over the bed
	if fill > 0.0:
		for r in range(1, height - 1):
			for c in range(1, width - 1):
				var i: int = plane.index(c, r)
				if plane.ground[i] < WALL:
					plane.depth[i] = maxf(fill - plane.ground[i], 0.0)
		plane.committed = plane.depth.duplicate()
	return plane


func surface(i: int) -> float:
	return ground[i] + depth[i]


func total_volume() -> float:
	var sum: float = 0.0
	for i in range(depth.size()):
		sum += depth[i]
	return sum


## One TIC: `ROUNDS_PER_TICK` rounds of flow, with the sources and sinks spread over them.
func tick() -> void:
	finish_tick()
	for _round in range(rounds_per_tick()):
		_round_step()
	committed = depth.duplicate()


## INCREMENTAL TICK (M6 F8, 2026-10-17): the rounds of a turn are spread over the frames instead of run in one hitch. `begin_tick()` completes whatever the
## last one left, COMMITS it (the rules read `committed`, so what a turn sees never depends on the frame rate) and queues a new tick; `step_rounds(n)` runs some
## of it (the sheet draws the live `depth`, so the water moves continuously). A valve or a breach finishes the tick first (below), so an input never lands
## mid-tick.
func begin_tick() -> void:
	finish_tick()
	committed = depth.duplicate()
	_rounds_left = rounds_per_tick()
	if threaded:
		_task_id = WorkerThreadPool.add_task(_run_pending_rounds, false, "FluidPlane tick")


## The worker's body: every round the tick still owes, back to back.
func _run_pending_rounds() -> void:
	var todo: int = _rounds_left
	for _round in range(todo):
		_round_step()


func step_rounds(count: int) -> void:
	if _task_id != -1:
		return    ## a worker owns the rounds
	var todo: int = mini(count, _rounds_left)
	for _round in range(todo):
		_round_step()
	_rounds_left -= todo


## Takes `amount` voxels of depth out of cell `i` (a flame eating oil): waits for a running tick, and moves the committed depth too, so the rules see it now.
func consume(i: int, amount: float) -> void:
	finish_tick()
	depth[i] = maxf(depth[i] - amount, 0.0)
	committed[i] = maxf(committed[i] - amount, 0.0)


func has_pending() -> bool:
	if _task_id != -1:
		return not WorkerThreadPool.is_task_completed(_task_id)
	return _rounds_left > 0


## Runs what is left of an incremental tick now (a hitch of at most that remainder).
func finish_tick() -> void:
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_rounds_left = 0
		return
	step_rounds(_rounds_left)


## A round moves the liquid at most one cell, so a tick needs as many rounds as the cells a wave crosses in a turn: `ROUNDS_PER_TICK` at the 0.25 GU the
## constant was tuned for, half as many at 0.5 GU (the same distance a turn, half the cost).
func rounds_per_tick() -> int:
	return maxi(int(round(float(ROUNDS_PER_TICK) * 0.25 / cell_gu * rounds_scale)), 1)


## One round of flow. M6 F8 (2026-10-17): the Moto measured 12.7 us a cell-round with the first form of this loop (a `dirs` array and an `index()` call per
## neighbour, members read inside the loop, a fresh `delta` per tick). Same arithmetic in the same ORDER (so the depths are bit-identical: `fluid_plane_selftest`
## pins a digest taken from the first form), with the members held in locals, the four neighbours unrolled and the rim visited by its own loop.
func _round_step() -> void:
	var w: int = cols
	var h_rows: int = rows
	var gr: PackedFloat32Array = ground
	var de: PackedFloat32Array = depth
	var ce: PackedFloat32Array = ceiling
	var fx: PackedFloat32Array = _flux
	var pm: PackedFloat32Array = _perm
	var accel: float = lerpf(0.03, 0.2, fluidity)
	var damp: float = lerpf(0.55, 0.96, fluidity)
	var per_round: float = 1.0 / float(rounds_per_tick())
	if _delta.size() != w * h_rows:
		_delta.resize(w * h_rows)
	var delta: PackedFloat32Array = _delta
	for src: Dictionary in _sources:
		var add: float = float(src["rate"]) * per_round
		for i in (src["cells"] as PackedInt32Array):
			## a source cannot push into a cell that is already full under its roof: the pipe is under pressure, not overfilled
			de[i] += minf(add, maxf(ce[i] - gr[i] - de[i], 0.0))
	delta.fill(0.0)
	var last_c: int = w - 1
	var last_r: int = h_rows - 1
	for r in range(h_rows):
		var row: int = r * w
		for c in range(w):
			var i: int = row + c
			var gi: float = gr[i]
			if gi >= WALL:
				continue
			var h: float = gi + de[i]
			var i4: int = i * 4
			var f0: float = 0.0
			var f1: float = 0.0
			var f2: float = 0.0
			var f3: float = 0.0
			if c < last_c:
				var j: int = i + 1
				if gr[j] < WALL:
					f0 = maxf(0.0, fx[i4] * damp + accel * (h - (gr[j] + de[j]))) * pm[i4]
			if c > 0:
				var j: int = i - 1
				if gr[j] < WALL:
					f1 = maxf(0.0, fx[i4 + 1] * damp + accel * (h - (gr[j] + de[j]))) * pm[i4 + 1]
			if r < last_r:
				var j: int = i + w
				if gr[j] < WALL:
					f2 = maxf(0.0, fx[i4 + 2] * damp + accel * (h - (gr[j] + de[j]))) * pm[i4 + 2]
			if r > 0:
				var j: int = i - w
				if gr[j] < WALL:
					f3 = maxf(0.0, fx[i4 + 3] * damp + accel * (h - (gr[j] + de[j]))) * pm[i4 + 3]
			## stored as float32 first, as the first form did: the scale below then acts on the STORED value
			fx[i4] = f0
			fx[i4 + 1] = f1
			fx[i4 + 2] = f2
			fx[i4 + 3] = f3
			var out_total: float = f0 + f1 + f2 + f3
			var di: float = de[i]
			if out_total > di and out_total > 0.0:
				var scale: float = di / out_total
				fx[i4] *= scale
				fx[i4 + 1] *= scale
				fx[i4 + 2] *= scale
				fx[i4 + 3] *= scale
				out_total = di
			if out_total <= 0.0:
				continue
			delta[i] -= out_total
			var v0: float = fx[i4]
			if v0 > 0.0:
				delta[i + 1] += v0
			var v1: float = fx[i4 + 1]
			if v1 > 0.0:
				delta[i - 1] += v1
			var v2: float = fx[i4 + 2]
			if v2 > 0.0:
				delta[i + w] += v2
			var v3: float = fx[i4 + 3]
			if v3 > 0.0:
				delta[i - w] += v3
	for i in range(w * h_rows):
		de[i] = maxf(de[i] + delta[i], 0.0)
	for snk: Dictionary in _sinks:
		var take: float = float(snk["rate"]) * per_round
		for i in (snk["cells"] as PackedInt32Array):
			de[i] = maxf(de[i] - take, 0.0)
	## the rim: whatever stands above a boundary cell's ground leaves the body
	for c in range(w):
		spilled += de[c]
		de[c] = 0.0
	for r in range(1, last_r):
		spilled += de[r * w]
		de[r * w] = 0.0
		spilled += de[r * w + last_c]
		de[r * w + last_c] = 0.0
	if h_rows > 1:
		for c in range(w):
			spilled += de[last_r * w + c]
			de[last_r * w + c] = 0.0
