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
  ending on an ELLIPSE of `length_scale` = 1.35 times the outer ring's projected
  radius, so they clearly overshoot the dome,
  `circularity` = 1 undoes the 2:1 isometric squash so the star reads round, and
  `lateral_scale` buys a little extra width back on top.
  **`rays_per_cell` is not the spoke count.** The BFS reaches 12 cells but they
  point in only EIGHT distinct screen bearings — `(1,0)` and `(2,0)` are the same
  direction at different lengths, likewise the other three axis pairs, and ring
  2's four diagonals supply up/down/left/right. The fan exists to fill the 45°
  gaps between those eight, so `spread_rad` must be sized against that gap:
  3 rays 15° apart span 30° of each 45°, which is near-even. Raising the count
  without opening the spread to match just makes eight tight bundles.
  **Lengths come from a direction, not from the cell's own distance.** Scaling
  each cell's delta made the four screen diagonals 64% longer than the four axes,
  because the BFS reaches an L1 diamond and `(2,0)` is 2 GU out while `(1,1)` is
  only 1.41 — the corners the Director circled as TOO LONG, with the short ones
  being the axes between them. Endpoints land on an ellipse instead
  (`_ellipse_radius()`, closed form), and the remaining variation is the ring
  step and the deterministic jitter, on purpose. They leave from `ray_origin_lift_gu` above the floor
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
  relação ao arremesso), e depois rolar 1/32 de volta pra trás, e parar"*.
  Rolling back less than it rolled forward is what makes it read as settling
  instead of bouncing. The prediction finishes inside the same cooking second.
  **Rotation is ONE continuous angular motion from release to rest.** The first
  version played three unrelated ones back to back — a tumble at constant full
  speed, a bounce with the sprite frozen, then a twitch from a standstill — and
  the Director's *"parece forçada"* was that seam, not any of the three
  amplitudes. One velocity now decays from the tumble, through the bounce, into
  the settle; the settle's start rate is DERIVED (an ease-out of 1−(1−t)² begins
  at 2×amount/duration) rather than picked, so the hand-off cannot show.
  The two things the Director said a fixed rule cannot cover are derived too:
  **angle** — a ground roll spins about an axis perpendicular to travel, seen in
  full when that axis lies across the screen and not at all when it points at
  the camera, which is exactly `roll_dir.x`, so the old arbitrary `sign()` and
  its coin-flip on vertical throws are gone; and **distance** — the settle
  scales with travel against `roll_reference_px`, clamped both ends.
  It is also a roll rather than a pivot: every turn moves the grenade `r·θ`
  along the ground, from the TURNS and not the visible rotation, because a
  grenade rolling away from the camera still travels while showing no spin.
  Honest caveat: at `roll_radius_px` = 11 that travel is ~5 px, so what fixes
  the feel is the continuity, not the displacement.

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

### 6.1 ✅ CLOSED 2026-08-11 — both items built and verified

Both were specified by the Director and left mid-task; both are now landed. What
follows is the original specification, kept verbatim, with the closure recorded
under each.

**A. The grenade's ground shadow — ✅ BUILT 2026-08-11.**
*"A sombra da granada. Nós já temos nas outras armas, e está funcionando bem.
Vamos aplicar na granada também. Durante o vôo da granada, a sombra precisa
acompanhar no chão, aumentando e diminuindo a opacidade e a difusão, de acordo
com a distância vertical. Quando a granada encosta no chão a sombra é muito bem
definida e bem menor, por baixo do asset. Durante o vôo ela aumenta um pouquinho
e fica mais difusa."*

`godot/shaders/object_ground_shadow.gdshader` is written and documented.
**Nothing references it yet** — it compiles, it is inert, and the tree is
functional without it. What is left:

1. `GrenadeProp` gains a shadow child `Sprite2D` with this material and
   `show_behind_parent = true`, fed the SAME colour frame the body is showing,
   squashed by `sin(ELEVATION_DEG)` = 0.5 (the bake camera's own elevation, the
   convention `CollectibleBakeConfig.SHADOW_SQUASH_Y` already uses).
2. `set_flight_height_px(px)` on `GrenadeProp`: the shadow's local `y` is `+px`
   so it stays pinned to the ground while the body lifts (the same trick as
   `floating_collectible.gd:528`), and `px` drives three things — scale up,
   `blur_px` up, `strength` down. Height 0 = small, sharp, opaque, directly
   under the asset.
