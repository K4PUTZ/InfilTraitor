# INFILTRAITOR — Rendering & Overlay System

> **Unified tile overlay architecture for shadows, detection cones, and navigation markers. Multiply and mix blend modes for visual clarity.**

---

## Grid Geometry

- **Source tile art:** `256x128` px
- **Rendered isometric tile:** `128x64` px half-extents (`TILE_HW=128`, `TILE_HH=64`)
- **Canonical center:** `floor_layer.map_to_local(cell) + Vector2(0.0, 64.0) + VISUAL_GRID_OFFSET`
- **Global visual offset:** `VISUAL_GRID_OFFSET = Vector2(0.0, 512.0)`

Use this as the shared reference for all overlay drawing code.

## Overview

The rendering system provides a **unified tile overlay framework** for all visual feedback:

- **Shadow rendering** with 3-level gradation (multiply blend)
- **Detection cones** with 5-band probability spectrum (mix blend)
- **Navigation markers** for exits and spawn points (DEV_VISION only)
- **Priority-based layering** to prevent visual conflicts

All overlays are instances of `TileOverlayClass` with independent material stacks.

---

## TileOverlay Architecture

### Core System: `tile_overlay.gd`

**Purpose:** Unified tile painting system with multiply/mix blend modes, priority sorting, and isometric diamond rendering.

**Key Features:**
- Independent entries dictionary: `Vector2i → {color, priority}`
- Automatic priority sorting before rendering
- Isometric diamond geometry (TILE_HW=128, TILE_HH=64)
- Static color utility functions for consistent palettes

### Integration Points

**1. Shadow System (`room.gd` — `_tile_shadow`)**
- Z-index: 1 (below noise/detection)
- Blend mode: `BLEND_MODE_MUL` (preserves texture detail with color tint)
- Priority: `PRIO_SHADOW` (1)
- Updated by: `_bake_shadow_tiles()` per frame

**2. Game Visuals (`room.gd` — `_tile_game`)**
- Z-index: 3 (above noise, below structures)
- Blend mode: `BLEND_MODE_MIX` (standard blending, vivid colors)
- Priorities: `PRIO_NAV` (4), `PRIO_DEV` (5)
- Updated by: `_apply_dev_vision()` when toggled

**3. Detection Cone (`guard_enemy.gd`)**
- Z-index: -5 (behind tiles, part of guard sprite)
- Blend mode: `BLEND_MODE_MIX` (vivid spectrum)
- Priority: Inline in `_draw_vision_tiles()` (no TileOverlay dependency)
- Drawn directly by guard per-frame

---

## Palette System

### Priority Constants

```gdscript
const PRIO_SHADOW   := 1    ## Shadows — drawn below everything
const PRIO_DETECT   := 2    ## Detection cone
const PRIO_MOVEMENT := 3    ## Movement/pathfinding preview
const PRIO_NAV      := 4    ## Navigation — exits, objectives
const PRIO_DEV      := 5    ## Dev only — spawn marker, debug
```

### Color Palettes

**Shadow System (Multiply, Alpha 0.80)**

| Palette Key | RGB | Purpose | Visual |
|-------------|-----|---------|--------|
| `shadow_full` | (0.1, 0.2, 0.4) | mult ≤ 0.35 | Dark blue, opaque shadows |
| `shadow_mid` | (0.3, 0.4, 0.6) | 0.35 < mult ≤ 0.65 | Medium blue, half shadows |
| `shadow_lite` | (0.5, 0.6, 0.8) | mult > 0.65 | Light blue, faint shadows |

**Detection System (Mix, Full Spectrum)**

| Palette Key | RGB | Purpose | Visual |
|-------------|-----|---------|--------|
| `detect_0` | (0.25, 0.75, 0.00) | prob ≤ 0.12 | Dark green, cone edge |
| `detect_1` | (0.50, 0.82, 0.00) | 0.12 < prob ≤ 0.35 | Light green, building |
| `detect_2` | (1.00, 0.82, 0.00) | 0.35 < prob ≤ 0.55 | Yellow, mid-range |
| `detect_3` | (1.00, 0.40, 0.00) | 0.55 < prob ≤ 0.80 | Orange, high alert |
| `detect_4` | (1.00, 0.13, 0.13) | prob > 0.80 | Red, frontal focus |

**Navigation Markers (Mix)**

| Palette Key | RGB | Purpose | Visual |
|-------------|-----|---------|--------|
| `exit` | (0.55, 0.10, 0.90, 0.28) | Purple | Map exit points (DEV_VISION) |
| `spawn` | (0.20, 0.20, 0.20, 0.40) | Gray | Agent spawn position (DEV_VISION) |

---

## Shadow Rendering Pipeline

### Calculation: `_bake_shadow_tiles()`

1. Query `_shadow_tiles` dictionary (populated by light calculations)
2. For each shadow cell: call `TileOverlayClass.shadow_color_for(mult)`
3. Map multiplier [0, 1] to 3-level gradient:
   - mult ≤ 0.35 → `shadow_full` (darkest)
   - 0.35 < mult ≤ 0.65 → `shadow_mid` (medium)
   - mult > 0.65 → `shadow_lite` (lightest)
4. Paint to `_tile_shadow` overlay with `PRIO_SHADOW`
5. Queue redraw

**Result:** Smooth 3-level shadow gradation instead of binary full/partial.

---

## Detection Cone Rendering

### Cone Visualization: `guard_enemy.gd`

