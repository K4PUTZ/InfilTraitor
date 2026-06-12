# INFILTRAITOR — Perception System

> **Visual detection, audio detection, guard attention, and how enemies perceive the world.**

---

## Overview

The perception system determines **how and when guards detect the agent**. It combines:

- **Visual detection** via probabilistic vision cones
- **Audio detection** via noise propagation and hearing
- **Attention management** for realistic, reactive behavior
- **Memory & decay** so guards forget old information over time

All perception uses **explicit, visible rules** — the player can always understand *why* they were detected.

---

## Visual Detection System

### Primary Vision Cone

Each guard has a **frontal vision cone** with probabilistic detection based on distance and angle.

**Parameters:**
- **FOV (Field of View) Width:** 90° default
- **Range:** 8 tiles maximum
- **Facing angle:** Updated via looking behavior (see Attention section)

**Distance Curve (Detection Probability by Tile Distance):**

```
Distance 1: 100% — adjacent tile, easily spotted
Distance 2: 95%
Distance 3: 85%
Distance 4: 60%
Distance 5: 40%
Distance 6: 15%
Distance 7: 5%
Distance 8: 1% — barely detectable at maximum range
```

### Cone Geometry & Angle Falloff

Detection is not binary at cone boundaries — it falls off smoothly:

```gdscript
func get_base_detection_chance(guard: Guard, target_tile: Vector2i) -> float:
    # Distance from detection curve
    var dist = manhattan_distance(guard.tile, target_tile)
    if dist > 8:
        return 0.0
    
    var base_chance = DISTANCE_CURVE[dist]
    
    # Angle falloff: edges of cone have reduced probability
    var angle_to_target = calculate_angle(guard, target_tile)
    var angle_from_facing = abs_angle_diff(guard.facing_angle, angle_to_target)
    var half_fov = guard.fov_degrees / 2.0
    
    if angle_from_facing > half_fov:
        return 0.0  # outside cone
    
    # Soft falloff at edges: 1.0 at center, 0.5 at edge
    var edge_factor = 1.0 - (angle_from_facing / half_fov)
    return base_chance * edge_factor
```

### Peripheral Vision (Movement Detection Only)

Guards have **wide, short-range peripheral vision** that only triggers if the **agent just moved**:

- **FOV Width:** 180° (very wide)
- **Range:** 2 tiles
- **Triggers if:** Agent moved on last turn
- **Base chance:** 8% per tile

**Design Rationale:** Helps catch moving targets without making stationary hiding impossible.

### Line of Sight (LOS)

Visual detection requires **unobstructed line of sight**. Walls and solid objects block vision:

```gdscript
func has_line_of_sight(guard_tile: Vector2i, target_tile: Vector2i) -> bool:
    var line = bresenham_line(guard_tile, target_tile)
    for i in range(1, line.size() - 1):  # exclude start and end
        var current = line[i]
        var previous = line[i - 1]
        
        # Check for walls using edge-wall system
        if WallEdgeData.is_wall_between(previous, current):
            return false
        
        # Check for solid obstacles
        if ObjectLayer.blocks_los(current):
            return false
    
    return true
```

---

## Detection Multipliers

Base detection chance is modified by several factors:

### State-Dependent Multipliers

| Guard State | Vision Range | FOV | Detection Mult | Notes |
|------------|--------------|-----|-----------------|-------|
| PATROL | 8 tiles | 90° | 0.80× | Relaxed, scanning casually |
| SUSPICIOUS | 8 tiles | 90° | 1.20× | Actively looking |
| ALERT | 9 tiles | 120° | 1.50× | Heightened awareness |
| CHASE | 10 tiles | 150° | 2.00× | Fully focused on threat |
| SEARCH | 8 tiles | 90° | 0.60× | Distracted, investigating |

### Shadow Multipliers

Tactical shadows reduce detection:

