# BURN_THROUGH_MASTER_PLAN
## Fire that opens a passage — cardboard, fabric, plywood — v0.2

> ## ⬆️ SUPERSEDED 2026-08-21 by [`MATERIALS_MASTER_PLAN.md`](MATERIALS_MASTER_PLAN.md)
>
> This plan was opened before the Director described the full materials wave.
> Fire turned out to be one of five parts (decals, fire, glass, voxel props,
> fluids), and a plan named after one part is the wrong container for all of
> them. **Nothing here is retracted** — §2's cascade-ceiling arithmetic and §3b's
> per-material fire curves are carried into MATERIALS_MASTER_PLAN §3 in
> substance, and the tasks this document closed (A0, A0b, A1, A2, B2) stay closed.
>
> Read this one for the reasoning; read the new one for what to do next.

**Status:** ⬆️ **SUPERSEDED — v0.2 was the last live revision.** The fire was
DESCRIBED (§3b) and the cascade ceiling RATIFIED (§2, option C); the propagation
mechanism is still unbuilt and now lives in MATERIALS_MASTER_PLAN §3.
**Written:** 2026-08-21, against `a7763792`.
**Reopens:** `DESTRUCTION_MASTER_PLAN`'s 2026-08-16 materials wave, question 3.
**Companions:** `DESTRUCTION_MASTER_PLAN` (owns how anything becomes broken
voxels), `VOXEL_LIGHT_MASTER_PLAN` (owns the ember and the light field),
`docs/systems/LIGHT_MASTER_PLAN.md`, `PROMPTS/ART_ORDER_NEW_MATERIALS.md`
(the five facades this waits on).

---

## 0. What the Director decided, 2026-08-21

Asked as the three questions `DESTRUCTION_MASTER_PLAN` listed as *"settle
before authoring, not during"*. All three answered:

1. **Fire means burning THROUGH.** Not the decorative ember. Fire propagates and
   converts voxels to `DESTROYED` over time, opening a passage that was not
   there. Chosen over the small version knowingly, with the cost stated.
2. **Cardboard and fabric block light until they burn**, then stop.
3. **Brick is concrete's neighbour on the resistance ladder** — one `RESISTANCE`
   row, one `DESTROY_MIN` row, different art, identical mechanics. It carries
   nothing from this plan.

> **Licensed skepticism, stated once and then dropped.** `DESTRUCTION_MASTER_PLAN`
> sized this wave as *"one hard problem (glass) and one column to fill
> (flammability)"*. Decision 1 makes it three: glass's non-local break, a fire
> propagation system, and the column. That is a milestone, not a column. The
> Director chose it against an explicit description of both options, so it is
> ratified and this plan builds it — the note exists so nobody later reads the
> scope growth as drift.

---

## 1. The one thing that is already free

**Decision 2 costs almost nothing, GIVEN decision 1**, and that is a real
finding rather than an optimistic reading.

Light does not read `damage_state`. `VoxelRenderer.build_occupancy()` is built
from `TileMapLayer.get_used_cells()`, and a voxel that goes `DESTROYED` has its
cell **erased** by `_process_dirty_slice_voxel()`'s `else` branch. So the moment
fire converts a voxel to `DESTROYED`, that cell leaves occupancy, and the light
field, the shadows and everything downstream of them already behave as though
the awning is gone.

**Consequence for scope:** "blocks light until it burns" needs **no opacity
state, no new material field, and no coupling to `LIGHT_MASTER_PLAN`.** It is a
property of burning-through being real destruction. What it does need is the
world revision bumped (`room.bump_world_revision()`) on every burn tick, or
predictions go stale — see `PREDICTION_MASTER_PLAN` §5.2.

