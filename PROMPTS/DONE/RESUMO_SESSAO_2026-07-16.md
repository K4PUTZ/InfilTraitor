# RESUMO_SESSAO — 2026-07-16

**Active master plan:** `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` —
**PAUSED at Alpha Ceiling Foundation** (end of this session).
**VERSION at session start:** 0.9.31
**VERSION at session end:** 0.9.44
**Mode:** Overlord direct implementation, continued from prior sessions
(occlusion paused at Alpha Foundation 2026-07-15; this session picked up
`DESTRUCTION_MASTER_PLAN` from Part 0 through a new Part 2b).
**Test fixtures:** synthetic headless selftests throughout, cross-checked
against the real `PLAYGROUND` map (`FileMapSource`/`MapCompiler`, the exact
path `room.gd::load_map()` uses) for every integration claim.

---

## Executive Summary

**Session focus:** the entire session was `DESTRUCTION_MASTER_PLAN`, start
to a natural pause point. Opened with a code-state check and a technical-debt
correction pass, then ran the full arc: Part 0 (measurement spike) → Part 1
(`Slab` container) → Part 2 (floor: palette + hash selector, negative
storey, fixed levels, real map integration) → an unplanned but real
"lajes"/roof-ceiling feature (Part 2b, `Slab.Role.CEILING`, all-destructible,
existing wall materials, real map integration, and a real border-overlap
bug found and fixed via the real map, not assumed safe).

**Governing discipline, held throughout:** every wave landed as build →
lint → real headless run (never trust code-reading) → regression-check every
prior selftest → document in the plan → commit (bundling VERSION bump) →
push. Several times a design assumption was corrected *after* real evidence
contradicted it (D2's "generalize the junction compositor" turned out wrong;
the first roof-border fix turned out incomplete) — both times the fix
shipped only after the contradicting evidence was in hand, not before.

---

## Wave table (this session)

| ID | What | Status |
|---|---|---|
| — | Code-state check: `technical_debt.md` corrections (overlay "per-frame" claim never matched the code; `BAKE-CACHE-01` already resolved 2026-07-11, stale "open" claim propagated into 3 docs) | ✅ `a99b98c` |
| DESTRUCTION-PART0 | Measurement spike: TileMapLayer scaling, full-floor voxelization, bake-combo scaling. Go/no-go: GO | ✅ `1143930` |
| DESTRUCTION-PART1 (D1) | `Slab`/`SlabRegistry` — container sibling of `Slice`, dirty-count/TIC-skip, mirrors `EdgeRegistry` | ✅ `1143930` |
| — | Guard the pre-existing Registries-autoload headless gap in `slice_geometry_selftest.gd`/`prop_01_tests.gd` (found while verifying Part 0/1, unrelated) | ✅ `8a56062` |
| DESTRUCTION-PART2-CORE (D2/D4) | Corrected: floor is a hash-selected voxel palette (~8 earth variants), not a compositor reuse — the original D2 framing was wrong | ✅ `6dfe5d9` |
| — | `[FIX]` dead `ring`/`ghost_alt` computation in `apply_occlusion()`, found via the PROBLEMS tab, real pre-existing warning | ✅ `fe6adb7` |
| DESTRUCTION-PART2-CONSUMER | Wire `EarthVariantSelector` into `VoxelRenderer`/`Slab` — `render_slab()`, `SlabGenerator`, real round-trip evidence | ✅ `a1890e0` |
| DOC (D13/D17/D18) | Director's design pass: negative storey (floor lives at storey −1, walls untouched), lazy reveal, 8-level stack (1 destructible + 7 fixed) | ✅ `96936ee` |
| DESTRUCTION-D17 | `VoxelRenderer` supports negative storey levels — `_negative_voxel_layers` dict, `_build_voxel_layer_node()` shared formula | ✅ `2a692dc` |
| DESTRUCTION-D13 | `render_fixed_earth_level()` — the 7 fixed levels, no `Slab`/`Voxel`, structurally incapable of being dirty | ✅ `8deba36` |
| DESTRUCTION-PART2-INTEGRATION (floor) | Real map load builds the negative-storey floor — 600 Slabs for the real 30×20 `PLAYGROUND` map | ✅ `a352941` |
| DOC | Real visual before/after found via `SCREENSHOT-HOOK-01`'s own pre-commit capture (unplanned bonus evidence) | ✅ `1c28226` |
| DESTRUCTION-D18b | Border GUs eagerly build the full 8-level block (dev-only scaffolding, to see cosmetic storeys before Part 3 exists) | ✅ `d8a0b2c` |
| DESTRUCTION-D1-ROOF | Roof/ceiling slabs: N-level, all-destructible, existing wall materials — `render_slab_solid()`, zero new geometry class | ✅ `d15d2dd` |
| DESTRUCTION-PART2-INTEGRATION (roof) | Real map load builds roofs above real blocks — 49 real blocks on `PLAYGROUND`, `solid_block_instances` forwarded by `map_compiler.gd` | ✅ `fd58e6e` |
| DESTRUCTION-D1-ROOF-b | Roof border real footprint growth (10×10, `generate_with_border()`) + a **real bug found via the real map**: 15/49 blocks had corrupted core voxels from a too-narrow adjacency check; fixed to map-wide adjacency | ✅ `f697576` |

