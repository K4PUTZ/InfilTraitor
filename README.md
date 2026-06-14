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

**Alpha Refactor Complete (2026-06-06)** — Refactor Sprint 04 + 5 bugfixes applied. Core systems consolidated: WallEdgeData unified, stats data-driven, angular FOV (8-dir), A* pathfinding with explicit data flow. Architecture stable for infinite scaling (Freelance mode, tier progression).

| Milestone | Status |
|---|---|
| M0 — Design & asset organization | ✅ Complete |
| M1 — Godot prototype (one room, movement) | ✅ Complete (replaced by M1-rewrite) |
| M1-rewrite — Stable interactive map foundation | ✅ Complete |
| M1.5 — Tactical UI + Alpha Gameplay feel | ✅ Complete (refactored) |
| M2 — Enemy visibility & guard detection | ⧖ In progress (M2-01 to M2-05 + quickfix deployed) |
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
- **M2 Sound System:** Event-driven tics (edge-crossing), persistent noise grid with decay, audio detection with wall attenuation, organic patrol behavior (variable speed, pauses, look rotation), probabilistic colored cone visualization.
- Architecture now supports infinite scaling: data-driven stats, no hardcoded ceilings, LLM-ready (structure/content separated).
- Next internal work is confrontation mechanics (4 cover states, flanking, peek).

### M2 Alpha Sound System Deploy (Completed 2026-06-07)

✅ **M2-01:** Event-driven tic detection — edge-crossing replaces turn-based evaluation  
✅ **M2-02:** Colored cone visual system — tile-by-tile probability visualization with state-based appearance  
✅ **M2-03:** Patrulha Orgânica — variable patrol speed (0.6× to 3.0× multiplier), spontaneous pauses (20% chance, 1–2 turns), look rotation to 8 directions without movement  
✅ **M2-04:** Sistema de Barulho — persistent noise grid with per-turn decay (0.25 rate), emission at ~20% per agent step, 3-layer cyan cone visualization  
✅ **M2-05:** Detecção Auditiva — audio detection independent of visual LOS, wall attenuation (0.6× per wall), distance falloff (2-tile hearing radius)  
✅ **Quickfix:** Removed duplicate constants, added detection accumulation to audio reactions, immediate UI feedback  

📖 **See:** [DEVELOPMENT/PROGRESS.md](DEVELOPMENT/PROGRESS.md) for complete technical report.

### Refactor Sprint 04 (Completed 2026-06-06)

✅ **Refactor 01:** WallEdgeData consolidation — unified edge key generation  
✅ **Refactor 02:** Data-driven stats — removed hardcoded maxima  
✅ **Refactor 03:** Angular FOV — 90° smooth cone (8-direction support)  
✅ **Refactor 04:** A* pathfinding — optimal guard navigation  

✅ **Bugfixes Applied (2026-06-06):**
- _path_index starts at 1 (guards skip start cell on pathfind)
- move_to_cell_animated() uses GuardPathfinder (not greedy)
- Removed dead code (_build_step_path_to, _orthogonal, _axis_projection)
- Explicit types in guard_pathfinder.gd (nb: Vector2i)
- Data flow explicit: no defaults, all parameters passed through chain

📖 **See:** [DEVELOPMENT/REFACTOR_SPRINT_04.md](DEVELOPMENT/REFACTOR_SPRINT_04.md) for detailed report.

### Alpha Dev Vision Foundation (Completed 2026-06-06)

✅ **Dev 01:** DEV_VISION Mode — centralized V-key toggle for all debug overlays  
✅ **Dev 02:** Guard Debug Label — state display panel (id, state, cell, facing, last_known)  
✅ **Dev 03:** Tile Info on Hover — cyan label showing coordinates + blocked/guard/agent metadata  
✅ **Dev 04:** Agent Trail Overlay — yellow diamond path history (last 5 tiles), opacity gradient  
✅ **Dev 05:** Guard Detection Meter — arc meter above guard head showing state-based detection (0% → 100%)  
✅ **Quickfixes:** Trail offset parameterized, hover label completed with full metadata  

📖 **See:** [DEVELOPMENT/DEV_VISION_FOUNDATION.md](DEVELOPMENT/DEV_VISION_FOUNDATION.md) for complete technical report.

### Alpha Lighting Taxonomy & Vertical Depth Foundation (Completed 2026-06-14)

✅ **L-DOC-01:** Lighting Taxonomy & Semantic Visibility Classes
- 5 discrete visibility classes (FULL_LIT, DIM, PENUMBRA, SHADOW, DEEP_SHADOW)
- Detection multiplier model (2.0× to 0.2× guards' baseline detection)
- 7 light source types (Omni, Directional, Cone, Ambient, Intermittent, Emergency, Mobile)
- Separated tactical (gameplay) from visual (rendering) lighting

✅ **L-DOC-02:** Vertical Lighting Topology & Height Semantics
- 4 semantic vertical layers (L0–L3): Subfloor, Playable, Structural, Overhead
- 5 discrete height classes (0–4) for deterministic shadow casting
- Shadow projection formula with 8-direction quantization
- Shadow ownership matrix: walls cast shadows, guards/agents receive shadows
- Runtime philosophy: grid-based, deterministic, low-overhead, gameplay-first

📖 **See:** [docs/systems/lighting.md](docs/systems/lighting.md) for L-DOC-01 & L-DOC-02 (671 lines, pure semantic architecture)

### Next up (M2 continuation)

- **M2-13:** Geometric shadow projection & baking — implement cone shadow casting, deterministic shadow grids per room
- **M2-14:** Shadow system calibration & visual polish — threshold tuning, edge smoothing, per-guard detection customization (L-DOC-03)
- **M2-15:** Advanced overlays & tactical visualization — movement preview (PRIO_MOVEMENT), noise heatmap, objective markers
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
