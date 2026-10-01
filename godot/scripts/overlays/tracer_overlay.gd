extends Node2D
## TracerOverlay — WEAPON_MASTER_PLAN §6c Part D: the decorative projectile,
## drawn from the muzzle to the point the round actually reached.
##
## ⚠️ THIS IS THE VISIBLE HALF OF AN AMENDMENT TO D21, and the amendment is
## narrow enough to be worth stating narrowly. D21 ratified that *"the
## projectile does not exist in the scene — no travel, no per-frame simulation,
## only its consequences are drawn"*; the Director asked for *"projéteis
## decorativos saindo"*, so the projectile becomes VISIBLE, not SIMULATED.
##
## What that buys, concretely: nothing here decides anything. The endpoints are
## handed in already resolved by BlastCalculator, the shot has already committed
## its damage by the time the first frame draws, and deleting this node changes
## no outcome. If a future change ever lets the drawn streak decide where the
## round lands, that is a different decision and D21 has to be reopened for it —
## a tracer that reports is decoration, a tracer that decides is a simulation.
##
## Deliberately NOT folded into ShrapnelOverlay, whose fragments are physical
## debris with their own arcs and lifetimes; a tracer is one straight segment
## between two known points, and sharing a file would mean sharing a per-frame
## integrator neither needs.
class_name TracerOverlay

## Warm, near-white core with a short tail. Not calibrated against anything —
## a first pass for the Director to react to, like every other visual placeholder
## in this stack.
const CORE_COLOR := Color(1.0, 0.93, 0.72, 0.95)
const TAIL_COLOR := Color(1.0, 0.62, 0.22, 0.55)
const CORE_WIDTH_PX: float = 2.0
const TAIL_WIDTH_PX: float = 4.0

## Seconds a streak stays fully lit before it starts fading, and how long the
## fade itself takes. Short on purpose: a tracer that outlives the muzzle flash
## reads as a laser rather than a round in flight.
## ⚠️ THE FLIGHT IS COUNTED IN DRAWN FRAMES, NOT IN SECONDS, and the seconds
## version is why this comment is long.
##
## v1 aged the streak by `delta`. Measured 2026-08-19 by printing `_draw()`'s own
## call log: for one shot it ran TWICE, at age 0.000 s and age 0.141 s. A single
## frame had lasted 141 ms — the firearm path pays ~310 ms of synchronous CPU at
## the trigger (§0's W-PRECOOK measurement, technical_debt 16) — so the entire
## 0.14 s flight elapsed inside one stalled frame and the round was only ever
## drawn already arrived. Splitting the controller's resolve/flight/impact passes
## helped and did not fix it: the stall simply moved to the next frame, ages went
## 0.000 -> 0.139, and the streak was parked again.
##
## A DURATION IS THE WRONG UNIT FOR THIS. What has to elapse is not time, it is
## PICTURES OF THE ROUND IN DIFFERENT PLACES, and a frame that takes 141 ms
## produces exactly one of those however much time it spends. Counting frames
## makes the projectile immune to the stall by construction instead of by hoping
## the stall gets fixed — and it stays correct after W-PRECOOK lands, because 8
## frames is 8 frames at any frame rate the game actually ships at.
##
## The cost of the choice, stated: on a slow machine the tracer flies for longer
## in wall-clock terms. For decoration that is the right trade — a projectile
## nobody sees is worth nothing, and one that lingers 50 ms extra is worth
## nearly the same as one that does not.
## ⚠️ THE ROUND MUST BE GONE BEFORE THE IMPACT FRAME, and that is a hard
## constraint rather than a look preference.
##
## Director, 2026-08-19: *"O projétil, exatamente pelo fato de que ele é
## decorativo, tem que sair sempre em tempo real. E não precisa ir até o fim,
## pode sumir no meio do caminho. O importante é sair da arma junto com o
## clarão."*
##
## HOLD + FADE was 15 frames while `AgentShotController.TRACER_FLIGHT_FRAMES` is
## 8, so the heavy impact frame landed while the streak was still on screen — and
## a decorative round frozen in mid-air is the single most obvious symptom of a
## stall. 5 + 3 = 8 makes the round leave the barrel, cross what it crosses, and
## VANISH before anything expensive runs. It does not reach the wall, by the
## Director's own permission; leaving the gun with the flash is what it is for.
##
## KEEP THE SUM <= TRACER_FLIGHT_FRAMES. If that constant changes, this must.
const HOLD_FRAMES: int = 5
const FADE_FRAMES: int = 3

const STREAK_FRACTION: float = 0.16

## The projectile's own bright head — what makes it read as a ROUND leaving the
## gun rather than as a streak that happens to be moving. Drawn as a filled dot
## at the leading end, over the tail.
const HEAD_RADIUS_PX: float = 2.6
const HEAD_COLOR := Color(1.0, 0.97, 0.86, 1.0)

