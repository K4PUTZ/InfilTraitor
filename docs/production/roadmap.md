# INFILTRAITOR — Roadmap

> **Macro-level development phases. Each phase has a clear exit criterion before advancing.**

---

## Development Philosophy

**Focus on feeling before content.** A prototype that demonstrates the essence of the game with placeholder graphics is more valuable than a visually polished game with broken mechanics. The core loop — observe, plan, act, react — must be fun and tense before any other investment.

**Phases are sequential and dependent.** We do not advance to the next phase until the current phase's exit criteria are validated. Marking milestones complete without functional validation is the main development risk.

---

## Phase Overview

```
PHASE 1: Prototype Foundation (M1.0–M1.5)     ✅ COMPLETE
├─ Grid navigation
├─ Isometric rendering
├─ 3-layer FOW
└─ Movement mechanics

PHASE 2: Stealth Core Systems (M2.0–M2.12)    ✅ FUNCTIONAL
├─ Noise system (math + guards react) ✅
├─ TIC system (calculation) ✅
├─ Shadow baking ✅
├─ Guard detection (gradual with thresholds) ✅
├─ Guard FSM & communication ✅
└─ Audio detection ✅

PHASE 3: Investor Demo                         🟡 IN PROGRESS (scope expanded)
├─ Voxel rendering pivot (walls, bake, lighting) ✅ shipped, undocumented
│  here until 2026-07-26 — see milestones.md "Voxel Architecture Pivot"
├─ View occlusion + floor shadows + voxel-face lighting ✅ shipped
├─ Destruction (grenades) ✅ foundation shipped, paused (sequencing, not blocked)
├─ Provisional AI ⏸ (gate condition largely met — Director call to resume)
├─ Character/animation pipeline — being discussed now, ahead of schedule
└─ → EXIT CRITERION: a fun, convincing stealth loop (unchanged, not yet reached)

PHASE 4: Production Pass (Post-Investment)     ⏳ QUEUED
├─ Real audio SFX
├─ Sprites and animations
├─ Polished UI/UX
├─ Multi-room support
└─ Save system

PHASE 5: Campaign — Chapter 1                  ⏳ QUEUED
├─ 5–7 handcrafted rooms
├─ Difficulty progression
├─ Mission briefings
└─ Narrative introduction

PHASE 6: Campaign — Chapters 2 & 3            ⏳ QUEUED
├─ Guard communication and coordination
├─ Combat (optional, never optimal)
├─ Narrative climax
└─ Freelance mode unlock

PHASE 7: Freelance Mode                        ⏳ QUEUED
├─ Procedural mission generation
├─ Progression system
├─ Scalable difficulty
└─ Leaderboards

PHASE 8: Polish & Release                      ⏳ QUEUED
├─ Full (adaptive) audio
├─ Final animations
├─ Localization
├─ Performance optimization
└─ QA & deploy (iOS, Android, Web)
```

---

## Detailed Phases

### Phase 1: Prototype Foundation (COMPLETE ✅)

**Focus:** Core navigation, rendering, and grid mechanics.

**Exit Criterion (validated):**
- Agent moves smoothly on the grid
- FOW updates correctly with movement
- Consistent, performant rendering
- No visual or camera glitches

---

### Phase 2: Stealth Core Systems (FUNCTIONAL ✅)

**Focus:** Detection, noise, shadow, and basic AI systems.

**What is functional:**
- TIC System (detection probability calculation) ✅
- Noise System (persistent grid, decay, propagation) ✅
- Shadow baking (cone projection, 8 directions) ✅
- Guard detection (gradual with thresholds 0.30/0.60/1.00) ✅
- Guard FSM transitions ✅
- Guard communication signals ✅
- A* pathfinding for guards ✅
- Audio detection with wall attenuation ✅

**Exit Criterion (validated):**
- Guards detect the player and escalate state ✅
- Stealth is possible with planning ✅
- Demonstrable tension loop ✅

---

### Phase 3: Investor Demo (IN PROGRESS 🟡 — updated 2026-07-26)

**Goal:** A 5–10 minute experience that demonstrates the game's core pitch. Placeholder graphics. No audio, narrative, or polished UI.

**What actually happened (2026-06-28 → 2026-07-26), not reflected below until
this update:** the phase did not proceed as originally sequenced. Instead of
AI tuning after a scoped VIS-01 visual pass, the project underwent a
two-month **voxel architecture pivot** — replacing the flat sprite renderer
with a native voxel-per-tile system, a bake pipeline, a view-occlusion
system, a destruction system (grenades, real voxel damage), and a
voxel-face lighting system. See `docs/production/milestones.md` → "The Voxel
Architecture Pivot" for the full list, and `docs/production/current_state.md`
for maintained per-domain status. None of that was in the original Phase 3
scope; all of it is now largely done.

**Status as of 2026-07-26:**
- Functional AI with correct (gradual) escalation ✅ — unchanged since 2026-06-14
- Gradual visual detection implemented ✅
- Functional audio detection ✅
- View occlusion (`OCCLUSION_MASTER_PLAN.md`) — Parts 1–3 done, paused
- Floor shadows + voxel-face lighting — shipped
- Destruction (grenades) — foundation shipped, paused only on Director
  sequencing, not on any remaining blocker
