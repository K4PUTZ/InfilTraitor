# Infiltraitor — Enemy AI & Alert System: Technical Design Prompt

## Project Context

Turn-based 2D isometric stealth game built in **Godot 4** (GDScript, mobile-first).
Grid: `TileMapLayer` isometric. Movement: Action Point based (agent has 2 AP per turn).
Wall system: edge-based (see `infiltraitor_wall_system.md`).
This document covers the full enemy AI stack: perception, state machines, communication,
alert escalation, radio, and wall-mounted alarms.

---

## 1. Guard Data Model

Every guard is a node (`guard.gd`) carrying three independent layers of state:

```gdscript
class_name Guard extends CharacterBody2D

# --- LAYER 1: Physical Status (overrides everything) ---
enum PhysicalStatus { ALIVE, UNCONSCIOUS, STUNNED, DEAD [future: POISONED, BURNING, INJURED, FROZEN, etc.]}
var physical_status: PhysicalStatus = PhysicalStatus.ALIVE

# --- LAYER 2: Loyalty (modifies detection parameters) ---
enum Loyalty { NORMAL, BRIBED, CONTROLLED, CONVERTED, ALLY }
var loyalty: Loyalty = Loyalty.NORMAL

# --- LAYER 3: Operational State (main FSM) ---
enum OpState {
    RELAXED, PATROLLING, TENSE, ALERT,
    SEARCHING, CHASING, REPOSITIONING,
    ATTACKING, FLEEING, CALLING_ALARM
}
var op_state: OpState = OpState.RELAXED

# --- PERCEPTION ---
var facing_angle: float          # degrees, 0 = North in iso space
var fov_degrees: float = 90.0    # frontal cone width
var peripheral_fov: float = 180.0

# --- KNOWLEDGE ---
var knowledge: GuardKnowledge    # see Section 2

# --- DETECTION METER ---
var detection: float = 0.0       # 0.0 to 1.0; 1.0 = fully detected
var detection_triggered: bool = false

# --- COMMUNICATION ---
var has_radio: bool = false
var radio_cooldown: int = 0      # turns until next radio call allowed
var whistle_cooldown: int = 0

# --- PATROL ---
var patrol_route: Array[Vector2i] = []
var patrol_index: int = 0
var idle_turns_remaining: int = 0
```

Layer 1 suspends Layer 3 entirely — a STUNNED guard does not process OpState.
Layer 2 modifies detection gain rates — a BRIBED guard has `detection_gain_multiplier = 0.0`
toward the agent but still processes all other stimuli normally.

---

## 2. GuardKnowledge — Distributed Information Model

Each guard maintains its own knowledge object. Guards do NOT share a global blackboard.
Information is shared explicitly via whistle, radio, or conversation.

```gdscript
class_name GuardKnowledge

enum ConfidenceLevel { NONE, INFERRED, HEARD, SEEN }

var last_known_tile: Vector2i = Vector2i(-1, -1)
var last_known_area: Rect2i                        # broader search zone if only heard
var knowledge_age: int = 0                         # turns since last update
var confidence: ConfidenceLevel = ConfidenceLevel.NONE
var source_guard_id: int = -1                      # who told this guard (-1 = self)

func merge(other: GuardKnowledge) -> void:
    # Only upgrade confidence, never downgrade
    if other.confidence > self.confidence:
        self.last_known_tile = other.last_known_tile
        self.last_known_area = other.last_known_area
        self.confidence = other.confidence
        self.knowledge_age = other.knowledge_age
        self.source_guard_id = other.source_guard_id

func decay(turns: int = 1) -> void:
    knowledge_age += turns
    # Confidence degrades: SEEN → HEARD after 3 turns without update
    if confidence == ConfidenceLevel.SEEN and knowledge_age >= 3:
        confidence = ConfidenceLevel.HEARD
    # HEARD → INFERRED after 5 more turns
    elif confidence == ConfidenceLevel.HEARD and knowledge_age >= 8:
        confidence = ConfidenceLevel.INFERRED
```

---

## 3. Detection System

### 3a. Dual-Cone FOV

Each guard has two overlapping vision cones evaluated every time the guard's turn resolves:

**Primary cone** — frontal, full range:
- Width: `fov_degrees` (default 90°)
- Range: 8 tiles
- Detection chance per tile by distance (from image reference):

