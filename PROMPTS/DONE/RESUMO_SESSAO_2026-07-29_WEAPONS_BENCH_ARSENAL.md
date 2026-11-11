# RESUMO_SESSAO — 2026-07-29/30 (WEAPONS BENCH, ARSENAL CATALOG, SHOT PHYSICS)

**Active master plans:** `WEAPON_MASTER_PLAN.md` (**new this session**, D1–D24),
`DESTRUCTION_MASTER_PLAN.md` (Part 5 added, §7 q0 answered),
`ACTOR_MASTER_PLAN.md` (D30 added). No wave resumed — every item was a
same-session Director request.
**VERSION at session start:** 0.9.84
**VERSION at session end:** 0.9.85
**Mode:** Solo mode.
**Screenshot session:** not toggled; every capture via one-off
`INFILTRAITOR_SCREENSHOT_ONCE=1` / direct `INFILTRAITOR_AUTO_SCREENSHOT=1` runs.

---

## Executive Summary

The session went from a hung selftest to a working directional-destruction
weapon, six baked guns on a range ladder, and a ratified shot-physics model —
and ended by establishing that the shipped weapon mechanic is **the wrong shape**
and must be replaced. That is not a failure of the session; it is the session's
most valuable output, and it arrived because the Director described the physics
he wanted after seeing the thing work.

Three findings mattered more than the features:

1. **A cone is aim-error spread, not a volume of destruction** (D13). The
   shipped `flood_gu_cone()` destroys every slice inside the wedge, which is
   exactly why the shotgun read as both "área muito larga" and floor-to-ceiling.
   The correct model resolves each projectile to a **point** — a shotgun is 8
   scattered points, not one wedge. **This supersedes D1/D2 for every firearm.**
2. **Frames were costing 48.2 MB of VRAM per prop instance** — measured, not
   suspected, and found while sizing the *next* batch rather than from a bug.
   The four bench shotguns held four identical copies. Projected 1447 MB for the
   planned layout; fixed structurally to 49.8 MB before baking anything.
3. **A measurement caught a facing bug that reasoning had introduced.**
   `PERSPECTIVE_YAW_DEG` was copied verbatim from a working class and was wrong
   for E/W by ~180° — invisible on a grenade (which points nowhere), fatal on a
   weapon. A weapon aiming at a specific block is the project's first object
   whose facing is *falsifiable*.

## Wave Table

| ID | What | Status |
|---|---|---|
| FIX-SELFTEST | `slice_geometry_selftest` hung forever instead of failing loud (missing `quit(1)` + an uncatchable headless compile error); the hang had been masking a real stale-source-index failure | ✅ |
| CLEANUP-TILESET | `build_tileset.gd`'s recursive scan was sweeping voxel atoms and actor bakes into `tileset_blocks.tres` (65 sources → 4); orphaned voxel TileSet pipeline retired | ✅ |
| BENCH-01 | Test-zone inversion: shotgun becomes a placed aimed prop, grenade becomes the pickup. Static facing mode on `FloatingCollectible` — the bake already holds every facing, so a pointed prop is that flipbook frozen | ✅ |
| BENCH-02 | `FACING_YAW_DEG` measured by PCA + thin-end test; caught `PERSPECTIVE_YAW_DEG` E/W inversion (178.2° → 9.4° worst error over 4 views × 4 columns) | ✅ |
| WEAPON-CAT | `WEAPON_MASTER_PLAN.md`: four delivery shapes (RADIAL/CONE/LINE/NONE), step-falloff generalisation of `ring_multipliers`, boundaries against DESTRUCTION/ACTOR/AI | ✅ |
| WEAPON-FIRE-01 | `flood_gu_cone()` + `WeaponDef`/`WeaponRegistry` + `WeaponBenchController` + parameterised context menu → right-click "Atirar" chews a real hole. 6 new selftests | ✅ |
| WEAPON-ARSENAL | 5 archetypes baked from one table-driven tool at a shared framing (true relative sizes); range ladder y=4…13; `LINE` declared truthfully and **loud-fails** rather than firing a cone | ✅ |
| FRAME-MEM-01 | `CollectibleFrameCache` in the Registries autoload; static props load 4 frames of 120. 241 MB → 49.8 MB measured | ✅ |
| COLLECTIBLE-OUTLINE-02 | Outline becomes per-instance colour (rarity-ready) and a collectible-only affordance | ✅ |
| PHYSICS-REG | Shot-physics brainstorm registered: D12–D24 + nine questions (§7a), S1/S10 closed same day | ✅ |
| STATE-MODEL | Run-state model recorded in `ARCHITECTURE.md` §1: three tiers, two commit points, segment rewind | ✅ |

