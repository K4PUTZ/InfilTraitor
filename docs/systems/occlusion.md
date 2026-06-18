# INFILTRAITOR — Occlusion Semantics & Structural Blocking Model

> **Formal specification of how structures block light and line of sight. Establishes semantic foundation for occlusion before advanced stealth, ballistics, and AI integration.**

**Related Documents:**
- [Lighting System](lighting.md) — Tactical visibility and exposure
- [Lighting Runtime Pipeline](lighting_runtime_pipeline.md) — Official runtime flow (LIGHT-01)
- [Authoring Pipeline](../pipelines/lighting_authoring_pipeline.md) — Level design workflow (LIGHT-03)
- [Perception System](perception.md) — Guard vision and detection (future)

---

## Overview

Occlusion is the **semantic model of how structures interact with perception systems** (light, line of sight, sound, etc.). It is **not**:

```
❌ Physics simulation
❌ Ray tracing
❌ Material properties
❌ Renderer-specific
```

It is:

```
✓ Discrete semantic classification
✓ Gameplay-first design
✓ Auditable and deterministic
✓ Shared across multiple systems
```

### Core Principle

```
Occlusion is semantic, not physically simulated.

A structure is classified by how it behaves in gameplay,
not by its visual appearance or material composition.
```

### Design Philosophy

**Five Core Principles:**

1. **Deterministic** — Same structure always has same occlusion properties
2. **Grid-Based** — Occlusion is per-tile/per-cell, not continuous
3. **Gameplay-First** — Occlusion enables fun stealth, not realistic physics
4. **Auditable** — Designers understand why a structure blocks or passes
5. **Discrete** — 4 occlusion classes, not continuous spectrum

### Why Occlusion Matters

Occlusion determines:

- **Lighting:** How structures cast shadows and block light
- **Line of Sight (LOS):** How structures block vision cones
- **Sound Propagation:** Which walls muffle audio (future)
- **Ballistics:** Which structures stop bullets (future)
- **Stealth Mechanics:** What provides cover vs concealment
- **Level Design:** Playable space topology

---

## Occlusion Philosophy

### Semantic vs Physical Model

**Physical Model (NOT used):**
```
Material physics → Light propagation → Shadow calculation
```

**Semantic Model (USED):**
```
Structure type → Occlusion class → Behavioral impact
```

**Example: Glass Wall**

| Approach | Model | Result |
|----------|-------|--------|
| Physical | Fresnel + refraction + transparency | Continuous brightness gradient |
| Semantic | "Transparent" class | Light passes, LOS passes, but edge defined |

### Why Semantic?

1. **Auditability:** Designer says "this is TRANSPARENT" → everyone knows what happens
2. **Performance:** No ray tracing, no propagation, no simulation
3. **Control:** Game designer, not physics, decides what blocks
4. **Fairness:** Consistent rules for both player and AI
5. **Modding:** Clear rules enable custom content

### Accepted Limitations

```
✓ Shadows have hard edges (not soft/penumbra)
✓ Occlusion is all-or-nothing per-tile (not per-pixel)
✓ No light bleeding or caustics
✓ No refraction or absorption
✓ No volumetric fog rendering
✓ No dynamic shadow updates mid-frame
```

These are **intentional constraints** that enable clarity and performance.

---

## Occlusion Classes

Four discrete semantic classes define all structural blocking behavior:

### Class 1: SOLID

**Definition:** Completely blocks both light and line of sight

**Properties:**
- Light cannot pass through
- LOS completely blocked
- Shadow cast is full (100% shadow)
- Provides full cover AND concealment
- Examples: Stone wall, concrete, metal barrier

**Behavior:**
```
Light:     BLOCKED (100%)
LOS:       BLOCKED (100%)
Shadow:    FULL (0% exposure)
Cover:     Full
Stealth:   Excellent
```

**Gameplay Impact:**
- Agent cannot be seen through (structural concealment)
- Light cannot illuminate beyond (shadow barrier)
- Optimal for strongholds and safe zones
- Limits map connectivity