```gdscript
const PRIMARY_DISTANCE_CURVE: Array[float] = [
    1.00,  # tile 1 (adjacent)
    0.95,  # tile 2
    0.85,  # tile 3
    0.60,  # tile 4
    0.40,  # tile 5
    0.15,  # tile 6
    0.01,  # tile 7
    0.00   # tile 8
]
```

**Peripheral cone** — wide, short range, movement-only:
- Width: `peripheral_fov` (default 180°)
- Range: 2 tiles
- Base detection chance: 0.08
- Only triggers if agent **moved** on their last turn

### 3b. Angle-Based Softening

Detection chance is not binary at cone edges — it falls off smoothly:

```gdscript
func get_detection_chance(guard: Guard, target_tile: Vector2i) -> float:
    if not has_line_of_sight(guard.tile, target_tile):
        return 0.0

    var to_target = Vector2(target_tile - guard.tile).normalized()
    var facing_vec = Vector2.from_angle(deg_to_rad(guard.facing_angle))
    var angle_diff = rad_to_deg(facing_vec.angle_to(to_target))
    var half_fov = guard.fov_degrees / 2.0

    # Primary cone
    if abs(angle_diff) <= half_fov:
        var dist = manhattan_distance(guard.tile, target_tile)
        if dist >= PRIMARY_DISTANCE_CURVE.size(): return 0.0
        var base = PRIMARY_DISTANCE_CURVE[dist]
        var edge_factor = 1.0 - (abs(angle_diff) / half_fov)  # soft falloff at edges
        return base * edge_factor

    # Peripheral cone (movement only)
    var half_peripheral = guard.peripheral_fov / 2.0
    if abs(angle_diff) <= half_peripheral:
        var dist = manhattan_distance(guard.tile, target_tile)
        if dist <= 2 and agent_moved_last_turn:
            return 0.08 * (1.0 - (abs(angle_diff) / half_peripheral))

    return 0.0
```

### 3c. Line of Sight

LOS uses the edge-wall system from `wall_edge_data.gd`.
Cast a tile-by-tile ray from guard to target; a wall edge perpendicular to the ray blocks it.
Interactable objects (crates, furniture) also block LOS if they occupy the tile fully.

```gdscript
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
    for tile in bresenham_line(from, to):
        if tile == from: continue
        var prev = get_previous_tile_in_line(from, to, tile)
        if not WallEdgeData.can_see_through(prev, tile):
            return false
        if ObjectMap.blocks_los(tile):
            return false
    return true
```

### 3d. Detection Meter — Accumulation and Decay

The detection meter uses a **sigmoid gain curve** so the transition from 40%→70% feels urgent:

```gdscript
func sigmoid_gain(detection: float, k: float = 8.0) -> float:
    var midpoint = 0.5
    return 1.0 / (1.0 + exp(-k * (detection - midpoint)))

func update_detection(guard: Guard, raw_chance: float) -> void:
    var multiplier = get_detection_multiplier(guard)
    # gain is modulated by current detection level via sigmoid
    var gain = raw_chance * multiplier * sigmoid_gain(guard.detection)
    guard.detection = clamp(guard.detection + gain, 0.0, 1.0)

    if guard.detection >= 1.0 and not guard.detection_triggered:
        guard.detection_triggered = true
        trigger_full_detection(guard)
```

**Detection multipliers by OpState:**

```gdscript
func get_detection_multiplier(guard: Guard) -> float:
    match guard.op_state:
        OpState.RELAXED:      return 1.0
        OpState.PATROLLING:   return 1.0
        OpState.TENSE:        return 1.8
        OpState.ALERT:        return 2.2
        OpState.SEARCHING:    return 3.0
        OpState.CHASING:      return 3.0
    return 1.0
```

**Decay rates (per turn agent is out of sight):**

```gdscript
func get_decay_rate(guard: Guard) -> float:
    match guard.op_state:
        OpState.RELAXED:      return -0.15
        OpState.PATROLLING:   return -0.12
        OpState.TENSE:        return -0.06
        OpState.ALERT:        return -0.04
        OpState.SEARCHING:    return -0.02
        OpState.CHASING:      return -0.01
    return -0.10
```

---

## 4. Noise System

All sound-producing events (agent movement, guard whistle, radio crackle, alarm, running)
use a **single unified propagation model**. There is no separate "radius" per event type —
everything goes through `NoiseEvent`.

