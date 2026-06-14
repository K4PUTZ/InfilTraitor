# INFILTRAITOR — Lighting Runtime Pipeline & Invalidation Architecture

> **Official specification of the lighting system runtime flow, ownership rules, and invalidation semantics. Stabilizes architecture before systemic integration and future AI extensions.**

**Related Documents:**
- [Lighting System](lighting.md) — Tactical visibility and exposure
- [Occlusion Semantics](occlusion.md) — Structural blocking model (L-ARCH-02)
- [Authoring Pipeline](../pipelines/lighting_authoring_pipeline.md) — Level design workflow (L-ARCH-03)
- [Perception System](perception.md) — Guard vision and detection (future)

---

## Overview

The lighting system has evolved through 7 implementation phases (L-IMP-01 through L-IMP-07), each adding features and complexity. This document formalizes the **official runtime pipeline**, ensuring:

- **Unidirectional data flow** (lighting → shadows → exposure → gameplay)
- **Clear ownership** (each system owns specific calculations)
- **Explicit invalidation rules** (when and why rebuilds happen)
- **Auditability** (developers understand system state at any point)
- **Extensibility** (future AI/equipment systems know exactly where to hook)

**Core Principle:**
```
Lighting data flows downward only.
No system should recalculate upstream data.
All queries are read-only from gameplay/AI perspective.
```

---

## Core Runtime Flow

### Official Pipeline Diagram

```
┌──────────────┐
│ LightSource  │  Spatial properties, type, energy, temporal effects
│   Registry   │  Active/inactive, temporal state updates
└────────┬─────┘
         │ lights_changed_this_frame
         ↓
┌──────────────────────┐
│ ShadowProjector      │  For each light:
│ project_light()      │    - Compute direct illumination
│ _project_direct()    │    - Cast shadow rays
│ _project_shadows()   │    - Generate ShadowResult
└────────┬─────────────┘
         │ Array[ShadowResult]
         ↓
┌──────────────────────┐
│ ExposureSystem       │  Merge shadow results:
│ rebuild_from_results │    - Map shadows → visibility classes
│ build_confidence()   │    - Calculate exposure confidence
│ set_stability()      │    - Classify shadow stability
└────────┬─────────────┘
         │ _exposure_grid populated
         │ _exposure_confidence set
         │ _shadow_stability set
         ↓
┌──────────────────────┐
│ Overlays refresh     │  Update visual representations:
│ _shadow_overlay      │    - Shadow overlay redraws
│ _exposure_overlay    │    - Exposure overlay redraws
│ _elite_overlay       │    - Elite overlay redraws
│ _temporal_overlay    │    - Temporal overlay redraws
└────────┬─────────────┘
         │ visual_dirty = false
         ↓
┌──────────────────────┐
│ Gameplay Queries     │  Stealth mechanics query:
│ ExposureSystem APIs  │    - get_visibility_class()
│ Guard perception     │    - get_detection_multiplier()
│ AI pathfinding       │    - get_shadow_stability()
│ etc.                 │    - get_exposure_confidence()
└──────────────────────┘
```

### Timing & Triggers

**Per Frame (_process in room.gd):**
1. Update temporal light states (flicker, pulse, rotate)
2. Identify lights that changed this frame
3. IF lights changed:
   - Rebuild shadows (ShadowProjector)
   - Rebuild exposure (ExposureSystem)
   - Refresh overlays
4. Execute gameplay queries (guards, pathfinding, etc.)
5. Render frame

**Pseudocode:**
```gdscript
func _process(delta: float) -> void:
    # Step 1: Temporal updates
    changed_lights = _light_registry.update_temporal_all(delta)
    
    # Step 2-3: Conditional rebuild
    if changed_lights.size() > 0:
        all_shadow_results = []
        for light in _light_registry.get_active_lights():
            shadow_result = _shadow_projector.project_light(light)
            all_shadow_results.append(shadow_result)
        
        _exposure_system.rebuild_from_results(all_shadow_results)
        _refresh_overlays()
    
    # Step 4: Gameplay
    _process_guard_perception()
    _process_ai_pathfinding()
    _update_vision_fog()
```

