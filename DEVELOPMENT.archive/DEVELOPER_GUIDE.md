# INFILTRAITOR — Developer Guide

> Internal reference for engine direction, Godot project structure, implementation notes, and developer workflow.

## Purpose

This document is the internal developer guide for `INFILTRAITOR`. It is intentionally distinct from the root `README.md`:

- `README.md` is the public project overview and high-level status report.
- `DEVELOPMENT/DEVELOPER_GUIDE.md` is the internal technical reference for the team.

Use this file for implementation details, Godot structure, engine choices, and current prototype direction.

## Engine & Visual Direction

- **Engine:** Godot 4 (GDScript)
- **Rendering:** Isometric 2.5D — dimetric projection (45° horizontal, 26.57° elevation)
- **Orientation:** Portrait mobile-first, with optional desktop viewport mode
- **Tile system:** Godot `TileMap` in isometric mode, using Kenney isometric packs
- **Gameplay feel:** tactical XCOM-style movement, Zelda-like room flow, stealth-first information management

## Visual References

| Reference | Lesson |
|---|---|
| *Emperor: Rise of the Middle Kingdom* | Pre-rendered isometric sprites, readable silhouettes, tile-based structure |
| *StarCraft / SC: Remastered* | Strong contrast, tile readability, clear unit presentation |
| *XCOM 2* | Tactical UI clarity, movement zones, turn-based feel |

See `REFERENCES/` for screenshots and style cues.

## Source of truth

| File | Contents |
|---|---|
| `DEVELOPMENT/GAME_PLAN.md` | Full game design, mechanics, milestones, open questions |
| `DEVELOPMENT/ASSET_MAP.md` | Tile catalogue, asset mapping, procedural generation guide |
| `README.md` | High-level project overview and public-facing status |

## Current implementation snapshot

**M1.5 Alpha Walls Done** — the current prototype is a stable tactical segment with a robust room builder and isometric rendering pipeline.

### Key systems in place

- Procedural room builder with `build_room(rect, doors)` and `place_inner_room()`
- Autotile wall selection for straights, corners, and door slots
- 18×36 tactical segment generation with floor, border, inner walls, and props
- Tile picking aligned to visual centres using 3×3 nearest-neighbour search and diamond hit-testing
- Stepwise agent movement along Dijkstra paths with `step_finished` events
- Movement range overlay, path preview, two-tap confirm, and AP band display
- Progressive fog-of-war system with three overlapping layers:
  - distance fog shader (`vision_fog.gdshader`)
  - FOW polygon overlay
  - camera leash
- Y-sorting fix on room root and all TileMap layers
- Tile origin calibration for wall, corner, and corner-adjacent assets

### Recent technical achievements

- All 36 corner asset variants calibrated and anchored correctly
- Y-sorting enabled across `Room` and tile layers to enforce isometric occlusion
- Floor apron around room borders to make walls sit on ground rather than background
- Interior barrier placement merged into blocked map and pathfinding
- Static camera input with drag pan, scroll/pinch zoom, and mobile gesture support

## Prototype direction

The active prototype is focused on making the tactical movement and room environment feel correct before adding combat complexity.

Short-term goals:

- Door open/close visuals and logical passage state
- Segment transition between adjacent rooms and level persistence
- Player character sprite and animation
- Contextual action menu for second-tap interactions
- First guard enemy placeholder with patrol and vision cone

## Project layout (current)

```
INFILTRAITOR/
  DEVELOPMENT/         ← design docs (GAME_PLAN.md, DEVELOPER_GUIDE.md, ASSET_MAP.md)
  REFERENCES/          ← visual style screenshots
  ASSETS/              ← game-ready assets
    ISOMETRIC/         ← Kenney isometric tile packs
    CHARACTERS/        ← animated character sprites
    UI/                ← HUD, menus, icons
    FX/                ← particle/effect sprites
    REFERENCE/         ← orthographic renders / alt tilesets
  ARCHIVE/             ← legacy / reference textures
  godot/               ← active Godot project
  export/              ← web export output
```

### Godot project structure

```
godot/
  project.godot
  scenes/
    game/
      room.tscn
  scripts/
    game/
      room.gd
      room_layout_builder.gd
      agent.gd
      turn_manager.gd
      movement_overlay.gd
      path_preview.gd
      selection_overlay.gd
      tile_labels_overlay.gd
    ui/
      fog_of_war_overlay.gd
    tools/
      build_tileset.gd
  shaders/
    vision_fog.gdshader
  resources/
    tilesets/
      tileset_blocks.tres
```

## Milestones

- **M0** — Design & asset organization
- **M1** — Godot prototype and movement system
- **M1.5** — Tactical UI, alpha gameplay, fog of war, room generation
- **M2** — Threats, guards, detection, enemy AI
- **M3** — Procedural floor builder and dungeon systems
- **M4** — Vertical slice
- **M5** — Monetisation and polish

## Developer workflow

- Work in feature branches: `feature/<short-name>`
- Keep dev notes in `DEVELOPMENT/PROGRESS.md` or `DEVELOPMENT/GAME_PLAN.md`
- Use Godot editor for scene/testing; use the tile builder scripts for batch asset updates

## Notes

This guide should remain the internal technical reference. If the same information is useful outside the team, move it to `README.md` instead and keep this guide focused on implementation details.
