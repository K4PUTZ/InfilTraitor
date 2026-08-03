# RESUMO_SESSAO — 2026-08-02 (DAMAGE DECALS, D32)

**Active master plan:** `PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md` — D32
ratified and shipped (assets + runtime wiring), D32.6/D32.7 same session, D33
ratified and deferred.
**VERSION at session start:** 0.9.87
**VERSION at session end:** 0.9.88
**Mode:** Solo mode.
**Screenshot session:** not toggled; captures via direct off-screen
`INFILTRAITOR_AUTO_SCREENSHOT=1` runs.

---

## Executive summary

The session opened as an audit — *"confirma que o diagrama está refletido no
projeto"* — and the honest answer was no, in a way nobody had noticed: the
impact art had its mark drawn on the voxel's **top diamond**, so **every firearm
hit on a wall painted its bullet hole on the roof.** Measured, not inferred:
`voxel_concrete_dented.png`'s dark pixels sat at bbox `(11,3)–(21,13)` and the
top diamond spans `y = 0..15`.

That audit became D32, ratified across four exchanges with the Director, and it
shipped in full: a new decal pipeline, 153 generated assets, and the runtime
wiring behind it.

---

## What D32 actually changes

Damage art is no longer a hand-drawn 32×36 atom per (material, tier, cause). It
is a **flat, square, unprojected decal** the Director authors, which the
generator projects onto whichever face the damage physically reached.

- **Square is canon, not preference.** `ART_SPECIFICATIONS.md` §1 already pinned
  it — *"never pre-stretch to compensate for projection — the compositor owns
  all projection math"* — and `bake_compositor.gd::_get_plane_source()` already
  did exactly that for facades. The generator now applies the same two
  operations: ×20/16 vertically onto a lateral face, nothing onto a top face.
  This also answers the Director's own constraint (*"não quero distorcer o
  círculo além do que é necessário para a perspectiva"*) by letting him draw a
  genuinely round hole.
- **Half voxels are a shared substrate**, generated from the material's own atom
  — the exposed cut is the MATERIAL with a dent decal pressed into it, not D25's
  generic grey fracture.
- **CRACKED covers all three visible faces.** *"Não existe voxel rachado só em
  uma face."*
- **Placement, per cause:** a bullet hits walls only and marks the one lateral
  face it struck; a wall dents laterally, a floor from above, a ceiling from
  below; a ceiling carve is silhouette only.
- **Three variants** per family per material, stored on the Voxel and persisted.

Glass and brick deferred by the Director; glass will get no DENTED/CRACKED tier
at all, its cracks becoming a future multi-voxel system.

---

## Three defects the verification caught

Each one was found by a check, not by review — which is the point of having
them.

1. **Mirroring the finished PNG shifted the silhouette one pixel.** The atom is
   not mirror-symmetric (`V_E` sits at x=32 in a 32-wide canvas); **30 alpha
   pixels differ** between `voxel_concrete.png` and its own pixel-mirror. On a
   flat wall voxel that seams against its neighbours. Right-hand composites are
   now built natively from mirrored **polygons**.
2. **A decal reaching its canvas corners grew the substrate's silhouette**,
   violating **B3**. `blast_dented_top` gained alpha outside the half voxel and
   leaked 2 px past the sunken diamond. Composites are now clamped to the
   substrate's alpha.
3. **My own recommendation was wrong before I read the shipped code.** I told
   the Director to author at 4:5 on my own reasoning about face geometry;
   `ART_SPECIFICATIONS.md` §1 and the real compositor both said square. Caught
   by reading `bake_compositor.gd` rather than continuing to reason — the same
   discipline CLAUDE.md states for bridging two data shapes.

A fourth, smaller: the new PNGs existed on disk but had no `.import` sidecars,
so the first selftest run hard-failed at boot. That is B6 behaving correctly,
not a bug — but `--import` is now a documented step in `ART_SPECIFICATIONS.md`
§7 for whoever drops art next.

---

## Evidence trail

- Asset side: **96 composites** carry a silhouette byte-identical to their
  substrate; decal pixels land inside the intended face measured against the
  same parametric `0 ≤ s,t < 1` region the compositor clips with — **zero
  outside**, across all four surfaces and both sides; ceiling half voxel diffs
  to **0 px** of decal.
- `run_selftests.py` — **20 clean, 0 failed**, including the new
  `voxel_decal_selftest.gd` (21 assertions: every generated name has a loadable
  asset, the manifest agrees with the renderer's constants, a bullet never
  resolves on a horizontal face, blast-CRACKED collapses to one whole-voxel name
  from all five sides, the ceiling carve is variantless, variants resolve
  distinctly and survive `set_damage()`'s read-once rule, unknown materials fall
  back instead of composing a phantom name).
