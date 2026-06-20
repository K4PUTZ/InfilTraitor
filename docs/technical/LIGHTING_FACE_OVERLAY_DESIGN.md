# Lighting & Face Overlay — Design Decisions

**Session:** 2026-06-20
**Status:** Design consolidated. The implementation attempts (FL-01 → FL-01d) are being
**rolled back** to the pre-session code state. This document is the source of truth for a
clean re-implementation. It records every design decision we settled, the canonical numbers,
the architecture, and the engineering pitfalls discovered during the failed attempts so the
redo avoids them.

---

## 1. Milestone ordering

AI and the detection system are **deferred** until the WORLD/rendering system is complete.
The agreed order of work:

1. **Wall & object lighting** — dynamic per-face light/shadow (the face overlay). *This is the
   current focus.*
2. **Occlusion / cutaway** — hide walls/objects in front of the character so the actor stays
   visible (see §9).
3. **Modifiable lights** — break a lamp, toggle lights on/off in real time, flicker. The
   foundation exists in `LightSource` (energy/flicker/break) but is not yet wired into the
   scene.

Crates can vanish entirely (all bands HIDDEN) and don't strictly need partial banding, but
terrain obstacles will naturally exist at 1/4, 2/4, 3/4 heights, so the **band method must be
built and kept ready** for them.

---

## 2. Core lighting model — FLAT + OVERLAY

This is the central decision and everything else follows from it.

- Assets are authored **flat-lit**: uniform faces, **no baked directional shadow**. The only
  per-asset shading allowed is a subtle edge line for readability.
- At runtime, each **visible face** is tinted dynamically from the active light direction:
  - **MULTIPLY** on the side facing away from the light (darkens), strength ∝ how shadowed.
  - **SCREEN / ADD** on the side facing the light (brightens), with a faint glow on a strongly
    lit top face.
  - **Neutral brightness ⇒ no tint** — the sprite shows through unchanged.
- Brightness per face = light-direction · face-normal, attenuated by distance, aggregated over
  active lights. This is computed by the overlay module itself from the light data (it is a
  read-only consumer), independent of the floor `ExposureSystem`.
- Because lighting is a *tint* (a delta with a blend mode), it composes over textured assets
  without replacing them — the grain survives the multiply/screen. **Verified** via a blend
  proof on wood and concrete.

Rejected alternative: baked directional shadows in the asset. They cannot stay coherent with a
moving/breaking light, which is the whole point of the system.

---

## 3. Texture strategy

- **Texture is baked into the PNG** (wood for crates, concrete for walls); the dynamic light
  is the solid tint overlay on top. Static texture + dynamic light separated this way costs the
  minimum at runtime (GPU just samples the texture; the tint is a few blended quads on light
  change).
- **Vector-in-game texture: rejected.** Drawing grain procedurally would redraw texture
  geometry on every repaint for zero gameplay benefit. Vector would only pay off for infinite
  procedural variation, which tactical placeholders don't need.
- **Stable Diffusion: rejected for these assets.** SD produces *baked* lighting (the exact
  thing we remove), can't hit exact pixel dimensions, gives no clean alpha edges, and varies
  across a set. SD may later add *detail/texture* painted over the flat base — never the
  dimensional base itself.

---

## 4. Height model — integer floor grid + quarter-band vertical axis

There are **two independent axes**, and conflating them (via per-sprite "nudges") was the
original floating-crate bug.

- **World grid (the floor / chão):** cell `(x, y)` + **integer** floor level. Quarters do
  **NOT** subdivide this grid. Stacking = increment the floor level by 1 per full block.
- **Vertical face axis:** every floor of vertical face is internally subdivided into **4
  quarter-bands** (1/4 floor each). This is **universal** — even a full 4/4 block is banded —
  so cover heights, posture, and occlusion cutaway are honored without touching the world grid.

Asset body height is expressed in **quarters**:

| Quarters | Meaning |
|---|---|
| 0 | flat floor (shallow ground) |
| 1/4 | crawl cover / base stub (the part that stays lit when the top is occluded) |
| 2/4 | crouch cover |
| 3/4 | high cover / standing cover |
| 4/4 | full block = exactly 1 floor |

