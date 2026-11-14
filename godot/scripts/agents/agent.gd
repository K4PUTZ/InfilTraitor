extends Node2D
class_name Agent
const GroundGridRef = preload("res://godot/scripts/geometry/ground_grid.gd")  ## R3D-5a: the cell lattice, no TileMapLayer
## The playable agent: owns its grid cell, converts cell → world position, and
## animates step-by-step.
##
## CHARACTER_MASTER_PLAN Part 2 §10 CLOSED 2026-08-16 — the vector placeholder
## that used to live in `_draw()` is gone, replaced by `ActorPose`, the baked
## figure at three postures and four facings under the room's real lighting. What
## remains of `_draw()` is DEV-ONLY and says so.
##
## The class name still says Debug because renaming it touches every consumer,
## and that is a rename, not this task.

signal move_started(from_cell: Vector2i, to_cell: Vector2i)
signal step_finished(cell: Vector2i)
signal move_finished(cell: Vector2i)

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

var visual_offset: Vector2 = Vector2.ZERO
var cell: Vector2i = Vector2i.ZERO
var vision_radius: int = 7  ## base player visibility radius in tiles; affects enemy fade thresholds
var is_moving: bool = false
var dev_vision: bool = false

## The baked figure. Null until attach_pose() succeeds, and every call site
## guards on it: a missing bake must degrade to an invisible agent that still
## plays, never to a crash in the middle of a turn.
var pose: ActorPose = null

## Agent.Posture -> ActorPose's directory name. The mapping lives here
## rather than in ActorPose so the dependency runs one way: the renderer knows
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
## Seconds per GU of a DASH (both AP on one move). ASSUMPTION, not yet ratified: D61 fixes only the walk's 0.56 s; the run gets its own tempo.
var dash_step_duration: float = 0.32
var _dashing: bool = false

## The body/head colours that used to sit here went with the placeholder they
## existed for — the "replaced by sprites in M3+" that POSTURE_COLORS' own
## comment promised. `guard_enemy.gd` declares its OWN identically-named trio and
## is untouched; the guards are still vector diamonds, which is Part 7.
## Grepped the whole repo before deleting: zero external users. (The 2026-07-12
## `[CLEANUP]` commit that stopped every wall rendering deleted a var that looked
## unused in one file and was written from another — cross-file writes are
## invisible to the linter, so the grep is the check, not the linter.)

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
	if pose != null:
		var measured: Vector2 = pose.head_offset_px()
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
## HERITAGE T2 W4 — the shot's origin as the pair the effects take: {"pos": 2D point, "floor": 2D floor under it}. From the
## held weapon's muzzle (`ActorMesh3D.muzzle_global()`) when one is drawn; otherwise the old head-based estimate with its
## floor at the feet (the old rig, a headless run).
func muzzle_points() -> Dictionary:
	var figure: Variant = pose.get_meta("figure3d") if pose != null and pose.has_meta("figure3d") else null
	if figure != null and is_instance_valid(figure) and (figure as Object).has_method("muzzle_global"):
		var g: Vector3 = (figure as Object).call("muzzle_global")
		var board: Node = (figure as Node).get_parent()
		while board != null and not board.has_method("lift_pair_of_global"):
			board = board.get_parent()
		if g != Vector3.INF and board != null:
			var pair: Array = board.call("lift_pair_of_global", g)
			return {"pos": pair[0], "floor": pair[1]}
	return {"pos": muzzle_origin(), "floor": position}


## MOVEMENT 2026-11-12 — where the thrown grenade leaves, as the pair the flight takes ({"pos": 2D point, "floor": 2D floor under it, "launch": height in px}): the
## grenade's last place in the figure's hand (`ActorMesh3D.throw_release_global()`); empty when the figure has no throw timeline (the caller keeps `throw_origin()`).
func grenade_release_points() -> Dictionary:
	var figure: Variant = pose.get_meta("figure3d") if pose != null and pose.has_meta("figure3d") else null
	if figure == null or not is_instance_valid(figure) or not (figure as Object).has_method("throw_release_global"):
		return {}
	var g: Vector3 = (figure as Object).call("throw_release_global")
	var board: Node = (figure as Node).get_parent()
	while board != null and not board.has_method("lift_pair_of_global"):
		board = board.get_parent()
	if g == Vector3.INF or board == null:
		return {}
	var pair: Array = board.call("lift_pair_of_global", g)
	return {"pos": pair[0], "floor": pair[1], "launch": maxf((pair[1] as Vector2).y - (pair[0] as Vector2).y, 0.0)}


