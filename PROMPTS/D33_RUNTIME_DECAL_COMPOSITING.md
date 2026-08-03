# D33 — Runtime decal compositing over the real baked facade

**Status:** ✅ **Part 3 fully done (2026-08-03) — every impact-mark shape
(full-voxel CRACKED, wall/floor/ceiling DENTED) now composites onto the
real baked facade instead of losing it to the flat generic material.** Part
0 viable (§9 wrong, §10 corrected); §11 explains why ROTATE-KILL-01 removed
the harder of §10's two open design points; Parts 1, 2, 3a/b/c/d all done.
**Remaining: Part 4 (retire the 97 pre-composited PNGs `composites/` held —
the whole reason ASSET-LAYOUT-01 split that folder out) — not started.**

---

## 1. Why — the one thing this buys that nothing else can

Today a damaged voxel on a photographically baked wall **throws its baked pixels
away**. `_set_voxel_cell()` short-circuits every impact mark past the baked
lookup (`voxel_renderer.gd:1040,1052`) and falls through to the generic material
atom, so a bullet hole in a concrete facade renders as a flat grey cube with a
hole in it, sitting in the middle of a photographic wall.

That was correct when an impact mark was a whole pre-drawn atom — it had no way
to know what it was sitting on. Under D32 the mark is a **decal**, and a decal
composited per cell can be stamped onto that cell's own baked atom.

The file-count saving (97 PNGs) and the iteration-speed saving (no generator run,
no reimport) are real but secondary. **The facade preservation is the reason to
do this.**

---

## 2. What is true today — measured, not recalled

| Fact | Value | Where |
|---|---|---|
| Baked atom size | 32×36 | `BakeCompositor.VOXEL_ATOM_W/H` |
| Baked page | `PAGE_W` 4096 × (tile_rows × 36) | `bake_compositor.gd:54` |
| Page → TileSet source | one `TileSetAtlasSource` per page, `texture_region_size (32,36)`, tiles created per used coord | `VoxelRenderer.register_baked_atlas_page()` |
| Baked sources are **transient** | `_baked_source_ids` is cleared on every rebuild; **every rotation re-bakes** | `voxel_renderer.gd:524-529` |
| `BakeConfig.enabled` | **`true`** today (canon says flip to `false` before release) | `bake_config.gd:12` |
| Damaged cells already carry what `resolve()` needs | `process_dirty` passes `edge`, `voxel_xy`, `slice.face` | `voxel_renderer.gd:1438` |
| Alternative-id space | 1536 of 4096 used (12 buckets × 64 soot × 2 flips); light alts minted **lazily** | `voxel_renderer.gd`, `_ensure_light_alt` |

**Scale, measured on a real PLAYGROUND detonation (bomb index 0):**

```
one grenade:  wall dented 54 · wall cracked 44 · floor dented 99  = 197 cells
197 × 32×36 RGBA (4608 B) = 886 KB of unique composites, per grenade
```

That is the number the design has to survive, and it is why "one TileSet source
per damaged cell" is not an option.

---

## 3. The constraint nobody has priced yet

**Baked sources are rebuilt on every rotation, and damage persists across
rotations.** So the composite work is not paid once per detonation — it is paid
**again for every accumulated damaged voxel, on every camera rotation**.

Late in a mission at ~2000 damaged cells that is 2000 composites per rotation.
Rotation cost is already a tracked regression surface: VL-03-PERF moved light
alternatives to lazy minting precisely because eager minting dominated it.

**This is the risk that decides whether D33 ships at all, and it is unmeasured.**
Hence Part 0.

---

## 4. Part 0 — The measurement spike *(blocks everything; no code ships from it)*

Same discipline as `DESTRUCTION_MASTER_PLAN` Part 0. Throwaway branch,
throwaway code, three numbers.

**S1 — Cost of one composite in GDScript.** Build one 32×36 composite the real
way (read the baked atom region out of the page `Image`, `blit_rect` the
pre-sheared decal, clamp alpha to the substrate) and time 1000 of them.
*Needed because the shear decomposes into per-column `blit_rect` calls (16 for a
lateral face, 16+32 for a top face) — cheap in principle, unmeasured in
GDScript.*

**S2 — Reuse rate of baked atoms among damaged cells.** For a real detonation,
count `distinct (page, atlas_coords)` among damaged cells vs. total damaged
cells. A facade page has 64 atom columns with mirrored-repeat wrapping, so the
same atom may back many cells. **If reuse is high, a cache keyed on
`(page, atlas_coords, composite_name)` collapses the 197 into far fewer** and the
rotation cost in §3 largely evaporates. If reuse is ~1.0, it does not.

**S3 — Real rotation cost at scale.** Detonate N grenades, rotate, measure. Do
it at N = 1, 5, 15 to get the slope, not one point.

**Kill criterion:** if S1 × (cells after S2 reuse) exceeds **~150 ms** added to a
rotation at 15 grenades, the per-cell approach is dead in this form and the
fallback is §7.