- **Direct shadow** (0.30×) — tile adjacent to obstacle
- **Penumbra** (0.55×) — tile 2 steps away from obstacle
- **No shadow** (1.00×) — open floor

**Application:**
```gdscript
var base_chance = get_base_detection_chance(guard, agent_tile)
var shadow_mult = get_shadow_multiplier(agent_tile)
var state_mult = STATE_DETECTION_MULTIPLIER[guard.state]
var final_chance = base_chance * shadow_mult * state_mult
```

### Noise Bonus

If the agent recently made noise (moving, using gadgets), guards get a **+30% detection bonus**:

```gdscript
var noise_bonus = 0.0
if agent_made_noise_recently:
    noise_bonus = 0.30

var final_chance = clamp(base_chance + noise_bonus, 0.0, 1.0)
```

---

## Detection Meter (Per-Guard)

Each guard maintains a **personal detection meter** (0.0 to 1.0). The meter accumulates detection probability over time using a **sigmoid gain curve** to create urgency:

### Accumulation
```gdscript
func sigmoid_gain(current_meter: float, k: float = 8.0) -> float:
    # Curve peaks near 0.5, creating urgency as detection approaches
    var midpoint = 0.5
    return 1.0 / (1.0 + exp(-k * (current_meter - midpoint)))

func update_detection_meter(guard: Guard, detection_chance: float):
    var gain = detection_chance * sigmoid_gain(guard.detection)
    guard.detection = clamp(guard.detection + gain, 0.0, 1.0)
    
    if guard.detection >= 1.0:
        trigger_full_detection(guard)  # Fully detected!
```

### Threshold Reactions
```
detection >= 1.0   → STATE_CHASE (fully detected, raise alarm)
detection >= 0.70  → STATE_ALERT (high confidence, investigate)
detection >= 0.40  → STATE_SUSPICIOUS (suspicious activity)
detection < 0.40   → STATE_PATROL (relaxed)
```

### Decay
Detection meters decay when the agent is **not visible** and has **not made noise**:

- **Per turn decay:** -0.05 when undetected and quiet
- **Fast decay:** -0.15 if agent moves into shadow or out of sight
- **Minimum:** 0.0 (cannot go below zero)

---

## Audio Detection System

### Independent from Visual

Audio detection is **completely independent** of visual detection. A guard can hear you through a wall even if they can't see you.

### Noise Sources
Guards hear noise from:
- **Agent movement** (footsteps, ~20% per step at 0.5 intensity)
- **Gadget use** (smoke bomb, EMP - loud, 1.0 intensity)
- **Interactions** (hacking, picking locks - medium, 0.7 intensity)

### Noise Propagation
Noise travels through tiles with **wall attenuation**:

```gdscript
func get_audio_strength(source_tile: Vector2i, listener_tile: Vector2i) -> float:
    var path = bresenham_line(source_tile, listener_tile)
    var signal_strength = NOISE_BASE_INTENSITY  # e.g., 0.5 for footsteps
    
    for i in range(1, path.size() - 1):
        var current = path[i]
        var previous = path[i - 1]
        
        # Each wall reduces signal by 40%
        if WallEdgeData.is_wall_between(previous, current):
            signal_strength *= 0.6
    
    # Distance attenuation (linear over 2-tile hearing radius)
    var distance = manhattan_distance(source_tile, listener_tile)
    if distance > 2:
        return 0.0  # beyond hearing range
    
    var distance_mult = 1.0 - (float(distance) / 2.0)
    return signal_strength * distance_mult
```

### Audio Reaction Thresholds

```
Audio Strength >= 0.60  → STATE_SUSPICIOUS for 3 turns (investigate)
Audio Strength >= 0.25  → STATE_SUSPICIOUS for 1 turn (glance)
Audio Strength < 0.25   → Ignored (background noise)
```

### Detection Meter Accumulation
Regardless of audio reaction, the detection meter **always accumulates** audio evidence:

```gdscript
# Detection meter always increases when hearing noise
var audio_gain = audio_strength * 0.5  # 50% of audio becomes detection
guard.detection += audio_gain
```

---

## Guard Attention System

### Decoupled Vision & Facing

Guards have **two independent angles:**

1. **Facing angle** (`guard.facing_angle`) — which direction the guard is physically facing
2. **Vision angle** (derived from attention focus) — where the guard is *looking*

This allows for realistic behavior: a guard can face north while looking east.

### Three Attention Modes

| Mode | Behavior | Purpose |
|------|----------|---------|
| **IDLE_SCANNING** | Guard rotates slowly, looking left/right (±45° from facing) | Casual patrol scanning |
| **WAYPOINT_ANTICIPATION** | Guard faces their next patrol waypoint, looking ahead | Preparing to move |
| **AGENT_TRACKING** | Guard focuses directly on agent | Active hunting |

### Attention Transitions
```gdscript
# Transition to new attention mode
func set_attention_mode(guard: Guard, new_mode: AttentionMode):
    guard.attention_mode = new_mode
    match new_mode:
        AttentionMode.IDLE_SCANNING:
            start_scan_tween(guard)  # rotate view ±45° slowly
        AttentionMode.WAYPOINT_ANTICIPATION:
            look_toward(guard, guard.next_waypoint)
        AttentionMode.AGENT_TRACKING:
            look_toward(guard, agent.tile)
```

---

## Memory & Information Decay

### Guard Knowledge Class

Each guard maintains knowledge of the agent's last-known position:

```gdscript
class GuardKnowledge:
    var last_known_tile: Vector2i
    var confidence: ConfidenceLevel  # NONE, INFERRED, HEARD, SEEN
    var knowledge_age: int = 0
    
    func decay():
        knowledge_age += 1
        if confidence == ConfidenceLevel.SEEN and knowledge_age >= 3:
            confidence = ConfidenceLevel.HEARD
        elif confidence == ConfidenceLevel.HEARD and knowledge_age >= 8:
            confidence = ConfidenceLevel.INFERRED
```

### Confidence Levels

| Level | Meaning | Decay Time | Use In |
|-------|---------|-----------|--------|
| **SEEN** | Guard directly observed agent | 3 turns | Direct chase |
| **HEARD** | Guard heard agent (audio/communication) | 5 turns | Investigation |
| **INFERRED** | Guard guessed based on pattern | — | Predictive patrol |
| **NONE** | No knowledge | — | Random patrol |

---

## Scanning & Focus Behavior

### Spontaneous Pauses

While patrolling, guards pause (~20% per step) for 1–2 turns to look around:

```gdscript
# During guard's turn
if randf() < 0.20:  # 20% chance
    guard.idle_turns_remaining = randi_range(1, 2)
    guard.enter_state(STATE_IDLE)  # pause and scan
```

### Scanning During Idle

When paused, guards perform a **focus sweep** in their immediate area:

```gdscript
func perform_scan_sweep(guard: Guard):
    # Rotate view ±45° left and right
    var scan_left = guard.facing_angle - 45
    var scan_right = guard.facing_angle + 45
    var scan_duration = 1.5  # seconds, but expressed in turn equivalents
    
    # Any nearby movement gets extra detection bonus during scan
    var nearby_tiles = get_tiles_in_radius(guard.tile, 3)
    for tile in nearby_tiles:
        if agent_on_tile(tile):
            # Bonus detection during scan
            var bonus_chance = 0.40  # extra 40% during scan
            guard.detection += bonus_chance
```

---

## See Also

- `docs/systems/noise.md` — Detailed noise propagation and audio system
- `docs/systems/lighting.md` — Shadow calculations and tactical visibility
- `docs/systems/ai.md` — How guards use perception to make decisions
- `docs/systems/movement.md` — How player movement triggers detection

---

**Last Updated:** 2026-06-11  
**Maintained By:** Lead Programmer  
**Status:** Active 🟢
