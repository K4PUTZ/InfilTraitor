# EXPLOSION_REBUILD_MASTER_PLAN
## Grenade detonation: targeting, choreography, and voxel damage — v1.0

**Date opened:** 2026-08-05
**Next up:** **E-JUNCTION-01** (2026-08-13, planned, not yet built) — corner
wall-junction columns take no damage from any weapon, explosive or firearm.
Plan-first per the Director's own instruction; see the dated section near the
end of this file before touching `detonation_plan_builder.gd` or
`blast_calculator.gd`.

**Latest update:** 2026-08-10, session close — 🟢 **ALL SIX TASKS COMPLETE.**
E-RAY/E-DEBUG-RAY/E-FRAG/E-SHARD/E-FUME/E-BUBBLE all built and pushed
(commits d6dd657–3fba237). The white strobe frame is retired in favour of
a camera-facing shard that darkens into the existing negative flash, the
blast gets decorative iron shrapnel (and a debug twin), soot becomes its own
late beat, and Phase B's aim-bubble is wired. Phase B (targeting UI, throw arc)
is now unblocked. See the **"E-FRAG-01 / E-SHARD-01 (2026-08-10)"** section at
the end of this file for the task table, implementation notes, and the scope
boundary: a real room-wide relight after a blast is confirmed real but belongs
to its own future gameplay milestone alongside cover/exposure.
>
> **Correction, 2026-08-12:** "complete" was wrong for E-FRAG/E-DEBUG-RAY —
> both called a `VoxelRenderer` method (`cell_level_to_world`) that never
> existed, so every real detonation silently aborted before a fragment or ray
> was built. Real destruction was unaffected (the SCRIPT ERROR did not abort
> the caller). Fixed along with a second bug that would have kept the
> fragments invisible anyway (`BLEND_MODE_ADD` on a near-black colour). Detail
> in `TARGETING_MASTER_PLAN.md` §6.3, since that is where the bug was first
> found and logged as pre-existing.

<details><summary>Previous update — 2026-08-09, session close (Alpha Explosion Flow)</summary>

**Latest update:** 2026-08-09, session close (Alpha Explosion Flow) — **Phase A
is complete and its last dependency is discharged.** The 3-frame collapse and
the 171 ms detonation block are both gone; `PREDICTION_MASTER_PLAN` shipped all
six of its tasks, so a grenade's damage is computed before the player confirms
it and a detonation no longer freezes the camera. **Phase B (targeting UI, throw
arc, bubble) is now unblocked and is the next work** — see §11, which names the
exact seam it plugs into. Task 6's look-tuning surface is deliberately still
open: the Director deferred it until the mechanism was established.

</details>

<details><summary>Previous update — 2026-08-08, later session</summary>

**Latest update:** 2026-08-08, later session — **the decal-bake seam is
formalized: D34 (E-SEAM-01 `8dd926e`, E-SEAM-02 `22b24be`).** The SLAB/SLICE
split is gone for structural materials: a floor is a roof at the base of the
scene, so wall, roof and floor of one material all bake from the same
grayscale `facade_<id>` under MULTIPLY, and roof and floor share one page.
`slab_<id>` survives only for organic ground (`has_facade: false`). The
Director's own call made it free — fill a 1024×512 facade to the isotropic
1024×1024 with a **vertically flipped copy, not a stretch** — which also fixed
a latent roof bug (rows past ~36 had no texels) and recovered the floor's
vertical detail. Floor dents now wear their own material's decal art
(`decal_dent_concrete_*` etc.), with `earth` demoted to the fallback for
materials with no art of their own. `MaterialDef.slab_full_color` deleted —
never read by anything. Still open: `earth` itself is not unified (needs
`facade_earth.png`, art that does not exist), and the GPU-flush safeguard.
See §11.

</details>

