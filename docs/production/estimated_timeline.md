# INFILTRAITOR — Development Timeline & Phases

> **Long-term development roadmap organized by maturity phases, not rigid dates.**

---

## Philosophy

This roadmap uses **phases** rather than dates, because:
- Dates create false precision
- Phases reflect actual dependencies
- Easier to adjust without cascading delays
- Focus on *what* matters, not *when*

---

## Phase Progression Model

```
Phase 1: Stealth Core
  ↓
Phase 2: Search & Suspicion
  ↓
Phase 3: Objectives & Missions
  ↓
Phase 4: Combat Integration
  ↓
Phase 5: Content Expansion
  ↓
Phase 6: Polish & Optimization
  ↓
Release
```

---

## Phase 1: Stealth Core Stabilization

**Status:** 🟡 IN PROGRESS  
**Est. Duration:** 3–4 more weeks  
**Completion Condition:** Stealth mechanics playtest-ready

### Objectives
- ✅ Perception system stable
- ✅ Audio detection working
- ✅ Shadow system baked
- 🟡 Noise propagation integrated
- 🟡 Animation framework started
- ⏳ Audio integration complete

### Milestones
- M2-13 — Shadow System Rewrite ✅
- M2-14 — Audio Integration + Double Pause ✅
- M2-15 — AI Refinement + Search Prep
- M2-16 — Playtesting + Optimization Pass

### Exit Criteria
- Core stealth mechanics solid
- Playtesting session complete
- Performance baseline established
- No critical bugs

### Next Phase Gate
Requires:
- ✅ Stealth feels right (playtester feedback)
- ✅ Performance acceptable (<100ms per frame)
- ✅ AI behaves predictably

---

## Phase 2: Search & Suspicion Escalation

**Status:** ⏳ QUEUED  
**Est. Duration:** 3–4 weeks  
**Completion Condition:** Search behavior + escalation working

### Objectives
- ⏳ Search AI implemented
- ⏳ Suspicion escalation refined
- ⏳ Multi-guard coordination
- ⏳ Communication propagation tested
- ⏳ Detection escalation polished

### Milestones
- M2-17 — Search Behavior Implementation
- M2-18 — Escalation Refinement
- M2-19 — Multi-Guard Tactics
- M2-20 — Balance & Tuning

### Exit Criteria
- Search doesn't infinite-loop
- Escalation feels fair
- Coordination visible to player
- Playtest validated

### Next Phase Gate
Requires:
- ✅ Search behavior stable
- ✅ Playtester feedback integrated
- ✅ No AI unpredictability

---

## Phase 3: Objectives & Missions

**Status:** ⏳ QUEUED  
**Est. Duration:** 4–5 weeks  
**Completion Condition:** Mission system + objective types working

### Objectives
- ⏳ Objective system (reach goal, acquire intel, etc.)
- ⏳ Mission briefing UI
- ⏳ Save/load system
- ⏳ Campaign progression framework
- ⏳ Content: 5–10 test missions

### Milestones
- M3-00 — Feature Freeze + Objectives API
- M3-01 — Campaign Content Creation
- M3-02 — Save/Load System
- M3-03 — Mission UI Polish

### Exit Criteria
- Players can complete multiple missions
- Save/load reliable
- Content variety present
- Campaign progression visible

### Next Phase Gate
Requires:
- ✅ Objectives well-integrated
- ✅ Campaign progression clear
- ✅ Content at minimum level (10+ missions)

---

## Phase 4: Combat Integration

**Status:** ⏳ QUEUED  
**Est. Duration:** 4–6 weeks  
**Completion Condition:** Combat system integrated + balanced

### Objectives
- ⏳ Combat system design
- ⏳ Combat animations + SFX
- ⏳ Combat balance + difficulty curve
- ⏳ Stealth + combat interaction
- ⏳ Takedown refinement

### Milestones
- M4-00 — Combat System Prototype
- M4-01 — Combat Integration
- M4-02 — Combat Balance
- M4-03 — Animation & Audio Polish

### Exit Criteria
- Combat feels responsive
- Stealth remains primary (combat is backup)
- Balance matches design intent
- Performance acceptable

### Next Phase Gate
Requires:
- ✅ Combat doesn't overshadow stealth
- ✅ Balance playtested
- ✅ All animations complete

---

## Phase 5: Content Expansion

**Status:** ⏳ QUEUED  
**Est. Duration:** 6–8 weeks  
**Completion Condition:** Rich content library

### Objectives
- ⏳ Guard archetypes (5+)
- ⏳ Gadget variety (6+ gadgets, full utility)
- ⏳ Tileset expansion (5+ tilesets)
- ⏳ Mission types (12+ missions)
- ⏳ Environmental hazards (6+ hazards)
- ⏳ Narrative baseline (mission briefs, lore)

