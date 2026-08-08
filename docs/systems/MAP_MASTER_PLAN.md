# INFILTRAITOR — Map System Master Plan

> **Canonical specification for the data-driven map pipeline, MapSpec contract, and compilation.**

The map system is completely data-driven. `room.gd` is a renderer that consumes a `layout` dictionary; it does not know how the map was produced. Permanent (hardcoded) maps and future procedural generators share the same vocabulary and compiler.

---

## Architecture Overview

```
room.gd  @export map_id ("PLAYGROUND" | "SIGMA_01" | "PROCEDURAL")
   │
   ├─ LevelGraph.generate(seed) ─► connections   (only for access_from_graph specs)
   │
   ├─ MapCatalog.get_spec(map_id, {connections, segment_grid_pos, seed})
   │        PLAYGROUND → PlaygroundMap.spec()
   │        SIGMA_01   → Sigma01Map.spec()
   │        PROCEDURAL → ProceduralMap.generate(seed)
   │              │  MapSpec (internal / segment coords)
   │
   ├─ MapCompiler.compile(spec, context)   ◄ SOLE OWNER of the buffer offset
   │        size = inner_size + 2×buffer
   │        per-cell offset in map_geometry.build_room()
   │        blocked buffer ring
   │        dividers+gates
   │        props + lights + patrols + exits
   │              │  layout dict (raw/grid coords)
   │
   └─ _build_room(layout)
      └─ _cache_blocked_cells(layout)         ◄ renderer (unchanged)
```

**Key principle:** `MapCompiler` is the **sole owner** of the buffer offset (`+ buffer`). This offset is applied in exactly **one place** and never duplicated in map definitions or overlays.

---

## MapSpec Contract

A MapSpec is a Dictionary containing the map data in **internal/playable coordinates** (the same coordinate space as `LevelGraph`, before buffer offset).

### MapSpec Keys

| Key | Type | Required | Notes |
|-----|------|----------|-------|
| `id` | String | ✅ | Unique map identifier |
| `inner_size` | Vector2i | ✅ | Playable area size (e.g., 18×36) |
| `buffer` | int | ✅ | Border size (e.g., 5) |
| `floor_tile` | String | ✅ | Base floor tile name (e.g., "floor_NE") |
| `agent_start` | Vector2i | ✅ | Agent starting cell (internal coords) |
| `wall_height` | int | ⏳ | Storeys of outer wall (default 1) |
| `access_points` | Array[Vector2i] | — | List of {cell, ...} dicts OR |
| `access_from_graph` | bool | — | `true` — pulls from LevelGraph |
| `rooms` | Array | — | `[{rect, doors}, ...]` inner rooms |
| `dividers` | Array | — | `[{cells: [Vector2i...]}, ...]` inner walls |
| `blocks` | Array | — | `[{gu, size, storeys, material}, ...]` solid GU blockers (also drives ROOF-BAKE) |
| `floor_zones` | Array | — | `[{gu, size, material}, ...]` author-declared floor-bake ground material rects (same shape as `blocks`; see BAKE_SYSTEM_REFERENCE.md FLOOR-ZONE-BAKE). D34: a structural material's floor bakes from the same `facade_<material>` as its walls/roofs. `"earth"` is not declarable — it is the "no zone here" sentinel, and a rect declaring it warns and is ignored |
| `props` | Array | — | `[{cell, tile}, ...]` crate_*, column_* |
| `lights` | Array | — | `[{x, y, height, radius, intensity}, ...]` map lights |
| `patrols` | Array[Array] | — | `[[Vector2i, ...], [...]]` guard routes |

### Example MapSpec

```gdscript
static func spec() -> Dictionary:
    return {
        "id": "PLAYGROUND",
        "inner_size": Vector2i(18, 36),
        "buffer": 5,
        "floor_tile": "floor_NE",
        "agent_start": Vector2i(9, 34),          # internal coord (no +buffer)
        "wall_height": 1,
        "access_from_graph": true,
        "props": [
            {"cell": Vector2i(10, 10), "tile": "crate_wood"},
        ],
        "lights": [
            {"x": 12, "y": 15, "height": 2, "radius": 5, "intensity": 1.0},
        ],
        "patrols": [
            [Vector2i(5, 5), Vector2i(10, 5), Vector2i(10, 10)],
        ],
    }
```

---

## Layout Dict Contract (Compiler Output)

The `layout` dictionary is produced by `MapCompiler.compile()` and consumed by `room._build_room()`. It uses **raw/grid coordinates** (with buffer offset already applied).

### Layout Keys

