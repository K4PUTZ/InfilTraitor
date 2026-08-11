# TARGETING_MASTER_PLAN
## Grenade targeting UI, throw arc, and planning flow — Phase B

**Date opened:** 2026-08-10  
**Status:** 🟢 **BUILT** — Tasks 1–4 land and the whole chain runs end to end
(G → aim → Enter → detonation), verified by real capture, not by description.
Phase A (detonation VFX) closed 2026-08-10. This plan describes the UI and
interaction layer that feeds Phase A.

**Evidence (hand-named, so the 50-file rotation cannot eat them):**
- `Screenshots/history/grenade_aim_dome.png` — dome, perimeter, up-arc and rays
- `Screenshots/history/grenade_throw_cooked.png` — the throw detonating at the
  aimed cell after its arc, bounce and cooking second
- `Screenshots/history/grenade_menu_detonate.png` — the restored right-click
  "Detonar" menu on a grenade already lying on the floor
- `Screenshots/history/grenade_throw_before.png` / `grenade_throw_after.png` —
  the same throw with and without the `get_physics_frame` fix

**Dev capture actions** (`INFILTRAITOR_CAPTURE_ACTION=`): `grenade_aim`,
`grenade_throw`, `grenade_cancel`, with `INFILTRAITOR_CAPTURE_AIM_CELL="x,y"`.

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

Everything below is measured in GAME UNITS and projected by `IsoProjection`
(`godot/scripts/world/utilities/iso_projection.gd`), never in hand-picked pixels.
Its basis is asserted against the real TileSet by `iso_projection_selftest.gd`.

- **Perimeter on floor**: red ellipse, radius `throw_range_gu` = 6.5 GU. The
  projection of a grid circle is exactly a 2:1 axis-aligned ellipse — derived,
  not eyeballed, and the same circle the throw's clamp tests against.
- **Dome** (E-BUBBLE): a hemisphere of `aim_dome_radius_gu` = **2.0 GU** sitting
  on the floor — Director, 2026-08-10: *"uma esfera seccionada pelo chão (e
  paredes próximas), como em XCOM"*, ref. `REFERENCES/granade.webp`. Drawn as the
  silhouette ellipse (181.0 × 183.8 px/GU — a sphere projects to very nearly a
  circle here) closed underneath by the floor section (181.0 × 90.5 px/GU). Both
  share their horizontal semi-axis, so the seam is exact.
  2.0 rather than 1.5 is deliberate and is asserted by the selftest: at exactly
  2.0 the rim passes through the centres of the cells two out along each axis,
  spilling past the 3×3 block — *"para indicar que a granada é meio imprecisa, e
  a região de dano se estende além das GUs, sem uma localização exata."*
  **Explicitly NOT the predicted damage footprint** — the Director ruled out
  showing the silhouette with its holes.
- **Shrapnel rays** (T-FRAG): LightRayOverlay's mechanism pointed at a grenade —
  lines from the target GU centre outward for every cell `flood_gu_rings()`
  reaches, so walls cut them the same way they cut the real blast. This is where
  cover shows; the dome promises nothing about it. Dark iron, two per cell,
  `length_scale` past the cell centre, and `circularity` = 1 undoes the 2:1
  isometric squash so the star reads round instead of flattened. The trade,
  stated: at full circularity a ray no longer ENDS on the cell it came from —
  it is a fragment's direction and reach, not a per-cell readout.
- **Throw arc**: parabola arcing UP (`arc_height_ratio` = 0.35 of the throw's
  screen distance), shared by the preview line and the sprite's own flight via
  `ThrowArcOverlay`'s statics, so the two cannot disagree.
- **Throw timing**: `throw_duration_s` 0.6 s flight, a light landing hop
  (`bounce_height_ratio` 0.12, `bounce_duration_s` 0.18), then
  `grenade_cook_s` = 1.0 s sitting on the ground before it goes off. The
  prediction finishes inside that cooking second.

---

## 5. Questions for Director — ANSWERED 2026-08-10

- **Throw range:** ~~derive from BombDef?~~ → a standalone `throw_range_gu` tuning
  var. It is a property of the thrower, not of the bomb's blast table; deriving
  it from `ring_multipliers.size()` was the first pass's mistake.
- **Perimeter style:** solid ellipse, red, kept. Widened 5.57 → 6.5 GU on the
  Director's *"poderia ser um pouquinho mais largo."*
- **Throw animation easing:** ~~open~~ → the arc IS the easing. It rises and
  falls, lands with a light hop, then holds.
- **Throw timing before detonation:** ~~open~~ → `grenade_cook_s` = 1.0 s on the
  ground, per *"antes de pausar para ficar 'cooking' por aprox. 1 segundo."*

---

## 6. Open

- **Wall sectioning of the dome.** The Director asked for a sphere sectioned by
  the floor *and by nearby walls*; only the floor section is built. Walls need
  the depth classification `FloatingCollectible` already uses
  (`VoxelRenderer.classify_geometry_over_rect()`, OcclusionSet policy O5) —
  `z_index` encodes HEIGHT in this project and cannot express "behind that wall
  but in front of this one".
- ~~The click-driven `test_zone_*` capture actions are dead.~~ **CLOSED
  2026-08-10.** `ecdae79` had removed the right-click → `open_menu_for()` path
  ("now G-key only"), taking `test_zone_menu` / `test_zone_detonate` /
  `test_zone_escape` with it. Restored on the Director's call — the two routes
  are not rivals: **G aims and throws a NEW grenade; right-click detonates one
  already lying on the floor**, which is what keeps the choreography and
  performance work testable. Proven by trace, not by eye
  (`grenade_index=0` → menu → Enter → `[E-PLAN] census gu=(3,5)`) plus
  `grenade_menu_detonate.png`.

---

## 7. Schedule

Tasks 1–4 are done. What is left is polish and the two items in §6:

1. Wall sectioning of the dome (the only part of the Director's brief not built).
2. Decide what the `test_zone_*` capture actions should drive now.
3. Throw feel — easing, a deliberate hold before detonation, landing bounce, SFX.

