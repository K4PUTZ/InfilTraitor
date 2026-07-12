# INFILTRAITOR — Asset Map

> **Purpose:** Single reference for every asset available in the project — what it is, where it lives, how it maps to a game element, and how it is used in procedural dungeon generation.
> **Last updated:** 2026-06-21
> **Engine:** Godot 4 · TileMap isometric mode · 2:1 dimetric projection (45° horizontal, 26.57° elevation)
> **Master Assets System:** Introduced to standardize asset creation with correct dimensions, proportions, and offsets for reproducible game art.

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

## Master Assets System

The **Master Assets** folder (`ASSETS/ISOMETRIC/master_assets/`) is the **source of truth for fundamental game assets**. It contains flat-lit, direction-aware artwork with correct isometric proportions and standardized dimensions. These masters are:

1. **Authoritative source** — The single reference for all game art
2. **Organized by category** — `blocks/`, `walls/`, etc., enabling future environment theming
3. **Correct dimensions & proportions** — Exact pixel dimensions verified for the isometric 256×128 grid
4. **Texture-origin calibrated** — Precisely positioned for Godot's TileMap using calculated offsets

### Master Assets Organization

```
master_assets/
├── blocks/          ← Solid structural pieces (crates, pillars, columns)
│   └── crate.png    (direction-agnostic: feeds all 4 slots)
├── walls/           ← Wall faces, corners, and variations
│   ├── wall_NE.png     (directional: NE slot only)
│   ├── wall_NW.png     (directional: NW slot only)
│   ├── wall_SE.png     (directional: SE slot only)
│   ├── wall_SW.png     (directional: SW slot only)
│   ├── wallHalf_NE.png
│   ├── wallHalf_NW.png
│   ├── wallHalf_SE.png
│   ├── wallHalf_SW.png
│   ├── wallCorner_NE.png   (corner-specific geometry)
│   ├── wallCorner_NW.png
│   ├── wallCorner_SE.png
│   ├── wallCorner_SW.png
│   ├── wallCornerHalf_NE.png
│   ├── wallCornerHalf_NW.png
│   ├── wallCornerHalf_SE.png
│   └── wallCornerHalf_SW.png
└── [future categories]
```

### Master Asset Types

**Direction-agnostic masters** (e.g. `blocks/crate.png`):
- Symmetric objects that look identical from all 4 directions
- Single PNG that feeds all 4 directional slots in the TileSet
- Lookup: `tile_name = "crate"` → `masters["crate"]` → all 4 directions get this texture

**Directional masters** (e.g. `walls/wall_NW.png`):
- Geometry differs per direction due to perspective or edge-straddling
- Separate PNG per direction with direction suffix (`_NE`, `_NW`, `_SE`, `_SW`)
- Each PNG is positioned uniquely on its canvas to align with that direction's tile edge
- Lookup: `tile_name = "wall_NW"` → `masters["wall_NW"]` → only NW slot uses this texture

---

## Asset Generation System

The **Asset Generation** pipeline (`tools/asset_generation/`) generates master assets programmatically using Python. This ensures:

- **Reproducible geometry** — Same code = same proportions every time
- **Precise calibration** — Offsets and positions are calculated, not guessed
- **Future extensibility** — Add new asset types by creating new generator scripts

### How Asset Generation Works

1. **Generator script** (e.g. `generate_master_walls.py`) defines:
   - Canvas dimensions (`PNG_W × PNG_H`)
   - 3D face geometry (floor diamond vertices, wall heights, depth offsets)
   - Grid subdivisions (horizontal bands, vertical columns)
   - Color palette (flat fill, structural outline, grid lines)

2. **Face definitions** use **canonical isometric vertices**:
   - Floor diamond: `bN`, `bE`, `bS`, `bW` (bottom corners, on canvas at rows 384–512)
   - Top vertices: `tN`, `tE`, `tS`, `tW` (lifted by wall height)
   - These define the 3D slab shape in 2D projection

3. **Per-direction logic** accounts for **perspective visibility**:
   - NW/NE/SW/SE faces are visible from the camera angle
   - NW/SW: original edge faces away; camera-facing surface is the offset (back) face
   - NE/SE: original edge faces camera directly
   - Generator flips and repositions accordingly

