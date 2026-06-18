# INFILTRAITOR — Lighting Authoring Pipeline & Serialization Model

> **Official level design workflow for semantic lighting and structural metadata. Establishes authoring conventions before content expansion and future tooling integration.**

**Related Documents:**
- [Lighting Runtime Pipeline](../systems/lighting_runtime_pipeline.md) — Runtime behavior and invalidation (LIGHT-01)
- [Occlusion Semantics](../systems/occlusion.md) — Structural blocking model (LIGHT-02)
- [Lighting System](../systems/lighting.md) — Tactical visibility specification
- [Tile Semantics](../../INFILTRAITOR/godot/scripts/world/tile_semantics.gd) — Height and structure encoding

---

## Overview

The **lighting authoring pipeline** defines how level designers create and organize semantic lighting and worldbuilding data. It establishes:

- **Author intent capture** — How designers express semantic meaning
- **Data organization** — Storage of lighting, heights, structures, occlusion
- **Serialization contracts** — Future persistence formats
- **Authoring workflows** — Step-by-step processes for designing levels
- **Validation rules** — Ensuring consistency and auditability

### Core Principle

```
Level designers author semantics first, visuals second.

Gameplay meaning (height, occlusion, light) is defined independently
from visual representation (sprites, colors, animations).
```

### Why This Matters

Without a formalized authoring pipeline:

```
❌ Maps grow disorganized (no structure)
❌ Semantics diverge (inconsistent data)
❌ Future tooling breaks (no contracts)
❌ Content sharing fails (no standards)
❌ Maintenance becomes impossible (unclear ownership)
```

With formal authoring:

```
✓ Level data is semantic-driven (meaning-first)
✓ Maps are auditable and maintainable
✓ Tooling can standardize workflows
✓ Team can collaborate consistently
✓ Content scales reliably
```

---

## Authoring Philosophy

### Five Core Principles

#### 1. Semantic-Driven Design

```
Author semantics first.
Visual representation follows semantics.

NOT: Visual appearance → infer gameplay meaning
YES: Gameplay semantics → apply visual style
```

**Example:**

```
WRONG:
- Artist: "I'll use a big sprite for a wall"
- Designer: "OK, I'll mark it as blocking"
- Result: Visual appearance drives semantics

CORRECT:
- Designer: "This is a SOLID wall structure"
- Artist: "I'll render it with appropriate sprite/lighting"
- Result: Semantics drives appearance
```

#### 2. Grid-Based Organization

```
All authoring data is grid-aligned.
No per-pixel, sub-tile, or continuous metadata.

Structure:
- Each tile has semantic metadata
- Metadata defines game behavior
- Visual rendering is secondary
```

**Storage:**
```gdscript
# Per-tile semantic data
var _tile_metadata[Vector2i] = {
    "height": int,
    "structure": string,
    "occlusion": string,
    "light_socket": bool,
    "shadow_anchor": bool
}
```

#### 3. Author-Friendly Workflows

```
Authoring should be:
- Intuitive (designers understand immediately)
- Forgiving (can experiment without breaking)
- Transparent (can audit what's stored)
- Extensible (can add new semantic layers)
```

#### 4. Auditable & Transparent

```
Every semantic decision is visible:
- Why is this tile SOLID?
- Where is the light anchored?
- How does this structure affect stealth?

Designers must always understand system behavior.
```

#### 5. Stable & Versioned

```
Authoring data must be:
- Version-trackable (git-friendly)
- Deterministic (same data → same result)
- Parseable (both human-readable and machine-readable)
- Backward-compatible (older maps still load)
```

---

## Structural Metadata

### Per-Tile Data Structure

Every tile in a playable map can store semantic metadata:

