# ART ORDER — the glass fracture sheets and floor shards

**For:** the Director, who is authoring the art.
**Written:** 2026-09-01, against commit `57017b7c`.
**Material:** `glass`, and every tinted variant of it.
**Closes:** `GLASS_MASTER_PLAN` **G-ART** (task order 3), which unblocks **G5**
(the CRACKED tier), **G6** (shards), **G-D4** (the bullet web) and the whole
crack arc **G-D19 / G-D21 / G-D23 / G-D24**.

> Every claim below about how a file is consumed was read out of the source
> named beside it, this session. Where this document and
> [`ASSETS/ART_SPECIFICATIONS.md`](../ASSETS/ART_SPECIFICATIONS.md) §7 disagree,
> that file is the canon and this one is the bug.

⚠️ `ASSETS/materials/*/*` is **gitignored** (`.gitignore:66`). The art never
appears in a diff and never travels in a commit — this order and its gate are
what the repo carries.

---

## 0. The short version

**Five files, in two classes that fail in completely different ways.**

```
ASSETS/materials/glass/fracture_glass_tight.png     1024 x 512   grayscale on BLACK
ASSETS/materials/glass/fracture_glass_wide.png      1024 x 512   grayscale on BLACK
ASSETS/materials/glass/decals/decal_shard_glass_0.png    256 x 256   RGBA, real alpha
ASSETS/materials/glass/decals/decal_shard_glass_1.png    256 x 256   RGBA, real alpha
ASSETS/materials/glass/decals/decal_shard_glass_2.png    256 x 256   RGBA, real alpha
```

**Two sheets, because G-D14 gives glass exactly two hole sizes** — pistol and
shotgun pellet take the tight web, rifle-class the wide and more spaced one.
**Three shard variants, because three is the number the runtime hashes into** —
not two, not four.

### What is deliberately NOT in this order

| Not asked for | Why |
|---|---|
| a `bullet_web` family | **G-D21 folded it into the sheet.** The hole is baked at the sheet's centre and the sheet is re-anchored onto the impact voxel, so a separate per-voxel bullet mark would be a second, competing fracture |
| a `dent` family | **Impossible for glass, permanently.** G-D3 amended D22 so CRACKED returns and DENTED never does — glass fractures, it does not deform, and `glass.json`'s `dent_factor` is pinned at `0.0` to say so in data |
| a `frame_remnant` family | It is **geometry, not a decal** (§5.2) — a jagged half-voxel substrate, built, not painted |
| anything for `glass_armored` / `glass_screen_*` | **G-D16: the variants differ by tint and behaviour class, never by geometry.** They reuse these same two sheets. G-VARIANT adds no art at all |
| a third, fourth… fracture variant | See §1.5 — every sheet costs 2048 composed atoms at every map load, whether or not anything ever cracks |

⚠️ §8 of `GLASS_MASTER_PLAN` describes a four-family order with a
**direction-indexed** `crack_web`. That was written before G-D20/G-D21 and is
**superseded**: the sheet is anchored to the EVENT, so direction falls out of the
offset arithmetic and no art is indexed by bearing. §8 now points here.

---

## 1. The fracture sheet

One 64 × 32-voxel page, at the pinned `TEX_AUTHORING_N = 16` texels per voxel.
`64 × 16 = 1024`, `32 × 16 = 512`.

| Property | Value | Where it comes from |
|---|---|---|
| Path | `ASSETS/materials/glass/fracture_<material>_<tight\|wide>.png` | `TextureResolver.resolve(id, folder)` reads `res://ASSETS/materials/<folder>/<id>.png` and has **no subdirectory step** — a sheet under `decals/` is unreachable |
| Dimensions | **1024 × 512, never pre-squared** | `BakeCompositor.FACADE_W = 1024`, `SHEET_COLS = 64`, `SHEET_ROWS = 32` |
| Colour | **Grayscale, R == G == B** | Invariant B2. Colour reaches glass through `base_color`'s multiply and the pane tint, never through a pattern source |
| Field | **Pure black = no fracture.** The sheet is a MASK: luminance is how much crack is at that texel | G-D19 — see §1.1 |
| Alpha | **Not used. Do not rely on it.** | See §1.1 — the compositor destroys it |
| Origin | **The fracture radiates from the exact centre of the canvas, pixel (512, 256)** | G-D21 — see §1.2 |
| Orientation | **Authored right side up.** The bottom edge of the PNG is the ground; the top edge is the top of the wall | `bake_compositor.gd:409` — `y0 = (SHEET_ROWS − 1 − row) · 20`, so level 0 lands on the last band |
| Repeat | **None. It clamps.** Beyond the sheet there is simply no crack, never a mirrored one | G-D23 |

