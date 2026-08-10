# TARGETING_MASTER_PLAN
## Grenade targeting UI, throw arc, and planning flow — Phase B

**Date opened:** 2026-08-10  
**Status:** 🟡 **PLANNING**. Phase A (detonation VFX) closed 2026-08-10. This plan
describes the UI and interaction layer that feeds Phase A.

**Dependency:** `EXPLOSION_REBUILD_MASTER_PLAN.md` Phase A complete (E-RAY through
E-BUBBLE, commits d6dd657–3fba237). `PredictionCache` built
(`PREDICTION_MASTER_PLAN.md`, all 6 tasks). All mutation gates respect
`room.bump_world_revision()`.

---

## 1. Phase B Sequence

Restated from `EXPLOSION_REBUILD_MASTER_PLAN.md` §1 for clarity:

1. Player presses grenade button (right-click or long-touch)
2. **UI enters targeting mode** (this plan's Task 1–2)
   - Cursor locked to a GU, capped by throw range
   - Red perimeter on floor showing reachable GUs
   - Virtual bubble at cursor (E-BUBBLE wired)
   - Cancellable by ESC or backtrack
3. Player clicks/taps target GU → **grenade armed** (Task 3 – pre-production begins)
4. **Heavy compute window #1** — prediction cache finishes if not already done
5. **Throw animation** (Task 4)
   - Parabolic arc from player hand to target GU
   - Grenade lands at GU and sits for 1 s
6. **Heavy compute window #2** — final bake if multi-floor (deferred for Freelance)
7. **Phase A** fires (already built)

---

## 2. Tasks

| # | Task | Deliverable | Depends |
|---|------|-------------|---------|
| 1 | **T-MODE** | Targeting mode: cursor grid lock (throw range cap), context menu replaced by direct click/tap, visual feedback (red perimeter on floor) | — |
| 2 | **T-BUBBLE** | Wire E-BUBBLE to cursor position and bomb radius from BombDef, show during targeting mode | E-BUBBLE, T-MODE |
| 3 | **T-COOK** | Pre-production: `PredictionCache.request()` on "armed" (click), pump via budget loop while throw plays, ready for detonation | PredictionCache, T-MODE |
| 4 | **T-ARC** | Throw animation: 2D parabolic arc from player world position to target GU; lands and holds for 1 s before detonation (timing buffer for prediction if needed) | T-MODE, T-COOK (can run in parallel) |

Each task closes against Phase A's existing integration (test_zone_controller flow).

---

## 3. Known Integration Points

### Cursor / Input
- `SelectionController` drives cursor + right-click → `open_menu_for(index)` today
- **Change for Phase B:** direct grid-locked cursor to grenade target, no context menu
- Cancellation on ESC or backtrack (existing input paths)

### GU Selection
- Right-click today shows menu → "Detonar" → `TestZoneController.detonate_active()`
- **Phase B:** direct click/tap target GU → `TestZoneController._on_grenade_target_selected(target_gu)`
- Pre-production starts immediately (context menu replaced)

### Prediction Cache
- `TestZoneController._begin_preproduction(gu)` and `_pump_prediction()` already exist
- **Phase B wires:** armed click → start pump, finish before throw ends
- `_take_prediction()` already pulls from cache on detonate

### Detonation
- `TestZoneController._start_detonation_sequence()` already handles all beats
- **Phase B just feeds it:** call same method once throw finishes and prediction is done

### E-BUBBLE
- `room._aim_bubble_overlay.show_bubble(center, radius)` exists
- **Phase B wires:** show on targeting mode entry, update on cursor move, hide on cancel/arm

---

## 4. Visual Requirements

- **Perimeter on floor**: red line circle, radius = throw range (from BombDef), GU-grid resolution
- **Bubble**: already built (E-BUBBLE, translucent blue disc)
- **Throw arc**: visual only, 2D parabolic curve (or simple arc), player hand → landing GU
- **Throw animation timing**: ~0.5–0.8 s (measured, not configured initially; tuning pass after first working prototype)

---

## 5. Questions for Director

- **Throw range:** derive from BombDef? Fixed constant? Skill-scaled?
- **Throw animation:** easing curve preference? Linear, ease-in, ease-out?
- **Throw timing:** how long should the grenade sit before detonation? (1 s default in §1)
- **Perimeter style:** solid circle, dashed, segments? Colour intensity?

---

## 6. Schedule

**Next session:** T-MODE (Tasks 1–2 required for Phase B to be playable at all).  
**T-COOK and T-ARC** can start in parallel once T-MODE is land; they have independent audiences (compute flow vs. animation flow).

**Risk:** none identified. All dependencies are built.

