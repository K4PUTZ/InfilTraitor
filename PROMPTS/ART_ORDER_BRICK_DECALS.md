# ART ORDER — the brick decals

**For:** the Director, who is authoring the art.
**Written:** 2026-08-21, against commit `9b66d869`.
**Material:** `brick` (tijolo), and **only** brick.
**⚠️ Paths updated 2026-08-21** by ASSET_TREE_REFORM — the art tree is now one
folder per material. Author into `ASSETS/materials/brick/decals/`.
**Closes:** `MATERIALS_MASTER_PLAN` M2a.

> Every number in §1 was measured on the 45 SHIPPED decals with
> `tools/persistent/check_decal.py`, not read off a spec. Where this document
> and [`ASSETS/ART_SPECIFICATIONS.md`](../ASSETS/ART_SPECIFICATIONS.md) §7
> disagree, that file is the canon and this one is the bug.

---

## 0. The short version

**Nine PNGs, and nothing else.** Brick follows concrete exactly — Director,
2026-08-21: *"o tijolo vamos criar normalmente, seguindo o estilo do
concreto."* Concrete is the only wall material that claims all three families,
so "the style of concrete" is a complete set:

```
ASSETS/materials/brick/decals/decal_bullet_brick_0.png
ASSETS/materials/brick/decals/decal_bullet_brick_1.png
ASSETS/materials/brick/decals/decal_bullet_brick_2.png
ASSETS/materials/brick/decals/decal_dent_brick_0.png
ASSETS/materials/brick/decals/decal_dent_brick_1.png
ASSETS/materials/brick/decals/decal_dent_brick_2.png
ASSETS/materials/brick/decals/decal_crack_brick_0.png
ASSETS/materials/brick/decals/decal_crack_brick_1.png
ASSETS/materials/brick/decals/decal_crack_brick_2.png
```

**256 × 256 px · square · RGBA with real transparency · full colour allowed.**

**Nothing for the soft materials.** The order that preceded this one asked for
21 files across brick, cardboard, fabric and plywood. MAT-SOFT-01 (2026-08-21)
cut it to these nine: fabric, cardboard and plywood can no longer reach a marked
tier at all, in code and in data, so art for them would be files nothing can
ever load. **Glass gets none either** and is deferred whole (M4b) — it needs its
own crack/hole algorithm, not decals.

---

## 1. The spec, measured

| Property | Value | How I know |
|---|---|---|
| Path | `ASSETS/materials/<id>/decals/decal_<family>_<material>_<n>.png` | The runtime COMPOSES this name; it never scans the directory (a scan does not survive export packing) |
| Dimensions | **256 × 256, square** | All 45 shipped decals measured at exactly 256×256 |
| Alpha | **REQUIRED, and it must be real** | All 45 are RGBA. This is the opposite of the facade rule: a facade's alpha is DISCARDED (B3), a decal IS its alpha |
| Colour | **Full colour allowed** | B2 binds facade/pattern sources only. In practice most shipped decals are near-grey (avg RGB 90–174) and read as soot/chipping |
| Coverage | Anywhere in **2.6% – 82.9%** | The measured span of the shipped art. There is no house number — `decal_crack_concrete_1` covers 15.8%, `decal_dent_concrete_2` covers 72.9%, and both are right |
| Peak opacity | **Usually below 255, on purpose** | Concrete's nine peak at 150/204/179 · 194/254/179 · 204/255/179. The mark **tints** the face rather than replacing it — that is the house style |
| Variants | **Exactly 3 per family. Not 2, not 4** | The runtime hashes the voxel's coordinates into 0..2 and loads whichever it lands on. A gap is a boot-time B6 error; a `_3` is a file nothing can pick |
| Never | pre-project, pre-stretch, or bake in the isometric skew | §1's standing rule. A lateral face gets ×20/16 vertically from the generator |

### What each family means, and where it lands

