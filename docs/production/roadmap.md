# INFILTRAITOR — Roadmap

> **Macro-level development phases without technical detail. Each phase unlocks new gameplay possibilities.**

---

## Phase Overview

```
Prototype (M1.0–M1.5)          ✅ Complete
├─ Core grid navigation
├─ Isometric rendering
├─ FOW system (3 layers)
└─ Movement mechanics

Alpha: Sound System (M2.0–M2.05) ✅ Complete
├─ Event-driven detection (TIC system)
├─ Noise propagation & decay
├─ Audio perception (independent of LoS)
└─ Perception systems foundation

Alpha: Shadows Foundation (M2.06–M2.13) 🟡 In Progress
├─ Guard attention (decoupled vision/facing)
├─ Tactical shadows (baked, directional)
├─ Communication (whistles, radios)
├─ Physical search behavior
├─ Audio indicators
└─ Spatial perception complete

Alpha: Suspicion Escalation (M2.14–M2.20) ⏳ Queued
├─ Guard suspicion meters
├─ Investigation patterns
├─ Coordinated guard response
├─ Alert escalation mechanics
└─ De-escalation strategies

Alpha: Combat & Confrontation (M3.0–M3.10) ⏳ Queued
├─ Basic combat resolution
├─ Damage modeling
├─ Enemy tactics (flanking, covering)
├─ Overwatch system
└─ Trap mechanics

Vertical Slice: Campaign (M4.0–M4.10) ⏳ Queued
├─ Chapter 1: Tutorial (visual perception focus)
├─ Chapter 2: Escalation (communication focus)
├─ Chapter 3: Confrontation (coordination focus)
├─ Narrative integration
└─ First full playable experience

Beta: Freelance Mode (M5.0–M5.10) ⏳ Queued
├─ Procedural mission generation
├─ Difficulty scaling
├─ Infinite progression
├─ Leaderboards
└─ Session-based play

Content & Polish (M6.0–M6.20) ⏳ Queued
├─ Audio design (SFX, music)
├─ Visual polish (animations, particles)
├─ UI localization
├─ Performance optimization
└─ Platform-specific tuning

Release Prep (M7.0–M7.10) ⏳ Queued
├─ QA & bug fixing
├─ Platform deployment
├─ Soft launch
├─ Analytics & balance tuning
└─ Full release
```

---

## Detailed Phases

### Phase 1: Prototype (COMPLETE ✅)

**Focus:** Core navigation, rendering, and grid mechanics.

**Deliverables:**
- Top-down isometric rendering with consistent geometry
- Tile-based grid navigation (no diagonal movement initially)
- Three-layer fog of war (unseen/peek/revealed)
- Basic agent movement (2 AP per turn)

**Acceptance Criteria:**
- Agent moves smoothly on grid
- FOW updates correctly with movement
- No camera clipping or visual glitches
- Performance stable on target devices (60 FPS)

---

### Phase 2: Alpha — Sound System (COMPLETE ✅)

**Focus:** Event-driven detection, noise propagation, and audio perception.

**Deliverables:**
- TIC-based visual detection (event-driven, not turn-based)
- Colored vision cones (probabilistic detection visualization)
- Persistent noise grid (decay over time)
- Audio perception independent of LoS
- Organic patrol behavior (variable speed, spontaneous pauses)

**Acceptance Criteria:**
- Detection events trigger on guard movement
- Noise persists and propagates correctly
- Guards react to audio independently of visual LoS
- Patrol behavior feels organic and unpredictable

---

### Phase 3: Alpha — Shadows Foundation (IN PROGRESS 🟡)

**Focus:** Tactical shadows, guard attention, communication, and physical investigation.

**Deliverables:**
- Baked directional shadows (light source cone projection)
- Guard attention system (decoupled vision angle from facing)
- Communication system (whistles, radios, escalation)
- Physical search behavior (guards move to investigate)
- Audio direction indicators (where guard noise comes from)

**Acceptance Criteria:**
- Shadows cast from light sources in 8 directions
- Shadows always visible (never hidden by FOW)
- Guards show attention independently of facing angle
- Whistles reach nearby guards; radios reach all guards
- Guards physically patrol search zones

---

### Phase 4: Alpha — Suspicion Escalation (QUEUED ⏳)

**Focus:** Guard suspicion meters, investigation patterns, and coordinated response.

**Deliverables:**
- Per-guard suspicion meter (0–100%)
- Investigation patterns (approaching last-known position)
- Coordinated guard response (multiple guards converge)
- Alert escalation (SUSPICIOUS → ALERT → CHASE)
- De-escalation mechanics (guards forget over time)

**Acceptance Criteria:**
- Suspicion meter updates based on player actions
- Investigation creates multi-guard threat
- Alert escalation is visible and terrifying
- De-escalation is possible but requires planning

---

### Phase 5: Alpha — Combat & Confrontation (QUEUED ⏳)

**Focus:** Combat resolution, enemy tactics, and reactive mechanics.

**Deliverables:**
- Basic combat system (ranged + melee)
- Enemy tactics (flanking, covering fire)
- Damage modeling and health tracking
- Overwatch system (player can hold action)
- Trap mechanics (place and trigger)

**Acceptance Criteria:**
- Combat is viable but discouraged
- Enemy coordination makes confrontation challenging
- Overwatch adds tactical depth
- Traps create meaningful decisions

