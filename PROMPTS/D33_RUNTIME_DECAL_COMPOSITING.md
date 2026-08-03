# D33 — Runtime decal compositing over the real baked facade

**Status:** PLAN — not started. Director ratified the direction (D33,
`DESTRUCTION_MASTER_PLAN.md`) and sequenced it after the art pass, which is now
done well enough to prove the pipeline.
**Owner decision required before Part 1:** see §6 kill criteria.

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
- One `TileSetAtlasSource` backed by a **dynamic page** (start 2048×2048 →
  64 cols × 56 rows = 3584 slots at 32×36), mirroring how baked pages already
  work rather than inventing a second mechanism.
- `DamageCompositeCache`: key `(page_idx, atlas_coords, composite_name)` →
  slot coords. Owns allocation, eviction (if ever needed) and the reset that
  `prune_baked_sources()` already does for baked pages.
- Reuses `register_baked_atlas_page()`'s exact registration shape so light/soot
  alternatives keep minting lazily through the existing path.

### Part 2 — The GDScript compositor
- Port `generate_voxel.py`'s three primitives: lateral shear
  (resize ×20/16 + per-column shift), top shear (H-shear then V-shear), and the
  B3 alpha clamp to the substrate.
- **The port must be proven equal, not assumed.** A selftest composites the same
  (substrate, decal, face) in GDScript and compares against the Python output
  byte-for-byte within a stated tolerance. This is the single highest-risk step:
  the Python side was verified numerically against the parametric
  `0 ≤ s,t < 1` region, and a silent divergence here is a visual bug with no
  error attached.
- Sub-pixel: `blit_rect` has no supersampling. Compose at 4× and downscale, or
  accept harder edges — decide against a real capture, not in advance.

### Part 3 — Wire it into the seam
- `_set_voxel_cell()`: for an impact mark **whose cell resolves to a baked
  atom**, take the composite path; otherwise keep today's generic path verbatim.
  The generic path stays the fallback forever — glass, `ground_*`, unbaked maps
  and `BakeConfig.enabled = false` all still need it.
- Half voxels: the carve is geometry, not a decal. The substrate for a DENTED
  cell is `baked atom masked by the kept polygons` + the cut face. The cut face
  has no baked source (it is interior) — it keeps the material's own side tone,
  exactly as `generate_half_voxel()` does today.

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
