# RESUMO_SESSAO — 2026-08-06b (doc recovery, codebase audit, Task 0, material reform decided)

**Continues:** `RESUMO_SESSAO_2026-08-06_EXPLOSION_REBUILD_ANSWERS.md`, which
closed with Task 0 (the bake-cost spike) as the next action and Q1b open.
**VERSION:** 0.9.89 at start → **0.9.90 at close** ("ALPHA EXPLOSION REBUILD
READY").
**Mode:** Solo mode.

---

## Executive summary

Four distinct blocks of work, in order: a **documentation recovery** that
pulled the game's design canon out of an archive nobody was reading; a
**full-codebase audit** that found two broken tests and one export-breaking
issue; **Task 0**, the measurement that gates the whole explosion
architecture, which passed with 2.7× headroom; and a **material reform**
(D19–D21) that the Director pulled in front of the bake work.

Phase A of `EXPLOSION_REBUILD_MASTER_PLAN` now has **zero open questions**.
The next concrete action is **Task 1a (E-MAT)**.

---

## 1. Documentation recovery — `docs/DESIGN_MASTER_PLAN.md`

The June 2026 design archive was stamped **DEPRECATED** for its *architecture*
sections, which buried the game design under the same banner. That design had
never been superseded by anything: combat and the 4 cover states, the 3-layer
resistance model and the tenth-shot rule, the 3 equipment classes, the enemy
factions and 6-rank guard hierarchy, segment map structure, Freelance
escalation — plus the guard-AI depth in `infiltraitor_enemy_ai_system.md`
(3 state layers, `GuardKnowledge` with no global blackboard, dual-cone FOV,
deterministic sweep, delayed activation, `GuardProfile`).

All of it recovered into **`docs/DESIGN_MASTER_PLAN.md`**, in English, tagged
BUILT / PARTIAL / DESIGNED per section, and linked from `docs/README.md`
"Start here" and `CLAUDE.md`'s reference map. Two sections are **not** from
the archive:

- **§19** — the six architecture rules the endless-game model depends on
  (they are the origin of `CLAUDE.md`'s inviolable Rule 1).
- **§20** — where the shipped build already diverges from the design, every
  row read out of the code rather than copied from another doc.

The archives stay unmodified as the provenance record. Their §17-equivalent
technical-state sections were deliberately **not** recovered — those were
genuinely obsolete, and that is what earned the DEPRECATED banner.

### Stale claims corrected in `current_state.md`, all verified against code

- Perception was marked "🚨 not connected"; `turn_controller.gd:212-222` calls
  `observe_player()` at the 0.30/0.60/1.00 thresholds, and the file's own AI
  section said so 200 lines earlier.
- Voxel rendering read 40%/Alpha next to a table calling it the only wall
  renderer at Beta.
- "Dirty Flag + TIC updates" was still *Planned CONTAINER-05*; it shipped as
  VOXEL-07 in the same document.
- View occlusion was still "Planned"; Parts 1–3 closed 2026-07-21 and
  `occlusion_set.gd` / `occlusion_overlay.gd` exist.
- The "2–4 week demo" estimate and the "Maintained By: GitHub Copilot" footer
  are now dated to the milestone they describe instead of reading as current.
- `docs/README.md` described `METHODOLOGY.md` as covering the retired
  Director/Overlord/Operator split, which that file has never mentioned; two
  screenshot tools named the Overlord as an actor.

---

## 2. Codebase audit (AUDIT-01)

Clean: `project_lint` 181 files 0 errors · `check_invariants` OK · CODEMAP
fresh · **29/29 selftests** · git tree clean · zero banned terms · zero
`printerr` · real `room.tscn` boot with **0 SCRIPT ERROR**.

### Fixed this session

- **`occlusion_set_test.gd` was a false green** — printed `SUMMARY: 3/5 tests
  passed` / `[FAILURE] 2 test(s) failed` and still **exited 0**. Every test
  handed `recompute()` a raw `Array[Vector2i]`; OCC-07 moved the decision to
  per-Slice, so `_group_slices_by_edge()` had been reading `.voxels` off a
  `Vector2i` ever since. GDScript aborts only the erroring function, so the
  set came back empty and the surviving "passes" were vacuous — one literally
  printed `Cardinality reasonable: 0 cells (expect dozens)`. Fixtures now
  build the real `Slice`/`Voxel` shape, and depth-ordering refuses to pass on
  an empty set (it was *still* passing over 0 cells after the shape fix,
  because its span sat entirely behind the agent — now 23 real cells).
  **Ring ORDERING coverage was deliberately reduced and says so in the file:**
  it asserted ring-vs-euclidean-distance through four properties that no
  longer exist, and OCC-08/09/10 replaced concentric circles with
  adjacency-graph propagation, under which the old assertion is *false*, not
  merely misconfigured. Range is asserted instead.
- **`input_controller.gd:62`** — `get_tree().paused` was unguarded while
  `get_viewport()` ten lines above was guarded. Off-tree that threw 17 SCRIPT
  ERRORs in `input_controller_test`, which now exits 0 clean.
- **`run_selftests.py` now names its own blind spot.** Eight
  `*_test.gd`/`*_tests.gd` files sit beside the `*_selftest.gd` glob and had
  always been invisible to the arbiter. Renaming them in is not free
  (`prop_01_tests` and `version_info_test` need autoloads `--script` does not
  instantiate), so the runner lists what it did not run.
- **`room_builder.gd` `_get_prop_registry()`** — its `TODO: Fix Registries
  reference` was false; `Registries` is a registered autoload and
  `ensure_prop_registry()` exists. Comment corrected to state what is true
  (PROP-01's PropDef path is unreachable; nothing is missing on screen because
  maps use the legacy tile path) and that re-enabling is a Director call. No
  behaviour change.

### Reported, deliberately NOT fixed — needs a Director decision

**61 assets are loaded in a way that cannot work in an exported build.** The
real boot emits **85** engine warnings: *"Loaded resource as image file, this
will not work on export."* Three production sites call `img.load()` on `res://`
paths — [`texture_resolver.gd:83`](godot/scripts/systems/texture_resolver.gd:83),
[`collectible_frame_cache.gd:59`](godot/scripts/systems/collectible_frame_cache.gd:59),
[`grenade_prop.gd:178`](godot/scripts/overlays/grenade_prop.gd:178) — covering
the 5 texture defaults and 56 actor-bake frames.

The reason is legitimate *in the editor*: bake output is written by `--script`
CLI runs, never passed through the import scan, so plain `load()` fails with
"No loader found" and `Image.load()` sidesteps the import cache. It is exactly
that sidestep that cannot work inside a packed `.pck`.

**Why nobody noticed:** the last APK is **2026-07-18** and the last web build
**2026-07-06**; all three call sites landed **2026-07-28/29**. Nothing has been
exported since the code that breaks exports was written. Not confirmed by a
real export — that is the check to run. Its fix (route bakes through `user://`,
or register the assets with the import system) is larger than a patch.

---

## 3. Task 0 — the number the whole architecture rests on

**~737 ms to bake all 207 atoms, against a ~2 s gate. Passes with 2.7×
headroom, so §3.4's escape hatches are not taken.** Three runs: 742.3 / 731.3
/ 739.0 ms, spread 1.5% — not a single sample.

| Cohort | Atoms | Cost | Per atom |
|---|---|---|---|
| Wall (`_composite_full/half_voxel_decal`) | 162 | ~680 ms | ~4.2 ms — effectively the entire cost |
| Ceiling (`_composite_ceiling_carve`) | 36 | ~13 ms | ~0.35 ms — silhouette carve, no decal |
| Floor (`_composite_floor_sunk_decal`) | 9 | see caveat | — |

All three classes measured **separately** — they use three different
compositors, so projecting the table off one path would have been a guess.

Method discipline: `BakeConfig.enabled` asserted true **before** timing (a
false would have measured misses, not composites); every call used a distinct
`(grid_pos, level, material_name)` key so the per-cell cache never
short-circuited one — **0 misses** in the wall and ceiling cohorts. Hook
reverted before commit; `grep -n explosion_bake_spike` comes back empty and
`room.gd` is byte-identical to its pre-spike state.

**Why this is not the old ~95 ms/voxel figure:** that was per-cell and partly
cold over 71,296 placed cells. The atom model removes the cell dimension — the
unit cost barely moved, the count collapsed by three orders of magnitude.

**Flagged for Task 1b, not diagnosed:** the floor cohort needed **7,305
attempts to land its 9 atoms** (7,296 misses, consistent across all three
runs), suggesting `resolve_flat()` finds no baked atom for almost every floor
cell. The 9 timed composites are genuine, so the number stands.

---

## 4. Decisions taken (D14–D21) — Phase A is now fully specified

| # | Decision |
|---|---|
| **D14** | **Spherical falloff.** One ring step per 8 voxels in *every* direction. `VOXELS_PER_UNIT_AXIS = 8` and `LEVELS_PER_STOREY = 8`, so a storey of height measures a GU of width — it is a sphere by construction, not by approximation. |
| **D15** | A grenade can be thrown **onto a roof**, opening a hole in the slab, on the floor's exact destruction model. |
| **D16** | **Which existing atom pool a slab draws from is decided by the blast's SIDE, not the slab's role.** Grenade on the floor → ceiling takes it from below → ceiling atoms, unchanged. Grenade on a roof → that slab behaves as a floor and shows the floor's existing atoms. **Adds no atoms.** |
| **D17** | One grenade pierces one slab; the next grenade the next slab down. Task 2 exposes a **named calibration multiplier**, distinct from `destroy_multiplier`. |
| **D18** | **Upper storeys are not playable.** They compose scene height. A roof hole is a **lighting** event, never an access route. |
| **D19** | **A material behaves identically on floor, wall and ceiling** — durability, baked assets, soot, effects, ember. |
| **D20** | The naming logic: material id `concrete` (one row); vertical texture `facade_concrete` (SLICE); horizontal texture `slab_concrete` (SLAB — floor *and* ceiling). |
| **D21** | **Material properties are dynamic data, never hardcoded, never map-coupled.** |

### Two things D14 changed in existing code, found by reading it

1. **For walls the formula already ships** — `apply_container_damage()`
   computes `floor(level_offset / LEVELS_PER_STOREY)` today. §4.3 proposed
   something that exists.
2. **It retires a documented deliberate asymmetry.** The same function advances
   roofs one ring per **raw level** because `ROOF_LEVEL_COUNT` is 2, and its
   comment ends *"Deliberate asymmetry, not an oversight — flagged for review
   if a real capture shows it reading wrong."* D14 is that review and goes the
   other way. **Visible consequence: roofs stop showing internal top-vs-bottom
   grading**, judged at Task 5.
3. `maxi(0, …)` must become `absi(…)` — the clamp assumed nothing exists below
   a floor-level blast, which D15 breaks.

### D20's naming was measured, not guessed

`facade` is **512 occurrences** across 31 `.gd` files, 35 docs, 8 assets — and
**zero map files**. `ground_` is **107 occurrences** and **is** in 2 maps. So
`facade_*` stays (5× the churn for no semantic gain, and it is the bake
system's entrenched vocabulary) while `ground_* → slab_*` changes anyway: the
maps carry it, so a MAPFILE migration is happening regardless, and *ground* is
semantically wrong under D19 because a ceiling is a slab and is never ground.

### D21's two current violations, both in Task 1's path

- `MaterialResistanceTable.TABLE` is a `const` Dictionary literal.
- `MaterialRegistry.register_defaults()` hardcodes the roster — and the
  `ground_*` resistance rows were added *because PLAYGROUND specifically* has
  a concrete floor, which is exactly the map-coupling D21 forbids.

Same direction as `CLAUDE.md`'s inviolable Rule 1, whose checker scopes only
the named gameplay stats and so never flagged this.

### What closed for free

**D10's `crack_factor` gap is void.** `MaterialResistanceTable` carries two
rows for one material — `concrete {0.3, 0.15, 0.1}` and
`ground_concrete {0.5, 0.2, 0.0}` — and that disagreement *is* the gap. Under
D19 there is one concrete row, `crack_factor` 0.1, floors crack like walls.
The "216-atom variant" note the gap generated is void; the table stays at
**207**.

---

## 5. Phase 3's sequencing, finally written down

The Director ratified *why* the engine work precedes the gameplay loop, in
answer to an assessment that had read it as scope drift:

```
destruction → light & shadow layout → guard reaction, agent movement,
                                      which route, HOW MANY TILES, sound
                                      propagation, patrol routing
```

Light and shadow are **tactical**, not decorative (`SHADOW_MULT = 0.30`,
`PENUMBRA_MULT = 0.55`, the five exposure classes). Destruction moves where
light falls, so calibrating detection, movement cost or patrols first would be
calibrating against numbers that are still going to move. `tic_system.gd` and
`noise_system.gd` untouched since 2026-06-17 is **not neglect** — they wait on
inputs that are not final. Recorded in `roadmap.md` Phase 3.

---

## 6. State at close

- `EXPLOSION_REBUILD_MASTER_PLAN` is 🟢 **BUILDING**, Task 0 done, **zero open
  questions in Phase A**.
- Task 1 split: **1a (E-MAT)** the material reform, then **1b (E-BAKE)** the
  original bake work reading 1a's unified table.
- Explosive destruction is still deliberately a **no-op**; firearms still work.
- Nothing in `godot/scripts/` changed except the four AUDIT-01 fixes.

## 7. Next session starts here

**Task 1a (E-MAT).** Its gate is a **pixel-identical PLAYGROUND capture** —
1a changes names and plumbing, never appearance; if the capture moves,
something broke. Deliverables in `EXPLOSION_REBUILD_MASTER_PLAN` §8's Task 1a
row.

Take a **reference capture before touching anything** — that is the
before-half of the gate and cannot be reconstructed afterwards. Give it a
hand-picked name (`e_mat_before.png`), never `auto_*`: the 50-file rotation
eats those, and 16 of 23 `auto_*` citations across the docs were already dead
when measured on 2026-08-03.

Two items carried forward, neither blocking:
- The **export-unsafe `Image.load()`** issue (§2) — Director decision pending.
- The **floor cohort's 0.1% hit rate** (§3) — look at it when D9 rewires floor
  specials onto pre-baked SLAB atoms in Task 1b.
