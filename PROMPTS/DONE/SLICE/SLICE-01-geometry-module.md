# SLICE-01 — Geometry Module (Greenfield, Unwired)

> **Series:** SLICE — second prompt. Requires SLICE-00 accepted (Transform Canon in place,
> alignment selftest green).
> **Nature:** Purely ADDITIVE. This session creates the new geometry module and its selftest.
> Nothing existing is modified, wired, or deleted — integration and legacy removal are
> SLICE-02. If at any point an existing file needs editing to make this compile, STOP and
> report: that is a design error in this prompt, not something to work around.

---

## CONTEXT

Engine Geometry Architecture 1.0 (SLICE_MASTER_PLAN, approved): a wall is not a physical
object; it is a logical relationship between two independent Slices, one per adjacent
GAME UNIT. Canonical hierarchy: **GAME UNIT → FACE → SLICE → VOXEL**. The existing voxel
runtime (VOXEL-01..07) already places 2 slices per edge via `set_cell()`, but its identity
model still encodes "Wall owns two slices" (`slice_index` 0/1, both slices carrying the
origin cell as `gu_cell`, string edge keys). This prompt builds the definitive module from
scratch in a new folder, **porting** the validated knowledge (junction dual-key logic,
V-junction rules, dirty aggregation) rather than reinventing it.

Vocabulary and direction semantics: `docs/DIRECTION_GLOSSARY.md` (vertex-aligned compass:
N = top diamond vertex; NW/NE/SE/SW are edges). Geometry constants and the Transform Canon:
`VOXEL_MASTER_PLAN.md` §3 and §"Transform Canon".

---

## MODULE

New folder `godot/scripts/geometry/` — 8 new files — plus 1 new selftest in
`godot/scripts/tools/`. No other files.

---

## TASK

### T1 — `geometry_coords.gd` (`class_name GeometryCoords`)

Port from `subcube_coords.gd` (READ-ONLY reference) the voxel-plane constants and
conversions, with clean names. Contents:

```gdscript
const VOXELS_PER_UNIT_AXIS: int = 8
const VOXEL_TILE_SIZE      := Vector2i(32, 16)
const VOXEL_STEP_PX: float  = 20.0
const VOXEL_STOREY_HEIGHT_PX: float = 160.0
const VOXEL_ATOM_W: int = 32
const VOXEL_ATOM_H: int = 36    ## top face 16 + side face 20
const VOXEL_TILE_H: int = 16
## Derived texture anchoring (Transform Canon 3, sign as confirmed in SLICE-00):
static func voxel_texture_origin() -> Vector2i: ...

static func gu_to_voxel_origin(gu: Vector2i) -> Vector2i    ## 8 * gu — Canon 4
static func voxel_to_gu(v: Vector2i) -> Vector2i
static func voxel_local(v: Vector2i, gu: Vector2i) -> Vector2i
static func gu_voxels(gu: Vector2i) -> Array[Vector2i]
```

Copy the SLICE-00-confirmed sign into `voxel_texture_origin()`. Duplication with
`SubcubeCoordsClass` is intentional and temporary — the old class dies in SLICE-02.

### T2 — `face.gd` (`class_name Face`)

Face enum + helpers, single source for face semantics:

```gdscript
enum { NW, NE, SE, SW }
static func delta(face: int) -> Vector2i      ## NW=(-1,0) NE=(0,-1) SE=(1,0) SW=(0,1)
static func opposite(face: int) -> int        ## NW↔SE, NE↔SW
static func from_delta(d: Vector2i) -> int    ## -1 for invalid
static func to_string_name(face: int) -> String
```

Deltas per DIRECTION_GLOSSARY §3/§6 — copy exactly, do not re-derive.

### T3 — `edge.gd` (`class_name Edge`) — the logical wall