### Class 2: TRANSPARENT

**Definition:** Allows both light and line of sight to pass through

**Properties:**
- Light passes through (possibly attenuated)
- LOS unobstructed
- Shadow minimally affected
- Provides no cover
- Examples: Window, glass wall, chain fence (visually open)

**Behavior:**
```
Light:     PASSES (100%)
LOS:       PASSES (100%)
Shadow:    MINIMAL (90% normal exposure)
Cover:     None
Stealth:   Poor
```

**Gameplay Impact:**
- Agent can be seen through (no concealment)
- Light illuminates normally
- Offers no protection from detection
- Does not block line of fire (future ballistics)
- Useful for dramatic visibility (seeing into lit rooms)

### Class 3: DIFFUSE

**Definition:** Degrades both light and line of sight, but doesn't fully block

**Properties:**
- Light scattered and reduced
- LOS visible but obscured
- Shadow partial (intermediate depth)
- Reduces visibility range
- Examples: Smoke, steam, fog, frosted glass, curtains

**Behavior:**
```
Light:     REDUCED (50% penetration)
LOS:       REDUCED (50% clarity)
Shadow:    PARTIAL (50% normal exposure)
Cover:     Partial
Stealth:   Good
```

**Gameplay Impact:**
- Agent visible but blurred/indistinct
- Guard detection chance lowered (increased confidence distance)
- Light still illuminates but dimly
- Perfect for "smoke grenade" stealth mechanics
- Creates visual confusion for both player and guards

**Detection Modifier:**
```
detection_mult *= 0.6  # 40% reduction from normal
```

### Class 4: PERFORATED

**Definition:** Partially blocks both light and line of sight (discrete holes/gaps)

**Properties:**
- Light passes through gaps, fully blocked by structure
- LOS can peek through perforations
- Shadow striped/patterned
- Spatial resolution matters (gaps vs solid)
- Examples: Chain link fence, metal grating, slotted wall

**Behavior:**
```
Light:     PARTIAL (50% average, patterned)
LOS:       PARTIAL (50% visible through gaps)
Shadow:    STRIPED (alternating shadow/light bands)
Cover:     Yes (physical protection)
Stealth:   Moderate
```

**Gameplay Impact:**
- Agent partially visible (can see silhouette through gaps)
- Partial cover from shots (bullets blocked by structure)
- Light creates striped shadow pattern
- Useful for industrial settings, prisons, observation areas

**Detection Modifier:**
```
detection_mult *= 0.7  # 30% reduction from normal
```

### Class Matrix

| Class | Light | LOS | Concealment | Cover | Use Case |
|-------|-------|-----|-------------|-------|----------|
| **SOLID** | ❌ Blocked | ❌ Blocked | Excellent | Full | Walls, bunkers |
| **TRANSPARENT** | ✓ Pass | ✓ Pass | None | None | Windows, open space |
| **DIFFUSE** | ⚠ Reduced | ⚠ Reduced | Good | Partial | Smoke, fog, steam |
| **PERFORATED** | ⚠ Partial | ⚠ Partial | Moderate | Yes | Fences, gratings |

---

## Structural Semantics

Mapping real structures to occlusion classes:

### By Material/Environment

| Structure | Class | Reasoning | Light | LOS |
|-----------|-------|-----------|-------|-----|
| Concrete wall | SOLID | Impenetrable | ❌ | ❌ |
| Stone pillar | SOLID | Structural support | ❌ | ❌ |
| Metal door | SOLID | Sealed barrier | ❌ | ❌ |
| Glass window | TRANSPARENT | Clear view through | ✓ | ✓ |
| Chain fence | PERFORATED | Gaps between links | ⚠ | ⚠ |
| Metal grating | PERFORATED | Structured holes | ⚠ | ⚠ |
| Curtain/fabric | DIFFUSE | Disperses light | ⚠ | ⚠ |
| Smoke cloud | DIFFUSE | Visual obscuration | ⚠ | ⚠ |
| Steam vent | DIFFUSE | Opacity/blur | ⚠ | ⚠ |
| Fog patch | DIFFUSE | Environmental obscuration | ⚠ | ⚠ |

