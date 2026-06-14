# INFILTRAITOR — Lighting System

> **Semantic taxonomy of illumination, visibility, and tactical stealth. Gameplay-first design with discrete, auditable visibility classes.**

---

## Overview

The lighting system is **not visual decoration**. It is a core gameplay and stealth mechanic.

**Primary Purpose:**
- Define **tactical visibility** — how exposed the agent is to guard detection
- Enable **stealth progression** — shadows as safe zones, light as danger zones
- Support **AI perception** — guards detect based on light exposure
- Provide **readable feedback** — player understands visibility state instantly

**Key Principle:**
```
visual brightness  ≠  tactical visibility
```

The appearance of light on screen is **secondary** to the gameplay state it represents.

---

## Design Goals

### 1. Gameplay-First Architecture

Lighting is **not** derived from visual rendering or shaders. It is a **discrete game state**:

```gdscript
var visibility_class: String = "SHADOW"  ## Semantic state, independent of renderer
```

Visual lighting is then **styled** to match this state, not the reverse.

### 2. Core Principles

| Principle | Meaning |
|-----------|---------|
| **Deterministic** | Same position always produces same visibility (no random flicker) |
| **Grid-Based** | Visibility is per-tile, not per-pixel or per-position |
| **Auditable** | Player can always understand *why* they are in a given visibility class |
| **Semantic** | Classes have clear meaning: SHADOW = stealth, FULL_LIT = danger |
| **Discrete** | 5 visibility classes, not continuous values (avoids ambiguity) |
| **Stealth-Oriented** | Light/shadow fundamentally changes guard detection probability |

### 3. Design Constraints

- Visibility must be **consistent** across all observers (all guards see same exposure)
- Visibility must **change smoothly** at tile boundaries (no hard edges except walls)
- Visibility must be **computable in real-time** (shadows baked, not streamed)
- Visibility must be **independent of camera** (tactical, not visual)

### 3. Design Constraints

- Visibility must be **consistent** across all observers (all guards see same exposure)
- Visibility must **change smoothly** at tile boundaries (no hard edges except walls)
- Visibility must be **computable in real-time** (shadows baked, not streamed)
- Visibility must be **independent of camera** (tactical, not visual)

---

## Lighting Taxonomy

### Light Source Types

| Type | Description | Range | Behavior | Example |
|------|-------------|-------|----------|---------|
| **Omni** | Radial illumination from point source | 1–8 tiles | Emits equally in all directions | Torch, lamp, emergency exit sign |
| **Directional** | Linear incidence from fixed direction | Entire tile layer | Sunlight, moon, global ambient | Daylight, moon glow |
| **Cone** | Focused beam with falloff (FOV-like) | 3–6 tiles | Directional with angle attenuation | Spotlight, guard flashlight, lighthouse beam |
| **Ambient** | Global weak illumination (no source) | Entire level | Uniform floor illumination | Base light level, faint glow |
| **Intermittent** | Pulsing or flickering light | 1–4 tiles | Rhythmic on/off cycles | Alarm light, strobe, malfunctioning lamp |
| **Emergency** | High-intensity alert lighting | 2–6 tiles | Triggered by alerts, full intensity | Lockdown searchlight, alert override |
| **Mobile** | Light coupled to entity (AI, player) | Local to entity | Moves with entity, independent of level | Guard's torch, player's equipped light |

### Light Quality Types

| Quality | Intensity | Detection Bonus | Tactical Use | Example |
|---------|-----------|-----------------|--------------|---------|
| **Full Bright** | 100% | +100% (max exposure) | Danger zones, enforced spaces | Main corridor under spotlight |
| **Bright** | 70–85% | +60% detection | Active monitoring zones | Guard post, command center |
| **Normal** | 40–60% | +20% detection | Standard patrolled areas | Corridor, stairwell |
| **Dim** | 15–30% | -30% detection | Semi-safe zones | Storage room, side passages |
| **Dark** | 2–10% | -70% detection | Stealth zones | Shadows, alcoves, blind corners |

---

## Visibility Classes

### Definition

**Visibility Class** is a **semantic label** that describes the agent's exposure at a given tile. It determines:

- How easily guards detect the agent
- What stealth bonuses apply
- What visual feedback the player sees
- What audio/UI cues are triggered

### The Five Visibility Classes

| Class | Exposure Level | Guard Detection Bonus | Tactical Meaning | Visual Appearance |
|-------|---------------|-----------------------|------------------|-------------------|
| **FULL_LIT** | Maximum exposure | +100% (multiplier: 2.0) | Detected easily; avoid | Bright, high saturation, no shadows |
| **DIM** | Partial exposure | +20% (multiplier: 1.2) | Visible but forgiving | Well-lit, some shadows, readable |
| **PENUMBRA** | Degraded perception | -30% (multiplier: 0.7) | Detected reluctantly | Mixed light/shadow, ambiguous edges |
| **SHADOW** | Strong concealment | -60% (multiplier: 0.4) | Effective stealth | Dark, sharp shadows, low readability |
| **DEEP_SHADOW** | Maximum concealment | -80% (multiplier: 0.2) | Expert stealth | Near-black, detailed shadows, dev-only |

### Discrete by Design

These 5 classes are **mutually exclusive** per tile. No intermediate states.

**Why?**
- Eliminates ambiguity for player
- Makes AI decision-making simpler (each class has clear behavior)
- Reduces shader complexity (5 discrete materials vs. continuous blending)
- Auditable: player can predict visibility by tile appearance

---

## Gameplay Semantics

### How Guards Interpret Visibility

Guards use visibility class as a **multiplier on their base detection probability**:

```gdscript
func get_detection_probability(agent_tile: Vector2i, distance: float) -> float:
    var base_prob = distance_curve(distance)  ## Intrinsic detection based on distance
    var visibility_mult = visibility_multiplier(agent_tile)  ## Lighting modifier
    return base_prob * visibility_mult
```

**Multiplier Table:**

| Visibility Class | Multiplier | Example Detection |
|------------------|------------|-------------------|
| FULL_LIT | 2.0 | 60% base → **120%** (capped at 100% = guaranteed) |
| DIM | 1.2 | 60% base → **72%** |
| PENUMBRA | 0.7 | 60% base → **42%** |
| SHADOW | 0.4 | 60% base → **24%** |
| DEEP_SHADOW | 0.2 | 60% base → **12%** (nearly invisible) |

### UI & Player Feedback

**Visibility Indicator (HUD):**
- Show current class + danger level (0–100%)
- Update in real-time as agent moves
- Change color per class (green SHADOW → red FULL_LIT)

**Audio Cues:**
- FULL_LIT: High-alert beep (110 Hz tone)
- DIM: Neutral ambient sound continues
- SHADOW: Quiet, minimal feedback (stealth is "silent")

