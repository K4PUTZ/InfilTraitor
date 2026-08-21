# RESUMO_SESSAO — 2026-08-21 · ALPHA MATERIALS MASTERPLAN 0.9.106

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-20_PRECOOK_AND_WEAPON_CHARACTER.md`
**Commits:** `8e0dda68`, `a7763792`, `d5a4dc98`, `ae8c903b`, `25cf8b6a`,
`39436646`, `14afb4d6`, `63cfc5dd`, `b9a46b15`, `bfcf64ce`, `9a1c1ce7`, and this
one — all pushed to `main`.
**Gates at close:** lint 210 ✅ · selftests 35 clean / 0 failed ✅ · invariants ✅
· CODEMAP ✅.

---

## Read this first if you are resuming

**The materials milestone is PLANNED, not built.**
[`MATERIALS_MASTER_PLAN.md`](PLANNING/MATERIALS_MASTER_PLAN.md) is the live
document; `BURN_THROUGH_MASTER_PLAN` is superseded and kept only for its
reasoning. M1 is done — the five new materials render, break and are lit — and
every other part is designed and unbuilt.

Three rules this session produced, all forced by measurement:

> **A hole is not a target.** Nothing in the shot pipeline asked whether the
> voxel it was about to mark still existed, so a second shot re-marked holes the
> first had opened. `set_damage()` must not clamp (the segment-rewind system
> needs to walk voxels back), so the check belongs to whoever knows a hole when
> it sees one.

> **Any material with RESISTANCE below 0.706 reaches the cascade ceiling.** The
> arsenal's worst case is `3.528 / RESISTANCE` against a global 5.0. Every soft
> material hits it *by definition*, so the ceiling is per material now.

> **A material in `BASE_MATERIALS` but not in `VOXEL_MATERIALS` renders, and
> renders WRONG.** `glass` was in that state for months and nothing saw it,
> because a glass block had never been placed.

**Next blocking step:** M2 (decals — art) and M3-2b (half-thickness elements —
the milestone's largest single item, and it is not fire). M4a (glass blend mode)
is independent of everything and is the only part that changes a screenshot
without waiting.

---

## 1. The code pass, and the bug it found (`8e0dda68`)

A review of the previous session's W-TUNE/W-PRECOOK work, run before touching
anything.

**`plan_point_impact()` never asked whether its target still existed.** The shot
salt carries `room._world_revision`, which every shot bumps, so two shots at the
same target roll different luck — measured **1.11 then 0.96** against wood's
breach of 1.03, i.e. above the threshold and then below it, on the same wall.
The second shot wrote `DESTROYED -> DENTED` over voxels the first had opened.

Confirmed on the real map before changing anything, with a temporary probe in
`set_damage()`, two shotgun shots in one boot
(`INFILTRAITOR_SHOT_FILM_SECOND_AT=30`):

```
[PROBE-DOWNGRADE] voxel (144, 32) lvl=2 DESTROYED -> 3 (visible=false)
[PROBE-DOWNGRADE] voxel (157, 32) lvl=0 DESTROYED -> 3 (visible=false)
```

**What it did NOT break, checked rather than assumed.** Nothing healed on
screen: `_process_dirty_slice_voxel()` branches on `voxel.visible`, not on the
tier, and the soot BFS is guarded the same way. What it corrupted was the
**counts** — the second shot reported `wood:s1 dented=19` with two of the
nineteen being holes — and `WEAPON_MASTER_PLAN`'s calibration matrix is read
straight off that print. It also threw impact sparks at open air.

The fix invents nothing: D28 already rules that a fully-penetrated path leaves
no mark, and an existing hole IS that path. Green, same command, same binary:
downgrades **2 → 0**, `wood:s1 dented` **19 → 17**, `wood:s2 dented` **2 → 4**
(the rounds arrive behind instead). Pinned by
`test_point_impact_never_re_marks_an_existing_hole`, itself run red first.

Second, smaller: the per-material tier tally did `row[missing] += 1`, a hard
runtime error in GDScript — a diagnostic that could take down the shot it was
diagnosing.

## 2. The art order, and a gate that had to be earned (`a7763792`)

The Director authored five facades. The order that preceded them
([`ART_ORDER_NEW_MATERIALS.md`](ART_ORDER_NEW_MATERIALS.md)) was **one file per
material**, and each reduction was measured:

- **No voxel atom** — all 17 shipped atoms are 32×36 with byte-identical alpha
  (md5 `884d98981cee`), and alpha is the only channel a canonical atom's masking
  reads. Aliased in `BakePolicy.CANONICAL_ATOM_ALIASES`.
- **No roof texture** — roofs reproject the wall facade (ROOF-BAKE-02c).
- **No `_2` variant** — those files exist and are referenced by nothing.
- **No prop art** — a prop is built from dictionary materials
  (`PropDef.material_zones`); a cardboard crate is `crate_full.json` with one
  word changed. This removed what looked like the milestone's largest art ask.

**`check_facade.py` failed two SHIPPED facades on its first run**, both of which
render correctly and have for months — so the gate was wrong, not the art.
`facade_concrete.png` failed on alpha (B3 discards facade alpha entirely) and
`facade_metal.png` on a stale `.import` mtime (Godot rewrites the compiled
`.ctex` without touching the sidecar). Corrected, then proven against three
synthetic deliveries reproducing the real failure modes — full colour (the
actual `facade_earth` rejection), pre-squared to 1024×1024, and never imported.

## 3. Registration and the per-material cascade ceiling (`25cf8b6a`)

**The ceiling arithmetic.** The arsenal's worst case is
`3.0 × 0.70 × 1.4 × 1.0 × 1.20 = 3.528`, divided by RESISTANCE — so anything
under **0.706** reaches the global 5.0 with a shipped weapon, which D30.2
forbids. `glass` was already there at 0.4 → punch 8.82, and the selftest carried
a hardcoded `if material == "glass": continue` whose own comment said the
exclusion goes the day glass gets a real rule.

`CASCADE_MIN` is deliberately a **floor-lifting exception table**, not a
replacement: only materials whose worst case exceeds 5.0 get a row, so the
calibrated hard materials are untouched. It does **not** scale as
`1/resistance` — that would cancel the resistance term and make every material
need the same weapon to crater. Each row is its own worst case plus ~15%
headroom, so cardboard still cascades to a weapon ~2.7× weaker than metal.

The exclusion is retired; all 10 materials are measured against their own
ceiling as a ratio:

```
✓ arsenal worst case is sniper_rifle on wood (punch 4.41 vs ceiling 5.00)
  — 88% of that material's own ceiling, over 10 materials with no exclusions
