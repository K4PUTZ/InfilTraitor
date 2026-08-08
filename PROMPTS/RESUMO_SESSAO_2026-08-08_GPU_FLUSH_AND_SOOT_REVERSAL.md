# RESUMO_SESSAO — 2026-08-08 (GPU-flush bug found + fixed; Post-Task-5 soot conclusion reversed)

**Continues:** `PROMPTS/RESUMO_SESSAO_2026-08-07_POST_TASK5_SOOT_DIAG.md`,
which closed with the "fuligem quebradiça" complaint investigated but
unresolved, and a (wrong, see below) conclusion that pre-existing dent-decal
art was the cause.
**VERSION:** 0.9.90 (unchanged).
**Commits:** `419d8c4`, `eec46e1`, `512fa5c`, `31bf069`, `edadf32` (see
below for what each shipped).
**Mode:** Solo mode.

---

## What happened, in order

1. **Director rejected yesterday's diagnosis outright**, before any new
   code: `frag_grenade.json`'s ring 3 has `destroy/dent/crack_ring_weights`
   all `0.0`, so a ring-3 voxel never reaches `apply_container_damage()`'s
   DENT/CRACK selection loops and can never roll a `decal_variant`/
   `substrate` — there is no dent-decal art or D3 randomization for ring 3
   to inherit. If ring 3 still read "quebradiça," yesterday's conclusion
   couldn't be right. Confirmed directly in code before writing anything.

2. **Built a real verification rig** (`godot/scripts/debug/
   damage_gallery_debug.gd`, new file) that forces DENTED/CRACKED onto real
   voxels of every declared material (concrete/metal/stone/wood), on
   WALL/FLOOR/CEILING, and reports whether `apply_damage_voxel_swap()`
   actually hit a pre-baked atom — triggered live via F5, or unattended via
   a new `INFILTRAITOR_CAPTURE_ACTION=damage_gallery` auto-screenshot
   action (`room.gd`). Caught and fixed a bug in the rig itself first
   (MapCompiler's `+(board.buffer, board.buffer)` GU shift, missed on the
   first pass — 100% CEILING miss). Commit `419d8c4`.