---

## Invalidation Sources & Rebuild Rules

### Event Categorization

| Event | Trigger | Rebuild | Scope | Cost |
|-------|---------|---------|-------|------|
| Light temporal state changes | Flicker/pulse/rotation | Shadow + Exposure | All active lights | Medium |
| Light position changes | Agent moves light | Shadow + Exposure | Affected light only | Low |
| Light toggles on/off | Boolean change | Shadow + Exposure | Affected light only | Low |
| Structural change | Wall placement/removal | Shadow + Exposure | Full room | High |
| Map load | Level initialization | Full rebuild | All lights | Very High |
| Alarm state change | Alert escalation | Exposure only | Zone-specific | Low |
| Overlay mode toggle | DEV_VISION changes | Overlay only | Visual layer | None |

### Detailed Invalidation Patterns

#### Invalidation: Light Temporal Change

**Trigger:**
- LightSource.flicker_enabled changes
- LightSource.pulse_enabled changes
- LightSource.rotation_speed changes
- OR: LightRegistry.update_temporal_all() detects changed_this_frame

**Action:**
```gdscript
# Mark light as changed
light.changed_this_frame = true

# Trigger rebuild
if changed_lights.size() > 0:
    _rebuild_all_shadows_and_exposure()
```

**Affected Systems:**
- ShadowProjector: Recomputes shadow for affected light
- ExposureSystem: Regenerates exposure grid
- Overlays: Shadow/exposure/temporal overlays redraw

**NOT Affected:**
- TileSemantics (structural data unchanged)
- LightRegistry (light registry unchanged)
- Height data (agent height unchanged)

#### Invalidation: Light Position Change

**Trigger:**
- LightSource.cell changes (manually moved)
- LightRegistry updates spatial index

**Action:**
```gdscript
var old_cell = light.cell
light.cell = new_cell
_rebuild_all_shadows_and_exposure()  # Full rebuild (conservative)
```

**Future Optimization:**
- Could compute only shadow delta (L-IMP-10+)
- Currently: full rebuild for simplicity

#### Invalidation: Structural Change

**Trigger:**
- blocked_cells dictionary modified
- New wall added/removed
- Agent places barricade

**Action:**
```gdscript
# Update structural data
_blocked_cells[new_wall] = true

# Trigger full rebuild
_shadow_projector.obstacle_heights = _recompute_obstacle_heights()
_rebuild_all_shadows_and_exposure()
```

**Affected Systems:**
- Everything downstream (highest cost)

#### Invalidation: Map Load

**Trigger:**
- _ready() initialization
- Level transition
- Checkpoint restore

**Action:**
```gdscript
func _ready() -> void:
    # ... standard initialization ...
    _light_registry.clear_all()
    _setup_lights()
    _setup_tile_semantics()
    _setup_height_overlay()
    _setup_temporal_overlay()
    _setup_elite_exposure_overlay()
    
    # Initial full rebuild
    _rebuild_all_shadows_and_exposure()
```

**Cost:** Very high, but happens once per level

#### Invalidation: Alarm State Change

**Trigger:**
- Guard alert escalation (SUSPICIOUS → ALERT)
- Emergency lights activate
- Alarm semantics change

**Action:**
```gdscript
# Only exposure rebuild needed
# (shadow topology unchanged, but confidence/stability may change)
_exposure_system.rebuild_from_results(all_shadow_results)
_exposure_overlay.queue_redraw()
```

**Why not shadow rebuild:**
- Shadow topology is deterministic (light position + structure)
- Alarm doesn't change light properties
- Only affects exposure interpretation

#### Invalidation: Overlay Toggle (DEV_VISION)

**Trigger:**
- User presses dev key
- dev_vision bool toggled

