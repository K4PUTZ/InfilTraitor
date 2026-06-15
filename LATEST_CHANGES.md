# Latest Changes — 2026-06-14

## Summary

**6 commits implementing overlay separation and color alignment:**
- OVERLAY-SPLIT-01: Light Vision mode (L key) separated from Dev Vision (V key)
- EXPOSURE-COLOR-FIX-01: Realign overlay colors to 6-class enum
- Total: 2 new features, 1 bug fix, 2 refactored overlays

---

## 📋 Detailed Changes

### 1. Alpha Light Vision (Commit: 60a7201)

**Feature: OVERLAY-SPLIT-01 — Separate DEV VISION and LIGHT VISION**

**What Changed:**
- Added `var light_vision: bool = false` to room.gd (line 148)
- Added `_toggle_light_vision()` function (mirrors `_toggle_dev_vision` pattern)
- Added `_apply_light_vision()` function controlling 4 light overlays:
  - `_light_overlay` (light source visualization)
  - `_shadow_overlay` (shadow topology)
  - `_height_overlay` (height semantics)
  - `_temporal_overlay` (temporal state of lights)
- Refactored `_apply_dev_vision()` to control mechanics overlays only:
  - Guards visibility + dev state
  - `_exposure_overlay`, `_tile_risk_overlay`, `_elite_exposure_overlay`
  - Exit/spawn markers
- Updated FOW visibility in both functions: `fog_of_war.visible = not (dev_vision or light_vision)`
- Added KEY_L input handler to toggle light_vision

**Why:**
- Light debugging (L key) now independent from mechanics debugging (V key)
- Both can be active simultaneously for comprehensive analysis
- Clearer concern separation: tactical decisions (V) vs. light behavior (L)

**Acceptance:**
- ✅ light_vision flag present
- ✅ _toggle_light_vision() and _apply_light_vision() implemented
- ✅ 4 light overlays moved to _apply_light_vision()
- ✅ Mechanics overlays remain in _apply_dev_vision()
- ✅ FOW logic updated for both flags
- ✅ KEY_L handler added

**Files Modified:**
- `godot/scripts/world/room.gd` (+50 lines, -5 lines)

---

### 2. EXPOSURE-COLOR-FIX-01 (Commit: caa9add)

**Bug Fix: Realign overlays to 6-class enum**

**Problem:**
- ExposureSystem was expanded from 5 to 6 classes (added OCCLUDED_VOID=0, shifted others up by 1)
- `exposure_overlay.gd` still used old integer keys (4, 3, 2, 1, 0) → FULL_LIT rendered as dim
- `tile_risk_overlay.gd` guarded on `get_tiles_by_class(0)` → broke with new OCCLUDED_VOID

**Solution — exposure_overlay.gd:**
- Preload ExposureSystem class for access to constants
- Replace hardcoded integer keys with named enum values:
  ```
  EXPOSURE_SYSTEM_CLASS.FULL_LIT → Color(1.0, 1.0, 0.0, 0.6)      # Yellow
  EXPOSURE_SYSTEM_CLASS.DIM → Color(1.0, 0.6, 0.0, 0.6)           # Orange
  EXPOSURE_SYSTEM_CLASS.PENUMBRA → Color(0.3, 0.7, 1.0, 0.6)      # Blue
  EXPOSURE_SYSTEM_CLASS.SHADOW → Color(0.8, 0.4, 1.0, 0.6)        # Purple
  EXPOSURE_SYSTEM_CLASS.DEEP_SHADOW → Color(0.1, 0.1, 0.3, 0.6)   # Dark blue
  EXPOSURE_SYSTEM_CLASS.OCCLUDED_VOID → Color(0.02, 0.02, 0.05, 0.7) # Near-black
  ```
- Add guard in `_draw_exposure_tile()` to skip unknown classes

**Solution — tile_risk_overlay.gd:**
- Remove guard on `get_tiles_by_class(0)` 
- Let loop + `if risk > 0.0` decide rendering
- Overlay now draws correctly even when no OCCLUDED_VOID tiles exist

**Why:**
- Integer keys were brittle; enum changes broke colors
- Using named constants ensures maintainability
- Proper fallback prevents crashes on unknown classes

