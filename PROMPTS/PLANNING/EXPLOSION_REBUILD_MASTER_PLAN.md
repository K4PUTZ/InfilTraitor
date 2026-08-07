# EXPLOSION_REBUILD_MASTER_PLAN
## Grenade detonation: targeting, choreography, and voxel damage — v1.0

**Date opened:** 2026-08-05
**Updated:** 2026-08-06 — Director answered Q1–Q6, then corrected/extended Q1b
and Q3b in a follow-up round (floor is material-real now, not agnostic to
"earth"; bullet marks join the pre-bake), then added D13 (per-map material
scope + cross-session bake cache, §3.5). Task 0 ran and passed its gate
(§8.1), Q1b was answered (spherical falloff D14, roof-throw holes D15).
**Same day, later: Task 1a (E-MAT) shipped — commit `95d83cb`. Later still:
Task 1b (E-BAKE) shipped — commit `2d18a9e`.** Q7–Q9 remain (Phase B only).
**2026-08-07: Task 2 (E-RING) shipped** — see its closure note below.
**Status:** 🟢 **BUILDING. Task 0, Task 1a, Task 1b, and Task 2 are all done.
273 real damage atoms bake on PLAYGROUND, cache-verified (1498ms → 31ms on a
second load), wired end-to-end (`apply_damage_voxel_swap()` resolves via the
pre-bake for a real wall voxel). `apply_container_damage()`/
`apply_crater_damage()` now carry the full ring/falloff/gating surface (D14
spherical falloff, per-tier weights, D2 deep-layer gate, D16 blast-side
routing, D17 pierce multiplier) — calculation-layer only, no live caller yet
(see Task 2's own closure note for why). Task 3 (E-SOOT) is the next concrete
action.**
**Next action:** §11. **Task 3 (E-SOOT)** — per-voxel authored soot,
consuming `soot_ring_tones`/`smoke_ring_weights` (parsed by Task 2, not read
yet). Q1d is answered and implemented — D19/D20/D21's rename and
dynamic-data reform are live (`res://materials/*.json`, `ground_* → bare`,
`facade_*`/`slab_*` texture split); see the Task 1a/1b/2 closure notes below
for the real corrections surfaced against the plan text.

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

**Cadence confirmed 2026-08-06: 40 ms/wave** → 15 waves ≈ 600 ms of
choreography (was 560 ms/14 waves before Smoke ring 3 was added).
`wave_interval_ms` is a `var`, not a `const`, and trivially re-tuned after the
first capture.

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
| 3 | E-SOOT | per-voxel soot codes; `min()` merge of derived + stamped; ring-3 stamping | Real capture showing soot at ring 3 where nothing is destroyed |
| 4 | E-PLAN | `DetonationPlan` builder — all resolution, all exposure fallback, the single light repaint | Printed plan census (cells per wave) from a real detonation |
| 5 | E-WAVE | `DetonationChoreographer`; reconnect `TestZoneController.detonate_active()` | Real capture per wave; measured per-wave ms |
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

### Q6 — 🟡 PARTIALLY ANSWERED 2026-08-06 (bubble described; reference image attached). Phase B only, does not block Phase A.

The Director attached the XCOM reference and described it: a line simulating
the parabola from the throwing agent to the impact point, and a translucent
3D bubble over the blast-radius area, in isometric perspective — the same
information the existing floor-perimeter wireframe (`open_menu_for()`) already
computes, extended into a 3D projected volume rather than a flat outline. Not
detailed further here since Phase B is not scheduled — recorded so the Phase B
plan doesn't have to re-ask for the image.

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

## 11. Next session starts here (updated 2026-08-07, post-Task-2)

**Resume point:** Task 0, Task 1a (E-MAT), Task 1b (E-BAKE), and Task 2
(E-RING) are all done and committed. Grenades still detonate and damage
nothing — `apply_container_damage()`/`apply_crater_damage()` now carry the
full ring/falloff/gating surface but have no live caller yet
(`TestZoneController.detonate_active()` stays disconnected until Task 5);
firearms still work, untouched. **Task 3 (E-SOOT) is the next concrete
action** — see §8's Task 3 row and §5: per-voxel authored soot codes,
`min()`-merging derived + stamped, ring-3 stamping. `soot_ring_tones`/
`smoke_ring_weights` are already parsed into `BombDef` (Task 2) and sitting
unread — Task 3 is where they first get consumed.

Older order-of-business items (Q1b confirmation, Task 0, Task 1a, Task 1b,
Task 2) are fully closed and folded into §1/§8.1/§8's task rows / the
closure notes above; not repeated here.

**Order of business:**

1. **Task 3 (E-SOOT) is next.** Read §8's Task 3 row and §5.1–5.3: per-voxel
   granularity (not per-face), authored by the blast per ring rather than
   derived, `FACE_SOOT_CLEAN = 4` real tones. §5.3 ("Not breaking firearms")
   is the scope boundary to reread first — this task must not touch the
   D33 live-compositing path Task 1b just finished proving untouched.
2. Once Tasks 3–5 (Phase A's remaining waves) are captured and signed off,
   `TestZoneController.detonate_active()` gets rewired back onto
   `BlastCalculator` (removed 2026-08-05, commit `d412480`) — that is the
   actual remaining "flip the switch" moment for explosions, and also where
   Task 2's `deep_layer_unlocked`/`slab_pierce_multiplier` parameters and
   D2's `room._gu_blast_count` state first get a real caller. **Firearms
   already flip their own switch automatically** (see §9's rewritten D12
   note) — nothing left to do there.

**Do not:**
- start Phase B (targeting UI, bubble, throw, explosion frames) — the Director
  chose Phase A first, deliberately, so the 15 waves are verifiable with real
  captures before they get wrapped in animation. Q6's bubble description and
  XCOM reference (2026-08-06) are recorded in §10 for when Phase B starts, not
  a signal to start it now;
- re-enable camera rotation as part of this work (§9);
- treat the 207/273-atom counts in §3.2/Task 1b as open numbers — both are
  settled and measured (D16 adds routing, not atoms; Task 0 measured ~737 ms,
  Task 1b measured the real 273-atom bake at ~1.5 s cold / ~31 ms warm);
- assume Task 2's new parameters (`deep_layer_unlocked`,
  `slab_pierce_multiplier`, the per-tier weight arrays) are live in any real
  playthrough — they are proven correct in isolation via selftest only,
  since no caller exists yet (Task 5's job).

---

## 12. Verification contract for this plan

Nothing in this plan is reported done on reasoning. Each task closes with:
`project_lint.py` clean · `run_selftests.py` clean · `check_invariants.py` OK ·
`gen_codemap.py --check` clean · **and a real capture from the real PLAYGROUND
map with real counts printed** — the floor-dent lesson (69 dents on a fixture,
zero on PLAYGROUND) applies to every single one of the 15 waves.

Captures meant to be cited here get **hand-picked names** (`expl_wave3_ring0.png`),
never `auto_*` — the 50-file rotation eats those, and 16 of 23 `auto_*`
citations across the docs were already dead when measured on 2026-08-03.