**Action:**
```gdscript
func _apply_dev_vision() -> void:
    if _shadow_overlay != null:
        _shadow_overlay.visible = dev_vision
    if _exposure_overlay != null:
        _exposure_overlay.visible = dev_vision
    if _elite_exposure_overlay != null:
        _elite_exposure_overlay.visible = dev_vision
    if _temporal_overlay != null:
        _temporal_overlay.visible = dev_vision
    
    # Note: NO rebuild triggered
```

**Cost:** Zero (visual only, no calculation)

---

## System Ownership & Responsibilities

### Ownership Matrix

| System | Owns | Responsible For | Query Rights | Modify Rights | Cache |
|--------|------|-----------------|---------------|---------------|-------|
| **LightSource** | Light properties | Emission, type, energy, temporal state | All | Registry only | Local (flicker_phase) |
| **LightRegistry** | Light collection | Registration, tracking, temporal updates | Queries only | Light activation/deactivation | Spatial index |
| **ShadowProjector** | Shadow topology | Ray casting, blocking, projection | Calls from room only | Never | ShadowResult (ephemeral) |
| **ExposureSystem** | Visibility mapping | Class assignment, confidence, stability | Gameplay/AI | Exposure rebuild only | _exposure_grid, _exposure_confidence, _shadow_stability |
| **ShadowOverlay** | Shadow visualization | Visual display of shadows | Read _exposure_grid | Visual only | Glyph cache |
| **ExposureOverlay** | Exposure visualization | Visual display of exposure | Read _exposure_grid | Visual only | Color cache |
| **EliteOverlay** | Advanced visualization | Depth/confidence/stability display | Read ExposureSystem | Visual only | Gradient cache |
| **TemporalOverlay** | Temporal visualization | Light state/energy display | Read LightRegistry | Visual only | State cache |
| **Future AI** | Movement decisions | Pathfinding, patrol routes | Read ExposureSystem | Never | Heuristic cache |

### Key Ownership Rules

#### Rule 1: Downward-Only Data Flow

```
Lighting data flows downward through the pipeline.
No system reads or writes data from systems downstream.

CORRECT:
- ShadowProjector reads LightRegistry ✓
- ExposureSystem reads ShadowProjector results ✓
- Gameplay reads ExposureSystem ✓

INCORRECT:
- Gameplay writes to ExposureSystem ✗
- Overlays rebuild ShadowProjector ✗
- AI modifies LightRegistry ✗
```

#### Rule 2: Each System Owns One Calculation

```
ShadowProjector        owns shadow topology (only place it's calculated)
ExposureSystem         owns exposure classes (only place it's calculated)
Overlays               own visualization (read from upstream)
Gameplay/AI            own queries (read from upstream)
```

#### Rule 3: No Circular Dependencies

```
Forbidden patterns:

LightRegistry → ShadowProjector → ExposureSystem → LightRegistry (CYCLE!)
Overlays → ShadowProjector → Overlays (CYCLE!)
AI → ExposureSystem → AI (CYCLE!)
```

#### Rule 4: Query vs Modification

```
Query Rights (allowed):
- Read _exposure_grid
- Call get_visibility_class()
- Call get_detection_multiplier()
- Call get_shadow_stability()

Modification Rights (NOT allowed for gameplay/AI):
- Never write to _exposure_grid
- Never call rebuild_from_results()
- Never modify light properties
```

---

## Rebuild Philosophy

### Current Approach: Global Rebuilds

**Status:** Correct for development phase
**Rationale:** Simplicity and auditability trump performance

**Philosophy:**
```
Correctness > Optimization
Auditability > Elegance
Understandability > Cleverness
```

### When Global Rebuilds Are Appropriate

1. **Early Development** — While architecture stabilizing ✓
2. **Correctness Verification** — When debugging ✓
3. **Auditing** — When understanding system behavior ✓
4. **Small Scope** — Room size < 100x100 tiles ✓

### When Global Rebuilds Are NOT Appropriate

