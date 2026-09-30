## PropFragmentSim — what a Tier 4 prop does in the half second after a blast, as pure deterministic maths.
##
## PROPS_TIER4_PLAN P2 / `ACTOR` D67. The prop has been voxelized (`PropVoxelizer`, board-size cubes that keep its shape). This
## moves those cubes: they fall from where the prop stood; the blast carves away the ones nearest it (by the ring weight) and
## pushes the rest outward; what is left lands, STACKS on the column under it, slumps downhill, and ends as a pile of charred
## cubes on the board's own voxel lattice. No Godot physics, no scene, no `randf()`: every roll is a hash of (seed, fragment), so the
## same blast on the same prop gives the same pile (a replay, a rotation and a test all see one answer).
##
## TIMED, NOT COUNTED. `advance(delta)` runs fixed 1/60 s steps of SIMULATED time, so 0.5 s is 0.5 s on a 30 fps handset (15 drawn
## frames) and on the desktop (30) alike; a long frame runs several steps, capped so a hitch can never spiral.
##
## SPACE. World units are GU (1.0 = one game unit; the board voxel is 1/8). `origin` is the world position of the prop's local
## (0, 0, 0): the floor, on a voxel boundary in X/Z, so a local cell index plus `origin / voxel` is the board's own voxel column.
class_name PropFragmentSim
extends RefCounted

## GU per second squared: 9.8 m/s^2 at ~1.2 m per GU.
const GRAVITY: float = 8.0
const STEP: float = 1.0 / 60.0
const MAX_STEPS_PER_ADVANCE: int = 8
## A hard stop: whatever is still in the air is put on its column.
const MAX_SIM_TIME: float = 1.6
const SLIDE_TIME: float = 0.07
## Outward speed (GU/s) at weight 1, and the up-kick.
const PUSH_SPEED: float = 1.3
const PUSH_UP: float = 1.2
## The charred tone of a fragment: a multiplier on its colour, `BoardLook.char_mult(h)` = `lerp(MIN, MAX, h*h)` (mostly dark, some lighter; D-P5).
## Seconds over which a fragment goes from its own colour to its charred tone, starting at the wave.
const CHAR_TIME: float = 0.30

enum State { FALLING, SLIDING, LANDED, GONE }

var count: int = 0
var voxel: float = 0.125
var origin: Vector3 = Vector3.ZERO
var weight: float = 1.0
var time: float = 0.0
var wave_time: float = 0.06

## Per fragment (all sized `count`).
var pos: PackedVector3Array = PackedVector3Array()
var vel: PackedVector3Array = PackedVector3Array()
var euler: PackedVector3Array = PackedVector3Array()
var spin: PackedVector3Array = PackedVector3Array()
var state: PackedInt32Array = PackedInt32Array()
var zone: PackedInt32Array = PackedInt32Array()
var level: PackedInt32Array = PackedInt32Array()      ## stack level once landed
var column: Array[Vector2i] = []                      ## board voxel column (x, z) once landed
var tone: PackedFloat32Array = PackedFloat32Array()   ## the charred multiplier this fragment ends at
var jitter: PackedFloat32Array = PackedFloat32Array() ## a small brightness variation, so a flat colour still reads as cubes
var vanish_at: PackedFloat32Array = PackedFloat32Array()  ## -1 = survives

var _stack: Dictionary = {}      ## Vector2i column -> number of landed cubes
var _slide_from: PackedVector3Array = PackedVector3Array()
var _slide_to: PackedVector3Array = PackedVector3Array()
var _slide_t: PackedFloat32Array = PackedFloat32Array()
var _seed: String = ""
var _can_cross: Callable = Callable()
var _acc: float = 0.0
var _done: bool = false