---

## Decision register updates

### D2 corrected — floor is a hash-selected palette, not a compositor reuse
**Original (2026-07-12):** "generalize `_compose_junction_pages()`."
**Corrected (2026-07-16, Director's diagram):** floor/slab voxels have no
corners and no continuous facade plane — the junction compositor's shear
math never applied. Real mechanism: ~8 pre-authored flat voxel atoms per
terrain material + deterministic FNV-1a hash of `(x, y, level)`. D2 and D4
are now the same decision. Consequence: the one real cost risk Part 0 found
(bake-combo-scaling) doesn't apply to floor/slab — that risk lives entirely
in the wall/junction compositor this mechanism never touches.

### D13 corrected — floor is an 8-level stack in negative storey, not 2 layers
**Original:** "2-layer slab: top destructible, bottom fixed bedrock."
**Corrected:** floor is a per-GU 8-level stack at **storey −1** (D17). Only
the top level (adjacent to storey 0, where walls begin) is a real `Slab`;
the other 7 are fixed, never even instantiated as `Voxel` objects — no code
path exists that could mark them dirty, not merely a discipline not to.

### D17 (new) — floor lives in negative storey space
Walls/blocks/props keep their existing storey-0-and-up placement completely
unchanged — audited the two places a wall's base storey is decided
(`edge_extractor.gd:97`, `room_builder.gd:611`), neither touched. Confines
the whole floor effort to `VoxelRenderer`'s own bookkeeping:
`_negative_voxel_layers: Dictionary[int, TileMapLayer]`, separate from the
existing `_voxel_layers: Array`, because `array[-1]` means "last element" in
GDScript, not "grow downward." Rejected alternative: shifting every
wall/block/prop up a full storey — touches the tested wall/junction/
occlusion pipeline across multiple files for no gain negative storey
doesn't already deliver at lower risk.

### D18 (new) — lazy reveal
Nothing below the top destructible level is ever instantiated until digging
exposes it. Intact-map cost stays at one level/GU (matches Part 0's real
43,264-cell/34.84 ms/10.70 MB baseline), not multiplied by 8. Same principle
as D3/D6, applied to depth. **D18b amendment (dev-only):** map-border GUs
eagerly build the full 8-level block, since production's camera-buffer zone
(hides lateral cuts) doesn't exist yet during development — revisit and
remove once it does.

### D1-ROOF (new, no formal D-number yet — logged under D1) — roof/ceiling slabs
Director's request: "lajes"/"telhados" positioned above existing block
structures, reusing `Slab` geometry but shaped oppositely to the floor — 2+
levels, **every** level destructible, existing wall materials
(concrete/metal/stone/wood) matched to the structure below. Zero new
geometry class needed: `Slab.Role.CEILING` already existed (D1's original
text), so an N-level roof is `SlabGenerator.generate()` (later
`generate_with_border()`) called N times. New: `render_slab_solid()`
(fixed material per voxel, no hash — sibling to `render_slab()`).

**Border sub-decision, and a real bug it caught.** A same-size roof only
covers a wall's *own-side* slice (`SliceGenerator` puts the far slice one
voxel into the *neighbour* GU) — visibly unfinished at every wall. Director
ratified **Option A** (real tracked footprint growth, 8×8 → 10×10, over a
cosmetic untracked border fill) explicitly to avoid a second truth that
needs remembering: *"a verdade nunca precisa ser lembrada."* First
implementation only suppressed a border side within one `solid_block_instances`
entry (correct for a genuine multi-GU block) — but `roof_integration_selftest.gd`,
run against the real `PLAYGROUND` map, caught **15 of 49 real blocks with
corrupted core voxels**: the map's own test fixture places 5 same-material
blocks as 5 *separate* 1×1 declarations in a contiguous row, and GUs have
zero gap between them, so each border landed on the neighbour declaration's
own core row. Fixed to compute adjacency map-wide, across every
`solid_block_instances` entry, not per-declaration.

---

## Bugs found this session

