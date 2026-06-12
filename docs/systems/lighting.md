# INFILTRAITOR — Lighting & Shadows

> **Baked shadows, light sources, and tactical visibility mechanics.**

---

## Overview

The lighting system creates **tactical shadow zones** that reduce enemy detection probability. Shadows are **baked** (pre-calculated) onto TileMapLayers using light source cone projection geometry, ensuring they're always visible and never hidden by fog of war.

Shadows are a **core stealth mechanic** — they are not cosmetic.

---

## Light Sources

### LightSource Model

Each light source is defined by:

```gdscript
class LightSource:
    var cell: Vector2i              # Position on grid
    var height: float               # Height above ground
    var radius: int                 # Projection radius in tiles
    var intensity: float            # Brightness (0.0–1.0)
    var active: bool = true         # Can be toggled on/off
    var direction: Vector2 = Vector2.ZERO  # Optional, for spotlights
```

**Default Light Sources (Playtest Mockup):**
```
Light 1: cell=(9, 4),   height=5.0, radius=8, intensity=0.90
Light 2: cell=(9, 18),  height=5.0, radius=7, intensity=0.85
Light 3: cell=(9, 30),  height=5.0, radius=7, intensity=0.85
```

### Light Customization

Lights can be per-room via layout configuration:

```gdscript
# In room layout (future)
var layout = {
    "light_sources": [
        {"x": 9, "y": 4, "height": 5.0, "radius": 8, "intensity": 0.9},
        {"x": 9, "y": 18, "height": 5.0, "radius": 7, "intensity": 0.85},
        # ... more lights
    ]
}
```

---

## Shadow Projection Geometry

### Cone Projection Formula

When an obstacle blocks a light source, it casts a shadow **cone** in the direction away from the light:

$$\text{shadow\_length} = \frac{\text{obstacle\_height} \times (\text{light\_height} - \text{obstacle\_height})}{\text{distance}}$$

**Example:**
- Light at height 5.0
- Obstacle at height 1.5 (crate)
- Distance 3 tiles from light
- Shadow length = $\frac{1.5 \times (5.0 - 1.5)}{3} = \frac{1.5 \times 3.5}{3} = 1.75$ tiles

The shadow extends approximately **2 tiles** in the direction away from the light.

### Obstacle Heights

Tile types map to obstruction heights:

```gdscript
const OBSTACLE_HEIGHTS: Dictionary = {
    "crate":     1.0,      # Small boxes
    "wall":      2.0,      # Full-height walls
    "block":     2.0,      # Blocks
    "column":    3.0,      # Pillars (taller obstruction)
    "half_wall": 1.0,      # Partial walls
}
const OBSTACLE_HEIGHT_DEFAULT := 1.5
```

---

## 8-Direction Shadow Quantization

Shadows are cast in **8 isometric directions** (not just 4 cardinals) for smooth coverage:

```
Direction Indices:
0: UP       (-0, -1)
1: NE       (+1, -1)
2: RIGHT    (+1,  0)
3: SE       (+1, +1)
4: DOWN     ( 0, +1)
5: SW       (-1, +1)
6: LEFT     (-1,  0)
7: NW       (-1, -1)
```

For each light source, the direction is **quantized** to the nearest 8-direction:

```gdscript
func quantize_direction(vector: Vector2i) -> Vector2i:
    var angle = atan2(float(vector.y), float(vector.x))
    var index = int(round(angle / (PI / 4.0))) % 8
    return SHADOW_DIRS[((index % 8) + 8) % 8]
```

---

## Shadow Rendering Layers

### Two Shadow Layers

Shadows are rendered on two distinct **TileMapLayer**s for visual variety:

1. **ShadowFullLayer** — Dark shadows (multiplier ≤ 0.35)
   - Modulate: Color(0.58, 0.58, 0.58, 1.0) — 58% brightness
   - Gives strong visual indication of deep shadow

