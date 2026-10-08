# INFILTRAITOR — Technical Debt & Maintenance

> **Known limitations, architectural issues, and maintenance requirements.**

> **✅ 2026-09-25 — the largest debt item is PAID (R3D-END).** The 2D board is deleted; on the 3D board the Moto reads PSS ~1.1 GB (was 2.2-2.3), idle 19 ms (was 54-60), detonation means 28-31 ms (was 100+), load 15 s (was 54). Remaining performance debt is the hitch frames of a blast and a shot (`RENDER3D` R3D-LIGHT). **Items below that are properties of `TileMapLayer`s (overlay and tile performance) are moot unless they concern the props' structure layer.**
>
> **⏭️ 2026-09-15 — (was) the largest debt item, now a plan.**
> - **The debt:** the 2D board's cost on the target phones, measured in
>   `DEVICE_DIAGNOSTICS_MASTER_PLAN` §10–§15.
>   - memory 2.17–2.20 GB, with 0.7–1.4 GB swapped out;
>   - a 60 ms idle frame;
>   - multi-second detonation stalls.
> - **The plan:** move the board to Godot 3D over a packed voxel store —
>   [`RENDER3D_MASTER_PLAN`](../../PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md).
> - **Before working an item below that is a property of `TileMapLayer`s** (overlay and
>   tile performance), read it against that plan.

---

## 🔎 Code audit (2026-10-07)

Targeted scans over `godot/scripts/` (271 files, ~82 k lines) and `tools/`: content loading from `user://`, release-build switches,
committed secrets, saves, `print`/`printerr`, hard-coded strings, per-frame redraws, Python subprocess use. Record:
`PROMPTS/RESUMO_SESSAO_2026-10-07_PERF_REVIEW.md`.

**Fixed in the audit (each with a selftest):**
- 🔴 **Code execution through a player prop (FIXED).** `PropRegistry` reads prop JSON from `user://props/` and `PropModelFit` did
  `load()` + `instantiate()` on whatever `model` named: a `user://` `.tscn` with an embedded GDScript RAN (red proven by
  `prop_model_path_selftest`: the payload flag was set by `PropModelFit.fit()`). `PropModelFit.is_allowed_model_path()` now admits only a
  shipped `res://` `.glb` / `.gltf`, refused BEFORE loading, loudly. Every model route (props, grenade, pickups, the target cursor) goes
  through this one loader.
- 🟠 **A checkpoint could be lost to a kill mid-write (FIXED).** `SaveState.save_to_file()` opened the save with `WRITE`, which truncates
  first; it now writes a sibling `.tmp` and renames it over the old file (`SaveState.write_text_atomic()`, `save_state_file_selftest`).

