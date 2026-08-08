# RESUMO_SESSAO — 2026-08-08 (D34: the SLAB/SLICE seam, unified)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-08_GPU_FLUSH_AND_SOOT_REVERSAL.md`,
which closed by naming the floor/wall pipeline divergence as the real root
gap and deferring it to "next session, before any soot tuning."
**VERSION:** 0.9.90 (unchanged).
**Commits:** `8dd926e` (E-SEAM-01), `22b24be` (E-SEAM-02), `9cd37ae`
(E-SEAM-03). Pushed to `main`.
**Mode:** Solo mode.

---

## What the Director asked for, and how it changed the plan

The session opened with the Director's own diagnosis: facades are burned onto
voxels that already carry a material colour, which is why the art is
desaturated and multiplied — but the FLOOR used coloured art instead, giving
the project two render methods for one problem. Open questions raised: keep
everything grayscale or move everything to colour? Does the fallback really
need to sit *underneath* the textures at runtime?

Audit before answering, and it turned up three concrete things:

1. **`slab_full_color` was dead data.** All 8 material JSONs declared it,
   `MaterialDef` parsed it, **nothing read it** — the compositor decided from
   the texture id's `slab_` prefix. Its doc comment claimed the opposite. That
   is why `metal`/`stone`/`wood` declared `slab_full_color: false` ("tint me")
   and rendered at WHITE anyway: the grey floors the Director was seeing.
2. **The floor never used its own material's decal art.**
   `decal_dent_concrete/metal/stone/wood_*` existed on disk and were already
   used by WALLS; `IMPACT_FLOOR_MATERIAL = "earth"` forced every floor dent to
   the earth family regardless.
3. **The runtime-toggle premise did not hold.** F7 calls `room.load_map()` —
   a full reload. There is no live toggle, so "the fallback must sit
   underneath at runtime" was never a constraint the code imposed. And
   "missing texture → bake the clean voxel" is already the behaviour
   (`TextureResolver` → `Tier.NONE` → generic atlas).

**The Director's answer went well past what was asked.** Not "pick a colour
rule" but: unify the surfaces outright — *a floor is a roof at the base of the
scene* — so floor, ceiling and walls burn their voxels the same way, which also
sets up the damage-direction model (damage from above → floor top-carve;
from below → ceiling bottom-carve). Photographic art stays as an exception for
wild/organic areas.

## The blocker, and the Director's fix for it

Unifying the texture id made a concrete roof and a concrete floor collide on
one page cache key (`ROOF|<material>|<facade>`), which would have silently
dropped the second spec's cells. Reachable immediately: PLAYGROUND declares
the same 4 materials as blocks AND as floor zones.

Resolving it forced the projection question, and working the real numbers out
for a diagram **corrected my own framing**: the roof was not "wrong". A
horizontal surface addresses 64 cells × 16 texels = 1024 texels per axis
(`resolve_flat` folds both axes at period `SHEET_COLS`), and the facade art is
1024×512. Something has to give:

- roof (`target_h = 512`) kept **native pixels** but covered only 32 of the 64
  cell rows — rows past ~36 fell off the plane entirely. Latent, invisible only
  because roof structures are small (a 3 GU block is 24 voxels).
- floor (`target_h = 1024`) covered the **full domain** but reached it with
  `resize(NEAREST)`, duplicating every texel row.

I offered a 3-option menu. The Director rejected the frame: *fill the empty
half with a vertically flipped copy of the facade instead of stretching it.*
That is strictly better than every option I listed, and it is already the
codebase's own idiom — `_get_roof_plane_source` mirrors on X for the wrap strip
and mirrors the vertical margins, and `_mirror_index` is the basis of the whole
fold model. Stretching was the odd one out. Both surfaces gain: the roof keeps
native pixels **and** stops running out of domain; the floor keeps the domain
**and** recovers vertical detail. Cost is a tighter repeat period on y (32
cells instead of 64), which reads better than blockiness.

One option I had offered ("both at 512") turned out to be outright broken for
the floor — only visible after working the mechanism through properly.

## What shipped

**E-SEAM-01 `8dd926e`** — the SLAB family is chosen by the MATERIAL now:
`has_facade == true` → `facade_<id>` (grayscale + multiply, same source as its
wall and roof); `has_facade == false` → `slab_<id>` (photographic, organic
ground). `BakePolicy.texture_for_material()` owns it, `has_facade` deliberately
required rather than defaulted. One isotropic 1024 projection for every
horizontal surface, reached by `_mirror_tile_v()`. Roof and floor of one
material share a page, with `room_builder._merge_horizontal_specs()` unioning
their cells first. `BakedTileLookup` reads the same `MaterialDef` field
(injected by room_builder; self-loads from disk if absent rather than guessing)
so B1 holds on both ends. `BAKE_CODE_VERSION` 8 → 9.

