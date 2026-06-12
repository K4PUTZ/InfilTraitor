# INFILTRAITOR — Not Yet Started Systems

> **Explicit documentation of systems that are planned but not yet initiated.**

---

## Purpose

This document prevents scope creep invisibility and ensures that unstarted systems are:
1. Explicitly acknowledged
2. Tracked with estimated effort
3. Assigned to phases
4. Blocked on dependencies

---

## Combat System

**Status:** ⏳ Not Yet Started

**Dependencies:**
- M2-14: Investigation Patterns (guards converging)
- M3-00: Feature Freeze approval + playtest validation

**Phase:** Phase 2 - Search & Engagement

**Estimated Effort:** 3–4 weeks

**Scope:**
- Melee combat resolution (attack/defend)
- Combat animations (attack, hit, dodge)
- Damage modeling (armor, critical hits)
- Health UI (damage feedback)
- Combat progression (weapon upgrades)

**Key Design Questions:**
- Should combat favor the agent or guards?
- Do we allow player-initiated attacks, or only defensive?
- How do armor/weapons affect outcomes?
- Does combat end a mission or just escalate?

**Acceptance Criteria:**
- Combat feels meaningful but not overpowered
- Guard-initiated attacks are challenging
- Player-initiated combat is possible but risky
- Combat feedback is clear and dramatic

---

## Meta Progression System

**Status:** ⏳ Not Yet Started

**Dependencies:**
- M3-00: First mission complete + balance tested

**Phase:** Phase 3 - Objectives & Progression

**Estimated Effort:** 2–3 weeks

**Scope:**
- Mission unlocking (prerequisites)
- Difficulty tiers (normal, hard, nightmare)
- Persistent upgrades (loadouts, skills)
- Player statistics (missions completed, stealth ratio)
- Progression tracking (UI display)

**Key Design Questions:**
- Should progression be linear or branching?
- How much replayability do we target?
- What upgrades create meaningful choices?
- Should difficulty affect rewards?

**Acceptance Criteria:**
- Players can select mission difficulty
- Upgrades feel impactful
- Progression is visible and motivating
- Statistics are accurate and informative

---

## Save System

**Status:** ⏳ Not Yet Started

**Dependencies:**
- M3-00: First playable campaign

**Phase:** Phase 2 (secondary) or Phase 3

**Estimated Effort:** 1–2 weeks

**Scope:**
- Game state serialization (rooms, guards, items)
- Save slots (3+ concurrent saves)
- Load/resume functionality
- Auto-save on mission completion
- Save file metadata (mission, date, playtime)

**Key Design Questions:**
- Should we allow mid-mission saves?
- Should guards remember player actions across saves?
- How many save slots do we support?
- Can saves be shared/exported?

**Acceptance Criteria:**
- Game state saves/loads correctly
- Save slots are independent
- Save metadata is accurate
- Load time is acceptable (<2 seconds)

---

## Mission Generation System

**Status:** ⏳ Not Yet Started

**Dependencies:**
- M3-00: First campaign complete (5–10 manual missions)
- C-02: Content expansion (multiple tilesets, guard types)

**Phase:** Phase 4 - Campaign Expansion

**Estimated Effort:** 4–6 weeks

**Scope:**
- Procedural room generation (tiles, obstacles)
- Guard placement algorithm (varied difficulty)
- Objective randomization (targets, locations)
- Difficulty scaling (guard count, detection radius)
- Validation (solvability, playability)

**Key Design Questions:**
- Should generation be fully random or guided?
- How do we ensure missions are solvable?
- Should we allow player-defined parameters?
- Can players save favorite generated missions?

**Acceptance Criteria:**
- Generated missions are playable
- Difficulty scaling works as expected
- Generation completes in <5 seconds
- Content variety feels fresh across 50+ missions

---

## Audio Integration (SFX & Music)

**Status:** 🟡 In Progress (This Sprint)

**Dependencies:**
- Au-01: Noise system foundation

**Phase:** Phase 1 - Final Polish

**Estimated Effort:** 1–2 weeks (this sprint + next)

**Scope:**
- Footstep SFX (quiet/alert variations)
- Alert sounds (whistle, radio, impact)
- UI feedback sounds (click, select, error)
- Adaptive background music (tension-based)
- Radio chatter (guard dialogue)
- Localization hooks (multi-language support)

**Current Progress:**
- ✅ Noise grid system complete
- ✅ Audio propagation validated
- 🟡 Footstep SFX being implemented (this sprint)
- ⏳ Alert sounds queued (next sprint)
- ⏳ Adaptive music queued (M2-15)