**Per-Guard Drawing:**
```gdscript
func _draw_vision_tiles():
    ## For each tile in cone:
    var prob = get_detection_probability(tile)
    var color = _prob_to_color(prob, alpha_mult)
    ## Draw isometric diamond at tile position
```

**Color Mapping (Unified Palette):**
- **Green** (≤12%) — cone edge, minimal threat
- **Yellow** (35%) — agent entering cone
- **Orange** (55%) — high alert zone
- **Red** (>80%) — frontal focus, highest priority

**Alpha Modulation by State:**
- PATROL: alpha ≈ 0.4 (faint, relaxed cone)
- SUSPICIOUS: alpha ≈ 0.6
- ALERT: alpha ≈ 0.8
- CHASE: alpha = 1.0 (fully opaque, active threat)

---

## DEV_VISION Markers

### Entry/Exit Display

**Function:** `_apply_dev_vision()` in `room.gd`

When `dev_vision = true`:
- Paint all `_exit_cells` with `"exit"` palette (purple diamonds) at `PRIO_NAV`
- Paint `_agent_start_cell_base` with `"spawn_dev"` palette (gray marker) at `PRIO_DEV`

When `dev_vision = false`:
- Clear both `PRIO_NAV` and `PRIO_DEV` from `_tile_game`

**Visual Purpose:** Verify map exits, spawn point, and exit accessibility in editor.

---

## Blend Mode Semantics

### BLEND_MODE_MUL (Multiply)

**Formula:** `output = base_color × overlay_color`

**Properties:**
- Darkens only — white overlay is transparent
- Preserves texture detail underneath
- Good for shadows, darkening overlays

**Used For:**
- Shadow system (`_tile_shadow`)

**Example:** Shadow overlay with color (0.1, 0.2, 0.4) on tile (0.5, 0.5, 0.5) produces darkened blue tone.

### BLEND_MODE_MIX (Standard/Alpha Blend)

**Formula:** `output = overlay_color × overlay_alpha + base_color × (1 - overlay_alpha)`

**Properties:**
- Pure color blending, respects alpha transparency
- Can brighten or darken
- Vivid, saturated colors

**Used For:**
- Detection cones (`guard_enemy.gd` — `_vision_tiles_node`)
- Navigation markers (`_tile_game`)

**Example:** Detection overlay with color (1.0, 0.13, 0.13, 0.85) renders as vivid red over tile.

---

## Performance Considerations

### Priority Sorting

`_draw()` in `tile_overlay.gd` sorts entries by priority before rendering:

```gdscript
sorted.sort_custom(func(a, b): return a[1]["prio"] < b[1]["prio"])
```

**Lower priority drawn first** (rendered below, closer to tiles).

**Cost:** O(n log n) per frame, minimal for typical entry counts (<200 tiles).

### Alpha Culling

Entries with `alpha ≤ 0.01` are skipped during rendering:

```gdscript
if color.a <= 0.01:
    continue
```

Reduces draw calls for transparent/invisible entries.

---

## Future Extensions

### Planned (M2-15+):

- **Movement Preview Overlay** (PRIO_MOVEMENT): Pathfinding tiles highlighted
- **Objective Markers** (PRIO_NAV): Collectibles, targets
- **Lighting Radiosity** (PRIO_SHADOW): Dynamic ambient occlusion
- **Guard Alert Waves** (PRIO_DETECT): Expanding detection as reinforcements arrive
- **Noise Visualization** (PRIO_DETECT): Tile-based audio propagation heatmap

### Overhead Visual Engine (VIS-01)

Topmost (5th-floor) ceiling layer + **view occlusion**. Staged plan lives in
`docs/production/milestones.md` → **VIS-01**. Two pillars sharing one fade machine:

- **Ceiling layer** — `CeilingPropLayer` above wall storey N renders sprites/scenes
  (lamps, chandeliers, holofotes/spots, conduits, pipes, vents). Authored via a new
  `MapSpec.ceiling` key, perspective-rotated like every other layer.
- **View occlusion** — keep the agent readable under walls/ceiling via (1) directional
  storey cutaway keyed to `_active_perspective`, (2) proximity dither-cutout around the
  agent, (3) hover reveal, with the existing 4-way rotation as manual override.
  Principle: **fade, never delete** — cut walls must still read as cover.

> ⚠️ **Not to be confused with `docs/systems/occlusion.md`.** That doc is gameplay
> *occlusion semantics* (what blocks light / LoS / sound). VIS-01 *view occlusion* is
> a **camera/UX** concern (what the player can see). Different systems, same word.

---

## Configuration & Tweaking

### Shadow Calibration (`tile_overlay.gd`)

Adjust `shadow_color_for()` thresholds if shadows are too dark/light:

```gdscript
static func shadow_color_for(mult: float) -> Color:
    if mult <= 0.35:
        return PALETTE["shadow_full"]
    elif mult <= 0.65:
        return PALETTE["shadow_mid"]
    else:
        return PALETTE["shadow_lite"]
```

### Detection Color Tuning

Modify `PALETTE["detect_0"]` through `["detect_4"]` in `tile_overlay.gd` to adjust cone spectrum.

Alternatively, call `detect_color_for(prob)` in `guard_enemy.gd._prob_to_color()` for unified palette.

---

## References

- **Shadow System:** `docs/systems/lighting.md`
- **Detection Logic:** `docs/systems/perception.md`
- **Code:** `godot/scripts/overlays/tile_overlay.gd`
- **Integration:** `godot/scripts/world/room.gd`, `godot/scripts/agents/guard_enemy.gd`
