# BAKING_SYSTEM_MASTER_FIX
## Correcting the Baking Pipeline's Core Geometry — Master Plan v1.0

**Status:** ✅ CLOSED 2026-07-10. Phases 0–4 complete: geometry corrected via
the continuous-plane model (which superseded the master-strip design of §4 —
see `docs/technical/BAKE_SYSTEM_REFERENCE.md` §OVERLORD-FIX-01/02 for the
as-built canon and closure evidence), B3 closed with 0/9,437,184 alpha
mismatches, junction columns continue their legs, Director visual
ratification at tags `verified/v0.5.0` ("Alpha Baking Base") and
`verified/v0.5.1` ("Alpha Walls Textured"). Phase 5 (secondary baking /
destructible interiors) was deferred by design and transfers to
`TOP_TEXTURE_MASTER_PLAN.md` Part 3. Safe to archive.
**Companion docs:** `docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md` (canon,
2026-06-29), `PROMPTS/DONE/BAKING_MASTER_PLAN.md` (v1.0, 2026-07-04, the doc that
introduced the bug), `tools/persistent/OPERATOR_CONTEXT.md`.
**Triggered by:** Director-provided updated Baking System diagram (2026-07-07),
instruction to fix fundamentals, not the simplest patch.

---

## 0. Purpose & Scope

`BAKE-SILHOUETTE-01` (this session, commit `1fa1eb0`) attempted to close invariant B3
by giving baked tiles a real alpha silhouette. Verifying that fix surfaced something
bigger: **the entire BAKE-01…08 pipeline was built on a tile-canvas size that does not
match the real, currently-shipping voxel asset.** This is not a bug introduced by
BAKE-SILHOUETTE-01 — it has been latent since BAKE-01 (2026-07-04) and is the reason
every prior attempt to close B3 (`FIX-BAKE-04`, `FIX-BAKE-09`, `FIX-BAKE-09b`, and now
`BAKE-SILHOUETTE-01`) either deferred it or produced a broken result. This plan
documents the root cause with evidence, frames the fix decision, and sequences the
corrective prompts. **No implementation prompt in this plan should run before §3 is
ratified.**

---

## 1. Root Cause — A Conflation in the Master Plan Itself

`BAKING_MASTER_PLAN.md` §3 Stage 5 states:

> `texture_region_size = VOXEL_TILE_SIZE (32×16)` — identical to canon.

This is the bug, sitting in the ratified planning document, faithfully implemented by
every BAKE prompt since. `VOXEL_TILE_SIZE` (`geometry_coords.gd:9`) is the **logical
grid-cell size** — the isometric diamond footprint one voxel occupies on the map.
It was never the size of the actual texture asset. The real voxel sprite is taller,
by design, so its top and side faces are visible above the flat footprint:

```
VOXEL_ATOM_W = 32   VOXEL_ATOM_H = 36   VOXEL_TILE_H = 16   (geometry_coords.gd:27-29)
```

`build_voxel_tileset.gd` — the code that builds the tileset actually used by every wall
in the game today — gets this right:

```gdscript
source.texture_region_size = Vector2i(texture.get_width(), texture.get_height())  # 32×36
```

`bake_compositor.gd` never got this right. `_get_material_tile()` and `_composite_tile()`
have used `Image.create(32, 16, ...)` since BAKE-01, and neither file references
`VOXEL_ATOM_H`/`VOXEL_ATOM_W` at all (confirmed by grep — zero hits across
`bake_compositor.gd`, `per_face_projector.gd`, `material_atlas_generator.gd`,
`baked_tile_lookup.gd`). `room_builder.gd::_register_baked_atlas_page()` inherits the
same wrong size (`texture_region_size = Vector2i(32, 16)`).

### 1.1 Evidence trail

