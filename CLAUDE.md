# CLAUDE.md

Standing instructions for Claude Code sessions in INFILTRAITOR — auto-loaded
every session. Distilled from `docs/history/SOLO_MODE_CONTEXT.md`,
`docs/history/OPERATOR_CONTEXT.md`, and `docs/history/OVERLORD_CONTEXT.md`
(retired 2026-07-27, moved there when this file superseded them), which
remain the fuller record (philosophy, delegation calibration, the
manual-injection workflow other tools use). If this file and one of those
three disagree on a rule that still applies, the more detailed source wins
— fix this file to match, this
file existing does not make the others stale.

## The project

Turn-based tactical stealth, mobile-first (iOS/Android), portrait
orientation. Godot 4.6, GDScript, isometric 2.5D voxels drawn as **a Godot 3D board over a packed
voxel store** (`VoxelStore` + `Board3DLive`; ratified 2026-09-15,
[`RENDER3D_MASTER_PLAN`](PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md)). **The 2D `TileMapLayer` board was deleted
at R3D-END (steps END-0 to END-6, 2026-09-24/25); `34881f81` is the last commit that builds it.** END-8's device
gate ran on both handsets (no regression). Props, actors and the 2D overlays are still 2D until R3D-PROPS / R3D-ACTORS.
No deadline — architecture and code quality outrank speed.

Repo: https://github.com/K4PUTZ/InfilTraitor

**Language:** code, comments, docs, commit messages — English, always.
Conversation with the user (referred to project-wide as **"the Director"**)
— Brazilian Portuguese.

## Director protocol

Two standing duties, both obligations:

- **Ask, don't guess.** When an instruction is ambiguous, a number looks
  suspect, or a design detail is underspecified, stop and ask at the exact
  point of ambiguity — not after building on the guess. A trivial gap with
  one obvious reading: fill it and state the assumption in one line.
- **Licensed skepticism.** If a request looks risky, contradicts canon, or
  costs far more than it appears to, say so before executing — state the
  risk, the cost, and the safer alternative if one exists. Once the Director
  ratifies a direction, execute fully and stop relitigating.

## Environment & workflow

- Godot stays open with the project loaded when possible — don't close or
  reopen unnecessarily. If unavoidable:
  `/Applications/Godot.app/Contents/MacOS/Godot --path . 2>/dev/null &`
- GDScript changes hot-reload automatically.
- **Video of the game on a handset** (to judge the flow of an effect): `python3 tools/persistent/device_record.py --device <serial> --preset blast --out videos/<name>.mp4`; `videos/` is git-ignored. Guide: [`docs/pipelines/device_video_recording.md`](docs/pipelines/device_video_recording.md). Costs +1 to +2 ms/frame on the Moto: never record during a measurement.
- Generated PNGs land in `ASSETS/ISOMETRIC/source_assets/generated/` (the floor / structure `TileSet` only) or in a material's
  own folder `ASSETS/materials/<id>/` (facades, decals — what the 3D board reads); switch focus to Godot and wait 3–5s for
  reimport. There is no bake step to run and no `BakeConfig` (deleted at END-6).
- On interruption or session resume: re-read the active prompt/plan file
  from disk first and state the resume point in one line before continuing.
  Conversational memory is not ground truth; the file on disk is.

## Verification protocol (before declaring anything done)

**One command, in tiers, failing fast: `python3 tools/persistent/verify.py`** (added 2026-09-25; the header of
`tools/persistent/verify.py` has the reasoning). **Director's rule (2026-09-25): stop re-running the same explosions and shots
after every change.** The 2D board is gone, so the identity gates have nothing left to protect on an ordinary change. The default is
the cheap tier; the heavy one runs on request.

| Tier | Runs | Time | When |
|---|---|---|---|
| `docs` | invariants, codemap | seconds | Markdown / `PROMPTS/` / `docs/` only |
| `quick` | lint, invariants, codemap, selftests (items 1, 5, 6 below) | ~1 min | tools, selftests, localisation |
| `smoke` | `quick` + `smoke_boot.py`: PLAYGROUND and GLASS boot, rotate E then N, no grenade, no shot | ~1.5 min | **the default for any change under `godot/`** (`verify.py` picks it by itself) |
| `full` | `smoke` + `ground_gate`, `shot_3d_gate`, `occ_canonical_gate`, `mirror_gate`, `roundtrip --with-store`, and the two identity gates held to a stored baseline | ~7 min | **ONLY when the Director asks, or to close a stage that rewires the board / the state / the light / the ground** (`verify.py` never picks it) |

- `verify.py full` wants a baseline taken at the START of the task, on the code before your change: `verify.py --baseline`
  (two boots per case, ~3.5 min, git-ignored under `Screenshots/verify_baseline/`). Without one the identity gates fall back to
  their two-boot form and say so.
