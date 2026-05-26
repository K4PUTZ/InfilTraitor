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

**Alpha 2** — Clean room rewrite: correct isometric tile picking, camera pan/zoom, HUD toolbar, coordinate overlay.

| Milestone | Status |
|---|---|
| M0 — Design & asset organization | ✅ Complete |
| M1 — Godot prototype (one room, movement) | ✅ Complete (replaced by M1-rewrite) |
| M1-rewrite — Stable interactive map foundation | ✅ Complete |
| M1.5 — Tactical UI (tap-to-select, path preview) | |
| M2 — Threats & combat (guards, detection) | |
| M3 — Procedural floor builder | |
| M4 — Vertical slice | |
| M5 — Monetisation | |
| M6 — Content expansion | |
| M7 — Polish & launch | |

### Alpha 2 — what's working (2026-05-26)

- **Complete room rewrite** — deleted all M1 scripts/scenes; rebuilt from scratch with a clean 3-file architecture
- **Correct isometric tile picking** — 3×3 nearest-neighbour search comparing to visual centres (`map_to_local + Vector2(0,64)`); click any quadrant of any tile, always selects the correct cell
- **Pink diamond selection outline** — `SelectionOverlay` draws in world space, zero lag
- **17×17 room** with block border and floor interior
- **Camera pan** — left-drag with threshold (> 8 px = pan, short release = tile select)
- **Mouse-wheel zoom** — scroll up/down ±0.06 per tick, clamped 0.20–1.20
- **Pinch-to-zoom** — two-finger gesture via `InputEventScreenTouch` / `InputEventScreenDrag`; conflicts with single-finger pan suppressed automatically
- **Tile coordinate overlay** — `TileLabelsOverlay` draws `x,y` with drop shadow at each tile's visual centre
- **HUD toolbar** (`#` / `[]` / `M|D`):
  - `#` — toggle coordinate overlay (dims to 35 % when off)
  - `[]` — toggle fullscreen / windowed
  - `M / D` — switch between mobile (390×844) and desktop (1280×720) with correct `content_scale_size` update so camera FOV changes accordingly
- **Default launch in desktop 1280×720**

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
