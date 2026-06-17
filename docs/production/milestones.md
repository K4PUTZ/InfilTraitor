# INFILTRAITOR — Milestones

> **Executable list of milestones with status, dependencies, and blockers.**

---

## ⚠️ Revision Note (2026-06-14)

Code audit (2026-06-14): the AI system is functional with GRADUAL detection implemented. Guards detect and react to the agent with correct escalation.

- **Code exists and works** — `choose_next_cell()`, `tick_state()`, `observe_player()`, `hear_noise()`, communication via signals
- **Detection is gradual** — Thresholds (0.30 SUSPICIOUS, 0.60 ALERT, 1.00 CHASE) implemented in `room.gd:_apply_tic_result()`
- **Functional for the demo** — M2.07 (Search) and M2.08 (Communication) work, guards react to the agent

Milestones ID-01 through ID-04 represent integration refinements, not critical bug fixes.

---

## Completed Milestones

### ✅ M1.0 — Prototype Foundation
**Objective:** Core grid navigation, isometric rendering, and FOW system operational.

**Dependencies:** None (project start)

**Status:** ✅ Complete (2026-02-20)

**Deliverables:**
- Tile-based grid navigation (4 directions)
- Isometric 2.5D rendering
- Three-layer fog of war (unseen/peek/revealed)
- Basic movement mechanics (2 AP per turn)

**Validation:**
- Agent moves smoothly on grid
- FOW updates correctly with movement
- Rendering is consistent and performant

---

### ✅ M1.5 — Tile System & Navigation Polish
**Objective:** Tile-wall autotile system, movement overlays, and navigation polish.

**Dependencies:** M1.0

**Status:** ✅ Complete (2026-04-15)

**Deliverables:**
- Tile-wall autotile system (corner+edge+fill logic)
- Movement overlay (Dijkstra pathfinding visualization)
- Floor apron and biome hierarchy
- Phase 1 border and end-cap fixes

**Validation:**
- Tile walls render correctly with autotiling
- Movement paths are visible and accurate
- Floor apron is seamless

---

### ✅ M2.0 — Sound System Foundation
**Objective:** Event-driven detection, noise propagation, and audio perception.

**Dependencies:** M1.5

**Status:** ✅ Complete (2026-06-05)

**Deliverables:**
- TIC System (event-driven detection)
- Noise System (persistent grid with decay)
- Audio perception (independent of LoS)
- Organic patrol behavior

**Validation:**
- Detection events trigger on boundary crossing
- Noise persists and decays correctly
- Guards react to audio independently of vision
- Patrol behavior is variable and organic

---

### ✅ M2.01 — Visual Detection Cones
**Objective:** Color-coded probabilistic vision visualization.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-05-25)

**Deliverables:**
- Color-coded cone visualization (blue/yellow/red)
- Distance-based attenuation
- Lateral falloff (center/±1/±2 from heading)
- State-dependent appearance (PATROL/SUSPICIOUS/ALERT/CHASE)

**Validation:**
- Cones render correctly and are color-coded
- Attenuation matches distance curve
- Cones update in real-time

---

### ✅ M2.02 — Organic Patrol Behavior
**Objective:** Variable speed, spontaneous pauses, and look rotation.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-05-30)

**Deliverables:**
- Variable speed (0.60× patrol to 3.00× chase)
- Spontaneous pauses (~20% chance per step)
- Look rotation between cardinal directions
- Smooth animation and tween-based transitions

**Validation:**
- Speed multipliers apply correctly
- Pauses are frequent enough to feel organic
- Look rotation is smooth and responsive

---

### ✅ M2.03 — Audio Detection System
**Objective:** Noise-based detection independent of visual LoS.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-06-02)

**Deliverables:**
- Audio detection evaluation (separate from visual)
- Wall attenuation (0.6× per wall crossed)
- Distance falloff (linear over 2-tile radius)
- Thresholded reactions (≥0.6, ≥0.25, <0.25)
- Detection meter accumulation

**Validation:**
- Audio detection works independently of visual LOS
- Wall attenuation applies correctly
- Distance falloff is linear and predictable
- Reaction thresholds trigger correctly

---

### ✅ M2.04 — Noise Propagation & Decay
**Objective:** Persistent noise grid with decay and emission mechanics.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-06-01)

