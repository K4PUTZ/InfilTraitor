# RESUMO SESSÃO: TOP_TEXTURE Parts 1–2 Closure + Baking System Milestone (2026-07-11)

**Architect:** Claude (Overlord) · **Director:** Matt
**Status:** `TOP_TEXTURE_MASTER_PLAN.md` Parts 1–2 CLOSED, Director-ratified
("ALPHA TOP TEXTURE" checkpoint). Part 3 (textured interiors) stays open,
blocked on the destruction system. Baking System as a whole is
**partially-complete and milestone-tracked** (`VOX-BAKE-01` added to
`docs/production/milestones.md`), not fully closable while Part 3 is open.

---

## Context for a fresh session

This session closed the loop the previous one (2026-07-10, "Alpha Walls
Textured") left open: TOP-01 had shipped tops that rendered as unprojected
squares while its own completion report certified all criteria PASS. The
Overlord broke the corrective into four single-mechanism prompts
(`TOP-00-baseline` → `TOP-SHEAR-01` → `TOP-CROP-02` → `TOP-JUNCTION-03`),
each ≤4 acceptance criteria — the first real exercise of the prompt-sizing
rule tightened after the TOP-01/02-c pattern of "novel geometry + red-before-
green skipped inside a big prompt." All four landed clean; Director confirmed
visually (screenshot: continuous diamond-projected slab through a junction
corner). This session's work was the **milestone-closure pass**: verify the
whole thing end-to-end, fix what a fresh-eyes read turned up, retire dead
code, and push a clean checkpoint.

## What shipped this session (Overlord direct, no new prompt)

1. **Real FNV-1a hash fix.** `BakeCompositor._fnv1a_64()` was a home-grown
   XOR/shift function *labeled* "FNV-1a" that never multiplied by the FNV
   prime — a second, non-canonical hash living beside the real, B4-tested
   one in `FacadeSampler._fnv1a_hash()`. This is exactly the drift B4 (FNV-1a
   determinism, project-wide) exists to prevent, and exactly what the
   BAKE-CACHE-01 prompt had explicitly asked the Operator to avoid ("reuse
   the project's existing implementation... do not add a third hash").
   Fixed to the real algorithm (offset basis 2166136261, prime 16777619).
   Old `user://bake_cache/*.png` files invalidated harmlessly (different
   keys; regenerate on next miss — cleared this session).
2. **MULTIPLY set as the shipped dev default** (`BakeConfig.blend_mode`
   static + the local `bake_config.cfg` override, which was still pointing
   at the superseded `TEXTURE_ONLY` value and would have silently
   overridden the code default). Director ratification from the prior
   session, applied here.
3. **Legacy-test debt retired.** `baked_tile_lookup_test.gd` and
   `block_01b_baking_e2e_test.gd` (BAKE-05-era, calling APIs that no longer
   exist — `_make_bake_key`, `atlas.pages`) moved to
   `godot/scripts/tools/_archive/` per the project's own
   `docs/technical/archive_policy.md`, with a manifest README explaining
   why and what supersedes their coverage. Neither was wired into lint/CI;
   pure dead weight removed, nothing live touched.
4. **Full suite re-verified green** post-cleanup: `bake_fix_02` 3/3,
   `bake_fix_09` 5/5, `bake_fix_11` 7/7 (0/9,437,184 alpha mismatches),
   `bake_fix_12` 10/10, `bake_selftest` 19/19, `bake_cache_test` 2/3 (see
   open item below), lint 0 errors, headless TEXTURES boot 128928/128928
   baked hits with the real MULTIPLY config.
5. **Recovered accidental data loss.** Found while auditing `PROMPTS/DONE/`
   for the milestone summary: commit `eb15ef3` (`TOP-01-b`, 2026-07-10)
   reorganized `PROMPTS/DONE/` into topic subfolders (`BAKE/`, `SLICE/`, …)
   via what git recorded as ~100 renames — but **six `RESUMO_SESSAO_*.md`
   files had no corresponding move and were simply gone** from the working
   tree (including the 463-line `RESUMO_SESSAO_20260704_BAKE_FIX.md` and
   the prior session's own summary). `PROMPTS/DONE/` is explicitly
   Director-only territory per `OPERATOR_CONTEXT.md` — this was a real
   violation, invisible in a `git show --stat` skim because it read as
   "just renames." Restored all six from the pre-deletion commit (`2b8b0b5`)
   verbatim; **OPERATOR_CONTEXT.md amended** to explicitly ban bulk
   reorganization of `DONE/`, not just single-file edits, citing this
   incident.
6. **Documentation:** `TOP_TEXTURE_MASTER_PLAN.md` updated with the
   as-executed prompt sequence and closure status (Parts 1–2 closed, Part 3
   open); `BAKE_SYSTEM_REFERENCE.md` gained the TOP-SHEAR-01/CROP-02/
   JUNCTION-03 canon section; `docs/production/milestones.md` gained a
   `VOX-BAKE-01` entry (the milestones doc had no Baking System entry at
   all — it was tracked purely through master-plan documents until now).

## Open items, priority order

1. **BAKE-CACHE-01 warm-boot budget still failing**: measured ~730–770 ms
   against the 150 ms target. Confirmed CPU-bound (PNG decode of ~20 MB
   across 8 sheet pages, 2.3–3.2 MB each), not I/O or hashing (hashing is
   µs-scale). Not blocking Parts 1–2 closure — correctness (byte-identical
   round-trip) is proven and cold bake is already fast (~0.4–1.2 s). Needs
   its own small prompt if pursued: smaller page footprint, faster codec,
   or parallel page loads are the candidate directions, none attempted.
2. **TOP_TEXTURE_MASTER_PLAN Part 3 (textured interiors) — NOT STARTED**,
   deliberately. Blocked on a destruction-system implementation plan that
   does not exist yet. D-TT4 (the B5 invariant amendment) stays PENDING
   until Part 3 closes — do not promote it into the context static cores
   before then.
3. **LINEAR_LIGHT / OVERLAY_EXPERIMENTAL** blend modes still render as
   TEXTURE_ONLY (logged loudly at runtime) pending LUT page variants —
   parked since v0.5.0, pick up only if the Director asks post-MULTIPLY-canon.
4. **INTERFACE_MASTER_PLAN** — still the next master plan in the queue
   (named in the 2026-07-10 session), now genuinely next since the Baking
   System's actively-worked portion (Parts 1–2) is closed. Not drafted yet.
5. **`PROMPTS/DONE/` hygiene**: the `eb15ef3` reorganization into subfolders
   (`BAKE/`, `SLICE/`, `CODING/`, `CONTAINER/`, `MODULARIZE-05.../06...`)
   otherwise looks intentional and reasonable — Matt's call whether to keep
   the subfolder structure or flatten back; not reverted here, only the
   lost files were restored (to `DONE/` root, matching their pre-reorg
   location — Matt may choose to re-file them into `BAKE/` etc. on his own
   schedule, per the "archival is entirely Matt's manual action" rule).

## Version / tags this session

`VERSION` bumped for the push. Tag `verified/v0.5.1` ("Alpha Walls
Textured") → this session's checkpoint tag `verified/v0.6.0` ("Alpha Top
Texture") once pushed.
