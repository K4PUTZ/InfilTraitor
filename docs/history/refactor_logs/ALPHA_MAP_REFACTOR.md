# Refactoring Sprint — Alpha Map Refactor

**Date:** June 14, 2026  
**Status:** ✅ Complete & Published — Unified overlay system + detection cone migration  
**Release Tag:** `Alpha-Map-Refactor`  
**Commits:**
- `b32ded6` — Prompt H: TileOverlay system integration into room.gd
- `78aa72f` — Prompt I: M2-TILE-CONE migration (detection cone to TileOverlay palette)
- `213becd` — Fix: Move TileOverlayClass preload after class_name

---

## Overview

This refactor unified INFILTRAITOR's visual overlay system under a single abstraction (`TileOverlayClass`), migrating shadows and detection cones to consistent palettes and blend modes.

**Impact:**
- ✅ Reduced code duplication (shadow + detection rendering)
- ✅ Unified color palettes (7-band → 5-band detection spectrum)
- ✅ Improved visual clarity (MUL for shadows, MIX for detection)
- ✅ Foundation for future overlays (movement preview, objectives, noise heatmap)
- ✅ Better maintainability (single point for blend modes, priorities)

---

## Deliverables

### 1. Unified Overlay Architecture

**File:** `godot/scripts/overlays/tile_overlay.gd` (173 lines)

**Features:**
- Abstract Node2D with entries dictionary: `Vector2i → {color, priority}`
- Static palette system: PALETTE dict with 13 color entries
- Priority-based rendering: PRIO_SHADOW (1) through PRIO_DEV (5)
- Isometric diamond geometry: TILE_HW=128, TILE_HH=64
- Static utility functions: `shadow_color_for()`, `detect_color_for()`
- Methods: `paint()`, `paint_named()`, `clear_priority()`, `set_cells_named()`, `queue_redraw()`

**Blend Modes:**
- Multiply: Shadows (darkens, preserves texture)
- Mix: Detection, exits, markers (vivid, saturated)

**No Dependencies:** Fully self-contained, reusable across any Node2D parent.

### 2. Shadow System Migration

**File:** `godot/scripts/world/room.gd`

**Changes:**
- Added: `var _tile_shadow: Node2D` (z_index=1, BLEND_MODE_MUL)
- Migrated: `shadow_full_layer` + `shadow_partial_layer` (TileMapLayers) → `_tile_shadow` (TileOverlay)
- Updated: `_bake_shadow_tiles()` — uses `TileOverlayClass.shadow_color_for(mult)` for 3-level gradation
- Added: `setup()` call to `_tile_shadow` with floor_layer reference

**Before:** Binary shadow (full/partial), gray tone, TileMapLayer rendering
**After:** 3-level gradation (shadow_full/mid/lite), blue-cool tone, multiply blend, overlay system

**Result:** Smooth shadow gradient with texture preservation.

### 3. Detection Cone Migration

**File:** `godot/scripts/agents/guard_enemy.gd`

**Changes:**
- Added: `const TileOverlayClass = preload("res://godot/scripts/overlays/tile_overlay.gd")`
- Changed: `BLEND_MODE_MUL` → `BLEND_MODE_MIX` in `_vision_tiles_node`
- Simplified: `_prob_to_color()` — replaced 7-band conditionals with `TileOverlayClass.detect_color_for(prob)`
- Code reduction: 14 lines → 4 lines

**Before:** Multiply-blended detection cone, 7 custom color bands, tinted/darkened appearance
**After:** Mix-blended detection cone, 5 unified bands, vivid spectral colors (green → red)

**Result:** High-contrast detection visualization matching standardized palette.

### 4. DEV_VISION Markers

**File:** `godot/scripts/world/room.gd`

**Features:**
- Exit cells: Purple diamond markers (PRIO_NAV) visible when `dev_vision=true`
- Spawn position: Gray marker (PRIO_DEV) visible when `dev_vision=true`
- Automatic cleanup: Clear both priorities when `dev_vision=false`

**Purpose:** Quick visual debugging of map exits and spawn point.

---

## Palette System

### Color Consolidation

| System | Before | After | Rationale |
|--------|--------|-------|-----------|
| Detection | 7 bands | 5 bands | Smoother gradient, fewer thresholds |
| Shadow | 2 levels (binary) | 3 levels (gradation) | Better visual fidelity |
| Navigation | N/A | 2 entries (exit, spawn) | New feature for DEV_VISION |

### 5-Band Detection Spectrum

```
detect_0: (0.25, 0.75, 0.00)  — prob ≤ 0.12    Green, cone edge
detect_1: (0.50, 0.82, 0.00)  — 0.12-0.35      Light green
detect_2: (1.00, 0.82, 0.00)  — 0.35-0.55      Yellow
detect_3: (1.00, 0.40, 0.00)  — 0.55-0.80      Orange
detect_4: (1.00, 0.13, 0.13)  — prob > 0.80    Red, frontal focus
```