```gdscript
class TileMetadata:
    var cell: Vector2i
    
    # Height semantics (L-IMP-05)
    var height_class: String  # FLOOR, LOW_COVER, WALL, TALL, OVERHEAD
    var height_numeric: int   # 0-4 (HEIGHT_FLOOR through HEIGHT_OVERHEAD)
    
    # Structural category (L-IMP-05)
    var structure_category: String  # FLOOR, LOW_COVER, WALL, TALL, OVERHEAD
    
    # Occlusion behavior (LIGHT-02)
    var occlusion_class: String  # SOLID, TRANSPARENT, DIFFUSE, PERFORATED
    
    # Light interaction (L-IMP-05)
    var can_receive_light: bool = true
    var can_receive_shadow: bool = true
    var is_light_socket: bool = false  # Can anchor light here
    
    # Exposure metadata (L-IMP-07)
    var structural_depth: int = 0  # Depth class for structurally hidden
    var shadow_anchor_priority: int = 0  # For shadow placement
    
    # Visual mapping (art-facing)
    var visual_style: String = "default"  # Sprite/color hints for renderer
    var visual_variant: int = 0  # Variation number for tile
```

### Metadata Semantics

**Important:** Metadata describes **gameplay behavior**, not visual appearance:

```
height_class = "WALL"
DOES NOT MEAN: "This sprite looks like a wall"

MEANS: "This tile blocks light at wall height,
        provides cover, and blocks LOS"
```

### Minimal vs Rich Metadata

**Minimal (for rapid prototyping):**
```
- height_class only
- Derived occlusion from height
- Visual style from height
```

**Rich (for production levels):**
```
- All semantic fields
- Explicit occlusion class
- Custom light anchors
- Shadow behavior flags
- Exposure metadata
```

### Metadata Versioning

```gdscript
# Metadata includes version for future extension
var metadata_version: int = 1

# Allows safe addition of new fields:
# v1 → v2: add shadow_anchor_priority
# v2 → v3: add exposure_confidence_hint
# Systems read version and handle gracefully
```

---

## Height Painting Workflow

### Overview

Height painting is the process of defining vertical topology semantically. It determines:

- How structures relate vertically
- What light can reach
- Where agents can hide
- LOS blocking patterns

### Philosophy

```
Height painting is INDEPENDENT of sprite size or visual appearance.
```

**Why?**
- Sprite scale is art decision
- Gameplay height is design decision
- They must not be coupled

### Painting Process

#### Step 1: Understand Height Classes

```
HEIGHT_FLOOR (0)         → Ground level, no cover
HEIGHT_LOW_COVER (1)     → Waist-high, partial concealment
HEIGHT_WALL (2)          → Chest-height wall
HEIGHT_TALL (3)          → Tall structure, full cover
HEIGHT_OVERHEAD (4)      → Ceiling/overhead, blocks from above
```

#### Step 2: Identify Playable vs Static Areas

```
Playable Areas:
- Agent can move here
- Must have HEIGHT_FLOOR or LOW_COVER
- Represents navigable ground

Static Areas:
- Walls, obstacles, clutter
- Can be HEIGHT_WALL, TALL, OVERHEAD
- Defines level topology
```

#### Step 3: Paint Heights Semantically

```
Designer's Mental Model:

"I want:
- An open room (FLOOR)
- With a central pillar (WALL/TALL)
- Covered by overhead beams (OVERHEAD)
- With some low boxes for hiding (LOW_COVER)"

Painting:
1. Paint ground area: HEIGHT_FLOOR
2. Paint pillar: HEIGHT_TALL
3. Paint overhead: HEIGHT_OVERHEAD
4. Paint boxes: HEIGHT_LOW_COVER
```

#### Step 4: Validate Height Topology

Check:
- ✓ Playable areas connected (FLOOR/LOW_COVER path exists)
- ✓ Cover is positioned strategically
- ✓ OVERHEAD blocks from above correctly
- ✓ No "floating" TALL structures without support
- ✓ Silhouettes are clear to player

### Height Painting Guidelines

#### For Rooms