4. **PNG generation** outputs 4 PNGs (one per direction) with correct:
   - Canvas size (256×512 for full walls, 256×512 for half-walls)
   - Face position relative to tile boundary
   - Grid lines (subdivisions for visual detail)
   - Silhouette (dark outline for clarity)

5. **Post-generation**: Run `build_tileset.gd` to:
   - Scan master assets
   - Apply `texture_origin` offsets (calculated calibration values)
   - Register tiles in TileSet
   - Generate `tile_registry.gd` (name→ID lookup)

### Running Asset Generators

```bash
# Generate all master wall PNGs
python3 tools/asset_generation/generate_master_walls.py

# Output: 8 PNGs written to master_assets/walls/
# wall_NE.png, wall_NW.png, wall_SE.png, wall_SW.png (full walls)
# wallHalf_NE.png, wallHalf_NW.png, wallHalf_SE.png, wallHalf_SW.png (half walls)
```

After generation, rebuild the TileSet in Godot:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script godot/scripts/tools/build_tileset.gd
```

This rebuilds `tileset_blocks.tres` and `tile_registry.gd` with the new assets.

---

## Wall Geometry — Technical Details

### Overview

Walls in INFILTRAITOR are **placed on tile edges**, not within tiles. Half the visual thickness straddles each adjacent tile, creating seamless wall networks. This design choice is enforced by:

1. **Generator script** — Positions faces to straddle boundaries
2. **Texture origin offsets** — Fine-tunes sprite positioning in Godot
3. **TileSet registration** — Applies calibrated offsets per direction

### Canvas & Diamond Layout

**Canvas:** 256 px wide × 512 px tall (all wall variants use this)  
**Floor diamond** occupies the **bottom portion**: rows 384–512  
**Wall face** occupies the **upper portion**: rows 0–384  
**Shift constant** (`SPRITE_OFFSET` in `build_tileset.gd`): `Vector2i(0, -384)`

The floor diamond sits in a 2:1 isometric diamond shape:

```
Canvas coordinates (y increases downward):
  y=0 ┌─────────────────────────────────┐
      │                                 │
      │         Wall face area          │
      │      (subdivided by grid)       │
      │                                 │
  y=384┌─────────────────────────────────┐
      │  Floor diamond:                 │
      │    tN = (128, 384) ← top        │
      │    tE = (256, 448) ← right      │
      │    tS = (128, 512) ← bottom     │
      │    tW = (0, 448)   ← left       │
      │                                 │
      │  Canvas boundary = y=512        │
  y=512└─────────────────────────────────┘
      x=0          x=128          x=256
```

### Wall Heights

**Full wall** (`wall_*`):
- Height: 160 px
- Top vertices lifted by 160 from floor: `tN = (128, 224)`, `tE = (256, 288)`, `tS = (128, 352)`, `tW = (0, 288)`
- Grid: 5 horizontal bands × 4 vertical columns (32 px each)

**Half wall** (`wallHalf_*`):
- Height: 80 px (exactly half)
- Top vertices lifted by 80: `tN = (128, 304)`, `tE = (256, 368)`, `tS = (128, 432)`, `tW = (0, 368)`
- Grid: 2 horizontal bands × 4 vertical columns

### 3D Face Geometry

Each wall tile is a 3D slab with **three visible faces** from the isometric camera:

1. **Front face** — Main vertical parallelogram on the tile edge
2. **Top face** — Thin parallelogram showing slab thickness from above
3. **End face** — Camera-visible end of the slab (narrow parallelogram)

#### Front Face Definitions (tL, tR, bR, bL)

The front face vertices are defined in order: top-left, top-right, bottom-right, bottom-left.

```
NW: (tN, tE, bE, bN)  ← upper-right, slope = +0.5  x∈[128,256]
    tN───────tE
    │        │
    │        │  Screen slope: top-right to bottom-left
    │        │
    bN───────bE

SW: (tW, tN, bN, bW)  ← upper-left, slope = −0.5   x∈[0,128]
    tW───────tN
    │        │
    │        │  Screen slope: top-left to bottom-right
    │        │
    bW───────bN

NE: (tS, tE, bE, bS)  ← lower-right, slope = −0.5  x∈[128,256]
    tS───────tE
    │        │
    │        │  Screen slope: top-left to bottom-right
    │        │
    bS───────bE

SE: (tW, tS, bS, bW)  ← lower-left, slope = +0.5   x∈[0,128]
    tW───────tS
    │        │
    │        │  Screen slope: top-right to bottom-left
    │        │
    bW───────bS