---

## 5. Parts, assuming Part 0 clears

### Part 1 — The composite cache and its page

**Status: ✅ DONE 2026-08-03.**

- `godot/scripts/geometry/damage_composite_cache.gd` — `DamageCompositeCache`,
  a `RefCounted` owned lazily by `VoxelRenderer` (`get_damage_composite_cache()`).
  Dynamic page, default 2048×2048 (64 cols × 56 rows = 3584 slots at 32×36),
  overridable so a selftest can force page-overflow without allocating
  thousands of composites. `store(key, composite_image)` allocates a slot
  (growing to a new page when full) and blits; a repeat `store()` with an
  already-seen key is a pure cache hit. `resolve(key)`/`has(key)` mirror
  `BakedTileLookup.resolve()`'s shape. **Key is a caller-supplied opaque
  `String`** — this class does not know or care what a key means; Part 3
  owns constructing one that is base-space + physical-face + decal-name, per
  §11.
- `voxel_renderer.gd` gained two new methods, deliberately mirroring
  `register_baked_atlas_page()`'s shape rather than inventing a second one:
  `register_damage_composite_page(image)` (registers an empty dynamic
  `TileSetAtlasSource`, appends to `_baked_source_ids` — same list, same
  lifetime, same cleanup) and `add_damage_composite_tile(source_id, image,
  atlas_coords)` (creates one tile + re-uploads the page texture via
  `ImageTexture.update()`).
- `prune_baked_sources()` now also resets the damage composite cache — no
  second cleanup path: the page *sources* die via the existing
  `_baked_source_ids` loop, and the cache's own bookkeeping (Dictionary +
  in-memory `Image`s, which that loop can't see) is reset alongside it.
