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

## Visual Occlusion (Wall/Roof Ghosting) — OCC-01→27, ROOF-OCC-01

> **Distinct from the semantic model above.** Everything above this section
> (LIGHT-02) governs light/LOS/sound classification. This section documents a
> separate, later system: the runtime visual effect that erases and
> wireframes geometry standing between the camera and the agent, so the
> player can still see the agent through walls/roofs he's behind. Code:
> `godot/scripts/systems/occlusion_set.gd` (`OcclusionSet`),
> `godot/scripts/overlays/occlusion_wireframe_overlay.gd` +
> `occlusion_slice_panel.gd`, wired from `room.gd::_recompute_occlusion()`.

### What it does

On every agent step, view rotation, and (for a preview) hover-cell change,
`OcclusionSet.recompute()` decides which wall columns and roof cells sit
between the camera and one or more **origins** (agent position, optionally
the hover cell) and are close enough on screen to actually hide him. Those
cells are **erased** from their `TileMapLayer` (not ghosted via alpha —
`VoxelRenderer.apply_occlusion()`), and a dotted-white wireframe box
(`OcclusionWireframeOverlay`) is drawn in their place so the structure's
shape stays legible. Restoring the cell is lossless and verified on every
capture run (`VoxelRenderer.verify_ghost_roundtrip()`).

### Walls (OCC-01→27)

- **Trigger:** a real 2D screen-space overlap test between an EDGE's
  (one wall column, every storey) footprint and the origin's own silhouette
  rectangle — not a corridor/distance heuristic. `depth = x + y` (view-space
  isometric); an edge only triggers if it is nearer the camera than the
  origin (`depth > origin.depth`).
- **Ring falloff:** a multi-source BFS along the wall's own connectivity
  graph (shared grid VERTEX = adjacency), up to `MAX_RING` hops, only through
  simple pass-through vertices continuing the same face — corners and
  junctions stop propagation. Ring index selects
  `VoxelRenderer.GHOST_ALPHAS` / the wireframe fill alpha.
- **Always-visible base:** an occluded edge's own bottom
  `BASE_VISIBLE_LEVELS` (2) levels are never erased — reads as solid ground
  truth footprint regardless of ring.
- **Erase span is capped at the edge's own top** (`max_level`, OCC-26,
  2026-07-18): earlier code erased from `min_level` through every layer in
  the renderer, which also ate a roof's 1-voxel border row sitting in the
  same wall columns above the wall's own top — the visible roof edge fell
  back one voxel, a ~4-screen-px seam against the wireframe reported as
  "wireframe shifted up." Fixed by threading `max_level` alongside
  `min_level` in every occluded-cell entry; a cell shared by two claimants
  (e.g. a wall column also touched by a roof stripe) keeps the wider span.
- **Junction columns** (V-junction fillers, not part of any Edge/Slice) ghost
  only when BOTH edges they fill the elbow between are themselves occluded;
  always ring 0.

### Roofs — ROOF-OCC-01 (2026-07-18)

Roofs (`Slab.Role.CEILING`) join the same occlusion pass as **screen-
horizontal GU stripes**: a stripe is every roofed GU sharing one
`gu.x + gu.y` (an anti-diagonal in grid space, which projects as a
horizontal row of GU diamonds on screen — Director-ratified orientation).

- **Trigger** (either fires the whole connected roof component — 4-adjacency,
  level-blind, the same rule `ROOF-BAKE-02c` uses for texture anchors):
  - **(a) Containment** — an origin's GU sits inside the component's
    footprint (agent/hover inside a roofed room).
  - **(b) Wall-coupling** — any occluded wall edge belongs to the component's
    own structure. Needed because a solid block (e.g. every TEXTURES tower)
    has no walkable interior, so (a) never fires there; without (b) the roof
    would float, solid, over a wall the player can already see through.
- **Ring = `|stripe_depth − origin_depth|`** (min over all origins), occluded
  only within `MAX_RING` — the reveal opens a moving window around the
  agent rather than the whole interior at once.
- **Small-roof rule:** a component with `≤ SMALL_ROOF_MAX_STRIPES` (5 —
  exactly the TEXTURES 3×3 towers) ghosts every stripe regardless of ring:
  the whole roof disappears and leaves one continuous wireframe of its own
  shape, rather than a partial stripe reveal that would look broken on
  something that small.
