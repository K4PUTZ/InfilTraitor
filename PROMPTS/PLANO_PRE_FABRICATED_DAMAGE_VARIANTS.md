# PLANO: Pre-Fabricated Damage Variants (Swap-Based Destruction)

**Date:** 2026-08-04  
**Status:** Planning (awaiting Director sign-off)  
**Goal:** Replace runtime decal compositing with pre-baked damage voxels, eliminating runtime composition pipeline entirely.

---

## Problem Statement

**Current Architecture (Today):**
```
Explosion triggered
  → BlastCalculator computes damage per voxel
  → VoxelRenderer._set_damage_mark() composites decal onto baked atlas (PERF-02 A1/A2/A3)
  → VoxelLightField rebuilds light buckets (PERF-03)
  → GPU uploads textured pages
  → ~920ms total for detonation
```

**User Observation:** "O flow está esquisito, os frames não fluem naturalmente" + "flashes" suggest visual artifacts/hitches during decal compositing.

**Root Cause:** Runtime pixel compositing (decal onto baked atlas) happens during detonation, blocking render frames. Even with 78% speedup, the pipeline remains:
- Serial (one voxel mark after another)
- Expensive (baked image readback, pixel blending, re-upload)
- Visually jarring (color flashes from composite writes)

---

## Proposed Solution: ID-Swap Destruction

**Core Idea:**
Replace damage-state-based rendering + runtime decal compositing with **pre-fabricated voxel atoms**. During load, create and cache all damage variants; during detonation, simply swap tile IDs.

**Key Insight:** Voxels are discrete atoms (32×36px). Baking already creates them uniquely. The damaged versions (DENTED, CRACKED, DESTROYED + all blast/carved_side/variant combos) are *also* 32×36px atoms — they can be pre-baked too, then swapped by ID at runtime.

---

## Architecture: Three Phases

### Phase 1: Load-Time Pre-Fabrication

**When:** During `room_builder._bake_textures()` or new dedicated step.

**What:**
1. For every facade/material combination that gets baked, also pre-create damage variants with **soot intensity variations**:
   - **INTACT** (1 per material — clean)
   - **DENTED** (blast × 4 sides + bullet) × **3 soot intensities** = 5 × 3 = 15 per material
   - **CRACKED** (blast) × **3 soot intensities** = 1 × 3 = 3 per material
   - **DESTROYED** (1 per material — hole, no soot variation needed)
   
   **Total per material: 1 + 15 + 3 + 1 = ~20 atoms per material, × 4 wall materials = ~80 baked atoms**
   
2. Store each variant as a discrete baked voxel atom (32×36px) on the atlas pages.

3. Build a **Voxel Variant Dictionary** for each cell:
   ```gd
   # Key: (cell_pos, level, edge_id, material_id)
   # Value: {
   #   intact_id: source_id,        # Current baked atlas cell ID
   #   cracked_ids: [source_id, source_id, source_id],  # 3 soot intensities
   #   dented_ids: {                # Pre-baked DENTED atoms (all sides + bullet)
   #     "blast_top_0": [source_id, source_id, source_id],
   #     "blast_top_1": [source_id, source_id, source_id],
   #     "blast_top_2": [source_id, source_id, source_id],
   #     "blast_left_0": [...],
   #     ...,
   #     "bullet_0": [source_id, source_id, source_id],
   #   },
   #   destroyed_id: source_id      # Hole (invisible/transparent)
   # }
   ```
   
   **Soot intensity** is selected at destruction time: `randi() % 3` picks which variant to render.

4. Store this dictionary on `voxel_renderer` or a new `VoxelVariantRegistry` singleton.

**Output:** 
- All damage variants (with soot diversity) pre-registered on the tileset (0 runtime composition).
- Dictionary ready for O(1) ID lookup + soot randomization during detonation.

---

### Phase 2: Runtime ID-Swap Destruction (Single-Frame, No D11 Choreography)

**When:** Detonation occurs.

