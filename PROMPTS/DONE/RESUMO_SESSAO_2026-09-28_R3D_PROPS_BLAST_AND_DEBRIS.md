# Session 2026-09-28 — glass-demo crash fixed, real crate placement, Tier 3/4 mesh props live, crates finally blast-destructible

Full record in commit messages (see `git log`). Commits: `265d4a48..7cfeca3a`.

## Ask

Continue R3D-PROPS from yesterday's Tiers 1-4 close ("pode seguir na ordem que achar mais
conveniente"), then, once the Director wanted proximity effects: *"a ideia da proximidade é que
o efeito seja condizente com a parede, quanto mais perto da granada mais dano, fuligem, etc.,
proporcional aos demais materiais"* and *"cria um mapa PROPS com os elementos necessários para os
testes."* Later: *"vamos simular uma crate quebrando numa explosão, e os voxels caindo no chão…
aproveitar o mecanismo do vidro que quebra e cai, combinado com o desvio dos estilhaços… mais o
material queimar, virar brasa, fumaça — em tese tudo isso já existe."*

## Part 1 — the glass-demo crash fix (`265d4a48`)

`_glass_shard_cells` was renamed to `_glass_shaped_cells` on `VoxelBoard` at some point after
R3D-END; five diagnostic print sites in `room.gd`'s glass crack/blast dev captures were never
updated, crashing the moment either ran. Fixed; verified by actually running
`_capture_glass_blast_demo` end to end (it had never been re-run since the rename).

## Part 2 — a real crate on PLAYGROUND (`086ddea2`)

Found the map-schema gap from yesterday's OPEN THREADS was smaller than it looked: `MapCompiler`
already translated a map's `"props"` section into `voxel_prop_instances` end to end — no shipped
map had ever populated it. Added one real `crate_full` to `maps/PLAYGROUND.map.json`. Verified on
a normal boot, no dev flags: `PropRegistry` registers it, no "Unknown prop def" warning, the crate
renders as a real depth-tested wood cube.

## Part 3 — Tier 3/4 mesh props get a real placement path (`10491710`)

`PropMesh3D` existed since last session but nothing ever called it. Added `PropDef.mesh_tier` /
`mesh_size`, `MeshPropInstance` + `VoxelBoard.register_mesh_prop()`/`mesh_props()` (no `VoxelStore`
state — rule 8 doesn't apply), `Board3DLive._build_mesh_props()` (one tinted `BoxMesh` per
instance, lit/sooted through the same `register_prop_light_material()` seam every prop mesh
already had). `RoomBuilder` branches on `mesh_tier` in the same `"props"` section Tier 1/2 already
used — no new map schema needed.

Proximity: Tier 3's soot/smoke needed no new code — its shader already reads the real soot-plane
cell beneath it, stamped by true 3D distance to the epicentre exactly like a wall's. Tier 4's one
discrete event (shatter or stay standing) reuses the same wall-aware ring flood, gated on
`destroy_ring_weights`. New `maps/PROPS.map.json` + `props/pistol_prop.json` (Tier 3) +
`props/wood_table.json` (Tier 4).

**First real detonation test looked wrong** (a nearer wood_table seemed to survive while a
farther one didn't) — diagnosed later (Part 5) as the SAME blocked-cell bug that also broke
Tier 1/2, not a layout artefact as first assumed.

## Part 4 — crates were never actually blast-destructible (found, then fixed) (`0dc456fb`)

While preparing the "crate breaking" simulation, found the real root cause:
`BlastCalculator.find_affected_containers()` only ever returned
`{slices, roofs, floors, junctions}` — **no `"props"` bucket at all.** A crate rendered as real
`VoxelStore` geometry but a grenade could sit next to it forever without touching it.

Fixed at the root:
- `find_affected_containers()` gains a `"props"` bucket — with the real complication that a solid
  prop's own GU is a `blocked_cells` entry (`MapCompiler` marks every `"props"` placement
  impassable), and `flood_gu_rings()` refuses to assign ANY ring to a blocked cell. Fixed by
  taking the ring of the prop's nearest FLOODED neighbour, the same "ring at the boundary" reading
  `hit_slices` already gets via `edges_touching_gu()`. `Room.apply_prop_proximity_effects()`
  (Tier 4, Part 3) had the identical bug — fixed with the same fallback
  (`Room._prop_ring_at()`).
