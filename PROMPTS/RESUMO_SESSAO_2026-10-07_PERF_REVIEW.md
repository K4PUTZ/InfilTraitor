# Session record — 2026-10-07: project review, performance review, rulings

No code changed. `verify.py smoke` PASSED at the start (76 s, 70 selftests clean) on `dbb9a38c`.

## What was done
1. **General review of the week** (2026-09-29 to 10-07, 181 commits): R3D-PROPS, ACTORS, WORLD, ROT, RETIRE-2D, R3D-FINISH (buffer ring, CLAIMS), R3D-LOOK, SURFACES.
   The engine is practically closed; gameplay (AI-02/03, M2.14, confrontation) has not moved since June.
2. **Performance review** against §0.5 (both handsets); the numbers are in `DEVICE_DIAGNOSTICS_MASTER_PLAN`'s 2026-10-07 top block.
3. **Damage-scaling measurement** (real PLAYGROUND plan via a scratch copy of `blast_purity_selftest` with a `PROBE_GU` override; the JSON and
   `CRATER_MAX_FACTOR` were edited temporarily and restored, no diff left): damaged voxels at GU 29,6 / 41,6 are 617 / 1 664; x0.8 on
   `destroy_ring_weights` -2 % / -2 %; on all three tier weights -12 % / -4 %; plus the crater radius x0.8 -27 % / -9 %.

## Finding
The 2026-10-05/06 Moto rows (R3D-LOOK, the soot bake) used `GRENADE_GUS=25,2;37,2`, the pre-ring coordinates. Idle numbers stand
(pre-blast medians: pre-LOOK 19.7, LOOK first cut 26.5, 2-fetch 20.8 / 24.2, bake 21.1 / 21.3 ms); the blast numbers are another spot.
No standard-scenario blast row exists on the current code.

## Director's rulings
- The frag grenade is deliberately oversized: it is the engine's stress case and **ships** as one of the player's last acquisitions;
  a reduced everyday bomb comes at finalisation. Budgets are judged on it (`DESTRUCTION_MASTER_PLAN`, `WEAPON_MASTER_PLAN`).
- No all-glass rooms in INFILTRAITOR 1 (parked for INFILTRAITOR 2); the glass box is beyond the shipped worst case; glass work stays in
  the materials milestone (`GLASS_MASTER_PLAN`, `MAP_MASTER_PLAN`).
- End-turn progress indicator: **concept B** (ring segmented per acting faction) chosen, planned for round 5 (`INTERFACE_MASTER_PLAN`, roadmap).

## Open at the time (the first four were RATIFIED in the consolidation below)
- Memory ceiling PSS <= 1.2 GB on the Galaxy.
- For the strongest grenade: unlimited pre-cook; one designed hit-stop under the flash with a ceiling; 100 ms elsewhere; memory a hard limit;
  cosmetic density scaled per device, gameplay identical.
- A combined stress scenario (simultaneous events, dense content, many guards).
- One handset round on both phones, standard coordinates, current code.
- Housekeeping: `export/` holds 47 throwaway APKs (6.0 GB); ~115 untracked files in `Screenshots/history/`.

## Consolidation (later the same day)
All debates closed; the decisions and the ordered activities are the 2026-10-07 top block of `docs/production/roadmap.md` (single source):
checkpoint-only lifecycle; procedural art generated at first load and cached; the four performance proposals ratified; JAMES suspended;
`PERFORMANCE`, `TOP_TEXTURE`, `OCCLUSION`, `DESTRUCTION` archived to `PROMPTS/DONE/` with reform headers (33 files relinked).

## Resume point (next session)
Step **A1** of the roadmap order: engine tools on the desktop (cosmetic density per device, the hit-stop under the flash, the combined
stress scenario, the map-size study tooling, first-load art + export audit). No handset run until step B.

## Code audit (end of session)
Findings and the follow-up list are in `docs/production/technical_debt.md`, block "Code audit (2026-10-07)". Fixed, each red-before-green
or pinned by a new selftest: a player prop in `user://props/` could run code through `PropModelFit`'s `load()` (now only shipped `res://`
glTF/GLB; `prop_model_path_selftest`, red proven: the payload ran); the save write is atomic (`SaveState.write_text_atomic`,
`save_state_file_selftest`). Open, needs the Director: `DevFlags` live in the store build, the debug-keystore signing, no checkpoint wired,
user-tier schema validation, `room.gd` size, 254 runtime `print()`. `verify.py smoke` PASSED (76 s).

## Error-prevention round (closing the session)
Fixed with `registry_load_errors_selftest` (red reproduced first: a broken `user://bombs/*.json` printed only Godot's path-less
"line 0" message, an id-less row printed nothing): the five catalogues read rows through the new `JsonFile` helper (loud, path-named,
collected in `load_errors`); `PropDef` / `SlotDef` vector fields fall back instead of aborting the row; `BombDef.MAX_RING` (16) caps a
bomb's reach. The shipped data loads with zero errors (90 materials, 12 props, 7 weapons, the grenade). Attention markers in
`DevFlags._candidate_paths()` and `SaveState.save_to_file()`. CLAUDE.md's error-handling contract gained the `JsonFile` line.
Updated: `technical_debt.md`, `milestones.md`, `PROP_PIPELINE_PLAN`, `DEVICE_DIAGNOSTICS_MASTER_PLAN`. `verify.py smoke` PASSED (77 s).

**Session closed. Resume at roadmap step A1.**