```
// Simple room example
####################
#FLOOR.....FLOOR..#
#..TALL......TALL.#
#FLOOR.....FLOOR..#
#WALL......WALL...#
####################

Meanings:
# = solid wall (boundary)
. = playable floor
TALL = central pillar
WALL = obstacle/barrier
```

#### For Verticality

```
// Multi-level room
┌─────────────────┐
│ OVERHEAD (L3)   │  ← Ceiling beams (height 4)
├─────────────────┤
│ FLOOR with      │  ← Ground (height 0)
│ TALL posts      │  ← Central support (height 3)
│ LOW_COVER boxes │  ← Crates for hiding (height 1)
└─────────────────┘
```

#### For Stealth Opportunities

```
// Strategic height layout for stealth play
TALL                TALL
  │                  │
FLOOR──LOW_COVER──FLOOR
  │                  │
WALL    OVERHEAD    WALL

Design intent:
- FLOOR is dangerous (exposed)
- LOW_COVER provides concealment
- TALL posts create shadow zones
- OVERHEAD reduces detection range
```

### Height Painting Constraints

```
Constraint 1: Adjacent heights must be compatible
✓ FLOOR → LOW_COVER → WALL (gradual progression)
✗ FLOOR → OVERHEAD (missing intermediate)

Constraint 2: Playable space must be traversable
✓ FLOOR and LOW_COVER form connected path
✗ Isolated FLOOR tiles (unreachable)

Constraint 3: Cover placement must be strategic
✓ LOW_COVER positioned for stealth
✗ Random placement without stealth value

Constraint 4: Silhouettes must be readable
✓ Clear distinction between heights visually
✗ Similar-height structures create visual confusion
```

---

## Light Placement Workflow

### Overview

Light placement defines tactical lighting for gameplay. Each light source explicitly specifies:

- Type and positioning
- Emission characteristics
- Tactical and visual energy
- Temporal effects

### Philosophy

```
Lighting is NOT inferred from environment.
Lighting is explicitly authored by designer.

Each light is a deliberate gameplay decision.
```

### Light Properties

Each light source defines:

```gdscript
class LightPlacementData:
    var cell: Vector2i              # Grid position
    var type: String                # OMNI, DIRECTIONAL, SPOTLIGHT, CEILING, etc.
    var height: int                 # HEIGHT_FLOOR, HEIGHT_WALL, etc.
    
    # Emission characteristics
    var radius: int                 # How far light reaches (tiles)
    var intensity: float            # 0.0-1.0 brightness
    var tactical_energy: float      # 0.0-1.0 stealth danger
    
    # Emission direction
    var emission_direction: String  # OMNI, DOWN, UP, HORIZONTAL, etc.
    var emission_angle: float       # For directional lights (degrees)
    
    # Temporal properties (L-IMP-06)
    var flicker_enabled: bool = false
    var flicker_interval: float = 0.5
    var pulse_enabled: bool = false
    var pulse_speed: float = 1.0
    var rotation_speed: float = 0.0
    
    # Serialization
    var active: bool = true
    var author_notes: String = ""
```

### Light Placement Process

#### Step 1: Determine Lighting Intent

```
Question: What does this light DO for stealth gameplay?

Possible Answers:
- "Creates dangerous fully-lit zone" (high tactical_energy)
- "Illuminates entry checkpoint" (medium tactical_energy)
- "Dim ambient light" (low tactical_energy)
- "Creates flickering distraction" (temporal effect)
- "Provides stealth opportunity when timed right" (temporal + low energy)
```

#### Step 2: Place Light at Semantic Anchor

```
Question: Where can this light physically be anchored?

Valid Anchors (from tile_semantics.gd):
- CEILING: HEIGHT_OVERHEAD structures (hanging lights)
- WALL: HEIGHT_WALL structures (wall-mounted)
- FLOOR: HEIGHT_FLOOR (standing lamp)
- COLUMN: HEIGHT_TALL (column-top mounted)
- SPOTLIGHT: Directional from specific angle
- AMBIENT: Global, no specific anchor
```