**Deliverables:**
- Noise grid (Dictionary<Vector2i, {intensity, age}>)
- Decay mechanics (-0.25 per enemy phase)
- Emission (~20% chance per guard step)
- Visualization (cyan cones with intensity-based alpha)

**Validation:**
- Noise persists across turns
- Decay is consistent (4-turn lifespan for 0.5 intensity)
- Emission rate feels natural
- Visualization is clear

---

### ✅ M2.05 — Guard Attention System
**Objective:** Decoupled vision angle and focus-based scanning behavior.

**Dependencies:** M2.0, M2.01

**Status:** ✅ Complete (2026-06-08)

**Deliverables:**
- Visual vision angle decoupled from facing angle
- GuardAttention inner class (3 focus modes)
- Smooth head rotation and scanning
- Interest management (IDLE scanning, WAYPOINT anticipation, AGENT tracking)

**Validation:**
- Vision angle updates independently of facing
- Head rotation is smooth and responsive
- Scanning behavior is clear and observable
- Focus modes trigger appropriately

---

### ✅ M2.06 — Tactical Shadows System
**Objective:** Shadow projection with DIRECT and PENUMBRA multipliers.

**Dependencies:** M1.5

**Status:** ✅ Complete (2026-05-20)

**Deliverables:**
- Shadow projection (adjacent tiles + 2-step penumbra)
- DIRECT multiplier (0.30×)
- PENUMBRA multiplier (0.55×)
- Perspective-aware rotation

**Validation:**
- Shadows project correctly in all 4 cardinal directions
- Multipliers apply correctly to detection
- Shadows update on perspective rotation

---

### ✅ M2.07 — Suspicion-Based Search
**Objective:** Physical investigation behavior for SEARCH state.

**Dependencies:** M2.0, M2.05

**Status:** ✅ Complete (2026-06-10)

**Deliverables:**
- Physical movement to search tiles
- Observational pauses at reached tiles
- Queue management for multi-point patrolling
- De-escalation to SUSPICIOUS after search complete

**Validation:**
- Guards move physically to search targets
- Pauses allow for focus sweeps
- Queue consumption is robust
- De-escalation occurs correctly

---

### ✅ M2.08 — Guard Communication System
**Objective:** Whistle and radio signal propagation.

**Dependencies:** M2.0, M2.07

**Status:** ✅ Complete (2026-06-10)

**Deliverables:**
- Whistle signal (ALERT state, 3-tile radius)
- Radio signal (CHASE state, global)
- Signal routing via room hub
- State escalation validation

**Validation:**
- Whistles reach nearby guards correctly
- Radios broadcast globally
- Guards ignore low-priority alerts (state hierarchy)
- Signal propagation is immediate

---

### ✅ M2.09 — Audio Direction Indicators
**Objective:** Floating indicators showing where guard noise originates.

**Dependencies:** M2.04

**Status:** ✅ Complete (2026-06-11)

**Deliverables:**
- GuardNoiseIndicator script (renders "(((" and ")))" symbols)
- Floating animation and fade-out (1.8s duration)
- Color coding by intensity (low/high)
- Z-index placement (above all overlays)

**Validation:**
- Indicators display at correct positions
- Animation is smooth and readable
- Colors correspond to intensity
- Duration feels appropriate

---

### ✅ M2.10 — Decoupled Camera During Enemy Phase
**Objective:** Lock camera on agent; focus on guards only if revealed.

**Dependencies:** M2.0

**Status:** ✅ Complete (2026-06-11)

**Deliverables:**
- Camera lock on agent during enemy phase (no following guards)
- Conditional focus gate: is_cell_revealed() check before guard focus
- Z-index ordering: shadow(1) < fog_of_war(2) < structures(3)

**Validation:**
- Camera stays centered on agent
- Revealed guards are shown; unrevealed guards are behind FOW
- Shadows visible in all cases (baked at z_index=1)

---

### ✅ M2.11 — Directional Shadow System Rewrite
**Objective:** Baked shadows using light source cone projection and 8-direction quantization.

**Dependencies:** M2.06

**Status:** ✅ Complete (2026-06-11)

**Deliverables:**
- LightSource inner class (position, height, radius, intensity)
- Obstacle height mapping (tile types to heights)
- Cone projection geometry (shadow_len = height × (light_height - height) / distance)
- 8-direction quantization
- ShadowFullLayer and ShadowPartialLayer (baked, z_index=1)
- Shadow layer population via _bake_shadow_tiles()

