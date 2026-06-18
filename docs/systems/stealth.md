# INFILTRAITOR — Stealth & Evasion

> **Fog of war, cover mechanics, and tactical positioning.**

---

## Overview

Stealth is a **layered system** combining fog of war, shadow cover, movement patterns, and guard behavior to create spaces where the agent can hide, plan, and strike. Success depends on managing **information asymmetry** — remaining unseen while learning guard patterns.

---

## Fog of War (FOW)

### Three-Layer FOW System

The fog of war uses three visual states:

| State | Appearance | Mechanics | Reveals |
|-------|-----------|-----------|---------|
| **Unseen** | Black/opaque | No information | Nothing |
| **Peek** | Faded/translucent | Limited info visible | Tile contents, nearby enemies |
| **Revealed** | Full brightness | Complete information | Everything on tile |

### Revealment Rules

Tiles transition through FOW states based on **line of sight** from the agent:

```gdscript
# During player phase, for each visible tile:
if has_line_of_sight(agent.tile, target_tile):
    if manhattan_distance(agent.tile, target_tile) <= 1:
        fow_layer.set_cell(target_tile, REVEALED)  # adjacent = full reveal
    else:
        fow_layer.set_cell(target_tile, PEEK)  # distance = peek
else:
    if not fow_layer.was_revealed_before(target_tile):
        fow_layer.set_cell(target_tile, UNSEEN)  # out of LOS = fog
```

### Persistence
- **Revealed tiles never go back to fog** — once seen, always remembered
- **Peek state persists** if tile is within visual range but not directly adjacent
- **Unseen tiles** revert if line of sight is broken

### Memory
Player builds a **permanent map memory** as they explore:
- Walls are permanent (seen once = remembered)
- Terrain features are permanent
- Guard positions change (memory is stale)

---

## Shadow Cover

### Shadow as Tactical Asset

Shadows (from `lighting.md`) are **not cosmetic** — they actively reduce detection:

**Shadow zones:**
- **Direct shadow** (0.30× multiplier) — Very safe, heavily preferred
- **Penumbra** (0.55× multiplier) — Moderately safe
- **Open floor** (1.00× multiplier) — Exposed

### Strategic Shadow Use

```
Layout:        Detection Chance:
Wall           Direct Shadow (0.30×)
███ ■ Agent    From nearby guard: 5% (normally 16%)
   ▓ ▓ ▓
   ▓ ▓ ▓       Penumbra (0.55×)
   ▓ ▓ ▓       From nearby guard: 9%
```

Players naturally move along walls and through shadowed areas to minimize detection probability.

---

## Movement Patterns & Detection

### Stationary vs. Mobile

| State | Detection | Notes |
|-------|-----------|-------|
| **Waiting in shadow** | Very low (0.30×) | Safe default |
| **Moving slowly** | Low (0.40–0.60×) | Footsteps emit noise |
| **Moving quickly** | Medium (0.70–0.90×) | More noise, more visible |
| **Running** | High (1.00×) | Maximum detection risk |

### Turn-Based Evasion

Since movement is **discrete (turn-based)**, players can wait for guard attention to shift:

```
Turn 1: Agent waits in shadow (guard looking elsewhere)
Turn 2: Guard pauses, turns head — Agent moves during pause
Turn 3: Guard moves to new patrol point — Agent follows in shadows
Turn 4: Agent reaches exit safely
```

---

## Detection Avoidance Strategies

### Strategy 1: Shadow Lanes

Move along walls and through shadowed areas:
- Reduces detection from 16% to 5% on each visible tile
- **Cost:** Slower, longer path
- **Benefit:** Near-zero risk

### Strategy 2: Guard Timing

Study patrol patterns and move during gaps:
- Observe guard movement for 2–3 turns
- Note when they look away or pause
- Move during blind moment
- **Cost:** Requires time investment
- **Benefit:** Direct path, quick execution

### Strategy 3: Noise Masking

Use enemy activity to mask own movement:
- Guard walks, emits noise (0.40 intensity)
- Agent moves at same time, footsteps masked
- Combined noise = no extra alert
- **Cost:** Requires enemy proximity
- **Benefit:** Freedom from noise detection

### Strategy 4: Diversions

