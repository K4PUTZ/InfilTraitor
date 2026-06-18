# INFILTRAITOR — Animation Pipeline & Roadmap

> **Character animation, state transitions, and visual feedback.**

---

## Animation Categories

---

## 1. Guard Animations (High Priority)

### Idle States

| Animation | Frames | Status | ETA | Trigger |
|-----------|--------|--------|-----|---------|
| **Idle standing** | 1 | Design | This sprint | Default |
| **Idle scanning** | 8–12 | Design | This sprint | Patrol state |
| **Idle alert** | 6–8 | Design | Next sprint | Alert state |
| **Idle injured** | 6 | Design | Combat phase | Wounded |

### Movement

| Animation | Frames | Speed | Status | ETA | Notes |
|-----------|--------|-------|--------|-----|-------|
| **Walk (normal)** | 4–6 | 1.0× | Design | This sprint | PATROL speed |
| **Walk (brisk)** | 6–8 | 1.5× | Design | Next sprint | SUSPICIOUS speed |
| **Walk (running)** | 8–10 | 2.0× | Design | Next sprint | CHASE speed |
| **Walk (careful)** | 6–8 | 0.7× | Design | Combat phase | Stealthy |

### State Transitions

| Animation | Frames | Status | ETA | Trigger |
|-----------|--------|--------|-----|---------|
| **Alert reaction** | 6–8 | Design | Next sprint | PATROL → SUSPICIOUS |
| **Combat readiness** | 8 | Design | Combat phase | → ALERT |
| **Surrender** | 4–6 | Design | Combat phase | Defeated |
| **Pain reaction** | 4 | Design | Combat phase | Hit |

### Combat (Post-GAME-01)

| Animation | Frames | Status | ETA |
|-----------|--------|--------|-----|
| **Melee attack** | 8–12 | Planned | M4-01 |
| **Ranged attack** | 10–14 | Planned | M4-01 |
| **Dodge/roll** | 8–10 | Planned | M4-01 |
| **Death** | 12–16 | Planned | M4-01 |

---

## 2. Agent (Player) Animations (Medium Priority)

### Idle & Movement

| Animation | Frames | Status | ETA | Notes |
|-----------|--------|--------|-----|-------|
| **Idle (standing)** | 1 | Tweening | Current | Basic, no sprite |
| **Walking** | Tweening | Tweening | Current | Position lerp |
| **Running** | Tweening | Tweening | Combat phase | Faster lerp |
| **Crouching** | 1 | Design | Combat phase | Reduced profile |

### Interaction

| Animation | Frames | Status | ETA |
|-----------|--------|--------|-----|
| **Interacting with door** | 8–12 | Planned | M3-02 |
| **Hacking terminal** | 10–14 | Planned | M3-02 |
| **Using gadget** | 6–10 | Planned | M3-01 |
| **Taking damage** | 4–6 | Planned | Combat phase |

### Combat (Post-GAME-01)

| Animation | Frames | Status | ETA |
|-----------|--------|--------|-----|
| **Melee attack** | 8–12 | Planned | M4-01 |
| **Ranged attack** | 10–14 | Planned | M4-01 |
| **Dodge** | 8–10 | Planned | M4-01 |
| **Death** | 12–16 | Planned | M4-01 |

---

## 3. Visual Effects & Feedback (Low Priority)

### Detection Indicator Animations

| Effect | Status | ETA | Trigger |
|--------|--------|-----|---------|
| **Exclamation mark** | Not started | M6-03 | Alert state |
| **Question mark** | Not started | M6-03 | Suspicious state |
| **Particle burst** | Not started | M6-03 | Full detection |
| **Red vignette** | Not started | M6-03 | Chase state |

### Gadget Usage

| Effect | Status | ETA | Gadget |
|--------|--------|-----|--------|
| **Smoke puff** | Particle system | Next sprint | Smoke Bomb |
| **Electric spark** | Particle system | Combat phase | EMP |
| **Decoy sparkle** | Particle system | Combat phase | Decoy |
| **Flashbang flash** | Screen effect | Combat phase | Flashbang |

---

## 4. UI Animations (Low Priority)

| Animation | Status | ETA | Context |
|-----------|--------|-----|---------|
| **AP meter tick** | Not started | M6-01 | Turn display |
| **Detection meter fill** | Not started | M6-01 | Tension building |
| **Button hover** | Not started | M6-01 | UI feedback |
| **Menu transition** | Not started | M6-01 | Screen change |

---

## Animation Asset Pipeline

### 1. Design Phase
- Concept art (pose sheets)
- Movement beats (keyframe breakdown)
- Timing guidelines
- Reference video (optional)

