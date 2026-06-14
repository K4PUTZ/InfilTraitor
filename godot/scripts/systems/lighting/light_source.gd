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

# Flicker behavior
var flicker_enabled: bool = false
var flicker_interval: float = 1.0  ## Seconds between on/off toggle
var flicker_phase: float = 0.0     ## Current time in flicker cycle

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
## - Flicker (on/off toggle)
## - Pulse (brightness oscillation)
## - Rotation (angle sweep for spotlights)
##
## Minimal, deterministic, no complex procedural noise.
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
		flicker_phase += delta
		var cycle_duration = flicker_interval
		var normalized_phase = fmod(flicker_phase, cycle_duration * 2.0) / (cycle_duration * 2.0)
		
		# First half of cycle: ON, second half: OFF
		if normalized_phase < 0.5:
			current_state = STATE_FLICKER
			energy_multiplier = 1.0
		else:
			current_state = STATE_FLICKER
			energy_multiplier = 0.0
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

## Set light to flicker state
func set_flicker(enabled: bool, interval: float = 1.0) -> void:
	flicker_enabled = enabled
	flicker_interval = max(interval, 0.1)
	flicker_phase = 0.0
	pulse_enabled = false

## Set light to pulse state
func set_pulse(enabled: bool, speed: float = 1.0, min_energy: float = 0.5, max_energy: float = 1.0) -> void:
	pulse_enabled = enabled
	pulse_speed = max(speed, 0.1)
	pulse_min = clamp(min_energy, 0.0, 1.0)
	pulse_max = clamp(max_energy, 0.0, 1.0)
	pulse_phase = 0.0
	flicker_enabled = false

## Set light to rotate (for spotlight sweeps)
func set_rotation(speed_radians_per_sec: float) -> void:
	rotation_speed = speed_radians_per_sec
	rotation_phase = direction_angle

## Get effective tactical energy after temporal effects
func get_effective_tactical_energy() -> float:
	return tactical_energy * energy_multiplier

## Get debug string with temporal state
func debug_temporal_state() -> String:
	var effects = []
	if flicker_enabled:
		effects.append("flicker(%.1fs)" % flicker_interval)
	if pulse_enabled:
		effects.append("pulse(%.1fHz)" % pulse_speed)
	if rotation_speed != 0.0:
		effects.append("rotate(%.2frad/s)" % rotation_speed)
	
	var effects_str = ",".join(effects) if effects.size() > 0 else "static"
	return "%s state=%s energy=%.2f effects=[%s]" % [
		self._to_string(),
		current_state,
		energy_multiplier,
		effects_str
	]

## Check if this light affects a cell (simple radius check, no occlusion yet)
func affects_cell(target_cell: Vector2i) -> bool:
	if not active:
		return false
	
	var distance: float = cell.distance_to(target_cell)
	return distance <= float(radius)

## Get directional vector for this light (used by cone/directional)
func get_direction_vector() -> Vector2:
	return Vector2(cos(direction_angle), sin(direction_angle))

## Get cone spread as fraction (0.0 = tight, 1.0 = wide)
func get_cone_spread() -> float:
	return clamp(cone_angle / 180.0, 0.0, 1.0)