**Example:**
```
// Room with light placement
####################
#CEILING_LIGHT.....#  ← CEILING anchor on OVERHEAD
#FLOOR.....FLOOR..#
#..TALL......TALL.#
#FLOOR.....FLOOR..#
#WALL_LIGHT..WALL.#  ← WALL anchor on WALL
####################
```

#### Step 3: Define Tactical Energy

```
Tactical Energy = How dangerous this light is for stealth

0.0 = Completely safe (dark shadow)
0.25 = Dim (negotiable)
0.5 = Medium (risky)
0.75 = Bright (very dangerous)
1.0 = Fully lit (maximum danger)
```

**Mapping:**
```
Tactical Energy  →  Visibility Class  →  Detection Multiplier
0.0              →  OCCLUDED_VOID     →  0.0x (safe)
0.1-0.2          →  DEEP_SHADOW       →  0.1-0.2x
0.3-0.4          →  SHADOW            →  0.3-0.4x
0.5-0.6          →  PENUMBRA          →  0.5-0.6x
0.7-0.8          →  DIM               →  0.7-0.8x
0.9-1.0          →  FULL_LIT          →  0.9-1.0x
```

#### Step 4: Configure Temporal Effects (Optional)

```
Temporal effects create gameplay opportunities:

Flicker:
- Represents unreliable light
- Creates brief concealment windows
- Detection becomes time-dependent
- interval: how fast flicker cycles

Pulse:
- Represents breathing or pulsing light
- Creates gradual concealment cycles
- Good for timed movement challenges
- speed: how fast pulse cycles

Rotation:
- Represents rotating spotlight
- Creates predictable pattern
- Challenge: predict light sweep
- speed: degrees per second
```

**Example:**
```
Light: SPOTLIGHT (tactical_energy: 0.8)
- Rotates slowly (rotation_speed: 45°/sec)
- Sweeps in 360° every 8 seconds
- Guard must time movement between sweeps
- Player learns pattern and times escape
```

#### Step 5: Annotate with Author Notes

```gdscript
// Example placement
light_data = {
    "cell": Vector2i(15, 10),
    "type": "CEILING",
    "radius": 5,
    "tactical_energy": 0.75,
    "flicker_enabled": true,
    "flicker_interval": 0.8,
    "author_notes": "Guard checkpoint light. Flicker creates 
                     brief concealment every 0.8s. Agent must 
                     time entry through this zone."
}
```

### Light Placement Guidelines

#### For Guard Checkpoints

```
Design: Heavy illumination, no escapes except timed

Light Configuration:
- type: CEILING or SPOTLIGHT
- radius: 6-8 tiles
- tactical_energy: 0.85-1.0
- flicker: false (consistent)
- Result: Dangerous zone, must evade completely
```

#### For Stealth Opportunities

```
Design: Strategic darkness, timed concealment

Light Configuration:
- type: CEILING with flicker
- radius: 4-5 tiles
- tactical_energy: 0.4-0.5
- flicker_interval: 1.0-2.0 (slow, predictable)
- Result: Skilled player times movement through flicker
```

#### For Ambient Lighting

```
Design: Global environment, not per-tile

Light Configuration:
- type: AMBIENT
- radius: entire level
- tactical_energy: 0.2-0.3 (baseline)
- temporal: false
- Result: Baseline illumination, adds to local lights
```

#### For Dynamic Pressure

```
Design: Creating temporal challenge

Light Configuration:
- type: SPOTLIGHT with rotation
- radius: 3-4 tiles
- tactical_energy: 0.6-0.8
- rotation_speed: 60°/sec (1 rotation per 6 sec)
- Result: Guard must predict sweep pattern, time movement
```

---

## Serialization Model

### Overview

