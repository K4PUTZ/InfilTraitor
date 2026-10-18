## LiquidFlames — the flame BALLS of a burning liquid (M6 F5, Director 2026-10-18: *"as mesmas bolinhas de fogo da explosão, em toda a extensão que estiver
## queimando. Nascem no chão, vão subindo com variadas velocidades e tamanhos, e somem"*).
##
## It spawns nothing of its own: the blast's fire is `EmberOverlay` glows (yellow-hot, cooling to red, a soft halo, born and dying), and these are the same
## embers, born on the surface of the cells whose `LiquidFire.visual` level is above `HOT_LEVEL`, anchored in 3D on the oil, each with its own life, rise speed
## and size, so a front that sweeps across the pool is followed by flames and a cell that is put out stops throwing them as its level falls. PURELY VISUAL.
## The rate follows the number of hot cells up to `MAX_PER_SECOND` a body (a flooded floor does not become a thousand particles); the cells are picked at random.
class_name LiquidFlames
extends RefCounted

const PER_CELL_PER_SECOND: float = 3.5   ## flames a hot cell throws a second (a cell is 0.25 GU^2 at 0.5 GU)
const MAX_PER_SECOND: float = 160.0      ## the cap for one body
const MAX_DT: float = 0.1                ## a stalled frame is capped, not paid back
const LIFE_MIN: float = 0.6             ## seconds
const LIFE_MAX: float = 1.7
const RISE_MIN_PX_S: float = 90.0        ## the blast's own buoyancy is 150 px/s +-45 %
const RISE_MAX_PX_S: float = 300.0
const SIZE_MIN: float = 0.5              ## the ember radius scale (a coal of the crater is 1.0, the fuse's spark 0.3-0.5)
const SIZE_MAX: float = 2.0
const LIFT_GU: float = 0.05              ## above the oil, so the depth test does not bury the first frame

var _carry: float = 0.0


## One frame. `base_y` is the sheet's surface height (GU), `embers` the room's `EmberOverlay`.
func tick(dt: float, fire: RefCounted, base_y: float, embers: Node) -> void:
	if fire == null or embers == null or fire.hot_cells.is_empty():
		_carry = 0.0
		return
	var step: float = minf(dt, MAX_DT)
	_carry += minf(float(fire.hot_cells.size()) * PER_CELL_PER_SECOND, MAX_PER_SECOND) * step
	var spawn: int = int(_carry)
	_carry -= float(spawn)
	var half: float = fire.plane.cell_gu * 0.5
	for _n in range(spawn):
		var i: int = fire.hot_cells[randi() % fire.hot_cells.size()]
		var at: Vector2 = fire.centre_of(i) + Vector2(randf_range(-half, half), randf_range(-half, half))
		var size: float = randf_range(SIZE_MIN, SIZE_MAX)
		## a big ball is slower and lives longer than a small one, but both vary: the eye reads a flame, not a column of one speed
		var rise: float = lerpf(RISE_MAX_PX_S, RISE_MIN_PX_S, size) * randf_range(0.75, 1.25)
		var life: float = lerpf(LIFE_MIN, LIFE_MAX, size) * randf_range(0.7, 1.3)
		embers.add_ember(Vector2.ZERO, life, Vector2.ZERO, 0.0, rise, 1.0, 0.0, size, 1.0, false,
				Vector2.ZERO, Vector3(at.x, base_y + LIFT_GU, at.y))