**Acceptance Criteria:**
- All footstep variations play correctly
- Alert sounds trigger on guard state changes
- UI feedback is immediate and satisfying
- Adaptive music responds to tension
- Audio feels cohesive and immersive

---

## Narrative Systems

**Status:** ⏳ Not Yet Started

**Dependencies:**
- M3-00: First mission playable + approved
- M5-04: Content expansion (multiple missions)

**Phase:** Phase 5 - Campaign & Narrative

**Estimated Effort:** 3–4 weeks

**Scope:**
- Mission briefing system (text display)
- Objective descriptions (contextual)
- Intel fragments (collectible lore pieces)
- Character introductions (NPC dialogue)
- Environmental storytelling (world-building)
- Dialogue system (minimal, future)
- Localization (multi-language support)

**Deprioritization Rationale:**
- Gameplay must be fun before story is added
- Narrative that contradicts gameplay is worse than no narrative
- Story can be added post-launch without breaking gameplay
- Focus on audio/animation/content first (more immediate impact)

**Current Status:**
- ⏳ [Narrative Pipeline](narrative_pipeline.md) created (framework only)
- ⏳ Mission briefing format designed (not implemented)
- ⏳ Faction profiles sketched (TBD)
- ⏳ World lore not started

**Timeline:**
- **Phase 1 (now):** Establish mission context (1–2 sentences per mission)
- **Phase 5 (M5-04):** Full narrative (briefings, fragments, story)
- **Post-Launch:** Character arcs, world expansion, live storytelling

**Acceptance Criteria:**
- Narrative enhances gameplay without contradicting it
- Story is optional (players can skip briefings)
- Environmental clues feel natural
- Lore depth is rewarding for engaged players

---

## Interaction System (Gadgets)

**Status:** 🟡 Planned (Next Sprint — G-05)

**Dependencies:**
- G-04: Overwatch system

**Phase:** Phase 1 - Extension

**Estimated Effort:** 1–2 weeks

**Scope:**
- Gadget inventory system
- Gadget placement (throw/deploy mechanics)
- Gadget interaction (activation, deactivation)
- Gadget effects (smoke bomb, EMP, decoy)
- Animation & feedback (particles, sounds)
- UI controls (selection, targeting)

**Planned Gadgets:**
- Smoke Bomb (obstructive, temporary cover)
- EMP (disable guards, 1-turn effect)
- Decoy (distraction, guard focus)
- Jammer (audio suppression, 1-mission duration)
- Night Vision (FOW enhancement, power drain)
- Grappling Hook (climbing, future)

**Acceptance Criteria:**
- Gadgets feel responsive and impactful
- UI for gadget selection is intuitive
- Feedback (particles, sounds) is clear
- Gameplay balance is maintained

---

## Objectives & Mission Types

**Status:** ⏳ Not Yet Started

**Dependencies:**
- M3-00: First mission playable

**Phase:** Phase 3 - Objectives & Progression

**Estimated Effort:** 2–3 weeks

**Scope:**
- Objective types (steal, rescue, destroy, infiltrate)
- Dynamic objectives (location-based, time-based)
- Optional objectives (for challenge/rewards)
- Failure conditions (capture, time limit, detection)
- Mission completion rewards (credits, reputation)
- Objective validation (on-map interaction checks)

**Planned Mission Types (15+):**

| Type | Objective | Difficulty | Status |
|------|-----------|-----------|--------|
| Theft | Steal item from room | Medium | Not started |
| Rescue | Extract NPC from location | Hard | Not started |
| Destruction | Sabotage equipment | Medium | Not started |
| Infiltration | Reach room undetected | Easy | Not started |
| Assassination | Neutralize target | Very Hard | Not started |
| Data Breach | Hack terminal/safe | Medium | Not started |
| Escort | Guide NPC to exit | Very Hard | Not started |
| Patrol Elimination | Clear area of guards | Hard | Not started |
| Plant | Place device/evidence | Medium | Not started |

**Acceptance Criteria:**
- Each mission type feels mechanically distinct
- Failure conditions are clear and fair
- Objectives are achievable with planning
- Rewards feel proportional to difficulty

---

## Extended Gadget Set

**Status:** ⏳ Not Yet Started

**Dependencies:**
- G-05: Gadget system foundation
- M3-00: First mission playable

**Phase:** Phase 2 - Expansion

**Estimated Effort:** 2–3 weeks

**Scope:**
- Grappling Hook (vertical movement, climbing)
- Holographic Decoy (persistent false target)
- Sound Dampener (movement silence, 1-mission duration)
- Thermal Goggles (guard detection, power drain)
- Remote Explosion (gadget detonation)
- Disguise Kit (guard uniform, imperfect disguise)
- Lock Bypass (automated lock-picking)