```
size: Vector2i                          # total grid size (inner + 2×buffer)
agent_start_cell: Vector2i              # agent spawn (raw coords)
floor_tile_name: String                 # base floor tile
wall_tiles: Array[String]               # unique wall tile names used
wall_levels: Array[Array]               # [0] = ground (doors), [1..N] = solid ring
max_floors: int                         # number of vertical storeys
structure_tiles: Array[Vector2i]        # props, columns, etc.
blocked_cells: Array[Vector2i]          # cells agent cannot enter
blocked_edges: Dictionary               # {edge_key: true} — agent cannot cross
enemy_defs: Array[Dictionary]           # guard spawn definitions
light_sources: Array[Dictionary]        # omni lights (rotated by perspective)
exit_cells: Array[Vector2i]             # map exit cells (rotated by perspective)
```

---

## Wall Storeys (N-Floor Stacking)

`MapSpec.wall_height` (storeys of the outer perimeter; default 1) controls wall rendering height.

**Compiler behavior:**
- Emits `wall_levels: Array[Array]`
  - `[0]` = ground course (with door gaps + dividers)
  - `[k≥1]` for k > 0 = solid perimeter ring (no door gaps, walls stack)

**Renderer behavior (`room._build_room`):**
- Level 0 rendered on `StructureWallLayer` (z=10)
- Each level `k≥1` rendered on dynamic `TileMapLayer` offset by `-WALL_FLOOR_STEP_PX` (=158px) at `z=10+k`
  - Result: top level occludes sprites below
  - Visual effect: solid wall above doors, preserving door height

**Inner dividers:** Do NOT stack vertically. Only perimeter walls stack.

**Override for testing:**
```gdscript
@export var wall_height_override: int = -1  # on Room node
```
If > 0, overrides `wall_height` from spec.

---

## Lights Come From the Map

Lights are never hardcoded. All lights come from `MapSpec.lights`:

**Pipeline:**
```
MapSpec.lights (map data)
    ↓
MapCompiler.compile()
    ↓
layout.light_sources (rotated by perspective)
    ↓
LightingController._setup_lights_from_layout()
    ↓
LightSource instances registered
```

**Rotation:**
On perspective change, `_layout_with_perspective()` rotates `light_sources` along with all other per-cell layers. `LightingController.rebuild_all()` re-derives shadows, exposure, and semantics from the rotated data.

---

## Perspective Rotation Coherence

`_layout_with_perspective()` rotates ALL per-cell data atomically:

```gdscript
_layout_with_perspective(perspective: int)  # 0=N, 1=E, 2=S, 3=W
  ├─ wall_levels
  ├─ structure_tiles
  ├─ blocked_cells / blocked_edges
  ├─ enemy_defs
  ├─ exit_cells
  └─ light_sources
```

Then `_set_perspective()` re-derives:
```gdscript
_set_perspective(perspective: int)
  ├─ redraws overlay numbers
  ├─ calls LightingController.rebuild_all()
  │   └─ lights / semantics / shadows / exposure follow rotation
  ├─ analysis overlays update via lighting_rebuilt signal
  └─ clears trail
```

**Principle:** On perspective rotation, re-derive every system per cell from rotated layout, exactly like `_ready`.

---

## Adding a Permanent Map

1. Create file: `godot/scenes/definitions/{name}_map.gd`
2. Implement `static func spec() -> Dictionary`:
   ```gdscript
   static func spec(context: Dictionary = {}) -> Dictionary:
       return {
           "id": "MY_MAP",
           "inner_size": Vector2i(18, 36),
           "buffer": 5,
           ...
       }
   ```
3. Add branch to `MapCatalog.get_spec()`:
   ```gdscript
   elif map_id == "MY_MAP":
       return MyMapName.spec(context)
   ```
4. Select map on Room node: `@export var map_id = "MY_MAP"`

---

## Coordinate Rules (Inviolable)

**Rule 7: Maps are authored in internal (playable) coordinates, never raw**

Every `MapSpec` uses the playable segment space (`inner_size`, e.g. 18×36, the same space as `LevelGraph`). The buffer offset is applied in **one single place**: `MapCompiler`.

```gdscript
## CORRECT in any *_map.gd:
"agent_start": Vector2i(9, 34)        # internal coord

## WRONG:
"agent_start": Vector2i(14, 39)       # (9+5, 34+5) — hardcoded buffer (+5)
```

This rule ensures:
- Maps remain self-contained and testable
- Buffer offset is changeable without rewriting maps
- Procedural generators use same coordinate space as hardcoded maps

---

## Outer Walls & Blocked Cells Contract

**Outer walls do NOT go into `blocked_cells`** — they block only via `blocked_edges`.

**Reason:** Interior is delimited by edges, not by central cell blockage. This behavior is inherited from SIGMA-01.

- `blocked_edges` — defines which edges agents cannot cross
- `blocked_cells` — defines which cells agents cannot enter (used for props, structures, interior walls)
- Outer wall perimeter: blocked via `blocked_edges` only, not `blocked_cells`

---

## Related Documentation

- **OPERATOR_CONTEXT** — Development handbook with architectural invariants
- **ARCHITECTURE.md** — High-level system relationships
- **docs/systems/rendering.md** — Visual rendering and map display
- **docs/systems/movement.md** — Grid navigation and A\* pathfinding on layout data