1. **Production Performance** — Need 60 FPS consistency ✗
2. **Large Scope** — Room size > 200x200 tiles ✗
3. **Continuous Animation** — Many simultaneous lights ✗
4. **Streaming Worlds** — Infinite procedural levels ✗

### Accepted Limitations (Current Implementation)

```
❌ No incremental rebuild (yet)
❌ No shadow caching (yet)
❌ No spatial chunking (yet)
❌ No threading (yet)
❌ No GPU acceleration (yet)
```

These are all **planned for future optimization phases** (M2-13+), but would compromise clarity if attempted now.

### Correctness Over Optimization

**Example Decision:**

*Question: Can we cache shadow results?*

**Early Development Answer (NOW):**
- NO, because:
  - Light properties can change unpredictably
  - Temporal effects modify energy each frame
  - Caching logic would add complexity
  - Rebuild is fast enough for room sizes we test

**Production Answer (FUTURE):**
- YES, because:
  - Cache invalidation rules would be formalized
  - Performance requirements would force it
  - Complexity would be justified by speed

---

## Overlay Rules & Information Layers

### Overlay Hierarchy

```
Z-Index 0-19    Gameplay Layer (not part of lighting)
Z-Index 20      Light Overlay (L-IMP-01)
Z-Index 21      Shadow Overlay (L-IMP-02)
Z-Index 22      Exposure Overlay (L-IMP-03)
Z-Index 23      Tile Risk Overlay (L-IMP-04)
Z-Index 24      Height Overlay (L-IMP-05)
Z-Index 25      Temporal Overlay (L-IMP-06)
Z-Index 26      Elite Exposure Overlay (L-IMP-07)
Z-Index 27+     Future overlays (spectator, analysis, etc.)
```

### Overlay Classification

#### DEV Overlays (Visible in DEV_VISION only)

```
Purpose: Development, debugging, understanding

Allowed Characteristics:
- Heavy computation (not realtime-critical)
- Redundant information (multiple views of same data)
- Verbose labeling (maximum clarity)
- Experimental visualization (may change)

Examples:
- Shadow overlay (projects shadow data)
- Risk heatmap (visualizes detection risk)
- Elite overlay (shows confidence + stability)
- Temporal overlay (shows light animation state)

Cost: Acceptable (only visible when dev_vision enabled)
```

#### Runtime Overlays (Visible during normal gameplay)

```
Current: None (lighting is invisible to player)

Future Possibilities:
- Minimal HUD elements (equipment-dependent)
- Risk color coding (at high difficulty)
- Light source indicators (visibility only)

Constraints:
- Zero performance cost
- Cinematically clean
- Never distracting
- Optional (can be disabled)
```

### Overlay Update Rules

#### Rule 1: Overlays Never Trigger Rebuilds

```
CORRECT:
```gdscript
_exposure_overlay.visible = dev_vision
_exposure_overlay.queue_redraw()  # Visual update only
```

INCORRECT:
```gdscript
_exposure_overlay.visible = dev_vision
_exposure_system.rebuild_from_results(...)  # NO!
```
```

#### Rule 2: Overlays Read Downstream Data Only

```
CORRECT:
- Shadow overlay reads ShadowResult ✓
- Exposure overlay reads _exposure_grid ✓
- Elite overlay reads _exposure_confidence ✓

INCORRECT:
- Shadow overlay modifies lights ✗
- Exposure overlay rebuilds shadows ✗
- Elite overlay changes game state ✗
```

#### Rule 3: Multiple Overlays Can View Same Data

```
It's OK for multiple overlays to read the same data.
This is why ExposureSystem exposes everything:

- ExposureOverlay can read exposure classes
- EliteOverlay can read exposure + confidence + stability
- Future AI analysis can read same data

No coordination needed (all read-only).
```

---

## Future AI Hooks (L-IMP-09+)

### AI as Consumer, Not Owner