### By Function

| Function | Class | Examples | Gameplay |
|----------|-------|----------|----------|
| **Vault Protection** | SOLID | Bunker, sealed room | Maximum security |
| **View Preservation** | TRANSPARENT | Window, observation point | Dramatic sight lines |
| **Environmental Stealth** | DIFFUSE | Smoke, steam, fog | Temporal concealment |
| **Partial Protection** | PERFORATED | Fence, grating | Industrial aesthetic |

### By Stealth Role

| Role | Class | Strategy | Detection |
|------|-------|----------|-----------|
| **Safe Zone** | SOLID | Hide completely | 0% visibility |
| **Dangerous Open** | TRANSPARENT | Never hide here | 100% visibility |
| **Stealth Window** | DIFFUSE | Time-based concealment | 50% reduced |
| **Physical Cover** | PERFORATED | Duck behind | Blocked shots, partial hide |

---

## Light & LOS Interaction

### How Occlusion Classes Affect Light

#### SOLID Occlusion

```
Light Source at (10, 10)
Solid wall between (15, 10) and light

Shadow projection:
┌──────────┐
│ LIGHT    │
└────┬─────┘    Shadow ray:
     │          (10,10) → (15,10) → cast ray beyond
  ┌──────┐
  │SOLID │  ← blocks ray
  └──────┘
     ↓
  No light beyond
  Result: DEEP_SHADOW on far side
```

**Implementation:**
```gdscript
func _project_shadows(light, result) -> void:
    for blocked_cell in blocked_cells.keys():
        var occlusion_class = get_occlusion_class(blocked_cell)
        
        if occlusion_class == OCCLUSION_SOLID:
            # Full shadow cast
            _cast_shadow_ray(light, blocked_cell, result)
        elif occlusion_class == OCCLUSION_PERFORATED:
            # Partial shadow (striped pattern)
            _cast_partial_shadow_ray(light, blocked_cell, result)
        elif occlusion_class == OCCLUSION_DIFFUSE:
            # Reduced shadow (partially penetrates)
            _cast_diffuse_shadow_ray(light, blocked_cell, result)
        # TRANSPARENT: no shadow cast
```

#### TRANSPARENT Occlusion

```
Light passes through glass as if structure didn't exist

Light Source  Glass  Behind Glass
    ◉  ━━━━  ◉
           ↓
    Normal light projection
    (transparency ignored)
```

**Behavior:** Structure is invisible to shadow calculation

#### DIFFUSE Occlusion

```
Light scattered through diffuse material

Light Source
    ◉
     \
      \  ← scattered rays
    ┌──────┐
    │DIFFUSE  │  ← smoke, steam
    └──────┘
       ↓
    Reduced light (50% penetration)
    + partial shadow (gradient)
```

**Behavior:** Light passes but attenuated, creates soft shadow

#### PERFORATED Occlusion

```
Light passes through gaps, blocked by structure

Light Source
    ◉
  ↙ ↓ ↘  ← rays through gaps
┌─ ─ ─┐
│█ █ █│  ← solid bars block rays
│ █ █ │
└─ ─ ─┘
    ↓
Striped shadow pattern
(alternating shadow/light)
```

**Behavior:** Structured shadow (gaps = light, bars = shadow)

### How Occlusion Classes Affect LOS

#### SOLID Occlusion (Vision Blocked)

```
Guard at (5, 5)
Solid wall between (10, 5) and guard

Vision cone:
    👁━━●━━━━●
         ↓
      │ SOLID │  ← blocks vision
      │       │
      └───────┘
         ↓
Agent at (15, 5): NOT VISIBLE

Guard cannot see through solid wall.
```

#### TRANSPARENT Occlusion (Vision Passes)