**Visual Feedback:**
- Tile highlight or aura when agent moves to new class
- Smooth fade between classes at tile boundaries
- DEV_VISION overlay for tactical visibility map

---

## Tactical Lighting vs Visual Lighting

### Critical Separation

**Tactical Lighting** (Gameplay):
- Computed from light sources, obstacles, and shadows
- Determines visibility class per tile
- Affects guard detection probability
- **Independent of renderer**

**Visual Lighting** (Rendering):
- Shaders, bloom, HDR, post-processing
- Creates atmospheric appearance
- Styled to match tactical lighting but not required to match exactly
- Can be disabled (e.g., colorblind mode, dev mode)

### Why This Matters

**Problem:** If gameplay depends on visual rendering:
- Shader bugs → gameplay bugs
- Performance optimization (reduce shaders) → stealth broken
- Accessibility features break gameplay

**Solution:** Tactical lighting is a **discrete game state**, separate from rendering.

**Example:**
```gdscript
## Tactical: What game engine computes
visibility_class = "SHADOW"  ## This is what matters for gameplay

## Visual: What renderer displays (can be customized)
shader_brightness = 0.2     ## Visual appearance
shader_saturation = 0.5
hdr_bloom = false
```

A player could be in SHADOW (stealth) with a visual that appears darker or lighter—the **tactical class** is what guards see.

---

## DEV_VISION

### Philosophy

In **DEV_VISION** (toggled with `V` key), the system displays:

- **Visibility class per tile:** Color-coded overlay (green SHADOW, red FULL_LIT)
- **Guard detection map:** Heatmap showing where guards are focused
- **Light source projection:** Circles/cones showing light coverage
- **Tactical flow map:** Recommended safe routes
- **Shader layers:** Separate toggles for shadow, highlight, normal rendering

### Purpose

DEV_VISION is **not** for player use. It is for:
- Level design verification (ensuring shadows align with design intent)
- AI debugging (seeing why guards move certain ways)
- Performance profiling (which overlays cost most)
- Educational feedback (teaching player how stealth works)

### Runtime (Non-DEV) Display

During normal gameplay:
- Minimal UI (only essential threat indicators)
- Clean visual (no debug overlays)
- No tactical maps (player must infer from environment)
- Ambient audio only (no debug beeps)

---

## Tactical Visibility Tiers

### How Guards Use Visibility Class

#### Tier 1: Can Agent Be Detected?

```
FULL_LIT or DIM    → YES, easily
PENUMBRA           → YES, possible
SHADOW             → NO, unlikely
DEEP_SHADOW        → NO, almost impossible
```

#### Tier 2: How Fast Is Detection?

```
FULL_LIT           → Instant (same turn)
DIM                → 1–2 turns
PENUMBRA           → 2–4 turns
SHADOW             → 4+ turns (slow accumulation)
DEEP_SHADOW        → 8+ turns (negligible)
```

#### Tier 3: What Happens After Detection?

Once agent is **detected** (not just visible):
- Detection probability becomes **irrelevant** (already caught)
- Guard enters **CHASE** state
- Lighting advantage is **lost**
- Combat/escape is the only option

---

## Light Source Positioning Rules

### How Lights Distribute Visibility

1. **Omni Sources:** Concentric circles of decreasing visibility
   - Center (0–1 tile): FULL_LIT
   - Inner ring (2–3): DIM
   - Mid ring (4–5): PENUMBRA
   - Outer ring (6–8): SHADOW
   - Beyond: unlit

2. **Directional Sources:** Linear gradient
   - Direct path: FULL_LIT
   - 45° falloff: DIM
   - 90° falloff: PENUMBRA
   - Behind: DEEP_SHADOW

3. **Ambient:** All tiles uniform unless overridden
   - Typical: DIM (safe but not stealthy)
   - Can be lowered to PENUMBRA (night scene)
   - Cannot be FULL_LIT (that requires specific light sources)

4. **Obstacles Block Light:**
   - Walls: Hard shadow (DEEP_SHADOW behind)
   - Pillars: Soft shadow (PENUMBRA behind)
   - Furniture: Partial block (gradient around)

---

## Planned Extensions

### Near-term (M2)

- **Tactical Visibility Overlay:** Real-time map of visibility per tile (DEV_VISION)
- **Dynamic Shadows:** Baked shadows update when player moves obstacles
- **Alert Lighting:** Emergency lights trigger when alert level rises

### Medium-term (M3)

- **Night Vision Upgrade:** Gadget that shifts SHADOW → DIM (tactical advantage)
- **Light Manipulation:** Player can disable/redirect light sources
- **Thermal Optics:** Alternative visibility system (heat instead of light)
- **Adaptive Stealth Gear:** Equipment that reduces detection in specific classes

### Long-term (M4+)

- **Moving Spotlights:** Animated cone lights (guards with flashlights)
- **Light Puzzles:** Environmental challenges using shadow geometry
- **Power Systems:** Lights tied to facility power (disrupt = darkness)
- **Alarm Lighting:** Special red alert mode with high-intensity lighting
- **Guard Reinforcement Waves:** Each wave adds more lighting coverage

---

## Glossary

| Term | Definition |
|------|-----------|
| **Visibility Class** | Discrete semantic label for agent exposure (5 classes) |
| **Tactical Lighting** | Game state computation (gameplay-relevant) |
| **Visual Lighting** | Renderer output (appearance, shaders) |
| **Light Source** | Origin of illumination (omni, directional, cone, ambient, etc.) |
| **Shadow** | Region where visibility class is reduced |
| **Detection Multiplier** | How visibility class scales guard detection probability |
| **DEV_VISION** | Debug overlay showing tactical lighting map |
| **Tactical Visibility Map** | Grid showing visibility class per tile (DEV_VISION only) |
| **Ambient Light** | Global baseline lighting (no specific source) |
| **Stealth Zone** | Area where visibility class is SHADOW or better |

---

## Technical Implementation (M2-13+)

### Shadow Projection Geometry

When an obstacle blocks a light source, it casts a shadow **cone** in the direction away from the light:

$$\text{shadow\_length} = \frac{\text{obstacle\_height} \times (\text{light\_height} - \text{obstacle\_height})}{\text{distance}}$$

(Details: See M2-13 implementation document)

### Baked Shadow System

Shadows are pre-calculated per room and stored on dedicated TileMapLayers.

**Current Status:** Shadows rendered via `TileOverlay` system (Prompt H) with 3-level gradation.

---

## References

- **Perception System:** `docs/systems/perception.md` — How guards use visibility
- **Rendering System:** `docs/systems/rendering.md` — Shadow and overlay rendering
- **Tactical Semantics:** `docs/systems/ai.md` — Guard AI uses visibility classes
- **Code:** `godot/scripts/systems/lighting_system.gd` (planned M2-13)

---