**2026-08-08, session close (superseded by the above the same day)** —
Director's call after the GPU-flush fix and the soot reversal below:
**formalize the decal-bake step next session, before any soot tuning.** Root
design gap surfaced today, not before: floor (SLAB) textures are a genuinely
different art/render pipeline from wall (SLICE) textures — different
dimensions (1024×1024 isotropic vs 1024×512 anisotropic), different color
rules (SLAB is the one full-color exception to B2's grayscale rule),
different resolver validation — and that divergence is what actually broke
metal/stone/wood floor damage (`slab_metal.png` etc. never existed; this
session's stopgap fix reused the wall facade, palette-mode-converted and
resized, not a real asset). Soot's real lever (the stamp mechanism, confirmed
below) waits until that foundation is solid.
**2026-08-08, earlier the same day** — the 2026-08-07 "fuligem quebradiça" A/B
result (below) was itself built on a real bug: `DetonationChoreographer`
never flushed `DamageCompositeCache`'s GPU texture uploads, so that A/B
compared two captures both reading stale/unflushed content. Fixed
(`flush_damage_composite_pages()`, once per wave); the SAME A/B test re-run
clean shows the blast's own soot stamp genuinely IS the cause (4.1% of
pixels differ at mean 101.6/255, vs the earlier false "3.3% at 0.76/255
near-identical" reading) — reversing Post-Task-5's conclusion. Exact
mechanism (uniform per-ring tone → checkered per-pixel result) still
untraced. See the Post-Post-Task-5 note after Task 5's closure and §11
point 2.
**2026-08-07, post-Task-5** — real-capture feedback ("fuligem quebradiça")
investigated with a real A/B pixel-diff; root cause isolated to the
pre-existing floor dent decal art + substrate randomization, NOT this
rebuild's own soot stamp — **this conclusion was wrong, see the 2026-08-08
update above.**
**Updated 2026-08-06** — Director answered Q1–Q6, then corrected/extended Q1b
and Q3b in a follow-up round (floor is material-real now, not agnostic to
"earth"; bullet marks join the pre-bake), then added D13 (per-map material
scope + cross-session bake cache, §3.5). Task 0 ran and passed its gate
(§8.1), Q1b was answered (spherical falloff D14, roof-throw holes D15).
**Same day, later: Task 1a (E-MAT) shipped — commit `95d83cb`. Later still:
Task 1b (E-BAKE) shipped — commit `2d18a9e`.** Q7–Q9 remain (Phase B only).
**2026-08-07: Task 2 (E-RING) shipped, commit `a3f58ee`. Same day, later:
Task 3 (E-SOOT) shipped** — see both closure notes below. A real design
tension surfaced before Task 3's code was written and was resolved directly
with the Director (not guessed past): §5.1's original "per-voxel, one tone"
soot-encoding collapse was a processing-cost concession that no longer
applies now that explosions are pre-baked, not live-composited — **full
per-face directional soot is kept everywhere** (FACE-SOOT-01 and self-soot
untouched), and the new blast-stamp mechanism is itself directional too, not
isotropic. See Task 3's closure note for the full resolution.
**Status:** 🟢 **BUILDING. Task 0, Task 1a, Task 1b, Task 2, Task 3, Task 4,
and Task 5 are all done — grenades detonate and damage voxels for real,
on screen, for the first time since the 2026-08-05 reset.** 273 real damage
atoms bake on PLAYGROUND, cache-verified (1498ms → 31ms on a second load),
wired end-to-end. `DetonationPlanBuilder.build_plan()` (Task 4) resolves an
entire detonation up front; `DetonationChoreographer` (Task 5) plays it back
as the real 15-wave sequence, and `TestZoneController.detonate_active()` is
reconnected. A real capture (`Screenshots/history/e_wave_detonation.png`)
shows a real scorch crater; real per-wave timing is printed and measured on
every detonation. **Task 6 (the tuning pass) is the next concrete action.**
**Next action:** §11. **Formalize the decal-bake step (Director's call,
2026-08-08)** — the floor/SLAB texture pipeline needs to be a real,
complete asset+code path for every declared material, not the reused-facade
stopgap this session shipped for metal/stone/wood. **Task 6** (the tuning
pass over §4.2's ring weights, including soot) comes AFTER that — Q1d is
answered and implemented — D19/D20/D21's rename and dynamic-data reform are
live (`res://materials/*.json`, `ground_* → bare`, `facade_*`/`slab_*`
texture split); see the Task 1a/1b/2/3/4/5 closure notes below for the real
corrections surfaced against the plan text.

### Task 1a (E-MAT) — closed 2026-08-06, commit `95d83cb`

Shipped as planned (§8's Task 1a row), with one correction found by reading
the actual bake pipeline rather than the plan's summary text: **D20's "SLAB
serves floor AND ceiling" does not extend to the base/undamaged roof
render** — roofs keep resolving through `facade_<material>` (reprojecting
their own wall texture), unchanged. "Ceiling" in that phrase refers to the
future shared damage-atom pool (Task 1b's D6/D7 cracked/dented atoms), not
the roof's base bake. Verified: `room_builder.gd` bakes `roof_specs +
floor_specs` through the *same* `BakeCompositor._compose_roof_pages()`
function, disambiguated only by each combo's own `facade_id` string
(`facade_*` vs `slab_*`) — never by `material_id`, which after D19's
unification no longer encodes surface (concrete is now both a wall and a
floor material at once). This also forced `MaterialDef.full_color` to be
retired: the WHITE-vs-tinted bake modulate now reads the texture id's own
prefix instead of a flag on the material, since one unified `MaterialDef`
could not represent "tinted on walls, full-color on floors" for concrete
otherwise. Full writeup: `PROMPTS/RESUMO_SESSAO_2026-08-06_E_MAT_TASK1A.md`.

### Task 1b (E-BAKE) — closed 2026-08-06, commit `2d18a9e`

Shipped larger than the plan's one-line row summary suggested: the retired
D-ARCH-01 `DamageVariantBaker`/`VoxelVariantRegistry` pair was genuinely dead
code (`room_builder.gd` built an always-empty registry with a literal
`TODO (D-ARCH-01 Phase 2)`), and the consumer
(`VoxelRenderer.apply_damage_voxel_swap()`) was still written for the retired
per-cell key shape — making it real required a new persisted `Voxel.
damage_substrate` field (D3/§3.3), a `BlastCalculator.substrate_for()`
matching `decal_variant_for()`'s shape, and a 7th `_base_damage` column, none
of which the plan row named explicitly.

**273 real atoms bake on PLAYGROUND** (not the estimated 207/279 — the real
number, printed on every load). Two corrections found by reading the actual
compositor rather than the plan text, both recorded rather than guessed
past: **(1)** bullet marks bake BOTH shapes (cracked full-voxel and dented
half-voxel, 144 not 72 atoms) — confirmed with the Director, since
`ShotPunchTable.damage_state_for()` genuinely produces either outcome.
**(2)** D7's "3 irregular ceiling cut shapes" isn't implemented in
`HalfVoxelCompositor` yet (`carve_ceiling_silhouette()` takes no shape
parameter) — ceiling DENTED bakes the 1 real shape × 3 substrates per
material, not 3 shapes, until that art/code exists.

Mechanism: `_composite_full_voxel_decal()`/`_composite_half_voxel_decal()`
now branch on `edge == null` (the atom-bake's signal) to resolve substrate
via `resolve_flat()` instead of the edge-based `resolve()`, confirmed by
direct code reading that the edge-based path needs a real, run-registered
`Edge` a synthetic bake-time call has no reason to fabricate.
`BakeCompositor` bakes **sparsely** (only real placement usage composes a
tile), so `room_builder.gd`'s bake step forces 3 chosen substrate positions
per declared material into real wall/roof/floor combo usage before
`bake()` runs. A `user://` disk cache (reusing `BakeCompositor`'s own
encode/decode/load/save helpers via a new overridable cache directory)
measured **1498ms → 31ms** on a second load, 255/255 disk cache hits.
Firearms (D33 live compositing) verified untouched via a real weapon-fire
capture. Full writeup: `PROMPTS/RESUMO_SESSAO_2026-08-06_E_BAKE_TASK1B.md`.

**Supersedes for explosions:** the destruction path described in
`DESTRUCTION_MASTER_PLAN.md` Part 3 and the whole PERF-01/02/03 + D11 +
D-ARCH-01 arc (`DETONATION_PERFORMANCE_MASTER_PLAN.md`,
`PLANO_PRE_FABRICATED_DAMAGE_VARIANTS.md`, `INVESTIGACAO_EXPLOSAO_2026-08-04.md`).
Those documents stay as the historical record of why this rebuild exists.
**Narrows, does not fully preserve, the old firearm-destruction boundary**
(`WEAPON_MASTER_PLAN.md` D26–D33): bullet *mark application* now shares this
plan's pre-baked registry (D12, 2026-08-06) — see §9's rewritten note. Hit
detection and damage-state logic in D26–D33 are still untouched.

### Task 2 (E-RING) — closed 2026-08-07, commit `a3f58ee`

Shipped as scoped by this task's own research pass (not the plan row's flat
list): **neither `apply_container_damage()` nor `apply_crater_damage()` has
a live caller today** (`TestZoneController.detonate_active()` stayed
disconnected since 2026-08-05, commit `d412480`), so this task is
calculation-layer only — parameter surface + selftest proof, no `room`
state. Confirmed with the Director (AskUserQuestion) before writing code:
`room._gu_blast_count`'s persistence and reconnecting `detonate_active()`
are Task 5 (E-WAVE)'s job, since no caller exists yet to drive that state.

- **`frag_grenade.json`/`BombDef`**: 4th ring
  (`ring_multipliers: [1.0, 0.6, 0.25, 0.0]`) plus `destroy_ring_weights`/
  `dent_ring_weights`/`crack_ring_weights: Array[float]` and
  `soot_ring_tones`/`smoke_ring_weights` (parsed now, consumed by Task 3+).
- **D14 (spherical falloff)**: `apply_container_damage()`'s vertical-ring
  step is now `absi(level_offset) / LEVELS_PER_STOREY` for wall AND roof —
  the `is_roof` per-raw-level branch this file's own doc comment used to
  justify is retired. **Confirmed as load-bearing, not cosmetic**: a
  dedicated selftest (`test_vertical_falloff_identical_for_wall_and_roof`)
  proves that under the OLD per-raw-level roof stepping, a roof voxel one
  level above the blast would already have fallen to ring 1 — under D14 it
  stays at ring 0, the whole storey through. A second selftest
  (`test_roof_two_levels_same_ring_group`) proves the master plan's own
  "roof pierces as one unit falls out for free" claim concretely: two Slabs
  at levels 0/1 (a real roof's `ROOF_LEVEL_COUNT=2`) land in the identical
  ring group, not split.
- **Per-tier weights**: `destroy_ring_weights`/`dent_ring_weights`/
  `crack_ring_weights` replace the single `ring_multipliers[ring]` scaling
  read in `apply_container_damage()`. `ring_multipliers` itself is
  unchanged in its other job (range cap). Proven against the REAL
  `frag_grenade.json` (loaded via `BombRegistry`, not a hand-built array):
  ring 3 is in range and evaluated, not skipped, yet produces zero material
  damage — the real "4th ring is smoke-only" shape.
- **D2 (two floor layers)**: `apply_crater_damage()` gains
  `deep_layer_unlocked: bool = false` — the principled replacement for the
  removed PERF-02 B4 hack ("skip FLOOR_-2 entirely"). `false` leaves every
  `GeometryCoords.FLOOR_DEEP_LEVEL` voxel `INTACT` even inside
  `core_radius`; `true` lets them take real damage. The caller flipping
  this from a GU's second blast onward (`room._gu_blast_count`) is Task 5's
  job, per the scope note above.
- **D17 (slab-pierce multiplier)**: `apply_crater_damage()` gains
  `slab_pierce_multiplier: float = 1.0`, scaling both the destroy
  probability and the dent probability in the crater's rim band. Trailing +
  defaulted, byte-for-byte inert at 1.0 (proven, not assumed) — a future
  calibration knob, since no stacked-slab scenario exists in any real map
  today (confirmed via a research pass: `SlabRegistry` has no
  topmost/next query, `Slab` has no pierced/intact flag).
- **D16 (blast-side atom routing)**: turned out to need **zero changes** to
  `apply_crater_damage()` — its DENTED path already hardcoded
  `CarvedSide.TOP` unconditionally, already correct for a roof struck from
  above. D16 is entirely a render-side fix in
  `VoxelRenderer.apply_damage_voxel_swap()`: a CEILING container whose
  voxel carries `damage_carved_side == TOP` now routes through the FLOOR
  naming/key path (`floor_damage_material()`, the GU's real ground material
  via `_floor_zone_by_gu`) instead of the ordinary CEILING path. Proven
  against the real PLAYGROUND registry and a real `TileMapLayer` readback
  (`damage_atom_bake_selftest.gd`'s new `test_5`) — not just a boolean
  return value, since both candidate keys are real, registered atoms on
  this map and could not otherwise be told apart.
- **D9 (real-material floor lookup)**: confirmed already fully wired before
  this task (`git show d412480~1` — the pre-reset caller already passed a
  real material, never hardcoded `"earth"`); this task's job was proving
  it, not building it. New selftest compares a real `wood` floor against a
  real `concrete` floor through `apply_crater_damage()` — 10 dents vs 49,
  tracking each material's real `dent_factor` from the reformed
  one-row-per-material table (D19/D20).

**One real bug caught and fixed by the selftests themselves, not by manual
review**: `damage_atom_bake_selftest.gd`'s first draft of the D16 routing
test re-used one real `Voxel` for both the TOP and BOTTOM checks, calling
`set_damage(DENTED, ..., TOP, ...)` then `set_damage(DENTED, ..., BOTTOM,
...)` — but `Voxel.set_damage()` no-ops when `new_state == damage_state`
(`voxel.gd:105`), so the second call was silently dropped and the BOTTOM
check ran against a voxel still carrying `TOP`. Caught by a real
red-before-green run (the BOTTOM assertion failed with a concrete,
non-matching atlas coordinate — not a crash, not a false green), fixed by
resetting `damage_state` to `INTACT` between the two calls so the second
`set_damage()` actually applies.

Full verification: `project_lint.py` 183 files/0 errors, `run_selftests.py`
31/31 clean (13 new assertions: 6 in `blast_calculator_selftest.gd`, 1 new
multi-assertion test in `damage_atom_bake_selftest.gd`), `check_invariants.py`
OK, `gen_codemap.py --check` clean. No live capture — no live caller exists
to capture (confirmed above), matching this task's own stated gate.

### Task 3 (E-SOOT) — closed 2026-08-07, commit `fdcb5e9`

Shipped calculation-layer only, matching Task 2's own precedent — same
underlying reason: `TestZoneController.detonate_active()` is still
disconnected, so nothing can drive a real blast-soot stamp yet.

**A real design tension surfaced and was resolved with the Director before
any code was written, not guessed past.** §5.1 as originally written
proposed collapsing soot from per-FACE (a voxel's 3 visible faces, each
independently tracked, `FACE_SOOT_CODE_COUNT=125`) to per-VOXEL (one shared
tone, 5 codes), to save alt-id headroom. Reading the actual code first
showed this would have silently retired two already-shipped, tested
systems — **FACE-SOOT-01** (2026-08-01, `encode_face_soot()`/
`decode_face_soot()`, and `voxel_face_shading.gdshader`'s per-face
`soot_face_mult`) and **self-soot/D33-SOOT-01** (2026-08-03,
`_self_soot_faces()`/`apply_self_soot()`, 7 passing `SOOT-SELF-*`
assertions) — neither of which §5.1's text mentioned anywhere. Flagged via
`AskUserQuestion` before writing code. **The Director's answer: the
per-voxel collapse was a processing-cost concession that no longer applies
now that explosions are pre-baked, not live-composited — keep full per-face
directionality everywhere, and make the new stamp genuinely directional
too.** No changes to `FACE_SOOT_CODE_COUNT`, the encode/decode functions, or
the shader — all confirmed untouched by the final 31/31 selftest run,
including the pre-existing `SOOT-SELF-*`/`FACE-SOOT-*` assertions.

- **`stamp_container_soot()`** (walls/ceiling) reuses D14's exact ring
  formula (factored out into a new `_vertical_ring_for()` helper,
  behavior-preserving, verified by an unchanged `apply_container_damage()`
  selftest run) and `carved_side_for()` (already the canonical "which face
  points at the epicentre" answer, used elsewhere for decal carving) via a
  new `_toward_for_carved_side()` helper, then delegates to the SAME
  `_face_rings_for()` derivation `derive_soot_rings()` already uses — the
  strong/faint split comes free, reused rather than reimplemented. A ceiling
  underside (`is_roof=true`) is skipped entirely, mirroring
  `_self_soot_faces()`'s own BOTTOM rule.
- **`stamp_crater_soot()`** (floor) extends `apply_crater_damage()`'s own
  `rim_span` unit into numbered rings past the crater proper — one
  `rim_span`-wide band per ring, boundary-inclusive to the closer ring
  (`ceil`, not `floor`, matching every other `<=`-based band test in
  `apply_crater_damage()`; caught and fixed during this task's own
  selftest-writing, before any assertion was written against the wrong
  formula). **Assumption stated, open to one-line correction** (Task 2's own
  D1/D2 pattern): this banding is new, not separately specified — reasonable
  given rings apply uniformly in every direction (Q1b's spherical answer).
  Isotropic (`Vector3i(tone, CLEAN, CLEAN)`) — a floor voxel has exactly one
  visible face, so there is genuinely one channel, not a shortcut.
- Both write into shared `out_snapshot`/`out_faces` dictionaries with
  min-wins semantics (never overwrites a stronger/lower value already
  present), composing with `derive_soot_rings()`'s output the same way
  `room._merge_soot_into()` already composes two independent passes today
  — proven directly (a real derived ring 0 survives a fainter stamp applied
  afterward on the same shared dicts, and vice versa).
- **No `room.gd` changes this task.** The right persistence unit for a
  stamped blast is the *event* (base-space epicenter, rings, `is_roof`,
  `soot_ring_tones`), not its derived per-voxel output — `carved_side_for()`
  is screen-space and rotates, so caching a raw `Vector3i` across a view
  change would show soot on the wrong face (D25's own bug class).
  `room._crater_floor_soot` is the existing precedent: rebuilt from
  `_base_damage` every call, never trusted as a raw cache. Building the
  event-replay list and wiring it into `_build_soot_snapshot()` is Task 5's
  job, alongside `detonate_active()`'s reconnection — the same split Task 2
  established for `_gu_blast_count`.
- **No live capture** — same reasoning as Task 2 (confirmed by rereading
  `test_zone_controller.gd`: `detonate_active()` still only hides the
  grenade sprite). Deferred to Task 5's real wave driver.

Verification: `project_lint.py` clean, `run_selftests.py` 31/31 clean (12
new assertions in `blast_calculator_selftest.gd`, real numbers throughout —
e.g. the epicenter-directional face split matched `(top=1,se=1,sw=0)`
exactly). The `stamp_crater_soot()` ring-band off-by-one (`floor` vs `ceil`,
above) was caught by hand-tracing the exact boundary distances while
designing the assertions, fixed in the source before the first run — not a
red-before-green catch, since the buggy version was never executed against
a test. `check_invariants.py` OK, `gen_codemap.py --check` clean.

### Task 4 (E-PLAN) — closed 2026-08-07, commit `ddbe7dd`

Shipped as scoped by §8's Task 4 row and §6.1, with a real (not synthetic)
gate this time: unlike Task 2/3, which stayed calculation-layer only because
no live caller existed to drive one, Task 4's own gate ("printed plan census
from a real detonation") requires actually running the full resolution
pipeline against real PLAYGROUND data — so a new selftest
(`detonation_plan_selftest.gd`) boots the map through the same MinimalRoom
scaffold Task 1b established and calls `DetonationPlanBuilder.build_plan()`
for real, at the GU of PLAYGROUND's first real concrete wall (not a
hand-picked coordinate, so the test cannot silently stop exercising anything
the next time the map is edited).

**The literal reading of §2 ("no compositing, no lookup... inside a wave")
turned out to be achievable without a risky refactor, once read against the
real code, not guessed past.** `VoxelRenderer._set_voxel_cell()` — the
function every damage/floor-reveal render path ultimately funnels through —
already had exactly ONE side-effecting line (`layer.set_cell()`) at the very
end of an otherwise pure resolution cascade (baked lookup → D33 live-
compositing fallback → flat material-only last resort). A trailing
`apply: bool = true` parameter (default preserves every existing caller
byte-for-byte, proven by the unchanged 31/31 selftest run before this task's
own test was added) turns that one line into a `return` of the resolved
`{source_id, atlas_coords, alternative_id}` triple instead — the same seam
added to `render_slab()`/`render_fixed_earth_level()`/`reveal_floor_slab()`
(the exposure-fallback paths) and, via a Task-3-style pure extraction,
`apply_damage_voxel_swap()` → `resolve_damage_voxel_swap()` (the pre-baked
lookup, now its own function). **DetonationPlanBuilder never calls
`layer.set_cell()`/`erase_cell()` anywhere** — proven, not asserted: the
selftest snapshots every one of PLAYGROUND's 108,576 placed cells'
`(source_id, atlas_coords, alt)` before and after `build_plan()` and asserts
byte-identity.

**What `build_plan()` actually does, concretely:**
- Runs the SAME resolution Task 2/3 already shipped
  (`apply_container_damage()`/`apply_crater_damage()`/
  `stamp_container_soot()`/`stamp_crater_soot()`) — unchanged writers, no
  new damage logic.
- Composes the blast's stamped soot with a **whole-map** derive-from-holes
  pass (`derive_soot_rings()` + `apply_self_soot()`, walking every registered
  Slice/Slab, not just this blast's affected containers) — closing the exact
  gap Task 3's own closure note flagged as unbuilt: "this compositional step
  belongs [in the first real caller], not in room.gd." No `room.gd` changes
  — this class runs equally well against a real Room or the MinimalRoom
  selftest scaffold, matching Task 1b/2/3's own precedent.
- Builds ONE `VoxelLightField` via `.build()` and only ever *queries* it
  (`bucket_for()`/`face_soot_code()`) — never calls `apply_light_field()`,
  so the single map-wide light repaint §2 describes never touches the live
  layer either. Occupancy for that field is derived from `Voxel.visible`
  directly (a new `_voxel_occupancy()`, NOT `VoxelRenderer.build_occupancy()`
  — that reads the live TileMapLayer, which still shows every voxel this
  blast just destroyed as solid, since nothing has erased it yet).
- Packages `destroy`/`dented`/`cracked` by the SAME per-voxel ring
  `apply_container_damage()` computes internally (walls/roofs via a newly
  **public** `BlastCalculator.vertical_ring_for()` — promoted from
  `_vertical_ring_for()`, Task 3's own extraction, because this is now a
  genuine cross-file consumer) and a newly extracted
  `BlastCalculator.crater_ring_for()` (floor voxels, pulled out of
  `stamp_crater_soot()`'s own inline banding so destroy/dent grouping and
  soot banding can never disagree about which ring a floor voxel is in).
- Resolves the exposure fallback (§2/B5) via `_expose_below()`'s exact
  pre-reset logic (`git show 2ad1494`'s `TestZoneController`), now
  resolve-only: reveals the deep floor Slab (the common real case — a real
  Slab always exists at `FLOOR_DEEP_LEVEL`) or the fixed earth plane beneath
  it (only reached once a second blast opens the deep layer too), nested
  into the owning ring's destroy entry.
- **`smoke_ring_weights`'s first real consumer** (flagged "still unread" by
  Task 2's own closure note) — one descriptor per GU the flood actually
  reached, `duration`/`scale` both set to that ring's weight; the selftest
  confirms every entry matches `frag_grenade.json`'s own array element for
  element.

**One documented, honest gap, not silently papered over:** the live-
compositing-fallback branch for a Slab (FLOOR/CEILING/INTERIOR) resolves the
same shared material name the live pipeline would, but does not reproduce
`_process_dirty_slab_voxel()`'s full zoned-floor branching. Flagged in the
source rather than assumed correct — Task 1b's own bake measured **zero**
unresolved atoms across all three element classes on real PLAYGROUND
material, so this path is real plumbing for a case that plumbing exists for
but is not exercised by any real material today.

**Real census from the real detonation** (source GU = PLAYGROUND's first
concrete wall's own GU):

| Wave | ring0 | ring1 | ring2 | ring3 | total |
|---|---|---|---|---|---|
| destroy | 102 | 14 | 4 | — | 120 |
| dented | 20 | 8 | — | — | 28 |
| cracked | — | 12 | 4 | — | 16 |
| smoke | 1 | 1 | 3 | 5 | 10 |
| soot | 180 | 136 | 157 | 88 | 561 |

Matches D1's own "muito/menos/quase nada" shape exactly, and matched by a
real assertion, not eyeballed: `dent_ring_weights[2]=0.0` and
`crack_ring_weights[0]=0.0` in the real `frag_grenade.json` — the census
table above shows dented stopping at ring 1 and cracked never touching ring
0, and `test_6_real_ring_gates()` asserts this holds for every zero-weight
ring, not just the two the table happens to show. 64 floor-reveal `expose`
entries resolved under the destroy waves that actually opened a crater; 44
dented/cracked entries all carry a real non-negative `source_id` plus
`atlas_coords`/`alt` (never a placeholder).

Verification: `project_lint.py` 185→186 files/0 errors, `run_selftests.py`
32/32 clean (new `detonation_plan_selftest.gd`, 6/6 of its own assertions
passing; every pre-existing seam selftest for `_set_voxel_cell()`/
`apply_damage_voxel_swap()` — `decal_seam_selftest.gd`,
`half_voxel_seam_selftest.gd`, `ceiling_carve_seam_selftest.gd`,
`floor_sunk_seam_selftest.gd`, `generic_mark_seam_selftest.gd`,
`damage_atom_bake_selftest.gd` — still passes unchanged, proving the
resolve/apply split is behavior-preserving for firearms' live D33 path too,
not just for this task's own new caller), `check_invariants.py` OK,
`gen_codemap.py --check` clean (186 scripts). **No visual capture** — same
reasoning as Task 2/3: a plan with no player-visible effect (nothing calls
`layer.set_cell()` yet, by design) has nothing to screenshot; the printed
census above and the byte-identity snapshot diff are this task's real
evidence instead. Deferred to Task 5's real wave driver, which is where a
detonation first becomes visible.

### Task 5 (E-WAVE) — closed 2026-08-07, commit `98e9772`

Shipped as scoped by §8's Task 5 row: `DetonationChoreographer` plays back
Task 4's `DetonationPlan` as the real 15-wave sequence, and
`TestZoneController.detonate_active()` is reconnected — **a grenade now
detonates, damages voxels, and repaints correctly for real**, the first
time this has been true since the reset on 2026-08-05 (`d412480`).

**One real bug, caught by the capture itself, not by reasoning about the
code.** The first real run scheduled all 15 `SceneTreeTimer`s correctly
(confirmed via a diagnostic print per timer) but **not one `timeout` ever
fired** — `DetonationChoreographer`'s own header comment had assumed a
`SceneTreeTimer`'s `timeout` connection holding a bound `Callable` would be
enough to keep the (RefCounted, non-Node) choreographer alive for its whole
~600 ms sequence. Measured false: `detonate_active()`'s local `choreographer`
variable was the only reference, and it went out of scope the instant the
function returned — before a single wave applied. Fixed by
`TestZoneController` holding an explicit `_active_choreographer` reference,
cleared via the class's own new `finished` signal once the last wave lands.
The class's own doc comment was rewritten to record the measured finding
instead of the wrong assumption, so the next reader doesn't repeat it.

**What shipped, concretely:**
- **`DetonationChoreographer`** (`godot/scripts/systems/destruction/
  detonation_choreographer.gd`) — the static 15-entry `WAVE_TABLE` from §1,
  each wave scheduled on its own independent `SceneTreeTimer` from t=0 (never
  chained/awaited), `wave_interval_ms` a `var` at 40 (Q5). `_apply_wave()` is
  the ONLY place in the whole pipeline that calls `layer.set_cell()`/
  `erase_cell()`/`SmokeSparkOverlay.add_smoke()` — every value it applies was
  already fully resolved by Task 4. Prints `[E-WAVE] wave N/15 kind=... ring=...
  cells=... elapsed=...ms apply=...ms` per wave — the Task 5 gate's own
  "measured per-wave ms" evidence, on every real detonation, not just a dev
  capture.
- **`SmokeSparkOverlay.add_smoke()`** gained a trailing `duration_scale: float
  = 1.0` (both pre-existing callers — `EmberOverlay`, room.gd's VFX-01
  dispatch — unaffected), so smoke waves can make a farther ring's puff
  genuinely linger for less time, not just read smaller/fainter.
- **`DetonationPlanBuilder.build_plan()`** now also returns
  `"touched_voxels"` (`Array[Voxel]`, every voxel this blast actually changed
  the damage_state of) — Task 5's persistence seam, so
  `TestZoneController.detonate_active()` can call
  `room.record_voxel_damage_to_base()` for real without a second flood/
  find_affected_containers pass to re-derive the same set.
- **`room._gu_blast_count: Dictionary`** (new, cleared on map load alongside
  `_base_damage`) — D2's floor-layer memory, threaded into
  `build_plan()`'s `ctx["deep_layer_unlocked"]` as `count(gu) > 0`.
- **`TestZoneController.detonate_active()`** rebuilds a real `ctx` from the
  live room (`_edge_registry`/`_slab_registry`/`_voxel_renderer`, real
  `blocked_edges`/`blocked_cells`, real `LightSource` objects from
  `room._lighting_controller.get_light_registry().get_active_lights()` — a
  real room already has these, unlike the selftest scaffold which had to
  hand-convert map-data dicts), calls `build_plan()`, increments
  `_gu_blast_count`, persists `touched_voxels`, then hands the plan to a
  `DetonationChoreographer`.

**One documented, deliberate scope decision, not silently dropped:**
VFX-01's per-voxel dust/spark/chip debris (`room._dispatch_destruction_vfx()`,
driven by `VoxelRenderer.voxel_destroyed`) does not fire for blast-caused
destruction any more — the choreographer's destroy wave calls
`layer.erase_cell()` directly rather than routing through
`VoxelRenderer.process_dirty()`, and the plan's own destroy entries carry no
material to dispatch debris VFX from (§6.1's literal shape is `{cell,
level}` only). The OLD immediate-smoke half of that same dispatch would have
doubled up with the new staged smoke waves (D5) if left connected, which is
the more load-bearing reason it isn't. Firearms are unaffected — still the
signal-driven path, untouched. Revisiting blast debris needs material
threaded onto destroy plan entries, not a quick patch; flagged for whoever
picks this up, not decided here.

**Real evidence — a real detonation, captured and measured, not reasoned
about:**

| Wave | ring0 | ring1 | ring2 | ring3 |
|---|---|---|---|---|
| destroy | 899 | 2 | 0 | — |
| dented | 38 | 62 | — | — |
| cracked | — | 0 | 0 | — |
| smoke | 1 | 4 | 7 | 10 |
| soot | 217 | 708 | 513 | 389 |

(Metal wall, `INFILTRAITOR_CAPTURE_DETONATE_INDEX=1` —
`cracked` is correctly always 0: metal's `crack_factor` is 0, matching
D32.6/the material table.) Real per-wave timing from the SAME run — the
"never delays the next" property holding for real, not just in the formula:
waves land at elapsed ≈ 8/9/9/9/127/127/127/243/243/243/267/304/431/438/443 ms
(target cadence 0/40/80/120/160/200/240/280/320/360/400/440/480/520/560 ms —
real drift is frame-quantization, not compounding delay: wave 15 is 443 ms
after t0, not 15×whatever wave 14 took). Apply cost per wave: sub-1 ms for
every wave except the two biggest (wave 1's 899-cell destroy: 8.4 ms; wave
13's 708-cell soot: 8.9 ms) — confirming Task 0's own finding that the
expensive part was never the per-cell work, it was the old per-cell
*resolution* this whole rebuild eliminated.

Visual: a real, framed capture
(`Screenshots/history/e_wave_detonation.png`) shows a dark, textured,
irregular scorch crater on the floor, visibly distinct from the surrounding
clean tile pattern — the first real, on-screen grenade damage this rebuild
has produced.

Verification: `project_lint.py` 188 files/0 errors, `run_selftests.py`
33/33 clean (new `detonation_choreographer_selftest.gd` drives
`_apply_wave()` directly, in `WAVE_TABLE` order, against a real PLAYGROUND
plan, and asserts every resulting cell — erasures, exposed reveals, dented,
cracked, soot — matches its plan entry exactly, plus a real smoke-puff
count on `SmokeSparkOverlay`; every pre-existing selftest, including every
`_set_voxel_cell()`/`apply_damage_voxel_swap()` seam test, still passes
unchanged), `check_invariants.py` OK, `gen_codemap.py --check` clean (188
scripts). A separate real `weapon_fire` capture confirms firearms are
unaffected.

#### Post-Task-5 note (2026-08-07) — the "quebradiça" soot texture, investigated, root cause NOT this session's work — **REVERSED 2026-08-08, see the note right after this one**

Director feedback on the real `e_wave_detonation.png` capture: the crater's
scorch reads as "quebradiça e irregular" (brittle/fragmented) rather than
one uniform shade per face — a real visual concern worth investigating
before Task 6 spends time moving numbers on the wrong lever.

**Investigated, not guessed.** Four candidate causes were identified by
reading the actual render chain: (a) the new blast-stamped soot
(`stamp_container_soot()`/`stamp_crater_soot()`, Task 3/4) rendering
non-uniformly; (b) `MaterialResistanceTable.dent_factor`-driven DENTED
density in the crater rim, each voxel independently drawing one of the
floor's own dent decals; (c) the floor dent decal art itself
(`decal_dent_earth_0/1/2.png`) — inherently a noisy, mottled
crumbled-earth/crater texture, authored for D22/D23, predating this whole
rebuild; (d) D3's per-cell random substrate-crop selection adding further
tiling variety on top.

**Isolated (a) with a real A/B capture, not reasoning.** A new diagnostic
toggle (`DetonationPlanBuilder.build_plan()`'s `ctx["stamp_soot_enabled"]`,
default `true`; `TestZoneController` reads
`INFILTRAITOR_DISABLE_STAMP_SOOT=1` to flip it for a manual capture only —
`derive_soot_rings()`/`apply_self_soot()` keep running unchanged either
way, so this isolates ONLY the blast's own authored stamp) produced two
captures at the identical GU
(`Screenshots/history/soot_stamp_on.png`/`soot_stamp_off.png`). Pixel-diffed
directly, not eyeballed: **3.3% of pixels differ by more than 5/255, mean
diff 0.76/255** — the two images are visually near-identical, and the
"quebradiça" pattern is present, unchanged, in both. **Conclusion: (a) is
not the cause.** The stamp's real, measured contribution is a small extra
darkening at the crater's outer edge (ring 3 — exactly the gap Task 3 closed,
soot reaching a ring that destroys nothing) and nothing more; (b)/(c)/(d),
all of them pre-existing, are where the texture actually comes from.

**Left as an explicit open item for Task 6, not decided here** (four
concrete options were put to the Director, not resolved yet):
tighten crater-rim dent density, replace the dent decal art, disable D3's
per-cell substrate randomization, or change the soot shader from a pure
multiply to a flatter blend toward a solid tone. The diagnostic toggle
itself stays in the code (`stamp_soot_enabled`, harmless — `true` by
default, byte-identical to before it existed) since it's a real, cheap,
reusable seam for the next A/B comparison, not a one-off hack to revert.

#### Post-Post-Task-5 note (2026-08-08) — the A/B test above was comparing two broken captures; re-run clean, the stamp IS the cause

The Director rejected the conclusion above outright: "não dá pra ver nenhum
decal baked no chão, em nenhum material" (not a soot complaint — a claim
that NO dent/crack decal was rendering on the floor at all, in any
material), and pointed out that (b)/(c)/(d) above cannot explain ring 3 at
all — `frag_grenade.json`'s `destroy_ring_weights[3]`/`dent_ring_weights[3]`/
`crack_ring_weights[3]` are all `0.0`, so a ring-3 voxel never reaches
`apply_container_damage()`'s `DENT`/`CRACK` selection loops and therefore
never rolls a `decal_variant`/`substrate` at all (`decal_variant_for()`/
`substrate_for()` are called ONLY inside those loops) — there is no dent
decal art or D3 randomization for ring 3 to inherit in the first place.

Chasing that contradiction (via a new floor/wall/ceiling damage-atom gallery
rig, `damage_gallery_debug.gd`) found a real, unrelated bug first:
`DamageCompositeCache.store()` (every WALL/FLOOR/CEILING damage atom's
compositor, baked or live) blits into a CPU-side `Image` and marks the page
dirty, but defers the actual GPU texture upload to `flush_dirty_pages()`.
Every real call site pairs painting with that flush EXCEPT
`DetonationChoreographer` — the only place a `DetonationPlan` ever reaches
`set_cell()` — which never did. Fixed
(`voxel_renderer.flush_damage_composite_pages()`, once per wave,
`detonation_choreographer.gd`).

That means the ORIGINAL A/B capture above (`soot_stamp_on.png`/
`soot_stamp_off.png`, 2026-08-07) was comparing two captures that were both
reading unflushed, potentially stale GPU texture content — exactly the kind
of noise that would wash out a real difference and produce a false "near
identical" reading (3.3% pixels, mean diff 0.76/255). Same test, same
identical stone crater, re-run clean after the fix
(`INFILTRAITOR_CAPTURE_ACTION=test_zone_detonate` +
`INFILTRAITOR_DISABLE_STAMP_SOOT=1` vs unset): **4.1% of pixels differ, mean
diff 101.6/255 — over 130x the earlier signal.** Visually decisive, not a
statistical technicality: with the stamp OFF, ring 3's floor tiles read as a
smooth, even darkening; with it ON (today's shipped default), the same
tiles show the "quebradiça e irregular" checkerboard/pockmark pattern
verbatim.

**Conclusion, reversed: the blast's own soot stamp (`stamp_container_soot()`/
`stamp_crater_soot()`, Task 3/4) IS the cause.** `stamp_crater_soot()`'s ring
assignment is a plain Euclidean-distance band (`crater_ring_for()`) with no
per-voxel hashing or randomness — every voxel in a ring gets the textually
identical `tone`. Exactly how that uniform per-ring value turns into a
checkered per-pixel result on screen is NOT yet traced — candidates, in no
particular order: an interaction between the soot tone and the light-bucket
alternative-tile encoding (`encode_voxel_alt()`, VL-01's 12-bucket system),
or a base-texture contrast effect only visible once the multiply-blend
darkening is strong enough (ring 3 is the stamp's own deepest/darkest
reach). **Options (b)/(c)/(d) from the note above (dent-decal art, D3
substrate randomization, crater-rim dent density) are very likely NOT where
Task 6's tuning time belongs** — they were never reachable in the region
that actually changed. Option 4 (the shader's multiply-vs-flatter-blend
question) or the stamp's own rendering path is the real lever. The
diagnostic toggle (`stamp_soot_enabled`) remains the correct seam for
whoever traces the exact mechanism next — now finally trustworthy, since
both sides of the comparison are flushed correctly.

---

## 0. Where the system actually is right now

Established by reading the repo, not from memory:

- `TestZoneController.detonate_active()` hides the grenade sprite and closes
  its menu. **It damages nothing** — the calls to
  `BlastCalculator.apply_container_damage()`/`apply_crater_damage()` were
  removed on 2026-08-05 (commit `d412480`). This is intentional, not a
  regression.
- The blast-radius red wireframe preview (`open_menu_for()`) still works — it
  never touched voxels.
- **Kept intact and unused (still true for detonation itself):**
  `BlastCalculator` (1105 lines, fully selftested — grenades still damage
  nothing, see Task 2), `DecalCompositor`, `HalfVoxelCompositor`, all 45
  decal PNGs.
- **No longer unused, as of Task 1b (2026-08-06):** `VoxelVariantRegistry`,
  `DamageVariantBaker`, `apply_damage_voxel_swap()` — 273 real atoms bake on
  PLAYGROUND and a real firearm hit resolves through the pre-bake. What's
  still missing is the *trigger*: nothing calls `BlastCalculator` yet (that's
  Task 2 rewiring `TestZoneController.detonate_active()`), so the populated
  registry currently only serves firearm marks.
- **Working and untouched:** `WeaponBenchController.fire_active()` — firearms
  destroy voxels through D33 runtime compositing.
- Light flicker is off (`a2d0d47`), for clean diagnostic captures.
- The floor is two real destructible planes: `FLOOR_TOP_LEVEL` (−1) and
  `FLOOR_DEEP_LEVEL` (−2), plus fixed bedrock at −8..−3.
- `frag_grenade.json` declares `ring_multipliers: [1.0, 0.6, 0.2]` → 3 rings
  (0,1,2). `flood_gu_rings()` derives its cap from that array's size.
- Soot is per-FACE (3 faces packed into one modulate-alpha code, 125 codes),
  **derived fresh from currently-destroyed voxels** on every light repaint
  (D24) — never authored by the blast.

### Why the last architecture failed, in one line

D-ARCH-01 pre-baked a damage variant **per cell**, so the bake surface was
71,296 cells × N variants. Measured 2026-08-05: ~95 ms/wall-voxel → tens of
minutes at map load. Infeasible.

### Why this one is different

The Director's rule *"usando voxels aleatórios das facades por baixo"* removes
the per-cell dimension entirely. A damaged voxel no longer shows **its own**
facade under the decal — it shows a randomly chosen one for that material. The
bake set collapses from *cells × variants* to *materials × types × decals ×
substrates* — roughly **190 atoms for the whole map**, baked once. That single
sentence is what makes the whole plan viable, and everything below depends on
it.

---

## 1. Director's specification (2026-08-05), restated exactly

Ring model — the grenade reaches **3 GU beyond ring 0**, so rings 0,1,2,3.

| Effect | Ring 0 | Ring 1 | Ring 2 | Ring 3 |
|---|---|---|---|---|
| **Destruction (floor + wall/ceiling, unified — D1)** | muito | menos | quase nada | — |
| **Dented** | alguns | menos | — | — |
| **Cracked** | — | vários | alguns | — |
| **Soot (fuligem)** | strongest | medium | weak | minimal — **ring 3's only effect** |
| **Smoke (fumaça)** | most | medium | least | minimal — staggered in after ring 2 |

Plus, as ratified in this session (2026-08-05) and revised the next
(2026-08-06, marked **rev**):

- **D1 (rev 2026-08-06, corrected same day — see Q1b)** Destruction, dented,
  cracked, soot, and smoke all use **one unified per-tier ring-weight model**
  (§4.2) for floor, wall, and ceiling. What this replaces is the old idea that
  walls used a *different formula shape* ("ring-mult × material-resistance")
  than the floor's *muito/menos/quase nada* table — they now share the same
  ring-weight tables. **What it does NOT replace: `MaterialResistanceTable`
  itself.** Per-material resistance (concrete destroys more than stone, metal
  never cracks, wood chars instead) is an existing, unchanged mechanism and
  keeps multiplying against the ring weight exactly as it does today — the
  Director's own words: *"Esse mecanismo já existe. O que muda é só a
  intensidade em que isso ocorre por slice vertical até o teto."* The only new
  axis is *vertical*: rings flood walls horizontally (0–3 across GUs) **and**
  vertically — the slice directly above the blast's own floor level takes
  less, the slice above that even less. This is why a ceiling naturally takes
  the least damage today: not a hardcoded ceiling rule, a consequence of
  vertical distance from a blast that (for now) always originates at floor
  level. **Formula confirmed 2026-08-06 as D14 below.**
- **D14 (new 2026-08-06, answers Q1b)** The falloff is **spherical**: one ring
  step per **8 voxels in every direction**, horizontal or vertical. The
  constants make this exact rather than approximate —
  `VOXELS_PER_UNIT_AXIS = 8` and `LEVELS_PER_STOREY = 8`, so one storey of
  height measures one GU of width. Only the **material** changes what that
  distance costs (`MaterialResistanceTable`, unchanged). Two code
  consequences, both detailed in §10 Q1b: it **retires** the deliberate
  `is_roof` per-raw-level stepping in `apply_container_damage()` (whose own
  comment asked to be reviewed against a real capture — this is that review),
  and `maxi(0, vertical_ring)` becomes `absi(…)` so the sphere is symmetric
  below the blast as well as above, which D15 makes load-bearing.
- **D15 (new 2026-08-06)** A grenade can be thrown **onto a roof**, destroying
  it and opening a **hole in the slab**. Its destruction physics is *"o mesmo
  sistema de destruição do chão, sem nenhuma diferença"* — the same
  `apply_crater_damage()` model, the same rings, the same per-material
  resistance; only the container role differs. The blast's origin level is the
  roof's own level, which §4.3's formula already handles (it always measures
  from that detonation's floor level, never a fixed ground constant). **How
  many grenades it takes is settled by D17; which atoms the struck slab shows
  is settled by D16; what the hole is *for* is settled by D18.**
- **D16 (new 2026-08-06)** **Which existing atom pool a slab draws from is
  decided by the side the blast hits it from, not by the slab's role.** The
  Director raised this unprompted as the contradiction nobody had asked about:
  D6/D7 established that ceiling voxels never appear on floors and vice versa.
  That rule stands — it is about *where the blast comes from*, which for a
  ceiling had until now always been below:
  - Grenade **on the floor** → the ceiling takes the blast **from below** → it
    shows only ceiling-baked damage (D7's bottom alpha-cuts). No floor
    dented/cracked ever appears up there. Unchanged.
  - Grenade **on top of a roof slab** (D15) → that slab **stops behaving as a
    ceiling and behaves as a floor**: it takes the blast **from above** and
    shows dented, cracked and holes *"como se fosse no chão"*, drawing the
    floor's **existing** special voxels.

  **This adds no atoms and §3.2's total does not move.** Director, correcting
  an earlier reading of mine that had invented a 36-atom row for it:
  *"não tem recontagem, os voxels já existem... a contagem não muda, apenas
  onde eles aparecem."* D16 is a routing rule over the current table, and
  Task 0's ~737 ms stands unchanged.

  *One thing to judge on capture, not in advance (Task 5):* the floor's atoms
  are baked against `ground_concrete` substrates, so a metal or wood roof
  pierced from above will show that damage material rather than its own. That
  may read perfectly well — a sunk hole is mostly debris and shadow — and it
  is what "the same floor voxels" means by construction. Flagged so a capture
  that reads wrong has a recorded cause, not so it gets pre-emptively changed.
- **D17 (new 2026-08-06, answers Q1c)** Roof piercing keeps the existing
  destruction model *"por enquanto"*: **one grenade pierces one slab; a second
  grenade pierces the next one down.** Task 2 must expose a **named
  calibration multiplier** on this specific term — Director: *"posteriormente
  podemos querer aumentar esse dano em função do gameplay, então deixe um
  multiplicador atrelado pra gente calibrar isso futuramente."* It is a
  separate knob from `apply_container_damage()`'s existing
  `destroy_multiplier` (WEAPON_MASTER_PLAN D2's calibre/punch term), which
  must keep meaning what it means today.
- **D18 (new 2026-08-06, scope-defining — read before designing anything
  around roof holes)** **Upper storeys are not playable.** They exist to
  compose the scene's height, nothing else. So roof destruction is a
  **lighting** event — it changes where light and shadow fall, which per the
  ratified Phase 3 sequencing is exactly what the detection, movement-cost,
  sound and patrol numbers are waiting on. It is **not** an access route: the
  player cannot enter from above, and no tactical entry mechanic hangs off it.
  Any reasoning that treats a roof hole as a way in is wrong.
- **D19 (new 2026-08-06, supersedes the surface-specific half of D9/D10)**
  **A material behaves identically on floor, wall and ceiling.** Director:
  *"os materiais são sempre os mesmos para chão e para teto. O fato de ser
  'ground' concrete não muda nada em relação a 'slab_concrete'... para
  durabilidade, baked assets, fuligem, efeitos especiais, brasa, etc, o
  material se comporta exatamente igual no chão, na parede ou no teto."*
  Material is one axis; surface is another; **the surface never modifies the
  material.** The `ground_` prefix encoded surface, which this decision makes
  meaningless — the canonical name is the bare one (`concrete`, `grass`,
  `sand`, `dirt`, `gravel`).

  **What it closes for free (behaviour side, do this in Task 2):**
  `MaterialResistanceTable` stops carrying separate `ground_*` rows. Today
  `concrete` reads `{destroy 0.3, dent 0.15, crack 0.1}` while
  `ground_concrete` reads `{0.5, 0.2, 0.0}` — two rows for one material, and
  the disagreement is exactly **D10's flagged `crack_factor` gap**. Under D19
  there is one concrete row, its `crack_factor` is 0.1, and floors crack like
  walls. **D10's gap is therefore closed by construction, not by a separate
  decision, and the "216-atom variant" note it generated is void.** Same for
  the `"earth"` shared-damage-family placeholder D9 was already retiring.

  **What is NOT free, and must not be done as a silent rename (flagged, see
  §10 Q1d):** `ground_*` are not aliases. They are five *photographic,
  `full_color = true`* materials, and `full_color` is a documented **exception
  to bake invariant B2's grayscale rule** (`bake_compositor.gd:456`, forcing
  modulate WHITE so their real RGB survives). So `concrete` currently has two
  different asset pipelines depending on surface — procedural grayscale for
  walls, photographic for floors — which is precisely the thing D19 says
  should not depend on surface. Worse, the strings live in shipped map data:
  `maps/*.map.json` reference `ground_concrete`, `ground_dirt`, `ground_grass`
  and `ground_sand`, so a rename is a **MAPFILE migration** under
  `MAPFILE_REFERENCE.md`'s versioned-section protocol, not a find/replace.
- **D20 (new 2026-08-06, executes D19 — the naming logic, decided)** One
  material table; the **only** thing that separates by surface is the baked
  texture. Director: *"a de chão usa outra projeção de imagem na superfície, e
  a parede exibe uma textura vertical. A iluminação muda porque o chão vai ter
  superfícies escuras e o multiply estava ficando ruim... Mas o material em si
  é rigorosamente o mesmo. Podemos ter uma tabela única para materiais e
  separar só a parte da textura que é baked."*

  ```
  material id          concrete          ← ONE row. Behaviour: destroy/dent/
                                           crack, soot, effects, ember.
                                           Surface-independent, always.
  vertical texture     facade_concrete   ← SLICE  (walls)
  horizontal texture   slab_concrete     ← SLAB   (floor AND ceiling)
  ```

  **Why this split of names and not the symmetric one.** The Director offered
  `slab_*`/`slice_*` or `facade_*`/`ground_*` and asked only that the logic be
  defined. Measured before choosing: `facade` is **512 occurrences across 31
  `.gd` files, 35 docs, 8 assets — and zero map files**; `ground_` is **107
  occurrences, and it IS in 2 maps**. So:
  - **`facade_*` stays.** Renaming it to `slice_*` is ~5× the churn for no
    semantic gain — "facade" is already the right word for a vertical building
    face, and it is the entrenched vocabulary of the whole bake system
    (`facade_id`, `FacadeSampler`, `bake_policy.gd`, the PNGs on disk).
  - **`ground_*` → `slab_*`.** This one has to change regardless: the maps
    carry it, so a MAPFILE migration is happening anyway, and `ground` is
    **semantically wrong** under D19 — a ceiling is a slab and is never
    "ground". `slab_*` matches the engine's own `Slab` container class.

  The asymmetry `facade`/`slab` is deliberate and meaningful: a facade is a
  vertical face, a slab is a horizontal plane. Both are the correct
  architectural words; neither is a leftover.

  **Earth walls and grass roofs become legal**, and behave like any other
  material taking damage — Director: *"em teoria possíveis de existir... Não
  vão aparecer muito em mapas porque não faz sentido. Mas a engine vai ser
  unificada em relação aos materiais."* The engine must not forbid them; map
  authorship simply won't ask for them often.
- **D21 (new 2026-08-06, hard constraint)** **Material properties are dynamic
  data and are never hardcoded, and never tied to a particular map.**
  Director: *"essa questão de materiais no FILEMAP não pode estar hardcoded em
  nenhum lugar, e atrelada a um mapa X ou Y. Precisamos ter as propriedades
  dinâmicas e bem definidas."* Two places violate this today and both are in
  Task 1's path:
  - `MaterialResistanceTable.TABLE` is a `const` Dictionary literal in
    GDScript. It must become registered data. (Note this is the same direction
    as `CLAUDE.md`'s inviolable Rule 1 — stats are `var`, never `const` —
    whose automated checker happens to scope only the named gameplay stats,
    so it never flagged this one.)
  - `MaterialRegistry.register_defaults()` hardcodes the roster in code, and
    the `ground_*` rows in the resistance table were added *because* PLAYGROUND
    specifically has a concrete floor — exactly the map-coupling D21 forbids.

  D13's per-map declared-materials section is the *right* shape for this: the
  **map declares which material ids it needs**, the **engine resolves their
  properties from registered data**, and no code anywhere names a map. This
  also lines up with why the Baking System exists at all — materials are
  headed toward per-player procedural generation, not a fixed catalog (§3.5).
- **D2** Floor layers: the **first** blast on a virgin GU cedes only
  `FLOOR_TOP_LEVEL` (−1). A **later** blast on a GU that has already been
  blasted also cedes `FLOOR_DEEP_LEVEL` (−2). Requires per-GU blast memory.
- **D3** Three substrate variants per (material × type × decal), chosen per
  cell by a deterministic hash, so neighbouring damaged voxels rarely show the
  same piece of facade.
- **D4** Build in phases: **Phase A** = bake + calculation + waves on the
  current right-click trigger. **Phase B** = targeting UI, throw animation,
  bubble, the 1-second pre-compute window.
- **D5 (new 2026-08-06)** Smoke reaches ring 3 (weak, per the table above),
  and rings fire their smoke **in order, not simultaneously** — already the
  wave list's shape below, now extended one entry for ring 3.
- **D6 (new 2026-08-06)** Cracked is **one voxel family per material**, not
  one per element class. A cracked atom bakes its decal onto all three visible
  faces at once (it represents a voxel already failing on every side), so the
  same 3×3 (decal × substrate) atom set serves floor, wall, *and* ceiling —
  see §3.2's rewritten count.
- **D7 (new 2026-08-06)** Ceiling DENTED gets **3 irregular alpha-cut shapes**
  (broken-brick-style, reference image on file), not the single silhouette
  §3.2 assumed under Q4's old default. The cut-shape *art* is reusable across
  materials that share a look (not every material cracks — iron doesn't — so
  not every material needs its own cut set), but each material still bakes its
  own atom (facade differs per material even when the cut shape is shared).
- **D8 (new 2026-08-06, optimization, not yet scheduled to a task)** Soot and
  the light repaint for blast-affected voxels can be computed **after** the
  smoke waves fire rather than before wave 1, since soot visibly appearing a
  moment late reads as natural. This loosens §2's "repaint once, before wave 1"
  rule specifically for the soot waves — see §6.3.
- **D9 (new 2026-08-06)** Floor damage baking is **not agnostic to a single
  "earth" family anymore.** Today `IMPACT_FLOOR_MATERIAL = "earth"` fixes both
  the decal *art* and the `MaterialResistanceTable` *lookup* to `"earth"`
  regardless of a GU's real ground material — the Director explicitly rejected
  this: *"Chão de ferro não fica rachado, chão de concreto destrói mais que
  chão de pedra."* Floor specials now key off each GU's **real** registered
  ground material (`MaterialRegistry` — PLAYGROUND's is `ground_concrete`)
  against the same resistance table walls already use, and their decal base is
  a **random pre-baked SLAB atom** (top-face facade for that ground material,
  produced by the existing Slab/`BakeCompositor` pipeline — `ground_concrete`
  is already in `VOXEL_MATERIALS`, §3.2) instead of a wall-style facade voxel.
  **Scope for this plan: `ground_concrete` only** — the Director was explicit
  that the wider ground roster (`ground_grass/dirt/gravel/sand`, already listed
  in `bake_compositor.gd`) is a later population pass, not this rebuild's job;
  this plan's task is to make the *pipeline* material-driven, not to populate
  it. See §3.2's rewritten floor rows.
- **D10 (new 2026-08-06, consequence of D6+D9)** Crack eligibility collapses
  to **one source of truth**: a material cracks if its
  `MaterialResistanceTable` row has `crack_factor > 0` — full stop, for wall
  *and* floor materials alike. The separate `IMPACT_CRACK_MATERIALS` constant
  (today hardcoded to `[concrete, stone]`) becomes a derived query instead of
  an independent list that has to be kept in sync by hand. **Known gap this
  surfaces, not silently papered over:** `ground_concrete.crack_factor` is
  `0.0` today, for the same reason wood's and metal's used to be — *"no
  texture wired stays off"* (the table's own standing rule). D6 now provides
  that texture (the universal cracked atom serves floor too), so the original
  reason is gone, but this plan does not unilaterally change balance data.
  **Task 2 should revisit this row** once the atom exists to serve it — flagged
  here so it isn't lost, not answered here.
- **D12 (new 2026-08-06, answers Q3b — numbered past D11 to avoid colliding
  with the pre-existing "D11" choreography decision this plan already
  references in §0/§2)** Bullet marks ("marked") join this same
  pre-baked-at-load registry, **replacing D33's live per-cell compositing for
  the mark-application step**. Per material: 3 decals × 2 sides (left/right) —
  no floor or ceiling variant, because *"tiros não acertam teto e nem chão"*
  (Director, confirming an existing design fact, not a new rule). This is a
  genuine scope change from the plan's original "firearms untouched" boundary
  — see §9's rewritten note and the sequencing flag in §11.

Detonation sequence (Phase B order, with Phase A's part marked):

1. Player presses the grenade button.
2. UI enters targeting mode: cursor becomes the impact GU, capped at throw
   range; red perimeter drawn on the floor around reachable GUs.
3. A virtual bubble shows the blast sphere (XCOM / Phoenix Point style).
4. Player clicks a GU → grenade armed.
5. **Heavy compute window #1** — a small hitch is tolerated here.
6. Throw animation; grenade lands and sits for 1 s.
7. **Heavy compute window #2** — a second hitch is tolerated here.
8. Full-screen white flash, tweened down. By this instant the dented/cracked
   atoms must already be resolved.
9. Explosion animation — 3 frames, fire/energy dispersing in alpha (**art
   pending from the Director**).
10. **[PHASE A]** 15 waves, fired one after another, inner rings first, each
    wave independent — no wave waits for the previous one to finish:

    > **⚠️ SUPERSEDED 2026-08-09 by E-ORGANIC-01/E-RADIAL-01 — the TABLE below
    > survives, the SCHEDULE does not.** The Director retired the fixed 15
    > waves (*"não precisamos fixar as 15 waves"*): a wave was whatever cells
    > fell in one (kind, ring) bucket, and buckets are wildly uneven, so
    > pacing by bucket guaranteed one catastrophic frame AND made effects
    > arrive in per-category blocks. The plan now flattens into one queue of
    > single-cell steps ordered by **radius from the epicentre**, paced
    > against a deadline. This table is still the tie-break ORDER at equal
    > radius. Read E-ORGANIC-01/E-RADIAL-01 before §11.

    | # | Wave | | # | Wave |
    |---|---|---|---|---|
    | 1 | Destruction ring 0 | | 9 | Smoke ring 1 |
    | 2 | Destruction ring 1 | | 10 | Smoke ring 2 |
    | 3 | Destruction ring 2 | | 11 | Smoke ring 3 |
    | 4 | Dented ring 0 | | 12 | Soot ring 0 |
    | 5 | Dented ring 1 | | 13 | Soot ring 1 |
    | 6 | Cracked ring 1 | | 14 | Soot ring 2 |
    | 7 | Cracked ring 2 | | 15 | Soot ring 3 |
    | 8 | Smoke ring 0 | | | |

    (Director's original 14-entry list plus **Smoke ring 3**, added
    2026-08-06 per D5/Q2 — destruction/dented/cracked apply to floor, wall,
    *and* ceiling cells within the same wave now, per D1; no per-element-class
    wave split needed.)

---

## 2. The core performance idea, stated once

**Every wave is a loop of `set_cell()` calls with already-resolved tile ids.**
No compositing, no lookup, no light rebuild, no allocation happens inside a
wave. Everything a wave needs — which cells, which `source_id`, which
`atlas_coords`, which alternative id (light bucket × soot tone) — is computed
in the pre-compute window and stored in a plain `DetonationPlan` dictionary.

This is what the previous architecture never had. D11's choreography did real
work per frame (composite, upload, repaint), which is why staging it made
things *worse*, not better. Here the choreography is pure playback of a
precomputed script.

Two consequences that must be designed for, not discovered later:

- **The map-wide light repaint runs exactly once**, inside the pre-compute
  window, *before* wave 1 — never per wave. Its output is folded into each
  cell's stored alternative id in the plan.
- **Exposure fallback is precomputed too.** Destroying a voxel exposes
  geometry behind it, which must fall back to the material atlas (bake
  invariant B5). Which cells those are, and which tile each gets, is resolved
  during pre-compute and shipped inside the destruction waves.

---

## 3. E-BAKE — the load-time damage atom set

### 3.1 Registry shape

`VoxelVariantRegistry`'s key loses its `(grid_pos, level)` dimension:

```
(element_class, material, damage_state, carved_side, decal_variant, substrate_variant)
  -> {source_id: int, atlas_coords: Vector2i}
```

`element_class ∈ {WALL, CEILING, FLOOR}`. The existing `make_cell_key()` is
replaced by `make_variant_key()`; the file's own docstring (which currently
describes the per-cell model) is rewritten to match.

### 3.2 Enumeration and count (rewritten 2026-08-06 twice — D6/D7, then D9/D10/D12)

**Enumeration rule (D10): derive material sets from `MaterialResistanceTable`,
don't hand-list them.** A material gets a DENTED atom if its `dent_factor > 0`;
a CRACKED atom if its `crack_factor > 0` (universal across floor/wall/ceiling,
D6); MARKED atoms unconditionally, for every wall material (bullets always
leave a mark regardless of blast resistance — a cosmetic, not a resistance
roll). Evaluated against today's real `TABLE` rows
(`material_resistance_table.gd`) and the real element-class rosters
(`voxel_renderer.gd`'s `IMPACT_DECAL_MATERIALS` for wall/ceiling-family
materials; D9's `ground_concrete` for floor, PLAYGROUND's only real ground
material today):

| Class | Materials (derived) | Combinations | Atoms |
|---|---|---|---|
| CRACKED (universal — floor + wall + ceiling, D6) | concrete, stone (2 — `crack_factor > 0`; **D10's `ground_concrete` exclusion is void under D19** — there is one concrete, and it cracks) | 3 decals × 3 substrates | 18 |
| DENTED WALL | concrete, metal, stone, wood (4) | 2 sides × 3 decals × 3 substrates | 72 |
| DENTED FLOOR (top only, D9) | ground_concrete (1 — real material, not `"earth"`) | 3 decals × 3 substrates | 9 |
| DENTED CEILING (bottom, alpha-cut, D7) | concrete, metal, stone, wood (4) | 3 cut shapes × 3 substrates | 36 |
| MARKED / bullets (D12, confirmed in-scope) | concrete, metal, stone, wood (4) | 2 sides × 3 decals × 3 substrates | 72 |
| | | **Total** | **207** |

**D16 adds no atoms.** A roof slab struck from above reuses the floor's
existing special voxels verbatim — Director: *"os voxels já existem... a
contagem não muda, apenas onde eles aparecem."* D16 is a routing rule over
this table, not an extension of it.

Not 135 (this session's first recount) and not the original ~192 — three real
moves happened across two rounds of answers: cracked went universal (D6,
−63), ceiling dented gained 2 more shapes (D7, +24), and marked/bullets joined
the pre-bake (D12, +72). ~~If Task 2 later turns on `ground_concrete.crack_factor` (D10's flagged gap),
the total becomes 216 (+9).~~ **Void under D19 (2026-08-06):** there is no
separate `ground_concrete` to turn on — one concrete row, `crack_factor` 0.1,
and the 18 cracked atoms already cover every surface it appears on. The total
stays **207**.

### 3.3 Substrate selection, and how it survives rotation

The substrate index (0..2) is **rolled at damage time and stored on the
Voxel**, exactly the way `damage_variant` already is, and for the identical
reason: `grid_pos` is view-space, so re-deriving it at paint time would re-roll
every mark on rotation.

- New field `Voxel.damage_substrate: int = 0`.
- Rolled by `BlastCalculator.substrate_for(salt, x, y)` — same FNV-1a
  hash-and-mod shape as the existing `decal_variant_for()`, **different salt**
  so substrate choice does not correlate with decal choice.
- Persisted in `room._base_damage` as a 7th column (see §7).

### 3.4 Bake cost — the gating unknown

The 95 ms/wall-voxel figure measured on 2026-08-05 was a per-cell bake with a
partly cold cache. A sequential 207-atom bake (§3.2, 2026-08-06 final recount)
is a different animal: the GPU readback cache (`_baked_source_image_cache`) is
warm after the first atom, the decal `Image`s are cached, `DecalCompositor`'s
resize cache is warm, and page uploads batch (PERF-02 A1 measured 197
uploads → 5, 876 ms → 8.1 ms). The marked/bullet atoms (D12) add real new
bake work here too — they used to be composited live, once per bullet hit, not
once per material at load; this spike is what tells us whether that trade is
actually cheaper.

**This projection is not evidence.** Task 0 below measures it before a single
line of the architecture is committed to.

Escape hatches, if Task 0 comes back too expensive **beyond what §3.5's cache
and per-map material scoping already buy**:
1. Substrates 3 → 1 (−138 atoms, 207 → 69; costs visual variety, D3 reversed).
2. Bake lazily on the **first** detonation, inside the pre-compute window
   (windows #1 and #2 exist precisely to absorb a hitch).

(The third hatch from the first draft of this section — "serialize the baked
page to disk" — is promoted out of the escape-hatch list: it's now baseline
design, §3.5, not a fallback. Task 0 still measures the **cold**, no-cache
case, because that's the number that answers "does a device's very first load
of a new material feel broken" — the cache cannot help that one.)

### 3.5 Material scope per map, and the cross-session bake cache (D13, new 2026-08-06)

**Why this exists (corrected understanding, same day):** the first framing of
this section guessed the reason was load-ordering (bake before geometry
compilation needs the atoms). The Director corrected that — the real reason is
bigger: the Baking System exists because maps and scenarios are planned to be
**downloadable and procedurally generated, unique per playthrough**, down to
subtle texture/UI/menu differences. *"O jogador A não vai ver o mesmo tipo de
madeira que o jogador B"* — materials carry per-player modifiers (color,
light, and other elements tied to character level or seasonal themes, e.g.
Halloween). A material set therefore **cannot be a small fixed game-wide
catalog** the way `IMPACT_DECAL_MATERIALS` is today — it's dynamic content,
different per player and even per session. Explicit per-map declaration isn't
an optimization choice over derivation, it's the only thing that can name a
material that doesn't exist anywhere else in the codebase yet.

**Scope: each map declares which materials it actually uses.** Per
`MAPFILE_REFERENCE.md`'s extension protocol, this is **a new registered
section** (`{section_id, version, serialize, deserialize, migrations[]}` via
`MapSectionRegistry`, read before implementing — required by CLAUDE.md for any
`.map.json` change), not an ad-hoc field bolted onto an existing one. For
today's game-wide materials (concrete, metal, stone, wood, ground_concrete),
Task 1 should add a selftest asserting the declared list is a superset of what
the map's own walls/blocks/floor_zones actually reference, so authoring drift
fails loudly (B6) instead of silently missing its bake.

**Cache: baked atoms persist across sessions on the same device.** `user://`-
scoped, keyed on `(material, damage_state class, decal_variant,
substrate_variant)` **plus** a version/hash of the bake inputs, so a content
update invalidates stale entries automatically. A map whose full declared
material set is already cached pays **effectively zero** bake time on that
load — Task 1's gate includes a real capture proving this.

**Explicitly deferred, not this plan's job (Director, 2026-08-06):**
*"o cache vai ser baked muitas vezes para cada jogador, e o cache precisa ter
um gerenciamento dinâmico e bem planejado — podemos deixar isso pra o fim da
fase de destruição."* Per-player procedural material variants mean the cache
will eventually need real management: a storage budget, an eviction policy,
versioning for regenerated/reskinned materials, tracking which variants
belong to which playthrough. **None of that is built here.** Task 1's cache
stays deliberately minimal — a flat `user://` store keyed as above, no
eviction, no per-player namespacing — sufficient for this plan's actual
material set (concrete-focused, game-wide, not yet procedural). The dynamic
cache-management system gets its **own dedicated planning pass, later, at the
end of the destruction phase** — not a Phase A or Phase B item of this plan,
and not something to start scoping now. Added to §9's out-of-scope list.

**Partial coverage is already handled, not new work (D10 generalizes):**
*"alguns materiais vão ter todos os decals, outros só alguns"* is exactly
what D10's derive-from-`MaterialResistanceTable` rule already does — a
material with `crack_factor == 0` simply never enumerates a CRACKED atom.
Extending the roster later (new materials, or new decal families for existing
ones) is adding rows/factors and declaring the material on the relevant maps,
no code change.

---

## 4. E-RING — the four-ring model and per-tier gating

### 4.1 Reaching ring 3

`flood_gu_rings()` caps at `ring_multipliers.size() - 1`, so ring 3 is reached
by **data alone**: `frag_grenade.json` becomes

```json
"ring_multipliers": [1.0, 0.6, 0.25, 0.0]
```

Ring 3's `0.0` means it contributes no destruction/dent/crack — it exists to
carry soot. No change to the flood code.

### 4.2 Per-tier ring gates (new; now shared by floor, wall, and ceiling — D1 rev)

Today every ring rolls all three tiers, scaled by one multiplier. The
Director's table gates tiers **by ring** — dented never appears in ring 2,
cracked never in ring 0. That needs explicit per-tier weight tables, living in
`BombDef` (loaded from JSON, so they are `var`s, honouring architecture rule 1):

```json
"destroy_ring_weights": [1.0, 0.35, 0.08, 0.0],
"dent_ring_weights":    [1.0, 0.45, 0.0,  0.0],
"crack_ring_weights":   [0.0, 1.0,  0.35, 0.0],
"soot_ring_tones":      [0, 1, 2, 3],
"smoke_ring_weights":   [1.0, 0.5,  0.2,  0.1]
```

`smoke_ring_weights[3]` moved from `0.0` to `0.1` (D5/Q2 — smoke now reaches
ring 3, weak). `apply_container_damage()` multiplies each tier's count by its
own ring weight instead of the single shared `ring_multipliers[ring]`, and —
new as of D1 rev — this is no longer a floor-only computation: the same
weight tables gate wall and ceiling cells too, using the *effective ring* from
§4.3 rather than the flat horizontal ring. The starting numbers above are a
first pass on *"muito / menos / quase nada"* — tuning knobs, expected to move
after the first real capture (Task 6).

**`MaterialResistanceTable` is untouched and keeps multiplying in, exactly as
today (D1's clarification)** — the real per-cell formula is
`count = ring_group_size × resistance[material][tier_factor] × tier_ring_weights[effective_ring]`,
not a replacement of the resistance term, an *addition* of the ring-weight
term next to it. The one real change for floor cells (D9): `material` in that
lookup stops being the hardcoded `"earth"` and becomes the GU's real ground
material (`ground_concrete` on PLAYGROUND today) — so `apply_crater_damage()`
needs the same material-lookup change `apply_container_damage()` already has,
where today it likely doesn't (unverified — Task 2 confirms by reading the
real function, not by this plan asserting it).

### 4.3 Vertical falloff for walls/ceiling (D1 rev — ✅ CONFIRMED 2026-08-06 as D14, spherical)

> **Confirmed and amended.** The mechanism below is right and, for walls, is
> already what `apply_container_damage()` ships. D14 amends it in two places
> that the text below predates — read §10 Q1b for the evidence:
> **(a)** `max(0, …)` becomes `abs(…)`, because D15's roof throws put real
> geometry *below* the blast and a sphere is symmetric;
> **(b)** the `is_roof` branch that advances roofs one ring per **raw level**
> is retired — roofs step per storey like everything else, which means a
> 2-level roof shows uniform damage rather than an internal gradient. That
> branch's own comment asked for exactly this review.

§4.2's weight tables are indexed by ring, and until 2026-08-06 "ring" meant
purely the horizontal GU distance from `flood_gu_rings()`. The Director's
answer to Q1 asks for a *second* falloff axis — vertical — so that a wall
slice directly above the blast's own floor level takes less than one at the
same level, and a slice above that takes less still (explaining, as a
consequence rather than a special case, why ceilings take the least damage:
they sit furthest above a blast that always originates at floor level).

**Proposed mechanism**, chosen because it reuses §4.2's existing tables
without adding a second parallel set of weights:

```
effective_ring(cell) = clamp(
    horizontal_ring(cell.gu) + max(0, cell.floor_level - blast.floor_level),
    0, ring_weights.size() - 1
)
```

A wall voxel at the blast's own floor level, horizontal ring 0, gets
`effective_ring = 0` (full weight). One floor level up, same horizontal ring,
gets `effective_ring = 1` ("menos"). Levels *below* the blast's floor level are
not penalized by this term (grenades that land on a floor have nothing
naturally below to fall off from; D2's floor-layer rule already governs
what's below). If throwing onto a roof is ever built, the formula is unchanged
— it always measures from that detonation's own floor level, never a fixed
"ground" constant.

This changes `apply_container_damage()`'s per-cell ring lookup from
`horizontal_ring(cell)` to `effective_ring(cell)` for wall/ceiling cells (floor
cells keep using the horizontal ring alone, since D2 already owns their
vertical dimension via the two-layer rule). **Confirm or correct before
Task 2** — it is the one piece of D1 the Director's answer described in
behavior, not in exact formula.

### 4.4 D2 — the two floor layers

`apply_crater_damage()` gains a `deep_layer_unlocked: bool`:

- `room` keeps `_gu_blast_count: Dictionary` (base-coords GU → int), persisted
  alongside `_base_damage`.
- First blast on a GU: only `FLOOR_TOP_LEVEL` voxels are candidates for
  destruction.
- Second and later: `FLOOR_DEEP_LEVEL` joins the candidate set, still narrowed
  by the existing `DEEP_FLOOR_CRATER_FACTOR` (0.5) bowl shape.

The existing PERF-02 B4 hack ("skip FLOOR_-2 entirely") is removed — D2 is the
principled version of the same saving.

---

## 5. E-SOOT — per voxel, authored, not derived
##
## ⛔ **SUPERSEDED 2026-08-13 by `SOOT_MASTER_PLAN`.** The authored stamp this
## section specifies was built, shipped disabled (E-DENT-01, 2026-08-08), shown
## to the Director on 2026-08-12 in a three-way A/B/C, and DELETED — it stamps
## once per container, i.e. once per GU, so it produces a hard GU boundary by
## construction ("muito forte por GUs, mas de repente na GU do lado não tem
## nada"). Soot is `derive_soot_rings()` + `apply_self_soot()` only.
## `BombDef.soot_ring_tones` is parsed and ignored. Read the section below as
## the historical specification it is.

### 5.1 What changes

| | Today | After |
|---|---|---|
| Granularity | per FACE (3 faces packed) | **per VOXEL** (one tone) |
| Code count | `FACE_SOOT_CODE_COUNT = 125` | **5** (4 tones + clean) |
| Alt-id headroom | 12 × 125 × 2 = 3000 / 4096 | 12 × 5 × 2 = **120** / 4096 |
| Origin | derived from holes each repaint | **authored by the blast**, per ring |

The alt-id ceiling (`TileSetAtlasSource.TRANSFORM_FLIP_H` = 4096) stops being a
binding constraint, which is what let the Director's earlier "five tones"
request get refused. Worth noting: five tones would now fit trivially.

### 5.2 Why derivation alone cannot work here

`derive_soot_rings()` seeds soot from **currently destroyed voxels**. Ring 3
destroys nothing, so a derived map can never produce ring 3 soot — which is the
Director's only stated effect for that ring. Soot must therefore be stamped
explicitly by the blast.

### 5.3 Not breaking firearms

Firearm soot rides entirely on that same derivation (D24: an isolated bullet
hole reads as ~1 ring on its own). Removing it would silently break the one
destruction path that currently works.

**Design: the soot map is the darker of the two sources.**
`soot_tone(cell) = min(derived_from_holes(cell), stamped_by_blast(cell))`
(lower index = darker). Derivation stays exactly as it is, firearms are
untouched, and the blast simply adds its own four rings on top. The per-face →
per-voxel collapse is a pure data simplification of the same values (take the
darkest of the three faces) and is verified by capture, not by reasoning.

**Timing, not just tone (D8, new 2026-08-06):** the stamped-by-blast half of
this computation, and the light repaint it feeds, do not need to land before
wave 1 the way destroy/dent/crack/smoke do — see §6.3 for the deferred-compute
proposal that spends that extra ~440 ms of slack.

---

## 6. E-WAVE — the choreography driver

### 6.1 The plan object

Built entirely in the pre-compute window:

```gd
DetonationPlan = {
  "destroy":  { ring: int -> Array[{cell: Vector2i, level: int,
                                    expose: Array[{cell, level, source_id, atlas_coords, alt}]}] },
  "dented":   { ring: int -> Array[{cell, level, source_id, atlas_coords, alt}] },
  "cracked":  { ring: int -> Array[{cell, level, source_id, atlas_coords, alt}] },
  "smoke":    { ring: int -> Array[{world_pos: Vector2, duration: float, scale: float}] },
  "soot":     { ring: int -> Array[{cell, level, alt}] },
}
```

Every rendering entry carries its final `alt` (light bucket × soot tone) so a
wave never consults the light field.

### 6.2 The driver

A small `DetonationChoreographer` (new, ~120 lines) walks a static wave table
`[(kind, ring, delay_ms)]` and applies each wave's array. Waves are scheduled
on absolute elapsed time from the flash, so a slow wave never delays the next —
matching *"cada onda independente, sem esperar a outra acabar."*

~~**Cadence confirmed 2026-08-06: 40 ms/wave** → 15 waves ≈ 600 ms of
choreography (was 560 ms/14 waves before Smoke ring 3 was added).~~

> **⚠️ SUPERSEDED 2026-08-09.** The Director moved this three times in one
> session — 40 ms → 20 ms → "no máximo 1 frame por wave" → no fixed wave at
> all. There is no per-wave interval any more: `sequence_ms` (240) is what the
> WHOLE blast should take, and each frame advances the queue to wherever that
> deadline says it should be. The paragraph's last sentence is the part that
> held up — it is still a `var`, and it was still re-tuned against real
> captures. See E-ORGANIC-01.

Smoke waves call the existing `SmokeSparkOverlay.add_smoke()` with per-blob
durations drawn from the ring (Director: *"usando durações diferentes"*) — that
overlay already exists and needs no rebuild.

### 6.3 Deferred soot + light compute (D8, new 2026-08-06 — optimization, not yet scheduled to a task)

§2's rule is "the map-wide light repaint runs exactly once, before wave 1."
The Director's 2026-08-06 addendum proposes loosening that specifically for
the four soot waves (12–15): since soot visibly settling a beat late reads as
natural (real fuligem takes a moment to appear), the soot tone computation and
its light repaint don't have to be ready before wave 1 — they only have to be
ready by the time wave 12 fires, roughly **440 ms** later at 40 ms/wave
(waves 1–11). That is real slack the destroy/dent/crack/smoke waves don't get.

Two ways to spend that slack, either compatible with `DetonationPlan`'s
existing shape:
- Compute soot synchronously but **after** dispatching wave 1, in whatever
  time remains before wave 12 is due — no thread needed, just reordering.
- Compute it on a background thread (`WorkerThreadPool`) started alongside the
  destroy/dent/crack pre-compute, and fire wave 12 on the *later* of "thread
  done" or "440 ms elapsed" — Director: *"se for possível soltamos antes, se a
  thread já estiver disponível."*

Not scheduled to a specific task yet — Task 4 (E-PLAN) is the natural place to
decide which of the two, once the rest of the pre-compute window's real cost
is known from Task 0.

**⚠️ SUPERSEDED IN PART, 2026-08-10.** This whole note predates
`build_plan()`/`WorldDelta` (P-DELTA, P-SLICE) — there is no "wave 1" to
dispatch relative to any more, and every entry's `alt` (including soot's) is
already resolved inside the single pure pre-compute pass, on the main thread,
before `commit()`. The reordering this note proposed never happened and the
timing pressure it was solving (soot ready by wave 12, ~440 ms in) no longer
applies at 5-frame `front_frames`. **The soot-as-a-late-fading-beat idea is
alive again, in a different shape** — see "E-FRAG-01 / E-SHARD-01
(2026-08-10)" near the end of this file, task E-FUME: soot moves to its own
step in the choreographer's queue, not a background thread, and the reason to
defer it now is a fade-in look, not a compute-cost deadline.

---

## 7. E-PERSIST — what survives rotation

`room._base_damage[Vector3i]` grows from 6 columns to 7:

```
[damage_state, is_blast, dir.x, dir.y, dir.z, variant, substrate]
```

Two new sibling stores, both in base coords:
- `_base_soot[Vector3i] -> tone` (soot is now independent of damage state — a
  ring-3 voxel is sooted and otherwise intact).
- `_gu_blast_count[Vector2i] -> int` (D2's floor-layer memory).

`.map.json` is untouched — these are runtime session state, not map data.

---

## 8. Tasks, in order

| # | Task | Deliverable | Gate |
|---|---|---|---|
| **0** | ✅ **DONE 2026-08-06 — GATE PASSED, see §8.1** | **~737 ms** measured for all 207 atoms (742.3 / 731.3 / 739.0 across three runs) | Gate was ~2 s. **2.7× headroom — no escape hatch needed.** Task 1 proceeds as written |
| **1a** | ✅ **DONE 2026-08-06, commit `95d83cb`** — **E-MAT**, D19/D20/D21 | **One material table, surface-independent.** `MaterialResistanceTable` + `MaterialRegistry` load from `res://materials/*.json` (+ `user://` override) instead of hardcoded GDScript — the duplicate `ground_*` rows collapsed into their base material, one `concrete` row, `crack_factor` 0.1, closing D10's gap; texture identity moved to `(material, surface_class)` via `BakePolicy` — `SLICE → facade_*` (unchanged, **including roofs**, which reproject their own wall texture rather than adopting a SLAB source) and `SLAB → slab_*` (renamed from `ground_*`, floor zones only); `full_color` **retired** from `MaterialDef` — corrected against the plan text: the bake compositor's WHITE-vs-tinted modulate now reads the texture id's own prefix, since one unified material (concrete) needs tinted-on-walls AND full-color-on-floors at once, which a single material-level flag cannot express; `floor_zones` MAPFILE section bumped v1→v2 with a migration, 2 shipped maps edited directly; no code names a map anywhere (D21) | `project_lint` + all 30 selftests clean · `check_invariants` OK · **real PLAYGROUND capture pixel-identical to the pre-reform one — 0/921600 differing pixels** (`Screenshots/history/e_mat_before.png`/`e_mat_after.png`) · `material_reform_selftest.gd` (new) proves the unified row + the surface-split render |
| **1b** | ✅ **DONE 2026-08-06, commit `2d18a9e`** — **E-BAKE** | `VoxelVariantRegistry` re-keyed to `(element_class, material, damage_material_name, substrate_variant)`; `DamageVariantBaker` rewritten to `bake_all(declared_materials, floor_materials)`, D10-derived (crack_factor > 0, not the hardcoded `IMPACT_CRACK_MATERIALS` list) across WALL/CEILING/FLOOR, scoped to each map's `damage_materials` MAPFILE section (D13, registered); D12's marked/bullet atoms baked as **both** shapes (144 atoms, Director-confirmed, not the plan's original 72) — and found to already be **live and consumed by `fire_active()`** with zero code changes there (§9's rewritten note); floor specials source substrate from the real ground material via SLAB atoms per D9; `user://` bake cache wired (reusing `BakeCompositor`'s own encode/decode/load/save helpers); wired into `room_builder`; `damage_atom_bake_selftest.gd` (new) asserts real coverage, the new key's consumer, cache parity, and D13's loud-fail | **273 real atoms** on PLAYGROUND (0 unresolved) · load-time count+ms printed · second-load cache-hit capture: **1498 ms → 31 ms**, 255/255 disk cache hits, 0 misses · firearm live-D33 sanity capture unaffected |
| **2** | ✅ **DONE 2026-08-07, commit `a3f58ee`** — **E-RING** | Calculation-layer only (neither function has a live caller yet — confirmed, Task 5's job to reconnect). 4th ring in `frag_grenade.json` + `destroy_ring_weights`/`dent_ring_weights`/`crack_ring_weights` in `BombDef`; `apply_container_damage()`'s vertical-ring step rewritten to D14's spherical `absi(level_offset) / LEVELS_PER_STOREY` (both wall and roof, `is_roof` per-raw-level branch retired); `apply_crater_damage()` gains `deep_layer_unlocked` (D2) and `slab_pierce_multiplier` (D17, trailing + inert at 1.0); D16 needed zero calculation-layer changes — it's entirely `VoxelRenderer.apply_damage_voxel_swap()`'s CEILING+TOP→FLOOR routing fix; D9 confirmed already fully wired pre-task, this task's job was proving it | `blast_calculator_selftest` +6 real assertions (ring-3 red-before-green against the REAL `frag_grenade.json`, D14 wall/roof parity, the roof-two-levels-one-ring-group proof, wood-vs-concrete floor realism, D2 gate on/off, D17 multiplier live-check) · `damage_atom_bake_selftest` +1 test (D16 routing proven against the real PLAYGROUND registry + a real `TileMapLayer` readback, not a boolean) · 31/31 selftests clean |
| **3** | ✅ **DONE 2026-08-07, commit `fdcb5e9`** — **E-SOOT** | Calculation-layer only, same reason as Task 2 (no live caller). Full per-face directional soot **kept everywhere** — `FACE_SOOT_CODE_COUNT`/encode/decode/shader untouched, per Director confirmation this session (§5.1's per-voxel collapse was a stale processing-cost concession); `stamp_container_soot()` (walls/ceiling, reuses D14's ring formula + `carved_side_for()` + `_face_rings_for()`) and `stamp_crater_soot()` (floor, extends `apply_crater_damage()`'s own `rim_span` unit into numbered rings) stamp soot from `BombDef.soot_ring_tones`, independent of what got destroyed — closing the real gap that ring 3 (destroys nothing) can never get soot through derivation alone; both min-wins-merge with `derive_soot_rings()`'s output. No `room.gd` changes — the stamped-blast event/replay list is Task 5's job, alongside `_gu_blast_count` | `blast_calculator_selftest` +12 real assertions (ring-3 reached-and-stamped against the REAL `frag_grenade.json`, epicenter-directional face split, ceiling-underside skip, stamped/derived min-merge both directions, crater ring bands + isotropic output, out-of-range skip) · 31/31 selftests clean, including all 7 pre-existing `SOOT-SELF-*`/`FACE-SOOT-*` assertions unchanged |
| **4** | ✅ **DONE 2026-08-07, commit `ddbe7dd`** — **E-PLAN** | `DetonationPlanBuilder.build_plan()` — the real resolution/soot-merge/single-light-field-query/exposure-fallback pipeline, resolve-only end to end (a new `apply` seam on `_set_voxel_cell()`/`apply_damage_voxel_swap()`→`resolve_damage_voxel_swap()`/`render_slab()`/`render_fixed_earth_level()`); `smoke_ring_weights` consumed for the first time; two new `BlastCalculator` public helpers (`vertical_ring_for()` promoted, `crater_ring_for()` extracted) so wave grouping and soot banding share one ring formula | Printed plan census from a real PLAYGROUND detonation (see closure note) · a real before/after TileMapLayer snapshot diff over 108,576 cells proves zero live mutation · `run_selftests.py` 32/32 clean |
| **5** | ✅ **DONE 2026-08-07, commit `98e9772`** — **E-WAVE** | `DetonationChoreographer` (15-wave table, independent `SceneTreeTimer` per wave, `wave_interval_ms=40`); `TestZoneController.detonate_active()` reconnected end to end; `add_smoke()` gained `duration_scale`; `build_plan()` returns `touched_voxels` for VL-PERSIST; `room._gu_blast_count` (D2) added | Real capture (`Screenshots/history/e_wave_detonation.png`) · real per-wave `[E-WAVE]` timing log on the actual detonation · `detonation_choreographer_selftest.gd` proves every wave's cells match the plan exactly · `run_selftests.py` 33/33 clean |
| 6 | Tuning pass | Director reviews captures, moves the §4.2 numbers | Director sign-off |

### 8.1 Task 0 result — the number the architecture rests on (2026-08-06)

**~737 ms to bake all 207 atoms. The gate was ~2 s. It passes with 2.7×
headroom, so §3.4's escape hatches are NOT taken and Task 1 proceeds as
written.**

Method: temporary `INFILTRAITOR_CAPTURE_ACTION=explosion_bake_spike` hook in
`room.gd`, driving the same compositor functions `DamageVariantBaker`
already calls, on a real headless PLAYGROUND load with `BakeConfig.enabled`
asserted true first (a false there would have measured misses, not
composites). Every call used a distinct `(grid_pos, level, material_name)`
key so the per-cell composite cache never short-circuited one — **0 misses in
the wall and ceiling cohorts, every timed call a genuine composite.** Hook
reverted before commit; `grep -n explosion_bake_spike` comes back empty.

| Run | Total (207 atoms) |
|---|---|
| 1 | 742.3 ms |
| 2 | 731.3 ms |
| 3 | 739.0 ms |
| **Mean** | **~737 ms** (spread 11 ms, 1.5%) |

Per cohort — the three classes use three different compositors, so the whole
table was never projected off one path:

| Cohort | Atoms | Cost | Per atom |
|---|---|---|---|
| **Wall** (`_composite_full/half_voxel_decal`) | 162 | ~680 ms | **~4.2 ms** — the entire cost, effectively |
| **Ceiling** (`_composite_ceiling_carve`) | 36 | ~13 ms | **~0.35 ms** — a silhouette carve with no decal to load; free |
| **Floor** (`_composite_floor_sunk_decal`) | 9 | see note | — |

Steady-state mean 3.50 ms/atom, median 3.28, first call ~15–17 ms (cold decal
load + atlas page creation, paid once).

**Why this is not the old ~95 ms/voxel number, and why that one was never
comparable:** that figure was a *per-cell* bake, partly cold, over 71 296
placed cells. The atom model removes the cell dimension entirely — the whole
map's damage vocabulary is 207 composites, not 71 296. The unit cost barely
moved; the count collapsed by three orders of magnitude. That is the whole
architecture in one number.

**Three caveats, none of them blocking:**

1. **The floor cohort needed 7 305 attempts to land its 9 atoms** — 7 296
   misses, consistently across all three runs. The 9 timed composites are
   real, so the number above stands, but a 0.1% hit rate on the floor path
   deserves a look in **Task 1** when D9 rewires floor specials onto pre-baked
   SLAB atoms: it suggests `resolve_flat()` finds no baked atom for the vast
   majority of floor cells. Flagged, not diagnosed.
2. **Headless, this machine, no GPU present.** Device cost is unmeasured. The
   headroom is large enough that this is a monitoring note, not a risk.
3. **Cost scales linearly with the atom count**, ~3.5 ms each. D13's per-map
   material scope is what keeps that count at 207; a map declaring many more
   materials pays proportionally, and the §3.5 cache is what keeps loads 2+
   from paying at all.

---

**Phase B** (targeting UI, bubble, throw animation, explosion frames, the two
compute windows) is planned separately once Phase A produces evidence — it is
not detailed here beyond §1's sequence, on purpose.

---

## 9. Explicitly out of scope

- **~~Firearm destruction~~ — narrowed 2026-08-06 (D12), then found to
  already be live 2026-08-06 (Task 1b).** The original plan put ALL of
  firearm destruction out of scope, D33 untouched; D12 narrowed that to say
  bullet MARK application would move onto the pre-baked registry, but
  planned it as its own future rewiring checkpoint — the assumption being
  that `WeaponBenchController.fire_active()`'s render path would need code
  changes to start consuming it. **That assumption was wrong, confirmed with
  a real spike (added and reverted the same session, `grep -n
  E-BAKE-VERIFY-SPIKE` comes back empty):** `_process_dirty_slice_voxel()`
  already called `apply_damage_voxel_swap()` unconditionally, first, before
  any live-compositing fallback — pre-existing D-ARCH-01 wiring that was
  never removed, only ever fed an empty registry (`room_builder.gd`'s old
  `TODO (D-ARCH-01 Phase 2)` stub). The instant Task 1b's `bake_all()`
  populates that registry for real, firearm marks start resolving through
  it automatically. Verified on a real fired shotgun blast: 9/9 hits logged
  `apply_damage_voxel_swap HIT key=WALL|concrete|concrete_bullet_dented_*`.
  **No `fire_active()` rewiring checkpoint is needed — it already happened,
  as a side effect of Task 1b, with zero lines of `fire_active()` touched.**
  What stays genuinely out of scope: the rest of D26–D33 (hit detection,
  damage-state transition) — only *how* a mark paints changed, never *when*
  or *whether* a shot damages a voxel.
- **Camera rotation.** Still disabled (ROTATE-KILL-01). The persistence
  contract in §7 is honoured anyway so re-enabling it is not blocked by this
  work.
- **Agent strength / throw-range skills.** Phase B ships a flat range constant;
  the skill term gets one named seam, the way `_agent_skill()` already does for
  firearms.
- **Actor damage from blasts.** Not mentioned in the Director's spec; not
  built.
- **Dynamic bake-cache management** (new 2026-08-06, D13). Storage budget,
  eviction policy, per-player namespacing, and versioning for procedurally
  regenerated/reskinned materials — needed eventually because materials will
  be customized per player and per playthrough (§3.5), but explicitly
  deferred by the Director to *"o fim da fase de destruição"*, its own
  dedicated planning pass. Task 1's cache is a minimal flat store, not this.

---

## 10. Open questions for the Director

Opened 2026-08-05. **Q1–Q6 answered 2026-08-06**, recorded below with the
mechanism each answer implies, plus two follow-up sub-questions (Q1b, Q3b)
that turn "what the Director wants" into "the exact rule the code checks" —
neither blocks Task 0. Q7–Q9 stay open, Phase B only.

### Q1 — ✅ ANSWERED 2026-08-06. Destruction on walls/ceilings uses the same ring model as floor, plus a vertical falloff.

> "Q1: tudo vai ser passível de destruição. Os rings se extendem pelas paredes
> da mesma forma que no chão... a slice imediatamente acima recebe menos dano,
> a que estiver mais pra cima menos ainda... As demais características
> (dented, cracked, fumaça, fuligem) também seguem o mesmo mecanismo do chão,
> ativados em waves."

Recorded as D1 (rev) in §1, weight-table sharing in §4.2. This **reverses**
the 2026-08-05 reading (walls kept their own ring-mult × resistance model) —
the earlier reading was wrong, corrected.

**Follow-up correction, same day:** the first draft of this update
mis-simplified D1 as "walls stop using resistance." The Director corrected
that immediately: *"o tipo de material ainda precisa influenciar na
destruição... Esse mecanismo já existe. O que muda é só a intensidade em que
isso ocorre por slice vertical."* `MaterialResistanceTable` never left — it
multiplies against the (now vertical-aware) ring weight, unchanged in
mechanism, and — new — the floor now consults it against its **real** ground
material too, not a fixed `"earth"` placeholder (D9, D10 in §1). See §4.2's
added paragraph.

#### Q1b — ✅ ANSWERED 2026-08-06. Spherical: one ring step per 8 voxels in every direction.

> "Sim, vamos seguir com o sistema esférico: slabs e slices são afetadas
> seguindo o mesmo sistema de anéis, tanto nos 8 voxels horizontais quanto nos
> 8 verticais. O que muda é o material (resistência). Porém vamos deixar ainda
> a possibilidade de jogar a granada SOBRE o teto, e destruir ele criando um
> BURACO na slab. A física segue o mesmo sistema de destruição do chão, sem
> nenhuma diferença."

Recorded as **D14** (spherical falloff) and **D15** (roof-throw holes) in §1.
The geometry backs the choice rather than merely permitting it:
`VOXELS_PER_UNIT_AXIS = 8` and `LEVELS_PER_STOREY = 8`, so one storey of
height measures exactly one GU of width. A ring step per 8 voxels in every
direction *is* a sphere; it needs no justification beyond the constants.

**Three consequences, verified against the preserved code, not reasoned:**

**1. For walls, this is already the shipped behaviour — §4.3 proposed
something that exists.** `BlastCalculator.apply_container_damage()` already
computes `vertical_ring = floor(level_offset / LEVELS_PER_STOREY)` and
`ring = base_ring + maxi(0, vertical_ring)`. Task 2 inherits it instead of
writing it.

**2. It RETIRES a documented deliberate asymmetry for roofs.** The same
function currently branches on `is_roof` and advances roofs **one ring per raw
level** instead of per storey. Its own comment says why: `ROOF_LEVEL_COUNT` is
2 (`room_builder.gd:289`), so a whole-storey step "would collapse every roof
level into ring 0 and roofs would never show falloff at all" — and it ends
*"Deliberate asymmetry, not an oversight — flagged for review if a real
capture shows it reading wrong."* D14 is that review, and it goes the other
way: under a sphere a 2-level-thick roof genuinely sits at one distance from
the blast, so uniform damage across its two levels is geometrically correct
and the per-level stepping was manufacturing a gradient the geometry does not
support. **Visible consequence: roofs stop showing internal top-vs-bottom
grading.** Task 5's captures are where that gets judged.

**3. `maxi(0, …)` has to become `absi(…)` — and D15 is why.** The clamp exists
because a floor-level grenade has nothing below it to fall off toward. D15 puts
a grenade *on top of a roof*, damaging the room beneath, and under the clamp
every level below the blast would sit at `vertical_ring = 0` — an infinite
downward cylinder, not a sphere. Symmetry is the direct reading of "esférico".

*Assumption stated, open to one-line correction:* Task 2 uses
`vertical_ring = absi(level_offset) / LEVELS_PER_STOREY` for both walls and
slabs. Floor cells keep D2's two-layer rule as the owner of their own vertical
dimension.

#### Q1c — ✅ ANSWERED 2026-08-06. One grenade per slab, with a calibration multiplier.

> "Q1c: sim a destruição permanece a mesma por enquanto, fura a primeira slab,
> e uma segunda granada fura a próxima. Posteriormente podemos querer aumentar
> esse dano em função do gameplay, então deixe um multiplicador atrelado pra
> gente calibrar isso futuramente. Só lembrando que os andares não são
> jogáveis... a destruição de um teto influencia na iluminação, mas não permite
> o jogador entrar por cima."

Recorded as **D17** (one grenade pierces one slab; the next grenade takes the
next slab down; Task 2 exposes a named multiplier for later calibration) and
**D18** (upper storeys are not playable — roof holes are a *lighting* event,
never an access route).

**The framing of the question was wrong, and the answer corrects it.** Q1c was
posed as a tactical trade-off — "can the agent open an entry from above in one
action, and is two grenades too expensive against a 2-gadget loadout?" D18
removes that premise entirely: there is no entry from above to buy. The real
consequence of a roof hole is what it does to the light, which is precisely the
dependency the whole Phase 3 sequencing rests on.

*Residual implementation detail, defaulted rather than re-asked:* "fura a
primeira slab" is read as **both of that slab's ~2 levels going with the one
blast** (it is pierced, not dished), with D2's "a later blast opens deeper"
expressing itself as *the next slab down*, not as the second level of the same
slab. Task 2's selftest asserts this shape; a capture that reads wrong is the
signal to revisit.

#### Q1d — ✅ ANSWERED 2026-08-06. Unify now, not later; naming decided as D20.

D19 settles behaviour completely: durability, damage tiers, soot, effects and
ember are the material's, never the surface's. Task 2 collapses
`MaterialResistanceTable`'s duplicate rows on that basis and D10's gap closes
with them. **None of that is in question.**

What is left open is narrower and purely about assets and names:

1. **`concrete` has two texture sources today** — a procedural grayscale
   facade (walls) and a photographic `full_color` ground page (floors, B2's
   documented exception). D19 says the *material* is one thing; it does not by
   itself say which of the two images a concrete **ceiling pierced from above**
   should show, nor whether the two should eventually converge into one source.
2. **Four of the five `ground_*` materials have no wall counterpart at all**
   (`grass`, `dirt`, `gravel`, `sand`). Under D19 they are simply materials
   that happen to appear only on floors so far — nothing forbids a grass roof.
   The rename drops their prefix too.
3. **The rename touches shipped map data.** `maps/*.map.json` carry
   `ground_concrete`, `ground_dirt`, `ground_grass`, `ground_sand`. Renaming is
   a versioned MAPFILE migration, not a text substitution.

**Answered:** *"vamos considerar fazer essa mudança agora e não depois"* —
the Director chose to do the reform up front, while the roster is still 5–6
materials and *"vai ser muito fácil reformar."* The three points above resolve
as: (1) the two texture pipelines are **real and stay** — a slab uses a
different image projection and a facade a vertical one, and the lighting
genuinely differs because dark floor surfaces made MULTIPLY read badly; only
the *material* unifies, not the textures; (2) earth walls and grass roofs
become legal and damage like anything else; (3) the rename is **D20**, and it
rides Task 1's mapfile change. The hard constraint that came with it is
**D21** — nothing about materials may be hardcoded or map-coupled.

### Q2 — ✅ ANSWERED 2026-08-06. Smoke reaches ring 3, weaker, and rings fire in sequence.

> "Q2: sim, vamos fazer a fumaça chegar no ring 3, mas queremos que a
> intensidade diminua um pouco entre os rings, e cada ring solte sua fumaça na
> ordem, e não todos ao mesmo tempo."

Recorded as D5 in §1. Wave 11 (**Smoke ring 3**) added to the choreography
(§1 step 10, now 15 waves); `smoke_ring_weights[3]` set to `0.1` in §4.2. The
"in order, not simultaneous" half was already the wave list's shape — no
change needed there.

### Q3 — ✅ ANSWERED 2026-08-06. Cracked is one voxel family per material, shared across floor/wall/ceiling.

> "Q3: cracked é um voxel só (x3 variantes de decal) para cada material...
> Esses 3 voxels servem pra chão telhado e teto. Por que? Porque o cracked tem
> que ser baked nas 3 faces do voxel... os demais voxels dented ou marked
> (bullets) são específicos para chão, parede ou teto."

Recorded as D6 in §1, §3.2 rewritten (2 crack materials × 3 decals ×
3 substrates = 18 atoms total, down from the old per-class 81). This resolves
the original Q3 (no cracked art existed for ceiling/floor) differently from
any of the proposed options (a)/(b)/(c) — the Director's answer makes ceiling
and floor crack **the same baked atom as the wall's**, so no new art and no
per-class art was ever needed; the 3 decal variants already planned for wall
cracked now cover all three classes.

#### Q3b — ✅ ANSWERED 2026-08-06. Marked/bullets join the pre-bake, wall-only, no live compositing.

> "Q3b: Sim, eu saí um pouco do escopo aqui. 'Marked' é o mesmo que 'bullets',
> e não aparece nas explosões. Porém queremos incluir o mesmo mecanismo de
> pré-bake dos voxels com marcas de tiros no load, usando 3 decals em 3 voxels
> aleatórios da facade — por material, x2 faces. Sem live bake... Decidimos
> que tiros não acertam teto e nem chão, então não é necessário criar as
> outras versões."

My original guess (excluded, §9's boundary holds) was **wrong** — corrected.
Recorded as D12 in §1 (renumbered past D11 to avoid colliding with this
plan's own pre-existing "D11" choreography reference), §3.2's table grows to
**207** total, §9's out-of-scope note rewritten, §11 adds an explicit
sequencing checkpoint so the `WeaponBenchController.fire_active()` rewiring
doesn't ride in silently on Task 1.

### Q4 — ✅ ANSWERED 2026-08-06. Ceiling DENTED gets 3 irregular alpha-cut shapes, reusable across materials.

> "Q4: o dented DE TETO é só metade de cima do voxel recortada em alpha...
> vamos fazer 3 tipos de recorte irregular, angulados, simulando um voxel com
> a base faltando, como um tijolo quebrado... Esses recortes podem ser
> re-utilizados em outros materiais similares... sem a necessidade de criar
> novas variações."

Recorded as D7 in §1. §3.2's ceiling-dented count moves from 1×3=12 to
3×3×4 materials = 36 (the *art* — the cut-shape alpha masks — is shared across
materials, but each material still bakes its own atom against its own
facade). No longer "nothing to vary" — superseded.

### Q5 — ✅ ANSWERED 2026-08-06. 40 ms/wave confirmed.

> "Q5: Me parece bom! Vamos seguir com 40ms."

§6.2 updated: 15 waves × 40 ms ≈ 600 ms of choreography (was 560 ms/14 waves
before Smoke ring 3).

### Q6 — 🟢 REFINED 2026-08-10 (second reference image, a Phoenix Point capture, attached). Phase B only, does not block Phase A.

The Director attached the XCOM reference and described it: a line simulating
the parabola from the throwing agent to the impact point, and a translucent
3D bubble over the blast-radius area, in isometric perspective — the same
information the existing floor-perimeter wireframe (`open_menu_for()`) already
computes, extended into a 3D projected volume rather than a flat outline. Not
detailed further here since Phase B is not scheduled — recorded so the Phase B
plan doesn't have to re-ask for the image.

**2026-08-10 refinement, from the Phoenix Point capture and the Director's own
words:** *"O HUD vai ser mais simplificado e translúcido, como na referência do
XCOM. A mira só vai usar uma parte dos raios, formando a bolha em volta da GU.
Não vamos exibir a trajetória inteira dos estilhaços antes dela acontecer."*
Three concrete narrowings for the FIRST version (task E-BUBBLE, see
"E-FRAG-01 / E-SHARD-01 (2026-08-10)" near the end of this file):

- **Flat and simple, not a per-voxel projection.** A translucent disc sized
  directly from `BombDef`'s own ring radii (`frag_grenade.json`), positioned at
  the hovered GU — closer to the reference image's flat hex overlay than to a
  true 3D volume. This needs no prediction data at all: the ring radii are
  known the instant a GU is hovered, so **E-BUBBLE has no dependency on
  `PredictionCache`, `build_plan()`, or E-RAY below.**
- **No pre-throw trajectory display.** The shrapnel rays (E-FRAG) and the
  camera shard (E-SHARD) are a DETONATION effect; the aim bubble shown while
  choosing a target must not show them in advance.
- **Explicitly deferred, not scheduled:** *"se a gente conseguir exibir os
  raios saindo de dentro da bola, temos um diferencial visual bem
  interessante. De qualquer maneira, deixamos isso pra depois."* Rays radiating
  from inside the bubble toward the real cells the blast would hit — this
  WOULD need E-RAY, real per-cell prediction data, and therefore the
  hover-driven cache tuning this session flagged but did not schedule (see the
  new section's closing note). Revisit only after the flat disc ships.

### Q7 — Explosion art 🟢 Phase B only

3 frames, fire/energy dispersing in alpha. Director said *"vou fornecer a
arte."* Phase B.

### Q8 — Throw range 🟢 Phase B only

A flat default in GU, until agent strength/skills exist. Note this is
**independent of the blast's 4 rings**: range decides how far the impact GU can
be placed, rings decide what the blast does once it lands.

*Assumed if unanswered:* 6 GU, matching the movement overlay's comfortable
reach.

### Q9 — Is the throw animation a new asset, or the existing sprite on an arc? 🟢 Phase B only

`GrenadeProp` already bakes 8 angles of the Quaternius grenade. Tweening that
existing sprite along a parabola is nearly free; a hand-authored throw
animation is not.

*Assumed if unanswered:* tween the existing prop.

---

## 11. Next session starts here (updated 2026-08-09, post-Alpha-Explosion-Flow)

> ### ✅ 2026-08-09, session close — the prediction dependency is BUILT and Phase B is unblocked.
>
> Everything the block below opened as a dependency has shipped.
> **[`PREDICTION_MASTER_PLAN.md`](PREDICTION_MASTER_PLAN.md) is complete — all
> six tasks.** Concretely, for this plan:
>
> - **Both defects named below are fixed.** The 3-frame collapse is gone
>   (`front_frames`, no wall-clock term survives in the pacing path), and the
>   171 ms block is out of the frame the player clicks on — pre-production starts
>   when the target is picked and the remainder finishes under a burning grenade.
>   Measured on the real map: **zero frozen frames.**
> - **Phase B's hover/throw flow has a real seam to plug into.**
>   `PredictionCache.request(signature, revision, …)` is what the hover should
>   call, and `TestZoneController._begin_preproduction()` is the working
>   reference — the context menu is standing in for the hover that Phase B will
>   build.
> - **The blast-radius bubble is a prediction consumer**, and it should read
>   `delta.census` (§3.4) rather than a full Delta.
> - **One rule Phase B must not break:** any new committed mutation calls
>   `room.bump_world_revision()`, or cached predictions go stale.
>
> **Task 6's remaining tuning surface is unchanged and still lives below.** The
> Director deferred the look pass deliberately at session close —
> *"a gente só vai conseguir fazer o fine tuning da fluidez quando todo o
> mecanismo estiver bem estabelecido"* — so the mechanism landed first.
>
> Full detail: `PROMPTS/RESUMO_SESSAO_2026-08-09_EXPLOSION_FLOW.md`.

<details><summary>The original 2026-08-09 dependency note, kept for the reasoning</summary>


> ### ⚠️ 2026-08-09, later the same day — Task 6 was opened and immediately grew a dependency.
>
> The Director's fine-tuning pass started, and the first two things they
> reported (*"vejo o console carregando os arquivos no momento da explosão…
> a câmera trava e de repente a explosão já está toda construída"*) were
> measured rather than tuned. Both turned out to be structural:
>
> 1. **`build_plan()` blocks for 171 ms, and it appears in NO existing log** —
>    `[E-WAVE]` sets `_t0_ms` *after* `build_plan()` returns, so every
>    detonation performance discussion in this document has been measuring the
>    cheap half. Phase breakdown, mutation inventory and method:
>    `PREDICTION_MASTER_PLAN` §1.1/§2.
> 2. **Every blast is 3 frames.** `cells_due_now()`'s wall-clock deadline means
>    one slow frame makes the next frame's quota the entire queue — measured,
>    2 057 of 2 185 steps on a single frame. **This is why E-RADIAL-01's
>    expanding front does not read as a wave on screen:** the ordering is
>    correct and ships, the front just crosses 2 185 steps in two visible
>    states. Fixing the pacing produces the Director's "ondas na água"
>    with no new feature (`PREDICTION_MASTER_PLAN` §6.2).
>
> The Director's answer to the pre-production question was to build it
> properly, as an engine capability rather than an explosion feature —
> *"vai ser fundamental para outros processos de previsão do game,
> inteligência dos guardas, informações no HUD… queremos um cache e a
> pré-produção profissionais."* That work is now
> **[`PREDICTION_MASTER_PLAN.md`](PREDICTION_MASTER_PLAN.md)**, and Phase B's
> hover/throw flow plugs into its Task 5 seam.
>
> **What that plan corrects in this one:** §2.3 there establishes that
> firearms do **not** share `apply_container_damage()` (D26/D27/D30 moved them
> to `apply_point_impact()`), so the blast mutators can be made pure without
> any risk to shotgun/sniper tuning. `MaterialResistanceTable` remains shared
> and remains untouchable.
>
> **Task 6's remaining tuning surface is unchanged** and still lives below —
> what moved out is the pre-production/cache half, plus the playback fix that
> has to land before any look-tuning is meaningful (tuning a blast you can only
> see in 3 frames is tuning blind).

</details>

**Resume point:** Tasks 0 through 5 are done and committed. The 2026-08-08/09
session (0.9.93, "Alpha Explosion Waves") took the blast from "the waves fire" to
**one organic event**; the 2026-08-09 session (0.9.94, **"Alpha Explosion Flow"**)
made it **flow** — visible pacing, three separated beats, and no frozen frame.
Full records: `PROMPTS/RESUMO_SESSAO_2026-08-09_EXPLOSION_FLOW.md` and
`PROMPTS/RESUMO_SESSAO_2026-08-08_09_EXPLOSION_WAVES.md`; per-topic detail in the
E-DENT-01 / E-CRACK-01 / E-SMOKE-01 / E-FLASH-01..03 / E-ORGANIC-01 /
E-RADIAL-01 / E-NATIVE-01 blocks just above §11's own order of business.

What a detonation is today, end to end:

0. **Pre-production.** The moment the player picks a target, the whole blast is
   computed in 4 ms slices without touching the world (P-COOK). By the time they
   confirm, the Delta is normally already in the cache.
1. **Beat 0 · COOKING.** `Room.spawn_blast_burst()` fires the core — embers,
   sparks and dust from the overlays this project already had, **no imported
   sprite** (E-NATIVE-01) — and the camera shakes. Both are unconditional and
   land on the frame the player clicked. If any computation is left, it finishes
   *here*, under the burning grenade. Usually zero frames.
2. **The commit.** `delta.commit()` is the single writer; persistence, census and
   the world-revision bump follow it.
3. **Beat 1 · FIRE**, alone, for whatever `burst_lead_frames` the cooking did not
   already spend.
4. **Beat 2 · STROBE** — white, negative, white, negative, one held frame each,
   caller-paced, with the fire still burning under it. The negative quad sits
   ABOVE ember/smoke so the fire goes dark with the world (P-DARKFIRE), and the
   inversion is desaturated so it goes neutral rather than blue.
5. **Beat 3 · DESTRUCTION**, clean, with no flash over it.
   `DetonationChoreographer` replays the plan as an **expanding front** paced by
   FRAME COUNT — every entry sorted by its own radius from the epicentre and
   snapped to visible bands, so the wave reads as "ondas na água"
   (E-RADIAL-01, P-PLAY). No wall-clock term survives anywhere in that path.
6. Per-voxel smoke — one puff per damaged voxel, intensity and lifetime from its
   damage tier, its ring, and a per-cell hash.

**Everything above is a `var`, and the fine-tuning pass is the next thing the
Director does** — deliberately deferred at 0.9.94's close (*"a gente só vai
conseguir fazer o fine tuning da fluidez quando todo o mecanismo estiver bem
estabelecido"*), so the mechanism landed first and the look is untouched. The
surface, updated for what this session changed:
`bombs/frag_grenade.json`'s ring weights · `front_frames` / `band_voxels` /
`front_jitter` / `KIND_RADIUS_BIAS` in `detonation_choreographer.gd`
(`sequence_ms` is GONE — P-PLAY deleted the wall-clock pacing) · `blast_burst_*`
in `room.gd` · `burst_lead_frames`, `SHAKE_SECONDS`, `predict_budget_ms` and
`cook_budget_ms` in `test_zone_controller.gd` · the flash overlay's
`strobe_white_alpha` / `strobe_negative_amount` / `strobe_negative_desaturate`
(the `flash_fade_*` fields are GONE — P-STROBE deleted the timed fade) ·
`SmokeSparkOverlay`'s duration and drift defaults · `DetonationPlanBuilder`'s
`SMOKE_*` and `CRATER_*` constants.

**The one open look question is Q6 in `PREDICTION_MASTER_PLAN` §10:** at
`strobe_white_alpha = 1.0` a white strobe frame compresses the whole image into
the top 16% of the brightness range, so the fire that is meant to keep burning
through the strobe is rendered but invisible. One number.

**Use the filmstrip to judge any of this** —
`python3 tools/persistent/build_filmstrip.py` puts every frame of ONE detonation
on one sheet, which is how three of this session's look calls were actually
made.

**Read before re-tuning anything performance-shaped:** the cost of this sequence
is **per frame that writes to a `TileMapLayer`**, not per cell — measured, and it
inverted the obvious answer once already (see the E-ORGANIC-01 block's table).
Tuning against the `apply=` column in the `[E-WAVE]` log will make the blast
slower while every number in the log improves.

Older order-of-business items (Q1b confirmation, Task 0 through Task 5) are
fully closed and folded into §1/§8.1/§8's task rows / the closure notes
above; not repeated here.

**Order of business — formalize the decal-bake step (Director's call,
2026-08-08), BEFORE Task 6:**

## ✅ RESOLVED 2026-08-08 as D34 (E-SEAM-01 `8dd926e`, E-SEAM-02 `22b24be`)

The Director's answer went further than the framing below asked for. Rather
than authoring the missing SLAB assets, **the SLAB/SLICE split itself was
removed for structural materials**: a floor is a roof at the base of the
scene, so wall, roof and floor of one material all bake from the same
grayscale `facade_<id>` under MULTIPLY. `slab_<id>` survives only as the
photographic exception for organic ground (`has_facade == false`).

The Director's own insight is what made it free: fill a 1024×512 facade up to
the isotropic 1024×1024 a horizontal surface addresses **with a vertically
flipped copy, not a stretch**. Mirrored repeat was already the idiom
everywhere else in the compositor; stretching was the odd one out. Both
surfaces gained — the roof kept native pixels AND stopped running out of
addressable domain past row ~36 (latent, hidden only by roof structures being
small), the floor kept full coverage AND recovered its vertical detail.

Point-by-point against the list below: **(1) is moot** — the 3 stopgap
`slab_metal/stone/wood.png` files are no longer loaded by anything; those
materials render from their own facades. **(4) is decided** — reuse is not a
fallback, it is the rule for `has_facade` materials, and a missing SLAB asset
is only a real gap for organic ground. **(2) is still open** (see the
remaining item after this block). **(3) is unchanged.**

Full record: `BAKE_SYSTEM_REFERENCE.md` FLOOR-ZONE-BAKE's new reversal block,
plus B2's widened scope.

**~~Still open: `earth` is not part of the unification yet.~~ CLOSED the same
day as D35 (`87fa023` + the Director's `facade_earth.png`).** Earth is a
buildable material now — walls, blocks and roofs render through the same
grayscale + multiply path as concrete/metal/stone/wood, which is the
"uma parede e um teto de terra" combo the Director described. Real capture:
`Screenshots/history/e_earth_buildable.png`. Three supports had to land with
it: `has_facade` + a derived `base_color` in `materials/earth.json`, a
canonical-atom alias (earth ships as eight variants, has no `voxel_earth.png`),
and a bare `"earth"` entry in `BASE_MATERIALS` for the bake-OFF/shipped path.

**Still scoped out, deliberately: earth as a DECLARED floor zone.** `"earth"`
is simultaneously the material name and the sentinel for "this GU has no
declared floor zone", compared in five places that decide how the whole floor
renders. Only the floor path conflates the two, so buildable earth needed no
sentinel change. A `floor_zones` entry declaring earth now push_warnings and
explains itself instead of vanishing silently.

<details><summary>Original framing, 2026-08-08 (kept for the record)</summary>

Director's framing, verbatim in spirit: floor textures turned out to have a
genuinely different art/render pipeline from wall textures, and that
divergence is what actually produced this session's problems — not a soot
bug specifically. Concrete gaps this session's diagnostic work (the
damage-atom gallery rig, `damage_gallery_debug.gd`) surfaced, none decided
here — for the Director to pick up next session:

1. **Real `slab_<material>.png` assets for metal/stone/wood.** They never
   existed (only `concrete`/`sand`/`dirt`/`grass`/`gravel` had one — the
   ground materials, not the wall-facade-only test materials). This
   session's fix was a stopgap: `facade_<material>.png` converted from
   palette to RGB and resized 1024×512 → 1024×1024 with
   `Image.NEAREST` (matching `bake_compositor.gd`'s own precedent for the
   roof plane), NOT a properly authored SLAB source. It resolves and bakes
   correctly (confirmed: FLOOR DENTED reads BAKED for all 4 materials,
   real capture shows a real crumbled-dent pattern, not the earlier flat
   color/orange artifact) but is visually a stretched wall photo, not real
   ground art. **`ASSETS/*` is gitignored (`.gitignore:48-53`) — these 3
   files exist only on this machine, not in the repo; flag for backup
   before relying on them across sessions.**
2. **The `DamageCompositeCache` GPU-upload-flush contract.**
   `store()` blits into a CPU-side `Image` and defers the actual texture
   upload to `flush_dirty_pages()` (that class's own doc comment) — every
   real call site is SUPPOSED to pair painting with a flush, and two
   independent ones didn't: this session's own diagnostic tool (fixed,
   commit `512fa5c`) and `DetonationChoreographer`, the real production
   path (fixed, commit `31bf069`). Both were silent — no error, no crash,
   just wrong/stale pixels on screen, found only by a real windowed
   capture. Worth deciding whether this needs a structural safeguard (e.g.
   folding the flush into `apply_damage_voxel_swap()` itself so no caller
   can forget it) rather than trusting every future call site to remember,
   since this exact bug class already bit two call sites independently.
3. **WALL and CEILING are confirmed solid** — real capture, both DENTED and
   CRACKED (where `crack_factor > 0`) bake and render correctly for all 4
   materials post-flush-fix. Not part of this formalization; recorded here
   only so the next session doesn't re-litigate them.
4. **The SLICE/SLAB convention itself** — should every declared material
   require both a `facade_<material>.png` AND a `slab_<material>.png`
   authored independently, or should reuse (facade → slab, isotropic
   resize) become a first-class, documented path instead of an ad-hoc
   fix? `BakePolicy`'s own doc comment (`bake_policy.gd:14-16`) already
   treats a missing SLAB asset as an expected, silently-tolerated gap
   ("TextureResolver.resolve() falls back to Tier.NONE") — worth deciding
   if that's still the right default now that floor damage decals depend
   on it existing.

</details>

**Still open from the list above — the GPU-flush safeguard (point 2):**

`DamageCompositeCache.store()` blits into a CPU-side `Image` and defers the
GPU upload to `flush_dirty_pages()`. Two independent call sites forgot to pair
them and both failed silently (no error, no crash, just stale pixels), found
only by real windowed captures: the 2026-08-08 diagnostic rig (`512fa5c`) and
`DetonationChoreographer`, the real production path (`31bf069`). Undecided:
whether to fold the flush into `apply_damage_voxel_swap()` itself so no future
caller can forget, rather than keep trusting every call site. D34 did not
touch this.

## E-DENT-01 / E-CRACK-01 (2026-08-08) — the soot stamp is off, and the floor finally cracks

Two Director calls in one session, both landed and pushed.

**E-DENT-01 (`a681af0`) — "vamos apagar o stamp de fuligem por enquanto."**
`TestZoneController` builds every real detonation with `stamp_soot_enabled =
false`; `build_plan()`'s own default stays `true`, so the calculation layer and
its selftests do not move and the reversal is one boolean
(`INFILTRAITOR_ENABLE_STAMP_SOOT=1` restores it).
`derive_soot_rings()`/`apply_self_soot()` are untouched — a voxel next to a real
hole still scorches. Same commit added the `[E-PLAN] census`: one line per
(surface, material) a blast actually reached, with destroyed/dented/cracked
counts and how many dent/crack tiles came from the pre-bake instead of the D33
live fallback. `[E-WAVE]`'s per-wave counts blend floor/wall/ceiling into one
figure, which is exactly what hid "69 dents on a fixture, zero on PLAYGROUND"
the first time.

That census is what found the real gap: **FLOOR/cracked measured 0 on every
material, on every one of the four test-zone blasts** — `apply_crater_damage()`
had no crack roll at all, so D19's "floors crack like walls" was closed in the
data (one `concrete` row, `crack_factor` 0.1) and never in the code.

**E-CRACK-01 — the Director's answer: build it, "seguindo o modelo da parede",
with the severity ladder "recebe muito → destruído; um pouco menos → dented; o
próximo → cracked, quase quebrando mas ainda resistiu". Hybrid dented+cracked
states explicitly scoped out for now.** Three layers, all of which had to move:

1. `apply_crater_damage()` grew a CRACKED tier —
   `_roll_floor_dent()` became `_roll_floor_surface_damage()`, offering each
   surviving voxel DENTED first and only then CRACKED (apply_container_damage()'s
   own D22 pool order, applied per voxel because a crater is radial). Three
   independent hash salts. The two tiers fall off over different spans (dent dies
   one `rim_span` past the crater, crack a `rim_span` later), so the ladder reads
   spatially as well as per voxel. The bomb's `dent_ring_weights`/
   `crack_ring_weights` now reach the floor, indexed by `crater_ring_for()` —
   floor and wall finally read the same authored tables. Both trailing +
   defaulted (`[]` = dent un-gated, crack off), so every pre-existing caller is
   byte-for-byte unaffected.
2. `floor_damage_material()` needed **nothing** — D34/E-SEAM-02 had already made
   it material-real, so a concrete floor asks for `concrete_blast_cracked_all_N`.
   The stale claim that it "always keys CRACKED off the earth sentinel" is
   corrected in `damage_variant_baker.gd`'s header.
3. `DamageVariantBaker` registers the universal CRACKED-blast atom under
   `"FLOOR"` for any floor material with `crack_factor > 0` — the same
   registration D6 already does for `"CEILING"`, from the same composite, no
   re-compositing and no second atlas slot. §3.2's roster always said CRACKED was
   "universal — floor + wall + ceiling"; only the registration was missing.

**Tuning (Director: "diminuir um pouco a quantidade de voxels destruídos e
tentar colocar mais decals").** Done on the BOMB and the crater radius, NOT on
`MaterialResistanceTable` — that table is shared with firearms through
`apply_container_damage()`, so every row moved there silently retunes shotgun and
sniper damage. `CRATER_CORE_FACTOR` 0.4 → 0.30 (one number: fewer holes, and
since `rim_span = max − core` it widens every mark band without changing the
crater's outer reach); `destroy_ring_weights` `[1.0, 0.35, 0.08, 0]` →
`[0.85, 0.28, 0.06, 0]`; `dent_ring_weights` `[1.0, 0.45, 0, 0]` →
`[1.0, 0.8, 0.25, 0]`; `crack_ring_weights` `[0, 1.0, 0.35, 0]` →
`[0, 1.0, 0.6, 0]`. One material row moved and only one: **wood's `dent_factor`
0.03 → 0.2**, because at 0.03 a wood floor that lost 137 voxels showed 7 dents,
which made D32.6's "wood dents instead of cracking" effectively void.

**One tuning attempt was reverted by a real capture, not by review.** Setting
`crack_ring_weights[0]` 0.0 → 0.45 (cracks inside the crater, to raise decal
density where the eye goes) produced isolated bright full-voxel cubes standing in
the hole: CRACKED is a 3-face composite while DENTED is a half-voxel carve, so a
cracked floor voxel whose neighbours were destroyed renders as a complete block
where every other floor tile renders as a flat top face. `e_crack_ring0_artifact.png`
is that frame. **§4.2's "cracked never in ring 0" is therefore load-bearing, not
cosmetic** — reverted to 0.0, and `blast_calculator_selftest.gd` now asserts it.

Real PLAYGROUND, all four test-zone grenades, before (2026-08-08 baseline) → after:

| surface/material | destroyed | dented | cracked | decals |
|---|---|---|---|---|
| FLOOR/concrete gu(3,5) | 268 → **239** | 69 → 69 | 0 → **67** | 69 → **136** |
| WALL/concrete | 26 → **16** | 8 → 28 | 24 → 36 | 32 → **64** |
| FLOOR/metal | 154 → **143** | 76 → 77 | 0 (D32.6) | 76 → **77** |
| WALL/metal | 2 → 2 | 20 → 60 | 0 (D32.6) | 20 → **60** |
| FLOOR/stone | 160 → **143** | 42 → 40 | 0 → **20** | 42 → **60** |
| WALL/stone | 12 → 12 | 12 → 32 | 20 → 28 | 32 → **60** |
| FLOOR/wood | 155 → **137** | 8 → 43 | 0 (D32.6) | 8 → **43** |
| WALL/wood | 50 → **38** | 2 → 32 | 0 (D32.6) | 2 → **32** |

Destruction down on every surface, decals up on every surface, **every single
dent/crack tile resolved from a pre-baked atom — 0 live-composite fallbacks**.
Captures: `e_crack_floor_concrete.png`, `e_crack_floor_metal.png`,
`e_crack_floor_stone.png`, `e_crack_floor_wood.png`.

**Known and NOT fixed — the crack decal barely survives the downsample.** The
art (`decal_crack_<material>_0..2.png`) is a real 256×256 fracture network of
thin dark lines; projected onto a floor voxel's top face it averages out to a
faint tonal patch rather than a visible crack. The same reads on walls: a
pre/post pixel diff of the stone block measured only 8363 changed pixels at mean
delta 24.8/255 (the floor's holes: 39.7, peak 248). This is an ART problem at
voxel scale, not a wiring one — the pipeline demonstrably delivers the right atom
to the right cell. Flagged for the Director, not guessed at.

## E-SMOKE-01 (2026-08-08) — 20 ms waves, and smoke from every damaged voxel

Two more Director calls, same session.

**Cadence: 40 ms → 20 ms.** Q5 confirmed 40 ms on 2026-08-06, before any of it
had been watched running; the Director halved it after real detonations. 15
waves now complete in **256 ms** (measured, `[E-WAVE]` log) instead of 565 ms.
Note for whoever tunes it next: at 20 ms the interval is already *below* one
frame at 60 fps, so the sequence is effectively frame-paced (~15 frames) and
lowering the number further will not shorten it.

**Smoke: one puff per flooded GU → one puff per damaged voxel.** Director:
"fumaça tem muito pouca, praticamente todo voxel afetado pode soltar um
pouquinho de fumaça, com intensidades diferentes e durações diferentes."
Measured, stone blast: **22 puffs → 465**, one for every voxel in the census
(464 damaged + 1 GU remainder). Three terms multiply into each puff, no `randf()`
anywhere in the plan:

- the damage tier's own intensity (`DESTROY 1.0 / DENT 0.6 / CRACK 0.35`) — the
  smoke draws a picture of the damage instead of a uniform fog;
- `smoke_ring_weights[ring]`, the table the GU-level path already read;
- a deterministic per-cell FNV-1a hash, with **separate salts for size and
  duration** so a big puff is not systematically also a long one.

The old per-GU puff survives as a *remainder* pass, filling only GUs the flood
reached but left undamaged. That is not tidiness: ring 3 damages nothing by
construction (§4.1), so without it ring 3 would have lost the weak smoke D5/Q2
deliberately gave it.

Cost is not the issue anyone expected: applying 298 puffs measured **0.579 ms**.
The real ceiling is draw-time — ~465 `draw_circle` calls per frame while the
puffs live (~1 s). Fine on desktop; **unmeasured on a real device, and this is a
mobile-first game** — flagged, not assumed.

**Two visual iterations, both driven by a real capture rather than review:**

1. First pass measured as *invisible* — the mid-sequence frame differed from the
   post-smoke frame on 1.1% of pixels at mean delta 12/255. Cause: dark grey
   (0.35) puffs drawn over an already-sooted crater, at a radius smaller than the
   voxel venting them. Fixed with an ash colour and `SMOKE_SCALE_BASE`.
2. Second pass overshot into **hard-edged discs** — `SmokeSparkOverlay` draws
   flat `draw_circle`s, so 274 opaque puffs read as a heap of bubbles
   (`e_smoke_hard_discs_rejected.png`). **Per-voxel smoke inverts the economics
   the one-puff-per-GU model was tuned for: density now comes from OVERLAP**, so
   alpha dropped 0.8 → 0.2 and `SMOKE_JITTER` rose to 0.7. Final: 2.57% of the
   frame at mean delta 19.1. Recorded because the wrong lever is obvious and
   wrong — turning the alpha back up is how this regresses.

Captures: `e_smoke_per_voxel_stone.png`, `e_smoke_per_voxel_metal.png`.
`INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES` (new, defaults to the historical 45)
lands a capture mid-sequence — **every detonation capture ever taken before this
showed the damage with the VFX already dead**, which is why no earlier session
could make a visual claim about smoke at all.

## E-FLASH-01 (2026-08-08) — the detonation finally has a detonation

Director, same session, five asks. All landed.

**1. Cadence, again: "no máximo 1 frame por wave."** Read as a CEILING on how
long a wave may wait, which is what it says. The implementation went through a
wrong version first and the wrong version is the interesting part: a pure
one-wave-per-`process_frame` loop satisfies the ceiling and **hands the
sequence's duration to the frame rate** — measured at 1111 ms in the off-screen
capture process (~9 fps there), i.e. *slower* than the 20 ms timers it replaced.
The shipped rule is both halves at once, extracted into a pure static
`waves_due_now()` so it is testable without controlling frame timing:

- at least one wave per frame (the ceiling — no wave waits two frames);
- **plus** every wave whose absolute deadline has already passed (the floor — a
  late frame catches up instead of pushing the rest back).

Same run after the fix: **254 ms**, at the same ~9 fps. This also restores what
§6.2's original absolute-time scheduling was protecting ("a slow wave never
delays the next"), which the frame-chained version had silently given up.

**2. Smoke: longer and higher.** `smoke_duration_min/max` 0.6/1.0 s → 1.0/1.8 s,
`smoke_drift_y` 18-32 → 34-58 px/s. The third number is the one that mattered:
`smoke_drift_damping` 0.4 → 0.62. At 0.4 a puff lost ~60% of its rise inside the
first second, so lifting the launch velocity alone would have bought almost
nothing. These are the overlay's own defaults, so VFX-01's per-voxel destruction
puffs and EmberOverlay's burn-out puffs move with them — which is what "geral"
asks for.

**3-4. The fireball and the white flash frame** — new `ExplosionFlashOverlay`.
Plays `ASSETS/ANIMATIONS/Explosion_1/Export/1..4.png` at the grenade's own
top-centre ("anchor point em cima da granada"), then the white frame follows its
last frame and tweens its opacity down while the destruction waves fire
underneath. Two implementation notes worth keeping:

- **The frames are `load()`ed at play time, never `preload()`ed.** `ASSETS/*` is
  gitignored (.gitignore:48), so a preload would turn a missing local asset into
  a whole-project COMPILE error on a fresh clone. A missing frame now
  `push_error`s and skips to the flash — the detonation still runs (B6).
- **The white wash is drawn in world space, not as a CanvasLayer + ColorRect.**
  room.tscn's two CanvasLayers (VisionFogOverlay, HUD) are both layer 0 and
  ordered by tree position, so a runtime-added layer lands *above* the HUD and
  whites out the dev overlays too. Filling the camera's own visible rect (from
  the canvas transform, so pan/zoom come free) keeps the wash on the world.

**5. Camera shake**, on `Camera2D.offset` — never `position`, which is the
leashed, drag- and focus-owned value a shake would fight. 0.55 s, 12 px peak,
quadratic decay, always ending at exactly `Vector2.ZERO`; `stop_shake()` is
called on map load and perspective change so no path can leave the camera
displaced. **Deliberately NOT `randf()`-seeded**: this project verifies visual
work by pixel-diffing two captures of the same event (the soot A/B, the
crack-artifact diff), and a randomised camera offset would put noise into every
such comparison forever, for variety nobody can perceive between blasts.

Sequence captures: `e_flash_fireball.png` (frame 4 at the anchor),
`e_flash_white_frame.png` (the wash, crater already forming under it),
`e_flash_smoke_rise.png` (smoke climbing off the crater).

### E-FLASH-02 (2026-08-09) — the Director's polish pass on the above

Five adjustments after watching it run. Four were tuning; one was a real,
measured bug the Director spotted by feel.

1. **Fireball 2×** (`sprite_scale` 1.0 → 2.0). At native 283 px it barely
   covered one GU next to a crater spanning two.
2. **Additive blend on the fireball** — "queremos deixar passar um pouco do
   fundo". `CanvasItemMaterial.blend_mode` is per-node, so the fire moved to its
   own child node (`_fire_layer`, `z_index = -1`) while the WHITE FLASH stayed on
   the parent at normal blend: a flash frame's job is to replace what is under
   it, so making that additive would be the opposite of the ask. Under ADD the
   art's dark halo drops out entirely and the floor grid reads through the ball
   (`e_flash_fireball_blend.png`).
3. **"O primeiro flash frame me pareceu que demorou um pouco... talvez precise de
   um pré-load" — the Director was right, and it was measurable: 44.94 ms** of
   PNG decode was happening inside the first detonation's own frame, ~3 frames at
   60 fps, once per session. Moved to `_ready()`. Still `load()`, never
   `preload()` — the gitignore reasoning in E-FLASH-01 is unchanged; only *when*
   moved.
4. **Camera shake starts with the fireball**, not with the flash — the ground
   moves as the charge goes off, not a beat later when the light reaches it.
   Lengthened 0.55 → 0.7 s to cover the animation's own ~8 frames as well.
5. **Smoke lingers and climbs**: duration 1.0-1.8 → 1.8-3.2 s, rise 34-58 →
   48-82 px/s, damping 0.62 → 0.78. Plus a real fix behind the ask —
   `SMOKE_DURATION_FLOOR`. Lifetime used to scale on `strength` exactly like size
   and alpha, so an outer cracked voxel's puff (strength ~0.07) lasted ~0.1 s and
   the *thinning outer edge* — precisely "o final" of the smoke — vanished first.
   Size and alpha still scale all the way down; only lifetime gets the floor.

Measured, blast on the stone patch, against a frame with the smoke fully gone:
centroid rises **y 362.7 → 349.4 → 337.7** across the window, and the cloud still
covers **2.11%** of the frame at 75 frames post-detonation
(`e_flash_smoke_lingers.png`). Honest caveat on those first two numbers: the
shake is still running at that point and displaces the whole frame, so the w18/w40
pixel counts include a little geometry shift — the w75 figure is the clean one.

`detonation_plan_selftest`'s envelope assertion had to split in two as a result:
ring weight still bounds a puff's SIZE, but no longer its LIFETIME, and asserting
the old single bound would have been asserting a rule the code deliberately
stopped following.

### E-FLASH-03 (2026-08-09) — in-between frames, and the real cause of the "engasgada"

**The stutter is real, measured, and is neither thing the Director suspected.**
They reported "me parece também que dá uma engasgada no último frame" and offered
two hypotheses: the white being slow to enter, or persistence of vision from an
all-white next frame. Per-frame instrumentation across a real detonation:

```
[ANIM-DIAG] dt=16.7ms  frame=3          ← the animation itself runs clean
[E-WAVE]    wave 1/15 destroy ring=0 cells=872 apply=15.951ms
[ANIM-DIAG] dt=150.0ms flash_t=0.017    ← the frame the flash starts on
[ANIM-DIAG] dt=119.8ms flash_t=0.167
```

The frame the flash appears on is the same frame `DetonationChoreographer`
applies destroy ring 0 — 244 `erase_cell`s plus 628 exposure `set_cell`s — and it
costs **150 ms** where every animation frame around it costs 8-17 ms. Only ~16 ms
of that is the wave's own apply; the rest is `TileMapLayer` rebuilding after 872
cell writes. The white was not slow: the frame was.

**Fixed here (the compounding half):** the flash advanced its fade by that same
150 ms delta, burning half its curve in one step, so the white appeared *already
half gone* — which is exactly what "demora pra entrar" looks like from the
outside. `flash_max_step_seconds` (0.034) caps the step the FADE sees. Re-measured
on the identical blast: the 149 ms frame now takes the flash to t=0.051 instead of
t=0.167, and the flash spans **18 frames instead of 5**.

**NOT fixed, and needs a Director call:** the 150 ms frame itself. The obvious
targeted fix is splitting the 628 exposure reveals out of destroy ring 0 into
their own wave, roughly halving the worst frame's cell churn — but that changes
§1's ratified 15-wave table and is a performance change, not an animation one, so
it is not being done on an animation ask. **Open question for the Director.**

**In-between frames (the Director's own suggestion B), shipped.** Playback moved
from an integer frame index to continuous TIME, and every drawn instant
cross-fades the two authored frames it falls between. Done at draw time rather
than by baking textures — no extra memory, no extra load cost, and the result is
continuous rather than one fixed in-between per pair. `frame_hold_fraction`
(0.35) keeps each authored pose readable for part of its slot instead of the
whole animation being one long mush. Under the additive blend the two
contributions sum, so brightness stays roughly constant through a blend instead
of dipping. `animation_seconds` 0.22 replaces `frames_per_animation_frame`.
Capture: `e_flash_interp_midframe.png`.

**Negative flash (the Director's suggestion A), available and switchable.** They
flagged it as maybe hard at runtime and maybe slower; it is neither — a six-line
`canvas_item` shader reading `hint_screen_texture` and mixing toward
`1.0 - src` by a tweened `amount`, on its own child node (the white flash is a
plain `draw_rect` and needs no material). One screen copy, no measurable delay.
`INFILTRAITOR_NEGATIVE_FLASH=1` selects it for a capture;
`flash_mode` defaults to WHITE and **this session does not pick between them** —
which reads better is a look decision.

Honest note from the capture (`e_flash_negative_mode.png`): the inversion reads
*dramatically* on high-contrast geometry (the dark stone wall goes white) and
*weakly* across the mid-grey concrete floor, because inverting mid-grey returns
mid-grey. On this particular map that makes it subtler overall than the white
flash, which may or may not be what the Director wants.

### E-ORGANIC-01 (2026-08-09) — the wave table stops being a unit of time

Director: "não precisamos fixar as 15 waves, queremos que seja o mais orgânico e
natural possível... ainda sinto umas engasgadas."

`WAVE_TABLE` still defines the ORDER — that ordering is the blast's dramatic
shape. What is gone is the idea that a wave is a unit of TIME. A wave was
whatever cells fell in one (kind, ring) bucket, and buckets are wildly uneven:
destroy ring 0 on a real PLAYGROUND blast is 872 cells (244 erases + 628
exposure reveals) while destroy ring 2 is 4. Giving each bucket a frame therefore
guaranteed one catastrophic frame, which is the "engasgada" that survived three
rounds of tuning. The plan now flattens into one ordered queue of single-cell
steps — with each exposure reveal broken out as its own step instead of riding
inside the destroy entry that carries 628 of them — drained against a deadline.

**The measurement that inverted the obvious answer.** The first attempt was a
flat per-frame cell budget. It made every frame look cheap in the log and made
the blast three to twenty times slower in wall clock. Same blast each time,
2072 steps, varying only the budget:

| budget | total | apply per frame |
|---|---|---|
| all 2072 in one frame | **26 ms** | 24.3 ms |
| 600 cells/frame | 509 ms | ~4.4 ms |
| 160 cells/frame | 496 ms | ~2.2 ms |
| 60 cells/frame | 485 ms | ~0.9 ms |

**A frame costs ~120 ms whether it writes 60 cells or 600.** The cost is Godot
rebuilding the dirtied `TileMapLayer`s, paid once per frame, not once per cell —
so "spread the work thinner" is exactly the wrong instinct, and the apply column
is exactly the wrong number to tune against. Recorded in the choreographer's own
header so the next person does not repeat it.

Shipped instead: a **deadline with catch-up at cell granularity** — the same
ceiling/floor shape the per-wave scheduler used, one level down. `sequence_ms`
(240) is what the blast should take; each frame advances to wherever that
deadline says it should be, with a `min_cells_per_frame` floor so a fast machine
still subdivides. On a healthy frame budget the blast becomes a dozen fine steps
and reads as propagation; when frames are expensive the quota drags it forward
rather than letting it stretch. Measured after: **261 ms**, versus 254 ms for the
old fixed schedule and 485-509 ms for the naive budget — organic pacing at no
wall-clock cost, and the 872-cell spike structurally gone.

**Caveat, stated because it matters for anyone re-tuning this:** every number
above comes from the off-screen capture harness, which renders the blast at
~8 fps. The ~120 ms per-frame constant is certainly much smaller on a real
windowed run. **The SHAPE of the finding (per-frame, not per-cell) is what to
trust; the constant is not.** The harness also cannot demonstrate the smooth
case — at ~8 fps the quota jumps straight to 100% on the second frame, so the
dozen-fine-steps behaviour is reasoned from the rule, not captured.

**Still open — the explosion's ART.** The Director: "essa animação autorada
também me causa um pouco de estranheza porque o gráfico tem um estilo cômico que
não combina com o resto do cenário. O Godot não tem algum efeito nativo mais
integrado pra simular explosões?" Answered in the session response, not built —
a new explosion look is a design decision (Process rule 1). Short version: yes,
`GPUParticles2D`/`CPUParticles2D` + `ParticleProcessMaterial` is the native
route, and more to the point this project already owns the vocabulary
(`EmberOverlay`, `SmokeSparkOverlay`, `DebrisOverlay`, `PointLight2D`) to build a
blast out of the same materials as everything else on screen instead of a foreign
sprite sheet. Awaiting the Director's call.

### E-RADIAL-01 / E-NATIVE-01 (2026-08-09) — an expanding front, and no imported art

Three Director calls, all landed.

**1. The waves were "duras... em soquinhos por categoria" — and that was
structural, not a pacing problem.** WAVE_TABLE order means every destruction
everywhere lands, then every dent everywhere, then every crack, then every soot:
four blocks by category, and no amount of pacing could hide it because the ORDER
itself was categorical. The Director asked for the opposite — "granularizadas por
voxels... realmente vão se expandindo a partir do centro, cada efeito surgindo no
seu tempo individual e terminando no círculo mais largo."

Every plan entry now carries its own **radius from the epicentre** (added in
`DetonationPlanBuilder`, which is the pass that already knows it), and the queue
is sorted by that radius instead of by category. The categories then interleave
on their own — destruction near the centre, dents further out, cracks and soot at
the rim — because that is physically where each one *is*. Measured on a real
PLAYGROUND plan: **171 category switches across the queue, against ~15 under the
old ordering.** The selftest asserts that number stays high, so the ordering
cannot silently revert.

Two refinements keep it from reading as machinery: `KIND_RADIUS_BIAS` gives each
effect a sub-voxel offset so a hole still leads its own scorch at the same
radius, and `front_jitter` (±0.9 voxel, deterministic FNV-1a per cell) keeps the
front ragged instead of a perfect expanding ring.

**2. The authored fireball is gone** (Director: "tirar as animações autoradas por
enquanto"). Three rounds of tuning an imported sprite — 2× scale, additive blend,
continuous frame interpolation — never fixed what was actually wrong with it,
which was a style mismatch. `ExplosionFlashOverlay` is now just the flash.

**3. The blast's core is built from this game's own vocabulary** —
`Room.spawn_blast_burst()` calls `EmberOverlay.add_ember()`,
`SmokeSparkOverlay.add_sparks()` and `DebrisOverlay.add_dust()`. No new
machinery: four calls to overlays that already existed, which is precisely why it
integrates — it is made of the same material as every other effect on screen.
**Deliberately NOT a particle system:** `GPUParticles2D` is the native route for
something this project did *not* already have, and adding one here would stand up
a second parallel VFX vocabulary beside one that already reads correctly.

**4. The negative flash is now the shipped look** (`INFILTRAITOR_WHITE_FLASH=1`
restores the old one). This surfaced a real ordering bug the moment it shipped:
the flash sat ABOVE ember/smoke, which was right for a white wash meant to cover
everything — but a negative flash INVERTS what is under it, so the blast's own
warm embers came out **blue** (seen directly in the first capture). The flash
moved below ember/smoke: the world is what gets blown out, the fire is the thing
doing the blowing out and must not inverted along with it.

Captures: `e_native_flash_core.png` (inversion at peak with the hot core over
it), `e_native_burst.png`, `e_native_smoke_core.png`.

**Order of business — Task 6, the tuning pass (§8's own row):**

1. ~~Get the Director a real capture and let them move §4.2's ring-weight
   numbers.~~ **Done 2026-08-08 as E-CRACK-01's tuning pass, above** — the
   numbers moved once, on real censuses, and every one of them is still a
   placeholder open to another pass. `soot_ring_tones` was NOT touched (the soot
   stamp is off entirely for now, E-DENT-01); `smoke_ring_weights` is unchanged
   in value but now scales hundreds of per-voxel puffs instead of a handful of
   per-GU ones (E-SMOKE-01), so the same numbers mean something different.
2. **The "quebradiça" (brittle/fragmented) soot texture** — **REVERSED,
   2026-08-08.** The Post-Task-5 A/B test below was run against a genuine
   bug (GPU-UPLOAD-01, same session's own damage-atom gallery rig found it
   first): `DamageCompositeCache.store()` defers the GPU texture upload to
   `flush_dirty_pages()`, and `DetonationChoreographer` — the only place a
   `DetonationPlan` ever reaches `set_cell()` — never called it, so both
   `soot_stamp_on.png` and `soot_stamp_off.png` were comparing stale/unflushed
   texture content, not the real difference. Fixed
   (`voxel_renderer.flush_damage_composite_pages()`, once per wave). Same
   A/B test, re-run clean on the identical stone crater: stamp ON vs OFF now
   differ on 4.1% of the frame at mean 101.6/255 (was 3.3% at 0.76/255) —
   **the blast's own soot stamp IS the cause.** With the stamp off, ring 3
   (soot-only — `destroy/dent/crack_ring_weights[3]` are all `0.0`, so it
   can carry no dent-decal-art or D3 substrate-crop variation at all) reads
   as a smooth, even darkening; with it on, the same tiles show the
   checkerboard/pockmark pattern. `stamp_crater_soot()`'s own ring math is a
   plain Euclidean-distance band with no per-voxel hashing — exactly how a
   uniform per-ring tone becomes a checkered pixel result is not yet traced
   (candidate: the soot tone's interaction with the light-bucket
   alternative-tile encoding, or with the base texture under strong
   multiply-darkening). Options 1-3 below (dent-decal art, D3 randomization)
   are very likely NOT where to spend tuning time now; option 4 (the
   shader's multiply-vs-flatter-blend question) or the stamp's own rendering
   path is where the real lever probably is. Original (now superseded)
   options, kept for the record: tighten crater-rim dent density (a
   `dent_factor`/rim-span data tweak), replace the dent decal art (art
   work, not code), disable D3's per-voxel substrate randomization (reverses
   a ratified decision — ask first), or change `voxel_face_shading.gdshader`
   from a pure multiply to a flatter blend toward a solid soot tone (a real
   shader-philosophy change — the shader's own header comment currently
   states multiply-only is deliberate).
3. Two items Task 5 flagged and deliberately did NOT resolve, both real
   design questions for the Director rather than something to guess past a
   second time:
   - **Blast debris VFX** — dust/spark/chip puffs (VFX-01) no longer fire
     for blast-caused destruction (only for firearms). Reinstating them
     needs material threaded onto the `DetonationPlan`'s destroy entries
     (§6.1's shape is `{cell, level}` only today) — a real, if small,
     schema change, not a quick patch. Ask before building it.
   - **§6.3's deferred-soot-compute question (D8)** — run the soot
     light-query on a background thread, or synchronously after wave 1
     dispatches. Task 4/5 never needed it: `build_plan()`'s own measured
     cost is small enough (the biggest real wave in this session's capture
     applied in ~8.9 ms) that the whole plan resolves well within one
     frame today. Revisit only if a much bigger real blast (more affected
     containers, not more rings) is measured to actually need the slack.
4. D18 still stands: roof holes are a lighting event, never a player access
   route — nothing building on Task 5 should treat one as an entry point.
5. Camera rotation is still disabled (ROTATE-KILL-01, §9). The stamped-blast
   soot's own rotation-persistence (an *event* replay list feeding
   `stamp_container_soot()`/`stamp_crater_soot()` again on rotation, per
   Task 3's own closure note) was never built — this is currently
   unreachable to even test with rotation off, so it stays deliberately
   unbuilt rather than guessed at. Build it when rotation comes back, not
   before — `_base_damage`'s DAMAGE STATE (not soot) already survives
   rotation correctly today via the ordinary `record_voxel_damage_to_base()`
   path Task 5 wired in.

**Do not:**
- start Phase B (targeting UI, bubble, throw, explosion frames) — the Director
  chose Phase A first, deliberately, so the 15 waves are verifiable with real
  captures before they get wrapped in animation. Q6's bubble description and
  XCOM reference (2026-08-06) are recorded in §10 for when Phase B starts —
  Phase A being functionally complete (Task 5) is still not that signal;
- re-enable camera rotation as part of Task 6 (§9) — see point 4 above;
- treat the 207/273-atom counts in §3.2/Task 1b as open numbers — both are
  settled and measured (D16 adds routing, not atoms; Task 0 measured ~737 ms,
  Task 1b measured the real 273-atom bake at ~1.5 s cold / ~31 ms warm);
- revisit the per-voxel/per-face soot granularity question — it is
  **closed**: full per-face directionality stays everywhere
  (`FACE_SOOT_CODE_COUNT`, `encode_face_soot()`, the shader), confirmed
  directly with the Director this session (Task 3's closure note);
- reproduce `_process_dirty_slab_voxel()`'s full zoned-floor branching
  inside `DetonationPlanBuilder._resolve_damaged_tile()`'s live-fallback
  path without a real failing case driving it — Task 4 flagged this as an
  honest, unexercised gap (0 misses measured on real PLAYGROUND material),
  not a silent assumption; fix it when a real material actually misses the
  bake, not preemptively;
- assume a `RefCounted` (non-Node) object with only a signal-connection
  reference stays alive across a real-time sequence — Task 5's own real
  bug: `DetonationChoreographer` needs an explicit owner
  (`TestZoneController._active_choreographer`), a bound `Callable` on a
  `SceneTreeTimer` connection was measured NOT sufficient on its own.

---

## E-FRAG-01 / E-SHARD-01 (2026-08-10) — the strobe becomes a shard, and the blast gets real debris

**Where this started:** `PREDICTION_MASTER_PLAN` §10 Q6, left open at last
session's close — *"how white should the white strobe frames be?"* §8.3 had
measured that at `strobe_white_alpha = 1.0` a white frame puts the whole image
in the top 16% of the brightness range, so the fire the Director wanted
burning through the strobe (*"o fogo permanece acontecendo durante os 4 frames
do flash"*) is rendered but invisible. This session answered it by deleting
the white frame rather than tuning its alpha, on the Director's own
reasoning: *"Não vamos mais ter aquele flash todo branco, inclusive por
questões de epilepsia."* Two reference stills of grenade/fragmentation VFX
were attached alongside the instruction — dark, angular, hard-silhouetted
debris against a bright core, not the round embers `ember_overlay.gd` already
draws — and a third, a Phoenix Point capture, for Q6's aim-bubble refinement
(folded into §10 above).

**The other three asks in the same message, restated exactly** because each
maps to a different existing system and none of them needed a new mechanic
invented — only a beat moved or a var animated:

> *"Isso resolve o problema do frame branco cobrir o fogo: um dos estilhaços de
> ferro pretos voam exatamente em direção à câmera (1 frame saindo da
> granada), vai ficando cinza no caminho (2 frames), termina no frame negativo
> cobrindo a tela toda (que já está pronto com o fogo escuro) e tween down
> rápido."* — confirmed as **no repetition**: one negative peak, opacity down
> over 3 frames, back to normal.
>
> *"A fuligem de todo o conjunto pode começar a ser pintada depois que a
> fumaça estiver no final, e terminar de aparecer no seu tempo, com um alpha
> suave, em vez de aparecer com 100% de uma vez."*
>
> *"A iluminação nova, por sobre toda a cena que foi esculpida, pode ser
> calculada e refeita depois que a fumaça tiver sido disparada."*

### The insight that reshaped the shrapnel task

The Director noticed `light_ray_overlay.gd` (golden shafts, one lamp to every
lit tile's centre, pre-computed arrays, one cheap `_draw()`) is geometrically
the same shape the shrapnel needs — an origin, many real destinations, drawn
as lines. Verified by reading the class: yes, and the reusable part is the
*pattern* (packed `_ray_froms`/`_ray_tos`/`_ray_alphas`, built once, redrawn
via `queue_redraw()`), not the class itself — the light rays are static
between `lighting_rebuilt` events and blend `MIX` gold; the shrapnel has to
animate (travel/grow, then fade) and blend dark over the fire. **Corrected
once, by the Director, before it got written into a task:** it is NOT one ray
per affected voxel the way light rays cover every lit tile — *"não precisamos
ter tantos estilhaços quanto raios de luz (que afetam absolutamente todo o
cenário). A granada na vida real tem um número X de gomos que são
disparados."* A real grenade fragments into a bounded number of pieces; the
decorative overlay samples a small fixed count from the plan's real
destroy/dented/cracked cells rather than drawing one per cell.

**The debug consumer is the opposite: deliberately NOT capped.** *"Não
precisamos alterar o comportamento da destruição dos voxels, o efeito visual é
só decorativo. Porém, queremos detectar a posição dos voxels especiais para
fins de debug."* E-FRAG stays purely cosmetic (no Voxel writes, same contract
as `ember_overlay.gd`/`smoke_spark_overlay.gd`); E-DEBUG-RAY exists precisely
to show every one, unbounded, because it is the tool this project's own
evidence discipline calls for — CLAUDE.md already records a feature that
passed its selftest with 69 synthetic dents and produced zero on the real
map, discovered only because someone eventually needed to see WHERE the
affected voxels actually were.

### Tasks, in order

| # | Tag | Deliverable | Depends on |
|---|---|---|---|
| 1 | **E-RAY** | Generic animated ray/streak overlay: `Node2D`, precomputed origin→destination(s) arrays (`light_ray_overlay.gd`'s pattern), but each entry carries its own travel/fade lifetime instead of being static. Sibling class, not a subclass — blend mode, colour and animation all differ from `LightRayOverlay`. | — |
| 2 | **E-DEBUG-RAY** | Dev-only consumer of E-RAY: one ray to every `dented`/`cracked` voxel a real blast plan touched, unbounded, env-var gated (same precedent as `INFILTRAITOR_ENABLE_STAMP_SOOT`). Ships FIRST after E-RAY because it is the lowest-risk consumer and gives every later task a real tool to verify against. | E-RAY |
| 3 | **E-FRAG** | Decorative shrapnel: a small `var frag_count` (tunable, "gomos" order of magnitude, not per-voxel) sampled from the plan's real destroy/dented/cracked cells — so directions stay coherent with where the blast actually lands without scaling with the census. Dark iron colour, alpha over the fire, lifetime in real TIME (`_process(delta)`, `ember_overlay.gd`'s convention) since nothing waits on it. Fires at the exact point `sprite.visible = false` already sets in `detonate_active()` (`test_zone_controller.gd:269`). *"Eles voam e somem, enquanto o fogo vai aparecendo por trás"* — E-FRAG draws above the fire and finishes before it does; no timing coupling needed beyond both starting at the same beat. | E-RAY |
| 4 | **E-SHARD** | The camera-facing shard, separate from E-FRAG's set. 1 frame leaving the grenade (small, black) → 2 frames growing and desaturating toward grey → on the frame it fills the screen, call `hold_frame(NEGATIVE)` — **no new shader**: `strobe_negative_amount` is already a `var` (`explosion_flash_overlay.gd:67`), just never animated per-frame before. 3 more held frames step it `1.0 → 0.0`, then `clear()`. This REPLACES `STROBE_SEQUENCE` (`test_zone_controller.gd:100`) entirely — `FlashMode.WHITE` is never invoked by the live sequence again (the env-var escape hatch `INFILTRAITOR_WHITE_FLASH=1` can stay, as a comparison tool, not a shipped path). | E-FRAG (shares its geometry/timing base) |
| 5 | **E-FUME** | Soot leaves `WAVE_TABLE`'s radially-interleaved ordering and becomes its own late step in `DetonationChoreographer`'s queue, firing once the smoke puffs are mostly spent rather than riding the front. Alpha ramps in over N frames instead of the tile's baked alt appearing at full opacity the instant `set_cell()` runs. | none of the above — pure reordering in `detonation_choreographer.gd` |
| 6 | **E-BUBBLE** | Phase B aim-bubble, flat translucent disc from `BombDef`'s ring radii — see §10 Q6's refinement above for the full scope and what is deliberately NOT built yet. | none — no prediction dependency for this scope |

Each task closes against §12's contract below, same as every other task in
this plan.

### What this session's research corrected before it became a task

Two places where reading the real code changed the plan from what a first
reading of the Director's words would have produced — recorded so neither
gets "fixed" back by someone trusting the plain-English request over the
code:

1. **The bubble does not need `delta.census` OR a full Delta.** `PREDICTION_MASTER_PLAN`
   §11 states the bubble "should read `delta.census` (§3.4) rather than a
   full Delta" — true for a per-cell ray-based bubble, but §3.4's census is
   an aggregate count per (surface, material), not per-cell positions, so it
   cannot drive individual rays either way. Moot for the scope actually
   shipping now (E-BUBBLE is a flat disc sized from static `BombDef` ring
   radii, no Delta of any shape needed) — but real, and worth naming, for
   the deferred "rays from inside the bubble" idea: that would need a THIRD,
   lighter shape on `WorldDelta` (per-ring cell positions, no material/light/
   soot resolution), not the census and not the full Delta. Not built; named
   so the deferred feature does not silently reach for the wrong field.
2. **No full-room relight fires after a blast today — grepped, not
   assumed. ✅ RESOLVED 2026-08-10 — it is a real future capability, and it is
   explicitly OUT of this plan.** `detonation_plan_builder.gd`'s own
   `VoxelLightField.build()` call (§8.8's phase 6) constructs a **throwaway,
   plan-scoped field** used only to resolve this blast's own entries' `alt`;
   it never touches `room._voxel_light_field`, and nothing in
   `test_zone_controller.gd`'s detonation sequence or `room.gd` calls a
   room-wide relight (`_repaint_world_shadows()` or `_voxel_light_field.build()`
   on the persistent field) after a commit. The Director confirmed this is
   deliberate for now, not a gap: *"nós vamos ter buracos no teto que iluminam
   o cenário, e paredes destruídas idem. Isso interfere diretamente no
   gameplay do jogo, causando sombras ou iluminação, e vai ter toda uma
   milestone só pra si."* A hole changing what the room's light field looks
   like is a GAMEPLAY system (shadows, tactical visibility) that belongs
   alongside cover/exposure and guard detection, not a destruction-VFX task —
   **deliberately deferred to that future milestone, not scheduled here.**
   What THIS plan closes is narrower and already built: the destroyed voxels'
   own soot/decal/light-bucket paint (exactly the three the Director named —
   *"fuligem, decals e luz"*) — `detonation_plan_builder.gd`'s existing
   per-entry `alt` resolution already covers all three, pre-commit, pure.
   **The original "defer this until after the smoke fires" idea is DISCARDED**
   on the Director's own conditional (*"se isso não for economizar
   processamento... podemos descartar essa alteração"*) — §8.8 already
   measured this exact phase at **0.1 ms**, so there is nothing to save by
   deferring it, and the extra time budget from the future throw-arc animation
   makes the point moot twice over. `build_plan()` keeps resolving it eagerly,
   unchanged. **E-FUME is unaffected by this** — it only moves WHEN soot's
   already-resolved `alt` gets painted onto the tilemap and how its alpha
   ramps in, never when it gets COMPUTED.

### Reference images (2026-08-10)

Two grenade-fragmentation stills (dark, angular, hard-silhouetted debris
against a bright core — the look target for E-FRAG/E-SHARD) and one Phoenix
Point capture (the flat translucent hex-grid aim overlay — the look target for
E-BUBBLE) were attached in chat. Not saved into the repo as of this writing;
if any becomes a long-lived visual reference, save it under a hand-picked name
(never `auto_*`, per this plan's own §12 rule) rather than relying on the chat
transcript.

---

## E-JUNCTION-01 (2026-08-13) — corner columns take no damage from anything

Director, with a screenshot circling three of them: *"a explosão não afeta as
COLUNAS EXTRAS nos cantos das paredes. Precisamos incluir elas no sistema de
destruição."* Plan written before any code changes, per the Director's own
instruction — this section is that plan, not a report of work already done.

### What they are

`JunctionResolver.resolve()` (`godot/scripts/geometry/junction_resolver.gd`)
fills the diagonal notch at a wall elbow (a V-junction, or a free-standing
wall end) with a `JunctionColumn` — its own class, structurally close to a
`Slice` (a `voxels: Array[Voxel]`, a `material`, a `facade_enabled`) but
**not** a `Slice` and **not** registered in `EdgeRegistry` or `SlabRegistry`.
It is a third container class, held only as a flat `Array` on
`room._junction_columns`, populated once at build time
(`room_builder.gd:565`) and consumed today by exactly two systems: rendering
(`voxel_renderer.render(edge_registry, junction_columns)`) and occlusion
(`_occlusion_set.recompute(origins, slices, _room_size, _junction_columns,
ceiling_slabs)`).

### Root cause, confirmed by reading every resolution path — not one bug, two

Both explosive and firearm damage resolve their target purely through
`edge_registry` / `slab_registry`. Neither has ever been told
`room._junction_columns` exists, so a junction column cannot be found by
either, regardless of how close the blast or the shot is:

- **Explosions.** `DetonationPlanBuilder._phase_setup()` calls
  `BlastCalculator.find_affected_containers(gu_rings, edge_registry,
  slab_registry)` — walls via `edge_registry.edges_touching_gu()` /
  `slices_of_edge()`, roofs/floors via `slab_registry.all_slabs()`. No third
  argument, no junction lookup. The real ctx builder
  (`test_zone_controller.gd:_build_detonation_ctx()`) doesn't pass
  `room._junction_columns` either — the gap is at both ends.
- **Firearms.** `BlastCalculator.resolve_pellet_voxel()` (CONE) and the LINE
  hit-test resolve a shot's target the same way: scan
  `edge_registry.edges_touching_gu(gu)` for the `Edge` reaching the target
  face, then `edge_registry.slices_of_edge(edge.id)`. Same blind spot, same
  cause — a shot aimed at a junction column's GU finds nothing there and (per
  `resolve_pellet_voxel()`'s own `if target_slice == null: return {}`) the
  pellet simply registers no impact.
- **The map-wide walk.** `_phase_walk()`'s container list
  (`detonation_plan_builder.gd:536-541`) is built from
  `edge_registry.all_slices()` + `slab_registry.all_slabs()` only, so even a
  junction column's SOOT and OCCUPANCY indexing (needed for the light field
  and for `derive_soot_rings()`) are silently skipped — a scorch mark from a
  blast that destroyed a neighbouring wall would never appear on the column
  standing right next to the hole.

So: fully solid, fully rendered, fully occluding geometry that no weapon in
the game can mark, dent, crack, destroy, or scorch. Confirmed real and not
rare — the Director's screenshot shows three on one PLAYGROUND camera angle;
every V-junction and free-standing wall end on every map has one.

### Why this is not a punctual fix

Read before proposing a scope, not assumed:

1. **`JunctionColumn` has no `.id`.** Every keyed lookup in the destruction
   pipeline (`affected["slices"][slice.id]`, `container_of[key] = slice`,
   the `census` grouping) is keyed by a container id string a `JunctionColumn`
   does not have.
2. **`DetonationPlanBuilder`'s phase state machine has no slot for a third
   container type.** `PHASE_SLICES` → `PHASE_ROOFS` → `PHASE_FLOORS` →
   `PHASE_WALK` is a fixed sequence (`_run_phase()`'s `match`); adding
   junction columns means a new phase (mirroring `_phase_slices()`, since the
   shape — voxels + material + ring/level math — is the same
   `simulate_container_damage()` walls already use) wired into that sequence
   and into `_phase_walk()`'s container list.
3. **`_resolve_damaged_tile()` has exactly two branches: `is Slice`, else
   assumed `Slab`** (`var slab: Slab = container` — a hard cast that would
   error on anything else). A `JunctionColumn` needs its own third branch, not
   a cast into either existing one.
4. **The real design question: a `Slice` has one `.face`; a `JunctionColumn`
   has two (`face_a`, `face_b`) — it IS the corner.** `_resolve_damaged_tile()`
   passes a slice's single face into `_set_voxel_cell()` to orient the damage
   texture. A column has no single orientation to hand it. Checked whether
   `Voxel.damage_carved_side` (already computed per-voxel, D25's directional
   carving) could pick between them for free — it can't: `CarvedSide` is
   `{TOP, BOTTOM, LEFT, RIGHT}`, a screen-space carve direction, not the
   `Face` enum (`NW/NE/SE/SW`) `face_a`/`face_b` use. No existing field
   answers "which of this column's two faces did the damage come from"
   without new geometry work.
5. **Baking (B1-B6) already special-cases junction columns for rendering**
   (`BAKE-FIX-06`/`BAKE-FIX-10` in `junction_resolver.gd` and
   `room_builder.gd` — mirroring, override resolution, a whole
   `_apply_junction_overrides()` post-pass). Damage rendering has to fit
   inside that existing baked/live split (B1: baked XOR generic, never both),
   not bypass it.

### Recommended design (for the Director's yes/no, not yet built)

- **Damage model: identical to an adjacent wall.** Same ring weights, same
  `simulate_container_damage()` call, same DESTROY/DENT/CRACK/soot tiers a
  `Slice` gets — a corner column is structurally a wall segment that happens
  to be diagonal, and giving it a lesser damage model would just move the
  "why doesn't this bit destroy" report one tile over.
- **Id:** synthesize one at resolve time — `"JCOL_%d_%d" % [gu_cell.x,
  gu_cell.y]` is unique (one column per diagonal GU, `JunctionResolver`'s own
  `cells_seen` dictionary already guarantees that).
- **Face for damage-texture resolution: `face_a` by default**, the simplest
  option that is never wrong so much as occasionally arbitrary — the column
  is one to a few voxels on a screen-small diagonal notch, and unlike a full
  wall face there is no long run of tiles where a consistently-wrong
  orientation would read as a mistake. Flagged as a LOOK detail to revisit
  after a real capture, same pattern this plan has used all session (e.g.
  S-FEATHER, the soot tail), not a blocking question.
- **Firearms and explosions share the fix.** Both dead ends are in
  `blast_calculator.gd` and resolve through the same `edge_registry`-shaped
  gap — a single new lookup (junction columns touching a GU, by face)
  extends both `find_affected_containers()` and `resolve_pellet_voxel()`/the
  LINE hit-test, rather than writing the search twice.

### Tasks, in order

| id | task | touches |
|---|---|---|
| J1 | `JunctionColumn` gains `.id` (synthesized, `resolve()`) | `junction_resolver.gd` |
| J2 | A shared "junction columns touching this GU" lookup, keyed like `edge_registry.edges_touching_gu()` | `blast_calculator.gd` (new helper) |
| J3 | `find_affected_containers()` takes `junction_columns: Array` and returns a `"junctions"` bucket alongside `"slices"`/`"roofs"`/`"floors"` | `blast_calculator.gd` |
| J4 | New `PHASE_JUNCTIONS` (mirrors `_phase_slices()`) wired between `PHASE_SLICES` and `PHASE_ROOFS`; `_phase_walk()`'s container list includes junction columns | `detonation_plan_builder.gd` |
| J5 | `_resolve_damaged_tile()` / `_surface_name()` / `_material_name()` gain a `JunctionColumn` branch (face_a, per the recommendation above) | `detonation_plan_builder.gd` |
| J6 | `resolve_pellet_voxel()` (and the LINE hit-test) search junction columns too, via J2's helper | `blast_calculator.gd` |
| J7 | Real ctx builders pass `room._junction_columns` through: `test_zone_controller.gd:_build_detonation_ctx()`, plus both selftest scaffolds (`detonation_plan_selftest.gd`, `detonation_choreographer_selftest.gd`) so coverage is real, not defaulted-empty | 3 files |
| J8 | Verify against B1-B6: a damaged junction column still resolves baked XOR generic, never both, through the existing `_apply_junction_overrides()`/bake path | `damage_atom_bake_selftest.gd` (extend) |

### Verification

Same contract as §12, plus the specific red-before-green this bug needs: a
real PLAYGROUND blast or shot aimed AT a junction column's GU, showing zero
touched cells before the fix and a real DESTROY/DENT/CRACK entry after it —
matching this plan's own floor-dent lesson (a synthetic fixture with a
junction column in convenient reach could pass while PLAYGROUND's real
columns stay untouched, so the real map is the gate, not a fixture built to
have one nearby).

---

## 12. Verification contract for this plan

Nothing in this plan is reported done on reasoning. Each task closes with:
`project_lint.py` clean · `run_selftests.py` clean · `check_invariants.py` OK ·
`gen_codemap.py --check` clean · **and a real capture from the real PLAYGROUND
map with real counts printed** — the floor-dent lesson (69 dents on a fixture,
zero on PLAYGROUND) applies to every effect the blast can produce — which since
2026-08-09 is a radially-ordered queue of per-voxel steps, not 15 waves.

Captures meant to be cited here get **hand-picked names** (`expl_wave3_ring0.png`),
never `auto_*` — the 50-file rotation eats those, and 16 of 23 `auto_*`
citations across the docs were already dead when measured on 2026-08-03.
