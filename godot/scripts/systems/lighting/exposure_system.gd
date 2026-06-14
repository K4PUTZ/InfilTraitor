## ExposureSystem — Tactical Exposure & Stealth Semantics
## 
## Responsibility: Convert shadow topology into discrete visibility classes
## for tactical stealth queries and gameplay semantics.
##
## This system:
## - Does NOT render or project shadows
## - Does NOT control AI perception (yet)
## - Does interpret lighting topology as stealth risk
##
## The exposure grid maps each tile to a semantic visibility class
## that gameplay and AI can query to make stealth decisions.

class_name ExposureSystem
extends Node

## ============================================================================
## Visibility Class Enum — Semantic Stealth States (L-IMP-07)
## ============================================================================

## Fully illuminated: Agent stands out, maximum detection risk
const FULL_LIT := 5

## Dimly lit: Agent visible but not prominent, moderate risk
const DIM := 4

## Penumbra (edge of shadow): Agent barely visible, low risk
const PENUMBRA := 3

## Shadowed: Agent concealed, minimal risk
const SHADOW := 2

## Deep shadow: Agent hidden, negligible detection risk
const DEEP_SHADOW := 1

## Occluded void: Extreme stealth, structurally protected (L-IMP-07)
const OCCLUDED_VOID := 0

## Convenience mapping for label generation
const CLASS_NAMES := {
	FULL_LIT: "FULL_LIT",
	DIM: "DIM",
	PENUMBRA: "PENUMBRA",
	SHADOW: "SHADOW",
	DEEP_SHADOW: "DEEP_SHADOW",
	OCCLUDED_VOID: "OCCLUDED_VOID",
}

## Shadow Stability Classification (L-IMP-07)
## Represents the nature and reliability of shadow protection
const STABILITY_STATIC := "static"          # Structural: always present
const STABILITY_TEMPORAL := "temporal"      # Flicker: intermittent
const STABILITY_DYNAMIC := "dynamic"        # Moving light: temporary
const STABILITY_OCCLUDED := "occluded"      # Completely hidden: structural protection

const STABILITY_NAMES := {
	STABILITY_STATIC: "Static",
	STABILITY_TEMPORAL: "Temporal",
	STABILITY_DYNAMIC: "Dynamic",
	STABILITY_OCCLUDED: "Occluded",
}

## ============================================================================
## Detection & Stealth Multipliers (L-IMP-04)
## ============================================================================

## Detection probability multipliers by visibility class.
## Applied to base guard detection chance; lower = harder to detect.
##
## These values are tuned for:
## - Clear differentiation between exposure states
## - Gameplay balance (not "realistic" physics)
## - Deterministic, auditable decision-making
##
## Future tuning: M2-13 (balance pass), M2-17 (equipment modifiers)
const DETECTION_MULT := {
	FULL_LIT:      1.00,    # Agent fully visible (100% base chance)
	DIM:           0.80,    # Dimly lit (80% base chance)
	PENUMBRA:      0.55,    # Edge of shadow (55% base chance)
	SHADOW:        0.30,    # Concealed in shadow (30% base chance)
	DEEP_SHADOW:   0.10,    # Hidden in deep shadow (10% base chance)
	OCCLUDED_VOID: 0.01,    # Extreme stealth (1% base chance, elite only)
}

## ============================================================================
## State
## ============================================================================

## Exposure grid: Vector2i -> int (visibility class)
## Generated from shadow results, queried by gameplay/AI
var _exposure_grid: Dictionary = {}

## Shadow stability by cell: Vector2i -> String (STABILITY_*)
## Tracks whether shadow is structural, temporal, or dynamic (L-IMP-07)
var _shadow_stability: Dictionary = {}

## Exposure confidence by cell: Vector2i -> float (0.0-1.0)
## Represents how stable/reliable the current exposure state is (L-IMP-07)
## High confidence (0.9-1.0): stable darkness (will remain hidden)
## Low confidence (0.0-0.3): intermittent shadow (may be exposed)
var _exposure_confidence: Dictionary = {}

## Room size for bounds checking
var _room_size: Vector2i = Vector2i.ZERO

## ============================================================================
## Initialization & Setup
## ============================================================================

func _init() -> void:
	pass

func set_room_size(size: Vector2i) -> void:
	_room_size = size

## ============================================================================
## Core Exposure Calculation
## ============================================================================

