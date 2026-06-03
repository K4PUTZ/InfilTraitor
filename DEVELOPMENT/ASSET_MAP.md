# INFILTRAITOR — Asset Map

> **Purpose:** Single reference for every asset available in the project — what it is, where it lives, how it maps to a game element, and how it is used in procedural dungeon generation.
> **Last updated:** 2026-05-19
> **Engine:** Godot 4 · TileMap isometric mode · 2:1 dimetric projection (45° horizontal, 26.57° elevation)

---

## Repository layout

```
INFILTRAITOR/
├── ASSETS/               ← game-ready assets (correct isometric angle ✅)
│   ├── ISOMETRIC/        ← tile packs for Godot TileMap
│   ├── CHARACTERS/       ← animated character sprites
│   ├── UI/               ← HUD, menus, icons
│   ├── FX/               ← particle / effect sprites
│   └── REFERENCE/        ← orthographic renders + mcblocks (alt style)
├── ARCHIVE/              ← flat 2D textures, fonts, FX (reference / future use)
├── DEVELOPMENT/          ← design docs (GAME_PLAN, README, this file)
├── REFERENCES/           ← visual style screenshots (Emperor, StarCraft, XCOM)
└── TEST/                 ← scratch space
```

---

## ASSETS/ISOMETRIC/ — Tile packs

All packs use the **same 2:1 dimetric projection** and are immediately compatible with Godot's isometric TileMap mode. No conversion needed.

### ★★★★★ `blocks-prototype/` — CORE GAME TILES

**Source:** Kenney Isometric Miniature Prototype  
**Use in Godot:** `TileMap` layer 0 (structural) + layer 1 (props/interactables)  
**Key path:** `ASSETS/ISOMETRIC/blocks-prototype/Isometric/<tiletype>_<dir>.png`

Naming convention: every tile exists in 4 rotations — `_NE`, `_NW`, `_SE`, `_SW`.
These diagonal suffixes match the isometric projection and are the actual filenames in the pack.
Total: **240 tiles** (60 types × 4 directions).

#### Tile catalogue by game role

| Game Role | Tile name(s) | Procedural use |
|---|---|---|
| **FLOOR — walkable** | `floor`, `floorHalf`, `floorQuarter` | Base layer of every room; `floor` is the standard tile |
| **WALL — solid block** | `block`, `blockHalf`, `blockAngle`, `blockQuarter` | Room perimeter; `block` for solid walls, `blockHalf` for low cover |
| **WALL — decorative** | `wall`, `wallHalf`, `wallCorner`, `wallCornerHalf`, `wallCurve`, `wallCurveHalf`, `wallBattlement` | Interior dividers, room decorations; `wallCorner` at 90° junctions |
| **WINDOW** | `window`, `windowLeft`, `windowMiddle`, `windowRight` | Optional wall detail; combine `windowLeft + windowMiddle(×n) + windowRight` for wide windows |
| **DOOR — passage** | `doorClosed`, `doorOpen` | Room connections (locked/unlocked state); swap at runtime |
| **DOORWAY — frame** | `doorway`, `doorwayBottom`, `doorwayCenter`, `doorwayLeft`, `doorwayLeftBottom`, `doorwayMiddle`, `doorwayMiddleBottom`, `doorwayRight`, `doorwayRightBottom` | Multi-tile doorway arch; for wide passages between rooms |
| **COVER — tactical** | `crate`, `blockHalf`, `wallHalf` | Procedural cover placement; crates are the primary cover prop |
| **COLUMN / PILLAR** | `column`, `columnBlocks`, `columnCorner`, `pole`, `poleGroup` | Interior obstacle; `column` for interior pillars, `columnCorner` at wall/pillar junctions |
| **FENCE / BARRIER** | `fence` | Partial barrier; allows vision but blocks movement |
| **SLOPE / RAMP** | `slope`, `slopeHalf`, `slopeQuarter`, `slopeSmall`, `sloperCornerInner`, `sloperCornerOuter` | Elevation transitions; use for ramp-style level connections |
| **STAIRS** | `stairs`, `stairsCornerInner`, `stairsCornerOuter`, `stairsOpen`, `stairsOpenCornerInner`, `stairsOpenCornerOuter`, `steps` | Level exits / multi-floor transitions (future M6+) |
| **LADDER** | `ladder` | Vertical access point; alternative to stairs for tight spaces |
| **SLAB / PLATFORM** | `slab`, `slabHalf`, `slabAngle`, `slabQuarter` | Raised surface / platform; used for elevated objective tiles |
| **SWITCH — floor** | `switchFloorOff`, `switchFloorOn` | Pressure plate / trigger tile; toggles with on/off state |
| **SWITCH — wall** | `switchWallOff`, `switchWallOn` | Hackable wall panel; objective tile for "Sabotage" room quests |
| **ARROW — direction** | `arrow`, `arrowWall` | In-game direction markers; use for tutorial or entry/exit indicators |

