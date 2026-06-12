# INFILTRAITOR — Risk Assessment & Mitigation

> **Known risks, probability, impact, and mitigation strategies.**

---

## Risk Matrix

**Probability:** Low (10–30%) | Medium (30–60%) | High (60%+)  
**Impact:** Low | Medium | High | Critical

---

## Design Risks 🎮

### Risk: Mobile Readability Unvalidated
**Probability:** Medium (40%)  
**Impact:** High  
**Status:** Active

**Description:**  
The game is designed for mobile but never tested with real users on mobile devices.

**Potential Outcomes:**
- Touch controls feel wrong
- UI too small on 4" screens
- Performance tanks on older devices
- Turn-based pacing too slow for touch

**Mitigation:**
- Playtesting phase (M2-16) includes mobile devices
- Early touch input testing (before M3.00)
- Performance profiling on 5-year-old iPhone

**Timeline:** Validate by end of M2-15

---

### Risk: Stealth Difficulty Curve Unknown
**Probability:** High (70%)  
**Impact:** High  
**Status:** Active

**Description:**  
Detection thresholds, shadow multipliers, and AP costs are theoretically designed but not playtested.

**Potential Outcomes:**
- Game too easy (stealth feels pointless)
- Game too hard (players frustrated)
- Detection meter unintuitive
- Shadow cover ineffective

**Mitigation:**
- Playtest difficulty curve (M2-16)
- Collect quantitative data on detection success rate
- Adjust thresholds based on feedback (target: 40–60% initial detection rate)
- Rapid iteration cycles

**Timeline:** Identify issues by end of M2-15

---

### Risk: AI Predictability
**Probability:** Medium (50%)  
**Impact:** Medium  
**Status:** Monitoring

**Description:**  
Guard AI is deterministic. After a few playthroughs, patterns become obvious.

**Potential Outcomes:**
- Game loses challenge on repeat plays
- Players memorize patrol routes
- "Solved" state reached too quickly

**Mitigation:**
- Add personality variance (guards behave differently)
- Implement procedural patrol generation (M3-00)
- Add learning behavior (guards adapt after repeated encounters)

**Timeline:** Address by M3-01

---

### Risk: Search AI Complexity Explosion
**Probability:** Medium (45%)  
**Impact:** Critical  
**Status:** Monitoring

**Description:**  
Search behavior requires searching a space systematically. This may lead to pathfinding explosion or infinite loops.

**Potential Outcomes:**
- Guards get stuck searching
- Pathfinding timeout (performance spike)
- Unfair player detection
- Soft-lock situations

**Mitigation:**
- Prototype search behavior early (M2-15 prep)
- Implement search timeout (guards give up)
- Use pre-computed search patterns
- Test exhaustively before integration

**Timeline:** Prototype by M2-16

---

## Technical Risks ⚙️

### Risk: FSM Scaling Failure
**Probability:** Medium (50%)  
**Impact:** Critical  
**Status:** Active

**Description:**  
Guard FSM uses simple switch/match structure. Adding personality variance, faction-specific behavior, and learning could create unmaintainable state explosion.

**Potential Outcomes:**
- Code becomes unreadable (100+ lines per state)
- New states introduce bugs
- Behavior becomes unpredictable
- Refactor required (weeks of work)

**Mitigation:**
- Plan FSM refactor to behavior tree (M2-15 design)
- Implement before personality variance added
- Use design patterns (Strategy, Behavior Tree)
- Code review process

**Timeline:** Refactor queued for M2-16

---

### Risk: Overlay Performance Degradation
**Severity:** Medium (50%)  
**Impact:** High  
**Status:** Active

**Description:**  
Movement and perception overlays iterate over all map tiles per frame. On large maps (50+×50+ tiles), this may drop FPS below 60.

**Potential Outcomes:**
- Framerate drops on large levels
- Unplayable on older devices
- Jank during overlay display
- Performance regression with each feature

**Mitigation:**
- Profile on target devices (M2-15)
- Implement tile culling (only visible region)
- Use precomputed masks
- Batch rendering

**Timeline:** Profile by M2-15, fix by M2-16

---

### Risk: Audio Desync
**Severity:** Low (25%)  
**Impact:** Medium  
**Status:** Monitoring

**Description:**  
Audio events (footsteps, alerts) may desync from visual feedback if audio is added late.

**Potential Outcomes:**
- Footsteps lag behind animation
- Alerts fire at wrong moment
- Audio threading issues
- Confusing player feedback

**Mitigation:**
- Integrate audio early (this sprint)
- Use frame-locked audio events
- Test sync rigorously
- Add audio delay adjustment (user setting)

**Timeline:** Implement audio this sprint

---

### Risk: Save System Complexity
**Severity:** Medium (40%)  
**Impact:** Medium  
**Status:** Queued

**Description:**  
Saving agent + guard state + map state could be complex and error-prone.

**Potential Outcomes:**
- Corrupted saves
- Desync between save and live state
- Load failure edge cases
- Data loss

**Mitigation:**
- Design save format early (M2-16)
- Use robust serialization (JSON or Godot Resource)
- Test save/load extensively
- Version save format for future compatibility

