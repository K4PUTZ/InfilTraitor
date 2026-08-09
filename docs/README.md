# INFILTRAITOR — Documentation Index

> Turn-based stealth tactics. Isometric 2.5D voxels, Godot 4.6, GDScript, mobile-first.

**Every file listed here exists.** If a link is dead, that is a bug — fix it or delete
the line. This index was rebuilt on 2026-07-12 after a cleanup that removed 55k lines of
docs describing a team, a process, and systems that never existed.

---

## Start here

| | |
|---|---|
| **[Game Vision](vision/game_vision.md)** | What the game is and why |
| **[Design Philosophy](vision/design_philosophy.md)** | The principles that don't bend |
| **[Design Pillars](vision/pillars.md)** | The seven pillars |
| **[Design Master Plan](DESIGN_MASTER_PLAN.md)** | **Every ratified mechanic in one place** — turn/detection/noise canon, and the confrontation, resistance, equipment, enemy and progression design that is decided but unbuilt. Read before designing anything gameplay-facing. |
| **[Architecture](ARCHITECTURE.md)** | How the engine is put together |
| **[Retrospective, first eight weeks](production/RETROSPECTIVE_2026-07.md)** | Where we've been, with the numbers |

---

## The canon — read before touching the render

These are load-bearing. Contradicting them breaks something that is expensive to find.

| Doc | Owns |
|---|---|
| **[BAKE_SYSTEM_REFERENCE](technical/BAKE_SYSTEM_REFERENCE.md)** | The bake: atlas, atoms, invariants B1–B6, themes, the `blit_rect` silent-clip trap. **D34 (2026-08-08) unified the horizontal bake** — a floor is a roof at the base of the scene, so wall/roof/floor of one material share one grayscale `facade_<id>` under MULTIPLY and one page; `slab_<id>` survives only for organic ground. FLOOR-ZONE-BAKE's Color-model and Projection subsections are marked SUPERSEDED, with the reversal block above them |
| **[DIRECTION_GLOSSARY](DIRECTION_GLOSSARY.md)** | NW/NE/SE/SW, the two coordinate planes, **§10 banned terms** |
| **[VOXEL_MASTER_PLAN](technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md)** | Voxel geometry: atoms, slices, edges, junctions, coordinate math |
| **[MAPFILE_REFERENCE](technical/MAPFILE_REFERENCE.md)** | The `.map.json` schema |
| **[ART_SPECIFICATIONS](../ASSETS/ART_SPECIFICATIONS.md)** | What art must conform to: authoring density, facades, roofs, props, **§7 damage decals** |
| **[VOXEL_LIGHT_MASTER_PLAN](../PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md)** | Voxel FACE lighting: 12-bucket brightness, blast soot/crater/ember visuals, destruction persistence, rotation perf, **per-face shading (FACE-READ-01/02)** |

### Master plans

Per-system status — most are paused mid-implementation, not blank slates.
Read the plan's own status header before proposing anything in its territory.

