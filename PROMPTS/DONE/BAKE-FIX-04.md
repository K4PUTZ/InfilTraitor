# BAKE-FIX-04 — Documentation Reconciliation

> **Part of `PROMPTS/PLANNING/BAKING_SYSTEM_MASTER_FIX.md` (Phase 4). Depends on
> BAKE-FIX-00…03 landing. Doc-only prompt — no production code changes expected.**

---

## CONTEXT

Three documents now describe a baking architecture that no longer exists after
BAKE-FIX-01/02: `BAKING_MASTER_PLAN.md` (the original per-face/32×16 design),
`docs/production/current_state.md` (which separately still describes a third, never-
implemented "VOXEL-08/09 WallSlice.bake_texture" model as "pending"), and
`docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md` (whose §7 crop+multiply
description turned out to be closer to what actually got built this time than
`BAKING_MASTER_PLAN.md` was). None of this is optional cleanup — leaving stale
architecture docs in place is exactly the "silent canon drift" pattern this whole
correction exists to stop repeating.

---

## MODULE

- `PROMPTS/DONE/BAKING_MASTER_PLAN.md`
- `docs/production/current_state.md`
- `tools/persistent/OPERATOR_CONTEXT.md`
- `tools/persistent/CODEMAP.md` (regenerate the Baking System section)
- `docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md` (only if BAKE-FIX-00 found a
  real discrepancy in §3's atom diagram — otherwise no change needed there)

---

## TASK

### 1. `BAKING_MASTER_PLAN.md` correction addendum

Do not edit the original decision register in place — add a dated addendum (same
convention as `JUNCTION-COMPLETION.md`'s addendum pattern) stating:
- Stage 5's `texture_region_size = VOXEL_TILE_SIZE (32×16)` was a conflation with the
  real atom size (32×36); superseded by `BAKING_SYSTEM_MASTER_FIX.md`.
- §4.5 (`PerFaceProjector`) is retired — the per-face affine shear it modeled has no
  counterpart in the real renderer; superseded by the master-strip approach.
- D5 (facade window addressing) survives, but "isolated" was the only mode ever wired
  before this fix — run-continuity was speced, unimplemented, and is now real.
- Link to `BAKING_SYSTEM_MASTER_FIX.md` as the authoritative document going forward
  for this subsystem.

### 2. `current_state.md` reconciliation

Its "Voxel Rendering System" section still lists `VOXEL-08` (Primary Baking) and
`VOXEL-09` (Secondary Baking) as "pending" describing a model
(`WallSlice.bake_texture`, `VoxelRef.face_atlas_rect`) that was never built and isn't
what BAKE-FIX-01/02 built either. Replace that section with an accurate description of
what actually ships now (master-strip bake + run-walking + junction-column handling),
and keep `VOXEL-09`'s true secondary-baking/per-HighWall-texture concept explicitly
listed as still-pending (Phase 5 of the master fix plan — not silently dropped).

### 3. `OPERATOR_CONTEXT.md` / `CODEMAP.md`

- Update the "Baking System" section's architecture description (currently describes
  `PerFaceProjector`, per-face 32×16 tiles) to match what's real: master-strip bake,
  atom-based, run-aware placement.
- Regenerate `CODEMAP.md`'s baking-related entries against the actual current file
  set (post-archival of `per_face_projector.gd`/`material_atlas_generator.gd`).
- Confirm B3's entry reads as genuinely closed (BAKE-FIX-03's evidence), and that the
  Known Limitations list still accurately reflects what's deferred (Phase 5).

### 4. Archival

Move `BAKE-FIX-00` through `BAKE-FIX-03` (and this prompt) to `PROMPTS/DONE/` per the
Director's normal manual-archival rhythm — or leave at root if follow-up micro-fixes
are still expected; either is fine per project convention (archival timing is not a
correctness signal).

---

## DO NOT TOUCH

- Any production `.gd` file — this is a documentation-only prompt.
- The historical record in `BAKING_MASTER_PLAN.md`'s original body — addendum only,
  never silently rewritten.

---

## ACCEPTANCE

- `git diff --name-only` shows only `.md` files.
- Each of §1–3's target docs contains the specific correction described, not a
  generic "updated for accuracy" edit — reviewer should be able to see exactly what
  changed and why by reading the diff alone.
- `python3 tools/persistent/check_invariants.py` stays green (no code changed).
- Bump `VERSION` per repo convention.

---

**Scope:** 4-5 docs updated · 1 session · closes out the `BAKING_SYSTEM_MASTER_FIX`
wave (Phase 5 — secondary baking/destructible slices — remains explicitly open for a
future wave).