| Finding | How verified | Implication |
|---|---|---|
| Real voxel atom is 32×36 with a genuine alpha silhouette (904 opaque / 239 transparent / 9 edge px, `voxel_concrete.png`) | Direct pixel inspection | This is the real canonical silhouette — nothing needs to be invented. |
| `PerFaceProjector`'s 4 face transforms, evaluated at real `screen_x∈[0,32) screen_y∈[0,16)` pixels, produce quads that mostly or entirely miss the tile (NE/SW: 0% coverage; SE/NW: partial, implausible clip) | Hand-derived the affine math (`is_inside_voxel`'s own matrices) in Python and enumerated all 1024 pixel positions per face | The transforms were never validated against a real pixel grid — confirmed by direct calculation, not suspicion. |
| The only prior code that used `is_inside_voxel` for shape (`material_atlas_generator.gd:70`) is called from **nowhere else in the codebase** | grep across `godot/scripts/` | It was never a validated reference. BAKE-SILHOUETTE-01 pointed at dead code as "already correct, already used elsewhere" — that premise was wrong. |
| `per_face_projector_test.gd::_test_point_in_voxel` generates its own "inside" test point via the same forward transform the predicate uses | Read the test | Circular — can never catch a quad that misses the real tile. Same failure shape as the B3 selftest BAKE-SILHOUETTE-01 already had to replace. |
| The real, currently-shipping (generic, non-baked) wall renderer places the *entire* 32×36 atom per voxel and always uses `atlas_coords = Vector2i.ZERO` regardless of wall compass direction (`voxel_renderer.gd:189-193`) | Read the fallback branch of `_set_voxel_cell()` | **Voxel shape does not vary by face orientation at all in the shipped game.** `PerFaceProjector`'s 4-orientation shape model has no counterpart in reality — it was solving a problem that doesn't exist at the shape layer. |

### 1.2 What this means

Two distinct things got conflated under "per-face orientation":

1. **Shape** (is this pixel part of the voxel silhouette?) — face-**invariant** in
   reality. Every voxel, on every wall regardless of direction, is the same 32×36
   sprite. `PerFaceProjector.is_inside_voxel()` should never have existed as a
   per-face concept; there is nothing to compute, because the shape is the atom's own
   alpha channel, always.
2. **Facade sampling** (which window of the infinite marble/wood/stone plane does this
   wall's texture come from?) — legitimately face-**dependent** (`BAKING_MASTER_PLAN.md`
   D5/Stage 3: wall run continuity, "clone stamp" avoidance for isolated walls). This
   part of the design is sound and should be kept.

`bake_compositor.gd` built both concerns into a single face-keyed 32×16 canvas, at the
wrong size, with no real silhouette source — which is why B3 could never actually close
no matter how many times it was attempted at the code level. The fix belongs one layer
up, in the canvas size and alpha source, not in another patch to `is_inside_voxel`.

---

## 2. Canon Comparison — Planned vs. As-Built

| Aspect | `VOXEL_MASTER_PLAN.md` §7 (2026-06-29, canon) | `BAKING_MASTER_PLAN.md` (2026-07-04, ratified) | As-built (`bake_compositor.gd` today) |
|---|---|---|---|
| Bake unit canvas | Voxel's own screen rect (implicitly the real atom, 32×36) | `VOXEL_TILE_SIZE (32×16)` — **conflated** | `Image.create(32, 16, ...)` |
| Alpha source | Real voxel atom's own alpha (crop+multiply preserves it) | "Alpha always comes from the canonical material tile" (B3) — correct in *intent* | Hardcoded `1.0`, then (this session) a broken face-keyed geometric guess |
| Shape variance by wall orientation | None — "geometry is identical across all materials" | Implicit 4-orientation model via `PerFaceProjector` | 4-orientation model, unvalidated, geometrically broken |
| Facade texture variance across a run | Not addressed (out of scope in VOXEL plan) | Deliberate: continuous veins across a run, "clone stamp" avoidance for isolated walls (D5, Stage 3) | `FacadeSampler`'s mirrored-repeat math — **sound, keep** — but only ever called in isolated-per-edge mode; the run-walking/mirroring behavior itself was never wired (§2.1). Per D-BAKE-1 (§3), this becomes strip-walking, not per-face shear. |
| Atlas registration | — | `texture_region_size = VOXEL_TILE_SIZE (32×16)` | Matches BAKING_MASTER_PLAN (i.e., matches the bug) |

