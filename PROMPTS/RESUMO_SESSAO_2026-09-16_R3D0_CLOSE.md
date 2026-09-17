# SESSION SUMMARY — 2026-09-16
## RENDER3D: R3D-0 closed, the `RNG_SEED` fix, R3D-1a (layout B), R3D-1b (the store in shadow) and R3D-1c CLOSED (five readers on the store)

**Director's request:** *"Vamos seguir com a sessão de ontem."* Yesterday ended with R3D-0
measured but not closed. Two R3D-6 items had no Moto pair: roof tops (item 1) and embers.

**Full records:**
- [`RENDER3D_MASTER_PLAN`](PLANNING/RENDER3D_MASTER_PLAN.md) v1.2, the R3D-0 section
  "the two missing pairs, and the gate closed";
- [`DEVICE_DIAGNOSTICS_MASTER_PLAN`](PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md) v1.9,
  §15.18.6.

---

## 1. What was built (commit `13562fba`)

- **The scenario step `capture_at <beat> <offset> <name>`.**
  - It arms a capture taken `<offset>` after the Room names a blast beat (`SOOT_FADE`,
    `CONSEQUENCE`…).
  - The offset is in frames (`2f`), or in seconds of process delta (`1.5s`), the clock the
    embers age on. So a 2D run and a 3D run capture the same moment, even though their
    frames cost very different times.
  - A capture still armed at `quit` is a `push_error`.
- **`Room.blast_beat(beat)`**, emitted by `event_probe_beat()` whether or not the frame
  probe is on.
- **`scenario_selftest`:** two `capture_at` steps in the ladder, and six refusals.
- **Gates:**
  - lint 0 errors;
  - 56 selftests clean;
  - invariants OK, CODEMAP regenerated.
- **Desktop check:** 2D and 3D both captured `SOOT_FADE 2f` and `CONSEQUENCE` at
  0.4 / 1.0 / 2.0 s. A `NEVER_NAMED` arm was reported at quit.

## 2. The Moto run — APK installed with sha256 `c3a1a6d3…`, 4 boots

- Every armed capture landed on its moment: 2D at +0.06–0.07 s (long frames), 3D within
  0.02 s.
- **The framings with no blast running repeat from run a to run b:**
  - roofs: 0 px;
  - closing frame: 0 px in 2D, 0.37 % in 3D.
- **In-blast frames differ between runs by 31–85 %**, because every particle rolls its
  own values. What repeats is the stage of the effect, in a/b and in 2D/3D: yellow at
  0.4 s, orange at 1.0 s, coals at 2.0 s.
- **Embers:** the same in both renderers, since they are a 2D overlay. Only in 3D, brown
  flecks and white dots sit on top of them — not identified.
- **Soot fade:** two frames in, 2D is part-way through darkening, and 3D has no scorch
  yet. The spike recolours soot once, after the fade, as its header says.

## 3. The finding: the dark "roof tops" are not roofs

- A PLAYGROUND material block is a **hollow box**: walls two storeys tall, under a
  CEILING slab at levels 96–97. Its roof reads **lit** in 3D, on the Moto and on desktop.
- The dark rhombus is the box's **interior floor at ground level**, drawn over the 3D
  walls. In 2D, the walls cover it.
- **Desktop bisection**, with a temporary hide patch that was never committed:
  - `shadow_full_layer`: no change;
  - `_tile_shadow`: removes the fill;
  - `_shadow_boundary_overlay`: removes the outline.
- The GU grid over the walls is the same kind of row. The **red line survives hiding 11
  overlay nodes**, and is still unidentified.
- **Director:** *"pode mover o item 1"*. R3D-6 item 1 moved to R3D-5; its number is kept so
  items 2–7 keep theirs.

## 4. `RNG_SEED` never reached an APK — fixed (commit `9740116a`)

- **Before:** `Room._ready()` read it with `OS.get_environment()`, not `DevFlags`, and none
  of the 20 Moto logs from 2026-09-15/16 prints `[RNG] seeded`. Every earlier device table
  that lists `RNG_SEED` ran with its particle rolls unseeded.
- **The fix** (Director: *"corrigir o RNG_SEED"*): it is read through `_dev_flag()`, which
  still asks the environment first.
  - Desktop: `=7` prints `seeded 7`, and no variable prints nothing.
  - 56 selftests are clean.
- **On the Moto:** the APK (sha256 `e9ede4ab…`, on disk and on the phone) was re-run as the
  same 4 boots (`r3d0c_*`), and **all 4 print `[RNG] seeded 1`**.
