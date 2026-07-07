# BAKE-FIX-00 — Ground-Truth Audit: Real Atom Geometry & Facade Dimensions

> **Part of `PROMPTS/PLANNING/BAKING_SYSTEM_MASTER_FIX.md` (Phase 0). Read that plan
> first — this prompt only makes sense in its context.** Investigation + documentation
> only. **No changes to `bake_compositor.gd`, `per_face_projector.gd`,
> `material_atlas_generator.gd`, or any other live bake-pipeline code in this prompt** —
> those are BAKE-FIX-01's job, and BAKE-FIX-01 depends on this prompt's real numbers.

---

## CONTEXT

The entire BAKE-01…08 pipeline was built on a canvas-size conflation
(`BAKING_MASTER_PLAN.md` §3 Stage 5 wrote `texture_region_size = VOXEL_TILE_SIZE
(32×16)` when the real voxel asset is `VOXEL_ATOM_W×VOXEL_ATOM_H = 32×36`), and every
attempt to close invariant B3 (`FIX-BAKE-04`, `FIX-BAKE-09`, `FIX-BAKE-09b`,
`BAKE-SILHOUETTE-01`) failed because nobody re-derived the real geometry — each fix
patched code against another formula, never against the actual asset file. The Master
Fix plan's whole discipline is: **no number in this corrective sequence may be derived
from the code under test.** This prompt produces the one set of numbers everything
downstream depends on.

The ratified direction (`BAKING_SYSTEM_MASTER_FIX.md` §3, D-BAKE-1) replaces live
per-voxel shear-baking with a **master strip**: bake N real atoms once per
(material, facade, theme), straight rectangular facade crop per atom position, no
`PerFaceProjector`. This prompt measures the three unknowns that decision depends on:
what the real atom canvas looks like, which sub-region of it the facade multiply
actually applies to, and how long the strip needs to be.

---

## MODULE

- New: `docs/production/TILE_ANATOMY.md` (or overwrite if replacing a stale prior
  version — check first; if one already exists from BAKE-01, treat its numbers as
  unverified and re-derive rather than trust)
- New (tool, headless-safe, throwaway is fine but keep it if useful for later
  regression): a small script under `godot/scripts/tools/` that performs the
  measurements below and prints them — this is how you get literal, pasteable
  evidence, not a claim.

---

## TASK

### 1. Real atom canvas

For each of the 4 materials (`ASSETS/ISOMETRIC/source_assets/voxels/voxel_{concrete,metal,stone,wood}.png`):
- Confirm dimensions are exactly 32×36 (`VOXEL_ATOM_W`/`VOXEL_ATOM_H` in
  `geometry_coords.gd`) — do not assume, decode and check `Image.get_width()`/`get_height()`.
- Dump the alpha channel. Report: total pixel count, count fully opaque (a > 0.99),
  count fully transparent (a < 0.01), count partial/edge (anti-aliasing). This is the
  real silhouette BAKE-FIX-01 will copy verbatim — paste the histogram, don't summarize
  it as "looks right."

### 2. Which sub-region receives the facade multiply

`VOXEL_MASTER_PLAN.md` §3's atom diagram claims: top 16px = top face (occluded by
higher layers, per canon), bottom 20px (`y ∈ [16, 36)`) = side face (the "primary
visible surface"). Verify this against the real renderer, not just the doc:

- Read how `voxel_renderer.gd` / `_ensure_voxel_layers()` stacks consecutive levels
  (`VOXEL_STEP_PX = 20`, atom height 36 → each level overlaps the one above by 16px).
  Confirm which rows of a given atom are actually visible on screen at any single
  level once painter's-algorithm stacking is accounted for, and which rows are always
  covered by the level above. This determines the *real* crop region for the facade
  multiply — it may not be a clean `y ∈ [16, 36)` split once overlap is considered.
  State the actual answer with the reasoning shown, not just the doc's claim restated.
- If the visible region turns out to differ from the doc's 16/20 split, note it as a
  correction to `VOXEL_MASTER_PLAN.md` §3 (do not silently use the doc's number if your
  own trace disagrees — flag it).

### 3. Facade plane dimensions and master-strip length

- Confirm the 4 shipped facade PNGs (`res://textures/defaults/facade_*.png`) are
  1024×512 as expected (`64N × 32N`, `N = TEX_AUTHORING_N = 16`). Decode and check, not
  assume.
- Measure real wall-run lengths in the two maps that exist today (PLAYGROUND,
  SIGMA_01) — walk each map's compiled wall edges (via `map_compiler.gd` /
  `EdgeExtractor`, headless) and report the distribution of collinear-run lengths (min,
  max, median, in voxel-widths). This is the evidence for choosing the master strip's
  atom count in BAKE-FIX-01 — don't pick a round number, derive it from what the real
  maps actually need (long enough that mirroring is the exception, not triggered on
  every run).

### 4. Report

`TILE_ANATOMY.md` must contain, each traceable to the raw measurement above:
- Real atom dimensions + alpha histogram (×4 materials)
- The resolved visible-region answer for item 2, with the stacking trace shown
- Real facade dimensions (×4 facades)
- Wall-run length distribution + the strip-length recommendation derived from it
- An explicit "corrections to prior docs" section if anything here contradicts
  `VOXEL_MASTER_PLAN.md` or `BAKING_MASTER_PLAN.md`'s existing claims

---

## DO NOT TOUCH

- `bake_compositor.gd`, `per_face_projector.gd`, `material_atlas_generator.gd`,
  `baked_tile_lookup.gd`, `room_builder.gd`, `voxel_renderer.gd` — no code changes.
  This prompt measures; BAKE-FIX-01 implements.
- `BakeConfig.enabled` — untouched, stays `false`.
- Existing selftests — do not modify `bake_selftest.gd` or any BAKE-0x test in this
  prompt.

---

## ACCEPTANCE

- `docs/production/TILE_ANATOMY.md` exists with all four sections in §4 above, every
  number traceable to a literal console output pasted into the completion report (not
  paraphrased).
- The measurement tool's full raw output pasted in the completion report.
- `git diff --name-only` shows only new files (the doc + the measurement tool) — zero
  production code touched.
- `python3 tools/persistent/check_invariants.py` stays green (trivially, since nothing
  production changed).

---

**Scope:** investigation + 1 new doc + 1 new headless tool · 1 session · unblocks
BAKE-FIX-01.