### 1.1 ⚠️ The trap that would waste an entire authoring night

**The compositor throws the alpha channel away.** `bake_compositor.gd:556-558`,
verbatim in the source: *"The RGB8 round-trip flattens any alpha the facade PNG
carries to 255"*.

So a sheet authored the way §7.3 of the master plan describes — *generate on
black, alpha = luminance, RGB = near-white* — arrives at the compositor as a
**near-white crack on OPAQUE BLACK**, and every uncracked voxel of the pane goes
pitch black. That recipe is correct, and it is correct **for the shard decals in
§2**. It is wrong here.

**Deliver the sheet exactly as the generator produces it: a bright fracture on a
black field, no alpha step at all.** That is less work, not more.

### 1.2 The origin, and why it is the one thing that cannot be approximate

G-D21 re-anchors the sheet by offsetting `(column_in_run, level)` by
`(impact − sheet centre)`. If the fracture's origin is not the centre of the
canvas, **every crack in the game lands a fixed distance from the round that made
it** — the same displacement, in the same direction, forever, with nothing on
screen to say so.

A radially symmetric web has its ink-weighted centroid at its own origin by
construction, so the gate measures the centroid directly and allows 4 voxels
(64 px) of slack for an asymmetric web. Which of the two middle columns the build
calls "the centre" is a build decision the offset absorbs; **your job is only
that the web radiates from the middle of the canvas.**

The hole itself is nearly invisible in play and is not worth fussing over: the
impact voxel is DESTROYED by G3 and stops rendering. What is seen is the craze
around it.

### 1.3 Reach — the number that decides whether the sheet does its job

G-D23 derives the maximum pane from this sheet: **64 × 32 voxels = 8 GU ×
4 storeys**, so that *"a centred hit can crack the whole pane"* is a guarantee
rather than a hope. Reaching a maximum pane's edges from the centre needs
**32 columns and 16 rows** of fracture.

- **`wide`** should carry usable fracture out to the sheet's edges. That is what
  makes the guarantee real.
- **`tight`** is *supposed* to fall short — a pistol makes a small web (G-D14).

The gate REPORTS reach on both axes and never fails it, precisely because tight
falling short is correct.

### 1.4 ✅ The good news, and it inverts what §7.3 warned about

**A fracture sheet is authored at essentially screen resolution.** Measured
through the compositor:

| | authored | on screen | ratio |
|---|---|---|---|
| one voxel, horizontally | 16 px | 16 px | **1 : 1** |
| one voxel, vertically | 16 px | 20 px | ×1.25, `INTERPOLATE_NEAREST` |

`_get_plane_source()` resizes `1024 × 512 → 1024 × 640` and each atom crops
`Rect2i(col · 16, y0, 16, 28)`. The horizontal axis is never touched.

So a 2 px hairline is a 2 px hairline in the game. **§7.3's "detail that reads
beautifully at 256 dissolves at 1/16th linear" is a warning about the DECALS in
§2, not about the sheet** — the sheet has no downsample to survive. Author
detail freely.

The one consequence to keep in mind is the opposite of the usual one: because the
vertical resample is NEAREST at ×1.25, a horizontal line one texel tall will be
1 px in some rows and 2 px in others. Diagonal and radial lines — which is what a
fracture is — do not show it.

### 1.5 What a sheet costs, and why the order stops at two

Each sheet is one facade page: **2048 atoms, composed once at map load** — the
boot log prints the count (`[BAKE] Composed sheet … (2048 atoms)`). Two sheets is
4096 atoms on every map that contains glass, paid whether or not a single pane is
ever hit.

That is the deliberate trade G-D21 bought: **a shot mints nothing.** It only
changes which already-composed atom each voxel asks for. Three variants per width
would triple the load cost to buy variety a re-anchored sheet already produces
for free — two hits on one pane are two different offsets. **Start at two. Add a
variant only if the repetition actually reads on screen.**

