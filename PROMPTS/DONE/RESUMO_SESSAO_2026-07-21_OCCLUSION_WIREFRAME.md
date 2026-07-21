# RESUMO_SESSAO — 2026-07-21 (OCCLUSION WIREFRAME REDESIGN, SESSION CLOSE)

**Active master plan:** `PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md` — was
**IN PROGRESS**, now **⏸️ PAUSED** as of this session's close (Director's
call: resume once a real map has objects to occlude against; not scheduled).
**VERSION at session start:** 0.9.63
**VERSION at session end:** see `VERSION` (bumped for this closing commit).
**Mode:** Solo mode.
**Screenshot session:** never toggled ON; all captures via direct off-screen
runs with `INFILTRAITOR_CAPTURE_*` env vars, same technique as prior
occlusion sessions.

---

## Executive Summary

Opened with a docs-reconciliation prompt (unrelated to occlusion, closed
first), then the Director reported a real visual bug in the roof-occlusion
wireframe from the prior session (2026-07-18): a serrated/jagged internal
mesh instead of a clean silhouette. What followed was a full redesign of the
wireframe system across several iterations, each verified against real
capture pairs before moving on, ending with the Director explicitly pausing
occlusion work until maps have real objects to occlude against.

**Net result:** the wireframe went from "one independent box per structural
unit" (walls, roof GUs, junction columns each drawing their own box,
overlap at unit boundaries treated as expected) to **one unified hidden-
face-culling pass** over the already-shared occluded-column set — the same
principle voxel engines use for chunk meshing. Line style now follows a
hidden-line-removal convention (solid for camera-facing edges, dots only for
the far/hidden side). Ring alpha (shared between the real ghost material and
the wireframe's own fill) settled at 8%/16%/24% after two live retuning
passes. A same-day attempt to split walls and roofs into two independently-
culled entities was tried, verified, and then reverted on the Director's
call.

## Wave table

| ID | What | Status |
|---|---|---|
| DOCS-SYNC-01 | Reconciled `current_state.md`/`technical_debt.md` stale "binary detection" claims with real `turn_controller.gd` behavior (unrelated to occlusion, closed first) | ✅ `de377e0` |
| ROOF-OCC-02 | Roof wireframe: merge contiguous same-(ring,min,max) GUs into maximal rectangles instead of one box per GU — fixed the roof-GU-to-GU seam specifically | ✅ `406bcec`, superseded next day |
| OCC-27 | **Unified wireframe**: one hidden-face-culling pass over the shared occluded-column set (walls+junctions+roofs together), replacing every independent-box design since O13. Solid/dots line style by camera-facing direction. Two real bugs found and fixed mid-redesign (see below) | ✅ `b27970d` — current design |
| ALPHA WIREFRAME REDUX 0.9.64 / OCC-28 | Tried splitting walls+junctions and roofs into two independently-culled entities (allowed to overlap at their seam) | ⛔ `b66915c`, reverted same day via `5797213` |
| Ring alpha retuning | 3%/6%/9% → 6%/12%/18% → 8%/16%/24%, two live Director asks | ✅ `4f9e59c`, `2a95f3d` |
| Documentation close-out | `occlusion.md`, `OCCLUSION_MASTER_PLAN.md`, source doc-comments, this summary | ✅ this commit |

## Decisions (Director-ratified)

1. **Unify, don't patch axis-by-axis** (OCC-27): after ROOF-OCC-02 fixed the
   roof axis and a wall-to-junction seam of the identical class was then
   reported, the Director's call was to redesign the whole mechanism once,
   not keep patching one boundary type at a time.
2. **Research real-world technique before redesigning** (Director's explicit
   ask this session): compared CAD/engineering hidden-line-removal
   conventions, voxel-engine greedy meshing / hidden-face culling, and
   stealth-game x-ray silhouette techniques before writing the new
   algorithm — see conversation for the comparison; OCC-27's design borrows
   directly from the first two.
3. **Solid-vs-dots by camera-facing direction, not by ring** (Director):
   simplification request — "linha cheia... na frente; pontinhos... atrás."
4. **Wall/roof split reverted** (OCC-28): tried, verified via real capture,
   then reverted same day — "não ficou muito bom."
5. **Ring alpha 8%/16%/24%** (final, two live retuning asks from an initial
   3%/6%/9%).
6. **Plan paused** until a map has real objects to occlude against — not a
   defect, a deliberate stopping point.

## Key forensic findings (worth keeping)

- **Two real bugs found and fixed inside the OCC-27 redesign itself, both
  via real capture + targeted debug instrumentation, not code-reading:**
  1. *Interval-overlap vs exact-level match.* OCC-26 deliberately widens a
     roof border row's erase range to union with the wall column beneath it
     (so the erase itself never leaves a gap). An exact-level hidden-face
     test read that widened range as a mismatch against the roof's own
     unwidened interior neighbours and drew a false seam the wall's entire
     height — a dense vertical "curtain" of dots, not a real silhouette.
     Fixed by testing whether the two columns' vertical ranges overlap AT
     ALL, not just at the specific level being drawn.
  2. *Wrong edge orientation (the actual root cause of the dense mesh).*
     The first draft of the redesign drew a **horizontal** edge (`p1` to
     `p2`, both at the same level) once per level a face spanned — for a
     22-level-tall wall, 22 stacked horizontal "rungs" instead of 2 real
     vertical corner lines. Found by making the dot texture temporarily
     giant/red and looking directly at what was being drawn, after several
     rounds of hypothesis-and-measure had failed to explain a debug count
     that showed **zero** false-internal classifications. Fixed: real
     vertical lines (fixed lattice point, level → level+1), drawn only at a
     boundary run's true start/end (checked via a width-axis neighbour
     exposure test), not per interior voxel.