## Decisions (Director-ratified)

1. **A projectile resolves to a POINT; the cone is aim-error spread** (D13) —
   supersedes D1/D2 for firearms. `RADIAL` untouched: a blast really is a volume.
2. **Dice, not simulation** (D12): hit roll then damage roll, with **visibility
   explicitly decoupled from hittability**. The projectile does not exist in the
   scene — only its consequences are drawn. X-COM named as the reference.
3. **The hit roll is the only thing that must be forceable** (D21). Everything
   downstream of a miss is decoration; any outcome inside D16's ladder is correct.
4. **Rolls use the existing FNV-1a hash, not an RNG** (D22, delegated to me).
   Decided on cost: no seed plumbing, and every destruction selftest keeps
   asserting **exact** voxel sets instead of dropping to ranges. My own earlier
   seed proposal was *worse* — `(turn, shooter, projectile)` cannot even be formed
   on the bench, which has neither.
5. **World state is segment-scoped with two commit points** (D24): a checkpoint
   step or leaving the segment. Death rewinds; quit reloads the whole set; only
   character progression persists.
6. **The bench is a matrix** (D6) — weapon per row at its proper range, material
   per column; proper ranges first, inverted distances a deliberate second pass.
7. **A weapon's declared `delivery` is the truth even when unimplemented** (D11)
   — loud-fail beats silently firing the wrong geometry.

## Evidence

- `project_lint.py`: 0 real compile errors at every checkpoint.
  `check_invariants.py` / `gen_codemap.py --check`: clean at every commit.
- **All 18 selftests green at close**: `blast_calculator` 27/27 (was 21, +6 for
  CONE), `geometry` 29/29, `bake` 19/19, `roof_slab` 15/15, `slab_geometry`
  15/15, `negative_storey` 12/12, `floor_integration` 10/10, `floor_zone_bake`
  8/8, `roof_bake` 8/8, `slab_render` 8/8, `earth_variant` 6/6, `neon_flicker`
  6/6, `texture_resolver` 6/6, `fixed_floor` 5/5, `roof_integration` 5/5,
  `voxel_light_incremental` 5/5, `voxel_persist` 2/2, `slice_geometry` 44 checks.
- **The cone selftest compares against the RADIAL flood from the same source**,
  so it proves the cone is doing work rather than merely returning fewer cells.
- **Material differentiation from one weapon, three captures**: metal takes
  pockmarks (0.05), concrete opens a breach (0.50), wood loses a corner (0.90) —
  `auto_2026-07-29_20-29-28 / _20-30-34 / _20-30-43`.
- **Facing verified analytically across all four views AND by capture in three**;
  the analytic pass is what found the E/W inversion.
- **VRAM measured on real GPU**, three times: 48.2 MB per instance, 49.8 MB for
  the shared/sparse test zone, 13.6 MB bench-only vs 458.4 MB for the pickups.
- **Grenade regression re-run after rewiring the shared context menu**: crater,
  soot and wood embers intact.
- **A capture that proves less than it appears to**, stated as such in its own
  commit: `auto_2026-07-29_22-24-57` is pixel-identical to `_21-15-51`, which
  proves the bench was unaffected by disabling the pickups — it does **not** show
  them disappearing, since they sat outside that framing in both.

