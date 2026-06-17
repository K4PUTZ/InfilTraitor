class_name TicSystem
## Processes a detection tic whenever an actor changes tile.
## Called by room.gd at two moments:
##   1. When the agent finishes a step (agent tic)
##   2. When a guard finishes its move (guard tic)

## Detection multipliers per guard state.
const STATE_MULTIPLIER: Dictionary = {
	"patrol":     0.55,
	"suspicious": 1.60,
	"search":      0.80,
	"alert":      2.00,
	"chase":      2.80,
}

## Detection gain per successful tic (before multipliers).
const DETECTION_GAIN_PER_TIC := 0.4

## Result of a detection tic.
class TicResult:
	var detected: bool = false       ## visible + dice roll passed
	var visible: bool = false        ## in line of sight only
	var raw_chance: float = 0.0      ## probability before the dice roll
	var angle_ratio: float = 0.0     ## 1.0 = cone center, 0.0 = edge
	var distance: int = 0

## Process a tic: evaluate a single guard against a single target cell.
## Returns a TicResult with the outcome of this check.
##
## L-IMP-04: Added exposure_system parameter for tactical exposure integration
static func evaluate(
	guard,                          ## GuardEnemy
	target_cell: Vector2i,
	blocked_cells: Dictionary,
	blocked_edges: Dictionary,
	exposure_system = null          ## ExposureSystem (optional, L-IMP-04)
) -> TicResult:
	var result := TicResult.new()

	## Get the agent reference if needed for the detection pipeline (Cover)
	var agent_ref = guard.get_tree().get_root().find_child("Agent", true, false)

	## Full evaluation delegated to the guard (Source of Truth)
	var eval: Dictionary = guard.evaluate_detection(
		target_cell,
		guard.fov_range,
		blocked_cells,
		blocked_edges,
		2,
		agent_ref
	)

	result.visible      = bool(eval.get("visible", false))
	result.angle_ratio  = float(eval.get("angle_ratio", 0.0))
	result.distance     = int(eval.get("distance", 99))

	if not result.visible:
		return result

	## Raw probability returned by the guard (includes shadows and cover)
	var raw_prob: float = float(eval.get("final_prob", 0.0))

	## Apply the guard state multiplier
	var state_mult: float = STATE_MULTIPLIER.get(guard.state, 1.0)

	## L-IMP-04: Apply tactical exposure modifier
	var exposure_mult: float = 1.0
	if exposure_system != null:
		exposure_mult = exposure_system.get_detection_multiplier(target_cell)

	result.raw_chance = raw_prob * state_mult * exposure_mult

	## Roll the dice: 0.0 to 1.0
	result.detected = randf() < result.raw_chance

	return result


## Evaluate whether a guard hears the noise on a tile.
## Returns perceived intensity (0.0 = not heard).
const HEARING_RADIUS := 2
static func evaluate_audio(
	guard,
	noise_tile: Vector2i,
	noise_intensity: float,
	blocked_edges: Dictionary
) -> float:
	if noise_intensity <= 0.0:
		return 0.0

	var dist := absi(guard.cell.x - noise_tile.x) + absi(guard.cell.y - noise_tile.y)
	if dist > HEARING_RADIUS:
		return 0.0

	## Distance attenuation
	var distance_factor := 1.0 - (float(dist) / float(HEARING_RADIUS + 1))

	## Wall attenuation — each wall crossed reduces by 40%
	var wall_penalty := _count_walls_between(guard.cell, noise_tile, blocked_edges)
	var wall_factor := pow(0.6, wall_penalty)

	return noise_intensity * distance_factor * wall_factor


static func _count_walls_between(
	from_cell: Vector2i,
	to_cell: Vector2i,
	blocked_edges: Dictionary
) -> int:
	## Count walls along the direct path (simplified Bresenham)
	var walls := 0
	var current := from_cell
	var dx := signi(to_cell.x - from_cell.x)
	var dy := signi(to_cell.y - from_cell.y)
	while current != to_cell:
		var next := current
		if current.x != to_cell.x:
			next.x += dx
		elif current.y != to_cell.y:
			next.y += dy
		if WallEdgeData.is_edge_blocked(current, next, blocked_edges):
			walls += 1
		current = next
	return walls