- Visual position is **derived** from `(cell, floor_level, quarters)` by one formula:
  `y = iso(cell, floor_level) − (quarters/4) · storey_px`. **No per-sprite nudges** (they
  accumulate drift and leave a phantom empty tile on top of a stack).
- A full block = exactly 1 storey ⇒ a stack of N full blocks = N storeys, seamless, no gap.
- Each band carries a **visibility state** used by occlusion: `FULL` / `GHOST` (multiply 50%) /
  `HIDDEN`.

---

## 5. Canonical dimensions

Derived from the in-engine tile (256×128, confirmed in `room.gd:_draw_shadow_debug`,
`hw=128 hh=64`).

| Quantity | Value |
|---|---|
| Tile / top diamond | 256 × 128 px (2:1 isometric) |
| Diamond half-extents | `tile_half_w = 128`, `tile_half_h = 64` |
| `storey_px` (1 floor) | **128 px** |
| quarter (1/4 floor) | **32 px** |
| Canvas width (always) | 256 px |
| Canvas height | 128 (top) + body |
| Anchor (sits on cell center) | base diamond center = `(128, 64 + body)` |

`storey_px = 128` was chosen because it divides cleanly by 4 (→32) and 8 (→16) and reads as a
cube in 2:1. Alternatives if a squatter floor is ever wanted: 96 (quarter 24) or 112 (quarter
28). **`storey_px` MUST come from a single shared source** consumed by both the placement code
and the face overlay — if the two diverge, the tint and the sprite stop aligning.

Top-diamond corners for cell center `c = floor_layer.map_to_local(cell) + VISUAL_GRID_OFFSET`
(offset applied exactly **once**):
`top = c+(0,−64)`, `right = c+(128,0)`, `bottom = c+(0,64)`, `left = c+(−128,0)`.
Side faces extrude **down** by `storey_px` per floor, `quarter_px` per band.

---

## 6. Asset set spec

Flat, transparent (RGBA), exact dimensions, uniform faces + edge line + (optional) faint
quarter guides on the body.

| Asset | Body px | Canvas | Anchor (x,y) |
|---|---|---|---|
| `floor_tile_0q` | 0 | 256 × 128 | 128, 64 |
| `cover_1q_crawl` | 32 | 256 × 160 | 128, 96 |
| `cover_2q_crouch` | 64 | 256 × 192 | 128, 128 |
| `cover_3q_stand` | 96 | 256 × 224 | 128, 160 |
| `block_4q` | 128 | 256 × 256 | 128, 192 |
| `crate_wood_4q` | 128 | 256 × 256 | 128, 192 |
| `wall_concrete_face` | — | concrete texture for wall faces | — |

---

## 7. Module architecture — dedicated `FaceLightingController`

The face overlay is a **separate module/controller**, NOT folded into `room_layout_builder`.

Rationale — **dual invalidation with different cadences**:
- Lighting change (rare): light breaks/flickers, perspective rotates ⇒ `lighting_rebuilt`.
- Viewer/agent change (frequent, per step): occlusion cutaway, posture.

`room_layout_builder` is a *static* builder (runs on map load / perspective switch). Mixing
frequent dynamic repaint into it violates the modularization the project already established.

Contract:
- The controller **owns its own draw `Node2D`(s)** and exposes `repaint()`.
- It is a **read-only consumer** of light data; it reads only `room`-owned fields plus a light
  snapshot passed in by `room`. **No module-to-module reach** (hub-and-spoke: `room` is the
  only caller into it, mirroring `_repaint_world_shadows`).
- Driven by `room._repaint_faces()` connected to `lighting_rebuilt`. This signal connection is
  the on-the-fly hook; occlusion/posture triggers later plug into the same entry point.