#### Spritesheet (for TileSet atlas in Godot)
`blocks-prototype/Spritesheet/` — not available (pack uses individual PNGs only).  
→ Use Godot's **AtlasTexture** per individual PNG, or use a texture-packing tool to generate a spritesheet at import time.

---

### ★★★★ `bases-terrain/` — GROUND PLATFORMS

**Source:** Kenney Isometric Miniature Bases  
**Use in Godot:** `TileMap` layer below blocks (terrain base / ground level)  
**Key path:** `ASSETS/ISOMETRIC/bases-terrain/Isometric/<shape>_<material>_<variant>_<dir>.png`

**5 materials:** `dirt`, `grass`, `snow`, `stone`, `wood`  
**2 shapes:** `base` (circular/diamond), `square`  
**3 height variants:** `flat`, `float` (floating), `high`  
**2 detail variants:** plain and `_detail` (adds surface decoration)  
Total: **160 base tiles** (40 types × 4 directions)

#### Material → Chapter theme mapping

| Material | Chapter theme | Room type |
|---|---|---|
| `stone` | Embassy, Government HQ, Bunker | Interior rooms (default) |
| `wood` | Warehouse, Cargo ship, Safehouse | Storage rooms |
| `dirt` | Underground, Sewer, Tunnels | Connecting corridors |
| `grass` | Courtyard, Rooftop garden, Exterior | Outdoor sections |
| `snow` | Frozen rooftop, Cold-storage lab | Special chapter theme |

Use `square_*` for flat rectangular room floors. Use `base_*` for elevated/floating platforms.

---

### ★★★ `buildings/` — BUILDING FACADES

**Source:** Kenney Isometric Buildings  
**Use in Godot:** Background / dressing layer (not walkable), or set-dressing props  
**Key path:** `ASSETS/ISOMETRIC/buildings/PNG/buildingTiles_<NNN>.png`  
**Spritesheet:** `buildings/Spritesheet/buildingTiles_sheet.png` + `.xml`

Contains building exterior pieces (facades, roofs, windows, doors). Use as:
- Backdrop tiles for exterior/rooftop levels
- Non-interactive building props in outdoor sections
- Spritesheet preferred for Godot TileSet atlas

---

### ★★★ `city/` — URBAN ENVIRONMENT

**Source:** Kenney Isometric City  
**Use in Godot:** Environment dressing for outdoor/city sections  
**Key path:** `ASSETS/ISOMETRIC/city/PNG/cityTiles_<NNN>.png`  
**Detail tiles:** `city/Details/cityDetails_<NNN>.png` (furniture, props, small objects)

Contains streets, crossings, sidewalks, urban furniture, trees, traffic lights.  
Use for outdoor city-chapter corridor sections between buildings.

---

### ★★★ `landscape/` — NATURAL TERRAIN

**Source:** Kenney Isometric Landscape  
**Use in Godot:** Outdoor/exterior level dressing  
**Key path:** `ASSETS/ISOMETRIC/landscape/PNG/landscapeTiles_<NNN>.png`  
**Spritesheet:** `landscape/Spritesheet/`

Contains terrain tiles (hills, water, grass, trees, rocks, cliffs). Use for:
- Exterior courtyard sections
- Escape-through-forest levels
- Rooftop with landscape backdrop

---

### ★★ `roads/` — STREET CONNECTORS

**Source:** Kenney Isometric Roads  
**Key path:** `ASSETS/ISOMETRIC/roads/png/<tilename>.png`

Road tiles, bridges, intersections, trees. Use for connecting outdoor sections. Also includes beach/coastal tiles.

---

### ★★ `roads-water/` — WATER / COASTAL

**Source:** Kenney Isometric Roads Water  
**Key path:** `ASSETS/ISOMETRIC/roads-water/png/<tilename>.png`

Water-road hybrids. Use for flooded basement / dockyard chapter themes.

---

### ★★ `vehicles/` — PROPS / OBSTACLES

**Source:** Kenney Isometric Vehicles  
**Use in Godot:** Non-interactive props (impassable obstacles in outdoor rooms)  
**Key path:** `ASSETS/ISOMETRIC/vehicles/PNG/<Type>/<tilename>.png`

