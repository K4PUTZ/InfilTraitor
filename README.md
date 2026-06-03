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

**Alpha Walls Done** — Room generation system complete; wall tile origins calibrated; all wall-face sprites pixel-perfect in all four orientations.

| Milestone | Status |
|---|---|
| M0 — Design & asset organization | ✅ Complete |
| M1 — Godot prototype (one room, movement) | ✅ Complete (replaced by M1-rewrite) |
| M1-rewrite — Stable interactive map foundation | ✅ Complete |
| M1.5 — Tactical UI + Alpha Gameplay feel | ⧖ In progress |
| M2 — Enemy visibility & guard detection | ⧖ In progress |
| M3 — Procedural floor builder | |
| M4 — Vertical slice | |
| M5 — Monetisation | |
| M6 — Content expansion | |
| M7 — Polish & launch | |

## Current status

- Core isometric room builder and wall-autotile system are stable.
- Movement, AP tracking, fog of war, tile selection, and camera controls are implemented.
- Perspective controls are now available via a 2x2 HUD pad (N/E/S/W), with runtime layout rotation.
- The current prototype is a playable tactical segment with placeholder agent visuals.
- Enemy visibility now tracks player vision radius and guard fade stages before disappearance.
- Next internal work is door/segment transitions, action menu, character sprite, and guard AI.

### Next up (M1.5 continued)

- Door tile visual verification and door open/close logic
- Segment transition — spawn adjacent segment on exit, pass `segment_grid_pos` and `level_seed`
- Character sprite (AnimatedSprite2D with Human_0 Idle/Run assets)
- Contextual action menu on second tap — move / interact / wait choices
- Enemy guard (patrol, vision cone, alert meter) — M2 start
- Environment theme system (Phase 2): `EnvironmentTheme` resource, `GameContext` autoload, ambient/fog color per zone
- Perspective transition polish: optional animated swap between N/E/S/W viewpoints

---

## Documentation

| File | Contents |
|---|---|
| [DEVELOPMENT/GAME_PLAN.md](DEVELOPMENT/GAME_PLAN.md) | Full game design — mechanics, milestones, open questions |
| [DEVELOPMENT/ASSET_MAP.md](DEVELOPMENT/ASSET_MAP.md) | Tile catalogue, chapter-theme mapping, procedural generation guide |
| [DEVELOPMENT/DEVELOPER_GUIDE.md](DEVELOPMENT/DEVELOPER_GUIDE.md) | Internal developer guide: engine direction, Godot structure, implementation notes |

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