### 2. Sprite Creation
- Main sprite sheet (outline/color)
- Frame per pose
- Consistent pixel dimensions
- Grid alignment

### 3. Import to Godot
- TileSet or SpriteFrames resource
- Animation Library setup
- Frame timing
- Loop settings

### 4. Integration
- Link to AnimatedSprite2D nodes
- State machine activation
- Transition triggers
- Performance optimization

### 5. Polish
- Motion interpolation (easing)
- Sound effect sync
- Visual juice (screen shake, particle sync)
- Accessibility (seizure-safe, no strobing)

---

## Sprite Guidelines

### Resolution
- **Base:** 64×64 pixels (guard)
- **Agent:** 48×48 pixels (player-sized)
- **Scale:** Isometric projection maintains proportions

### Frame Count (Typical)
- **Idle:** 1 frame
- **Walk cycle:** 4–6 frames
- **Action:** 6–12 frames
- **Reaction:** 4–8 frames

### Color Palette
- **Guards:** Faction-specific colors (gray, black, red trim)
- **Agent:** Dark tactical gear (navy, black)
- **Effects:** Bright accent colors (yellow, red, cyan)

### Animation Frame Timing
- **Idle:** 0.1–0.2 seconds per frame
- **Walk:** 0.15–0.25 seconds per frame
- **Combat:** 0.08–0.15 seconds per frame (faster)
- **Effects:** 0.05–0.10 seconds per frame (snappy)

---

## State-to-Animation Mapping

### Guard FSM States

```
STATE_PATROL
  ├─ Idle Scanning (looping)
  ├─ Walking (normal speed)
  ├─ → STATE_SUSPICIOUS transition (alert reaction)

STATE_SUSPICIOUS
  ├─ Idle Alert (looping)
  ├─ Walking (brisk speed)
  ├─ → STATE_ALERT transition (ready stance)

STATE_ALERT
  ├─ Combat Readiness (held)
  ├─ Walking (brisk speed)
  ├─ → STATE_CHASE transition (sprint)

STATE_CHASE
  ├─ Walking (running speed)
  ├─ Can trigger ranged attack (future)
  ├─ → STATE_SEARCH transition (halt, look around)

STATE_SEARCH
  ├─ Idle Scanning (looping, faster)
  ├─ Walking (normal speed, systematic)
  ├─ → back to PATROL (calm down)
```

### Agent FSM States

```
IDLE
  ├─ Idle Standing (looping)

MOVING
  ├─ Walking animation (direction-aware)

INTERACTING
  ├─ Interaction animation (door unlock, hacking, etc.)

ALERT (player detected)
  ├─ Alert Reaction

DEAD (combat phase)
  ├─ Death animation
```

---

## Animation Integration Timeline

### This Sprint (M2-14)
- ✅ Guard idle & walk sprites (design)
- ✅ State machine integration (framework)
- 🟡 Import to Godot (first pass)

### Next Sprint (M2-15)
- ⏳ Guard alert & combat readiness
- ⏳ Agent animations (sprites + integration)
- ⏳ Transition effects

### Combat Phase (M4-01)
- ⏳ Combat animations (attacks, dodges, death)
- ⏳ Blood/impact effects

### Polish Phase (M6-03)
- ⏳ Motion smoothing & easing
- ⏳ Sound sync
- ⏳ Visual juice (screen shake, particles)
- ⏳ Accessibility review

---

## Animation Performance

| Metric | Target | Current |
|--------|--------|---------|
| **Animation frame rate** | 60 FPS | Unknown |
| **Sprite memory** | <2 MB per character | TBD |
| **Simultaneous animations** | 10+ without stuttering | TBD |
| **GC pressure** | <1 ms per frame | TBD |

---

## Outsourcing Considerations

### If Contracting Animator
- Provide character design guidelines
- Provide pose sheet template
- Provide reference video (if available)
- Specify frame count and timing
- Test sprites in engine before final delivery

### Budget Estimate
- Guard animations (basic): $500–$1000
- Agent animations (basic): $300–$500
- Combat animations (advanced): $1500–$2500
- Total: $2300–$4000

---

## Animation Accessibility

| Feature | Status | ETA |
|---------|--------|-----|
| **Seizure-safe (no strobing)** | Planned | M6-04 |
| **Motion sickness opt-out** | Planned | M6-04 |
| **Colorblind modes** | Planned | M6-04 |

---

**Last Updated:** 2026-06-11  
**Maintained By:** Animation Director  
**Status:** Design Phase 🟡
