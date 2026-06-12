# INFILTRAITOR — Movement & Turn System

> **Grid navigation, turn structure, and action point economy.**

---

## Overview

INFILTRAITOR uses a **discrete turn-based** system with an **action point (AP) economy**. Each player turn, the agent receives **2 AP** to allocate freely among movement, gadgets, skills, and interactions. After the player ends their turn, all enemies execute **simultaneously** in sequence.

---

## Turn Structure

### Player Phase
1. Player observes the board and gathers information
2. Player selects actions from their 2 AP budget:
   - **Move** → 1 AP per move
   - **Use Gadget/Skill** → 1–2 AP (ability-dependent)
   - **Interact** → 1 AP (unlock, pick up, hack, etc.)
   - **Wait/Overwatch** → End turn early with a reactive stance
3. Player confirms "End Turn"

### Enemy Phase
1. All guards execute their turns sequentially (deterministically)
2. Each guard's behavior is driven by their current state (PATROL/SUSPICIOUS/ALERT/CHASE/SEARCH)
3. Alarms may escalate during this phase
4. Communications (whistles, radios) propagate instantly
5. Noise persists from previous turns and decays at phase end

### Loop
Player Phase → Enemy Phase → Loop

---

## Grid System

### Coordinate System
- **Isometric 2.5D** grid using **Vector2i** coordinates
- **4-directional movement** (up, down, left, right; no diagonals initially)
- **Square tiles** visually rendered in isometric perspective

### Tile-Based Navigation
```gdscript
# Movement to adjacent tile
agent.move_to_cell(Vector2i(x+1, y))

# Valid moves are bounded by room size
const ROOM_SIZE: Vector2i = Vector2i(36, 36)  # max coordinates

# Pathfinding via Dijkstra
var path: Array[Vector2i] = pathfinder.find_path(start, goal, blocked_cells)
```

### Special Tile Types

| Tile Type | Effect | Cost |
|-----------|--------|------|
| **Standard floor** | Normal movement | 1 tile/move |
| **Rough terrain** | Muddy, debris | 1.5 tiles/move (slower) |
| **Water current** | Flowing water | Free push 1 tile after turn |
| **Tall grass/shadow** | Reduces enemy vision (0.30× direct shadow, 0.55× penumbra) | Normal |
| **Wall/obstacle** | Impassable | Cannot enter |

---

## Action Point Economy

### 2 AP Per Turn
Each player turn, agent receives 2 AP. AP may be spent on:

| Action | AP Cost | Notes |
|--------|---------|-------|
| **Move to adjacent tile** | 1 AP | Pathfinding preview shows cost |
| **Gadget (standard)** | 1 AP | Most gadgets (smoke, EMP, etc.) |
| **Gadget (powerful)** | 2 AP | Rare, high-impact abilities |
| **Skill (standard)** | 1 AP | Combat moves, utility |
| **Skill (powerful)** | 2 AP | Ultimate abilities (unlocked late-game) |
| **Interact** | 1 AP | Unlock, hack, pick up, push button |
| **Wait (Overwatch)** | 0 AP | End turn early; enter reactive stance during enemy phase |

### Remaining AP
- Unspent AP is lost at end of turn (no carryover)
- **Exception:** Overwatch — Wait action ends turn but reserves remaining AP for reactions
- Via Overwatch, player can set a pre-selected reaction (dodge, use gadget, etc.)

---

## Pathfinding & Movement Visualization

### Movement Overlay (Dijkstra)
When the agent is selected (or turn begins), a **Dijkstra pathfinding layer** shows all reachable tiles:

- **1 AP zone** (blue outline) — tiles reachable with 1 move
- **2 AP zone** (orange outline) — tiles reachable with full movement (2 AP)
- **Path preview** — when hovering a tile, a highlight shows the exact path

### Cost Calculation
```gdscript
# Cost in tiles for a given destination
func get_movement_cost_in_ap(from: Vector2i, to: Vector2i) -> int:
    var path = find_path(from, to)
    var tile_count = path.size() - 1  # exclude start
    
    # Base: 1 tile per AP
    var ap_cost = ceil(float(tile_count) / 1.0)
    
    # Terrain modifiers:
    for tile in path:
        if is_rough_terrain(tile):
            ap_cost += 0.5  # rough terrain costs 1.5× normal
    
    return ceil(float(ap_cost))
```

### Blocked Cells
Certain cells are impassable:
- Walls and obstacles
- Enemy positions (guards block movement)
- Hazards (traps, if activated)
- Locked doors (until interacted)

---

## Movement Animation

### Smooth Tiles Movement
- Agent moves smoothly across tiles (tweened over ~0.3s)
- Animation begins immediately on player confirmation
- Camera **follows** agent during movement (pan to keep agent centered)

### Guard Movement
- Guards also move smoothly (state-dependent speed)
  - PATROL: 0.60× normal speed
  - SUSPICIOUS: 1.0× normal speed
  - ALERT: 1.5× normal speed
  - CHASE: 2.0×–3.0× normal speed