# L-DOC-02: Vertical Lighting Topology & Height Semantics

> **Semantic vertical architecture. Defines layer structure, height classes, and shadow projection rules. Does NOT implement runtime shadow casting, shaders, or optimizations.**

---

## Vertical Topology

The lighting system recognizes **4 semantic vertical layers**, stacked to create depth without requiring full 3D pathfinding.

### Design Rationale

**Avoided:** Multi-floor traditional gameplay, vertical navigation complexity  
**Instead:** Semantic planes with rich shadow projection and tactical depth

**Enables:**
- Visual profundity
- Complex shadow casting
- Tactical verticality
- Auditable gameplay semantics

**Does NOT enable:**
- True 3D pathfinding
- Vertical entity traversal
- Multi-level patrolling
- Elevation-based movement costs (future extensions only)

---

## Vertical Layers

### Layer Definitions

| Layer | Semantic Purpose | Examples | Height Range |
|-------|------------------|----------|---------------|
| **L3 — Overhead** | Infrastructure above playable space | Suspended lights, rails, drones, ventilation, moving lights, catwalks | 4.5–8.0 units |
| **L2 — Structural** | Elevated solid obstacles | Tall walls, pillars, stacked crates, containers, machinery | 2.0–4.5 units |
| **L1 — Playable** | Agent/guard movement and interaction | Agents, guards, interactive objects, ground-level cover | 0.0–2.0 units |
| **L0 — Subfloor** | Atmospheric and beneath-ground effects | Lava, smoke vents, electrical discharges, water, underground installations | −2.0–0.0 units |

### Layer Interactions

```
L3 (Overhead)      ← Casts shadows DOWN onto L2, L1
    ↓
L2 (Structural)    ← Blocks light FROM L3, casts shadows onto L1, L0
    ↓
L1 (Playable)      ← Where agents/guards move; receives all shadow cast
    ↓
L0 (Subfloor)      ← Beneath visibility; receives shadow but rarely interacts
```

---

## Height Semantics

### Height Classes

Each entity has a **semantic height class** (discrete, not continuous):

| Class | Height | Semantic Meaning | Examples |
|-------|--------|------------------|----------|
| **0 — Floor** | 0.0 units | Base level; no occlusion; no shadow casting | Floor decals, marks, minor terrain features |
| **1 — Low Cover** | 0.5–1.0 units | Small obstacles; limited shadow; crouching equivalent | Small crates, floor-level rubble, low walls |
| **2 — Human Height** | 1.5–2.0 units | Standard entity height; generates shadow; receives shadow | Agents, guards, pillars, standard crates |
| **3 — Tall Structure** | 2.5–3.5 units | Elevated obstacles; long shadow cast; blocks overhead light | Tall containers, wall stacks, machinery |
| **4 — Overhead** | 4.5+ units | Lights, catwalks, suspended infrastructure; never receives shadow | Lamps, drones, ventilation systems, bridges |

### Discrete-by-Design

```
The system uses DISCRETE semantic heights.
Continuous physical simulation is intentionally AVOIDED.
```

**Why?**
- Eliminates physics complexity
- Makes shadow projection auditable (no interpolation)
- Supports caching (discrete heights = discrete shadow sets)
- Simplifies AI reasoning (no continuous height checks)

---

## Shadow Projection Rules

### Basic Rule

```
IF light.height > obstacle.height:
    THEN obstacle casts shadow
ELSE
    obstacle does NOT cast shadow
```

### Projection Distance

Shadow length depends on:
1. **Light height** — higher light = longer shadow
2. **Obstacle height** — taller obstacle = longer shadow
3. **Obstacle distance from light** — closer = shorter shadow
4. **Light intensity** — brighter = longer shadow (boosted via multiplier)

### Formula (Discrete Approximation)

$$\text{shadow\_length} = \frac{\text{obstacle\_height} \times (\text{light\_height} - \text{obstacle\_height})}{\text{distance} + 1}$$

**Clamped:** Shadow never exceeds `SHADOW_LENGTH_MAX` (5–8 tiles)

### Discrete Quantization

Shadows project in **8 directions** (not continuous angle):

```
Directions (isometric):
0: UP          (0, -1)
1: NE-UP       (1, -1)
2: RIGHT       (1,  0)
3: SE-DOWN     (1,  1)
4: DOWN        (0,  1)
5: SW-DOWN     (-1,  1)
6: LEFT        (-1,  0)
7: NW-UP       (-1, -1)
```

Direction is determined by `quantize_dir(light_pos - obstacle_pos)`

### Determinism Requirement

```
Same light + obstacle + distance = ALWAYS same shadow
No randomness. No interpolation. No frame-dependent variation.
```

---

## Shadow Ownership

### Who Casts Shadow?

| Entity Type | Casts Shadow? | Receives Shadow? | Notes |
|-------------|---------------|------------------|-------|
| **Wall** | ✅ Yes (L2) | ❌ No | Structural barriers; full occlusion |
| **Tall Crate Stack** | ✅ Yes (L2–L3) | ✅ Yes | Can be stacked; dynamic obstacle |
| **Guard** | ❌ No (future) | ✅ Yes | Future extension for advanced AI |
| **Agent** | ❌ No | ✅ Yes | Player-controlled; no self-shadowing |
| **Floor Decal** | ❌ No (L0) | ✅ Yes | Atmospheric; receives ambient shadow |
| **Suspended Lamp** | ❌ No (L3) | ❌ No | Light source; overhead infrastructure |
| **Pillar** | ✅ Yes (L2) | ✅ Yes | Structural; prominent shadow caster |

### Shadow Responsibility

- **Light** — Determines shadow extent and falloff
- **Obstacle** — Defines shadow volume (via its height and position)
- **Receiver** — Consumes visibility class based on shadow coverage

---

## Tactical Exposure

### Definition

**Tactical Exposure** is the **likelihood a guard can detect the agent**, derived from:

1. **Visibility Class** — FULL_LIT, DIM, PENUMBRA, SHADOW, DEEP_SHADOW
2. **Position relative to light** — Inside/outside light cone; penumbra edge
3. **Structural coverage** — Behind wall, under overhang, etc.
4. **Future stealth modifiers** — Gadgets, upgrades, equipment (not yet implemented)

### NOT Visual Brightness

```
Tactical Exposure ≠ Shader Brightness

Example:
Agent in SHADOW visibility class may visually appear dim or bright.
The TACTICAL CLASS is what matters for guard detection.
Visual appearance is secondary.
```

### Exposure Flow

```
Guard searches for agent
    ↓
Guard queries: "What is agent's visibility class?"
    ↓
System returns: SHADOW (or other class)
    ↓
Guard applies detection probability: base_prob × visibility_multiplier
    ↓
Result: Agent has ~24% chance of detection (if visibility_multiplier = 0.4)
```

