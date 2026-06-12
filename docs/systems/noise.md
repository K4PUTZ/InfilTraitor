# INFILTRAITOR — Noise System

> **Sound propagation, noise decay, and audio perception mechanics.**

---

## Overview

The noise system creates a **persistent sound map** that propagates through the environment. Noise persists across entire enemy phases and decays gradually, creating emergent detection patterns independent of visual line of sight.

Noise is a **detection vector equal to vision** — enemies hear you before seeing you, and sound travels where sight cannot.

---

## Noise Grid

### Persistent Sound Map

A Dictionary maintains the current sound state across all tiles:

```gdscript
var _noise_grid: Dictionary = {}  # Dictionary<Vector2i, {"intensity": float, "age": int}>

# Example state:
_noise_grid = {
    Vector2i(5, 5): {"intensity": 0.6, "age": 0},
    Vector2i(6, 5): {"intensity": 0.3, "age": 1},
    Vector2i(7, 5): {"intensity": 0.1, "age": 2},
}
```

### Noise Properties

| Property | Range | Notes |
|----------|-------|-------|
| **Intensity** | 0.0–1.0 | Volume/strength of noise |
| **Age** | 0+ turns | Turns since noise was created |
| **Location** | Vector2i | Tile where noise originated |

---

## Noise Emission

### Emission Sources

Guards and the agent emit noise from various actions:

| Action | Intensity | Notes |
|--------|-----------|-------|
| **Footsteps (movement)** | 0.40–0.50 | ~20% chance per step |
| **Gadget use (smoke bomb)** | 1.0 | Very loud, immediate reaction |
| **Gadget use (EMP)** | 0.90 | Loud beep/hum |
| **Interaction (hacking)** | 0.70 | Sustained beeping |
| **Interaction (lock picking)** | 0.60 | Scratching, clicking |
| **Combat (melee)** | 0.80 | Clash, impact |
| **Combat (ranged)** | 1.0 | Gunshot, very loud |

### Guard Emission During Enemy Phase

After each guard move, there's a **noise check**:

```gdscript
func check_guard_emission(guard: Guard, destination: Vector2i) -> void:
    var state_noise_chance = GUARD_NOISE_CHANCE_BY_STATE.get(guard.state, 0.0)
    
    if randf() < state_noise_chance:
        var intensity = GUARD_NOISE_INTENSITY_BY_STATE.get(guard.state, 0.5)
        emit_noise(destination, intensity)

const GUARD_NOISE_CHANCE_BY_STATE = {
    "patrol": 0.15,
    "suspicious": 0.40,
    "alert": 0.60,
    "chase": 0.70,
    "search": 0.50,
}

const GUARD_NOISE_INTENSITY_BY_STATE = {
    "patrol": 0.40,
    "suspicious": 0.60,
    "alert": 0.90,
    "chase": 1.00,
    "search": 0.70,
}
```

### Agent Emission During Player Phase

Agent emits noise on certain actions:

```gdscript
# During movement
func move_agent(from: Vector2i, to: Vector2i) -> void:
    # Small noise from footsteps (5% base chance increased by terrain)
    if randf() < 0.05:
        emit_noise(to, 0.45)

# Gadget use
func use_gadget(gadget_type: String) -> void:
    match gadget_type:
        "smoke_bomb":
            emit_noise(agent.tile, 1.0)  # Very loud
        "EMP":
            emit_noise(agent.tile, 0.90)
        "decoy":
            emit_noise(decoy_tile, 0.60)
```

---

## Noise Propagation

### Wall Attenuation

Sound travels through the environment but is attenuated by walls:

```gdscript
func get_noise_propagation(from: Vector2i, to: Vector2i) -> float:
    var base_intensity = _noise_grid.get(from, {}).get("intensity", 0.0)
    if base_intensity <= 0.0:
        return 0.0
    
    var path = bresenham_line(from, to)
    var signal_strength = base_intensity
    
    # Each wall crossing reduces signal by 40%
    for i in range(1, path.size() - 1):
        var current = path[i]
        var previous = path[i - 1]
        
        if WallEdgeData.is_wall_between(previous, current):
            signal_strength *= 0.6  # 40% attenuation per wall
    
    # Distance falloff (linear over 2-tile radius from source)
    var distance = manhattan_distance(from, to)
    if distance > 2:
        return 0.0  # beyond hearing range
    
    # Linear: 1.0 at source, 0.0 at 2 tiles away
    var distance_mult = 1.0 - (float(distance) / 2.0)
    return signal_strength * distance_mult
```

### Effective Range
- **No walls:** Up to 2 tiles away at full intensity
- **1 wall:** Up to 2 tiles but at 60% intensity
- **2 walls:** Up to 2 tiles but at 36% intensity (0.6 × 0.6)
- **3 walls:** Severely attenuated, barely detectable

---

## Noise Decay

### Decay Schedule

Noise decays at the **end of each enemy phase**:

```gdscript
func decay_all_noise() -> void:
    for tile in _noise_grid.keys():
        var noise_data = _noise_grid[tile]
        noise_data["intensity"] -= 0.25  # Fixed -0.25 per turn
        noise_data["age"] += 1
        
        if noise_data["intensity"] <= 0.0:
            _noise_grid.erase(tile)
```

### Persistence
- **Initial Intensity 0.5:** Survives 2 turns (0.5 → 0.25 → 0.0)
- **Initial Intensity 1.0:** Survives 4 turns (1.0 → 0.75 → 0.5 → 0.25 → 0.0)
- **Decay multiplier:** 0.25 per enemy phase (fixed, not state-dependent)

### Age Tracking
```
Turn 0: Noise created, age=0, intensity=0.5
Turn 1: age=1, intensity=0.25 (still audible)
Turn 2: age=2, intensity=0.0 (decayed, removed from grid)
```

---

## Audio Detection

### Guard Audio Reaction System

When guards hear noise, they react based on **perceived intensity**:

```gdscript
func evaluate_audio_perception(guard: Guard) -> void:
    var max_perceived_intensity = 0.0
    var loudest_tile = Vector2i.ZERO
    
    # Check all noise sources within hearing range
    for noise_tile in _noise_grid.keys():
        var propagated = get_noise_propagation(noise_tile, guard.tile)
        if propagated > max_perceived_intensity:
            max_perceived_intensity = propagated
            loudest_tile = noise_tile
    
    # React based on intensity thresholds
    if max_perceived_intensity >= 0.60:
        guard.enter_state(STATE_SUSPICIOUS)
        guard.last_known_agent_cell = loudest_tile
        guard.suspicion_turns = 3  # Investigate for 3 turns
    elif max_perceived_intensity >= 0.25:
        guard.enter_state(STATE_SUSPICIOUS)
        guard.suspicion_turns = 1  # Just glance around
    elif max_perceived_intensity < 0.25:
        # Ignored (background noise or too distant)
        pass
```

### Reaction Thresholds

| Audio Intensity | Reaction | Duration |
|-----------------|----------|----------|
| ≥ 0.60 | Enter SUSPICIOUS, investigate last-known position | 3 turns |
| ≥ 0.25 | Enter SUSPICIOUS, look around | 1 turn |
| < 0.25 | Ignored | — |

### Detection Meter Accumulation

**Important:** Detection meter **always accumulates** audio evidence, even if no state change:

```gdscript
# In addition to state reactions, always add to detection
var audio_gain = perceived_intensity * 0.5  # 50% of audio becomes detection
guard.detection += audio_gain
```

This means:
- Audio at 0.5 intensity adds 0.25 to detection meter
- Audio at 1.0 intensity adds 0.5 to detection meter
- Accumulation happens even if guard doesn't enter SUSPICIOUS

---

## Noise Visualization

### 3-Layer Cyan Cone

Noise is visualized as a 3-layer expanding cone (in debug mode):