```gdscript
class_name NoiseEvent

enum NoiseType { FOOTSTEP, WHISTLE, RADIO, ALARM_PANEL, BODY_FALL, OBJECT_BREAK }

var origin_tile: Vector2i
var amplitude: int          # in AP-equivalent tiles (1 AP = base movement range)
var type: NoiseType
var source_id: int          # who/what made it (-1 = environment)

# Amplitude reference values:
# Agent walking:       1 AP range
# Agent running:       2 AP range
# Guard whistle:       2 AP range (same as agent run, intentional)
# Radio (open mic):    3 AP range (leaks sound)
# Alarm panel:         entire scene (broadcast)
# Body falling:        1 AP range
# Glass breaking:      2 AP range
```

**Propagation:** walls with the edge system attenuate sound by 1 amplitude per wall crossed.
A sound with amplitude 2 crossing 1 wall reaches only amplitude-1 guards on the other side.

```gdscript
func propagate_noise(event: NoiseEvent) -> void:
    for guard in get_all_active_guards():
        var path_cost = get_sound_path_cost(event.origin_tile, guard.tile)
        if path_cost <= event.amplitude:
            var attenuation = path_cost / float(event.amplitude)
            notify_guard_of_noise(guard, event, 1.0 - attenuation)
```

**Visual feedback:** guards that hear a noise display a sound-wave ripple effect pointing
toward the noise origin (directional, not omnidirectional). Guards that are not yet
activated show a muted/smaller version of this effect — visible to the player but not
revealing the guard's position beyond the effect itself.

**Agent noise chance:**
- Agent standing still: 0% noise
- Agent walking 1 tile (1 AP): 20% chance of footstep noise, amplitude 1
- Agent running 2 tiles (2 AP in one action): 80% chance, amplitude 2
- Guard within 1 AP range: chance doubles (40% walk, 100% run)

---

## 5. Operational State Machine

### State Definitions and Behaviors

```
RELAXED
  Behavior:   Standing, idle animations, talking to nearby guards (2-tile range).
              May look around slowly (facing_angle changes ±30° occasionally).
  Transition: → PATROLLING if patrol_route assigned and idle_turns_remaining = 0
              → TENSE if noise heard (confidence = HEARD)
              → SEARCHING if detection_triggered briefly then lost (confidence dropped)

PATROLLING
  Behavior:   Follows patrol_route in order. Pauses at waypoints for 1–2 turns.
              Facing direction follows movement direction.
  Transition: → RELAXED at waypoint with idle behavior defined
              → TENSE if noise heard
              → CHASING if detection >= 1.0

TENSE
  Behavior:   Stops moving. Turns toward noise origin. Investigates after 1-turn delay.
              Detection multiplier raised. Does NOT immediately chase.
  Duration:   Maximum 4 turns in TENSE before returning to prior state.
  Transition: → ALERT if noise confirmed or detection rises above 0.5
              → prior state (RELAXED/PATROLLING) if nothing confirmed after 4 turns

ALERT
  Behavior:   Guards a fixed checkpoint or doorway. Higher detection multiplier.
              Communicates via radio check-in every 3 turns (see Section 7).
  Transition: → SEARCHING if last_known_tile is set and no direct sight
              → CHASING if agent in direct sight

SEARCHING
  Behavior:   Moves toward last_known_tile. If reached, performs sweep pattern
              (checks adjacent tiles in a spiral). Updates last_known_tile as
              knowledge decays. Gives up after MAX_SEARCH_TURNS (default: 6).
  Post-search: → TENSE for 3 turns → prior non-searching state
  Transition: → CHASING if agent spotted during search

CHASING
  Behavior:   Uses A* pathfinding toward agent's current tile each turn.
              Updates last_known_tile every turn with SEEN confidence.
              Calls whistle if other guards within 2 AP range.
              Uses radio if has_radio = true and radio_cooldown = 0.
  Transition: → REPOSITIONING if agent reaches cover tile adjacent to guard
              → SEARCHING if LOS lost for 2 consecutive turns
              → ATTACKING if within melee/attack range

REPOSITIONING
  Behavior:   Guard moves to flanking position relative to agent's last_known_tile.
              Tries to avoid being in direct line from agent's cover tile.
  Transition: → ATTACKING from new position
              → CHASING if agent moves away

ATTACKING
  Behavior:   Uses available attack actions (defined separately from AI system).
  Transition: → CHASING if agent escapes attack range
              → FLEEING if guard health below threshold (configurable per guard type)
              → CALLING_ALARM if no weapon or civilian-type guard

FLEEING
  Behavior:   Moves toward nearest alarm panel or exit. Ignores agent.
              Still broadcasts knowledge via radio if has_radio = true.
  Transition: → CALLING_ALARM when adjacent to alarm panel

CALLING_ALARM
  Behavior:   1-turn action to activate alarm panel. Cannot be interrupted by movement
              (must be neutralized before action resolves).
  Transition: → (alarm triggers; see Section 8) → ALERT
```