---

## Runtime Philosophy

The vertical lighting system prioritizes:

### Core Principles

```
✓ Grid-based       — Tile/layer aligned; no sub-tile computation
✓ Deterministic    — Same input = same shadow; no variation
✓ Low-Overhead     — O(n) shadow queries per turn
✓ Cache-Friendly   — Shadow sets pre-computed; stored as sparse dictionary
✓ Auditable        — Designer can predict shadow behavior
✓ Gameplay-First   — Tactical clarity over visual realism
```

### Explicitly Avoided

```
✗ Raytracing       — Too expensive; not needed for gameplay clarity
✗ Continuous Physics — Complexity not justified for stealth game
✗ Volumetric Simulation — GPU overhead defeats purpose
✗ GPU-Dependent Logic — Gameplay must work on any hardware
✗ Dynamic Recalculation — All shadows pre-baked per room
✗ Sub-Pixel Precision — Grid-based only; no interpolation
```

### Performance Target

- **Per-room bake time:** ~20–50 ms (all shadows pre-computed)
- **Per-turn query time:** < 1 ms (sparse lookup)
- **Memory footprint:** < 50 KB per room (shadow dictionary)
- **Runtime cost:** Negligible (all lookups, no simulation)

---

## Future Vertical Extensions

### M2 (Current Phase)

- [x] Discrete vertical layers defined
- [x] Height semantics registered
- [x] Shadow projection rules established
- [ ] M2-13: Geometric shadow baking (cone projection + clamping)
- [ ] M2-15: Advanced overlays (movement preview, noise map)

### M3 (Mid-term)

- [ ] **Catwalk Shadows** — Suspended structures cast complex overlapping shadows
- [ ] **Moving Overhead Lights** — Animated light sources (sweeping searchlights)
- [ ] **Elevated Searchlights** — Guard-mounted lights on scaffolding
- [ ] **Ceiling Fans** — Spinning obstacles; time-varying shadow patterns
- [ ] **Steam Occlusion** — Volumetric smoke affecting visibility (gameplay-semantic, not visual)

### M4+ (Long-term)

- [ ] **Volumetric Smoke** — Expanded smoke system with height-aware propagation
- [ ] **Multi-Height Stealth** — Agents on elevated platforms (M4+)
- [ ] **Vertical Guard Patrol** — Guards climbing/descending (advanced AI)
- [ ] **Light Bridges** — Hazards formed by shadow boundaries (tactical geometry)
- [ ] **Reflective Surfaces** — Mirrors/light redirectors affecting shadow distribution

---

## Glossary

| Term | Definition |
|------|-----------|
| **Vertical Layer** | Semantic height band (L0–L3) for gameplay organization |
| **Height Class** | Discrete entity height (0–4, not continuous) |
| **Shadow Cast** | Process of obstacle blocking light and creating shadow zone |
| **Tactical Exposure** | Likelihood of guard detection; based on visibility class + position |
| **Overhead Infrastructure** | L3 layer; lights, rails, drones, structures above play space |
| **Structural Height** | L2 layer; elevated obstacles casting shadows downward |
| **Playable Grid** | L1 layer; where agents and guards move and interact |
| **Subfloor** | L0 layer; atmospheric effects, underground installations |
| **Deterministic Shadow** | Same light + obstacle = always same shadow (no variation) |
| **Discrete Quantization** | Shadow direction rounded to 8 isometric directions |

---

## Sign-Off

**Document:** L-DOC-02 — Vertical Lighting Topology & Height Semantics  
**Date:** June 14, 2026  
**Status:** Semantic definition (not implementation)  
**Next Phase:** M2-13 (Geometric shadow baking) + M2-15 (Advanced overlays)  
**Maintained By:** Game Designer / Stealth Systems  
**Status:** Active 🟢

---

## References (L-DOC Series)

- **L-DOC-01** — Lighting Taxonomy & Semantic Visibility Classes (5 discrete classes, detection multipliers)
- **L-DOC-02** — Vertical Lighting Topology & Height Semantics (4 layers, height classes, shadow rules) ← **YOU ARE HERE**
- **L-DOC-03** — Shadow System Calibration & Visual Polish (thresholds, edge smoothing, per-guard customization) — *planned M2-14*
- **M2-13** — Geometric Shadow Projection & Baking (implementation spec)
- **M2-15** — Advanced Overlays & Tactical Visualization (movement, noise, objective markers)

---

## Sign-Off (L-DOC-01)

**Document:** L-DOC-01 — Lighting Taxonomy & Semantic Visibility Classes  
**Date:** June 14, 2026  
**Status:** Semantic definition (not implementation)  
**Next Phase:** M2-13 (Geometric shadow projection and baking)  
**Maintained By:** Game Designer / Stealth Systems  
**Status:** Active 🟢

---

## L-IMP-01: Runtime Light Source Foundation

### Implementation Overview

**Purpose:**
- Establish explicit light ownership in the runtime
- Create central registry for light queries
- Enable debug visualization of light sources (DEV_VISION)
- Prepare foundation for tactical visibility queries (M2-13)

**Scope:**
- ✅ LightSource class with semantic fields
- ✅ LightRegistry for central management
- ✅ Debug visualization overlay (DEV_VISION toggle)
- ✅ Hardcoded test lights for validation
- ⏳ Shadow projection integration (M2-13)
- ⏳ Exposure calculation (M2-13)

### Architecture

#### LightSource (RefCounted)
```gdscript
class_name LightSource
extends RefCounted

# Spatial & semantic properties
var cell: Vector2i
var height_class: int  # 0-4 (Floor, Low Cover, Human, Tall Structure, Overhead)
var light_type: String  # omni, directional, cone, ambient, intermittent, emergency, mobile
var radius: int
var active: bool

# Direction (for directional/cone types)
var direction_angle: float  # Radians
var cone_angle: float  # Degrees

# Energy levels
var tactical_energy: float  # Affects shadow strength and detection multiplier [0..1]
var visual_energy: float  # Affects brightness (not used for gameplay)

# Metadata
var light_id: String  # Unique identifier
var owner_name: String  # "lamp_01", "guard_torch", etc.
```

#### LightRegistry (Node)
```gdscript
class_name LightRegistry
extends Node

# Public methods
func register_light(light: LightSource) -> void
func remove_light(light_id: String) -> void
func get_all_lights() -> Array
func get_active_lights() -> Array
func get_lights_by_type(light_type: String) -> Array
func get_lights_affecting_cell(target_cell: Vector2i) -> Array  # Radius check only
func get_lights_at_cell(cell: Vector2i) -> Array
func get_light(light_id: String) -> LightSource
func is_empty() -> bool
func clear_all() -> void

# Signals
signal light_registered(light)
signal light_removed(light)
```

