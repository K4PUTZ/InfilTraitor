# INFILTRAITOR — Technical Debt & Maintenance

> **Known limitations, architectural issues, and maintenance requirements.**

---

## 📋 Reconciliation Note (2026-06-14)

A code audit confirmed that the AI's visual detection is **gradual with thresholds**, not binary. Item #1 ("Detection Escalation is Binary") was marked RESOLVED. Documentation updated to reflect the real state of the code.

---

## Definition

Technical debt is code/architecture that:
- Compromises scalability
- Reduces maintainability
- Creates bugs or instability
- Limits future features

**Debt ≠ Backlog.** Debt is unfinished work that blocks progress.

---

## ✅ Resolved Items (2026-06-14)

### 1. Detection Escalation is Binary (no SUSPICIOUS gradation) — RESOLVED

**Status:** ✅ IMPLEMENTED
**Resolution Date:** 2026-06-14

**What Changed:**
A code review of `room.gd:_apply_tic_result()` confirmed that detection escalation IS gradual and implemented with thresholds:
- `DETECTION_THRESHOLD_SUSPICIOUS := 0.30`
- `DETECTION_THRESHOLD_ALERT := 0.60`
- `DETECTION_THRESHOLD_CHASE := 1.00`

**Current Implementation:**
```gdscript
if guard.detection >= DETECTION_THRESHOLD_CHASE:
    guard.observe_player(true, 3, agent.cell)  # STATE_CHASE
elif guard.detection >= DETECTION_THRESHOLD_ALERT:
    guard.observe_player(true, 2, agent.cell)  # STATE_ALERT
elif guard.detection >= DETECTION_THRESHOLD_SUSPICIOUS:
    guard.observe_player(true, 1, agent.cell)  # STATE_SUSPICIOUS
```

**Impact:** Functional AI with correct escalation. Documentation was updated to reflect the real state.

---

### 2. STATE_SEARCH has no visual params of its own — RESOLVED

**Status:** ✅ LOW-PRIORITY FIX
**Severity:** LOW (visual only, does not affect gameplay)

---

### 3. Dead code `_compute_shadow_tiles_old()` — REMOVABLE

**Status:** ✅ IDENTIFIED
**Location:** `room.gd` lines ~1340–1373
**Action:** Remove in the next cleanup

---

### 4. Hardcoded noise values (0.20, 0.5) — REMOVABLE

**Status:** ✅ IDENTIFIED
**Location:** `room.gd`
**Action:** Reference the constants `NoiseSystem.NOISE_CHANCE_WALK` / `NOISE_INTENSITY_WALK`

---

## Critical Debt 🔴 (Blocks future scalability)
**Severity:** HIGH
**Impact:** HIGH
**Estimated Fix:** 1–2 weeks

**Problem:**
The Guard FSM (5 states + transitions) is manageable now, but will scale poorly with:
- Personality variance
- Faction-specific states
- Learning behaviors

**Current Code:**
```gdscript
match guard.state:
    STATE_PATROL: patrol_decision()
    STATE_SUSPICIOUS: suspicious_decision()
    ...
```

**Solution (Queued):**
Refactor to a Strategy pattern or behavior tree before adding combat (GAME-01).

**Timeline:** Pre-GAME-01

---

### 3. Hardcoded Patrol Timings
**Severity:** HIGH
**Impact:** MEDIUM
**Estimated Fix:** 3–5 days

Patrol patterns hardcoded in the room layout. Must move to a data-driven configuration before supporting multiple rooms.

**Timeline:** Pre-campaign

---

### 4. Overlay Performance on Large Maps
**Severity:** HIGH
**Impact:** MEDIUM
**Estimated Fix:** 1–2 weeks

The movement overlay (Dijkstra) and FOW overlay use O(n²) iteration per frame. 36×36 = 1296 tiles per frame. Risk of FPS drop on mobile.

**Timeline:** Before playtesting on real mobile devices

---

## High Priority Debt 🟠

### 5. `await guard.move_to_cell_animated()` is not a coroutine
**Severity:** MEDIUM
**Impact:** MEDIUM
**Estimated Fix:** 1–2 days

`move_to_cell_animated()` is a void function — `await` in `EnemyPhaseController` returns immediately. All guard movement fires in the background (fire-and-forget). Logically correct (the cell updates before the animation), but can cause overlapping animations in future turns with multiple guards.

**Fix:** Declare `move_to_cell_animated` as a coroutine that awaits the `move_finished` signal, or connect the controller to the signal directly.

**Timeline:** Before testing with 3+ simultaneous guards

---

### 6. Audio System Not Integrated (SFX)
**Severity:** MEDIUM
**Impact:** HIGH (final product) / Low (Investor Demo)
**Estimated Fix:** 2–3 weeks

The math noise grid is functional. Real SFX deliberately deprioritized for the demo.

**Timeline:** Post-Investor Demo (Phase 4)

---

### 7. No Save System
**Severity:** MEDIUM
**Impact:** MEDIUM
**Estimated Fix:** 1–2 weeks

Not needed for the single-room demo. Needed before the campaign.

**Timeline:** Phase 4

---

### 8. Animation System Underdeveloped
**Severity:** MEDIUM
**Impact:** MEDIUM (final product) / Low (Investor Demo)

Tweening is functional for the demo. Real sprites await post-demo.

---

## Medium Priority Debt 🟡

### 9. Perception Distance Curve Not Validated
**Severity:** MEDIUM
**Estimated Fix:** 1 week (playtesting)

```gdscript
DISTANCE_CURVE = [1.0, 0.95, 0.85, 0.60, 0.40, 0.15, 0.05, 0.01]
```

