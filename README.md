# INFILTRAITOR

> Mobile turn-based stealth tactics game  
> **Engine:** Godot 4.6 (GDScript) · **Rendering:** isometric 2.5D voxels on a Godot 3D board · **Platform:** iOS / Android, portrait

---

## Overview

INFILTRAITOR is a turn-based stealth tactics game in the style of XCOM, with a Zelda-like room-to-room flow.

- **2 AP per turn** tactical movement, portrait orientation, camera follows the agent
- **A Godot 3D board over a packed voxel store** (`VoxelStore` + `Board3DLive`): every wall, floor, roof and glass pane is voxels
  (8 per grid unit axis, 8 levels per storey) that blasts, shots and fire destroy, scorch and char; destruction persists
- **Camera-only rotation:** four fixed views (N/E/S/W) of one world; turning is the camera's yaw, nothing is rebuilt
- **Live skinned-mesh actors** lit from the board's own light planes; props are real models (CC0) or destructible voxel objects
- **Data-driven maps** (`maps/*.map.json`); procedural generation is designed (`docs/systems/MAP_MASTER_PLAN.md`), not built

Visual direction: readable tactical overlays (XCOM 2) over a voxel world that reacts to what the player does.

---

## 📚 Documentation Hierarchy

**The documentation is organized into four levels. Start here, then follow the path for your task.**

### Level 1: Your Starting Point (5 min read)

**I'm implementing a feature. Where do I start?**
1. Read this README (you are here)
2. Read [CLAUDE.md](CLAUDE.md) — development handbook with rules, workflow, and system references (Claude Code auto-loads it; other tools should read it manually)
3. Identify which subsystem you're modifying
4. Follow the link to the relevant Master Plan (see below)

**The workflow is:**
```
README
	↓
CLAUDE.md (handbook + architectural rules)
	↓
Identify subsystem
	↓
Read relevant Master Plan
	↓
Implement
	↓
Run smoke test (CLAUDE.md § Verification Protocol)
```

### Level 2: Master Plans (Canonical Subsystem Specifications)

**Read these when modifying a specific subsystem:**