```

The front face fill is `COLOR_FLAT` (220, 132, 46) — **no baked directional light**, just a neutral base.

### Wall Depth & Thickness

Walls have **measurable 3D thickness** (verified from Kenney reference assets):

**Depth = 32 px screen-x** = 1/4 tile diamond step perpendicular to the wall face

Depth offsets (from front face center to back face):

```
NW: offset = (-32, +16)  ← perpendicular to NE edge, going NW into tile
SW: offset = (+32, +16)  ← perpendicular to NW edge, going SE into tile
NE: offset = (-32, -16)  ← perpendicular to SE edge, going NW into tile
SE: offset = (+32, -16)  ← perpendicular to SW edge, going NE into tile
```

### Top Face (Showing Depth)

The top face is a thin parallelogram connecting the front edge to the back edge, showing the slab's thickness from above:

```
tL─────────tR
│         │
│ (depth) │
│         │
tL_back───tR_back
```

- Front edge: `tL` to `tR` (the top of the front face)
- Back edge: `tL_back` to `tR_back` (offset by the depth vector)
- The parallelogram is filled with `COLOR_FLAT` and outlined with `COLOR_EDGE`
- Shows depth as a subtle 3D effect

### End Face (Camera-Visible Tip)

The end face is the **narrow parallelogram at the camera-visible corner** of the slab:

```
t_tip ─────── t_back
│             │
│             │
b_tip ─────── b_back
```

For **NW/SW** (original edge faces away):
- The camera-facing surface is the offset (back) face
- End face connects offset face back to the original edge
- Offset applied to end face vertices: `offset`
- Offset applied to top/back edges: `-offset` (negative)

For **NE/SE** (original edge faces camera):
- End face connects original edge to offset (back) face
- Offset applied to end face vertices: `offset`

The end face fill is `COLOR_FLAT` with `COLOR_EDGE` outline.

### Grid Subdivisions

All walls include grid lines for structural definition:

**Horizontal bands** (parallel to floor edge):
- Divide the front face into equal vertical sections
- Full wall: 5 bands
- Half wall: 2 bands
- Lines are drawn at `t = i / vcubes` interpolation between top and bottom

**Vertical columns** (perpendicular to floor edge):
- 4 columns (32 px each, spanning the 256 px width)
- Lines connect top edge to bottom edge
- Creates a 32×32 px grid (or similar proportions)

All grid lines are `COLOR_GRID` (120, 66, 22) — darker than fill, lighter than silhouette.

### Color Palette

```
COLOR_FLAT  = (220, 132, 46)   ← Primary fill (no directional light)
COLOR_EDGE  = (92, 50, 16)     ← Silhouette / structural outline
COLOR_GRID  = (120, 66, 22)    ← Subdivision lines
TRANSPARENT = (0, 0, 0, 0)     ← Canvas background (transparent PNG)
```

The palette is **intentionally flat** — no baked lighting direction. Future lighting variations (different environments) can overlay shaders or recolor at runtime.

### Silhouette Re-stroke

After drawing grid lines, all walls receive a **silhouette re-stroke** with `COLOR_EDGE`:

1. **Top edge** (width=2): Horizontal line from `tL` to `tR`
2. **Left silhouette** (width=2): Vertical line from `tL` to `bL`
3. **Right silhouette** (width=2): Vertical line from `tR` to `bR`

This ensures the wall outline is **always visible** even with grid lines in the way.

### Edge-Straddling: texture_origin Calibration

**Critical rule:** Master PNGs are **not centered** on the canvas. They are positioned to sit **on the tile boundary**. This is the **edge-straddling system**.

In `build_tileset.gd`, the `EDGE_VISUAL_OFFSETS` dict applies **calibrated nudges** (in pixels) to shift each sprite into the correct straddle position:

```gdscript
const EDGE_VISUAL_OFFSETS := {
    "NE": Vector2i(-16, -8),   ← NE wall face: shift left 16, up 8
    "NW": Vector2i(-16,  8),   ← NW wall face: shift left 16, down 8
    "SE": Vector2i( 16, -8),   ← SE wall face: shift right 16, up 8
    "SW": Vector2i( 16,  8),   ← SW wall face: shift right 16, down 8
}