---

## 6. Sweep Pattern for SEARCHING State

When a searching guard reaches `last_known_tile`, it performs a deterministic sweep
rather than random wandering:

```gdscript
func get_sweep_pattern(center: Vector2i) -> Array[Vector2i]:
    # Clockwise spiral from center, 1-tile radius first, then 2-tile
    return [
        center,
        center + Vector2i(0, -1),   # N
        center + Vector2i(1, -1),   # NE
        center + Vector2i(1, 0),    # E
        center + Vector2i(1, 1),    # SE
        center + Vector2i(0, 1),    # S
        center + Vector2i(-1, 1),   # SW
        center + Vector2i(-1, 0),   # W
        center + Vector2i(-1, -1),  # NW
    ]
```

The guard pathfinds to each point in sequence, skipping impassable tiles.
If agent is spotted during sweep, transitions immediately to CHASING.

---

## 7. Communication Systems

### 7a. Whistle (Local Broadcast)

- Range: 2 AP equivalent tiles, using the noise propagation system (amplitude = 2)
- Wall attenuation applies
- Guards that hear it receive a `NoiseEvent` of type WHISTLE
- The receiving guard gains knowledge at `ConfidenceLevel.HEARD` with the whistling
  guard's `last_known_tile` as origin area
- Whistle has a 2-turn cooldown per guard
- Visual: directional sound wave effect toward agent's direction

```gdscript
func do_whistle(guard: Guard) -> void:
    if guard.whistle_cooldown > 0: return
    var event = NoiseEvent.new()
    event.origin_tile = guard.tile
    event.amplitude = 2
    event.type = NoiseEvent.NoiseType.WHISTLE
    event.source_id = guard.id
    NoiseSystem.propagate_noise(event)
    guard.whistle_cooldown = 2

func on_whistle_received(receiver: Guard, sender: Guard, sender_knowledge: GuardKnowledge):
    var received = GuardKnowledge.new()
    received.last_known_tile = sender_knowledge.last_known_tile
    received.last_known_area = sender_knowledge.last_known_area
    received.confidence = ConfidenceLevel.HEARD   # downgrade from SEEN
    received.knowledge_age = sender_knowledge.knowledge_age + 1
    receiver.knowledge.merge(received)
    if receiver.op_state in [OpState.RELAXED, OpState.PATROLLING]:
        receiver.set_op_state(OpState.TENSE)
```

### 7b. Radio (Precise Broadcast)

Guards with `has_radio = true` can transmit the agent's **exact last known tile**
(`ConfidenceLevel.SEEN`) to all radio-equipped guards in the scene, regardless of distance.
Walls do not block radio. However:

- Radio transmission is audible — it emits a `NoiseEvent` of type RADIO, amplitude 3,
  at the transmitting guard's position. The agent can hear guards about to radio.
- Radio has a 3-turn cooldown per guard.
- Radio is only used when:
  - Guard is in CHASING or ATTACKING state, OR
  - Guard witnesses a body/unconscious ally, OR
  - Guard does not respond to a scheduled radio check-in (see below)

```gdscript
func do_radio_broadcast(guard: Guard) -> void:
    if not guard.has_radio or guard.radio_cooldown > 0: return

    # Emit audible noise first — player can react before info spreads
    var noise = NoiseEvent.new()
    noise.origin_tile = guard.tile
    noise.amplitude = 3
    noise.type = NoiseEvent.NoiseType.RADIO
    NoiseSystem.propagate_noise(noise)

    # Then broadcast knowledge to all radio guards (next turn resolution)
    RadioSystem.broadcast(guard.id, guard.knowledge)
    guard.radio_cooldown = 3

func on_radio_received(receiver: Guard, sender_knowledge: GuardKnowledge) -> void:
    # Radio transmits full SEEN confidence regardless of sender's actual state
    var received = sender_knowledge.duplicate()
    received.confidence = ConfidenceLevel.SEEN
    receiver.knowledge.merge(received)
    if receiver.op_state in [OpState.RELAXED, OpState.PATROLLING, OpState.TENSE]:
        receiver.set_op_state(OpState.ALERT)
```

