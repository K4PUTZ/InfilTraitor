## AgentSprite — WHAT an actor's figure is doing: its facing, posture, grip, weapon, walk, throw and head. It draws
## nothing; `ActorMesh3D` draws it (RENDER3D R3D-ACTORS, `ACTOR` D64).
##
## R3D-ACTORS step 5 (2026-10-01) RETIRED THE GAMEPLAY FRAME BAKE from this node: the colour/normal frame sets, the head
## and hat layers, the per-posture anchors and D17's normal-map relight are gone, and with them every texture this file
## loaded (D42's RAM was the atlases'). What stayed is the half both renderers shared, unchanged in meaning:
##
##  - FACING, SNAPPED AT THE GU BOUNDARY (D47), one of FOUR (D44, kept for gameplay at step 2: the mesh could turn to any
##    yaw, but whether movement keeps four facings is a design question, and keeping it changes nothing). Stored as the
##    BASE grid step it came from, so it survives a camera turn by construction.
##  - THE POSTURE, THE GRIP, THE WEAPON. Each is now a name the live rig has an action for
##    (`tools/asset_generation/r3d_live_rig_export.py`); a name it does not have is refused loudly and the previous one kept.
##  - THE WALK, read straight off the step's progress (one cycle per GU, D61): no accumulator to drift. Standing only, as
##    before: a crouched or prone figure slides.
##  - THE THROW: raise (held for the aim), release, and the cancel as the raise played backwards (the Director's own
##    reuse rule). `throw_released` fires when the release crosses THROW_RELEASE_FRACTION — the fraction of the key list
##    p3_throw_export.py releases at — and at the latest when the release ends, because `execute_grenade_throw()` awaits
##    it. Standing only, as the bake was.
##  - THE HEAD'S GRID ANGLE (a guard looking where its cone points), clamped to HEAD_YAW_LIMIT_DEG off the body by the mesh.
##
## The class keeps its name and its `Sprite2D` base so every caller (agent, guards, controllers) is untouched; the node is
## hidden by the mesh that draws it and is only ever a holder of state.
class_name AgentSprite
extends Sprite2D

const THROW_RAISE := "raise"
const THROW_RELEASE := "release"
## KEYS_RELEASE in p3_throw_export.py is [COCKED, WIND, RELEASE, FOLLOW, IDLE]: the grenade leaves on the third of five
## keys, half way through the sequence.
const THROW_RELEASE_FRACTION: float = 0.5
const HEAD_YAW_LIMIT_DEG := 60.0
const POSTURES: PackedStringArray = ["standing", "crouch", "prone"]
## Grip suffixes the rig has actions for ("" = lowered).
const GRIPS: PackedStringArray = ["", "_aimed"]
## Weapon suffixes the rig holds ("" = the shotgun). The rifle has no grip in p2_grip_spike.GRIPS yet.
const WEAPONS: PackedStringArray = ["", "_pistol"]
const STEPS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## The facing a figure starts with: the step the bake's "N" frame drew (screen NE on the N lattice).
const START_STEP := Vector2i(0, -1)

## Which model the figure wears ("" = the agent, "_enemy_white" = the guard): `ActorMesh3D.RIG_BY_FAMILY`.
var frame_family: String = ""
var grip: String = ""
var weapon: String = ""
var room: Node = null

signal throw_released

var _posture: String = "standing"
var _facing_step: Vector2i = START_STEP
var _walk_progress: float = -1.0
var _head_grid_deg: float = 0.0
var _has_head_yaw: bool = false
var _dev_vision: bool = false
var _throw_seq: String = ""
var _throw_t: float = 0.0
var _throw_seconds: float = 0.0
var _throw_reversed: bool = false
var _throw_hold: bool = false
var _throw_released_sent: bool = false
var _warned: Dictionary = {}


func setup(p_room: Node) -> bool:
	room = p_room
	set_process(true)
	return true


## D47's snap: the facing is set once per step, from the step's own (BASE) direction, and nothing interpolates.
func face_step(step: Vector2i) -> void:
	if not STEPS.has(step):
		return
	_facing_step = step


