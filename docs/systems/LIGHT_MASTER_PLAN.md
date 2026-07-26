# INFILTRAITOR — Lighting System Master Plan

> **Canonical specification for visibility semantics, lighting taxonomy, and detection multipliers.**

Lighting is core gameplay, not visual decoration. This document defines how light exposure affects guard detection probability and stealth mechanics.

---

## Overview & Philosophy

**Key Principle:**
```
Visual brightness  ≠  Tactical visibility
```

The appearance of light on screen is secondary to the gameplay state it represents.

### Core Principles

| Principle | Meaning |
|-----------|---------|
| **Deterministic** | Same position always produces same visibility (no random flicker) |
| **Grid-Based** | Visibility is per-tile, not per-pixel or per-position |
| **Auditable** | Player can always understand *why* they are in a given visibility class |
| **Semantic** | Classes have clear meaning: SHADOW = stealth, FULL_LIT = danger |
| **Discrete** | 5 visibility classes, not continuous values (avoids ambiguity) |
| **Stealth-Oriented** | Light/shadow fundamentally changes guard detection probability |

---

## Visibility Classes (Discrete Taxonomy)

Five semantic visibility states, independent of camera or rendering:

| Class | Intensity | Detection Bonus | Tactical Use | Example |
|-------|-----------|-----------------|--------------|---------|
| **FULL_SHADOW** | 2–10% | -70% | Optimal stealth | Shadows, alcoves, blind corners |
| **PENUMBRA** | 15–30% | -30% | Semi-safe zones | Storage room, side passages |
| **NORMAL** | 40–60% | +20% | Standard patrolled | Corridor, stairwell |
| **BRIGHT** | 70–85% | +60% | Active monitoring | Guard post, command center |
| **FULL_LIT** | 100% | +100% (max) | Maximum danger | Spotlight, main corridor |

**Semantic properties:**
- Each class has deterministic detection multiplier
- Transitions happen per-tile boundary
- Player receives visual feedback for each class
- Guards apply same multipliers to all detection

---

## Light Source Architecture

All lights are **map-driven** via `MapSpec.lights` → `layout.light_sources`.

**Pipeline:**
```
MapSpec.lights (map data)
    ↓
MapCompiler.compile()
    ↓
layout.light_sources (rotated by perspective)
    ↓
LightingController._setup_lights_from_layout()
    ↓
LightSource instances registered
    ↓
LightingController.rebuild_all() (on perspective change)
    ↓
tile_semantics + shadows + exposure derived
```

### Light Source Types

| Type | Description | Range | Behavior | Example |
|------|-------------|-------|----------|---------|
| **Omni** | Radial illumination from point source | 1–8 tiles | Emits equally in all directions | Torch, lamp, emergency exit sign |
| **Directional** | Linear incidence from fixed direction | Entire layer | Sunlight, moon, global ambient | Daylight, moon glow |
| **Cone** | Focused beam with falloff (FOV-like) | 3–6 tiles | Directional with angle attenuation | Spotlight, guard flashlight |
| **Ambient** | Global weak illumination (no source) | Entire level | Uniform floor illumination | Base light level, faint glow |
| **Intermittent** | Pulsing or flickering light | 1–4 tiles | Rhythmic on/off cycles | Alarm light, strobe, malfunctioning lamp |
| **Emergency** | High-intensity alert lighting | 2–6 tiles | Triggered by alerts, full intensity | Lockdown searchlight |
| **Mobile** | Light coupled to entity | Local to entity | Moves with entity | Guard's torch, player's equipped light |

---

## Spatial Coordinates & Fixtures

### Canonical Screen Positions

Use these formulas for lighting fixture placement (never invent empirical tables):

| What | Formula | Notes |
|---|---|---|
| **Tile center** | `floor_layer.map_to_local(cell) + Vector2(0, 64) + VISUAL_GRID_OFFSET` | "canonical center" |
| **Ceiling lamp** | `tile_center - Vector2(0, WALL_FLOOR_STEP_PX * (max_floors + 0.75))` | `max_floors` from `room._base_layout` |
| **Temporal fixture knob** | `tile_center - Vector2(0, WALL_FLOOR_STEP_PX * (max_floors + 0.75) + 72)` | Matches TemporalOverlay |

**Key rule:** Any overlay that needs the lamp's screen position must use:
```gdscript
ceiling_lift = WALL_FLOOR_STEP_PX * (max_floors + 0.75)
```
Receive `max_floors` from `room.gd` — never a per-`height_class` lookup table.

---

## Shadow System

### World Shadows (Always-On)

Floor shadows are **real-world elements**, always visible — they do not depend on DEV/LIGHT/HEAT vision modes.

