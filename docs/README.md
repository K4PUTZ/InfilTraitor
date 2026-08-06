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
| **[BAKE_SYSTEM_REFERENCE](technical/BAKE_SYSTEM_REFERENCE.md)** | The bake: atlas, atoms, invariants B1–B6, themes, the `blit_rect` silent-clip trap |
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
- **[EXPLOSION_REBUILD_MASTER_PLAN](../PROMPTS/PLANNING/EXPLOSION_REBUILD_MASTER_PLAN.md)** — 🟠 Planning, nothing built. Supersedes `DESTRUCTION_MASTER_PLAN` Part 3 for explosions specifically. 4-ring model, 207 pre-baked damage atoms shared across floor/wall/ceiling (materials × decals × substrates, derived from `MaterialResistanceTable` — no per-cell bake), a 15-wave `set_cell()`-only choreography. §3.5/D13: per-map declared material scope + cross-session bake cache, because materials are headed toward per-player procedural content, not a fixed catalog. Narrows `WEAPON_MASTER_PLAN`'s firearm-untouched boundary by one step (bullet-mark *painting* only, D12 — see that plan's §3). Resume point: §11 — Task 0's bake-cost spike is next, one open question (Q1b, the vertical-falloff formula) left.
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