**Bottom line:** BAKE-03 (facade sampling/addressing) and TEX-CATALOG-01 (resolver) are
sound and empirically tested — no changes needed there. The defect is isolated to the
**canvas size and alpha source** used by `BakeCompositor`/`PerFaceProjector`/atlas
registration — everything downstream of "how big is one baked tile and where does its
shape come from."

---

## 2.1 Second Finding (Director, 2026-07-07) — Junction Extra Columns Are Invisible to Baking

The Director flagged a case neither this plan nor the original BAKE-01…08 work
accounted for: **`JUNCTION-01b`'s filler columns at V-junctions currently receive zero
facade texture, ever, regardless of `BakeConfig.enabled`.** Verified directly:

- `voxel_renderer.gd::_render_junction_column()` calls
  `_set_voxel_cell(column.voxel_pos, level, column.material)` — **no `edge` argument**.
  `_set_voxel_cell()`'s baked-lookup branch (`_baked_lookup.resolve(edge, ...)`) requires
  a non-null `edge` to ever fire; junction columns always fall through to the flat
  material-only path, baked or not.
- `room_builder.gd::_bake_textures(extraction, _edge_registry)` never receives the
  junction-column list at all (`_junction_columns` is computed and handed straight to
  `_voxel_renderer.render()`, never to the bake step).

So this isn't just a crop-width detail — **junction columns are entirely outside the
bake pipeline today**, on top of the canvas-size defect in §1.

The Director's new diagram adds the geometric requirement for when this gets fixed: a
wall run that terminates in a V-junction has a facade texture that must account for the
extra column at that end, because the run's true visual span is (edges × 8 voxels) + 1
extra voxel-width per V-junction end — not just the wall slices' own footprint. Per the
diagram (`(0,1)`/`(1,0)` GUs meeting at a corner, extra column entering the *outer*
diagonal GU `(1,1)`), two candidate fixes:

- **Extend-the-crop**: the facade window for a run doesn't start at the run's first true
  wall voxel — it starts one voxel-width earlier (at the extra column's position),
  covers all interior slices, and ends one voxel-width past the last true voxel if that
  end also terminates in a V-junction. Requires the bake-set/window-origin math to know,
  per run, how many ends are V-junctions (0/1/2) and shift+widen accordingly.
- **Mirror-at-the-column**: leave the run's own crop exactly as wide as its true wall
  slices (no width/origin change to the run math at all); the junction column
  independently samples whichever facade texel column sits at its neighboring wall
  slice's boundary and renders a horizontally mirrored copy of it.

**A third fact makes the mirror option more attractive than it first looks:** the
"continuous texture across a run of edges" feature this whole question depends on
(`BAKING_MASTER_PLAN.md` D5, "successive slices in the run consume consecutive plane
columns") **was never actually wired into production either.**
`FacadeSampler.get_window_origin_run_texels()` exists but is called from nowhere in
`bake_compositor.gd` or `baked_tile_lookup.gd` — both call `get_window_origin_isolated_texels()`
unconditionally, meaning every wall edge today gets an independent, unrelated window,
not a continuous one. Likewise `high_wall.gd` (`HighWall`, the container the canon
docs describe as the natural unit for a "run") is defined but referenced only by the
presence-check selftest — never built by `room_builder.gd`. Both the run-continuity
feature and the extra-column handling are greenfield work landing in the same phase;
neither currently exists, so there's no working behavior to preserve either way.

**D-BAKE-2 — Extra-column facade handling. RATIFIED 2026-07-07: mirror-at-the-column.**
Keeps the (still-to-be-built) run-window math at a fixed, predictable width regardless
of which ends terminate in junctions; reuses the mirrored-repeat aesthetic already
accepted for the facade plane itself. Extend-the-crop is dropped — not pursued further
in this plan.

**D-BAKE-3 — Extra-column material override. RATIFIED 2026-07-07 (new requirement,
added after D-BAKE-2).** The junction column must support an *authored* material
different from the wall's own material — e.g., an iron accent column at the corner of
a wall otherwise built from a different metal/material — independent of whether that
column also carries facade texture (plain-material-only columns must remain possible,
same as any other material-only voxel today). This is additive on top of the existing
`JunctionColumn.material` field (`junction_resolver.gd`, added in
`FIX-JUNCTION-COLUMN-MATERIAL-01`), which currently always derives its value from
`edge_a.material` — i.e., whichever of the two meeting walls happens to be first in
dictionary order. Closing D-BAKE-3 means:

- An authoring path for the override (where a map author specifies "this V-junction's
  column is `<material>`, with facade `<on/off>`") — the natural home is `MapSpec`,
  resolved at the same point `junction_resolver.gd` currently derives `edge_a.material`
  automatically. **Stated assumption** (trivial gap, filled rather than round-tripped):
  the override is optional per named junction/vertex, keyed the same way `WallEdgeData`
  already keys edges; absent an override, current behavior (derive from `edge_a`)
  is unchanged. Flag if this isn't the right authoring surface.
- `JunctionColumn` gains a `facade_enabled: bool` (or equivalent), independent of its
  `material` — a column can be textured-mirror, material-only, or (per the override)
  both a different material *and* material-only, all as separate authorial choices.

---

## 3. Decision Required (Director ratification)

**D-BAKE-1 — Fix direction. RATIFIED 2026-07-07 — Option (c), synthesized from the
Director's own description of the intended runtime model** (neither of the two
options originally framed here was quite right; see the explanation below).

The Director's clarifying question ("are we using the texture to cover more than one
atom?") cut to the actual problem. Current answer: **no, and that's exactly the bug.**
`bake_compositor.gd` bakes **one atom at a time, live, at each room's load, using a
per-face-orientation screen-space shear transform** (`PerFaceProjector`) to figure out
which facade pixels land on which screen pixels. That transform is what turned out to
be geometrically broken (§1) — it's solving an orientation-dependent screen-projection
problem that, per §1.1's last evidence row, **doesn't need to exist**: the real,
shipping renderer already proves voxel shape and placement don't vary by wall
compass-direction at all (`atlas_coords` is always `Vector2i.ZERO` regardless of face).

The Director's actual intended model is simpler and was never what got built:

> Bake a **large master strip** per (material, facade, theme) combination **once**
> (at load, not per-wall) — enough atoms, pre-composited, cached in a dictionary.
> At room-build time, the builder doesn't bake anything — it just **picks a contiguous
> range of already-baked atoms** out of that dictionary for however long the wall run
> needs to be, mirroring past the strip's end if the run is longer. Junction extra
> columns always mirror the boundary atom to complete each face (D-BAKE-2).

This is a genuine third option, combining what's sound in the existing code with what
was actually intended:

- **Keep**: `TextureResolver`, `MaterialRegistry`'s pattern math, and — critically —
  `FacadeSampler`'s mirrored-repeat infinite-plane addressing (`_mirror_1d`/`_mirror_2d`)
  is *exactly* the mechanism needed for "mirror past the strip's end." It was already
  built correctly; it was just never given a strip to walk, only ever called per
  isolated edge (§2.1).
- **Drop**: `PerFaceProjector`'s per-face affine shear entirely. Once baking targets the
  real 32×36 atom (§1) directly and crops from the facade plane are **straight
  rectangular slices** (atom *i* of a run = facade plane columns `[i·W, (i+1)·W)`, no
  screen-space shear), there is nothing left for `PerFaceProjector` to compute — the
  orientation-dependence it modeled doesn't exist in the real renderer. This also
  **structurally eliminates B3**: alpha is the real atom's own alpha, copied as-is, no
  `is_inside_voxel` geometry ever needed. Not a fix to the broken predicate — its
  removal.
- **Build**: the master-strip bake pass (once per unique material+facade+theme actually
  used in a map, at load) and the dictionary lookup the room builder walks instead of
  baking live. This is where run-continuity (§2.1) and D-BAKE-2/3's mirroring land
  naturally — they're the same mechanism (`FacadeSampler`'s mirror math) applied to
  strip-walking instead of a single edge's window.

This also answers the earlier (a)/(b) framing directly: it has (a)'s low blast-radius
(BAKE-03/TEX-CATALOG-01 untouched) while being *closer* to (b)/the original diagrams'
"bake once, crop+place at runtime" spirit than either original option was — because it
correctly identifies that the live per-voxel shear was never load-bearing.

---

## 4. Corrective Sequence (Phases)

Every phase requires **empirical, ground-truth evidence** — the exact discipline
`VOXEL_MASTER_PLAN.md`'s SLICE-00 lesson demands and which this whole defect shows was
skipped at BAKE-01. No prompt in this plan may validate itself with a test derived from
the same code path it's testing (the recurring failure mode above).

### Phase 0 — Ground-truth audit (blocks everything else)

- Load the actual `voxel_concrete.png` (and the other 3 materials), dump alpha, confirm
  the real 32×36 canvas and which pixels are opaque/transparent — this is the
  silhouette going forward, verified against the file, not re-derived.
- Confirm which sub-region of the atom's 36px height actually receives the facade
  multiply (the visible side face, `y ∈ [16, 36)` per `VOXEL_MASTER_PLAN.md` §3's atom
  diagram — verify against the real file and real renderer behavior, don't assume the
  doc is still accurate).
- Confirm the facade plane's real dimensions against the shipped PNGs (`64N × 32N`,
  already validated as 1024×512 for the 4 shipped facades) and decide the master
  strip's length in atoms — long enough to cover any realistic wall run without
  mirroring kicking in constantly (measure against real map wall-run lengths in
  PLAYGROUND/SIGMA_01, don't guess a round number).
- Produce a corrected `TILE_ANATOMY.md` with numbers traceable to real files.

### Phase 1 — Master-strip bake pass (replaces live per-voxel baking)

Per unique (material, facade, theme) combination actually referenced by the loaded
map's `MapSpec` (not every catalog entry — only what's used):

