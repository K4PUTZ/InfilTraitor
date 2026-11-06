# Session summary — 2026-11-05 (later): MV-4's first slice, a Tripo Agent on the board and on the Moto

## Done

- **On the board** (Director's order: board + Moto before transitions and texturing). `godot/scripts/geometry/tripo_figure.gd` is the one
  authority for wearing a Tripo Agent (dressed set, coat two-sided + emblem + push) and for decoding the bank (Hips in the figure's metres, in place,
  sway and bob kept, `travel_m`). `godot/scripts/tools/tripo_game_clips.gd` writes `ASSETS/ANIMATIONS/game/agent_<fig>.res` (idle, walk, run), now
  versioned and carried by the APK (the exclusion is `ASSETS/ANIMATIONS/bank/*`; `export_android.py` requires the set). `ActorMesh3D` wears the
  LIGHT Agent under `TRIPO_FIGURE=<female|male>`, idle on its clock, the move clip (`TRIPO_MOVE`, walk) phased by the ground covered.
  The old rig is still the default. `tripo_figure_selftest` (game set = bank decoded now, in place, bones, pieces).
- **Scenario `walk <x,y>`** (the tap path, AP spent) and PLAYGROUND take `agent_walk` (POIs `agent_walk_area`, `agent_walk_south`, `agent_walk_east`).
- **Base FULL for measurement**: `tools/asset_generation/tripo/tripo_export_base.py` → `AGENT_<FIG>_BASE_A[_NOKEYS].glb` (the .blend never saved);
  bench `agent_base_<fig>[_nokeys]_clip_<id>` holds the clip's corrective key at 1.
- **Moto** (`ACTOR` D105): 9 LIGHT on a real walk +5.0 ms (shipped agent +6.2); room's 10 actors as Tripo +0.2-0.3; keys ~+0.5 for 9 (FULL, one run each).

## Commits

`3b1fe6f6` (code), and this documentation close.

## Open (for the Director)

1. ~~Tempo~~ **RATIFIED** (Director: "O video está perfeito, vamos manter assim"): `walk` phased by the ground at D61's step (~2.1x its own pace).
2. The Tripo figure lacks weapons in hand, aim, crouch, prone, throw; the head is white (no painted map in the LIGHT GLB).
3. A LIGHT built from the base (with D101/D104 skins and the corrective keys) — the keys are cheap, so worth it.
4. Next by the earlier order: transitions, texturing.