## An arbitrary direction, reduced to the nearest of D44's four: the guards snap to eight and a diagonal has no facing
## of its own, so the dominant axis is the honest reduction (and the rule lives here, not in every caller).
func face_direction(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	if absi(dir.x) >= absi(dir.y):
		face_step(Vector2i(signi(dir.x), 0))
	else:
		face_step(Vector2i(0, signi(dir.y)))


func set_posture_name(name: String) -> void:
	if not POSTURES.has(name):
		_warn_once("posture:" + name, "[AgentSprite] no posture '%s' in the live rig — keeping '%s'" % [name, _posture])
		return
	_posture = name


func set_grip(name: String) -> void:
	if not GRIPS.has(name):
		_warn_once("grip:" + name, "[AgentSprite] no '%s' grip in the live rig — keeping '%s'. Add it to p2_grip_spike.GRIPS and re-run r3d_live_rig_export.py."
			% [name, grip if grip != "" else "lowered"])
		return
	grip = name


## Nothing to load any more: every grip the rig has is resident with it. Kept for the callers that warm a grip ahead of
## the click that shows it (W-LOAD-02).
func preload_grip(name: String) -> bool:
	return GRIPS.has(name)


## W-WEAPON-01 — the HELD weapon, as its suffix ("" = shotgun). A weapon the rig does not hold is refused once, loudly,
## and the figure keeps the one it has.
func set_weapon_bake(name: String) -> bool:
	if not WEAPONS.has(name):
		_warn_once("weapon:" + name, "[AgentSprite] the live rig holds no '%s' — the figure keeps the %s. Add its grip to p2_grip_spike.GRIPS and WEAPONS, and re-run r3d_live_rig_export.py."
			% [name.trim_prefix("_"), weapon.trim_prefix("_") if weapon != "" else "shotgun"])
		return false
	weapon = name
	return true


## Kept for the dev bracket's call; the walk is continuous now, so there is nothing to quantise.
func set_walk_phase_quantise(_n: int) -> void:
	pass


## `progress01` is how far through the CURRENT GU the agent is: one cycle is one GU exactly, so it is also the phase.
func set_walk_phase(progress01: float) -> void:
	if _posture != "standing":
		return
	_walk_progress = fposmod(progress01, 1.0)


func stop_walking() -> void:
	_walk_progress = -1.0


## Where the head is looking, as a GRID angle in degrees (0 = North, +90 = East: the guard's `vision_angle` convention).
func set_head_yaw_grid_deg(grid_deg: float) -> void:
	_head_grid_deg = grid_deg
	_has_head_yaw = true


func clear_head_yaw() -> void:
	_has_head_yaw = false


## Kept for the DEV VISION toggle's call. The yellow-joint dev bake it used to swap in retired with the frame bake; the live
## rig has one look, so the flag is only remembered.
func set_dev_vision(enabled: bool) -> void:
	_dev_vision = enabled


## The facing is base-space state and the mesh re-reads everything each frame, so a step or a view change has nothing
## to refresh here.
func update_for_cell() -> void:
	pass


## Where the head is above the feet, in 2D canvas pixels on the N lattice: the live rig's head bone, asked of the mesh
## that draws this figure. ZERO when no mesh draws it (a headless selftest); the agent then falls back to HEAD_OFFSET.
func head_offset_px() -> Vector2:
	var figure: Variant = get_meta("figure3d") if has_meta("figure3d") else null
	if figure != null and is_instance_valid(figure) and (figure as Object).has_method("head_offset_px"):
		return (figure as Object).call("head_offset_px")
	return Vector2.ZERO


## A one-shot the player triggered, which outranks the walk and the idle pose while it plays. Standing only.
func play_throw(sequence: String, seconds: float, hold: bool = false, reversed_playback: bool = false) -> bool:
	if sequence != THROW_RAISE and sequence != THROW_RELEASE:
		return false
	if _posture != "standing":
		_warn_once("throw:" + _posture, "[AgentSprite] no '%s' throw in the live rig (standing only, as the bake was)" % _posture)
		return false
	_throw_seq = sequence
	_throw_seconds = maxf(seconds, 0.001)
	_throw_t = 0.0
	_throw_hold = hold
	_throw_reversed = reversed_playback
	_throw_released_sent = false
	return true


func stop_throw() -> void:
	_throw_seq = ""
	_throw_hold = false
	_throw_reversed = false


## What this figure is doing, for `ActorMesh3D`: the facing as the BASE grid step it was set from, the walk progress, and
## the throw's `u` with the cancel's reversal already applied.
func mesh_state() -> Dictionary:
	var throw_u: float = -1.0
	if _throw_seq != "":
		throw_u = clampf(_throw_t / _throw_seconds, 0.0, 1.0)
		if _throw_reversed:
			throw_u = 1.0 - throw_u
	return {
		"step": _facing_step,
		"posture": _posture,
		"grip": grip,
		"weapon": weapon,
		"walk": _walk_progress if _posture == "standing" else -1.0,
		"throw": _throw_seq,
		"throw_u": throw_u,
		"head": _head_grid_deg if _has_head_yaw else NAN,
	}


func _process(delta: float) -> void:
	if _throw_seq == "" or (_throw_hold and _throw_t >= _throw_seconds):
		return
	var before: float = _throw_t / _throw_seconds
	_throw_t = minf(_throw_t + delta, _throw_seconds)
	var after: float = _throw_t / _throw_seconds
	var releasing: bool = _throw_seq == THROW_RELEASE and not _throw_reversed
	if releasing and not _throw_released_sent and before < THROW_RELEASE_FRACTION and after >= THROW_RELEASE_FRACTION:
		_throw_released_sent = true
		throw_released.emit()
	if _throw_t < _throw_seconds or _throw_hold:
		return
	## GUARANTEED, NOT MERELY LIKELY: `execute_grenade_throw()` awaits `throw_released`, so a release that ends without it
	## would hang the throw forever. By the end of a release the round has left the hand by definition.
	if releasing and not _throw_released_sent:
		_throw_released_sent = true
		throw_released.emit()
	stop_throw()


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)
