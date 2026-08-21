# ASSET_TREE_REFORM
## One folder per material — plan, v0.1 (awaiting the Director's ruling on §3)

**Status:** 🟠 **PLAN ONLY. Nothing has been moved.**
**Written:** 2026-08-21, against `7c7fb6ec`.
**Asked for by the Director, 2026-08-21:** *"reorganizar todos os materiais,
texturas, decals, artes, facades, etc., numa árvore lógica coerente, e atualizar
o código… tudo que for relativo a concreto deve estar na pasta
`assets/materials/concrete/`… Isso é importante porque vamos ter muitas trocas de
artes ao longo da vida útil do game, e fazer essa mudança precisa ser trivial e
bem fácil de encontrar… com calma e com cuidado, pra não quebrar nada."*

---

## 1. The inventory, measured

Every figure below was counted on disk, not estimated.

| What | Where today | Files |
|---|---|---|
| Facades | `ASSETS/TEXTURES/defaults/facade_<id>.png` | 10 |
| Floor/slab textures | `ASSETS/TEXTURES/defaults/slab_<id>.png` | 8 |
| Voxel atoms | `.../source_assets/voxels/materials/voxel_<id>.png` | 17 (8 of them `voxel_earth_0..7`) |
| Half atoms | `.../source_assets/voxels/halves/voxel_<id>_half_<side>.png` | 17 |
| Decals | `.../source_assets/voxels/decals/decal_<family>_<id>_<n>.png` | 47 (12 of them the material-agnostic `generic` family) |
| Data rows | `materials/<id>.json` (repo root) | 14 |
| **Total** | | **~113 files** |

**Ten code files hold a path**, and only six of them hold a *root*:

| File | Constant |
|---|---|
| `voxel_renderer.gd:138` | `VOXEL_ASSET_ROOT` → `materials/` and `decals/` templates |
| `texture_resolver.gd:21` | `tex_default_dir` (+ `tex_user_dir`) |
| `bake_compositor.gd:80` | `VOXEL_BASE_PATH` |
| `earth_variant_selector.gd:17` | `ASSET_PATH_TEMPLATE` |
| `tools/asset_generation/generate_voxel.py:89` | `VOXEL_ROOT` |
| `tools/persistent/check_facade.py` · `check_decal.py` | `DEFAULTS_DIR` · `DECAL_DIR` |

The rest are selftests and the audit tool (`material_reform_selftest.gd`,
`voxel_decal_selftest.gd`, `bake_selftest.gd`, `tile_anatomy_audit.gd`), plus
`voxels/manifest.json` and the docs.

**This is a small refactor.** ~113 asset files and six real constants.

### Explicitly OUT of scope

`ASSETS/ISOMETRIC/source_assets/actor_bakes/` — **~5 800 PNGs**, and a different
axis entirely (character, weapon, pose, palette). It has its own naming contract
in `docs/pipelines/character_bake_pipeline.md`, and folding it into the same pass
would turn a tractable change into the session's whole budget. Worth its own
reform later; not this one.

`source_assets/generated/` (4 floor tiles) is **borderline** and needs a ruling:
it is the only asset folder referenced from a `.tres`
(`godot/resources/tilesets/tileset_blocks.tres`, by **path**, not by UID), so
moving it means editing that file too. Recommendation: leave it where it is this
pass.

---

## 2. Two things found while counting

**`ASSETS/ISOMETRIC/source_assets/voxels/brics/` is 9 duplicate files.** Every one
is byte-identical (md5) to the concrete decal of the same name in `decals/`, and
the string `brics` appears in **no** `.gd`, `.py`, `.tres`, `.json` or `.md` in
the repo. It is an unreferenced copy — most likely a staging folder from the
decal authoring pass. **Not deleted**: removing files is the Director's call, and
CLAUDE.md's standing rule is that an unrequested cleanup is a defect. Flagged
here for a decision.

**The `user://` override tier makes this reform worth more than tidiness.**
`TextureResolver.resolve()` tries `user://textures/<id>.png` *before*
`res://ASSETS/TEXTURES/defaults/<id>.png` — that is the seam the
downloadable/procedural per-playthrough material vision runs on. Today a material
pack would have to scatter its files across four flat folders that also hold
every other material. **Under this reform a material is ONE folder**, on both
tiers, so shipping or swapping one becomes copying a directory. That is the
Director's stated reason (*"muitas trocas de artes"*) turning out to be
structural rather than cosmetic.

---

## 3. ⚠️ THE ONE DECISION THAT HAS TO COME FIRST — do the FILENAMES change?

Both options give the folder tree the Director asked for. They differ in what the
files inside are called, and the difference is not cosmetic — it decides how much
code moves and how a file reads when it is out of its folder.

**The mechanism, so the choice is made on what actually happens rather than on
taste:** `TextureResolver.resolve(texture_id)` builds a path by
`dir.path_join(texture_id + ext)` — a flat directory plus an id. `BakePolicy`
hands it the literal string `"facade_" + material_id`. So today the *filename* is
the lookup key, and there is no folder in the question at all. Any per-material
tree has to teach the resolver the material, whichever option is chosen:

```
resolve("facade_concrete")            →  <dir>/facade_concrete.png          (today)
resolve("facade_concrete", "concrete") →  <dir>/concrete/facade_concrete.png (A)
resolve("facade", "concrete")          →  <dir>/concrete/facade.png          (B)
```

**Option A — keep the filenames, move only the folders.**

```
ASSETS/materials/concrete/facade_concrete.png
ASSETS/materials/concrete/slab_concrete.png
ASSETS/materials/concrete/voxel_concrete.png
ASSETS/materials/concrete/halves/voxel_concrete_half_left.png
ASSETS/materials/concrete/decals/decal_bullet_concrete_0.png
ASSETS/materials/concrete/concrete.json
```

Every filename still says what it is when it is on a desktop, in a diff, in a
screenshot, or attached to a message. `grep facade_brick` still finds
everything. The templates gain one `%s`.

**Option B — the folder carries the identity, the file carries the role.**

```
ASSETS/materials/concrete/facade.png
ASSETS/materials/concrete/slab.png
ASSETS/materials/concrete/voxel.png
ASSETS/materials/concrete/halves/left.png
ASSETS/materials/concrete/decals/bullet_0.png
ASSETS/materials/concrete/material.json
```

A tidier tree, and a material pack becomes a folder of identically-named files —
which is *better* for the `user://` override story. The cost: `facade.png` alone
is anonymous, ten of them in a downloads folder are indistinguishable, and every
grep for a material's art becomes a path grep instead of a name grep.

**Recommendation: A.** The reason is the failure mode this project already has on
record — a wrong facade produces **no error at all** (`Tier.NONE`, generic atlas,
silently wrong). Self-identifying filenames are the cheapest defence against
dropping the right art in the wrong folder, and art gets dropped by hand.

*(A third shape exists — keep filenames AND let the resolver fall back to the old
flat folder during the migration. Rejected on sight: two live locations for the
same art is exactly how the `ground_concrete`/`concrete` duplicate-row bug
happened, and it is the state this reform exists to end.)*

---

## 4. The proposed tree (shown in Option A)

```
ASSETS/materials/
  _generic/decals/          decal_generic_*  (12) — material-agnostic, D25
  brick/  cardboard/  concrete/  dirt/  earth/  fabric/  glass/  grass/
  gravel/ metal/  plywood/  sand/  stone/  wood/
```

Fourteen material folders, matching `MATERIALS` registration exactly — which
gives the reform a free invariant: **a registered material with no folder, or a
folder with no registration, is a bug**, and a selftest can say so. That check
does not exist today and is the reason `glass` rendered wrong for months.

---

## 5. Order of work — one stage per commit, gates between

Nothing here is clever; the care is all in the sequencing.

| # | Stage | Gate that must pass before the next |
|---|---|---|
| **0** | **Write the inventory as a machine-readable manifest** — every file, its current path, its destination. The migration script reads it; nothing is moved by a wildcard | the manifest lists exactly the counted files, no more |
| **1** | Teach `TextureResolver`, `BakeCompositor`, `VoxelRenderer`, `EarthVariantSelector` to take a material folder, **still pointing at the old locations** | full selftests + a real-map capture identical to a same-boot control |
| **2** | Move the files (PNG **and** its `.import` sidecar together), then `godot --headless --import` | `check_facade.py --all` · `check_decal.py --all` · both must be green, and they are the gates that catch a silent miss |
| **3** | Flip the roots to `ASSETS/materials/` | full selftests + `tile_anatomy_audit` + a real-map capture diffed against stage 1's |
| **4** | `materials/<id>.json` into its folder, and mirror the shape on `user://` | `material_reform_selftest` |
| **5** | The new invariant: every registered material has a folder and vice versa | a selftest, run red by removing one folder |
| **6** | Docs: `ART_SPECIFICATIONS`, both art orders, `ASSET_PIPELINE_QUICK_REFERENCE`, `docs/README` | no dead links |

**Stage 2 is the dangerous one, and the danger is specific.** A PNG's `.import`
sidecar records the source path; moving the PNG without it, or without
re-importing, leaves the compiled `.ctex` orphaned — and the symptom is
`Tier.NONE`, which renders **something** and reports **nothing**. That is why
`check_facade.py` and `check_decal.py` are the stage gate rather than "it looks
right": both already read the sidecar's own `dest_files` and fail when the
compiled resource is missing.

**Verification that the reform changed nothing visually** is a same-boot control
pair, per the standing rule: capture PLAYGROUND before stage 2 and after stage 3
from the same binary and diff. A material that fell to the generic atlas will
show as a large pixel delta; a clean move is 0.

---

## 6. When

**Recommendation: before the brick decals are authored (M2b).**
`ART_ORDER_BRICK_DECALS.md` names nine destination paths. If the Director draws
into those and the tree moves afterwards, the order rots and the art moves twice.
Doing the reform first means the order is rewritten once, against the final tree,
and the first art ever authored into the new layout is authored there natively.

It also lands cleanly against the current state: M1, MAT-SOFT-01, M2a, M3-1 and
M3-2 are all closed and pushed, and the next material tasks (M3-2b half-thickness,
M3-3 fire) touch geometry and behaviour, not asset paths — so the reform collides
with nothing that is in flight.
