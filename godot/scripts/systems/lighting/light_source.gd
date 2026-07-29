## LightSource — Explicit light entity with semantic ownership
## 
## Foundation for tactical lighting system. Defines:
## - Spatial properties (position, height, radius)
## - Type semantics (omni, directional, cone, ambient)
## - Energy levels (tactical, visual)
## - Direction for directional/cone types
##
## Does NOT define:
## - shadow projection
## - exposure calculation
## - color/visual appearance
## - runtime animation

class_name LightSource
extends RefCounted

# Light type constants (semantic names, not magic numbers)
const TYPE_OMNI := "omni"
const TYPE_DIRECTIONAL := "directional"
const TYPE_CONE := "cone"
const TYPE_AMBIENT := "ambient"
const TYPE_INTERMITTENT := "intermittent"
const TYPE_EMERGENCY := "emergency"
const TYPE_MOBILE := "mobile"

# Height class constants (from L-DOC-02)
const HEIGHT_FLOOR := 0
const HEIGHT_LOW_COVER := 1
const HEIGHT_HUMAN := 2
const HEIGHT_TALL_STRUCTURE := 3
const HEIGHT_OVERHEAD := 4

# Spatial properties
var cell: Vector2i = Vector2i.ZERO
var height_class: int = HEIGHT_OVERHEAD

# Type and range
var light_type: String = TYPE_OMNI
var radius: int = 5
var active: bool = true

# Direction (for directional/cone types)
var direction_angle: float = 0.0  # Radians, 0 = right/east
var cone_angle: float = 90.0  # Degrees, cone spread

# Energy levels
var tactical_energy: float = 1.0  ## Affects shadow strength and detection multiplier
var visual_energy: float = 1.0    ## Affects brightness (not used for gameplay)

# ============================================================================
# Temporal Properties (L-IMP-06) — Simple, deterministic animation
# ============================================================================

# Flicker behavior — NEON-FLICKER-01 (Director, 2026-07-28): a failing neon tube,
# not a metronome. Lit far longer than dark, and the dark part arrives as a short
# BURST of irregular blips (off/on/off/on) rather than one fixed half-cycle.
#
# Event-driven on purpose. energy_multiplier changing is what schedules a repaint
# of the light's influence set (room._update_temporal_lights), so a continuous
# analog wobble would repaint EVERY frame; discrete states with irregular
# durations give the flicker its variety at ~2-3 repaints/second, the same order
# as the old 50/50 square wave (1.67/s at the PLAYGROUND lamp's 0.6s interval).
var flicker_enabled: bool = false
var flicker_interval: float = 1.0  ## Base LIT time; the real hold is this × FLICKER_ON_HOLD_MIN..MAX
var flicker_phase: float = 0.0     ## Seconds remaining in the current flicker state

## Lit stretch between bursts, as a multiple of flicker_interval — the "acesa
## mais tempo que apagada" half of the effect.
const FLICKER_ON_HOLD_MIN := 2.0
const FLICKER_ON_HOLD_MAX := 6.0
## One burst = this many dark blips, each followed by a brief re-light.
const FLICKER_BLIPS_MIN := 1
const FLICKER_BLIPS_MAX := 4
## Blip durations (seconds). Dark is kept shorter than the re-light on average so
## even mid-burst the tube reads as struggling-but-on, never as strobing.
const FLICKER_BLIP_OFF_MIN := 0.03
const FLICKER_BLIP_OFF_MAX := 0.16
const FLICKER_BLIP_ON_MIN := 0.04
const FLICKER_BLIP_ON_MAX := 0.22
## Some blips only BROWN OUT instead of cutting to black — the difference between
## a tube that stutters and one that just switches.
const FLICKER_DIM_ENERGY := 0.18
const FLICKER_DIM_CHANCE := 0.35

## Per-light stream, seeded from the light's own identity (below) so two lamps in
## the same room never stutter in unison and one lamp replays the same sequence
## every run — no shared global RNG, nothing to save.
var _flicker_rng: RandomNumberGenerator = null
var _flicker_blips_left: int = 0   ## dark blips still owed by the current burst
var _flicker_lit: bool = true      ## is the tube currently in a lit state?

# Pulse behavior (brightness oscillation)
var pulse_enabled: bool = false
var pulse_speed: float = 1.0       ## Hz frequency of pulse (1.0 = 1 cycle/sec)
var pulse_phase: float = 0.0       ## Current phase (0-2π equivalent)
var pulse_min: float = 0.5         ## Min tactical energy during pulse
var pulse_max: float = 1.0         ## Max tactical energy during pulse

# Rotation behavior (for cone/directional lights)
var rotation_speed: float = 0.0    ## Radians/sec; 0 = stationary
var rotation_phase: float = 0.0    ## Current angle offset

# State machine (L-IMP-06)
const STATE_ON := "on"
const STATE_OFF := "off"
const STATE_FLICKER := "flicker"
const STATE_PULSE := "pulse"

var current_state: String = STATE_ON
var energy_multiplier: float = 1.0  ## Applied to tactical_energy for temporal effects

# Track if light changed this frame (for rebuild triggering)
var changed_this_frame: bool = false
var last_energy: float = 1.0
var last_angle: float = 0.0

# Optional tracking
var light_id: String = ""  ## For debugging and tracking
var owner_name: String = ""  ## "lamp_01", "spotlight_guard_area", etc.

## Validate properties
func _to_string() -> String:
	return "[LightSource id=%s type=%s cell=%s height=%d radius=%d active=%s]" % [
		light_id,
		light_type,
		cell,
		height_class,
		radius,
		active
	]