```gdscript
var id: String                 ## canonical, see below
var gu_a: Vector2i             ## anchor cell = lexicographically smaller (x, then y)
var gu_b: Vector2i             ## gu_a + Face.delta(face_a)
var face_a: int                ## face of gu_a toward the edge — always SE or SW
var face_b: int                ## Face.opposite(face_a) — always NW or NE
var storey_count: int
var material: String           ## "concrete" default
var slice_a_id: String
var slice_b_id: String
```

**Canonical identity:** anchor = the smaller cell, so `face_a ∈ {SE, SW}` always.
`id = "EDGE_%d_%d_%s" % [gu_a.x, gu_a.y, Face.to_string_name(face_a)]`.
Static constructor `Edge.between(cell_1, cell_2, storeys, material)` normalizes any input
order into canonical form; assert cells are 4-adjacent.

### T4 — `slice.gd` (`class_name Slice`) and `voxel.gd` (`class_name Voxel`)

Port `wall_slice.gd` / `voxel_ref.gd` with the identity reform:

`Slice`: `id` (`"SLICE_%d_%d_%s" % [gu.x, gu.y, face_name]`), `gu_cell` (**the GU that
actually contains this slice** — for the B-side this is gu_b, fixing the old model where
both slices carried the origin cell), `face: int`, `edge_id: String`, `storey_count`,
`material`, `voxels: Array`, `dirty_count: int`, `baked: bool`, `bake_texture` (null;
reserved for VOXEL-08), `integrity: float = 1.0` (reserved). Methods: `get_voxel(i)`,
`total_voxel_count()`, `mark_all_dirty()`. **No `slice_index`. No `direction` string.**

`Voxel`: port VoxelRef unchanged in behavior — `grid_pos`, `level`, `visible`, `dirty`,
`damage_state` (INTACT/CRACKED/DESTROYED), `face_atlas_rect`, parent-slice backref,
`set_visible()`, `set_damage()`, `clear_dirty()` with dirty_count propagation.

### T5 — `edge_registry.gd` (`class_name EdgeRegistry`)

The single source of truth linking the model:

```gdscript
register_edge(edge: Edge) -> void
register_slice(slice: Slice) -> void        ## also backfills edge.slice_a_id / slice_b_id
get_edge(id) / get_slice(id)
slices_of_edge(edge_id) -> Array            ## [slice_a, slice_b]
edge_of_slice(slice_id) -> Edge
sibling_slice(slice_id) -> Slice            ## the other side of the wall
edges_touching_gu(gu: Vector2i) -> Array
all_edges() / all_slices() / clear() / is_empty()
dirty_slices() -> Array                     ## dirty_count > 0 — TIC entry point
```

Port the signal emissions from `voxel_registry.gd` (`slice_registered`, plus
`edge_registered`). HighWall grouping does NOT live here — see T7.

### T6 — `edge_extractor.gd` (`class_name EdgeExtractor`) + `slice_generator.gd` (`class_name SliceGenerator`)

**EdgeExtractor** — the temporary adapter (Compiled Map → Edges), replacing
`subcube_geometry.gd`'s role until SLICE-03 makes the compiler emit edges natively:

```gdscript
static func extract(compiled: Dictionary) -> Dictionary
## returns { "edges": Array[Edge], "solid_blocks": Array[Dictionary] }
```