## Process learnings

- **Measure before multiplying.** The VRAM problem was found by sizing the next
  batch, not by a bug report. Six weapons × 4 columns would have shipped 1.4 GB.
- **A copied constant is not a verified constant.** `PERSPECTIVE_YAW_DEG` came
  from a class where it demonstrably worked, and was still wrong here — because
  the grenade it worked for has no orientation a human could falsify.
- **Two of my own proposals were beaten by simpler alternatives** once the
  constraint was stated properly: the seed (beaten by the existing hash) and the
  4-direction cheap bake (irrelevant, since one 120-frame bake already serves
  both the spinning and the frozen role). Worth naming both rather than quietly
  dropping them.
- **Ask what a capture proves.** Two captures being identical was the *evidence*
  in one case and a *trap* in another, within the same session.
- **New `class_name` scripts need a Godot rescan before `project_lint` sees
  them** (`--headless --editor --quit`), or the lint reports a phantom
  "Identifier not found" for the class's own name.

## Where this stands, and what blocks it

**The shipped weapon mechanic is known-wrong and deliberately left in place.**
`flood_gu_cone()` destroys a volume; D13 says it should scatter points. It was
not rewritten this session because the Director asked to plan the physics
properly first. Anyone picking this up should read `WEAPON_MASTER_PLAN` §5b
before touching `WeaponBenchController`.

**Blocking Part 3b (`LINE` + the physics rewrite):**
- **S7 — origin and target points do not exist.** D15's 360° trajectory and
  D18's chest height both need two 3-D points: agent chest or muzzle? enemy
  chest? which of the 8 `LEVELS_PER_STOREY`? Nothing can be derived without them.

**Awaiting Director instructions (explicitly paused, nothing changed):**
- Shotgun calibration — three candidates measured (§6b), *"vou fornecer
  instruções mais detalhadas"*. Note the numbers describe the model D13 replaces.
- Shot height limiting — *"vamos limitar a altura, aguarde mais detalhes"*.

**Open, unordered:** S2 (metal denting collides with inviolable Rule 8 — wants
baked "dented" atlas variants), S3 (face-local soot is a new data shape;
`soot_ring` is per-voxel while `VoxelLightField` already works per-face), S4
(noise is entirely absent from the physics brainstorm, in a stealth game), S5
(projectile pass-through/penetration), S6 (intervening geometry: hard block or
roll modifier — the cone currently reuses the *movement* gate), S8 (the bench
exercises only the miss path; hit/damage has no fixture), S9 (range cap, AP,
ammo, "environment interativo", actor voxel damage).

**Also surfaced, not owned by the arsenal:** the inventory of *other*
segment-scoped state. Fog of war is a known second payload; **enemy state, doors
and collected items are not inventoried anywhere** — and the Director's puzzle
case ("act in segment A, collect in B") needs at least some of them committed.

**Deliberately disabled:** the collectibles strip
(`TEST_ZONE_COLLECTIBLES_ENABLED`), after proving the pipeline. Flag, not
deletion — the table below it is derived data. VRAM reminder logged for Phase 8.

## Commits

`a686775` selftest hang · `6d4230b` + `7a410d6` tileset scan narrowed ·
`b8bd059` orphan voxel pipeline retired · `e98ad25` weapons bench + static
facing · `c1f6f76` WEAPON_MASTER_PLAN · `f56d924` outline per-instance ·
`e6b0934` CONE + right-click "Atirar" · `e944777` frame cache ·
`d18da45` five weapons + range ladder · `76b4adf` calibration measurements ·
`587dc51` collectibles disabled · `821caac` shot physics D12–D20 ·
`6ac3845` S1 closed · `9c6f8f4` D23 retired, save model · `77c6a19` run-state
model · (this close-out: RESUMO + VERSION 0.9.85).