---

### Phase 6: Vertical Slice — Campaign (QUEUED ⏳)

**Focus:** Narrative integration and first complete playable experience.

**Deliverables:**
- Chapter 1: The Asset (visual perception tutorial)
- Chapter 2: The Frature (communication and coordination)
- Chapter 3: The Traitor (final confrontation)
- Mission briefings and extraction sequences
- Narrative branching (choice-driven ending)

**Acceptance Criteria:**
- Campaign is playable from start to finish
- Each chapter introduces new mechanics progressively
- Narrative feels cohesive and driven by player choice
- Campaign is ~45–60 minutes for skilled players

---

### Phase 7: Beta — Freelance Mode (QUEUED ⏳)

**Focus:** Infinite progression and procedural content.

**Deliverables:**
- Procedural mission generation
- Difficulty scaling (matches player power)
- Leaderboards and achievement tracking
- Session-based saving (no autosave creep)
- Cosmetics shop (optional purchases)

**Acceptance Criteria:**
- Missions are procedurally unique but feel fair
- Difficulty scales appropriately with progression
- Players can play indefinitely without stat trivializing encounters
- Monetization respects player time

---

### Phase 8: Content & Polish (QUEUED ⏳)

**Focus:** Audio, visual, and platform-specific optimization.

**Deliverables:**
- Complete sound design (SFX, music, ambiance)
- Animation polish (guard movement, agent poses)
- Particle effects (noise indication, detection events)
- UI animation and responsiveness
- Performance optimization for older devices

**Acceptance Criteria:**
- Audio design supports stealth atmosphere
- Animations feel weighty and responsive
- Performance stable on 5-year-old target devices
- UI feels polished and native to platform

---

### Phase 9: Release Prep (QUEUED ⏳)

**Focus:** QA, deployment, and soft launch.

**Deliverables:**
- Comprehensive QA pass (bug fixing)
- Platform-specific deployment (iOS, Android, Web)
- Soft launch with analytics collection
- Balance tuning based on early user data
- Final polish and optimization

**Acceptance Criteria:**
- Zero critical bugs
- Deployment successful on all platforms
- Soft launch metrics show player engagement
- Final balance tuning complete

---

## Milestone Dependencies

```
M1.0 (Prototype)
  ↓
M2.0 (Sound System)
  ├─ M2.05 (Audio Perception)
  ↓
M2.06 (Shadows + Attention)
  ├─ M2.13 (Directional Shadows)
  ├─ M2.14 (Guard Communication)
  ├─ M2.15 (Search Behavior)
  ↓
M2.20 (Suspicion Escalation)
  ├─ M3.0 (Combat System)
  ├─ M3.05 (Enemy Tactics)
  ↓
M4.0 (Campaign Narrative)
  ├─ M4.05 (Chapter Missions)
  ├─ M4.10 (Campaign Polish)
  ↓
M5.0 (Freelance Mode)
  ├─ M5.05 (Procedural Generation)
  ├─ M5.10 (Progression Scaling)
  ↓
M6.0 (Content & Polish)
  ├─ M6.05 (Audio Design)
  ├─ M6.10 (Visual Polish)
  ├─ M6.15 (Localization)
  ↓
M7.0 (Release Prep)
  ├─ M7.05 (QA & Deployment)
  ├─ M7.10 (Soft Launch)
```

---

## Timeline Estimates

| Phase | Estimated Duration | Status |
|-------|-------------------|--------|
| Prototype | 2–3 weeks | ✅ Complete |
| Sound System | 2–3 weeks | ✅ Complete |
| Shadows Foundation | 1–2 weeks | 🟡 In Progress |
| Suspicion Escalation | 2–3 weeks | ⏳ Queued |
| Combat & Confrontation | 2–3 weeks | ⏳ Queued |
| Campaign Narrative | 3–4 weeks | ⏳ Queued |
| Freelance Mode | 2–3 weeks | ⏳ Queued |
| Content & Polish | 4–6 weeks | ⏳ Queued |
| Release Prep | 2–3 weeks | ⏳ Queued |
| **Total** | **~20–28 weeks** | — |

---

## Success Criteria Per Phase

1. **Prototype** — Game is playable; grid and FOW are correct
2. **Sound System** — Noise propagates; audio detection works independently
3. **Shadows Foundation** — Shadows are visible; guards investigate physically
4. **Suspicion Escalation** — Meter updates; escalation is dramatic
5. **Combat System** — Viable but not optimal (stealth remains preferred)
6. **Campaign** — Narrative is cohesive; all mechanics are introduced
7. **Freelance Mode** — Infinite progression is engaging; difficulty scales
8. **Polish** — Game feels complete; performance is smooth
9. **Release** — No critical bugs; deployment successful; analytics positive

---

## Next Steps

See: `docs/production/milestones.md` for detailed executable milestones
See: `docs/production/backlog.md` for future features without priority

---

## Revision History

| Date | Update | Status |
|------|--------|--------|
| 2026-06-11 | Roadmap created from DEVELOPMENT/PROGRESS.md | Current |
| 2026-06-10 | M2.13 (Shadows) in progress | — |
| 2026-06-05 | M2.0 (Sound System) complete | — |
| 2026-02-20 | M1.0 (Prototype) started | — |