## `p`: cells (Array[Vector3i]), zones (PackedInt32Array), origin (Vector3), blast (Vector2, world X/Z), weight (0..1),
## seed (String), voxel (float, optional), wave_delay (float seconds, optional), can_cross (Callable(Vector2i, Vector2i) -> bool,
## optional: may a fragment pass from this GU to that one).
func _init(p: Dictionary) -> void:
	var cells: Array = p["cells"]
	var zones: PackedInt32Array = p.get("zones", PackedInt32Array())
	origin = p["origin"]
	voxel = float(p.get("voxel", voxel))
	weight = clampf(float(p["weight"]), 0.0, 1.0)
	wave_time = float(p.get("wave_delay", wave_time))
	_seed = String(p.get("seed", ""))
	_can_cross = p.get("can_cross", Callable())
	var blast: Vector2 = p["blast"]
	count = cells.size()
	pos.resize(count)
	vel.resize(count)
	euler.resize(count)
	spin.resize(count)
	state.resize(count)
	zone.resize(count)
	level.resize(count)
	tone.resize(count)
	jitter.resize(count)
	vanish_at.resize(count)
	_slide_from.resize(count)
	_slide_to.resize(count)
	_slide_t.resize(count)
	column.resize(count)
	var centres: PackedVector2Array = PackedVector2Array()
	centres.resize(count)
	var far: float = 0.001
	for i in range(count):
		var c: Vector3i = cells[i]
		pos[i] = origin + Vector3((float(c.x) + 0.5) * voxel, (float(c.y) + 0.5) * voxel, (float(c.z) + 0.5) * voxel)
		zone[i] = zones[i] if i < zones.size() else 0
		centres[i] = Vector2(pos[i].x, pos[i].z)
		far = maxf(far, centres[i].distance_to(blast))
		state[i] = State.FALLING
		vanish_at[i] = -1.0
		tone[i] = BoardLook.char_mult(_h01(i, "tone"))
		jitter[i] = 0.94 + 0.12 * _h01(i, "jit")
	## The blast carves away the fragments nearest it: rank by (a hash nudged by distance), the first `round(weight * count)` go.
	var order: Array = range(count)
	var score: PackedFloat32Array = PackedFloat32Array()
	score.resize(count)
	for i in range(count):
		score[i] = _h01(i, "destroy") + 0.6 * (centres[i].distance_to(blast) / far)
	order.sort_custom(func(a: int, b: int) -> bool:
		return score[a] < score[b] or (score[a] == score[b] and a < b))
	var destroyed: int = int(round(weight * float(count)))
	for k in range(destroyed):
		var i: int = order[k]
		vanish_at[i] = wave_time + 0.06 * _h01(i, "vanish")
	## Every fragment is pushed from the blast and falls; the push scales with the weight and with how close it was.
	for i in range(count):
		var away: Vector2 = centres[i] - blast
		var dir: Vector2 = away.normalized() if away.length() > 0.001 else Vector2.from_angle(_h01(i, "dir") * TAU)
		var near: float = 1.0 - 0.5 * (away.length() / far)
		var speed: float = PUSH_SPEED * weight * near * (0.55 + 0.45 * _h01(i, "speed"))
		vel[i] = Vector3(dir.x * speed, PUSH_UP * weight * near * (0.3 + 0.7 * _h01(i, "up")), dir.y * speed)
		spin[i] = Vector3(_h01(i, "sx") - 0.5, _h01(i, "sy") - 0.5, _h01(i, "sz") - 0.5) * (14.0 * weight)


func is_done() -> bool:
	return _done


## Advances the simulation by `delta` seconds of real time (whole fixed steps; the remainder waits for the next call).
func advance(delta: float) -> void:
	if _done:
		return
	_acc += delta
	var steps: int = 0
	while _acc >= STEP and steps < MAX_STEPS_PER_ADVANCE and not _done:
		_acc -= STEP
		step()
		steps += 1
	if steps >= MAX_STEPS_PER_ADVANCE:
		_acc = 0.0   ## a hitch is dropped, never replayed


## One fixed step.
func step() -> void:
	time += STEP
	var moving: bool = false
	for i in range(count):
		var st: int = state[i]
		if st == State.GONE:
			continue
		if vanish_at[i] >= 0.0 and time >= vanish_at[i]:
			_release_column(i)
			state[i] = State.GONE
			continue
		if st == State.FALLING:
			moving = true
			_fall(i)
		elif st == State.SLIDING:
			moving = true
			_slide(i)
	## Not before the last carved fragment has had its turn to vanish (one that landed early is still to go).
	if (not moving and time >= wave_time + 0.07) or time >= MAX_SIM_TIME:
		_finish()