Create noise on one side while moving through opposite:
- Use gadget (smoke bomb) on eastern side
- Guards investigate noise
- Agent moves west safely
- **Cost:** Gadget charge, attention
- **Benefit:** Escape pressure

---

## Cover Mechanics (Future)

### Wall-Adjacent Cover

Standing directly adjacent to walls provides **tactical cover**:

```
Layout:        Benefit:
███ Agent      Cover against guards on opposite side
```

**Planned features:**
- Reduce detection from certain angles
- Peek around corners
- Fire from cover (post-GAME-01 combat)

---

## Visibility & Detection Probability

### Visible Tiles (During Player Turn)

The agent can always see adjacent tiles and tiles within their vision cone. These are marked visually:

```gdscript
# Agent's visible tiles each player turn:
var visible = get_vision_cone(agent.tile, AGENT_FOV_RANGE)
visible.append_array(get_adjacent_tiles(agent.tile))

# Mark these tiles with "you can see this" indicator
for tile in visible:
    debug_overlay.mark_visible(tile, true)
```

### Enemy Detection Likelihood (For Player)

When planning a move, the player should see **how dangerous** each tile is:

1. **Color coding:**
   - Blue = Safe (low detection chance)
   - Yellow = Risky (medium detection)
   - Red = Dangerous (high detection)

2. **Based on:**
   - Distance to nearest guard
   - Guard state (patrol vs. alert)
   - Shadow coverage
   - Recent noise

---

## Silently Reaching Objectives

### Silent Takedown (Combat-Free)

The agent can perform a **silent takedown** from adjacent tile if:
- Guard is **undetected** or has low detection meter (<0.30)
- Agent is in shadow or directly behind guard
- Takes 1 AP

**Outcome:** Guard is neutralized without raising alarm (if undetected)

### Avoiding Alarms

To avoid escalation:
- Don't raise alarm (stay below 0.30 detection)
- Use gadgets to break line of sight (smoke bomb)
- Eliminate guards before they escalate (combat or takedown)
- Move during guard pauses
- Use shadows

---

## Failure & Escalation

### Detection Escalation

As detection meter increases:

```
0.00–0.30  → Undetected (Agent safe)
0.30–0.50  → Suspicious (Guard active, looking)
0.50–0.70  → Alert (Guard on edge, may whistle)
0.70–1.00  → Chase (Full detection, radio alarm, pursuit)
```

### What Happens When Detected

1. **Detection ≥ 1.0 → Full Detection → Alarm**
2. Guard enters CHASE state
3. Guard whistles (3-tile radius, alerts nearby guards)
4. Guards with radios broadcast global alert
5. **Player choice:**
   - Escape before surrounded (fight or flight)
   - Use gadget to break LOS (smoke bomb)
   - Trigger traps to block pursuers
   - Combat engagement (not recommended)

### Recovery After Detection

Once detected, de-escalation is possible but **difficult**:

- Eliminate all hostile guards in area
- Move far away and hide in deep shadows
- Wait for guard suspicion to decay
- Use specific gadgets (flashbangs, EMP) to scatter guards
- Exit the room to "reset" threat level

---

## Information Gathering Phase

### Safe Scouting

Players can spend turns **scouting** rather than acting:

1. Move to vantage point (often high risk first time)
2. Observe guard patterns for 2–3 turns
3. Note patrol cycles, pause times, rotation speeds
4. Plan route through discovered "blind spots"

**Time cost:** 3–5 turns per scouting phase  
**Benefit:** Near-perfect certainty of guard positions

---

## Constant Vigilance

### Guards Never Stop Perceiving

Key design principle: **Guards perceive the world every turn**, even when not directly looking at agent:

- Peripheral vision catches movement
- Audio perception works without seeing
- Communication shares information
- Suspicion meters accumulate slowly

**Design goal:** Stealth is not "invisible mode" — it's a **constant dance** between staying ahead of perception.

---

## See Also

- `docs/systems/perception.md` — How detection actually works
- `docs/systems/lighting.md` — Shadow mechanics and tactical positioning
- `docs/systems/movement.md` — Turn-based movement and AP economy
- `docs/systems/ai.md` — How guards react to threats

---

**Last Updated:** 2026-06-11  
**Maintained By:** Design Lead  
**Status:** Active 🟢
