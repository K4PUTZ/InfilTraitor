# TARGETING_MASTER_PLAN
## Grenade targeting UI, throw arc, and planning flow — Phase B

**Date opened:** 2026-08-10  
**Status:** 🟢 **BUILT** — Tasks 1–4 land and the whole chain runs end to end
(G → aim → Enter → detonation), verified by real capture, not by description.
Phase A (detonation VFX) closed 2026-08-10. This plan describes the UI and
interaction layer that feeds Phase A.

**Evidence (hand-named, so the 50-file rotation cannot eat them):**
- `Screenshots/history/grenade_aim_dome.png` — dome, hatched footprint, grenade
  marker, up-arc and rays
- `Screenshots/history/grenade_aim_wide.png` — the same, zoomed out far enough
  to see the whole 7 GU throw perimeter
- `Screenshots/history/grenade_throw_cooked.png` — the throw detonating at the
  aimed cell after its arc, bounce and cooking second
- `Screenshots/history/grenade_menu_detonate.png` — the restored right-click
  "Detonar" menu on a grenade already lying on the floor
- `Screenshots/history/grenade_aim_gameplay_hud.png` — the PLAYER's view, dev
  vision off: dome, rays, virtual grenade, arc, and neither red perimeter
- `Screenshots/history/grenade_flight_tumble.png` — three points of one flight
- `Screenshots/history/grenade_throw_before.png` / `grenade_throw_after.png` —
  the same throw with and without the `get_physics_frame` fix

**Dev capture actions** (`INFILTRAITOR_CAPTURE_ACTION=`): `grenade_aim`,
`grenade_throw`, `grenade_cancel`, `grenade_tap`, `grenade_second`. Modifiers:
`INFILTRAITOR_CAPTURE_AIM_CELL="x,y"` and `INFILTRAITOR_CAPTURE_NO_DEV=1`.

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

**What the PLAYER sees vs. what the DEVELOPER sees** (T-DEV, Director
2026-08-10): *"tanto o perímetro vermelho do alcance, quanto o perímetro
vermelho do dano, vamos deixar ativos só no DEV VISION. Durante o gameplay
normal o HUD só vai mostrar a bolha, os raios, e a granada virtual."*

| | normal | dev vision |
|---|---|---|
| aim dome, shrapnel rays, virtual grenade, throw arc | ✅ | ✅ |
| red throw perimeter | — | ✅ |
| red damage footprint (affected GUs) | — | ✅ |

Both reds are exact, legible diagrams of numbers the player is not meant to be
reading off the board — the throw's radius in cells and the blast's cell list.
The dome and the rays say the same two things approximately, which is the point.
The **clamp is unaffected** by the toggle: the range is real either way, only the
line drawing it is a dev instrument.

`dev_vision` defaults to TRUE in this build (ROTATE-KILL-01), so the harness
shows the developer's view unless told otherwise —
`INFILTRAITOR_CAPTURE_NO_DEV=1` presses V first, which is the only way to
capture the player's HUD.

**The throw arc is kept in normal play**, and that is a judgement call worth
flagging rather than burying: it is not one of the three things the Director
listed, but it is also not a perimeter, it is the only thing that shows whether
the throw clears the geometry in between, and its physics were tuned across two
passes. One line in `_set_targeting_target()` moves it behind the same gate if
that reading was wrong.

Everything below is measured in GAME UNITS and projected by `IsoProjection`
(`godot/scripts/world/utilities/iso_projection.gd`), never in hand-picked pixels.
Its basis is asserted against the real TileSet by `iso_projection_selftest.gd`.

- **Perimeter on floor**: red ellipse, radius `throw_range_gu` = **7 GU**. The
  projection of a grid circle is exactly a 2:1 axis-aligned ellipse — derived,
  not eyeballed, and the same circle the throw's clamp tests against.
  **The radius must stay a WHOLE number** — *"o perímetro precisa passar pelo
  centro das últimas GUs que o arremesso alcança."* Cell centres only sit at
  integer offsets, so a fractional radius draws a perfectly good ellipse
  through empty space between two rings. Asserted by selftest [9], including
  the counter-case (nothing is on a 6.5 GU rim, anywhere on the board).