**Error-prevention round (same day, after the audit), each with a selftest:**
- 🟠 **Every catalogue dropped a bad row in silence (FIXED).** `MaterialRegistry`, `MaterialResistanceTable`, `PropRegistry` (props and
  slots), `BombRegistry` and `WeaponRegistry` skipped a row that did not parse (Godot's own message names no file and says "line 0") or
  had no `id` (no message at all; red reproduced with a broken and an id-less `user://bombs/*.json`). They now read through
  `JsonFile.read_object()` / `require_id()`: a loud `push_error` WITH the path, and the line in the registry's `load_errors`.
  A material folder with no row of its own (`_generic/`) stays quiet on purpose.
- 🟠 **A malformed vector field aborted a row half-way (FIXED).** `PropDef` / `SlotDef` indexed `mesh_size`, `model_rotation_deg`,
  `footprint_gus`, `max_size` raw: `[90.0]` raised a SCRIPT ERROR and left the rest of the row unread. `JsonFile.vector3()` /
  `vector2i()` fall back to the default and report it; the row loads whole.
- 🟠 **A bomb could ask for any reach (FIXED).** `BombDef.MAX_RING` (16, a var by rule 1) cuts every per-ring table, loudly; the
  frag grenade uses 0..3.
- `registry_load_errors_selftest` also pins that the SHIPPED data loads with **zero** errors in all five catalogues (90 materials,
  12 props, 7 weapons, the grenade), so a future broken row fails the suite instead of vanishing.
- ⚠️ Attention markers left in the code where a decision is pending: `DevFlags._candidate_paths()` (item 1 below) and
  `SaveState.save_to_file()` (item 3).
- Tooling lesson: a NEW `class_name` is not visible to a headless `--script` run until the editor rebuilds the global class cache
  (`Identifier "JsonFile" not declared`), and a selftest whose `_init()` dies before `quit()` never exits; consumers `preload()` the
  helper, the project's usual pattern.

**Needs attention (documented, not changed):**
1. 🔴 **`DevFlags` is live in the store build.** A release APK reads `dev_flags.cfg` from its external files directory, which the device
   owner can write (adb or a file manager on some devices): `SCENARIO` steps, `MAP`, `GRENADE_GUS`, `GUARD_REVEAL`, every diagnostic.
   Not remote, but a cheat / tamper surface and a support risk. Fix before any public build: a `dev_flags` custom feature tag in a
   MEASUREMENT export preset only, and `DevFlags` ignores the file unless `OS.has_feature("dev_flags")` (the measured APK stays a release
   template). Needs the export pipeline change and the Director's sign-off.
2. 🔴 **The release is signed with the DEBUG keystore** (`export_android.py`, documented there): not publishable. A real release keystore,
   kept outside the repo (env vars, as today), before any store upload.
3. 🟠 **No save is wired into gameplay.** `SaveState.save_to_file()` / `load_from_file()` have no caller outside the class; the
   checkpoint model the Director ratified (2026-10-07: if the app is killed, only the checkpoint survives) has nothing writing a checkpoint
   yet. Belongs to roadmap A2 / the save work.
4. 🟠 **The `user://` content tier is validated at the top level only** (*partly closed by the error-prevention round below the list: rows, ids, vector fields and bomb reach are now checked; the remaining per-field schema is still owed*). Every registry checks that a file is a JSON object, but fields are
   read raw (`PropDef.from_json` indexes `model_rotation_deg[0..2]`; a `BombDef` may declare any number of rings, so a user bomb can make
   `flood_gu_rings` arbitrarily large). Harmless to anyone but the player who wrote the file, but a schema check per registry is owed before
   PP2/PP3 open user content (`PROP_PIPELINE_PLAN`). The `.vox` parser is already defensive (size caps, bounds, chunk guard): the model to follow.
5. 🟡 **`room.gd` is 11 145 lines** (then `detonation_plan_builder.gd` 3 091, `board3d_live.gd` 2 573, `voxel_board.gd` 2 454). Not a
   defect today, but every gameplay task lands in it; the controllers pattern (`world/controllers/`) is the extraction route, one system at a
   time, when the stealth loop touches it.
6. 🟡 **254 `print()` calls in runtime code** (160 in `room.gd`), against the contract's `print_debug()` for debug output. Most sit behind
   flags; the unconditional ones still write to logcat on every device. One pass to gate or convert them, measured on the Moto, in the
   optimisation milestone.
7. 🟢 **Player-facing tooltips are English literals in `hud.tscn`** ("End turn", the auto-end hint); the labels themselves go through
   `tr()`. Tooltips do not show on touch, so this only matters on desktop.

**Clean:** no committed secrets or keystores (`export_presets.cfg` holds no credentials); no `printerr`; no `str_to_var` / `bytes_to_var`,
`Expression`, `OS.execute` or network calls in runtime code; no `shell=True`, `eval`, `pickle` in `tools/`; every per-frame overlay redraw
either stops its `_process` when empty, or is a hidden dev overlay (`temporal`, `elite_exposure`) whose `_draw` Godot skips while it is invisible.

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

## Props and content debt (2026-09-30)
- **The two real prop models carry their own colours:** colour/texture must move to the material registry (`ACTOR` D66, `PROPS_TIER4_PLAN` P5); today the two CC0 models carry their own.
- **Tier 4 voxel replacement and the pile are BUILT** (2026-09-30); still planned: registry colour/textures for the fragments, the colour grade, charred variety, prop shadows (`PROPS_TIER4_PLAN` P4-P7). The old chip/smoke burst still plays beside the cubes, the Moto is not measured, fragments ignore the floor's holes and other props' tops (they land on the lattice of this prop's own pile only), and the lamps' cached shadow map is not re-fed when a prop stops blocking.
- **Slots, several models per slot, the validator, the fallback chain and `.vox` voxel models are BUILT (PP1/PP4); no `.iprop` and no user tier for models yet** (`PROP_PIPELINE_PLAN` PP2/PP3). `PropMesh3D` still makes one material per surface per instance (sharing per zone and a `MultiMesh` for many instances are measured options). **A voxel model is one GU of footprint** (the `MapCompiler` blocks only the anchor cell; footprint-aware rotation is the known gap), and a MESH prop still does not turn with the view (its long axis stays put on a rotation; R3D-ROT fixes both).
- **Material library is 14 rows with no `family`/fallback**; 8 materials are missing for everyday objects (`PROPS_TIER4_PLAN` §2b).
- **Firearms on props:** the agent path only; the weapon bench is untouched by decision; no debris on a shot.
- **Closed 2026-10-02 (SOOT-TRUTH):** the PLAYGROUND round trip soot divergence (`_soot_map` owns the scorch, the plane follows).
- **Documentation:** `docs/systems/*.md` and the milestones / roadmap were re-audited against the code on 2026-10-02 (a status table in `milestones.md`, per-file banners of what is built and what is specification); `docs/ARCHITECTURE.md` §2-§14, `ASSET_MAP`, `TEXTURE_CATALOG` still describe July 2026 (bannered; `ARCHITECTURE.md` §15.7).

## Engine debt after R3D-ROT (2026-10-02)
- **Heat vision's tile-risk overlay is heavy per frame** (`tile_risk_overlay.gd`, dev only): it walks a fixed 55x55 window (3 025 cells) and draws a quad for every cell with risk > 0, which is all of them (3 025 quads on a 126-cell map), redrawing every frame: ~9.5-10.5 ms of CPU on the desktop (1.3 ms of it the risk lookups; the shader is flat colour and cheap, the cost is building the quads and the mesh), so ~30-40 ms on the Moto. The Director keeps it per frame; bounding the loop to the map (and a coarser, guard-driven update) is the cheap lever, and the zone-vs-guard-motion calibration is on the `ACTOR` plan.
- **Dev text labels are billboards** (`GroundCanvas3D.draw_string` -> `Label3D`): not occluded by every wall; "numbers" on PLAYGROUND creates ~1 900 of them while on.
- **Air overlays have a maths gate, no picture gate:** `world_gate` holds `WorldCanvas3D.lift()` and `screen_axes()` under yaw; what the aim dome, throw arc and tracer draw with them is judged on captures only.
- **`_base_*` records** (damage, shattered props, debris, piles, cracks) are checkpoint persistence, not rotation workarounds; they go when `SaveState` serialises the `VoxelStore` (a stage of its own).
- **`layout_with_perspective()`** remains as the fixture of five selftests (floor_zone_bake, slice_geometry, voxel_persist, roof_entity, roof_bake): coverage, not a runtime path. `circle_gate_probe.gd` is a perf instrument and stays 2D on purpose.
- **Noise:** the guard noise indicator never shows (`GuardCoordinator` called a method that never existed; the call is a comment now); when wired its direction must use the view's axes (`WorldCanvas3D.screen_axes()`).
- **Small, known:** the rifle has no grip (it holds the shotgun); crouched and prone throws do not exist; `agent_live*.glb` are git-ignored (a fresh clone runs `r3d_live_rig_export.py` twice); the new `soot_truth_selftest.gd` has no `.uid` yet (the editor writes it).
- **Soot halo** (`BlastCalculator.SOOT_HALO_CHANCE`, 0.0) is built and off by the Director's choice; reapply at 0.5.

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
baked, `BakedTileLookup.resolve_flat()` misses, and `voxel_board.gd`
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
| **Depth on the isometric board** (a glass pane composites over an opaque wall in FRONT of it — `O5`: `z_index` encodes HEIGHT, depth is independent. The third system to hit it, after props and the occlusion wireframe) | 🟠 renderer scale, **spike-gated** | voxel_board.gd (glass layers + backbuffer) — the per-level `z_index` scheme itself is deliberately NOT touched | [`RENDER_ORDER_MASTER_PLAN`](../../PROMPTS/DONE/RENDER_ORDER_MASTER_PLAN.md) Task 1. ⛔ The 2026-09-10 design (`GLASS` §19 + `OCCLUSION` §7) was rejected the same day — do not build from it |
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


## Stress scenario findings (2026-10-07, roadmap A1)
Found by `tools/persistent/stress_scenario.py` (desktop, `maps/STRESS.map.json`).
1. **Overlapping blasts shared one `_active_presenter`: FIXED 2026-10-07.** A second grenade thrown inside the first blast's tail replaced
   the reference (one "light landed" for two blasts, 8 scripts leaked at exit). `TestZoneController._active_presenters` is a list swept
   by `DetonationPresenter.is_done` (a callback that captured the presenter was a reference cycle, found by `--verbose`). The scenario
   now fails unless both blasts land their light and nothing leaks (`stress_scenario.py`; red proven before, green after).
2. **The throw's worst frame is the FUSE-END frame, not the plan** (corrects the first reading: `P-COOK` was the scenario throwing without
   waiting). With `THROW_PROFILE=1` the plan is pumped during the arc (28-36 frames, 4 ms budget, fine) and the leftover cook is 0 frames. The
   hitch is ONE frame at the end of the fuse that does, before any flash covers it: `_take_prediction` (ctx rebuild) 89 ms PLAYGROUND /
   142 ms STRESS; `delta.commit()` 122 ms / 109 ms (1 601 / 2 749 voxels); `apply_prop_debris_fall` 1 ms / **258 ms** (60 props: it scales
   with props); `record_voxel_damage_to_base` 15 / 25 ms. Total ~230 ms PLAYGROUND, ~540 ms STRESS on the desktop, x3-4 on the Moto
   (the 632-641 ms worst frame of grenade 1 is this frame plus the glass work). Candidates, none built (they move work across beats, a
   design call): (a) take the prediction's ctx at aim time, (b) do `delta.commit()` + persist under the flash peak with the hit-stop,
   since meshes are rebuilt only at `on_blast_commit` and the fuse beat shows nothing of it, (c) spread `apply_prop_debris_fall` over the
   fuse frames. Needs the Moto row at step B to size it.
   **(b) and (c) BUILT 2026-10-07** (Director): for the `hit_stop` bomb the world commit runs under the flash in stages (0 `delta.commit` on the peak frame; 1 the presenter's commit + remesh; 2 glass flush + prop rings/proximity + a 60 ms slice of the debris; 3 the debris rest + persist; the desktop-only census after the flash), the prop debris is a resumable job (`Room.begin_/step_prop_debris_fall`, `apply_prop_debris_fall` is a wrapper). Desktop, STRESS glass grenade: worst frame ~540 -> 158 ms (stages 24 / 145 / 152 ms, commit 119 ms, all under the 200 ms ceiling); the final 10 MB board probe of two blasts is byte-identical to `HIT_STOP=0` (label line aside). **(a) BUILT** the same day: `_take_prediction` built the whole ctx (blocked edges, lights, shadows, debris policy) and a cache HIT discarded it; `PredictionCache.has_live()` lets it skip the build (89-142 ms -> 0.05 ms). What is left is the world commit itself (stage 0: `delta.commit`, 119-158 ms on the desktop, noisy): the worst frame is now 155 ms PLAYGROUND / 195 ms STRESS. The stages overshoot their slice by one step (no step is split further).
3. The pane grouper rejects a pane wider than 8 GU x 4 storeys (G-D23, loud `ERROR`): the generator keeps panes at 8.

## First Moto numbers for the A1 work (2026-10-07, STRESS, release APK 62 MB, `device_run.py` + `stress_scenario.py --mode sequential`)
The first handset look at the hit-stop and the stress map; one run each, desktop-built code, NOT the step-B round. Moto g04s, STRESS (24 guards, 60 props):
- **The staged hit-stop beats the single frame but does not hold its 200 ms ceiling on the device.** Glass grenade: stages 475 / 207 / 740 / 803 ms, worst probe frame 907 ms; `HIT_STOP=0` (everything in one frame) worst 1 869 ms (commit 425 + prop debris 1 221 + persist 145). Grenade 0 (brick rooms): stage 2 = 865 ms for 446 voxels. Desktop stage 2 was 145 ms, so the step is ~6x on the device, not the ~3-4x assumed: **`step_prop_debris_fall` steps are too coarse** (one material's `plan_landings` + `spawn_glass_rain` is one step) and the 60 ms slice budget cannot hold.
- **`PROP DEBRIS FALL` is the hot spot, with or without hit-stop:** 851 ms on 446 voxels (grenade 0), 1 221 ms on 2 749 (grenade 1). Next: find which half (the landing plan or the rain spawn) costs, subdivide it, and spread the debris over more frames.
- **`_take_prediction` still costs 567-571 ms on the SECOND throw** (0.04-0.10 ms on the first): the cache is missed there (the first blast's commit moved the world revision while the second was being pumped), so the ctx is built in the throw frame after all. Needs the revision handling looked at.
- The world commit alone is 425-445 ms on the device against 119 on the desktop (x3.7).
- Idle 27 ms/frame (GPU 25.4 ms) with the STRESS map; PSS and the rest of the table belong to step B.
