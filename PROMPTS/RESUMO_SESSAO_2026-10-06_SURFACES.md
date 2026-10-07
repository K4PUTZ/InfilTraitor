# Session record — 2026-10-06 / 07: R3D-LOOK closure and R3D-SURFACES

32 commits, `4a37df29..3f479af4` on `main` (plus this record). The plan is [`SURFACES_MASTER_PLAN`](PLANNING/SURFACES_MASTER_PLAN.md) (decisions DS-1..DS-18,
stages, schemas); the content inventory is [`docs/systems/SURFACES_CATALOG.md`](../docs/systems/SURFACES_CATALOG.md). This file is the story and the resume point.

## Resume point

Read the plan's "RESUME HERE" block. Proposed next stage: **SM-1 Marking** (hazard stripes, road lines, arrows, crosswalks: `class` in `surfaces/rules.json`, a
GU-exact enforcement in `GroundDecals3D` / `MapCompiler`, a procedural `gen_markings.py`, a gallery band, a marking-rule selftest). Everything is committed and
pushed; `verify.py full` last passed on `de121ed1` (16 steps, 508 s, probe dumps identical to the baseline); `smoke` and `look` passed on `3f479af4`.

## What was built, in order

1. **R3D-LOOK closure.** The soot smoothing of floors baked into the cell plane's B channel (`RGB8`, one bilinear fetch): Moto idle +3.6 -> +0.3 ms; Galaxy no cost.
2. **Organic transitions** (`GroundTransitions3D`): symmetric feather, 1 GU per side, a world-noise iso-line, no priority table. Galaxy: +4 draw calls, no frame cost.
3. **Floor tags** (`surfaces/rules.json`, `SurfaceRules`, `MaterialDef.tags`): a closed vocabulary, `requires` / `forbids` per patch kind, loud errors; **patches on the voxel
   lattice** (1/8 GU, free rotation).
4. **Corporate floors** (`tile`, `parquet` herringbone, `carpet`), **50 carpets** (5 patterns x 10 colours; a colour is a JSON row with `facade_from`, no PNG),
   **industrial floors** (`steel_plate`, `grating`), `tile_beige/grey`. All procedural and seeded (`tools/asset_generation/gen_*_floors.py`).
5. **Per-map colour** (`material_tints`: a target albedo compensated by the facade's mean).
6. **Art rooms** `SURFACES_GALLERY`, `SURFACES_LAB`, `SURFACES_SCATTER`, generated and judged by `surfaces_gallery.py` (fails on any engine `ERROR: [`).
7. **SM-2 scatter**: `ground_scatter` section, `GroundScatter` (deterministic jittered grid), cluster STAMPS (`leaf_litter`, `pebbles`, `dirt`, `oil`), SINGLES (`leaf_single`,
   `pebble`, `twig`, `dirt_spot`, `oil_drop`), weighted `kinds` mixes, per-kind `size` / `class` / `priority` in the rules, tile culling + mipmaps.
8. **Real floor openings** (`floor_openings`, `FloorOpenings`, `SlabGenerator` skip on both floor levels) and the **steam vent** (`ground_vents`, `VentEmitter`: born 1 GU
   under the floor, fading in, so it shows only as it rises through the slats; `steam` and the bigger `steam_big`).
9. **Docs:** `SURFACES_MASTER_PLAN`, `SURFACES_CATALOG`, `MAPFILE_REFERENCE` rows (`ground_scatter`, `ground_vents`, `floor_openings`, `material_tints`).

## Director's rulings of the session (quoted in the plan as DS-n)

Symmetric transitions, 1 GU each side (DS-1); patches on the voxel lattice (DS-2); tags as the one mechanism for what may lie where (DS-3); art order, human-made floors of the MVP
first (DS-4); the grating is a REAL opening, bottomless, walkable, the effect below it later (DS-5, DS-18); colour = fixed rows + `material_tints`, per-cell tint deferred (DS-6);
four classes of floor mark by PLACEMENT (DS-7); cluster stamps instead of a scatter cap (DS-11); scatter first (DS-12); blood is in, flagged `mature` (DS-13); liquids are a
parked track (DS-14); stamps derived at load from user singles (DS-15); a fully customisable open tree with a merit gate (DS-16), as a LATE milestone with photo desaturation
cached and the alpha cut-out later (DS-17); the leaf art is his to redraw.

## Measurements (all cited with the scene, zoom and boot count in the plan)

- **Scatter** (Moto): a stamp COUNT is the wrong budget; the cost is blended area, ~5 ms per full-screen layer, **halved to ~2.4** by mipmaps on the stamp textures
  (`filter_linear_mipmap`; tile culling alone gave only 0.8 ms). Galaxy ~1.3 ms per layer.
- **Steam vent** (Moto, 1 vent in view at GAMEPLAY zoom): +6.8 ms -> **+3.0 ms** after the disc shader (no `discard`, no per-fragment `pow`: all smoke and embers, pixel
  gate 0 px), an octagon disc mesh, and puffs spaced 1.3x. Rule: at most ONE big vent in view; the small one for secondary vents.

## Traps (each one cost time; also in the memory of the project)

- **The facade is MIRRORED**: a 45 degree stripe becomes concentric rings; directional art is a mark, not a floor.
- **A map is ~46 GU per side** (the light/soot plane): past it cells draw with no light and log `outside the 512x512 cell plane`; I shipped captures of an oversize room before the
  harness learned to fail on any `ERROR: [`.
- **Measure a localised effect at the zoom of PLAY**: my first steam measurement (zoom 0.34) said ~1.2 ms per vent and was wrong by 4-6x.
- **An intermittent desktop hang** (four times): the engine ran frames and did not draw, so `await RenderingServer.frame_post_draw` never returned. `ScenarioDraw` waits for the draw
  but forces one after 20 frames. **The cause is INFERRED, not proven** (the fallback was never seen firing, a minimised window still draws); if a hang shows with it in place,
  it is something else.
- A real mouse pointer changed 10 px between two boots of the same code; a scripted run now ignores the hover.
- Tooling slips of mine: a `sed -i` without `''` on macOS breaking a `&&` chain, a bare `git stash pop` applying an OLD stash (use `git diff > patch` / `git apply -R` for A/B, never
  stash); a measurement script without `chmod +x` hidden by `>/dev/null`. Confirm a background job actually started.
- A selftest that creates `Node`s must free them (the leak gate); `pitch` of an opening is "a bar every N voxels", so a larger pitch leaves MORE gaps.

## Still open

Per-cell colour (decided only by scenario, §7.1 of the plan); the SM-6 liquids below a grating; the marking class (next); stroke and dense layer; the customisation milestone (gate, photo
ingestion, a mod-pack validator app); `surfaces/rules.json` inside the APK was not proven on a device by a rule-dependent run; Moto row for the organic transitions; the leaf art.