3. **Found metal/stone/wood floor damage never baked at all** — their
   `slab_<material>.png` substrate texture was never authored (only
   `concrete`/the ground materials had one; no map had ever declared them
   as floor materials before this session's new `floor_zones` patches).
   Director's direction: reuse the wall `facade_<material>.png` art as the
   source (same precedent `ART_SPECIFICATIONS.md` §3 already documents for
   roofs), rewrite `_gallery_floor()` to cover whole GUs ("as if an
   explosion already happened") instead of alternating voxels. Shipped the
   texture fix (palette→RGB conversion, 1024×512→1024×1024 resize) and the
   whole-GU floor logic. Commit `eec46e1` — closed with a visible orange
   artifact still unexplained (flagged honestly, not papered over).

4. **Director looked at a real capture and called it: no decal is visible
   on the floor, in any material** — and asked for the same whole-GU
   treatment on WALL, compared directly against the shotgun's real,
   confirmed-working bullet marks. Rewrote `_gallery_wall()` to use real
   Slice/Voxel objects (found via `room._edge_registry`, not a throwaway
   one), fixed a "hollow block" bug from marking all of a GU's real faces
   at once instead of just the camera-visible one, then — comparing against
   a real `weapon_fire` capture step by step (immediate + late cell
   readbacks, both proving the DATA was always correct) — **found the real
   root cause**: `DamageCompositeCache.store()` blits into a CPU-side Image
   and marks the page dirty, but the GPU texture upload is deferred to
   `flush_dirty_pages()`; this tool called `apply_damage_voxel_swap()`
   directly, bypassing every real call site's paired
   `process_dirty()`/`process_dirty_async()` flush. One call
   (`renderer.flush_damage_composite_pages()`) fixed both the wall
   invisibility AND the floor orange artifact at once. Commit `512fa5c`.

5. **Checked whether the same bug exists in real gameplay — it does.**
   `DetonationChoreographer` is the only place a `DetonationPlan` ever
   reaches `set_cell()` (its own header comment), and it never flushed
   either. Fixed the same way, once per wave (`detonation_choreographer.gd`).
   Commit `31bf069`.

6. **Re-ran the Post-Task-5 A/B test clean, on the identical stone crater.**
   Yesterday's captures (`soot_stamp_on.png`/`soot_stamp_off.png`, 3.3%
   pixels differ, mean 0.76/255, "near identical") were themselves reading
   unflushed/stale GPU content — noise that washed out the real signal.
   Same test post-fix: **4.1% of pixels differ, mean 101.6/255 — over 130x
   the earlier signal.** With the stamp OFF, ring 3's floor tiles read as a
   smooth, even darkening; with it ON (shipped default), the same tiles
   show the "quebradiça e irregular" checkerboard verbatim. **The blast's
   own soot stamp IS the cause — Post-Task-5's conclusion reversed.** Exact
   mechanism (a uniform per-ring tone becoming a checkered per-pixel
   result — `stamp_crater_soot()`'s own ring math has no per-voxel hashing)
   not yet traced. Commit `31bf069` (code), `edadf32` (docs correction —
   `EXPLOSION_REBUILD_MASTER_PLAN.md`'s Post-Task-5 note struck through, a
   Post-Post-Task-5 note appended with the reversal, same precedent the
   plan already uses for D-number corrections).

## Director's close, this session

Confirmed root design gap: **floor (SLAB) and wall (SLICE) textures are a
genuinely different art/render pipeline** — different dimensions
(1024×1024 isotropic vs 1024×512 anisotropic), different color rules (SLAB
is B2's one full-color exception), different resolver validation — and
that divergence, not a soot-specific bug, is what actually produced this
session's floor/wall problems. **Next session formalizes that seam
properly** (real `slab_<material>.png` assets for metal/stone/wood, not
this session's reused-facade stopgap; a decision on whether the GPU-flush
contract needs a structural safeguard now that it's bitten two independent
call sites) **before any soot tuning** — see
`EXPLOSION_REBUILD_MASTER_PLAN.md` §11's new lead item for the concrete,
undecided list. Soot's real lever (the stamp's own rendering path, or the
shader's multiply-vs-flatter-blend question) waits until that foundation
is solid.

## Verification (per CLAUDE.md's evidence discipline)

- `project_lint.py`: 189 files, 0 errors (every commit this session).
- `run_selftests.py`: 33/33 clean throughout — no existing suite exercises
  this class of bug (a GPU-upload-timing gap is invisible to any
  headless/CPU-only check by construction; every finding this session came
  from a real windowed capture, several from directly comparing two real
  captures pixel-by-pixel via PIL/numpy, not from reasoning about the code).
- `check_invariants.py` / `gen_codemap.py --check`: clean throughout.
- Real captures at every step, several pixel-diffed directly rather than
  eyeballed: the offset-bug fix, the texture-asset fix, the "hollow wall"
  fix, the flush fix (floor before/after, wall before/after), and the
  final soot A/B (`Screenshots/history/auto_2026-08-08_02-10-38.png` /
  `auto_2026-08-08_02-12-54.png`, stamp on/off on the identical crater).

## State at close

- `EXPLOSION_REBUILD_MASTER_PLAN` is 🟢 **BUILDING**. Tasks 0-5 still done.
  Task 6 (the tuning pass) is NOT next — formalizing the decal-bake step is,
  per the Director's explicit call this session.
- WALL and CEILING damage decals confirmed correct for all 4 materials
  (real capture, post-flush-fix). FLOOR DENTED confirmed baked and
  rendering for all 4 materials, though the underlying `slab_<material>.png`
  assets for metal/stone/wood are a stopgap (reused wall art), not properly
  authored ground textures — explicitly flagged, not silently accepted as
  done.
- The 3 new local texture assets (`ASSETS/TEXTURES/defaults/
  slab_metal.png`/`slab_stone.png`/`slab_wood.png`) are **not in git**
  (`ASSETS/*` is gitignored, same as every other texture in the project) —
  exist only on this machine; flagged for the Director's own asset-backup
  workflow.
- `damage_gallery_debug.gd` (F5, or
  `INFILTRAITOR_CAPTURE_ACTION=damage_gallery`) stays in the codebase as a
  real, reusable verification rig for whoever picks up the decal-bake
  formalization next session — including two diagnostic readback helpers
  (`INFILTRAITOR_GALLERY_READBACK=1`) that were instrumental in finding the
  GPU-flush bug and are cheap to keep.
- Pushed to `main`.