⚠️ **Verify before building on it.** The reasoning above is read off the code,
not measured. Task B1 is a real capture: burn one fabric voxel, confirm the
light field changed, against a same-boot control (see the "control run before
reading a capture" rule).

---

## 2. The threat this plan must not walk into

**The soft materials break the cascade ceiling, and the ceiling is a single
global number.**

`ShotPunchTable.NEIGHBOUR_CASCADE_PUNCH = 5.0` is D30.2's "reserved for a future
bazooka" threshold, pinned by `test_no_shipped_weapon_reaches_the_cascade`
against the real weapon JSONs. The worst case in the arsenal is an elite sniper
at point blank with max luck:

    3.0 (PUNCH_GAIN) x 0.70 (sniper) x 1.4 (elite) x 1.0 (point blank) x 1.20 (LUCK_MAX)
      = 3.528, divided by the material's RESISTANCE

So **any material with `RESISTANCE` below 3.528 / 5.0 = 0.706 reaches the
cascade.** This is not hypothetical and not new: **glass is already there**, at
resistance 0.4 → punch 8.82, and the selftest carries an explicit `if material
== "glass": continue` with the measured reason and the note *"if glass ever gets
its own destruction rule this exclusion goes"*.

Cardboard, fabric and plywood are soft **by definition**. Any resistance that
makes them read as soft puts them under 0.706 too. Three options, and the
choice is the Director's:

| | Shape | Cost | Honest read |
|---|---|---|---|
| **A** | Keep resistances above 0.706 | Free | The materials are not actually soft. Defeats the point |
| **B** | Add each to the selftest's exclusion list | Free | The exclusion list becomes a hack that grows once per material, and the pin stops pinning |
| **C** | Make the cascade threshold **per material**, exactly as `DESTROY_MIN` became per material in W-TUNE-02 | ~10 lines + a retune | Follows a pattern already ratified this month, for the identical reason: a single global threshold cannot serve materials whose punch bands do not overlap |

**Recommendation: C**, and it is not a close call. W-TUNE-02 already established
the principle in this exact file, with measurement — LUCK spans 1.41x while
RESISTANCE spans 2.75x, so one number is always entirely above or entirely below
a band. Adding four more materials widens the RESISTANCE span further and makes
a global cascade threshold worse, not merely unchanged. C also retires the glass
exclusion instead of adding four siblings to it.

> ### ✅ RATIFIED 2026-08-21 — option C
>
> Director: *"Vamos com o teto por material."* The cascade ceiling becomes a
> per-material table on the `DESTROY_MIN` pattern, `NEIGHBOUR_CASCADE_PUNCH`
> stays as the fallback for an unlisted material, and the selftest's `glass`
> exclusion is retired in the same change — it becomes a row, not a `continue`.
> **A0 is closed.**

---

## 3. What burning-through has to answer

The mechanism is not designed yet. These are the questions, not the answers.

1. **What ignites it?** Today the only heat source is a detonation, and
   `flammability` already gates a real `ember` wave inside the blast's expanding
   front. Firearms have no heat concept at all. Does a bullet ignite cardboard?
2. **What is a tick?** The game is turn-based. `TacticalTurnManager` already
   emits `player_turn_started` and `enemy_phase_started`, and fire that advances
   on turn boundaries is legible to a player in a way fire advancing on `delta`
   is not. **Strong recommendation: fire is a turn-based agent, not a
   `_process()` effect.** A stealth game whose fire spreads in real time while
   the player thinks is a different game.
3. **How far does it spread, and does it stop?** Unbounded spread through a
   contiguous fabric wall burns the whole wall down, every time, which makes the
   material one-shot rather than tactical. A per-material spread budget, a
   probability per tick, or a fuel count per voxel are all shapes; none is
   chosen.
4. **Is it a threat to the agent and the guards?** Currently nothing in the
   project takes damage from the world. Answering "yes" pulls in actor damage,
   which is `GAME-01`'s, not this plan's. **Recommend explicitly OUT for v1.**
5. **Does it make noise / draw guards?** `docs/systems/noise.md` owns this seam
   and it is exactly the kind of emergent stealth consequence the design wants.
   **Recommend OUT for v1, named as the first extension.**

---

## 3b. The fire, as the Director described it (2026-08-21)

Verbatim design, transcribed before it is turned into anything. This is §3.3's
answer arriving ahead of the rest, and it is **per material** — the three do not
share a curve.

> *"os mais moles não vão destruir muito mais durante os tiros, mas na explosão
> o fogo 'pega'"*

**The first rule, and it reframes everything below: softness is a FIRE
property, not a bullet property.** A shot through cardboard is still just a
shot. What the soft materials change is what a *detonation* does to them. This
usefully shrinks §2's calibration worry: their resistance rows do not have to
carry the drama.

| Material | Behaviour | Passage |
|---|---|---|
| **fabric** (tecido) | Fire catches and burns **fast**, consuming everything; an ember remains **only at the edges**, then goes out | **Always** opens |
| **cardboard** (papelão) | A flame first **rises up** the material, then it is consumed by embers **more slowly** than fabric | **Always** opens |
| **plywood** (madeirite) | Burns for a while, turns to ember, then goes out | **Conditional** — see below |

**Plywood is the only one with a spatial rule**, and it is the interesting one:
*"abre passagem se a granada for bem na base da parede, queimando vários voxels;
se for mais distante queima menos."* So plywood's burn extent is a function of
the blast's **proximity to the wall's base** — which is a geometric input the
detonation already has (the ring/radius model, and the epicentre bias
`carved_side_for()` already consumes). Fabric and cardboard ignore it.

### The scope statement that should govern the whole milestone

> *"Na realidade esses materiais vão ser mais usados em caixas, tapumes,
> andaimes, toldos, e outros elementos decorativos que vão ser destruídos. Mas
> podem eventualmente serem usados para bloquear/desbloquear caminhos."*

**These are PROP materials first and wall materials second.** That is a
different centre of gravity than §4's staging assumed, and it is good news for
sizing:

- A prop is already built from dictionary materials — `PropDef.material_zones`,
  e.g. `props/crate_full.json` is `{"default": "wood"}`. A cardboard crate is
  that file with one word changed. **No new art and no new schema.**
- So "burning a crate" and "burning a wall" are the same mechanism over the
  same voxels, and the prop case is the one to build and demo FIRST — it is
  small, self-contained, and it is what the material is actually for.
- Blocking/unblocking a path is real but **occasional**. It should not drive the
  design of the propagation; it falls out of voxels going `DESTROYED`.

⚠️ **One known gap this walks into.** ART_SPECIFICATIONS §5 records that the v1
prop renderer **ignores `layers` and renders props as solid GU blocks**, and
that pinning the row/level ordering is an ART-01 deliverable. A burning awning
(toldo) is a thin, non-solid shape. So the prop-first route is blocked on
renderer v2 for anything that is not a solid block — a crate works today, a
toldo does not. Size C1 against that, or scope v1 to solid props.

### What is still open after this

§3.1 (what ignites it — does a bullet, or only a blast?), §3.3's spread budget
for the wall case, and §3.4/§3.5 (damage to actors, noise) remain unanswered.
The Director's description is entirely about **blast-sourced** fire, which is a
strong hint that the answer to §3.1 is "explosions only, for now".

---

## 4. Staging

Ordered so that nothing is built on an unverified assumption.

| Task | What | Blocked by |
|---|---|---|
| ~~**A0**~~ | ~~Director ratifies §2's option A/B/C~~ — ✅ **CLOSED 2026-08-21, option C** | — |
| ~~**A0b**~~ | ~~per-material cascade table; retire the `glass` exclusion~~ — ✅ **DONE `25cf8b6a`**. `CASCADE_MIN` is a floor-lifting exception table; the selftest now measures 10 materials against their own ceilings as a ratio, no exclusions | — |
| ~~**A1**~~ | ~~register `brick` + `plywood`~~ — ✅ **DONE `25cf8b6a`**, and it did NOT need the facades: registration is inert until a map places a block. Real boot registers both with zero errors | — |
| ~~**A2**~~ | ~~same for `cardboard` + `fabric`~~ — ✅ **DONE `25cf8b6a`**. `glass` also gained the `base_color`/`pattern_algorithm`/`has_facade` it was the only material missing | — |
| **B1** | **Measure the free win.** Force one fabric voxel to `DESTROYED`, capture the light field against a same-boot control, confirm §1 | A2 |
| ~~**B2**~~ | ~~place them as real blocks and run `roof_bake_selftest`~~ — ✅ **DONE**. All FIVE placed at gu x=22/26/30/34/38 (step 4, not the reserved 5 — plywood was a late addition and five 3-wide blocks would run past the 44-wide board). `roof_bake_selftest` PASSES with glass placed, which **closes ROOF_BAKE_LEAK_2026-08-17's second finding**: the 520 missing roof entries were a missing FACADE, not a missing roof family | — |
| **C0** | Answer §3.1–3.5 with the Director; write v0.2 of this plan | B2 |
| **C1+** | Build the propagation — **prop-first** (§3b), per-material curves, blast-sourced | C0 |
| **D** | **Glass, last** — its own non-local pane break. Separate brief; see §5 | — |

**The facades arrived 2026-08-21 and A1/A2/B2 all closed the same day.** What
placing the blocks found, and nothing else could have: `glass` had **never** been
in `BakeCompositor.VOXEL_MATERIALS`, so B6 fired *"no canonical voxel atom for
'glass' — will render unmasked rectangles"* even though `voxel_glass.png` had
been on disk for months. A material in `BASE_MATERIALS` but not in
`VOXEL_MATERIALS` renders, and renders WRONG. It went unseen because glass had
never been placed.

**The next blocking step is C0** — answering §3.1/§3.3/§3.4/§3.5 so the
propagation can be designed. Nothing else is waiting on art.

---

## 5. Glass keeps its own open item, unchanged

Not folded in here. Its hard problem is different in kind — a non-local break
across a connected pane, where every other material's damage is local — and its
blocking question is still `DESTRUCTION_MASTER_PLAN`'s: **what is a "whole
window"?** Whether a pane is derived from contiguous glass voxels or authored in
the mapfile is the decision that sets how big glass is.

Two smaller glass items found during the 2026-08-21 code pass, recorded here so
they are not rediscovered:

- **A far shotgun pellet CRACKS glass, which contradicts D22.** D22 ratified
  glass as DESTROYED-only — *"não vai ter dented; é buraco feito, ou não
  feito"*. `damage_state_for()` returns `CRACKED` below `PUNCH_DENT_MIN` (0.30)
  for every material, and a pellet at the far end of the shotgun's distance
  ladder computes 3.0 x 0.24 x 0.15 x 0.85 / 0.4 = **0.23**, under the floor.
  So glass can be cracked today.
- **Glass's no-DENTED rule is an accident of two numbers being equal.**
  `DESTROY_MIN["glass"]` is 0.30 and `PUNCH_DENT_MIN` is 0.30, which makes the
  DENTED band exactly empty. That is the ratified behaviour arriving by
  coincidence rather than by construction — lower `PUNCH_DENT_MIN` for any
  unrelated reason and glass silently grows a dent tier.
- **`materials/glass.json` has no `base_color`, no `pattern_algorithm` and no
  `has_facade`** — the only material file missing all three.