2. **ShadowPartialLayer** — Light shadows (multiplier > 0.35)
   - Modulate: Color(0.78, 0.78, 0.78, 1.0) — 78% brightness
   - More subtle penumbra effect

### Z-Index Ordering

```
Z-Index 0:  FloorLayer (base)
Z-Index 1:  ShadowFullLayer, ShadowPartialLayer (baked shadows)
Z-Index 2:  FogOfWarOverlay (fog of war)
Z-Index 3:  StructureLayer, StructureWallLayer (walls, objects)
Z-Index 4+: Sprites (agent, guards, etc.)
```

**Key:** Shadows are **always below fog of war**, so they're always visible (never hidden).

---

## Shadow Calculation Pipeline

### 1. Setup Light Sources

```gdscript
func _setup_light_sources(layout: Dictionary) -> void:
    _light_sources.clear()
    var lights = layout.get("light_sources", [])
    
    if lights.is_empty():
        lights = _default_light_sources()
    
    for entry in lights:
        _light_sources.append(LightSource.new(
            Vector2i(entry.get("x", 0), entry.get("y", 0)),
            float(entry.get("height", 4.5)),
            int(entry.get("radius", 7)),
            float(entry.get("intensity", 0.9))
        ))
```

### 2. Populate Obstacle Heights

```gdscript
func _populate_obstacle_heights() -> void:
    _obstacle_heights.clear()
    for blocked_cell in _blocked_cells.keys():
        var tile_name = _get_tile_name_at(blocked_cell)
        var height = OBSTACLE_HEIGHT_DEFAULT
        
        for key in OBSTACLE_HEIGHTS.keys():
            if tile_name.begins_with(key):
                height = OBSTACLE_HEIGHTS[key]
                break
        
        _obstacle_heights[blocked_cell] = height
```

### 3. Compute Shadow Tiles (Multi-Light)

```gdscript
func _compute_shadow_tiles() -> void:
    _shadow_tiles.clear()
    
    if _light_sources.is_empty():
        _compute_shadow_tiles_fallback()
        return
    
    for light in _light_sources:
        if not light.active:
            continue
        _cast_shadows_from_light(light)
```

### 4. Cast Shadows from Single Light

```gdscript
func _cast_shadows_from_light(light: LightSource) -> void:
    for blocked_cell in _blocked_cells.keys():
        var dist_vec: Vector2i = blocked_cell - light.cell
        var dist: float = dist_vec.length()
        
        if dist > light.radius or dist < 0.1:
            continue
        
        # Obstacle height with safety check
        var obs_height: float = _obstacle_heights.get(blocked_cell, OBSTACLE_HEIGHT_DEFAULT) as float
        if obs_height >= light.height:
            obs_height = light.height - 0.1
        
        # Cone projection length
        var shadow_len: float = obs_height * (light.height - obs_height) / maxf(dist, 0.1)
        shadow_len = minf(shadow_len * light.intensity, float(SHADOW_LENGTH_MAX))
        
        # Quantize to 8 directions
        var dir: Vector2i = _quantize_dir(dist_vec)
        
        # Project shadow along direction
        for i in range(1, int(ceil(shadow_len)) + 1):
            var shadow_cell: Vector2i = blocked_cell + dir * i
            if not _is_cell_inside_room(shadow_cell):
                break
            if _blocked_cells.has(shadow_cell):
                break
            
            # Linear falloff: SHADOW_MULT_DIRECT → 1.0
            var t: float = float(i) / shadow_len
            var mult: float = lerpf(SHADOW_MULT, 1.0, clampf(t, 0.0, 1.0))
            
            # Min function: darker shadows win
            if _shadow_tiles.has(shadow_cell):
                _shadow_tiles[shadow_cell] = minf(_shadow_tiles[shadow_cell], mult)
            else:
                _shadow_tiles[shadow_cell] = mult
```

### 5. Bake to TileMapLayers