**Acceptance Criteria:**
- Each gadget creates meaningful tactical options
- Gadgets don't break mission balance
- Cooldowns/duration feel fair
- Counter-play is possible (guards adapt)

---

## Guard Personality & Learning

**Status:** ⏳ Not Yet Started

**Dependencies:**
- M2-14: Investigation patterns
- M3-00: First mission playable

**Phase:** Phase 2 - AI Expansion

**Estimated Effort:** 2–3 weeks

**Scope:**
- Guard archetypes (personality variations)
- Learning behavior (remembers player tactics)
- Adaptive difficulty (guards become more challenging)
- Personality-driven decision-making
- Memory persistence (across missions, optional)

**Guard Archetypes:**

| Archetype | Trait | Behavior |
|-----------|-------|----------|
| Professional | Disciplined | Methodical searches, follows protocol |
| Aggressive | Trigger-happy | Quick escalation, favors confrontation |
| Paranoid | Suspicious | Frequent checks, higher alert threshold |
| Lazy | Disengaged | Misses details, easily distracted |
| Experienced | Observant | Faster pattern recognition, harder to fool |

**Acceptance Criteria:**
- Guard personalities feel distinct
- Learning doesn't punish experimentation
- Difficulty scaling is gradual
- Personalities add challenge without feeling unfair

---

## Dynamic Difficulty & Scaling

**Status:** ⏳ Not Yet Started

**Dependencies:**
- M3-00: First mission playable + player feedback

**Phase:** Phase 3 - Progression

**Estimated Effort:** 1–2 weeks

**Scope:**
- Difficulty settings (Easy, Normal, Hard, Nightmare)
- Dynamic adjustment (based on player performance)
- Guard count scaling
- Detection radius scaling
- Reward scaling (difficulty bonus)
- Adaptive AI (learning-based difficulty)

**Acceptance Criteria:**
- Difficulty feels appropriately challenging at each level
- Easy mode is accessible to casual players
- Hard mode rewards mastery
- Scaling is fair and predictable

---

## Live Events & Seasonal Content (Post-Launch)

**Status:** ⏳ Not Yet Started

**Dependencies:**
- All core systems complete
- Analytics infrastructure in place

**Phase:** Post-Launch

**Estimated Effort:** TBD

**Scope:**
- Limited-time missions (weekly/monthly)
- Seasonal themed content
- Community challenges
- Leaderboards (optional)
- Reward seasons (cosmetics, gadgets)

**Acceptance Criteria:**
- Events feel fresh and rewarding
- Community engagement is positive
- Content updates are sustainable

---

## Summary by Phase

| System | Phase | Status | Effort | ETA |
|--------|-------|--------|--------|-----|
| Audio SFX | Phase 1 | 🟡 In Progress | 1-2w | M2-14 |
| Gadget System | Phase 1 | ⏳ Queued | 1-2w | G-05 |
| Combat | Phase 2 | ⏳ Not Started | 3-4w | M3-01 |
| Search/Investigation | Phase 2 | 🟡 In Progress | 2-3w | M2-15 |
| Objectives | Phase 3 | ⏳ Not Started | 2-3w | M3-02 |
| Meta Progression | Phase 3 | ⏳ Not Started | 2-3w | M3-03 |
| Mission Generation | Phase 4 | ⏳ Not Started | 4-6w | M4-01 |
| Narrative Systems | Phase 5 | ⏳ Not Started | 3-4w | M5-04 |
| Post-Launch Content | Post | ⏳ Not Started | TBD | TBD |

---

## Critical Path

```
Foundation (Complete)
    ↓
Audio/Gadgets (Phase 1 Final Polish)
    ↓
Combat + Extended AI (Phase 2)
    ↓
Objectives + Progression (Phase 3)
    ↓
Content Expansion (Phase 4)
    ↓
Narrative + Polish (Phase 5)
    ↓
Launch
    ↓
Live Events (Post-Launch)
```

---

## Risk Mitigations

### Scope Creep
- All new systems above feature freeze at M3-00
- Post-freeze additions go to Phase 4+ or post-launch
- Regular design reviews to validate scope

### Feature Interdependencies
- Systems designed with minimal coupling
- Fallback behaviors prevent hard blocks
- Alternative approaches documented

### Team Capacity
- Sprint planning accounts for team size
- Unfinished systems deprioritized rather than delayed
- Post-launch roadmap for overflow

---

**Last Updated:** 2026-06-11  
**Maintained By:** Design Lead  
**Status:** Active 🟢
