# Design Decisions — Alpha Map Refactor (Prompts H & I)

> **June 14, 2026: Unified tile overlay system and detection cone migration. A synthesis of shadow rendering, visual consistency, and architectural clarity.**

---

## Executive Summary

This document captures the design decisions made during **Prompts H and I**, which unified the tile overlay architecture across INFILTRAITOR's visual systems.

**Commits:**
- `b32ded6` — Prompt H: TileOverlay integration into room.gd
- `78aa72f` — Prompt I: Detection cone migration
- `213becd` — Fix: GDScript declaration order

**Impact:** Reduced visual system complexity, unified color palettes, improved maintainability.

---

## Problem Statement

### Before Alpha Map Refactor

1. **Shadow Rendering:** Binary system (full/partial TileMapLayers) — no gradation, harsh visual
2. **Detection Cones:** Separate 7-band custom palette in `guard_enemy.gd` — inconsistent with planned systems
3. **Exit/Spawn Markers:** No unified framework for DEV_VISION overlays
4. **Code Fragmentation:** Shadow logic in `room.gd`, detection in `guard_enemy.gd`, each with custom rendering

### Root Cause

Lack of a **unified tile overlay abstraction**. Each visual system implemented its own Node2D + draw mechanics.

---

## Solution: Unified TileOverlay Architecture

### Decision 1: Create Abstract Overlay Class

**What:** `tile_overlay.gd` — reusable Node2D with:
- Independent entries dictionary (cell → {color, priority})
- Static palette system (PALETTE dict)
- Priority-based rendering (sorted before draw)
- Isometric diamond rendering

**Why:**
- **Consistency:** All overlays use same rendering pipeline
- **Reusability:** Shadow, detection, exits, objectives all use TileOverlayClass
- **Maintainability:** Single point for blend mode, alpha, and geometry logic

**Tradeoff:** Slight abstraction overhead (~15 lines per overlay instantiation).

### Decision 2: Blend Mode Selection

#### Shadow System → BLEND_MODE_MUL

**Decision:** Use multiply blending for shadows.

**Rationale:**
- Multiply preserves tile texture detail (colors darken but texture visible)
- Shadows are **subtractive** — reduce brightness, not replace color
- Blends naturally with colored tiles without visible seams

**Alternative Considered:** BLEND_MODE_MIX
- Would render opaque shadow overlay
- Would hide tile texture detail
- Rejected: Less visually appealing on detailed tiles

#### Detection Cone → BLEND_MODE_MIX

**Decision:** Changed from MULTIPLY to MIX for detection cones.

**Rationale:**
- Detection cones are **informational overlays** — need vivid, saturated colors
- MIX blend allows full color spectrum (green → red) to be visible
- Higher contrast than multiply-blended colors
- Matches player expectation of "warning indicator" (high visibility)

**Before (Multiply):** Detection colors appeared tinted/darkened over tiles
**After (Mix):** Detection colors appear vibrant and clear

### Decision 3: Unified Color Palette

#### Why 5-Band Detection Spectrum?

**Previous:** 7 custom bands in `_prob_to_color()`
```gdscript
if prob >= 0.95: c = Color(1.00, 0.13, 0.13)   # Red
elif prob >= 0.80: c = Color(1.00, 0.40, 0.00) # Orange dark
elif prob >= 0.55: c = Color(1.00, 0.63, 0.00) # Orange
elif prob >= 0.35: c = Color(1.00, 0.82, 0.00) # Yellow
elif prob >= 0.12: c = Color(0.78, 0.88, 0.00) # Yellow-green
elif prob >= 0.03: c = Color(0.50, 0.82, 0.00) # Light green
else: c = Color(0.25, 0.75, 0.00)              # Dark green
```

**New:** 5 unified bands in `detect_color_for(prob)` (TileOverlay)
```gdscript
detect_0: (0.25, 0.75, 0.00)  # prob ≤ 0.12  — edge
detect_1: (0.50, 0.82, 0.00)  # 0.12-0.35    — green
detect_2: (1.00, 0.82, 0.00)  # 0.35-0.55    — yellow
detect_3: (1.00, 0.40, 0.00)  # 0.55-0.80    — orange
detect_4: (1.00, 0.13, 0.13)  # prob > 0.80  — red
```

**Reduction Rationale:**
- 7 bands → 5 bands: Smoother interpolation with fewer thresholds
- Consolidates adjacent colors: yellow-green merged into green
- Simpler maintenance: 5 entries vs 7 conditionals
- Matches OSI/UML alert conventions (green → red)

**Validation:** Player can still distinguish all probability ranges. Spectrum remains smooth.

### Decision 4: Priority-Based Rendering

**What:** Each overlay tile entry has priority [1-5]:
- PRIO_SHADOW (1) — below all others
- PRIO_DETECT (2)
- PRIO_MOVEMENT (3)
- PRIO_NAV (4) — exits, objectives
- PRIO_DEV (5) — spawn marker, debug