**Golden Rule:**
```
AI systems query exposure data.
AI systems never own lighting calculations.
AI systems never modify any lighting state.
```

### Proposed AI Integration Points

#### Hook 1: Guard Perception

**Current (L-IMP-04):**
```gdscript
# Exposure system provides multiplier
detection_mult = exposure_system.get_detection_multiplier(cell)
guard_detection_chance *= detection_mult
```

**Future (L-IMP-09):**
```gdscript
# AI uses advanced queries
shadow_depth = exposure_system.get_shadow_depth(cell)
confidence = exposure_system.get_exposure_confidence(cell)
stability = exposure_system.get_shadow_stability(cell)

# AI makes sophisticated decisions
if confidence > 0.8 and stability == "static":
    return SAFE_FOR_EXTENDED_HIDING
elif stability == "temporal":
    return REQUIRES_TIMING
else:
    return UNSAFE
```

#### Hook 2: Pathfinding

**Current:** Uses exposure risk as heuristic

**Future (L-IMP-09):**
```gdscript
# AI queries tactical information
structurally_hidden = exposure_system.get_structurally_hidden_tiles()
safe_corridors = exposure_system.get_tiles_by_stability("static")

# AI builds patrol routes avoiding exposure
path = find_path_through_shadows(start, goal, safe_corridors)
```

#### Hook 3: Search Behavior

**Current:** None (too early)

**Future (L-IMP-09+):**
```gdscript
# Alert escalation changes lighting interpretation
if alarm_level == ALERT_L3:
    exposure_confidence_multiplier *= 0.5  # Shadows less reliable
    
# AI searches more aggressively
search_risk_tolerance = 1.0 - (avg_exposure_confidence * 0.5)
```

#### Hook 4: Learning & Adaptation

**Future (L-IMP-10+):**
```gdscript
# AI learns guard sight lines from exposure topology
learned_safe_zones = extract_patterns_from_exposure_grid()

# AI adapts search strategy based on learned patterns
patrol_route = generate_route_avoiding_learned_patterns()
```

### AI Integration Constraints

| Constraint | Rationale |
|-----------|-----------|
| AI reads ExposureSystem only | Prevents AI from modifying game state |
| No retroactive changes | AI can't request shadow recalculation |
| No probability distributions | Must use discrete classes (auditability) |
| No machine learning inference | Keep semantics interpretable |
| No procedural generation | All behaviors must be determinstic |

### What AI Cannot Do

```
❌ Request shadow recalculation based on perceived threat
❌ Modify light properties to gain advantage
❌ Adjust exposure confidence for tactics
❌ Create new visibility classes
❌ Override detection multipliers
```

These are **intentional guardrails** to maintain system integrity and gameplay fairness.

---

## Performance Constraints

### Accepted Hardware Assumptions

```
Target Platform: PC (decent GPU/CPU)
Target Frame Rate: 60 FPS
Target Resolution: 1080p or higher
Target Room Size: 50x50 to 100x100 tiles
Target Light Count: 10-20 simultaneous lights
```

### Performance Non-Goals (Explicit Out-of-Scope)

#### Constraint 1: No Realtime Continuous Simulation

```
❌ Physics-accurate light propagation
❌ Photon bouncing
❌ Wave simulation
❌ Continuous environmental effects

✓ Discrete grid, discrete states, discrete events
```

**Rationale:** Lighting is gameplay mechanic, not physics simulation

#### Constraint 2: No Shader-Dependent Gameplay

```
❌ GPU-resident visibility calculations
❌ Shader-based exposure determination
❌ Render-target-dependent game logic
❌ Visual-first semantics

✓ CPU-side game logic, visual rendering secondary
```

**Rationale:** Gameplay must be auditable and deterministic

#### Constraint 3: No Physically Accurate Propagation

```
❌ Fresnel effects
❌ Absorption coefficients
❌ Scattering models
❌ Wavelength-dependent effects

✓ Tactical gameplay mechanics
```

