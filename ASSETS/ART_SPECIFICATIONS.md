# INFILTRAITOR — Art Technical Specifications

**Version:** 1.0 · **Adopted:** 2026-07-16 · **Status:** LIVING DOCUMENT
**Companion milestone:** `ART-01 — Materials & Objects Pipeline`
(`docs/production/milestones.md`) — scheduled for the **Alpha → Beta window**,
after scenario and gameplay are complete.

This is the single authoritative manual for producing art assets for
INFILTRAITOR. Every texture, facade, and voxel object authored for the game
must conform to the specifications here. Sections marked **SHIPPED** describe
systems already in production; sections marked **PLANNED (ART-01)** describe
ratified direction whose implementation is scheduled, not built.

Ground-truth constants live in code, not here — when this document cites a
number, the code reference beside it is the canon. If they ever disagree,
the code is right and this document has a bug (stop and report; do not
silently fix either side).

---

## 1. Canonical Metrics (SHIPPED)

Source of truth: `godot/scripts/geometry/geometry_coords.gd`.

| Metric | Value | Constant |
|---|---|---|
| Voxels per Gameplay Unit (GU), per ground axis | 8 | `VOXELS_PER_UNIT_AXIS` |
| Levels (voxel rows of height) per storey | 8 | `LEVELS_PER_STOREY` |
| Voxel tile footprint on screen (isometric diamond) | 32×16 px | `VOXEL_TILE_SIZE` |
| Voxel atom (full render cell: 16 px top face + 20 px side face) | 32×36 px | `VOXEL_ATOM_W/H` |
| Screen rise per level of height | 20 px | `VOXEL_STEP_PX` |
| Storey height on screen (8 × 20) | 160 px | `VOXEL_STOREY_HEIGHT_PX` |
| **Texture authoring density (flat texels per voxel)** | **16 px** | `TEX_AUTHORING_N` |

Derived facts every artist must internalize:

- **1 GU = 8×8 voxels of footprint; 1 storey = 8 voxels of height.**
  A GU-storey volume is 8×8×8 = 512 voxels.
- **A slab is 1 voxel (1 level) thick.** There is no thinner unit; there does
  not need to be — the "mini slab" is the native unit
  (`godot/scripts/geometry/slab.gd`).
- **All flat (unprojected) texture art is authored at 16 texels per voxel.**
  128 px of texture = 8 voxels = 1 GU of surface. This is pinned
  (`TEX_AUTHORING_N`); never author at another density and never pre-stretch
  to compensate for projection — the compositor owns all projection math.
- Each voxel is one native Godot `TileMapLayer` cell. Art is consumed by the
  bake compositor (`godot/scripts/systems/bake_compositor.gd`), which slices
  it into 32×36 atoms at bake time (D12: procedural cost is paid at bake
  time, never per frame).

---

## 2. Wall Facades (SHIPPED)

The facade system for vertical surfaces (walls, junctions) — in production
since `verified/v0.6.0`.

| Property | Specification |
|---|---|
| File | `textures/defaults/facade_<material>.png` |
| Dimensions | **1024×512 px** (pinned: `FACADE_W`/`FACADE_H`, `bake_compositor.gd`) |
| Color | **Grayscale — R==G==B on every pixel** (invariant B2). Color arrives at runtime from the material via blend mode (MULTIPLY canon). |
| Alpha | None (fully opaque). Silhouette alpha comes from the canonical voxel texture, never from facade art (invariant B3). |
| Coverage | 1024/16 = **64 voxel columns** wide; 512/16 = **32 voxel rows** = 4 storeys tall |
| Wrap | Edges repeat by **mirroring**, not tiling — the pattern must tolerate being flipped at its borders without reading as broken |
| Vertical pre-scale | The compositor stretches walls ×20/16 vertically (16-texel authoring rows onto 20 px levels). **Author flat at 16 texels/voxel; never bake this stretch into the art.** |

Registration: material → facade mapping lives in
`godot/scripts/systems/bake_policy.gd` (`DEFAULT_FACADES`). Current
materials: `concrete`, `stone`, `wood`, `metal`.

---

## 3. Roof & Slab Top Textures (PLANNED — ART-01)

**Ratified direction (2026-07-16):** horizontal surfaces get their own
dedicated art family, separate from wall facades. Today (ROOF-BAKE-02c) roofs
reuse the wall facade unscaled as a proof of mechanism; that reuse was correct
as an experiment and is not the product.

Two distinct top families are planned:

- **Slab tops ("laje")** — flat utilitarian rooftops (concrete slab look).
- **Roof tiles ("telhado")** — tiled/shingled roof art, including the stepped
  ("staircase") sloped-roof profile (see §4).

