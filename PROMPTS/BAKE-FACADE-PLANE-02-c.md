# BAKE-FACADE-PLANE-02-c — Second-direction mirror fix + bake performance (final architecture)

**Status:** DRAFT — pending Director ratification
**Corrective for:** BAKE-FACADE-PLANE-02-b (commit `e1b0fbf`)
**Plane:** geometry/render grid (fine plane).

---

## CONTEXT

02-b fixed the atlas page collision, the compositor/cache lifecycle, and the
blocks-v2 `size` schema — Director-confirmed live: all four materials now load
distinct textures. Two things remain, plus a standing discipline item:

### Finding A — Second direction renders as reversed 16-px chop

Live symptom: only walls of one direction read as facade; the others look
irregular/chopped. Root cause is in the RIGHT-half u formula in
`_bake_atom_sheet()`:

```
current:  u = col·16 + (x − 16)
```

Within one atom, u increases with screen-x. But along a second-direction run,
the NEXT column's atom sits 16 px to the screen-LEFT — so across atoms u
decreases with screen-x. Result: the wall is a sequence of 16-px blocks,
each internally forward, globally ordered backward — texture never reads as
continuous. The fix is the Director's own earlier spec ("the texture must be
mirrored as a whole for the other direction"): mirror u **within** the right
half so per-atom order matches cross-atom order:

```
fixed:    u = col·16 + (15 − (x − 16))
```

With this, walking a second-direction wall in screen space the facade u
sequence is monotonic (descending = horizontally mirrored facade, physically
correct for viewing the plane from the other side) and seam-continuous
(`(col+1)·16` meets `col·16 + 15`). The v formula (opposite shear) stays.

**The acceptance test must assert screen-order truth, not formulas-as-written:**
for a run of EACH direction, walking placed cells in screen order, the facade
u sequence must be monotonic and continuous across every seam. That catches a
wrong half/sign no matter where it hides.

### Finding B — Bake still ~21 s: pre-shear deferred a third time; the CPU
### architecture below is now mandated exactly

02-b's commit honestly reports Finding 3 deferred "due to complexity" and
21 s live. Three mandates of "pre-shear" without landing means the prompt now
specifies the full algorithm. Two Director-ratified decisions (D-BAKE-PERF,
this round) unlock it:

1. **The baked path drops per-pixel pattern noise.** With a real facade
   texture carrying the detail, the pattern modulation is invisible; dropping
   it makes `shaded_base` a **constant color per material**, so every blend
   mode becomes a pure function of facade luminance → a 256-entry LUT per
   (material, blend_mode).
2. **MATERIAL_ONLY mode stops baking entirely.** It ignores the facade by
   definition — placement short-circuits to the generic material atlas
   (identical appearance to bake-off, which is what the mode means). Pattern
   noise thus survives exactly where it's visible: material-only rendering.

Mandated pipeline per (facade) — built once, session-cached:
1. `F_lut` per (material, mode): apply the 256-entry LUT to the facade
   (1024×512 pass) → pre-blended grayscale→RGB image.
2. Scale ×20/16 vertically (`Image.resize`, nearest) → 1024×640.
3. Shear into S⁺ (down x/2) and S⁻ (mirrored + opposite shear) via ~512
   2-px-wide `blit_rect` strips each — no per-pixel loops.
4. Per atom (col,row): two axis-aligned `blit_rect` crops (left half from S⁺,
   right half mirrored from S⁻ — offsets per the 01-b algebra, adjusted for
   Finding A's mirror), pasted into the atom/page.
5. Alpha (B3): apply the canonical atom's alpha via `blit_rect_mask` for the
   binary region PLUS an explicit per-pixel fixup restricted to the
   **precomputed list of partial-alpha (antialiased) pixels** per material
   (~66–200 px per atom footprint, per TILE_ANATOMY §1) so edge alpha is
   copied verbatim, not rounded. `bake_fix_11`'s 0-mismatch alpha check is
   the non-negotiable proof this survived.
6. Top face: constant `shaded_base` fill (rows 0..15) before the side-face
   blits — no change in look from 02-b.

Expected cost: LUT pass ~0.5 s per combo·mode worst case, everything else
blits — full TEXTURES bake (4 combos) lands well inside the budget.
**Budgets unchanged and final: ≤ 2000 ms full bake; ≤ 500 ms cache-hit
revisit.** If measured over budget, the report states the breakdown and
stops — no fourth deferral inside a "done" prompt.

### Standing discipline item

02 and 02-b both shipped with **no completion report appended to the prompt
file** (02-b's commit message was honest — that's noted and appreciated — but
a commit message is not a report). For this prompt: the appended report with
per-criterion verdicts (including NOT MET where true) is part of "done".

### Optional (Director: "serve por enquanto" — do only if trivial)

Flip the V-pairs' opening to face the agent start (corner anchor swap in
`maps/TEXTURES.map.json`). Zero code.

## MODULE

- `godot/scripts/systems/bake_compositor.gd` (Findings A + B)
- `godot/scripts/systems/baked_tile_lookup.gd` / placement (MATERIAL_ONLY
  short-circuit)
- `godot/scripts/tools/bake_fix_12_facade_2d_test.gd` (screen-order assertions)
- `maps/TEXTURES.map.json` (optional V flip only)

## DO NOT TOUCH

- B3 alpha verbatim guarantee (the AA-pixel fixup exists precisely to keep it);
  canonical atom loading; junction no-flip; transform canon; blocks v2 schema;
  DEV-HUD panel; TEXTURES layout beyond the optional flip.
- The four non-MATERIAL_ONLY blend formulas' semantics (they move into LUTs —
  same math, table form; `bake_fix_12` pixel-identity proves equivalence).

## ACCEPTANCE

All evidence pasted literal; per-criterion verdicts mandatory in the appended
completion report.

1. **Screen-order continuity, both directions:** for one run of EACH grid
   axis on TEXTURES, walking placed cells in screen order, facade u is
   monotonic and seam-continuous (assertion-backed; paste the sequences for
   ≥ 8 consecutive cells per direction). Kills Finding A unforgeably.
2. **Pixel identity survives the rework:** ≥ 64 samples per direction assert
   baked pixel == LUT(facade pixel) via the u,v formulas (facade loaded
   independently); 0 mismatches. (Proves LUT == formula blend and mirror
   correctness at pixel level.)
3. **Alpha canon intact:** `bake_fix_11_pixel_diff_tool.gd` 7/7 including the
   0/41472 alpha-mismatch check.
4. **Performance:** full TEXTURES bake (4 combos) ≤ 2000 ms and F7 revisit
   ≤ 500 ms, timings pasted from a real headless boot; report cites file/line
   showing no per-pixel facade sampling loop remains (only the AA fixup and
   LUT passes are per-pixel, both bounded and named).
5. **MATERIAL_ONLY short-circuit:** with blend_mode=MATERIAL_ONLY, placement
   uses the generic material atlas (log/counter proof) and rendering is
   pixel-identical to bake-off for the same map (sampled comparison pasted).
6. **Regressions:** `bake_fix_02` 3/3, `bake_fix_09` 5/5, `bake_fix_12`
   all-pass (updated expectations named); PLAYGROUND + SIGMA_01 headless,
   bake on AND off, zero errors.
7. `python3 tools/persistent/project_lint.py` pasted, zero errors; version
   bump; commit + push; **completion report appended to this file**.

**Director ratification (post-Operator):** every V shows its material's
facade continuous on BOTH directions (second direction mirrored, no 16-px
chop); F6/F7 near-instant after first visit; first bake ≤ 2 s.
