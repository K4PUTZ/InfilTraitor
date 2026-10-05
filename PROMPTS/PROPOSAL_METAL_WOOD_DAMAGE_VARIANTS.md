# PROPOSAL — damage variants for metal and wood

**Status (2026-10-05, later): CLOSED with option A as "keep the authored art".** A metal redraw (puncture / graze / flaked; buckle / crumple / bloom, `gen_metal_decals.py`) was built and judged worse than the original, so it was reverted (the files are in `ARCHIVE/metal_decals_2026-10-05_optionA/`); the wood originals already cover option A, so wood is untouched. Option B and the fire-tied charred variants were never ruled. The text below is the original proposal. Part of R3D-LOOK L1.
**Asked by the Director (2026-10-05):** metal and wood do not crack like stone, "mas poderíamos ter outros tipos de variação".

## 1. What exists, and the rails any proposal runs on

Metal and wood take two decal families today: `bullet` and `dent` (3 variants each, 6 files per material).
`crack` is stone-class only (D32.6: `crack_factor` 0.0 for both, `IMPACT_CRACK_MATERIALS` = concrete, stone, brick).

The rails, all measured in the code on 2026-10-05 (`VoxelStore` state byte, `Board3DLive._decal_faces`):

| Rail | Consequence for this proposal |
|---|---|
| The damage STATE has four values: INTACT, CRACKED, DESTROYED, DENTED (2 bits) | A new look attaches to an existing state or needs a bit nobody has (the byte is full: visible 1, state 2, blast 1, carved side 3) |
| D32.3: a state is exclusive; CRACKED draws on all three visible faces, DENTED on the carved face (a recess) | A new CRACKED-slot mark is a three-face mark; a DENTED-slot mark is one face, in a pit |
| D32.7: an explosion never makes a bullet hole | A bullet-class mark never appears on a blast-written voxel |
| The variant is 4 bits (0..15) but the runtime hashes into 0..2 (`IMPACT_DECAL_VARIANTS`) and `check_decal.py` demands exactly 3 per family | More looks per family means a bigger variant count in code, gate and selftest, or more families |
| A decal's family name is composed into the file name; the catalogue loads only what is on disk | A new family is a new loop entry in `_build_decal_catalog`, `_decal_faces`, `check_decal.py`, `voxel_decal_selftest` |

## 2. What already reads, so art effort goes where it is needed

Measured as mean relative luminance change when a decal is composited over its wall (the brick/concrete/stone analysis of 2026-10-05):

| Material | bullet | dent |
|---|---|---|
| metal (wall L 0.31) | 20 – 29 % | 5 – 12 % |
| wood (wall L 0.27) | 6 – 15 % | 17 – 25 % |

Metal's bullet marks and wood's dents are strong. **Metal's dents (5-12 %) and wood's bullets (6-15 %) are the weak ones** (the same dark-on-dark failure brick had), so any redraw starts there.

## 3. The two options

### Option A — more LOOKS inside the states metal and wood already have (recommended first)

No runtime gating change, no new state, no D32.6 change. The variety comes from what the three variants of each family depict.
The families stay `bullet` and `dent`; a variant is a different *event*, not a different crack:

| Material | `bullet` variants (3) | `dent` variants (3) |
|---|---|---|
| **metal** | 0 clean puncture with a bright petalled rim · 1 oblique graze: an elongated gouge with a bright scraped streak (a ricochet) · 2 puncture with paint flaked off round it, bare steel showing | 0 buckle: a shallow concave crease with a light/dark lip · 1 crumple: a folded fan of ridges · 2 blast bloom: dished, with a soot-to-heat-tint ring |
| **wood** | 0 entry hole with a pale splinter star · 1 raking splinter: a long pale shaving torn along the grain · 2 hole with a charred ring | 0 gouge: a scooped scar of pale heartwood · 1 split-out: a torn splinter plate, grain visible · 2 scorched scoop: charred rim, pale core |

Cost: **12 PNGs** (6 per material, replacing the current 12), a generator like `gen_brick_decals.py` per material, no code change except `voxel_decal_selftest`'s expectations if they pin the art. The dent bowl geometry (built 2026-10-05) already gives a metal dent a dish and a wood dent a scoop.
Risk: low. The Director's eye decides the art; the gate is the existing `check_decal.py`.

### Option B — give metal and wood a CRACKED-slot mark of their own (a design change, needs a ruling)

Lift D32.6 in a limited way: metal and wood get a small `crack_factor` and a `crack` family, but the mark is **not a fracture**:

| Material | `crack` meaning | Why it is honest |
|---|---|---|
| **metal** | **tear / seam-split**: a short jagged rip with curled lips, plus heat discoloration (a stressed sheet near failure) | a plate that nearly gave way does not look cracked like stone; it tears and warps |
| **wood** | **split along the grain**: long straight parallel fissures with raised splinters | wood fails along its grain |

This is the "ainda se segurando, aos trancos e barrancos" tier of D32.3, which would otherwise be missing for the two materials (their blast-damaged walls skip it: the voxels beyond the dent ring stay pristine, the same "freed share" D32.6 left untouched).
Cost: **6 PNGs** + `crack_factor` for the two rows in the resistance table (a **balance change**, to be ruled) + `IMPACT_CRACK_MATERIALS` + the selftest + `check_decal.py` ("crack" for metal/wood). It changes how often walls of these materials show damage after a blast, which D32.6 deliberately refused to do unasked.
Risk: medium (balance), the art risk is the same as A.

## 4. Recommendation and the questions I need answered

**Recommend A now, B only if you want more blast-ladder variety on those materials.** A is art-only and fixes the two weak marks measured above; B is a rule change with a balance effect.

1. **A or B, or both?** (B includes A's art for `bullet`/`dent`.)
2. **If B, may `crack_factor` for metal and wood leave 0.0?** What value (concrete and stone are 0.1)? Or should the tear/split appear only as a *variant* of the dent, with no tier change?
3. **Wood and fire:** wood is the flammable material. Should the scorched variants (wood dent 2, bullet 2) be tied to the fire system (a charred look only where fire reached) rather than picked by hash? That is a gameplay-coupled rule, not art, and I would not build it without your word.
4. **Order:** metal first (its dent is the weakest), then wood.

Nothing is written until you rule. The art tooling for A is ready to reuse: `tools/asset_generation/gen_brick_decals.py` (blobs, fbm, line work) and `gen_crack_decals.py` (the palette pattern); the display for judging is the scenario step `decal_wall <material> <gx,gy>` (`godot/scripts/world/room.gd`).
