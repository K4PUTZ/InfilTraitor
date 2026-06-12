# INFILTRAITOR — Technical Debt & Maintenance

> **Known limitations, architectural issues, and maintenance requirements.**

---

## Definition

Technical debt is code/architecture that:
- Compromises scalability
- Reduces maintainability
- Creates bugs or instability
- Limits future features

**Debt ≠ Backlog.** Debt is unfinished work that blocks progress.

---

## Critical Debt 🔴

### 1. FSM Scaling Risk
**Severity:** HIGH  
**Impact:** HIGH  
**Estimated Fix:** 1–2 weeks

**Problem:**  
Guard FSM (5 states + transitions) is manageable now, but will explode with:
- Personality variance
- Faction-specific states
- Learning behaviors
- Cooperative tactics

**Current Code:**
```gdscript
match guard.state:
    STATE_PATROL: patrol_decision()
    STATE_SUSPICIOUS: suspicious_decision()
    STATE_ALERT: alert_decision()
    STATE_CHASE: chase_decision()
    STATE_SEARCH: search_decision()
```

**Problem:** Adding 10+ more states will make this unmaintainable.

**Solution (Queued):**
- Refactor to Strategy pattern or behavior tree
- Decouple state logic into individual classes
- Enable composition of behaviors

**Timeline:** Post-M2-15, pre-M3.00

---

### 2. Hardcoded Patrol Timings
**Severity:** HIGH  
**Impact:** MEDIUM  
**Estimated Fix:** 3–5 days

**Problem:**  
Guard patrol patterns are hardcoded in room layout:
```gdscript
const PATROL_POINTS = [
    Vector2i(5, 5), Vector2i(15, 5), 
    Vector2i(15, 15), Vector2i(5, 15)
]
const PATROL_SPEED_MODIFIER = 0.60
```

**Issues:**
- Cannot change patrols without code recompile
- No procedural patrol generation
- Mission designers blocked

**Solution (Queued):**
- Move patrols to layout configuration
- Add data-driven patrol system
- Enable per-room customization

**Timeline:** M3-00 (Objectives & Missions)

---

### 3. Overlay Performance on Large Maps
**Severity:** HIGH  
**Impact:** MEDIUM  
**Estimated Fix:** 1–2 weeks

**Problem:**  
Movement overlay (Dijkstra visualization) and FOW overlay use full map iteration:
```gdscript
func _draw():
    for x in range(map_size.x):
        for y in range(map_size.y):
            # Draw every tile
            draw_rect(...)
```

**Issues:**
- O(n²) complexity per frame
- 36×36 room = 1296 tiles per frame
- May drop FPS on 5-year-old devices

**Solution (Queued):**
- Implement tile culling (only visible tiles)
- Use precomputed LayerMasks
- Batch rendering

**Timeline:** M2-16 (Optimization pass)

---

## High Priority Debt 🟠

### 4. Audio System Not Integrated
**Severity:** MEDIUM  
**Impact:** HIGH  
**Estimated Fix:** 2–3 weeks

**Problem:**  
- Noise grid exists mathematically
- No actual audio playback
- No SFX library
- No adaptive music

**Issues:**
- Gameplay feels silent and unresponsive
- Detection meter ticks silently
- Alerts have no audio feedback

**Solution (In Progress):**
- Integrate AudioStreamPlayer nodes
- Create SFX library
- Add footstep triggers
- Add alert sounds

**Timeline:** This sprint (M2-14 second pass)

---

### 5. No Save System
**Severity:** MEDIUM  
**Impact:** MEDIUM  
**Estimated Fix:** 1–2 weeks

**Problem:**  
- No save/load functionality
- No mission progress tracking
- No permanent state

**Issues:**
- Players can't resume mid-mission
- No campaign progression
- Testing requires replaying missions

**Solution (Queued):**
- Implement mission save files
- Add checkpoint system
- Serialize agent/guard state

**Timeline:** M3-00 (Objectives & Missions)

---

### 6. Animation System Underdeveloped
**Severity:** MEDIUM  
**Impact:** MEDIUM  
**Estimated Fix:** 2–3 weeks

**Problem:**  
- Only basic tweening
- No sprite-based animations
- No state-based animation switching

**Issues:**
- Guards look stiff
- No feedback on state changes
- Combat/interaction animations missing

**Solution (In Progress):**
- Build sprite animation system
- Create guard sprite sets
- Link animations to FSM states

**Timeline:** This sprint (M2-14)

---

### 7. UI System Incomplete
**Severity:** MEDIUM  
**Impact:** MEDIUM  
**Estimated Fix:** 1–2 weeks

