extends Node2D
class_name DebugAgent
## The playable agent: owns its grid cell, converts cell → world position, and
## animates step-by-step.
##
## CHARACTER_MASTER_PLAN Part 2 §10 CLOSED 2026-08-16 — the vector placeholder
## that used to live in `_draw()` is gone, replaced by `AgentSprite`, the baked
## figure at three postures and four facings under the room's real lighting. What
## remains of `_draw()` is DEV-ONLY and says so.
##
## The class name still says Debug because renaming it touches every consumer,
## and that is a rename, not this task.

signal move_started(from_cell: Vector2i, to_cell: Vector2i)
signal step_finished(cell: Vector2i)
signal move_finished(cell: Vector2i)
signal posture_changed(new_posture: Posture)

enum Posture { STANDING, CROUCHING, PRONE }

## Current state
var posture: Posture = Posture.STANDING

## AP cost to change posture
const POSTURE_CHANGE_AP := 1

## Visual detection multipliers per posture
const POSTURE_DETECTION_MULT: Dictionary = {
	Posture.STANDING:  1.00,
	Posture.CROUCHING: 0.55,
	Posture.PRONE:     0.20,
}

## Extra movement cost per posture (additional AP tiles)
## Crouching: +1 AP per tile. Prone: cannot move this turn.
const POSTURE_MOVE_AP_COST: Dictionary = {
	Posture.STANDING:  0,
	Posture.CROUCHING: 1,   ## each tile costs +1 extra AP
	Posture.PRONE:     99,  ## cannot move (99 = effective block)
}

## Declared for M3+ (combat) — not used yet
const POSTURE_HIT_MULT: Dictionary = {
	Posture.STANDING:  1.00,
	Posture.CROUCHING: 0.50,
	Posture.PRONE:     0.70,
}
const POSTURE_AIM_MULT: Dictionary = {
	Posture.STANDING:  1.00,
	Posture.CROUCHING: 0.75,
	Posture.PRONE:     0.50,
}

var floor_layer: TileMapLayer = null
var visual_offset: Vector2 = Vector2.ZERO
var cell: Vector2i = Vector2i.ZERO
var vision_radius: int = 7  ## base player visibility radius in tiles; affects enemy fade thresholds
var vision_mode: String = "normal"  ## future modes: thermal, night vision, xray
var is_moving: bool = false
var dev_vision: bool = false

## The baked figure. Null until attach_sprite() succeeds, and every call site
## guards on it: a missing bake must degrade to an invisible agent that still
## plays, never to a crash in the middle of a turn.
var sprite: AgentSprite = null

## DebugAgent.Posture -> AgentSprite's directory name. The mapping lives here
## rather than in AgentSprite so the dependency runs one way: the renderer knows
## nothing about the gameplay enum.
const POSTURE_SPRITE_NAME: Dictionary = {
	Posture.STANDING: "standing",
	Posture.CROUCHING: "crouch",
	Posture.PRONE: "prone",
}

## Cover
enum CoverType { NONE, PARTIAL, FULL }
var cover_state: CoverType = CoverType.NONE
var cover_direction: Vector2i = Vector2i.ZERO  ## direction toward the obstacle

const COVER_FULL_MULT   := 0.20   ## detection probability when in full cover
const COVER_PARTIAL_MULT := 0.55  ## partial cover (only 1 adjacent blocked)

const TILE_CENTER_OFFSET := Vector2(0.0, 64.0)

## Seconds to cross one GU.
##
## ✅ SETTLED 2026-08-16 by blind judgement — §9 #12. **0.56 s per GU = 2.86 m/s.**
## Director, on `p3_step_bracket_blind.mp4`: *"o ritmo é o B mesmo"*, B being the
## 560 ms panel, chosen against 130 / 320 / 950 ms with the labels blind, the
## order seeded, and the slowest deliberately not last.
##
## **The pick was INTERIOR to the range** — 320 ms was faster and 950 ms slower,
## and both were rejected — which is what a real optimum looks like and what
## neither position bias nor "more is always better" can produce. The range did
## not need re-running wider.
##
## What it replaces: 0.13 s, which over a 1.60 m GU (VOXELS_PER_UNIT_AXIS 8 x
## 0.20 m) is **12.3 m/s — faster than the 100 m world record**. That was never a
## bug; it was tuned for a 44x61 px vector diamond with no legs to contradict it.
## Part 2 gave the agent legs and the number stopped surviving contact with them.
##
## A `var`, not a `const`: architecture rule 1 says stats are vars, and the
## bracket sweeps this exact field rather than a parallel test-only path.
var step_duration: float = 0.56