Specification (to be finalized at ART-01 kickoff; recommendation is the
Overlord's, dimensions await Director ratification with a D-number):

| Property | Specification |
|---|---|
| File | `textures/defaults/roof_<material>.png` (naming to be confirmed at ART-01) |
| Dimensions | **512×512 px recommended** → a 32×32-voxel period (4×4 GUs). Hard constraint: each axis must be a **multiple of 128 px** (1 GU). |
| Color | Grayscale (B2), same as facades |
| Projection | **Isotropic — no vertical pre-scale.** Both axes of a horizontal surface are ground axes at 16 texels/voxel. The compositor's roof path (`_get_roof_plane_source`) already handles this. |
| Anchoring | Structure-local: the pattern anchors to each building's connected roof component (`Slab.texture_anchor`), so identical structures render identical roofs and no world-line seams appear. Already shipped mechanism (ROOF-BAKE-02c). |
| Wrap | Mirrored, same as facades |
| Step faces | Stepped-roof art must design the exposed 1-voxel step face (the "testeira" band) as part of the texture concept — see §4. |

Plumbing change required (small, scoped in ART-01): `BakePolicy` gains a
separate `roof_facade_for_material` map; the compositor's pinned roof source
dimensions move to the ratified values.

---

## 4. Stepped Roofs — 1-Voxel Roof Tiles (PLANNED — ART-01)

Feasibility confirmed 2026-07-16 against the shipped geometry. Key facts:

- A `Slab` is already exactly 1 voxel high; the current flat roof is a stack
  of 2 slab levels (`ROOF_LEVEL_COUNT`, `room_builder.gd`). Stacked slabs at
  successive levels are shipped, tested, and independently destructible.
- A sloped roof is therefore **a generator concern, not a new mechanism**: a
  "roof profile" emits slabs with partial (strip) footprints at ascending
  levels. `SlabGenerator` already supports variable footprints (that is how
  border growth works).
- **Visual slope math:** one level of rise = 20 px on screen; one voxel of
  horizontal advance = 8 px on screen. A step every 1 voxel reads near-
  vertical; **a step every 2 voxels is the expected minimum readable pitch**.
  Final pitch is a Director art call, decided against a PLAYGROUND fixture.
- **Budget guard:** stepped profiles multiply roof voxel count roughly 3–4×
  (PLAYGROUND flat baseline: 7,778 roof voxels). Cost is bake/placement/
  memory, not per-frame (D12 holds), but ART-01 includes a measured budget
  spike before stepped roofs become a default.

---

## 5. Voxel Objects — Props Dictionary (PLANNED — ART-01)

**Canon (Director, 2026-07-16):** every game element other than walls,
roofs, and floors exists as **one GU or a whole multiple of GUs**. No new
exotic geometry. All objects (props, furniture, containers) are voxel
objects built from dictionary materials; every voxel is a native Godot tile,
individually destructible, predictable, verifiable.

The object schema already exists — `godot/scripts/systems/prop_def.gd`
(JSON files in `props/`, e.g. `props/crate_full.json`):

| Field | Meaning | Authoring rule |
|---|---|---|
| `id` | Unique object id | snake_case |
| `size_vox` | `[x, y, z]` voxel dimensions | **Every axis a multiple of 8** (GU rule) |
| `layers` | Per-level occupancy bitmask: 8-char rows of `0`/`1`, rows separated by `/`, one string per level | Exact row/level ordering is **not yet pinned** — pinning it (with a D-number) is an ART-01 deliverable; do not author multi-layer objects before that |
| `material_zones` | Zone → material id from the materials dictionary (§6) | Only dictionary materials |
| `footprint_gus` | GU cells occupied, relative to anchor | Whole GUs only |
| `storeys` | Rendered solid height | — |
| `gameplay` | `cover` (`full/half/quarter/none`), `destructible` | — |
| `tags` | Classification | — |

**Current limitation (why this is PLANNED, not SHIPPED):** the v1 renderer
ignores `layers` and renders props as solid GU blocks. ART-01's renderer v2
consumes `layers` voxel-by-voxel through the existing placement pipeline
(`_set_voxel_cell`) — which, per architecture Rule 8, grants baking, theming,
and destruction for free. Multi-GU objects additionally require
footprint-aware rotation in `perspective_mapper` (known gap, recorded
2026-07-16; all shipped props are 1×1).

### Open-source voxel models (.vox import)

Open-source MagicaVoxel models **do not work directly** — two conversion
gaps, both scoped in ART-01:

1. **Palette → material curation.** `.vox` uses an arbitrary 256-color
   palette; INFILTRAITOR uses a small materials dictionary. Every import
   requires a curated palette-to-material mapping — this is editorial work
   per asset, not automation.
2. **Scale normalization.** Community models come in arbitrary sizes
   (16³, 32³, 126³…). The converter must normalize to whole-GU multiples
   (crop, pad, or downsample — per-asset decision).

The converter itself (`.vox` → PropDef JSON, offline Python tool under
`tools/`) is small; the format is simple and well documented. Licensing:
only assets whose license permits redistribution in a commercial project
(CC0 preferred); record source + license per imported asset in the object's
JSON (field to be added at ART-01).

---

## 6. Materials Dictionary (PLANNED — ART-01)

Today "what is a material" is scattered across three places:
`BakePolicy.DEFAULT_FACADES`, the compositor's material registry, and
`material_zones` in PropDefs. ART-01 consolidates this into a single
authoritative **materials dictionary** — the single writer of material
truth. Planned `MaterialDef` shape (schema finalized at ART-01):

| Field | Purpose |
|---|---|
| `id` | Canonical material id (`concrete`, `stone`, `wood`, `metal`, …) |
| `wall_facade` | Facade file for vertical surfaces (§2) |
| `roof_facade` | Dedicated top texture (§3) |
| `base_color` | Runtime tint for MULTIPLY blend |
| Gameplay properties | HP/damage class, sound signature, debris behavior (destruction phase) |

Rule: once the dictionary exists, `BakePolicy` and every other consumer
**read** it; nobody keeps a private copy of material truth (anti-split-brain).

---

## 7. Damage Decals (SHIPPED — wired; final art pending)

Impact art for the destruction system. Director diagrams, 2026-08-02.

The Director authors **flat, unprojected decals**; the runtime
(`VoxelRenderer`, D33) projects them onto voxel faces and composites them
live, at room load — never pre-projected, and never pre-composited to a file
either (D33 Part 4c retired the `composites/` staging folder this section
used to describe; see below). Art is never pre-projected — §1's rule, and
the same division of labour `bake_compositor.gd` already has with facades.

| Property | Specification |
|---|---|
| File | `ASSETS/ISOMETRIC/source_assets/voxels/decals/decal_<family>_<material>_<n>.png` |
| Dimensions | **256×256 px, square** — 16× the pinned `TEX_AUTHORING_N` density |
| Aspect | **Square, always.** A voxel face is square in flat space. The ×20/16 vertical stretch onto a lateral face is applied by the generator, never by the art (§1) |
| Alpha | **Required.** The decal is a mark on a face, not a face — everything outside the mark is transparent. Its alpha is clamped to the substrate's silhouette on composite (invariant B3): a decal can never enlarge a voxel |
| Color | Full color allowed (these are not facade/pattern sources, so B2 does not bind them) |
| Families | `bullet` (firearms), `dent` (explosions, on half voxels), `crack` (explosions, on whole voxels) |
| Variants | **3 per family per material**, fixed. Runtime picks one by hashing the voxel's base coordinates, so the choice survives rotation and repaint |
| Materials | `concrete`, `metal`, `stone`, `wood`, plus `earth` for `dent` only. Glass and brick deferred (glass gets no DENTED/CRACKED tier at all — destroyed or intact) |

**Which material needs which family — 33 files total:**

| Family | Materials | Files | Why not the others |
|---|---|---|---|
| `bullet` | concrete, metal, stone, wood | 12 | Firearms hit walls only |
| `dent` | concrete, metal, stone, wood, **earth** | 15 | `earth` is the shared floor dent every ground material routes to (D26) |
| `crack` | concrete, stone | 6 | D32.6 — metal and wood do not fracture, only dent or take bullets |

An explosion never produces a bullet hole (D32.7), so `dent` and `crack` must
read as chipped/fractured, never as a round puncture — at 16×20 px on screen a
gently perturbed circle still reads round, so the shape needs visible facets.

**Where each family lands** — one decal, two destinations, and the geometry
decides which stretch applies:

| Destination | Native size | Stretch from the square source |
|---|---|---|
| Lateral face (SW/SE) of a whole voxel | 16 × 20 | ×20/16 vertical (canon) |
| Cut plane of a lateral half voxel | 16 × 20 | ×20/16 vertical |
| Top diamond of a whole voxel | 16 × 16 | none — 1:1 |
| Sunken top of a floor half voxel | 16 × 16 | none — 1:1 |

**Placement rules** (Director, 2026-08-02) — each mark in its own place:

- A **bullet** only ever hits a wall, and marks exactly the **one lateral
  face** it struck. Never a top face, never a floor, never a ceiling.
- A **wall** dents laterally only (`left`/`right`), never top or bottom.
- A **floor** dents from above only (`top`); a **ceiling** from below only
  (`bottom`).
- A **ceiling** half voxel is **silhouette only** — an isometric camera never
  sees a voxel's underside, so no decal is composited onto it.
- **CRACKED covers all three visible faces of a whole voxel.** A voxel that
  nearly became DENTED and is barely holding together cannot read pristine on
  one side and shattered on the other. There is no single-face cracked voxel.
- DENTED and CRACKED are mutually exclusive; a voxel is one or the other.

**Half voxels** (`voxel_<material>_half_<left|right|top|bottom>.png`) are
generated from the material's own atom. Not read by the runtime any more
(D33 Part 4b builds the carved substrate live from the flat material atom
instead — `HalfVoxelCompositor`), kept as authored INPUT art per
ASSET-LAYOUT-01's own rule regardless.

`voxels/manifest.json` is the machine-readable copy of the counts above
and is what runtime reads for variant discovery — never a directory scan,
which does not survive export packing.

The voxel source tree is split by what the pipeline does with a file —
`materials/`, `halves/` and `decals/` are INPUTS the generator never
overwrites. **There is no OUTPUT folder any more** — `composites/` (a pure,
always-rebuilt derivative) was retired in D33 Part 4c (2026-08-03): every
damage mark composites LIVE at room-load time now, straight from these three
INPUT folders, never pre-baked to a file. The rule and the reasoning live in
that tree's own `ASSETS/ISOMETRIC/source_assets/voxels/README.md`
(ASSET-LAYOUT-01).

**After dropping new art**, run the generator and let Godot reimport before
launching, or the new PNGs fail to load and every affected voxel hard-errors at
boot (invariant B6 — a missing asset is loud, never a silent fallback):

```
python3 tools/asset_generation/generate_voxel.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Runtime side (for whoever changes it next): `damage_variant_material()` names
the pseudo-material, `VoxelRenderer._set_voxel_cell()`'s plan parsers
(`_full_voxel_decal_plan`/`_half_voxel_decal_plan`/`_floor_sunk_decal_plan`/
`_ceiling_carve_plan`) recognize it and pick the composite path, and
`voxel_decal_selftest.gd` asserts every name the plan parsers can produce has
a loadable asset behind BOTH the photographic decal path and the generic
vector-mark path below — so adding a corner of the matrix with no art behind
it fails the suite instead of failing on screen.

### Generic vector marks (procedural — nothing to author here)

A generic (flat, unbaked) voxel — `BakeConfig.enabled == false` (the release
canon), or simply no baked atom available for a given cell — never wears the
photographic decal art above (Director, 2026-08-03: "não queremos texturas
sendo aplicadas em voxels genéricos"). Instead it gets a **material-agnostic,
procedurally generated** vector mark: `generate_generic_bullet_decal()` /
`generate_generic_bullet_crack_decal()` / `generate_generic_blast_dent_decal()`
/ `generate_generic_blast_crack_decal()` in `generate_voxel.py`, 3 variants
each, written to `decals/decal_generic_<kind>_<n>.png` — 12 files total,
never per-material (that is the whole point: one set works on any material's
flat colour, at 70% ink opacity so the material's own colour still reads
through). **Nothing here is Director-authored** — there is no art to drop in,
no filename to override; regenerating always overwrites these (unlike every
other file in `decals/`). If a future pass wants real per-material generic art
instead, that is a new design conversation, not a file drop.

---

## 8. Invariants That Bind All Art

Full detail: `docs/technical/BAKE_SYSTEM_REFERENCE.md`.

- **B2 — Grayscale:** all `facade_*` and pattern sources are grayscale
  (R==G==B). Color is a runtime material property.
  **D34 (2026-08-08):** one `facade_<material>.png` now serves that
  material's WALL, ROOF **and FLOOR** — authoring a separate ground texture
  for a structural material is no longer a thing. The only full-color
  sources left are `slab_<material>.png` for organic ground (grass, dirt,
  sand, gravel — materials with `has_facade: false`), where hue is the
  material's identity and grayscale cannot carry it.
  Facades stay 1024×512; the compositor reaches the 1024×1024 a horizontal
  surface needs by mirroring the art vertically, so **do not pre-square a
  facade** — same rule as never pre-stretching for projection (§1).
- **B3 — Alpha from canon:** silhouette alpha always comes from the
  canonical voxel texture; art never carries silhouettes.
- **B6 — Loud-fail:** a missing or malformed asset must hard-assert at
  bake, never fall back silently. Ship no asset that "mostly works."
- **D12 — Mobile budget:** all procedural cost at bake time; art decisions
  that would add per-frame cost need explicit Director sign-off.
- **16 texels/voxel** (`TEX_AUTHORING_N`) is pinned. Changing it is a
  canon change (stop-and-report), not a tuning knob.

---

## 9. Governance

- This document lives at `ASSETS/ART_SPECIFICATIONS.md` and is owned by the
  Director (ratification) and the Overlord (maintenance).
- Sections marked PLANNED are ratified **direction**; numbers inside them
  marked "recommended" await a D-number at ART-01 kickoff before any asset
  is produced against them.
- Amendments follow the same rule as context files: pinned values change
  only by Director ratification, recorded in the active master plan's
  decision register.
