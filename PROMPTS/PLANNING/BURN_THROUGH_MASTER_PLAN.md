# BURN_THROUGH_MASTER_PLAN
## Fire that opens a passage — cardboard, fabric, plywood — v0.1

**Status:** 🟡 **v0.1 — captured brief, ratified in shape, not yet executable.**
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

**This is a design decision and is NOT taken here.** Task A0 is the Director
ratifying A, B or C.

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

## 4. Staging

Ordered so that nothing is built on an unverified assumption.

| Task | What | Blocked by |
|---|---|---|
| **A0** | Director ratifies §2's option A/B/C | — |
| **A1** | Register `brick` + `plywood`: material JSONs, `RESISTANCE`, `DESTROY_MIN`, `BASE_MATERIALS`, `VOXEL_MATERIALS`, `canonical_voxel_atom_for()` aliases | facades |
| **A2** | Same for `cardboard` + `fabric` | facades, A0 |
| **B1** | **Measure the free win.** Force one fabric voxel to `DESTROYED`, capture the light field against a same-boot control, confirm §1 | A2 |
| **B2** | Place all four as real blocks in PLAYGROUND (reserved today at gu x=22-24 / 27-29 / 32-34 / 37-39), run `roof_bake_selftest` — this is where a missing facade shows up as 520 missing roof entries | A1, A2 |
| **C0** | Answer §3.1–3.5 with the Director; write v0.2 of this plan | B2 |
| **C1+** | Build the propagation | C0 |
| **D** | **Glass, last** — its own non-local pane break. Separate brief; see §5 | — |

**A1 and A2 are inert until B2**: registering a material that nothing places
changes no pixel. That is deliberate — it means the registration can land the
moment the art does, without waiting on §3.

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
