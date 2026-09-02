# Session 2026-09-02 — G-ART delivered, and the two things it found

The previous session is
[`RESUMO_SESSAO_2026-09-01_PART3_GART_AND_G_VARIANT.md`](RESUMO_SESSAO_2026-09-01_PART3_GART_AND_G_VARIANT.md),
which closed G-VARIANT and left G-ART's order and gate written but the art
undelivered. **This session delivered it**, wired what §4 could be wired, and
surfaced two blockers that are Director decisions rather than work.

| | commit |
|---|---|
| the fracture sheets, procedural | `8c402270` |
| the shard decals, and a wiring check whose advice would break canon | `a7394107` |
| §4 — the sheets are wired, and step 3 turns out to be a contradiction | `8f906ad4` |
| `update_docs` — undetermined is not empty | `34bb91dc` |

---

## 1. The question that started it: can Stable Diffusion author this?

**It could not be answered from this machine, and that is the first finding.**
There is no SD install on the Mac mini — no `stable-diffusion-webui`, no ComfyUI,
no `diffusers`, no checkpoints on disk. That matches **D58**
(`ACTOR_MASTER_PLAN:301`): generative work lives on the Director's PC, and this
Mac is Front B. Inspecting it is the Director's to do.

So the question became an experiment instead: build the art two ways here and
measure both against the real gate.

**The reference route died on a measurement.** `REFERENCES/bullet-hole-…zip`
(Freepik / macrovector, free licence requires attribution) has exactly the right
vocabulary, but the transparency checkerboard is BAKED into the 4500² JPG. A
global black point left 22.4 % of a corner above the ink threshold at luminance
115; a median-filter background subtraction left 22.3 %. The reason is
structural, not a tuning failure: **the checker's edges are thin bright lines,
which is the same signal the crack is.** The clean source is the accompanying
EPS, and this Mac has no rasteriser (no gs, Inkscape or ImageMagick).

**Procedural won, for a reason that is not aesthetic.** The sheet has two hard
requirements — radiate from the EXACT page centre (G-D21), and carry ink to the
edges on `wide` (G-D23). Generated, those are a parameter and a measurement.
Prompted, they are a lottery sampled until the gate agrees. Across six seeds of
each width: every centroid inside ±1.6 voxels, every `wide` at 32/16 reach.

## 2. The art

`tools/persistent/gen_fracture_sheet.py` and `gen_shard_decal.py`, both
committed; the PNGs are gitignored like every other asset.

| file | measurement |
|---|---|
| `fracture_glass_tight.png` | centroid (−0.2, −0.1) vox · reach 11/12 · 2.61 % ink |
| `fracture_glass_wide.png` | centroid (−0.5, +0.2) vox · **reach 32/16** · 6.84 % ink |
| `decal_shard_glass_{0,1,2}.png` | coverage 25.7 / 21.5 / 25.8 % |

**A real defect against ratified canon, found by the Director's question "is the
centre based on a voxel?"** It was not — the bore was sized in PIXELS, which put
`wide` at ≈1.2 voxels: a rifle hole the size of a pistol's. G-D14 gives
pistol/pellet 1 voxel and rifle-class 2–4. `hole_voxels` is now a diameter in
voxels (1.0 / 3.0, the middle of the rifle band). **No third sheet** — inside the
rifle class the engine destroys 2–4 voxels; the art does not grow a variant per
weapon.

### 2.1 Four symmetry defects that PASSED the gate

Each was invisible while zoomed in and obvious at true screen size. They are the
failure MODE of a procedural sheet — regularity the eye reads as ornament — and
the next generator will reinvent them:

1. **The mandala.** Waves drawn across every sector at one radius close into a
   regular polygon; stacked, they read as a flower.
2. **The rim polygon.** The same defect at the far end of the radius — outer
   arcs chaining into a big regular ring.
3. **The slab.** A shard drawn as a free polygon in a sector floats as a flat
   grey block. The gate *almost* caught this one: the ink centroid moved to
   (+1.6, +1.8) voxels. Fixed by clipping a sliver to the two real crack paths
   that bound it, which also makes its outline irregular for free.
4. **The slab again, through the twins.** An un-capped twin beside a `wide`
   radial opens into a huge wedge, because `wide`'s runs are three times longer.

### 2.2 The 1:16 read rejected the first shard pass outright