1. **`technical_debt.md` propagated two stale claims** (session-opening
   check, not part of Destruction work): the overlay "O(n²) per frame"
   claim never matched the code (both overlays are purely event-driven, no
   `_process()`); `BAKE-CACHE-01` was already fixed 2026-07-11, a day
   *before* `DESTRUCTION_MASTER_PLAN` (drafted 2026-07-12) and
   `RETROSPECTIVE_2026-07.md` (written 2026-07-12) both cited it as an open
   730–770 ms blocker. Corrected in both living docs.
2. **`room._slab_registry` and `room._voxel_renderer.clear()` were nested
   inside the `if not extraction.edges.is_empty()` conditional** in
   `room_builder.gd` — meant any edge-less room (no walls) would have left
   the floor's registry null forever. Found while wiring the floor's real
   map integration; moved both to run unconditionally.
3. **Dead `ring`/`ghost_alt` computation in `VoxelRenderer.apply_occlusion()`**
   — leftover from before OCC-21 (2026-07-14) replaced tile-alternative
   ghosting with erase+wireframe-fill. Found via the PROBLEMS tab (real,
   not the stale-cache class of finding), fixed since the file was already
   in scope that session.
4. **Two pre-existing headless selftests crashed past their own summary
   line**, `slice_geometry_selftest.gd` and `prop_01_tests.gd`, both hitting
   the same root cause: `MapCatalog.get_spec()` routes through
   `Registries.ensure_file_map_source()`, and the `Registries` autoload
   isn't in the tree yet this early in `--script` mode. Guarded with a
   `root.has_node("Registries")` check instead of crashing blind. Unrelated
   to Destruction work, found while verifying it.
5. **Roof border overlap — the session's one real, map-caught defect.**
   Covered in the D1-ROOF decision entry above. The fix generalizes
   correctly to both the multi-GU-single-block case and the
   separate-adjacent-blocks case; both are now directly tested (zero shared
   voxel positions between any two real, roofed, adjacent GUs).

---

## Code architecture notes

### Floor stack (D13/D17/D18, final state)
- Storey −1, per GU: level −1 = 1 real `Slab` (destructible, `Role.FLOOR`);
  levels −2..−8 = `render_fixed_earth_level()` calls, no `Slab`/`Voxel`.
- Map-border GUs (dev-only, D18b) eagerly build all 7 fixed levels; interior
  GUs stay lazy (top level only) until something digs down (Part 3, not
  built).
- Material: `EarthVariantSelector.variant_for(grid_pos, level)` — FNV-1a
  hash of position, `% 8`, reused from `FacadeSampler._fnv1a_hash()` (made
  `static` so both callers share one algorithm, per B4).

### Roof/ceiling stack (D1-ROOF, final state)
- Every real block (`solid_block_instances`, `map_compiler.gd`'s forwarded
  original per-GU declaration) gets `ROOF_LEVEL_COUNT` (placeholder: 2)
  levels above `storeys × LEVELS_PER_STOREY`, each an independent, fully
  destructible `Slab` (`Role.CEILING`).
- Each level's footprint grows via `SlabGenerator.generate_with_border()` —
  per-side, computed against a map-wide `roofed_gu_cells` set (every block
  on the map, not just the current declaration) — 1 voxel border on any
  side with no roofed neighbour, 0 on any side that has one.
- Material: `slab.material` directly (`render_slab_solid()`, no hash) — the
  block's own material, one-to-one.

### `VoxelRenderer` level storage (D17)
- `_voxel_layers: Array[TileMapLayer]` — positive levels, walls/blocks/
  props/roofs, completely unchanged by this session's floor work.
- `_negative_voxel_layers: Dictionary[int, TileMapLayer]` — floor/background,
  new this session. `get_layer(level)`/`_set_voxel_cell()` are the two
  routing points that make the split invisible to every other caller.
- `_build_voxel_layer_node(level)` — the one position/z-index formula both
  storages share.

---

## Testing evidence

All headless selftests, real executions (not code-reading), zero
regressions carried across every wave:

| Selftest | Result |
|---|---|
| `negative_storey_selftest.gd` | 12/12 |
| `fixed_floor_selftest.gd` | 5/5 |
| `slab_render_selftest.gd` | 8/8 |
| `earth_variant_selftest.gd` | 6/6 |
| `slab_geometry_selftest.gd` | 15/15 |
| `roof_slab_selftest.gd` | 15/15 |
| `floor_integration_selftest.gd` (real `PLAYGROUND`) | 9/9 |
| `roof_integration_selftest.gd` (real `PLAYGROUND`) | 5/5 |
| `bake_selftest.gd` (regression only, untouched by this session) | 19/19 |

**Real map integration, both confirmed against the actual `PLAYGROUND` map
(30×20, 151 real edges, 23 junction columns, 49 real blocks) — never a
synthetic `map_spec`:** 600 floor `Slab`s (one per GU), 98 roof `Slab`s (49
blocks × 2 levels), every cell independently re-derived and matched against
the writer's own choice, not trusted from it.