**Validation:**
- Shadows cast in 8 directions (not just 4)
- Cone projection geometry is correct
- Shadows visible across entire map
- Baked layers never hidden by FOW

---

### ✅ M2.12 — GUI Cover Hints Removal
**Objective:** Remove old cover hint system; prepare for M2.15 redesign.

**Dependencies:** None

**Status:** ✅ Complete (2026-06-11)

**Deliverables:**
- Removed _draw_cover_hints() from movement_overlay.gd
- Removed cover hint color constants
- Reserved for M2.15 wall-face ícones redesign

**Validation:**
- No compilation errors
- No lingering references to cover hints

---

## In-Progress Milestones

### ✅ ID-01 — Detection Escalation Gradual — IMPLEMENTED

**Objective:** Connect the detection meter to the state thresholds for gradual escalation (PATROL → SUSPICIOUS → ALERT).

**Status:** ✅ RESOLVED (Implemented on 2026-06-14)

**Resolution Details:**
A code audit confirmed that gradual detection escalation **IS ALREADY IMPLEMENTED** in `room.gd:_apply_tic_result()`:
- Defined thresholds: `DETECTION_THRESHOLD_SUSPICIOUS := 0.30`, `ALERT := 0.60`, `CHASE := 1.00`
- The detection meter accumulates per tic and drives state transitions
- Automatic de-escalation via `_get_detection_decay()` works per state
- Audio detection integrated with the same threshold model

```gdscript
if guard.detection >= DETECTION_THRESHOLD_CHASE:
    guard.observe_player(true, 3, agent.cell)  # STATE_CHASE
elif guard.detection >= DETECTION_THRESHOLD_ALERT:
    guard.observe_player(true, 2, agent.cell)  # STATE_ALERT
elif guard.detection >= DETECTION_THRESHOLD_SUSPICIOUS:
    guard.observe_player(true, 1, agent.cell)  # STATE_SUSPICIOUS
```

**Validation:** ✅ Complete
- Guards detect and escalate gradually
- Timer-based de-escalation works
- Audio + visual detection integrated
- Functional AI for the Investor Demo
**Objective:** Reorganize documentation into modular, scalable structure.

**Dependencies:** None (orthogonal to gameplay)

**Status:** 🟡 In Progress (2026-06-11)

**Deliverables:**
- `docs/vision/` — game_vision.md, design_philosophy.md, pillars.md
- `docs/systems/` — individual system documentation
- `docs/production/` — roadmap.md, milestones.md, backlog.md, pipeline.md
- `docs/technical/` — architecture.md, implementation guides
- `docs/history/` — sprint logs and refactors
- Central index (docs/README.md)

**Blockers:** None

**Next Steps:**
1. Create system documentation (perception.md, lighting.md, noise.md, etc.)
2. Create technical architecture documentation
3. Move history and refactor logs
4. Create central index
5. Clean up old documentation

**Validation:**
- No system docs duplicated across multiple files
- Philosophy separate from milestones
- Roadmap separate from system docs
- Central index navigable

---

## Queued Milestones

---

### ⏳ ID-02 — Detection Tuning & Game Feel
**Objective:** Calibrate the detection parameters so that stealth is genuinely tense and fair.

**Dependencies:** ID-01

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Internal playtest with functional guards (at least 10 sessions)
- Adjust the DISTANCE_CURVE based on feedback
- Adjust the posture multipliers (STANDING/CROUCHING/PRONE)
- Adjust the shadow multipliers (DIRECT/PENUMBRA)
- Adjust the escalation thresholds (SUSPICIOUS/ALERT/CHASE)
- Adjust the per-turn decay rate

**Acceptance Criteria:**
- Agent standing, lit, 2 tiles from a guard = detected in ~2 turns
- Agent crouched, in shadow, 4+ tiles away = detection < 15% per turn
- Possible to complete the demo room undetected (but it takes effort)
- De-escalation possible (guard returns to normal state if the agent disappears)

---

### ⏳ ID-03 — Demo Room Polish
**Objective:** Create a demo room that showcases all systems at once.

**Dependencies:** ID-02

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Layout with multiple shadows, corridors, and cover positions
- 2–3 guards with distinct, non-trivial patrols
- At least 1 guard with a patrol that crosses a lit area
- Vision cones colored by state (blue/yellow/orange/red)
- Visible, readable noise indicator
- Basic objective (reach the extraction tile)
- Minimal UI: turn phase, agent AP, overall detection state

