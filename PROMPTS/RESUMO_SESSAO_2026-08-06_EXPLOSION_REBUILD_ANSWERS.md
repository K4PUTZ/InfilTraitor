# RESUMO_SESSAO — 2026-08-06 (explosion rebuild — Director's answers folded into the plan)

**Continues:** `RESUMO_SESSAO_2026-08-05_EXPLOSION_REBUILD_PLAN.md`, which
closed with nine open questions in `EXPLOSION_REBUILD_MASTER_PLAN.md` §10 and
Task 0 (the bake-cost measurement spike) as the next concrete action.
**VERSION:** 0.9.89 at start → **0.9.89 at close** (no bump — no code
changed, planning only).
**Mode:** Solo mode.

---

## Executive summary

Pure planning session, **zero `.gd` files touched**. The Director answered
all nine of §10's open questions across three rounds — an initial pass
(Q1–Q6), a same-day correction pass (Q1b, Q3b) after a misreading on my part,
and a final architectural reveal (D13) about *why* per-map material scoping
matters at all. `EXPLOSION_REBUILD_MASTER_PLAN.md` was rewritten across four
commits to carry all of it; three other docs got forward-pointers so they
don't go stale relative to the new plan. The plan's atom count moved
**192 → 135 → 207** as understanding sharpened — not churn, each number was
the honest total for what was known at that point, and the reasoning for each
move is preserved in the plan itself (§3.2, §10).

**Only one open item left: Q1b, the exact vertical-falloff formula (§4.3),
proposed but not yet confirmed.** Task 0 does not depend on it. Task 0 itself
was **not run this session** — the Director asked to close the session on
documentation instead.

---

## 1. What got answered, and what it changed

**Q1 — walls/ceiling use the floor's ring model, not their own.** Reverses
the 2026-08-05 reading. Corrected same-day after I over-simplified it: per-
material resistance (`MaterialResistanceTable`) was never being replaced,
only extended with a new vertical-distance axis alongside the existing
horizontal ring. Recorded as **D1 (rev)**.

**Q2 — smoke reaches ring 3, weaker, staggered in ring order.** A 15th wave
(**Smoke ring 3**) added to the choreography. **D5.**

**Q3 — cracked is one voxel family per material, shared across floor/wall/
ceiling** (baked on all three faces at once, since a cracked voxel is already
failing everywhere). Collapses what would have been three separate per-class
cracked bakes into one. **D6.**

**Q3b — bullet marks join the same pre-baked registry**, replacing D33's live
per-cell compositing for the *mark-painting* step only (hit detection and
damage-state logic stay where D26–D33 put them). A real scope change from the
plan's original "firearms fully untouched" line. **D12** (renumbered past
D11 to avoid colliding with this plan's own pre-existing D11 reference).

**Q4 — ceiling DENTED gets 3 irregular alpha-cut shapes**, not one
silhouette; the cut-shape art is reusable across materials that share a look.
**D7.**

**Q5 — 40 ms/wave confirmed.** 15 waves ≈ 600 ms of choreography.

**Q6 — bubble described, XCOM reference attached.** Phase B only; recorded
for when that phase starts, not acted on now.

**D9/D10 (new, correcting a real gap I hadn't caught):** floor damage baking
was about to inherit an old bug — `IMPACT_FLOOR_MATERIAL = "earth"` is a
placeholder that today makes *all* floor damage resistance and decal art
agnostic to the GU's real ground material. The Director rejected that
outright: iron floor shouldn't crack, concrete floor should destroy more than
stone floor. Floor now keys off the GU's real material (`ground_concrete` on
PLAYGROUND), and crack eligibility for *every* material — wall or ground —
collapses to one source of truth: `MaterialResistanceTable.crack_factor > 0`,
not a separately hand-maintained list. This surfaced a live gap, not silently
patched over: `ground_concrete.crack_factor` is `0.0` today, a leftover from
when no floor-crack art existed at all — Task 2 needs to make a real decision
there now that D6's universal cracked atom removes the original reason.