- **What the seed did not do:** the in-blast frames still differ by 32–42 % from run a to
  run b. Only 3D's fade frame moved, from 85 % to 18 %. The remaining variation is not
  attributed.

## 5. R3D-1a — the store layout, measured (Director: *"pode seguir com o R3D-1a"*)

- **The rule came first, in commit `43af4062`.**
  - Candidates:
    - O, today's objects, as the reference;
    - A, the dense grid;
    - Ac, A per allocated chunk (added because A grows with map volume, and §14.1's mission
      map is 54×108 GU);
    - B, per-container arrays plus a derived grid.
  - The gates, in order: identity with O; memory ≤ 10 % of O; no hot reader more than
    10 % slower than O on the Moto; lowest T2 + T3 wins.
- **The spike:** `StoreLayoutSpike`, reached through the scenario step `store_spike <reps>`
  (`54b98629`, `8c7b2e55`).
- **Identity:** every kernel on every layout equals O on 5 maps. That includes PLAYGROUND
  after two grenades beside box corners, and it held on the Moto.
- **Memory:** all layouts are under 10 % of O everywhere. On PLAYGROUND, A is 14.6 MB,
  Ac 7.9 MB and B 13.5 MB, against O's 191 MB. For the §14.1 mission map the ESTIMATE is
  A ~80, Ac ~40 and B ~74 MB, against O ~1 064 MB.
- **On the Moto, medians in ms, in the order T1 · T2 · T3:**
  - O: 1 364 · 788 · 362;
  - A: 481 · 593 · **422** — fails the speed gate;
  - Ac: 1 045 · 641 · 292;
  - B: 481 · 417 · 134.
- **The rule picks B.** Its T2 + T3 is 550 ms against Ac's 933. ⏳ The Director confirms
  it before R3D-1b.
- **Collisions:** the two claims of a corner cell DIVERGE under a blast — 16 of the 18
  damaged corner cells after one grenade. R3D-0's "0 divergences" had no damaged corner
  in it. B keeps both claims, so the choice of B needs no ruling on this.

## 6. R3D-1b — the store in shadow (Director: *"pode confirmar o B e seguir com o R3D-1b"*)

- **Built (commit `eaa191e8`):**
  - `VoxelStore` (layout B), behind `VOXEL_STORE=1`.
  - It is rebuilt right after both `build_from_layout()` calls, and mirrored from
    `Voxel.set_damage()` / `set_visible()`, the only writers of voxel state.
  - A claim is found from the container's box geometry, VERIFIED per voxel at build
    (0 irregular containers).
  - Unplaceable writes are counted.
- **Instruments:**
  - `BoardProbe.write_store()` writes the objects' dump format;
  - scenario steps `probe_store`, `shoot`, `reload`, `save_restore` and `perspective`;
  - `board_probe.py shadow`;
  - `voxel_store_selftest` — 5 tests, and 4 fail with the mirror sabotaged.
- **The gate: SHADOW PASS.**
  - PLAYGROUND: load, corner grenades ×2, a shot, views E/S/W/N, a SaveState round trip
    and an F2 reload — IDENTICAL at all 10 stages.
  - GLASS: the same stages without the shot, with a pane shatter from the grenades — all 9
    identical.
  - Both maps: grid mismatches 0, lost writes 0.
  - Controls: 611 / 3 867 / 19 voxels.
  - Pixels: flag off vs on 0 px on a crater frame, control 0 px.
  - Lint 0 errors, 57 selftests clean, invariants OK.
- **Found by the controls, NOT caused by the store:**
  - A rotation round trip on PLAYGROUND loses the damage of 21 voxels (11 junction-column,
    10 box-corner), and the SaveState restore loses the same.
  - Likely `_reapply_base_damage()`, which indexes only slices and slabs, and keys by
    cell.
  - Offered as a separate task.

## 7. R3D-1c step 1 — the light field's occupancy onto the store

- **Measured first** (`07194b55`): today the light reads the DRAWN 2D board, not the
  voxels, and they differ in three ways:
  - the map buffer's L72–77 tile strata (no voxels);
  - the deep floor, drawn only where a crater reveals it;
  - a corner cell erased while its other claim stands.
- **On screen:** max 6/255.
- **The Director ratified option A:** the voxels are the truth.
- **Flipped** (`c511af14`): `VOXEL_STORE` and `STORE_OCCUPANCY` default ON, `=0` for
  comparison.
  - Voxels are identical, and light changes only in the three classes.
  - The gate, shadow and selftests are all green.