The serialization model defines how level data persists and loads. It establishes data contracts for:

- Map metadata storage
- Tile semantics encoding
- Light source persistence
- Structural data archival

### Data Organization

#### Tier 1: Map Metadata (Global)

```json
{
  "map_version": "1.0",
  "author": "Level Designer Name",
  "date_created": "2026-06-14",
  "difficulty": "normal",
  "bounds": { "width": 50, "height": 50 },
  "spawn_point": { "x": 5, "y": 5 },
  "objectives": [
    { "type": "eliminate_target", "target": "Guard Captain" },
    { "type": "retrieve_data", "location": (30, 30) }
  ]
}
```

#### Tier 2: Tile Semantics (Per-Tile)

```json
{
  "tiles": {
    "15,10": {
      "height": "wall",
      "structure": "wall",
      "occlusion": "solid",
      "can_receive_light": true,
      "is_light_socket": false,
      "visual_style": "concrete"
    },
    "16,10": {
      "height": "floor",
      "structure": "floor",
      "occlusion": "transparent",
      "can_receive_light": true,
      "is_light_socket": false,
      "visual_style": "tile"
    }
  }
}
```

#### Tier 3: Light Source Persistence

```json
{
  "lights": [
    {
      "id": "light_checkpoint_01",
      "cell": { "x": 20, "y": 15 },
      "type": "ceiling",
      "radius": 6,
      "intensity": 0.9,
      "tactical_energy": 0.85,
      "flicker": { "enabled": false },
      "active": true
    },
    {
      "id": "light_stealth_01",
      "cell": { "x": 10, "y": 25 },
      "type": "ceiling",
      "radius": 4,
      "intensity": 0.4,
      "tactical_energy": 0.4,
      "flicker": { "enabled": true, "interval": 1.0 },
      "active": true
    }
  ]
}
```

#### Tier 4: Structural Anchors (Light Sockets)

```json
{
  "light_anchors": [
    {
      "id": "anchor_guard_post_01",
      "cell": { "x": 20, "y": 15 },
      "type": "ceiling",
      "height": "overhead",
      "direction": "down",
      "capacity": 2
    },
    {
      "id": "anchor_wall_mounted_01",
      "cell": { "x": 25, "y": 10 },
      "type": "wall",
      "height": "wall",
      "direction": "horizontal",
      "capacity": 1
    }
  ]
}
```

### Serialization Format

**Current Recommendation:**
```
Format: JSON (human-readable, git-friendly, versionable)
Encoding: UTF-8
Structure: Hierarchical (metadata → tiles → lights → anchors)
Versioning: Explicit version field, semantic versioning
```

**Rationale:**
- JSON is text-based (git diffs are readable)
- Hierarchical structure mirrors data relationships
- Versioning enables safe evolution
- Simple parsing from GDScript

**Example File Structure:**
```
maps/
├── level_01_intro.json
│   ├── metadata (global)
│   ├── tiles (per-cell)
│   ├── lights (all light sources)
│   └── anchors (structural sockets)
├── level_02_compound.json
└── level_03_warehouse.json
```

### Data Validation

Level validation ensures consistency:

```gdscript
func validate_map(map_data: Dictionary) -> Array:
    var errors = []
    
    # Tier 1: Metadata
    if !map_data.has("map_version"):
        errors.append("Missing map_version")
    
    # Tier 2: Tiles
    for cell_key in map_data["tiles"]:
        var tile = map_data["tiles"][cell_key]
        if !_is_valid_height(tile["height"]):
            errors.append("Invalid height: " + cell_key)
        if !_is_valid_occlusion(tile["occlusion"]):
            errors.append("Invalid occlusion: " + cell_key)
    
    # Tier 3: Lights
    for light in map_data["lights"]:
        if !_is_valid_light_placement(light):
            errors.append("Invalid light placement: " + light["id"])
    
    # Tier 4: Anchors
    for anchor in map_data["anchors"]:
        if !_is_valid_anchor_height(anchor):
            errors.append("Invalid anchor height: " + anchor["id"])
    
    # Cross-tier validation
    if !_lights_match_anchors(map_data):
        errors.append("Light placement doesn't match anchors")
    
    return errors
```