const CORNER_VISUAL_OFFSETS := {
    "NE": Vector2i(-32, -8),   ← NE corner: distinct offset (spans full vertex)
    "NW": Vector2i(  0, 16),
    "SE": Vector2i(  0,-16),
    "SW": Vector2i( 32, -8),
}
```

These offsets are applied **after** `SPRITE_OFFSET`:

```gdscript
# For a wall tile:
texture_origin = SPRITE_OFFSET + EDGE_VISUAL_OFFSETS[direction]
              = Vector2i(0, -384) + Vector2i(±16, ±8)
              = Vector2i(±16, -376±8)

# For a corner tile:
texture_origin = SPRITE_OFFSET + CORNER_VISUAL_OFFSETS[direction]
```

**Why these specific values?**

- **±16 X**: 1/8 of a cell step (256 px cell = 32 px per voxel = 16 px half-step)
- **±8 Y**: 1/16 of a full-height wall (160 px / 20 = 8 px)
- **Direction logic**: NW/NE shift left (negative X); SE/SW shift right (positive X)
- **Vertical logic**: NW/SW shift down (positive Y — away from top); NE/SE shift up (negative Y)

These values **must match the PNG geometry** produced by the generator. If you modify the canvas position in the Python script, you **must recalibrate these offsets** to maintain visual alignment.

**Calibrated in commit 924dbf0** — Do not change without visual verification.

### Corner Walls (wallCorner / wallCornerHalf)

Corner sprites are **asymmetrically expanded** to fill the gap where two adjacent wall faces meet:

```
NW/SE corners: Canvas widened to 320 px (extra 64 px on the right)
    ← Normal wall: 256 px wide
    ← Corner: 256 + 64 = 320 px wide

NE/SW corners: Canvas heightened to 528 px (extra 16 px at the bottom)
    ← Normal wall: 512 px tall
    ← Corner: 512 + 16 = 528 px tall
```

The `texture_origin` offsets in `CORNER_VISUAL_OFFSETS` compensate for this asymmetric expansion so the corner visually meets both adjacent wall faces exactly:

```
NE (528 px tall):
   texture_origin = (0, -384) + (-32, -8) = (-32, -392)
   Shifts the sprite UP and LEFT to compensate for extra height below

NW (320 px wide):
   texture_origin = (0, -384) + (0, 16) = (0, -368)
   Shifts the sprite DOWN to compensate for extra width on the right
```

These are **per-corner-specific** values, not generic.

### How to Add New Wall Types

To add a new wall variant (e.g., `wallDestroyed`, `wallVine`):

1. **Create a generator script** (e.g., `generate_master_walls_destroyed.py`):
   - Copy `generate_master_walls.py` as a template
   - Modify `COLOR_FLAT` or grid style
   - Change `base_name` parameter in the `generate()` calls
   - Update `OUTPUT_DIR` to point to `master_assets/walls/` (same directory)

2. **Define the wall geometry**:
   - Keep the same canvas (256×512)
   - Keep the same vertex positions (`bN`, `bE`, `bS`, `bW`, `tN`, etc.)
   - Only change colors, grid lines, or surface texture

3. **Run the generator**:
   ```bash
   python3 tools/asset_generation/generate_master_walls_destroyed.py
   ```

4. **Rebuild TileSet**:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script godot/scripts/tools/build_tileset.gd
   ```

5. **Use in maps**: Add `"wallDestroyed"` to any map definition (it will automatically get 4 directional tiles).

**Important:** Do NOT manually edit PNG files after generation — always regenerate from Python. This ensures consistency and reproducibility.

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
| 2026-06-21 | **Master Assets System & Asset Generation documented.** Added comprehensive sections: Master Assets organization (blocks/, walls/, directional vs. direction-agnostic), Asset Generation pipeline (Python-driven with reproducible geometry), Wall Geometry technical details (canvas layout, 3D faces, depth/thickness, grid subdivisions, silhouette, texture_origin calibration, edge-straddling system), and How to Add New Wall Types. All offsets (EDGE_VISUAL_OFFSETS, CORNER_VISUAL_OFFSETS) documented with pixel values and rationale. |
| 2026-05-19 | Initial asset map created. Full inventory of ASSETS/ and ARCHIVE/ after reorganization. Tile catalogue for blocks-prototype. Chapter theme mapping table. Cover placement rules. Godot import path guide. |
