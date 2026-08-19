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
## MEASURED, then raised. At 0.05 s the streak crossed the whole map in three
## frames at 60 Hz and the evidence capture caught it already parked against the
## far wall — a projectile the player cannot see is not decoration, it is a
## rounding error. 0.14 s puts the flight at ~8 frames, which is short enough to
## read as a round and long enough to read at all.
const HOLD_S: float = 0.14
const FADE_S: float = 0.16

## How much of the segment the drawn streak occupies, as a fraction — a round is
## a streak, not a line connecting two dots, so it is drawn as the LAST slice of
## the path travelling outward rather than the whole span at once.
const STREAK_FRACTION: float = 0.35

## Each entry: {"from": Vector2, "to": Vector2, "age": float}. World space, the
## same space the overlay's own transform is in.
var _streaks: Array = []


func _ready() -> void:
	z_index = 4000
	set_process(false)


## Draw one round. `from` and `to` are world-space points; the caller owns both,
## because the caller is the only scope that knows the muzzle AND the impact.
func add_tracer(from: Vector2, to: Vector2) -> void:
	if from == to:
		return
	_streaks.append({"from": from, "to": to, "age": 0.0})
	set_process(true)
	queue_redraw()


func clear_tracers() -> void:
	_streaks.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var alive: Array = []
	for s in _streaks:
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) < HOLD_S + FADE_S:
			alive.append(s)
	_streaks = alive
	if _streaks.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for s in _streaks:
		var age: float = float(s["age"])
		## Alpha holds, then ramps down. Explicit float division throughout —
		## an INTEGER_DIVISION warning here would be a real bug in the ramp.
		var alpha: float = 1.0
		if age > HOLD_S:
			alpha = clampf(1.0 - (age - HOLD_S) / FADE_S, 0.0, 1.0)
		var from: Vector2 = s["from"]
		var to: Vector2 = s["to"]
		## The streak travels: its trailing end walks from the muzzle to the
		## impact across the hold, so the round reads as leaving the barrel
		## rather than as a wire strung between two points for a moment.
		var travel: float = clampf(age / maxf(HOLD_S, 0.0001), 0.0, 1.0)
		var head: Vector2 = from.lerp(to, travel)
		var tail: Vector2 = from.lerp(to, maxf(travel - STREAK_FRACTION, 0.0))
		if head == tail:
			continue
		draw_line(tail, head, Color(TAIL_COLOR, TAIL_COLOR.a * alpha), TAIL_WIDTH_PX)
		draw_line(tail, head, Color(CORE_COLOR, CORE_COLOR.a * alpha), CORE_WIDTH_PX)