## The body/head colours that used to sit here went with the placeholder they
## existed for — the "replaced by sprites in M3+" that POSTURE_COLORS' own
## comment promised. `guard_enemy.gd` declares its OWN identically-named trio and
## is untouched; the guards are still vector diamonds, which is Part 7.
## Grepped the whole repo before deleting: zero external users. (The 2026-07-12
## `[CLEANUP]` commit that stopped every wall rendering deleted a var that looked
## unused in one file and was written from another — cross-file writes are
## invisible to the linter, so the grep is the check, not the linter.)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.28)

## Where the head marker sits, per posture, in the agent's own local space.
##
## T-ARC (Director, 2026-08-10): "a parábola está começando no pé do agente
## (centro da GU), vamos subir para sair mais ou menos da bolinha branca que
## fica em cima do losângulo verde, que vai corresponder à altura dos braços
## aproximadamente." These numbers used to live only inside `_draw()`'s three
## posture branches; they are a const now because `throw_origin()` below needs
## the same values, and two copies of "where the head is" would drift the first
## time a posture's shape is tuned.
const HEAD_OFFSET: Dictionary = {
	Posture.STANDING: Vector2(0.0, -64.0),
	Posture.CROUCHING: Vector2(0.0, -44.0),
	Posture.PRONE: Vector2(26.0, -10.0),
}


## Where a thrown object leaves this agent, in the same space as `position` —
## roughly arm height, which the head marker already stands for. Crouching and
## prone throws start correspondingly lower, for free.
##
## ⚠️ FIXED 2026-08-19, and the fix CHANGES A SHIPPED ARC on purpose. This used to
## read HEAD_OFFSET directly — vectors tuned on 2026-08-10 (T-ARC) against the
## vector DIAMOND placeholder, which this class stopped drawing on 2026-08-16.
## They put the launch point 64 px up where the baked figure's real drawn reach
## is ~169 px, so the grenade left the agent's WAIST. The same staleness was
## caught on the muzzle first (§6c), fixed there alone, and flagged here rather
## than fixed because moving a tuned ballistic arc deserved its own pass. This is
## that pass: the Director asked for the throw to be built properly, and building
## a throw ANIMATION on top of a launch point that misses the hand by 100 px
## would bake the error into the pose work.
##
## Both readers of this move together — `throw_launch_height()` below returns the
## same vector's magnitude, so the arc's asymmetry stays consistent with where it
## now starts. HEAD_OFFSET survives as the pre-load fallback only.
func throw_origin() -> Vector2:
	return position + _head_anchor()


## The measured head anchor, or the placeholder constant when no frame set is
## loaded yet. ONE function, because the throw, the arc's launch height and the
## muzzle must never disagree about where this figure's hands are.
func _head_anchor() -> Vector2:
	if sprite != null:
		var measured: Vector2 = sprite.head_offset_px()
		if measured != Vector2.ZERO:
			return measured
	return HEAD_OFFSET.get(posture, HEAD_OFFSET[Posture.STANDING])


## WEAPON_MASTER_PLAN §6c Part A — where a SHOT leaves this agent, in the same
## space as `position`.
##
## Derived from the same HEAD_OFFSET anchor `throw_origin()` uses, and that is
## the point of the function existing at all: §6c names the risk in so many
## words — the muzzle *"is the same class of anchor and should not become a
## second, independently-drifting copy."* Two hand-tuned "where the weapon is"
## constants would disagree the first time a posture's shape is tuned, and the
## disagreement would show as a tracer that starts somewhere the figure is not.
##
## MUZZLE_DROP_FRACTION is the one honest difference between a throw and a shot:
## a grenade leaves from above the shoulder, a shouldered weapon's barrel sits a
## little below the head. A fraction rather than a pixel figure, so it holds for
## every posture and every future silhouette.
const MUZZLE_DROP_FRACTION: float = 0.18