3. Counter-rotate the shadow against the tumble (`_shadow.rotation = -rotation`
   in `_process`), or the squash is applied after the parent's rotation and
   shears.
4. The throw animation feeds it: during flight
   `ground_from.lerp(target_world, t).y - sprite.position.y`, during the bounce
   `ThrowArcOverlay.bounce_lift(...)`, and 0 once it settles. The four resting
   test-zone props get height 0 for free, which is the "encosta no chão" look.

**Why a shader and not baked frames — stated, because it is a substitution.**
`FloatingCollectible`'s shadow is two BAKED passes per frame
(`frame_%02d_shadow_{sharp,soft}.png`) crossfaded by height, and
`grenade_collectible_frames/` really does ship 480 of them. The THROWN prop's
`grenade_frames/` has none: `grenade_frame_bake_spike.gd` never had a shadow
pass, only `grenade_collectible_bake_spike.gd` does. Deriving the shadow from
the alpha of the colour frame the prop is already showing gives both looks from
one texture with no pipeline run, and it is still the object's real silhouette
rather than a stand-in ellipse. The baked route remains open: add a shadow pass
to the prop spike and this shader stops being needed.

**Closure.** All four steps landed, plus one the spec did not anticipate: a child
inherits its parent's WHOLE transform, so counter-rotating the shadow is not
enough — its ground offset gets rotated too and the shadow ORBITS the tumbling
grenade. `GrenadeProp._sync_shadow_transform()` undoes both exactly (the algebra
is in its docstring); the net world transform is a plain screen-space drop of
`h` px, with the parent's uniform scale cancelling out of the linear part.

The first tuning rendered nothing visible, and the diagnosis was NOT eyeballed: a
`print_debug` proved the node was in the tree, visible, textured and holding a
loaded shader at a correct world position, and forcing `strength` to 1.0 and the
scale to 3.0 rendered a perfectly placed black grenade. So the wiring was never
the problem — `FloatingCollectible`'s airborne alpha (0.28) is simply too faint
for a 22 px squashed silhouette when it works fine for a baked, dilated blob.
Walked back to 0.35 in flight / 0.55 on the ground.

`SHADOW_HEIGHT_REF_PX` (90) is derived, not picked: `arc_height_for()` floors
every apex at `launch_px · 1.4` = 89.6 px for a standing throw, so even the
SHORTEST throw the geometry allows reaches the full effect at its own apex, and
longer ones hold it instead of pumping.

Evidence, hand-named so the 50-file rotation cannot eat it:
`grenade_shadow_flight.png` (mid-flight, larger + diffuse + faint),
`grenade_shadow_ground.png` (landed, small + sharp + under the asset), and the
red/green partner `grenade_shadow_off.png` — same binary, same map, same frame,
shadow strength forced to 0. Diffing the pair: **291 px changed, peak darkening
55.4%** — the effect's measured footprint rather than a description of one.

**B. The settle roll is still quantised.** Director, 2026-08-10: *"me parece que
o giro da granada no chão está travado ainda em 1/16 e 1/32 de volta. Essa
graduação precisa ser livre, de acordo com o ângulo e a energia. Vamos fazer
essa rolada bem sutil, com ease in/out, sem pressa."*

Correct — `roll_forward_turns` / `roll_back_turns` are still literal fractions
of a turn, merely multiplied by a clamped distance factor, so the amount is
quantised even though the timing is now continuous. The replacement is a
friction model, which drops out of the ballistics already built:

    landing rate ω₀ = (ground distance in GU × 181.02 px/GU / throw_duration)
                      / (TAU · roll_radius_px) · restitution      [turns/s]
    duration      T = ω₀ / friction
    amount        θ = ω₀² / (2·friction)

Constant friction integrates to `θ(t) = amount·(1 − (1 − t/T)²)`, which is
**exactly the ease-out already in the code** — so the profile does not change,
only where its two numbers come from. Both then graduate freely: amount goes
with the square of throw distance (kinetic energy), duration linearly. Clamp `T`
against `grenade_cook_s` so a long throw cannot outlast the fuse, and derive the
back-rock as a RATIO of the forward roll rather than a second fixed fraction.
Distances must be measured in **GU, not screen px** — a throw along the screen's
vertical covers half the pixels of the same ground distance sideways, so screen
px would under-rate exactly the throws the Director calls out as angle-dependent.

