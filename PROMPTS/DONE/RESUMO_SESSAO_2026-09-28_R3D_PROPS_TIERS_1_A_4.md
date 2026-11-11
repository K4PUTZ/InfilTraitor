# Session 2026-09-27/28 — masterplans reorganized, R3D-PROPS closed end to end (Tiers 1-4), FloorPile3D geometry fixed

Full record: `RENDER3D_MASTER_PLAN` v1.29 → v1.47 (top blocks, chronological). Commits: `3a40b1b7..591c7869`.

## Ask

"Vamos manter uma trilha mais simples e eficiente... fechar as funções básicas da engine" (reorganize the 24 masterplans into one clear path), then "seguir com R3D-PROPS" once the reorganization gave R3D-PROPS a clean spot at the head of the queue.

## Part 1 — Masterplan reorganization (`ebad404a`..`ce6c6a6b`)

- **10 fully-closed plans archived** `PLANNING/` → `DONE/`: `ASSET_TREE_REFORM`, `BURN_THROUGH`, `FIRE_REBUILD`, `DETONATION_PERFORMANCE`, `DETONATION_PRESENTATION`, `EXPLOSION_REBUILD`, `PREDICTION`, `RENDER_ORDER`, `TARGETING`, `SOOT`. Every live cross-reference (`docs/README.md`, `docs/DESIGN_MASTER_PLAN.md`, `docs/production/*`, `CLAUDE.md`) repointed; historical `RESUMO_SESSAO_*.md` logs left as-is (they describe the repo as it stood that day).
- **12 remaining non-R3D plans** got a one-line banner pointing to the live R3D-* track that now owns their open work, so `RENDER3D_MASTER_PLAN` became the single place to read for "what is still open in the engine."
- **Closing sequence for "engine basics" ratified:** `R3D-PROPS` → `R3D-ACTORS` → `R3D-ROT` + `R3D-WORLD` → `R3D-SURFACES` → `R3D-LOOK` → `R3D-CLAIMS`/`R3D-BUFFER`.
- **OPEN THREADS list created**, consolidating loose ends that used to be scattered: the occlusion-persists-across-map-load bug, the RESUME button, WEAPON's D12-D20, the SOOT_STORAGE_REFORM evaluation, the rotation design questions (added after being missed in the first pass), MATERIALS' deliberately-unmade `plastic`/S-4.
- **Four design decisions ruled** (`dd9d5703`): rotation stays 4 fixed views (a free dev-mode camera left open as a possible later addition); camera-only rotation (one map, the layout never re-lays-out); `SOOT_STORAGE_REFORM` §5.3 — scorch dies with the material, checkpoint restore returns walls to clean; WEAPON's "which face was struck" question closes as moot (true 3D geometry answers it by construction).
- **`SOOT_STORAGE_REFORM` evaluation closed** (`c4dbf953`): the redundancy fear was about a 6-direction view-space format SOOT-STAMP had already deleted (2026-09-22); the live isotropic-tone store is exactly what serves "keep already-explored map state across a checkpoint reset" — already built, already cheap. The plan document archives; the feature is unchanged.
- **RESUME button + the occlusion bug, both fixed same day** (`80afbaac`): `MainMenuPanel` gets a `_btn_resume` (first, default-focused); `load_map()` never called `_recompute_occlusion()` after building a fresh `Board3DLive` node — fixed by mirroring the identical call already proven on view rotation.

## Part 2 — R3D-PROPS art direction ruled (`c4dbf953`)

Four tiers (Director): construction stays native-voxel; most square props (crates) are native-voxel like construction; small/medium props (weapons, cutlery, plates) are non-destructible mesh with cosmetic soot/smoke by proximity; medium/large organic/natural props (tables, chairs, rocks, trees) are mesh while intact, swapping on impact for a transient "LEGO-style" fragment-cube VFX swarm — never a persistent `VoxelStore` container. That reclassification removed Tier 4 from the memory/architecture risk a persistent dense sub-voxel prop would have had.

