# Session record — 2026-11-04: the cleanup, `temp/`, the animation bank saved and catalogued

Picks up `RESUMO_SESSAO_2026-11-03_TPOSE_FIT_HIDDEN_FACES.md`. The Director put a session of cleanup before the A <-> T transition. Nothing was permanently deleted by Claude: what left went to `temp/cleanup_2026-11-04/`, with a `MANIFEST.txt` of the original paths, for the Director to delete by hand.

## Directed (Director)
- The goal ahead: "Queremos refazer a transição entre os dois estados" (A and T, both figures), on the hand-finished T meshes. "Não sei se é necessário eliminar os mesmos vertices na pose A. Esses detalhes técnicos espero que você consiga trabalhar." The backpack under the coat waits for a later milestone.
- First: "uma sessão pra dar uma geral nos modelos todos; limpar arquivos soltos e coisas inuteis; limpar videos e prints mil temporários (a gente precisa formalizar uma pasta 'temp' pra eu poder deletar manualmente a qualquer momento). Mais tarde vamos dar uma conferida no código."
- Mid-way: "temos um montão de animações que precisam ser catalogadas e salvas."
- On the proposal: the Final Cut library, "Delete"; `Screenshots/history/` keeping only the `d78_*`, "Sim"; "salvas" means versioned in git, "Sim"; a female clip seemed to be missing, "só me fala qual é", then "tem o dive em algum dos outros modelos femininos" (right: it is `dive`, in two of her files).

## Built
- **`temp/`:** `tools/persistent/temp_dir.py` (`temp_path()`), `Room._temp_dir()` for the dev captures. git-ignored and `.gdignore`d; nothing reads it between runs; both sides make it again with its `.gdignore`. `capture`, `material_videos`, `actor_video`, `build_filmstrip`, `surfaces_gallery`, `build_material_matrix` and four dev captures in `room.gd` write there; `p3_step_bracket` reads the walk frames from there; `gfx_census` and `BACKUP` skip it. Rule in `CLAUDE.md`.
- **`ASSETS/MODELS/`:** a `.gdignore` in `sources/`, `history/` and `fit/` (Blender reads them, Godot has no business importing them), the README rewritten (it still said git-ignored), `tripo_female ANIMATIONS.glb` renamed `tripo_female_ANIMATIONS.glb`.
- **The bank (`MOVEMENT` §3.2):** the male's `ANIMATIONS` file registered and extracted; `tripo_anim_bank.py` fixed (a third generation overwrote `<id>_b`); `tripo_bank_catalog.py` + `bank_tags.json` (category, priority, use per clip; `CATALOG.md`; `--sheets`); `tripo_bank_sheets.py` (frames on the LIGHT Agent, no coat or hat); the whole of `ASSETS/ANIMATIONS/bank/` versioned, sidecars out.

## Moved to `temp/cleanup_2026-11-04/`
| What | Size | Why it could go |
|---|---|---|
| `ASSETS/ANIMATIONS/_TESTES` (the Final Cut library: Avengers, LULA, TESTES) | 24.1 GB | the Director's "Delete"; not game material; 22 GB were render files |
| 49 test APKs + `.idsig` in `export/` | 6.5 GB | only `Infiltraitor.apk` stays |
| `.claude/worktrees/unruffled-austin-9e2806` (`git worktree move`) | 738 MB | its one commit's fix is in main (`cd5a0f58`, same line of `prediction_reaper.gd`); its uncommitted edit was the `Branch:` line |
| `.godot/imported` orphans: 20 270 files no `.import` names | 874 MB | stale cache |
| `.venv-1` | 364 MB | nothing names it (`.venv` is the one the music tools use) |
| Loose captures, `Screenshots/takes`, `video_sets`, `godot472`, `look_baseline` | 200 MB | receipts; nothing reads them |
| `export/web` | 146 MB | the web export was retired on 2026-09-23 |
| `agent_posed_*`, `agent/walk/*`, `agent_live_walk`, `agent_base_nocrease`, `agent_base_test_white` | 109 MB | the retired frame bake's output; nothing live reads them |
| `Screenshots/history/` but the four `d78_*` | 100 MB | the Director's ruling; still in git history |
| `videos/` | 62 MB | review recordings |
| `hero_*` iterations no code names | 60 MB | D85 retired them; scripts made them |
| Godot's extracted textures and sidecars in `sources/`, `history/`; a stale `coat_light_ref` | 27 MB | regenerated if ever imported |
| `.blend1` | 14 MB | Blender's backups; the files are versioned |
| `.aider*`, `tripo_shirt_simplify.py` | 2 MB | an old tool's leftovers; the rejected test script |