## ⚠️ HEAD_OFFSET IS NOT USED HERE, AND THAT IS THE POINT.
##
## Those three vectors were tuned on 2026-08-10 (T-ARC) against the vector
## DIAMOND placeholder — a figure this class stopped drawing on 2026-08-16, when
## SILHOUETTE_WIDTH/HEIGHT below were corrected from 44x61 to the baked 104x222
## and HEAD_OFFSET was not. Reading them costs 64 px where the real drawn reach
## is ~169 px, and the first capture of a shot showed exactly that: the muzzle
## flash went off at the agent's WAIST while the barrel sat at his shoulder.
##
## So the muzzle asks the SPRITE, which reads its own bake's `anchor_px` and
## `head_socket_px` per posture — the same numbers the head layer is registered
## against, so the flash cannot drift from the head it is supposed to be beside.
## HEAD_OFFSET remains the fallback for the frames before a set is loaded.
## `throw_origin()` was corrected the same way on 2026-08-19 — see its own note
## for why that one waited for a reason to move a tuned arc.
func muzzle_origin() -> Vector2:
	var head: Vector2 = _head_anchor()
	return position + head - Vector2(0.0, head.y * MUZZLE_DROP_FRACTION)


## --- The grenade throw (Director, 2026-08-19) --------------------------------
##
## Three passthroughs rather than one with a mode argument, because the three are
## triggered from genuinely different moments in the grenade flow (aim opens, aim
## cancels, throw commits) and a single entry point would make every caller
## restate which of them it meant.
##
## The DURATIONS live in p3_throw_export.py's manifest as `seconds` per sequence,
## because the frame count and the playback rate are one decision — see that
## file's RAISE_SECONDS note. These constants mirror it; if the export's numbers
## change, these follow.
const THROW_RAISE_SECONDS: float = 0.18
const THROW_RELEASE_SECONDS: float = 0.40
## The cancel is FASTER than the raise, on the Director's own word — *"bem
## rapidinho, só pra não sumir de repente."* It is the same frames in reverse, so
## only the duration differs.
const THROW_CANCEL_SECONDS: float = 0.12


## Raise the arm and HOLD the cocked pose for the whole aim.
func play_throw_raise() -> bool:
	if sprite == null:
		return false
	return sprite.play_throw(AgentSprite.THROW_RAISE, THROW_RAISE_SECONDS, true)


## Put it back down along the same path, quickly.
func play_throw_cancel() -> bool:
	if sprite == null:
		return false
	return sprite.play_throw(AgentSprite.THROW_RAISE, THROW_CANCEL_SECONDS,
		false, true)


## Throw. Emits `sprite.throw_released` on the frame the grenade leaves the hand.
func play_throw_release() -> bool:
	if sprite == null:
		return false
	return sprite.play_throw(AgentSprite.THROW_RELEASE, THROW_RELEASE_SECONDS)


## WEAPON_MASTER_PLAN §6c / B4 — raise or lower the held weapon.
##
## A passthrough rather than state of its own: the grip is a property of what is
## DRAWN, and the sprite already owns the "which bake am I showing" question
## (frame_family, posture, dev vision all live there). Duplicating it here would
## make two answers to that question possible.
func set_grip(name: String) -> void:
	if sprite != null:
		sprite.set_grip(name)


## How far above the floor that origin is, in pixels. The ballistic arc needs it
## as a number and not just as a point: a throw released above the plane it lands
## on peaks before halfway and falls longer than it rose, and that asymmetry is
## the whole difference between a real throw and a symmetric bow.
func throw_launch_height() -> float:
	return absf(_head_anchor().y)

## The standing character's on-screen extent (O7 stroke clips to this).
##
## ⚠️ THESE MOVED ON 2026-08-16 AND THE CHANGE IS BEHAVIOURAL, not cosmetic. They
## were 44 x 61, the enclosing rect of the vector DIAMOND — a placeholder that no
## longer exists. The baked figure MEASURES 104 x 222 px (agent_frame_bake_spike,
## standing: 104x217 facing N/E and 104x222 facing S/W, the widest and tallest of
## the four taken), so the old pair understated the agent by 2.4x in width and
## 3.6x in height. The silhouette is taller than the figure's own 189.8 px of
## vertical reach because the body's depth projects into screen-Y as well; the
## drawn extent is the right quantity here, because every consumer asks about
## visual overlap.
##
## `occlusion_set.gd` keeps its OWN copy of this pair on purpose (to stay a
## dependency-free geometry module) with a comment saying to re-sync by hand when
## the agent's on-screen size changes. This is that change, and it is re-synced
## there in the same commit.
const SILHOUETTE_WIDTH := 104.0   ## left-right span of standing character
const SILHOUETTE_HEIGHT := 222.0  ## top-bottom span of standing character
const SILHOUETTE_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.3)  ## semi-transparent white
const SILHOUETTE_OUTLINE_WIDTH := 1.5

