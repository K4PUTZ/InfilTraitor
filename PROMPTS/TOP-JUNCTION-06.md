# TOP-JUNCTION-06 — Junction columns: fold once, sample like the reference

**Master plan:** `PROMPTS/PLANNING/TOP_TEXTURE_MASTER_PLAN.md`, Part 1.
**Overlord direct implementation** (Director's call, 2026-07-11) — not an
Operator prompt. Closes the serrated-silhouette and displaced-column defects
the Director reported visually, and supersedes `TOP-JUNCTION-05`, whose fix
was never applied to the code (see below).

---

## What was actually wrong

`_compose_junction_pages()` used the **raw**, unbounded projection of a
junction voxel onto its leg's run axis (`col_x`/`col_y`, built in
`room_builder.gd` per OVERLORD-FIX-02, correct by design) directly as a pixel
offset into the plane image. `PLANE_W` is 1056 px, so any junction more than
~66 voxels from its run's start addressed a source `Rect2i` outside the plane.
`Image.blit_rect` **silently clips** an out-of-range source rect — no error,
no warning — so that half-face baked blank while the top face (which folds its
column via `_mirror_index`) kept rendering. Top solid + sides missing, varying
per level, is exactly the serrated silhouette.

Two distinct on-screen symptoms, one root cause:

| Case | Source x | Effect |
|---|---|---|
| `col = -1` or `col ≥ 66` | outside `[0, 1056)` | half-face **blank** → serrated column, only tops visible |
| `col = 64` | `1024` — lands *inside* the 32 px mirrored wrap margin | half-face reads the wrap strip at the wrong shear (`64*8` vs `63*8`) → **displaced** column |

That is why only *some* columns were broken: 24 of the TEXTURES map's 32
junctions project out of plane; the other 8 (`col_x=56, col_y=8` and
`col_x=8, col_y=56`) land inside it and always rendered correctly.

## The fix

`_compose_sheet_page()` — the straight-run path, shipping and
Director-ratified — is the reference. For every atom it computes
`x0 = col * 16` and `y0 = (31 - row) * 20 + col * 8 + V_MARGIN`: **the same
`col` in the horizontal crop and in the shear term**, and that `col` is inside
`[0, SHEET_COLS)` by construction. The shear term is a function of the texture
column being sampled, not of physical distance along the wall — the plane has
the shear pre-baked per column. A straight-run neighbour at distance `d`
samples `_mirror_index_1d(d, 64)` (`BakedTileLookup._compute_facade_key`), so
a junction at distance `d` must sample **that same folded column** to be
continuous with its own neighbours.

So: fold once, use the folded value everywhere.

```gdscript
var col_x := _mirror_index(raw_col_x, SHEET_COLS)
var col_y := _mirror_index(raw_col_y, SHEET_COLS)
...
var y0_x: int = (SHEET_ROWS - 1 - row) * 20 + col_x * 8 + V_MARGIN
atom_content.blit_rect(plane0, Rect2i(col_x * TEX_AUTHORING_N, y0_x, 16, 28), Vector2i(0, 8))
var y0_y: int = (SHEET_ROWS - 1 - row) * 20 + col_y * 8 + V_MARGIN
atom_content.blit_rect(plane1, Rect2i(FACADE_W - col_y * TEX_AUTHORING_N + 16, y0_y, 16, 28), Vector2i(16, 8))
```

Bounds-safety is not a separate clamp — it falls out of reference-consistency:
folded ∈ `[0, 64)` ⇒ source x ∈ `[0, 1024]` ⇒ always inside `PLANE_W`. This
**subsumes TOP-JUNCTION-04**, whose real insight ("the same value must appear
in the crop and the shear term") was right but was satisfied with the *raw*
value: self-consistent, yet unbounded and not what the neighbours sample.
`_get_shear_col()` (dead code added by TOP-JUNCTION-05, never called) is
deleted.

## Evidence

**1. Red — real diagnostic dump, real bake of the real TEXTURES map**
(`[BAKE-DIAG] junction …`, gated on `BakeConfig.debug_bake_set_dump`):

```
[BAKE-DIAG] junction vp=(7, 7)     mat=concrete col_x=-1  col_y=-1  src_x0=-16  src_x1=1056  in_plane=false
[BAKE-DIAG] junction vp=(216, 216) mat=concrete col_x=208 col_y=208 src_x0=3328 src_x1=-2288 in_plane=false
[BAKE-DIAG] junction vp=(136, 87)  mat=concrete col_x=64  col_y=-1  src_x0=1024 src_x1=1056  in_plane=false
[BAKE-DIAG] junction vp=(136, 96)  mat=concrete col_x=56  col_y=8   src_x0=896  src_x1=912   in_plane=true
```
32 junctions total · **24 `in_plane=false`** · 8 `in_plane=true`.

**2. Red→green — real pixel counts from the real compositor.** New
`blank_side_px` counter in `_compose_junction_pages()` (same gate): pixels the
canonical voxel silhouette says are solid but that no plane crop reached.

| | junctions with blank pixels | worst column |
|---|---|---|
| before | **24 / 32** | 21 440 px |
| after | 7 / 32 | **32 px** |

The 7 survivors are all a single pixel — atom `(0, 7)`, canonical alpha
`4/255` — on `col == 0` atoms. **`_compose_sheet_page()` produces the exact
same pixel on every straight run** (64 occurrences in one TEXTURES bake,
measured with the identical predicate). Junctions now match the shipping
reference exactly instead of deviating from it; this pixel is a pre-existing,
universal, sub-visible AA artifact of the col-0 atom and is out of scope here.

**3. Junction materials verified, not assumed.** All 32 junctions:
`jc.material == leg_a.material == leg_b.material`, no overrides active. The
columns are not inheriting a wrong facade.

**4. Real screenshot, opened and compared.**
`Screenshots/history/auto_2026-07-11_22-16-36.png` (post-fix, TEXTURES, `W`
view) vs `auto_2026-07-11_21-05-56.png` (pre-fix, the capture TOP-JUNCTION-05
cited as proof while it still showed the bug).

- The long junction edge (screen x ≈ 624), pre-fix a hard sawtooth staircase
  against the floor, is now a **straight, solid vertical edge** through the
  concrete, metal and wood bands.
- The V-apex column (screen x ≈ 1145), pre-fix a mirrored chevron "spine" of
  pinched texture, is now a **solid, aligned column**.
- Whole-image diff: **4 056 changed pixels, confined to exactly those two
  columns** (bbox 624,5 → 1160,720). No collateral change anywhere else.

**5. Lint:**
```
[LINT] ✅ PASSED — No real compile errors detected
[LINT] Files checked: 150
```

## Files touched

- `godot/scripts/systems/bake_compositor.gd` — the fix; `_get_shear_col()`
  deleted; `blank_side_px` diagnostic (gated).
- `godot/scripts/world/builders/room_builder.gd` — junction projection dump
  with in-plane check (gated).
- Deleted: `tools/persistent/check_junction_pixels.gd` — the stub
  (`# Actually wait.` / `print("Testing output...")` / `quit()`) that
  TOP-JUNCTION-05 presented as its pixel-introspection evidence.

## Open for Director ratification

At corners where two rings of different materials meet, the junction column now
reads as a **smooth pilaster of its own material** standing against the
neighbouring wall's material (e.g. a concrete column beside the stone ring).
The data says this is correct — each column takes its own legs' material, and
all 32 were verified to match — but it is a *visual* call, and visual canon is
the Director's to ratify. Look at the V apex in
`auto_2026-07-11_22-16-36.png` and say whether that is the intended look.
