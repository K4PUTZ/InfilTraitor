# INFILTRAITOR — AI & Guard Behavior

> **Guard FSM, decision-making, communication, and distributed knowledge.**

---

## Overview

Each guard runs an **independent state machine** with layered decision-making:

- **Physical State Layer** — Where am I? What am I doing?
- **Operational State Layer** — What threat am I responding to?
- **Loyalty/Status Layer** — Can I be bribed, intimidated, compromised?

Guards are **distributed actors** — they have no shared global knowledge. Information spreads via explicit communication (whistles, radios).

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

| State | Priority | Behavior | Detection | Duration |
|-------|----------|----------|-----------|----------|
| **PATROL** | Low | Walk assigned route, casual scanning | 0.8× | Indefinite |
| **SUSPICIOUS** | Medium | Active search, investigate sounds/movement | 1.2× | 3–5 turns |
| **ALERT** | High | Heightened awareness, ready to escalate | 1.5× | 1–3 turns |
| **CHASE** | Highest | Pursue target, call for backup, aggressive | 2.0× | Until target lost/dead |
| **SEARCH** | Medium | Systematic search of area, less focused | 0.6× | 2–4 turns |

### State Transitions

#### Patrol → Suspicious
**Triggers:**
- Spot unconfirmed target (~0.15–0.30 probability at 2 tiles)
- Hear moderate noise (intensity 0.25–0.60)
- Find evidence (overturned object, door unlock)

**Duration:** 3–5 turns

#### Suspicious → Alert
**Triggers:**
- Confirm target sighting (confidence ≥ 0.60)
- Hear loud noise (intensity ≥ 0.70)
- Radio call from nearby guard

**Duration:** 1–3 turns

#### Alert → Chase
**Triggers:**
- Full detection (meter ≥ 1.0)
- Direct threat (target moves adjacent)
- Radio broadcast (global alert)

**Duration:** Until target lost or neutralized

#### Chase → Search
**Triggers:**
- Lost line of sight for 2+ turns
- Last-known position unreachable
- Radio call from different location

**Duration:** 2–4 turns

#### Search → Patrol
**Triggers:**
- Find nothing after 4 turns
- No new information
- Manually reset by command

**Duration:** Return to normal patrol

### Communication & State Propagation

When a guard **changes state to SUSPICIOUS or ALERT**, it broadcasts:

- **Whistle** (3-tile radius) — Any guard within 3 tiles hears and escalates
- **Radio** (global) — All guards with radios hear (CHASE state only)

```gdscript
func enter_state(new_state: String) -> void:
    if new_state in [STATE_SUSPICIOUS, STATE_ALERT]:
        if new_state == STATE_ALERT:
            emit_signal("whistle", tile, 3)  # 3-tile radius
        if new_state == STATE_CHASE:
            emit_signal("radio", "ALERT", tile)  # global broadcast
```

---

## Layered Decision Architecture

### Layer Priority

```
PhysicalStatus (bottom)  — Can I move? Am I alive/operational?
        ↓
OpState (middle)         — What's my goal? What threat am I responding to?
        ↓
Loyalty (top)            — Am I trustworthy? Can I be compromised?
        ↓
(Final Decision)         — Execute action
```

### PhysicalStatus Layer

Tracks guard operational readiness:

```gdscript
enum PhysicalStatus { OPERATIONAL, WOUNDED, IMMOBILIZED, ELIMINATED }

# OPERATIONAL: Move and act normally
# WOUNDED: 50% movement speed, +0.30 to detection meter (bleeding sounds)
# IMMOBILIZED: Stunned, cannot move for 2 turns
# ELIMINATED: Guard is out (dead or unconscious)
```

### OpState Layer

Tracks primary objective and threat response:

```gdscript
class OpState:
    var primary_goal: String  # PATROL, INVESTIGATE, PURSUE, DEFEND
    var threat_assessment: float  # 0.0–1.0, confidence in threat
    var last_known_agent_tile: Vector2i
    var communication_status: String  # ISOLATED, HEARING_WHISTLES, ON_RADIO
```

### Loyalty Layer

Tracks guard trustworthiness (future expansion):

```gdscript
class LoyaltyStatus:
    var morale: float  # 0.0–1.0 (1.0 = fully committed)
    var corruption: float  # 0.0–1.0 (0.5+ = can be bribed/turned)
    var fear_level: float  # 0.0–1.0 (fear of agent, mutiny, etc.)
```

---

## Per-State Decision-Making

### PATROL Decision Logic

Each patrol turn, guard decides:

```gdscript
func patrol_decision() -> String:
    # Step 1: Check for threats
    var threat_level = evaluate_threats()
    if threat_level > 0.3:
        return "enter_suspicious"
    
    # Step 2: Move to next waypoint
    var path_to_next = pathfind(tile, next_waypoint)
    if path_to_next.is_empty():
        # Waypoint unreachable, pick new random waypoint
        next_waypoint = get_random_patrol_point()
    else:
        move_along_path(path_to_next, 1)  # Move 1 tile toward waypoint
    
    # Step 3: Spontaneous pause check
    if randf() < 0.20:
        pause_turns = randi_range(1, 2)
        return "pause_and_scan"
    
    return "continue_patrol"
```

### SUSPICIOUS Decision Logic

Guard actively investigates:

```gdscript
func suspicious_decision() -> String:
    # Step 1: Move toward last-known agent location
    if last_known_agent_tile != Vector2i.ZERO:
        var path = pathfind(tile, last_known_agent_tile)
        if not path.is_empty():
            move_along_path(path, 1)
    else:
        # No known location, perform search sweep
        move_toward(get_nearby_search_point())
    
    # Step 2: Active scanning
    perform_scan_sweep()
    
    # Step 3: Check if threat escalates to Alert
    if threat_level > 0.60:
        return "enter_alert"
    
    # Step 4: Decay if no new info
    if suspicion_age > 5:
        return "back_to_patrol"
    
    return "continue_suspicious"
```

### ALERT Decision Logic

Guard is ready for combat:

```gdscript
func alert_decision() -> String:
    # Step 1: Prepare for action (draw weapon, ready)
    ready_for_combat()
    
    # Step 2: Find defensive position
    if not has_line_of_sight_to_last_known():
        var defense_tile = find_cover_position()
        move_toward(defense_tile)
    
    # Step 3: Emit alert signal to nearby guards
    emit_whistle()
    
    # Step 4: Escalate if threat confirms
    if agent_in_line_of_sight:
        return "enter_chase"
    
    return "continue_alert"
```

### CHASE Decision Logic

Guard is in active pursuit:

```gdscript
func chase_decision() -> String:
    # Step 1: Pursue agent's last-known position
    var path_to_agent = pathfind(tile, agent_tile)
    if not path_to_agent.is_empty():
        move_along_path(path_to_agent, 2)  # Move 2 tiles (chase speed)
    else:
        # Blocked, find alternate route
        move_toward(agent_tile)
    
    # Step 2: Global radio alert
    emit_radio_alert()
    
    # Step 3: Coordinate with nearby guards
    coordinate_with_nearby_guards()
    
    # Step 4: If lost line of sight
    if not has_line_of_sight_to_agent():
        return "enter_search"
    
    return "continue_chase"
```

### SEARCH Decision Logic

Guard is searching without direct contact:

```gdscript
func search_decision() -> String:
    # Step 1: Systematic tile-by-tile search
    var search_area = get_search_area(last_known_agent_tile, 5)
    var next_search_tile = get_next_search_tile(search_area)
    move_toward(next_search_tile)
    
    # Step 2: Periodic scan
    if search_turns % 2 == 0:
        perform_scan_sweep()
    
    # Step 3: If agent found
    if agent_in_line_of_sight:
        return "enter_chase"
    
    # Step 4: Give up if search fruitless
    if search_turns >= 4 and not new_evidence:
        return "back_to_patrol"
    
    return "continue_search"
```

---

## Communication System

### Whistle Propagation

```gdscript
func emit_whistle(origin_tile: Vector2i, radius: int = 3) -> void:
    for tile in get_tiles_in_radius(origin_tile, radius):
        if not is_cell_inside_room(tile):
            continue
        
        # Find guard at tile
        var guard_at_tile = get_guard_at(tile)
        if guard_at_tile and guard_at_tile != self:
            # Immediate escalation
            if guard_at_tile.state == STATE_PATROL:
                guard_at_tile.enter_state(STATE_SUSPICIOUS)
            elif guard_at_tile.state == STATE_SUSPICIOUS:
                guard_at_tile.enter_state(STATE_ALERT)
            
            # Broadcast whistle further (chain reaction)
            if radius > 1:
                guard_at_tile.emit_whistle(tile, radius - 1)
```

### Radio Broadcast

```gdscript
func emit_radio_alert(reason: String) -> void:
    # Global broadcast to all guards
    for guard in all_guards:
        if guard == self:
            continue
        
        # All guards enter ALERT or CHASE
        if reason == "AGENT_SPOTTED":
            guard.receive_radio({"type": "THREAT", "location": agent_tile})
            guard.enter_state(STATE_CHASE)
        elif reason == "GUARD_DOWN":
            guard.receive_radio({"type": "ALARM", "location": self.tile})
```

