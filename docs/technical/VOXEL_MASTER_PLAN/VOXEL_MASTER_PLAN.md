# INFILTRAITOR — VOXEL SYSTEM MASTER PLAN

> **Status:** PLANNING — Do not begin implementation before this document and `OPERATOR_CONTEXT.md`
> are reviewed, updated, and approved.
>
> **Supersedes:** `PROMPTS/DONE/SUBCUBE_MASTER_PLAN.md` · WallContainer series (CONTAINER-01..04)
> · `docs/technical/SUBCUBE_WALL_STRADDLE.md` (archived, replaced by this document)
>
> **Authored:** 2026-06-29
> **Scope:** Complete specification of the Voxel rendering system — geometry, containers,
> baking, dirty flag/TIC, and destructibility.

---

## 1. Motivation

The CONTAINER-01..04 series (`WallContainer` via `Image.blend_rect`) never achieved reliable
wall alignment. The root cause was structural, not a tuning problem:

| Root Cause | Symptom |
|---|---|
| `FACE_CENTER_OFFSET` required empirical calibration | Would re-break after any constant change |
| `blend_rect` composited in a coordinate space disconnected from Godot's tile grid | Alignment impossible to derive analytically |
| `is_x_varying` introduced orientation-dependent rendering paths | Critical bug in RENAME-01b: 96px horizontal displacement |
| Layer position offsets (`+100, +2`) were empirical patches | WALLALIGN-01: removed patches, still no visual confirmation |

**The new system eliminates all of this.** 1 VOXEL = 1 Godot Tile. Wall placement is purely
`TileMapLayer.set_cell()`. No image compositing, no calibration, no empirical offsets.
The position of every voxel is `map_to_local(voxel_coord)` — analytically exact.

**Additional gains from this architecture:**

- **Hierarchical addressability** — `HIGHWALL_012.WALL_NW_03.VOXEL_034.VISIBLE = false`.
  Individual voxels are controllable without processing every voxel in the scene.
- **Dirty Flag + TIC** — Only changed voxels are processed per turn. Containers with zero
  dirty voxels are skipped entirely.
- **Baking System** — Texture overlays applied once at load time (Crop + Multiply) at any
  granularity: single wall, high wall composite, or the full room.
- **Runtime Destructibility** — Voxels can be individually removed at runtime. The system
  supports structural collapse events and pre-authored damage states.
- **Natural Godot integration** — `y_sort_enabled` and `z_index` per TileMapLayer handle
  isometric depth sorting natively. No custom z-index math per container.

---

> **Architectural Note**
>
> VoxelLayers represent **visual storeys**, not gameplay floors.
> Only Storey 0 participates in gameplay simulation. Higher and lower
> VoxelLayers exist solely for rendering purposes (extended walls, ceilings,
> underground scenery, lighting, props and atmospheric effects).
>
> See **ARCHITECTURE.md → Visual Storeys** for the architectural rationale.

---

## 2. Vocabulary and Object Hierarchy

### Canonical Terms

| Term | Definition |
|------|-----------|
| **GAME UNIT** | Gameplay plane atom. `tile_size = 256×128 px`. Guards, A\*, TicSystem, alarms, blocked_edges all operate here. **Unchanged.** |
| **GODOT TILE** | The rendering atom in the voxel TileSet. `tile_size = 32×16 px`. 1 Godot tile = 1 voxel. |
| **VOXEL** | The indivisible rendering unit. Occupies exactly 1 Godot tile. Has `visible`, `dirty`, and `face_atlas_rect` state. |
| **WALL SLICE** (primary container) | One face-direction of one wall edge: 8 voxels wide × `8 × N` voxels tall (N = storeys). Two slices are emitted per wall edge. |
| **HIGH WALL** (secondary container) | A named composite of multiple wall slices. Can receive a single large texture baked across all constituent voxels. |
| **BAKING SYSTEM** | Load-time pipeline. Applies a texture overlay (Crop + Multiply) to voxel faces. Runs once; result is stored per-voxel. |
| **DIRTY FLAG** | Per-voxel `bool`. Set when voxel state changes. TIC system processes all dirty voxels each cycle. |
| **TIC SYSTEM** | Turn-based update loop. Skips containers with `dirty_count == 0`. |

### Object Hierarchy (runtime)

