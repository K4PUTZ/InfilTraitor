## TileSemantics — Semantic metadata for worldbuilding
##
## Centralizes height classes, structural meaning, stealth modifiers, and flags.
## Decouples tile behavior from visual representation.
##
## This is the source of truth for tile meaning in the lighting system.

class_name TileSemantics
extends RefCounted

## ============================================================================
## Height Classes (Vertical Position in World)
## ============================================================================
## Heights define vertical "layers" where light propagates and shadows form.
## Height is independent of sprite size or visual appearance.

const HEIGHT_FLOOR := 0           ## Floor level (0u elevation)
const HEIGHT_LOW_COVER := 1       ## Crouching height (~0.5-1.5u)
const HEIGHT_HUMAN := 2           ## Standing height (~1.5-2.5u)
const HEIGHT_TALL_STRUCTURE := 3  ## Tall objects (~2.5-4.5u)
const HEIGHT_OVERHEAD := 4        ## Ceiling/infrastructure (>4.5u)

## ============================================================================
## Structural Categories (Semantic Meaning)
## ============================================================================
## Structural type defines how tile interacts with light, shadows, and stealth.
## Orthogonal to height; a tile can be "floor + structural" or "wall + tall".

const STRUCT_FLOOR := "floor"
const STRUCT_LOW_COVER := "low_cover"
const STRUCT_WALL := "wall"
const STRUCT_TALL := "tall"
const STRUCT_OVERHEAD := "overhead"

## ============================================================================
## Layer Assignment (Vertical Infrastructure)
## ============================================================================
## Layers define rendering order and light interaction depth.
## L0 is subfloor (effects, hazards, indirect light).
## L1 is playable floor (agent navigation, shadows).
## L2 is structural (walls, covers, mid-height props).
## L3 is overhead (ceiling, infrastructure, skylights).

const LAYER_SUBFLOOR := 0        ## L0: Atmosphere, hazards, indirect effects
const LAYER_PLAYABLE := 1        ## L1: Floor, navigation, shadows
const LAYER_STRUCTURAL := 2      ## L2: Walls, covers, mid-height obstacles
const LAYER_OVERHEAD := 3        ## L3: Ceiling, infrastructure, overhead lights

## ============================================================================
## Tile Properties
## ============================================================================

var height_class: int = HEIGHT_FLOOR
var structural_type: String = STRUCT_FLOOR
var layer_assignment: int = LAYER_PLAYABLE

## Light interaction flags
var receives_shadow: bool = true    ## Can tile be shadowed by obstacles?
var receives_light: bool = true     ## Can tile receive direct light?
var blocks_los: bool = false        ## Blocks line-of-sight for agents?
var blocks_light: bool = false      ## Blocks light propagation?
var blocks_shadow: bool = false     ## Blocks shadow projection?

## Stealth semantics
var stealth_modifier: float = 1.0   ## Detection chance multiplier (future)
var acoustic_dampening: float = 0.0 ## Sound absorption (future)

## Authored metadata
var is_light_anchor: bool = false   ## Valid socket for light placement?
var anchor_type: String = ""        ## Type of anchor: "wall", "ceiling", "floor", "column"
var has_hazard: bool = false        ## Subfloor hazard present?
var hazard_type: String = ""        ## "lava", "vapor", "electricity", etc.

## ============================================================================
## Constants Lookup Tables
## ============================================================================

const HEIGHT_NAMES := {
	HEIGHT_FLOOR: "FLOOR",
	HEIGHT_LOW_COVER: "LOW_COVER",
	HEIGHT_HUMAN: "HUMAN",
	HEIGHT_TALL_STRUCTURE: "TALL",
	HEIGHT_OVERHEAD: "OVERHEAD",
}

const STRUCT_NAMES := {
	STRUCT_FLOOR: "Floor",
	STRUCT_LOW_COVER: "LowCover",
	STRUCT_WALL: "Wall",
	STRUCT_TALL: "Tall",
	STRUCT_OVERHEAD: "Overhead",
}

const LAYER_NAMES := {
	LAYER_SUBFLOOR: "L0-Subfloor",
	LAYER_PLAYABLE: "L1-Playable",
	LAYER_STRUCTURAL: "L2-Structural",
	LAYER_OVERHEAD: "L3-Overhead",
}

## ============================================================================
## Factory Methods
## ============================================================================

