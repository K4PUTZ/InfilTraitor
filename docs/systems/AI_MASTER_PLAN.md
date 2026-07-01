# INFILTRAITOR — AI & Guard Behavior Master Plan

> **Canonical specification for guard FSM, detection, and communication.**

This is the definitive reference for guard artificial intelligence, perception, and inter-guard communication. See OPERATOR_CONTEXT for architectural invariants and development workflow.

---

## Guard State Machine (FSM)

### Five Core States

```
PATROL ←→ SUSPICIOUS ←→ ALERT → CHASE
  ↓
SEARCH
  ↓
(back to PATROL or SUSPICIOUS)
```

| State | Priority | Behavior | Detection Mult | Duration |
|-------|----------|----------|-----------------|----------|
| **PATROL** | 0 (Low) | Walk assigned route, casual scanning | 0.55× | Indefinite |
| **SUSPICIOUS** | 1 (Medium) | Active search, investigate sounds/movement | 1.60× | 3–5 turns |
| **SEARCH** | 2 (Medium-High) | Systematic search of area, less focused | 0.80× | 2–4 turns |
| **ALERT** | 3 (High) | Heightened awareness, ready to escalate | 2.00× | 1–3 turns |
| **CHASE** | 4 (Highest) | Pursue target, call for backup, aggressive | 2.80× | Until target lost/dead |

**State Priority Rule:** Never downgrade from a higher state (e.g., once in CHASE, cannot return to ALERT or SUSPICIOUS without exiting CHASE).

### State Transition Rules

#### Patrol → Suspicious
**Triggers:**
- Spot unconfirmed target (raw probability 0.15–0.30 at 2 tiles)
- Hear moderate noise (intensity 0.25–0.60)
- Find evidence (overturned object, door unlock)

**Duration:** 3–5 turns (timer: `TIMER_SUSPICIOUS_TO_PATROL := 4`)

#### Suspicious → Alert
**Triggers:**
- Confirm target sighting (detection meter ≥ 0.60)
- Hear loud noise (intensity ≥ 0.70)
- Radio call from nearby guard (whistles)

**Duration:** 1–3 turns

#### Alert → Chase
**Triggers:**
- Full detection (meter ≥ 1.00)
- Direct threat (target moves adjacent)
- Global radio broadcast from other guard

**Duration:** Until target lost or neutralized
**Timer:** `TIMER_ALERT_TO_CHASE := 3`

#### Chase → Search
**Triggers:**
- Lost line of sight for 2+ turns
- Last-known position unreachable
- Radio call from different location

**Duration:** 2–4 turns
**Timer:** `TIMER_CHASE_TO_SEARCH := 3`

#### Search → Patrol (or Suspicious)
**Triggers:**
- Find nothing after 4 turns
- No new information
- Manual reset by game event

**Duration:** Return to normal patrol
**Timer:** `TIMER_SEARCH_TO_SUSPICIOUS := 2`

#### Any → Suspicious (via noise)
**Triggers:**
- Auditory detection above thresholds

**Timers:**
- `TIMER_NOISE_SUSPICIOUS := 3` (loud noise)
- `TIMER_NOISE_SUSPICIOUS_MED := 2` (medium noise)

---

## Visual Detection (TicSystem)

### Detection Tuning

**FOV Distance Curve** — probability falloff by distance:
```
FOV_DISTANCE_CURVE: [1.00, 1.00, 0.95, 0.88, 0.70, 0.48, 0.20, 0.06, 0.01]
```
Index = tile distance from guard (0–8).

**FOV Lateral Falloff** — probability by column offset from central axis:
```
FOV_LATERAL_FALLOFF: [1.0, 0.50, 0.10]
```
- Index 0: center column (±0 tiles)
- Index 1: adjacent columns (±1 tiles from center)
- Index 2: far columns (±2 tiles from center)

**State-Based Detection Multipliers:**
```
patrol:     0.55× (range 4, fov 70°,  alpha 0.40)
suspicious: 1.60× (range 6, fov 90°,  alpha 0.80)
search:     0.80× (range 5, fov 120°, alpha 0.70)
alert:      2.00× (range 7, fov 100°, alpha 0.95)
chase:      2.80× (range 7, fov 110°, alpha 1.00)
```

