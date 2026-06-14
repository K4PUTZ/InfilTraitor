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
## Visibility Class Enum — Semantic Stealth States
## ============================================================================

## Fully illuminated: Agent stands out, high detection risk
const FULL_LIT := 4

## Dimly lit: Agent visible but not prominent, moderate risk
const DIM := 3

## Penumbra (edge of shadow): Agent barely visible, low risk
const PENUMBRA := 2

## Shadowed: Agent concealed, minimal risk
const SHADOW := 1

## Deep shadow: Agent hidden, negligible detection risk
const DEEP_SHADOW := 0

## Convenience mapping for label generation
const CLASS_NAMES := {
	FULL_LIT: "FULL_LIT",
	DIM: "DIM",
	PENUMBRA: "PENUMBRA",
	SHADOW: "SHADOW",
	DEEP_SHADOW: "DEEP_SHADOW",
}

## ============================================================================
## State
## ============================================================================

## Exposure grid: Vector2i -> int (visibility class)
## Generated from shadow results, queried by gameplay/AI
var _exposure_grid: Dictionary = {}

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