**E-SEAM-02 `22b24be`** — `floor_damage_material()` takes the material and
names by it. D25's shared fracture is demoted to the FALLBACK for materials
with no `decal_dent_<m>_*` of their own, which is where it was always correct.
`_floor_sunk_decal_plan()` extracts `base_material` like every other parser in
the file. Also fixed in passing: `_composite_generic_floor_sunk()` (bake-OFF)
hardcoded the `earth_0` atom as substrate for every material, so a damaged
concrete floor turned into dirt.

**E-SEAM-03 `9cd37ae`** — `slab_full_color` deleted from the 8 JSONs and from
`MaterialDef`; `has_facade` expresses the same split and cannot encode the
contradiction two booleans could. Docs realigned: `BAKE_SYSTEM_REFERENCE` B2
(widened, not narrowed) plus a reversal block over FLOOR-ZONE-BAKE's two now-
invalid subsections (kept, marked SUPERSEDED — the reasoning is the record of
why the split existed); `ART_SPECIFICATIONS` §8; `EXPLOSION_REBUILD_MASTER_PLAN`
§11 resolved point by point.

## Verification (per CLAUDE.md's evidence discipline)

- `project_lint.py`: 188 files, 0 errors — every commit.
- `run_selftests.py`: 33/33 clean — every commit.
- `check_invariants.py` / `gen_codemap.py --check`: clean throughout.
- **Selftests rewritten, not relaxed.** Six assertions encoded the contract
  D34 reverses. Two of them (`decal_seam`, `half_voxel_seam`) stated the
  premise in their own comments — *"concrete_blast_dented_top_N is not a name
  any real caller ever constructs"* — which D34 makes false, so they invert.
  Four new cases cover the new mechanisms: the has_facade split, the modulate
  consequence, mirrored repeat keeping exact pixels in order 0,1,2,3,3,2,1,0
  (matching `_mirror_index`'s repeated edge row), and the roof/floor cell union.
- **Real captures, named to escape the 50-file rotation:**
  - `Screenshots/history/e_seam_floor_unified.png` — PLAYGROUND. The stone
    floor patch shows the SAME cobblestone as the stone block beside it; wood
    reads brown next to the wood block; metal matches its block. All three
    rendered flat grey before.
  - `Screenshots/history/e_seam_damage_gallery.png` — FLOOR DENTED reads BAKED
    for all 4 materials under the new material-real names. Every MISS in that
    log is a documented unreachable (FLOOR CRACKED is never baked; metal/wood
    have `crack_factor` 0).
  - `Screenshots/history/e_seam_organic_exception.png` — FLOOR_ZONES_TEST, the
    regression risk of the whole change, checked directly: photographic grass,
    sand and dirt still render in real colour.
- **Real boot log**, not reasoning about the code: PLAYGROUND composes 4
  horizontal pages (`ROOF|{concrete,metal,stone,wood}|facade_*`), not the 8 the
  old split produced on that map; zero `slab_*` pages; no SCRIPT ERROR.
  Concrete uses all 4096 atoms of the 64×64 fold domain, confirming the
  isotropic target was load-bearing. FLOOR_ZONES_TEST's own log shows the split
  holding: `facade_concrete` for the structural material, `slab_grass`/
  `slab_sand`/`slab_dirt` for the organic ones.

## State at close

- The decal-bake formalization that blocked Task 6 is **done**. Task 6 (the
  tuning pass, incl. soot ring weights) is the next concrete action;
  `EXPLOSION_REBUILD_MASTER_PLAN` is still 🟢 BUILDING.
- **Flagged, not fixed — `earth` is not part of the unification.** The Director
  wants it baked like any other material ("uma parede e um teto de terra"), but
  `facade_earth.png` does not exist and `materials/earth.json` carries no
  `base_color`, so it still renders via `EarthVariantSelector`. Art task,
  deliberately outside this session's "sem arte nova" scope.
- **Still open — the GPU-flush safeguard** (§11 point 2, untouched by D34):
  whether to fold `flush_dirty_pages()` into `apply_damage_voxel_swap()` so no
  future call site can forget it, after that bug class bit two independently.
- The 3 stopgap `slab_metal/stone/wood.png` files from the previous session are
  **no longer loaded by anything** — those materials render from their own
  facades now. They can be deleted; left in place, harmless.