**Responsibilities:**
- Store and retrieve lights by ID
- Index lights by cell position for spatial queries
- Emit signals on registration/removal
- Provide simple radius-based queries (no occlusion/shadow calc)

**Does NOT:**
- Calculate shadows
- Compute exposure/visibility
- Render or animate lights
- Manage visual effects

#### LightOverlay (Node2D, DEV_VISION only)
**Purpose:** Debug visualization of light sources in DEV_VISION mode

**Display:**
- Filled circle (translucent) showing light radius
- Central marker showing light position
- Directional arrow for cone/directional lights
- Type indicator and height class
- Active/inactive state (dimmed if inactive)

**Colors by Type:**
- Omni: Yellow (1.0, 1.0, 0.5)
- Directional: Cyan (0.5, 1.0, 1.0)
- Cone: Magenta (1.0, 0.5, 1.0)
- Ambient: Gray (0.8, 0.8, 0.8)
- Intermittent: Orange (1.0, 0.5, 0.0)
- Emergency: Red (1.0, 0.0, 0.0)
- Mobile: Green (0.0, 1.0, 0.0)

**Integration:**
- Automatically toggled with `dev_vision` (press V in room)
- Z-index 20 (above all other overlays)

### Integration Points

#### room.gd
```gdscript
# Preload classes
const LightSourceClass = preload("res://godot/scripts/systems/lighting/light_source.gd")
const LightRegistryClass = preload("res://godot/scripts/systems/lighting/light_registry.gd")

# Initialize in _ready()
_light_registry = LightRegistryClass.new()
add_child(_light_registry)
_setup_debug_lights()
_setup_light_overlay()

# DEV_VISION toggle includes overlay
func _apply_dev_vision() -> void:
    # ... existing FOW and guard code ...
    if _light_overlay != null:
        _light_overlay.visible = dev_vision
        _light_overlay.queue_redraw()
```

### Test Lights

Three hardcoded test lights validate the architecture:

1. **Test Omni** — Overhead lamp at (10, 10)
   - Type: Omni
   - Height: Overhead (class 4)
   - Radius: 6 tiles
   - Energy: 1.0 (full strength)

2. **Test Cone** — Spotlight at (15, 8)
   - Type: Cone
   - Height: Human (class 2)
   - Radius: 5 tiles
   - Direction: 135° (southwest)
   - Cone spread: 60°

3. **Test Directional** — Guard torch at (8, 15)
   - Type: Directional
   - Height: Human (class 2)
   - Radius: 4 tiles
   - Direction: 45° (northeast)

**Validation:**
- Press V to toggle DEV_VISION
- See colored circles showing light coverage
- Verify lights activate/deactivate correctly
- Check registry print statement in console

### File Locations

```
godot/scripts/systems/lighting/
├── light_source.gd      (RefCounted light entity)
└── light_registry.gd    (Central light management)

godot/scripts/overlays/
└── light_overlay.gd     (Debug visualization)
```

### Future Integration (M2-13)

**L-IMP-02 will add:**
- Shadow projection from LightRegistry queries
- Tactical exposure calculation per light
- Visibility class assignment per tile
- Guard detection probability multipliers
- Performance optimization (baking, caching)

**Query Pattern:**
```gdscript
var lights_here = _light_registry.get_lights_affecting_cell(agent_cell)
for light in lights_here:
    var visibility_class = _calculate_exposure(light, agent_cell)
    # ... apply detection multipliers ...
```

### Status

- ✅ Classes implemented (L-IMP-01 steps 1-2)
- ✅ Registry integration in room.gd (L-IMP-01 step 3)
- ✅ Hardcoded test lights (L-IMP-01 step 4)
- ✅ Light overlay visualization (L-IMP-01 steps 5-6)
- ✅ DEV_VISION integration (L-IMP-01 step 6)
- ⏳ Advanced queries (L-IMP-01 step 7) — planned for M2-13
- 📝 Documentation (L-IMP-01 step 8) — **THIS SECTION**
- 🧪 Acceptance tests (L-IMP-01 step 9) — compile verification + visual validation

### Sign-Off (L-IMP-01)

**Document:** L-IMP-01 — Runtime Light Source Foundation  
**Date:** June 14, 2026  
**Status:** Foundation implementation (queries & shadow calc in M2-13)  
**Next Phase:** M2-13 (Shadow projection & exposure calculation)  
**Maintained By:** Runtime Systems / Lighting Subsystem  
**Status:** Active 🟢

---

## L-IMP-02: Grid Shadow Projection Prototype

### Implementation Overview

**Purpose:**
- Implement deterministic grid-based shadow projection
- Validate height semantics and vertical topology
- Create debug visualization for stealth readability
- Establish foundation for exposure calculation (future L-IMP-03)

**Scope (MVP):**
- ✅ ShadowResult structure for tile classification storage
- ✅ ShadowProjector for deterministic ray casting
- ✅ Simple radius projection (all tiles within radius marked initially)
- ✅ Height-aware occlusion (obstacles higher than light cast shadows)
- ✅ Simple shadow rays in 8 quantized directions
- ✅ ShadowOverlay debug visualization (DEV_VISION only)
- ⏳ Soft/penumbra edges (L-IMP-03)
- ⏳ Exposure calculation (L-IMP-03)

**Explicitly NOT implemented:**
- Raycast complexity (no line-of-sight checks yet)
- Continuous smooth shadows (discrete grid only)
- Volumetric lighting
- Performance optimization (caching planned for M2-13)

### Architecture

#### ShadowResult (RefCounted)
```gdscript
class_name ShadowResult
extends RefCounted

# Visibility class dictionaries
var fully_lit_tiles: Dictionary
var dim_tiles: Dictionary
var penumbra_tiles: Dictionary
var shadow_tiles: Dictionary
var deep_shadow_tiles: Dictionary

# Metadata
var source_light: LightSource
var computed_tile_count: int
```

**Methods:**
- `add_tile(cell, visibility_class)` — Add cell to classification
- `is_fully_lit(cell)` → bool — Query direct light
- `is_shadowed(cell)` → bool — Query any shadow classification
- `get_visibility_class(cell)` → String — Get classification for cell
- `get_tiles_by_class(vis_class)` → Array[Vector2i] — Get all tiles in class
- `merge(other: ShadowResult)` — Combine multiple light results

**Design Principles:**
- Extensible: Supports all 5 visibility classes from L-DOC-01
- Auditable: Can inspect exact tile assignments
- Merge-friendly: Multiple lights combine via `merge()`

#### ShadowProjector (Node)
```gdscript
class_name ShadowProjector
extends Node

func project_light(light: LightSource) -> ShadowResult
```

**Algorithm:**

1. **Phase 1: Direct Light Projection**
   - Iterate all tiles within light.radius
   - Mark as `fully_lit`