## Each entry: {"from": Vector2, "to": Vector2, "frames": int}. World space, the
## same space the overlay's own transform is in.
var _streaks: Array = []
## R3D-WORLD: on the 3D board the streak is world geometry (`WorldCanvas3D`), from the muzzle's world point to the
## impact's, so it stays where the round went when the view turns. Null on the 2D path.
var _world: RefCounted = null  ## WorldCanvas3D
const WorldCanvas3DRef = preload("res://godot/scripts/geometry/world_canvas3d.gd")


func _ready() -> void:
	z_index = 4000
	set_process(false)


## Draw one round. `from` and `to` are world-space points; the caller owns both,
## because the caller is the only scope that knows the muzzle AND the impact.
## `from_floor` / `to_floor` are the 2D points of the floor under each end (the agent's feet under the muzzle); omitted,
## the end is on the floor itself.
func add_tracer(from: Vector2, to: Vector2, from_floor: Vector2 = Vector2.INF, to_floor: Vector2 = Vector2.INF) -> void:
	if from == to:
		return
	_streaks.append({"from": from, "to": to, "frames": 0,
		"from_floor": from if from_floor == Vector2.INF else from_floor,
		"to_floor": to if to_floor == Vector2.INF else to_floor})
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	var alive: Array = []
	for s in _streaks:
		s["frames"] = int(s["frames"]) + 1
		if int(s["frames"]) < HOLD_FRAMES + FADE_FRAMES:
			alive.append(s)
	_streaks = alive
	if _streaks.is_empty():
		set_process(false)
	queue_redraw()


## R3D-WORLD — draw on the 3D board instead (null: back to the 2D canvas).
func set_board3d(board: Node3D) -> void:
	if _world != null:
		_world.detach()
		_world = null
	if board != null:
		_world = WorldCanvas3DRef.new()
		_world.attach(board, self, 4)
	queue_redraw()


func _draw() -> void:
	if _world != null:
		_draw_world()
		return
	for s in _streaks:
		var frames: int = int(s["frames"])
		## Alpha holds, then ramps down. Explicit float conversion throughout —
		## an INTEGER_DIVISION warning here would be a real bug in the ramp.
		var alpha: float = 1.0
		if frames > HOLD_FRAMES:
			alpha = clampf(1.0 - float(frames - HOLD_FRAMES) / float(FADE_FRAMES),
				0.0, 1.0)
		var from: Vector2 = s["from"]
		var to: Vector2 = s["to"]
		## The streak travels: its trailing end walks from the muzzle to the
		## impact across the hold, so the round reads as leaving the barrel
		## rather than as a wire strung between two points for a moment.
		var travel: float = clampf(float(frames) / float(HOLD_FRAMES), 0.0, 1.0)
		var head: Vector2 = from.lerp(to, travel)
		var tail: Vector2 = from.lerp(to, maxf(travel - STREAK_FRACTION, 0.0))
		if head == tail:
			continue
		draw_line(tail, head, Color(TAIL_COLOR, TAIL_COLOR.a * alpha), TAIL_WIDTH_PX)
		draw_line(tail, head, Color(CORE_COLOR, CORE_COLOR.a * alpha), CORE_WIDTH_PX)
		## The head last, so nothing is drawn over it. It shrinks as the round
		## fades instead of only dimming — a dot that dims stays a dot, and this
		## one should read as going away.
		draw_circle(head, HEAD_RADIUS_PX * maxf(alpha, 0.35),
			Color(HEAD_COLOR, HEAD_COLOR.a * alpha))


## The same streak as `_draw()`, in the world: each end lifted from its floor point, so the head travels the real line
## from the muzzle to the impact.
func _draw_world() -> void:
	_world.begin()
	for s in _streaks:
		var frames: int = int(s["frames"])
		var alpha: float = 1.0
		if frames > HOLD_FRAMES:
			alpha = clampf(1.0 - float(frames - HOLD_FRAMES) / float(FADE_FRAMES), 0.0, 1.0)
		var from3: Vector3 = _world.lift(s["from"], s["from_floor"])
		var to3: Vector3 = _world.lift(s["to"], s["to_floor"])
		var travel: float = clampf(float(frames) / float(HOLD_FRAMES), 0.0, 1.0)
		var head: Vector3 = from3.lerp(to3, travel)
		var tail: Vector3 = from3.lerp(to3, maxf(travel - STREAK_FRACTION, 0.0))
		if head.is_equal_approx(tail):
			continue
		_world.line(tail, head, Color(TAIL_COLOR, TAIL_COLOR.a * alpha), TAIL_WIDTH_PX)
		_world.line(tail, head, Color(CORE_COLOR, CORE_COLOR.a * alpha), CORE_WIDTH_PX)
		_world.disc(head, HEAD_RADIUS_PX * maxf(alpha, 0.35), Color(HEAD_COLOR, HEAD_COLOR.a * alpha))
	_world.end()
