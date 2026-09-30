# PROP_PIPELINE_PLAN
## Drop-in models: a pipeline like the textures', for props, vehicles and voxel objects — v0.1 (PLANNING, nothing built)

Session 2026-09-30, Director's planning round. Sibling of [`PROPS_TIER4_PLAN`](PROPS_TIER4_PLAN.md) (which owns what a prop looks like and how it breaks) — this file owns **how a model
gets into the game**: authored by us, dropped in by a player, or taken from an open voxel library. Canon it obeys: materials come from OUR registry (PROPS_TIER4 D-P1), the texture pipeline's
two-tier `res://` / `user://` rule (user wins) and its loud-fail discipline (B6), and R3D-CLAIMS (no new per-voxel engine state that is not needed).

## 0. The Director's questions, answered

**Can the game load a 3D object and show it at runtime?** Yes, and it is a supported Godot 4 path: `GLTFDocument.append_from_file()` + `generate_scene()` works in an exported Android build, from
`user://` as well as from the pack; it needs no editor import. So a "player Y's car" can be a file in the user tier that replaces "player X's car" in the same place.

**Our own extension, with models processed for the game?** Yes, and it is the right call, for a reason that is not about speed: **safety**. A Godot `.tres` / `.res` / `.tscn` loaded from disk can carry a
script, i.e. run code; a file a player supplied must never go through `ResourceLoader`. glTF is pure data (no scripts), but it is a big format and a loose one. So:
- **Exchange format:** GLB (glTF binary). What artists and open libraries already produce. The dev path loads it directly.
- **Shipping / player format: `.iprop`** — a data-only package (a ZIP read with `ZIPReader`: `manifest.json` + flat vertex/index buffers + optional `voxels.bin`), produced by an offline compiler from a GLB, parsed by OUR code into an `ArrayMesh`
  (`add_surface_from_arrays`). No script, no `Resource` deserialisation, hard size limits checked before allocating, every field validated. It also carries the parts the engine would otherwise compute at load (the
  voxelisation for fragments and shadows, the zone list, the fitted size), so the handsets do less at load.
- **The contract is the point, not the format** (§1).

## 1. The slot: what lets two different models be the same thing to the game