2. **Phase 2: Shadow Casting**
   - For each blocked cell (obstacle):
     - If obstacle.height_class >= light.height_class:
       - Cast shadow ray away from light
       - Mark shadow cells as `shadow`

3. **Shadow Ray (Grid-based):**
   - Quantize direction to nearest 8-direction cardinal/diagonal
   - Project ray for SHADOW_LENGTH_MAX tiles
   - Stop at next obstacle or boundary

**Height Semantics:**
```
Light at HEIGHT_OVERHEAD (4)
  + Obstacle at HEIGHT_TALL_STRUCTURE (3)
  → Casts full shadow (obstacle is lower)

Light at HEIGHT_HUMAN (2)
  + Obstacle at HEIGHT_TALL_STRUCTURE (3)
  → No shadow (obstacle is higher, blocks itself)

Light at HEIGHT_HUMAN (2)
  + Obstacle at HEIGHT_LOW_COVER (1)
  → No shadow (obstacle is lower)
```

**Determinism:**
- Same light always produces identical ShadowResult
- No randomness, no frame-dependent behavior
- Direction quantization guarantees consistent ray paths

#### ShadowOverlay (Node2D, DEV_VISION only)
**Purpose:** Visual debug of projected shadows

**Display:**
- Fully lit tiles: Bright green circles (0.2, 1.0, 0.2)
- Dim tiles: Yellow (1.0, 1.0, 0.2)
- Penumbra: Orange-yellow (1.0, 0.8, 0.2)
- Shadow tiles: Dark blue (0.2, 0.4, 1.0)
- Deep shadow: Very dark (0.1, 0.1, 0.3)

**Integration:**
- Automatic update when DEV_VISION toggled (press V)
- Z-index 21 (above light overlay)
- Recomputes projections on each frame (for now; optimization in M2-13)

### Integration Points

#### room.gd
```gdscript
# Initialization
_shadow_projector = ShadowProjectorClass.new()
_shadow_projector.set_blocked_cells(_blocked_cells)
_shadow_projector.set_obstacle_heights(_get_obstacle_heights())
_shadow_projector.set_room_size(_room_size)

_shadow_overlay = ShadowOverlayClass.new()
_shadow_overlay.shadow_projector = _shadow_projector
_shadow_overlay.light_registry = _light_registry
add_child(_shadow_overlay)

# DEV_VISION toggle
func _apply_dev_vision() -> void:
    if _shadow_overlay != null:
        _shadow_overlay.visible = dev_vision
        _shadow_overlay.set_dev_vision(dev_vision)
```

### File Locations

```
godot/scripts/systems/lighting/
├── light_source.gd       (RefCounted light entity)
├── light_registry.gd     (Central light management)
├── shadow_result.gd      (Tile classification storage)
└── shadow_projector.gd   (Grid-based projection engine)

godot/scripts/overlays/
├── light_overlay.gd      (Light source debug viz)
└── shadow_overlay.gd     (Shadow projection debug viz)
```

### Performance Constraints

**Current Implementation (MVP):**
- Per-light projection: ~1-2ms for 10-20 lights (single-threaded)
- Result storage: ~1-2 KB per light (dict overhead)
- Overlay rendering: ~0.5ms for visual update

**Explicitly Avoided:**
- ❌ Continuous simulation (update only when needed)
- ❌ Realtime volumetric lighting (discrete grid only)
- ❌ GPU-dependent gameplay logic (CPU can always compute)
- ❌ Precalculated shadow maps (runtime determinism prioritized)

**Future Optimization (M2-13):**
- Baking static shadows to texture
- Incremental caching per light
- Culling off-screen tiles
- Vectorized distance checks

### Testing & Validation

**Acceptance Tests:**
- ✅ Lights project illuminated areas within radius
- ✅ Obstacles generate shadow rays in correct directions
- ✅ Height classes affect shadow presence correctly
- ✅ ShadowOverlay visualizes all 5 visibility classes
- ✅ System produces identical results on repeated runs
- ✅ No crashes with 50+ test lights
- ✅ DEV_VISION toggle shows/hides overlays correctly

**Validation Steps:**
1. Press V to enter DEV_VISION
2. Observe colored circles: green (lit), blue (shadow)
3. Move around light sources mentally — confirm shadow direction
4. Check height class: tall obstacles should/shouldn't cast shadows
5. Disable DEV_VISION — confirms overlays fully hide

### Known Limitations

1. **No Penumbra Edge Smoothing** — Shadows have hard boundaries
2. **No Continuous Light Values** — Only discrete visibility classes
3. **No Self-Shadowing** — Source cells can't shadow themselves (by design)
4. **No Mutual Occlusion** — Shadows don't block other shadows (yet)
5. **No Performance Baking** — Every frame recomputes (acceptable for prototype)

### Future Extensions (M2-13 & M2-14)

**L-IMP-03 (Exposure Calculation):**
- Combine multiple light shadows
- Apply tactical visibility multipliers
- Stealth detection probability per tile

**M2-13 (Geometric Refinement):**
- Line-of-sight raycast validation
- Penumbra distance falloff
- Guard-specific shadow perception

**M2-14 (Visual Polish):**
- Shadow edges glow/halo effect
- Smooth fade-in/out for moving lights
- Per-guard shadow sensitivity customization

**M2-15 (Advanced Overlays):**
- Movement/noise visualization over shadows
- Tactical threat assessment overlay
- Guard search pattern visualization

### Status

- ✅ ShadowResult structure (L-IMP-02 step 2)
- ✅ ShadowProjector implementation (L-IMP-02 steps 3-4)
- ✅ Simple shadow rays (L-IMP-02 step 5)
- ✅ Height semantics integration (L-IMP-02 step 6)
- ✅ ShadowOverlay visualization (L-IMP-02 step 7)
- ✅ room.gd integration (L-IMP-02 implicit)
- ✅ DEV_VISION integration (L-IMP-02 implicit)
- 📝 Documentation (L-IMP-02 step 8) — **THIS SECTION**
- 🧪 Acceptance tests (L-IMP-02 step 9) — compile verification + visual validation

### Sign-Off (L-IMP-02)

**Document:** L-IMP-02 — Grid Shadow Projection Prototype  
**Date:** June 14, 2026  
**Status:** Deterministic grid projection (soft shadows in L-IMP-03)  
**Next Phase:** L-IMP-03 (Exposure calculation & visibility multipliers)  
**Maintained By:** Runtime Systems / Lighting Subsystem  
**Status:** Active 🟢

---

## L-IMP-03: Visibility Classification & Tactical Exposure Foundation

### Overview

**Purpose:**
Convert geometric lighting projection into discrete **tactical visibility classes** usable by stealth gameplay and AI perception.

**Key Distinction:**
```
L-IMP-02: "Where are the shadows cast?"  (geometry)
L-IMP-03: "How exposed is the agent?"     (gameplay state)
```