**Why:**
- Prevents visual conflicts when overlays overlap
- Exits never covered by shadows or detection
- Spawn markers visible on top of everything in DEV_VISION
- Extensible: New priorities can be added without restructuring

**Implementation:** `_draw()` sorts by priority before rendering.

---

## Implementation Details

### Shadow System Migration

**Before (`room.gd`):**
```gdscript
shadow_full_layer.set_cell(shadow_cell, floor_sid, Vector2i.ZERO)
shadow_partial_layer.set_cell(shadow_cell, floor_sid, Vector2i.ZERO)
```

**After (`room.gd`):**
```gdscript
_tile_shadow.clear_priority(PRIO_SHADOW)
for shadow_cell: Vector2i in _shadow_tiles.keys():
    var mult: float = _shadow_tiles[shadow_cell]
    var shadow_color := TileOverlayClass.shadow_color_for(mult)
    _tile_shadow.paint(shadow_cell, shadow_color, PRIO_SHADOW)
```

**Benefits:**
- 3-level gradation instead of binary
- Blue-cool tones instead of neutral gray
- Texture detail preserved via multiply blend

### Detection Cone Migration

**Before (`guard_enemy.gd`):**
```gdscript
var mat_mul := CanvasItemMaterial.new()
mat_mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
_vision_tiles_node.material = mat_mul
```

**After (`guard_enemy.gd`):**
```gdscript
var mat_mix := CanvasItemMaterial.new()
mat_mix.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
_vision_tiles_node.material = mat_mix
```

**Function Simplification:**
```gdscript
# Before: 14 lines of conditionals
static func _prob_to_color(prob: float, alpha_mult: float = 1.0) -> Color:
    if prob >= 0.95: ...
    elif prob >= 0.80: ...
    ...

# After: 4 lines
static func _prob_to_color(prob: float, alpha_mult: float = 1.0) -> Color:
    var c: Color = TileOverlayClass.detect_color_for(prob)
    c.a *= alpha_mult
    return c
```

### DEV_VISION Markers

**New Feature:** In `_apply_dev_vision()`:

```gdscript
if dev_vision:
    _tile_game.set_cells_named(_exit_cells, "exit", PRIO_NAV)
    _tile_game.paint_named(_agent_start_cell_base, "spawn_dev", PRIO_DEV)
else:
    _tile_game.clear_priority(PRIO_NAV)
    _tile_game.clear_priority(PRIO_DEV)
```

**Purpose:** Quick visual debugging of exit points and spawn location.

---

## Testing & Validation

### Acceptance Criteria (All Passed)

✅ Project compiles without errors
✅ Shadow rendering displays 3-level gradation
✅ Detection cone renders with vivid colors (not tinted/dark)
✅ Green → yellow → orange → red gradient visible in cone
✅ DEV_VISION toggle shows/hides exit markers (purple) and spawn (gray)
✅ Guard behavior and detection logic unchanged
✅ State-based alpha transparency still works (PATROL < ALERT/CHASE)
✅ Perspective changes (N/S/E/W) update cone correctly

### Known Limitations

- **Shadow Visibility:** Shadows currently calibrated for placeholder assets. May need threshold adjustment for final tileset.
- **Detection Cone Alpha:** Currently fixed per state. Could be enhanced with distance-based fade.

---

## Future Directions

### M2-15: Advanced Overlays

- **Movement Preview** (PRIO_MOVEMENT): Pathfinding tiles highlighted
- **Objective Markers** (PRIO_NAV): Collectibles, interactive objects
- **Noise Heatmap** (PRIO_DETECT): Tile-based audio propagation visualization

### M3: Dynamic Shadow System

- Real-time light source calculation
- Multiple shadow layers (directional, falloff)
- Dynamic shadow LOD for performance

### M4: Guard Reinforcement Waves

- Expanding detection rings as alerts propagate
- Visual communication of guard state changes
- Temporal overlay animations

---

## Lessons Learned

1. **Abstraction Pays Off:** TileOverlayClass avoided code duplication across shadow, detection, and marker systems.

2. **Palette Consolidation:** 7 bands → 5 bands reduced conditional logic while maintaining visual clarity.

3. **Blend Mode Semantics:** MUL vs MIX have distinct purposes (shadow darkening vs information display). Wrong choice degrades visual feedback.

4. **Priority System:** Even simple (1-5) priority layers prevent visual conflicts and scale for future features.

5. **GDScript Order:** `class_name` must precede constants. Small detail, big compilation errors.

---

## References

- **Implementation:** `godot/scripts/overlays/tile_overlay.gd`
- **Integration:** `godot/scripts/world/room.gd` (Prompt H)
- **Detection:** `godot/scripts/agents/guard_enemy.gd` (Prompt I)
- **System Overview:** `docs/systems/rendering.md`
- **Commits:** `b32ded6`, `78aa72f`, `213becd`

---

## Sign-Off

**Decision Makers:** Mateus (Developer)
**Review Date:** 2026-06-14
**Status:** Implemented & Published (Alpha-Map-Refactor tag)
