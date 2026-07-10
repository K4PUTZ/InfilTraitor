# BAKE-FACADE-PLANE-02-b — Atlas page collision, unreachable cache, size schema, pre-shear (final)

**Status:** DRAFT — pending Director ratification
**Corrective for:** BAKE-FACADE-PLANE-02 (commit `429f5d1`, self-labeled "02a")
**Plane:** geometry/render grid + one MAPFILE schema extension.

---

## CONTEXT — Overlord inspection findings (all verified in code)

02 shipped **without a completion report** (nothing appended to the prompt
file; a commit message is not a report). This corrective therefore carries
both the new fixes and the still-unproven 02 criteria. Live symptoms reported
by the Director, each traced to a confirmed root cause:

### Finding 1 — With bake ON, every material shows the same texture
**Root cause: atlas page collision.** In
`bake_compositor.gd::_render_strips_to_pages()`, `page_idx` is initialized to
0 and **never advances**, and each strip's atom placement restarts at
`atom_idx = 0`. Every material's 2048 atoms are blitted to the **same page at
the same tile coordinates**; each strip overwrites the previous one's pixels,
and every material's lookup keys point at those shared coordinates. The last
combo baked wins — all walls render with that one facade. (The "squares on
metal" the Director sees are whichever facade baked last; per-material
appearance can only be judged after this fix.)

**Fix:** give each strip a distinct, non-overlapping region: either advance a
global atom offset across strips (packing multiple sheets per page,
row-aligned) or one page per strip — Operator's choice, but pages must be
**sized to used content** (a 64×32 sheet needs 2048 tiles = 16 page-rows =
4096×576, not 4096×4096), and `lookup` entries must carry the true
(page, atlas_coords).

### Finding 2 — F6/F7 still hangs: the cache is unreachable by construction
**Root cause: lifecycle.** `room_builder.gd:392` creates a **new
`BakeCompositor` on every map load/reload**; `_session_cache` is an instance
field, so it dies with its owner before any second lookup — production can
never hit it. Every F6/F7 toggle re-bakes everything from scratch.

**Fix:** persist ONE compositor (or at minimum its cache) across reloads
within the session — `RoomBuilder` survives `load_map()` calls, so owning the
instance there is sufficient; no autoload needed, no `Engine.set_meta`
(FIX-SHUTDOWN-CRASH lesson — never park RefCounted instances in Engine meta).
The cache key must include the combo set or map id in addition to blend mode
(a blend-only key returns stale pages after a map switch). `clear_cache()`
semantics: clear on explicit map change if keying doesn't already cover it.

### Finding 3 — Bake is still per-pixel: pre-shear skipped for the second time
`_bake_atom_sheet()` still samples the facade **per pixel per atom** via
`FacadeSampler` (grep the file: no pre-shear exists). Mandated in 01-b,
re-mandated in 02, not done. With 4 combos on TEXTURES 2.0 the full bake is
~4× the measured 4.8 s single-combo cost — this alone explains "still slow".

**Fix (non-negotiable this round):** build per-facade pre-sheared images once
— S⁺ and S⁻ (mirror + opposite shear, the 02 second-direction spec) — via
`blit_rect` strips; per-atom face content becomes axis-aligned crops (the
algebra is in 01-b CONTEXT). The per-pixel per-atom facade sampling loop must
be **gone from the code**, not just faster. Alpha stays the per-pixel copy
from the canonical atom (B3) — that loop is 32×36 per atom and may remain.

### Finding 4 — The V-walls never existed: `size` is not a schema field
`maps/TEXTURES.map.json` uses `"size": [w,h]` on `blocks` items — a field
**no code reads** (`FileMapSource` passes items through; the block renderer
reads only `gu`/`storeys`/`material`). Every "wall" item silently degraded to
a single 1-GU block — the Director's screenshots show 4 lone towers, not
V-pairs. Additionally the JSON itself is wrong even if `size` worked: all
four SW legs share `x=6` (they overlap), and consecutive pairs are 2 GU apart
= only 1 free GU between walls (spec: 2 free GUs).