---

## 2. The floor shards

`decal_shard_glass_{0,1,2}.png` — ordinary damage decals, and everything
`ART_SPECIFICATIONS.md` §7 says about a decal applies unchanged.

| Property | Value |
|---|---|
| Path | `ASSETS/materials/glass/decals/decal_shard_glass_<n>.png` |
| Dimensions | **256 × 256, square** |
| Alpha | **REQUIRED, and here it really is the art.** Everything outside a shard is transparent. **This is where §7.3's luma-to-alpha recipe belongs** |
| Colour | Full colour allowed |
| Variants | **Exactly 3.** The runtime hashes the cell's base coordinates into 0..2 |
| Peak opacity | Below 255 is the house style — 6 of the 9 shipped concrete decals peak at 150–204. Broken glass on a floor should tint it, not replace it |

### Where it lands, and the two constraints that follow

Shards ride the **floor** path (`_floor_sunk_decal_plan`), the same one `earth`'s
dent takes. That means the **top diamond**, and §7's table gives its native size
as **16 × 16, no stretch — a 1 : 16 linear downsample from the 256 canvas.**

1. **This IS the harsh read §7.3 warns about.** A shard field that is exquisite
   at 256 becomes 16 px of mush. Check at true size before delivering — a
   handful of large, high-contrast facets beats a convincing scatter of small
   ones.
2. **The corners are cut.** The square decal is projected into an isometric
   diamond and masked (`blit_rect_mask` with `top_mask`), so art in the four
   corners of the canvas is discarded. Keep the shards toward the middle.

The three variants differ by **density**, not by arrangement: G-D16a piles shards
in columns and reports depth (measured on the GLASS map: *882 shards on 37 cells,
deepest pile 24*), so a sparse, a medium and a dense plate give the pile
somewhere to go.

---

## 3. The gate — run it before telling me the art is ready

```bash
python3 tools/persistent/check_decal.py --material glass
```

Built and proven **this session, before the art** — the same order M2a took.

It checks both classes. For the sheets: the filename and width, 1024 × 512,
grayscale (B2), that the page is neither black nor lit, that the file is
IMPORTED, and **that the fracture's origin is the page centre**. For the shards:
the filename, 256 × 256, real transparency, neither empty nor opaque, imported,
and all three variants present.

### Proven red before it was trusted

A gate that rejects everything passes a rejection-only test, so the green control
came first: a synthetic well-formed sheet **PASSes**, reporting `origin ok —
centroid (-0.0, -0.0) voxels from centre` and `reach 32 col / 16 row`.