## Rebuild exposure grid from a ShadowResult.
##
## Converts shadow topology directly into semantic visibility classes:
## - fully_lit -> FULL_LIT (4)
## - dim -> DIM (3)
## - penumbra -> PENUMBRA (2)
## - shadow -> SHADOW (1)
## - deep_shadow -> DEEP_SHADOW (0)
##
## All unclassified tiles default to DEEP_SHADOW (safest for stealth).
func rebuild_from_shadow_result(result) -> void:
	_exposure_grid.clear()
	
	# Map each visibility class from ShadowResult to enum value
	# Note: result parameter untyped to avoid scope compilation issues
	
	# Fully lit tiles (highest detection risk)
	var fully_lit_tiles = result.get_tiles_by_class("fully_lit")
	for cell in fully_lit_tiles:
		_exposure_grid[cell] = FULL_LIT
	
	# Dim tiles (moderate visibility)
	var dim_tiles = result.get_tiles_by_class("dim")
	for cell in dim_tiles:
		_exposure_grid[cell] = DIM
	
	# Penumbra tiles (edge of shadow, low visibility)
	var penumbra_tiles = result.get_tiles_by_class("penumbra")
	for cell in penumbra_tiles:
		_exposure_grid[cell] = PENUMBRA
	
	# Shadow tiles (concealed, minimal risk)
	var shadow_tiles = result.get_tiles_by_class("shadow")
	for cell in shadow_tiles:
		_exposure_grid[cell] = SHADOW
	
	# Deep shadow tiles (hidden, negligible risk)
	var deep_shadow_tiles = result.get_tiles_by_class("deep_shadow")
	for cell in deep_shadow_tiles:
		_exposure_grid[cell] = DEEP_SHADOW

## Rebuild from multiple shadow results (future: exposure merging for multiple lights).
##
## For now, this uses the most conservative visibility (highest risk).
## Future refinement: apply detection multipliers from L-DOC-01.
func rebuild_from_results(results: Array) -> void:
	_exposure_grid.clear()
	
	# Track maximum exposure per tile (most "visible" across all lights)
	var max_exposure: Dictionary = {}
	
	for result in results:
		# Accumulate visibility from each light
		var fully_lit_tiles = result.get_tiles_by_class("fully_lit")
		for cell in fully_lit_tiles:
			if cell not in max_exposure or max_exposure[cell] < FULL_LIT:
				max_exposure[cell] = FULL_LIT
		
		var dim_tiles = result.get_tiles_by_class("dim")
		for cell in dim_tiles:
			if cell not in max_exposure or max_exposure[cell] < DIM:
				max_exposure[cell] = DIM
		
		var penumbra_tiles = result.get_tiles_by_class("penumbra")
		for cell in penumbra_tiles:
			if cell not in max_exposure or max_exposure[cell] < PENUMBRA:
				max_exposure[cell] = PENUMBRA
		
		var shadow_tiles = result.get_tiles_by_class("shadow")
		for cell in shadow_tiles:
			if cell not in max_exposure or max_exposure[cell] < SHADOW:
				max_exposure[cell] = SHADOW
		
		var deep_shadow_tiles = result.get_tiles_by_class("deep_shadow")
		for cell in deep_shadow_tiles:
			if cell not in max_exposure or max_exposure[cell] < DEEP_SHADOW:
				max_exposure[cell] = DEEP_SHADOW
	
	_exposure_grid = max_exposure

## ============================================================================
## Query Methods — Gameplay Stealth Interface
## ============================================================================

## Get the visibility class (0-4) for a tile.
##
## Returns DEEP_SHADOW (0) for unclassified tiles (safest default).
## Gameplay should always query ExposureSystem, never ShadowProjector directly.
func get_visibility_class(cell: Vector2i) -> int:
	if cell in _exposure_grid:
		return _exposure_grid[cell]
	return DEEP_SHADOW

## Check if a tile is hidden (shadow or deeper).
##
## Returns true if visibility class <= SHADOW (1).
## Useful for quick stealth checks.
func is_hidden(cell: Vector2i) -> bool:
	var vis_class = get_visibility_class(cell)
	return vis_class <= SHADOW

## Get human-readable label for a visibility class.
##
## Returns semantic name: "FULL_LIT", "DIM", "PENUMBRA", "SHADOW", "DEEP_SHADOW".
func get_exposure_label(cell: Vector2i) -> String:
	var vis_class = get_visibility_class(cell)
	if vis_class in CLASS_NAMES:
		return CLASS_NAMES[vis_class]
	return "UNKNOWN"

## Get all tiles with a specific visibility class.
##
## Useful for batch queries (e.g., "find all hidden tiles").
func get_tiles_by_class(target_class: int) -> Array:
	var result: Array = []
	for cell in _exposure_grid.keys():
		if _exposure_grid[cell] == target_class:
			result.append(cell)
	return result

## Get exposure statistics for debugging/balancing.
##
## Returns dict with class counts.
func get_exposure_stats() -> Dictionary:
	var stats = {
		"full_lit": 0,
		"dim": 0,
		"penumbra": 0,
		"shadow": 0,
		"deep_shadow": 0,
	}
	
	for vis_class in _exposure_grid.values():
		match vis_class:
			FULL_LIT:
				stats["full_lit"] += 1
			DIM:
				stats["dim"] += 1
			PENUMBRA:
				stats["penumbra"] += 1
			SHADOW:
				stats["shadow"] += 1
			DEEP_SHADOW:
				stats["deep_shadow"] += 1
	
	return stats

## ============================================================================
## Detection & Risk Queries (L-IMP-04 — Tactical Exposure Integration)
## ============================================================================