var _path_queue: Array[Vector2i] = []

## Progress through the current GU, 0 to 1, tweened by _step_next(). The setter
## is where it reaches the sprite: one walk cycle per GU means this value IS the
## cycle phase, so there is nothing to convert.
var _walk_progress: float = 0.0:
	set(value):
		_walk_progress = value
		if sprite != null:
			sprite.set_walk_phase(value)


func setup(tile_layer: TileMapLayer, offset: Vector2, start_cell: Vector2i) -> void:
	floor_layer = tile_layer
	visual_offset = offset
	set_cell(start_cell)


## Part 2 §10's swap. Separate from `setup()` because the sprite needs `room` and
## `setup()` is called with a TileMapLayer — and because a caller that has no
## room (a headless selftest) must still get a working agent.
func attach_sprite(p_room: Node) -> bool:
	if sprite != null:
		return true
	var s := AgentSprite.new()
	s.name = "AgentSprite"
	add_child(s)
	if not s.setup(p_room):
		## The bake is missing or unreadable. Loud-failed already by AgentSprite;
		## drop the node rather than leave an invisible child that makes the agent
		## silently vanish from the map.
		s.queue_free()
		return false
	sprite = s
	sprite.set_posture_name(POSTURE_SPRITE_NAME[posture])
	return true


func set_cell(new_cell: Vector2i) -> void:
	cell = new_cell
	position = _cell_to_world(new_cell)
	if sprite != null:
		sprite.update_for_cell()
	queue_redraw()


func get_vision_radius() -> int:
	return vision_radius


func set_posture(new_posture: Posture) -> void:
	if new_posture == posture:
		return
	posture = new_posture
	if sprite != null:
		sprite.set_posture_name(POSTURE_SPRITE_NAME[posture])
	posture_changed.emit(posture)
	queue_redraw()


## Mirrors `dev_vision` onto the sprite's second bake (yellow joints). Called by
## room.gd's one dev switch, the same one the probes already follow.
func set_dev_vision(enabled: bool) -> void:
	dev_vision = enabled
	if sprite != null:
		sprite.set_dev_vision(enabled)
	queue_redraw()


## The room rotated. The agent's cell is re-derived by room.gd; its FACING has to
## make the same trip, and does — AgentSprite stores the facing in base space and
## recomposes it against the live perspective, so this only has to ask for a
## refresh.
func on_perspective_changed() -> void:
	if sprite != null:
		sprite.update_for_cell()


func update_cover(blocked_cells: Dictionary) -> void:
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var blocked_count := 0
	var last_blocked_dir := Vector2i.ZERO

	for dir in dirs:
		if blocked_cells.has(cell + dir):
			blocked_count += 1
			last_blocked_dir = dir

	if blocked_count == 0:
		cover_state   = CoverType.NONE
		cover_direction = Vector2i.ZERO
	elif blocked_count == 1:
		cover_state   = CoverType.PARTIAL
		cover_direction = last_blocked_dir
	else:
		cover_state   = CoverType.FULL
		cover_direction = last_blocked_dir  ## primary direction

	queue_redraw()


## Animate the agent along every cell in `path` (must include the start cell).
## Emits step_finished(cell) on each arrival; move_finished(cell) at the end.
func move_along_path(path: Array[Vector2i]) -> void:
	if path.size() < 2:
		return
	is_moving = true
	move_started.emit(path[0], path.back())
	_path_queue = path.duplicate()
	_path_queue.pop_front()  ## already at path[0] — skip it
	_step_next()


