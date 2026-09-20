# Session summary — 2026-09-19 — R3D-6 (glass, decals, dents) and R3D-7 (cutaway)

**Resume point:** the port's mechanics are in 3D and `RENDER3D` is the default. What is left is decided by the
Director: wall picking by ray, the Moto measurements of this session's additions, R3D-6 items 5–6 (look tuning,
deferred by the Director until the mechanics are done), then R3D-8 (retire the 2D board, the canon change).

## Commits (all on `main`, pushed)
| Commit | What |
|---|---|
| `7915188e` `[R3D-6e]` | **Root cause of the "incomplete `touched_voxels`":** `_collect_store` grouped claims with `>> 5` (32) while `_chunk_of()` uses 16, so a blast remeshed the wrong chunks. Fixed; the full-remesh workaround and `CONSEQUENCE_REMESH` deleted |
| `14fb469e` `[R3D-6f]` | `RENDER3D` on by default; `run_selftests.py` pins `RENDER3D=0` |
| `cbf25fea` `[R3D-6g]` | Glass erase + crack re-cut now run under `SKIP_BOARD_WRITES`; the soot wave reads the store (was an empty tilemap) |
| `c1abac6d` `[R3D-6h]` | Rim wedge: applied glass openings cut the pane along their polygon |
| `4810bdc2` `[R3D-6i]` | Dents: a DENTED voxel's carved face is a real recess in the mesh |
| `7ac1f9cb` `70354c0f` `[R3D-6j]` | Damage decals: `Texture2DArray` of the 42 decals + a lit decal quad per damaged face |
| `91a324dd` … `bdaa12ea` `[R3D-7a..i]` | Cutaway (see below); the last commit of the day shortens the dashes |

## The cutaway — what was decided
Two spikes were **rejected**: a cylinder around the camera ray (it cut the back wall — the camera looks down, so
the top of a wall BEHIND the agent counts as nearer in view depth) and a map-wide storey cut ("the player cannot know
what is behind the wall"). The spec is the Director's diagram of the **original 2D mechanism**: an occluded EDGE keeps
its bottom 2 voxels solid (8x2x2), everything above becomes a wireframe of the slices above with a fill whose opacity
varies. Built as: the 2D `OcclusionSet` decides (O1: view only); a column texture (min level, max level, ring + 1)
drives a Bayer dither in the face shader (kept / discarded / ghost diamond, density by ring, per-face contrast); the base
top is capped and the volume's sides are filled where a solid non-glass voxel stands across them; the outline is its
own line mesh, each piece classified by a ray march through the store (behind a real wall = dropped, back of the
volume = dashed, front = full). Details and the rejected alternatives: `RENDER3D_MASTER_PLAN` R3D-7.

## Findings worth remembering
1. **`render_priority`: a HIGHER value draws LATER.** -10 for a fill let the floor paint over it.
2. **A material that reads stencil must be in the alpha queue** (Godot 4.6 logs it and ignores the read otherwise).
3. **Depth-buffer tricks could not express "hidden behind a real wall, but visible through my own fill".** The fix
   was to classify each line piece on the CPU and draw the lines as an independent node.
4. **A dash longer than the segments it is applied to never breaks the line.** The set emits 1-voxel edges; merge
   collinear runs first. A corner shared by two faces is emitted twice — dedupe before dashing.
5. **`SKIP_BOARD_WRITES` hid three gaps** behind "the 2D board is hidden": glass authority (`_glass_layers`), the crack
   occupancy re-cut, and the plan builder's soot wave (it asked the tilemap whether a cell existed). Diagnosed by
   diffing the 2D and 3D `board_probe` dumps of the same grenade (`plane texels` 8 063 vs 5 345 → 823 floor cells).
6. **Pixel diffs were not an instrument here:** two identical captures differed by ~105 000 px. Vertex counts per chunk
   (commit vs a forced full remesh) were.
7. The 3D board still draws no glass panes in the cutaway; the 2D wireframe overlay is hidden while it is live.

## Evidence
`Screenshots/history/r3d7_cutaway_dither_spike.png` (PLAYGROUND) and `r3d7_cutaway_glass_map.png` (GLASS, agent at
16,15); the glass and blast captures of the previous session. Gates at every commit: `project_lint`, 60/60 selftests
(2D), `check_invariants`, `gen_codemap --check`. `board_probe.py gate` was run for the soot fix, not after the mesh-only
changes (dents, decals, cutaway).

## Open / next
- **Not measured on the Moto:** decals, dents, the rim wedge, the cutaway's per-step rebuild and ray march.
- **Not verified:** a bullet decal from a real shot; the crack decal art on a wall; cutaway on an upper storey, with
  guards, with glass, three-deep nesting.
- **Deferred by the Director (look tuning):** whole facades per wall run, embers / burnt voxels / floor shards, the
  floor-light jump at the end of a blast.
- **Needs the Director:** wall picking by ray (R3D-5's open item).