**Architecture:**
- `ExposureSystem` computes full and penumbra cells
- Three layers rendered at `z=1`:
  - `ShadowFullLayer` — full shadow cells, fixed modulate
  - `ShadowPartialLayer` — penumbra cells, fixed modulate
  - `_tile_shadow` — spill overlay (cosmetic halo)

**Repaint trigger:**
- `room._ready()` — initial setup
- `room._repaint_world_shadows()` — called on every `lighting_rebuilt` signal

### Shadow Spill

A soft cosmetic halo that a full-shadow cell bleeds onto neighbours:

```
_compute_shadow_spill()  → calculate halo strength
_spill_color()          → color per ring/direction
```

**Properties:**
- **PURELY VISUAL** — never feeds gameplay detection
- Tones by ring (darker closer) and by direction (orthogonal darker than diagonal)
- All values are `var` (tunable)

### Shadow Boundary Lines

Dark lines on edges where shadow meets non-shadow:

```
ShadowBoundaryOverlay (z=4)
  ├─ Dark lines at shadow/non-shadow edges
  └─ Vignette fill
```

**Update method:**
```gdscript
set_full_shadow_cells(cells)
set_lite_shadow_cells(cells)
```
Called during `_repaint_world_shadows()`.

---

## Detection Multipliers by Environment

Guards apply these multipliers when calculating detection chance:

```
Direct shadow (SHADOW_MULT):    0.30×   (full shadow, full safety)
Penumbra (PENUMBRA_MULT):       0.55×   (shadow edge, moderate safety)
Normal light:                   1.00×   (baseline)
Bright areas:                   1.60×   (guard alert zones)
Full light:                     2.00+×  (maximum danger)
```

Combined with:
- Agent posture (standing 1.0× vs crouching <1.0×)
- Cover status (full/partial cover multipliers)
- Guard state multiplier (patrol 0.55× vs chase 2.80×)

---

## Perspective Rotation Coherence

On perspective change, lighting is re-derived:

**Rotation rule:**
```gdscript
_layout_with_perspective()
  ├─ rotates all per-cell layers (wall_levels, structure_tiles, blocked_cells/edges)
  ├─ rotates exit_cells AND light_sources
  └─ returns rotated layout

_set_perspective()
  └─ calls LightingController.rebuild_all()
      └─ re-derives lights, semantics, shadows, exposure from rotated layout
      └─ emits lighting_rebuilt signal
      └─ all analysis overlays update
```

**Principle:** On a perspective change, re-derive every lighting system per cell from the rotated layout, exactly like the initial `_ready` setup.

---

## LightingController API

### Setup

```gdscript
func _setup_lights_from_layout(layout: Dictionary) -> void
    ## Register light sources from layout.light_sources
    ## Called once per map load and on perspective rotation
```

### Rebuild & Invalidation

```gdscript
func rebuild_all() -> void
    ## Re-derive all light semantics, shadows, exposure
    ## Called on perspective rotation, light changes, structure changes
    ## Emits: signal lighting_rebuilt
```

### Query Methods

```gdscript
func get_tile_visibility_class(cell: Vector2i) -> String
    ## Returns one of: FULL_SHADOW, PENUMBRA, NORMAL, BRIGHT, FULL_LIT

func get_detection_multiplier(cell: Vector2i) -> float
    ## Returns multiplier applied to guard detection

func is_cell_in_shadow(cell: Vector2i) -> bool
    ## Returns true if cell is in FULL_SHADOW or PENUMBRA
```

---

## Architectural Rules (Inviolable)

1. **No empirical pixel offsets in lighting**
   - All fixture positions derive from canonical formulas
   - Use `WALL_FLOOR_STEP_PX` and `max_floors` from room

2. **Lights come from the map, never hardcoded**
   - `MapSpec.lights` is the sole source of truth
   - Test lights are created via map specifications

3. **Lighting rebuilds atomically**
   - `rebuild_all()` is transactional
   - All systems (shadows, semantics, exposure) derive from same data
   - Emits `lighting_rebuilt` when complete

---

## Related Documentation

- **OPERATOR_CONTEXT** — Development handbook with architectural invariants
- **ARCHITECTURE.md** — High-level system relationships
- **docs/systems/lighting_runtime_pipeline.md** — Runtime flow and invalidation rules
- **docs/systems/occlusion.md** — LoS and structural blocking
- **docs/systems/rendering.md** — Visual rendering and overlay systems
- **PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md** — the VISUAL BRIGHTNESS half of
  this canon: how the tactical state defined above (visibility classes,
  shadows, exposure) gets painted onto voxel faces as 6-then-12 discrete
  buckets, plus blast soot/ember/crater visuals and destruction persistence
  through perspective rotation. Read that doc before touching
  `VoxelLightField`, `VoxelRenderer.apply_light_field*()`, or `EmberOverlay` —
  this doc's split (brightness ≠ visibility) is the canon it inherits.