**Detection Gain:**
```
DETECTION_GAIN_PER_TIC: 0.4
```
When the agent is visible, detection accumulates: `detection += raw_chance * DETECTION_GAIN_PER_TIC`

**Detection Decay:**
```
When agent is outside detection cone, decay is applied via _get_detection_decay()
```

### Detection Thresholds

State transitions are triggered when `guard.detection` meter crosses these values:

```gdscript
DETECTION_THRESHOLD_SUSPICIOUS := 0.30
DETECTION_THRESHOLD_ALERT      := 0.60
DETECTION_THRESHOLD_CHASE      := 1.00
```

### Detection Multipliers

Environmental and tactical modifiers:

```
Direct shadow (SHADOW_MULT):    0.30×   (tile blocked by full shadow)
Penumbra (PENUMBRA_MULT):       0.55×   (shadow edge)
Agent posture (DebugAgent.POSTURE_DETECTION_MULT):
    STANDING:    1.0×
    CROUCHING:   <1.0× (user-configurable)
Cover FULL:                     DebugAgent.COVER_FULL_MULT
Cover PARTIAL:                  DebugAgent.COVER_PARTIAL_MULT
Cover flanking:                 Guard in exposed arc ignores cover (dot product of direction)
```

### Guard Vision Cone

Vector-based, per-tile, color-coded by detection probability (red = high risk → green = low):

| State | Range | FOV | Alpha | Color Mode |
|-------|-------|-----|-------|-----------|
| Patrol | 4 tiles | 70° | 0.40 | Blue (low) → Green (medium) |
| Suspicious | 6 tiles | 90° | 0.80 | Yellow (medium) |
| Search | 5 tiles | 120° | 0.70 | Yellow-Orange (medium-high) |
| Alert | 7 tiles | 100° | 0.95 | Orange (high) |
| Chase | 7 tiles | 110° | 1.00 | Red (highest) |

---

## Auditory Detection (NoiseSystem + TicSystem.evaluate_audio)

### Noise Generation

**From player movement:**
```
NOISE_CHANCE_WALK:    0.20   (20% chance per walk tile)
NOISE_INTENSITY_WALK: 0.5    (intensity 0–1)
NOISE_DECAY_PER_TURN: 0.25   (tile cleared after ~4 turns: 4 × 0.25 = 1.0)
```

**Guard movement noise (by state):**
```
GUARD_NOISE_CHANCE_BY_STATE:
    patrol:     [chance, intensity]
    suspicious: [higher chance, higher intensity]
    ...
```

### Noise Propagation

```
NOISE_RADIUS:  2 tiles (grid propagation via NoiseSystem)
HEARING_RADIUS: 2 tiles (guard perception radius in TicSystem.evaluate_audio)
Wall attenuation: 0.6× per wall crossed
```

### Noise Detection Thresholds

In `guard.hear_noise(noise_tile, perceived_intensity)`:

```gdscript
if perceived_intensity >= 0.60:
    → enter STATE_SUSPICIOUS + update last_known_cell
if perceived_intensity >= 0.25:
    → enter STATE_SUSPICIOUS (no last_known)
if perceived_intensity < 0.25:
    → ignored
```

---

## Guard-to-Guard Communication

Routed exclusively via signals in `room.gd` — never direct guard-to-guard.

### Signal Flow

```gdscript
guard.whistled → _on_guard_whistled
    ↓
guards ≤ 3 tiles away receive whistle
    ↓
enter STATE_SEARCH (escalate from SUSPICIOUS or lower)

guard.radioed → _on_guard_radioed
    ↓
all guards in room receive radio
    ↓
enter STATE_ALERT

_on_guard_alarmed
    ↓
all guards in room
    ↓
enter STATE_CHASE
```

**When signals are emitted:**
- `whistled` — emitted in `_enter_state()` when entering ALERT
- `radioed` — emitted in `_enter_state()` when entering CHASE
- `alarmed` — game event, fires globally when agent is detected with high certainty