- **Two blend layers**, each with its own `_draw` handler (Godot only allows drawing into the
  node whose `draw` signal is currently firing):
  - `_mul_layer` — `CanvasItemMaterial.BLEND_MODE_MUL` (darkens shadowed faces; `g→1` = no-op).
  - `_add_layer` — `CanvasItemMaterial.BLEND_MODE_ADD` (brightens lit faces; `a→0` = no-op).
- The face geometry is parameterized by **footprint** so the same banding/lighting serves both
  cell-centered props (cube faces) and edge-aligned walls (§8).

Lighting is **cached** (rebuild only on light change); occlusion is a separate cheap per-step
pass that modulates the cached result. This separation is *why* the module is dedicated.

---

## 8. Wall asset class — thin, edge-aligned

Walls are a different footprint from cube props:
- A wall is a **thin slab (~1/4 tile thick)**, positioned on a **grid edge** (between two
  cells), **half to each side** of the edge — not cell-centered.
- The per-face lighting math is identical (dot of light direction with the face normal); only
  the polygon footprint differs (thin edge quad vs cell diamond). The quarter banding is the
  same.
- Therefore the `FaceLightingController` must accept two footprint types and reuse the band
  lighting for both.

---

## 9. Occlusion model — view-only cutaway

When the actor moves **behind** a wall/object:
- Cut the **top 3/4** of the wall on the actor's floor + the **full 4/4** of walls on the floor(s)
  above; keep the **bottom 1/4 `FULL`** (the lit "base stub") so the actor reads against it and
  can occupy that space (lean, crouch — pose refinement is later).
- Show only the bottom 1/4 when the actor is behind, **regardless** of the wall's total height
  (2/4 or 4/4).
- "Cut" = **MULTIPLY blend at 50% opacity** (`GHOST`), not full transparency, so the wall is
  still sensed. The occluded selection can widen by 1–2 adjacent walls.

### Orthogonality (the answer to "does occlusion break lighting/faces?")

No — lighting and occlusion are **independent axes** and compose cleanly:
- **Lighting** decides a band's base tint (multiply/screen by light direction). Light-driven,
  viewer-independent, **cached** (recomputed only on light change).
- **Occlusion** decides a band's visibility (`FULL`/`GHOST`/`HIDDEN`). Viewer-driven,
  light-independent, a **cheap** per-step pass.
- They layer: paint the lit band, then apply the occlusion ghost (multiply 50%) on top. If they
  were entangled, every agent step would force a full relight — the separate module avoids that.

### Inviolable rule

**Occlusion is purely a render operation.** A ghosted wall is still **solid for the world**: it
keeps blocking light, casting shadow, and blocking LOS. Occlusion modulates the overlay
alpha/blend **only** — it must **never** write `blocked_cells`, the `ExposureSystem`, or LOS
data. (Removing a wall from `blocked_cells` to "hide" it would silently break shadows and
vision.) This must be grep-enforced in the implementation acceptance.

### Draw order

Solid lower bands → actor → ghosted upper bands (multiply 50%), so the actor shows through the
ghosted portion (≈50% visible).

---

## 10. Asset generation pipeline

- **SVG → PNG** (cairosvg) for the flat geometry; **Pillow** for baked texture (wood grain,
  concrete speckle, affine-warped per face). Pixel-exact, flat, regenerable. Single calibration
  knob `STOREY = 128`.
- **Do NOT have the Operator regenerate assets via Python inside the project.** A Godot repo
  typically lacks cairo/cairosvg, so in-project generation fails and tiles fall back to missing
  textures (the black-artifact symptom). **Commit the pre-generated PNGs** and have the Operator
  only import + wire them. Keep the generator script in the repo as documentation/repro, not as
  a build dependency.

---

## 11. Implementation roadmap (prompt sequence)

The clean re-implementation should proceed in small, grep-verifiable steps, validating each
before the next:

1. **Assets in place** — commit the pre-generated flat PNGs; import + reference them; demo
   crates use `crate_wood_4q`, floor uses `floor_tile_0q`. No procedural fallback.
2. **`FaceLightingController` scaffold** — owns its draw node, `repaint()` wired to
   `lighting_rebuilt` via `room._repaint_faces()`; the face-brightness model; **gated behind a
   default-OFF debug flag**; render validated on **ONE cell** first.
