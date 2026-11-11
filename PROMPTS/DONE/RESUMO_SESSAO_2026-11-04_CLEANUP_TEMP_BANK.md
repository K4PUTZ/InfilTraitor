# Session record — 2026-11-04: the cleanup, `temp/`, the animation bank, the code review and the sweep

Picks up `RESUMO_SESSAO_2026-11-03_TPOSE_FIT_HIDDEN_FACES.md`. The Director put a session of cleanup before the A <-> T transition. Nothing was permanently deleted by Claude: what left went to `temp/cleanup_2026-11-04/`, with a `MANIFEST.txt` of the original paths, for the Director to delete by hand. Code removed from `HEAD` stays in git history.

## Resume here
- **Next: the A from the T_HAND topology, then the transition** (`ACTOR` D97; Director: "deixa pra amanhã"). By script, never by hand, checking welded vertices that were apart in the A.
- **Waiting on the Director:** whether another backup of the art exists (audit finding 1; a clean clone runs with no figures or facades); a look at the bank's sheets (`ASSETS/ANIMATIONS/bank/sheets/`) and the canonical generation of the three stealth clips (`MOVEMENT` §3.2); the audit's dead-code list; the audit's other proposals.
- **Housekeeping:** `temp/` (33 GB) is his to delete; after that, `git worktree prune` clears the old worktree's entry.
- **Not verified:** the 90.2 MB APK (`temp/apk/after_review.apk`) has not been on a handset, and `export/Infiltraitor.apk` is still the build from before the cleanup.

## Directed (Director), in order
- The goal ahead: "Queremos refazer a transição entre os dois estados" (A and T, both figures), on the hand-finished T meshes. "Não sei se é necessário eliminar os mesmos vertices na pose A. Esses detalhes técnicos espero que você consiga trabalhar." The backpack under the coat waits for a later milestone.
- First: "uma sessão pra dar uma geral nos modelos todos; limpar arquivos soltos e coisas inuteis; limpar videos e prints mil temporários (a gente precisa formalizar uma pasta 'temp' pra eu poder deletar manualmente a qualquer momento). Mais tarde vamos dar uma conferida no código."
- Mid-way: "temos um montão de animações que precisam ser catalogadas e salvas."
- On the proposal: the Final Cut library, "Delete"; `Screenshots/history/` keeping only the `d78_*`, "Sim"; "salvas" means versioned in git, "Sim"; a female clip seemed to be missing, "só me fala qual é", then "tem o dive em algum dos outros modelos femininos" (right: it is `dive`, in two of her files).
- The code review of what the cleanup retired: taken in this session; on its list, "Pode aplicar".
- "Deixa pra amanhã. Vamos dar mais uma geral no código todo, e ver se não tem nenhuma ponta solta ou fio desencapado." On the audit: "Pode corrigir".
- "Quando terminar vamos documentar tudo e encerrar a sessão."

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

Results: `ASSETS/` 23 GB -> 0.6 GB, `export/` 6.3 GB -> 141 MB, `.godot/imported` 1.4 GB -> 0.5 GB, `Screenshots/` 364 MB -> 76 MB.

