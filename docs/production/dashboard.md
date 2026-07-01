# INFILTRAITOR — Production Dashboard & Status

> **Quick snapshot of project status, blockers, and immediate priorities.**

---

## Current Goal

**Target:** Investor Demo — a functional, convincing stealth room.
Criterion: anyone who plays for 5–10 minutes can feel the stealth tension, sees the guards reacting, and understands the game's pitch. Placeholder graphics, no audio, narrative, or polished UI.

---

## 📊 Current Status Snapshot

**Project Phase:** Investor Demo Preparation (� VOXEL Phase 2 complete, AI + visuals functional)
**Overall Progress:** 68% complete (Phase 2 runtime system finalized)
**Last Updated:** 2026-07-01

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

**PRIMARY FOCUS:** Visual system — wall **view occlusion** + **floor shadow projection** (VIS-01)
**SECONDARY FOCUS:** Ceiling / overhead layer (VIS-01 stages)
**DEFERRED:** All guard AI work (provisional) — resumes only after the visual system is complete

---

## 📈 Domain Status (revised)

### Gameplay (G-xx) — 75% Beta
✅ Grid movement, turn system, AP economy, A* pathfinding
✅ Guards detect and react to the agent (functional)
⏳ Objectives, combat, overwatch/gadgets (post-demo)

### AI & Behavior (A-xx) — ⏸ PROVISIONAL · deferred until the visual system is done
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

### Now — Visual System (VIS-01)
🟢 **Build the overhead visual engine + view occlusion**
- Wall **view occlusion** (keep the agent readable under walls/ceiling)
- **Floor shadow projection** rendering
- Ceiling / 5th-floor overhead layer
- **Criterion:** the agent is never lost under geometry; shadows read on the floor

### Deferred — Guard AI (provisional)
⏸ **All AI work parked until the visual system is complete**
- AI-01 (fix FSM), AI-02 (detection tuning), AI-03 (FSM refactor)
- Reason: detection tuning depends on reading shadows/cover on screen — needs the visuals first

### After the visuals — Demo Room Polish (CONTENT-01)
⏳ Showcases tuned guards + the finished visuals

---

## ⚠️ Known Risks

| Risk | Status | Mitigation |
|------|--------|-----------|
| Non-functional guards (stealth useless) | ⏸ Deferred | Provisional AI acceptable until the visual system is done |
| Docs out of sync with code | 🚨 ACTIVE | Update in progress |
| Mobile readability | Pending | Test on a real device post-demo |
| Stealth difficulty balance | Pending | Playtest after the fix |
| FSM scaling pre-GAME-01 | Active | Refactor before adding combat |
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
- AI-01: Guard FSM Fix (this week) 🔴

---

### Planned Milestones: Investor Demo Path

**Investor Demo (ID-xx)**
- AI-01: Guard FSM critical fix ⏳
- AI-02: Detection tuning & game feel ⏳
- CONTENT-01: Demo room polish ⏳

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
