# RESUMO_SESSAO — 2026-08-05 (explosion rebuild — planning only)

**Continues:** `RESUMO_SESSAO_2026-08-05_EXPLOSION_RESET.md`, which closed with
*"Waiting on the Director"* for the rebuild instructions. Those instructions
arrived this session.
**VERSION:** 0.9.89 at start → 0.9.89 at close (no bump — no code changed).
**Mode:** Solo mode.

---

## Executive summary

Planning session, **zero code changed**. The Director gave the full explosion
specification (4 rings, per-ring effect prevalence, pre-baked special voxels,
per-voxel soot, a 14-wave choreography, and the Phase B targeting/throw
sequence). Output is one document:
`PROMPTS/PLANNING/EXPLOSION_REBUILD_MASTER_PLAN.md`.

The repo is in **exactly** the post-reset state the previous summary describes:
grenades detonate and damage nothing; firearms damage normally. Nothing was
reconnected this session.

---

## 1. The architectural finding

D-ARCH-01 died because it pre-baked a damage variant **per cell** — 71,296
cells × N variants, measured at ~95 ms/wall-voxel, projecting to tens of
minutes at map load.

The Director's rule *"usando voxels aleatórios das facades por baixo"* removes
the per-cell dimension outright: a damaged voxel no longer shows **its own**
facade under the decal, it shows a randomly chosen one for its material. The
bake set collapses from *cells × variants* to *materials × types × decals ×
substrates* ≈ **192 atoms for the whole map**. Everything else in the plan
depends on that one sentence.

Second core idea, the one D11 never had: **a wave is a pure `set_cell()` loop**.
All resolution (tile ids, exposure fallback, final alternative ids) happens in a
precomputed `DetonationPlan`, and the map-wide light repaint runs **once**,
before wave 1. D11 staged real work per frame, which is why staging made it
worse rather than better.

---

## 2. Director decisions ratified this session

1. Destruction hits **floor and walls/ceilings**, as today (not floor-only).
2. Floor layers: first blast on a virgin GU cedes only `FLOOR_TOP_LEVEL` (−1);
   later blasts on the same GU also cede `FLOOR_DEEP_LEVEL` (−2). Needs per-GU
   blast memory.
3. **3 substrate variants** per (material × type × decal), hash-picked per cell.
4. **Phase A first** — bake + calculation + waves on the current right-click
   trigger. Phase B (targeting UI, bubble, throw animation, the two compute
   windows) planned separately, after Phase A produces real captures.

---

## 3. Consequences worth carrying forward

- **Soot must become authored, not derived.** Today it is derived from
  destroyed voxels; ring 3 destroys nothing, so derivation can never produce
  the ring-3 soot the spec requires. Resolution that does not break firearms
  (which rely on the derivation): `tone = min(derived, stamped_by_blast)`.
- **Per-face → per-voxel soot frees the alt-id ceiling**: 125 codes → 5, i.e.
  3000/4096 → 120/4096. The Director's earlier five-tone request, refused on
  2026-08-04 for lack of alt-id space, would now fit comfortably.
- **Ring 3 is data, not code** — `flood_gu_rings()` derives its cap from
  `ring_multipliers.size()`, so a 4th JSON entry is the whole change.
- The spec's per-ring tier prevalence (dented only 0/1, cracked only 1/2)
  needs **per-tier weight tables** in `BombDef`, separate from today's single
  shared multiplier.

---

## 4. Risks recorded, not hidden

- **The ~192-atom bake cost is a projection, not a measurement.** Task 0 of the
  plan is a warm-sequential measurement spike and gates everything else.
  Projecting on an unmeasured number was half of what went wrong in the
  previous arc; the old ~95 ms/voxel figure was per-cell and partly cold, and
  must not be reused as if it answered this question.
- **Cracked art for ceilings and floors does not exist** (D32.6 fixed
  blast-CRACKED to concrete/stone; the floor family has no crack tier). This
  gates 64 of the ~192 atoms — see Q3.
- The spec contradicts itself on whether smoke reaches ring 3 (prose says yes,
  the wave list and *"o único elemento do ring 3"* say no) — Q2.

---

## 5. State at close

- **VERSION 0.9.89** (unchanged). No `.gd` file touched this session.
- `check_invariants` OK · `project_lint` PASSED (181 files) — run by the
  pre-commit hook on both commits.
- Commits: `2ba9a19` (the plan), plus this session's closing docs commit. Both
  pushed to `main`.

---

## 6. Next session starts here

Read `PROMPTS/PLANNING/EXPLOSION_REBUILD_MASTER_PLAN.md` **§11**, which is
written as the resume point. In short:

1. Take the Director's answers to §10's nine questions. **Q1** (does the
   floor's *muito/menos/quase nada* falloff apply to walls too?) and **Q3**
   (cracked art for ceilings/floors) are the two that change work already
   planned; the rest carry stated defaults so nothing stalls.
2. Run **Task 0**, the bake-cost measurement spike — it commits to no design
   decision and can start before any question is answered.
3. Then Tasks 1 → 6 in §8's order.

Do not start Phase B, do not touch `WeaponBenchController.fire_active()` or the
D33 runtime path it uses, and do not re-enable camera rotation as part of this
work.
