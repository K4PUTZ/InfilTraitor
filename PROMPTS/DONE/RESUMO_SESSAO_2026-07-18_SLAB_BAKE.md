# RESUMO_SESSAO — 2026-07-17/18 (ALPHA SLAB BAKE FIX)

**Active master plan:** `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` —
still **PAUSED at Alpha Horizontal Bake Foundation** (this session was a
Director-reported visual bug wave on the slab/junction bake, not plan work).
**VERSION at session start:** 0.9.52
**VERSION at session end:** 0.9.59
**Mode:** Solo mode, Director-driven fix wave (diagram-guided).
**Screenshot session:** one-off captures per fix (`INFILTRAITOR_SCREENSHOT_ONCE`),
never left ON.

---

## Executive Summary

Four Director-reported visual defects, all fixed with real-capture evidence,
plus one self-inflicted regression caught by the Director and fully reverted
same-session. The through-line: the roof/slab bake was designed around the
wall sheet's `(col, row) = (run position, level)` roles, and every defect
traced to a place where a slab or junction consumed a coordinate the wall
math never had to: the SE half-face consumes **y as a run position**
(ROOF-SIDE-03), and junction columns consume **columns outside the run**
whose mirrored fold REFLECTS (JUNCTION-MIRROR-02).

Two diagnostic lessons worth keeping: (1) a max-statistic over per-atom
diffs "confirmed" a mirror violation that was actually 7 asymmetric
silhouette-alpha edge pixels per atom — medians/counts before conclusions;
(2) channel-tint probes (tint a compose path, capture, see what lights up)
resolved in minutes what pixel-forensics could not: they proved the roof
atoms/placement were innocent and located the true smear source (wall-top
diamonds showing through canonical-silhouette notches — which the Director
then ratified as **intended**, closing that line entirely).

---

## Wave table

| ID | What | Status |
|---|---|---|
| OCC-23 | Wireframe panels draw in front of lower-level voxels: OCC-21f's `z−5` dropped low panels below the edge's own opaque base band; now `z−1` (in front of everything strictly below, still behind own-level visible voxels; tree-order tiebreak favors the overlay) | ✅ `231f7ab` (0.9.53) |
| ROOF-SIDE-02 | Side halves masked to border-exposed cells only (2-bit mask in ROOF key, `Slab.side_masks`) — **misdiagnosis, fully reverted by ROOF-SIDE-04**; kept in history for the record | ✅→↩ `8d72ee8` (0.9.54) |
| ROOF-SIDE-03 | Slab SE half-faces run in the wall-below direction: dir-1 plane, transposed fold (run position = y, band index = x, stagger = y); ROOF key folds BOTH axes at period 64; `_band_index()` re-derives 32-band indices; bake v6 | ✅ `006c854` (0.9.56) |
| ROOF-SIDE-04 | Solid slabs: every roof atom paints both side halves again; the v5 masking left slabs hollow under occlusion see-through (and would leave destruction holes); full machinery removal, −189 lines; bake v7 | ✅ `16ac6cd` (0.9.57) |
| JUNCTION-MIRROR-02 | Lateral V-junction columns repeated the adjacent wall column: `_mirror_index()` drops the fold's reflection bit; reflected raw columns (−1 at box corners, 208 at perimeter far corners) now sample the plane mirrored in texture space with per-column shear compensation (`_is_reflected_fold()` + `_blit_half_mirrored()`); center corners untouched; bake v8 | ✅ `067ec70` (0.9.58) |
| — | Docs updated (`BAKE_SYSTEM_REFERENCE.md`: OVERLORD-FIX-02 correction, TOP-JUNCTION-06 addendum, ROOF keys/composition rewrite, limitation #1 resolved), this summary, session close | ✅ session close (0.9.59) |

Between OCC-23 and ROOF-SIDE-03 the Director landed their own commits
(`6fc4397` OCC-24/25 vector-circle dots, `8da9d4e` occlusion panel alpha fix,
0.9.54→0.9.55) — not part of this wave's scope.

## Decisions (Director-ratified)

1. **Wall-top leak-through is intended.** The dot grid on wall faces (and
   its denser strip at rooflines) is wall-top diamond content showing
   through canonical-silhouette notches. Green-tint probe surfaced it;
   Director: "essa parte verde está correta e funcionando". Not a defect;
   no fix wanted.
2. **Slab side faces must run in the wall-below direction** (diagram,
   2026-07-18): left half always did (dir-0, run = x); right half now
   samples dir-1 with transposed roles. Ratified after ROOF-SIDE-03
   evidence: "Maravilha, é isso aí. Faces laterais resolvidas."
3. **Slabs are solid.** Interior roof voxels paint both side halves —
   occlusion see-through and future destruction both expose interiors.
4. **Lateral junction columns mirror** (never repeat) the adjacent wall
   column; center V-junction behavior stays as-is. Implemented as the
   general reflected-fold rule, which also covers perimeter far corners.
5. **Corner "ears" are not a defect** — that reading was back-wall
   occlusion ghosting triggered by agent presence.

## New tooling / knowledge

- `INFILTRAITOR_CAPTURE_AGENT_CELL` expects **compiled** (post-buffer)
  coords, not internal map coords — worth a doc line on the env var.
- Channel-tint probes as the standard "which compose path feeds these
  pixels" instrument (roof halves cyan/magenta; interior atoms magenta;
  wall tops green — each settled a hypothesis in one capture).
- `_is_reflected_fold()` / `_blit_half_mirrored()` (bake_compositor):
  reusable pieces for any future consumer of mirrored-repeat folds.
- Screenshot diffs (`ImageChops` + hot-column ranges) localize bake-change
  effects to exact screen strips — used to prove JM-02 touched only
  junction columns.

## Testing evidence

| Check | Result |
|---|---|
| `roof_bake_selftest` (keys re-derived under 64×64 fold, twice reworked) | 8/8 every commit |
| `bake_selftest` | 19/19 |
| `slab_render_selftest` | 8/8 |
| `fixed_floor_selftest` / `floor_integration_selftest` | 5/5, 9/9 |
| `negative_storey_selftest` | 12/12 |
| `bake_cache_test` | 7/7 |
| `project_lint.py` | 0 real compile errors, every commit |

Visual (all real captures in `Screenshots/history/`):
`auto_2026-07-17_16-04-52` (OCC-23: wireframe over base ring),
`auto_2026-07-17_23-58-02` (ROOF-SIDE-03: SE band continuous with wall),
`auto_2026-07-18_00-19-25` (ROOF-SIDE-04: solid slab underside, occluded view),
`auto_2026-07-18_00-45-31` + `occ_view_E` (JM-02: mirrored lateral corners,
diff-verified to touch only junction column strips).

## Open items carried forward

- Junction mirror on fine textures (concrete/metal) is visually subtle —
  Director to ratify in play; stone is the showcase.
- Remaining ROOF-BAKE known limitations (roof tops show wall facade laid
  flat; slab-vs-far-slice overlap at storey steps; roof occlusion
  participation) unchanged from 2026-07-16 — see
  `BAKE_SYSTEM_REFERENCE.md`.
- ART-01 (materials & objects pipeline) still gated to the Alpha→Beta
  window.