- **Evidence**: `godot/scripts/tools/damage_composite_cache_selftest.gd`,
  16/16 PASS — empty-state reporting, idempotent repeat `store()`, two keys
  landing in distinct slots with verified non-bleeding pixels (read back from
  the real page `Image`, not assumed), a wrong-sized composite rejected
  (B6-style `push_error`, state untouched), page overflow at a forced 2-slot
  page boundary with all three keys still resolving correctly across it,
  `reset()` clearing state, and — the one that exercises the real integration
  point, not just the standalone class — `VoxelRenderer.prune_baked_sources()`
  (`room_builder.gd:716`'s real call site) actually driving the reset.
  `project_lint`, `check_invariants`, `gen_codemap --check`, `run_selftests`
  (21/21) all clean.
- **What Part 1 deliberately does not do**: no pixel compositing (Part 2, the
  Python↔GDScript shear/alpha-clamp port), no `_set_voxel_cell()` wiring
  (Part 3 — today's decal path is completely untouched), no real key
  construction (opaque string, Part 3's job). Rule 8 intact: this only ever
  registers a `TileSetAtlasSource`; nothing reaches the tilemap except
  through the same `set_cell()`/`_set_voxel_cell()` seam everything else uses.

### Part 2 — The GDScript compositor

**Status: ✅ DONE 2026-08-03.**

**Correction first**: this bullet list, as originally written, described the
wrong algorithm. "Lateral shear (resize ×20/16 + per-column shift), top shear
(H-shear then V-shear)" was a memory of what `bake_compositor.gd` does for
*facade* baking, assumed to also describe the decal path without reading it.
The real `generate_voxel.py` function (`_paste_decal`) is more general: it
inverse-maps every DESTINATION pixel into the decal's parametric `(s, t)`
space through an arbitrary parallelogram (not a fixed shear), 4×4-supersamples
each one against a Lanczos-pre-resized copy of the decal, and blends
premultiplied-then-unpremultiplied alpha. `blit_rect` was never going to be
enough on its own — there is no per-pixel inverse-mapping primitive in Godot's
`Image` API that does this; the port implements the same nested-loop math
`_paste_decal` does, not a `blit_rect` call.

**What shipped:**

- `godot/scripts/geometry/decal_compositor.gd` — `DecalCompositor`, two
  `static func`s: `paste_decal()` (the inverse-map + supersample + blend, line
  for line the same math as `_paste_decal`) and `compose_decal_voxel()` (B3
  clamp: composite onto a copy of the substrate, then force any pixel to
  `(0,0,0,0)` wherever the substrate itself was transparent — decal art can be
  clipped at a face's corners, but can never expand the canonical silhouette).
- `tools/asset_generation/d33_part2_fixture_gen.py` — a one-shot fixture
  generator that calls the REAL, unmodified Python functions
  (`generate_voxel_atom` for a genuine concrete substrate, a procedural
  soft-edged colour-gradient decal chosen to exercise partial alpha rather
  than an all-or-nothing mask, `compose_decal_voxel` itself) and writes
  `godot/scripts/tools/fixtures/d33_part2/{substrate,decal,reference_lateral,
  reference_top}.png`. The fixture is the ground truth; nothing about it is
  reimplemented independently on either side.
- **The equality measurement, not an assumption**:
  `damage_composite_cache_selftest.gd`'s sibling,
  `godot/scripts/tools/decal_compositor_equality_selftest.gd`, runs
  `DecalCompositor` on the fixture inputs and diffs the result against the
  Python-produced reference, pixel by pixel, over every pixel either image
  considers non-transparent. **Measured result: max channel difference = 1
  (of 255), 0 of 911 compared pixels differ at all beyond that** — far
  tighter than the tolerance guessed before measuring (12/channel, 5% of
  pixels; kept in the selftest's own comment as the record of the guess, not
  in the passing condition). Confirmed visually too: the GDScript and Python
  composites are indistinguishable at both the lateral and top targets, not
  just numerically close.
- **What the ~1-level residual almost certainly is, not guessed**: Godot's
  `Image.INTERPOLATE_LANCZOS` and Pillow's `Image.LANCZOS` are different
  implementations and were the predicted risk — they turned out to agree
  far more closely than expected on this fixture. The remaining ±1 is
  consistent with Python's round-half-to-even vs. Godot's round-half-up at
  8-bit quantization, reachable only at exact `.5` boundaries.
- A third selftest checks B3 independently of numeric closeness: even if the
  colour math ever drifted, no pixel outside the substrate's own alpha may
  gain alpha. Holds.
- `project_lint`, `check_invariants`, `gen_codemap --check`, `run_selftests`
  (22/22) all clean.

**What Part 2 deliberately does not do**: no `_set_voxel_cell()` wiring
(Part 3), no decision about composing at a scale other than the pinned
4× supersample (measured fine, not revisited), no change to
`DamageCompositeCache`'s key (still Part 3's job, per §11).

### Part 3 — Wire it into the seam

**Split into 3a (done) and 3b (not started) mid-session, 2026-08-03**, once
reading `generate_voxel.py` end to end (rather than working from memory)
showed this bullet list bundled two very differently-sized problems. Full
detail of what was found and why: the session record; the durable summary
lives here.

**Part 3a — full-voxel CRACKED marks. Status: ✅ DONE.**

The straightforward half: bullet-CRACKED (mark on the one lateral face
struck) and blast-CRACKED (mark on all three visible faces) both use the
**full voxel atom** as their substrate — no geometry carve, nothing D25's
`generate_half_voxel()` does applies here at all. Wiring these needed three
things, in `voxel_renderer.gd`:

- `VoxelRenderer._full_voxel_decal_plan(material_name)` — parses the pseudo-
  material string (e.g. `concrete_bullet_cracked_left_0`,
  `stone_blast_cracked_all_1`) into `{base_material, decal_family, variant,
  targets}`, returning `{}` for anything this slice doesn't cover (DENTED,
  clean materials) so the caller falls through unchanged. `DecalCompositor`
  gained named `FACE_TOP`/`FACE_SW`/`FACE_SE`/`FACE_SE_MIRRORED` constants
  (the vertex geometry, copied once from `generate_voxel.py`) as the single
  source of truth both this parser and the Part 2 selftest now reference.
- `VoxelRenderer._composite_full_voxel_decal(...)` — the real substrate read.
  **A correctness question surfaced here that neither Part 1 nor Part 2
  needed to answer**: baked facade pages are grayscale-plus-modulate
  (`BakeCompositor`/`_modulate_for_mode()` — the real material tint is a
  per-tile `TileData.modulate`, never baked into the page's own pixels), so
  reading the page back raw would produce a colourless substrate. Fixed by
  multiplying the substrate's pixels by the baked tile's own `modulate`
  *before* compositing, once — the stored composite already carries the real
  colour, the new tile registers with the default WHITE modulate, and
  `_ensure_light_alt()`'s existing lazy light-bucket minting (unmodified —
  it derives its multiplier from whatever the tile's own alt-0 modulate is)
  keeps dimming this tile correctly with zero new code.
- Cache key: `"%d,%d,%d,%s" % [grid_pos, level, material_name]` — safe as
  view-space rather than base-space *specifically because* Part 1's cache is
  reset every `build_from_layout()` pass (§11): grid_pos never has to mean
  the same thing across two rebuilds, because the cache never survives one.
- `_set_voxel_cell()` gained one new branch, inserted before the existing
  generic fallback, guarded by `is_impact_mark and bake enabled and edge !=
  null` — exactly the condition that used to skip straight to generic. Every
  other branch, and the generic fallback itself, is untouched.

**Evidence**: `godot/scripts/tools/decal_seam_selftest.gd`, 12/12 PASS —
plan parsing (including that `FACE_SE_MIRRORED` really is a different
parallelogram from `FACE_SE`, not the same one twice), the tint math verified
against real registered baked pixels, idempotent caching, DENTED and
clean-material names proven UNAFFECTED (still resolve to their pre-D33 id),
a missing-baked-atom case falling through cleanly, and the real
`_set_voxel_cell()` seam picking the composite end to end. Also run live on
real PLAYGROUND: `INFILTRAITOR_CAPTURE_ACTION=test_zone_detonate` produced
real `cracked` concrete voxels (`[BLAST] slice=SLICE_3_3_SW ... cracked=10`)
with **zero errors, zero missing-decal pushes** — the real
`decal_bullet_concrete_0.png`/`decal_crack_*.png` files loaded and composited
without incident. A tight, unambiguous before/after screenshot of the mark
itself was attempted and is **inconclusive at this capture's resolution/
framing** — a bullet mark's real footprint is small (~16×28 of a 32×36 atom)
against a busy soot/destruction backdrop, and getting the camera precisely
onto one specific damaged voxel needs more iteration than this session spent
on it. Recorded honestly rather than claimed: the numeric/functional
evidence above is solid, the crisp visual is a follow-up, not a substitute.
`project_lint`, `check_invariants`, `gen_codemap --check`, `run_selftests`
(23/23) all clean.

**Part 3b — half-voxel DENTED marks (wall left/right). Status: ✅ DONE
2026-08-03, same session.**

**A real bug surfaced first, in already-shipped Part 3a code, and was fixed
before 3b was built on top of it.** Building 3b's fixtures prints geometry
straight from the real Python constants (same discipline as Part 2's), and
the numbers didn't match `decal_compositor.gd`: `V_WB`/`V_EB` should be
`TILE_H + SIDE_H - TILE_H//2 = 28`, and the file had `26` — an arithmetic
slip. Undetected by Part 2's own equality selftest because its two targets
(`FACE_SE`, `FACE_TOP`) never reference `V_WB`/`V_EB` at all; `FACE_SW` and
`FACE_SE_MIRRORED` do, and those are exactly Part 3a's bullet-LEFT/bullet-
RIGHT targets — a passing suite with a real, silent coverage gap. Fixed
(`26 → 28`), and the fixture generator + selftest now also cover
`FACE_SW`/`FACE_SE_MIRRORED` — confirmed the new tests actually catch the
class of bug by reverting the constant by hand and re-running (28-29%
mismatch), then restoring the fix (5/5 clean).

**Then Part 3b itself.** `generate_half_voxel()` builds its LEFT/RIGHT
substrate by **polygon-masking**, not by decorating a full atom — the newly
exposed CUT FACE gets a flat, un-baked side tone, and the KEPT lateral-face +
KEPT top-diamond regions are copied from the atom masked by
`_KEPT_RIGHT_FACE`/`_KEPT_TOP_HALF` (mirrored for "right"). Pillow's
`Image.paste(source, (0,0), mask)` has no direct Godot `Image` equivalent, so
this needed a genuinely new primitive, not a wiring change:

- `godot/scripts/geometry/half_voxel_compositor.gd` — `HalfVoxelCompositor`:
  `paste_masked()`/`fill_masked()` (point-in-polygon per destination pixel,
  no resampling — a different primitive from `DecalCompositor`'s projected/
  sheared paste) and `build_half_voxel_substrate(kept_atom, cut_fill, side)`,
  a direct port of `generate_half_voxel()`'s left/right branch.
- **Measured, not assumed, and NOT a clean bit-match** — the one real
  imperfection in this whole plan so far: point-in-polygon (even-odd,
  top-left-corner sampling — measured better than pixel-centre, 24→12
  mismatches) disagrees with Pillow's own scanline polygon fill on **1.94%**
  of LEFT's boundary pixels and **6.40%** of RIGHT's (mirrored polygons don't
  inherit Pillow's fill bias symmetrically — tried and rejected several fixed
  offsets for the mirrored case, best found 33/641, still short of LEFT).
  Confined to a 1px-wide diagonal seam at the shape's own OUTER edge (the
  shared edges between kept regions line up correctly); confirmed
  **visually indistinguishable** at real scale side-by-side against the
  Python reference despite the measured gap. Closing this fully means
  reimplementing Pillow's specific C scan-fill algorithm rather than tuning
  a generic point test — flagged as a known, accepted limitation, not
  chased further this session.
- `VoxelRenderer._half_voxel_decal_plan()` — parses `bullet_dented_left/
  right_N` and `blast_dented_left/right_N` (raw decal family is "bullet" for
  the former, **"dent" not "blast"** for the latter, matching
  `generate_voxel.py`'s `DECAL_FAMILIES` naming); `{}` for CRACKED (Part
  3a's), floor `_top`, ceiling `_bottom`, and clean materials.
- `VoxelRenderer._composite_half_voxel_decal()` reuses Part 3a's baked-atom-
  read/tint logic (refactored into a shared `_resolve_tinted_baked_atom()`),
  resolves the cut-face fill colour via `_flat_material_side_color()` — reads
  it straight off the ALREADY-LOADED flat MATERIALS atom rather than
  re-deriving a darken factor against a baked tile's modulate, sidestepping a
  real ambiguity (whether a baked tile's modulate already represents the
  darkened lateral tone, or a pre-shader value `voxel_face_shading.gdshader`
  darkens further — not established, and guessing wrong would over/under-
  darken every cut face).
- Wired into `_set_voxel_cell()` as a second branch, tried only when Part
  3a's full-voxel plan didn't match (a name is CRACKED-full-voxel or
  DENTED-half-voxel, never both).
- **Evidence**: `half_voxel_compositor_equality_selftest.gd` (5/5, the
  measured numbers above) and `half_voxel_seam_selftest.gd` (12/12) — plan
  parsing, the flat side-colour cache, the real seam picking the half-voxel
  composite end to end with idempotent caching, CRACKED confirmed to still
  route through 3a (not swallowed by 3b), floor/ceiling DENTED and
  no-baked-atom cases confirmed unaffected. Fixing this session's own
  regression cost along the way: Part 3a's `decal_seam_selftest.gd` had
  asserted wall-DENTED falls through to generic — true when written, false
  now that 3b handles it — updated to assert the still-true claim (floor
  DENTED falls through), not weakened. Run live on real PLAYGROUND
  (`test_zone_detonate`): real wall-DENTED voxels produced
  (`[BLAST] slice=SLICE_3_3_SW ... dented=13`), **zero errors**.
  `project_lint`, `check_invariants`, `gen_codemap --check`, `run_selftests`
  (25/25) all clean.

**Part 3c — floor-sunk DENTED (zoned ground materials). Status: ✅ DONE
2026-08-03, same session.**

The floor case turned up its own real wrinkle, different from 3a/3b's: a
zoned floor's damage pseudo-name is ALWAYS `"earth_blast_dented_top_N"`
(`floor_damage_material()` — D26, one shared decal family for every ground
material) regardless of which REAL material (`ground_grass`,
`ground_concrete`, ...) is actually there. By the time `_set_voxel_cell()`
sees `render_material`, the real material name is already gone —
overwritten in `process_dirty_slabs()` before the call. But
`resolve_flat(material_id, ...)` (the zoned-floor lookup seam,
ROOF-BAKE-01/02c) needs the REAL material to find the right baked zone page;
calling it with `"earth_blast_dented_top_0"` finds nothing.

- `_set_voxel_cell()` gained one new parameter, `zone_material: String = ""`
  — every existing caller keeps passing nothing and nothing changes for
  them; `process_dirty_slabs()`'s zoned-floor branch now passes
  `slab.material` (the real zone) alongside `render_material` (the pseudo-
  name), so both are available where they're each needed.
- `HalfVoxelCompositor.build_floor_sunk_substrate(kept_atom)` — no
  `cut_fill`/`side` parameters at all, unlike the wall version: the sunk
  region's fill tone is sampled directly off `kept_atom`'s own top-diamond
  pixel (16, 8) rather than resolved through a second colour lookup — it
  IS the material's own top tone already, reading it back is the same fact
  Python's `_rgba(base_color)` states, not a shortcut.
- `VoxelRenderer._floor_sunk_decal_plan()`/`_composite_floor_sunk_decal()`:
  the decal family is unconditionally `"dent"`/`IMPACT_FLOOR_MATERIAL`
  ("earth") — never derived from a `base_material` in the name, because
  there isn't one to derive; the substrate lookup uses the separate
  `zone_material` parameter instead.
- **Evidence**: `half_voxel_compositor_equality_selftest.gd` extended (now
  7/7) — floor's own measured gap is 3.89% (between wall LEFT's 1.94% and
  RIGHT's 6.40%, same class of 1px outer-seam disagreement, not a new
  problem). `floor_sunk_seam_selftest.gd` (8/8): plan parsing, the real seam
  picking the floor composite with idempotent caching, **`resolve_flat()`
  proven to receive the real zone material and never the pseudo-name**
  (the one bug this whole part existed to prevent), an empty
  `zone_material` (unzoned/never-baked earth) falling through unchanged, and
  a no-baked-zone miss falling through cleanly. Run live on real PLAYGROUND
  (`ground_concrete` zone, the same `test_zone_detonate` that already
  produced real floor dents): **zero errors.** `project_lint`,
  `check_invariants`, `gen_codemap --check`, `run_selftests` (26/26) all
  clean.

**Part 3d — ceiling DENTED (silhouette carve, no decal). Status: ✅ DONE
2026-08-03, same session — Part 3 is now fully complete.**

The last and simplest shape, structurally: no polygon mask, no decal, no
cut-face fill. `generate_half_voxel()`'s "bottom" branch delegates straight
to the older, D25-era `generate_dented_voxel(base_img, base_img, "bottom")`
— keep the whole atom, carve a **deterministic jagged line** off its
underside (an isometric camera never sees a ceiling's underside at all, the
reason this tier carries no exposed-surface decal in the first place).

- `HalfVoxelCompositor.carve_ceiling_silhouette(kept_atom)` — a direct port,
  including `_hash01()` (FNV-1a over `(x, y, salt)`) and `_jagged_profile()`.
  **Verified bit-exact against real Python output before writing the real
  version**: a standalone GDScript port of `_hash01()` reproduced Python's
  values to full float precision on a spot-check, confirming the byte-order
  assumption (little-endian, matching `int.to_bytes(4, "little", ...)`'s own
  iteration order) before it went anywhere near production code.
- `VoxelRenderer._ceiling_carve_plan()` — unlike floor, the REAL material
  IS recoverable directly from the pseudo-name here (`"concrete_blast_dented_bottom"`
  already says "concrete" — no shared substitute the way floor's "earth" is
  one), so no `zone_material` threading needed; `resolve_flat()` is called
  with the extracted material directly.
- `_set_voxel_cell()`'s edge-less branch now tries ceiling before floor (the
  two plan parsers never both match the same name, so order doesn't matter
  functionally — ceiling first since it needs nothing extra resolved).
- **Evidence**: `half_voxel_compositor_equality_selftest.gd` extended again
  (now 8/8) — ceiling's own measured gap is **1.39%** (8 of 574 pixels), the
  smallest of the three shapes and a different mechanism than the others: a
  per-column discrete row cutoff, not a continuous polygon boundary, so an
  isolated off-by-one in the linear-interpolation rounding shows up as one
  row of one column differing, not a rasterizer tie-break. `ceiling_carve_seam_selftest.gd`
  (9/9): plan parsing (including that floor/wall names correctly don't
  match), the real seam picking the ceiling composite with idempotent
  caching, `resolve_flat()` proven to receive the material extracted
  straight from the name, floor still resolving correctly with the ceiling
  branch tried first (no collision), and a no-baked-atom miss falling
  through cleanly. `project_lint`, `check_invariants`, `gen_codemap --check`,
  `run_selftests` (27/27) all clean.
- **Honestly recorded, not chased further**: PLAYGROUND has **zero roof/
  ceiling geometry defined** (`grep -c "roofs" maps/PLAYGROUND.map.json` →
  0), so there is no live scenario on the current test map to capture a real
  ceiling-DENTED voxel in play — unlike every other part this session, this
  one has no real-game screenshot behind it, only the equality/seam proofs
  above. Building one would mean adding roof geometry to a map for a feature
  whose entire justification is "the camera never sees this" — not a
  trade worth making for this checkpoint.

### Part 4 — Retire the pre-composited PNGs
- `composites/` is deleted wholesale (this is what ASSET-LAYOUT-01 was
  structured for). `materials/`, `halves/`, `decals/` stay — they become the
  runtime's inputs instead of the generator's.
- `generate_voxel.py` keeps producing `materials/` and `halves/`; its composite
  stage goes away.
- `VoxelRenderer.MATERIALS` loses the 97 generated entries and
  `impact_decal_names()` with them.

---

## 6. Kill criteria / what makes me stop and report

- Part 0 S3 over budget (§4).
- The GDScript↔Python equality test in Part 2 cannot be made to pass within a
  defensible tolerance.
- Any need to place a decal through anything other than `set_cell()` — that is
  **inviolable Rule 8** and ends the approach, not the rule.

---

## 7. Fallback if Part 0 fails

Keep pre-composited PNGs for the **generic** path (today's behaviour, unchanged)
and composite **only baked cells** at runtime, lazily, capped at N per frame with
the uncomposited remainder showing today's generic atom until it catches up.
Uglier, but it buys the facade preservation without paying it on every rotation.

---

## 8. Acceptance

- A real capture of a bullet hole and a blast dent **on a photographically baked
  concrete wall**, showing facade texture continuing around the mark — the thing
  that does not exist today. Side by side with the same shot before the change.
- Rotation timing at 1 / 5 / 15 grenades, before and after, from a real run.
- `run_selftests.py` clean, including the Part 2 equality test.
- `project_lint`, `check_invariants`, `gen_codemap --check` clean.
- Rule 8 untouched: every voxel still reaches the tilemap through `set_cell()`.


---

## 9. Part 0 result — measured 2026-08-03, and the verdict

Spike ran on the real PLAYGROUND with the real bake enabled. All spike code
(`d33_spike.gd`, instrumentation in `test_zone_controller.gd` and `room.gd`) was
reverted; nothing shipped, exactly as Part 0 specified.

### S1 — cost of one composite, in GDScript, 1000 iterations

| Scale | Per composite | Notes |
|---|---|---|
| 1× (blit only) | **0.31 ms** | harder edges, no supersampling |
| 4× (compose big, downscale) | **1.10 ms** | smooth edges |

Feasibility itself is confirmed: reading a baked atom back out of its page
(`TileSetAtlasSource.texture.get_image().get_region()`), column-wise
`blend_rect` as the shear, and the B3 alpha clamp all work at runtime.

### S2 — reuse of baked atoms among damaged cells

One real grenade: **197 damaged cells, 197 of them baked, 0 on the generic
path.** Backed by **167 distinct atoms** and needing **190 distinct composites**.

**Reuse factor 1.04×.** By substrate pixel content it improves to 1.44× on the
98 wall cells (68 distinct hashes), which is still nowhere near enough. *The
cache that was supposed to rescue the approach saves essentially nothing.*

### S2b — does a composite survive a rotation? *(the decisive one)*

Substrate pixel hashes, before and after a rotation to E, same 197 damaged cells:

```
before:       68 distinct substrates
after:        68 distinct substrates
intersection:  0     ← zero
to recompose: 68 (all of them)
```

**0% overlap.** A re-bake under a new perspective genuinely re-samples every
facade run, so every damaged cell's substrate is new pixels. The cost is
therefore **per rotation**, structurally, and no cache key can avoid it — this
is not a tuning problem.

### S3 — rotation baseline

`_set_perspective()` = **1918 ms** today, with one grenade's damage on the map.

### Verdict

| Damage on map | Cells | Added per rotation @1× | vs. the 150 ms criterion |
|---|---|---|---|
| 1 grenade | 197 | 61 ms | under |
| 5 grenades | ~985 | 305 ms | **2× over** |
| 15 grenades | ~2955 | 916 ms | **6× over** |

At 4× it is 220 ms / 1.1 s / 3.3 s — over the criterion before the first
grenade finishes.

**The criterion in §4 is exceeded by 6× at the stated worst case, so the
approach is dead in this form.** I am not moving that criterion after the fact
to make the result pass: the baseline being slow (§S3) is context the Director
may weigh, not grounds for me to rewrite the bar I set before measuring.

### What is worth keeping from this

1. **`_set_perspective()` costs ~1.9 s.** That is the more interesting number
   this spike produced, and it is not a D33 problem — it is a rotation problem
   that existed before and will outlive this decision. Nobody had measured it.
2. **The §7 fallback remains technically viable** and was not killed: composite
   only baked cells, lazily, capped at N per frame. At 0.31 ms, 20 per frame is
   6 ms/frame and 2955 cells fill in over ~2.5 s of progressive catch-up, with
   damaged cells showing today's generic atom until they land. It buys the
   facade preservation without blocking the rotation — at the cost of a whole
   caching + progressive-fill subsystem for a visual that only appears on
   damaged cells of baked walls. **Not recommended on its own merits**; recorded
   so the option is not rediscovered from scratch.
3. Runtime compositing is confirmed *possible*. If the rotation re-bake ever
   stops being per-view — or if damage ever stops persisting across rotations —
   the arithmetic changes completely and this plan is worth re-reading.


---

## 10. Correction — the kill in §9 was wrong, and why

The Director pushed back ("*se a gente derrubar a rotação, daria pra colocar o
decal por cima dos baked voxels?*") and the pushback exposed a defect in the
spike, not in the idea.

### What §9 got wrong

S2b measured whether a damaged cell's substrate changes across a rotation. It
does — and I read that as *"a re-bake re-samples every facade run, so the cost is
per-rotation structurally."* **That inference does not follow.** The substrate
changes because rotating shows a **different physical face** of the wall, which
is correct behaviour, not resampling noise.

The cache key I planned in §5 — `(page_idx, atlas_coords, composite_name)` — is
**screen-space**. Screen-space keys cannot survive a rotation by construction, so
measuring one and concluding the approach is dead was circular.

### The measurement that settles it — N → E → N

Same 197 damaged cells, hashing each cell's substrate at each stop:

```
view N          68 distinct substrates
view E          68 distinct substrates      N∩E = 0    → 68 new composites
view N (back)   69 distinct substrates      N∩N' = 67  → 97% CACHE HIT
```

Substrates are **stable per view**. Returning to a view already visited costs
essentially nothing. The correct key is per-view (equivalently, base-space cell +
physical face + decal).

### Corrected cost

| Event | Cost |
|---|---|
| Rotation into a view that has not seen this damage | cells × 0.31 ms — e.g. **61 ms** for one grenade's 197 cells |
| Rotation into a view that has | **~0** (cache hit) |
| Steady state after all 4 views seen | **0** |

The 916 ms figure in §9 assumed every rotation recomposites everything. It does
not; it recomposites only what *that view* has not seen. **The kill criterion is
not breached.** Rotation does not need to be dropped.

### The real binding constraint, and it is a different one

Not time — **memory**. Worst case is `damaged cells × views visited × 4.6 KB`;
at 2955 cells across all four views that is **~54 MB**, against a bake budget
D21 already measured at 75.9 MB. Realistic figures are far lower (a wall face is
not visible from all four views), but this needs a cap with eviction, and that
cap — not the timing — is what Part 1 must design around.

### Still unmeasured, and it is a real design point

The composite cache must **outlive the room rebuild**. Rotation rebuilds every
Voxel from the MapSpec and clears `_baked_source_ids`; a cache that lives on the
renderer dies with it. It has to hang off something with room lifetime, keyed in
base space, and it must invalidate correctly when the *map* changes rather than
when the *view* does. Part 1 owns this and it is the next thing to prove.

### Process note

Two lessons, recorded because they cost a full spike:

1. **Measuring the thing you designed proves only that you designed it that
   way.** The spike validated my cache key instead of the question.
2. The Director's "*me parece tão trivial*" was the correct instinct. When a
   measured result says an obviously-simple thing is impossible, the measurement
   is the more likely suspect.

---

## 11. Correction — ROTATE-KILL-01 resolves §10's harder open point (2026-08-03)

Same-day follow-on, unrelated in origin: `PROMPTS/ENGINE_PERFORMANCE_REVIEW.md`
(the Director's whole-engine performance review) measured `_set_perspective()`
at a flat ~1.3-1.9 s per call with no cheap fix available, and the Director
ratified killing player rotation entirely — `PerspectivePad` is now gated
behind `VisionController.dev_vision` (default ON for dev builds, OFF for
players), commit `ROTATE-KILL-01`. That decision was made purely on
performance grounds and never mentioned D33 — but it changes this plan's
constraint directly.

### The mechanical fact that matters here

Verified by grepping every call site of `RoomBuilder.build_from_layout()` in
`room.gd`: there are exactly two, `load_map()` (`room.gd:551`, the one-time
initial load) and `_set_perspective()` (`room.gd:1145`, rotation). With
rotation gated out of player builds, **a player session never calls
`build_from_layout()` a second time.** The room is built once per mission and
never rebuilt until the next `load_map()` (a genuinely new map/mission, which
should invalidate every cache anyway — that was always going to be true).

### What this resolves

§10 left two open points for Part 1. One is unaffected; the other is now moot
for the case that matters:

- **"The composite cache must outlive the room rebuild"** (§10, "Still
  unmeasured, and it is a real design point") — **moot for players.**
  `_baked_source_ids` is cleared and every `Voxel` is rebuilt only when
  `build_from_layout()` runs, and that no longer happens mid-session. A plain
  in-memory cache scoped to the loaded room's lifetime (built lazily as cells
  take damage, discarded whole on the next `load_map()`) is now sufficient —
  no invalidate-on-rotation logic to design, because there is no rotation to
  invalidate against.
- **The memory ceiling** (§10, "the real binding constraint") — recalculated,
  not just discounted. §10's worst case was `damaged cells × views visited ×
  4.6 KB` ≈ **54 MB** at 2955 cells across 4 views. With exactly one view ever
  rendered for a player, the multiplier is 1, not 4: **≈13.6 MB** at the same
  2955-cell worst case — comfortably inside the 75.9 MB bake budget D21
  measured, with no eviction policy required for correctness. A cap is still
  cheap insurance, but Part 1 no longer has to design one to ship.
- **What does NOT change**: S1 (0.31 ms / 1.10 ms per composite, §9) is
  unaffected by any of this, and Part 2's real open risk — porting the
  shear/alpha-clamp math from `generate_voxel.py` to GDScript and proving
  numeric equality — has nothing to do with rotation either. That is still
  the one genuinely unproven step in this whole plan.

### What still needs a per-view-shaped key, and why

`DEV_VISION` keeps `_set_perspective()` alive for QA (ROTATE-KILL-01's own
design — a visibility gate, not a removal). A developer can still rotate, and
§10's finding stands unchanged: the same physical edge shows a genuinely
different face under a different view, so a naive "one composite per voxel,
full stop" cache would show a stale or wrong face if a dev rotates after
damage. The key still needs a face/orientation component, not just
`(grid_pos, level)` — it just no longer needs to *survive being rebuilt*,
because for the one case that has to be fast (the player), the face never
changes at all. Concretely: key on **base-space voxel identity + the
resolved face + decal name** — `(container_id, grid_pos, level, face,
decal_name)`, sourced from the exact fields `process_dirty()` already passes
around (`voxel_renderer.gd:1438`: `edge`, `voxel_xy`, `slice.face`) rather
than anything screen-space. For a player this key never repeats under a
different face (no rotation to produce one); for a dev rotating in
DEV_VISION, a face change is a genuinely new key, correctly recomposited —
same behaviour as before, just no longer perf-critical since it only fires
under a debug toggle.

### Net effect on Part 1's scope

D33 was "✅ viable, with two open design problems for Part 1." One is now
solved by a decision made for a different reason; the other (memory) has a
comfortable margin instead of needing an eviction subsystem. **Part 1 is
lower-risk than it looked on 2026-08-03 morning, unchanged in what it still
owes: the base-space key design above, and Part 2's Python↔GDScript equality
proof.**