- **Open Director decisions, not yet made:** resume AI-02 tuning now vs.
  sequence after character/animation work; when to start the
  character/animation asset pipeline (originally "post-investment," now
  being actively discussed); shot-based wall destruction (shotgun) now has a
  plan — `PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md`, 2026-07-29 — but only its
  test bench is built; no shot geometry exists yet.

**Estimate:** no longer meaningful as "3–5 weeks" — the phase absorbed two
months of unplanned engine work. Re-estimate once the open decisions above
are made.

**Why the engine work comes first — Director, 2026-08-06.** Read this before
concluding the phase has drifted. It has not: the ordering is a dependency
chain, ratified deliberately.

> A demo will never sell the project without a minimum of visual art.
> Shipping a gameplay loop that does not read visually would compromise
> everything.

And the systems are not separable in the direction one might assume:

```
destruction  →  light & shadow layout  →  guard reaction, agent movement,
                                          which route he takes, HOW MANY
                                          TILES he must walk, sound
                                          propagation, patrol routing
```

Light and shadow are **tactical**, not decorative — `SHADOW_MULT = 0.30` and
`PENUMBRA_MULT = 0.55` in `guard_enemy.gd`, the five exposure classes in
`exposure_system.gd`. Shadow structure is what makes a route safe or fatal,
and destruction *moves where the light falls*. Tuning detection, movement
cost or patrols before destruction works would be calibrating against numbers
that are still going to move.

So `tic_system.gd` and `noise_system.gd` sitting untouched since 2026-06-17 is
not neglect — those systems are waiting on inputs that are not final yet. The
confrontation phase the design calls for at 100% detection
([`DESIGN_MASTER_PLAN.md`](../DESIGN_MASTER_PLAN.md) §8) is genuinely unbuilt
and still matters; it is **sequenced after this foundation**, not dropped.
This is still the Investor Demo phase, laying its ground.

---

### Phase 4: Production Pass (Post-Investment ⏳)

**Prerequisite:** Investor Demo done and interest confirmed.
**Goal:** Raise production quality to a vertical slice presentable to the public.

**Deliverables:**
- SFX integration (footsteps, alerts, detection events)
- Sprites and state animations for guards and agent
- Polished UI/UX (HUD, menus, settings, pause)
- Multi-room support (data-driven layout)
- Basic save system (checkpoint between rooms)
- Performance optimization (overlay O(n²) → culled)
- Data-driven patrol system

**Exit Criterion:**
- Playable vertical slice presentable to press/public
- Audio and visuals sufficient for a gameplay trailer

**Estimate:** 8–12 weeks with 2–3 people

---

### Phase 5: Campaign — Chapter 1 (⏳)

**Prerequisite:** Phase 4 complete. Team expanded.
**Goal:** Narrative tutorial with 5–7 handcrafted rooms.

**Deliverables:**
- 5–7 handcrafted levels with progressive difficulty
- Introduction of mechanics (vision → noise → shadow)
- Mission briefings and extraction sequences
- Narrative introduction (agency, agent background)

**Exit Criterion:**
- Chapter 1 playable start to finish
- A new player understands the game without an explicit tutorial

**Estimate:** 8–10 weeks with a full team

---

### Phase 6: Campaign — Chapters 2 & 3 (⏳)

**Prerequisite:** Chapter 1 validated with playtesters.
**Focus:** Guard communication, coordination, optional combat, narrative climax.

**Deliverables:**
- Chapter 2: 5–7 levels focused on communication/coordination
- Chapter 3: 5–7 levels with confrontation, moral choice, resolution
- Basic combat system (viable but not optimal vs stealth)
- Freelance mode unlock

**Exit Criterion:**
- Campaign playable start to finish (~45–60 min)
- The player's final choice has narrative impact

**Estimate:** 12–16 weeks with a full team

---

### Phase 7: Freelance Mode (⏳)

**Prerequisite:** Campaign complete.
**Focus:** Infinite progression and procedural generation.

**Deliverables:**
- Procedural layout generation (templates + variation)
- Agent progression system (skills, gadgets)
- Difficulty scales with progress
- Optional leaderboards

**Estimate:** 8–10 weeks

---

### Phase 8: Polish & Release (⏳)

**Focus:** Final quality, performance, localization, deploy.

**Deliverables:**
- Full adaptive audio (music + SFX)
- Final animations and VFX
- Localization (PT/EN minimum; ES/FR optional)
- Performance optimized for 4–5 year old iOS/Android
- **Baked-frame VRAM budget (FRAME-MEM-01)** — Director-flagged 2026-07-29 for
  this phase. All figures measured on real GPU, not estimated:

  | | texture VRAM |
  |---|---|
  | Test-zone bench, 6 weapons × 4 frames (what ships today) | **13.6 MB** |
  | 7 spinning pickups on top of it (built, then removed) | **+458.4 MB** |
  | One 120-frame collectible set | **48–65 MB** (canvas-dependent) |

  `CollectibleFrameCache` already shares one set per bake folder and gives
  static props only the 4 frames they can display, which is what makes the
  bench cheap. **The unsolved half is the spinning pickups** — one is worth
  ~35 bench weapons, so their count is what decides whether a real room can
  show loot at all. The collectibles strip was disabled
  (`TEST_ZONE_COLLECTIBLES_ENABLED`) once it had proven the pipeline, precisely
  because of this. Unexplored levers: VRAM compression on the baked PNGs, fewer
  frames traded against `CollectibleBakeConfig`'s measured ~10–12 Hz
  smooth-motion threshold, and instantiating pickups only when the player is
  near. See `PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md` D10.