**Acceptance:**
- ✅ 6 mappings present: all enum classes to colors
- ✅ No get_tiles_by_class(0) in tile_risk_overlay
- ✅ 0 compilation errors
- ✅ FULL_LIT now renders as yellow (high risk center)
- ✅ Classes visually coherent with stealth risk

**Files Modified:**
- `godot/scripts/overlays/exposure_overlay.gd` (+14 lines, -2 lines)
- `godot/scripts/overlays/tile_risk_overlay.gd` (+1 line, -9 lines)

---

### 3. Shadowing Warning Fix (Commit: 06473e4 → 000339d)

**Issue:**
- GDScript warning: `ExposureSystem` constant shadowed global class
- Even with `const`, naming conflict triggered SHADOWED_GLOBAL_IDENTIFIER

**Solution:**
- Rename constant to `EXPOSURE_SYSTEM_CLASS` (UPPERCASE convention)
- Update all references: `EXPOSURE_SYSTEM_CLASS.FULL_LIT` etc.
- No functional change, pure naming cleanup

**Files Modified:**
- `godot/scripts/overlays/exposure_overlay.gd` (2 insertions, 2 deletions)

---

## 🔧 Technical Details

### Overlay Architecture After OVERLAY-SPLIT-01

```
V Key (DEV_VISION)                    L Key (LIGHT_VISION)
├── Guards.set_dev_vision()           ├── _light_overlay
├── Enemy visibility updates          ├── _shadow_overlay
├── Trail overlay                     ├── _height_overlay
├── _exposure_overlay                 └── _temporal_overlay
├── _tile_risk_overlay                
├── _elite_exposure_overlay           FOW (shared)
└── Exit/spawn markers                └── visible = not (dev_vision OR light_vision)
```

### Color Mapping After EXPOSURE-COLOR-FIX-01

| Enum | Value | Purpose | Color |
|------|-------|---------|-------|
| FULL_LIT | 5 | High detection risk | Bright yellow (1.0, 1.0, 0.0) |
| DIM | 4 | Moderate risk | Orange (1.0, 0.6, 0.0) |
| PENUMBRA | 3 | Low risk | Blue (0.3, 0.7, 1.0) |
| SHADOW | 2 | Minimal risk | Purple (0.8, 0.4, 1.0) |
| DEEP_SHADOW | 1 | Hidden | Dark blue (0.1, 0.1, 0.3) |
| OCCLUDED_VOID | 0 | Sealed niche | Near-black (0.02, 0.02, 0.05) |

All mapped via named constants (no magic numbers).

---

## ✅ Validation Results

**Compilation:** 0 errors, 0 warnings (after shadowing fix)

**Acceptance Tests:**
- ✅ OVERLAY-SPLIT-01: 6/6 requirements met
- ✅ EXPOSURE-COLOR-FIX-01: All class mappings present, no get_tiles_by_class(0)
- ✅ Light/dev overlays properly separated
- ✅ FOW responds to both vision flags
- ✅ Godot project loads without errors

**Godot Log Output:**
```
[Room] Exposure system rebuilt: full_lit=57, dim=67, penumbra=0, shadow=0, deep_shadow=0
[Room] Exposure system initialized with 3 light projections
[Room] Exposure overlay initialized
[Room] Tile risk heatmap overlay initialized
[Room] Elite exposure overlay initialized: [EliteExposureOverlay safe=0 total=124 confidence=0.90 depth_layers=6 stability_types=4]
```

---

## 🎯 Impact

### Gameplay/User Experience
- No direct gameplay impact (purely debug visualization)
- Developers now have clearer debugging modes for different concerns

### Architecture
- Overlay architecture more modular
- Enum-based color mapping more maintainable
- Foundation for future overlay systems (risk heatmap, noise visualization, etc.)

### Technical Debt Reduction
- Removed magic number dependencies
- Proper enum usage patterns established
- Shadowing warnings eliminated

---

## 📚 Related Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Updated implementation status
- [docs/systems/lighting.md](docs/systems/lighting.md) — 6-class enum definition
- [godot/scripts/overlays/](godot/scripts/overlays/) — All overlay implementations

---

## Next Tasks

- **AI-INT-01:** Integrate exposure multipliers into TicSystem detection
- **L-ARCH-04:** LOS occlusion with height semantics
- **M2-15:** Advanced overlays (movement preview, noise heatmap)