```

Run red by deleting fabric's row: *"sniper_rifle on fabric (punch 11.76 vs
ceiling 5.00) reached 235%"*.

**`DESTROY_MIN` for the newcomers is derived**, from the Director's own spec —
*"os mais moles não vão destruir muito mais durante os tiros, mas na explosão o
fogo pega"*. `punch` already divides by RESISTANCE, so halving resistance would
double what a shot destroys; scaling the breach threshold by the same factor
cancels it. Two references: soft `= 1.03 × 0.80/r` (wood), mineral
`= 0.63 × 1.30/r` (concrete).

## 4. The blocks, and what placing glass found (`63cfc5dd`, `b9a46b15`)

All five placed at gu x=22/26/30/34/38 (step 4, not the reserved 5 — plywood was
a late addition and five 3-wide blocks at step 5 run past the 44-wide board),
each with a 3×3 floor zone so the same facade is exercised on the SLAB path too.

**`roof_bake_selftest` passes with a real glass block**, which closes the second
finding of `ROOF_BAKE_LEAK_2026-08-17.md`: the 520 missing roof lookup entries
were a missing **facade**, not a missing roof family.

**And it exposed a bug nothing else could have.** `glass` had never been in
`BakeCompositor.VOXEL_MATERIALS`. The moment a block existed, B6 fired — *"no
canonical voxel atom for 'glass' — will render unmasked rectangles"* — with
`voxel_glass.png` on disk the whole time. The loud-fail contract worked exactly
as designed.

**Seven lamps** followed, for a concrete reason rather than taste: every
existing lamp sat at x ≤ 16 and the new materials are at x=22..40, so they had
no light source at all. That is why the first capture came out near-black and
sent me measuring facade luminance to explain something that was never a
material problem — fabric computes to (0.37, 0.35, 0.31) against concrete's
(0.40). Capture: `Screenshots/history/mat_block_02_lit_five_materials.png`.

## 5. The milestone (`bfcf64ce`, `9a1c1ce7`, and this commit)

Six ordered parts: **M1** ✅ · **M2** decals · **M3** fire · **M4** glass ·
**M5** voxel props · **M6** fluids (research). The ordering is load-bearing:
M2 before M3 because a burning wall's intermediate states are marks, and
building fire against materials that cannot show damage means judging it blind.

### What the Director ratified

- **Ignition: explosions only, for now.**
- **Fabric and cardboard burn ENTIRELY**, always opening a passage. This makes
  them **object-scoped rather than radius-scoped** — simpler than the general
  spreading-front case, and it means the old "how far does it spread" question
  only ever applied to plywood.
- **Plywood** burns upward, embers, propagates at the edges, goes out; a grenade
  at the wall's **base** opens a way through.
- **Tick: `delta` for v1.** The previous turn-based recommendation is withdrawn
  on the Director's objection — a per-turn fire *frozen* between turns does not
  read as fire, and making it read right during thinking time needs a looping
  effect, where every VFX here is fire-and-forget. Kept behind ONE advance call
  so the turn-based version stays testable.
- **Glass needs a blend mode, not alpha** — *"ver a textura dele por cima do
  fundo… sem opacidade pura, pra não ficar lavado"*.
- **Fluids are a research task**, and the study is the deliverable.

### The passage rule, and the question it corrected

All three readings offered were wrong: they assumed the unit that stacks is a
voxel **level**. It is a **storey**. Underneath sat a vocabulary collision — the
Director's "slice" is one storey of wall on one GU face; the code's `Slice`
class is the whole face across every storey.

Checked rather than transcribed: the baked agent is **222 px against
`WALL_FLOOR_STEP_PX` 158 — 1.41 storeys tall**. A one-storey opening is 0.71 of
him (crouch), two storeys is 1.41× (standing).

### And the largest single item in the milestone, which is not fire

**Half-thickness elements.** Fabric, cardboard, glass and plywood occupy one
storey-face, on one of the two GUs, preferably the inner one — a glass window
covers one face and leaves the opposite face empty inside the opening, which is
what gives the reveal depth.

`SliceGenerator.generate()` calls `_create_slice(edge, true)` then
`_create_slice(edge, false)` with **no per-side gate anywhere**. Every wall in
the game is full thickness by construction.

§3.2c is the builder design, written against the real chain. Its load-bearing
finding: **`Edge._init()` canonicalises and swaps `gu_a`/`gu_b`**, so a boolean
`side_a` flag on the mapfile would silently mean different things for different
walls depending on which way the author drew them — the same defect class as the
`P3_WEAPON`/`GRIP_SUFFIX` collisions. **The side must be an absolute GU cell.**

What already tolerates a missing sibling (checked): `sibling_slice()` returns
null cleanly, both of its two real callers already null-check, and `all_slices()`
iterates what is registered. What does not: `voxel_renderer.gd:1892`'s final
fallback has no null branch, and `JunctionResolver` is edge-derived and
side-blind, so a half-thickness element still gets a full corner column.

**And the rule that must not be broken:** do not fake it by pre-destroying one
side. A `DESTROYED` voxel is a hole with soot, a damage atom and a history; an
**absent** voxel is geometry that was never there. Conflating them corrupts the
census, D24's soot-from-absence derivation, and the passage query itself.

---

## Open, in priority order

1. **M2 — decals.** 21 files (`bullet` ×4 materials, `dent` for brick/plywood,
   `crack` for brick). Art. Never a blocker: an unlisted material still takes a
   real mark via the material-agnostic generic family.
2. **M3-2b — half-thickness elements.** The critical path, §3.2c.
3. **M4a — glass blend mode.** Independent of everything; the only part that
   changes a screenshot without waiting on anything else.
4. **M3-1** — measure whether the light win is really free (it is read off the
   code, not measured), against a same-boot control.
5. **M6 — the fluid study**, whose four required answers are in §6.

## Carried forward, unrelated to materials

- **The rifle's and pistol's posed frames** —
  [`BAKE_ORDER_WEAPON_GRIPS.md`](BAKE_ORDER_WEAPON_GRIPS.md). Pressing `1`
  genuinely arms a rifle; the figure still holds a shotgun.
- **The aim warm is ~500 ms**, still the largest number in a shot.
- **Two glass calibration bugs**, now recorded in `MATERIALS_MASTER_PLAN` §4.2:
  a far shotgun pellet CRACKS glass against D22's hole-or-nothing rule, and
  glass's no-DENTED behaviour is a coincidence of `DESTROY_MIN["glass"]` and
  `PUNCH_DENT_MIN` both being 0.30.