```gdscript
# Layer 1: Intense (inner)
draw_colored_polygon(cone_points(tile, 0.3), Color(0.2, 0.8, 1.0, 0.4))

# Layer 2: Medium (middle)
draw_colored_polygon(cone_points(tile, 0.6), Color(0.2, 0.8, 1.0, 0.25))

# Layer 3: Faint (outer)
draw_colored_polygon(cone_points(tile, 1.0), Color(0.2, 0.8, 1.0, 0.1))
```

**Alpha by intensity:**
```gdscript
var alpha = noise_intensity * 0.4  # Max 40% opacity
```

---

## Guard Noise Direction Indicators

### Audio Indicator System

When a guard emits noise while moving, the agent sees a **direction indicator** showing where the sound came from:

- **Display:** "(((" or ")))" symbols floating around the agent
- **Color:** Orange/red based on intensity
- **Position:** Orbits agent at 120px radius
- **Duration:** 1.8 seconds with smooth fadeout
- **Quantity:** One indicator per noise emission per turn

```gdscript
class GuardNoiseIndicator:
    func add_indicator(agent_pos: Vector2, noise_pos: Vector2, intensity: float) -> void:
        var direction_to_noise = (noise_pos - agent_pos).normalized()
        var indicator_pos = agent_pos + direction_to_noise * 120  # 120px radius
        var color = lerp(COLOR_LOW, COLOR_HIGH, clamp(intensity, 0.0, 1.0))
        
        _indicators.append({
            "pos": indicator_pos,
            "color": color,
            "intensity": intensity,
            "age": 0.0,
        })
```

---

## Noise & Silence Strategies

### Forcing Silence

Players can force silence through:

1. **Not moving** — No footsteps
2. **Not using gadgets** — No loud effects
3. **Waiting in shadows** — Small noise chance during subsequent enemy phase
4. **Using silent gadgets** (future) — EMP with muffler, etc.

### Creating Distractions

Players can deliberately emit noise to:

1. **Distract guards** — Play noise on one side of room while moving through opposite
2. **Mask movement** — Use loud gadget while moving
3. **Test guard reactions** — Emit small noise to probe alert status

---

## Noise Grid Visualization (Debug)

In DEV_VISION mode, display current noise state:

```gdscript
func draw_noise_debug() -> void:
    for tile in _noise_grid.keys():
        var data = _noise_grid[tile]
        var intensity = data.get("intensity", 0.0)
        
        # Draw intensity on tile
        draw_string(font, floor_layer.map_to_local(tile), 
                   "%.2f" % intensity, 
                   FONT_COLOR, 
                   Color(0.2, 0.8, 1.0, intensity))
```

---

## Constants Reference

```gdscript
# Decay
const NOISE_DECAY_PER_TURN := 0.25
const MAX_NOISE_PERSISTENCE := 4  # turns (for 1.0 intensity)

# Propagation
const WALL_ATTENUATION := 0.6  # 40% loss per wall
const HEARING_RANGE := 2  # tiles
const HEARING_RANGE_MAX_INTENSITY := 0.0  # at 2 tiles away

# Detection thresholds
const AUDIO_INVESTIGATE_THRESHOLD := 0.60
const AUDIO_GLANCE_THRESHOLD := 0.25
const AUDIO_DETECTION_GAIN := 0.5  # meter gain per intensity

# Guard emission
const GUARD_EMIT_CHANCE_BASE := {
    "patrol": 0.15, "suspicious": 0.40, "alert": 0.60, "chase": 0.70, "search": 0.50
}
const GUARD_EMIT_INTENSITY := {
    "patrol": 0.40, "suspicious": 0.60, "alert": 0.90, "chase": 1.00, "search": 0.70
}

# Agent emission
const AGENT_FOOTSTEP_CHANCE := 0.05
const AGENT_FOOTSTEP_INTENSITY := 0.45
```

---

## See Also

- `docs/systems/perception.md` — Audio detection thresholds
- `docs/systems/ai.md` — How guards react to noise
- `docs/production/milestones.md` — M2-04 (Noise System deployment)

---

**Last Updated:** 2026-06-11  
**Maintained By:** Audio Programmer  
**Status:** Active 🟢