- Guards may pause spontaneously (~20% chance per step) for 1–2 turns

---

## Overwatch System (Advanced)

### Setting Overwatch
If the player ends their turn with **unspent AP** via the **Wait action**:
1. Player selects "Wait" action (0 AP cost)
2. Turn ends immediately
3. Remaining AP is reserved for reactions
4. Player can set a **pre-selected reaction**:
   - **Dodge** — agent moves to adjacent cover
   - **Use Gadget** — triggers a gadget (if within AP budget)
   - **Use Skill** — triggers a skill (if within AP budget)
   - **Shoot** — opens fire (if enemy moves into LOS)

### Reaction Trigger
During enemy phase, if a threat enters the agent's vision and **meets the reaction criteria**:
- The reaction fires automatically
- Remaining AP is consumed
- Agent returns to normal state

**Example:** Player ends turn with 1 AP remaining and sets Overwatch → "Use Smoke Bomb if guard moves adjacent". If a guard enters detection range and approaches, the smoke bomb triggers automatically.

---

## Turn Counter & Session Length

### Turns Per Level
- **Early levels** — 8–15 turns typical (1–3 minutes of gameplay)
- **Mid levels** — 12–20 turns typical
- **Late levels** — 15–25 turns typical (plus resets on failed stealth)

### Session Structure
- Each level is **one session** (save/load happens between levels)
- Failed stealth (detected + eliminated) = level restart
- Successful extraction (reach exit) = level complete

### Failure State
If the agent is fully detected and eliminated:
- Level restarts from beginning
- No mid-level saving
- Encourages careful planning over trial-and-error

---

## Move Order & Determinism

### Guard Turn Order
Guards execute **sequentially** and **deterministically**:
1. Guard 1 takes action → updates state
2. Guard 2 observes the world (including Guard 1's new position) → takes action
3. Guard 3 observes → takes action
4. ... and so on

**Determinism:** Same initial state = same guard actions (no randomness in *execution*, only in *perception*).

### Communication & Alerts
During the enemy phase:
1. If Guard 1 detects the agent and enters ALERT, it may **whistle** (3-tile radius)
2. Nearby guards (Guard 2, 3) hear the whistle and escalate immediately
3. Alerts propagate via **radio** (global, only for CHASE state)
4. All guards see the escalated alert state and adjust their decisions

---

## AP Costs Reference

| Action | Cost | Availability | Notes |
|--------|------|--------------|-------|
| Move (1 tile) | 1 AP | Always | Standard movement |
| Move (2 tiles) | 2 AP | Always | Full turn on movement |
| Smoke Bomb | 1 AP | 3 charges | Break LoS, disable alarms |
| EMP Device | 2 AP | 1 charge | Disable cameras, alarms |
| Silent Takedown | 1 AP | Always (adjacent) | Requires positioning, undetected |
| Hack Terminal | 1 AP | Variable | Depends on terminal |
| Pick Up Item | 1 AP | Variable | Collect intel, supplies |
| Interact (door, etc.) | 1 AP | Variable | Context-dependent |
| Wait (Overwatch) | 0 AP | Always | End turn, reserve AP for reactions |

---

## Performance Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Movement animation smooth | 60 FPS | ✅ |
| Pathfinding latency | <50 ms | ✅ |
| Turn resolution <200 ms | True | ✅ |
| AP UI responsive | Instant | ✅ |

---

## Advanced Topics

### Tile Offset Calculation
```gdscript
# Visual grid offset (isometric projection)
const VISUAL_GRID_OFFSET: Vector2 = Vector2(0.0, 512.0)

# Convert grid coordinate to world position
func grid_to_world(cell: Vector2i) -> Vector2:
    var iso_pos = floor_layer.map_to_local(cell)
    return iso_pos + VISUAL_GRID_OFFSET
```

### Pathfinding with Obstacles
```gdscript
# Dijkstra pathfinder accounting for blocks
func find_path(start: Vector2i, goal: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
    var open_set = [start]
    var came_from = {}
    var g_score = {start: 0}
    var f_score = {start: heuristic(start, goal)}
    
    while open_set.size() > 0:
        var current = find_lowest_f(open_set, f_score)
        if current == goal:
            return reconstruct_path(came_from, current)
        
        open_set.erase(current)
        for neighbor in get_neighbors(current):
            if blocked.has(neighbor):
                continue
            var tentative = g_score[current] + 1
            if tentative < g_score.get(neighbor, INF):
                came_from[neighbor] = current
                g_score[neighbor] = tentative
                f_score[neighbor] = tentative + heuristic(neighbor, goal)
                if neighbor not in open_set:
                    open_set.append(neighbor)
    
    return []  # no path
```

---

## See Also

- `docs/systems/stealth.md` — Fog of war and movement constraints
- `docs/systems/perception.md` — How guards perceive movement
- `docs/systems/ai.md` — How guards decide their actions
- `docs/production/roadmap.md` — Timeline for AP and movement refinement

---

**Last Updated:** 2026-06-11  
**Maintained By:** Lead Programmer  
**Status:** Active 🟢