| Family | Cause | Where it is drawn | Must NOT read as |
|---|---|---|---|
| `bullet` | a firearm | the **one lateral face** the round struck (SW/SE) — never a top, never a floor | a chip. This is a puncture |
| `dent` | an explosion, on a **half** voxel | the cut plane of a lateral half; the sunken top of a floor half | a round puncture — D32.7: an explosion never makes a bullet hole |
| `crack` | an explosion, on a **whole** voxel | **all three visible faces at once** — a voxel barely holding together cannot read pristine on one side and shattered on the other | a dent. Fracture lines, not a depression |

**Brick-specific, and the reason brick claims `crack` while metal and wood do
not** (D32.6): brick is a rigid mineral material, so it **fractures**. Cracks
should read as fracture running along and through the mortar lines your
`facade_brick.png` already establishes — a crack that ignores the courses will
read as a scratch on top of the bricks rather than damage to them.

At the size these are actually seen — 16 × 20 px on a lateral face — a gently
perturbed circle still reads as a circle. **Facets and straight segments are
what separate a chip from a bullet hole.**

---

## 2. The gate — run it before telling me the art is ready

```bash
python3 tools/persistent/check_decal.py --material brick
```

Built and proven for this delivery. It checks the filename, 256×256, the alpha
channel, that the canvas is neither empty nor fully opaque, that the file is
IMPORTED, that all 3 variants of each family exist, **and** that
`IMPACT_DECAL_MATERIALS` agrees with what is on disk in both directions.

It was validated the way `check_facade.py` had to be: it passes all 45 shipped
decals unchanged, and it was run red against five real failure
modes — no alpha channel, non-square, an empty canvas,
a `_3` variant, and a family missing its variant 2 (proven by temporarily
removing the real `decal_crack_concrete_2.png`). Two of its own checks were
CORRECTED by that exercise: the constant parser was mangling the first entry on
`Array[String]`'s bracket, and `earth` was reported as unwired because it rides
a different constant.

**After dropping the PNGs**, let Godot reimport before launching, or every
affected voxel hard-errors at boot (B6):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

### The failure mode worth naming

`brick` is **not** in `VoxelRenderer.IMPACT_DECAL_MATERIALS` yet, and adding it
before the files exist is a **silent miss** — not a warning, not a crash. The
material simply keeps falling back to the generic grey mark and looks vaguely
wrong. So the id goes in only once the gate is green, and the gate now fails
loudly on exactly that mismatch.

---

## 3. What brick looks like TODAY, so you can judge the delta

Brick already takes real marks — through the material-agnostic GENERIC family,
composited onto brick's own atom. Measured on the real map this session, one
shotgun burst from GU (23,10) at a guard on (23,5), into the brick block at
(22..24, 2):

```
[AGENT-SHOT-TIER] brick:s1  cracked=0 dented=15 destroyed=8  (resist 1.15, breach 0.71)
[AGENT-SHOT-TIER] brick:s2  cracked=0 dented= 8 destroyed=0
```

Capture: `Screenshots/history/shot_mat_brick_control_3_damage.png`. Those 23
dents are the grey generic mark. **This order replaces them with brick's own** —
which is why M2 is quality, never a blocker.

### Reviewing the baked result

A decal never appears as you authored it: what lands on a voxel is the decal
composited onto a crop of `facade_brick.png` and tinted by `base_color`. Two
commands produce a printable contact sheet of every baked atom, to look at while
editing:

```bash
INFILTRAITOR_CAPTURE_ACTION=export_atoms python3 tools/persistent/auto_screenshot.py
python3 tools/persistent/build_atom_sheet.py
```

---

## 4. What I do when the nine land

1. Run `check_decal.py --material brick`; report the measured numbers, not "looks fine".
2. Add `"brick"` to `VoxelRenderer.IMPACT_DECAL_MATERIALS`, and to
   `IMPACT_CRACK_MATERIALS` (it fractures; metal and wood do not).
3. Update `voxels/manifest.json` — `materials` and `crack_materials`. It is what
   the runtime reads for variant discovery, and `voxel_decal_selftest.gd`
   asserts the two agree.
4. Update `ART_SPECIFICATIONS.md` §7's file-count table: 33 → 42.
5. Re-run the same shotgun burst at the same cells and post the before/after
   pair — the delta above is the acceptance evidence.