A model does not define gameplay. A **slot** does (`props/slots/<id>.json`): a visual container the game promises and any conforming model fills.
- `footprint_gus`, the **max box** (size in GU, so a model can never be bigger than the space it claims), the **pivot** (centre of the footprint, on the floor) and the **front axis**;
- gameplay: cover, blocks, destructible tier, hit volumes — **taken from the slot, never from the model** (a prettier car is not a harder car; fair by construction, and no player-supplied number reaches the simulation);
- the **zones** the model must/may name (`body`, `glass`, `wheels`; a surface's name selects the registry material, PROPS_TIER4 D-P1) and a per-zone default;
- budgets: triangles, surfaces (draw calls), file size, bounding box;
- **no textures from the model**: colour and detail come from the material library (so a hundred player cars share one palette and cost no texture RAM); a model may only choose a zone and, for `painted_metal`, a tint from a small palette.
A `vehicle_sedan` slot is filled by the default sedan we ship; a player's `user://props/my_car.iprop` declaring `slot: vehicle_sedan` replaces it on load **if it validates**; if not, the shipped default is used and the reason is logged
(B6: loud, never silent). The same idea covers skins for weapons lying on the floor, furniture sets, a player's "trophy" on a shelf.

## 2. Three kinds of content, one loader

| Kind | Source | Becomes | Destruction | Tier |
|---|---|---|---|---|
| **Mesh model** | GLB -> `.iprop` | `PropMesh3D` (what exists today) | Tier 3: soot only; Tier 4: the fragment replacement (PROPS_TIER4 §2.2) | 3 / 4 |
| **Voxel model** | MagicaVoxel `.vox` (open libraries, §4) -> `.iprop` with `voxels.bin` | a `PropBlock`-style container in the `VoxelStore` (the crate's path) | **free**: the whole blast / firearm / burn / charred / debris machinery already works on it | 2 |
| **Procedural** | `PropDef` with `size_vox` / `hollow_shell` | what exists (the crate) | as today | 1 / 2 |

## 3. Voxel models (the Director's third idea): yes, this is the cheap way to fill the room with mundane square objects

**Why it works here:** the board already draws any voxel container through one mesher (faces merged by MATERIAL, facade sampled at 16 texels per voxel, light and soot read from the cell planes). A voxel prop is one more container: it gets the look of the walls
and crates, light, soot, charred tone, fire, blast and firearm damage, picking, rotation and save for free. The crate (`crate_full`, hollow shell) is this path already.

**What the import does (`.vox` -> container):**
1. Parse `.vox` (a small documented chunk format: `SIZE`, `XYZI`, `RGBA`): ~100 lines, bounds-checked.
2. **Scale:** the model's voxel size is set per asset to land on our board voxel (1/8 GU) or an integer multiple (a 2x2x2 block per source voxel for chunky art). A table must come out 8 x 5 x 5 board voxels, not 40 x 25 x 25.
3. **Hollow it:** keep only voxels with an empty 6-neighbour (the crate's `hollow_shell` idea), so a 16^3 model is ~1 200 claims, not 4 096. Claim cost is ~64 B (PLAYGROUND: 216 400 claims = 13.8 MB), so even 50 props of 500 claims are ~1.6 MB.
4. **Colour -> material:** each palette index maps to a registry material (a sidecar `palette.json`, default = nearest `base_color`). The store keeps one material byte per claim, so a model with 12 colours needs <= 12 materials present; unmapped = the family / generic fallback (PROPS_TIER4 §2b).
5. Register as a `PropBlock`-kind container (an irregular one, like the hollow crate).

**Limits, stated now:** (a) per-voxel colour is per MATERIAL: a red car with black tyres is `painted_metal` (red tint variant) + `rubber`; arbitrary colour voxel art is quantised to the library, on purpose (one universe); (b) every extra material on a chunk is an extra draw, so a model is held to <= 4 materials
(a budget the validator enforces); (c) very large voxel models (vehicles at 1/8 GU are ~40 x 20 x 16 voxels, ~2 500 shell claims) are allowed but counted against a per-map claim budget.

**Sources surveyed (2026-09-30; each asset's own licence decides, the source does not):**
| Source | Content | Licence (as listed) |
|---|---|---|
| [Medieval Theme Voxels Asset Pack, OpenGameArt](https://opengameart.org/content/medieval-theme-voxels-asset-pack) | 363 `.vox` models (furniture, barrels, crates, tools) | CC0 |
| [Voxel Buildings, OpenGameArt](https://opengameart.org/content/voxel-buildings) | `.vox` + OBJ/FBX/Blend | CC0 |
| [PixVoxelAssets (GitHub)](https://github.com/tommyettinger/PixVoxelAssets) | voxel models exportable to `.vox` | CC0 |
| [enkisoftware/voxel-models (GitHub)](https://github.com/enkisoftware/voxel-models) | Avoyd-format models | CC BY 4.0 (attribution required: recorded in `props/MODEL_SOURCES.md`) |
Rule already in force (D57): CC0 is a hard filter for what ships; CC BY only with the attribution kept and the Director's word. Every imported model is logged in `props/MODEL_SOURCES.md` (source, author, licence, date, who approved).
Honest expectation: the libraries are heavy on medieval / fantasy themes; the mundane modern objects this game wants (desks, lockers, crates, shelves, barrels, drums) are the easy ones, vehicles and electronics will mostly be ours.

## 4. The pipeline (like the textures')

```
GLB / .vox  ->  tools/persistent/build_prop.py (offline compiler)  ->  <id>.iprop  ->  check_prop.py (validator, like check_facade.py)
                                                                              |
                          res://props/ (shipped)   or   user://props/ (a player's; user wins on id collision)
                                                                              v
                       PropLoader (runtime): validate against the SLOT -> build mesh / container -> register in PropRegistry
                       on ANY failure: the slot's shipped default + one loud line (B6)
```
- `build_prop.py`: reads GLB/.vox; applies the slot's fit (rotation, uniform scale into the max box, pivot); maps surface names / palette to material zones; decimates only if asked; voxelises (PROPS_TIER4 §2.1); writes `.iprop`. Deterministic (same input, same bytes).
- `check_prop.py`: the gate — triangles, surfaces, file size, box, zones all known, no NaN, hashes; it runs in `verify.py quick` for every shipped prop, and the loader runs the SAME checks on a user file at load.
- Loading is **lazy and budgeted**: a prop is built when a map that needs it loads, never on boot; a file over its limit is rejected before it is read into memory.
- Packs: a prop pack is a DIRECTORY on either tier (`props/<pack>/*.iprop` + `pack.json`), the same shape as a material pack (ASSET_TREE_REFORM), so "downloadable content" is a folder.

## 5. Stages (each: `verify.py smoke`; the ones that load files also get a hostile-input test)
- **PP1 — the slot and the loader for GLB in dev:** `props/slots/*.json`, `PropDef.slot`, the validator logic as a pure class with a selftest (oversize, too many triangles, unknown zone, NaN); the GLB path already drawn (`setup_model`) goes through the slot's fit.
- **PP2 — `.iprop`:** the format spec (a short doc), `build_prop.py`, `check_prop.py`, `PropLoader` with `ZIPReader`; a hostile-file suite (truncated, oversized counts, bad offsets, a zip-bomb ratio, a file that claims 4 G vertices) — none may crash, hang or allocate past its limit.
- **PP3 — user tier:** `user://props/`, id collision (user wins), the slot default on rejection, the log line. Test on the Moto (path under `Android/data/<pkg>/files`, as `dev_flags.cfg`).
- **PP4 — voxel models:** `.vox` parser, scale/hollow/palette mapping, the container registration; first content: 5-10 CC0 objects (crate variants, shelf, barrel, desk, locker) placed in PROPS; blast + firearm + fire on each; the claim count and Moto memory (`alloc` census).
- **PP5 — material-tint variants** (`painted_metal` red/blue/...): how many fit in the 256-material byte and what they cost per chunk.
- **PP6 — the first vehicle slot** with our own default model, to prove a swap end to end (two different `.iprop` files in the same slot, same footprint, same cover).

## 6. Open questions for the Director (recommendation first)
1. **Multiplayer / sharing?** The design assumes player models are cosmetic and local (a `user://` file). If another player must SEE your car, the file travels: then size limits, hashing and a review path become product questions. *Recommend: decide before PP3; keep it local until then.*
2. **Who validates a player's model?** *Recommend: the loader alone, with hard limits and a fallback, no trust.*
3. **Voxel models: our board voxel (1/8 GU) as the target, chunky multiples allowed?** *Recommend: yes.*
4. **Do we ship the `.vox` library curation (5-10 objects) before or after the pipeline?** *Recommend: after PP4, so every model is chosen against the real container, not guessed.*

## 7. Risks
- **Untrusted files** are the whole security surface: never `ResourceLoader`, never scripts, limits before allocation, fuzz-style tests in PP2.
- **Licences:** a single CC BY or unknown-licence file in the pack is a release problem; `MODEL_SOURCES.md` is gated (every `.iprop` in `res://props/` must have a row).
- **Triangle / draw budget on the Moto:** the validator's limits are guesses until PP1 measures 20 props on the device.
- **A voxel prop adds claims to the store** (R3D-CLAIMS's concern): the per-map claim budget is enforced, not hoped.