**Rationale:** Complexity not justified by gameplay benefit

#### Constraint 4: No GPU-Owned Stealth Semantics

```
❌ Compute shaders calculating exposure
❌ GPU-side stealth state
❌ Asynchronous GPU readback for gameplay
❌ Rendering-first visibility determination

✓ CPU-side semantics, GPU for visualization only
```

**Rationale:** Determinism requires CPU ownership

### Performance Targets

| Operation | Target | Acceptable | Unacceptable |
|-----------|--------|-----------|--------------|
| Shadow projection (1 light) | < 0.5ms | < 1ms | > 5ms |
| Full exposure rebuild | < 5ms | < 10ms | > 50ms |
| All overlays redraw | < 2ms | < 5ms | > 10ms |
| Guard perception query | < 0.1ms | < 0.5ms | > 1ms |

### Performance Budgets

**Per Frame (60 FPS = 16.67ms budget):**
```
Gameplay:                6ms (36%)
Graphics/Input:          7ms (42%)
Lighting System:         2ms (12%)  ← Our budget
Audio:                   1ms (6%)
Overhead:                0.67ms (4%)
```

**Lighting System Breakdown (2ms = 2000μs):**
```
Temporal updates:        200μs (10%)
Shadow projection:       800μs (40%)
Exposure rebuild:        600μs (30%)
Overlay redraw:          300μs (15%)
Queries/gameplay:        100μs (5%)
```

---

## Audit Trail & Debugging

### How to Verify System Integrity

#### Verification 1: Data Flow Unidirectionality

```gdscript
# Audit: Verify no system modifies upstream data

# ✓ Correct
_shadow_projector.project_light(light)  # Reads light
_exposure_system.rebuild_from_results(results)  # Reads shadows

# ✗ Incorrect (should never appear in code)
light.energy = 0.5  # Gameplay modifying light! (outside registry)
shadow_result.shadows.clear()  # Modifying cached result!
```

#### Verification 2: Ownership Clarity

```gdscript
# Every calculation should have ONE owner

# ✓ Shadow projection owned by ShadowProjector
shadow_result = _shadow_projector.project_light(light)

# ✗ Never do shadow calculation elsewhere
var my_shadows = manual_shadow_cast(light)  # NO!
```

#### Verification 3: Rebuild Triggering

```gdscript
# Only specific events should trigger rebuilds

# ✓ Correct triggers
- changed_lights = _light_registry.update_temporal_all(delta)
- _rebuild_all_shadows_and_exposure()

# ✗ Never triggered by
- Overlay toggle (visual only)
- AI queries (read-only)
- Performance optimizations (must be explicit)
```

#### Verification 4: Cache Validity

```gdscript
# Caches must be explicitly invalidated

# ✓ Correct
light.changed_this_frame = true  # Mark change
_rebuild_all_shadows_and_exposure()  # Rebuild

# ✗ Never silently use stale cache
return _exposure_grid[cell]  # Must verify grid was rebuilt!
```

### Debugging Checklist

When something seems wrong with exposure:

1. **Is the light active?** `light.active == true`
2. **Did the light move?** Check `light.cell`
3. **Did temporal effects trigger rebuild?** `changed_this_frame == true`
4. **Were shadows projected?** `ShadowResult.get_tiles_by_class("fully_lit")`
5. **Was exposure rebuilt?** `ExposureSystem._exposure_grid.size() > 0`
6. **Is the query correct?** `get_visibility_class(cell)` returns class 0-5
7. **Is overlay visible?** `dev_vision == true` for DEV overlays

---

## Runtime Example: Full Scenario

### Scenario: Guard Detects Agent in Light

**Frame 0:**
```
Agent at (10, 10) in SHADOW
Light at (20, 20) with type OMNI, radius 5
Light.active = true

Exposure at (10, 10) = DEEP_SHADOW
Detection mult = 0.10
Guard detection chance = 0.05 (low)
```