**Real visual evidence, found via `SCREENSHOT-HOOK-01`'s own pre-commit
capture (unplanned, not manually forced):** `Screenshots/history/
auto_2026-07-16_14-10-30.png` (before) vs. `auto_2026-07-16_14-29-06.png`
(after) — the ground visibly changes from a plain grid placeholder to the
mottled brown earth-voxel pattern. Later captures (`15:27:39`, `16:11:58`)
show the four PLAYGROUND test blocks with solid capped roofs instead of
open/hollow tops.

---

## Open items (deferred, not blocking)

1. **Bake-system experiment for roof surfaces** — Director's explicit "a
   princípio vamos tentar," phased *after* geometry on purpose, next
   session. `facade_tops`/`_get_plane_top()` already bakes continuous-
   looking wall/junction voxel tops but is edge/perimeter-projected, never
   built to fill an entire block's interior footprint as one surface —
   extending it is a real open question. **Expected, not a defect:** roof
   lateral (side) faces will look different from the walls below once
   materials genuinely mix on real maps — noted so it isn't mistaken for a
   bug later.
2. **Occlusion observation, unconfirmed.** Director noticed roof parts
   already showing some occlusion in a real capture. Plausible (roofs are
   ordinary `TileMapLayer` cells, so existing wall-occlusion machinery may
   partially apply by accident) but not investigated this session — revisit
   when occlusion participation is deliberately scoped.
3. **Light/shadow pass-through on roof destruction** — described as a goal,
   no mechanism built; depends on Part 3 (the trigger) existing first.
4. **`voxel_prop_instances`-based structures (crates etc.) don't get
   roofs** — only `"blocks"`-section structures do, for now.
5. **`usage_cells` (D3), depth shading (D7), the 16-variant coarse composite
   (D14)** — remaining original Part 2 scope, not touched this session.
6. **Part 3 (the trigger)** — nothing in the real game calls
   `Voxel.set_visible(false)`/`set_damage()` yet. Both the floor's and the
   roof's `Slab`s are structurally destructible and dirty-track correctly
   (proven in isolation and against the real map), but nothing triggers it
   during actual play.
7. **`solid_block_instances`' `gu_cell` isn't rotated by
   `layout_with_perspective()`** for non-N views — matches
   `voxel_prop_instances`' identical, pre-existing limitation (verified
   absent from `perspective_mapper.gd` entirely). Not fixed, flagged for
   whoever eventually fixes it for voxel props.
8. **`prop_01_tests.gd` criteria 4/6 still fail** — `MapCompiler.compile()`
   not returning `voxel_prop_instances` as that stale test expects; a
   different, unrelated root cause from anything touched this session, not
   investigated.

---

## Session statistics

- **Duration:** one long session, 2026-07-16 (date persisted across the
  whole session per system clock).
- **Commits:** 16 (`a99b98c` → `f697576`), all pushed.
- **VERSION:** 0.9.31 → 0.9.44 (13 bumps).
- **New selftests:** `destruction_part0_spike.gd`, `slab_geometry_selftest.gd`,
  `earth_variant_selftest.gd`, `slab_render_selftest.gd`,
  `negative_storey_selftest.gd`, `fixed_floor_selftest.gd`,
  `floor_integration_selftest.gd`, `roof_slab_selftest.gd`,
  `roof_integration_selftest.gd` — 9 new files, all real headless runs, all
  green at session end.
- **New production code:** `slab.gd`, `slab_registry.gd`, `slab_generator.gd`,
  `earth_variant_selector.gd`; `voxel_renderer.gd` gained
  `render_slab()`/`render_slab_solid()`/`render_fixed_earth_level()`/
  `_ensure_negative_voxel_layer()`/`_build_voxel_layer_node()`;
  `room_builder.gd` and `map_compiler.gd` gained the real map integration
  for both floor and roof.
- **Real compile errors across the whole session:** 0 (every commit's
  `project_lint.py` output pasted in this summary's source commits).
- **Real defects found via evidence, not assumed safe:** 5 (listed above),
  all fixed same-session.

---

## Conclusion

`DESTRUCTION_MASTER_PLAN` reaches **Alpha Ceiling Foundation**. Both the
floor and the roof/ceiling systems are real, tested, dirty-trackable
geometry rendering in the actual running game against real maps — not
isolated proofs-of-concept. The floor's negative-storey model and the
roof's border-growth model both survived contact with the real `PLAYGROUND`
map, and in the roof's case, that contact caught and fixed a real bug a
synthetic test never would have shaped to find.

**Tag:** `alpha-ceiling-foundation`
**Status:** PAUSED — next session picks up the bake-system experiment for
roof surfaces, per the Director's explicit phasing.