- **[OCCLUSION_MASTER_PLAN](../PROMPTS/PLANNING/OCCLUSION_MASTER_PLAN.md)** — ⏸️ Paused 2026-07-21; Parts 1–3 closed. O1: occlusion is VIEW, not STATE.
- **[DESTRUCTION_MASTER_PLAN](../PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md)** — 🟢 Part 3 (the trigger) done 2026-07-22; **Part 5 added 2026-07-29** — directional destruction, `CONE` shipped and `LINE` open. **D25/D26 (2026-07-31, 2026-08-01):** a DENTED voxel is a carved half-voxel oriented by the blast, and floors dent too. §7 q0 answers what a checkpoint restore does to holes. Sole writer of `Voxel.visible`. **D33 (2026-08-03), complete:** damage marks composite LIVE at room-load time — onto a real baked facade when available, onto the flat atom via a material-agnostic vector mark when it isn't (bake off, or no baked atom for that cell); `composites/` (the pre-baked PNG staging folder) is deleted permanently. Execution record: `PROMPTS/D33_RUNTIME_DECAL_COMPOSITING.md`. **D33-SOOT-01 (2026-08-03):** a DENTED/CRACKED voxel that never happens to sit beside a real hole now gets a faint self-soot on its own struck face too, instead of staying perfectly clean regardless of weapon/material.
- **[EXPLOSION_REBUILD_MASTER_PLAN](../PROMPTS/PLANNING/EXPLOSION_REBUILD_MASTER_PLAN.md)** — 🟢 BUILDING, Tasks 0–5 done (2026-08-05→07), **Phase A complete and polished into one organic event (0.9.93, "Alpha Explosion Waves", 2026-08-08/09)**. Supersedes `DESTRUCTION_MASTER_PLAN` Part 3 for explosions specifically. 4-ring spherical model (D14); pre-baked damage atoms shared across floor/wall/ceiling; a fully pre-resolved `DetonationPlan` (`DetonationPlanBuilder`, proven never to touch the live TileMapLayer before its own step fires) replayed by `DetonationChoreographer`. §3.5/D13: per-map declared material scope + cross-session bake cache, because materials are headed toward per-player procedural content, not a fixed catalog. Narrows `WEAPON_MASTER_PLAN`'s firearm-untouched boundary by one step (bullet-mark *painting* only, D12) — firearms confirmed unaffected by every task. **2026-08-08 earlier:** a silent GPU-upload-flush bug affecting every detonation's marks, found and fixed; the Post-Task-5 "fuligem quebradiça" A/B re-run clean and its conclusion **reversed** (the soot stamp IS the cause); the SLAB/SLICE seam formalized and closed as **D34 + D35** (a floor is a roof at the base of the scene — one grayscale `facade_<id>`, mirrored vertical repeat rather than a stretch, which also fixed a latent roof bug; `earth` became buildable). **2026-08-08/09 — the Alpha Explosion Waves session, 8 commits:** the blast soot stamp is OFF for now and a per-(surface, material) `[E-PLAN]` census replaced blended per-wave counts; **the floor finally CRACKS** (E-CRACK-01 — `apply_crater_damage()` had no crack roll at all, so D19's "floors crack like walls" was closed in the data and never in the code); smoke went from one puff per GU to **one per damaged voxel** with per-tier intensity and lifetime; the detonation gained a native burst, a **negative** screen flash and camera shake; **the fixed 15-wave table is retired** — the plan flattens into one queue of single-cell steps ordered by **radius from the epicentre**, so the blast reads as an expanding front instead of per-category blocks (171 category switches vs ~15), paced against a deadline with catch-up. The authored 4-frame fireball was **removed** — its style did not fit, and the blast's core is now built from this game's own overlays (embers/sparks/dust). Two measurements worth carrying forward: the sequence's cost is **per frame that writes to a TileMapLayer, not per cell** (a naive per-frame budget made it 3–20× slower while every log number improved), and the "engasgada" the Director kept feeling was a **150 ms frame**, not the flash. Commits `8dd926e`, `22b24be`, `9cd37ae`, `87fa023`, `6ec2566`, `a681af0`, `fde80ce`, `d5f5e59`, `8dab214`, `2c35ec0`, `b9ed121`, `d654149`, `04bfed1`. **Open:** Phase B (targeting UI, throw arc) not started; the Director's fine-tuning pass is the next concrete action; the crack decal art barely survives the downsample to a voxel face (art, not wiring); the GPU-flush safeguard is still undecided — resume point §11.
- **[PREDICTION_MASTER_PLAN](../PROMPTS/PLANNING/PREDICTION_MASTER_PLAN.md)** — 🔵 **PLANNED 2026-08-09, no code yet.** The engine's *simulate without committing* layer: a pure `simulate(action) -> WorldDelta`, a `commit(delta)`, and the pre-production + cache machinery around them. Opened by the Director as an ENGINE capability, not an explosion feature — guard AI ("what if I move there"), HUD estimates and the Phase B targeting bubble are all prediction consumers; explosions are only the first. **Three measurements opened it, all on a real PLAYGROUND blast:** `build_plan()` blocks **171 ms that appears in no existing log** (`[E-WAVE]` starts its clock after it returns); **101 of those ms are two map-wide phases** that do not shrink with a smaller grenade; and **only 41 ms of it mutates** — the cheap part is the dangerous part. Two findings de-risked the refactor: the whole soot layer is **already pure** w.r.t. Voxel (a model to copy, not a problem), and **firearms do not share the blast mutators** (D26/D27/D30 moved them to `apply_point_impact()`), so the purity work cannot retune a shotgun. Separately documents a shipping defect it does NOT own: the choreographer's wall-clock deadline collapses every blast into **3 frames** (2 057 of 2 185 steps land on one), which is why the already-shipped radial front never reads as an expanding wave — §6 fixes that independently and first. **Open:** Q1 ripple look, Q2 blast duration, Q3 the guard AI's real query shape (sizes the cache).
- **[INTERFACE_MASTER_PLAN](../PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md)** — 🟡 In progress; Waves 1–2 closed, Wave 3 not started.
- **[TOP_TEXTURE_MASTER_PLAN](../PROMPTS/PLANNING/TOP_TEXTURE_MASTER_PLAN.md)** — Parts 1–2 closed 2026-07-11; Part 3 blocked.
- **[ACTOR_MASTER_PLAN](../PROMPTS/PLANNING/ACTOR_MASTER_PLAN.md)** — 🟡 v1.4: Part 5a Showcase shipped — a real CC0 shotgun renders live in a main-menu screen, adaptive layout verified both orientations. Part 6's first exercise (floating/rotating collectible, real normal-map lighting) also shipped. **D30 (2026-07-29):** the same class now covers a second object and a static-facing mode, and its frames are shared per bake rather than per instance. Living-beings track (character twin/poses/damage) deferred.
- **[WEAPON_MASTER_PLAN](../PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md)** — 🟢 v1.0, 2026-07-29: the arsenal catalog. Six weapons on a range ladder; CONE ships and fires, LINE declared but unbuilt. **D13 supersedes the shipped cone for firearms** — a cone is aim-error spread, not a volume — so read §5b before touching `WeaponBenchController`. Owns *what* weapons emit, never *how* voxels break.

---

## Systems

| Built | Planned |
|---|---|
| [Perception](systems/perception.md) · [Lighting](systems/lighting.md) · [Noise](systems/noise.md) | [AI_MASTER_PLAN](systems/AI_MASTER_PLAN.md) |
| [Movement & turns](systems/movement.md) · [Stealth](systems/stealth.md) | [LIGHT_MASTER_PLAN](systems/LIGHT_MASTER_PLAN.md) |
| [Enemy AI](systems/ai.md) · [Rendering](systems/rendering.md) | [MAP_MASTER_PLAN](systems/MAP_MASTER_PLAN.md) |
| [Occlusion semantics](systems/occlusion.md) — *gameplay* (what blocks light/LoS/sound), **not** view occlusion | [Lighting runtime pipeline](systems/lighting_runtime_pipeline.md) |

Audio, animation, narrative and combat are at **0%**. There are no docs for them because
there is nothing to document — writing the roadmap before the system is how the last set
of docs rotted.

---

## Production

- **[production/README.md](production/README.md)** — index of this folder, with what got removed and why
- **[current_state.md](production/current_state.md)** — status by domain. Header auto-regenerated by `update_docs.py`; **this is the live one.**
- **[milestones.md](production/milestones.md)** — the executable list
- **[roadmap.md](production/roadmap.md)** — macro phases
- **[technical_debt.md](production/technical_debt.md)** — known issues
- **[METHODOLOGY.md](production/METHODOLOGY.md)** — the two axes (phases vs. milestones), milestone IDs, the domain enum
- **[TILE_ANATOMY.md](production/TILE_ANATOMY.md)** — tile geometry (audited by `tile_anatomy_audit.gd`)

## Technical

- **[repo_structure.md](technical/repo_structure.md)** · **[developer_setup.md](technical/developer_setup.md)**
- **[ASSET_MAP.md](technical/ASSET_MAP.md)** · **[TEXTURE_CATALOG.md](technical/TEXTURE_CATALOG.md)**
- **[INPUT_REFERENCE.md](technical/INPUT_REFERENCE.md)** · **[LOCALIZATION_REFERENCE.md](technical/LOCALIZATION_REFERENCE.md)**
- **[lighting_authoring_pipeline.md](pipelines/lighting_authoring_pipeline.md)**

## History

[design-concepts/](history/design-concepts/) — the original June 2026 concept docs.
**Their game design was recovered into [DESIGN_MASTER_PLAN.md](DESIGN_MASTER_PLAN.md)
on 2026-08-06** — go there, not here. These files stay archived and unmodified as the
provenance record; only their technical-state sections are genuinely obsolete, which is
what their DEPRECATED banners were about. Sprint logs, refactor logs, deprecated designs,
and the subcube wall-straddle record were deleted on 2026-07-12: a record of decisions we
no longer make, and **git already keeps it** —
`git show <sha>:docs/history/<file>` recovers any of it.

[SOLO_MODE_CONTEXT.md](history/SOLO_MODE_CONTEXT.md),
[OPERATOR_CONTEXT.md](history/OPERATOR_CONTEXT.md),
[OVERLORD_CONTEXT.md](history/OVERLORD_CONTEXT.md) — retired 2026-07-27,
superseded by `CLAUDE.md` (repo root). Kept in full, not deleted: they carry
philosophy and calibration detail `CLAUDE.md` deliberately doesn't duplicate.

---

## Where the working docs live

- `CLAUDE.md` (repo root) — auto-loaded every Claude Code session; the
  load-bearing subset of the retired files below, distilled for automatic
  loading. Correct it to match them if they ever disagree.
- `history/SOLO_MODE_CONTEXT.md`, `history/OPERATOR_CONTEXT.md`,
  `history/OVERLORD_CONTEXT.md` — **retired 2026-07-27**, superseded by
  `CLAUDE.md`. Kept for the fuller philosophy, delegation calibration, and
  the manual-injection workflow other tools may still use.
- `tools/persistent/CODEMAP.md` — generated; a pre-commit hook blocks a stale one
- `tools/persistent/run_selftests.py` — runs every `*_selftest.gd` and fails a
  run on any `SCRIPT ERROR`. The arbiter for selftests: a bare `godot --script`
  run can print one and still exit 0.
- `tools/persistent/QUICK_REFERENCE.md` · `ASSET_PIPELINE_QUICK_REFERENCE.md`
