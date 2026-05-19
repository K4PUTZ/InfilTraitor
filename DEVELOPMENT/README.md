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
```

See [ASSET_MAP.md](ASSET_MAP.md) for the full tile catalogue and procedural generation guide.

## Planned Godot project structure (M1)

```
godot/
  project.godot
  assets/
    tilesets/          ← isometric tile atlases (sourced from ASSETS/ISOMETRIC/)
    sprites/           ← agent, enemies, interactive objects
    ui/                ← HUD elements, icons, fonts
    audio/             ← music tracks, SFX
  scenes/
    main.tscn          ← entry point
    game/
      game.tscn        ← main game scene
    map/
      room.tscn        ← base room template
      tilemap.tscn     ← isometric TileMap node
    entities/
      agent.tscn
      guard.tscn
    ui/
      hud.tscn
      context_menu.tscn
      alert_meter.tscn
  scripts/
    core/
      turn_manager.gd
      grid.gd
      pathfinder.gd
    entities/
      agent.gd
      guard.gd
    map/
      room.gd
      dungeon_generator.gd
    ui/
      hud.gd
      context_menu.gd
  resources/
    rooms/             ← room template .tres definitions
    tiles/             ← TileSet resources
  data/
    rooms/             ← JSON room templates
    skills/
    gadgets/
```

## Milestones

See [GAME_PLAN.md §11](GAME_PLAN.md) for the full roadmap.

**Next: M1** — Godot project setup; isometric TileMap; entrance/exit room; agent movement (2 AP/turn); TurnManager.

## Contributing

Suggested workflow:

- `git checkout -b feature/<short-name>`
- commit changes
- push branch and open a PR