Port the logic of `maps/subcube_geometry.gd::build()`: iterate `wall_levels`, map
`wall_<SUFFIX>` tile names via Face.from suffix, skip `doorOpen_*`, pass `block_*` through
as solid_blocks (footprint now expressed in voxels: `VOXELS_PER_UNIT_AXIS`). Merge multiple
storeys of the same physical edge into ONE Edge with `storey_count = max + 1` (port the
max_storey merge from `_place_wall_voxels`'s edge_groups pass). Use `Edge.between()` so
the dual-key problem (same physical edge emitted from either adjacent GU) is normalized
away at the door — this replaces the old `_has_any` dual-key checks structurally.

**SliceGenerator** — Edges → Slices + Voxels + junction columns:

```gdscript
static func generate(edges: Array, registry: EdgeRegistry) -> void
static func slice_voxel_positions(gu: Vector2i, face: int) -> Array[Vector2i]
```

`slice_voxel_positions` is the clean rewrite of `_voxel_slice_positions`: given the OWNING
GU and its face, return the 8 voxel positions hugging that face inside that GU — derived
purely from `GeometryCoords.gu_to_voxel_origin(gu)` + face:

- NW: column `8·gu.x`, rows `8·gu.y .. +7`
- NE: row `8·gu.y`, cols `8·gu.x .. +7`
- SE: column `8·gu.x + 7`, rows `8·gu.y .. +7`
- SW: row `8·gu.y + 7`, cols `8·gu.x .. +7`

Note this is per-owner — no from/to, no slice_index branch. For each edge, generate slice A
(gu_a, face_a) and slice B (gu_b, face_b), each with `storey_count × 8` levels of voxels
(8 positions × levels), register both.

**Junction columns:** port the VOXEL-05 V-junction algorithm from room.gd
(`_build_voxel_junction_extras`) as `junction_resolver.gd` (`class_name JunctionResolver`):

```gdscript
static func resolve(registry: EdgeRegistry) -> Array   ## Array of JunctionColumn
```

Inner class or small file `JunctionColumn`: `gu_cell` (the corner GU that owns the column),
`voxel_pos: Vector2i`, `storey_count`, `voxels: Array`. Preserve the rules exactly:
vertex touched by edges → check 4 diagonal corners → corner uncovered iff both covering
edges absent → uncovered corner + ≥1 adjacent edge = place 1 column at max adjacent
storey height; nothing for T/X junctions. The dual-key membership checks become simple
`registry.get_edge()` lookups thanks to canonical Edge ids — port the *rules*, simplify
the *mechanism*. Keep the explanatory comments from the original; they encode a week of
debugging.

### T7 — `high_wall.gd` port (`class_name HighWallGroup`)

Port `world/high_wall.gd` into the module as the bake-grouping container (VOXEL-08 target):
`id`, `edge_ids: Array[String]`, `slice_ids: Array[String]`, `junction_columns: Array`,
`bake_texture`, `baked`, `dirty_count`, `voxel_bounds`. Grouping strategy for now:
**1 group per Edge** (its 2 slices + junction columns whose corner touches it) — the
maximal-run regrouping is a VOXEL-08 decision, leave a `## VOXEL-08:` note. Class renamed
to avoid collision with the live `HighWall` until SLICE-02 deletes it.

### T8 — `voxel_renderer.gd` (`class_name VoxelRenderer`, extends Node2D)

The module's only scene-tree citizen. Owns its TileMapLayers; room.gd will add ONE node
(SLICE-02). Port from room.gd's voxel functions, honoring the Transform Canon:

```gdscript
func setup(visual_grid_offset: Vector2) -> void      ## stores offset; builds tileset
func render(registry: EdgeRegistry, junction_columns: Array) -> void
func process_dirty(registry: EdgeRegistry) -> void   ## TIC: only dirty slices/voxels
func clear() -> void
```

- Tileset build: port `_build_voxel_tileset()` — 4 materials, DIAMOND_DOWN, 32×16,
  `texture_origin = GeometryCoords.voxel_texture_origin()` (derived, per canon).
- Layers: port `_ensure_voxel_layers()` — `position = offset − Vector2(0, VOXEL_STEP_PX·k)`
  (Equation E1), `z_index = wall_base_z + k` (wall_base_z as a setup parameter, default
  matching room.gd's `WALL_BASE_Z_INDEX`).
- `render()`: for each slice, `slice_voxel_positions` × levels → `set_cell()`; then
  junction columns; then hidden/damaged voxels per state (port the visibility handling
  from `_tic_voxel_system`).
- `process_dirty()`: port VOXEL-07 semantics — iterate `registry.dirty_slices()` only,
  update cells for dirty voxels, `clear_dirty()`, decrement aggregates. Zero work when
  nothing is dirty.

### T9 — `godot/scripts/tools/geometry_selftest.gd`

Headless selftest in the style of `voxel_selftest.gd`. Build a synthetic compiled dict
(no scene): a 3×3-GU room at offset (5,5) with a full wall ring, one `doorOpen_SE`, one
2-storey edge, and an L-corner. Then assert, at minimum:

1. **Extractor:** correct edge count; door produces no edge; canonical ids (`face_a` always
   SE/SW; `gu_a` lexicographically ≤ `gu_b`); the same physical edge fed from both adjacent
   cells yields ONE edge; storey merge takes the max.
2. **Generator:** exactly 2 slices per edge; `slice.gu_cell` is the true owner (B-side slice
   carries gu_b, not gu_a); faces are `Face.opposite` pairs; `edge.slice_a_id/slice_b_id`
   backfilled; voxel positions match the closed-form table of T6 for all four faces
   (compare against literal expected arrays for one GU per face).
3. **Registry:** `sibling_slice()` round-trips; `edges_touching_gu()` correct on a corner
   GU (2 edges) and a mid-wall GU; `dirty_slices()` empty on a fresh build.
4. **Junctions:** the L-corner produces exactly 1 junction column, at the analytic corner
   voxel position, with the max adjacent storey height; a T-junction case produces none.
5. **Dirty flow:** `voxel.set_visible(false)` → slice dirty_count 1 → appears in
   `dirty_slices()`; `clear_dirty()` → back to zero.
6. **Canon compliance:** `GeometryCoords.gu_to_voxel_origin(g) == 8·g` for a probe set;
   `voxel_texture_origin()` equals the SLICE-00 recorded value (read the constant from
   `SubcubeCoordsClass`/room constants for cross-check while both exist).

Target the same rigor as voxel_selftest (hundreds of checks); print per-group tallies and
exit non-zero on any failure.

---

## DO NOT TOUCH

- `room.gd`, `subcube_coords.gd`, `wall_slice.gd`, `voxel_ref.gd`, `high_wall.gd`,
  `voxel_registry.gd`, `maps/subcube_geometry.gd` — READ-ONLY references for porting.
  They keep running the game untouched until SLICE-02 swaps the seam.
- `room.tscn`, all overlays, all gameplay systems, `tileset_blocks.tres`.
- No renames, no deletions anywhere.
- Do not wire `VoxelRenderer` into any scene — instancing it in the selftest is allowed
  only if the selftest stays headless-clean; otherwise test it by API without add_child.

---

## ACCEPTANCE

- **A1:** `ls godot/scripts/geometry/` → exactly: `geometry_coords.gd`, `face.gd`,
  `edge.gd`, `slice.gd`, `voxel.gd`, `edge_registry.gd`, `edge_extractor.gd`,
  `slice_generator.gd`, `junction_resolver.gd`, `high_wall.gd` (HighWallGroup),
  `voxel_renderer.gd` (+ .uid files).
- **A2:** `grep -rn "class_name" godot/scripts/geometry/` → each declared once;
  `grep -rn "class_name Slice\b\|class_name Voxel\b\|class_name Edge\b" godot/scripts/`
  shows no duplicates outside the new folder.
- **A3:** `grep -rin "subcube" godot/scripts/geometry/` → ZERO matches. The new module is
  born clean.
- **A4:** `grep -rn "slice_index" godot/scripts/geometry/` → ZERO matches.
- **A5:** Headless run of `geometry_selftest.gd` exits 0; log shows all 6 check groups.
- **A6:** `slice_geometry_selftest.gd` (SLICE-00) still exits 0 — canon untouched.
- **A7:** Godot loads clean; PROBLEMS tab clear; smoke test shows the game rendering
  EXACTLY as before this session (the module is dormant).
- **A8:** `git status` → only additions under `godot/scripts/geometry/` and the new
  selftest (+ .uid files). Any modified existing file = abort and report.

Do not commit automatically.
