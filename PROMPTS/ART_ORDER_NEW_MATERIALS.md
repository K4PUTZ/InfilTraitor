# ART ORDER — the five new materials

**For:** the Director, who is authoring the art.
**Written:** 2026-08-21, against commit `8e0dda68`.
**Materials:** `brick` (tijolo) · `cardboard` (papelão) · `fabric` (tecido) ·
`plywood` (madeirite) · `glass` (vidro).

> ⚠️ **Paths updated 2026-08-21 by ASSET_TREE_REFORM** — the art moved to one
> folder per material. The files themselves are unchanged and were not re-authored.
>
> **Every number below was measured on the shipped files, not read off a
> spec.** Where this document and `ASSETS/ART_SPECIFICATIONS.md` disagree, that
> file is the canon and this one is the bug — but §1's measurements are the
> current on-disk truth and were taken for this order.

---

## 0. The short version

**You author exactly ONE file per material.** Five PNGs, all the same shape:

```
ASSETS/materials/brick/facade_brick.png
ASSETS/materials/cardboard/facade_cardboard.png
ASSETS/materials/fabric/facade_fabric.png
ASSETS/materials/plywood/facade_plywood.png
ASSETS/materials/glass/facade_glass.png
```

**1024 × 512 px · grayscale (R == G == B on every pixel) · no alpha.**

Everything else a material needs is code and data, and is mine — see §4 for
what I am building against this.

---

## 1. The facade spec, measured

| Property | Value | How I know |
|---|---|---|
| Path | `ASSETS/materials/<id>/facade_<id>.png` | `BakePolicy.facade_for_material()` returns `"facade_" + material_id`, literally — no table, no registration step |
| Dimensions | **1024 × 512** | All 8 shipped facades measured at exactly 1024×512 |
| Colour | **Grayscale, R == G == B** | All 8 measured at 0.00% non-grayscale over 10 878 sampled pixels. Invariant B2 |
| Alpha | **None.** Fully opaque | Invariant B3 — the silhouette's alpha comes from the canonical voxel atom, never from facade art |
| Coverage | 1024/16 = 64 voxel columns · 512/16 = 32 voxel rows = 4 storeys | `TEX_AUTHORING_N = 16` texels per voxel, pinned |
| Wrap | **Mirrored on BOTH axes**, not tiled | Edges get flipped, so a pattern that reads as broken when mirrored will read as broken in game |
| Pre-scale | **None. Author flat.** | The compositor stretches walls ×20/16 vertically itself. Baking that stretch into the art double-applies it |
| Never | pre-square it to 1024×1024 | D34 reaches the second 512 by mirroring vertically |

**The colour of the material does not live in this file.** It arrives at
runtime from `base_color` in `materials/<id>.json` via MULTIPLY. So author the
value structure — mortar lines, corrugation, weave, grain, glazing bars — in
gray, and tell me the hue you want and I will set it.

### The one failure mode worth naming

**A rejected facade produces no error at all.** Not a warning, not a crash —
`TextureResolver` returns `Tier.NONE`, the surface silently falls back to the
generic atlas, and the material just looks vaguely wrong. Two ways to trip it:

1. **Full colour instead of grayscale.** This already happened once: the first
   `facade_earth.png` delivery was rejected for being full-colour, and it was
   caught only because somebody measured the file.
2. **Not imported.** `TextureResolver` resolves through
   `ResourceLoader.exists()`, so a PNG that Godot has not imported is invisible.
   A stale `.import` after a re-export fails the same silent way.

