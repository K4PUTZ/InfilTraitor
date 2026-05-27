# INFILTRAITOR

Mobile turn-based stealth tactics game — Godot 4, isometric 2.5D, portrait orientation, grid-based.

## Engine & Visual Direction

- **Engine:** Godot 4 (GDScript) ✅ DECIDED
- **Rendering:** Isometric 2.5D — dimetric projection (45° horizontal, 26.57° elevation), square tile grid
- **Orientation:** Portrait; camera scrolls to follow the agent
- **Tileset source:** Kenney isometric packs (see `ASSETS/ISOMETRIC/`)

## Visual References

| Reference | Style lesson |
|---|---|
| *Emperor: Rise of the Middle Kingdom* | Isometric pre-rendered 3D sprites; rich, readable silhouettes on a clear tile grid |
| *StarCraft / SC: Remastered* | Dimetric 2:1 grid; high-contrast units on dark terrain; strong unit readability |
| *XCOM 2* | Tactical turn-based UI overlay clarity; 1-AP / 2-AP movement zone legibility |

See `REFERENCES/` for screenshots.

## Source of truth

- Game plan: [GAME_PLAN.md](GAME_PLAN.md)
- Repo: https://github.com/K4PUTZ/InfilTraitor.git

## Current implementation snapshot (2026-05-26)

- **M1.5 is in progress** — the active runtime is now a tactical movement prototype, not just a static debug board
- **17×17 debug room split into layers** — floor tiles on `FloorLayer`; slabs, walls and crates on `StructureLayer` above the path overlays
- **Agent + AP slice implemented** — in-engine debug agent, AP label, end-turn button, and auto-end checkbox embedded inside `END`
- **Movement UX implemented** — 1 AP / 2 AP movement overlay, path preview, blocked border cells, blocked crate cells, and two-tap confirmation on the same tile before movement triggers
- **Coordinate overlay starts OFF by default** — still available from the `#` HUD button when needed for debugging
- **Camera controls** — pan, wheel zoom, pinch zoom, fullscreen toggle, mobile/desktop viewport toggle
- **Tile picking stabilized** — 3×3 nearest-neighbour search around `local_to_map`, followed by a strict diamond hit-test so empty space above the board no longer selects cells
- **Visual/logical alignment compensation** — `VISUAL_GRID_OFFSET` is shared by camera centering, coordinate labels, selection overlay and picking so the rendered board and the logical numbered grid occupy the same place on screen
- **Current limitations** — movement currently uses a single tween to the destination instead of stepping cell-by-cell along the previewed path; the alignment correction is still runtime-side rather than TileSet-owned

## Prototype direction

- Zelda-like top-down room-to-room dungeon flow on a square isometric grid
- Turn-based tile interaction with 2 AP per turn
- Tap-to-select pathfinding and contextual action menu
- Distinct 1 AP and 2 AP movement overlays (XCOM-inspired readability)
- Procedural floor generation from handcrafted room templates
- Isometric 2.5D rendering via Godot `TileMap` in isometric mode

## Project layout (current)

```
INFILTRAITOR/
  DEVELOPMENT/         ← design docs (GAME_PLAN.md, README.md, ASSET_MAP.md)
  REFERENCES/          ← visual reference screenshots (Emperor, StarCraft, XCOM)
  ASSETS/              ← game-ready assets (correct isometric angle)
    ISOMETRIC/         ← 8 Kenney isometric tile packs
    CHARACTERS/        ← animated character sprites (Human_0–7)
    UI/                ← HUD, panels, medals, icons
    FX/                ← particle effects (smoke)
    REFERENCE/         ← orthographic renders + alt tilesets (not for gameplay)
  ARCHIVE/             ← flat textures, fonts, FX sprites (reference / future use)
  TEST/                ← scratch space
  godot/               ← active Godot project (scene, scripts, TileSet resource)
  export/              ← web export output
```

See [ASSET_MAP.md](ASSET_MAP.md) for the full tile catalogue and procedural generation guide.

## Current Godot project structure (Alpha 2.2)

```
godot/
  project.godot
  scenes/
    game/
      room.tscn        ← current interactive debug room
  scripts/
    game/
      room.gd                ← room setup, layers, input, selection, movement flow
      agent.gd               ← debug agent node + movement tween
      turn_manager.gd        ← minimal AP / end-turn controller
      movement_overlay.gd    ← reachable tiles with blocked-cell support
      path_preview.gd        ← selected-destination path preview
      selection_overlay.gd   ← pink selection diamond
      tile_labels_overlay.gd ← numbered grid overlay
    tools/
      build_tileset.gd       ← headless TileSet builder
  resources/
    tilesets/
      tileset_blocks.tres    ← generated TileSet resource
  shaders/
```

Likely next structural additions during M1.5: contextual action UI, stepwise movement execution along the previewed path, and first enemy placeholder systems.

## Milestones

See [GAME_PLAN.md §11](GAME_PLAN.md) for the full roadmap.

**Next: M1.5** — keep the current tactical slice and add contextual interaction plus stepwise movement execution on top of the stabilized interactive map foundation.

## Contributing

Suggested workflow:

- `git checkout -b feature/<short-name>`
- commit changes
- push branch and open a PR
