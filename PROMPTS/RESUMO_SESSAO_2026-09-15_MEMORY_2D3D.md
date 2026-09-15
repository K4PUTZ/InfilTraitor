# SESSION SUMMARY — 2026-09-14 / 15
## The 2D-vs-3D comparison, memory axis (DIAG-23)

**Director's request:** *"Vamos seguir com a comparação 2D x 3D"*. Four axes were open:
memory, look parity, the 3D stalls and the Galaxy. The Director chose **memory**.

**Full record:**
[`DEVICE_DIAGNOSTICS_MASTER_PLAN`](PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md) v1.6 —
§15.15 (measured) and §15.16 (proposed next).

---

## 1. What was built

- **`drop2d`**, a scenario step and an instrument (commit `b6b0b17c`).
  - It calls `Room.scenario_drop_2d_board()` → `VoxelRenderer.debug_drop_board_cells()`.
  - Under a 3D board it clears the hidden 2D board's cells: the opaque, glass and structure
    layers.
  - It keeps the floor layer, which gameplay reads, and the planes, which the 3D board reads.
  - It refuses loudly without `RENDER3D=1`.
  - `scenario_selftest` covers its parsing.
- **A memory table in `bench_analyze.py`:** `--mem-poll` samples per scenario segment, as
  first · median · last.
- **Two harness fixes** (commit `e588cdb8`):
  - `device_run.py` sorted a capture that crossed midnight wrongly;
  - the poll taken after `quit` was averaged into the last idle segment.

**Why not a true 3D-only load:**
- the load-time light apply writes the cell planes only for cells present in a 2D layer;
- the detonation plan skips cells without a tile.

So the atlas is removed at the source (`NO_BAKE`) and the cells are dropped after the load.
The 3D figure is an upper bound.

## 2. The result — Moto g04s, idle, portrait zoom 0.5, runs a / b

| | 2D, bake ON | 2D, NO_BAKE | 3D, NO_BAKE, 2D dropped |
|---|---|---|---|
| TOTAL PSS | 2 201 / 2 171 MB | 1 107 / 1 101 MB | **1 099 / 1 036 MB** |
| GL mtrack | 734 MB | 318 MB | **272–277 MB** |
| swap | 721 / 1 395 MB | 0 | **0** |
| boot → map loaded | 54.0 / 52.2 s | 19.1 / 19.6 s | 22.9 / 22.8 s |
| idle frame | 60.0 ms | 76.0 ms | 22.9 ms |

- **At the shipped look, 3D is about half the memory, and nothing is swapped.**
- **The half it saves is the bake atlas.** 207 944 dropped cells free only 59 MB of native
  heap and no graphics memory.
- 2D cannot drop the atlas at the same look. The paired capture shows 2D without it drawing
  the floor as a generic checker, while 3D keeps the facade.
- Retention, stated: the 59 MB stayed as heap free space in both runs.
- The peak at load was not measured.

## 3. Gates

- Lint: 0 errors.
- Selftests: 55 clean.
- `check_invariants`: OK; CODEMAP regenerated.
- Desktop real path:
  - drop in 12 ms; before/after captures differ by 0 px;
  - the red path (no 3D) aborts.

## 4. Where it stops — next session

The Director picks from §15.16:
1. the decision itself, which now has its memory row;
2. a clean 3D-only load, which is the render-neutral refactor;
3. decomposing the ~1.1 GB floor both representations share;
4. the Galaxy A16;
5. the detonation-stall items of §15.14.

The other axes of the comparison are still open: look parity, the 3D stalls and the Galaxy.
