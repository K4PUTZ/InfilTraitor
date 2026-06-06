class_name AgentStats
## Central data container for all agent parameters.
## Read these values from here — never hardcode them in gameplay logic.
## Foundation for difficulty tiers and Freelance mode scaling (M4+).


## Action Points
var max_ap: int = 2
var move_points_per_ap: int = 3

## Health layers
var max_hp: int = 3
var max_armor: int = 0
var current_hp: int = 3
var current_armor: int = 0

## Vision
var vision_radius: int = 7
var vision_mode: String = "normal"

## Alert system
var alert_max: int = 100
var alert_gain_warning: int = 20
var alert_gain_full: int = 45

## Difficulty tier — scales stats for Freelance mode (used from M4 onward)
var difficulty_tier: int = 1


func get_max_resistance() -> int:
	return current_hp + current_armor


## The fatal hit rule: one hit beyond the resistance total is always fatal.
## Proportional — works at any tier and any HP value.
func is_fatal_hit(hits_taken: int) -> bool:
	return hits_taken > get_max_resistance()
