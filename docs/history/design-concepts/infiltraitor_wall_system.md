# Infiltraitor — Wall System Refactor: Technical Design Prompt

## Context

This is a 2D isometric stealth game built in **Godot 4** called **Infiltraitor**, currently in debug/early development. The game uses a tile-based isometric grid with a `TileMapLayer` node. The current wall system treats each wall tile as a fully impassable block occupying the entire tile, which wastes ~75% of the visual tile space and makes rooms feel smaller than they are.

The goal of this refactor is to implement a **thin, edge-based wall system** that:
- Keeps collision logic simple and tile-friendly
- Visually places walls on the border between two tiles rather than inside one
- Uses autotiling to select the correct wall sprite variant automatically
- Lays the foundation for a future lean/cover mechanic

---

## Current Architecture (Before)

- Each tile is either **walkable** or **impassable** (binary)
- Wall tiles are full-tile blocks, collision covers 100% of the tile
- Wall assets are centered on the tile
- Pathfinding uses a simple walkability array (`bool[][]`)
- No directional awareness of walls — a tile is blocked from all sides or none

---

## Target Architecture (After)

### 1. Tile Data Model — Edge Flags

Each tile will carry a bitmask or dictionary of **wall edges**, independent of walkability:

```gdscript
# Each tile stores which of its edges have a wall
# Edges: NORTH, SOUTH, EAST, WEST (relative to isometric grid axes)
var wall_edges: Dictionary = {}
# Example: { Vector2i(3, 2): ["N", "W"] }
```

A tile can be **walkable** AND have wall edges. The wall lives on the boundary between two tiles, not inside either one.

### 2. Collision — Edge-Based Movement Check

Movement between two adjacent tiles is blocked if:
- The **origin tile** has a wall on the edge facing the destination, OR
- The **destination tile** has a wall on the edge facing the origin

```gdscript
func can_move(from: Vector2i, to: Vector2i) -> bool:
    var direction = to - from
    var from_edge = direction_to_edge(direction)        # e.g. "N"
    var to_edge = opposite_edge(from_edge)              # e.g. "S"
    
    if wall_edges.get(from, []).has(from_edge): return false
    if wall_edges.get(to, []).has(to_edge): return false
    return true
```

This means the tile itself remains walkable — the wall only blocks the **transition** between tiles.

### 3. Visual Placement — Wall Assets on Tile Edges

DONE: Wall assets are already anchored to the **edge of the tile**, not the center:
In practice, this means wall `Sprite2D` nodes are visually offset from the tile's center.
We only have to flag the proper wall/corner/door, tile and the assets will lay on the right space.

### 4. Autotiling — Wall Sprite Variants

The system must detect neighboring wall edges and select the correct sprite automatically. Required sprite variants:

| Variant | Description |
|---|---|
| Straight N/S | Wall running east-west |
| Straight E/W | Wall running north-south |
| Corner (external) | Two walls meeting on the outside |
| Corner (internal) | Two walls meeting on the inside (concave) |
| T-junction | Three walls meeting |
| Cross | Four walls meeting |
| Terminal | End of a wall, one open side |
| Door frame | Wall with a gap (no collision on that edge) |

The autotile selection logic runs whenever a wall edge is placed or removed, checking all 4 neighbors and updating sprites accordingly.

```gdscript
func update_wall_sprite(tile: Vector2i):
    var edges = wall_edges.get(tile, [])
    var neighbors = get_neighboring_wall_edges(tile)
    var variant = resolve_autotile_variant(edges, neighbors)
    set_tile_sprite(tile, variant)
```

### 5. Pathfinding — A* with Edge Awareness

The existing A* pathfinder must be updated to use `can_move(from, to)` instead of checking `is_walkable(to)`:

```gdscript
func get_neighbors(tile: Vector2i) -> Array:
    var result = []
    for dir in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
        var neighbor = tile + dir
        if is_in_bounds(neighbor) and can_move(tile, neighbor):
            result.append(neighbor)
    return result
```

This is the only required change to the pathfinding layer — the rest of A* remains unchanged.

### 6. Door System

Doors are wall edges with a **togglable passability flag**:

```gdscript
var door_states: Dictionary = {}
# { Vector2i(3,2): { "edge": "N", "open": false } }

func can_move(from, to):
    # ... wall check ...
    # Additionally check doors
    var door = get_door_between(from, to)
    if door and not door.open: return false
    return true
```

Doors use the same edge system — no special tile type needed.

---

## Scope of Changes

### Files/systems to modify:
- `tile_map.gd` (or equivalent) — add `wall_edges` dictionary, `can_move()`, `update_wall_sprite()`
- `pathfinder.gd` — replace walkability check with edge-aware `can_move()`
- `level_editor.gd` (if exists) — wall placement tools now set edge flags, not tile types
- `TileSet` resource — add wall sprite variants as separate tiles/alternatives

### Files/systems to create:
- `wall_edge_data.gd` — data container and helper functions (direction_to_edge, opposite_edge, resolve_autotile_variant)
- `door_system.gd` — door state management

### What does NOT change:
- Floor tile system and walkability for open tiles
- Character movement input and animation
- Camera, rendering, Y-sort setup
- Any AI/enemy logic (they use the same pathfinder, which gets the update transparently)

---

## Future Extension — Lean/Cover Mechanic (Not in scope now, but design for it)

The edge wall system naturally enables a lean mechanic later:

- A tile adjacent to a wall edge can be flagged as a **cover tile**
- When a character occupies a cover tile and faces the wall, they enter a **lean state**
- In lean state, the character's sprite offset shifts toward the wall edge (~30% of tile)
- This is purely visual + a state machine addition — no new collision logic needed

Design the `wall_edges` data structure with this in mind: store enough directional information per tile that cover tile detection is a simple neighbor query.

---

## Implementation Order (Suggested)

1. Implement `wall_edge_data.gd` with all helper functions and unit-test them in isolation
2. Refactor tile data model to store edge flags (migrate existing wall tiles to equivalent edge flags)
3. Update `can_move()` and wire it into pathfinding
4. Implement autotile sprite selection (start with straight walls only, add corners iteratively)
5. Update level editor tools to place/remove edge walls
6. Add door system on top
7. Playtest room sizes and navigation feel — adjust wall thickness and collision margins

---

## Key Constraints

- **Target platform: Mobile** — keep runtime data structures small; avoid per-frame wall queries
- **Godot 4.x** — use `TileMapLayer`, not the deprecated `TileMap` node
- **GDScript** — no C# or GDExtension required for this system
- **No third-party plugins required** — all logic is custom, built on Godot's native tilemap and physics
- The `wall_edges` dictionary should be **serializable** for save/load and level editor export