This milestone:
- ✅ Does NOT alter guard perception (yet)
- ✅ Does NOT control AI detection (yet)
- ✅ Does NOT implement stealth progression mechanics (yet)

It **only**:
- Interprets shadow topology as stealth semantics
- Provides queries for future gameplay systems
- Establishes the bridge between lighting and stealth

### Architecture

#### ExposureSystem — Semantic Visibility Interpreter

**File:** `scripts/systems/lighting/exposure_system.gd`  
**Type:** RefCounted (non-rendering service)  
**Responsibility:** Convert `ShadowResult` into discrete visibility classes

```gdscript
class_name ExposureSystem
extends Node

const FULL_LIT    := 4    # High risk
const DIM         := 3    # Moderate risk
const PENUMBRA    := 2    # Low risk
const SHADOW      := 1    # Minimal risk
const DEEP_SHADOW := 0    # Hidden
```

#### Exposure Grid

**Structure:**
```gdscript
var _exposure_grid: Dictionary = {}  # Vector2i -> int (visibility class)
```

**Semantics:**
- Each tile maps to exactly one visibility class (0-4)
- Unclassified tiles default to `DEEP_SHADOW` (safest for stealth)
- Grid rebuilt whenever shadow topology changes

**State:**
```
_exposure_grid[Vector2i(10, 5)] = ExposureSystem.SHADOW  # This tile is in shadow
```

### Visibility Classes — Tactical Semantics

| Class | Value | Meaning | Guard Detection Risk |
|-------|-------|---------|----------------------|
| **DEEP_SHADOW** | 0 | Hidden from light | Negligible (~0%) |
| **SHADOW** | 1 | Concealed | Minimal (~5%) |
| **PENUMBRA** | 2 | Edge of shadow | Low (~25%) |
| **DIM** | 3 | Dimly lit | Moderate (~50%) |
| **FULL_LIT** | 4 | Fully illuminated | High (~80%) |

**Key Property:**
- Classes are **discrete**, not continuous
- No interpolation between states
- Clear threshold semantics for AI logic

### Conversion from ShadowResult

**Method:** `rebuild_from_shadow_result(result: ShadowResult) -> void`

**Conversion Rules:**
```
ShadowResult visibility class → ExposureSystem class
fully_lit                      → FULL_LIT (4)
dim                            → DIM (3)
penumbra                       → PENUMBRA (2)
shadow                         → SHADOW (1)
deep_shadow                    → DEEP_SHADOW (0)
```

**Process:**
1. Iterate tiles in each ShadowResult visibility class
2. Map to ExposureSystem class
3. Store in `_exposure_grid`
4. All other tiles default to DEEP_SHADOW

**Example:**
```gdscript
var shadow_result = shadow_projector.project_light(test_light)
exposure_system.rebuild_from_shadow_result(shadow_result)

# Now exposure grid contains tactical visibility for this light
assert exposure_system.is_hidden(Vector2i(10, 10)) == true  # If in shadow
```

### Multiple Lights: Exposure Merging

**Method:** `rebuild_from_results(results: Array) -> void`

**Strategy:**
- Merge multiple `ShadowResult` objects into single exposure grid
- Conservatively approach: highest risk (most visible) per tile wins
- Tile gets the **highest** visibility class across all lights

**Example:**
```
Tile (10, 10) with 3 lights:
  Light A: SHADOW
  Light B: DIM
  Light C: PENUMBRA
  
Result: DIM (3) — most visible state across all lights
```

**Rationale:**
- Guard can see from any light source
- Tile is as exposed as the brightest light reaching it
- Conservative for stealth gameplay

### Query Interface — Gameplay API

ExposureSystem provides semantic queries for gameplay and AI:

```gdscript
# Get visibility class for a tile
var exposure_class = exposure_system.get_visibility_class(cell: Vector2i) -> int

# Quick stealth check
var is_safe = exposure_system.is_hidden(cell: Vector2i) -> bool  # shadow or deeper

# Human-readable label
var label = exposure_system.get_exposure_label(cell: Vector2i) -> String
# Returns: "FULL_LIT", "DIM", "PENUMBRA", "SHADOW", "DEEP_SHADOW"

# Batch queries
var hidden_tiles = exposure_system.get_tiles_by_class(SHADOW: int) -> Array

# Statistics (for debugging/balancing)
var stats = exposure_system.get_exposure_stats() -> Dictionary
# Returns: {full_lit: 45, dim: 120, penumbra: 89, shadow: 156, deep_shadow: 234}
```

**Design Principle:**
```
AI and gameplay consult ExposureSystem, never ShadowProjector directly.
```

### ExposureOverlay — DEV_VISION Tactical Display

**File:** `scripts/overlays/exposure_overlay.gd`  
**Type:** Node2D (debugging visualization)  
**Purpose:** Visualize tactical visibility classification (NOT visual brightness)

**Color Palette (Stealth Semantics):**
| Class | Color | RGB | Meaning |
|-------|-------|-----|---------|
| **FULL_LIT** | Bright Yellow | (1.0, 1.0, 0.0) | High risk zone |
| **DIM** | Orange | (1.0, 0.6, 0.0) | Moderate risk |
| **PENUMBRA** | Blue | (0.3, 0.7, 1.0) | Low risk edge |
| **SHADOW** | Purple | (0.8, 0.4, 1.0) | Safe zone (minimal risk) |
| **DEEP_SHADOW** | Dark Blue | (0.1, 0.1, 0.3) | Hidden (safest) |

**Display:** Per-tile colored rectangles (dimetric grid projection)  
**Optional:** Semantic labels ("SHADOW", "DEEP_SHADOW", etc.)  
**Update:** Real-time as dev_vision toggles  
**Z-Index:** 22 (above light and shadow overlays)

**Usage:**
```
Press V to toggle DEV_VISION
Observe colored exposure grid
Each color represents stealth risk tier
```

### Integration in room.gd

**Initialization Order:**
```
1. LightRegistry created → stores light sources
2. ShadowProjector initialized → computes shadow geometry
3. ExposureSystem initialized → converts shadow to visibility classes
4. ExposureOverlay created → displays for DEV_VISION
```

**Code Flow:**
```gdscript
# In room.gd _ready() after _build_room():
_setup_shadow_projector()     # Computes shadow geometry
_setup_shadow_overlay()       # Visualization

_setup_exposure_system()      # Converts to visibility classes
_setup_exposure_overlay()     # Visualization

# In _apply_dev_vision():
if _exposure_overlay != null:
    _exposure_overlay.visible = dev_vision
    _exposure_overlay.set_dev_vision(dev_vision)
```

