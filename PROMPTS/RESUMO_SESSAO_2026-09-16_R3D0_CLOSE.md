# SESSION SUMMARY — 2026-09-16
## RENDER3D R3D-0 closed: the embers and roof-top pairs, and what the "dark roofs" really are

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
- **Proposed:** move R3D-6 item 1 to R3D-5 (overlays). ⏳ Director's call.

## 4. Found, not fixed

- ⚠️ **`RNG_SEED` has never reached an APK.**
  - `Room._ready()` reads it with `OS.get_environment()`, not `DevFlags`, and none of the
    20 Moto logs prints `[RNG] seeded`.
  - Every device table that lists `RNG_SEED` ran with its particle rolls unseeded.
  - The fix is one read through `DevFlags`. ⏳ Awaiting the Director.
  - Seeding still would not make in-blast frames identical, because the cook's ms budget
    varies how many draws come before the blast.

## 5. Next session

1. **R3D-1a** — the store layout spike (dense per-level grid vs per-container arrays).
2. **The Director's calls:**
   - item 1 → R3D-5;
   - the `RNG_SEED` fix.
3. **The junction column id task** (from R3D-0), if the Director starts it.
