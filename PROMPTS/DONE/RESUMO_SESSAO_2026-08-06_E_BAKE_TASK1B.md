# RESUMO_SESSAO — 2026-08-06d (Task 1b / E-BAKE — damage-atom pre-bake, shipped)

**Continues:** `RESUMO_SESSAO_2026-08-06_E_MAT_TASK1A.md`, which closed with
Task 1a done and Task 1b as the next action.
**VERSION:** 0.9.90 (unchanged — no version bump requested).
**Commit:** `2d18a9e` — `[E-BAKE] Task 1b — damage-atom pre-bake: 273 real
atoms, cache-backed, wired`.
**Mode:** Solo mode.

---

## What shipped

`EXPLOSION_REBUILD_MASTER_PLAN.md` Task 1b (E-BAKE): a real load-time
damage-atom pre-bake, replacing the D-ARCH-01 dead code
(`DamageVariantBaker`/`VoxelVariantRegistry` existed but `room_builder.gd`
fed the registry nothing — a literal `TODO (D-ARCH-01 Phase 2)`).

- **`Voxel.damage_substrate`** (new field, D3/§3.3) + `BlastCalculator.
  substrate_for()` (mirrors `decal_variant_for()`, different hash salt) +
  `room._base_damage`'s 7th column, persisting which of 3 pre-baked
  substrate crops a mark's decal sits on, same read-once/rotation-safe
  discipline as the existing `damage_variant` field.
- **`VoxelVariantRegistry`** re-keyed from `(grid_pos, level, material)` to
  `(element_class, material, damage_material_name, substrate_variant)` — no
  cell dimension, matching the atom model's premise (a damaged voxel shows a
  randomly chosen facade crop, never its own).
  `VoxelRenderer.apply_damage_voxel_swap()` rewritten to build this key from
  the voxel's own state.
- **`DamageVariantBaker.bake_all(declared_materials, floor_materials)`** —
  one entry point, called once per map load. Enumerates WALL (DENTED
  blast+bullet, CRACKED bullet always + blast when `crack_factor > 0`,
  D10-derived not the old hardcoded `IMPACT_CRACK_MATERIALS` list), CEILING
  (D6's shared CRACKED atom + its own DENTED-bottom carve), FLOOR (D9, real
  ground material). Drives the *same* D33 compositor functions
  (`_composite_full_voxel_decal()` etc.) via a synthetic, edge-free
  substrate crop — `edge == null` now branches those two functions onto
  `resolve_flat()` instead of the edge-based `resolve()`.
- **D13's `damage_materials` MAPFILE section** registered (mirrors Task 1a's
  `floor_zones` v1→v2 as the worked pattern); PLAYGROUND declares its 4 real
  materials. `room_builder.gd` forces the 3 chosen substrate positions into
  real wall/roof/floor bake usage before `BakeCompositor.bake()` runs
  (confirmed via research: the compositor bakes *sparsely*, only real
  placement usage composes a tile) and loud-fails (push_warning, B6) if a
  map uses a material it never declared.
- **`user://` disk cache** for the atoms — reused `BakeCompositor`'s own
  encode/decode/load/save helpers via a new overridable `cache_dir` param
  rather than duplicating them, sibling directory
  (`user://damage_atom_cache/`).

## The real numbers, not projections

- **273 atoms** baked on PLAYGROUND, 0 unresolved (not the plan's ~207 or my
  own pre-code estimate of ~279 — the real, measured count).
- **Cold load: ~1.5 s.** **Warm (cache) load: ~31 ms.** 255/255 disk cache
  hits, 0 misses, 0 saves on the second run.
- `apply_damage_voxel_swap()` verified against a real PLAYGROUND wall voxel
  (selftest) and a real fired shotgun blast (9/9 hits logged through the new
  key, via a temporary print — added, verified, and reverted the same
  session, `grep -n E-BAKE-VERIFY-SPIKE` comes back empty).

## Two corrections found by reading the actual code, not the plan summary

