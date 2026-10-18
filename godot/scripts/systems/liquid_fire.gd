## LiquidFire — a flammable liquid on fire (M6 F5, `MATERIALS_MASTER_PLAN` §6).
##
## One per body whose liquid is `gameplay.flammable`. It owns WHICH cells of the body's `FluidPlane` burn (a byte a cell, the plane's own grid) and nothing else:
## the water is the plane's, the flames are drawn by the sheet's shader (real time, so they loop while the game is paused), the agent's dose is the Room's.
##
## RULES (Director, 2026-10-17): anything explosive, an incendiary arrow or a shot lights it (`ignite`); the fire runs a few GU a turn along the wet cells
## (`gameplay.fire.speed`), then burns on, eating the oil a little each turn (`burn`) until the cell is dry; water or an extinguisher puts a cell out;
## a burning cell is lethal to stand in (`dose_step` / `dose_turn`, added to the liquid's own dose). Pure and deterministic: the same ignitions and turns
## give the same cells, so a checkpoint can keep `state()` and restore it.
class_name LiquidFire
extends RefCounted

const NO_DEPTH: float = 0.05     ## below this a cell is dry (as `LiquidExposure.NO_DEPTH`)
const DEFAULT_SPEED: float = 3.0     ## GU of front a turn
const DEFAULT_BURN: float = 0.15     ## voxels of depth eaten a turn
const DEFAULT_DOSE_STEP: float = 0.5
const DEFAULT_DOSE_TURN: float = 0.5
## THE LOOK is not the rules (Director, 2026-10-18: "uma coisa suave e fluida"): `burning` is the turn's truth and jumps; what is DRAWN is `visual`, a level 0..1 a
## cell that rises when its turn comes (the front SWEEPS across the cells a turn lit instead of lighting them all at once), and falls slowly when the cell goes out.
const SWEEP_SECONDS: float = 0.9      ## the time a turn's front takes to cross the GU it gained
const BLAST_FRONT_GU_S: float = 7.0   ## how fast a blast's fire opens outward from its point
const RISE_PER_S: float = 4.0         ## a lit cell reaches full flame in about a quarter of a second
const FALL_PER_S: float = 1.1         ## and takes about a second to die away
const HOT_LEVEL: float = 0.35         ## from here a cell throws flames (`hot_cells`)

var plane: RefCounted = null
var burning: PackedByteArray = PackedByteArray()   ## 1 = the plane cell burns (the whole grid, rim included, which never burns)
var speed_gu: float = DEFAULT_SPEED
var burn_per_turn: float = DEFAULT_BURN
var dose_step: float = DEFAULT_DOSE_STEP
var dose_turn: float = DEFAULT_DOSE_TURN
var visual: PackedFloat32Array = PackedFloat32Array()    ## 0..1 per plane cell: the flame the eye sees
var hot_cells: PackedInt32Array = PackedInt32Array()      ## the cells whose visual level is above HOT_LEVEL, rebuilt each `advance_visual`
var _lit_at: PackedFloat32Array = PackedFloat32Array()    ## the visual clock at which a burning cell may start to light
var _clock: float = 0.0
var version: int = 0               ## bumped whenever a cell lights or goes out (the sheet redraws then)


func setup(fluid_plane: RefCounted, spec: Dictionary) -> void:
	plane = fluid_plane
	burning.resize(plane.cols * plane.rows)
	burning.fill(0)
	visual.resize(plane.cols * plane.rows)
	visual.fill(0.0)
	_lit_at.resize(plane.cols * plane.rows)
	_lit_at.fill(0.0)
	_clock = 0.0
	speed_gu = float(spec.get("speed", DEFAULT_SPEED))
	burn_per_turn = float(spec.get("burn", DEFAULT_BURN))
	dose_step = float(spec.get("dose_step", DEFAULT_DOSE_STEP))
	dose_turn = float(spec.get("dose_turn", DEFAULT_DOSE_TURN))
	version = 0


func count() -> int:
	var n: int = 0
	for b in burning:
		n += int(b)
	return n


func _wet(i: int) -> bool:
	return plane.committed[i] > NO_DEPTH and plane.ground[i] < plane.WALL


func _interior(c: int, r: int) -> bool:
	return c >= 1 and r >= 1 and c <= plane.cols - 2 and r <= plane.rows - 2


## The GU position of a plane cell's centre.
func centre_of(i: int) -> Vector2:
	var c: int = i % plane.cols
	var r: int = i / plane.cols
	return plane.origin + Vector2((float(c) + 0.5) * plane.cell_gu, (float(r) + 0.5) * plane.cell_gu)