**D13 — the big one.** What started as "don't bake materials a map doesn't
use" turned out to be about something much bigger: INFILTRAITOR is planned to
ship **downloadable, procedurally generated scenarios unique per
playthrough**, with per-player material/texture/UI/menu customization down to
things like character-level color modifiers and seasonal themes (Halloween
was the example given). A material is not a small fixed catalog — it's
dynamic content that can be unique per player. That's why each map needs to
**explicitly declare** which materials its damage bake needs (a new
`MAPFILE_REFERENCE.md`-registered section, not derived from existing
geometry sections), and why the bake cache needs to survive across sessions
on `user://`. The Director was explicit that **full dynamic cache management
(storage budget, eviction, per-player namespacing, procedural-material
versioning) is deliberately out of scope here** — its own planning pass,
later, at the end of the destruction phase. This session's plan keeps the
cache minimal on purpose. Saved to long-term memory
(`procedural-per-player-materials-vision.md`) since it's context worth
carrying into unrelated future sessions, not just this plan.

---

## 2. Atom count, tracked honestly across the session

| Point in session | Total | Why it moved |
|---|---|---|
| Start (2026-08-05 plan) | ~192 | Original per-class enumeration |
| After D6/D7 | 135 | Cracked universal (−63), ceiling dented 3-shape (+24) |
| After D12 (bullets in) | 207 | +72 marked/bullet atoms, wall-only |
| If Task 2 turns on `ground_concrete.crack_factor` | 216 | +9, data-only change |

---

## 3. Documentation updated

- **`PROMPTS/PLANNING/EXPLOSION_REBUILD_MASTER_PLAN.md`** — the main body of
  work, four commits (`9e9cc89`, `7697500`, `6c789eb`, `6626b12`): header
  status, §1 (D1 rev, D5–D13), §3.2 (atom table rewritten twice), new §3.5
  (material scope + cache), §4.2/§4.3 (resistance clarified, vertical
  falloff proposed), §8 (task table), §9 (firearm-boundary narrowed,
  cache-management deferral added), §10 (all nine Qs resolved or
  cross-referenced), §11 (resume point kept current throughout).
- **`PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md`** §3 — forward-pointer noting
  D12 narrows the firearm-untouched boundary by one step (mark painting
  only), with an explicit disambiguation since that plan has its own
  unrelated local D12/D13 in §5b.
- **`docs/technical/MAPFILE_REFERENCE.md`** — added `damage_materials` to the
  "Reserved, not yet registered" list, so a future reader of the map schema
  isn't surprised when D13 lands.
- **`docs/technical/BAKE_SYSTEM_REFERENCE.md`** — forward-pointer noting D13
  is coming and that `TextureResolver`'s existing `user:// → default:// →
  material-only` fallback chain already anticipates player-specific
  overrides — the new work extends an existing idea, doesn't invent one.
- **`docs/README.md`** — added the missing `EXPLOSION_REBUILD_MASTER_PLAN`
  index entry (it didn't have one since the plan's creation on 2026-08-05).
- **Memory** (`~/.claude/.../memory/`) — new
  `procedural-per-player-materials-vision.md`, indexed in `MEMORY.md`.

---

## 4. State at close

- **VERSION 0.9.89** (unchanged).
- `run_selftests.py`: **29 clean, 0 failed.**
- `check_invariants.py`: OK. `gen_codemap.py --check`: clean.
- `project_lint.py`: PASSED, 181 files, only the usual 7 headless
  autoload false positives.
- Five commits this session (four plan-doc commits above, plus this closing
  summary), all pushed to `main`.
- Tag `alpha-pre-explosion-rebuild-master-plan` applied at the Director's
  request, matching this repo's existing `alpha-*` descriptive-checkpoint
  convention (not `verified/vX.Y.Z`, which this repo reserves for
  version-numbered checkpoints — no version was bumped this session).

---

## 5. Next session starts here

Read `EXPLOSION_REBUILD_MASTER_PLAN.md` §11 (kept current throughout this
session). In short:

1. **Confirm Q1b** — §4.3's proposed effective-ring formula
   (`horizontal_ring + max(0, floor_level - blast.floor_level)`, clamped) —
   before Task 2 is written. Not needed for Task 0 or Task 1.
2. **Run Task 0** — the bake-cost measurement spike, cold/uncached, over the
   real 207-atom table. This is the next concrete action; it was deliberately
   not run this session so the plan document could be finished first.
3. Then Tasks 1 → 6 in §8's order, remembering: Task 1 bakes the D12
   marked/bullet atoms but does **not** rewire `WeaponBenchController.
   fire_active()` onto them (its own later checkpoint, §11); Task 1 also
   builds D13's minimal cache and the new `MAPFILE_REFERENCE.md` section
   (read that doc's extension protocol first); do not start Phase B; do not
   scope the full dynamic cache-management system (§9) — that's later, on
   its own.