## MOVEMENT 2026-11-12 — the shot on the figure: the arms and the gun kick and a case is thrown (`ActorMesh3D.fire_kick()`). False when the figure
## draws no gun (the old rig, a headless run): nothing kicks.
func play_shot_kick() -> bool:
	var figure: Variant = pose.get_meta("figure3d") if pose != null and pose.has_meta("figure3d") else null
	if figure != null and is_instance_valid(figure) and (figure as Object).has_method("fire_kick"):
		return bool((figure as Object).call("fire_kick"))
	return false


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
	if pose == null:
		return false
	return pose.play_throw(ActorPose.THROW_RAISE, THROW_RAISE_SECONDS, true)


## Put it back down along the same path, quickly.
func play_throw_cancel() -> bool:
	if pose == null:
		return false
	return pose.play_throw(ActorPose.THROW_RAISE, THROW_CANCEL_SECONDS,
		false, true)


## Throw. Emits `sprite.throw_released` on the frame the grenade leaves the hand.
func play_throw_release() -> bool:
	if pose == null:
		return false
	return pose.play_throw(ActorPose.THROW_RELEASE, THROW_RELEASE_SECONDS)


## WEAPON_MASTER_PLAN §6c / B4 — raise or lower the held weapon.
##
## A passthrough rather than state of its own: the grip is a property of what is
## DRAWN, and the sprite already owns the "which bake am I showing" question
## (frame_family, posture, dev vision all live there). Duplicating it here would
## make two answers to that question possible.
func set_grip(name: String) -> void:
	if pose != null:
		pose.set_grip(name)


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

var _path_queue: Array[Vector2i] = []

## Progress through the current GU, 0 to 1, tweened by _step_next(). The setter
## is where it reaches the sprite: one walk cycle per GU means this value IS the
## cycle phase, so there is nothing to convert.
var _walk_progress: float = 0.0:
	set(value):
		_walk_progress = value
		if pose != null:
			pose.set_walk_phase(value)


func setup(offset: Vector2, start_cell: Vector2i) -> void:
	visual_offset = offset
	set_cell(start_cell)


## Part 2 §10's swap. Separate from `setup()` because the sprite needs `room` and
## `setup()` is called with a TileMapLayer — and because a caller that has no
## room (a headless selftest) must still get a working agent.
func attach_pose(p_room: Node) -> bool:
	if pose != null:
		return true
	var s := ActorPose.new()
	s.name = "ActorPose"
	add_child(s)
	if not s.setup(p_room):
		## The bake is missing or unreadable. Loud-failed already by ActorPose;
		## drop the node rather than leave an invisible child that makes the agent
		## silently vanish from the map.
		s.queue_free()
		return false
	pose = s
	pose.set_posture_name(POSTURE_SPRITE_NAME[posture])
	return true


func set_cell(new_cell: Vector2i) -> void:
	cell = new_cell
	position = _cell_to_world(new_cell)
	if pose != null:
		pose.update_for_cell()
	queue_redraw()


func get_vision_radius() -> int:
	return vision_radius


func set_posture(new_posture: Posture) -> void:
	if new_posture == posture:
		return
	posture = new_posture
	if pose != null:
		pose.set_posture_name(POSTURE_SPRITE_NAME[posture])
	queue_redraw()


## Mirrors `dev_vision` onto the sprite's second bake (yellow joints). Called by
## room.gd's one dev switch, the same one the probes already follow.
func set_dev_vision(enabled: bool) -> void:
	dev_vision = enabled
	if pose != null:
		pose.set_dev_vision(enabled)
	queue_redraw()


## The camera turned (R3D-ROT: the cell never moves). ActorPose stores the facing in base space and
## recomposes it against the live view, so this only has to ask for a refresh.
func on_perspective_changed() -> void:
	if pose != null:
		pose.update_for_cell()


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
func move_along_path(path: Array[Vector2i], dash: bool = false) -> void:
	if path.size() < 2:
		return
	is_moving = true
	_dashing = dash
	if pose != null:
		pose.set_dash(dash)
	move_started.emit(path[0], path.back())
	_path_queue = path.duplicate()
	_path_queue.pop_front()  ## already at path[0] — skip it
	_start_profile = _dash_start_profile() if dash else {}
	_step_next()


## The run's START (MOVEMENT 2026-11-14): a dash from standing does not leave at full speed. The figure's authored start (`ActorPose.dash_start`: the
## ground its body covers, frame by frame, the support foot planted) drives the first step instead of the linear tween; it is played `rate` times
## faster than authored so it ends at this dash's own speed, then the step goes on linearly. {} = no start (none authored, or longer than one GU).
var _start_profile: Dictionary = {}