- **Two regressions caught and fixed before closing:**
  - the cook's LIGHT step, 45 → 82 ms, fixed to 38–40 ms (below the old 44–46);
  - the store build at load, 3.26 s on the Moto, fixed to 1.25 s (`3b7a5655`).
- **Moto:**
  - idle frame, grenades and LIGHT step: the same or slightly better;
  - boot to map: **+0.9–1.0 s**;
  - native heap: **+15–18 MB**.
  Both last until R3D-1d removes the objects.

## 8. R3D-1c step 2 — the prediction WALK onto the store (`3b298025`)

- **What changed:**
  - state, visible, blast and the cell now come from the store, with the Delta's
    projection re-keyed by claim;
  - the WALK's dead `occupancy` is no longer built;
  - `STORE_WALK` defaults on, `=0` for comparison.
- **Identity:** IDENTICAL on/off on both maps (voxels and planes), including corner
  grenades plus a shot; the cook's counts match.
- **On the Moto:**
  - the WALK drops from 1 651–1 662 to 941–956 ms (−43 %);
  - grenades take 18.2 · 15.0 s instead of 19.7 · 16.3 s;
  - the commit frame drops from ~250 to ~190 ms;
  - the idle frame is the same.
- **Found for R3D-2:** the cook's PACKAGE phase costs ~7.9 s per grenade on the Moto,
  resolving 2D atlas tiles even on the 3D board. It is the cook's largest cost on the
  device.

## 9. R3D-1c step 3 — glass onto the store (`386d122b`)

- **What changed:**
  - `VoxelStore.cells_of()`, `damage_of()` and `visible_of()` were added behind
    `STORE_GLASS` (default on).
  - Every glass state read moved: shatter, crack, fall, the room's glass bookkeeping, the
    shot controller, the plan builder and the renderer's seam index.
  - The `shoot` step takes `SHOT_AGENT_CELL` / `SHOT_GUARD_CELL`.
- **Identity:** on/off IDENTICAL on PLAYGROUND (corner grenades, 2 shots through a pane,
  rotation) and GLASS (grenades, rotation), with identical `[GLASS-*]` log lines.
- **Live-path proof:** a sabotaged store read changed the glass log (no shatter; 19 → 52
  crossings) but NOT the probe, because the final voxel set was the same. The log digest
  is part of this step's gate.

## 10. R3D-1c step 4 — passage and point impact onto the store (`c4c6c6e2`)

- **What moved:** `PassageQuery` and `plan_point_impact`'s check (`STORE_BLAST`, default
  on). `OcclusionSet` reads no voxel state.
- **What went back:** the soot BFS moved, then returned to the objects. Through the store
  it cost SOOT +11–16 %, and it removed no dependency, because its input map is objects.
- **New instrument:** the scenario step `passages`, which digests every edge's passage
  class.
- **Identity:** on/off identical on both maps (probes, logs, passages). A sabotage turns
  every passage to NONE, which proves the path is live.

## 11. R3D-1c step 5 — `Board3DLive` from the store (`8f47fc6a`), and R3D-1c CLOSED

- **What changed:** claims are indexed by world chunk with a counting sort, faces come
  from the owner claim and the `occ` grid, and a blast commit only marks chunks.
  `STORE_BOARD3D` defaults on.
- **Identity:** faces, quads and chunks identical, and 0 px on PLAYGROUND and GLASS. The
  only difference is the ratified corner cell (option A), which is no longer erased
  while its other claim stands.
- **On the Moto:**
  - 3D collect: 2.3–2.4 s → 0.95 s;
  - boot to map: 24.4 → 22.8 s;
  - commit remesh: 124 → 100 ms.
- **R3D-1c is closed.** Light, WALK, glass, passage and the 3D board all read the store.
- **Still on objects:** writes, the plan/Delta keys, and the soot BFS input.

## 12. Next session

1. **R3D-1d** — the objects go: writes through the store, the plan/Delta keyed by claim,
   and the soot BFS on claims, then the `Voxel` objects deleted and memory re-measured on
   the Moto (~191 MB to recover).
2. **The rotation / SaveState damage-loss task** (R3D-1b finding), if started.
2. **The rotation / SaveState damage-loss task**, if the Director starts it.
3. **The junction column id task** (from R3D-0), if the Director starts it.