---

## Knowledge Model (Distributed)

### GuardKnowledge Class

Each guard maintains personal knowledge:

```gdscript
class GuardKnowledge:
    var agent_last_seen_tile: Vector2i = Vector2i.ZERO
    var agent_confidence: int  # 0=none, 1=heard, 2=seen
    var confidence_age: int = 0  # turns since last update
    var known_gadgets: Array = []  # observed items
    var suspected_capabilities: Array = []  # guessed abilities
```

### Knowledge Merge (After Communication)

When guards whistle or radio, they share knowledge:

```gdscript
func merge_knowledge(other_guard: Guard) -> void:
    # Only merge if other guard has more recent info
    if other_guard.knowledge.confidence_age < self.knowledge.confidence_age:
        self.knowledge = other_guard.knowledge.duplicate()
        self.knowledge.confidence_age += 1  # Mark as slightly stale
```

### Knowledge Decay

Knowledge decays if unconfirmed:

```gdscript
func decay_knowledge() -> void:
    knowledge.confidence_age += 1
    
    if knowledge.agent_confidence == 2:  # SEEN
        if knowledge.confidence_age >= 3:
            knowledge.agent_confidence = 1  # Downgrade to HEARD
    elif knowledge.agent_confidence == 1:  # HEARD
        if knowledge.confidence_age >= 5:
            knowledge.agent_confidence = 0  # Forget (NONE)
```

---

## Multi-Guard Coordination

### Implicit Coordination (No Shared Plan)

Guards do not have a "master plan" — they coordinate implicitly:

1. **Whistle spreads alert** → nearby guards escalate
2. **Radio maintains awareness** → all guards know threat exists
3. **Each guard acts independently** → based on own perception
4. **Emergent coordination** → guards naturally converge on agent

### Example: Multi-Guard Trap

```
Turn 1: Agent moves near Guard A
Turn 2: Guard A spots agent, enters SUSPICIOUS, whistles
Turn 3: Guard B (within 3 tiles) hears whistle, enters ALERT
        Guard A enters CHASE, moves toward agent
        Guard B predicts agent's escape route, moves to intercept
Turn 4: Agent caught between Guard A and Guard B
```

---

## Guard Variance & Personality (Future)

### Variance Parameters

Future guards will have personalities:

```gdscript
class GuardPersonality:
    var aggression: float  # 0.0 = cautious, 1.0 = reckless
    var intelligence: float  # 0.0 = dumb, 1.0 = clever
    var patience: float  # 0.0 = trigger-happy, 1.0 = thorough
    var discipline: float  # 0.0 = independent, 1.0 = obedient
```

- **Aggressive guards** escalate faster (thresholds lower)
- **Intelligent guards** share knowledge more effectively
- **Patient guards** conduct thorough searches
- **Disciplined guards** follow protocols strictly

---

## Constants Reference

```gdscript
# State machine
const STATE_PATROL = "patrol"
const STATE_SUSPICIOUS = "suspicious"
const STATE_ALERT = "alert"
const STATE_CHASE = "chase"
const STATE_SEARCH = "search"

# Transitions
const SUSPICIOUS_THRESHOLD := 0.30
const ALERT_THRESHOLD := 0.60
const CHASE_THRESHOLD := 1.00
const SUSPICIOUS_DECAY := 0.05  # per turn
const ALERT_DECAY := 0.10  # per turn

# Detection multipliers (by state)
const STATE_DETECTION_MULTIPLIER = {
    "patrol": 0.80,
    "suspicious": 1.20,
    "alert": 1.50,
    "chase": 2.00,
    "search": 0.60,
}

# Communication ranges
const WHISTLE_RADIUS := 3
const RADIO_RANGE := "global"

# Knowledge decay
const KNOWLEDGE_SEEN_DECAY := 3  # turns before downgrade to HEARD
const KNOWLEDGE_HEARD_DECAY := 5  # turns before downgrade to NONE
```

---

## See Also

- `docs/systems/perception.md` — How guards perceive threats
- `docs/systems/noise.md` — Audio communication and alerts
- `docs/systems/movement.md` — Turn order and guard sequencing
- `DEVELOPMENT/Concept/infiltraitor_enemy_ai_system.md` — Historical design (legacy)

---

**Last Updated:** 2026-06-11  
**Maintained By:** AI Programmer  
**Status:** Active 🟢