---

## Data Ownership Matrix

### System Ownership & Responsibilities

| System | Owns | Produces | Consumes | Modifies |
|--------|------|----------|----------|----------|
| **Map Authoring** | Tile metadata | Heights, structures | None | Map data during design |
| **Height Painting** | Height grid | Height classes | Map structure | Tile heights |
| **Light Placement** | Light sources | Light data | Map bounds | Light properties |
| **ShadowProjector** | Shadow calculation | Shadow results | Tile heights, lights, occlusion | None (read-only) |
| **ExposureSystem** | Exposure mapping | Exposure grid | Shadows, lights | Exposure data |
| **Serialization** | Persistence layer | File data | Runtime state | File I/O only |

### Authoring-Time Ownership

```
Designer owns: Semantic decisions
- "This is a wall" (height decision)
- "This light is dangerous" (tactical_energy decision)
- "This zone should have cover" (structural decision)

System infers: Derived data
- Shadow projection (from light + structure)
- Exposure classes (from shadows)
- Detection probability (from exposure)
```

### Runtime Ownership

```
RuntimeSystem owns: Calculated results
- ShadowProjector owns shadow topology
- ExposureSystem owns exposure mapping
- Overlays own visualization

Designer data is: Read-only at runtime
- Heights don't change during play
- Light positions don't change (unless dynamic)
- Occlusion doesn't change (unless dynamic)
```

---

## Mapping Constraints & Best Practices

### Design Constraints

#### Constraint 1: Favor Stealth Readability

```
Players must be able to read the stealth situation instantly.

Good:
- Clear light zones (bright areas obvious)
- Distinct cover (LOW_COVER visually distinct)
- Shadow patterns are understandable
- LOS blocking is visible

Bad:
- Ambiguous darkness (is it safe?)
- Cover hidden behind clutter
- Confusing light patterns
- LOS blocking unclear
```

#### Constraint 2: Avoid Visual Clutter

```
Too many elements reduce readability.

Budget per room:
- Max 3-4 distinct light sources (+ ambient)
- Max 5-6 major structural elements
- Max 2-3 height layers clearly expressed
- Negative space for clarity

Purpose: Player can understand room at glance
```

#### Constraint 3: Maintain Silhouette Clarity

```
Agent silhouette must be readable in all contexts.

Good:
- Light + shadow create clear agent outline
- Cover arrangement shows standing vs crouching
- Height changes show agent's tactical position

Bad:
- Agent merges with environment
- Multiple overlapping heights confuse position
- Lighting erases agent outline
```

#### Constraint 4: Support Multiple Stealth Strategies

```
Room should support 2-3 distinct playstyles:
- Direct action (guards avoided entirely)
- Stealth timing (movement between light cycles)
- Cover-based hiding (use of structural elements)

Example:
- Path 1: Around guard (low-cover route)
- Path 2: Wait for darkness (temporal stealth)
- Path 3: Eliminate quietly (direct action)
```

### Layout Best Practices

#### For Guard Patrol Rooms

```
Layout Pattern:
┌─────────────────────────────┐
│ CHECKPOINT                  │
│ ◉ Heavy lighting            │
│ ├─ CEILING light (0.85 energy)
│ ├─ Minimal cover            │
│ └─ Forced evasion            │
└─────────────────────────────┘

Purpose:
- Guard sees everything
- Agent must avoid entirely or use timing
- Creates "do or die" tension
```

#### For Stealth Challenge Rooms