- New `PHASE_PROPS` in `DetonationPlanBuilder`, mirroring `PHASE_JUNCTIONS` exactly.
- `_material_name()`/`_surface_name()` learn `PropBlock` — previously "?", which made
  `MaterialResistanceTable.flammability()` always 0 for any prop's own voxels.
- The WALK phase (occupancy/flammability/soot bookkeeping "for the whole map") now walks a
  `PropBlock`'s voxels too, in the exact order `VoxelStore.containers_of()` uses — this also
  re-enables the fast store-walk path, previously always false (and silently falling back to the
  slow object walk) on any map with a prop.
- `Room.apply_prop_debris_fall()`: a crate's destroyed voxels fall and land through the exact
  mechanism a shattered pane's shards already do (`GlassFall.plan_landings()`, same `impulse`
  shape a real glass break builds), `spawn_glass_rain()` gained an optional `tint` (default
  preserves glass's own blue), landing uses the Tier 4 debris-pile mechanism
  (`place_debris_piece()`, already material-tinted).

Ember/burn/soot needed no new code — the WALK-phase fix alone made a flammable crate catch,
ember and soot through the same waves a wall does, "em tese tudo isso já existe" confirmed
exactly.

## Part 5 — verifying both tiers for real (`a8584e19`, `7cfeca3a`)

Added a permanent, opt-in `INFILTRAITOR_PROP_DEBUG=1` diagnostic (same env-gated-print idiom
already used throughout the file) rather than one-off prints. Confirmed on real detonations
against `maps/PROPS.map.json`:
- **Tier 1/2**: `PROP/wood` census line (326 destroyed, 102 dented of 512), 64 embers queued, a
  directionally-carved crate (the corner facing the blast is gone, not a symmetric shrink),
  wood-tinted debris scattered at its base, smoke rising. `burn=0` is correct, not a bug — wood's
  `burn_consumption` is ratified at 0.0 (embers, never fully burns away; that's plywood's job).
- **Tier 4**: all three `wood_table` instances within range (ring 0/1/2, weights
  0.85/0.28/0.06) actually shattered — confirmed via the debug line that `remove_mesh_prop()`
  found and freed each live node, not just that the code path ran. The ring-3 instance
  (weight 0.0) correctly stayed standing. The first test's "still standing" read was a
  misidentification — the visible cube was the Tier 1/2 crate (partial damage), not a surviving
  wood_table.

Per the Director's request, took a second capture with `INFILTRAITOR_CAPTURE_ROTATE_AFTER=S` to
show the crate's damaged face head-on (view N showed mostly the intact top/side) — a clean
reference angle for the wood/plywood debris art the Director is authoring next.

## What is live vs. what is still open

- **Live:** crates and props take real, ring-proportional blast damage and participate in the
  same ember/burn/soot machinery a wall does; Tier 4 mesh props shatter proportionally and are
  actually removed from the scene; a crate's destroyed voxels fall and land using the glass-fall
  mechanism, tinted by material, landing as a Tier-4-style debris pile.
- **Open, explicitly deferred to the Director:** the wood/plywood debris art itself (Director is
  authoring it next session, using the `INFILTRAITOR_CAPTURE_ROTATE_AFTER=S` reference angle);
  cardboard/fabric art and ash/charred decals (unchanged from yesterday's OPEN THREADS); no
  proximity-triggered path exists yet for FIREARM (non-blast) damage to reach props — only the
  grenade/blast path was wired, matching the Director's own "da granada" framing.
- **Environment note, not a code bug:** the manual headless capture harness
  (`--position 4000,4000`, no `--headless`, same invocation `smoke_boot.py` itself uses) hung
  silently mid-boot 4 times this session, always at the same point (right after `[WALK-WARM]`,
  before any grenade logic runs), independent of which code path was under test. Not chased
  further — killed and retried each time; `verify.py smoke`/`quick` never hung once.

## Evidence

- `verify.py quick`/`smoke` (lint, invariants, codemap, 51/51 selftests, PLAYGROUND+GLASS boot)
  passed clean after every commit, re-run at each step rather than once at the end.
- Every visual/behavioural claim backed by a real detonation capture (`test_zone_detonate`, no
  dev shortcuts) and its console output, sent to the Director inline as they landed: the crate
  before/after the wiring fix, the Tier 4 shatter gradient with its removal confirmed in the log,
  the rotated front-facing reference shot.
