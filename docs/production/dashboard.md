# INFILTRAITOR — Production Dashboard & Status

> **Quick snapshot of project status, blockers, and immediate priorities.**

---

## Current Goal

**Target:** Investor Demo — a functional, convincing stealth room.
Criterion: anyone who plays for 5–10 minutes can feel the stealth tension, sees the guards reacting, and understands the game's pitch. Placeholder graphics, no audio, narrative, or polished UI.

---

## 📊 Current Status Snapshot

**Project Phase:** Investor Demo Preparation (🟡 functional AI, system integration in progress)
**Overall Progress:** 65% complete (re-estimated with functional AI)
**Last Updated:** 2026-06-14

---

## ⚠️ Active Design Gaps (no critical blockers)

| Gap | File | Status |
|-----|------|--------|
| `move_to_cell_animated` is not awaitable (fire-and-forget) | `guard_enemy.gd` | Opens a risk of overlapping animations with 3+ guards |
| ShadowProjector: direct light without LOS, inverted height, quantized direction | `shadow_projector.gd` | Functional for the demo, refinement post-investment |
| ExposureSystem: 6 classes defined, 2 used; stability/confidence not populated | `exposure_system.gd` | Spec complete, partial implementation expected |

**Status:** Guards detect, react, and escalate gradually. AI is functional for the demo. The refinements above are quality/architecture, not blockers.

---

## 🎯 Current Priority

**PRIMARY FOCUS:** Integrating perception (lighting/LOS) with the AI (auditory + visual checks)
**SECONDARY FOCUS:** Game-feel refinement (tuning detection curves)
**TERTIARY:** Demo polish and investor presentation

---

## 📈 Domain Status (revised)

### Gameplay (G-xx) — 75% Beta
✅ Grid movement, turn system, AP economy, A* pathfinding
✅ Guards detect and react to the agent (functional)
⏳ Objectives, combat, overwatch/gadgets (post-demo)

### AI & Behavior (A-xx) — 75% Alpha
✅ Guards detect and react to the agent (functional)
✅ FSM with 5 states and timer-based de-escalation
✅ Visual detection with gradual escalation (thresholds 0.30/0.60/1.00)
✅ Excellent A* pathfinding
✅ Communication (whistle/radio) functional via signals
⏳ Multi-guard coordination refinement, personality variance (post-demo)

### Lighting & Visibility (L-xx) — 80% Alpha
✅ Shadow projection, baking, fog of war, visualization
⚠️ Light sources hardcoded (acceptable for the demo)
⏳ Dynamic lighting (future)

### Audio & Sound (Au-xx) — 10% (math-only noise grid)
✅ Noise grid, propagation, decay (math)
⏳ SFX, adaptive music (post-demo, post-investment)

### Animation (An-xx) — 5% (tweening only)
✅ Movement tweening (functional for the demo)
⏳ Sprites, state animations (post-demo)

### UI & Presentation (P-xx) — 30% Prototype
✅ Debug overlays (FOW, vision cone, noise, trail)
✅ AP display, turn indicator
⏳ Menu, settings, polished HUD (post-demo)

### Content (C-xx) — 15% Prototype
✅ 1 room, 1 guard archetype, 1 basic tileset
⏳ Variety, room expansion (post-demo)

### Infrastructure & Tooling (I-xx) — 50% Alpha
✅ Godot 4.6, git, documentation
⏳ CI/CD, analytics (post-launch)

---

## ⏭️ Next Immediate Milestones

### This Week — Fix Blockers (ID-01)
🔴 **Fix Guard FSM Methods**
- Implement/rename `choose_next_cell()` → `pick_next_patrol_cell()`
- Implement `tick_state()` with real transition logic
- Connect TicSystem → detection meter → state transitions
- Synchronize state multipliers
- **Criterion:** A guard facing the player should escalate PATROL → ALERT in 2–3 turns

### Next 2 Weeks — Tuning & Feel (ID-02)
⏳ **Detection Curve Validation**
- Internal playtest with functional guards
- Adjust the detection curve (distance, shadow, posture)
- Target: stealth should be possible but not trivial

### Weeks 3–4 — Demo Room Polish (ID-03)
⏳ **Polish the demo room**
- A layout that showcases the systems (shadows, noise, multiple guards)
- Guards with interesting patrols
- Enough visual feedback for the investor to understand what is happening

---

## ⚠️ Known Risks

| Risk | Status | Mitigation |
|------|--------|-----------|
| Non-functional guards (stealth useless) | 🚨 ACTIVE | Immediate fix (this week) |
| Docs out of sync with code | 🚨 ACTIVE | Update in progress |
| Mobile readability | Pending | Test on a real device post-demo |
| Stealth difficulty balance | Pending | Playtest after the fix |
| FSM scaling pre-M3.0 | Active | Refactor before adding combat |
| Overlay performance | Active | Profiling before mobile |

---

## 📊 Milestone Status by Domain

### Completed Milestones: 12 ✅

**Gameplay (G-xx)**
- G-01: Grid navigation ✅
- G-02: Turn resolution ✅
- G-03: AP economy ✅

**AI & Behavior (A-xx)**
- A-01: Guard FSM structure ✅ (structure declared; functionality blocked)
- A-02: Perception calculation ✅ (calculation correct; not connected)
- A-03: Attention system ✅
- A-04: Communication signals ✅ (code exists; not fired due to blocker)

**Lighting (L-xx)**
- L-01: Shadow system ✅
- L-02: Fog of war ✅

**Navigation (N-xx)**
- N-01: A\* pathfinder ✅
- N-02: Movement overlay ✅

**Audio (Au-xx)**
- Au-01: Noise system (math) ✅

---

### In-Progress Milestones: 1 🟡

**AI & Behavior (A-xx)**
- ID-01: Guard FSM Fix (this week) 🔴

---

### Planned Milestones: Investor Demo Path

**Investor Demo (ID-xx)**
- ID-01: Guard FSM critical fix ⏳
- ID-02: Detection tuning & game feel ⏳
- ID-03: Demo room polish ⏳

**Post-Demo (PD-xx) — depends on investment/resources**
- Audio integration
- Animation & sprites
- UI polish
- Multiple rooms
- Save system
- Campaign Chapter 1

---

## 📞 Current Structure

| Role | Status |
|------|--------|
| Solo/Indie Developer | Active |
| Audio/Animation | Hire post-investment |
| QA | Informal playtest (pre-investment) |

---

**Last Updated:** 2026-06-12
**Status:** 🟡 FUNCTIONAL WITH GAPS — guards detect and react, visual escalation needs gradation
**Next action:** Connect the detection meter to the state thresholds for gradual escalation PATROL → SUSPICIOUS → ALERT