```
Layout Pattern:
┌─────────────────────────────┐
│ MEDIUM LIGHTING             │
│ + STRATEGIC COVER           │
│ ◉ Light 1 (0.6 energy)      │
│ ◉ Light 2 (0.4 energy)      │
│ + Low-cover boxes           │
│ = Multiple paths possible    │
└─────────────────────────────┘

Purpose:
- Rewards careful observation
- Multiple valid approaches
- Player feels clever
```

#### For Narrative Spaces

```
Layout Pattern:
┌─────────────────────────────┐
│ LOW-PRESSURE ZONE           │
│ ◉ Dim ambient lighting      │
│ ◉ Spotlight on objective    │
│ + Plenty of cover           │
│ = Story focus without danger │
└─────────────────────────────┘

Purpose:
- Player explores safely
- Focuses on objective/dialogue
- Reduces stealth pressure
```

---

## Future Tooling Pipeline

Prepared for future implementation (not current scope):

### Tool 1: Height Painter (LIGHT-04)

```
Purpose: Visual editor for height painting

Features:
- Paintbrush for height classes
- Live preview of height topology
- Validation feedback (connectivity, coverage)
- Silhouette preview
- Height heatmap (visual distribution)

Input: Mouse + keyboard
Output: Updated tile_metadata

Status: Designed, not implemented
```

### Tool 2: Light Painter (LIGHT-04)

```
Purpose: Visual light placement editor

Features:
- Click to place lights
- Drag to adjust radius
- Real-time exposure preview
- Tactical energy visualization
- Light overlap detection

Input: Mouse placement
Output: Updated light_source_data

Status: Designed, not implemented
```

### Tool 3: Semantic Validator (LIGHT-04)

```
Purpose: Verify map consistency

Checks:
- Height topology connected (playable space)
- Lights placed at valid anchors
- Occlusion consistent with height
- No isolated tiles
- Light coverage adequate

Input: Map file
Output: Validation report + warnings

Status: Partially implemented (in room.gd)
```

### Tool 4: Exposure Preview (LIGHT-04)

```
Purpose: Visualize exposure before runtime

Features:
- Show exposure grid
- Color-code visibility classes
- Highlight detection hotspots
- Temporal animation preview
- Risk heatmap

Input: Map + lights
Output: Exposure visualization overlay

Status: Implemented via elite_exposure_overlay.gd
```

### Tool 5: Stealth Readability Analyzer (LIGHT-05)

```
Purpose: Analyze level design for stealth clarity

Measures:
- Silhouette distinctness
- Light pattern comprehensibility
- Strategic cover adequacy
- Multiple approach viability
- Player confusion risk

Input: Map + visual assets
Output: Readability score + recommendations

Status: Designed, not implemented
```

---

## Example: Complete Authoring Workflow

### Scenario: Designing a Guard Checkpoint Room

#### Phase 1: Conceptual Design

```
Designer's Intent:
"I want a guard checkpoint that forces tactical challenge.
 Heavy lighting, limited cover, player must time movement
 through darkness or find alternate route."
```

#### Phase 2: Height Painting

```
Step 1: Identify room structure
- Outer perimeter: WALL (solid boundary)
- Center floor: FLOOR (playable area)
- Checkpoint position: TALL (guard barrier)
- Overhead: OVERHEAD (ceiling lamp support)

Step 2: Paint heights
####################
#WALL...WALL...WALL#
#WALL.FLOOR...WALL.#
#WALL.TALL.TALL.WALL#
#WALL.FLOOR...WALL.#
#WALL..CEILING.WALL#
####################

Step 3: Validate topology
✓ Center playable area connected
✓ TALL creates natural checkpoint
✓ OVERHEAD positioned for light anchor
✓ WALL boundary is clear
✓ No floating elements
```

#### Phase 3: Light Placement

