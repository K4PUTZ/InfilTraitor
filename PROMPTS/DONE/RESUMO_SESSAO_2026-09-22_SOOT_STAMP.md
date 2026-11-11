# Session summary — 2026-09-22 — SOOT-STAMP: soot stamped once per event, measured on the Moto

**Resume point:** the soot rework is DONE, tuned by the Director on captures and measured on the Moto g04s. Every
commit is pushed (`fa2b168e` … `20d110f8` plus this summary). No `verified/` tag was asked for. **Next session opens
with the Director's lighting question (last section) — a discussion, nothing is decided or built.**

## What happened, in order
1. **Analysis** (the shotgun's "travada monstra"). Instrumented and measured, not reasoned: the aim's shot pre-cook
   (a PREDICTION pass) wiped the soot index cache, so every shot walked all 173 128 voxels twice (~375 ms each on
   desktop); and every event re-derived the scorch of EVERY hole on the level (a shot after 5 grenades: 887 ms; a
   blast's SOOT phase grew 45 -> 206 ms over 5 grenades, one un-budgeted call). Side defect: the impact frame's
   soot-free repaint wrote CLEAN over 4 199 older sooted cells and uploaded them to the 3D board for two frames.
   Record: `PROMPTS/AUDITS/SHOT_SOOT_PERF_2026-09-22.md`.
2. **SOOT-STAMP** (`0d0a5069`, Director: *"Faz todas as correções, não importa o visual. Queremos máxima
   performance e eficiência do código"*). `Room._soot_map` = `level -> {base_cell: tone 0..3}`, written once by the
   event: shot = L1 ball around the voxels it touched; blast = every surviving flood voxel by 3D distance to the
   epicentre (per VOXEL, never per GU); fire = burnt cells' neighbours. No light apply writes the soot plane; the
   map-wide repaint resets the planes and re-projects; `SaveState` v2 saves it. ~1 900 net lines removed
   (derivation, per-face soot, six-direction store, self-soot, the map index, `Voxel.soot_dirty`,
   `_crater_floor_soot`, the shot soot fade). The shot's impact repaint now uses the stale set.
3. **SOOT-VARY** (`e1f50251`, done by another model from the plan left here): ragged edge offset, more tone
   outcomes (lighten 1–2, darken 1, edge drop), soot radius per weapon (`WeaponDef.soot_radius`, weapons JSON).
4. **Per-GU cut fixed** (`7b52f0b3`): the blast's bands ran out to the flood's edge, so the last flooded GU's
   slices/slabs were sooted and the next GU clean. The bands now end at the circle inscribed in the flood's GU
   diamond (x `SOOT_REACH_SCALE` = 1.25 after `4e40032b`). Tones lightened.
5. **SOOT-EDGE** (`622b9cae`, Director: *"escurece só os voxels imediatamente vizinhos aos destruídos"*): tone 0
   (0.38) is reserved for a voxel touching a destroyed one; the gradient uses 0.60 / 0.76 / 0.90
   (`soot_face_mult` in `voxel_face_shading.gdshader`, `Board3DLive` fallback + inline default).
6. **Moto g04s, release APKs before/after** (`20d110f8`, table in the audit): shot soot 5.2 s / 4.8 s -> 19 / 15 ms;
   blast SOOT phase 257 -> 1 142 ms growing -> 225–282 ms flat; cook worst step up to 1 142 -> ~190 ms; detonation
   MEAN frame 32.5–36.8 -> 31.2–32.9 ms (all five grenades under the 33.3 ms budget; 3 of 5 were over).

## Verified
- `run_selftests.py` 63 clean / 0 failed (new `soot_stamp_selftest`, incl. "tone 0 only beside a hole"; 17 tests of
  the derivation deleted with it). `project_lint`, `check_invariants`, `gen_codemap --check` clean.
- `shot_3d_gate.py` PASSED (brick, concrete). Blast + shot run clean on the 2D board (`RENDER3D=0`).
- Captures judged by the Director: 3D vs 2D per weapon identical; the per-GU cut gone; final look accepted.

## Still over budget on the Moto (none of it soot)
- The detonation's COMMIT frame, ~190 ms every grenade.
- The cook's atomic LIGHT phase, 188–190 ms per grenade; the SOOT phase's one-shot todo build ~70 ms (could be
  chunked); the WALK totals 0.8–1.3 s but is budgeted.
- The first shot after blasts: 719 ms tail (its stale set carries every earlier crater's neighbourhood; plus
  `build_occupancy()`, ~30 ms desktop, map-wide on every scoped repaint, three per shot).
- Grenade 5 (the glass wall): a 919 ms CONSEQUENCE frame, identical before and after.
- Candidate, unmeasured: the shot's W-PRECOOK mints 0 TileSet alternatives on the 3D board and may be dead weight.

## For the next session — the Director's lighting question (NOT decided)
Director, 2026-09-22: *"estou inclinado a adotar esse mecanismo de estados limitados de voxels para a iluminação
também (...) uma quantidade X de níveis de iluminação, digamos 1024, e com isso o renderer vai aplicar a iluminação
adequada no nivel do voxel, e não calcular cada pixel. Ou então, fazendo um giro totalmente inverso a gente poderia
universalizar luzes 3D no cenário, aposentando a metodologia 2D, porém forçando as áreas determinísticas de gameplay
stealth a seguir um shade específico. Precisamos refletir sobre isso."*

Facts to bring into that discussion (checked this session, not opinions):
- **Light is ALREADY a limited per-voxel state.** `VoxelRenderer.LIGHT_BUCKET_COUNT = 12`; each cell's bucket lives
  in the cell plane's G channel (PERF-P3) and the shader applies it per voxel face; no light is evaluated per pixel.
  More levels (1024) would change the look's smoothness, not the cost: the cost is the CPU DECIDING each voxel's
  bucket after a change (lamp term x surface/AO x shadow), and whatever still walks the map to do it.
- **Where the light's CPU cost is, measured on the Moto today:** the cook's LIGHT phase 188–190 ms (one atomic
  `VoxelLightField.build()`), the commit frame ~190 ms, `build_occupancy()` on every scoped repaint. The lesson the
  soot taught that transfers directly: an event should recompute only its own neighbourhood and never re-read the
  map; the light already has half of that (the stale set, the lamp cache), so the question is what in it still walks
  or rebuilds map-wide.
- **Option B (real 3D lights) is compatible with the existing canon**: `LIGHT_MASTER_PLAN` already separates visual
  brightness from tactical visibility, so a GPU-lit look with the stealth grid kept deterministic is not a new
  principle. The unknown is the Moto's GPU (Mali) cost of dynamic lights and shadows under the renderer in use, and
  whether the D26 look survives. It would retire the CPU light field (a large CPU win) by moving cost to the GPU.
- Suggested first step (to confirm with the Director): a measured spike of each option on the Moto before choosing.