**Radio Check-in Protocol:**
Every 5 turns, the scene's `RadioSystem` requests a check-in from all radio-equipped guards.
Guards in RELAXED or PATROLLING state respond automatically (no action cost).
If a guard cannot respond (UNCONSCIOUS, DEAD, STUNNED), the RadioSystem flags them as
missing after 1 turn of silence. Any guard that hears the failed check-in transitions
to ALERT and investigates the non-responding guard's last known patrol position.

```gdscript
# RadioSystem.gd
var checkin_interval: int = 5
var pending_checkins: Dictionary = {}   # { guard_id: turns_waiting }

func request_checkins() -> void:
    for guard in get_radio_guards():
        pending_checkins[guard.id] = 1  # expect response within 1 turn

func process_checkins() -> void:
    for guard_id in pending_checkins.keys():
        pending_checkins[guard_id] += 1
        if pending_checkins[guard_id] > 1:
            # Guard did not respond — escalate
            on_guard_missing(guard_id)
            pending_checkins.erase(guard_id)
```

---

## 8. Alarm Panel System

Alarm panels are **interactable scene objects** placed on wall tiles via the level editor.
They are not tile types — they are `Node2D` objects with a tile position reference.

```gdscript
class_name AlarmPanel extends Node2D

var tile_position: Vector2i
var is_active: bool = false
var activation_turns: int = 1       # turns to activate (guard must stay adjacent)
var can_be_disabled: bool = true    # agent can disable before guard reaches it

func activate() -> void:
    if is_active: return
    is_active = true
    AlarmSystem.trigger_global_alarm()
    # Visual: red flashing light, alarm sound effect
    # Audio: NoiseEvent with amplitude = entire scene (all guards wake)
    var event = NoiseEvent.new()
    event.origin_tile = tile_position
    event.amplitude = 999           # scene-wide
    event.type = NoiseEvent.NoiseType.ALARM_PANEL
    NoiseSystem.propagate_noise(event)
```

**Guard behavior toward alarm panels:**

Guards in FLEEING or CALLING_ALARM state pathfind to the nearest reachable alarm panel.
A guard adjacent to a panel uses 1 AP and 1 full turn to activate it (cannot move same turn).
The agent can intercept by knocking out the guard before the turn resolves.

```gdscript
# AlarmSystem.gd
func trigger_global_alarm() -> void:
    for guard in get_all_guards():
        if guard.physical_status == PhysicalStatus.ALIVE:
            if guard.op_state in [OpState.RELAXED, OpState.PATROLLING]:
                guard.set_op_state(OpState.ALERT)
            # Guards already in higher states are unaffected (already alert)
            guard.knowledge.confidence = ConfidenceLevel.HEARD
            guard.knowledge.last_known_area = SceneBounds.get_full_rect()
    SceneState.global_alarm = true
```

**Disabling panels:** The agent can spend 1 AP adjacent to an inactive panel to disable it
permanently for the run. A disabled panel shows a visual indicator (broken/sparking).
Once the global alarm is triggered, panels cannot be disabled retroactively.

---

## 9. Unactivated Guard Behavior

Guards that have never been activated (detection = 0, op_state = RELAXED or PATROLLING)
follow these rules:

- Their movement is **not shown** to the player — the camera does not follow them
- They may emit random `NoiseEvent` of type FOOTSTEP (amplitude 1) with 10% chance per turn
- This noise is shown as a sound-wave visual effect **pointing toward** the noise source,
  visible from the agent's position if within range
- The effect direction helps the player infer where the guard is without revealing position
- Agent noise (walking/running) uses the same system — the guard may react to it
  even without being "shown" to the player