---

## Priority Layering

### PRIO Constants

| Priority | Layer | Usage |
|----------|-------|-------|
| PRIO_SHADOW (1) | Below | Shadows (multiply blend) |
| PRIO_DETECT (2) | Reserved | Future: detection heatmap |
| PRIO_MOVEMENT (3) | Reserved | Future: pathfinding preview |
| PRIO_NAV (4) | Above | Exits, objectives |
| PRIO_DEV (5) | Top | Spawn marker, dev-only |

**Rendering:** `_draw()` sorts by priority, lower drawn first (below higher).

---

## Verification & Testing

### Acceptance Criteria (All Passed ✅)

- ✅ Project compiles without errors
- ✅ Shadow rendering displays 3-level gradation (blue-cool tone)
- ✅ Detection cone renders with vivid colors (green → red spectrum)
- ✅ Exit markers visible in DEV_VISION (purple diamonds)
- ✅ Spawn marker visible in DEV_VISION (gray, PRIO_DEV)
- ✅ Guard behavior unchanged (detection logic functional)
- ✅ State-based alpha transparency works (PATROL ≈ 0.4, ALERT/CHASE = 1.0)
- ✅ Perspective changes update cone correctly

### Known Limitations

- **Shadow Visibility:** Shadows calibrated for placeholder assets. May need threshold adjustment for final tileset (Prompt J pending).
- **Detection Cone Alpha:** Fixed per state. Could be enhanced with distance-based fade in future iterations.

---

## Code Quality Metrics

| Metric | Value |
|--------|-------|
| Files Modified | 3 (tile_overlay.gd, room.gd, guard_enemy.gd) |
| Lines Added | ~250 |
| Lines Removed | ~50 |
| Net Growth | ~200 (acceptable for new feature) |
| Duplication Reduced | ~40 (shadow + detection rendering) |
| Cyclomatic Complexity | ↓ (unified palette reduces conditionals) |

---

## Documentation

### New Docs Created

1. **`docs/systems/rendering.md`** — Complete rendering system overview
   - TileOverlay architecture, blend modes, palettes
   - Shadow rendering pipeline, detection cone visualization
   - DEV_VISION markers, performance considerations
   - Future extensions (M2-15+)

2. **`docs/technical/design-decisions-alpha-refactor.md`** — Design decision log
   - Problem statement (fragmentation, inconsistency)
   - Solution architecture (unified overlays)
   - Blend mode semantics (MUL vs MIX)
   - Palette consolidation rationale (7 → 5 bands)
   - Implementation details, testing results, lessons learned

---

## Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| **Prompt G** (tile_overlay.gd creation) | June 13 | ✅ Complete |
| **Prompt H** (room.gd integration) | June 14 | ✅ Complete |
| **Prompt I** (guard_enemy.gd migration) | June 14 | ✅ Complete |
| **Syntax Fix** (GDScript order) | June 14 | ✅ Complete |
| **Documentation** (rendering.md, decisions) | June 14 | ✅ Complete |
| **Publication** (Alpha-Map-Refactor tag) | June 14 | ✅ Complete |

---

## Next Steps

### Immediate (Next Session)

- **Prompt J:** Shadow System Calibration
  - Adjust `shadow_color_for()` thresholds for visibility
  - Test against final tileset
  - Verify multiply blend doesn't darken too much

### Short-term (M2)

- **Prompt K:** Visual Polish
  - Detection cone anti-aliasing (optional, if needed)
  - Smooth transitions between alpha states
  - Additional cone customization per guard type

- **M2-15:** Advanced Overlays
  - Movement preview (PRIO_MOVEMENT)
  - Objective markers (PRIO_NAV)
  - Noise heatmap (PRIO_DETECT)

### Medium-term (M3)

- Dynamic shadow system with multiple light sources
- Real-time light propagation
- Guard alert wave visualization

---

## References

### Code

- `godot/scripts/overlays/tile_overlay.gd` — Unified overlay architecture
- `godot/scripts/world/room.gd` — Shadow system integration, DEV_VISION markers
- `godot/scripts/agents/guard_enemy.gd` — Detection cone migration

### Documentation

- `docs/systems/rendering.md` — Rendering system overview
- `docs/technical/design-decisions-alpha-refactor.md` — Design decisions & rationale
- `docs/systems/perception.md` — Detection logic (unchanged)
- `docs/systems/lighting.md` — Shadow calculations (unchanged)

### Commits

- `b32ded6` — Prompt H: TileOverlay system integration
- `78aa72f` — Prompt I: M2-TILE-CONE migration
- `213becd` — Fix: GDScript declaration order
- `daf8df6` — SIGMA-01 Prompt G: TileOverlay.gd creation (predecessor)

---

## Approvals

**Developer:** Mateus  
**Date:** June 14, 2026  
**Status:** ✅ Published (Alpha-Map-Refactor tag + push to main)