**Closure — ✅ BUILT 2026-08-11, re-anchored.** The model above is exactly what
shipped, but NOT with a friction coefficient in the code. Since `ω₀ ∝ v`, the two
results collapse to `T ∝ v` and `θ ∝ v²`, so `friction` and `restitution` cancel
out entirely and the whole thing is expressed by what the LONGEST throw does —
two numbers anyone can picture instead of two nobody can. `roll_reference_px`,
`roll_scale_min/max`, `roll_forward_turns`, `roll_back_turns`, `roll_forward_s`
and `roll_back_s` are all gone.

What replaced them: one free number, `roll_turns_at_max_range` = 1/8 turn; the
duration at max range is itself **derived from the fuse** (`grenade_cook_s ÷ (1 +
roll_back_duration_ratio)`), so the longest throw comes to rest exactly as the
grenade goes off — no clamp ever truncates the throw the effect is sized by. The
ease-out is byte-for-byte the old one, which is the point: under constant
friction it was already the exact solution.

Measured, by tracing the real `_start_grenade_throw_animation` on eight throws:

| target | GU dist | forward roll | duration |
|---|---|---|---|
| (15,13) | 2.236 | **4.59°** | 0.188 s |
| (13,11) | 3.000 | **8.27°** | 0.252 s |
| (11,9) | 5.385 | **26.63°** | 0.453 s |
| (9,9) | 6.403 | **37.65°** | 0.538 s |

Free and continuous, amount with the square of distance, duration linear — no
fraction of a turn anywhere. And the GU-not-pixels requirement is confirmed
rather than asserted: four throws of exactly 3.000 GU in four different grid
directions from (13,14) — to (13,11), (10,14), (16,14), (13,17) — all returned
**identical** numbers (8.27° over 0.252 s), which is precisely what a screen-px
measure could not have done.

Not captured, and deliberately: a still cannot show a rotation over time, so the
trace above is the evidence rather than a screenshot claimed to stand for one.

### 6.2 Standing