- Full QA pass
- Deploy iOS, Android, Web

**Estimate:** 8–12 weeks

---

## Timeline Summary

| Phase | Estimate | Prerequisite | Status |
|-------|----------|--------------|--------|
| Phase 1: Prototype | — | — | ✅ Complete |
| Phase 2: Stealth Core | — | Phase 1 | ✅ Functional |
| **Phase 3: Investor Demo** | **2–3 weeks** | **Integration** | **🟢 Ready** |
| Phase 4: Production Pass | 8–12 weeks | Investment | ⏳ Queued |
| Phase 5: Chapter 1 | 8–10 weeks | Phase 4 + team | ⏳ Queued |
| Phase 6: Chapters 2–3 | 12–16 weeks | Phase 5 | ⏳ Queued |
| Phase 7: Freelance | 8–10 weeks | Phase 6 | ⏳ Queued |
| Phase 8: Polish & Release | 8–12 weeks | Phase 7 | ⏳ Queued |

**Total estimate post-investment (Phases 4–8):** 12–18 months with a team of 3–5 people.

**Note on estimates:** The post-investment phases depend on team size. Without investment the estimates are meaningless — the goal right now is Phase 3.

---

## Milestone Dependencies

```
Phase 1 (Prototype) ✅
    ↓
Phase 2 (Stealth Core) ⚠️
    ↓
VIS-01 (Visual system: wall occlusion + floor shadow projection) ← NOW
    ↓
AI track [DEFERRED until VIS-01]: AI-01 fix FSM → AI-02 tuning → AI-03 refactor
    ↓
CONTENT-01 (Demo room polish)
    ↓
Phase 3 COMPLETE → Investor Demo

----- post-investment -----
    ↓
Phase 4 (Production Pass)
    ↓
Phase 5 (Chapter 1)
    ↓
Phase 6 (Chapters 2–3) + GAME-01 (Combat)
    ↓
Phase 7 (Freelance)
    ↓
Phase 8 (Polish & Release)
```

---

## What Is Deliberately Out of the Current Scope

| Item | Reason to defer |
|------|-----------------|
| Audio SFX | The math noise grid is sufficient for the demo |
| ~~Sprites/animations~~ | **Reopened 2026-07-26** — Director is actively scoping the character/animation asset pipeline (3D-rendered low-poly sprites) ahead of the originally-planned post-investment window. No longer "deliberately out of scope"; not yet started either. |
| Menu/settings UI | The current HUD is sufficient for the demo |
| Save system | Not needed in a single-room demo |
| Narrative | Requires a campaign (post-investment) |
| Combat (GAME-01) | Requires a solid FSM; defer until post-refactor |
| Shot-based destruction (shotgun) | Scoped 2026-07-29 — catalog in `PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md` (Part 0 bench done); the CONE/LINE geometry itself is that plan's Part 2, landing in `DESTRUCTION_MASTER_PLAN.md` Part 5 |
| Procedural generation | Requires a campaign (post-investment) |
| Localization | Final phase |

---

## Flexibility & Descope

If **behind schedule:** descope content (fewer missions/gadgets) before extending
the timeline; parallelize where structure allows.

If **ahead:** add content, extend playtesting, or pull the next milestone forward.

**Descope priority (if forced):**
1. ✅ Keep — core stealth, AI, perception (never cut)
2. ⏳ Reduce — combat complexity, content volume
3. ⏳ Remove — advanced personality variance, procedural generation (push post-launch)

**Contingencies:** a major bug pauses dependent phases until fixed; an unavailable
contractor falls back to in-house + a 1–2 week extension; a platform-requirement
change triggers a 1-week assessment + timeline adjustment.

---

## Post-Release (Future)

- **Season 1 (3–6 months):** balance patches, accessibility, community feedback
- **Season 2 (6–12 months):** new faction, new mission types, expanded content
- **Long-term:** co-op/multiplayer, cross-over events, advanced AI learning

---

## Revision History

| Date | Update |
|------|--------|
| 2026-06-18 | Absorbed `estimated_timeline.md` (descope/contingency/post-release) and deleted it — single phase model; IDs migrated to `{DOMAIN}-{NN}` per METHODOLOGY.md |
| 2026-06-12 | Roadmap rewritten: Investor Demo as the primary goal; post-investment phases rationalized; realistic estimates; critical blockers documented |
| 2026-06-11 | Initial roadmap created from DEVELOPMENT/PROGRESS.md |