---

## Guard Object Public API

### Setup Methods

```gdscript
func setup(tile_layer: TileMapLayer, offset: Vector2, id: String,
           route: Array[Vector2i], start_index: int = 0) -> void
    ## Initialize guard with starting route

func set_los_data(blocked_cells: Array[Vector2i], blocked_edges: Dictionary,
                  room_size: Vector2i, shadow_tiles: Dictionary) -> void
    ## Set the LoS, wall, and shadow data for pathfinding

func set_dev_vision(enabled: bool) -> void
    ## Enable/disable DEV_VISION mode (debug overlay)
```

### Detection Methods

```gdscript
func evaluate_detection(player_cell: Vector2i, vision_range: int,
                       blocked_cells: Array[Vector2i], blocked_edges: Dictionary,
                       close_warning_range: int, agent_ref: Node) -> Dictionary
    ## Returns: {detected: bool, visible: bool, raw_chance: float, angle_ratio: float, distance: int}

func observe_player(visible: bool, severity: int, player_cell: Vector2i) -> void
    ## severity 1 → SUSPICIOUS · 2 → ALERT · 3 → CHASE
    ## Never downgrades state

func hear_noise(noise_tile: Vector2i, perceived_intensity: float) -> void
    ## Process auditory detection
```

### Movement Methods

```gdscript
func choose_next_cell(occupied_cells: PackedVector2iArray,
                     blocked_cells: Array[Vector2i], blocked_edges: Dictionary,
                     player_cell: Vector2i, room_size: Vector2i) -> Vector2i
    ## Returns next cell for A* pathfinding

func move_to_cell_animated(new_cell: Vector2i, blocked_cells: Array[Vector2i],
                          blocked_edges: Dictionary, room_size: Vector2i) -> void
    ## ⚠️ FIRE-AND-FORGET: await returns immediately
```

### State Methods

```gdscript
func receive_alert(known_cell: Vector2i, target_state: String) -> void
    ## Force state to target_state with known cell

func tick_state() -> void
    ## Process state timers, de-escalation, etc.

func reset_to_route_start() -> void
    ## Reset to initial patrol route
```

---

## Turn Flow

```
AGENT TURN
  agent.step()
    ├─ emit step_finished signal
    ├─ TicSystem.evaluate() for each guard (before movement)
    │   → _apply_tic_result()
    ├─ NoiseSystem.emit() — 20% chance per walk
    └─ _process_audio_detection() — immediate auditory tic

ENEMY PHASE
  _process_audio_detection()
    ├─ persistent noises affect all guards
    └─ update guard.detection meters

  for each guard:
    TicSystem.evaluate() (tic before movement)
      → _apply_tic_result()
    
    guard.choose_next_cell(...) → pathfind
    guard.move_to_cell_animated(...) (await finishes)
    
    guard emits noise (GUARD_NOISE_CHANCE_BY_STATE)
    
    TicSystem.evaluate() (tic after movement)
      → _apply_tic_result()
    
    guard.tick_state()

  NoiseSystem.decay_all()
  turn_manager.finish_enemy_phase()
```

---

## Architectural Rules (Inviolable)

1. **Rule 4: Guard state transitions via `_enter_state()` only**
   - Never assign `state =` directly outside `_enter_state()`
   - State transitions are guarded, logged, and signal-emitting

2. **Communication via signals, never direct guard-to-guard**
   - All communication routed through `room.gd`
   - Enables centralized logging, testing, and future networked scenarios

3. **`_alert_meter` accumulates only in `_apply_tic_result()`**
   - Do not accumulate the global alert anywhere else in code
   - Single point of control for alert progression

---

## Related Documentation

- **OPERATOR_CONTEXT** — Development handbook with architectural invariants
- **ARCHITECTURE.md** — High-level system relationships
- **docs/systems/perception.md** — Visual detection details (FOV, LOS, geometry)
- **docs/systems/noise.md** — Audio propagation mechanics
- **docs/systems/movement.md** — Grid navigation and A\* pathfinding
