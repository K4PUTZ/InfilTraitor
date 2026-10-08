# INFILTRAITOR — Roadmap

> 🧭 **2026-10-07 — CONSOLIDATED DECISIONS AND THE ORDER OF ACTIVITIES (Director-ratified; SUPERSEDES the round order of the 2026-10-04 block below, which stays as the record of rounds 0-4).** Session record: `PROMPTS/RESUMO_SESSAO_2026-10-07_PERF_REVIEW.md`.
>
> **Decisions:** (1) the frag grenade is the stress case and ships as a late-game acquisition; budgets are judged on it (`DESTRUCTION`, `WEAPON`). (2) No all-glass rooms in INFILTRAITOR 1 (`GLASS`, `MAP`). (3) End-turn indicator, concept B (`INTERFACE_MASTER_PLAN`). (4) App killed in the background: **checkpoint only**, no suspend snapshot. (5) Package size: **procedural art is generated at first load and cached in `user://`** (the seeded facade / stamp generators are ported from `tools/asset_generation/` into the game); CC0 photos stay in the package; the export is audited for dead content (`assets/.godot/imported/BAKING`, a 4.9 MB `Black…` file) and gets a size check; release APK today 123 MB (166 MB unpacked, 66 MB of it the engine). (6) Performance, ratified on Claude's evaluation at the Director's request ("podemos gastar mais esforço agora; depois não vamos ter fartura"): **PSS peak <= 1.2 GB on the Galaxy A16** as a hard limit; **the strongest grenade** gets an unlimited pre-cook, ONE designed hit-stop under the flash with a ceiling (~150-200 ms) and the 100 ms line everywhere else; **cosmetic density (shards, debris, smoke) scales per device, gameplay never does**; **a combined stress scenario** (simultaneous events, dense content, many guards). (7) JAMES stays suspended; Claude owns the UI (rule 11 binding). (8) `PERFORMANCE`, `TOP_TEXTURE`, `OCCLUSION` and `DESTRUCTION` plans archived to `PROMPTS/DONE/` with a reform header each (what stays canon, where each open item went). (9) Planning gaps (block below): audio = future debt; iOS assumed stronger than the Android targets; no sustained/thermal run (short sessions); no extra devices; content rating follows the Play Store; field crash reporting in the optimisation milestone; maximum map size by a scaling study.
>
> **Order (Director: "vamos preparar todos os códigos antes de testar nos aparelhos"):**
>
> | Step | Content |
> |---|---|
> | **A1 — engine tools (desktop)** | ✅ **Cosmetic density per device BUILT 2026-10-07** (`CosmeticDensity`, flag `COSMETIC_DENSITY=low|mid|high|0.1-1.0`, default 1.0 = identity; read by the glass rain, embers, smoke blobs and ground debris; prop fragments and anything that is state are NOT scaled; `cosmetic_density_selftest`; the per-device default is chosen at step B from the handset rows); ✅ **the strongest grenade's hit-stop BUILT 2026-10-07, reworked 2026-10-08 as a staged world commit + task queue (see `technical_debt.md`, "A1 desktop round")** (BombDef tag `hit_stop` on `frag_grenade`; the commit lands on the flash PEAK frame and the glass flush + second remesh on the next flash frame, each reported against `hit_stop_ceiling_ms` = 200; `HIT_STOP=0` is the A/B ablation; desktop PLAYGROUND grenade 0: commit 15.9 ms, tail 5.0 ms; the glass grenade (1) was NOT exercised, and the Moto numbers are owed at step B); ✅ **the combined stress scenario BUILT 2026-10-07** (`maps/STRESS.map.json` from `tools/persistent/gen_stress_map.py`: 3x3 rooms of 8 materials, a glass hall under a glass roof, 24 guards, 60 props, 14 lights; `tools/persistent/stress_scenario.py` runs it on the desktop or prints the `dev_flags.cfg` for a handset: grenade into the brick rooms, a SECOND grenade into the glass hall thrown 150 frames later while the first blast's consequence plays, then a shot; desktop 0 ERROR lines; findings in `technical_debt.md`, "Stress scenario findings": #1 overlapping blasts FIXED, #2 the fuse-end frame (~230-540 ms desktop): (b)+(c) BUILT, worst 540 -> 158 ms on STRESS; (a) the ctx rebuild BUILT too (142 -> 0.05 ms); worst frame now ~155-195 ms desktop = the world commit stage itself); ✅ **the map-size scaling study's tooling BUILT 2026-10-07** (`tools/persistent/scale_study.py`: generated `SCALE_<N>` maps, STRESS density per GU^2 or `--content empty`, one row per size from the engine's own log lines, `--print N` for a handset, `--parse` for a logcat; a first DESKTOP series in `docs/measurements/scale_study_desktop_{dense,empty}_2026-10-07.md`: the 46 GU cell plane breaks first, the blast bends with content not area; the handset series is step B); ✅ **export audit and size check BUILT and APPLIED 2026-10-07** (`tools/persistent/apk_audit.py`; the Android `exclude_filter` now holds out DIAGRAMS / docs / videos / PROMPTS / ANIMATIONS / photo_src and the retired agent bake models: **release APK 127.7 -> 62.0 MB**, `export_android.py` forbids the bake models and the audit takes `--max-mb`; booted and ran the STRESS scenario on the Moto, no fatal). **Decision (Director, 2026-10-07): NO port of the generators and no first-load generation** — the procedural art in the package is ~2.4 MB; the catalogue ships fixed, `user://` is an optional override, and what the player sees is gated by gameplay; the ground-stamp groupers run only on a custom-material upload, with their own load, cache and UI (the late customisation milestone). |
> | **A1b — the agent's FINAL 3D model (at least for the demo): a GATE BEFORE ANY MOVEMENT AUTHORING** (Director, 2026-10-08) | Pick and lock the model the demo ships with, **before** the movement milestone starts. Why first: every action is keyed on one rig (`r3d_live_rig_export.py`, D64), so a different skeleton, proportion or attachment layout afterwards means re-keying (retargeting) all of it. To settle at the gate: the model itself (CC0 filter, `ACTOR` D57), the skeleton and its bone names (`hand_R` / `hand_L` carry the weapon and the grenade today), proportions against the scale canon, polygon and texture budget on the Moto, the silhouette classes and the faction palette (D34, D63), and whether the guards share the rig. Done when the Director has signed the choice and the rig exports and plays an existing action end to end. The current figure and the guards are placeholders. Detail and sequencing: `MOVEMENT_MASTER_PLAN` §6.0 and `CHARACTER_MASTER_PLAN`. |
> | **A2 — the stealth loop (desktop)** | AI-02 / AI-03, more noise emitters, M2.14 investigation, the non-combat turn **with the end-turn indicator B**; the agent's movement on the live rig (crouch, prone, sneak) in parallel, **only after A1b has locked the model**. |
> | **B — ONE handset round** | Moto g04s + Galaxy A16, current code, **standard coordinates `29,6;41,6`**: idle, turn, both grenades, shot, PSS (vs 1.2 GB), the combined stress scenario, the map-size study (Moto), the first-load time and package size. |
> | **C** | Minimal confrontation (DESIGN §8-10, scope sign-off first). |
> | **D** | Materials milestone: glass (G-S1, blocks, the COMMIT; target = the strongest grenade beside the largest shipped glass surface), the 8 library materials. |
> | **E** | Content scale (PP2/PP3 `.iprop`, user-tier models, the dormitory), then Phase 4. |
>
> **Parked, no step:** SURFACES SM-1 (when a map asks for it); audio; iOS; crash reporting (optimisation milestone); the content-rating check (when the content exists). **Risk accepted with this order:** regressions found only at B (the 2026-09-28 prop flood regression surfaced a week late); mitigation: every A step keeps `verify.py` green and the desktop `FRAME_PROBE` / `EVENT_FRAMES` rows of the standard scenario as a proxy.

