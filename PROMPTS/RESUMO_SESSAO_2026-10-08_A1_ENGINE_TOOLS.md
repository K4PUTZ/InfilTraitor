# Session record — 2026-10-07/08: roadmap step A1 (engine tools, desktop)

Started from `RESUMO_SESSAO_2026-10-07_PERF_REVIEW.md` ("resume at A1"). Every item below is committed on `main`; `verify.py smoke` PASSED at each
commit (75-79 s). Details and numbers: `docs/production/technical_debt.md` ("Stress scenario findings", "First Moto numbers", "A1 desktop round")
and `docs/production/roadmap.md` (the A1 row).

## Built
1. **Cosmetic density per device** — `CosmeticDensity` + flag `COSMETIC_DENSITY=low|mid|high|0.1-1` (default 1.0 = identity): glass rain, embers, smoke
   blobs, ground debris. Gameplay and prop fragments are never scaled. `cosmetic_density_selftest`. The per-device default is for step B.
2. **Hit-stop for the strongest grenade** — BombDef tag `hit_stop` (on `frag_grenade`); the world commit runs under the flash (stage 0 on the peak
   frame, 1 the presenter's commit + remesh, 2 the glass flush + a budgeted queue, 3 the queue again, the rest to the presenter's background).
   `HIT_STOP=0` is the single-frame control. Reworked on 2026-10-08 after the first Moto numbers (below).
3. **Combined stress scenario** — `maps/STRESS.map.json` (`gen_stress_map.py`: 3x3 rooms of 8 materials, glass hall, 24 guards, 60 props, 14
   lights) + `stress_scenario.py` (two grenades, the second thrown into the first's tail, then a shot; `--mode sequential` is the control;
   `--print` for `dev_flags.cfg`; `--device <serial>` for a handset).
4. **Map-size study tooling** — `scale_study.py` (generated `SCALE_<N>` maps, STRESS density or `--content empty`, one row per size from the
   engine's log lines, `--print`, `--parse`); first desktop series in `docs/measurements/scale_study_desktop_{dense,empty}_2026-10-07.md`.
5. **Export audit and size check** — `apk_audit.py` (weight by category and by source directory, `--max-mb`); the Android `exclude_filter` now holds out
   dev folders and the retired agent bake models: **release APK 127.7 -> 62.0 MB**; `export_android.py` forbids the bake models.
6. Fixed on the way: overlapping blasts shared one `_active_presenter` (now a list swept by `is_done`; the callback that captured the presenter was a
   reference cycle); `_take_prediction` built a ctx on every call (`PredictionCache.has_live`: 142 -> 0.05 ms).

## Decisions (Director)
- **No port of the procedural generators and no first-load generation** (supersedes roadmap decision 5's first half): the procedural art in the
  package is ~2.4 MB. The catalogue ships fixed; `user://` is an optional override; what the player sees is gated by gameplay; the ground-stamp
  groupers run only on a custom-material upload with their own load, cache and UI (the late customisation milestone). The package-size win came from
  the export filter.
- Desktop first, the Moto the next day: "faz tudo o que for possível pelo desktop, tomando as decisões recomendadas".

## Findings worth keeping
- The Moto (2026-10-07, before the rework): the staged hit-stop beat the single frame (worst 907 vs 1 869 ms) but missed its 200 ms ceiling by 3-4x; the
  cause was `GlassFall.build_surface_index` (a walk over the whole map per call, once per prop material: ~850 ms on the device), not the stage split.
- A scenario that fires `shoot` while a grenade is in flight makes the throw rebuild a stale prediction (570 ms): a scenario-order artifact, written
  into `stress_scenario.py`.
- Size alone is cheap, content is not: the blast's worst frame bends with props / guards / glass, not with the floor area; the 46 GU cell plane is the
  first hard wall (`outside the 512x512 cell plane` from 64 GU).
- Candidate "unreferenced" lists from a grep are noise (89 of 99 MB): a resource loaded by a built path has no literal name.

## Resume point — TOMORROW: the Moto round (step B's first slice)
`export/Infiltraitor.apk` already holds the 2026-10-08 code (59 MB; exported, NOT installed: the Moto was offline). Order:
1. `python3 tools/persistent/export_android.py --install`  (the handset must be attached, unlocked, screen on)
2. `python3 tools/persistent/stress_scenario.py --mode sequential --device ZF524T5TG5`  then the same with `--no-hit-stop` (the control)
3. Read: the `HIT-STOP stage N` lines against the 200 ms ceiling (`past its ceiling` warnings), the `detonation —` WORST per blast, `TAKE`, any
   `ERROR`; compare with the 2026-10-07 rows (stages 475/207/740/803 ms, worst 907; control worst 1 869).
4. If a stage is still over: the stage-0 world commit (~425 ms) is the piece left, then `rim shards` (26 ms desktop) inside it.
5. Then the standard-coordinates round (`29,6;41,6`), `scale_study.py` on the Moto (maps must be in the APK: `--keep --no-run`, export, `--print N`),
   `COSMETIC_DENSITY` tiers, and PSS against the 1.2 GB ceiling on the Galaxy (`R5CY8122K7D`).
After the handset: A2 (the stealth loop) per the roadmap order.

Not done / owed: `verify.py full` was not run (nothing rewired the board/state/light/ground, and the board probe of two blasts is byte-identical to the
pre-change code); no visual capture of the crater appearing under the flash (judge on a video); the `--device` path of `stress_scenario.py` is untested
on a device.