## ============================================================================
## Temporal Update (L-IMP-06) — Per-frame animation logic
## ============================================================================

## Update temporal state based on elapsed time.
## 
## This is called every frame from room._process() to animate:
## - Flicker (neon stutter — see _advance_flicker)
## - Pulse (brightness oscillation)
## - Rotation (angle sweep for spotlights)
##
## Minimal and deterministic: no per-frame procedural noise, and the one random
## stream (flicker) is seeded from the light's own identity, never randomize().
func update_temporal_state(delta: float) -> void:
	changed_this_frame = false
	var old_energy = energy_multiplier
	var old_angle = direction_angle
	
	# Only update if temporal effects are enabled
	if not (flicker_enabled or pulse_enabled or rotation_speed != 0.0):
		energy_multiplier = 1.0
		current_state = STATE_ON
		return
	
	# Update flicker state
	if flicker_enabled:
		current_state = STATE_FLICKER
		_advance_flicker(delta)
	# Update pulse state
	elif pulse_enabled:
		current_state = STATE_PULSE
		pulse_phase += delta * pulse_speed * TAU  # TAU = 2π
		var normalized_pulse = (sin(pulse_phase) + 1.0) * 0.5  # Normalize to 0-1
		energy_multiplier = lerp(pulse_min, pulse_max, normalized_pulse)
	else:
		current_state = STATE_ON
		energy_multiplier = 1.0
	
	# Update rotation (for spotlights/directional lights)
	if rotation_speed != 0.0:
		rotation_phase += delta * rotation_speed
		direction_angle = fmod(rotation_phase, TAU)
	
	# Track if energy or angle changed (for rebuild triggering)
	if abs(energy_multiplier - old_energy) > 0.001:
		changed_this_frame = true
	if abs(direction_angle - old_angle) > 0.001:
		changed_this_frame = true

## NEON-FLICKER-01 — drive one step of the neon state machine.
##
## flicker_phase counts DOWN the remaining time in the current state; every time it
## runs out the tube switches and draws a fresh duration. The `while` (not `if`)
## drains a frame long enough to span several states — a stall must not desync the
## lamp — and always terminates, since every branch adds a strictly positive
## duration.
func _advance_flicker(delta: float) -> void:
	if _flicker_rng == null:
		_seed_flicker_rng()

	flicker_phase -= delta
	while flicker_phase <= 0.0:
		if _flicker_lit:
			## Lit stretch (or a mid-burst re-light) is over — go dark. A burst is
			## drawn once, on the blip that starts it, so its length is decided
			## before the first dark frame rather than re-rolled per blip.
			if _flicker_blips_left <= 0:
				_flicker_blips_left = _flicker_rng.randi_range(FLICKER_BLIPS_MIN, FLICKER_BLIPS_MAX)
			_flicker_blips_left -= 1
			_flicker_lit = false
			energy_multiplier = FLICKER_DIM_ENERGY if _flicker_rng.randf() < FLICKER_DIM_CHANCE else 0.0
			flicker_phase += _flicker_rng.randf_range(FLICKER_BLIP_OFF_MIN, FLICKER_BLIP_OFF_MAX)
		else:
			_flicker_lit = true
			energy_multiplier = 1.0
			if _flicker_blips_left > 0:
				## Still inside the burst: a brief re-light before the next blip.
				flicker_phase += _flicker_rng.randf_range(FLICKER_BLIP_ON_MIN, FLICKER_BLIP_ON_MAX)
			else:
				## Burst spent — back to the long lit stretch.
				flicker_phase += flicker_interval * _flicker_rng.randf_range(
						FLICKER_ON_HOLD_MIN, FLICKER_ON_HOLD_MAX)


## Seed this light's own flicker stream and start it mid-lit-stretch. Seeding from
## cell + light_id (not `randomize()`) keeps a given lamp's sequence reproducible
## run to run, which is what makes a reported "that lamp blinks wrong" reproducible
## at all; the initial partial hold is what stops every lamp in a room from bursting
## on the same frame.
func _seed_flicker_rng() -> void:
	_flicker_rng = RandomNumberGenerator.new()
	_flicker_rng.seed = hash("%s:%d,%d" % [light_id, cell.x, cell.y])
	_flicker_lit = true
	energy_multiplier = 1.0
	_flicker_blips_left = 0
	flicker_phase = flicker_interval * _flicker_rng.randf_range(
			FLICKER_ON_HOLD_MIN, FLICKER_ON_HOLD_MAX)


## Set light to flicker state
func set_flicker(enabled: bool, interval: float = 1.0) -> void:
	flicker_enabled = enabled
	flicker_interval = max(interval, 0.1)
	## Dropping the RNG re-seeds (and re-holds) on the next update — the phase is
	## meaningless across an interval change, and light_id/cell may have been
	## assigned only after construction.
	_flicker_rng = null
	flicker_phase = 0.0
	pulse_enabled = false

## Get effective tactical energy after temporal effects
func get_effective_tactical_energy() -> float:
	return tactical_energy * energy_multiplier

## Check if this light affects a cell (simple radius check, no occlusion yet)
func affects_cell(target_cell: Vector2i) -> bool:
	if not active:
		return false
	
	var distance: float = cell.distance_to(target_cell)
	return distance <= float(radius)

## Get directional vector for this light (used by cone/directional)
func get_direction_vector() -> Vector2:
	return Vector2(cos(direction_angle), sin(direction_angle))