- Bake a contiguous strip of N real 32×36 atoms, straight rectangular facade crop per
  atom position (`atom i` = facade plane columns `[i·W, (i+1)·W)`, `W` from Phase 0 —
  no shear, no `PerFaceProjector`), alpha copied verbatim from the real atom file.
  Runs once at map load (or first reference), not per wall.
- Store in a dictionary keyed by (material, facade, theme, strip-index), consumed by
  `BakedTileLookup` in place of today's per-edge live bake.
- `room_builder.gd::_register_baked_atlas_page()`'s registration parameters
  (`texture_region_size`, `texture_origin`, `y_sort_origin`) updated to mirror
  `build_voxel_tileset.gd` exactly (32×36, real origin/sort values) — this is what
  makes the swap pixel-identical to the generic renderer.
- `bake_selftest.gd`'s B1–B6 assertions updated for the new canvas size and the new
  dictionary-lookup shape; every assertion checks literal pixel coordinates against the
  real atom file, never a value derived from the code under test.
- `per_face_projector.gd` and `material_atlas_generator.gd` (dead code, §1.1) are
  retired, not patched — delete or archive per project convention, don't leave a second
  unused geometry path sitting next to the real one.

### Phase 2 — Room-build strip walking (run continuity + junction columns)

- Group consecutive collinear wall edges of the same material/facade into a run at
  build time (the unused `HighWall` container is the natural home — wire it into
  `room_builder.gd`'s build flow, or a lighter run-grouping step if `HighWall` carries
  more than this needs).
- For each run, walk a contiguous range of the Phase 1 dictionary starting at the run's
  FNV-1a-derived offset (`FacadeSampler.get_window_origin_run_texels()` — exists,
  unused today, this is where it finally gets called), one atom per wall-slice voxel
  position along the run, **mirroring past the strip's end** via the same
  `_mirror_1d`/`_mirror_2d` math already built and validated in `FacadeSampler`.
- **Junction columns (D-BAKE-2, mirror-at-the-column):** in
  `voxel_renderer.gd::_render_junction_column()`, resolve the dictionary atom at the
  neighboring wall slice's boundary position and render it horizontally mirrored,
  instead of skipping the baked-lookup branch entirely (`room_builder.gd::_bake_textures()`
  must start receiving `_junction_columns`, currently passed only to
  `_voxel_renderer.render()`).
