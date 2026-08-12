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
- **[EXPLOSION_REBUILD_MASTER_PLAN](../PROMPTS/PLANNING/EXPLOSION_REBUILD_MASTER_PLAN.md)** — 🟢 BUILDING, Tasks 0–5 done (2026-08-05→07), **Phase A complete and polished into one organic event (0.9.93, "Alpha Explosion Waves", 2026-08-08/09)**. Supersedes `DESTRUCTION_MASTER_PLAN` Part 3 for explosions specifically. 4-ring spherical model (D14); pre-baked damage atoms shared across floor/wall/ceiling; a fully pre-resolved `DetonationPlan` (`DetonationPlanBuilder`, proven never to touch the live TileMapLayer before its own step fires) replayed by `DetonationChoreographer`. §3.5/D13: per-map declared material scope + cross-session bake cache, because materials are headed toward per-player procedural content, not a fixed catalog. Narrows `WEAPON_MASTER_PLAN`'s firearm-untouched boundary by one step (bullet-mark *painting* only, D12) — firearms confirmed unaffected by every task. **2026-08-08 earlier:** a silent GPU-upload-flush bug affecting every detonation's marks, found and fixed; the Post-Task-5 "fuligem quebradiça" A/B re-run clean and its conclusion **reversed** (the soot stamp IS the cause); the SLAB/SLICE seam formalized and closed as **D34 + D35** (a floor is a roof at the base of the scene — one grayscale `facade_<id>`, mirrored vertical repeat rather than a stretch, which also fixed a latent roof bug; `earth` became buildable). **2026-08-08/09 — the Alpha Explosion Waves session, 8 commits:** the blast soot stamp is OFF for now and a per-(surface, material) `[E-PLAN]` census replaced blended per-wave counts; **the floor finally CRACKS** (E-CRACK-01 — `apply_crater_damage()` had no crack roll at all, so D19's "floors crack like walls" was closed in the data and never in the code); smoke went from one puff per GU to **one per damaged voxel** with per-tier intensity and lifetime; the detonation gained a native burst, a **negative** screen flash and camera shake; **the fixed 15-wave table is retired** — the plan flattens into one queue of single-cell steps ordered by **radius from the epicentre**, so the blast reads as an expanding front instead of per-category blocks (171 category switches vs ~15), paced against a deadline with catch-up. The authored 4-frame fireball was **removed** — its style did not fit, and the blast's core is now built from this game's own overlays (embers/sparks/dust). Two measurements worth carrying forward: the sequence's cost is **per frame that writes to a TileMapLayer, not per cell** (a naive per-frame budget made it 3–20× slower while every log number improved), and the "engasgada" the Director kept feeling was a **150 ms frame**, not the flash. Commits `8dd926e`, `22b24be`, `9cd37ae`, `87fa023`, `6ec2566`, `a681af0`, `fde80ce`, `d5f5e59`, `8dab214`, `2c35ec0`, `b9ed121`, `d654149`, `04bfed1`. **Phase B (targeting UI, throw arc) is BUILT — see `TARGETING_MASTER_PLAN` below.** **Open:** the crack decal art barely survives the downsample to a voxel face (art, not wiring); the GPU-flush safeguard is still undecided — resume point §11. **2026-08-10 (0.9.95, "Alpha Grenade Shrapnel", planning only, no code):** Q6 (the white strobe frame) resolved by deleting it rather than tuning it — a camera-facing shard now darkens into the existing negative flash — and a six-task ordered plan (E-RAY through E-BUBBLE) covers it plus decorative shrapnel, a dented/cracked debug overlay, a late soot fade-in beat, and Phase B's aim-bubble (which turns out to need none of the prediction machinery for its first version). A confirmed future mechanic — holes relighting the room, affecting shadows and detection — was scoped OUT to its own milestone rather than folded in. See the new dated section "E-FRAG-01 / E-SHARD-01".
- **[TARGETING_MASTER_PLAN](../PROMPTS/PLANNING/TARGETING_MASTER_PLAN.md)** — 🟢 **BUILT 2026-08-10/11 (0.9.96, "Alpha Bubble Foundation").** `EXPLOSION_REBUILD`'s Phase B: the grenade aiming UI that feeds Phase A. G → aim → tap or Enter → arc → bounce → 1 s cook → detonation, running end to end. **It ran none of that when the session opened** — the previous pass reported it complete with `34/34 selftests clean`, and an audit found the throw aborting on its first frame (`SceneTree.get_physics_frame()` does not exist in Godot 4.6), ESC opening the Main Menu instead of cancelling, Enter consumed before GUI input (which had also killed the context menu's focused button and the `test_zone_detonate` capture), the bubble sized from the throw range instead of the blast, and the throw using the raw hovered cell while the preview showed a clamped one. **The load-bearing piece is `IsoProjection`** — one analytic home for "a shape in GAME UNITS drawn on the isometric plane", whose basis is MEASURED against `tileset_blocks.tres` rather than reasoned from Godot's layout enum, because a self-comparison would pass whatever the constants said: zero off-diagonal ⇒ axis-aligned ellipses, floor circle exactly 2:1 at (181.02, 90.51) px/GU, sphere (181.02, 183.83) ⇒ very nearly a circle, and normalised radius == `(grid distance / R)²` in every direction, which is what lets a radius here mean a real number of cells. **Shipped:** a 2 GU orange dome (sphere ellipse closed by its floor section, tangent at the extremes; the rim passes through the cells two out, and that spill is the message — deliberately NOT the predicted footprint, holes and all); shrapnel rays taking their directions from the same wall-aware BFS the blast floods with and their lengths from an ellipse; a 7 GU throw perimeter (whole number on purpose — cell centres only sit at integer offsets); the affected GUs graded per ring with MovementOverlay's own mechanism, zero-damage rings excluded by data rather than a hardcoded −1; a virtual grenade cursor built from `GrenadeProp`'s REAL baked frames under `virtual_grenade.gdshader`; and a genuinely ballistic throw that accounts for the grenade leaving the hand above the floor it lands on (apex at t ≈ 0.455, the fall the longer half), with one continuous angular velocity from release to rest. Both red diagnostics are dev-vision-only — the player's HUD is dome, rays, virtual grenade, arc. Right-click "Detonar" was restored alongside the G flow, which is what keeps the choreography and performance work testable. **Closed since (§6.1/§6.3):** the grenade's ground shadow, the settle roll (now graduates freely with distance/energy), and E-FRAG/E-DEBUG-RAY (2026-08-12 — a nonexistent `VoxelRenderer` method name, then a near-black colour on `BLEND_MODE_ADD` that rendered every frame while being invisible). **Attempted then paused (§6.2, 2026-08-11/12):** wall sectioning of the dome — a real lat/long wireframe grid with each vertex cast as a 3D ray against nearby walls' real per-edge height (`room._wall_height_edges`, retained from `EdgeExtractor` instead of discarded) verifiably worked, but the Director rejected the curved-clamp SHAPE on sight ("mais angulosa") and it's reverted to a plain grid pending a refined spec; the height-aware data stays retained for the redo. **Still open, not this plan's to fix:** `detonation_choreographer_selftest` fails deterministically (91% of the front on one frame) since `[E-FUME]` pulled soot out of `WAVE_TABLE` — proven red/green.
- **[PREDICTION_MASTER_PLAN](../PROMPTS/PLANNING/PREDICTION_MASTER_PLAN.md)** — ✅ **BUILT 2026-08-09, all six tasks.** The engine's *simulate without committing* layer: `simulate(action) -> WorldDelta`, `delta.commit()`, and the pre-production + cache machinery around them. Opened by the Director as an ENGINE capability, not an explosion feature — HUD estimates and the Phase B targeting bubble are prediction consumers; explosions are only the first (guard AI is explicitly out of scope, Q3). **What shipped:** the two blast mutators are `commit(simulate(…))`; `DetonationPlanBuilder.build_plan()` changes nothing and returns a `WorldDelta` carrying the waves, census, touched cells and cost; the pipeline is an 11-phase resumable, cancellable state machine, and `build_plan()` is that machine with an unlimited budget; predictions are cached on `(signature, world_revision)` and start when the player picks a target, so **the detonation no longer freezes the camera** — whatever is left finishes under a burning grenade. **The whole arc is 0-differing-pixels against the pre-refactor capture.** Two gates recorded as short rather than declared met: §4.4's 4 ms per-frame budget (worst unsuspendable visit 7–9 ms, §8.8 names the phases and costs the fix) and the total build cost (~192 ms vs a pre-refactor 178 ms — what purity costs). **§8.8 also corrects §1.1's opening phase table**, which every earlier decision was reasoned from: the soot BFS is 10 ms not 66, the light field 0.1 ms not 35, and the map-wide voxel walk — never a separate phase — is 66% of everything. **§10 Q6 answered 2026-08-10**, not by tuning `strobe_white_alpha` but by removing the white frame from the strobe entirely — full mechanism lives in `EXPLOSION_REBUILD_MASTER_PLAN`'s "E-FRAG-01 / E-SHARD-01" section, per this plan's own division of labour with look/choreography work.
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
