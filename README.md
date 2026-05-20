# INFILTRAITOR

> Mobile turn-based stealth tactics game  
> **Engine:** Godot 4 · **Rendering:** Isometric 2.5D · **Platform:** iOS / Android / HTML5

---

## Overview

INFILTRAITOR is a turn-based stealth tactics game in the style of XCOM, with a Zelda-like room-to-room dungeon flow.

- **2 AP per turn** tactical movement
- **Portrait orientation**, camera follows the agent
- **Procedural dungeon generation** from handcrafted room templates
- **Isometric 2.5D** — dimetric projection (45° horizontal, 26.57° elevation), square tile grid via Godot `TileMap`

Visual direction: pre-rendered isometric 3D sprites (Emperor: Rise of the Middle Kingdom / StarCraft), readable tactical overlays (XCOM 2).

---

## Project status

**Alpha 1** — AP/turn system, movement overlay and animated movement working in-engine.

| Milestone | Status |
|---|---|
| M0 — Design & asset organization | ✅ Complete |
| M1 — Godot prototype (one room, movement) | ✅ Complete |
| M1.5 — Tactical UI (tap-to-select, path preview) | |
| M2 — Threats & combat (guards, detection) | |
| M3 — Procedural floor builder | |
| M4 — Vertical slice | |
| M5 — Monetisation | |
| M6 — Content expansion | |
| M7 — Polish & launch | |

### Alpha 1 — what's working (2026-05-19)

- **TurnManager** autoload singleton — PLAYER / ENEMY phase cycle
- **2 AP per turn** system with Dijkstra movement range (zone1 = 1 AP / zone2 = 2 AP / dash = 2 AP + bonus tile)
- **MoveOverlay** — perimeter outline per zone with glow effect (faint fill + thick antialiased border); hides during movement, re-appears on arrival
- **Click-to-move** with AP cost awareness; End Turn button triggers enemy phase (stub: resolves immediately)
- **Movement animation** — 0.30 s Tween (QUAD/EASE_OUT); camera follows agent's animated position
- **55×55 room** with oriented border walls and floor variety (floorHalf mixed at 20%)
- **Decorative props** (crates, columns, pole groups) scattered as visual landmarks (~4.5% of tiles)
- VS Code dev workflow: **F5** launches the game, **⌘⇧B** rebuilds the TileSet

### Alpha 0 — what's working (2026-05-19)

- Godot 4.6 project scaffold (portrait 390×844, Mobile renderer)
- 240-tile isometric TileSet generated from `blocks-prototype` pack
- Custom data per tile: `tile_name`, `walkable`, `cover`, `interactive`
- 9×9 test room rendered from name-based tile placement (`room.gd`)
- TileRegistry: name → source_id lookup (auto-generated)

### Next up (M1.5)

- Agent AP bar UI (pip indicators draining as AP is spent)
- Room shape: corridor + side passages (replace open rectangle)
- Entrance / exit tiles and room transitions
- Enemy placeholder with cone of vision

---

## Documentation

| File | Contents |
|---|---|
| [DEVELOPMENT/GAME_PLAN.md](DEVELOPMENT/GAME_PLAN.md) | Full game design — mechanics, milestones, open questions |
| [DEVELOPMENT/ASSET_MAP.md](DEVELOPMENT/ASSET_MAP.md) | Tile catalogue, chapter-theme mapping, procedural generation guide |
| [DEVELOPMENT/README.md](DEVELOPMENT/README.md) | Engine direction, visual references, planned Godot project structure |

---

## Asset structure

```
ASSETS/
├── ISOMETRIC/          ← 8 Kenney isometric packs (blocks, terrain, city, etc.)
├── CHARACTERS/humans/  ← 8 character variants × Idle / Run / Pickup animations
├── UI/                 ← HUD panels, icons, medals
├── FX/smoke/           ← particle sprites
└── REFERENCE/          ← orthographic renders + alternate tilesets (not for gameplay)
REFERENCES/             ← visual style screenshots (Emperor, StarCraft, XCOM)
```

All isometric packs use the same dimetric projection — fully compatible with Godot's isometric TileMap mode.

---

## Repository

`git clone https://github.com/K4PUTZ/InfilTraitor.git`
