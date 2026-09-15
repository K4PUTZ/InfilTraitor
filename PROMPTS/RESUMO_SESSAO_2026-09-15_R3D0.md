# SESSION SUMMARY — 2026-09-15
## RENDER3D R3D-0: the identity instrument, the `Voxel` cost on the Moto, and the baseline

**Director's request:** *"Vamos seguir com a sessão anterior."* The previous session ended
with [`RENDER3D_MASTER_PLAN`](PLANNING/RENDER3D_MASTER_PLAN.md) v1.0 written, and R3D-0 as
its next step.

**Full records:**
- `RENDER3D_MASTER_PLAN` R3D-0: what was built, the gate, the findings, and the device
  half;
- [`DEVICE_DIAGNOSTICS_MASTER_PLAN`](PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md) v1.8,
  §15.18: the device tables.

---

## 1. What was built (commit `5988234f`)

- **`BoardProbe`** (`godot/scripts/systems/board_probe.gd`), reached through the scenario
  step `probe <name>`.
  - It dumps every voxel of every slice, junction column and slab: coordinates,
    `visible`, damage, blast, carved side, variant, substrate and material. It also
    dumps every cell plane.
  - It reads the simulation's own record, never a tile, so it outlives the 2D board.
  - ⚠️ **It stores values, not the hashes the plan named.** A hash cannot say where two
    runs differ.
- **`tools/persistent/board_probe.py`**
  - `diff` compares two dumps per voxel and per plane texel.
  - `gate` boots each map twice and requires identity, plus a control that grenade #0
    changes the dump. `--env` flips a stage's flag.
- **The `alloc objects|packed|bytes <count>` scenario step** measures the `Voxel` cost on
  the device. `bytes` is a known-size positive control.
- **Small changes:**
  - `VoxelRenderer.cell_plane_levels()`;
  - `GRENADE_GUS` through DevFlags, so GLASS grenades reach the APK;
  - `board_probe_selftest`, and `scenario_selftest` extended.
- **Gates:**
  - lint 0 errors and 0 warnings;
  - **56 selftests clean**;
  - invariants OK, CODEMAP fresh.

## 2. The identity gate, earned on the unchanged simulation (desktop)

| map | voxels | run 1 vs run 2 · load · g0 · g1 | control, load vs g0 |
|---|---|---|---|
| PLAYGROUND | 216 104 | 0 · 0 · 0 | 460 voxels |
| GLASS | 114 280 | 0 · 0 · 0 | 3 867 voxels |

It was run twice: before the commit, and on `5988234f`, with the same numbers.

## 3. What the probe found (recorded, not changed)

1. **215 432 was the count of cells.** PLAYGROUND holds **216 104 voxels**.
2. **The first collision census, for R3D-1a:**
   - PLAYGROUND has 672 cells claimed twice, GLASS 160;
   - every one is a slice × slice corner of one GU, always with the same material.
   - Whether the two claims can diverge in damage is R3D-1a's rule to write.
3. **Junction column ids are not unique.** 8 ids on PLAYGROUND each name two different
   columns.
   - A lookup by id finds one of the pair.
   - Proposed as a separate task (investigate, then ask the Director) — not fixed here.

## 4. The device half — Moto g04s, APK `fb867845…`, 16 boots

- **A `Voxel` costs ~925 B on the Moto.** 215 432 objects add +190 MB of native heap in
  both runs, so PLAYGROUND's voxels cost ~191 MB — not the 316 MB of the desktop debug
  build.
  - Calibrated: the packed array reads +1 MB, and a known 190.7 MB reads +191 MB.
- **The baseline repeats DIAG-21/22/23 on every row:**
  - idle, 2D 60 → 135 ms against 3D 21.6–23.4 ms;
  - grenade #1, 27.1 s against 11.2 s;
  - memory, 2.18–2.20 GB with swap against 1.08–1.09 GB with none;
  - boot, 53 s against 23 s.
- **Grenade #0's device remesh folds 460 voxels,** the same count the probe reads on
  desktop.

- **The R3D-6 reference captures:** 2D / 3D pairs from the same APK, covering:
  - glass on PLAYGROUND and on the GLASS map;
  - decals, dents, whole facades and the floor grid;
  - soot and burnt voxels.

  What the pairs show:
  - **Glass is the largest gap.** 3D is pale cyan with washed-out variant tints, and it
    draws **no crack or craze on any pane**.
  - Decals and dents are flat dark squares in 3D.
  - The 3D floor is the smooth facade, with no 8×8 grid.
  - Two R3D-5 rows showed up: the dark diamond under the agent, and a red line drawn
    only in 3D (not identified).
- ⛔ **R3D-0 is measured but NOT closed.** Two items have no pair yet:
  - **roof tops (item 1):** the `roofs` framing shows a wall face;
  - **embers:** `detonate` waits past the fire.

  Both need a framing, or a capture inside the blast.

## 5. Next session

1. **R3D-1a** — the store layout spike (dense per-level grid vs per-container arrays). It
   now has its first collision number and a device object cost to beat.
2. **The Director's calls from `RENDER3D` §8**, asked at the stage that needs each one.
3. **The junction column id task**, if the Director starts it.