```
Guard at (5, 5)
Glass window at (10, 5)

Vision cone:
    👁━━●━━━━●
       ║ glass ║
       ║       ║
       └───────┘
           ↓
Agent at (15, 5): VISIBLE

Guard sees through glass as if it wasn't there.
(Window doesn't degrade detection in current system)
```

#### DIFFUSE Occlusion (Vision Reduced)

```
Guard at (5, 5)
Smoke cloud at (10, 5)

Vision cone:
    👁━━●━━━ ░ ░ ░
       │smoke│
       │░░░░░│
       └─────┘
           ↓
Agent at (15, 5): BARELY VISIBLE

Smoke reduces visibility range or detection confidence.
Guard has reduced detection chance through diffuse material.
```

#### PERFORATED Occlusion (Vision Partial)

```
Guard at (5, 5)
Chain fence at (10, 5)

Vision cone:
    👁━━●━━━●
      │█ █ █│
      │ █ █ │  ← fence gaps
      └─────┘
           ↓
Agent at (15, 5): PARTIALLY VISIBLE

Guard can see through gaps but structure blocks some view.
Partial cover from detection (reduced but not blocked).
```

---

## Interaction Matrix: Occlusion Across Systems

### System Usage Patterns

| System | Light | LOS | Sound (Future) | Ballistics (Future) | Occlusion Class |
|--------|-------|-----|----------------|-------------------|-----------------|
| **Lighting System** | ✓ Full | — | — | — | SOLID, DIFFUSE, PERFORATED |
| **Vision/Perception** | ✓ LOS | ✓ Full | — | — | SOLID, DIFFUSE, PERFORATED |
| **Sound Propagation** (Future) | — | — | ✓ Medium | — | SOLID (blocks), DIFFUSE (reduces) |
| **Ballistics** (Future) | — | — | — | ✓ Full | SOLID (blocks), PERFORATED (partial) |
| **Environmental** | ✓ Diffuse | ✓ Diffuse | ✓ Diffuse | — | DIFFUSE only |

### Key Interactions

#### Lighting × LOS Alignment

Both use same occlusion classes for consistency:

```
SOLID wall:
- Blocks light ✓
- Blocks LOS ✓
- Consistent system-wide

DIFFUSE smoke:
- Reduces light ✓
- Reduces LOS ✓
- Consistent system-wide

PERFORATED fence:
- Partial light ✓
- Partial LOS ✓
- Consistent system-wide
```

#### Shared Occlusion Database

All systems reference same occlusion data:

```gdscript
# Central occlusion registry (singleton)
var _occlusion_grid: Dictionary = {}  # Vector2i → occlusion_class

# All systems query same database
shadow_projector.uses(_occlusion_grid)
los_system.uses(_occlusion_grid)  # (future)
audio_system.uses(_occlusion_grid)  # (future)
ballistics.uses(_occlusion_grid)  # (future)
```

---

## Partial Visibility & Degradation

### Degradation Model

Instead of binary blocking, occlusion **degrades** perception:

```
SOLID:       0% visible (complete block)
PERFORATED:  50% visible (partial)
DIFFUSE:     50% visible (reduced clarity)
TRANSPARENT: 100% visible (no degradation)
```

### Diffuse Materials (Smoke, Fog, Steam)

Diffuse materials reduce detection chance:

```gdscript
detection_multiplier = base_mult * degradation_factor

# DIFFUSE example (smoke):
detection_mult_in_smoke = 0.50  # 50% of normal

# Interpretation:
- 0.5 * 1.0 (FULL_LIT)   = 0.5 (equivalent to DIM in open)
- 0.5 * 0.1 (DEEP_SHADOW) = 0.05 (enhanced concealment)
```

### Perforated Materials (Fences, Gratings)

Perforated materials provide **physical cover** + **visual obstruction**:

```gdscript
# Ballistics (future): Agent protected
can_be_shot = false  # Behind fence structure

# Vision (current): Agent partially visible
detection_mult = 0.70  # 30% reduction

# LOS: Can see through but obscured
visible_but_obscured = true
```