- **Affected GUs** (T-FILL): the footprint of `flood_gu_rings()` outlined at the
  base of the dome and filled red, graded per ring — *"assim como no Phoenix
  Point, vamos realçar as GUs afetadas pela granada, para indicar quais inimigos
  vão ser atingidos"*, then *"pintar o interior do perímetro de vermelho com
  opacidades variadas, usando o mesmo mecanismo visual que estamos usando para
  indicar o perímetro de movimentação do agente."* That mechanism is
  `MovementOverlay`'s flat per-diamond `draw_colored_polygon` under the outline;
  here the grade is by blast ring instead of by AP cost. Same
  `BlastWireframeOverlay` the right-click menu already used — the fill only
  turns on when a caller passes ring data, so its two older callers are
  unchanged. (An earlier hatch attempt was rejected and removed.)
  **Rings that do no damage are excluded.** `flood_gu_rings()` caps at
  `ring_multipliers.size() - 1` because that array's length IS the bomb's range,
  but `frag_grenade`'s outermost entry is `0.0` with every per-tier weight zero
  too — reached, and harmless. Drawing it claimed one GU more than the blast
  delivers (*"o perímetro vermelho da granada no chão está muito largo, vamos
  reduzir uma GU no raio"*). `_damaging_rings()` trims by damage rather than by
  a hardcoded −1, so a bomb whose outer ring does bite keeps it.
- **Target marker** (T-CURSOR): `SelectionOverlay`'s magenta diamond is hidden
  for the duration of the throw and a **virtual grenade** stands on the target
  cell instead — `GrenadeProp`'s own baked frames, through its
  `load_color_frames()` rather than a second path constant, per *"exibir o
  verdadeiro asset da granada, já que vamos ter outros tipos de explosivos.
  Carregue dinamicamente o que quer que tenha sido definido como granada."*
  A hand-drawn silhouette beside a baked prop is two definitions of one object;
  the second explosive type is when they drift. It mirrors the prop's anchoring
  and per-view frame swap, so the preview stands exactly where the throw lands.
  `virtual_grenade.gdshader` is what separates them: 50% red overlay, 2 px red
  stroke round the silhouette, 2 px diagonal red hatch across it meeting the
  stroke on both sides. Sizes are in TEXTURE pixels — the sprite is scaled by
  `SPRITE_SCALE` and again by camera zoom, so screen-space widths would need the
  live zoom every frame and would still read differently at every zoom level.
- **Confirm by tap** (T-TAP): with the throw being aimed, the left button
  belongs to it — the first click aims, a second on the **same** GU throws,
  identical to Enter. *"Um segundo clique/tap na GU que está com a bolha marcada
  dispara a bomba."* This is what makes the flow work with no hover at all, and
  is `PREDICTION_MASTER_PLAN` §4.2's own trigger ("hover, or first tap on a GU
  for mobile"). The comparison is on the CLAMPED cell, so two taps beyond the
  perimeter both resolve to the same edge cell and the second still fires.
- **Draw order** (T-Z): *"os raios laranjas precisam ficar por cima do perímetro
  vermelho. A granada virtual fica por cima dos raios."* The aiming overlays hold
  absolute slots `Room.AIM_Z_FOOTPRINT` … `AIM_Z_GRENADE` (100–105) rather than
  `max_voxel_z_index + n`. That is the fix, not a tidy-up: the footprint has
  always been at a flat 100, while the rest rode a few ticks above the tallest
  voxel — nowhere near 100 — so the footprint drew over everything regardless of
  their relative order.
- **Dome** (E-BUBBLE), ORANGE since 2026-08-10 (*"vamos mudar a arte bolha de
  azul para laranja"*), which also puts it in the same family as the shrapnel
  rays instead of reading as a separate, cooler UI element: a hemisphere of
  `aim_dome_radius_gu` = **2.0 GU** sitting
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
  cover shows; the dome promises nothing about it. Orange-red, three per cell,
  `length_scale` = 1.7 past the cell centre so they clearly overshoot the dome,
  `circularity` = 1 undoes the 2:1 isometric squash so the star reads round, and
  `lateral_scale` buys a little extra width back on top.
  **`rays_per_cell` is not the spoke count.** The BFS reaches 12 cells but they
  point in only EIGHT distinct screen bearings — `(1,0)` and `(2,0)` are the same
  direction at different lengths, likewise the other three axis pairs, and ring
  2's four diagonals supply up/down/left/right. The fan exists to fill the 45°
  gaps between those eight, so `spread_rad` must be sized against that gap:
  3 rays 15° apart span 30° of each 45°, which is near-even. Raising the count
  without opening the spread to match just makes eight tight bundles. They leave from `ray_origin_lift_gu` above the floor
  (roughly where the grenade sits) and `ground_brake` shortens the ones aimed
  downward, since the floor is in the way on that side. The trade, stated: at
  full circularity a ray no longer ENDS on the cell it came from — it is a
  fragment's direction and reach, not a per-cell readout. The per-cell readout
  is the hatched footprint above.
- **Throw arc**: a real BALLISTIC path (`arc_height_ratio` = 0.35 of the throw's
  screen distance sets the apex), shared by the preview line and the sprite's own
  flight via `ThrowArcOverlay`'s statics, so the two cannot disagree. It leaves
  `DebugAgent.throw_origin()` — the head marker's own height, roughly where the
  hands are (*"vamos subir para sair mais ou menos da bolinha branca (...) que
  vai corresponder à altura dos braços"*), not the cell centre at the agent's
  feet. Crouching and prone throws start lower for free, because the offsets are
  the same const `_draw()` places the marker with.
  On *"desacelerar a granada até o ápice da parábola, e acelerar até o chão"*:
  constant gravity already did that — a `4·h·t·(1−t)` lift has a constant second
  derivative. What was missing is that the grenade **leaves the hand above the
  floor it lands on**, and that is what makes a real throw asymmetric. With
  `launch_px` threaded through (`DebugAgent.throw_launch_height()`), the apex
  arrives at t ≈ 0.455 instead of 0.5 and the fall is the longer, faster half.
  With `launch_px` = 0 it reduces **exactly** to the old symmetric parabola, so
  it is a strict generalisation rather than a retune — selftest [10] asserts
  that, along with the monotonic decelerate-then-accelerate itself. That test
  measures the HEIGHT term, not screen Y: on an isometric map the ground path
  has its own linear screen-Y drift, and mixing it in masks the acceleration.
- **Throw timing and settle**: `throw_duration_s` 0.6 s flight with a
  `flight_turns` = 1 tumble (one whole turn, so it lands upright), a light
  landing hop (`bounce_height_ratio` 0.12, `bounce_duration_s` 0.18), then
  `grenade_cook_s` = 1.0 s on the ground before it goes off. The settle happens
  inside that second — *"rolar um pouquinho (1/16 de volta) pra frente (em
  relação ao arremesso), e depois rolar 1/32 de volta pra trás, e parar"* —
  where forward is the direction the throw was travelling, so a throw to the
  left rolls the other way. Rolling back less than it rolled forward is what
  makes it read as settling instead of bouncing. The prediction finishes inside
  the same cooking second.

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

