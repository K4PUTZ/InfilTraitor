# RESUMO_SESSAO — 2026-08-08 (D35: earth becomes buildable; material unification closed)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-08_E_SEAM_D34.md`, which closed
with the SLAB/SLICE seam unified and `earth` explicitly flagged as the one
material left outside it, blocked on art that did not exist.
**VERSION:** 0.9.90 → **0.9.91** (`verified/v0.9.91`, "Alpha Material
Unification") → **0.9.92** (`verified/v0.9.92`, "Alpha Floor Facade Fix", the
session-close checkpoint).
**Commits:** `87fa023` (E-EARTH-01), `6ec2566` (E-EARTH-02), `52156fc` (doc
sweep), `a85f714` (PLAYGROUND floor zones), `5df259b` (ATOM-SHEET). Pushed to
`main`.
**Mode:** Solo mode.

---

## What happened

The Director asked to close the unification by authoring `facade_earth.png`.
Before drawing anything, the audit surfaced that `earth` is not like the other
materials: **the string `"earth"` is doing double duty** — it is the material
name AND the sentinel for "this GU has no declared floor zone", compared in
five places that decide how the entire floor renders.

That split the work in two, and the Director scoped it: **buildable earth**
(walls, blocks, roofs — literally the "uma parede e um teto de terra" combo
described when D34 was decided), leaving earth-as-a-declared-floor-zone alone.
Only the floor path conflates the two, so walls/blocks/roofs needed no
sentinel change at all.

## E-EARTH-01 (`87fa023`) — everything but the art

Three supports, each failing differently and silently on its own, so each is
asserted separately rather than inferred from one boot:

- **The material row.** `has_facade: true` plus a `base_color` of
  `[0.52, 0.39, 0.26]` — **derived, not picked**: the mean RGB of the opaque
  top-face pixels across all eight existing `voxel_earth_N` atoms, so baked
  earth reads like the earth floor already in the game. It lands one step from
  `dirt`'s own value, which is the corroboration, not the source.
- **The canonical voxel atom.** Earth ships as eight surface variants and has
  no `voxel_earth.png`, so a naive path build push_errors and B3 masking
  degrades to unmasked rectangles. New `BakePolicy.canonical_voxel_atom_for()`
  aliases earth → `earth_0`. Safe because alpha is the only channel a
  canonical atom's masking reads, and the selftest **verifies** earth's alpha
  is identical to concrete's over all 1152 px rather than assuming it.
  Deliberately a policy function, not a copied file: `materials/` is an INPUT
  directory (ASSET-LAYOUT-01) and a duplicate there would be a derived
  artifact posing as authored art.
- **The generic atlas.** Bare `"earth"` in `BASE_MATERIALS`; without it a
  bake-OFF earth wall resolves `MATERIALS.find("earth") == -1` and paints
  itself flat concrete — and bake-OFF is the SHIPPED canon, so that is the
  release path. Appended, never inserted (`MATERIALS[0]` is the last-resort
  fallback). `earth_0..earth_7` are untouched and pinned by the selftest —
  that is EarthVariantSelector's palette for the UNZONED ground, a different
  thing entirely.

The footgun is loud now: a `floor_zones` rect declaring `"earth"` used to
vanish without a word; it push_warnings and explains why (B6).

## E-EARTH-02 (`6ec2566`) — the art, and how it first failed

**The first delivery was rejected at load for being full-colour** — 100% of
sampled pixels past the resolver's tolerance, mean RGB 181/163/138. Worth
recording because of HOW it failed: a rejected facade produces **no error
whatsoever** — Tier.NONE, generic atlas, a material that just looks vaguely
wrong. It was caught only by measuring the file. The Director re-exported
desaturated; the corrected art passes every gate measured, not assumed:
1024×512, zero pixels over the grayscale tolerance, alpha solid 255,
luminance 41..246.

The same probe caught a second silent failure mode: the `.import` was stale
(older than the PNG), and `TextureResolver` resolves through
`ResourceLoader.exists()`, so an un-imported file is invisible to the bake and
falls back silently. Both are now standing warnings in `ART_SPECIFICATIONS` §2
and in CLAUDE.md's art-authoring row.

## Verification (per CLAUDE.md's evidence discipline)