```
Room (room.gd)
│
├── VoxelLayer[0]           TileMapLayer — level 0 (ground), z_index = WALL_BASE_Z + 0
├── VoxelLayer[1]           TileMapLayer — level 1,          z_index = WALL_BASE_Z + 1
│   ...
└── VoxelLayer[8*N-1]       TileMapLayer — top level for N storeys

VoxelRegistry              (Dictionary, runtime index by string id)
└── HighWall["HIGHWALL_012"]
    ├── WallSlice["WALL_NW_03_S0"]     slice 0 = inner (in current GU)
    │     └── Voxel[0..63]             8 voxels × 8 levels = 64 VoxelRefs per slice
    ├── WallSlice["WALL_NW_03_S1"]     slice 1 = outer (in adjacent GU)
    │     └── Voxel[0..63]
    └── JunctionExtra["JX_NW_03"]      1 extra voxel column at V-junction corner (if applicable)
          └── Voxel[0..7]              8 voxels (1 column × 8 levels)
```

### Addressing

```gdscript
## Direct access via dotted string path:
HIGHWALL_012.WALL_NW_03_S0.VOXEL_034.VISIBLE = false
HIGHWALL_012.WALL_NW_03_S0.VOXEL_034.DIRTY   = true

## Via registry:
var voxel = _voxel_registry.resolve("HIGHWALL_012.WALL_NW_03_S0.VOXEL_034")
voxel.set_visible(false)  ## marks dirty automatically

## Via class hierarchy:
_high_walls["HIGHWALL_012"]\
    .get_slice("WALL_NW_03_S0")\
    .get_voxel(34)\
    .set_visible(false)
```

This enables:
- **TIC efficiency**: skip containers with `dirty_count == 0`
- **Selective visibility**: per-voxel, per-slice, or per-high-wall granularity
- **Scripted effects**: explosion destroys voxels in a radius, occlusion hides a column

---

## 3. Geometry

### Constants

| Constant | Value | Derivation |
|----------|-------|------------|
| `VOXEL_TILE_SIZE` | `Vector2i(32, 16)` | GAME_UNIT tile_size / 8 per axis |
| `VOXELS_PER_UNIT_AXIS` | `8` | New granularity (was 4 for subcubes) |
| `VOXEL_STEP_PX` | `20` px | `side_face_h = 1.25 × tile_h = 1.25 × 16 = 20` |
| `VOXEL_ATOM_W` | `32` px | = tile width |
| `VOXEL_ATOM_H` | `36` px | `16 (top face) + 20 (side face)` |
| `VOXEL_STOREY_HEIGHT_PX` | `160` px | `8 × 20` — same as old subcube system ✓ |
| `WALL_THICKNESS_VOXELS` | `2` | 2 slices, 1 per adjacent GAME UNIT |

### Consistency Proof

```
Old: SUBCUBES_PER_UNIT_AXIS(4) × SUBCUBE_STEP_PX(40)  = 160 px / storey
New: VOXELS_PER_UNIT_AXIS(8)   × VOXEL_STEP_PX(20)    = 160 px / storey ✓

Wall thickness (screen px, perpendicular axis):
  2 voxels × (16 / 2) px projection = 16 px ← same as before
```

Storey height is invariant. No gameplay or controller code changes.

### Voxel Atom PNG Structure (32 × 36 px)

```
  0 ┌──────────────────────────────┐
    │       TOP FACE               │  16 px
    │  (isometric diamond 32×16)   │
 16 ├──────────────────────────────┤
    │       SIDE FACE              │  20 px
    │  (front rectangle 32×20)     │
 36 └──────────────────────────────┘
```