### Applications

**Smoke Stealth:**
```
Agent + enemy in smoke:
- Player sees: Blurred silhouette
- Detection: 50% reduced chance
- Escape: Can move undetected if distance sufficient
```

**Fence Cover:**
```
Agent behind fence:
- Player sees: Agent in gaps
- Bullets: Blocked by fence (future)
- Stealth: Difficult but possible if timely

Guard sees:
- Agent visible but partially obscured
- 30% harder to detect
- Must account for fence gaps
```

**Steam Vents:**
```
Agent in steam plume:
- Temporary concealment
- Exposure confidence low (unreliable)
- Guard confused but suspicious
- Perfect for timed movement
```

---

## Structural Categories by Gameplay Role

### Combat-Focused Structures

| Structure | Class | Role |
|-----------|-------|------|
| Sandbag wall | SOLID | Full cover + concealment |
| Concrete barrier | SOLID | Full cover + concealment |
| Heavy machinery | SOLID | Partial cover (specific angles) |

**Gameplay:** Block both shots and detection

### Environmental Structures

| Structure | Class | Role |
|-----------|-------|------|
| Guard rail | PERFORATED | Decorative (little protection) |
| Chain link fence | PERFORATED | Functional fence (stops movement) |
| Metal grating | PERFORATED | Industrial (partial cover) |

**Gameplay:** Modulate visibility without complete blocking

### Dynamic/Ephemeral Structures

| Structure | Class | Role |
|-----------|-------|------|
| Smoke cloud | DIFFUSE | Temporary concealment |
| Steam vent | DIFFUSE | Environmental effect |
| Fog patch | DIFFUSE | Atmospheric hazard |

**Gameplay:** Time-limited stealth opportunities

### Architectural Elements

| Structure | Class | Role |
|-----------|-------|------|
| Window | TRANSPARENT | Dramatic visibility |
| Glass wall | TRANSPARENT | Scenic overlook |
| Reinforced door | SOLID | Narrative barrier |

**Gameplay:** Scene composition and pacing

---

## Future Dynamic Occlusion (LIGHT-03+)

Prepared for future implementation:

### Dynamic Occlusion Sources

| Source | Class | Behavior | Trigger |
|--------|-------|----------|---------|
| **Moving Smoke** | DIFFUSE | Drifts across level | Physics simulation |
| **Steam Vents** | DIFFUSE | Periodic activation | Timer |
| **Temporary Barriers** | SOLID | Deployed then removed | Event trigger |
| **Destructible Walls** | SOLID → TRANSPARENT | Structure destroyed | Damage/explosion |
| **Dynamic Blackout** | SOLID (all lights) | Power failure | Alarm event |
| **Crowd Coverage** | DIFFUSE | NPC density creates fog | Population event |

### Implementation Hooks (Prepared)

```gdscript
# Future: Dynamic occlusion updates
func update_dynamic_occlusion(delta: float) -> void:
    # Move smoke plumes
    for smoke in _active_smoke_clouds:
        smoke.position += smoke.velocity * delta
        _update_occlusion_grid_for_cell(smoke.position)
    
    # Update destructible state
    for wall in _destructible_walls:
        if wall.health <= 0:
            change_occlusion_class(wall.cell, OCCLUSION_TRANSPARENT)
    
    # Environmental effects
    for vent in _steam_vents:
        if vent.is_active():
            apply_diffuse_occlusion(vent.emission_zone, 0.5)

# Trigger full rebuild
if occlusion_changed_this_frame:
    _rebuild_shadows_and_exposure()
```

### Future Gameplay Scenarios

**Smoke Manipulation:**
```
Scenario: Guard detects agent in open, agent deploys smoke grenade
- Smoke creates DIFFUSE occlusion zone
- Exposure confidence drops in smoke (unreliable)
- Guard loses clear detection opportunity
- Agent escapes through smoke cover
```

**Destructible Cover:**
```
Scenario: Guard shoots down wooden barrier
- Barrier transitions SOLID → TRANSPARENT
- Agent now fully exposed
- Must immediately relocate
```