- **Material override (D-BAKE-3):** extend `JunctionColumn` with an override material
  and a `facade_enabled` flag; add the `MapSpec` authoring surface for per-junction
  overrides (stated assumption, §2.1 — confirm once seen against real `MapSpec` shape:
  optional per named junction/vertex, keyed like `WallEdgeData`; absent an override,
  current `edge_a.material` derivation is unchanged). `junction_resolver.gd::resolve()`
  checks for an override before falling back; `_render_junction_column()` branches on
  `facade_enabled` (mirrored-bake vs. flat-material-only, independent of which material
  won).
- Real (non-circular) tests per case: default mirror on a synthetic 3-edge run
  terminating in a V-junction; material override with facade on; material override
  with facade off (flat). Each asserts the specific expected pixel/material result, not
  just "not the old broken fallback."

### Phase 3 — Close B3 for real + visual QA

Re-verify all 4 wall orientations render a real silhouette matching the generic
(non-baked) wall pixel-for-pixel (the actual acceptance bar B3 always implied: "bit-
identical to the generic wall's shape by construction" — literally compare rendered
pixels, not just assert opaque+transparent exist somewhere). Enable baking on
PLAYGROUND, screenshot both baked and generic renders of the same wall, confirm no
silhouette divergence, no seams, and confirm a wall run's texture reads as continuous
across slices and into its junction columns. Only then mark B3 closed in
`OPERATOR_CONTEXT.md`.

### Phase 4 — Documentation reconciliation

- `BAKING_MASTER_PLAN.md`: add a correction addendum to Stage 5 and §4.5 (do not
  silently edit the historical decision — record what was wrong and what superseded
  it, per project convention).
- `docs/production/current_state.md`: its VOXEL-08…11 section still describes an
  entirely different, never-implemented "WallSlice.bake_texture" model as "pending" —
  reconcile it with whatever actually ships after Phases 1–3, so it stops being stale.
- `OPERATOR_CONTEXT.md`: B3 status, corrected go-live blocker language, new
  master-strip architecture summary replacing the `PerFaceProjector`-based description.

### Phase 5 — Secondary baking / destructible slices (deferred, explicit)

`VOXEL-09` (per-HighWall single texture spanning all constituent slices, distinct from
the per-material master strip in Phase 1) and the runtime-destructible-subcube behavior
shown in both diagrams are **not** covered by Phases 0–4 — they were never implemented
at all (confirmed: `docs/production/current_state.md` still lists `VOXEL-09`/`VOXEL-10`
as pending, and no code path builds a `HighWall`-level texture today). Scoped here so
it isn't lost, not because it's next — sequence it after Phase 3 lands and B3 is
verified in-game.

---

## 5. What This Plan Does Not Touch

- `TextureResolver` / `TEX-CATALOG-01` (fallback chain, validation) — sound, keep as-is.
- `FacadeSampler`'s mirrored-repeat addressing and FNV-1a window-origin derivation —
  empirically tested (BAKE-03), sound, keep as-is.
- `MaterialRegistry`'s pattern algorithms (`stone_pattern.gd` etc.) — the *shading*
  math (RGB) is independent of the canvas-size defect; only how their output gets
  combined with real alpha changes.
- `junction_resolver.gd`'s V/T/X **detection** logic itself (which cells get a column,
  and where) — correct, verified last wave, not in question. Only *how that column
  gets textured* is in scope, per §2.1/Phase 1b — `JUNCTION-01b` is not being redone.
- The Part 2 fix from `BAKE-SILHOUETTE-01` (view-toggle button/keyboard desync,
  `room.gd`) — already correct and unrelated to baking geometry.

---

## 6. Immediate Housekeeping (do now, independent of §3's answer)

- Reopen B3 in `OPERATOR_CONTEXT.md` — `BAKE-SILHOUETTE-01`'s Part 1 did not close it;
  the "closed ✅" language committed this session is inaccurate and should not stand
  unamended.
- `BakeConfig.enabled` stays `false`. Nothing in this session's commit changed the
  default, so no immediate action there — noted only to confirm no regression risk
  while this plan is pending.

---

*This document supersedes `BAKING_MASTER_PLAN.md` §3 Stage 5 and §4.5 (`PerFaceProjector`,
the 32×16 canvas, per-edge isolated-only sampling). All BAKE-* prompts from this point
derive from this plan, not from the original `BAKING_MASTER_PLAN.md`, until that
document receives its correction addendum (Phase 4).*