**What:**
1. **Remove** the D11 three-stage choreography entirely:
   - Delete `begin_destruction_vfx_capture()` / `flush_destruction_vfx()` frame-throttling logic
   - Delete `_repaint_voxel_light_buckets()` calls (light is now static, pre-baked)
   - Delete staged render passes (DESTROYED frame 1 → DENTED frame 2 → CRACKED frame 3 → smoke frames 4+)
   - Delete alternating red/yellow/smoke flash frames

2. **Keep only the white flash:**
   - Full-screen white flash at detonation start
   - Tween down to normal over ~0.3-0.5s (as before)
   - This is the only visual feedback; everything else is instant

3. **New destruction flow (single frame):**
   ```gd
   # Old (today, D11 choreography):
   # Frame 1: set_destroyed() → voxel.visible = false
   # Frame 2: set_dented() → voxel_renderer._set_damage_mark() → pixels composed
   # Frame 3: set_cracked() → voxel_renderer._set_damage_mark() → pixels composed
   # Frame 4+: smoke/soot/red/yellow flashes
   
   # New (ID-swap, single frame):
   # All at once:
   #   voxel.set_damage(DENTED, blast, side, variant)
   #   → lookup variant_dict[voxel_pos].dented_ids[key]
   #   → soot_variant = randi() % 3  # Random soot intensity
   #   → tilemap.set_cell(voxel_pos, dented_ids[key][soot_variant], coords, 0)
   #   → DONE (no compositing, no light rebuild, no frame delays)
   ```

4. **Update destruction callers:**
   - `BlastCalculator.apply_damage()` calls new `voxel_renderer.apply_damage_voxel_swap()`
   - New function does one `set_cell()` per voxel with randomized soot variant
   - All voxels updated in a single render frame
   - No staged choreography

5. **Persist damage state as before:**
   - `room._base_damage` dict still stores `{voxel_pos: damage_state, blast, side, variant}`
   - On camera rotation, re-apply by looking up correct ID with same random seed (deterministic)
   - No re-baking, just tile ID swap (same as detonation)

---

## Benefits of Single-Frame Model

- **No strobing:** All damage visible instantly, no frame-by-frame strobe effect
- **Flow:** Explosion feels instantaneous (damage applied), white flash tweens normally
- **Simplicity:** One render pass, no D11 choreography complexity

---

### Phase 3: Cleanup & Integration

**Remove:**
- `damage_composite_cache.gd` (entire PERF-02 cache structure)
- `DecalCompositorClass` / decal runtime pixel logic
- `HalfVoxelCompositorClass` / polygon mask writes
- `_set_damage_mark()` function
- `flush_damage_composite_pages()` call in room/TIC cycle
- PERF-03 light-rebuild invalidation (light buckets now pre-computed during bake, not rebuilt)
- **D11 three-stage choreography: `begin_destruction_vfx_capture()`, `flush_destruction_vfx()`, staged render passes**
- **Alternating red/yellow/smoke flash sequences**
- **`_repaint_voxel_light_buckets()` calls during detonation**

**Keep (but simplify):**
- `VoxelRenderer.render_frame_budget_ms` — may be much higher now (no compositing bottleneck), or can be removed
- `room._base_damage` dict — persists damage for rotation (now with soot-variant seed)
- `Voxel.damage_state` — still tracks state logically for game logic
- **White flash + tween** — only visual effect during detonation

**New:**
- `VoxelVariantRegistry` — O(1) lookup for (voxel_pos, damage_state, blast, side, variant) → (ID list with soot variants)
- `apply_damage_voxel_swap()` function — single-frame damage application via tile ID swap

---

## Benefits Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Detonation cost** | ~920ms (compositing + light rebuild) | ~50-100ms (pure tile ID swaps) |
| **Visual quality** | Color flashes, frame strobing, jarring composition | Instant crisp damage marks, zero strobing |
| **Flow** | Jerky, D11 three-stage choreography (3+ frames blocked) | Smooth, single-frame application, white flash tween only |
| **Soot variety** | Single mark per damage state | 3 soot intensities per damage type |
| **Code complexity** | Decal/light-rebuild pipeline + D11 staging | Simple dictionary lookups |
| **GPU overhead** | Repeated readbacks + uploads | Zero (all pre-baked) |
| **Memory** | Per-room decal cache + D11 state | All variants on atlas (~20 atoms per material) |