## Part 3 — Tier 1/2: crates place real voxels (`09658877`)

The gap found the previous session (`crate_full` resolved its def but placed zero voxels — `register_block_levels()` is a 2D-era no-op) is closed. New `PropBlock` container (mirrors `Slice`'s minimal contract; `VoxelStore._fill()` reads containers duck-typed, no changes needed there). `VoxelStore` gets `KIND_PROP` and a 4th `containers_of()`/`build()` parameter (defaults to `[]`, every existing caller unchanged). `VoxelBoard.register_prop()` now builds real voxels filling the footprint × storeys box at native resolution.

**Two real bugs found and fixed along the way** (would have crashed/silently-broken on the first prop with a visible voxel): `Board3DLive`'s per-kind visible-claim tally was sized for exactly 3 container kinds (`KIND_PROP` would index out of bounds); `BoardProbe`'s identity-gate tally likewise only counted 3 kinds (a prop container would have been silently invisible to the gates — the "vacuous gate" trap this project has hit before).

Verified: `FLOOR_ZONES_TEST` with a temporary `crate_full` placement — claims +512 (8×8×8, one footprint GU × one storey), 0 irregular containers, captured on desktop (a correctly lit, depth-tested wood cube, same store/mesher path as a wall).

## Part 4 — Orphaned soot cleared (`6d21893d`)

`SOOT_STORAGE_REFORM` §5.3's ruling ("scorch dies with the material") implemented: `Room._clear_orphaned_soot()` hooks `VoxelBoard.voxel_destroyed` — the one choke point every destruction path (blast, firearm, fire, glass) already fires through once per newly-destroyed voxel — and erases that voxel's base-space cell from `_soot_map`. Deliberately leaves the crater-floor case alone (a different, still-intact voxel).

## Part 5 — Tier 4: the shatter burst, from existing VFX (`4f07e50d`)

`Room.spawn_prop_shatter(cell, level, material_id, fragment_count)` reuses 100% of `_dispatch_destruction_vfx()`'s smoke/dust/spark/chip machinery instead of a new particle field or real fragment geometry — `fragment_count` is a density knob, not a literal instance count. Demo seam `PROP_SHATTER_DEMO`. Captured on desktop: wood-tinted chips launch and arc from the barrel's cell.

## Part 6 — Tier 3/4 props scorch like a wall (`7ea8ecbe`)

Director noticed props already stand in the world and asked whether an explosion soots them the way it soots a wall — it did not: `prop_mesh3d.gdshader` only read the cell-plane's light bucket (G), never the soot code (R) every wall material already decodes. Added the same R-channel decode `OPAQUE_SHADER` uses, reading the TOP ring of the floor cell the prop already samples for light (a stand-in for "how sooted is the ground here" — a prop mesh has no flat wall face to pick a per-face read from). `board3d_live.gd` pushes `soot_mult` to prop materials alongside the light uniforms. Also ruled: debris art should be authored CLEAN (grayscale/neutral), soot applied procedurally — matches every other decal in the project.

## Part 7 — Debris art incorporated: grayscale tinting + real ground pile (`8bbae3e1`, `d4eceaaf`)

Director asked whether debris art should already be dirty since it only appears post-explosion; agreed clean art is right, and separately clarified debris should be grayscale, tinted by the material that broke it (unlike a ground/patch decal, which complements a photographic surface and stays full colour). `floor_decal3d.gdshader` already multiplied `texel.rgb * COLOR.rgb` — `FloorPile3D.set_pile()` just hardcoded that colour to white; added an optional `tint` param (default white, every existing caller unaffected).

Director delivered 3 real grayscale wood-splinter decals (`WOOD1/2/3.png`, CC0 sourcing was explored earlier in the session but the Director produced original art instead — not third-party, no `SOURCES.md` needed). Copied to `decal_debris_wood_0/1/2.png`. Built the real ground-debris mechanism: one lazily-created `FloorPile3D` per material in `VoxelBoard`, wired into `spawn_prop_shatter()`. Verified end to end on desktop: a wood-tinted patch sits on the ground after the burst, persists past the fragments' fall.

## Part 8 — FloorPile3D geometry fixed: true ground-plane losango (`61b3311c`)

Director spotted the wood debris pile rendering as a screen-facing square instead of the isometric losango the floor grid has, and correctly suspected glass suffered the same bug. Root cause: the quad was built by back-projecting a SCREEN-space square onto the ground through `ground_affine()` — a `Sprite2D`-era leftover (the explicit old goal was "keep the same screen footprint it had as a sprite"). Rewrote as a plain world-space X/Z quad (the same convention `Board3DLive._emit_quad()`'s top face and `PropMesh3D` use) — it now shears under the camera exactly like the floor tile beneath it.

Also generalized placement per the Director's follow-up: debris should scatter as several small, randomly-rotated pieces free to land across a GU or voxel-cell edge (breaking up the grid, the same purpose a ground/leaf patch serves), not one mark pinned to the break's exact cell. `set_pile()` stays as the cell-centred wrapper every existing caller (glass, the leaf patch) uses unchanged; a new `place(id, center, level, ...)` takes an arbitrary world-space centre. `spawn_prop_shatter()` now scatters 2-5 jittered, rotated pieces instead of one fixed pile.

Verified on desktop, both consumers: GLASS map, a real blast (found the pane's GU the way `_capture_glass_blast_demo` does, drove it through the plain scenario language) — shard piles read as clear diamonds matching the floor grid. PLAYGROUND, `PROP_SHATTER_DEMO` — several small wood-tinted piles scattered around the break, crossing tile boundaries.

## What is live vs. what is still open

- **Live:** Tiers 1/2 (native-voxel props, e.g. `crate_full`) place real, destructible geometry; Tier 3/4 prop meshes scorch by proximity; Tier 4's shatter burst and persistent, tinted, correctly-shaped ground debris (wood only, real art); orphaned soot clears on destruction; the FloorPile3D geometry fix covers every consumer (glass, leaf patch, debris) uniformly.
- **Open, real follow-on scope (Director's call to schedule):**
  1. No real map-data schema for prop placement yet (everything tested via dev flags or temporary map edits, reverted).
  2. No proximity detection wiring a Tier 3/4 prop to an actual nearby blast/shot — `spawn_prop_shatter()` and the Tier 3 soot/smoke response both need a real trigger, not just a demo call.
  3. Art still needed: cardboard/fabric, ash/charred decals (specs given; CC0 source found for cardboard — `CardboardSet001` on ambientCG — none found for ash/charred).
  4. `_capture_glass_blast_demo` crashes on a stale debug print (`_glass_shard_cells`, no such property) — dev-only diagnostic tool, not the game.
  5. WEAPON's D12-D20 (unbuilt), INTERFACE's Wave 3 items beyond RESUME (none currently open), MATERIALS' deliberately-unmade `plastic`/S-4 — all pre-existing, tracked in OPEN THREADS.

## Evidence

- `verify.py smoke` PASSED after every code change this session (lint, invariants, codemap, 51/51 selftests, PLAYGROUND+GLASS boot) — re-run and re-confirmed at each commit, not just once at the end.
- Desktop captures for every visual claim: the crate (depth-tested wood cube), the shatter burst (wood chips mid-arc), the ground-debris pile (tinted patch), the glass-shard diamond fix (cropped for inspection), the debris scatter (multiple small pieces crossing tile boundaries) — all sent to the Director inline as they landed, not described from memory.
- Two silent-failure traps found and closed before they could bite: `Board3DLive`/`BoardProbe`'s 3-slot kind tallies (Tier 1/2), and the stale `_capture_glass_blast_demo` debug print (flagged, not fixed — out of scope).