### Milestones
- M5-00 — Content Pipeline Setup
- M5-01 — Guard & Faction Expansion
- M5-02 — Gadget & Tool Variety
- M5-03 — Level & Environment Design
- M5-04 — Narrative Integration
- M5-05 — Content QA Pass

### Exit Criteria
- 20+ missions available
- Content feels varied
- Player has meaningful choices
- Minimal repetition

### Next Phase Gate
Requires:
- ✅ Content design documents complete
- ✅ Pipeline established
- ✅ External contractors engaged (if applicable)

---

## Phase 6: Polish & Optimization

**Status:** ⏳ QUEUED  
**Est. Duration:** 4–6 weeks  
**Completion Condition:** Release-quality polish

### Objectives
- ⏳ Performance optimization (60 FPS target)
- ⏳ UI/UX polish (menus, settings, accessibility)
- ⏳ Audio mixing & mastering
- ⏳ Animation smoothness
- ⏳ Visual effects (particle systems, screen juice)
- ⏳ Accessibility features

### Milestones
- M6-00 — Performance Profiling & Optimization
- M6-01 — UI Polish & Menus
- M6-02 — Audio Mixing
- M6-03 — Visual Polish
- M6-04 — Accessibility Pass
- M6-05 — Release Build Preparation

### Exit Criteria
- 60 FPS on target hardware
- UI polished and intuitive
- Audio balanced
- No visual jank
- Accessibility validated

### Next Phase Gate
Requires:
- ✅ All gameplay systems frozen (no new features)
- ✅ Performance profiling complete
- ✅ QA sign-off

---

## Release Preparation

**Status:** ⏳ QUEUED  
**Duration:** 1–2 weeks

### Activities
- Final build preparation
- Release notes compilation
- Submission to platforms
- Launch marketing prep
- Post-launch support planning

---

## Timeline Summary

| Phase | Status | Duration | Gate |
|-------|--------|----------|------|
| **1. Stealth Core** | 🟡 In Progress | 3–4 weeks | Playtesting approval |
| **2. Search & Suspicion** | ⏳ Queued | 3–4 weeks | Search stable |
| **3. Objectives & Missions** | ⏳ Queued | 4–5 weeks | Campaign works |
| **4. Combat** | ⏳ Queued | 4–6 weeks | Combat balanced |
| **5. Content Expansion** | ⏳ Queued | 6–8 weeks | Content complete |
| **6. Polish & Optimization** | ⏳ Queued | 4–6 weeks | QA sign-off |
| **Release** | ⏳ Queued | 1–2 weeks | Ready to ship |
| **Total** | — | **24–35 weeks** | — |

---

## Critical Path

```
Start → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Release
        (must complete to unblock next phase)
```

If Phase 1 takes 5 weeks instead of 3, entire timeline shifts.

---

## Dependencies Between Phases

| Phase | Requires | Cannot Start Until |
|-------|----------|-------------------|
| 1 | None | Now |
| 2 | Phase 1 | Stealth core approved |
| 3 | Phase 1, 2 | Objectives designed |
| 4 | Phase 3 | Campaign structure set |
| 5 | Phase 4 | Core gameplay complete |
| 6 | Phase 5 | All features locked |

---

## Flexibility & Adjustments

### If Behind Schedule
- Descope content (fewer missions, fewer gadgets)
- Extend timeline (phases run longer)
- Parallelize where possible (Phase 5 can start before Phase 4 complete if structured)

### If Ahead of Schedule
- Add more content
- Extend playtesting
- Improve polish
- Begin next milestone early

### Descope Priority (if needed)
1. ✅ Keep: Core stealth, AI, perception
2. ⏳ Reduced: Combat complexity, content volume
3. ⏳ Remove: Advanced personality variance, procedural generation (post-launch)

---

## Contingencies

### If Major Bug Found in Phase 3
- All phases pause until fixed (3–5 days)
- Timeline shifts accordingly

### If Contractor Unavailable
- In-house alternatives + timeline extension (1–2 weeks)
- Scope reduction if not viable

### If Platform Requirements Change
- Assessment + mitigation plan (1 week)
- Timeline adjustment if necessary

---

## Post-Release Roadmap (Future)

### Season 1 (3–6 months post-launch)
- Balance patches
- Accessibility improvements
- Community feedback integration

### Season 2 (6–12 months post-launch)
- New faction
- New mission types
- Expanded content

### Long-term
- Multiplayer (or co-op)
- Campaign cross-over events
- Advanced AI learning

---

**Last Updated:** 2026-06-11  
**Maintained By:** Project Management  
**Status:** Active 🟢
