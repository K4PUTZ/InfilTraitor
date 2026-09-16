# SESSION SUMMARY — 2026-09-16
## RENDER3D R3D-0 closed (embers, roof tops, the "dark roofs"), the `RNG_SEED` fix, and R3D-1a measured

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

## 6. Next session

1. **The Director's confirmation of B**, then **R3D-1b** — the store in shadow, with
   `BoardProbe` gates.
2. **The junction column id task** (from R3D-0), if the Director starts it.