## The landed fragments as pile records, in a stable order: {"column": Vector2i (board voxel x, z), "level": int, "tone": float,
## "jitter": float, "zone": int}.
func pile_records() -> Array:
	var out: Array = []
	for i in range(count):
		if state[i] == State.LANDED:
			out.append({"column": column[i], "level": level[i], "tone": tone[i], "jitter": jitter[i], "zone": zone[i]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = a["column"]
		var cb: Vector2i = b["column"]
		if ca.x != cb.x:
			return ca.x < cb.x
		if ca.y != cb.y:
			return ca.y < cb.y
		return int(a["level"]) < int(b["level"]))
	return out


func vanished_count() -> int:
	var n: int = 0
	for i in range(count):
		if state[i] == State.GONE:
			n += 1
	return n


## 0 = its own colour, 1 = fully charred (the multiplier `tone[i]` applies at 1).
func char_amount(i: int) -> float:
	var ramp: float = clampf((time - wave_time) / CHAR_TIME, 0.0, 1.0)
	return ramp * clampf(weight * 1.15, 0.0, 1.0)


func rotation_of(i: int) -> Basis:
	return Basis.from_euler(euler[i])


# ── internals ─────────────────────────────────────────────────────────────────────────────────────────────────

func _fall(i: int) -> void:
	var v: Vector3 = vel[i]
	v.y -= GRAVITY * STEP
	vel[i] = v
	var next: Vector3 = pos[i] + v * STEP
	if _can_cross.is_valid():
		var from_gu := Vector2i(floori(pos[i].x), floori(pos[i].z))
		var to_gu := Vector2i(floori(next.x), floori(next.z))
		if from_gu != to_gu and not bool(_can_cross.call(from_gu, to_gu)):
			next.x = pos[i].x
			next.z = pos[i].z
			vel[i] = Vector3(v.x * -0.3, v.y, v.z * -0.3)
	euler[i] += spin[i] * STEP
	var col := Vector2i(floori(next.x / voxel), floori(next.z / voxel))
	var top: float = origin.y + float(int(_stack.get(col, 0))) * voxel
	if vel[i].y <= 0.0 and next.y - voxel * 0.5 <= top + 1.0e-6:
		_land(i, col)
	else:
		pos[i] = next


func _land(i: int, col: Vector2i) -> void:
	var k: int = int(_stack.get(col, 0))
	_stack[col] = k + 1
	column[i] = col
	level[i] = k
	pos[i] = _cell_centre(col, k)
	vel[i] = Vector3.ZERO
	euler[i] = Vector3.ZERO
	state[i] = State.LANDED
	_slump(i)


## A cube that landed two or more above a neighbouring column slides down to it (the pile collapses instead of standing in a spike).
func _slump(i: int) -> void:
	var col: Vector2i = column[i]
	var h: int = int(_stack.get(col, 0))
	if level[i] != h - 1:
		return   ## not the top of its column any more
	var best := Vector2i(999999, 999999)
	var best_h: int = h - 1
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = col + d
		var nh: int = int(_stack.get(n, 0))
		if nh > h - 2:
			continue
		if _can_cross.is_valid() and not _same_gu(col, n) and not bool(_can_cross.call(_gu_of(col), _gu_of(n))):
			continue
		if nh < best_h or (nh == best_h and best.x != 999999 and _h01(i, "slump%d" % h) < 0.5):
			best = n
			best_h = nh
	if best.x == 999999:
		return
	_stack[col] = h - 1
	_stack[best] = best_h + 1
	column[i] = best
	level[i] = best_h
	_slide_from[i] = pos[i]
	_slide_to[i] = _cell_centre(best, best_h)
	_slide_t[i] = 0.0
	state[i] = State.SLIDING


func _slide(i: int) -> void:
	_slide_t[i] += STEP
	var t: float = clampf(_slide_t[i] / SLIDE_TIME, 0.0, 1.0)
	pos[i] = _slide_from[i].lerp(_slide_to[i], t)
	if t >= 1.0:
		pos[i] = _slide_to[i]
		state[i] = State.LANDED
		_slump(i)


## A fragment that vanishes out of a column it had landed on gives its slot back, and whatever stood above it drops one level.
func _release_column(i: int) -> void:
	if state[i] != State.LANDED and state[i] != State.SLIDING:
		return
	var col: Vector2i = column[i]
	var lvl: int = level[i]
	_stack[col] = maxi(int(_stack.get(col, 0)) - 1, 0)
	for j in range(count):
		if j != i and state[j] == State.LANDED and column[j] == col and level[j] > lvl:
			level[j] -= 1
			pos[j].y -= voxel


func _finish() -> void:
	for i in range(count):
		if state[i] == State.FALLING or state[i] == State.SLIDING:
			if state[i] == State.SLIDING:
				state[i] = State.LANDED
				pos[i] = _slide_to[i]
			else:
				var col := Vector2i(floori(pos[i].x / voxel), floori(pos[i].z / voxel))
				_land_no_slump(i, col)
	_done = true


func _land_no_slump(i: int, col: Vector2i) -> void:
	var k: int = int(_stack.get(col, 0))
	_stack[col] = k + 1
	column[i] = col
	level[i] = k
	pos[i] = _cell_centre(col, k)
	vel[i] = Vector3.ZERO
	euler[i] = Vector3.ZERO
	state[i] = State.LANDED


func _cell_centre(col: Vector2i, k: int) -> Vector3:
	return Vector3((float(col.x) + 0.5) * voxel, origin.y + (float(k) + 0.5) * voxel, (float(col.y) + 0.5) * voxel)


func _gu_of(col: Vector2i) -> Vector2i:
	return Vector2i(floori(float(col.x) * voxel), floori(float(col.y) * voxel))


func _same_gu(a: Vector2i, b: Vector2i) -> bool:
	return _gu_of(a) == _gu_of(b)


## A deterministic number in [0, 1) for (fragment, purpose) under this blast's seed.
func _h01(i: int, what: String) -> float:
	return float(FacadeSampler._fnv1a_hash("%s:%d:%s" % [_seed, i, what]) % 100003) / 100003.0