## The code review of what the cleanup left retired ("Pode aplicar")
Reported first with nothing changed, then applied as listed.
- **Removed:** the bench's `quat` and `hero_*` modes with their costume suffixes (424 -> 301 lines; `agent` and `agent_<light|full>` stay; `scenario_runner.gd` now refuses the old names); `tools/asset_generation/hero/` but `faction_palette.json` and `faction_dress_art.py` (the D78 recipe in `COSMETICS` §9.9 says so); eight `p*` scripts nothing imported: `p1_agent_preview`, `p1_agent_sheet`, `p1_procedural_sculpt_spike`, `p2_grip_sheet`, `p3_head_sweep_sheet`, `p3_head_turn_spike`, `p3_posture_sheet`, `p8_sculpt_start_scene`. 4 434 lines in all, plus the bench's; last at `9316d8c4`.
- **Moved:** `quaternius_universal_base/` to `ARCHIVE/hero_sources/` (no copy in git, CC0 originals + `ATTRIBUTION.txt`); `agent_hifi.*`, `agent_sculpt_start.blend`, `agent_base_enemy.*`, `s2_mockup/` and the `.blend` sidecars to `temp/cleanup_2026-11-04/`, with 55 MB more of orphan cache.
- **Changed:** `filesystem/import/blender/enabled=false` (no `.gd` names a `.blend`); the Android filter gains `official/*_AGENT_BASE*` and `official/COAT_BASE*`, loses `videos/*`, `agent_hifi*`, `agent_sculpt*` (nothing can recreate those two now; `agent_posed*` and `agent/walk/*` stay, because the `p3` exports can); `export_android.py` forbids the source models in an APK; the Web preset left (Android is `preset.0`) and `MobileTesting.md` lost the web + ngrok flow.
- **Kept on purpose:** `r3d_live_rig_export.py`, `p1_agent_model`, `p2_grip_spike`, `p3_posture_export`, `p3_walk_export`, `p3_throw_export` (the only recipe of `agent_base*.blend` and `agent_live*.glb`, which are not in git) until `MOVEMENT` MV-4; `p3_step_bracket.py` and `Room._capture_walk_filmstrip()` until MV-3, which will want the blind step test; the D70-D72 prototype shaders, unwired.
- **Measured:** the APK went from 147.1 MB to **90.2 MB** on disk (hero 45.8 MB -> 0, superhero 5.9 -> 0, source models 4.3 -> 0), `export_android.py`'s checks all ok. `.godot/imported` is 458 MB, no `.blend` in it. Both game rigs, rebuilt into `temp/` before and after: byte-identical to the current files. `actor_bench hero_split 1` is rejected loudly.

## The sweep of the whole code (`PROMPTS/AUDITS/LOOSE_ENDS_2026-11-04.md`)
Read-only at first. The game is sound: 27 of 27 maps boot with no error, `map_lint` 27 of 27, `verify.py full` passed 19 of 19 on a baseline taken today (it replaced the one from 2026-10-19, and it proves the gates, not "no change since an older commit"). The real exposure: git alone cannot run the game, because the art exists only on this disk.

**Fixed at his word ("Pode corrigir"):** `tripo_coat_decal.py`'s `NameError` (exit 1 before, exit 0 and its renders after); the bench's suffixes combine in any order; a rejected scenario ends with code 1 (4 s, was a 120 s timeout); `actor_video.py`'s default crop shows the whole figure (`--crop`, `--crop-y`); the menu's Load button hidden until roadmap A2. `verify.py smoke` passed after them.

**My error, corrected in the audit:** I reported that a player could press that button; it was already disabled.

**Left as they are:** dead-code lists and the other proposals, in the audit. `room.gd`, touched today, keeps its 41 older compiler warnings: the zero-warnings rule was not applied to it, because cleaning them was not on an approved list. The sweep's scripts were scratch and were not kept; its method is in the audit.

## Found / measured
- **The T_HAND weld and the GPU:** exporting A and T_HAND to GLB (nothing saved): male 36 772 -> 33 888 vertices (-8 %), 32 799 -> 31 337 triangles (-4 %); female 27 563 -> 25 948 (-6 %), 25 821 -> 25 338 (-2 %), against a Blender count that halves (34 694 -> 15 992, 25 454 -> 12 912). The exporter splits a vertex again at every UV seam and hard normal: the male's hair is 10 938 -> 4 524 in Blender, 10 938 -> 10 940 in the GLB. LIGHT does not come from these files. Recorded in `ACTOR` D97.
- **The male's T_HAND carries the hidden-face deletion** (trousers 3 296 faces exactly, shirt 3 442), contrary to yesterday's record. Recorded in `ACTOR` D98.
- **The bank:** the new male file gave exactly the 30 predicted ids, 67 repeats, 3 other generations (all of stealth clips). A re-run is byte-identical: 218 of 218. `bank.json` was not versioned, contrary to `MOVEMENT` §3.2's old text.
- **The female's missing clip:** her `ANIMATIONS` file has the male's 100 without `dive`; she has `dive` in `tripo_female_base.glb` and `tripo_female_nocoat.glb`, and the bank's female side already had it.
- **Evidence for `temp/`:** with the folder absent, a filmstrip run made `temp/.gdignore` and six frames (`Room._temp_dir`); `capture.py --still` wrote `temp/takes/PLAYGROUND_material_row.png`; no `.import` under `temp/`.
- **Traps (new):** (1) a `git reset` to unstage a folder also unstages a `git mv` inside it: the rename left the commit it belonged to and needed its own (`f8c93a5b`); (2) an orthographic tile has no horizon, so a floor shows no height: a disc under the hips does; (3) the tool's `loops` flag is only "first and last pose within 12 degrees", so read it on the sheet.
