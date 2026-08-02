# RESUMO_SESSAO — 2026-08-02 (ALPHA FIREARM DESTRUCTION, SESSION CLOSE)

**Active master plans:** `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` (D30,
D30-CAL, D31 landed) and `PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md` (Part 3b
closed — `LINE` was the last unbuilt delivery shape of the three that carry
destruction).
**VERSION at session start:** 0.9.86
**VERSION at session end:** 0.9.87
**Mode:** Solo mode.
**Screenshot session:** not toggled; every capture via direct off-screen
`INFILTRAITOR_AUTO_SCREENSHOT=1` / `INFILTRAITOR_CAPTURE_ACTION=weapon_fire`
runs.

---

## Executive Summary

Three arcs. The session **opened on a rejected experiment** — a proposed
alpha edge/vignette mask baked onto the voxels to make the three faces
readable without per-face shading work. It was prototyped analytically,
captured on the real PLAYGROUND at two strengths, and the Director rejected
it on sight ("ficou muito quadriculado, tá poluído"). Reverted with
`git checkout`, nothing committed. **The analysis that preceded it still
stands and is worth keeping:** the mask would have been cost-NEUTRAL, not a
saving — the expensive axis in the face system is alternative-tile minting
(4095/tile ceiling, 1536 occupied), and an edge is a property of the pixel,
not of the cell. Burning it into the material PNGs, the Director's first
option, would have reached 0.25% of a real capture for the reason
FACE-READ-01 already measured: every baked wall takes its pixels from a
facade page and never sees the material atom.

Then the real work: **firearms finally damage the scenery the way the
Director specified.** `LINE` shipped (D30) with a single readable
destruction coefficient, and the shotgun's cone was rebuilt from a
horizontal streak into a proper disc (D31).

---

## What landed

### D30 — `LINE` delivery + the `punch` coefficient (commit `bce4eca`)