> ⏭️ **2026-10-04 — THE ORDER OF THE NEXT ROUNDS (Director-ratified; this block is the single source, the other documents point here).**
> **Rule: close the engine before starting gameplay** (Director: *"vale a pena fechar a engine antes de começar a trabalhar com gameplay, principalmente o item 2D sobrando"*). R3D was closed by the Director on 2026-10-04; the rounds below are the engine finish he wants before gameplay, a track AFTER that close, tracked as **R3D-FINISH** in [`RENDER3D_MASTER_PLAN`](../../PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md).
>
> | Round | Content |
> |---|---|
> | **0** | Housekeeping and handset closure: the Galaxy A16 with the final code; on the Moto a camera turn and PSS against END-8; the stray modification in `current_state.md` committed; `export/retire2d.apk` removed; these documents reordered. |
> | **0b** | **Galaxy blast regression (found in round 0): DONE 2026-10-04.** The negative flash drawn cold cost ~190 ms on the first blast of a session; a 2 s invisible warm draw fixes it (Galaxy grenade 0: 231-343 -> 74-108 ms). The Moto confirmation and the idle cost of the warm draw are owed. The glass COMMIT of the second grenade (Galaxy 269-331 ms) stays on the glass track. |
> | **1** | **The last 2D: DONE 2026-10-04, nothing to build.** Both items were already closed (the shafts draw through `WorldCanvas3D` since RETIRE-2D; `GuardNoiseIndicator` was deleted in RETIRE-3); `canvas_gate.py` PASSED (0 on the canvas in 11 states). Kept 2D on purpose: the HUD, the explosion flash, `VfxDrawProbe`, the coordinate space. |
> | **2** | **R3D-BUFFER, simplified: BUILT 2026-10-04** (`verify.py full` PASSED; Moto measured 2026-10-04: idle unchanged, PSS peak +~170 MB for the empty ring; the Galaxy row is still owed). There already was a 1 GU buffer; every map is `buffer 5` now and each ring cell takes the ground of the nearest playable cell (same ground extended, no objects, dark). Every raw coordinate moved +4 per axis; the gates were corrected and their digests re-recorded with evidence (see `RENDER3D_MASTER_PLAN` v1.61, F2). **The Moto number after this round is an EMPTY-border number and is optimistic: never read it as the final cost.** |
> | **3** | **R3D-CLAIMS: BUILT 2026-10-05** (C1-C4; `verify.py full` PASSED, pixel gate 0 px). The containers hold cells, not `Voxel` objects; a voxel is a handle made on request (3 % of the voxels after a grenade and a shot). **Moto: PSS peak in the blast scenario 1 169-1 210 -> 945-967 MB (about -20 %), peak during the load 1 143-1 158 -> 914-934 MB, `[VOXEL-STORE] built` 1 264-1 829 -> 781-807 ms; frame times unchanged.** |
> | **4** | **R3D-LOOK: CLOSED 2026-10-05 (Director).** L1 the marks on a wall (decals by photo fill, the dent as a bowl), item 3 the floor depth and the burnt voxels (flat crater, soft soot), item 2 the spark anchor (one impact point, sparks back at the shooter, the sand trickle), item 7 the reveal silhouette by faction. **Not built, by decision:** per-run facade origins (the 3D board is already position-based and continuous; a per-GU offset in the shader is the cheap fix if a map ever shows repetition). Open: the handset cost of the dent bowl (28 quads) and of the 4-fetch soot smoothing, metal / wood option B, R3D-SURFACES art (more patch kinds). Record: `RENDER3D_MASTER_PLAN` F4 entries and `PROMPTS/RESUMO_SESSAO_2026-10-05_R3D_LOOK.md`. |
> | **5+** | Gameplay: **the stealth loop** (AI-02 / AI-03, more noise emitters, M2.14 investigation, the non-combat turn) with **the agent's movement** (keyed actions on the live rig: crouch, prone, sneak) in parallel; **the end-turn progress indicator, concept B** (`INTERFACE_MASTER_PLAN`, 2026-10-07) goes with the non-combat turn; then **minimal confrontation** (DESIGN §8-10, needs scope sign-off); then **the materials milestone** (glass reopened: structural collapse G-S1, glass blocks, the second grenade's 648-769 ms COMMIT on the Moto, the 8 library materials); then **content scale** (PP2/PP3 `.iprop` and user-tier models, the dormitory); then **Phase 4**. |
>
> **2026-10-07 — planning gaps reviewed with the Director (none is built; each is a placeholder for a plan):** (1) **Audio** does not exist (4 loose files, no `AudioStreamPlayer`): future debt, and it is not in any budget yet. (2) **iOS** has no export preset and no measurement: assumed to have more processing power than the Android targets; the Metal path is unverified. (3) **Sustained / thermal run (DIAG-07)**: not needed — sessions are short by the nature of the gameplay and the scenario construction. (4) **Android app lifecycle** (the app killed in the background mid-mission; the save is checkpoint-scoped): to think through. (5) **Package size** (the release APK is 123 MB; Play Store AAB base limit, asset packs): important, to debate. (6) **More devices**: not needed, the two targets are bottom-tier on purpose. (7) **Content rating**: the game intends violence, aggression and suicide; whatever the Play Store bans, the game drops too. (8) **Field crash reporting**: planned for the optimisation milestone. (9) **Maximum map size**: a standard map size will be set; the maximum must be determined scientifically from what is known (the ~46 GU cell-plane limit `CellPlaneStore.SOOT_TEX_SIZE`, memory per GU after CLAIMS, load time, idle draw cost) — a scaling study of generated maps of growing size on the Moto, to find where each cost bends, before the procedural (Freelance) generator is designed.
>
> **2026-10-07 rulings:** the frag grenade is the deliberate stress case and ships as a late-game acquisition (budgets are judged on it; `DESTRUCTION_MASTER_PLAN`); no all-glass rooms in INFILTRAITOR 1 (`GLASS_MASTER_PLAN`); performance review and the stale-coordinate handset rows in `DEVICE_DIAGNOSTICS_MASTER_PLAN`'s top block.
>
> **Open Director calls, not decided here:** (1) resume the interface track (JAMES) — the suspension read "until the performance milestone closes" and nobody has declared that milestone closed; (2) archive the closed plans (`PERFORMANCE`, `TOP_TEXTURE`, `OCCLUSION`, `DESTRUCTION`) to `PROMPTS/DONE/` — the archive is the Director's curation; (3) the border's look (above). **Resuming the AI track is part of this order (the 2026-06-18 gate, "occlusion and shadows done", is met).**

