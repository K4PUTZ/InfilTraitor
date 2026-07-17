# RESUMO_SESSAO — 2026-07-16 (ROOF BAKE)

**Active master plan:** `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` —
**PAUSED at Alpha Horizontal Bake Foundation** (end of this session).
**VERSION at session start:** 0.9.45
**VERSION at session end:** 0.9.48
**Mode:** Overlord direct implementation. Second session of 2026-07-16
(the first, `RESUMO_SESSAO_2026-07-16.md`, closed at Alpha Ceiling
Foundation with the bake experiment as open item #1 — this session ran
that experiment to a closed foundation).
**Tag:** `alpha-horizontal-bake-foundation`
**Screenshot session:** turned ON at open, OFF at close (visual phase).

---

## Executive Summary

The Director's open question — "can the wall bake system texture the roof
slabs through the same mechanism?" — is answered **yes, and closed as a
foundation**. The load-bearing discovery: `_get_plane_top()`'s mapping
`T(u−v, (u+v)/2)` was always an isometric projection of a flat 2-D grid;
walls consume it as `(column_in_run, level)`, a roof consumes the same
math as `(voxel_x, voxel_y)`. Adjacent roof voxels' screen offset (±16, +8)
equals the plane's crop-window offset exactly, so roof tops are
seam-continuous **by construction** — no new projection math was invented,
only a new consumer of the existing one.

The session ran as two waves with a real Director visual review between
them — the review caught three real defects the selftests were not shaped
to see, and all three were fixed same-session with the fixes proven by
new, locally-re-derived selftest criteria.

---

## Wave table

| ID | What | Status |
|---|---|---|
| ROOF-BAKE-01 | Roofs consume the bake system: `resolve_flat()`, `flat_baked` seam in `_set_voxel_cell`, roof generation hoisted above `_bake_textures()`, roof usage → wall sheets, `roof_bake_selftest.gd` 5/5 (incl. 2304-pixel continuity check + 7758 real roof voxels) | ✅ `c6edb71` |
| — | Director visual review (3 screenshots, N/E/S views): wood proves the mechanism; stone mirror-seams; concrete missing strips; metal pattern wrong; **roofs on the wrong buildings in rotated views** | ratified fix wave |
| ROOF-BAKE-02a | `layout_with_perspective()` rotates `solid_block_instances` (rectangle) + `voxel_prop_instances` (points) — closes old open item #7 | ✅ `f88d060` |
| ROOF-BAKE-02b | Level-aware roof border adjacency: suppress toward same-or-higher neighbour, eave over lower — kills the 1-voxel gap at storey steps | ✅ `f88d060` |
| ROOF-BAKE-02c | Dedicated `ROOF\|mat\|fac\|col\|row` page family: isotropic top projection (unscaled facade, full 1024×512 period), STRUCTURE-LOCAL keys (`Slab.texture_anchor`, one anchor per connected roofed-GU component) — kills world-line mirror folds; wall-sheet usage merge from 01 reverted | ✅ `f88d060` |
| — | Docs: master plan Part 2c, `BAKE_SYSTEM_REFERENCE.md` §ROOF-BAKE, this summary | ✅ session close |

---

## Decisions (Director-ratified)