The five rifled weapons had declared `LINE` and loud-failed since D11.
`BlastCalculator.select_line_impact()` fires one straight ray, deliberately
reusing `_walk_pellet_ray()` at angle 0 rather than reimplementing a ray, so
the stop conditions (edge blocking, occupied cells, D15's void fallthrough)
can never drift between `CONE` and `LINE`.

One coefficient decides everything a projectile does:

```
punch = PUNCH_GAIN x weapon_punch x skill x distance x luck / resistance
```

Every factor centred on 1.0, printed on the `[SHOT]` line, all tunables in
one file (`shot_punch_table.gd`). It replaces D28's three-way probability
roll, because *"a marca vai afundando conforme a potência do tiro"* is a
ramp, not a dice bucket. Ladder: `<0.30` CRACKED, `<0.60` DENTED, above that
DESTROYED plus 0→8 neighbours. No "nothing happened" rung — a stray shot
always marks.

The Director's four answers became D30.1–D30.4: neighbours destroyed but
never marked; neighbour cascade to layer 2 only above a threshold set above
the arsenal's measured worst case; skill is the agent's and rides in the
quotient; luck spreads destruction only, never hit/miss, and also picks
*which* neighbours go so holes are irregular.

### D31 — the shotgun cone is a disc (commit `e124226`)

Two independent bugs, both fixed: there was **no vertical axis at all**
(`resolve_pellet_voxel()` pinned every pellet to chest level, so 24 pellets
shared one row by construction), and the lateral angle was
`lerp(-half, +half, unit)` with `unit` uniform, which spreads pellets evenly
across the **full width** — half of every blast past 12.5° of a 25° cone,
extremes as likely as dead centre, smearing the pattern along the cone's
edge instead of filling it.

Each pellet now draws a point in the unit disc (`theta` uniform,
`rho = sqrt(u)`, uniform over area). Horizontal steers the ray, vertical
becomes a level offset, sub-GU horizontal comes off the same disc. Both
scale with distance travelled, so *"tiros de longe erram mais longe"* falls
out of the cone's geometry rather than being a separate rule. Shotgun
`cone_half_angle_deg` 25° → 6°: at 25° the disc's radius at the bench's 4 GU
is 14.9 voxel rows against a storey only 8 rows tall, so every pellet
clamped to the wall's edges — the measured form of *"muito aberto em relação
à arma"*. Range stays uncapped, per the Director's own correction.

---

## Three mistakes the process caught, and how

Recorded because each one was caught by a gate rather than by review, which
is the point of having them.

1. **I read a ratified field against its ratified meaning.** D1 defines
   `step_multipliers` as distance bands for `CONE` but **penetration depth**
   for `LINE`. I used it as distance for both. The symptom was a sniper at
   `punch 0.54` at 11 GU — *weaker at range than a pistol*, inverting the
   whole weapon. Caught by reading the real `[SHOT]` line on a real bench
   shot, not by reasoning. Split into `cone_distance_multiplier()` and
   `penetration_multiplier()`, with a selftest asserting they are not
   interchangeable.

2. **I regressed the shotgun.** Wiring `CONE`'s table in as a distance term
   looked canon-correct (D2) and measured as a regression: the shotgun's
   table bottoms out at 4 GU, exactly where the bench stands it, taking 24
   pellets from ~7 holes through concrete to **zero**. The old `CONE` path
   never read that table at all, so switching it on was a behaviour change
   nobody asked for. Distance left neutral for both shapes (D30-CAL);
   shotgun `punch` calibrated to 0.24, restoring parity at 8 of 24.

3. **I set a threshold from a partial hand calculation, twice.** The
   neighbour-cascade ceiling was first derived from concrete only (forgot
   wood, 4.41), then from the four wall materials only (forgot glass, 8.82).
   The fix was not a better calculation but turning the claim into
   `test_no_shipped_weapon_reaches_the_cascade`, which reads the **real
   weapon JSONs** so a future balance edit fails the suite instead of
   silently turning a rifle into a bazooka. Glass is excluded from that
   ceiling with a measured value plus D22's ratified DESTROYED-only/deferred
   status cited — an exclusion with a reason, not a convenience.

A fourth, smaller one: the capture harness framed weapon shots at
`w_cell.y - 2`, written when every bench weapon was the shotgun at y=6. The
`LINE` weapons at y=9 and y=13 put their impacts off-screen entirely — fixed
by taking whichever of the two is closer to the wall, which leaves the
shotgun's original framing untouched.

---

## Evidence trail

- `project_lint.py` — PASSED, 164 files, both commits.
- `run_selftests.py` — **19 clean, 0 failed**; `blast_calculator_selftest`
  48 → **56**, the 8 new ones covering the neighbour ladder
  (`[0,0,3,5,8,8]`), zero marked strays at punch 2.5, cascade only above
  threshold, coefficient ordering across weapon/skill/material, the CONE/LINE
  step-table split, the arsenal cascade ceiling, LINE ray straightness, and
  the disc spread.
- `check_invariants.py` OK · `gen_codemap.py --check` clean, both commits.
- Real PLAYGROUND bench captures, one per weapon:
  `Screenshots/history/auto_2026-08-02_19-02-04.png` (sniper, punch 1.81,
  one large breach), `auto_2026-08-02_19-02-13.png` (pistol, 0.63, single
  voxel), `auto_2026-08-02_19-02-21.png` (shotgun before the cone fix),
  `auto_2026-08-02_19-28-44.png` (shotgun after).
- Per-pellet instrumented run of the real bench shot: 24 pellets across rows
  2–5 × cols 2–5 of a single GU face, against one row before.

---

## Open, deliberately

- **Damage falloff with distance (D30-CAL).** `punch` ignores distance for
  both shapes today. Director's call at session close: *"o dano vamos
  trabalhar na parte de COMBATE"* — so this moves to the combat work, not to
  a weapon-plan follow-up. `ShotPunchTable.cone_distance_multiplier()` is
  the tested seam it lands on.
- **Agent skill.** No actor carries the stat; `_agent_skill()` returns
  neutral 1.0 and is the single seam for when one exists.
- **Glass.** Resistance 0.4 puts a sniper at punch 8.82, far past the crater
  threshold. Excluded from the ceiling test citing D22; if glass ever gets
  its own destruction rule, that exclusion has to come back.
- **The edge-mask experiment is closed, not parked.** The Director rejected
  the look; the per-face shader path already in production stays the
  mechanism, and the open item there remains per-face LIGHT via the 12-level
  merged darkening index (`VOXEL_LIGHT_MASTER_PLAN`).