**Acceptance Criteria:**
- An observer with no context can understand the situation in < 2 minutes
- The room demonstrates: stealth via shadow, vision-cone evasion, noise management
- Guards communicate alerts to each other when they detect the agent

---

### ⏳ ID-04 — FSM Architecture Refactor
**Objective:** Refactor GuardEnemy's match/case to a Strategy pattern before adding combat.

**Dependencies:** ID-01 (guards working), before M3.0

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Each guard state as a separate class (GuardStatePatrol, GuardStateSuspicious, etc.)
- Common interface (decide(), enter(), exit())
- GuardEnemy delegates to the current state object
- Personality traits as modifiers (not as new states)

**Acceptance Criteria:**
- Adding a new state = create a new class, without touching the existing if/match
- Current behavior preserved (no regression)
- More readable code (each state ~50 lines, not 200+ lines in the match)

---

### ⏳ M2.13 — Suspicion Meter Integration (MERGED INTO ID-01)
**Objective:** Per-guard suspicion tracking and escalation mechanics.

**Dependencies:** ID-01 (this functionality was merged into ID-01)

**Estimated Duration:** (covered by ID-01)

**Deliverables:**
- Per-guard suspicion meter (0–100%)
- Visual meter display
- Meter increase triggers (visual detection, noise, communication)
- Meter decrease over time (de-escalation)
- State transitions based on meter (PATROL → SUSPICIOUS → ALERT → CHASE)

**Acceptance Criteria:**
- Meter updates responsively
- Escalation is visible and dramatic
- De-escalation is possible with planning

---

### ⏳ M2.14 — Investigation Patterns
**Objective:** Guards investigate last-known agent position.