## Get the detection multiplier for a tile.
##
## Maps visibility class to detection probability modifier.
## Multiplier applies to base guard detection chance:
## - 1.0 = normal detection (full light)
## - 0.5 = half detection chance (shadow)
## - 0.1 = very low detection (deep shadow)
##
## Gameplay: guard_detection_chance *= exposure_system.get_detection_multiplier(agent_cell)
func get_detection_multiplier(cell: Vector2i) -> float:
	var vis_class = get_visibility_class(cell)
	if vis_class in DETECTION_MULT:
		return DETECTION_MULT[vis_class]
	return DETECTION_MULT[DEEP_SHADOW]  # Conservative: default to safest

## Get the tactical risk of a tile (inverse of safety).
##
## Returns 0.0-1.0 where:
## - 0.0 = completely safe (deep shadow)
## - 1.0 = maximum danger (full light)
##
## Useful for pathfinding, search prioritization, and strategic planning.
## Complement: risk = 1.0 - (detection_mult / 1.0)
func get_tile_risk(cell: Vector2i) -> float:
	var detection_mult = get_detection_multiplier(cell)
	return detection_mult  # Risk directly proportional to detectability

## Get debug string for a tile (exposure + risk + multiplier).
##
## Format: "SHADOW x0.30 (risk:0.30)"
func get_tile_debug_info(cell: Vector2i) -> String:
	var label = get_exposure_label(cell)
	var mult = get_detection_multiplier(cell)
	var risk = get_tile_risk(cell)
	return "%s x%.2f (risk:%.2f)" % [label, mult, risk]

## ============================================================================
## Advanced Tactical Queries (L-IMP-07 — Shadow Semantics)
## ============================================================================

## Get shadow depth for a tile (0-6 scale).
##
## Maps visibility class to tactical depth:
## - 6 = extreme exposure (FULL_LIT)
## - 3 = medium (PENUMBRA)
## - 0 = extreme concealment (OCCLUDED_VOID)
##
## Used for elite vision overlays and advanced stealth queries.
func get_shadow_depth(cell: Vector2i) -> int:
	var vis_class = get_visibility_class(cell)
	return vis_class  # Direct mapping: 0-5

## Get exposure confidence for a tile.
##
## Returns 0.0-1.0 where:
## - 1.0 = stable darkness (structural shadow, will persist)
## - 0.5 = moderate reliability (temporary shadow)
## - 0.0 = unreliable (flickering or intermittent)
##
## Used for high-skill pathfinding and temporal stealth decisions.
func get_exposure_confidence(cell: Vector2i) -> float:
	if cell in _exposure_confidence:
		return _exposure_confidence[cell]
	return 0.5  # Default: unknown reliability

## Check if a tile is structurally hidden.
##
## Returns true only if OCCLUDED_VOID or if structurally protected.
## Distinct from temporal concealment (flicker shadows).
##
## Used for pathfinding AI, cover assessment, and elite vision.
func is_structurally_hidden(cell: Vector2i) -> bool:
	var vis_class = get_visibility_class(cell)
	return vis_class == OCCLUDED_VOID

## Get shadow stability classification for a tile.
##
## Returns STABILITY_STATIC, STABILITY_TEMPORAL, STABILITY_DYNAMIC, or STABILITY_OCCLUDED.
##
## Used for understanding exposure nature and planning stealth windows.
func get_shadow_stability(cell: Vector2i) -> String:
	if cell in _shadow_stability:
		return _shadow_stability[cell]
	return STABILITY_STATIC  # Default: assume structural

## Get all structurally hidden tiles (OCCLUDED_VOID).
##
## Useful for identifying strongholds, safe zones, and strategic positions.
func get_structurally_hidden_tiles() -> Array:
	var result: Array = []
	for cell in _exposure_grid.keys():
		if _exposure_grid[cell] == OCCLUDED_VOID:
			result.append(cell)
	return result

## Get tiles by shadow stability classification.
##
## Returns array of tiles with given stability type.
func get_tiles_by_stability(stability_type: String) -> Array:
	var result: Array = []
	for cell in _shadow_stability.keys():
		if _shadow_stability[cell] == stability_type:
			result.append(cell)
	return result

## ============================================================================
## Utility
## ============================================================================

## Clear exposure grid (used when resetting lights or rebuilding).
func clear() -> void:
	_exposure_grid.clear()

## Debug output.
func _to_string() -> String:
	var stats = get_exposure_stats()
	var total = stats["full_lit"] + stats["dim"] + stats["penumbra"] + stats["shadow"] + stats["deep_shadow"]
	if total == 0:
		return "ExposureSystem: [empty grid]"
	
	return "ExposureSystem: [total=%d full_lit=%d dim=%d penumbra=%d shadow=%d deep_shadow=%d]" % [
		total,
		stats["full_lit"],
		stats["dim"],
		stats["penumbra"],
		stats["shadow"],
		stats["deep_shadow"]
	]