**Types:** Ambulance, Civilian, Garbage, Police, Taxi  
Each vehicle type has 8 directional variants. Use as large map props in city/rooftop/parking sections.

---

## ASSETS/CHARACTERS/ — Character Sprites

### `humans/` — Agent & Guard Sprites

**Source:** Kenney Isometric Miniature Prototype — Characters/Human  
**Use in Godot:** `AnimatedSprite2D` node per entity  
**Key path:** `ASSETS/CHARACTERS/humans/Human_<variant>_<anim><frame>.png`

**8 variants** (skin/outfit combinations):
- `Human_0` → base (beige/pink)
- `Human_1` through `Human_7` → alternate color variants

**Animations per variant:**
| Animation | Frames | Use |
|---|---|---|
| `Idle` | 1 frame (`_Idle0`) | Default standing state between turns |
| `Run` | 10 frames (`_Run0`–`_Run9`) | Movement animation (play during move action) |
| `Pickup` | 10 frames (`_Pickup0`–`_Pickup9`) | Interaction animation (hack, collect, interact) |

> ⚠️ **Direction note:** These sprites appear to be single-direction renders. In Godot, use `flip_h` for left/right mirroring and `rotation` for additional directional variants. Verify visually during M1 setup.

**Suggested assignments:**
| Character | Variant | Role |
|---|---|---|
| Agent (player) | `Human_0` | Use a distinct outfit color |
| Guard — basic | `Human_1`, `Human_2` | Generic guard |
| Guard — alert | `Human_3` | Use when guard is suspicious |
| Guard — elite | `Human_4`, `Human_5` | Higher-tier enemy |
| Hostage / ally | `Human_6`, `Human_7` | Friendly NPC |

---

## ASSETS/UI/ — Interface Elements

### `pixel-ui/` — Core HUD

**Source:** Kenney Pixel UI Pack  
**Use in Godot:** `Control` node layer — buttons, sliders, panels, bars  
**Key path:** `ASSETS/UI/pixel-ui/`

Contains 9-slice panel textures, buttons, checkboxes, sliders, progress bars.  
→ Primary source for the in-game HUD (AP bar, alert meter, context menu).

### `rpg-expansion/` — Icons & Inventory

**Source:** Kenney UI Pack RPG Expansion  
**Use in Godot:** Item slots, gadget wheel, skill icons

Contains RPG-style icons (weapons, potions, keys, scrolls, etc.).  
→ Gadget wheel, inventory slots, skill tree icons.

### `fantasy-borders/` — Dialog Panels

**Source:** Kenney Fantasy UI Borders  
**Use in Godot:** `NinePatchRect` for dialog boxes and tooltip panels

32 border styles + 32 panel styles + dividers.  
→ In-game dialog bubbles, mission briefing panels, reward screens.

### `medals/` — Reward Badges

**Source:** Kenney Medals Pack  
**Use in Godot:** Level completion screen

Gold/silver/bronze medal sprites.  
→ Star/medal rating on mission complete screen.

---

## ASSETS/FX/ — Visual Effects

### `smoke/` — Smoke Bomb Effect

**Source:** Kenney Smoke Particles  
**Use in Godot:** `GPUParticles2D` or `AnimatedSprite2D`  
**Key path:** `ASSETS/FX/smoke/PNG/`

Individual smoke puff sprites for animation.  
→ Smoke bomb gadget visual; guards blocked by smoke overlay.

---

## ASSETS/REFERENCE/ — Not for gameplay

| Folder | Contents | Use |
|---|---|---|
| `mcblocks/` | mcblocks2.5 tileset (Admurin) — colorful isometric style | Alternative visual style reference; use if switching to a more playful art direction |
| `blocks-prototype-angle/` | Orthographic angle renders of prototype blocks (side/front views) | Reference for creating custom sprite art; shows the 3D shape of each piece |
| `bases-terrain-angle/` | Orthographic angle renders of terrain bases | Same as above for terrain pieces |

---

## Procedural Room Generation — Asset Guide

The procedural dungeon builder (M3) assembles rooms from templates using the tiles above. Here is the recommended tile selection logic per room element:

### Room assembly checklist