**Dependencies:** M2.13

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Investigation target calculation (agent's last-known cell)
- Multi-guard convergence (multiple guards approach investigation target)
- Investigation completion trigger (guard reaches cell or timeout)
- De-escalation after fruitless search

**Acceptance Criteria:**
- Investigation creates multi-guard threat
- Convergence is coordinated and challenging
- Player can still evade with clever planning

---

### ⏳ M3.0 — Combat System Foundation
**Objective:** Basic combat resolution and damage modeling.

**Dependencies:** M2.14

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- Combat resolution (hit/miss)
- Damage calculation
- Health tracking
- Combat state machine (pre-combat, in-combat, post-combat)
- Basic enemy tactics (flanking, covering)

**Acceptance Criteria:**
- Combat is viable but not optimal
- Enemy tactics are coordinated and challenging
- Combat escalates threats appropriately

---

### ⏳ M3.05 — Advanced Tactics
**Objective:** Overwatch, traps, and reactive mechanics.

**Dependencies:** M3.0

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Overwatch system (hold action, reactive trigger)
- Trap mechanics (place, trigger, effects)
- Enemy reaction to traps
- Tactical depth through conditional mechanics

**Acceptance Criteria:**
- Overwatch adds strategic depth
- Traps create meaningful decisions
- Enemy reactions are intelligent

---

### ⏳ M4.0 — Campaign Narrative: Chapter 1
**Objective:** Tutorial chapter introducing visual perception mechanics.

**Dependencies:** M2.12

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- 5–7 handcrafted levels
- Mission briefings
- Difficulty progression (tutorial → challenge)
- Narrative introduction (agent's background, first mission)

**Acceptance Criteria:**
- Chapter is playable start-to-finish
- Mechanics are introduced progressively
- Narrative is engaging and cohesive

---

### ⏳ M4.05 — Campaign Narrative: Chapter 2
**Objective:** Communication and escalation chapter.

**Dependencies:** M4.0, M2.13, M2.14

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- 5–7 handcrafted levels
- Mission difficulty increase
- Narrative escalation (agent discovers deception)
- Guard coordination theme

**Acceptance Criteria:**
- Chapter is challenging but fair
- Coordination mechanics are showcased
- Narrative moves toward climax

---

### ⏳ M4.10 — Campaign Narrative: Chapter 3
**Objective:** Final confrontation and resolution chapter.

**Dependencies:** M4.05, M3.0

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- 5–7 handcrafted levels
- Maximum difficulty and coordination
- Narrative climax (agent's choice: destroy Agency or go public)
- Freelance mode unlock

**Acceptance Criteria:**
- Chapter is climactic and challenging
- Player choice feels meaningful
- Freelance mode is unlocked and ready

---

### ⏳ M5.0 — Freelance Mode: Procedural Generation
**Objective:** Procedurally generated missions and difficulty scaling.

**Dependencies:** M4.10

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- Procedural mission layout generation
- Difficulty scaling (matches player progression)
- Mission variety (different objectives, layouts)
- Infinite mission chain

**Acceptance Criteria:**
- Missions feel fair and varied
- Difficulty scales appropriately
- Procedural variety is noticeable

---

### ⏳ M5.05 — Freelance Mode: Progression Systems
**Objective:** Character progression, upgrades, and infinite scaling.

**Dependencies:** M5.0

**Estimated Duration:** 1–2 weeks

**Deliverables:**
- Character leveling system
- Equipment upgrades
- Skill unlocks
- Difficulty scaling (keeps pace with character power)

**Acceptance Criteria:**
- Progression is rewarding
- Difficulty remains challenging
- No trivializing mechanics

---

### ⏳ M6.0 — Audio Design
**Objective:** Complete sound design and music.

**Dependencies:** M4.10

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- SFX library (footsteps, detection, alarms, etc.)
- Music composition (adaptive soundtrack)
- Ambiance and environmental audio
- Localization (multiple languages)

**Acceptance Criteria:**
- Audio design supports stealth atmosphere
- Music is adaptive and responsive
- Localization is complete

---

### ⏳ M6.05 — Visual Polish
**Objective:** Animation, particles, and visual refinement.

**Dependencies:** M4.10

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- Guard animations (movement, detection, investigation)
- Agent animations (various poses, states)
- Particle effects (noise, detection, alerts)
- UI animation and polish

**Acceptance Criteria:**
- Animations feel weighty and responsive
- Particles enhance readability
- UI feels native and polished

---

### ⏳ M7.0 — Release Prep: QA & Optimization
**Objective:** Bug fixing, performance optimization, and platform preparation.

**Dependencies:** M6.05

**Estimated Duration:** 2–3 weeks

**Deliverables:**
- Comprehensive QA pass
- Performance optimization (target 60 FPS on 5-year-old devices)
- Platform-specific builds (iOS, Android, Web)
- Final balance tuning

**Acceptance Criteria:**
- Zero critical bugs
- Performance stable on target devices
- Deployment successful
- Analytics ready

---

### ⏳ M7.05 — Soft Launch & Analytics
**Objective:** Soft launch with analytics collection and user feedback.

**Dependencies:** M7.0

**Estimated Duration:** 2–4 weeks

**Deliverables:**
- Soft launch on limited markets
- Analytics dashboard
- User feedback collection
- Balance tuning based on data

**Acceptance Criteria:**
- Soft launch is successful
- Analytics are being collected
- User feedback is positive
- Balance tuning underway

---

## Blockers & Risks

| Milestone | Blocker | Status | Mitigation |
|-----------|---------|--------|-----------|
| **ID-01** | `choose_next_cell()` does not exist | 🚨 ACTIVE | Implement/rename this week |
| **ID-01** | `tick_state()` does not exist | 🚨 ACTIVE | Implement this week |
| **ID-01** | Detection meter not connected | 🚨 ACTIVE | Connect TicSystem → guard |
| ID-02 | ID-01 complete | Waiting on ID-01 | — |
| ID-03 | ID-02 complete | Waiting on ID-02 | — |
| ID-04 | ID-01 complete | Waiting on ID-01 | — |
| M3.0 (Combat) | ID-04 complete | Waiting on refactor | Do not start before the refactor |
| M4.0 (Campaign) | Investment | Waiting on investor demo | — |
| M5.0 (Procedural) | Generation algorithm | At risk | Templates initially |
| M6.0 (Audio) | Audio assets | At risk | Hire externally if needed |

---

## Next Steps

1. **Now (this week):** ID-01 — Fix guard FSM (guards must detect and react)
2. **Week 2:** ID-02 — Detection tuning for good game feel
3. **Weeks 3–4:** ID-03 — Polish the demo room for presentation
4. **Weeks 4–5:** ID-04 — Refactor the FSM before adding combat
5. **Post-investment:** Production pass (audio, animations, UI, multiple rooms)

See: `docs/production/roadmap.md` for the macro view of the phases
See: `docs/production/technical_debt.md` for blocker details