- **CODEMAP.md drift caught and fixed at the source**: a doc-comment in
  `occlusion_slice_panel.gd` still quoted the ring alpha's first (3%/6%/9%)
  value after two later live bumps — since CODEMAP.md is generated from
  that comment, it inherited the stale number. Fixed by removing the
  hardcoded value from the comment (point at the constant instead), not by
  hand-editing the generated file.

## Testing evidence

| Check | Result |
|---|---|
| `project_lint.py` | 0 real compile errors, every commit |
| `occlusion_set_test.gd` | 3/5 — pre-existing stale fixture (predates the OCC-08 trigger redesign), unaffected throughout, not touched |
| `roof_slab_selftest` | 15/15, unaffected throughout |
| `roof_integration_selftest` | 5/5, unaffected throughout |

Visual (real captures, TEXTURES map, same agent position/view compared
before/after at each step): before/after pairs for the interval-overlap fix,
the vertical-orientation fix, the OCC-28 split (and its revert), and both
ring-alpha bumps — see conversation for the actual images; not archived to
`Screenshots/history/` beyond the four `occ_view_*.png` stable-name files,
which reflect the FINAL (OCC-27, post-revert, 8/16/24%) state.

## Open items carried forward

- **Plan is paused, not closed.** Resume trigger: a real map with placed
  objects/props to occlude against. `docs/systems/occlusion.md`'s "Visual
  Occlusion" section is the up-to-date spec for whoever resumes this —
  `OCCLUSION_MASTER_PLAN.md`'s Decision Register is history past 2026-07-14
  fine-grained detail (see its own bridging note after O19).
- **OCC-20 through OCC-26 were never individually ratified in the master
  plan** (they landed directly against Director feedback across sessions
  without updating this document) — flagged with a bridging note in the
  plan rather than reconstructed, to avoid inventing detail not actually
  witnessed. If this matters later, `occlusion_set.gd`'s own inline
  `## OCC-NN (date):` comments are the real record.
- **Destruction-aware wireframe** (parking lot #1 in the master plan):
  OCC-27's hidden-face-culling test already works off real per-voxel
  occupancy, so a destroyed voxel becoming "not occluded" should fall out
  of the existing mechanism with no redesign — not verified against real
  destroyed geometry, since none exists yet.
