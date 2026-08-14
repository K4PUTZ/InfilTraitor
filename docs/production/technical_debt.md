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

### 4. Overlay Performance on Large Maps — CORRECTED 2026-07-15
**Severity:** ~~HIGH~~ LOW (re-scoped, not a frame cost)
**Impact:** ~~MEDIUM~~ LOW
**Estimated Fix:** N/A — no fix needed as currently architected

**Original claim (2026-06-12, never verified against code):** the movement
overlay (Dijkstra) and FOW overlay run O(n²) iteration **per frame**, risking
FPS drop on mobile at 36×36 = 1296 tiles/frame.

**Checked against the real code 2026-07-15:** neither `fog_of_war_overlay.gd`
nor `movement_overlay.gd` has `_process()` or `_physics_process()`. Both only
implement `_draw()`, which Godot calls exclusively after an explicit
`queue_redraw()` — and every `queue_redraw()` call site in both files is
gated behind a discrete gameplay event (`reveal_around()` on agent entering a
new cell, `rebuild()`'s Dijkstra flood on player-turn start/agent move, AP
zone changes on hover). This is the same event-driven recompute discipline
already codified as invariant O4′ for the occlusion system (recompute only on
`agent.step_finished` / perspective change, never per frame). In a turn-based
game the practical firing rate is a handful of times per turn, not 60/sec.

**Timeline:** None — re-open only if a future change adds a `_process()`
loop or an unthrottled hover-driven redraw to either overlay.

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

Tweening is functional for the demo. ~~Real sprites await post-demo.~~
**2026-08-13: the character work is now active** — see
`current_state.md` → Animation / Sprites, and `ACTOR_MASTER_PLAN.md`.

---

### 16. Firing a gun costs ~310 ms of synchronous CPU (W-PRECOOK) — deferred on purpose
**Severity:** HIGH (when combat exists) / None today (no shooter exists)
**Impact:** HIGH — a visible stall on the frame the player fires
**Estimated Fix:** unscoped; two candidate routes on record
**Added:** 2026-08-13

Measured with `[SHOT-PROF]` on a real 24-pellet shotgun, PLAYGROUND bench:

    resolve 1.00 ms cpu · render 4.9 ms wall over 0 frame(s) · repaint 309.89 ms cpu ·  9 voxel(s)
    resolve 1.09 ms cpu · render 7.9 ms wall over 0 frame(s) · repaint 322.64 ms cpu · 18 voxel(s)

Damage resolution is 1 ms and the async render pass needs zero extra frames.
**The entire cost is `_repaint_voxel_light_buckets()`** — and that repaint is
load-bearing, not waste: bullet soot is derived from it. For contrast, a grenade
destroying 453 voxels commits in 0.5 ms, because it pre-computes during the
throw. The firearm has no pre-production at all.