```
[ ] Floor layer      → floor_NE / floor_NW / floor_SE / floor_SW (stone/wood/dirt per theme) tiled across room area
[ ] Perimeter walls  → block_NE/NW/SE/SW around edges; blockAngle at corners
[ ] Entry/exit       → doorClosed_<dir> at connection points (swap to doorOpen when unlocked)
[ ] Cover objects    → crate_<dir> at procedurally chosen interior tiles
[ ] Pillars          → column_<dir> at room corners / grid intersections
[ ] Barrier          → wallHalf_<dir> for partial LOS blockers (guard cover too)
[ ] Hackable panel   → switchWallOff_<dir> on a wall tile (objective tile)
[ ] Pressure plate   → switchFloorOff_<dir> on a floor tile (trap tile)
[ ] Ladder / stairs  → ladder_<dir> or stairs_<dir> at level exit tile
```

### Chapter themes — tile selection table

| Chapter | Floor | Wall/Block | Base terrain | Environment dressing |
|---|---|---|---|---|
| Embassy (Ch. 1) | `floor` (stone) | `block` + `wall` + `wallCorner` | `square_stone_flat` | `buildings/` facades |
| Lab (Ch. 2) | `floor` (stone) | `block` + `wallBattlement` | `square_stone_flat` | `city/Details/` props |
| Skyscraper (Ch. 3) | `floor` + `slab` | `block` + `window` segments | `square_stone_high` | `buildings/` + `vehicles/` |
| Warehouse (Ch. 4) | `floor` (wood) | `block` + `fence` | `square_wood_flat` | `vehicles/Garbage` props |
| Courtyard (outdoor) | `floor` (grass) | `fence` + `block` | `base_grass_flat` | `landscape/` + `roads/` |
| Rooftop (outdoor) | `floor` (stone) | `wallBattlement` | `square_stone_high` | `buildings/` skyline |
| Sewer / Tunnel | `floorHalf` (dirt) | `blockHalf` + `column` | `base_dirt_float` | `roads-water/` |
| Cold Storage | `floor` (snow) | `block` | `square_snow_flat` | `landscape/` snow |

### Cover placement rules (for fair procedural generation)

- Minimum 1 cover object per 8 floor tiles in a combat room
- Cover must never completely block the path from entrance to exit
- Crates near walls preferred; columns at grid intersections; fences across corridors
- No cover within 2 tiles of entry/exit door

### Detection / vision tile markers (runtime, not assets)

Use Godot shader overlays (no separate PNG needed) for:
- **1 AP range** — semi-transparent colored overlay on reachable tiles
- **2 AP range** — different color overlay
- **Danger zone** — enemy vision cone overlay (enemy facing × range)
- **Path preview** — highlighted tile chain on hover

---

## ARCHIVE/ — Reference / Future Use

Not used in the game directly. Keep for texture creation reference.

| Folder | Contents | Potential future use |
|---|---|---|
| `textures-flat/` | 50 seamless textures + normal maps; brick, dirt, terrain sets | Apply as surface textures if switching to shader-based isometric rendering |
| `sprites-2d/` | 2D sprite atlases (openpixels, LPC floors, Atlas2) | Inspiration for custom sprite art |
| `scifi-ui/` | 4 SciFi HUD interface designs (Blender + PNG) | UI visual direction reference for the game HUD |
| `top-down-lab/` | Top-down lab tileset (Aseprite source) | Lab chapter visual reference |
| `fonts/` | Pixel bitmap font (gnsh) — 9 color variants | In-game text if a custom pixel font is needed |
| `fx-lightning/` | Lightning/electric effect sprites | Laser grid / EMP visual effect |

---

## Quick reference — Godot import paths (M1)

When the Godot project is created in `godot/`, tile PNGs will be imported from:

```
res://../../ASSETS/ISOMETRIC/blocks-prototype/Isometric/floor_NE.png
```

Or, preferably, copy (or symlink) the relevant packs into the Godot project's `assets/` folder:

```
godot/assets/tilesets/blocks-prototype/   ← copy from ASSETS/ISOMETRIC/blocks-prototype/Isometric/
godot/assets/tilesets/bases-terrain/      ← copy from ASSETS/ISOMETRIC/bases-terrain/Isometric/
godot/assets/characters/humans/           ← copy from ASSETS/CHARACTERS/humans/
godot/assets/ui/                          ← copy from ASSETS/UI/
godot/assets/fx/                          ← copy from ASSETS/FX/
```

---

## Change log

| Date | Changes |
|---|---|
| 2026-05-19 | Initial asset map created. Full inventory of ASSETS/ and ARCHIVE/ after reorganization. Tile catalogue for blocks-prototype. Chapter theme mapping table. Cover placement rules. Godot import path guide. |