Results: `ASSETS/` 23 GB -> 0.6 GB, `export/` 6.3 GB -> 141 MB, `.godot/imported` 1.4 GB -> 0.5 GB, `Screenshots/` 364 MB -> 76 MB. After the Director deletes `temp/`, `git worktree prune` clears the old worktree's entry.

## Found / measured
- **The T_HAND weld and the GPU:** exporting A and T_HAND to GLB (nothing saved): male 36 772 -> 33 888 vertices (-8 %), 32 799 -> 31 337 triangles (-4 %); female 27 563 -> 25 948 (-6 %), 25 821 -> 25 338 (-2 %), against a Blender count that halves (34 694 -> 15 992, 25 454 -> 12 912). The exporter splits a vertex again at every UV seam and hard normal: the male's hair is 10 938 -> 4 524 in Blender, 10 938 -> 10 940 in the GLB. LIGHT does not come from these files. Recorded in `ACTOR` D97.
- **The male's T_HAND carries the hidden-face deletion** (trousers 3 296 faces exactly, shirt 3 442), contrary to yesterday's record. Recorded in `ACTOR` D98.
- **The bank:** the new male file gave exactly the 30 predicted ids, 67 repeats, 3 other generations (all of stealth clips). A re-run is byte-identical: 218 of 218. `bank.json` was not versioned, contrary to `MOVEMENT` §3.2's old text.
- **The female's missing clip:** her `ANIMATIONS` file has the male's 100 without `dive`; she has `dive` in `tripo_female_base.glb` and `tripo_female_nocoat.glb`, and the bank's female side already had it.
- **Evidence for `temp/`:** with the folder absent, a filmstrip run made `temp/.gdignore` and six frames (`Room._temp_dir`); `capture.py --still` wrote `temp/takes/PLAYGROUND_material_row.png`; no `.import` under `temp/`. `verify.py smoke`: 92 selftests clean, PLAYGROUND and GLASS ok. The smoke boot ran again after the cache orphans left: PASS. No `verify.py full`: nothing in the board, state, light or ground moved.
- **Traps (new):** (1) a `git reset` to unstage a folder also unstages a `git mv` inside it: the rename left the commit it belonged to and needed its own (`f8c93a5b`); (2) an orthographic tile has no horizon, so a floor shows no height: a disc under the hips does; (3) the tool's `loops` flag is only "first and last pose within 12 degrees", so read it on the sheet.

## Not done / open
- **The Director's look at the sheets** (`ASSETS/ANIMATIONS/bank/sheets/`) and the canonical generation of the three stealth clips (`MOVEMENT` §3.2 says which file each comes from).
- **The A from the T_HAND topology, then the transition** (`ACTOR` D97): next, by script, with the check on welded vertices that were apart in the A.
- The APK after the cleanup is not measured (it carried `hero_*`: `apk_audit.py` after the next export).
- `official/*.blend` are still imported by Godot (3 files): they cost editor time and may be in the APK.

## For the code review (later, the Director's call)
- Bench modes that name `hero_split`, `hero_joined`, `hero_naked`, `superhero_male_lean` (`actor_viability_bench.gd`), and the `hero_*` scripts (`tools/asset_generation/hero/`): their files stayed for now; D85 retired the line.
- The retired `p1_` / `p2_` / `p3_` scripts: they read `agent_base*` and still write to `Screenshots/`; `agent_posed_*` and `walk_*` are theirs (`p3_step_bracket.py` was repointed because it reads `room.gd`'s frames).
- `export_presets.cfg`'s exclude list names files that no longer exist (`agent_posed*`, `agent/walk/*`, `videos/*`): harmless; `export_android.py`'s retired-model check too.