> ⏭️ **2026-10-02 — status.** The visual/engine phase ran ahead of gameplay on purpose (Director: months of render, destruction and light work before the gameplay): the 3D board, destructible voxel world, light, props, live actors and camera-only rotation are built and gated (`RENDER3D_MASTER_PLAN`, [`current_state.md`](current_state.md)). The phases below were written in June 2026 and not re-audited in this pass; what remains designed-and-unbuilt is listed in `docs/DESIGN_MASTER_PLAN.md` §20.

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

**Status as of 2026-10-02:** the engine work this phase absorbed is built and gated (the 3D board, destructible voxel world, voxel light, props, live actors, camera-only rotation; `verify.py full` green). What the investor-demo experience still lacks is gameplay on top of it: confrontation and cover, equipment, enemy factions, the segment map structure (`docs/DESIGN_MASTER_PLAN.md`, designed and unbuilt), and a content scene beyond the dormitory and the test maps. The July status below is kept for the record.

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
| 2026-10-02 | Status note added to Phase 3 after R3D-ROT closed; the phase estimates below were not re-estimated |
| 2026-06-18 | Absorbed `estimated_timeline.md` (descope/contingency/post-release) and deleted it — single phase model; IDs migrated to `{DOMAIN}-{NN}` per METHODOLOGY.md |
| 2026-06-12 | Roadmap rewritten: Investor Demo as the primary goal; post-investment phases rationalized; realistic estimates; critical blockers documented |
| 2026-06-11 | Initial roadmap created from DEVELOPMENT/PROGRESS.md |
