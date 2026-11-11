# Session record 2026-11-08 (later): the agent close-up anchor and the open list, level 1

## Done (all on `main`)
- **PLAYGROUND `agent_close`**: POI on the agent's start cell (27,9), rail `agent_close_rail` (view S, the most frontal of the four), take `agent_closeup`. New capture frame mode **`close`** (the box as authored, no 3 GU floor; `capture_framer.gd`, `map_layout.gd`, `scenario_runner.gd`, `capture.py --mode close`); `ZOOM_MAX` 2.0 -> 4.0. A glass pane of the map crosses the right leg in the S view (left as is).
- **`gen_segment_map.py`** drops PLAYGROUND's `capture` section (red-before-green: it was inherited).
- **Main menu**: Load is permanent; with no save it shows `ui.main_menu.no_save`; with one it emits `load_requested`, `Room._on_menu_load_requested` calls `SaveState.load_from_file`. Not seen on screen, not tried with a real save (nothing writes one yet, roadmap A2). `ui.csv` reimports when Godot opens.
- **Assets in git**: `.gitignore` re-includes PNG / JPG / PSD under `ASSETS/` (face masters, materials facades and decals, vox props, texture sources); audio, video, `photo_src/`, `.blend1`, `.import` and the generated ISOMETRIC frames stay local. Models (glb, blend) were already tracked. `BACKUP.py` stays code-only (Director). `.git` is 3.1 GB.
- **JAMES clone** `../INFILTRAITOR_DESIGN` deleted (4.2 GB; clean, in sync; lost: 3 old WIP stashes).
- **ACTOR D88 RULED**: no spring simulator, the legs' push (D94) is the coat's only collision; measured on the stress clips (`coat_push_check.py`).

## Next (the open list, simplest first; level 1 is closed)
Level 2: grenade cancel fuse sparks to 0 in `play_throw_cancel()`; posture's AP cost never read; guard noise indicator unwired; the male's belt drape; shirt / trouser defects. Then device measurements and rounds (liquid flames, `VoxelFire`, fresh holes, A1 stress, Galaxy, PB Q5, the GLASS smoke boot), the remaining texturing and the MV-4 transitions, then the opaque-wall passage, the roofs (C4, cardboard, metal, the roof shot), the dress switch + turning tie, and last T4 (`ActorMesh3D` adapter for the 65-joint rig).