- **Wall sectioning of the dome — ✅ CLOSED 2026-08-12 (`c30601d`).** The dome
  is really sectioned now: the SILHOUETTE is cut, the sphere's own grid is not
  bent (only hidden where a wall stops it), and each visible wall face carries
  its own grid in the WALL's axes — the Director's diagram. Re-reading the
  reverted attempt said exactly why it read wrong and the mechanism was never
  at fault: it moulded only `_draw_wall_grid()` and left `outline`/`disc` as
  full undistorted ellipses, so the rim stayed a perfect round balloon with a
  dented interior (byte-identical rim between `grenade_wall_grid_molded.png`
  and the plain build). A radial sweep, not a convex hull, because a wall is a
  FINITE rectangle and a parapet leaves a non-convex region a hull would fill
  in. Four defects found by measuring — per-cell-pair edges arriving as seven
  segments, a box's three invisible faces, bucket aliasing (19 empty buckets of
  180), and the wall EDGE's shadow curve never sampled. Verified numerically:
  smooth at all 180 buckets across three aim cells, extremes landing exactly on
  `IsoProjection.sphere_semi_axes(2.0)` (362.04 / 367.65 px).
  `kernel_direction()`/`silhouette_basis()` added and asserted in
  `iso_projection_selftest` [11] by a different route through the basis.
  Evidence: `grenade_dome_sectioned_front.png`,
  `grenade_dome_parapet_overtop.png`.

  <details><summary>The original PAUSED note, kept as the record</summary>

  **ATTEMPTED 2026-08-11/12, PAUSED, not the depth trick this section used to
  propose.** `classify_geometry_over_rect()`/
  OcclusionSet O5 turned out to be the wrong tool — it only answers "in front
  of or behind," never "cut by, up to this real height," and the Director's
  follow-up ("vamos ter parapeitos, morros e outros cenários com paredes mais
  baixas — precisamos calcular por edge e por slice") ruled out any version
  that treats a wall as a uniform full-height plane. What got built instead:
  `AimBubbleOverlay` grew a real lat/long wireframe grid (`IsoProjection.
  project_point()`, new and additive), and `RoomBuilder` now retains
  `EdgeExtractor`'s per-edge `start_storey`/`storey_count` on
  `room._wall_height_edges` (1 storey == 1 GU) instead of discarding it right
  after `SliceGenerator` consumes it — the real per-edge, per-height data the
  Director asked for. Each grid vertex was cast as a 3D ray from the dome's
  centre, clamped to whichever is nearer: the sphere surface, or a wall plane
  whose real `[start_storey, start_storey+storey_count)` range covers the hit
  point. Verified working end to end (a real detonation-adjacent wall bent two
  meridians into straight lines tracing its face, `grenade_wall_grid_molded.
  png`). **Then reverted on sight**, 2026-08-11: *"a distorção não é assim...
  vai ser uma coisa mais angulosa"* — the curved ray-clamp is the wrong SHAPE,
  not a wrong mechanism in principle, and the request needs a refined spec
  before it's rebuilt. `AimBubbleOverlay` is back to a plain undistorted grid
  (`grid_line_width` 1.2 → 1.8 for legibility); `room._wall_height_edges`
  stays populated and documented as currently unconsumed — cheap, tested,
  correct on its own, and exactly what the next attempt will need, so
  re-deriving it later would be pure waste.

  </details>
- ~~The click-driven `test_zone_*` capture actions are dead.~~ **CLOSED
  2026-08-10.** `ecdae79` had removed the right-click → `open_menu_for()` path
  ("now G-key only"), taking `test_zone_menu` / `test_zone_detonate` /
  `test_zone_escape` with it. Restored on the Director's call — the two routes
  are not rivals: **G aims and throws a NEW grenade; right-click detonates one
  already lying on the floor**, which is what keeps the choreography and
  performance work testable. Proven by trace, not by eye
  (`grenade_index=0` → menu → Enter → `[E-PLAN] census gu=(3,5)`) plus
  `grenade_menu_detonate.png`.

### 6.3 Found in passing, NOT this plan's to fix

Both predate this work; neither surfaced on its own because both are
silently-inert rather than visible breakage. One is now closed.

- **`detonation_choreographer_selftest` fails, deterministically.** "One frame
  carries 367/403 steps (91.1%) — the sequence is collapsing again." Cause
  confirmed by red/green: `[E-FUME] 20334c3` pulled soot out of `WAVE_TABLE`,
  taking 546 of 949 steps out of the paced queue, and the front lost its spread.
  Restoring those four rows returns the suite to 10 PASS / 0 FAIL with the
  heaviest frame at 53.7%. This is the blast pacing the Director wants to close
  next, so it belongs to `EXPLOSION_REBUILD_MASTER_PLAN`, not here. Still
  failing as of 2026-08-12 (re-checked, unrelated to this session's work).
- **E-FRAG's post-blast debris has never fired — CLOSED 2026-08-12.** Two
  bugs, both silent because nothing but a real detonation exercises the path.
  `shrapnel_overlay.gd:49` and `debug_ray_overlay.gd:45` both called
  `VoxelRenderer.cell_level_to_world()`, which never existed — every
  detonation raised a SCRIPT ERROR and aborted before a single fragment/ray
  was built (confirmed NOT to abort the caller too: `_start_waves()` right
  after it always ran, so real destruction was never affected). Real name:
  `voxel_world_position(cell, level)`. Once fragments spawned, they still
  didn't render — `BLEND_MODE_ADD` on the near-black "dark iron" colour adds
  almost nothing to the frame under it. Proven by forcing a bright colour and
  tracing every `_draw()` call: geometry, timing and z-index were all already
  correct, only invisible. Switched to `BLEND_MODE_MIX`. Evidence:
  `grenade_shrapnel_verified_bright.png` (forced colour, proves the pipeline),
  `grenade_shrapnel_dark_iron.png` (real tuning), `grenade_debug_rays.png`
  (E-DEBUG-RAY's 200 rays, same fix).

---

## 7. Schedule

Tasks 1–4 are done, the whole chain runs end to end, **§6.1 A and B are both
closed** (2026-08-11), and **E-FRAG/E-DEBUG-RAY are closed** (2026-08-12, §6.3).
Next session, in order:

1. **§6.2 — wall sectioning of the dome, refined spec needed.** The
   ray-clamp mechanism works and the height-aware data (`room.
   _wall_height_edges`) is already retained — what's missing is the
   Director's "mais angulosa" shape spelled out concretely (which geometric
   primitive, what the transition looks like) before it goes back into
   `AimBubbleOverlay`.
2. Throw feel beyond that: SFX, and whether the arc should be dev-only after all
   (see §4's flagged judgement call).

Nothing here blocks the blast-choreography work in §6.3, and vice versa.