**Power Failure:**
```
Scenario: All lights offline (alarm escalation)
- Every light becomes DIFFUSE or OCCLUDED
- Entire level darkens dramatically
- Subfloor hazards become active
- Ultimate escape window (10-30 sec)
```

---

## Occlusion Data Structure

### Per-Tile Occlusion Storage

```gdscript
# In room.gd or central manager
var _occlusion_grid: Dictionary = {}  # Vector2i → occlusion_class

const OCCLUSION_SOLID = "solid"          # Blocks light + LOS
const OCCLUSION_TRANSPARENT = "transparent"  # Passes light + LOS
const OCCLUSION_DIFFUSE = "diffuse"      # Reduces light + LOS
const OCCLUSION_PERFORATED = "perforated"  # Partial light + LOS

# Set occlusion for tile
func set_occlusion(cell: Vector2i, occlusion_class: String) -> void:
    _occlusion_grid[cell] = occlusion_class
    _mark_occlusion_dirty()

# Query occlusion
func get_occlusion_class(cell: Vector2i) -> String:
    if cell in _occlusion_grid:
        return _occlusion_grid[cell]
    return OCCLUSION_SOLID  # Default: assume solid
```

### Integration Points

**ShadowProjector reads occlusion:**
```gdscript
func _project_shadows(light, result) -> void:
    for blocked_cell in blocked_cells.keys():
        var occlusion = _occlusion_grid.get(blocked_cell, OCCLUSION_SOLID)
        
        match occlusion:
            OCCLUSION_SOLID:
                _cast_shadow_ray(light, blocked_cell, result)
            OCCLUSION_DIFFUSE:
                _cast_diffuse_shadow_ray(light, blocked_cell, result)
            OCCLUSION_PERFORATED:
                _cast_partial_shadow_ray(light, blocked_cell, result)
            # TRANSPARENT: no shadow
```

**LOS System reads occlusion (future):**
```gdscript
func can_see(from_pos, to_pos) -> bool:
    var line = get_line_of_sight(from_pos, to_pos)
    
    for cell in line:
        var occlusion = _occlusion_grid.get(cell, OCCLUSION_SOLID)
        
        if occlusion == OCCLUSION_SOLID:
            return false  # Vision completely blocked
        elif occlusion == OCCLUSION_DIFFUSE:
            return degraded_vision(from_pos, to_pos)  # Reduced
        # TRANSPARENT and PERFORATED pass through
    
    return true
```

---

## Acceptance Criteria (LIGHT-02)

- ✅ `occlusion.md` exists (this document)
- ✅ Occlusion classes defined (4 discrete types)
- ✅ Structural semantics documented (mapping structures to classes)
- ✅ Partial visibility explained (degradation model)
- ✅ Interaction matrix defined (occlusion across systems)
- ✅ Light × LOS interaction documented (how occlusion affects both)
- ✅ Dynamic occlusion prepared (hooks for future)
- ✅ System remains discrete and auditable (no continuous values)
- ✅ Integration points clear (data structures and API)
- ✅ Future extensions documented (smoke, destruction, blackout)

---

## Document Status

**Author:** Architecture / Occlusion & Level Design  
**Date:** 2026-06-14  
**Version:** 1.0 (LIGHT-02)  
**Status:** Complete 🟢

**Purpose:** Formalize occlusion semantics before advanced stealth, ballistics, and AI perception

**Next Steps:**
1. Reference this document in all occlusion-dependent systems
2. Implement occlusion grid storage (per-tile classification)
3. Integrate with ShadowProjector (currently uses binary blocking)
4. Prepare for LOS system (L-IMP-08+)
5. Prepare for ballistics system (future milestone)
6. Prepare for audio propagation (future milestone)

**Maintained By:** Architecture / Occlusion Semantics Lead  
**Review Cycle:** Before L-IMP-08 (LOS Integration), M2-15 (Ballistics)