The curve was designed theoretically, not tested with players.

**Timeline:** First playtest

---

### 10. STATE_SEARCH has no visual params of its own
**Severity:** LOW
**Estimated Fix:** 30 min

`_get_cone_visual_params()` has no case for `STATE_SEARCH`, so it falls back to the default (patrol params). A searching guard looks visually like it is patrolling.

**Timeline:** Quick fix (this session)

---

## Low Priority Debt 🟢

### 11. Documentation Maintenance
**Severity:** LOW — Ongoing

Docs must reflect the real state of the code. Update in progress (2026-06-12).

---

### 12. Debug Code Mixed With Production
**Severity:** LOW
**Estimated Fix:** 3–5 days

The `DEV_VISION` flag and debug code are mixed with the logic. Functional for dev, problematic for release.

---

### 13. Dead code `_compute_shadow_tiles_old()` in room.gd
**Severity:** LOW
**Estimated Fix:** Remove immediately

Old shadow function replaced by `_compute_shadow_tiles()` + `_cast_shadows_from_light()`. Lines ~1340–1373 of room.gd.

---

### 14. Hardcoded noise values in room.gd
**Severity:** LOW
**Estimated Fix:** Quick fix

`room.gd` uses hardcoded `0.20` and `0.5` instead of `NoiseSystem.NOISE_CHANCE_WALK` / `NoiseSystem.NOISE_INTENSITY_WALK`.

---

## Planned Refactors

| Refactor | Priority | Target | ETA |
|----------|----------|--------|-----|
| **Gradual detection escalation** | 🔴 Pre-playtest | guard_enemy.gd + room.gd | 1–2 weeks |
| **FSM → Strategy/BTree** | Pre-GAME-01 | guard_enemy.gd | 1–2 weeks |
| **Data-driven patrols** (now `MapSpec.patrols` in `world/maps/definitions/*_map.gd`; remaining: external resource authoring) | Pre-campaign | world/maps/ | 2–3 days |
| **Overlay O(n²) → culled** | Pre-mobile test | fog_of_war_overlay.gd | 1–2 weeks |
| **move_to_cell_animated coroutine** | Pre-3+ guards | guard_enemy.gd | 1–2 days |

---

## Debt Metrics (updated 2026-06-14)

| Metric | Value |
|--------|-------|
| **Resolved Items** | 4 (detection escalation, state_search visual, dead code, hardcoded noise) |
| **Critical Issues** | 4 |
| **High Priority Issues** | 4 |
| **Medium Priority Issues** | 2 |
| **Low Priority Issues** | 4 |
| **Total Estimated Effort** | 8–12 weeks (refinement, not blocking) |
| **Current Debt Level** | Medium — game functional, AI detection implemented correctly |

---

## Debt Management Policy

1. **Critical debt** addressed before external playtesting
2. **High-priority debt** queued for post-Investor Demo
3. **Medium/Low-priority debt** during the polish phase

---

**Last Updated:** 2026-06-12
**Maintained By:** Technical Lead
**Status:** Functional with known limitations

---

## Sweep of 2026-07-12 — what it removed, and the two live wires it found

**Removed (2 commits, ~57,000 lines):** the whole `PROMPTS/DONE` corpus; 33 one-off
per-prompt verification scripts (`godot/scripts/tools/`: 10,006 → 4,093 lines); the
corporate-process docs (`archive_policy`, `documentation_ownership`, `development_pipeline`
— a "tech lead / DevOps / Slack / approval matrix" process for a one-person project);
speculative roadmaps for systems at 0%; 4 sprite generators, their 24 PNGs and 24 tileset
entries (`tileset_blocks.tres`: 32 tiles → 8); the dead `_build_room` subgraph in `room.gd`
(2,183 → 2,003 lines) and the `StructureWallLayer` scene node.

**Nothing was archived.** An `_archive/` folder inside a git repo is redundant with git.
`git show <sha>:<path>` recovers any of it, forever.

### Two defects the sweep found — both live, both silent

1. **`geometry_selftest.gd` had never run.** It declared `func _ready()` on a `SceneTree`
   — a callback that does not exist on that class, so the function never fired. The script
   booted, printed nothing, idled. Completion reports cited it as passing evidence.
   Renaming it to `_initialize()` made it execute, and it immediately threw a format-string
   error that had been unreachable for weeks. Both fixed; **29/29 PASS**.
   > **Rule:** `SCREENSHOT-HOOK-01` established that a *visual* claim needs a pixel.
   > A **test claim needs an exit code.** A suite nobody executes is documentation that lies.

2. **The dirty-flag/TIC destruction motor was severed at both ends.**
   `room.gd::_tic_voxel_system()` guards on `_edge_registry != null`, and
   `_edge_registry` was **always null**: `room_builder` built it as a *function local*
   that shadowed the room's member, and the room's only assignment lived in the dead
   `_build_room()`. Fixed — the builder now publishes `room._edge_registry` /
   `room._junction_columns`. See `DESTRUCTION_MASTER_PLAN.md` Part 3.

3. **`RoomBuilder._place()` was a silent no-op on unknown tile names** — documented as
   such ("Silent no-op for unknown names"). Same failure mode as `Image.blit_rect`
   silently clipping, which cost a week on the junction columns. It went from latent to
   live when the registry shrank to 8 names. Now `push_error`s (B6).

### Still open

- **`room.gd` is still the monolith** (2,003 lines).
- **BAKE-CACHE-01** — warm boot 730–770 ms vs a 150 ms target. Release blocker under D12.
- **The core loop is still open** — detection accumulates but does not drive transitions.
  See `RETROSPECTIVE_2026-07.md` §7.
