# INFILTRAITOR — Development Pipeline

> **Standardized process for features going from concept to production.**

---

## Overview

Every feature, system, and piece of content passes through this pipeline:

```
Concept → Prototype → Integration → Playtest → Balance → Polish → Optimization → QA → Content Lock
```

Each stage has entry/exit criteria, responsibilities, and deliverables.

---

## Stage 1: Concept

**Duration:** 1–2 weeks  
**Responsibility:** Design Lead + Tech Lead  
**Deliverables:** Design doc, specification, risk assessment

### Entry Criteria
- Feature approved in roadmap
- Aligned with design pillars
- No blocking technical risks

### Activities
1. **Document the Feature**
   - What is it? Why does it exist?
   - How does it interact with other systems?
   - What are success metrics?

2. **Prototype Proof**
   - Rough prototype (code or mockup)
   - Validate core mechanic works
   - Identify technical challenges

3. **Risk Assessment**
   - What could go wrong?
   - Estimated effort
   - Dependency mapping

### Exit Criteria
- Design document approved
- Technical approach agreed
- No unknowns remain (all risks documented)
- Timeline estimated

---

## Stage 2: Prototype

**Duration:** 2–4 weeks  
**Responsibility:** Lead Programmer / Feature Owner  
**Deliverables:** Working prototype, code review ready

### Entry Criteria
- Design doc locked
- Assigned to developer
- Technical risks addressed

### Activities
1. **Build Core Mechanic**
   - Write functional code
   - Hook up basic inputs
   - Test in isolation

2. **Internal Testing**
   - Does it work as designed?
   - What's missing?
   - What's broken?

3. **Document Implementation**
   - How does it work?
   - What's the architecture?
   - Edge cases addressed?

### Exit Criteria
- Core mechanic functional
- Code compiles, runs, doesn't crash
- Ready for code review
- Known limitations documented

---

## Stage 3: Integration

**Duration:** 1–2 weeks  
**Responsibility:** Lead Programmer  
**Deliverables:** Integrated system, test suite

### Entry Criteria
- Prototype passes code review
- No blocking issues
- Ready for integration

### Activities
1. **Integrate With Game**
   - Connect to other systems
   - Add to save/load
   - Add to UI
   - Add to settings

2. **Cross-System Testing**
   - Does it break anything?
   - Edge cases with other systems?
   - Performance acceptable?

3. **Add Tests**
   - Unit tests for core logic
   - Integration tests with related systems
   - Edge case tests

### Exit Criteria
- Feature integrated without breaking other systems
- Test suite passing
- No performance regression
- Ready for playtesting

---

## Stage 4: Playtesting

**Duration:** 1–2 weeks  
**Responsibility:** QA + Design Lead  
**Deliverables:** Playtest feedback report

### Entry Criteria
- Feature integrated
- No crashes on test hardware
- Minimal known bugs

### Activities
1. **Player Testing**
   - External playtesters (5–10 people)
   - Controlled environment
   - Observation + questionnaire

2. **Data Collection**
   - Success/failure rates
   - Time to complete
   - Frustration points
   - Suggestions

3. **Feedback Analysis**
   - What worked?
   - What was confusing?
   - What was boring?

### Exit Criteria
- Playtest completed
- Feedback collected
- Recommendations documented
- Critical bugs identified

---

## Stage 5: Balance

**Duration:** 1–3 weeks  
**Responsibility:** Design Lead  
**Deliverables:** Balanced feature, tuning parameters

### Entry Criteria
- Playtest feedback received
- Tuning parameters identified
- Design goals clarified

### Activities
1. **Adjust Mechanics**
   - Difficulty curves
   - Reward structures
   - Timing and pacing
   - Cost/benefit ratios

2. **Iterative Testing**
   - Play internally
   - Collect metrics
   - Adjust based on data

3. **Document Tuning**
   - Final parameters
   - Reasoning
   - Future adjustment guide

### Exit Criteria
- Feature feels right (subjective but team consensus)
- Metrics match goals
- Playtester feedback addressed
- Ready for art/audio pass

---

## Stage 6: Polish

**Duration:** 1–2 weeks  
**Responsibility:** Audio + Animation + Art  
**Deliverables:** Polished feature with audio/animation

### Activity Types

### Audio Pass
- Add SFX for key moments
- Add music stings if applicable
- Adaptive audio if complex
- Audio balance and mixing

### Animation Pass
- Add feedback animations
- State transition animations
- Polish movement

