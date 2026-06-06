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

**Alpha After Refactor (2026-06-05)** — Refactor Sprint 04 complete. Core systems consolidated: WallEdgeData unified, stats data-driven, angular FOV (8-dir), A* pathfinding. Architecture stable for infinite scaling (Freelance mode, tier progression).

| Milestone | Status |
|---|---|
| M0 — Design & asset organization | ✅ Complete |
| M1 — Godot prototype (one room, movement) | ✅ Complete (replaced by M1-rewrite) |
| M1-rewrite — Stable interactive map foundation | ✅ Complete |
| M1.5 — Tactical UI + Alpha Gameplay feel | ✅ Complete (refactored) |
| M2 — Enemy visibility & guard detection | ⧖ In progress (architecture locked) |
| M3 — Procedural floor builder | |
| M4 — Vertical slice | |
| M5 — Monetisation | |
| M6 — Content expansion | |
| M7 — Polish & launch | |

## Current status

- Core isometric room builder and wall-autotile system are stable.
- Movement, AP tracking, fog of war, tile selection, and camera controls are implemented.
- Perspective controls are now available via a 2x2 HUD pad (N/E/S/W), with runtime layout rotation.
- Enemy guard system with angular FOV detection (90°, 8 directions) and A* pathfinding.
- Architecture now supports infinite scaling: data-driven stats, no hardcoded ceilings, LLM-ready (structure/content separated).
- Next internal work is event-driven detection by tic, noise system, and confrontation mechanics.

### Refactor Sprint 04 (Completed 2026-06-05)

✅ **Refactor 01:** WallEdgeData consolidation — unified edge key generation  
✅ **Refactor 02:** Data-driven stats — removed hardcoded maxima  
✅ **Refactor 03:** Angular FOV — 90° smooth cone (8-direction support)  
✅ **Refactor 04:** A* pathfinding — optimal guard navigation  

📖 **See:** [DEVELOPMENT/REFACTOR_SPRINT_04.md](DEVELOPMENT/REFACTOR_SPRINT_04.md) for detailed report.

### Next up (M2 continuation)

- Event-driven detection by tic (edge-crossing) — replace turn-based evaluation
- Noise system — terrain cost, degradation, propagation radius
- Confrontation system — 4 cover states, flanking, peek mechanic
- Enemy state machine — complete FSM refinement (patrol → suspicious → alert → chase)
- Communication system — apito (local), rádio (global), alarme (site-wide)
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