Shards up to 200 authored px look magnificent at 256 and dissolve into
undifferentiated grey at 16 × 20 — §7.3's warning arriving exactly as written.
But small-and-many alone fails too: it averages into flat noise, because no piece
survives as itself. It took both — held to ~30–70 authored px AND a handful of
deliberately larger heroes that still land as a distinct bright pixel.

**The Director ratified the result** (2026-09-02): a shimmering white noise at
true size is the EXPECTED read for the fine debris, not a shortfall. Big pieces
are a different class — **G-D25**, a cut silhouette on 1–4 whole voxels using the
dented-ceiling alpha mechanism, no per-shape texture. G6 owns it; unbuilt.

## 3. §4's wiring — and the step that is not an edit

**Done:** a `fracture_` category in `TextureResolver._validate_dimensions()` (the
facade's own 64×32 contract, because the sheet rides that path verbatim and a
disagreement would break G-D21's offset arithmetic); `GlassMaterials.FRACTURE_WIDTHS`;
and the sheet wiring check §3 said was missing, proven red on both branches.
Step 4 (the manifest) was a genuine no-op — it is GENERATED and mirrors
`IMPACT_DECAL_MATERIALS`, which step 3 does not change.

**⛔ Step 3 is a contradiction, written up as `GLASS_MASTER_PLAN` §8.1.** Adding
`glass` to `IMPACT_DECAL_MATERIALS` would ask the renderer for
`glass_bullet_cracked_*` (that list reaches only the WALL families), and
`crack_factor > 0` makes `voxel_decal_selftest` **[12]** demand
`decal_crack_glass_{0,1,2}.png` — the per-voxel family G-D21 folded into the
sheet. **Glass is the first material where "cracks" and "has a crack decal
family" are different claims.** Consequence: glass cannot reach CRACKED at all,
so G5 is blocked and **G-D21 has nothing to trigger it on the map.**

**⚠️ §8.2 — G-D21's mechanism assumes a path glass is not on.** It reuses
`_compute_facade_key()`, the baked WALL path. Glass renders from its own
`_glass_atom_source[material][face][mask]`, and the frost is not in the atom at
all — the shader samples it by WORLD POSITION. Measured: 360 KB for every glass
atom today, 9.0 MB per face for a fracture atom page (36 MB across four), against
2.0 MB for the sheet as a world-sampled texture. Open for the Director.

## 4. Out of scope: a KNOWN, unowned defect that fired live and is now closed

⚠️ **This was not a discovery.** `current_state.md` §4.7 has carried
*"`update_docs.py`'s silent wipe"* as an unowned item since **2026-08-30**
(`6d22351d`). It then fired during this session's own doc regeneration, which is
how it got an owner.

`update_docs.py`'s `get_version_history()` ran git with a 5-second timeout inside
`except Exception: return []`, and the caller could not tell that from "VERSION
has no history" — so it wrote `(no version history)` OVER five real entries in
`docs/production/current_state.md`. Observed live: this repo is on a slow external
drive, the call timed out cold, and the same command succeeded a minute later.

Fixed so every source answers `None` for "could not determine" and keeps `[]`/`0`
for "determined and empty", and an undetermined block is left **byte-identical**.
Three other AUTO blocks had the same shape. **Loudness rides the exit code, not
stderr** — the pre-commit hook runs the script as `> /dev/null 2>&1`, so a
message on stderr reaches nobody in the very path where the damage happens.

**History audit: no wiped block ever landed.** All 334 commits touching that file
were read — zero `(no version history)`, zero `Branch: unknown`, zero zeroed
inventories. The 60 commits carrying `(none)` pending prompts are genuine.

---

## State at close

| | |
|---|---|
| `GLASS_MASTER_PLAN` | **v1.20.** G1, G2, G7, G-MAP, G-D9, G-D18/b, **G3 (all four stages)**, **G-VARIANT (V-A…V-D)** and **G-ART** built |
| Unbuilt in glass | **G5** (⛔ §8.1), **G4**, **G6** (+ G-D25's big shards; unblocked now the art landed), **G-D4**, `plastic` |
| Next session | **build G-D21** — decided with the Director, and it needs §8.1 answered first or there is nothing on the map to trigger it |
| Verification | `project_lint` PASSED (227 files) · `check_invariants` OK · CODEMAP fresh · `run_selftests` **49 clean, 0 failed** · `check_decal --all` **59 files, all PASS** |
| Open for the Director | **§8.1** the CRACKED tier · **§8.2** G-D21's mechanism · the Freepik licence (free requires attributing "macrovector / Freepik") · rasterising `9418.eps` if the reference route is ever wanted |