- `slab_render_selftest.gd` 12 → **18**: the floor-dent test now drives all
  three variants and asserts three **distinct** source ids, so a variant that is
  accepted and then ignored fails.
- `project_lint.py` PASSED (165 files) · `check_invariants.py` OK ·
  `gen_codemap.py --check` clean.
- Real captures: shotgun on the bench
  (`Screenshots/history/auto_2026-08-02_23-29-43.png`), grenade on concrete
  (`auto_2026-08-02_23-30-36.png`) and on metal (`auto_2026-08-02_23-30-44.png`)
  — the metal wall shows dented half voxels carrying the decal on their cut
  faces, and the crater rim shows floor dents on their sunken tops.

---

## Landed after the first close of this file

- **D32.6 — metal and wood stop cracking** (Director: *"metal e madeira não
  ficam rachados, só dented ou balas"*). `crack_factor` 0.0 for both, and the
  crack decal family gated to concrete/stone so no art is queued for a state the
  runtime cannot reach — the Director's asset debt dropped by 6. `dent_factor`
  deliberately not raised to absorb the freed share. **Real-map evidence**: every
  metal slice now logs `cracked=0` across all four rings, against 20/9 before.
- **D32.7 — an explosion never produces a bullet hole.** Already true when
  raised (all three blast writes pass `from_blast=true`); pinned anyway by an
  exhaustive 210-combination test, because the guarantee lives in a DEFAULT
  PARAMETER a future caller can silently omit. What the Director actually saw
  was the placeholder dent decal reading round at 16×20 px — rebuilt
  structurally angular.
- **D33 — runtime compositing, ratified and deferred.** Answered with numbers
  rather than a preference: RAM is a wash (same 97 textures either way), the
  shader route is dead on the alternative-id ceiling already documented in
  `voxel_renderer.gd`, and the load-time blit route is worth doing chiefly
  because a per-cell composite can stamp the decal onto that cell's BAKED atom,
  which today is discarded. Sequenced after the art by the Director's call.
- **ASSET-LAYOUT-01 — the voxel source tree split by pipeline role.**
  196 PNGs, 144 of them flat in one folder, became
  `materials/` · `halves/` · `decals/` (INPUTS, never overwritten) and
  `composites/` (OUTPUT, always rebuilt). No `bakes/` folder: nothing is baked
  to disk and "bake" is a protected term here. Verified on a real boot, not only
  by tests — zero missing-texture errors and a real detonation rendered.

## Documentation sweep (Director-requested, session close)

- **0 dead links across 86 markdown files** (was 8). `DIRECTION_GLOSSARY`
  pointed at a `../history/` that resolves outside the repo; the two retired
  context files kept relative links from before they were moved into
  `docs/history/`, and CLAUDE.md still calls them "the fuller record".
- `docs/README.md`'s claim to index every doc **verified** — 34/34.
- `ARCHITECTURE.md` listed the Voxel Render Plane as **Planned** while its own
  opening section describes it as shipped. Fixed that row; the document remains
  self-declared unreconciled since 2026-07-03 for bake closure, the screenshot
  hook, occlusion and destruction — a real reconciliation task, not a sweep.
- `ASSET_PIPELINE_QUICK_REFERENCE` still said "4 materials" and told the reader
  to switch focus to Godot for reimport; now lists the real material set and the
  headless `--import` form, flagged non-optional (B6).
- **Evidence citations decay by design, and that is now written down.** 16 of 23
  captures cited across the docs no longer exist: the rotation keeps the 50 most
  recent `auto_*` files and never touches anything else, so every hand-named
  capture survived and every `auto_` one eventually will not. Recorded in
  CLAUDE.md with the consequence that matters — name a capture without the
  `auto_` prefix when it is meant to be cited long-term.

## Open, deliberately

- **The art itself.** All 36 decals are placeholders at the real authoring size.
  Replacing any file and re-running the generator rebuilds every composite
  around it; nothing authored is ever overwritten.
- **Authoring resolution is an unratified multiple.** Canon density
  (`TEX_AUTHORING_N = 16`) puts one decal at 16×16 texels; they are authored at
  256×256, an exact 16× multiple that collapses back losslessly. Flagged to the
  Director, not decided.
- **"earth" was added to the decal family without being asked.** Every ground
  material's dent routes to that one shared asset (D26), so leaving it out would
  have put the new look on every wall while every crater rim in the same room
  kept the old grey fracture. Three extra dent decals; trivially revertible if
  the Director disagrees.
- **Glass and brick**, per the Director's own deferral.