---

## Implementation Strategy

### Step 1: Audit Current Baking
- Understand exactly what `BakeCompositor` creates
- Identify where baked atlas pages are allocated
- Find insertion point for variant pre-creation

### Step 2: Extend BakeCompositor / room_builder
- For each facade/material → also render CRACKED, DENTED (all sides/variants), DESTROYED
- Register all on tileset during load
- Build variant dictionary

### Step 3: Rewrite Destruction Path
- Update `BlastCalculator.apply_damage()` to call new `voxel_renderer.swap_voxel_id()`
- `swap_voxel_id()` does one `tilemap.set_cell()` per voxel
- Remove all compositing calls

### Step 4: Validate
- Selftests confirm all damage variants pre-exist
- Destruction produces zero render flashes
- Rotation re-applies damage correctly
- `project_lint.py` and `run_selftests.py` pass

### Step 5: Clean & Commit
- Remove dead code
- Update CLAUDE.md if any new architectural rules
- Commit

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Baking becomes more complex** | Longer load time, higher mem | Profile; make variant pre-bake optional (config toggle) |
| **Variant dict lookup miss** | Voxel renders as INTACT instead of damaged | Fallback: simple damage_state→ID formula; exhaustive selftest |
| **Rotation reapply fails** | Damage lost on camera turn | Test explicitly; variant dict persists across rotation |
| **Light system breaks** | Loss of dynamic lighting on damage | Pre-compute soot/light in bake; validate visually |
| **Savegame breaks** | Old saves can't load | Keep `_base_damage` format; only add variant IDs (non-breaking) |

---

## Questions for Director

1. **Acceptable memory cost?** All variants (CRACKED, DENTED×12, DESTROYED) per facade = ~10-20% more atlas space per map. OK?
2. **Pre-bake all variants, or make it optional?** (i.e. `BakeConfig.pre_bake_damage_variants` toggle)
3. **Accept removal of lighting rebuild?** Soot/brightness changes will be static per variant, not dynamic per position.
4. **Timeline:** Full implementation, or proof-of-concept on one map (e.g., PLAYGROUND)?

---

## Estimated Scope

- **Phase 1 (Pre-fabrication + soot variants):** 4–6 hrs (baking logic extension, soot generation)
- **Phase 2 (ID-swap destruction, remove D11):** 3–4 hrs (new swap logic, choreography removal)
- **Phase 3 (Cleanup):** 2–3 hrs (dead-code removal, decal/light-rebuild cleanup)
- **Validation & fixes:** 2–4 hrs (unforeseen issues)
- **Total:** 11–17 hrs (1.5–2 full days)

---

## Success Criteria

- [ ] Detonation < 100ms (90%+ improvement over 920ms)
- [ ] Zero visible strobing / color flashes during explosion
- [ ] Only white full-screen flash + normal tween (no red/yellow/smoke flashes)
- [ ] All 29 selftests pass
- [ ] `project_lint.py` zero errors
- [ ] Damage persists through camera rotation (using deterministic soot seed)
- [ ] Soot variants add visual richness (no identical damage marks side-by-side)
- [ ] Savegame load/save unaffected

---

## Director's Decisions (2026-08-04)

✅ **Decision 1: Soot Variants**  
- Yes: All DENTED/CRACKED will have 3 soot intensity variations (no soot / medium / heavy)
- Yes: Include bullet marks (full damage decals + soot)
- All pre-baked during load, swapped randomly at detonation for visual richness

✅ **Decision 2: Memory Cost**  
- Acceptable: ~80-100 baked atoms per material (3 soot × 45 decals / ~1.5 materials) = small
- Fits well within one atlas page

✅ **Decision 3: Scope**  
- Full implementation (not proof-of-concept)

✅ **Decision 4: Choreography Removal**  
- Remove D11 three-stage frame choreography entirely
- Remove red/yellow/smoke alternating flashes
- Keep only white full-screen flash + normal tween (existing behavior)
- Detonation becomes single-frame: all voxels swap IDs at once

---

## Next: Proceed to Implementation

Ready to begin Phase 1 (pre-fabrication + soot generation).