### Art Pass
- Visual feedback improvements
- UI refinement
- Particle effects if needed
- Screen juice (hit freezes, screen shake, etc.)

### Exit Criteria
- Feature has audio feedback
- Feature has visual feedback
- No placeholder graphics
- Ready for optimization

---

## Stage 7: Optimization

**Duration:** 1 week  
**Responsibility:** Lead Programmer  
**Deliverables:** Optimized code, performance metrics

### Entry Criteria
- Feature polished
- Ready for performance pass
- Target performance defined

### Activities
1. **Profile the Feature**
   - CPU time
   - Memory usage
   - GPU usage (if applicable)
   - GC pressure

2. **Optimize**
   - Algorithmic improvements
   - Caching
   - Batching
   - Memory pooling

3. **Test on Target Hardware**
   - 5-year-old iPhone
   - Budget Android device
   - Lowest target specs

### Exit Criteria
- Meets performance targets
- No regressions
- Profiling complete

---

## Stage 8: QA

**Duration:** 1–2 weeks  
**Responsibility:** QA Lead  
**Deliverables:** Bug report, edge case coverage

### Entry Criteria
- Feature optimized
- Stable
- Ready for testing

### Activities
1. **Comprehensive Testing**
   - Happy path
   - Edge cases
   - Error states
   - Combinations with other features

2. **Bug Hunting**
   - Deliberate exploit attempts
   - Stress testing
   - Multiplayer interactions (if applicable)

3. **Documentation**
   - Known issues
   - Workarounds
   - Notes for future maintenance

### Exit Criteria
- All critical bugs fixed
- Known issues documented
- Approved for release

---

## Stage 9: Content Lock

**Duration:** —  
**Responsibility:** Project Manager  
**Deliverables:** Feature finalized

### Entry Criteria
- QA approval
- All stages complete

### Activities
1. **Final Review**
   - Leadership sign-off
   - Feature matches design intent
   - Ready for release

2. **Release Notes**
   - Document what's new
   - Known limitations
   - Future improvements

### Exit Criteria
- Feature locked (no changes unless critical bug)
- Shipped with build
- Documented in release notes

---

## Example: Smoke Bomb Feature

### Concept (Week 1)
Design doc: "Smoke Bomb provides 2-second LoS break"

### Prototype (Weeks 2–3)
Smoke Bomb spawns, blocks vision tiles, despawns

### Integration (Weeks 4–5)
Integrated into gadget system, save/load working, UI showing charges

### Playtesting (Weeks 6–7)
5 external playtesters test smoke bomb in various scenarios

### Balance (Weeks 8–9)
Adjust duration (1.5 → 2 seconds), cooldown (2 → 1 turn), visibility range

### Polish (Weeks 10–11)
Add smoke particle effect, SFX, activation animation

### Optimization (Week 12)
Profile particle system, optimize culling

### QA (Weeks 13–14)
Test edge cases: smoke on guard, smoke on agent, multiple smokes, etc.

### Content Lock
Feature finalized, released in build

**Total:** ~3.5 months for single polish feature

---

## Fast-Track Pipeline (for minor features)

Some features don't need full pipeline:

**Minimal Fast-Track:**
- Concept (1 day)
- Prototype (1–2 days)
- Integration (1 day)
- Quick playtest (1 day)
- Polish (1 day)
- QA (1 day)

**Total:** 1–2 weeks

**Examples:**
- New patrol route
- Adjustment to detection curve
- UI refinement
- Small content addition

---

## Pipeline Parallelization

Multiple features can be in different stages:

```
Feature A → Concept → Prototype → [Integration]
Feature B →                      → [Playtesting]
Feature C →                                    → [Balance]
Feature D →                                               → [Polish]
Feature E →                                                          → [QA]
```

---

## Gating & Milestones

Features are gated by dependencies:

```
Cannot start Integration until Prototype is complete
Cannot start Balance until Playtesting is complete
Cannot ship until QA approves
```

---

## Pipeline Metrics

| Metric | Target | Current |
|--------|--------|---------|
| **Average pipeline time** | 8–12 weeks | TBD |
| **Prototype success rate** | 80%+ | TBD |
| **Playtesting feedback integration** | 70%+ | TBD |
| **QA bug discovery** | <5 critical bugs at ship | TBD |
| **Post-launch bugs per feature** | <2 | TBD |

---

**Last Updated:** 2026-06-11  
**Maintained By:** Project Management  
**Status:** Active 🟢