**Deliberately not fixed yet (Director, 2026-08-13).** The window this work
exists to fill is the aiming window, and there is no aim mode, no shooter and no
agent holding a weapon to build against — fixing it now means tuning against a
mock. Assigned to **GAME-01 (Combat System Foundation) as that milestone's last
item**, after aim mode is built in the same milestone. (Briefly assigned to M7.0
earlier the same day and pulled forward: *"vamos fazer ele no final da milestone
de combate."*)

**Timeline:** end of GAME-01 — aim mode built, and an agent from the ACTOR
living-beings track holding a weapon.
**Owner doc:** `PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md` §0 (measurement + both
routes) and D30.

---

## Medium Priority Debt 🟡

### 9. Perception Distance Curve Not Validated
**Severity:** MEDIUM
**Estimated Fix:** 1 week (playtesting)

```gdscript
## guard_enemy.gd — real current values, corrected 2026-07-26 (was quoted
## here as DISTANCE_CURVE = [1.0, 0.95, 0.85, 0.60, 0.40, 0.15, 0.05, 0.01],
## a stale 8-element array under the wrong name)
const FOV_DISTANCE_CURVE: Array[float] = [
	1.00, 1.00, 0.95, 0.88, 0.70, 0.48, 0.20, 0.06, 0.01
]
```

The curve was designed theoretically, not tested with players.

**Timeline:** First playtest

---

### 15. Roof material falls back to default on E/S perspective rotation
**Severity:** MEDIUM
**Found:** 2026-07-26 (Director report + investigation)

Some roofs (non-square footprints specifically) display the generic
fallback material instead of their real baked texture after rotating to E
or S. Root cause, fully diagnosed: two roof-page caches key purely on
`material_id|facade_id` with no direction/footprint component —
`room_builder.gd`'s bake-reuse cache (`_cached_bake_key`, ~line 589) and
`bake_compositor.gd`'s `_page_cache` (`_compose_roof_pages()`, ~line 661).
A roof's structure-local offset set is recomputed fresh per rotated view;
non-square footprints request `(col,row)` pairs the frozen cache never
baked, `BakedTileLookup.resolve_flat()` misses, and `voxel_renderer.gd`
falls back to the generic material.

**Why not fixed immediately:** the obvious correctness fix (key the cache by
direction too, like walls already do) trades away exactly the cache-hit
reuse `VL-PERF-BAKE` was built to provide — it would make every rotation
re-bake roof pages instead of reusing them across all 4 views. The
alternative (merge new frag keys into the existing page entry instead of
overwriting) preserves the perf win but needs careful implementation and
verification. **Director decision needed** on which trade-off to take before
implementing.

**Why the selftests missed it:** `roof_bake_selftest.gd` constructs a fresh
`RoomBuilder` (and empty cache) per direction tested — it validates
"bake fresh at N" and "bake fresh at E" in isolation, never "bake once, then
rotate live," which is the real `room.gd` runtime path and where the bug
actually lives. Same shape as the `geometry_selftest.gd` gap the 2026-07-12
sweep found: a test that doesn't exercise the real code path can't catch the
real bug.

**Timeline:** Ready to fix pending the Director's call on the cache-key
approach.

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

## Planned Refactors

| Refactor | Priority | Target | ETA |
|----------|----------|--------|-----|
| **Gradual detection escalation** | 🔴 Pre-playtest | guard_enemy.gd + room.gd | 1–2 weeks |
| **FSM → Strategy/BTree** | Pre-GAME-01 | guard_enemy.gd | 1–2 weeks |
| **Data-driven patrols** (now `MapSpec.patrols` in `world/maps/definitions/*_map.gd`; remaining: external resource authoring) | Pre-campaign | world/maps/ | 2–3 days |
| **Overlay O(n²) → culled** | Pre-mobile test | fog_of_war_overlay.gd | 1–2 weeks |
| **move_to_cell_animated coroutine** | Pre-3+ guards | guard_enemy.gd | 1–2 days |

---

## Debt Metrics (updated 2026-07-26)

| Metric | Value |
|--------|-------|
| **Resolved Items** | 4 (detection escalation, state_search visual, dead code, hardcoded noise) |
| **Critical Issues** | 2 (Guard FSM scaling; hardcoded patrol timings — Overlay Performance re-scoped to LOW 2026-07-15) |
| **High Priority Issues** | 5 (item 16, W-PRECOOK, added 2026-08-13 — deferred by design, not by neglect) |
| **Medium Priority Issues** | 2 (distance curve unvalidated; roof material fallback on E/S rotation) |
| **Low Priority Issues** | 2 |
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
- ~~**BAKE-CACHE-01** — warm boot 730–770 ms vs a 150 ms target. Release blocker under D12.~~
  **RESOLVED 2026-07-11**, one day before this plan cited it as open — `366bed9`
  (content-addressed disk cache) + `3ca1d33` (`BAKE-CACHE-PAGESIZE-01-b`, sparse-usage
  page composition) brought warm boot to ~32 ms (`docs/production/milestones.md`
  VOX-BAKE-01), reconfirmed live 2026-07-15 via `bake_cache_test.gd` TEST 3: **35 ms**.
  Budget (≤150 ms) cleared; not a release blocker. The 730–770 ms figure was the
  *original pre-fix* number, propagated stale into this doc, `DESTRUCTION_MASTER_PLAN.md`,
  and `RETROSPECTIVE_2026-07.md` §5 after the fix had already landed — corrected here;
  see `DESTRUCTION_MASTER_PLAN.md` §4 for the parallel correction.
- ~~**The core loop is still open** — detection accumulates but does not drive transitions.~~
  **Not current.** `turn_controller.gd::_apply_tic_result()` (`## ID-01: Gradual
  threshold-based escalation`) checks `guard.detection` against
  `DETECTION_THRESHOLD_SUSPICIOUS/ALERT/CHASE` (0.30/0.60/1.00) and calls
  `guard.observe_player(true, severity, ...)` — the meter drives transitions.
  This claim was already reconciled once (2026-06-14 note, this file) and drifted
  back; see `docs/production/current_state.md` for the maintained status.

---

## Consistency pass, 2026-07-26

Removed two items that duplicated the "Resolved Items" section above while
still being listed as open, the same self-contradiction pattern the sweep
notes above already describe:

- **#10 "STATE_SEARCH has no visual params of its own"** (Medium Priority) —
  duplicated Resolved Item #2 while contradicting it. Checked against the
  real code: `guard_enemy.gd::_get_cone_visual_params()` has its own
  `STATE_SEARCH` case (`range:5, fov:120.0, alpha:0.7, prob_mult:0.80`),
  distinct from the patrol default. Genuinely resolved; removed the stale
  duplicate.
- **#13/#14 "Dead code `_compute_shadow_tiles_old()`" and "Hardcoded noise
  values"** (Low Priority) — duplicated Resolved Items #3/#4.
  `_compute_shadow_tiles_old()` no longer exists anywhere in `room.gd`;
  `room.gd`'s noise emission already references
  `NoiseSystem.NOISE_CHANCE_WALK`/`NOISE_INTENSITY_WALK`, not hardcoded
  literals. Both confirmed resolved; removed.

Debt Metrics table corrected to match: Critical Issues 4 → 2 (only the Guard
FSM scaling problem and hardcoded patrol timings are still genuinely open;
Overlay Performance was already re-scoped to LOW on 2026-07-15), Low Priority
Issues 4 → 2. Numbering gaps in Critical Debt (no items 1–2) and Medium/Low
Priority sections are pre-existing from earlier resolved-item migrations, not
touched here — a full renumbering is out of scope for a consistency pass.