3. **Tint-blend** — `_mul_layer` (MUL) + `_add_layer` (ADD), neutral = no-op; `storey_px = 128`
   from the shared source; faces clad the flat sprite exactly (no oversize, no spill).
4. **Stacking** — placement at `storey_px` steps, anchored at base-diamond-center; N blocks = N
   storeys seamless.
5. **Scale up** — enable for all in-bounds occluders; confirm the full demo is clean.
6. **FL-02 thin-wall footprint** — edge-aligned wall slabs in the same band system.
7. **FL-03 occlusion** — per-band `GHOST`/`HIDDEN`, view-only, the inviolable rule enforced,
   correct draw order.

---

## 12. Engineering pitfalls discovered this session (avoid in the redo)

These caused the chaotic renders and the rollback:

1. **Procedural opaque fill instead of a tint.** FL-01 drew faces as solid polygons over the
   sprites (white cubes) instead of a multiply/add delta. The overlay must be a *tint*; neutral
   leaves the sprite untouched.
2. **Uncalibrated `storey_px` ⇒ floating/oversized faces.** Faces were taller than the sprites.
   `storey_px = 128` must match the asset body height, from a single shared source.
3. **Oversized diamonds.** Faces came out larger than a tile — caused by using full extents
   (256/128) instead of half (128/64), or applying `VISUAL_GRID_OFFSET` twice. Always:
   half-extents 128/64, offset once. Add a one-cell self-check that asserts the diamond is
   256×128.
4. **Drawing buffer / perimeter cells.** The overlay iterated blocked cells including the buffer
   ring and perimeter walls, painting off-map hatching and smears. Restrict scope to in-bounds
   prop occluders; exclude `INNER_ORIGIN`/`BUFFER` and the perimeter ring.
5. **ADD blowout to white.** When over-tall faces spilled onto the bright floor, ADD saturated.
   Once geometry is correct the tint lands on the sprite, not the floor; still cap add alpha
   (`add_alpha_max ≈ 0.30`) as a safety.
6. **Draw-context crash.** A single handler tried to draw into both blend layers; Godot only
   allows drawing into the node whose `draw` signal is firing. Use **one handler per layer**.
7. **Asset swap silently not landing** ⇒ tinting baked legacy sprites (double shading) and/or
   missing crates. Verify the texture path resolves; never fall back to procedural.
8. **Band-separator lines streaking.** Drawn in the wrong (non-face-local) space. Defer the
   separators until geometry is verified; re-add as face-local short segments.
9. **Disappearing crates / misplaced wall corner tiles** (latest build): the swap removed the
   legacy sprites before the flat ones were correctly wired, and the perimeter/edge geometry was
   off. Handle asset wiring and wall-edge geometry explicitly in the redo (§8).

**Debugging discipline:** stop scaling the overlay across the whole map. Get a clean base
(assets loaded, overlay OFF), then enable the overlay on a **single cell** and verify its
geometry against the spec before re-enabling globally.

---

## 13. Existing foundation this builds on

(Confirmed during the codebase audit — unchanged by the rollback.)

- Lighting pipeline is unidirectional: `LightRegistry → ShadowProjector → ExposureSystem →
  overlays/gameplay`. `LightingController` owns it and emits `lighting_rebuilt`.
- `room.gd` already connects `lighting_rebuilt` → `_repaint_world_shadows()` (floor shadows via
  the `_tile_shadow` overlay, `BLEND_MODE_MUL`) and → `_vision_controller.request_redraw`. The
  face overlay's `_repaint_faces()` mirrors this pattern.
- Hub-and-spoke contract: `room.gd` calls controllers directly; controllers signal back; no
  module-to-module calls except the one permitted signal. The face overlay respects this.
- Buffer architecture: `MAP_SIZE` 28×46, `BUFFER = 5`, `INNER_ORIGIN = (5,5)` — the overlay must
  exclude buffer cells.
- `LightSource` already carries energy/flicker/break state for the future modifiable-lights
  milestone.