## A blast / shot / flame at `centre` (GU) reaching `radius` GU: every wet cell inside burns. Returns how many cells caught.
func ignite(centre: Vector2, radius: float) -> int:
	var lit: int = 0
	for r in range(1, plane.rows - 1):
		for c in range(1, plane.cols - 1):
			var i: int = plane.index(c, r)
			if burning[i] == 0 and _wet(i) and centre_of(i).distance_to(centre) <= radius:
				burning[i] = 1
				_lit_at[i] = _clock + centre_of(i).distance_to(centre) / BLAST_FRONT_GU_S
				lit += 1
	if lit > 0:
		version += 1
	return lit


## Puts out every burning cell whose centre lies in `rect` (GU); the water pistol and the extinguishers of the props milestone call this. Returns how many.
func extinguish_rect(rect: Rect2) -> int:
	var out: int = 0
	for i in range(burning.size()):
		if burning[i] == 1 and rect.has_point(centre_of(i)):
			burning[i] = 0
			out += 1
	if out > 0:
		version += 1
	return out


func extinguish_all() -> void:
	burning.fill(0)
	version += 1


## One turn: `put_out` (Callable(Vector2 gu) -> bool, may be invalid) says where water stands; then the front runs `speed_gu`, then the flames eat the oil.
## Call it BEFORE the plane's next `begin_tick`, so the rules and the fire read the same committed depths.
func tick(put_out: Callable = Callable()) -> void:
	var changed: bool = false
	var front := PackedInt32Array()
	for i in range(burning.size()):
		if burning[i] == 1:
			if put_out.is_valid() and bool(put_out.call(centre_of(i))):
				burning[i] = 0
				changed = true
			else:
				front.append(i)
	var rounds: int = maxi(int(round(speed_gu / plane.cell_gu)), 1)
	var w: int = plane.cols
	for round_index in range(rounds):
		var next := PackedInt32Array()
		for i in front:
			var c: int = i % w
			var r: int = i / w
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: int = c + d.x
				var nr: int = r + d.y
				if _interior(nc, nr):
					var j: int = plane.index(nc, nr)
					if burning[j] == 0 and _wet(j) and not (put_out.is_valid() and bool(put_out.call(centre_of(j)))):    ## water standing there keeps the fire out
						burning[j] = 1
						_lit_at[j] = _clock + float(round_index + 1) / float(rounds) * SWEEP_SECONDS
						next.append(j)
						changed = true
		front = next
		if front.is_empty():
			break
	for i in range(burning.size()):
		if burning[i] == 1:
			plane.consume(i, burn_per_turn)
			if not _wet(i):
				burning[i] = 0
				changed = true
	if changed:
		version += 1


## The look, one frame: each cell's `visual` level moves toward 1 once its burning cell's turn has come (`_lit_at`) and toward 0 otherwise, so a front sweeps
## across the cells it gained and a put-out cell dies away. Returns true while anything is still changing or burning (the caller redraws then).
func advance_visual(dt: float) -> bool:
	_clock += dt
	var rise: float = RISE_PER_S * dt
	var fall: float = FALL_PER_S * dt
	var moving: bool = false
	hot_cells = PackedInt32Array()
	for i in range(visual.size()):
		var level: float = visual[i]
		var on: bool = burning[i] == 1 and _clock >= _lit_at[i]
		if on:
			if level < 1.0:
				level = minf(level + rise, 1.0)
				moving = true
		elif level > 0.0:
			level = maxf(level - fall, 0.0)
			moving = true
		visual[i] = level
		if level > HOT_LEVEL:
			hot_cells.append(i)
	return moving or not hot_cells.is_empty()


## Whether any burning cell lies in the GU cell `cell` (inner or raw GU, as the plane's grid is: raw).
func burning_at(cell: Vector2i) -> bool:
	var c0: int = maxi(int(floor((float(cell.x) - plane.origin.x) / plane.cell_gu)), 1)
	var c1: int = mini(int(ceil((float(cell.x + 1) - plane.origin.x) / plane.cell_gu)) - 1, plane.cols - 2)
	var r0: int = maxi(int(floor((float(cell.y) - plane.origin.y) / plane.cell_gu)), 1)
	var r1: int = mini(int(ceil((float(cell.y + 1) - plane.origin.y) / plane.cell_gu)) - 1, plane.rows - 2)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if burning[plane.index(c, r)] == 1:
				return true
	return false


## What a checkpoint keeps (and `restore` puts back).
func state() -> PackedByteArray:
	return burning.duplicate()


func restore(saved: PackedByteArray) -> void:
	if saved.size() == burning.size():
		burning = saved.duplicate()
		version += 1
