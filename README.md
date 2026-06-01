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

**Alpha Walls** — Room generation system complete; wall tile origins calibrated; all wall-face sprites pixel-perfect in all four orientations.

| Milestone | Status |
|---|---|
| M0 — Design & asset organization | ✅ Complete |
| M1 — Godot prototype (one room, movement) | ✅ Complete (replaced by M1-rewrite) |
| M1-rewrite — Stable interactive map foundation | ✅ Complete |
| M1.5 — Tactical UI + Alpha Gameplay feel | ⧖ In progress |
| M2 — Threats & combat (guards, detection) | |
| M3 — Procedural floor builder | |
| M4 — Vertical slice | |
| M5 — Monetisation | |
| M6 — Content expansion | |
| M7 — Polish & launch | |

### Alpha Walls — what's working (2026-06-01)

- **Rectangular room builder** — `build_room(rect, doors)` places correct autotile per cell: straight walls, corners, and door slots; returns `{wall_tiles, _blocked_map}`
- **`place_inner_room()`** — validates fit and gap, delegates to `build_room`; supports interior barriers (e.g. mid-room wall with passage gap)
- **Positional autotile** — `_pick_wall_tile(cell, rect)` uses edge membership to select `wallCorner_*` (2 edges), `wall_*` (1 edge) in all 4 orientations; all corners visually confirmed
- **`LevelGraph` 3×3 segment grid** — Kruskal MST on a 3×3 segment lattice; `EXIT_CELLS` per cardinal direction; `access_points_for()` / `is_dead_end()` helpers; wired into `room.gd` via `segment_grid_pos` and `level_seed` exports
- **Wall tile origins calibrated** — all 240 wall-face tile variants (`wall_*`, `wallHalf_*`, `arrowWall_*`, `switchWall*`, `window*`, `doorClosed_*`, `doorOpen_*`, `doorway*`) set to `texture_origin = Vector2i(0, -384)`; PNG content provides per-face visual offset natively

### Alpha Gameplay — what's working (2026-05-30)

- **Complete room rewrite** — deleted all M1 scripts/scenes; rebuilt from scratch with a clean 3-file architecture
- **Correct isometric tile picking** — 3×3 nearest-neighbour search comparing to visual centres (`map_to_local + Vector2(0,64)`); click any quadrant of any tile, always selects the correct cell
- **Visual/logical grid alignment stabilized** — shared `VISUAL_GRID_OFFSET` compensation keeps camera centering, coordinate labels, selection outline, and picking aligned to the rendered 512 px tile sprites
- **Strict diamond hit-test** — clicks outside the tile diamond no longer select cells in the empty area above the board
- **18×36 tactical segment** — floor tiles in `FloorLayer`; autotiled border + interior walls in `StructureWallLayer`; crates in `StructureLayer` above path overlays. 1-cell floor apron outside the border so walls sit on ground.
- **Tile-wall autotile system** — `room_layout_builder.gd` picks `wall_N/S/E/W`, `wallCorner_*`, or `block_N` per cell via three ordered rules: (1) mid-border straight-face override; (2) open-count autotile for corners and L-junctions; (3) end-cap facing for 3-open-side cells. Eliminates T-junction notches and floating cubes at interior wall passage mouths.
- **Blocking props and blocked border** — crate cells and border cells are inaccessible and excluded from movement range / selection
- **Step-by-step tile movement** — agent traverses the Dijkstra path cell-by-cell at 0.13 s/tile (TRANS_SINE ease-in/out); snappy tactical feel with no slide
- **Progressive fog-of-war reveal** — `step_finished` signal emitted on each tile arrival; fog clears as the agent walks, not all at once on arrival
- **Static camera** — camera is fully player-controlled (drag to pan, scroll/pinch to zoom); not locked to the agent during movement; destination tile must be visible before confirming a move
- **Vision fog shader tracks agent in real time** — gradient uses `agent.global_position` so the clear zone follows the animated sprite smoothly mid-step
- **2 AP movement prototype** — AP label, manual `END` button, and optional auto-end checkbox inside the `END` control
- **Movement range overlay** — reachable 1 AP / 2 AP bands recomputed from the agent cell with blocked cells respected
- **Path preview and two-tap confirmation** — first tap selects a destination tile, second tap on the same tile commits movement
- **Pink diamond selection outline** — `SelectionOverlay` draws in world space, zero lag
- **Camera pan** — left-drag with threshold (> 8 px = pan, short release = tile select)
- **Mouse-wheel zoom** — scroll up/down ±0.06 per tick, clamped 0.20–1.20
- **Pinch-to-zoom** — two-finger gesture via `InputEventScreenTouch` / `InputEventScreenDrag`; conflicts with single-finger pan suppressed automatically
- **Tile coordinate overlay** — `TileLabelsOverlay` draws `x,y` with drop shadow at each tile's visual centre; starts OFF by default
- **HUD toolbar** (`#` / `[]` / `M|D` / `AP` / `END`):
  - `#` — toggle coordinate overlay (dims to 35 % when off)
  - `[]` — toggle fullscreen / windowed
  - `M / D` — switch between mobile (390×844) and desktop (1280×720) with correct `content_scale_size` update so camera FOV changes accordingly
- **Default launch in desktop 1280×720**

Current notes:
- Agent is still a draw-based placeholder (diamond + head polygon); character sprites come after the gameplay feel is locked.
- The visual alignment correction lives in runtime scripts; if generalized later it should move into TileSet generation.

### Alpha 1 — historical snapshot (superseded by the M1-rewrite)

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

### Next up (M1.5 continued)

- Door tile visual verification and door open/close logic
- Segment transition — spawn adjacent segment on exit, pass `segment_grid_pos` and `level_seed`
- Character sprite (AnimatedSprite2D with Human_0 Idle/Run assets)
- Contextual action menu on second tap — move / interact / wait choices
- Enemy guard (patrol, vision cone, alert meter) — M2 start
- Environment theme system (Phase 2): `EnvironmentTheme` resource, `GameContext` autoload, ambient/fog color per zone

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
