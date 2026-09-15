# SESSION SUMMARY — 2026-09-14
## Device performance: telemetry, a 3D board inside Godot, and the grenade's cook stall

**Director's request:** *"Precisamos determinar quem é o(s) vilão(ões), pra poder fazer
escolhas educadas e conscientes."* — first with a realistic benchmark and telemetry,
then, after the ablation, with a 3D prototype. Every step after that was approved with
*"Vamos seguir"*.

**Full record:**
[`DEVICE_DIAGNOSTICS_MASTER_PLAN`](PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md) v1.5 —
§10.16–§10.18 (framing, zoom, render scale), §14 (TEL suite), §15 (the decisive
experiments, DIAG-19 to DIAG-22). Commits: `git log --since=2026-09-14`.

---

## 1. Director rulings this session

- **Framing follows the phone.** Portrait is the default and the test framing, and it
  fills the screen. The landscape canvas is 844×390, and D stays unrestricted (1280×720).
- **World render scale stays 1.0:** *"não vale a pena piorar o jogo por causa disso"*.
  0.75 was measured and not kept.
- **JAMES is suspended until the performance milestone closes.** Claude does
  everything, interface included; rule 11 / L3 still holds.
- **The 3D prototype goes inside Godot (option b)**, keeping the real voxels and
  registries and replacing only the renderer.

## 2. What was built

- **TEL suite:**
  - the `Telemetry` autoload (`[TEL]` lines plus a JSONL sink);
  - HUD, input, camera, menu and blast events;
  - `ViewContext` and `ScenarioRunner` (`SCENARIO=` steps: framing, zoom, centre, wait,
    mark, capture, detonate, quit);
  - `bench_analyze.py`, with segments, touched-segment flags and `[E-FRAME]` tables.
- **Board3DLive (`RENDER3D=1`):**
  - it reads the real slices, junction columns and slabs, greedy-merges per chunk, and
    uses an orthographic camera synced to the 2D camera;
  - it remeshes on detonation;
  - light and soot come per cell from the renderer's cell planes;
  - `SKIP_2D_BOARD_WRITES=1` is an instrument that skips the hidden 2D board's writes.
- **DIAG-22:**
  - `PREDICTION_PROFILE` and `THROW_PROFILE` now go through DevFlags, so both reach the
    APK;
  - `THROW_PROFILE` also prints a `[T-COOK]` trace per slow cook frame;
  - composite tiles are created up front.

## 3. The results, in order

| step | finding (Moto g04s) |
|---|---|
| DIAG-16–18 | The view drives the 2D board's cost, and pixel fill is 36–47 ms of GPU. |
| DIAG-19 | The detonation stalls are the damage footprint written into the 2D board: `BLAST_MAX_RING=1` takes the worst frame from 1.9 s to 0.3 s. |
| DIAG-20 | The same board in 3D costs 2.2–7.5× less. |
| DIAG-21 | The live board in 3D idles at 18 ms against 60 ms in 2D. Remesh on detonation halves the event. Without the 2D writes, grenade #1 takes 11.8 s against 28.5 s. |
| **DIAG-22** | **The cook stall was ONE damage composite creating a tile on the shared TileSet mid-cook**, which rebuilt every TileMapLayer, hidden ones included. |

**DIAG-22 in numbers** — grenade #1, same APK, lazy vs up front:

| | lazy | up front |
|---|---|---|
| cook frame that stores the composite, 3D+skip | 809 ms | **97–115 ms** |
| same frame, 2D | 1 734 ms | **189 ms** |
| worst frame of the event, 3D+skip | 822 ms | **265–279 ms** |
| worst frame of the event, 2D | 1 800 ms | 1 813 ms (now the soot-fade 2D rebuild) |
| load | — | +740 ms once |

Refuted on the logs, not by argument:
- the warm-up (the scenario interrupts the pump, so it never runs);
- the `[BAKE]` disk hits (they are boot).

## 4. Gates

- Lint: 0 errors.
- Selftests: 55 clean. `damage_composite_cache_selftest` [8] is a new check, with the
  lazy path as its control: the lazy store changes the TileSet 2 times, the up-front
  store 0 times.
- `check_invariants` OK; CODEMAP regenerated.

## 5. Where it stops — next session

1. **The LIGHT step of the cook (234–408 ms, both grenades)** is now the worst frame of
   grenade #0 and the largest in the cook. It rebuilds occupancy map-wide per blast. The
   design ready to build is a cached occupancy with an overlay of predicted-destroyed
   cells (`VoxelLightField` reads occupancy only through `.has()`).
2. **The 3D commit frame (~265–280 ms):** remesh off-thread, then touched-row plane
   uploads.
3. **The decision these feed is the Director's** (§15.12 item 4): a real 3D render path
   retires the 2D board's writes, and with them canon rule 8, B1/B3/B5 and the plan's
   tile-shaped entries.
4. **3D look gaps:**
   - some roof tops render dark;
   - glass is pale;
   - there are no decals;
   - a 2D overlay line is still visible.

⚠️ The fix covers one composite page. PLAYGROUND uses 447 of 3 584 slots. A blast that
overflows into a second page would still mutate the TileSet.