- **Cell ownership:** a roof cell that is also a wall column's own cell
  (the roof's border row) merges spans — `min(ring)`, `min(min_level)`,
  `max(max_level)` — so a merged claimant's erase never regresses either
  contributor's own correctness.

### Wireframe — OCC-27 (2026-07-21): unified hidden-face culling

Walls, junction columns and roofs used to each draw their **own independent
wireframe box** per structural unit (OCC-13: one per wall Edge, one per roof
GU, one — disabled — per junction column), explicitly accepting the overlap
at a unit-to-unit boundary as "expected, not a defect." In practice every
such boundary (wall-to-wall, wall-to-junction, GU-to-GU) drew a real extra
seam; ROOF-OCC-02 (2026-07-20, since superseded and removed) patched this
locally for roofs only via a rectangle merge. OCC-27 replaces all of that
with **one hidden-face-culling pass over the already-unified occluded-column
set** (`OcclusionSet._build_wireframe_geometry()`) — the same principle
voxel engines use for chunk meshing (only mesh a face if the neighbour
across it isn't solid): a face is internal (never drawn) iff the
neighbouring column is *also* occluded and its vertical range **overlaps**
this one (interval overlap, not exact-level match — OCC-26's wall-below-
roof-border union widens a border column's range past its own natural top,
and an exact-level test misread that as a mismatch, drawing a false seam
the wall's full height); external otherwise. This kills every unit-to-unit
seam for walls, junctions and roofs alike in one pass.

**Line style** (hidden-line-removal, CAD convention): a face exposed toward
+x or +y (O5: nearer camera) is this volume's own near side — drawn as a
plain **solid** line, no dots. A face exposed toward -x or -y is the far
side, behind the volume's own bulk from the camera's POV — drawn as **dots
only**, no underline. The flat top rim is the one exception: nothing
overhangs it from this camera angle regardless of direction, so it always
draws solid. The ghosted band's own bottom is never capped — it sits
directly on the always-visible base (`BASE_VISIBLE_LEVELS`), not a true
external boundary.

**Fill:** a translucent quad per exposed face plus the flat top (merged into
maximal rectangles to avoid antialiasing seams between adjacent per-voxel
quads), at `VoxelRenderer.GHOST_ALPHAS[ring]` — the same alpha the real
ghosted material uses, restoring OCC-19's original intent after it had
drifted to an independently-tuned 30/50/70% through the OCC-21 series.
Currently 8%/16%/24% (retuned twice live from an initial 3%/6%/9%, both
times Director's call: "faces read as almost invisible").

**OCC-28 (2026-07-21, tried and reverted same day):** split walls+junctions
and roofs into two independently-culled entities, so a wall's own top rim
and a roof's own underside would draw as two separate (possibly
overlapping) outlines instead of fusing into one. Director's verdict after
a real capture: "não ficou muito bom" — reverted via `git revert`, back to
OCC-27's single unified pass. Not re-attempted.

### OCC-FIX-03 (2026-09-01) — the wedge to the scene origin

**Symptom** (Director, on GLASS): "a oclusão está se confundindo com a
iluminação e projetando um rastro pro teto" — a translucent grey wedge
fanning from a ghosted wall's top rim up past the top of the screen, with a
white line and a dotted line converging on the same apex. It reads as a
light shaft, which is why it looked like a lighting bug; it is entirely the
wireframe overlay (`INFILTRAITOR_WF_HIDE=1` removes 100% of it).

**Cause — LEVEL-RENUMBER residue.** Both overlays resolved a screen position
by asking `VoxelRenderer.get_layer(...)` for the layer that actually draws a
level, with a fallback for levels that have no layer built — in practice
`max_level + 1`, which is where the ghost band's **top-cap** rim and fills
live. That fallback was written when the ground plane WAS level 0:

```gdscript
var base_layer := voxel_renderer.get_layer(0)          # null since the renumber
if base_layer == null:
    return Vector2.ZERO                                 # ← every top-cap point
return base_pos + Vector2(0.0, -float(level) * VOXEL_STEP_PX)   # absolute level
```

With the ground plane at `PLAYABLE_LEVEL` (80), `get_layer(0)` is null on
every map, so every point one level above a wall's top collapsed onto
`Vector2.ZERO` — the **scene origin**. Each top-cap quad became a triangle
from the wall's real top rim to (0, 0), and their union is the wedge.

The fix asks the renderer where its own origin is: `ground_plane_level()`
for the anchor layer and `relative_level()` for the offset — the two
accessors that exist so no caller has to know. Same one-line defect, same
root cause, in `occlusion_overlay.gd` (the dev ring-diamond painter, hidden
behind the `L` light-vision toggle): it returned `Vector2.ZERO` for *every*
cell, so the whole overlay painted in one pile at the origin.

**Measured, GLASS, agent at (11, 16), zoom 0.28** (erase-diff forensics, the
technique below):

| | ghosted wall's own pixels | wireframe's own pixels |
|---|---|---|
| before | y 153..475 | y 0..478, 81 564 px |
| after | y 153..475 | y 153..478, 28 053 px |

53 511 phantom pixels, all of them above the wall they claimed to outline.
Captures: `Screenshots/history/occ_wedge_before_2026-09-01.png` /
`occ_wedge_after_2026-09-01.png`; dev overlay
`occ_devoverlay_before_2026-09-01.png` / `..._after_...` (strong-red ring-0
diamonds: 9 stray px before, 657 px on the wall after).

**Arithmetic check that the fallback is now exact:** the built layers step
by `VOXEL_STEP_PX` (20 px) per level — level 82 sits at y 536, level 103 at
y 116 (21 levels × 20 px = 420). Ground (level 80) is therefore y 576, and
the extrapolation for level 104 gives 576 − 24 × 20 = **96**, exactly one
step above level 103's 116.

**The rest of the sweep** (Director, 2026-09-01: *"sim, vamos consertar tudo"*).
`get_layer(0)` survived at five more sites outside this system, all the same
silent-null defect, all fixed in the same pass:

| Site | What it had been doing |
|---|---|
| `grenade_prop.gd::_apply_z_index()` | Silent no-op — so `set_airborne(false)` at the end of a throw restored nothing and a **resting** grenade kept the flight z_index (`get_max_voxel_z_index() + 1`), i.e. drawn on top of every wall. D22-FOLLOWUP's own bug, reintroduced by a number. |
| `floating_collectible.gd::_apply_z_index()` | Returned before the depth sort ran; `z_index` never set at all. Dormant (`TEST_ZONE_COLLECTIBLES_ENABLED = false`). |
| `agent_probe_prop.gd::_apply_z_index()` | Same. Dormant (`TEST_ZONE_AGENT_PROBE_BRACKET` is empty). |
| `room.gd::_debug_probe_voxel_alignment()` | Aborted on every map since the renumber. Flag-gated. |
| `prop_01_tests.gd` (×2) | Read a null layer, so both voxel counts came out 0 and the equality assert passed on `0 == 0`. |

Measured on a real PLAYGROUND `throw_event` boot, with the two dormant props
temporarily enabled so all three ran their real path — one run, both answers:
`get_layer(0)` = **null** for every one of them, `ground_plane_level()` = 80,
and the resting grenade's z_index is now **10** (the ground layer's) rather
than 34 (`max_voxel_z + 1`).

**Pinned by a new invariant, L1 `level-never-a-literal`**
(`tools/persistent/check_invariants.py`, so it runs in the pre-commit hook): any
integer literal passed to `get_layer()` outside `voxel_renderer.gd` is a
violation. Verified red-before-green at both widths.

⚠️ `prop_01_tests.gd` still reports **4/7**, unchanged by this fix: its
criterion [3] crashes earlier on a `PropDef.footprint_gus` type mismatch, and
[4]/[6] on `map_compiler.gd:63`, so the corrected lines are not even reached.
Pre-existing rot in a file the selftest runner already reports as NOT RUN —
untouched here, and separate from this defect class.

### OCC-FIX-03c (2026-09-01) — the wider renumber sweep

Director: *"vamos continuar corrigindo tudo que aparecer."* L1 had started
narrow (literal `0` / `-N` only). Widening it to **every** integer literal was
what surfaced the rest, because a stale POSITIVE literal is the worse half of
the defect: it resolves to a real layer eighty levels from where it means, so
nothing is null, nothing warns, and the code quietly describes a different
building.

| Site | What it had been doing | Evidence |
|---|---|---|
| `damage_gallery_debug.gd::_gallery_ceiling()` | Looked for the roof Slab at `BLOCK_STOREYS * LEVELS_PER_STOREY` = 16; `room_builder` registers it at `storey_level_base(storeys)` = 96. **8 of 8 CEILING probes reported MISS "no Slab SLAB_x_y_CEILING_16"** — a false negative from the one tool whose job is answering "is this atom actually baked". | Real PLAYGROUND `damage_gallery` capture, red before / green after |
| `roof_slab_selftest.gd` | Block rendered at storey 0 (levels 80–87), "roof" placed at levels 8 and 9 — **72 levels below it**. Passed because it only ever asserted material, never the spatial relation in its own name. | Now prints `Block (level 80) and both roof levels (88, 89)`; 15 PASS |
| `fixed_floor_selftest.gd` | Half-migrated: test [1] already used `FLOOR_TOP_LEVEL - 3`, while [2]/[3]/[4] still spelled `-1`, `-2`, `-6`, `-8` — a D13 ground stack 80 levels under the real one. | Now prints `All 8 levels of the D13 stack (72..79)`; 5 PASS |
| `slab_render_selftest.gd` | Destructible top at literal `1`, "fixed bedrock" at `FLOOR_TOP_LEVEL` — the two labels had swapped with the renumber. | Now `FLOOR_TOP_LEVEL` / `FLOOR_DEEP_LEVEL`; passes |

**Checked and NOT residue** (recorded so the next sweep does not re-open them):
`bake_compositor.gd`'s `start_level` and `room_builder`'s junction
`level_start`/`level_end` are texture space, origin zero, on purpose;
`BakedTileLookup`'s `level == 0` is a facade sheet row, already relative;
`blast_calculator.gd`'s `chest_level` adds and subtracts
`start_storey * LEVELS_PER_STOREY` and cancels exactly;
`detonation_presenter._delay_for()` and `room.gd`'s `PassageQuery` calls both
already subtract `PLAYABLE_STOREY`; the `Slab.new(...)/Voxel.new(...)` unit
fixtures in `blast_calculator_selftest` / `slab_geometry_selftest` are synthetic
containers with a self-consistent origin that never reaches a layer, a slab id
in a real registry, a bake row, a hash or a screen position — which is the line
this sweep drew between "residue" and "a local coordinate".

### The invisible tier (2026-09-01) — the eight files outside the selftest glob

`run_selftests.py` globs `*_selftest.gd` and prints a NOT RUN list for the eight
`*_test.gd` / `*_tests.gd` files that fall outside it. Nothing gates those, and
two of them had gone red without a single symptom anywhere — both by an
unrelated, correctly-executed reform elsewhere in the tree:

| File | Was | Broken by | Now |
|---|---|---|---|
| `bake_cache_test.gd` | **1 PASS, 6 FAIL**, exit 0 | ASSET_TREE_REFORM (2026-08-21) gave `TextureResolver.resolve()` a material-folder argument; this file kept calling the one-arg form, so every lookup went to the old flat `ASSETS/materials/facade_<id>.png` and found nothing | 7/7 |
| `occlusion_set_test.gd` | **2/5**, exit 0, and one of the two "passes" was `✓ Cardinality reasonable: 0 cells (expect dozens)` | LEVEL-RENUMBER (2026-08-24): the fixture built voxels at levels 0..5, which `compute_edge_occlusion()` turns into a screen rectangle ~1600 px from the agent's, so nothing triggered and the set came back EMPTY | 5/5, real counts (4 / 53 / 31 cells) |
| `prop_01_tests.gd` | **4/7** | `PropDef.footprint_gus` is `Array[Vector2i]` and `tags` is `Array[String]` — untyped literals cannot be assigned; and `MapCompiler.compile()` takes `inner_size`/`agent_start`/`props[].cell` as `Vector2i`, which `FileMapSource._convert_from_json_compatible()` coerces before calling in | 7/7 |
| `panel_base_test.gd` | passed, but **leaked** two orphan nodes | never freed; invisible because LEAK-GATE-01 only runs inside the glob | freed |

Both regressions predate this session and both files had a written record of
passing (`RESUMO_SESSAO_2026-07-18` "bake_cache_test 7/7",
`RESUMO_SESSAO_2026-08-16` "occlusion_set_test passes 5/5"). Nothing regressed
them on purpose; nothing could tell anyone they had.

`occlusion_set_test`'s cardinality guard also **accepted the degenerate answer**
— `< 5 cells` printed a ⚠ and returned true. That is how it reported a healthy
green on an empty set for as long as the fixture was broken, twice (AUDIT-01,
then the renumber). It fails now; red-before-green: putting the fixture back on
pre-renumber levels gives 1/5 with `✗ Occlusion set is empty or near-empty (0)`.

**All eight now pass** except `version_info_test.gd`, which cannot load headless
(`VersionInfo` autoload).

**Six of them moved INTO the glob** (Director, 2026-09-01: *"vamos corrigir o que
for necessário"*), so the suite went from 40 gated to **46**:
`bake_cache_selftest`, `input_controller_selftest`, `mapfile_roundtrip_selftest`,
`occlusion_set_selftest`, `panel_base_selftest`, `resolver_hardening_selftest`.

`occlusion_set` needed three more things before it could join, and each was its
own way of being unable to report a failure outward:

1. `class_name OcclusionSetTest` — no caller used it, no sibling selftest
   declares one, and a global class name on a `--script` entry point buys
   exactly one thing: a "hides a global script class" parse error the moment the
   file is renamed. Removed.
2. `quit()` with no argument — **exits 0 whatever happened.** That is the
   AUDIT-01 trap this file's own header is about, still live in the line that
   reports the verdict. Now `quit(0)` / `quit(1)`.
3. No uppercase PASS banner. `run_selftests.py` additionally requires the
   suite's own banner in the output, because a script that fails to LOAD also
   exits 0 having run nothing — so `[SUCCESS] All tests passed` did not satisfy
   the arbiter. Now `[SUCCESS] OCCLUSION SET SELFTEST PASS — all N tests`.

Red-before-green **through the arbiter**: fixture back on pre-renumber levels →
`✗ occlusion_set_selftest.gd — exit 1`, `RESULT: 0 clean, 1 failed`. The same
break was invisible before.

`prop_01_tests` and `version_info_test` stay outside — they need autoloads
`--script` does not instantiate (`prop_01_tests` passes 7/7 by hand). The runner
still names them in its NOT RUN report.

### Map data (2026-09-01) — the test maps boot silent now

Director: *"não existem mapas autorados ainda, tudo é apenas ambiente de testes.
Podemos corrigir o que for simples, remover elementos antigos ou mesmo excluir os
mapas."*

| Map | Was | Fix |
|---|---|---|
| `SIGMA_01` | 9 `crate_*` sprite props (`crate_SE` ×3, `crate_SW` ×2, `crate_NW` ×2, `crate_NE` ×2) — 9 `push_error`s at boot, "Scenery is voxels now", nothing drawn where the map said a crate was | `legacy_compiler.props` emptied |
| `SIGMA_01`, `TEXTURES`, `TEST_BLOCKS`, `FLOOR_ZONES_TEST` | no `damage_materials` section, so their damage atoms never baked (the D13 warning, working correctly) | section added, listing what each map actually uses |

`FLOOR_ZONES_TEST`'s floor-zone materials were the one worth checking rather than
assuming: adding `grass`/`sand`/`dirt` makes the baker resolve
`ASSETS/materials/<id>/slab_<id>.png` (1024×1024, validated) and compose a real
roof page of 1025 atoms each — the art was already there, it was simply never
asked for.

**All six maps now boot with zero errors and zero warnings.**

### MAT-COHERENCE-01 (2026-09-01) — is anything instantiated without art?

Director, on reading the damage gallery's CEILING row: *"tem alguns materiais que
não ficam rachados mesmo. Se estiver coisa sendo instanciada sem arte aí sim me
avisa."* The answer, measured: **no.**

The gallery's `MISS` was mis-read (by me) as an art gap in the OCC-FIX-03c note
above. It is not one. `apply_damage_voxel_swap()` returns `false` on "no PRE-BAKED
atom", and every production caller has a D33 live-compositing fallback line right
after it; the gallery calls the swap directly, so it never reaches that fallback
and reports a MISS for something the game renders correctly. And for metal/wood
CRACKED specifically the tier is unreachable in the first place —
`crack_factor == 0.0` (D32.6, *"metal e madeira não ficam rachados"*), so there is
nothing to bake and nothing to draw.

Full coherence, read off `ASSETS/materials/<id>/<id>.json`:

| | materials | art |
|---|---|---|
| `crack_factor > 0` | brick 0.12, concrete 0.10, stone 0.10 | all three wired in `IMPACT_CRACK_MATERIALS`, 9/9 decals on disk |
| `crack_factor == 0` | metal, wood, glass, cardboard, fabric, plywood, dirt, earth, grass, gravel, sand | none wired to crack — no dead art |
| `dent_factor > 0`, own family | brick, concrete, metal, stone, wood, earth | 3/3 dent decals each |
| `dent_factor > 0`, no family | dirt 0.35, grass 0.35, gravel 0.30, sand 0.40 | the material-agnostic GENERIC mark (D33 Part 4b) — a real mark, not an absence |

**Gated from now on** by `voxel_decal_selftest` **[12]
`test_every_data_reachable_tier_has_art()`**. It enumerates materials by walking
`ASSETS/materials/<id>/<id>.json` — the same scan `MaterialResistanceTable`
itself does — so a material added tomorrow is covered the day it lands rather
than the day someone remembers this test. Test [10] already asserted the same
invariant for a hardcoded metal/wood pair; this is that rule for the whole table,
in both directions (a promise with no art, and art with no promise).
Red-before-green: `metal.crack_factor` temporarily 0.0 → 0.4 produced
`✗ 1 crack promise(s) the renderer cannot keep: metal (factor 0.40, not wired)`.

Also checked, and clean: `check_facade.py --all` 10/10 PASS, `check_decal.py
--all` 54/54 PASS. Both tools' no-argument usage path used to crash with
`AttributeError: 'NoneType' object has no attribute 'strip'` — their headers are
`##` comment blocks, not docstrings, so `__doc__` is `None`; fixed by reading the
`## Usage:` block back off the file rather than duplicating it.

`slice_geometry_selftest.gd`'s "Check 1: E1 (layer transform)" was flagged here
as hollow and is **fixed** (2026-09-01, Director: *"pode fazer todas as
correções"*): it computed an expected layer position and only `print_debug`'d it,
excused by a comment claiming "we can't instantiate TileMapLayers headless" —
which three other selftests disprove by doing exactly that. Worse, the formula it
printed omitted `TILE_OFFSET` entirely, the same re-derivation OCC-FIX-02 had to
undo in `OcclusionOverlay`; a check that asserts nothing cannot notice its own
canon is wrong. It now builds a real `VoxelRenderer` and asserts each layer's
`position` against E1 with `relative_level()`. Red-before-green: restoring the
historical 8 px `TILE_OFFSET` error (112, 56) produces 3 mismatches and exit 1.

### Capture instruments (env-gated, zero cost when unset)

For unattended visual verification (`room.gd::_run_auto_screenshot_capture()`):

| Env var | Effect |
|---|---|
| `INFILTRAITOR_CAPTURE_AGENT_CELL=x,y` | Teleport agent, reveal FOW, recompute occlusion before capture |
| `INFILTRAITOR_CAPTURE_REVEAL_RADIUS=N` | Override the FOW reveal radius for that teleport (large maps need more than the default) |
| `INFILTRAITOR_CAPTURE_VIEWS=1` | Drive all 4 real perspectives (N/E/S/W), one PNG each to `occ_view_*.png`, ghost round-trip verified per view |
| `INFILTRAITOR_OCC_DISABLE=1` | Force an empty occlusion set — an opaque-geometry reference capture for diffing against the occluded one |
| `INFILTRAITOR_WF_HIDE=1` | Hide only the wireframe overlay — isolates erase/restore pixels from wireframe pixels in a diff |

Erase-diff forensics (opaque capture minus occluded capture, same agent
cell) is the standard technique for measuring exactly which pixels an
occlusion change touched — used to both disprove the "wireframe offset"
read (median delta 0px at the wall base) and to locate the real roofline
seam (OCC-26).

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