```
Step 1: Identify lighting anchor
- Checkpoint has CEILING anchor
- Position: (10, 12)
- Type: CEILING (hanging light)

Step 2: Configure light
{
  "id": "checkpoint_01",
  "cell": { "x": 10, "y": 12 },
  "type": "ceiling",
  "radius": 6,
  "intensity": 0.95,
  "tactical_energy": 0.90,
  "flicker": false,
  "active": true,
  "notes": "Heavy checkpoint lighting. Illuminates entire 
            central zone. Forces evasion or timing."
}

Step 3: Preview exposure
✓ Light illuminates checkpoint area (0.90 energy)
✓ Creates strong shadows around perimeter
✓ Player can see safe routes through shadows
✓ Timing movement requires precision
```

#### Phase 4: Validation

```
Step 1: Semantic validation
✓ Heights form connected playable space
✓ Light anchored to CEILING structure
✓ Occlusion consistent (WALL is SOLID)
✓ Tactical energy matches intent

Step 2: Stealth readability
✓ Checkpoint clearly visible (high energy)
✓ Shadow patterns understandable
✓ Agent silhouette readable in all zones
✓ Multiple escape routes possible

Step 3: Gameplay validation
✓ Room supports timing challenge
✓ Alternative routes exist (low-cover path)
✓ Direct action possible (eliminate guard)
✓ Stealth scoring achievable
```

#### Phase 5: Runtime Verification

```
Step 1: Load map
- Tile metadata loaded
- Light sources registered
- Exposure grid calculated
- Overlays initialized

Step 2: In-game validation
✓ Light behaves as intended
✓ Exposure matches preview
✓ Guard sees as expected
✓ Player can execute strategy

Result: ✓ COMPLETE
```

---

## Acceptance Criteria (LIGHT-03)

- ✅ `lighting_authoring_pipeline.md` exists (800+ lines)
- ✅ Authoring philosophy defined (5 principles)
- ✅ Structural metadata documented (per-tile data structure)
- ✅ Height painting workflow specified (5-step process)
- ✅ Light placement workflow specified (5-step process)
- ✅ Serialization model defined (4-tier hierarchical)
- ✅ Data ownership matrix established (system responsibilities)
- ✅ Mapping constraints documented (4 key constraints)
- ✅ Future tooling registered (5 tools prepared)
- ✅ Complete workflow example provided (checkpoint room)
- ✅ System remains semantic-driven (no visual dependencies)

---

## Document Status

**Author:** Architecture / Level Design & Authoring Pipeline  
**Date:** 2026-06-14  
**Version:** 1.0 (LIGHT-03)  
**Status:** Complete 🟢

**Purpose:** Formalize authoring pipeline and serialization before content expansion

**Next Steps:**
1. Use this pipeline for all future level authoring
2. Reference when implementing LIGHT-04 (tooling)
3. Reference when expanding content
4. Use as basis for team authoring guidelines
5. Prepare for level editor development

**Maintained By:** Architecture / Level Design Lead  
**Review Cycle:** Before content expansion, before tool implementation

---

## Related Architecture Documents

| Document | Focus | Scope |
|----------|-------|-------|
| [LIGHT-01: Lighting Runtime Pipeline](../systems/lighting_runtime_pipeline.md) | Runtime flow, system ownership | Runtime behavior |
| [LIGHT-02: Occlusion Semantics](../systems/occlusion.md) | Structural blocking model | Gameplay semantics |
| **[LIGHT-03: Authoring Pipeline](lighting_authoring_pipeline.md)** | **Level design workflow** | **Design-time processes** |
| LIGHT-04: Tooling (Future) | Editor implementation | Tool development |
| LIGHT-05: Content Guidelines (Future) | Asset standards | Team consistency |

---

## Key Architecture Invariants

```
✓ Height painting is independent of sprite size
✓ Light placement is explicit, never inferred
✓ Semantics drive visuals, not vice versa
✓ All authoring data is versionable (git-friendly)
✓ Data ownership is clear (designer vs system)
✓ Serialization supports extension (versioning)
✓ Validation prevents inconsistency
✓ Tooling builds on stable data contracts
```