So after each delivery: focus the open Godot editor for a few seconds, or run

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
```

I will run the measurement gate in §3 on every file before wiring it — that is
the check, not eyeballing it in the editor.

---

## 2. What you do NOT need to author

Each of these looked like a requirement and is not. Checked, so you do not
spend a Blender afternoon on any of them.

- **No voxel atom.** `voxel_<id>.png` (32×36, the isometric cube silhouette)
  does NOT need to exist per material. Measured all 17 shipped atoms: every one
  is 32×36 with **byte-identical alpha** (md5 `884d98981cee`), and alpha is the
  only channel a canonical atom's masking ever reads. So a new id is aliased in
  `BakePolicy.canonical_voxel_atom_for()` — the same mechanism `earth` already
  uses — and that is exactly as correct as a new file. Mine to do.
- **No roof texture.** Roofs today reproject the material's own **wall facade**
  (`ROOF-BAKE-02c`). The dedicated `roof_<material>.png` family in
  `ART_SPECIFICATIONS.md` §3 is PLANNED (ART-01), not required now. Your one
  facade serves that material's wall, roof AND floor.
  → This is also why `glass` failed before: the 520 missing roof lookup entries
    in `ROOF_BAKE_LEAK_2026-08-17.md` were **not** a missing roof family. Glass
    simply had no facade at all. One file closes it.
- **No `_2` variant.** `facade_metal_2.png`, `facade_stone_2.png` and
  `facade_wood_2.png` exist on disk and are **referenced by nothing** — grep is
  clean across `godot/`, `materials/`, `docs/`. There is no facade variant
  system; only the exact name `facade_<id>.png` is ever read. Do not author
  second variants expecting them to be picked up.
- **No damage decals, for now.** The `decal_dent_<m>_*` families (§7 of
  `ART_SPECIFICATIONS.md`, 256×256, 3 variants per family) are per-material
  art. A material without one falls back to D25's shared fracture, which is a
  real, shipped, correct-looking path. Worth authoring later per material;
  never a blocker for landing the material.

---

## 3. The acceptance gate

Run this on any delivery before telling me it is ready. It is the same check I
will run, and it answers the silent-failure mode directly.

```bash
python3 tools/persistent/check_facade.py ASSETS/materials/brick/facade_brick.png
```

I am shipping that script alongside this order. It reports, per file: exact
dimensions, colour mode, the measured non-grayscale percentage, whether an
alpha channel is present, and whether Godot has imported it. All five lines
must read PASS.

---

## 4. What I am building against this, and what I need from you

Art-independent, landing before your files arrive:

- `materials/<id>.json` for all five — resistance/dent/crack tiers,
  `flammability`, `base_color`, `has_facade: true`.
- `ShotPunchTable.RESISTANCE` and `DESTROY_MIN` rows, so each one breaks at its
  own rate rather than sharing concrete's.
- Registration in `BakeCompositor.VOXEL_MATERIALS`, `VoxelRenderer.BASE_MATERIALS`
  (appended, never inserted — index 0 is the last-resort fallback) and the
  `canonical_voxel_atom_for()` aliases.
- PLAYGROUND blocks, which are currently reserved as open floor at
  gu x=22-24 / 27-29 / 32-34 / 37-39.

**Two things I am NOT deciding on my own**, because both change the size of the
work rather than its polish, and the destruction plan explicitly lists them as
"settle before authoring, not during":

1. **What "fogo" means mechanically** for cardboard, fabric and plywood. The
   shipped ember is a decorative glow with a lifetime. Burning *through* — a
   wall that opens into a new passage — is a destructive state change and a much
   larger claim. These are different-sized features and I need the call.
2. **What a "whole window" is**, for glass's non-local break. Every other
   material's damage is local; a window is not. Whether a pane is derived from
   contiguous glass voxels or authored in the mapfile is the decision that sets
   how big glass is — which is why glass is last.

Brick I will treat as concrete's neighbour on the resistance ladder (its
original descoping reason was *"entra quase na categoria de concreto, mudando um
pouco a resistência"*) unless you want it to read differently.

---

## 6. The definitive checklist (Director asked, 2026-08-21)

*"me manda uma lista do que eu preciso fornecer: facade_fabric, slab, etc"*

### REQUIRED — 5 files, and that is the whole list

One per material folder under `ASSETS/materials/`, all **1024×512, grayscale, no alpha**:

- [ ] `facade_brick.png`
- [ ] `facade_cardboard.png`
- [ ] `facade_fabric.png`
- [ ] `facade_plywood.png`
- [ ] `facade_glass.png`

Then reimport, then `python3 tools/persistent/check_facade.py --all`.

### NOT required — with the evidence for each

- **`slab_<id>.png` — NO.** `BakePolicy.texture_for_material()` returns
  `slab_for_material()` **only when `has_facade == false`**, which is the
  photographic exception kept for organic ground (grass, dirt, sand, gravel)
  where hue *is* the identity. Every material here is structural and gets
  `has_facade: true`, so its facade serves wall, roof AND floor.
  **Proof it is dead weight:** `slab_concrete.png`, `slab_metal.png`,
  `slab_stone.png` and `slab_wood.png` all exist on disk *and are never read*,
  because those four materials have `has_facade: true`. Authoring
  `slab_fabric.png` would produce a fifth unused file.
- **`voxel_<id>.png` — NO.** See §2. Aliased in code.
- **`roof_<id>.png` — NO.** See §2. Roofs reproject the wall facade.
- **Prop art (caixas, tapumes, andaimes, toldos) — NO.** A prop is built from
  **dictionary materials**, not from its own texture: `PropDef.material_zones`,
  and `props/crate_full.json` is literally `{"default": "wood"}`. A cardboard
  crate is that file with one word changed. The prop's SHAPE is JSON
  (`size_vox` + `layers`), its SURFACE is the material's facade.
  ⚠️ But see the gap: ART_SPEC §5 records that the v1 prop renderer **ignores
  `layers` and renders props as solid GU blocks**. A crate works today; a
  toldo (thin, non-solid) needs renderer v2 (ART-01).
- **`_2` variants — NO.** No variant system exists.

### OPTIONAL, and genuinely later — damage decals

Per §7 of `ART_SPECIFICATIONS.md`: **256×256, square, alpha REQUIRED, full
colour allowed** (B2 does not bind decals), **3 variants per family per
material**, at
`ASSETS/ISOMETRIC/source_assets/voxels/decals/decal_<family>_<material>_<n>.png`.

Without them a material still takes a **real, visible mark**, via the
material-agnostic GENERIC family (`decal_generic_bullet_dented_*`,
`decal_generic_blast_crack_*` — 12 files, already on disk) composited onto that
material's own flat atom. That path resolves through `MATERIALS.find()`, which
is exactly why registration in `BASE_MATERIALS` matters.

> Correction, 2026-08-21: an earlier revision of this section said the fallback
> was "D25's shared fracture". That is the FLOOR path (`floor_damage_material()`
> routing to `IMPACT_FLOOR_MATERIAL`); for a WALL, `_decal_material()` returns
> `""` for an unlisted material and the generic family above is what actually
> draws the mark. Same conclusion — decals are never a blocker — different
> mechanism.

Worth having eventually, and only these:

| Family | Materials | Files | Why not the rest |
|---|---|---|---|
| `bullet` | cardboard, fabric, plywood, brick | 12 | The Director's own ask — *"buracos de bala em papelão e tecido"*. A bullet hole in fabric reads nothing like one in concrete |
| `dent` | brick, plywood | 6 | Soft materials tear rather than dent; glass has no DENTED tier at all (D22) |
| `crack` | brick | 3 | D32.6 — only rigid mineral materials fracture |

**Glass gets none**: D22 ratified it as DESTROYED-only, *"não vai ter dented; é
buraco feito, ou não feito"*.