| Failure mode | What the gate says |
|---|---|
| fracture origin off centre | `FAIL … ink centroid sits (-19.5, -9.8) voxels from the page centre` |
| the crack lives only in ALPHA (§1.1's trap) | `FAIL … effectively empty — 0.000% of the page carries any fracture` |
| not grayscale | `FAIL … non-grayscale on 10571 of 524288 pixels (2.02%) — B2` |
| pre-squared to 1024 × 1024 | `FAIL … expected 1024x512 <- pre-squared` |
| a third width, `fracture_glass_medium.png` | `FAIL … width 'medium' is not one of tight/wide` |
| `decal_dent_glass_0.png` (a tier glass cannot reach) | `FAIL … family 'dent' is not one of shard for material 'glass'` |
| delivered but not imported | `FAIL … no .import sidecar` |

And the regression that matters: **all 54 shipped decals still PASS unchanged.**

**After dropping the PNGs**, let Godot reimport before launching, or every
affected voxel hard-errors at boot (B6):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

### One check that does NOT exist yet, said out loud

There is **no wiring check for the sheets**, because G-D21 is unbuilt and no
constant names them. The gate prints that warning itself rather than implying a
completeness it cannot verify. The shards' wiring check is real and already
armed: the moment the three files exist, `--material glass` fails with
`WIRING FAIL … 'glass' is NOT in IMPACT_DECAL_MATERIALS`, which is the gate
demanding §4 be done.

---

## 4. What I do when the five land

1. Run `check_decal.py --material glass` and report the measured numbers — the
   centroid, the reach, the coverage — never "looks fine".
2. **Add a `fracture_` category to `TextureResolver._validate_dimensions()`**
   (`texture_resolver.gd:176`). It infers a texture's category from the filename
   prefix and knows only `facade_`, `slice_` and `slab_`; anything else returns
   false, the file is rejected, and the surface falls back to the generic atlas
   **with no error at all**. This is the same Tier.NONE trap that once rejected a
   full-colour `facade_earth.png` silently. One `elif`, expecting
   `64 × TEX_AUTHORING_N` by `32 × TEX_AUTHORING_N`.
3. Add `"glass"` to `VoxelRenderer.IMPACT_DECAL_MATERIALS` (for the shards) and
   set `glass.json`'s `crack_factor` above `0.0` — **the two must move together
   with the art.** `voxel_decal_selftest` **[12]** asserts exactly that, in both
   directions, so a data edit without the art turns the suite red instead of the
   screen.
4. Update `ASSETS/materials/manifest.json` (`materials`, `families`) — it is what
   the runtime reads for variant discovery, and the selftest asserts it agrees
   with the constants.
5. Update `ART_SPECIFICATIONS.md` §7's file-count table: 42 → 45 decals, plus the
   two sheets as a new row.
6. Name the sheets' constant and **add the wiring check §3 says is missing.**
7. Fire a pistol and a rifle at the GLASS map's big pane and post the pair — per
   §11 of the master plan, on the real map, reading real counts, never a
   synthetic patch.

---

## 5. The Stable Diffusion route (§7.3, corrected for the sheet)

Realism: yes. And the sheet is the easy half.

| | |
|---|---|
| **the sheets** | Generate large (1024–2048) on black, desaturate, downsample to 1024 × 512, **stop.** No matting, no alpha, no tiling. The centre is the only composition constraint |
| **the shards** | Here the luma-to-alpha step applies: generate on black → alpha = luminance → RGB to the shards' own near-white. `check_decal.py` asks whether the IMAGE is transparent, so a palette PNG with a tRNS chunk passes like any ordinary export |
| **edge-matching** | Not needed any more. It was G-D20's problem, and G-D20 is superseded — one large fracture, cut nothing |
| **the true-size check** | Still the step that decides what ships, but **only for the shards** (1 : 16). The sheets are 1 : 1 — see §1.4 |

`REFERENCES/bullet-hole-transparent-glass-abstract-background-*.zip`,
`REFERENCES/Glass.png` and `REFERENCES/Glass.psd` were collected on 2026-08-02,
a month before this plan existed. Worth opening before generating anything.

---

## 6. The sheets were AUTHORED PROCEDURALLY — delivered 2026-09-02

`tools/persistent/gen_fracture_sheet.py` generates both sheets, and the pair in
`ASSETS/materials/glass/` is its output at `seed 1`. Regenerate with:

```
python3 tools/persistent/gen_fracture_sheet.py tight ASSETS/materials/glass/fracture_glass_tight.png 1
python3 tools/persistent/gen_fracture_sheet.py wide  ASSETS/materials/glass/fracture_glass_wide.png  1
```

**Why procedural rather than the §5 Stable Diffusion route.** §5 is not wrong —
SD's realism is real and the shard decals are still its natural territory. But
the sheet has two requirements SD cannot aim at: the fracture must radiate from
the EXACT page centre (§1.2), and `wide` must carry ink to the edges (§1.3).
Generated, those are a parameter and a measurement; prompted, they are a lottery
you sample until the gate happens to agree. Measured across six seeds of each
width: every centroid landed inside ±1.6 voxels of centre and every `wide` hit
32/16 reach — a 12-for-12 that no prompt loop would give.

The delivered pair, from `check_decal.py --material glass`:

| | centroid | reach | coverage |
|---|---|---|---|
| `fracture_glass_tight.png` | (−0.2, −0.1) vox | 11 / 12 | 2.61 % |
| `fracture_glass_wide.png` | (−0.5, +0.2) vox | **32 / 16** | 6.84 % |

### 6.1 The hole is denominated in VOXELS, and that was a real bug

The first drafts sized the bore in pixels, which put `wide` at ≈1.2 voxels —
a rifle hole the size of a pistol's, against ratified G-D14 (pistol / shotgun
pellet = 1 voxel, rifle-class = 2–4). `hole_voxels` is now a diameter in voxels:
`tight` = 1.0, `wide` = 3.0, the middle of the rifle band (Director,
2026-09-02, who also closed the question of a third sheet: there is none, and
G-D14/G-D21 are untouched — inside the rifle class the ENGINE destroys 2–4
voxels, the art does not grow a variant per weapon).