1. **Roof texture anchor = connected roofed-GU component** (4-adjacency,
   level- and material-blind), NW-corner voxel origin, stored on
   `Slab.texture_anchor`. Rejected: per-declaration anchor (mirror seam
   every 8 voxels across PLAYGROUND's 5-in-a-row fixtures); global keying
   (ROOF-BAKE-01's first cut — mirror folds at x=64k/y=32k world lines cut
   through showcase roofs; confirmed against real map coordinates before
   the fix).
2. **Roof top projection = unscaled facade** (isotropic), dedicated page
   family — NOT the wall sheets, whose ×20/16 vertical pre-scale reads 25%
   stretched when laid flat. The wall-sheet reuse was correct as an
   experiment and wrong as a product.
3. **Storey-step border rule**: suppress toward same-or-higher (the taller
   wall's far-slice fills that seam column; growing into it would
   double-write Slice-owned cells — the exact split-brain D1-ROOF-b
   killed), eave over lower.

## Bugs found (all real, all fixed same-session)

1. **`layout_with_perspective()` never rotated `solid_block_instances` /
   `voxel_prop_instances`** — pre-existing (old open item #7), invisible
   until roofs became the first per-view visual consumer: wood roofs on
   stone buildings in E/S views.
2. **Storey-step border gap** — boolean adjacency made different-height
   neighbours mutually suppress borders neither could provide at the
   other's level ("falta um pedaço", real pair metal[5,14]/concrete[6,14]).
3. **World-line mirror folds through roof interiors** — global keying;
   verified against real PLAYGROUND coordinates (y=32 cut the showcase
   columns, x=64 the stone row, x=128 concrete[15,1]).
4. **`bake()` early-returned before roof pages on wall-less maps** —
   caught by the roofs-only selftest fixture, not by the real map.

## Observations (not fixed, recorded)

- **Slab-vs-solid-block overlap at storey steps**: a lower roof's core
  column overlaps the taller block's wall far-slice cells (pre-existing
  since D1-ROOF). Invisible today; latent Part 3 conflict — recorded in
  `BAKE_SYSTEM_REFERENCE.md` §ROOF-BAKE.
- **Multi-GU props** would need footprint-aware rotation in the mapper;
  all shipped PropDefs are 1×1 (verified), so 02a's point rotation is
  complete today.

---

## Testing evidence

All headless, real executions; expectations locally re-derived in-test
(own mirror fold, own component flood fill, own E-rotation math — never
read back from the code under test):

| Selftest | Result |
|---|---|
| `roof_bake_selftest.gd` (NEW) | 8/8 |
| `roof_integration_selftest.gd` (level-aware border expectations; bake explicitly OFF — geometry suite) | 5/5 |
| `bake_selftest.gd` | 19/19 |
| `slab_render_selftest.gd` | 8/8 |
| `roof_slab_selftest.gd` | 15/15 |
| `floor_integration_selftest.gd` | 9/9 |
| `slab_geometry_selftest.gd` | 15/15 |
| `earth_variant_selftest.gd` | 6/6 |
| `negative_storey_selftest.gd` | 12/12 |
| `fixed_floor_selftest.gd` | 5/5 |

Key roof_bake criteria: 2304 opaque top-diamond pixels ALL equal a direct
roof-plane read (95 distinct luminances — not blank-vs-blank); isotropy
proven structurally (576 px roof source vs 704 px wall source); **7778
real PLAYGROUND roof voxels** placed exactly as their structure-local
offset predicts (own flood-fill anchors), 2 real storey-step sides
exercising the eave rule; **49/49 blocks roofed at their
independently-rotated E-view position with correct material**.

Visual evidence: `Screenshots/history/auto_2026-07-16_17-35-18.png`
(ROOF-BAKE-01: first baked roofs, wood already excellent) and
`auto_2026-07-16_18-59-40.png` (ROOF-BAKE-02: metal fold-band gone,
concrete full-coverage isotropic). `project_lint.py`: 0 real compile
errors, 132 files, every commit.

---

## Open items (next session)

1. **Director in-game visual pass on all 4 views** — the auto-captures are
   N-view only; 02a's rotation fix and stone's de-seamed tops deserve
   eyes-on at E/S/W. Stone was the most fold-damaged material.
2. **Roof side faces** (border voxels): dir-0 wall-plane content at
   arbitrary rows — textured but wall-unaligned. Expected, not a defect;
   treatment is a Director visual call.
3. **Per-material roof facades** — metal's wall facade laid flat is honest
   but reads odd; dedicated roof art is the obvious next quality step.
4. **Roof occlusion participation** — still accidental/partial (Part 2b
   note stands).
5. **Slab-vs-block overlap at storey steps** — resolve within Part 3.
6. Prior session's items unchanged: Part 3 trigger, `usage_cells` (D3),
   depth shading (D7), D14 composite, crates get no roofs,
   `prop_01_tests.gd` criteria 4/6.

---

## Session statistics

- **Commits:** 3 (`c6edb71`, `f88d060`, + session close) — all pushed.
- **VERSION:** 0.9.45 → 0.9.48.
- **New production surface:** `BakedTileLookup.resolve_flat()`;
  `VoxelRenderer._set_voxel_cell(flat_baked)`; `Slab.texture_anchor`;
  compositor `_get_roof_plane_source/_get_roof_plane_top/_compose_roof_page(s)`;
  `room_builder` roof hoist + component anchors + level-aware borders;
  `perspective_mapper` instance rotation.
- **New selftest:** `roof_bake_selftest.gd` (8 criteria, two full real-map
  boots: N and E views).
- **Real compile errors:** 0 across the session.

---

## Conclusion

`DESTRUCTION_MASTER_PLAN` reaches **Alpha Horizontal Bake Foundation**:
the bake system now covers vertical (walls/junctions) AND horizontal
(roof) surfaces through one mechanism, with rotation-correct placement,
level-aware borders, and structure-anchored, isotropic, seam-free-by-
construction roof tops — all proven against the real map at pixel level.
What remains on roofs is art and polish, not mechanism.