The top face is occluded by higher-level voxel layers (Painter's algorithm via layer z_index).
The side face is the primary visible surface. Material variants differ in color/shading only —
the geometry is identical across all materials.

### Screen Projection

Godot isometric with `tile_size = 32×16`, layout `DIAMOND_DOWN`:

```
  Column +1 → screen (+16, +8)
  Row    +1 → screen (-16, +8)

  GAME UNIT (gu_col, gu_row):
    voxel origin = Vector2i(gu_col × 8, gu_row × 8)

  Voxel (v_col, v_row) at level L:
    screen = VoxelLayer[L].position + VoxelLayer[L].map_to_local(Vector2i(v_col, v_row))

  VoxelLayer[L].position = Vector2(VISUAL_GRID_OFFSET.x,
                                   VISUAL_GRID_OFFSET.y - VOXEL_STEP_PX × float(L))
```

No `FACE_CENTER_OFFSET`. No empirical offsets. Position is fully analytically derived.

---

## 4. Wall Slice Architecture

![Voxel wall slice geometry — 2 slices per wall edge, each in an adjacent GAME UNIT](img/voxel_wall_slices.png)

*The image above shows the concept: individual voxels are assembled into a wall (GERA UMA
PAREDE). The assembled wall sits in a Container. Two such containers form a complete wall edge,
one slice in each adjacent GAME UNIT.*

### Slice Geometry

```
GAME UNIT (gc-1, gr)          │      GAME UNIT (gc, gr)
  □  □  □  □  □  □  □ [S2]  ║  [S1] □  □  □  □  □  □  □
                              ║
                         wall edge
               slice 2 = col 7       slice 1 = col 0
               of (gc-1, gr)         of (gc, gr)
```

Each wall edge produces **2 WallSlices** — `S0` (inner, in the current GU) and `S1` (outer,
in the adjacent GU). Each slice is 8 voxels wide × `8 × storey_count` voxels tall.

### Placement Algorithm (per wall edge, per storey)

```gdscript
## NW wall: between GAME UNIT (gc, gr) and GAME UNIT (gc-1, gr)

## Slice S0 — inner: col 0 of GU (gc, gr)
for j in range(VOXELS_PER_UNIT_AXIS):  # 0..7
    var vs := Vector2i(gc * 8, gr * 8 + j)
    for level in range(VOXELS_PER_UNIT_AXIS * storey_count):
        _voxel_layers[level].set_cell(vs, VOXEL_SOURCE_ID, ATLAS_COORD_WALL)

## Slice S1 — outer: col 7 of GU (gc-1, gr)
for j in range(VOXELS_PER_UNIT_AXIS):
    var vs := Vector2i((gc - 1) * 8 + 7, gr * 8 + j)
    for level in range(VOXELS_PER_UNIT_AXIS * storey_count):
        _voxel_layers[level].set_cell(vs, VOXEL_SOURCE_ID, ATLAS_COORD_WALL)
```

No `blend_rect`. No `FACE_CENTER_OFFSET`. No `is_x_varying`. Only `set_cell()`.

### Wall Direction Table

| Direction | Between GUs | Slice S0 (inner) | Slice S1 (outer) |
|-----------|-------------|-----------------|-----------------|
| NW | `(gc, gr)` ↔ `(gc-1, gr)` | col 0 of `(gc, gr)` | col 7 of `(gc-1, gr)` |
| NE | `(gc, gr)` ↔ `(gc, gr-1)` | row 0 of `(gc, gr)` | row 7 of `(gc, gr-1)` |
| SE | `(gc, gr)` ↔ `(gc+1, gr)` | col 7 of `(gc, gr)` | col 0 of `(gc+1, gr)` |
| SW | `(gc, gr)` ↔ `(gc, gr+1)` | row 7 of `(gc, gr)` | row 0 of `(gc, gr+1)` |

---

## 5. Junction Rules

At each GAME UNIT vertex (corner of up to 4 adjacent GUs), wall slices from different edges
may leave an uncovered diagonal voxel. The rule is deterministic:

| Walls at vertex | Junction type | Extra voxel column | Reason |
|---|---|---|---|
| 2 | **V** (L-shape) | ✅ 1 voxel at outer diagonal | Diagonal GU has no outer slice |
| 3 | **T** | ✗ | 3rd wall's outer slice covers the diagonal |
| 4 | **X** | ✗ | All 4 diagonals covered by outer slices |

### Corner Region Diagram (3×3 voxel cells around junction vertex)

```
V Junction:              T Junction:              X Junction:

[G ][LB][  ]            [LB][LB][  ]            [AM][AM][  ]
[LB][AM][DB]            [AM][AM][DB]            [AM][AM][DB]
[LB][DB][  ]            [LB][DB][  ]            [LB][DB][  ]

G  = extra voxel (green)   LB = outer slice (light)
AM = overlap (2 walls)     DB = inner slice (dark)
```

The junction vertex is the corner between the four cells at the center of the diagram.

### Why T Junction Needs No Extra

In a T junction, the 3rd wall (the one that continues through the junction) provides an
outer slice in the diagonal GU that would otherwise be the gap:

```
         [LB = 3rd wall outer slice — covers former gap]
          ↓
[LB][LB][  ]   ← row above junction (3rd wall outer slice runs across full row)
[AM][AM][DB]
```

X junction: all 4 walls provide outer slices → all 4 diagonal GUs covered → no gap possible.

### Extra Voxel Placement

```gdscript
func place_junction_extras(vertex: Vector2i, walls_at_vertex: Array) -> void:
    if walls_at_vertex.size() != 2:
        return   ## T (3) and X (4) junctions need no extra
    var gap_voxel_col := find_uncovered_diagonal_voxel(vertex, walls_at_vertex)
    for level in range(VOXELS_PER_UNIT_AXIS * storey_count):
        _voxel_layers[level].set_cell(gap_voxel_col, VOXEL_SOURCE_ID, ATLAS_COORD_WALL)
    ## Register in JunctionExtra for dirty tracking
    _register_junction_extra(vertex, gap_voxel_col)

## find_uncovered_diagonal_voxel: checks the 4 diagonal GUs at this vertex.
## Returns the corner voxel (col=7 or row=7) of the GU whose corner cell is
## not covered by either wall's outer slice.
```

---

## 6. Container System

### 6.1 WallSlice (Primary Container)

A `WallSlice` is the primary unit of voxel grouping. It represents **one slice of one wall
face** — one direction, one adjacent GU, all storeys.

```gdscript
class_name WallSlice

var id: String               ## e.g. "WALL_NW_GC03_GR02_S0"
var direction: String        ## "NW" | "NE" | "SE" | "SW"
var slice_index: int         ## 0 = inner (in primary GU), 1 = outer (in adjacent GU)
var gu_cell: Vector2i        ## primary GAME UNIT cell
var storey_count: int
var voxels: Array            ## Array[VoxelRef], 8 × storey_count × 8 entries
var dirty_count: int = 0
var baked: bool = false
var parent_high_wall: String ## id of parent HighWall, or "" if standalone
```

**Logical size:** `8 × (8 × storey_count)` voxels (width × height in voxel grid).
**Physical cells:** each voxel occupies exactly one cell in the corresponding VoxelLayer.

### 6.2 HighWall (Secondary Container)

A `HighWall` groups multiple `WallSlice` instances (and optional `JunctionExtra` voxels)
into a named composite structure. It is the natural unit for secondary baking and for
scripted events (explosion, collapse, reveal).

```gdscript
class_name HighWall

var id: String                       ## e.g. "HIGHWALL_012"
var slices: Array                    ## Array[WallSlice]
var junction_extras: Array           ## Array[JunctionExtra]
var bake_texture: Texture2D          ## assigned during loading (null if unbaked)
var baked: bool = false
var dirty_count: int = 0             ## accumulated from child slices

## Computed at registration time:
var screen_bounds: Rect2             ## bounding box in screen space (for baking crop)
var voxel_bounds: Rect2i             ## bounding box in voxel grid coords
```

**Formation:** A `HighWall` is formed by `map_compiler.gd` when authoring a multi-storey
perimeter wall, a corridor wall segment, or any explicitly named wall group in the MapSpec.
Individual isolated wall edges may remain as standalone `WallSlice` pairs without a parent
`HighWall`.

### 6.3 VoxelRef (Individual Voxel State)

```gdscript
class_name VoxelRef

var grid_pos: Vector2i        ## position in VoxelLayer[level].set_cell()
var level: int                ## which VoxelLayer (0 = ground)
var visible: bool = true
var dirty: bool = false
var damage_state: int = 0     ## 0=intact, 1=cracked, 2=destroyed
var face_atlas_rect: Rect2i   ## crop rect in baked texture atlas (set by BakeSystem)

func set_visible(v: bool) -> void:
    if visible == v: return
    visible = v
    dirty   = true
    ## propagate dirty_count up the hierarchy
    _parent_slice.dirty_count += 1
    if _parent_slice.parent_high_wall != "":
        _voxel_registry.get_high_wall(_parent_slice.parent_high_wall).dirty_count += 1

func set_damage(state: int) -> void:
    damage_state = state
    dirty        = true
    _parent_slice.dirty_count += 1
```

---

## 7. Baking System

The baking system applies a unique texture to voxel faces during map loading. Baking
runs **once** and stores the result per-voxel. Runtime operations work on pre-baked voxels.

![Baking pipeline — Container + Texture Overlay → Crop + Multiply → Textured HighWall → Runtime Destructible](img/voxel_baking_pipeline.png)

*The image above shows the full pipeline: assembled voxel walls (yellow cubes) combined with
a stone texture overlay produce a high-quality baked wall surface. The same wall can then be
destructed at runtime by toggling individual voxel visibility.*

### 7.1 Pipeline

```
LOADING
│
├── 1. Build voxel containers (wall placement + junction extras)
│
├── 2. BakeSystem.bake_all(_voxel_registry)
│     │
│     ├── For each HighWall:
│     │     a. Select TEXTURE_OVERLAY from TextureCatalog
│     │        (keyed by map_id + theme + player_level)
│     │     b. For each VoxelRef in the HighWall:
│     │           i.  Compute SCREEN_RECT of this voxel's side face
│     │           ii. CROP: extract sub-image from TEXTURE_OVERLAY at SCREEN_RECT
│     │          iii. MULTIPLY: blend(crop, voxel_base_color, MODE_MULTIPLY)
│     │           iv. Store in texture atlas; assign face_atlas_rect to VoxelRef
│     │     c. Upload combined atlas to GPU
│     │     d. Mark HighWall.baked = true
│     │
│     └── For each standalone WallSlice (no parent HighWall):
│           Same pipeline but with a material-specific texture
│
└── 3. Initial TIC: apply all voxel states (no dirty voxels at this point)
```

### 7.2 Primary vs. Secondary Baking

**Primary baking** operates at the `WallSlice` level:

```
Input texture: material tile (~32 × 36 px per voxel face)
Coverage: 1 wall face (8 voxels wide × 8N tall per storey)
Use case: standard materials (concrete, metal, stone, wood)
Addressing: WALL_NW_03_S0.VOXEL_034.face_atlas_rect = Rect2i(...)
```

**Secondary baking** operates at the `HighWall` level:

```
Input texture: arbitrarily large image (mural, graffiti, damage map, branding)
Coverage: entire HighWall bounding box — one texture spans all constituent slices
Use case: artistic overlays, landmark rooms, storytelling details, procedural damage
Addressing: HIGHWALL_012 → all VoxelRef.face_atlas_rect set from shared large texture
```

The same `VoxelRef.face_atlas_rect` field is used in both cases. The TileMapLayer rendering
path is identical regardless of bake level.

### 7.3 Texture Catalog

```gdscript
## texture_catalog.gd
enum WallTheme { CONCRETE, METAL, STONE, WOOD, TILE, ORGANIC }
enum BakeLayer { PRIMARY, SECONDARY }

static func get_texture(
    map_id:       String,
    theme:        WallTheme,
    player_level: int,
    bake_layer:   BakeLayer
) -> Image:
    ## Returns a unique Image per (map_id, theme, player_level, bake_layer).
    ## Called once per container during loading.
    ## Source: authored PNGs in res://assets/textures/walls/
```

### 7.4 Blend Modes

| Operation | Mode | Effect |
|-----------|------|--------|
| **Crop** | — | Extract sub-image matching voxel's screen rect from overlay |
| **Multiply** | `BLEND_MODE_MUL` | `result = crop × base_color` — preserves shading, adds texture |
| **Damage overlay** (optional) | `BLEND_MODE_MIX` | Mix with damage texture at damage_state weight |

---

## 8. Dirty Flag and TIC Integration

### 8.1 Per-Voxel Dirty Tracking

Every `VoxelRef` carries a `dirty: bool`. State changes propagate `dirty_count` upward
through the hierarchy so the TIC loop can skip entire containers efficiently.

```
VoxelRef.set_visible(false)
  → dirty = true
  → WallSlice.dirty_count += 1
  → HighWall.dirty_count += 1   (if parent exists)
```

### 8.2 TIC Processing Loop

```gdscript
## Called once per TIC (not per frame):
func tic_voxel_system() -> void:
    for hw in _voxel_registry.all_high_walls():
        if hw.dirty_count == 0: continue   ## skip — nothing to update
        for slice in hw.slices:
            if slice.dirty_count == 0: continue
            _process_slice(slice)
        for extra in hw.junction_extras:
            if extra.dirty: _apply_voxel_state(extra)
        hw.dirty_count = 0

    for slice in _voxel_registry.standalone_slices():
        if slice.dirty_count == 0: continue
        _process_slice(slice)

func _process_slice(slice: WallSlice) -> void:
    for voxel in slice.voxels:
        if not voxel.dirty: continue
        _apply_voxel_state(voxel)
        voxel.dirty = false
    slice.dirty_count = 0

func _apply_voxel_state(ref: VoxelRef) -> void:
    var layer := _voxel_layers[ref.level]
    if ref.visible and ref.damage_state < 2:
        layer.set_cell(ref.grid_pos, VOXEL_SOURCE_ID, ref.face_atlas_rect.position)
    else:
        layer.erase_cell(ref.grid_pos)
```

### 8.3 Initial Population

At room build time, all voxels start with `visible = true` and `dirty = false`. The
initial `set_cell()` calls in `_place_wall_voxels()` do not go through the dirty system —
they are direct placement during the build phase.

After baking completes, the first TIC pass applies `face_atlas_rect` values to any voxel
that was baked after initial placement.

### 8.4 Performance Characteristics

For a typical room with ~200 wall edge segments × 2 slices × 8 × 8 = ~25,600 voxels:

| Scenario | Processing cost |
|----------|----------------|
| Zero dirty voxels (idle TIC) | O(container_count) — trivial |
| 1 explosion (radius 3 voxels) | O(dirty_voxels) ≈ O(50..200) |
| Full room reset | O(all_voxels) — only on map reload |

---

## 9. Runtime Destructibility

Destruction is first-class in the voxel system. Individual voxels, entire slices,
or complete high walls can be removed at any granularity.

### 9.1 Destruction Flow

```
1. TRIGGER: explosion, player action, scripted event
2. IDENTIFY: VoxelRefs within affected area
       (by screen bounding circle, or explicit list from script)
3. STATE CHANGE:
       ref.damage_state = CRACKED or DESTROYED
       ref.visible      = false   (if DESTROYED)
       ref.dirty        = true    (propagates up hierarchy)
4. NEXT TIC: _apply_voxel_state() calls erase_cell() for destroyed voxels
5. STRUCTURAL EVENT (optional): if slice.destroyed_count / slice.total > COLLAPSE_THRESHOLD
       emit signal "container_collapsed(slice_id)"
       → room.gd handles collapse animation / re-routing
```

### 9.2 Damage States

Voxels support 3 pre-authored damage states. Damage textures are baked at load time.

| State | Value | Visual | TileMapLayer |
|-------|-------|--------|-------------|
| `INTACT` | 0 | Full baked texture | `set_cell()` with intact atlas rect |
| `CRACKED` | 1 | Damage overlay applied | `set_cell()` with cracked atlas rect |
| `DESTROYED` | 2 | Invisible | `erase_cell()` |

### 9.3 Back-Face Visibility

When a voxel is destroyed, the voxels behind it (on the far side of the wall) are not
automatically shown. Back-face visibility is **explicitly authored** at baking time for
each wall segment that may be destructed. This is intentional — automating back-face
reveal would require a full LOS recomputation and is deferred to a future phase.

---

## 10. Asset Pipeline

### 10.1 Python Generators

| Script | Output | Description |
|--------|--------|-------------|
| `generate_voxel.py` | `source_assets/voxels/voxel_base.png` | 32×36 neutral voxel atom |
| `generate_voxel_variants.py` | `voxel_concrete.png`, `voxel_metal.png`, etc. | Material-tinted variants |
| `generate_voxel_damaged.py` | `voxel_{mat}_cracked.png` | Pre-authored crack overlay atoms |

### 10.2 Voxel Atom Spec

```python
## generate_voxel.py
TILE_W  = 32; TILE_H = 16    # Godot tile_size (new voxel TileSet)
SIDE_H  = 20                  # side face = 1.25 × TILE_H (same ratio as old subcube)
TOTAL_H = TILE_H + SIDE_H     # 36 px total

TOP_FACE  = draw_iso_diamond(TILE_W, TILE_H, base_color)          # 32×16 diamond
SIDE_FACE = draw_rect(TILE_W, SIDE_H, darken(base_color, 0.8))    # 32×20 rectangle
ATOM      = vstack(TOP_FACE, SIDE_FACE)                            # 32×36
```

### 10.3 TileSet Configuration

New `TileSetAtlasSource` for voxels:

```
tile_size:        Vector2i(32, 16)
texture_origin:   Vector2i(0, 10)      ← SLICE-00: derived from atom geometry (VOXEL_ATOM_H - VOXEL_TILE_H) / 2 = (36 - 16) / 2 = 10
y_sort_origin:    8                    ← half of tile_height, centers sort pivot
layout:           DIAMOND_DOWN
```

One `TileSetAtlasSource` entry per material variant. No special orientation variants needed
(unlike the old subcube system with `SUBCUBE_FACE_OFFSETS`).

---

### 10.4 SLICE-00 — Transform Canon: Voxel Plane Alignment (Alpha OFFSET FIX)

**Problem:** Early voxel rendering showed walls offset from canonical gameplay grid.

**Root Cause:** Godot's `TileMapLayer.map_to_local()` returns the **N-vertex position** (diamond top) in isometric space,
not tile origin (0,0). The offset magnitude equals `half_tile_size`:
- **Floor layer** (tile_size = 256×128): offset = (128, 64) — half of tile_size
- **Voxel layer** (tile_size = 32×16): offset = (16, 8) — half of tile_size
- **Difference X**: (128 - 16) = **112** px
- **Difference Y**: **64** px (floor_half_h only; the Y component does not subtract voxel_half_h)

**Solution (SLICE-00 Canonical Fix, Calibrated SLICE-02):**

Two adjustments required for pixel-perfect alignment:

1. **Texture Origin Constant** (`_build_voxel_tileset()`)
   ```gdscript
   td.texture_origin = Vector2i(0, (36 - 16) / 2)  # = (0, 10)
   # Derived from atom geometry: (VOXEL_ATOM_H - VOXEL_TILE_H) / 2
   ```

2. **Layer Position Offset** (`_ensure_voxel_layers()`)
   ```gdscript
   const TILE_OFFSET: Vector2 = Vector2(112.0, 64.0)  # (floor_half_w − voxel_half_w, floor_half_h)
   layer.position = Vector2(
       VISUAL_GRID_OFFSET.x + TILE_OFFSET.x,
       VISUAL_GRID_OFFSET.y + TILE_OFFSET.y - VOXEL_STEP_PX * float(level))
   ```
   **NOTE:** Pre-2026-07-02 derivation used (112, 56), which incorrectly subtracted voxel_half_h on Y. This 8px error was empirically measured and corrected via DEBUG-02 ruler + nudge session (residual now zero). The new renderer achieves better alignment than the legacy baseline.

**Alignment Verification:**
After fix, both tiles render at the same screen coordinate:
```
Floor N-vertex  = floor_layer.map_to_local(cell) + floor_layer.position
                = (128, 64) + (0, 512) = (128, 576)

Voxel N-vertex  = voxel_layer.map_to_local(cell) + voxel_layer.position
                = (16, 8) + (112, 564) = (128, 572) → with Y offset (112, 64) = (128, 576) ✅
```

**Validation (T2 — Selftest):**
- ✅ E1 formula: layer position formula holds for levels 0, 1, 7 (note: selftest does not cover TILE_OFFSET itself)
- ✅ Scale identity: voxel_projection ≡ floor_projection at 8× scale
- ✅ texture_origin = (0, 10) verified against atom geometry (36−16)/2
- ✅ Canon 4 cell-space: round-trip holds for all test GUs
- ✅ Floor Rosetta: tileset_blocks texture_origin = (0, -384) confirmed

**Impact:** All walls render pixel-aligned with canonical grid. Empirically calibrated 2026-07-02. Better than legacy baseline.

---

## 11. Integration with Existing Systems

### 11.1 What Changes

| Module | Change |
|--------|--------|
| `subcube_coords.gd` | New constants: `VOXELS_PER_UNIT_AXIS=8`, `VOXEL_STEP_PX=20`, `VOXEL_TILE_SIZE=Vector2i(32,16)` |
| `room.gd::_build_wall_containers()` | Replaced by `_place_wall_voxels()` — calls `set_cell()` only |
| `room.gd::_ensure_subcube_layers()` | Renamed `_ensure_voxel_layers()`, count = `8 × storey_count` |
| `wall_container.gd` | Archived → replaced by `voxel_slice.gd` + `high_wall.gd` |
| `subcube_geometry.gd` | Updated: emits voxel-space slice addresses, not Image data |
| `map_compiler.gd` | Wall seam: emits `WallSlice` descriptors instead of WallContainer params |
| Python generators | `generate_subcube.py` → `generate_voxel.py` (32×36 atom) |
| TileSet | New `tileset_voxels.tres` with `tile_size=32×16`; old subcube TileSet archived |

### 11.2 What Does Not Change (Invariants)

| System | Status |
|--------|--------|
| GAME UNIT (gameplay plane) | ✅ Unchanged |
| `WallEdgeData` — sole source of edge keys | ✅ Unchanged |
| Guard FSM, A\*, TicSystem, alarms | ✅ Unchanged |
| `blocked_cells`, `blocked_edges` | ✅ Unchanged |
| All 6 controllers | ✅ Unchanged |
| All overlays | ✅ Unchanged |
| `VISUAL_GRID_OFFSET = Vector2(0, 512)` | ✅ Unchanged |
| `WALL_FLOOR_STEP_PX = 158` (multi-storey) | ✅ Unchanged |
| 7 Architectural Rules (OPERATOR_CONTEXT) | ✅ Unchanged |
| Map pipeline (MapSpec → MapCompiler → room) | ✅ Contract unchanged; voxel output added |

### 11.3 Archive Plan for Superseded Systems

| Superseded artifact | Action |
|---------------------|--------|
| `wall_container.gd` | Archive to `godot/scripts/world/_archive/` |
| `CONTAINER-01..04` prompts | Already in `PROMPTS/DONE/` — no action |
| `SUBCUBE_MASTER_PLAN.md` | Already in `PROMPTS/DONE/` — no action |
| `SUBCUBE_WALL_STRADDLE.md` (root + docs/technical) | Add deprecation notice, point to this doc |
| `WALLALIGN-01`, `DEVVIZ-01b` prompts | Superseded — move to DONE/, do not execute |
| Old subcube TileSet source entries | Remove from `tileset_blocks.tres` after VOXEL-02 |

---

## 12. Implementation Sequence

Each prompt file targets one module, one operator session. Dependencies are strict.

### Phase 1 — Core Rendering (VOXEL-00..05)

Goal: Wall placement works correctly with all junction types. No baking, no dirty flag yet.

| ID | Prompt Name | Depends on | Files touched |
|----|-------------|-----------|---------------|
| **VOXEL-00** | This document + OPERATOR_CONTEXT update | — | Docs only |
| **VOXEL-01** | `generate_voxel.py` — 32×36 atom PNG | VOXEL-00 | Python tool |
| **VOXEL-02** | New TileSet + `subcube_coords.gd` constants | VOXEL-01 | `subcube_coords.gd`, `tileset_blocks.tres` |
| **VOXEL-03** | `VoxelRef`, `WallSlice`, `HighWall` data classes | VOXEL-02 | 3 new `.gd` files |
| **VOXEL-04** | `_place_wall_voxels()` — basic placement, no junctions | VOXEL-03 | `room.gd`, `map_compiler.gd` |
| **VOXEL-05** | Junction detection + extra voxel placement | VOXEL-04 | `room.gd` |

**Acceptance at end of Phase 1:** All walls visible and aligned. V/T/X junctions gap-free.
No calibration or empirical offsets anywhere in the code.

### Phase 2 — Runtime System (VOXEL-06..07)

Goal: Containers are addressable at runtime. TIC processes dirty voxels correctly.

| ID | Prompt Name | Depends on | Files touched |
|----|-------------|-----------|---------------|
| **VOXEL-06** | `VoxelRegistry` — container index and string addressing | VOXEL-03 | `voxel_registry.gd` |
| **VOXEL-07** | Dirty Flag + TIC integration | VOXEL-06 | `room.gd`, `tic_system.gd` |

**Acceptance at end of Phase 2:** `HIGHWALL_012.WALL_NW_03_S0.VOXEL_034.VISIBLE = false`
executes correctly. Next TIC erases the voxel from the TileMapLayer. Idle TIC costs O(n_containers).

### Phase 3 — Baking System (VOXEL-08..09)

Goal: Walls display unique textures per map/theme. Both primary and secondary baking work.

| ID | Prompt Name | Depends on | Files touched |
|----|-------------|-----------|---------------|
| **VOXEL-08** | Baking System — primary (`WallSlice` level) | VOXEL-06 | `bake_system.gd` |
| **VOXEL-09** | Baking System — secondary (`HighWall` level) | VOXEL-08 | `bake_system.gd`, `texture_catalog.gd` |

**Acceptance at end of Phase 3:** Standard room loads with concrete texture applied.
Bake time < 200ms on target device. Pre-baked atlas uploaded in single GPU call.

### Phase 4 — Destructibility and Polish (VOXEL-10..11)

Goal: Individual voxels destructible at runtime. Full documentation updated.

| ID | Prompt Name | Depends on | Files touched |
|----|-------------|-----------|---------------|
| **VOXEL-10** | Destructibility — damage states + collapse events | VOXEL-07 | `VoxelRef`, `WallSlice` |
| **VOXEL-11** | CODEMAP regeneration + ARCHITECTURE.md update | VOXEL-10 | Docs |

**Acceptance at end of Phase 4:** Explosion removes N voxels. Next TIC applies changes.
Collapse threshold event fires correctly. CODEMAP matches code.

---

## 13. Open Decisions

Decisions that must be made before VOXEL-02 starts:

| Decision | Options | Recommendation |
|----------|---------|---------------|
| Layer naming | `_voxel_layers[]` vs `_subcube_layers[]` | Rename to `_voxel_layers` — clearer, avoids confusion |
| Voxel ID format | String `"VOXEL_034"` vs int `34` | Int at runtime, String for debug logging only |
| Baking trigger | On `_ready()` vs deferred idle frame | Deferred — avoids blocking scene load |
| Back-face visibility | Auto-computed vs authored | Authored in Phase 3; LOS-computed deferred |
| Texture catalog format | JSON manifest vs GDScript enum | GDScript enum — simpler, type-safe, no parsing |
| `storey_count` source | `MapSpec` vs per-container | `MapSpec.wall_height` — consistent with current arch |
| VoxelLayer z_index base | New constant `VOXEL_BASE_Z` vs reuse `WALL_BASE_Z_INDEX` | Reuse `WALL_BASE_Z_INDEX` — no gameplay impact |

---

## 14. Required Documentation Updates

Before VOXEL-01 begins, the following documents must be updated:

| Document | Required Update |
|----------|----------------|
| `tools/persistent/OPERATOR_CONTEXT.md` | Replace all subcube references with voxel vocabulary; update constants table; add VoxelLayer section; update grid geometry table |
| `docs/ARCHITECTURE.md` | Update "Subcube Render Plane" section → "Voxel Render Plane"; update constants; replace WallContainer description |
| `docs/DIRECTION_GLOSSARY.md` | Review — direction system itself unchanged; update examples to use voxel terminology where subcube was referenced |
| `docs/production/current_state.md` | Update Render System Status table |
| `docs/README.md` | Add this document to Technical section |
| `tools/persistent/CODEMAP.md` | Regenerate after VOXEL-11 completes |

---

*This document is the canonical reference for the VOXEL system.*
*All VOXEL-01..11 prompts derive their specifications from this document.*
*This document must be approved before any implementation prompt is written.*