**Frame 1: Light begins flicker**
```
Light.set_flicker(enabled: true, interval: 1.0)
Light.current_state = "flicker"
Light.energy_multiplier = 0.0 (OFF phase)

Temporal update:
  light.update_temporal_state(0.016)
  light.changed_this_frame = true

Rebuild triggered:
  shadow_result = project_light(light)  # Light OFF, minimal shadows
  exposure_system.rebuild_from_results([shadow_result])
  exposure_grid[10, 10] = SHADOW (slightly exposed)
  exposure_confidence[10, 10] = 0.2 (unreliable, flicker)

Guard perception:
  exposure = SHADOW
  detection_mult = 0.30
  guard_detection_chance = 0.15 (higher now)
  
Result: Guard has higher chance to detect agent due to flicker
```

**Frame 2: Agent moves into full light, OFF phase of flicker**
```
Agent.cell = (21, 21)

Exposure at (21, 21) = FULL_LIT
Detection mult = 1.00
Guard detection_chance = 0.50 (high)

BUT: Light is in OFF phase
  Light.energy_multiplier = 0.0
  Shadow radius = 0 (light OFF)
  
Exposure still = FULL_LIT (position exposed)
Detection chance = 0.50

Result: Agent is in exposed position despite light being off
(Flicker timing matters!)
```

**Frame 3: Elite player activates elite vision overlay**
```
DEV_VISION = true
_apply_dev_vision()

Elite overlay appears:
  Show depth map: (21, 21) shows FULL_LIT (red) - exposed
  Show confidence: (21, 21) shows 0.2 (red) - unreliable timing
  Show stability: "temporal" (yellow) - flicker-based
  Show contours: red lines showing exposure boundary

Player reads: "I'm exposed (red), but confidence is low (red) - timing!
If I wait for ON phase, light will expand shadows."

Result: Elite player uses tactical information to time movement
```

---

## Summary: The Complete Pipeline

| Stage | System | Input | Output | Responsibility |
|-------|--------|-------|--------|-----------------|
| 1 | LightRegistry | Light changes | changed_lights[] | Track which lights changed |
| 2 | ShadowProjector | LightSource + blocked_cells | ShadowResult[] | Project shadows from lights |
| 3 | ExposureSystem | ShadowResult[] | _exposure_grid populated | Map shadows to visibility classes |
| 4 | Overlays | _exposure_grid | Visual display | Visualize exposure data |
| 5 | Gameplay | ExposureSystem APIs | Detection chance | Use exposure for game logic |
| 6 | Future AI | ExposureSystem APIs | Behavior | Use exposure for AI decisions |

**Key Invariants:**
- ✓ Data flows downward only
- ✓ Each system owns one calculation
- ✓ No circular dependencies
- ✓ Overlays never trigger rebuilds
- ✓ AI never modifies state
- ✓ System is auditable and deterministic

---

## Acceptance Criteria (L-ARCH-01)

- ✅ Official runtime pipeline documented
- ✅ System ownership matrix defined
- ✅ Invalidation sources enumerated
- ✅ Rebuild philosophy formalized
- ✅ Overlay rules specified
- ✅ AI integration hooks designed
- ✅ Performance constraints established
- ✅ Data flow unidirectionality enforced
- ✅ Debugging checklist provided
- ✅ Example scenario illustrates full pipeline

---

## Document Status

**Author:** Architecture / Lighting System  
**Date:** 2026-06-14  
**Version:** 1.0 (L-ARCH-01)  
**Status:** Complete 🟢

**Purpose:** Formal specification before L-IMP-08+ integration

**Next Steps:**
1. Use this pipeline for all future lighting changes
2. Reference when implementing L-IMP-08 (ShadowProjector semantics)
3. Reference when implementing L-IMP-09 (AI integration)
4. Use invalidation rules for performance optimization (M2-13)

**Maintained By:** Architecture / Lighting System Lead  
**Review Cycle:** Before each major milestone (L-IMP-08+)