| Subsystem | Master Plan | Contains |
|-----------|-------------|----------|
| **AI & Guard Behavior** | [docs/systems/AI_MASTER_PLAN.md](docs/systems/AI_MASTER_PLAN.md) | FSM, detection curves, communication, turn flow |
| **Lighting & Visibility** | [docs/systems/LIGHT_MASTER_PLAN.md](docs/systems/LIGHT_MASTER_PLAN.md) | Visibility taxonomy, light sources, shadows, multipliers |
| **Map System** | [docs/systems/MAP_MASTER_PLAN.md](docs/systems/MAP_MASTER_PLAN.md) | MapSpec, layout, wall storeys (rotation is the camera's yaw since R3D-ROT) |
| **Voxel Geometry** | [docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md](docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md) | Voxel geometry (slices, slabs, junction columns), dirty flag |
| **The 3D board and the engine** | [PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md](PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md) | The migration, every stage built (LIGHT, PROPS, ACTORS, WORLD, ROT), the open threads and the gates |
| **Actors, props, destruction, weapons** | [PROMPTS/PLANNING/](PROMPTS/PLANNING/) | `ACTOR`, `CHARACTER`, `MOVEMENT`, `PROPS_TIER4`, `PROP_PIPELINE`, `DESTRUCTION`, `WEAPON`, `GLASS`: decision registers and plans |
| **Localization (i18n)** | [docs/technical/LOCALIZATION_REFERENCE.md](docs/technical/LOCALIZATION_REFERENCE.md) | TranslationServer, CSV format, key conventions |

### Level 3: System References (Detailed Documentation)

**Consult for deep dives into specific systems:**

| System | Reference | Purpose |
|--------|-----------|---------|
| **Architecture Overview** | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | High-level system relationships and philosophy |
| **Lighting Pipeline** | [docs/systems/lighting_runtime_pipeline.md](docs/systems/lighting_runtime_pipeline.md) | Runtime flow and invalidation rules |
| **Visual Perception** | [docs/systems/perception.md](docs/systems/perception.md) | Detection cones, LOS, geometry |
| **Audio System** | [docs/systems/noise.md](docs/systems/noise.md) | Noise propagation, hearing, audio detection |
| **Movement** | [docs/systems/movement.md](docs/systems/movement.md) | Grid navigation, A*, AP economy |
| **Rendering** | [docs/systems/rendering.md](docs/systems/rendering.md) | Overlay layering (pre-R3D text, bannered; the live render is in `docs/ARCHITECTURE.md` §0) |

### Level 4: Production & Vision (Team Coordination)

**For project leads and team members:**

- **[docs/vision/](docs/vision/)** — Game vision, design philosophy, pillars
- **[docs/production/](docs/production/)** — Roadmap, status, milestones, risk assessment

### Historical Archive

**[docs/history/](docs/history/)** — Archived design explorations and implementation logs, clearly marked as superseded

---

## Project status

**Engine track (RENDER3D): closed up to R3D-ROT (2026-10-02).** The 2D `TileMapLayer` board was deleted at R3D-END (2026-09-25; `34881f81`
is the last commit that builds it). Built since: R3D-LIGHT (blast and shot frames inside the 100 ms budget on the target phones),
R3D-PROPS, R3D-ACTORS, R3D-WORLD and R3D-ROT. `python3 tools/persistent/verify.py full` passes (selftests, boot, identity and
rotation gates: ground, shot, occlusion, mirror, pick, roof-yaw, world, round trip, pixel).

- **Live status, what works and what does not:** [`docs/production/current_state.md`](docs/production/current_state.md)
- **The engine plan and every open thread:** [`PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md`](PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md)
- **Debt and known limits:** [`docs/production/technical_debt.md`](docs/production/technical_debt.md)
- **Session records:** `PROMPTS/RESUMO_SESSAO_*.md` (the newest is where work stopped)
- **June 2026 status log** (M2 sound, light vision, refactor sprint 04): [`docs/history/README_STATUS_2026-06.md`](docs/history/README_STATUS_2026-06.md)

Not built yet (designed, in `docs/DESIGN_MASTER_PLAN.md`): confrontation and cover, the 3-layer resistance model, the equipment
classes, enemy factions and hierarchy, segment map structure and Freelance escalation, the noise indicator, saves with slots.

### How to check a change

```
python3 tools/persistent/verify.py            # picks docs / quick / smoke from what changed
python3 tools/persistent/verify.py full       # only to close a stage; take --baseline at the start of the task
```

The boot gates refuse to start while another Godot is alive (the editor included).

---

## Documentation

| File | Contents |
|---|---|
| [docs/README.md](docs/README.md) | Documentation index — start here |
| [docs/production/milestones.md](docs/production/milestones.md) | The executable milestone list |
| [docs/technical/ASSET_MAP.md](docs/technical/ASSET_MAP.md) | Tile catalogue and asset conventions |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | The layered runtime picture: content, load pipeline, state, simulation, render |
| [docs/DIRECTION_GLOSSARY.md](docs/DIRECTION_GLOSSARY.md) | Directions, faces and the banned-terms list |
| [docs/technical/BAKE_SYSTEM_REFERENCE.md](docs/technical/BAKE_SYSTEM_REFERENCE.md) | **Historical:** the atlas bake went at R3D-END; what survives is its logic (grayscale facades, FNV-1a, loud-fail) |

---

## Asset structure

```
ASSETS/
├── materials/<id>/     ← one folder per material: its grayscale facade and damage decals (what the 3D board reads)
├── props/              ← CC0 models, slots and .vox voxel objects (props/MODEL_SOURCES.md has the licences)
├── TEXTURES/           ← photographic surfaces and patches
├── ANIMATIONS/ AUDIO/  ← rigs and sound
├── ISOMETRIC/          ← the floor / structure TileSet sources only (the 3D board needs no tile atlas)
└── ART_SPECIFICATIONS.md   ← read before authoring any texture or decal
REFERENCES/             ← visual style screenshots (Emperor, StarCraft, XCOM)
```

---

## Repository

`git clone https://github.com/K4PUTZ/InfilTraitor.git`