```gdscript
func _bake_shadow_tiles() -> void:
    shadow_full_layer.clear()
    shadow_partial_layer.clear()
    
    var floor_sid: int = _tile_ids.get("floor_SE", -1)
    if floor_sid < 0:
        return
    
    for shadow_cell: Vector2i in _shadow_tiles.keys():
        var mult: float = _shadow_tiles[shadow_cell]
        if mult <= 0.35:
            shadow_full_layer.set_cell(shadow_cell, floor_sid, Vector2i.ZERO)
        else:
            shadow_partial_layer.set_cell(shadow_cell, floor_sid, Vector2i.ZERO)
```

---

## Shadow Multipliers & Detection

### Multiplier Effect on Detection

Detection calculation includes shadow multiplier:

```gdscript
var base_detection = get_base_detection_chance(guard, agent_tile)
var shadow_mult = get_shadow_multiplier(agent_tile)  # 0.30, 0.55, or 1.0
var final_detection = base_detection * shadow_mult
```

| Shadow Tier | Multiplier | Detection Reduction | Effect |
|-------------|-----------|-------------------|--------|
| **Direct Shadow** | 0.30× | 70% reduction | Very hard to detect |
| **Penumbra** | 0.55× | 45% reduction | Moderately hard |
| **Open Floor** | 1.00× | 0% reduction | Normal detection |

---

## Fallback Mode (No Light Sources)

If no light sources are defined, a simple **omnidirectional fallback** is used:

```gdscript
func _compute_shadow_tiles_fallback() -> void:
    var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    for blocked_cell in _blocked_cells.keys():
        for dir in dirs:
            var candidate: Vector2i = blocked_cell + dir
            if not _is_cell_inside_room(candidate) or _blocked_cells.has(candidate):
                continue
            
            # Direct shadow (adjacent)
            if _shadow_tiles.has(candidate):
                _shadow_tiles[candidate] = minf(_shadow_tiles[candidate], SHADOW_MULT)
            else:
                _shadow_tiles[candidate] = SHADOW_MULT
            
            # Penumbra (2 steps away)
            var penumbra: Vector2i = candidate + dir
            if _is_cell_inside_room(penumbra) and not _blocked_cells.has(penumbra):
                if not _shadow_tiles.has(penumbra):
                    _shadow_tiles[penumbra] = PENUMBRA_MULT
```

---

## Constants Reference

```gdscript
# Shadow multipliers
const SHADOW_MULT := 0.30          # Direct shadow (adjacent)
const PENUMBRA_MULT := 0.55        # Penumbra (2 tiles away)
const SHADOW_LENGTH_MAX := 5        # Max shadow projection (tiles)
const OBSTACLE_HEIGHT_DEFAULT := 1.5

# 8-direction vectors (isometric)
const SHADOW_DIRS: Array[Vector2i] = [
    Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
    Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

# Light source defaults
const DEFAULT_LIGHT_HEIGHT := 5.0
const DEFAULT_LIGHT_RADIUS := 7
const DEFAULT_LIGHT_INTENSITY := 0.85
```

---

## Performance Notes

- **Baking:** Done once per room initialization (~20 ms for 36×36 room)
- **Update:** Shadows persist; no per-frame recalculation
- **Memory:** Shadow tiles stored as Dictionary (sparse representation)
- **Rendering:** Two TileMapLayers, ~100–200 shadow tiles per room typical

---

## Visual Design Goals

1. **Readability:** Shadows are clearly visible as darker tiles
2. **Tactical:** Players naturally move toward shadows for stealth
3. **Realistic:** Cone geometry is physically plausible
4. **Performance:** Baked, not dynamic

---

## See Also

- `docs/systems/perception.md` — How shadows affect detection
- `docs/systems/stealth.md` — Tactical positioning using shadows
- `docs/systems/movement.md` — Movement patterns and tactical awareness
- `DEVELOPMENT/LIGHTING_DESIGN.md` — Historical design notes (legacy)

---

**Last Updated:** 2026-06-11  
**Maintained By:** Graphics Programmer  
**Status:** Active 🟢
