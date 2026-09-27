# Session 2026-09-26 (night) / 2026-09-27 — R3D-LIGHT closed by the Director ("Pode fechar o R3D-LIGHT")

Full record: `RENDER3D_MASTER_PLAN` v1.31-v1.33 blocks. Logs local `docs/measurements/device_2026-09-2[67]_{moto,galaxy}_*` (git-ignored).

## Result
- **Time from throw to boom:** the cook went 103 -> 28-29 frames on the Moto (20 / 19 on the Galaxy A16), ~3.1 s -> ~0.7-0.9 s.
- **Criterion "no blast or shot frame over 100 ms":** Galaxy <= 93.5 ms; Moto worst = the COMMIT at 98.8 / 100.8 ms (at the line, boot spread ~8 ms). Shot tail 67-69 ms Moto, 38 ms Galaxy.
- `verify.py full` PASSED (435 s) against the baseline taken at the start of the night.

## What was built (commits `ca4c7078` .. `2f333838`)
1. `VoxelStore.walk_cache` + `WalkWarmer`: the WALK's geometry indexes kept per store and built in idle frames (~21 MB on the Galaxy, `NO_WALK_CACHE=1` is the control).
2. `_select_ranked_once`: blast selection ranks each voxel once (SLICES 352 -> 112 ms Moto).
3. `_hole_cells`: the soot stamp asks a set (SOOT 225 -> ~90 ms).
4. `VoxelStore.gone_claims` index replaces the state-byte scan (WALK 91 -> 26 ms); selftest TEST 9.
5. `_claim_tag` cached per container and perspective (persist 46 -> 38 ms).
6. Instruments: `WALK_EQUIV`, `HOLE_EQUIV`, `SELECT_EQUIV` (env), `SCALE_3D`, `NO_WALK_CACHE`.

## GPU floor (Moto idle 17.5 ms; Galaxy 24-31 ms)
Measured by ablation: board shader ~4.2, 2D ~3.1, pixel baseline ~9.9, glass +4.2. The lever is the 3D render scale (0.75 -> 12.2 ms) — **Director ruled: stays 1.0**. The sRGB approximation and glass-without-screen-read were not chosen.

## Lessons (each cost a step)
- Measure the split first: three of four "obvious" causes were wrong or small (the hash per comparison was 85% of SLICES; the GDScript persist loop was mostly plain per-voxel work).
- A cache shared with a drainer needs the drainer told (`walk_shared`), or it empties the cache.
- The first boot after an install is noisy (112 ms WALK that never repeated).
- `PackedArray` in a Dictionary is copy-on-write: write it back.

## Open / not done
- Moto COMMIT frame has no margin (persistence ~37 ms; slicing needs a flush before every rotation, save and `_base_damage` read).
- PACKAGE / FLOORS not profiled inside; LIGHT's occupancy copy left (snapshot guarantee).
- Pre-existing: 26 `'has' ... TypedArray of String` errors in a scenario with `shoot 0` (task spawned separately).