func _dash_start_profile() -> Dictionary:
	if pose == null or pose.dash_start.is_empty():
		return {}
	var dist: PackedFloat32Array = pose.dash_start["dist"]
	var fps: float = float(pose.dash_start["fps"])
	var n: int = dist.size()
	if n < 2 or dist[n - 1] >= 1.0:
		push_warning("[Agent] the run's start covers %.2f GU: not used (it must end inside the first GU)" % (dist[n - 1] if n > 0 else 0.0))
		return {}
	var v_end: float = (dist[n - 1] - dist[n - 2]) * fps   ## GU a second, authored
	var rate: float = (1.0 / dash_step_duration) / v_end if v_end > 0.0 else 1.0
	pose.dash_rate = rate
	return {"dist": dist, "fps": fps * rate, "seconds": float(n - 1) / (fps * rate)}


## Ground covered `t` seconds into the first step of a started dash (GU).
func _start_distance(profile: Dictionary, t: float) -> float:
	var dist: PackedFloat32Array = profile["dist"]
	var seconds: float = float(profile["seconds"])
	if t >= seconds:
		return dist[dist.size() - 1] + (t - seconds) / dash_step_duration
	var f: float = t * float(profile["fps"])
	var a: int = int(floor(f))
	return lerpf(dist[a], dist[mini(a + 1, dist.size() - 1)], f - float(a))


func _step_next() -> void:
	if _path_queue.is_empty():
		is_moving = false
		_dashing = false
		if pose != null:
			pose.stop_walking()
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
	if pose != null:
		pose.face_step(next_cell - cell)

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
	if not _start_profile.is_empty():
		## the dash's first step from standing: the authored start's own pace, then linear to the end of the GU (see `_dash_start_profile`)
		var from: Vector2 = position
		var to: Vector2 = _cell_to_world(next_cell)
		var profile: Dictionary = _start_profile
		var seconds: float = float(profile["seconds"]) + (1.0 - _start_distance(profile, float(profile["seconds"]))) * dash_step_duration
		_walk_progress = 0.0
		tween.tween_method(func(t: float) -> void:
			var s: float = clampf(_start_distance(profile, t), 0.0, 1.0)
			position = from.lerp(to, s)
			_walk_progress = s, 0.0, seconds, seconds)
		_start_profile = {}
		tween.chain().tween_callback(func() -> void:
			step_finished.emit(next_cell)
			queue_redraw()
			_step_next()
		)
		return
	tween.tween_property(self, "position", _cell_to_world(next_cell), dash_step_duration if _dashing else step_duration)
	## One walk cycle per GU (p3_walk_export.py derives it from stride vs GU), so
	## the step's own progress IS the cycle phase, tweened alongside the position
	## rather than accumulated — nothing to drift over a long path.
	_walk_progress = 0.0
	tween.tween_property(self, "_walk_progress", 1.0, dash_step_duration if _dashing else step_duration)
	tween.chain().tween_callback(func() -> void:
		step_finished.emit(next_cell)
		queue_redraw()
		_step_next()
	)


func _cell_to_world(map_cell: Vector2i) -> Vector2:
	return GroundGridRef.map_to_local(map_cell) + TILE_CENTER_OFFSET + visual_offset


## PART 2 §10: the three posture diamonds and the head circle that used to be drawn here are GONE, and (RETIRE-2D) so are the 2D contact
## shadow, the 104 x 222 silhouette stroke and the 2D cover ring: `ActorMesh3D` draws the figure and its shadow, and the cover ring is a
## ground canvas on the 3D board (below). With no board nothing is drawn.
const COVER_RING_RADIUS_PX := 30.0
const COVER_RING_SEGMENTS := 32
var _ground: GroundCanvas3D = null


## The 3D board: the dev-vision cover ring draws on its ground (called when the actor's mesh is attached).
func set_board3d(board: Node3D) -> void:
	if _ground != null:
		_ground.detach()
		_ground = null
	if board != null:
		_ground = GroundCanvas3D.new()
		_ground.attach(board, 8, 0.03, false)
		_ground.follow_visibility_of(self)
	queue_redraw()


func _exit_tree() -> void:
	if _ground != null:
		_ground.detach()
		_ground = null


func _draw() -> void:
	if _ground == null:
		return
	_ground.begin(self)
	## Dev vision: a ring around the agent coloured by cover level.
	var ring_color := Color.TRANSPARENT
	if dev_vision:
		match cover_state:
			CoverType.PARTIAL: ring_color = Color(0.2, 0.6, 1.0, 0.6)
			CoverType.FULL:    ring_color = Color(0.1, 0.4, 0.9, 0.9)
	if ring_color.a > 0.0:
		var ring := PackedVector2Array()
		for i in range(COVER_RING_SEGMENTS + 1):
			var a: float = TAU * float(i) / float(COVER_RING_SEGMENTS)
			ring.append(Vector2(cos(a), sin(a)) * COVER_RING_RADIUS_PX)
		_ground.draw_polyline(ring, ring_color, 2.5)
	_ground.end()