- **The boot gates refuse to start while another Godot is alive, the editor included** (`smoke` does not care). Every boot times out
  at 180-300 s.
- ⚠️ **`pixel_gate.py` is blind to a brightness change under its 8/255 noise floor:** a face-tone change from 0.975 to 0.900 moved
  ~16 000 px but only 5 px above the floor. A look change needs a real capture (item 4), not this gate.
- The individual gates remain runnable on their own (each has its header); `verify.py --list` prints a tier's steps.

The numbered list below is what the tiers run and what each step means:

1. `python3 tools/persistent/project_lint.py` — zero real compile errors.
   The editor's Problems panel is a convenience view, not evidence (can
   hold stale entries for deleted/unsaved files) — the CLI is the arbiter.
2. Zero-tolerance on warnings in every file created or modified this
   session (pre-existing warnings in untouched files may be flagged, not
   fixed). Always use explicit float division (`/ 2.0`, `float(x)`) to
   avoid `INTEGER_DIVISION` warnings.
3. Run the closest real execution path and watch the console (`push_error`,
   `print_debug`, assertions).
4. Visual claims need a real capture (`Screenshots/history/`, or an
   explicit ad-hoc one) — never a written description standing in for one.
5. `python3 tools/persistent/run_selftests.py` (`--only <name>` for one) —
   **the arbiter for selftests, the way `project_lint.py` is for compile
   errors.** A bare `godot --script` run of a selftest can print a runtime
   `SCRIPT ERROR`, skip the rest of that function, and still report PASS
   with exit 0; GDScript cannot catch its own script errors in-process, so
   the check has to live outside the Godot process. Never cite a bare run as
   evidence a suite passed.
6. `python3 tools/persistent/check_invariants.py` and
   `python3 tools/persistent/gen_codemap.py --check` — both must pass;
   these also run as pre-commit gates, so a failure here blocks the commit
   anyway.
7. Commit (and push, if asked) on completion — see Git protocol below.

**Error-handling contract:**
- `push_error("[ClassName] context: %s" % detail)` — config/asset/spec
  failure; abort cleanly via early return, never leave state partial.
- `push_warning(...)` — anomaly with a documented fallback; operation
  continues.
- `print_debug(...)` for debug output. `printerr` is banned.
- `assert(condition)` for debug-only invariant checks (stripped in
  release).

## Evidence & reporting discipline

Every one of these was violated at least once in this project's history
before being written down.

- A completion summary ("all N criteria pass") is itself a claim — back
  every one with a pasted, literal, executed result, not a reasoned
  expectation.
- No silent substitution of an easier/synthetic test for a specified one —
  say so explicitly if a substitution was necessary, and why.
- Fixing a reported bug needs red-before-green on the *real* symptom, not a
  constructed stand-in.
- Any exclusion/skip-list needs the exact observed error for a specific
  instance — "probably needs special handling" is a guess, not a
  justification.
- Before writing a bridge between two data shapes, read the real consumer's
  actual field names/signatures — don't assume compatibility between
  independently-evolved formats.
- `"PASS (deferred)"` and its variants (future tense, "code-based
  verification," "will land in...") are banned constructions — a criterion
  is PASS or it isn't.
- **A green selftest does not mean the feature fires on the real map.**
  Synthetic fixtures are built with the material/data that works, so they
  cannot catch a feature made inert by real data. On 2026-08-01 the floor-dent
  path passed its selftest with 69 dents on a synthetic patch and produced
  **zero** on PLAYGROUND across 42 affected slabs — the map's floor is one
  `ground_concrete` zone and only `earth` had a `dent_factor` row. Run the real
  path and read the real counts before calling a feature done.
- **Stay inside the requested scope.** An unrequested cleanup, refactor, or
  dead-code removal is a defect by definition, not a bonus. On 2026-07-12
  an unrequested `[CLEANUP]` commit (`0f55cae`) deleted a var that looked
  unused in one file but was written cross-file from `room_builder.gd` —
  every wall in the game stopped rendering. Godot's linter cannot see
  cross-file writes; grep the *whole repo* before deleting anything as
  "unused."

## Auto-screenshot history

`Screenshots/history/*.png` is real, tracked evidence (unlike the rest of
`Screenshots/`, which is gitignored) — gated OFF by default, ~5–6s per
capture (a real windowed Godot boot).

⚠️ **The whole tree was wiped on 2026-09-09 (`cf48eb84`) and starts empty.**
Director ruling: *"o material realmente importante está em REFERENCES. Os
screenshots são só isso mesmo, screenshots."* **A receipt is not a reference** —
a capture cited beside a ratified ruling proves a measurement happened, but the
decision itself is in the prose next to it, so the picture answers nothing the
reader still needs. All 164 captures still cited by live docs were receipts by
that test, including an ART ORDER for art not yet made, which listed them under
the literal word "Evidence:" while the spec the artist needs was the text above.
Keep a capture only when a future reader must LOOK AT it to decide something
still undecided. Nothing below changed except that the folder is empty:
- Session toggle: `python3 tools/persistent/screenshot_toggle.py --on` /
  `--off` / `--status`.
- One-off for a single commit: `INFILTRAITOR_SCREENSHOT_ONCE=1`.
- `Shift+P` is the Director's own manual capture (saves to `Screenshots/`,
  no subfolder) — never trigger this programmatically.