func _step_next() -> void:
	if _path_queue.is_empty():
		is_moving = false
		if sprite != null:
			sprite.stop_walking()
		move_finished.emit(cell)
		queue_redraw()
		return

	var next_cell: Vector2i = _path_queue.pop_front()

	## D47: the facing SNAPS at the GU boundary, with no transition frames. The
	## Director judged that blind on 2026-08-15 against three alternatives, and it
	## is the row that keeps the body budget at 744 sets instead of 4608 — so the
	## facing is set here, once, from the step's own direction, and nothing
	## interpolates it. Read BEFORE `cell` advances, because the direction is the
	## difference between where he is and where he is going.
	if sprite != null:
		sprite.face_step(next_cell - cell)

	cell = next_cell  ## logical cell advances immediately

	## LINEAR, not EASE_IN_OUT, and that is the second half of §9 #12.
	## `_step_next()` builds a fresh tween PER TILE, so an eased one made a
	## five-GU path into five accelerate-decelerate cycles. With a diamond that
	## reads fine. With legs it is the direct obstacle to the Director's
	## *"movimentos únicos"*: the walk cadence is driven by distance, so an eased
	## step would make the feet speed up and stall inside every single tile while
	## the body glided. Linear per tile, chained end to end, is one constant-speed
	## walk across the whole path — which is what a walk cycle assumes.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_parallel(true)
	tween.tween_property(self, "position", _cell_to_world(next_cell), step_duration)
	## One walk cycle per GU (p3_walk_export.py derives it from stride vs GU), so
	## the step's own progress IS the cycle phase, tweened alongside the position
	## rather than accumulated — nothing to drift over a long path.
	_walk_progress = 0.0
	tween.tween_property(self, "_walk_progress", 1.0, step_duration)
	tween.chain().tween_callback(func() -> void:
		step_finished.emit(next_cell)
		queue_redraw()
		_step_next()
	)


func _cell_to_world(map_cell: Vector2i) -> Vector2:
	if floor_layer == null:
		return Vector2.ZERO
	return floor_layer.map_to_local(map_cell) + TILE_CENTER_OFFSET + visual_offset


## PART 2 §10: the three posture diamonds and the head circle that used to be
## drawn here are GONE. `AgentSprite`, a child node, draws the agent now.
##
## Two things survive, and both are deliberate rather than leftovers:
##
## 1. THE GROUND SHADOW STAYS, and it is the one place this file still draws the
##    character. AgentProbeProp ships without one on purpose — it fakes a shadow
##    the way GrenadeProp does, by squashing the sprite's own silhouette on Y,
##    which on a 2 m standing figure is a long smear rather than a footprint. A
##    DRAWN contact ellipse is not that substitution: it does not pretend to be
##    the figure's shape, it just says where the feet are, which is exactly what
##    the probe's header names as missing. The honest lit version is still a
##    separate top-down pass, and still unbuilt.
##
## 2. THE DEBUG RECT IS NOW DEV-ONLY. It used to draw unconditionally, which was
##    invisible-ish over a flat green diamond and is a white box around a
##    character. §10 says the placeholder is gone; a stroke that was part of it
##    does not get to stay on screen by being useful.
func _draw() -> void:
	var shadow := PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(28.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-28.0, 0.0),
	])
	draw_colored_polygon(shadow, COLOR_SHADOW)

	if not dev_vision:
		return

	_draw_silhouette_placeholder()

	## Ring around the agent colored by cover level
	var ring_color := Color.TRANSPARENT
	match cover_state:
		CoverType.PARTIAL: ring_color = Color(0.2, 0.6, 1.0, 0.6)
		CoverType.FULL:    ring_color = Color(0.1, 0.4, 0.9, 0.9)
	if ring_color.a > 0.0:
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, ring_color, 2.5)

## The agent's on-screen extent, as a dev overlay. OCC-04 renders a stroke within
## this rect, masked to the occluded-cell region.
func _draw_silhouette_placeholder() -> void:
	var half_w := SILHOUETTE_WIDTH * 0.5
	var points := PackedVector2Array([
		Vector2(-half_w, -SILHOUETTE_HEIGHT),
		Vector2( half_w, -SILHOUETTE_HEIGHT),
		Vector2( half_w,  0.0),
		Vector2(-half_w,  0.0),
	])
	draw_polyline(points + PackedVector2Array([points[0]]), SILHOUETTE_OUTLINE_COLOR, SILHOUETTE_OUTLINE_WIDTH)