## Create floor-level walkable tile
static func make_floor() -> TileSemantics:
	var tile = TileSemantics.new()
	tile.height_class = HEIGHT_FLOOR
	tile.structural_type = STRUCT_FLOOR
	tile.layer_assignment = LAYER_PLAYABLE
	tile.blocks_los = false
	tile.blocks_light = false
	return tile

## Create low cover (crouching height, ~0.5-1.5u)
static func make_low_cover() -> TileSemantics:
	var tile = TileSemantics.new()
	tile.height_class = HEIGHT_LOW_COVER
	tile.structural_type = STRUCT_LOW_COVER
	tile.layer_assignment = LAYER_STRUCTURAL
	tile.blocks_los = true
	tile.blocks_light = false
	return tile

## Create wall (full-height obstacle)
static func make_wall() -> TileSemantics:
	var tile = TileSemantics.new()
	tile.height_class = HEIGHT_TALL_STRUCTURE
	tile.structural_type = STRUCT_WALL
	tile.layer_assignment = LAYER_STRUCTURAL
	tile.blocks_los = true
	tile.blocks_light = true
	return tile

## Create tall structure (ceiling-height, ~2.5-4.5u)
static func make_tall() -> TileSemantics:
	var tile = TileSemantics.new()
	tile.height_class = HEIGHT_TALL_STRUCTURE
	tile.structural_type = STRUCT_TALL
	tile.layer_assignment = LAYER_STRUCTURAL
	tile.blocks_los = true
	tile.blocks_light = false
	return tile

## Create overhead infrastructure (ceiling, L3 layer)
static func make_overhead() -> TileSemantics:
	var tile = TileSemantics.new()
	tile.height_class = HEIGHT_OVERHEAD
	tile.structural_type = STRUCT_OVERHEAD
	tile.layer_assignment = LAYER_OVERHEAD
	tile.blocks_los = false
	tile.blocks_light = true
	return tile

## Create subfloor tile (L0 effects, hazards)
static func make_subfloor(hazard: String = "") -> TileSemantics:
	var tile = TileSemantics.new()
	tile.height_class = HEIGHT_FLOOR
	tile.layer_assignment = LAYER_SUBFLOOR
	tile.receives_light = false
	tile.receives_shadow = false
	if not hazard.is_empty():
		tile.has_hazard = true
		tile.hazard_type = hazard
	return tile

## ============================================================================
## Query Methods
## ============================================================================

## Does this tile obstruct light propagation?
func obstructs_light() -> bool:
	return blocks_light

## Does this tile obstruct line-of-sight?
func obstructs_los() -> bool:
	return blocks_los

## Is this tile a valid position for light placement?
func is_valid_light_socket() -> bool:
	return is_light_anchor

## Can shadows fall on this tile?
func can_receive_shadow() -> bool:
	return receives_shadow and layer_assignment == LAYER_PLAYABLE

## Can light directly illuminate this tile?
func can_receive_light() -> bool:
	return receives_light and layer_assignment != LAYER_SUBFLOOR

## ============================================================================
## Debugging
## ============================================================================

func debug_string() -> String:
	return "[%s|%s|H:%s] LOS:%s Light:%s" % [
		HEIGHT_NAMES.get(height_class, "UNKNOWN"),
		STRUCT_NAMES.get(structural_type, "UNKNOWN"),
		LAYER_NAMES.get(layer_assignment, "L?"),
		blocks_los,
		blocks_light
	]

func debug_info() -> String:
	var lines = [
		"=== Tile Semantics ===",
		"Height: %s (class %d)" % [HEIGHT_NAMES.get(height_class, "?"), height_class],
		"Structure: %s" % [STRUCT_NAMES.get(structural_type, "?")],
		"Layer: %s (L%d)" % [LAYER_NAMES.get(layer_assignment, "?"), layer_assignment],
		"--- Interaction ---",
		"LOS Blocker: %s" % [blocks_los],
		"Light Blocker: %s" % [blocks_light],
		"Receives Light: %s" % [receives_light],
		"Receives Shadow: %s" % [receives_shadow],
	]
	if is_light_anchor:
		lines.append("--- Light Anchor ---")
		lines.append("Type: %s" % [anchor_type])
	if has_hazard:
		lines.append("--- Subfloor ---")
		lines.append("Hazard: %s" % [hazard_type])
	return "\n".join(lines)