```gdscript
func process_unactivated_guard(guard: Guard) -> void:
    # Random ambient noise
    if randf() < 0.10:
        var event = NoiseEvent.new()
        event.origin_tile = guard.tile
        event.amplitude = 1
        event.type = NoiseEvent.NoiseType.FOOTSTEP
        NoiseSystem.propagate_noise(event)

    # Can still detect agent through FOV — activation happens on detection
    var chance = get_detection_chance(guard, agent.tile)
    if chance > 0.0:
        update_detection(guard, chance)
        if guard.detection > 0.3:
            reveal_guard(guard)     # now shown on screen
            guard.set_op_state(OpState.TENSE)
```

---

## 10. Delayed Activation (1-Turn Reaction Window)

When a guard first becomes aware of the agent (detection crosses 0.3 or noise received),
there is a **1-turn delay** before the guard changes OpState. This gives the agent a
reaction window and prevents instant punishing transitions.

```gdscript
var pending_state_change: OpState = OpState.RELAXED
var state_change_delay: int = 0

func request_state_change(new_state: OpState, delay: int = 1) -> void:
    pending_state_change = new_state
    state_change_delay = delay

func process_state_change() -> void:
    if state_change_delay > 0:
        state_change_delay -= 1
        if state_change_delay == 0:
            set_op_state(pending_state_change)
```

---

## 11. Guard Personality Types

Different guard types modify base parameters. Implemented as a `GuardProfile` resource:

```gdscript
class_name GuardProfile extends Resource

@export var fov_degrees: float = 90.0
@export var peripheral_fov: float = 180.0
@export var detection_gain_multiplier: float = 1.0
@export var decay_rate_multiplier: float = 1.0
@export var patrol_speed: int = 1          # tiles per AP
@export var max_search_turns: int = 6
@export var has_radio: bool = false
@export var will_flee_to_alarm: bool = true
@export var will_whistle: bool = true
@export var courage_threshold: float = 0.0 # health% below which guard flees
```

Suggested profiles for first implementation:

| Profile | FOV | Gain | Decay | Radio | Notes |
|---|---|---|---|---|---|
| Rookie | 70° | 0.7x | 1.5x | No | Easier early levels |
| Standard | 90° | 1.0x | 1.0x | No | Default |
| Veteran | 110° | 1.3x | 0.7x | No | Harder levels |
| Commander | 90° | 1.2x | 0.8x | Yes | Broadcasts on detection |
| Civilian | 60° | 0.5x | 2.0x | No | Flees immediately, triggers alarm |

---

## 12. Implementation Order

```
Phase 1 — Core data (no behavior yet)
  1. GuardKnowledge class + merge/decay logic
  2. NoiseEvent + NoiseSystem.propagate_noise()
  3. Detection meter: get_detection_chance(), update_detection(), decay

Phase 2 — Basic FSM
  4. OpState enum + set_op_state() with delayed transitions
  5. RELAXED → TENSE → SEARCHING → CHASING loop (minimum viable AI)
  6. LOS raycasting using wall edge system
  7. Sweep pattern for SEARCHING

Phase 3 — Communication
  8. Whistle system + on_whistle_received()
  9. Radio system + check-in protocol
  10. Unactivated guard ambient noise + reveal logic

Phase 4 — Alert escalation
  11. AlarmPanel object + CALLING_ALARM state
  12. AlarmSystem.trigger_global_alarm()
  13. FLEEING state pathfinding to alarm panel
  14. Agent alarm panel disable interaction

Phase 5 — Polish and profiles
  15. GuardProfile resource + parameter injection
  16. Peripheral vision cone
  17. Sigmoid detection curve tuning
  18. All visual feedback (sound waves, detection bar, etc.)
```

---

## 13. Key Constraints

- **Mobile-first:** all per-turn processing, no per-frame AI loops. AI resolves during
  the enemy turn only.
- **Godot 4.x GDScript** — no C# or GDExtension
- **No global blackboard** — guards share information only through explicit communication
  events (whistle, radio). This makes information warfare a gameplay mechanic.
- **Serializable state** — GuardKnowledge and all OpState data must be serializable for
  mid-level save support.
- **Wall edge system dependency** — LOS and noise attenuation depend on
  `WallEdgeData.can_see_through()` and `WallEdgeData.get_sound_path_cost()`. These
  functions must be implemented before Phase 2.
- **No concurrent guard actions** — all guards resolve their turns sequentially, not
  simultaneously. Turn order is fixed (e.g. by guard index) to ensure deterministic
  replays and avoid race conditions.
