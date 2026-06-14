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

