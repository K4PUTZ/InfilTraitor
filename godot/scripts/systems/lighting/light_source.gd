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
