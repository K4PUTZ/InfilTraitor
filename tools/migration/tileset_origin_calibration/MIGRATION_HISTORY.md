# Tileset Origin Calibration — Migration History

> **Documentation of the M2.06 tileset asset transformation process.**

---

## Overview

During **M2.06 — Tactical Shadows System**, the isometric tileset underwent comprehensive transformation:

1. **Naming Convention Change:** Kenney naming (N/E/S/W) → Screen-space naming (SE/SW/NE/NW)
2. **Texture Origin Calibration:** Aligned all directional assets to consistent anchor points
3. **Corner Asset Expansion:** Expanded corner assets (256px → 320px) for visual consistency
4. **Isometric Projection Fix:** Corrected dimetric perspective (45°/26.57°)

---

## Problem Statement

### Initial State (Before M2.06)

```
❌ Inconsistent texture origins across directional variants
❌ Corner assets undersized (256×256) vs wall assets (256×528)
❌ Naming convention mismatch (Kenney vs project standards)
❌ Visual misalignment in isometric grid
```

### Root Causes

1. **Rapid Prototyping:** Assets directly from Kenney (minimal customization)
2. **Iterative Development:** Fixes applied ad-hoc, not systematically
3. **Missing Calibration:** No formal texture origin framework
4. **Scale Mismatch:** Different asset families at different sizes

---

## Solution Timeline

### Phase 1: Naming Standardization

**Script:** `rename_tiles.py`  
**Objective:** Convert Kenney directional naming to screen-space  

**Mapping:**
```
Kenney _N   → Screen-space _SE   (bottom-right of diamond)
Kenney _E   → Screen-space _SW   (bottom-left of diamond)
Kenney _S   → Screen-space _NW   (top-left of diamond)
Kenney _W   → Screen-space _NE   (top-right of diamond)
```

**Status:** ✅ Complete (all 88 variants renamed)

---

### Phase 2: Texture Origin Calibration

**Primary Script:** `update_texture_origins.py` (CANONICAL)  
**Objective:** Apply consistent anchor points to all directional variants  

**Calibrated Origins:**

**Standard Wall-Aligned (poleGroup, pole, window*, column*, doorway, crate, etc.):**
```
SE: (16, -392)      ← bottom-right anchor
SW: (16, -376)      ← bottom-left anchor
NE: (-16, -392)     ← top-right anchor
NW: (-16, -376)     ← top-left anchor
```

**Corner-Aligned (columnCorner, wallCornerHalf, slopers, stairs, etc.):**
```
SE: (0, -400)       ← center-bottom anchor
SW: (32, -384)      ← left-center anchor
NE: (-32, -384)     ← right-center anchor
NW: (0, -368)       ← center-top anchor
```

**Validation:** All 88 assets tested visually ✅

---

### Phase 3: Corner Asset Expansion

**Problem:** Corner assets (256×256) undersized vs walls (256×528)  
**Solution:** Expand corner canvas to 320×320 (maintain center anchor)

**Iterative Attempts:**

| Attempt | Script | Approach | Result |
|---------|--------|----------|--------|
| 1 | expand_all_corners.py | Simple width expand | ⚠️ Partial |
| 2 | fix_corner_origins.py | Add origin adjustment | ⚠️ Incomplete |
| 3 | expand_corner_assets.py | Canvas + origin compensation | ⚠️ Offset issues |
| 4 | expand_corner_pngs.py | PNG-level transformation | ⚠️ Format mismatch |
| 5 | fix_all_corners.py | Comprehensive direct replacement | ✅ Working |
| 6 | update_corners_sw_ne.py | SW/NE specific refinement | ✅ Final |

**Final Solution:** `update_corners_sw_ne.py` with proper texture region sizing

**Status:** ✅ Complete (all 40 corner variants expanded and calibrated)

---

### Phase 4: Wall-Specific Origins

**Script:** `fix_wall_origins.py`  
**Objective:** Verify wall origins (sanity check)  

**Result:** ✅ Confirmed all 18 wall variants correct

---

## Outcome

### Deliverables

✅ **Naming:** All 88 assets renamed (Kenney → screen-space)  
✅ **Origins:** All 88 assets calibrated (anchors aligned)  
✅ **Corners:** All 40 corner assets expanded (256 → 320)  
✅ **Walls:** 18 wall variants verified  
✅ **Tileset:** Live in `godot/resources/tilesets/tileset_blocks.tres`

### Visual Impact

- Shadows now project correctly (M2.11 validation)
- Corner assets align with walls
- Isometric grid appearance improved
- No visual clipping or misalignment

### Code Changes

**Total:** 4082 texture_origin entries updated  
**Process:** Regex-based, validated post-execution  
**Safety:** All changes reversible via git history

---

## Lessons Learned

### What Worked ✅

1. **Systematic Approach:** One problem per script (separation of concerns)
2. **Iterative Refinement:** Each attempt informed next version
3. **Validation:** Visual inspection + git history checkpoints
4. **Documentation:** Keeping PROGRESS.md updated

### What Was Inefficient ⚠️

1. **Multiple Attempts:** 6 iterations for corner expansion (could have planned better)
2. **Script Proliferation:** 10 scripts total (could consolidate)
3. **Naming:** Script names like fix_* vs update_* inconsistent
4. **No Rollback Plan:** Should have tagged git before large changes

### Takeaways 📝

1. **Pre-plan complex transformations** — Save iterations with upfront design
2. **Use feature branches** — For multi-step migrations
3. **Name scripts by phase** — Not by attempt (migration_phase_1.py not fix_v1.py)
4. **One transformation per script** — Easier to debug
5. **Document assumptions** — Next person needs to understand why

---

## How to Use This Archive

### For Future Asset Calibration

If similar issues arise:

1. **Read this document first** (understand the process)
2. **Review update_texture_origins.py** (canonical approach)
3. **Adapt, don't copy** (your problem may be different)
4. **Document your changes** (add to this file)

### For Rollback (Emergency)

If tileset is corrupted:

```bash
git log --oneline godot/resources/tilesets/tileset_blocks.tres
# Find commit before M2.06
git checkout <commit-before-m2.06> -- godot/resources/tilesets/tileset_blocks.tres
```

### For Understanding the Codebase

This archive shows:
- How dimetric projection works in Godot
- Texture origin anchor systems
- Asset calibration workflow
- Problem-solving iteration

---

## Future Asset Management

### Prevent Similar Issues

1. **Define origin standards** before adding new asset families
2. **Create origin validation script** (automate checks)
3. **Use git hooks** to validate tileset integrity
4. **Document asset requirements** (size, origin, scale)

### Proposed Workflow (Next Iteration)

```
New Assets
    ↓
validate_asset_origins.py (new script)
    ↓
Godot Tileset Preview
    ↓
Approve/Reject
    ↓
Commit with audit trail
```

---

## Reference Information

### Related Files

- **Process Documentation:** DEVELOPMENT/REFACTOR_SPRINT_04.md
- **Current Tileset:** godot/resources/tilesets/tileset_blocks.tres
- **Shadow System:** docs/systems/lighting.md
- **Asset Inventory:** ASSET_MAP.md

### Git References

- **Completion Tag:** `alpha-texture-origins-complete`
- **Main Commit:** `93936ab` (final validation)
- **Related PRs:** M2.06 shadow system documentation

---

**Archive Created:** 2026-06-12  
**Archive Type:** Migration Historical (no longer active)  
**Maintained By:** Architecture Team  
**Status:** Archived 🔴
