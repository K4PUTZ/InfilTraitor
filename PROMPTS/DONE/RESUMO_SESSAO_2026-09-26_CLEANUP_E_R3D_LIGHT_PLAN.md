# Session summary — 2026-09-26 — the post-close cleanup, R3D-SURFACES planned, R3D-LIGHT planned

**Resume point:** R3D-END is closed and cleaned. **The Director closes R3D at R3D-LIGHT** ("Menos iniciativa e mais acabativa"); every other stage
(ACTORS, PROPS, WORLD, ROT, LOOK, SURFACES, CLAIMS, BUFFER) is a follow-on track, not R3D debt. **Next session: R3D-LIGHT step 1, incremental
occupancy** (read the v1.29 block at the top of `PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md` first). Nothing is edited; the tree is clean.
Verify with `python3 tools/persistent/verify.py` (smoke). Do NOT run `verify.py full` unless the Director asks.

## What the Director asked, in order
1. "Vamos retomar o R3D, leia a documentação." 2. "Vamos limpar o código morto primeiro." 3. Chose: keep `occlusion_overlay`, retire the atoms cluster keeping
`EarthVariantSelector`, delete the triage's dead symbols and keep the design stubs; and asked to check for more dead code, then stale comments. 4. "Me explica melhor as 3
decisões": FLOOR-DEPTH-01 is resolved; the weapon bench STAYS as is ("cruzar essa ponte quando chegarmos nela"); the organic-ground question was debated.
5. Wants two mechanisms (facade + photographic surfaces, roofs, mud, foliage), asked whether one large horizontal facade beats many slabs -> R3D-SURFACES planned.
6. "Fechar o R3D" -> the closing rule above. 7. "Vamos começar pelo R3D-LIGHT" -> measured, planned for the next session. 8. "atualizar o resto da documentação".

## Commits (all pushed, `main`)
| commit | what |
|---|---|
| `2bb5cbb1` | `_glass_neighbour`, `FacadeSampler.get_window_origin_*` (+ the private `_window_origin_*`), `GlassCrack.has_craze_art`, `GlassMaterials.fracture_texture_id`, `OcclusionSet._is_exposed`, `theme_applier.gd`, the root `test_keys.gd` |
| `ef41e88d` | the `tile_size` of three overlays nothing reads; the stale "fallback only when floor_layer is unset" comments |
| `33fc6891` | `FacadeSampler.sample()` + `_mirror_*`, 26 unused preload constants, the three `r3d4a_*` shaders |
| `82d80e88` | comment audit: 48 comments that named something deleted, rewritten; `check_facade.py` comments; a dead exception in `project_lint_validator.gd` |
| `f4ddd52c` | triage: 55 declarations removed, 34 kept (24 design stubs + 10 documentation / unbuilt rulings) |
| `71c6406b` | the atoms cluster: 73 files to `ARCHIVE/voxel_atoms_2d/`, `bake_policy.gd`, `high_wall.gd`, `tile_anatomy_audit.gd` git-removed |
| `200986da` | `DEEP_FLOOR_CRATER_FACTOR` removed; the plan records that the bench stays |
| `eb7e32c8` | R3D-SURFACES planned |
| this close | v1.29 of the plan, the diagnostics baseline, `CLAUDE.md`, `docs/README.md`, `current_state.md`, this summary |
Net: about **-1 550 lines**, 16 files deleted. Every code commit passed `verify.py` smoke (51 selftests; PLAYGROUND and GLASS boot and rotation).

## R3D-LIGHT, measured (desktop; no phone was attached, `adb` not on the PATH)
The shot's tail is 112.6 ms, of which the light repaint is 103.9 (**occupancy 66.0** · field.build 12.5 · apply 25.1). A grenade: COMMIT frame 32 ms, CONSEQUENCE 62.5 / 43.8,
the LIGHT beat's first frame 68.7 / 68.2 (derive 35 ms). The cause of the biggest item: `VoxelStore.occupancy_dict()` walks ~216 000 claims and builds a new Dictionary at every
light repaint, then `_stale_cells()` diffs it against the last one; the store already knows which cells changed. Plan (step 1) and its gates are in the plan's v1.29 block.
Log: `docs/measurements/desktop_2026-09-26_r3d_light_hitch.log` (git-ignored). Proposed closing criterion, awaiting the Director: no blast or shot frame over 100 ms on the Moto.

## Traps found (worth keeping)
- **A scan that counts a comment as a use keeps dead code alive.** `_is_exposed` looked referenced for months by two doc comments. Count identifiers with comments stripped; count declarations as uses of nothing.
- **A scan for "declared once" misses dynamic calls.** `scenario_reload` / `scenario_relight` are reached by `"scenario_" + step["op"]` assigned to a variable; a regex for `call("prefix" +` missed it. Grep the string prefixes that are concatenated before trusting a dead-function list.
- **My own removal tool took ten live lines with one deletion:** the walk up from a declaration to its doc comment accepted every line starting with `@`, so three neighbouring `@export var` declarations came with `wall_height_override`. Caught only because the removals were dry-run into a log and read. Review the log; then review the `git diff` of the big ones.
- **The same tool's `edit` helper eats the next line's indentation when the old text ends in a newline.** Use a whole-line drop helper for line removals.
- **A doc-comment block can be stacked on the wrong function** (`OcclusionSet._build_wireframe_geometry`'s header sat on `_is_exposed`); delete by anchor and move the block.
- **A named constant can be documentation of a live flag or an unbuilt ruling** (`THROW_PROFILE_ENV`, `DEEP_FLOOR_CRATER_FACTOR`, `STROBE_SEQUENCE`), and two comments can derive a value from a constant no code reads (`VOXEL_STOREY_HEIGHT_PX`). Zero readers is a reason to look, not a reason to delete.
- **A retired class can be the only statement in code of a design rule.** `BakePolicy` alone said that organic ground keeps a photographic `slab_<id>` floor (D34); the 3D board draws a flat colour, so that rule is prose now (recorded for R3D-LOOK / R3D-SURFACES).
- **`git log -S<name>`** on each dead name gives the commit that removed its last reader: it separates what the R3D stages orphaned from design stubs that never had a reader.
- **macOS has no `timeout`** (exit 127, silent): a scenario ends itself with `quit`.
- `verify.py` and the pre-commit hook regenerate the `AUTO:BEGIN inventory` block of `current_state.md` AFTER the commit, so it shows as modified once more; commit it with the next change.

## Left for later
The five "dev-tool paths" (never enumerated anywhere); the `damage_materials` map section (compiled and forwarded, nothing reads it); `WeaponBenchController` (~450 lines, wired in `room.gd`; **stays until new weapons**, its `add_weapon()` / `TEST_ZONE_WEAPON_ROWS` / `TEST_ZONE_WALL_GU_X` were removed by the triage and are in `f4ddd52c`);
`generate_voxel.py` still writes atoms and halves if run (header note); `is_combustible` is unused because its callers re-derive `> 0.0` inline; the idle `guard cone smooth draw` (4-7 ms/frame on the desktop, 9 calls);
R3D-SURFACES (planned) and the other follow-on tracks.