**Fix, two parts:**
1. Implement `size` properly via the MAPFILE extension protocol
   (`docs/technical/MAPFILE_REFERENCE.md`): `blocks` section **v1→v2** with a
   registered migration (v1 items = implicit `size: [1,1]`), rectangle
   expansion where blocks are compiled, `map_lint` aware of the new field.
   No ad-hoc parsing outside the section owner.
2. Rewrite the TEXTURES 2.0 center layout: four V-pairs (one per material,
   each leg 8 GU × 4 storeys), legs joined at a shared corner, **no two
   walls overlapping or touching**, consecutive pairs nested along the depth
   diagonal with **exactly 2 free floor GUs** between nearest walls of
   consecutive pairs, open side facing the agent start.

## MODULE

- `godot/scripts/systems/bake_compositor.gd`, `baked_tile_lookup.gd`
- `godot/scripts/world/builders/room_builder.gd` (compositor lifecycle)
- `godot/scripts/world/maps/persistence/map_sections_v1.gd` (+ blocks v2 migration)
- `godot/scripts/tools/map_lint.gd`, `maps/TEXTURES.map.json`
- `godot/scripts/tools/bake_fix_12_facade_2d_test.gd` (extend)

## DO NOT TOUCH

- B3 alpha path; blend-mode side-face formulas; junction no-flip; generic
  fallback; transform canon; DEV-HUD-01 panel; other maps' content.

## ACCEPTANCE

All evidence pasted literal. **A completion report appended to this file is
part of "done" — every criterion gets an explicit per-criterion verdict with
its pasted evidence; anything not met is stated as NOT MET, not omitted.**

1. **Cross-material uniqueness (kills Finding 1):** headless TEXTURES 2.0,
   bake on: for each of the 4 combos, sample one placed cell per material and
   assert the 4 resolved (page, atlas_coords) tuples are pairwise distinct AND
   the sampled baked pixels differ across materials (independent facade
   `load()` comparison for at least one pixel per material). 0 collisions.
2. **Cache reachability (kills Finding 2):** boot TEXTURES, cycle F7 through
   all 5 modes twice; paste the log showing 5 MISS then 5 HIT, with the HIT
   path timed ≤ 500 ms and a counter proving zero `_bake_atom_sheet()` calls
   on hits. Then `load_map("PLAYGROUND")` and back: no stale-page reuse
   (keying or clear proves it in the log).
3. **Pre-shear landed (kills Finding 3):** full TEXTURES bake (4 combos)
   ≤ 2000 ms, timings pasted; report quotes the new S⁺/S⁻ build code path and
   confirms the per-pixel per-atom facade sampling loop no longer exists
   (file/line references).
4. **Blocks v2 `size` (kills Finding 4):** `map_lint` passes on the updated
   TEXTURES; a v1 file (no `size`) still loads via migration (golden
   round-trip pasted); headless boot shows wall-cell counts consistent with
   8-GU legs (paste extraction counts per material — each combo's referenced
   columns must span 64, not 8).
5. **Carried from 02 (previously unproven):** second-direction pixel identity
   (≥ 64 samples, mirrored u,v, independent load, 0 mismatches) and
   anti-banding along one run of EACH axis (strictly advancing windows).
6. **Regressions:** `bake_fix_02` 3/3, `bake_fix_09` 5/5, `bake_fix_11` 7/7,
   `bake_fix_12` all-pass; PLAYGROUND + SIGMA_01 headless, bake on AND off,
   zero errors.
7. `python3 tools/persistent/project_lint.py` pasted, zero real compile
   errors. Version bump; commit + push per protocol.

**Director ratification (post-Operator):** booting TEXTURES 2.0 — four real
V-pairs, each showing its OWN material's full facade continuously on both
directions; F6/F7 fluid (first bake fast, revisits instant).