**Problem:**  
- No main menu
- No settings UI
- Minimal HUD

**Issues:**
- Game feels unpolished
- Players can't adjust settings
- No input customization

**Solution (Queued):**
- Create menu framework
- Add settings panel
- Build pause screen

**Timeline:** M2-16 (Polish)

---

## Medium Priority Debt 🟡

### 8. Perception Distance Curve Not Validated
**Severity:** MEDIUM  
**Impact:** MEDIUM  
**Estimated Fix:** 1 week (playtesting)

**Problem:**  
```gdscript
DISTANCE_CURVE = [1.0, 0.95, 0.85, 0.60, 0.40, 0.15, 0.05, 0.01]
```

**Issues:**
- Curve designed theoretically, not tested
- May be too forgiving or too punishing
- Shadow multipliers may need adjustment

**Solution (Queued):**
- Playtest with real players
- Collect detection data
- Adjust curve based on feedback

**Timeline:** M2-16 (Playtesting)

---

### 9. No Personality Variance Framework
**Severity:** MEDIUM  
**Impact:** LOW  
**Estimated Fix:** 1–2 weeks

**Problem:**  
All guards are identical:
```gdscript
# All guards use same decision logic
class GuardPersonality:  # Planned but not implemented
    var aggression: float
    var intelligence: float
    var patience: float
```

**Issues:**
- Guards feel repetitive
- No faction differentiation
- Combat becomes predictable

**Solution (Queued):**
- Implement personality traits
- Modulate thresholds per guard
- Add faction-specific behaviors

**Timeline:** M3-01 (Campaign Content)

---

### 10. Hardcoded Light Sources
**Severity:** MEDIUM  
**Impact:** LOW  
**Estimated Fix:** 3–5 days

**Problem:**  
Light positions hardcoded:
```gdscript
_light_sources = [
    LightSource.new(Vector2i(9, 4), 5.0, 8, 0.90),
    LightSource.new(Vector2i(9, 18), 5.0, 7, 0.85),
    # ...
]
```

**Issues:**
- Different rooms need custom lighting
- No designer control

**Solution (Planned):**
- Move to layout configuration
- Add per-room light definitions

**Timeline:** M3-00 (Content expansion)

---

## Low Priority Debt 🟢

### 11. Documentation Maintenance
**Severity:** LOW  
**Impact:** MEDIUM  
**Estimated Fix:** Ongoing

**Problem:**  
- Docs get out of sync with code
- Legacy DEVELOPMENT docs still exist
- No doc review process

**Solution (Ongoing):**
- DOC-01 establishes patterns
- Plan quarterly reviews
- Archive old docs

**Timeline:** Ongoing (post-DOC-02)

---

### 12. Debug Code Mixed With Production
**Severity:** LOW  
**Impact:** LOW  
**Estimated Fix:** 3–5 days

**Problem:**  
```gdscript
if DEV_VISION:
    draw_detection_overlay()
    draw_noise_visualization()
    # ... 20+ debug draws
```

**Issues:**
- Debug code clutters logic
- May affect release build size
- Performance implications

**Solution (Queued):**
- Extract to separate DebugDraw module
- Improve conditional compilation
- Add cleaner toggle system

**Timeline:** M2-16 (Pre-release polish)

---

## Planned Refactors

| Refactor | Current Scope | Target | ETA |
|----------|---------------|--------|-----|
| **FSM Architecture** | 5 states → behavior tree | Post-M2-15 | 1–2 weeks |
| **Patrol System** | Hardcoded → data-driven | M3-00 | 3–5 days |
| **Overlay Performance** | O(n²) → culled | M2-16 | 1–2 weeks |
| **Audio Integration** | Math-only → live SFX | This sprint | 2–3 weeks |
| **Animation System** | Tween-based → sprite anim | This sprint | 2–3 weeks |

---

## Debt Metrics

| Metric | Value |
|--------|-------|
| **Critical Issues** | 3 |
| **High Priority Issues** | 5 |
| **Medium Priority Issues** | 5 |
| **Low Priority Issues** | 2 |
| **Total Estimated Effort** | 8–12 weeks |
| **Current Debt Level** | Medium (sustainable) |

---

## Debt Management Policy

1. **Critical debt** must be addressed before next major release
2. **High-priority debt** should be addressed in current phase
3. **Medium-priority debt** queued for next sprint
4. **Low-priority debt** addressed during polish phase

---

**Last Updated:** 2026-06-11  
**Maintained By:** Technical Lead  
**Status:** Active 🟢
