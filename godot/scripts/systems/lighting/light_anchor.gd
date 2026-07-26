## LightAnchor — Semantic light placement socket
##
## Represents a natural attachment point for light sources.
## Decouples light placement from visual art.
##
## Anchors serve as "sockets" where level design specifies valid light positions.
## Examples: ceiling mount, wall sconce, floor uplighter, column spotlight.

class_name LightAnchor
extends RefCounted

## ============================================================================
## Anchor Types (Semantic Categories)
## ============================================================================
## Determines architectural placement and light direction constraints.

const TYPE_CEILING := "ceiling"      ## Hanging light; downward emission
const TYPE_WALL := "wall"            ## Wall-mounted; outward emission
const TYPE_FLOOR := "floor"          ## Floor-mounted; upward emission
const TYPE_COLUMN := "column"        ## Pole-mounted; omnidirectional
const TYPE_SPOTLIGHT := "spotlight"  ## Directional mount; configurable direction
const TYPE_AMBIENT := "ambient"      ## Non-positioned ambient light

## ============================================================================
## Properties
## ============================================================================

var anchor_cell: Vector2i = Vector2i.ZERO      ## Grid position
var anchor_type: String = TYPE_CEILING         ## Semantic placement type
var anchor_height: int = 0                     ## Vertical attachment height
var emission_direction: Vector2i = Vector2i.DOWN  ## Emission direction (for directionals)
var light_radius: int = 4                      ## Default light radius
var light_intensity: float = 1.0               ## Light strength multiplier
var light_color: Color = Color.WHITE           ## Light color (future visual)

## Metadata
var authored: bool = true               ## Explicitly placed by designer?
var locked: bool = false                ## Prevent runtime modification?
var description: String = ""            ## Designer notes

## ============================================================================
## Validation
## ============================================================================

## Check if anchor is properly configured
func is_valid() -> bool:
	return anchor_type in [
		TYPE_CEILING, TYPE_WALL, TYPE_FLOOR, 
		TYPE_COLUMN, TYPE_SPOTLIGHT, TYPE_AMBIENT
	] and (anchor_cell != Vector2i.ZERO or anchor_type == TYPE_AMBIENT)

## ============================================================================
## Factory Methods
## ============================================================================

static func make_ceiling(cell_pos: Vector2i, light_rad: int = 4) -> LightAnchor:
	var anchor = LightAnchor.new()
	anchor.anchor_cell = cell_pos
	anchor.anchor_type = TYPE_CEILING
	anchor.anchor_height = 4  ## HEIGHT_OVERHEAD
	anchor.emission_direction = Vector2i.DOWN
	anchor.light_radius = light_rad
	return anchor

static func make_wall(cell_pos: Vector2i, dir: Vector2i = Vector2i.RIGHT, light_rad: int = 3) -> LightAnchor:
	var anchor = LightAnchor.new()
	anchor.anchor_cell = cell_pos
	anchor.anchor_type = TYPE_WALL
	anchor.anchor_height = 2  ## HEIGHT_HUMAN
	anchor.emission_direction = dir
	anchor.light_radius = light_rad
	return anchor

static func make_floor(cell_pos: Vector2i, light_rad: int = 3) -> LightAnchor:
	var anchor = LightAnchor.new()
	anchor.anchor_cell = cell_pos
	anchor.anchor_type = TYPE_FLOOR
	anchor.anchor_height = 0  ## HEIGHT_FLOOR
	anchor.emission_direction = Vector2i.UP
	anchor.light_radius = light_rad
	return anchor

## ============================================================================
## Debugging
## ============================================================================

func debug_string() -> String:
	return "[Anchor %s at %v radius:%d]" % [anchor_type, anchor_cell, light_radius]

func debug_info() -> String:
	var lines = [
		"=== Light Anchor ===",
		"Type: %s" % [anchor_type],
		"Position: %v" % [anchor_cell],
		"Height: %d" % [anchor_height],
		"Direction: %v" % [emission_direction],
		"Radius: %d" % [light_radius],
		"Intensity: %.1f" % [light_intensity],
		"Authored: %s" % [authored],
		"Locked: %s" % [locked],
	]
	if not description.is_empty():
		lines.append("Notes: %s" % [description])
	return "\n".join(lines)
