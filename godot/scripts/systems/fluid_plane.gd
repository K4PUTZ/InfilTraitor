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
const ROUNDS_PER_TICK: int = 24
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


func setup(width: int, height: int, cell_size_gu: float, grid_origin: Vector2, liquid_fluidity: float) -> void:
	cols = width
	rows = height
	cell_gu = cell_size_gu
	origin = grid_origin
	fluidity = clampf(liquid_fluidity, 0.0, 1.0)
	ground.resize(cols * rows)
	depth.resize(cols * rows)
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


func add_sink(rect: Rect2, rate: float) -> void:
	_sinks.append({"cells": cells_in(rect), "rate": maxf(rate, 0.0)})


## A grate across the line at `at` GU on `axis` ("x": a vertical line, flow crosses it along x; "y": a horizontal line, flow crosses it along y).
## The liquid's fluidity decides what gets through.
func add_grate(axis: String, at: float) -> void:
	var pass_fraction: float = clampf((fluidity - GRATE_MIN_FLUIDITY) / (GRATE_FULL_FLUIDITY - GRATE_MIN_FLUIDITY), 0.0, 1.0)
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
	for r in range(height):
		for c in range(width):
			if plane.is_rim(c, r):
				plane.ground[plane.index(c, r)] = float(fluid["rim"])
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
	var accel: float = lerpf(0.03, 0.2, fluidity)
	var damp: float = lerpf(0.55, 0.96, fluidity)
	var per_round: float = 1.0 / float(ROUNDS_PER_TICK)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var delta := PackedFloat32Array()
	delta.resize(cols * rows)
	for _round in range(ROUNDS_PER_TICK):
		for src: Dictionary in _sources:
			for i in (src["cells"] as PackedInt32Array):
				## a source cannot push into a cell that is already full under its roof: the pipe is under pressure, not overfilled
				depth[i] += minf(float(src["rate"]) * per_round, maxf(ceiling[i] - ground[i] - depth[i], 0.0))
		delta.fill(0.0)
		for r in range(rows):
			for c in range(cols):
				var i: int = index(c, r)
				if ground[i] >= WALL:
					continue
				var h: float = ground[i] + depth[i]
				var out_total: float = 0.0
				for d in range(4):
					var nc: int = c + dirs[d].x
					var nr: int = r + dirs[d].y
					var f: float = 0.0
					if in_grid(nc, nr):
						var j: int = index(nc, nr)
						if ground[j] < WALL:
							f = maxf(0.0, _flux[i * 4 + d] * damp + accel * (h - (ground[j] + depth[j]))) * _perm[i * 4 + d]
					_flux[i * 4 + d] = f
					out_total += f
				if out_total > depth[i] and out_total > 0.0:
					var scale: float = depth[i] / out_total
					for d in range(4):
						_flux[i * 4 + d] *= scale
					out_total = depth[i]
				if out_total <= 0.0:
					continue
				delta[i] -= out_total
				for d in range(4):
					var fl: float = _flux[i * 4 + d]
					if fl > 0.0:
						delta[index(c + dirs[d].x, r + dirs[d].y)] += fl
		for i in range(depth.size()):
			depth[i] = maxf(depth[i] + delta[i], 0.0)
		for snk: Dictionary in _sinks:
			for i in (snk["cells"] as PackedInt32Array):
				depth[i] = maxf(depth[i] - float(snk["rate"]) * per_round, 0.0)
		## the rim: whatever stands above a boundary cell's ground leaves the body
		for r in range(rows):
			for c in range(cols):
				if is_rim(c, r):
					var k: int = index(c, r)
					spilled += depth[k]
					depth[k] = 0.0