- **Frame-by-frame analysis of a detonation:**
  `python3 tools/persistent/build_filmstrip.py` (P-FILM) — one contact sheet of
  every frame of ONE blast, to `Screenshots/filmstrip/` (gitignored). It boots
  once and passes `--fixed-fps 60`; both matter and neither is optional. A
  strip stitched from separate boots shows the fire jumping, because
  `spawn_blast_burst()` uses `randf_range()`; and without the fixed FPS the
  particle effects age several times too fast per frame while the frame-driven
  destruction and strobe stay exact, so the sheet lies about exactly what it is
  being used to judge.
- When a capture exists for a claim, point at the actual file instead of
  describing what the code should produce.
- **A pixel-diff gate has to be EARNED before it means anything.** Prove the
  harness is deterministic first, by diffing two runs of the *same* code — a
  0-pixel claim from a non-deterministic capture is noise wearing a number.
  Measured 2026-08-09: at the default 45-frame detonation wait under
  `--fixed-fps 60`, two identical runs differed by **36 733 pixels** (45 fixed
  frames is 0.75 s, well inside the fire/smoke lifetimes, and
  `spawn_blast_burst()` places embers with `randf_range()`). At
  `INFILTRAITOR_CAPTURE_DETONATE_WAIT_FRAMES=400` they differ by **0**. Capture
  the "before" side by stashing the change and re-running, so both sides come
  from the same binary and the same map.
- **A cited `auto_*.png` will eventually stop existing.** The rotation keeps the
  50 most recent `auto_`-prefixed files and never touches anything else, so a
  citation in a master plan decays the moment 50 more captures land — measured
  2026-08-03: **16 of 23 captures cited across the docs were already gone**,
  while every hand-named one (`occ_view_N.png`, `shotgun_preview_*.png`)
  survived. This is the rotation working, not data loss. ⚠️ A hand-name buys
  survival against the *rotation* only — the 2026-09-09 wipe took the named
  captures too, those two included, so neither file exists any more.
  Consequences: don't
  "fix" a dead capture link by re-running something (the run will not reproduce
  the old frame), don't treat a missing file as evidence of a deleted commit,
  and **give a capture a non-`auto_` name when it is meant to be cited
  long-term** — that is the only way to opt out of the rotation.

## Git & push protocol

- One task/prompt = at least one commit when the workflow expects a landed
  change.
- Commit subjects: `[TAG] <imperative summary>` (e.g. `[ACTOR-D17] ...`,
  `[FIX] ...`, `[DOCS] ...`) — the project's standing `[PROMPT-ID]`
  convention, kept even outside the formal prompt-file workflow.
- Hooks are mandatory: pre-commit runs `check_invariants.py`, CODEMAP
  freshness, and `project_lint.py`. Never bypass them.
- Never force-push `main`. Never rewrite published history.
- `verified/vX.Y.Z` tags mark Director-cleared checkpoints — only add one
  when explicitly instructed.

## PROMPTS folder convention

- `PROMPTS/` (root) — active or recently completed prompts, not yet
  manually archived by the Director.
- `PROMPTS/PLANNING/` — master plans only.
- `PROMPTS/DONE/` — Director-curated archive, plus session summaries
  (`RESUMO_SESSAO_*.md`).
- `PROMPTS/AUDITS/` — standalone audit documents, true audit-trigger cases
  only.

A prompt still sitting at root is not evidence it's incomplete — judge from
the prompt body and repo state.

## Session bootstrap

At the start of a session, in order: check the latest
`PROMPTS/RESUMO_SESSAO_*.md` (or under `PROMPTS/DONE/` if none at root) for
where things left off; check `VERSION` and recent `git log`; re-read the
active prompt/plan file if one is in flight before resuming. Current
milestone/version state is deliberately not hardcoded here — it goes stale
immediately; the files above are the live source.

---

## Architecture — inviolable rules

These must not be broken:

> **2026-09-25 — R3D-END END-7 retired the 2D-board rules** (the plan's R3D-END block has the record). Rule 8 is rewritten for the
> store; rule 2 was reviewed against its last readers and stays; L1 is retargeted; B1, B3 and B5 are retired and B2, B4 and B6
> survive where they still apply (below). A stage that needs to bend a rule stops and asks; it never works around it.

1. Stats = `var`, never `const` (future difficulty scaling).
2. `VISUAL_GRID_OFFSET` always via parameter, never hardcoded. *(Reviewed at END-7 against its last readers: `room.gd`
   defines it and hands it to the 2D overlays, the actors and `VoxelBoard.setup()`; `Board3DLive` must never know it. It is the
   screen-space offset of the 2D layer and retires with the last 2D overlay, not before.)*
3. `WallEdgeData` is the only source of edge keys — never recreate
   `_edge_key()`.
4. Guard state transitions go through `_enter_state()`, never direct
   `state =`.
5. `_alert_meter` accumulates only in `_apply_tic_result()`, nowhere else.
6. Mission structure stays independent of narrative (logic ≠ text).
7. Maps use internal coords only; the buffer is applied only in
   `MapCompiler`.
8. **Voxel state reaches the screen only through the store and the mesher.** Wall, Slab (floor / ceiling / interior) and
   glass state is `VoxelStore`'s; `Board3DLive` meshes it; nothing writes a `TileMapLayer` cell, an `Image` blit or a
   `Sprite2D` for it. (Rewritten at END-7: it used to say voxels reach the *tilemap* only through `set_cell()` /
   `_set_voxel_cell()`, which policed the 2D placement that was deleted.) Slab is a voxel class sharing this rule, not a second
   path. Hook-checked as **R8 `voxel-state-through-the-store`**: neither `voxel_board.gd` nor `board3d_live.gd` may call
   `set_cell()` / `erase_cell()`. Prop tiles on the structure layer are outside it until R3D-PROPS.

9. **A level is derived, never typed.** `VoxelBoard`'s level registry is keyed by
   ABSOLUTE level and the ground plane is `PLAYABLE_LEVEL` (80). Ask
   `board.ground_plane_level()` / `GeometryCoords.storey_level_base(storey)`
   for an anchor, `GeometryCoords.FLOOR_TOP_LEVEL` / `FLOOR_DEEP_LEVEL` for the
   ground stack, and `board.relative_level(level)` for a per-level offset.
   A literal is wrong in both directions and neither one raises: `has_level(0)`
   is false and `voxel_world_position(cell, 0)` answers `Vector2.ZERO` (as did
   `get_layer(0)` returning **null** before END-6, and the pre-renumber floor levels `-1` / `-2`), so the
   caller takes its own branch and does nothing at all, forever; a stale
   positive literal names a REAL level eighty levels from where it means,
   so the code runs and quietly describes a different building. Cost when
   ignored, all found on 2026-09-01 (OCC-FIX-03): the occlusion wireframe drew
   a wedge to the scene origin, the dev occlusion overlay painted in one pile
   there, three props' `_apply_z_index()` had become a silent no-op, the damage
   gallery reported 8 of 8 CEILING probes as "no Slab", and four selftests were
   passing against fixtures 72–80 levels from the geometry they were named for.
   Hook-checked as **L1 `level-never-a-literal`** — an integer literal handed to
   `has_level()`, `level_origin()`, `level_z_index()` or the level argument of
   `voxel_world_position()` outside `voxel_board.gd`, which owns the registry (retargeted
   at END-7 from `get_layer()`, which went with the level layers).

10. **A material FAMILY is asked, never compared.** `glass` is not one material
   — G-D16 makes it a family (`glass_armored`, `glass_screen_*`) whose members
   share every behaviour that matters: they do not occlude, they group into
   panes, they let a round through, they render on their own transparent layers,
   they drop no smoke, they anchor no shards. A bare `material == "glass"`
   excludes every new member and **fails silently** — the new material is simply
   an opaque wall that happens to be named glass, and nothing errors. Ask
   `GlassMaterials.is_glass(id)`. Hook-checked as **L2 `glass-is-a-family`**,
   which reads the roster out of `glass_materials.gd` rather than duplicating it;
   the seam module and `godot/scripts/tools/` (where selftests assert on fixture
   and map DATA, not behaviour) are the two exemptions.

11. **A HUD widget is named only inside `hud_controller.gd`.** UI-SPLIT-02
   (2026-09-09) made that file the facade the DESIGN branch owns: it resolves
   every widget out of `godot/scenes/ui/hud.tscn`, raises a signal for each
   interaction, and exposes `set_*`/`update_*` for each thing the engine
   changes. The engine asks; it never holds a Button. Before this, `room.gd`
   carried 21 `$HUD/...` `@onready` lookups and three more controllers reached
   through it, so renaming a button on the design branch broke the game at
   RUNTIME with a null `@onready` — silent to the compiler, the linter and
   every other gate, which is exactly why it needs one of its own. Adding
   something the engine must drive means adding a signal or a method here,
   never handing the node out. Hook-checked as **L3
   `hud-widget-behind-the-facade`**; the seam's behaviour is pinned by
   `hud_seam_selftest`, which runs against the real scene so a rename fails
   there instead of on screen.

**Enforcement:** rules 1–5, 8, 9, 10 and 11 are pre-commit-hook-checked
(`check_invariants.py`); 6–7 rely on review.

**Banned terms & eliminated patterns** (`SUBCUBE_*`, `WallContainer`,
`FACE_CENTER_OFFSET`, `is_x_varying`, Kenney derivations, …):
[`docs/DIRECTION_GLOSSARY.md`](docs/DIRECTION_GLOSSARY.md) §10 is the single
authoritative list — do not use or recreate anything on it.

### Bake invariants (B1–B6) — B1, B3, B5 retired; B2, B4, B6 survive where they still apply

The bake (facade atlas pages, `BakedTileLookup`, damage composite pages, TileSet alternatives) was the 2D board's and went at
R3D-END END-4. The 3D board samples the facade itself through UVs (`TextureResolver`, `MaterialRegistry`). Record and closure
evidence: [`docs/technical/BAKE_SYSTEM_REFERENCE.md`](docs/technical/BAKE_SYSTEM_REFERENCE.md) (historical).

- **B1 Branch Exclusivity — RETIRED.** There is one placement path and it is not an atlas (rule 8 / R8 replaces it).
- **B2 Grayscale Enforcement — SURVIVES** for facade / pattern art: all facade sources are grayscale (R==G==B), gated by
  `tools/persistent/check_facade.py` (a colored or un-imported facade is rejected with no error at all).
- **B3 Alpha from Canon — RETIRED.** It guarded the silhouette of pre-projected atoms; a 3D face has no atom.
- **B4 FNV-1a Determinism — SURVIVES** where a hash picks something that must not change between runs: the pinned constants live
  in `facade_sampler.gd` (hook-checked), and `FacadeSampler`'s window origins, `EarthVariantSelector`, the shot hit / punch
  tables and the glass opening pick read them.
- **B5 No Re-bake on Destruction — RETIRED.** There is no bake to skip; exposed geometry is drawn from the store.
- **B6 Loud-Fail — SURVIVES** as a general rule (see the error-handling contract above): a missing facade, decal or catalogue entry fails
  loudly (`Board3DLive`'s decal catalogue, `check_decal.py`, `voxel_decal_selftest`), never silently.

## Process — what not to do

- No design decisions or new systems without Director sign-off.
- No modifying files outside the task's scope without warning first.
- No weakening acceptance tests to make a task easier to close.
- No silently working around a blocker — report it.
- No hardcoded player-facing strings — `tr("domain.key")`.
- No empirical pixel offsets on voxel layer positions — positions are
  analytically derived (Transform Canon, `QUICK_REFERENCE.md`).
- ⏸ **The Engine-Only rule below is SUSPENDED since 2026-09-14, until the
  performance milestone closes** (Director: *"vamos suspender o JAMES até
  terminar o milestone de performance - você faz tudo, sem divisão de
  tarefas"*). Meanwhile Claude owns the interface too — `godot/scripts/ui/`,
  `godot/scenes/ui/`, `hud_controller.gd`, `input_controller.gd`. Rule 11 / L3
  still holds: the HUD seam is architecture, not staffing. On `main`,
  `check_design_scope.py` only warns. Recorded in
  `DEVICE_DIAGNOSTICS_MASTER_PLAN` §14.6, including what JAMES's branch must do
  before he resumes.
- **Claude is Engine-Only role** — Never modify visual layer scripts under
  `godot/scripts/ui/` or canvas HUD setups in `room.tscn`, unless strictly
  requested by the Director to expose a new engine signal or state container.
  UI belongs to the parallel branch `feat/design-interface-hud`, operated by
  JAMES (Qwen) from its own clone at `../INFILTRAITOR_DESIGN`. JAMES's charter
  is [`QWEN.md`](QWEN.md) — Qwen Code auto-loads that name, not this file — the
  shared process doc is [`.README_WORKSPACE.md`](.README_WORKSPACE.md), and the
  task list is
  [`PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md`](PROMPTS/PLANNING/INTERFACE_MASTER_PLAN.md).

## Reference map

Read the linked doc before modifying that system.

| Topic | Document | Essential |
|---|---|---|
| **Game design canon** (any gameplay-facing proposal) | [`docs/DESIGN_MASTER_PLAN.md`](docs/DESIGN_MASTER_PLAN.md) | Every ratified mechanic in one place. Confrontation/cover, 3-layer resistance + the tenth-shot rule, the 3 equipment classes, enemy factions and hierarchy, segment map structure and Freelance escalation are **designed and unbuilt** — extend that design, never invent a parallel one. §19 = the six architecture rules an endless game depends on; §20 = where the build already diverges |
| Grid, screen coords, voxel constants | [`tools/persistent/QUICK_REFERENCE.md`](tools/persistent/QUICK_REFERENCE.md) | `ceiling_lift = WALL_FLOOR_STEP_PX * (max_floors + 0.75)`; `TILE_OFFSET = (112, 64)`; two-plane model (gameplay grid vs. geometry/render grid) — never a per-height lookup table |
| Directions, faces, banned terms | [`docs/DIRECTION_GLOSSARY.md`](docs/DIRECTION_GLOSSARY.md) | Vertex-aligned compass, N = top diamond vertex; always qualify axes explicitly |
| Voxel wall system | [`docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md`](docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md) | The geometry is canon (8 voxels per GU axis, 8 levels per storey, slices, edges, junction columns, D16's two-voxel wall). "1 voxel = 1 Godot tile" is history: the 2D drawing rule went at R3D-END |
| Baking system (**historical**) | [`docs/technical/BAKE_SYSTEM_REFERENCE.md`](docs/technical/BAKE_SYSTEM_REFERENCE.md) | The atlas bake was deleted at R3D-END END-4 (`BakeConfig` at END-6); what survives is the logic — `TextureResolver`'s tier ladder, `MaterialRegistry`, `FacadeSampler`'s FNV-1a, grayscale facades (B2, B4, B6 above) |
| Voxel FACE lighting | [`PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md`](PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md) | 12-bucket directional brightness; blast soot/crater/ember visuals; destruction persists through rotation |
| Actor/object bakes, digital twin | [`PROMPTS/PLANNING/ACTOR_MASTER_PLAN.md`](PROMPTS/PLANNING/ACTOR_MASTER_PLAN.md) | ⏭️ **2026-09-23: D64 — actors render as LIVE skinned meshes lit by the board's cell planes (the frame bake retires for gameplay; D17, D34, D42, D44, D62 reopened), D65 — static props are meshes, breakable props are voxels.** **The decision register (D1–D58)** — twin (showcase) vs. simplification (gameplay, D16); normal-map relighting (D17); the character decisions are D32–D58 |
| **How the agent MOVES** (situations, poses, transitions, motion design) | [`PROMPTS/PLANNING/MOVEMENT_MASTER_PLAN.md`](PROMPTS/PLANNING/MOVEMENT_MASTER_PLAN.md) | ⏭️ **2026-09-23: motion is authored as ACTIONS on the live rig (D64), not baked frames.** 🟡 v0.1 — a captured brief, not yet executable. **The pipeline is PROVEN** (Director, 2026-08-16): proportion and viability are closed, motion QUALITY is what is open. The agent is a stealth infiltrator, so movement is situational, not a neutral cycle — M1–M5. **Key poses first, in-betweens second.** Research (§4) runs before authoring; CC0 is a hard filter (D57). Five items come first (§6) |
| **The player character** (model, rig, poses, animation, layering) | [`PROMPTS/PLANNING/CHARACTER_MASTER_PLAN.md`](PROMPTS/PLANNING/CHARACTER_MASTER_PLAN.md) | ⏭️ **2026-09-23: the rig becomes the runtime mesh (D64); `r3d_live_rig_export.py` keys the p3 phases into actions (no `.blend` holds one).** **Owns the build; ACTOR owns the decisions — cite D-rows, never restate them.** Rigged low-poly mesh (D35); four facings, permanently (D44); only archetype × silhouette class multiplies, everything else is additive or a free shader uniform (D34); RAM is the constraint, not CPU (D42). **Part 2 is CLOSED (2026-08-16) — the vector placeholder is gone and the pipeline is Director-ratified (D62)**; the step is 0.56 s per GU (D61) and a faction is a palette on one mesh (D63); Alpha closes mechanics, finish is Beta (D54); the hand bar is pose-capable, not anatomically correct (D56); CC0 is a licence filter, not a preference (D57, shortlist in §5.1) |
| Destruction | [`PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md`](PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md) | Sole writer of `Voxel.visible`; dirty-flag/TIC machinery other systems (actor damage) reuse |
| **Draw order / depth on the board** (**historical** — what covered what on the 2D board) | [`PROMPTS/PLANNING/RENDER_ORDER_MASTER_PLAN.md`](PROMPTS/PLANNING/RENDER_ORDER_MASTER_PLAN.md) | 🔒 **History since R3D-END (2026-09-25).** It solved depth for a board drawn as stacked `TileMapLayer`s (glass as a tile in its level's layer, the crack clip, the seam cull — all deleted at END-2). On the 3D board **a depth buffer decides what covers what by construction**; what carries over is the traps it records and Y-sort's measured cost. The 2D overlays and actors still sort by `z_index` (`WALL_BASE_Z_INDEX + relative_level`, `VoxelBoard.level_z_index()`), which encodes HEIGHT, never depth |
| **The 3D board migration** (anything that renders the board, stores voxel state, or retires a 2D-board rule) | [`PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md`](PROMPTS/PLANNING/RENDER3D_MASTER_PLAN.md) | 🟡 v1.29 — **R3D-END IS DONE (END-0 to END-8, 2026-09-24/25); the device gate ran on the Moto and the Galaxy with no regression. 2026-09-26: the post-close cleanup is done; the Director closes R3D at R3D-LIGHT (next session, step 1 = incremental occupancy, see the plan's top block); every other stage is a follow-on track; R3D-SURFACES (photographic horizontal surfaces) is planned, not started.** The 2D board is gone: no path writes a tile; `VoxelRenderer` is **`VoxelBoard`** (the state the board draws: the level registry `level_origin()` / `level_z_index()` / `has_level()`, the light and soot cell planes, the dirty -> `voxel_destroyed` pass, the glass and shard records); `BakeConfig`, `floor_layer`, the bake, the tile atlases and the 2D face shader are deleted. `34881f81` is the last commit that builds the 2D board. Every step was held to the END-0 set (`pixel_gate.py --against`, the `board_probe` dumps diffed against END-0, `ground_gate.py`'s recorded digests, `run_selftests.py`). **Still 2D by design:** the structure layer (props), actors, the 2D overlays and `VISUAL_GRID_OFFSET` until R3D-PROPS / R3D-ACTORS. **After the end:** R3D-WORLD, R3D-ROT (rotation), R3D-LOOK, R3D-LIGHT, R3D-CLAIMS, R3D-BUFFER, and the Moto / Galaxy device matrix (END-8). ⚠️ **Identity gates, all of them run before trusting a change: `board_probe.py gate|shadow|roundtrip` (voxels + cell planes, never a tile), `pixel_gate.py` (no other Godot alive, the editor included, or it times out at 600 s), `shot_3d_gate.py`, `mirror_gate.py`, `occ_canonical_gate.py`, `ground_gate.py`, `run_selftests.py`.** ⚠️ **A gate that reads a `TileMapLayer` is VACUOUS on the 3D board and prints PASS: read the population it prints against the board's.** ⚠️ **Before skipping or deleting a function on the 3D board, list what else it does** (R3D-10 skipped the shot pre-cook for its tile minting and lost its light-field warm; END-4's layer-material removal silently dropped a cell-plane creation, caught only by the probe dumps). **Rules: a NEW VFX stores world-space state (ground + height), never screen pixels; a level is asked of `ground_plane_level()`, never a literal.** The session records are `PROMPTS/RESUMO_SESSAO_2026-09-24_*.md` and `PROMPTS/RESUMO_SESSAO_2026-09-25_*.md`. |
| **Device measurement** (Android handsets, memory, frame budget, `DevFlags`, telemetry, scenarios) | [`PROMPTS/PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md`](PROMPTS/PLANNING/DEVICE_DIAGNOSTICS_MASTER_PLAN.md) | 🟢 v1.13 (2026-09-26: R3D-LIGHT's desktop baseline, the top block; 2026-09-25: the END-8 matrix on the only board, both handsets, no regression; the top block). Budget: 30 fps / 33.3 ms on playback frames (§0.5), on the Moto g04s and the Galaxy A16. The chain is `export_android.py` → `device_run.py --mem-poll` → `bench_analyze.py`. A flag reaches the APK only through `DevFlags` (`adb push` of `dev_flags.cfg`). §15 holds the 2D-vs-3D evidence; the top blocks hold the R3D-13 baseline on both handsets (Moto and Galaxy A16), the shot-tail A/B and the R3D-14 A/B. **Galaxy A16 serial `R5CY8122K7D`; put multi-step device runs in a bash script (zsh does not word-split, macOS has no `timeout`); the first boot after an install is noisy; an `adb install -r` of a throwaway APK must be proven in (compare the compiled `.gdc`) and the source diffed clean afterwards** |
| **Prediction / simulate-without-committing** (any preview, estimate, or "what if") | [`PROMPTS/PLANNING/PREDICTION_MASTER_PLAN.md`](PROMPTS/PLANNING/PREDICTION_MASTER_PLAN.md) | ✅ **BUILT 2026-08-09, all 6 tasks.** `build_plan()` is PURE — it returns a `WorldDelta` and `delta.commit()` is the only writer; the pipeline is an 11-phase resumable state machine (`begin()`/`step(budget)`/`cancel()`); `PredictionCache` keys on `(signature, room._world_revision)`. **Bump the revision from any new committed mutation** (`room.bump_world_revision()`) or predictions go stale. §2 is the authoritative mutation inventory (7 `set_damage()` sites, all behind `commit_damage()`); the soot layer was always pure; firearms use `apply_point_impact()` and share neither. **§8.8 supersedes §1.1's phase table** — the map-wide voxel walk is 66% of the cost, not the soot BFS or the light field |
| Weapons & arsenal catalog | [`PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md`](PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md) | Four delivery shapes (RADIAL/CONE/LINE/NONE) + step falloff; owns *what* a weapon emits, never *how* voxels break; facing constants are measured from baked frames, never reasoned |
| AI & guard behavior | [`docs/systems/AI_MASTER_PLAN.md`](docs/systems/AI_MASTER_PLAN.md) | FSM via Rule 4; alert meter via Rule 5; guard↔guard only via signals in `room.gd` |
| Map system | [`docs/systems/MAP_MASTER_PLAN.md`](docs/systems/MAP_MASTER_PLAN.md) | `MapSpec` contract; Rule 7 (buffer only in `MapCompiler`) |
| MAPFILE persistence (`.map.json`) | [`docs/technical/MAPFILE_REFERENCE.md`](docs/technical/MAPFILE_REFERENCE.md) | Sections versioned + owner-registered; unknown sections round-trip verbatim; loud-fail load |
| Lighting & visibility | [`docs/systems/LIGHT_MASTER_PLAN.md`](docs/systems/LIGHT_MASTER_PLAN.md) | Visual brightness ≠ tactical visibility; lights come from the map |
| Localization | [`docs/technical/LOCALIZATION_REFERENCE.md`](docs/technical/LOCALIZATION_REFERENCE.md) | `tr("domain.key")`; singleton via `get_node_or_null("/root/Localization")`; dev overlays stay English |
| Art authoring (any new texture/decal) | [`ASSETS/ART_SPECIFICATIONS.md`](ASSETS/ART_SPECIFICATIONS.md) | `TEX_AUTHORING_N = 16` texels/voxel is PINNED; never pre-stretch for projection — the compositor owns it. A facade is **1024×512 grayscale, never pre-squared** (D34 mirrors it vertically) and serves that material's wall, roof AND floor. A colored or un-imported facade is rejected with **no error at all** — Tier.NONE, generic atlas, silently wrong; measure a new one and reimport after every re-export. §7 = damage decals (square 256×256, alpha, 3 variants/family/material) |
| **Character bakes** (any new frame, palette or posed export) | [`docs/pipelines/character_bake_pipeline.md`](docs/pipelines/character_bake_pipeline.md) | ⏭️ **Retires for gameplay at `RENDER3D` R3D-ACTORS (D64); the game still draws these frames until then.** Blender model → posed GLB → windowed Godot frame bake. Camera is 30°/45° and CANNOT move (D26 — a wrong angle breaks the light maths silently); scale factor is fixed at 2.00/1.898 so every variant's body matches, which means total height varies with silhouette and the gate must be told (`P2_EXPECTED_HEIGHT_M`). §8 is the trap table — `P1_MODEL` is not a model-script variable, and stage 2's closing log prints the WRONG out_dir |
| Asset & TileSet pipeline | [`tools/persistent/ASSET_PIPELINE_QUICK_REFERENCE.md`](tools/persistent/ASSET_PIPELINE_QUICK_REFERENCE.md) | One on-disk TileSet (`tileset_blocks` 256×128) that only the STRUCTURE layer and `GroundGrid`'s geometry still use; **the voxel board has no TileSet, no atom and no reimport into tiles** — the 3D board reads the `ASSETS/materials/<id>/` facades and decals directly |
| Mobile device testing | [`tools/persistent/MobileTesting.md`](tools/persistent/MobileTesting.md) | ⏭️ **Since 2026-09-23 the phone test is the release APK (Director: web export no longer needed): `export_android.py` → `device_run.py` / `device_record.py`, flags via `dev_flags.cfg`.** The web + ngrok flow below is history |
| File map, API surface | [`tools/persistent/CODEMAP.md`](tools/persistent/CODEMAP.md) | **Generated — never hand-edit, never mirror lists here.** Consult on demand |
| Full documentation index | [`docs/README.md`](docs/README.md) | Every doc that exists; a dead link there is a bug |

**CODEMAP governance:** `python3 tools/persistent/gen_codemap.py`
(`--check` fails if stale) — the pre-commit hook regenerates and blocks
stale commits.