1. **Confirmed with the Director:** bullet marks bake **both** shapes
   (cracked full-voxel *and* dented half-voxel — 144 atoms, not the plan's
   72), since `ShotPunchTable.damage_state_for()` genuinely produces either
   outcome and D12's whole point was moving bullets fully off live
   compositing. Asked via `AskUserQuestion` before implementing — this was a
   real scope/cost decision, not a detail to guess past.
2. **D7's "3 irregular ceiling cut shapes" isn't built.**
   `HalfVoxelCompositor.carve_ceiling_silhouette()` takes no shape parameter
   — only 1 shape exists in the actual art/code. Ceiling DENTED bakes 1
   shape × 3 substrates per material, not 3 shapes × 3. Documented in the
   baker's own header rather than silently pretending unbuilt art exists.

## The finding that changes the plan's own next steps

`_process_dirty_slice_voxel()` already called `apply_damage_voxel_swap()`
unconditionally, first, before any D33 live-compositing fallback — this was
pre-existing D-ARCH-01 wiring nobody had removed, just starved of a
populated registry. **The moment Task 1b's `bake_all()` populates that
registry for real, firearm bullet marks start resolving through the
pre-bake automatically — zero lines of `WeaponBenchController.fire_active()`
touched.** The master plan's own §9/§11 had planned a *separate, later
checkpoint* to "rewire `fire_active()` onto the pre-baked atoms," on the
assumption that the call site itself needed code changes. That assumption
was wrong, verified with a real spike (temporary print in
`apply_damage_voxel_swap()`, confirmed against a real fired shot, reverted
before commit). Master plan updated: that checkpoint is gone from the
task list; the only remaining "flip the switch" moment is
`TestZoneController.detonate_active()` rewiring onto `BlastCalculator` for
*explosions*, which was always Task 2+'s job, not Task 1b's.

## Verification (per CLAUDE.md's evidence discipline)

- `project_lint.py`: 183 files, 0 errors, at every intermediate step.
- `run_selftests.py`: 31/31 clean (30 existing + new
  `damage_atom_bake_selftest.gd`). Caught and fixed a real false-green along
  the way: the new selftest's first draft crashed on a typed-Array
  assignment (`_baked_source_ids` is `Array[int]`, a plain `Array` value
  rejected it) *inside* `_init()`, silently aborting two of the four test
  functions before they reached a single `_pass()`/`_fail()` call — yet the
  suite still reported "5 PASS, 0 FAIL" (GDScript can't catch its own script
  errors in-process, exactly the failure mode `run_selftests.py`'s own
  header comment warns about). Fixed by building a properly-typed
  `Array[int]` before assignment; re-ran to confirm all 7 real assertions
  execute and pass.
- `check_invariants.py`: OK. `gen_codemap.py --check`: clean (184 scripts).
- Also ran the 3 non-glob test files this session's changes could plausibly
  affect (`bake_cache_test.gd`, `mapfile_roundtrip_test.gd`) by hand — clean.
- Real PLAYGROUND boot: 273 atoms, 0 unresolved. Real cache-hit boot: 31 ms,
  255/255 hits. Real firearm-fire capture
  (`Screenshots/history/e_bake_firearm_sanity.png`): marks render correctly,
  D33 live path unaffected.

## State at close

- `EXPLOSION_REBUILD_MASTER_PLAN` is 🟢 **BUILDING**, Task 0/1a/1b done.
- **Task 2 (E-RING) is the next concrete action** — 4th ring, per-tier
  weight tables, D14's spherical falloff, D15 roof-throw holes, D16 blast-
  side routing, D17 slab-pierce multiplier, D2 two-layer floor, D9's real-
  material floor resistance lookup.
- Explosive destruction is still a no-op (`detonate_active()` not yet
  rewired to `BlastCalculator` — that's Task 2+'s job). Firearms work,
  *and now consume the pre-bake automatically* — the one thing this session
  changed about them, as a side effect, not a deliberate rewiring.
- Pushed to `main` (pending — see next message).