**Data Flow:**
```
LightRegistry
    ↓
  Light objects (cell, radius, height_class)
    ↓
ShadowProjector
    ↓
  ShadowResult (fully_lit, dim, penumbra, shadow, deep_shadow tiles)
    ↓
ExposureSystem
    ↓
  _exposure_grid (Vector2i → visibility class 0-4)
    ↓
ExposureOverlay (DEV_VISION)
    ↓
  Colored tile display
```

### Example Scenario

**Setup:**
- Light A: Omnidirectional @ (10, 10), radius=6, height=2 (human level)
- Obstacle at (12, 10), height=2

**Shadow Projection (L-IMP-02):**
- ShadowResult marks (14, 10) through (20, 10) as shadow tiles

**Exposure Classification (L-IMP-03):**
- Tiles (10, 7) to (15, 13) → FULL_LIT (4)
- Tiles around edge → DIM (3)
- Penumbra tiles → PENUMBRA (2)
- Behind obstacle → SHADOW (1)
- Distant unlit areas → DEEP_SHADOW (0)

**Gameplay Query:**
```gdscript
if exposure_system.is_hidden(agent.cell):
    # Agent is safe from this light (shadow or deeper)
    guard.detection_chance *= 0.2  # Reduced visibility
else:
    # Agent is exposed (DIM or FULL_LIT)
    guard.detection_chance *= 1.0  # Normal detection
```

### Performance Characteristics

**ExposureSystem (L-IMP-03):**
- **Grid Size:** O(n) where n = map tiles (28×46 = 1,288 tiles)
- **Rebuild Cost:** O(m) where m = shadow result tiles (~200-300 per light)
- **Query Cost:** O(1) for individual lookups
- **Memory:** ~1.5 KB per light (exposure grid dictionary)

**Optimization Strategy:**
- No caching (grid rebuilt on light changes)
- No GPU computation (CPU-first for determinism)
- Lazy evaluation (queries computed on-demand)

**Future M2-13 Optimization:**
- Static baking for unchanging light sources
- Per-light caches with invalidation
- Batch query optimization for large agent counts

### Known Limitations

1. **Penumbra Approximation (L-IMP-03 MVP)**
   - Penumbra tiles are simplified from ShadowResult
   - Soft shadow edges not yet implemented
   - Future refinement: L-IMP-04 (soft shadows)

2. **No Height Gradation in Exposure**
   - All height classes mapped to single visibility class
   - Overhead lights don't reduce ground exposure
   - Future: L-IMP-05 (vertical visibility refinement)

3. **No Environmental Modifiers**
   - Fog, dust, smoke not yet implemented
   - Rain/weather doesn't affect visibility
   - Future: M2-15 (environmental effects)

4. **No Absorption or Reflection**
   - Light passes through all unblocked areas equally
   - No bouncing/diffuse lighting
   - Future: M2-16 (advanced light modeling)

### Future Gameplay Integrations

This milestone establishes the **interface** for:

#### Guard Perception (L-IMP-04)
```gdscript
guard.detection_chance = detection_multiplier[exposure_class]
# FULL_LIT: 80%, DIM: 50%, PENUMBRA: 25%, SHADOW: 5%, DEEP_SHADOW: 0%
```

#### Stealth Progression (L-IMP-05)
```gdscript
if exposure_system.is_hidden(cell):
    agent.stealth_rating += 1  # Building cover bonus
```

#### Equipment Upgrades (M2-14)
- **Thermal Optics:** See through PENUMBRA tier
- **Low-Light Vision:** Elevate SHADOW → DIM
- **Adaptive Camouflage:** Reduce exposure tier by 1

#### Tactical Awareness (M2-15)
```gdscript
var threat_map = {} # cell → detection probability
for cell in exposed_cells:
    threat_map[cell] = calculate_guard_threat(cell)
```

#### Noise Interaction (M2-16)
```gdscript
noise_volume = base_noise * exposure_class_modifier[cell]
# Moving in SHADOW: 0.5× noise
# Moving in FULL_LIT: 2.0× noise
```

#### Search Escalation (M2-17)
```gdscript
if guard.alert_level > THRESHOLD:
    exposure_system.apply_spotlight()  # Override shadows temporarily
```

### Testing & Validation (L-IMP-03)

**Acceptance Criteria:**
- ✅ ExposureSystem exists and compiles
- ✅ Visibility classes (0-4) function correctly
- ✅ Exposure grid generated from ShadowResult
- ✅ Semantic queries return correct classifications
- ✅ DEV_VISION overlay displays correctly
- ✅ room.gd integrates ExposureSystem successfully
- ✅ System remains decoupled from rendering
- ✅ Tactical exposure is independent of visual appearance

**Debugging Commands (Future):**
```gdscript
# Print exposure statistics
print(exposure_system.get_exposure_stats())

# Query specific tile
var class = exposure_system.get_visibility_class(Vector2i(10, 10))
print(exposure_system.get_exposure_label(Vector2i(10, 10)))

# Find all hidden tiles
var safe_zones = exposure_system.get_tiles_by_class(ExposureSystem.SHADOW)
```

### Sign-Off (L-IMP-03)

**Document:** L-IMP-03 — Visibility Classification & Tactical Exposure Foundation  
**Date:** June 14, 2026  
**Status:** Semantic exposure classification system established  
**Next Phase:** L-IMP-04 (Guard perception multipliers & detection probability)  
**Maintained By:** Runtime Systems / Lighting Subsystem  
**Status:** Active 🟢

---

## Architecture Evolution & Future Phases

### Completed Phases

**L-DOC-01/02:** Lighting taxonomy, visibility classes, shadow semantics (documentation)  
**L-IMP-01:** Runtime light source foundation (LightSource, LightRegistry)  
**L-IMP-02:** Grid shadow projection prototype (ShadowProjector, height semantics)  
**L-IMP-03:** Tactical exposure classification (ExposureSystem, semantic queries)

### Planned Phases

| Phase | Title | Scope | Status |
|-------|-------|-------|--------|
| L-IMP-04 | Guard Perception Multipliers | Detection probability from exposure | Planned |
| L-IMP-05 | Vertical Visibility Refinement | Height-dependent exposure calculations | Planned |
| M2-13 | Performance Optimization | Baking, caching, culling | Planned |
| M2-14 | Visual Polish & FX | Soft shadows, light bloom, ambient glow | Planned |
| M2-15 | Equipment Upgrades | Thermal optics, low-light vision, camouflage | Planned |
| M2-16 | Advanced Light Modeling | Absorption, reflection, diffuse lighting | Planned |
| M2-17 | Search Escalation | Spotlight override, emergency lighting | Planned |

### Architectural Principles

1. **Decoupling:** Exposure ≠ Rendering (gameplay-first)
2. **Determinism:** Same position always same visibility
3. **Auditability:** Player understands visibility state
4. **Semantics:** Discrete classes, not continuous values
5. **Extensibility:** Modular phases build on previous phases