### 6.2 Four symmetry defects, each found only at TRUE SIZE

Every one of these passed the gate. None was visible while zoomed in. They are
recorded because they are the failure MODE of a procedural sheet — regularity
that the eye reads as ornament — and the next generator will reinvent them:

1. **The mandala.** A concentric wave drawn across every sector at one radius
   closes into a regular polygon; stacked, they read as a flower. Fixed: a wave
   is an arc of 1–4 adjacent sectors from a random start, its radius drifts as
   it goes, and outer waves mostly do not happen.
2. **The rim polygon.** The same defect at the other end of the radius — outer
   arcs chaining into a big regular ring. Fixed: beyond half the radius a wave
   spans one sector only.
3. **The slab.** A shard drawn as a free polygon in a sector floats as a flat
   grey block. It also moved the ink centroid to (+1.6, +1.8) voxels — the gate
   telling the same story in a number. Fixed: a sliver is CLIPPED to the two
   real crack paths that bound it, so it cannot float and its outline is
   irregular for free.
4. **The slab, returning through the twins.** An un-capped twin beside a `wide`
   radial opens into a huge wedge, because `wide`'s runs are three times longer.
   Fixed: a twin is capped to 16–34 % of the run.

### 6.3 The shard decals — also procedural, delivered 2026-09-02

`tools/persistent/gen_shard_decal.py`, three variants at `seed 11`. Same
scheme as the sheets, with §5's luma-to-alpha step applied — which belongs to
THIS class and never to the sheets, because the facade path destroys alpha and
a decal *is* its alpha.

| | coverage | |
|---|---|---|
| `decal_shard_glass_0.png` | 25.7 % | 256×256 RGBA |
| `decal_shard_glass_1.png` | 21.5 % | 256×256 RGBA |
| `decal_shard_glass_2.png` | 25.8 % | 256×256 RGBA |

**The 1:16 read is what set every size here, and it rejected the first pass.**
Shards drawn up to 200 authored px look magnificent at 256 and dissolve into
undifferentiated grey at 16 × 20 — §7.3's warning, arriving exactly as written.
Held to ~30–70 authored px and tripled in count, they survive as a glint field;
a handful of deliberately larger HEROES then give the reduction something that
still lands as a distinct bright pixel. Small-and-many alone averages to noise.

### 6.4 ⚠️ THE SHARD DECALS LOAD NOWHERE, AND THE GATE PRESCRIBES A FIX THAT
### WOULD BREAK CANON

`check_decal.py --material glass` now ends **WIRING FAIL**, and the failure is
TRUE — but its suggested remedy is wrong for this material, so it is written
down here before someone follows it:

> the files exist but 'glass' is NOT in IMPACT_DECAL_MATERIALS … Add the id.

**Do not add the id.** `VoxelRenderer._decal_material()` (`voxel_renderer.gd:286`)
composes names from the DAMAGE STATE for every material in that list —
`glass_cracked_*`, `glass_bullet_*`. Those are precisely the two families
G-D21 folded into the fracture sheet and that this gate's own header says glass
must never claim. Adding `glass` there would ask the renderer for wall decals
that must not exist, and `shard` is not a name that function can compose at all.

`shard` is a FLOOR mark. Its sibling, earth's dent, rides `IMPACT_FLOOR_MATERIAL`
(`= "earth"`) through `_floor_sunk_decal_plan()` — a different constant and a
different path. Glass's consumer is **G6 / `GlassFall`**, which is unbuilt:
`glass_fall.gd:119` names the shape it will need and stops there.

So the wiring check has a hole: it assumes any material with decal files must be
in `IMPACT_DECAL_MATERIALS`, which is false for a material whose only family is a
floor one. Left RED deliberately — the art really does load nowhere, and a gate
that says so is doing its job even when its advice is wrong.

### 6.5 What is NOT done

- **§4's wiring, all of it.** `TextureResolver` still knows only `facade_` /
  `slice_` / `slab_` and rejects a `fracture_` name with no error at all, so
  these two files currently **load nowhere** — the gate says so itself under
  "NO WIRING CHECK EXISTS FOR SHEETS". The art being green is not the feature
  being on.