**Timeline:** Design M2-16, implement M3-00

---

## Production Risks 📊

### Risk: Team Capacity Unknown
**Probability:** High (65%)  
**Impact:** High  
**Status:** Active

**Description:**  
Project scope undefined; team size unknown; contractor availability uncertain.

**Potential Outcomes:**
- Animation delays (outsourced)
- Audio delays (outsourced)
- Feature creep leads to delays
- Burnout from unclear priorities

**Mitigation:**
- DOC-02 establishes clear scope
- Define minimum viable scope
- Set hard feature deadlines (M3.00 feature freeze)
- Regular status checks
- Hire contractors early if needed

**Timeline:** Establish by end of sprint

---

### Risk: Scope Creep
**Probability:** High (70%)  
**Impact:** Critical  
**Status:** Active

**Description:**  
New ideas, player requests, and feature additions could derail development.

**Potential Outcomes:**
- Deadlines missed
- Core features incomplete
- Team overwhelmed
- Release pushed indefinitely

**Mitigation:**
- Feature freeze at M3.00
- Backlog all post-M3.00 ideas
- Clear priority order
- Regular scope review meetings
- "No" is a complete sentence

**Timeline:** Enforce by M2-15

---

### Risk: Playtesting Scheduling
**Probability:** Medium (50%)  
**Impact:** Medium  
**Status:** Queued

**Description:**  
Finding playtesters at right times may be difficult. Scheduling conflicts, cancellations.

**Potential Outcomes:**
- Playtest delayed or cancelled
- Insufficient feedback
- Major issues discovered too late

**Mitigation:**
- Find and schedule playtesters early (now)
- Plan multiple playtest sessions
- Prepare playtest materials (questionnaire, metrics)
- Build buffer time into schedule

**Timeline:** Schedule by M2-14

---

## Scope Risks 🎯

### Risk: Content Drought
**Probability:** Medium (50%)  
**Impact:** High  
**Status:** Active

**Description:**  
Game may feel repetitive with only 1 mission and 1 guard archetype.

**Potential Outcomes:**
- Players lose interest quickly
- Release feels unfinished
- Campaign progression not possible

**Mitigation:**
- Commit to 12+ mission types by M3.00
- Add 3+ guard archetypes by M3.00
- Expand tilesets (5+) by M3.00
- Plan content pipeline (M3-00 onwards)

**Timeline:** Content expansion begins M2-15

---

### Risk: Narrative Scope Undefined
**Probability:** High (75%)  
**Impact:** Medium  
**Status:** Active

**Description:**  
Narrative is intentionally deprioritized, but may be needed sooner than expected.

**Potential Outcomes:**
- Missions feel disconnected
- No character motivation
- Player confusion about objectives
- Scope creep to add narrative retroactively

**Mitigation:**
- Define minimum narrative by M3-00
  - Basic mission briefings
  - Objective context
  - Character descriptions
- Leave full narrative for M4-00+
- Use environmental storytelling (cheap alternative)

**Timeline:** Define narrative roadmap by M2-16

---

### Risk: Combat Timeline Uncertainty
**Probability:** Medium (55%)  
**Impact:** High  
**Status:** Monitoring

**Description:**  
Combat system planned for M3.00 but complexity unknown.

**Potential Outcomes:**
- Combat takes longer than planned
- Stealth + combat integration difficult
- Delays to subsequent phases

**Mitigation:**
- Prototype combat mechanics (M2-16)
- Design combat system document (M2-16)
- Allocate extra time if needed
- Be ready to descope if necessary

**Timeline:** Design by M2-16

---

## Risk Summary Table

| Risk | Category | Probability | Impact | Status | ETA |
|------|----------|-------------|--------|--------|-----|
| Mobile readability | Design | Medium | High | Active | M2-15 |
| Difficulty curve | Design | High | High | Active | M2-15 |
| AI predictability | Design | Medium | Medium | Monitor | M3-01 |
| Search complexity | Design | Medium | Critical | Monitor | M2-16 |
| FSM scaling | Technical | Medium | Critical | Active | M2-16 |
| Overlay performance | Technical | Medium | High | Active | M2-15 |
| Audio desync | Technical | Low | Medium | Monitor | This sprint |
| Save system | Technical | Medium | Medium | Queued | M3-00 |
| Team capacity | Production | High | High | Active | M2-14 |
| Scope creep | Production | High | Critical | Active | M2-15 |
| Playtest scheduling | Production | Medium | Medium | Queued | M2-14 |
| Content drought | Scope | Medium | High | Active | M2-15 |
| Narrative scope | Scope | High | Medium | Active | M2-16 |
| Combat complexity | Scope | Medium | High | Monitor | M2-16 |

---

## Mitigation Timeline

| Timeline | Action |
|----------|--------|
| **This week** | Find playtesters, integrate audio |
| **M2-15** | Playtesting pass, difficulty validation, prototype search/combat |
| **M2-16** | Risk review, refactor decisions, timeline adjustment |
| **M3-00** | Feature freeze, hard scope lock |

---

**Last Updated:** 2026-06-11  
**Maintained By:** Project Management  
**Status:** Active 🟢