- `project_lint.py`: 188 files, 0 errors — every commit.
- `run_selftests.py`: 33/33 clean (material_reform 25 PASS, 0 FAIL).
- `check_invariants.py` / `gen_codemap.py --check`: clean throughout.
- **Real path, not reasoning:** `resolve("facade_earth")` → Tier DEFAULT at
  1024×512; the compositor composes `ROOF|earth|facade_earth` and the
  registered modulate comes back `(0.52, 0.39, 0.26)`, tinted by earth's own
  base_color like every other structural material; the built plane is 1088
  tall and **row 900** — far past the source's own 512 + margins — carries
  real opaque texels, so D34's mirrored vertical fill works on the real art,
  not just the synthetic case the selftest pins.
- **Real capture:** `Screenshots/history/e_earth_buildable.png` — an earth
  block's wall AND roof beside the stone and concrete blocks on TEST_BLOCKS.
- Before the art existed, a throwaway grayscale placeholder proved the same
  chain end to end and was then deleted along with its `.import` — plumbing
  verified working, explicitly NOT art shipped.

## Doc sweep (`52156fc`)

Every doc written for the old model corrected, or marked-not-deleted where it
is a dated decision record (the project's own precedent for reversals):
`DESTRUCTION_MASTER_PLAN` D26 (shared carved-TOP asset — partially reversed)
and D21 (its 18 MB `ground_concrete` budget figure — conclusion stands, the
accounting changed: 4 horizontal pages on PLAYGROUND where the split produced
8), `docs/README.md`'s bake and explosion rows, `MAPFILE_REFERENCE` and
`MAP_MASTER_PLAN`'s `floor_zones` rows, `ART_SPECIFICATIONS` §6 (whose
"PLANNED" premise had shipped), `DIRECTION_GLOSSARY` §10 (a new banned-terms
block for the reform), and CLAUDE.md's art-authoring row.

## After the tag — session close (0.9.92, "Alpha Floor Facade Fix")

Three follow-ups the Director asked for once `verified/v0.9.91` was pushed:

1. **Doc sweep** (`52156fc`) — every doc written for the old model corrected,
   or marked-not-deleted where it is a dated decision record. Notably
   `DESTRUCTION_MASTER_PLAN` D26 (the shared carved-TOP asset rule, partially
   reversed) and D21 (whose measured 18 MB `ground_concrete` page no longer
   exists — conclusion stands, accounting changed: PLAYGROUND composes 4
   horizontal pages where the old split produced 8), plus a new banned-terms
   block in `DIRECTION_GLOSSARY` §10.
2. **PLAYGROUND floor zones** (`a85f714`) — one patch per material aligned
   under its block group, adding the concrete patch that was missing because
   the 24×16 base is already concrete. **Reported honestly as a no-op on
   screen**: an overlapping rect of the same material resolves to the same
   value and merges into the same flood-fill component; a real boot confirmed
   byte-identical output. The value is the map file stating its intent.
3. **ATOM-SHEET** (`5df259b`) — the Director redirected mid-build ("não precisa
   perder tempo com o display dentro do game"): what they wanted was a
   printable DOCUMENT of the baked decals to work from while editing source
   art. Godot dumps every atom + a manifest
   (`INFILTRAITOR_CAPTURE_ACTION=export_atoms`, 300/300 on PLAYGROUND); Python
   composes the labeled PNG/PDF (`tools/persistent/build_atom_sheet.py`) —
   split that way because GDScript's Image API renders no text and the sheet's
   whole point is knowing which decal you are looking at. The in-game overlay
   survives as F8, the quick look.

   The sheet earned itself immediately: metal's atoms *look* like flat black
   faces. Measured, they are (58,62,66) with metal's own hue intact and zero
   truly-black pixels — dark, textured, correct. Art judgement for the
   Director, not a bug, and exactly the call the sheet exists to enable.

## State at close

- **Material unification is closed.** Wall, roof and floor of any structural
  material — concrete, metal, stone, wood, and now earth — render from one
  grayscale facade under MULTIPLY, sharing one baked page. `slab_*` survives
  only for organic ground (grass/dirt/sand/gravel).
- **Still scoped out:** earth as a DECLARED floor zone (needs the sentinel
  split across five sites that decide the whole floor's render).
- **Still open from D34:** the GPU-flush safeguard —
  `EXPLOSION_REBUILD_MASTER_PLAN` §11.
- `ASSETS/*` is gitignored (`.gitignore:52`), so `facade_earth.png` lives only
  on this machine, same as every other texture in the project.
- TEST_BLOCKS gained an earth block (2 storeys, GU [6,3]) — that fixture
  exists to eyeball block materials, and without something built from earth
  there was no way to see D35 at all. PLAYGROUND untouched.
