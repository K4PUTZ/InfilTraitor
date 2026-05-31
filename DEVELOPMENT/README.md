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

## Current implementation snapshot (2026-05-30 — M1.5 in progress)

- **M1.5 in progress** — segment layout, movement, tile-wall autotile system, and three-layer fog-of-war live; core movement feel locked as Alpha Gameplay
- **Segment prototype locked** — `room_layout_builder.gd` generates an **18 × 36** tile map; agent spawns at `Vector2i(9, 34)`; 7 authored crates; 2 access points (north + south)
- **Tile-wall autotile system locked** — `_pick_wall_tile()` selects from `wall_N/S/E/W`, `wallCorner_*`, and `block_N` per cell via three ordered rules:
  1. **Mid-border override** — non-corner border cells always get their straight face tile
  2. **Open-count autotile** — corners and L-junctions derived from open neighbour count
  3. **End-cap facing** — 3-open-side cells show the face opposite the closed side
- **Floor apron** — `_build_room()` floors `range(-1, MAP_SIZE.x+1)` × `range(-1, MAP_SIZE.y+1)` so border walls sit on ground, not dark background
- **Step-by-step movement locked** — `agent.move_along_path(path)` walks the Dijkstra path cell-by-cell at 0.13 s/tile (TRANS_SINE); `step_finished(cell)` emitted per arrival
- **Progressive FOW reveal** — `_on_agent_step_finished` calls `fog_of_war.reveal_around()` each step
- **Static camera** — player-controlled only (drag + scroll/pinch); destination must be visible before confirming
- **Vision fog shader smooth tracking** — `_update_vision_fog()` uses `agent.global_position` for mid-step smooth gradient
- **Three-layer visibility system tuned and locked:**
  - **Camera leash** (`room.gd`) — soft zone (2 tiles) + hard limit at `FOW_REVEAL_RADIUS`
  - **Distance fog gradient** (`vision_fog.gdshader`) — isometric 2:1 ellipse; `VISION_TILE_RADIUS = 5`
  - **Fog of War polygons** (`fog_of_war_overlay.gd`) — persistent reveal; 12-ring smoothstep opacity + per-vertex feathering
- **Agent + AP slice** — draw-based placeholder (diamond + head); AP label, end-turn button, auto-end checkbox
- **Movement UX** — 1 AP / 2 AP overlay, path preview, two-tap confirmation, blocked cells
- **Coordinate overlay** — starts OFF; `#` HUD button toggles
- **Camera controls** — pan, wheel zoom, pinch zoom, fullscreen toggle, mobile/desktop viewport toggle
- **Tile picking stabilized** — 3×3 nearest-neighbour search + strict diamond hit-test

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

## Current Godot project structure (Alpha 2.5)

```
godot/
  project.godot
  scenes/
    game/
      room.tscn        ← active interactive segment (18×36 tiles)
  scripts/
    game/
      room.gd                ← room setup, input, AP/turn UI, movement flow, fog control
      room_layout_builder.gd ← segment builder (18×36, slabs, crates, access points)
      agent.gd               ← debug agent node + movement tween
      turn_manager.gd        ← AP / end-turn controller
      movement_overlay.gd    ← reachable tiles with blocked-cell support
      path_preview.gd        ← selected-destination path preview
      selection_overlay.gd   ← selection diamond overlay
      tile_labels_overlay.gd ← numbered grid overlay (debug)
    ui/
      fog_of_war_overlay.gd  ← segment-persistent FOW (diamonds, 10-ring geometric opacity, feathering)
    tools/
      build_tileset.gd       ← headless TileSet builder
  shaders/
    vision_fog.gdshader      ← isometric 2:1 ellipse distance-fog gradient (always on)
  resources/
    tilesets/
      tileset_blocks.tres    ← generated TileSet resource
```
      movement_overlay.gd    ← reachable tiles with blocked-cell support
      path_preview.gd        ← selected-destination path preview
      selection_overlay.gd   ← pink selection diamond
      tile_labels_overlay.gd ← numbered grid overlay
    tools:
      build_tileset.gd       ← headless TileSet builder
  resources/
    tilesets/
      tileset_blocks.tres    ← generated TileSet resource
  shaders/
```

Likely next structural additions during M1.5: contextual action UI, stepwise movement execution along the previewed path, and first enemy placeholder systems.

## Milestones

See [GAME_PLAN.md §11](GAME_PLAN.md) for the full roadmap.

**M1.5 in progress** — segment layout + three-layer fog of war complete; next: contextual action UI, stepwise movement along path, first enemy placeholders.

## Contributing

Suggested workflow:

- `git checkout -b feature/<short-name>`
- commit changes
- push branch and open a PR
