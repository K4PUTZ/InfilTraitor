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
orientation. Godot 4.6, GDScript, isometric 2.5D voxels via `TileMapLayer`.
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
- Generated PNGs land in `ASSETS/ISOMETRIC/source_assets/generated/`; switch
  focus to Godot and wait 3–5s for reimport — no manual rebuild.
- On interruption or session resume: re-read the active prompt/plan file
  from disk first and state the resume point in one line before continuing.
  Conversational memory is not ground truth; the file on disk is.

## Verification protocol (before declaring anything done)

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
capture (a real windowed Godot boot):
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
  survived. This is the rotation working, not data loss. Consequences: don't
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

1. Stats = `var`, never `const` (future difficulty scaling).
2. `VISUAL_GRID_OFFSET` always via parameter, never hardcoded.
3. `WallEdgeData` is the only source of edge keys — never recreate
   `_edge_key()`.
4. Guard state transitions go through `_enter_state()`, never direct
   `state =`.
5. `_alert_meter` accumulates only in `_apply_tic_result()`, nowhere else.
6. Mission structure stays independent of narrative (logic ≠ text).
7. Maps use internal coords only; the buffer is applied only in
   `MapCompiler`.
8. Wall and Slab voxels (floor/ceiling/interior) reach the tilemap only
   through `set_cell()`/`_set_voxel_cell()`, never `blend_rect`, `Image`,
   or `Sprite2D`. **Slab is a voxel class sharing this rule, not a second
   placement mechanism** (2026-07-15 amendment) — a future Slab renderer
   has no excuse to invent a parallel image-compositing path.

**Enforcement:** rules 1–5 are pre-commit-hook-checked
(`check_invariants.py`); 6–8 rely on review.

**Banned terms & eliminated patterns** (`SUBCUBE_*`, `WallContainer`,
`FACE_CENTER_OFFSET`, `is_x_varying`, Kenney derivations, …):
[`docs/DIRECTION_GLOSSARY.md`](docs/DIRECTION_GLOSSARY.md) §10 is the single
authoritative list — do not use or recreate anything on it.

### Bake invariants (B1–B6)

Enforced by selftests + the pre-commit hook. Full detail, closure evidence,
and process learnings:
[`docs/technical/BAKE_SYSTEM_REFERENCE.md`](docs/technical/BAKE_SYSTEM_REFERENCE.md).

- **B1 Branch Exclusivity** — placement uses exactly one atlas path (baked
  XOR generic), never both.
- **B2 Grayscale Enforcement** — all facade/pattern sources are grayscale
  (R==G==B).
- **B3 Alpha from Canon** — silhouette never generated from scratch; alpha
  verified against the canonical voxel texture loaded independently, never
  a tautological self-comparison.
- **B4 FNV-1a Determinism** — hash values and wall-origin behavior stay
  pinned.
- **B5 No Re-bake on Destruction** — exposed geometry falls back to the
  material atlas.
- **B6 Loud-Fail** — missing dependencies fail loudly, never silently.

## Process — what not to do

- No design decisions or new systems without Director sign-off.
- No modifying files outside the task's scope without warning first.
- No weakening acceptance tests to make a task easier to close.
- No silently working around a blocker — report it.
- No hardcoded player-facing strings — `tr("domain.key")`.
- No empirical pixel offsets on voxel layer positions — positions are
  analytically derived (Transform Canon, `QUICK_REFERENCE.md`).

## Reference map

Read the linked doc before modifying that system.

| Topic | Document | Essential |
|---|---|---|
| **Game design canon** (any gameplay-facing proposal) | [`docs/DESIGN_MASTER_PLAN.md`](docs/DESIGN_MASTER_PLAN.md) | Every ratified mechanic in one place. Confrontation/cover, 3-layer resistance + the tenth-shot rule, the 3 equipment classes, enemy factions and hierarchy, segment map structure and Freelance escalation are **designed and unbuilt** — extend that design, never invent a parallel one. §19 = the six architecture rules an endless game depends on; §20 = where the build already diverges |
| Grid, screen coords, voxel constants | [`tools/persistent/QUICK_REFERENCE.md`](tools/persistent/QUICK_REFERENCE.md) | `ceiling_lift = WALL_FLOOR_STEP_PX * (max_floors + 0.75)`; `TILE_OFFSET = (112, 64)`; two-plane model (gameplay grid vs. geometry/render grid) — never a per-height lookup table |
| Directions, faces, banned terms | [`docs/DIRECTION_GLOSSARY.md`](docs/DIRECTION_GLOSSARY.md) | Vertex-aligned compass, N = top diamond vertex; always qualify axes explicitly |
| Voxel wall system | [`docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md`](docs/technical/VOXEL_MASTER_PLAN/VOXEL_MASTER_PLAN.md) | 1 voxel = 1 Godot tile via `set_cell()`; no image compositing |
| Baking system | [`docs/technical/BAKE_SYSTEM_REFERENCE.md`](docs/technical/BAKE_SYSTEM_REFERENCE.md) | `BakedTileLookup.resolve()` is the only placement seam; `BakeConfig.enabled` defaults `false`; B1–B6 above |
| Voxel FACE lighting | [`PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md`](PROMPTS/PLANNING/VOXEL_LIGHT_MASTER_PLAN.md) | 12-bucket directional brightness; blast soot/crater/ember visuals; destruction persists through rotation |
| Actor/object bakes, digital twin | [`PROMPTS/PLANNING/ACTOR_MASTER_PLAN.md`](PROMPTS/PLANNING/ACTOR_MASTER_PLAN.md) | **The decision register (D1–D58)** — twin (showcase) vs. simplification (gameplay, D16); normal-map relighting (D17); the character decisions are D32–D58 |
| **How the agent MOVES** (situations, poses, transitions, motion design) | [`PROMPTS/PLANNING/MOVEMENT_MASTER_PLAN.md`](PROMPTS/PLANNING/MOVEMENT_MASTER_PLAN.md) | 🟡 v0.1 — a captured brief, not yet executable. **The pipeline is PROVEN** (Director, 2026-08-16): proportion and viability are closed, motion QUALITY is what is open. The agent is a stealth infiltrator, so movement is situational, not a neutral cycle — M1–M5. **Key poses first, in-betweens second.** Research (§4) runs before authoring; CC0 is a hard filter (D57). Five items come first (§6) |
| **The player character** (model, rig, poses, animation, layering) | [`PROMPTS/PLANNING/CHARACTER_MASTER_PLAN.md`](PROMPTS/PLANNING/CHARACTER_MASTER_PLAN.md) | **Owns the build; ACTOR owns the decisions — cite D-rows, never restate them.** Rigged low-poly mesh (D35); four facings, permanently (D44); only archetype × silhouette class multiplies, everything else is additive or a free shader uniform (D34); RAM is the constraint, not CPU (D42). **Part 2 is CLOSED (2026-08-16) — the vector placeholder is gone and the pipeline is Director-ratified (D62)**; the step is 0.56 s per GU (D61) and a faction is a palette on one mesh (D63); Alpha closes mechanics, finish is Beta (D54); the hand bar is pose-capable, not anatomically correct (D56); CC0 is a licence filter, not a preference (D57, shortlist in §5.1) |
| Destruction | [`PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md`](PROMPTS/PLANNING/DESTRUCTION_MASTER_PLAN.md) | Sole writer of `Voxel.visible`; dirty-flag/TIC machinery other systems (actor damage) reuse |
| **Prediction / simulate-without-committing** (any preview, estimate, or "what if") | [`PROMPTS/PLANNING/PREDICTION_MASTER_PLAN.md`](PROMPTS/PLANNING/PREDICTION_MASTER_PLAN.md) | ✅ **BUILT 2026-08-09, all 6 tasks.** `build_plan()` is PURE — it returns a `WorldDelta` and `delta.commit()` is the only writer; the pipeline is an 11-phase resumable state machine (`begin()`/`step(budget)`/`cancel()`); `PredictionCache` keys on `(signature, room._world_revision)`. **Bump the revision from any new committed mutation** (`room.bump_world_revision()`) or predictions go stale. §2 is the authoritative mutation inventory (7 `set_damage()` sites, all behind `commit_damage()`); the soot layer was always pure; firearms use `apply_point_impact()` and share neither. **§8.8 supersedes §1.1's phase table** — the map-wide voxel walk is 66% of the cost, not the soot BFS or the light field |
| Weapons & arsenal catalog | [`PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md`](PROMPTS/PLANNING/WEAPON_MASTER_PLAN.md) | Four delivery shapes (RADIAL/CONE/LINE/NONE) + step falloff; owns *what* a weapon emits, never *how* voxels break; facing constants are measured from baked frames, never reasoned |
| AI & guard behavior | [`docs/systems/AI_MASTER_PLAN.md`](docs/systems/AI_MASTER_PLAN.md) | FSM via Rule 4; alert meter via Rule 5; guard↔guard only via signals in `room.gd` |
| Map system | [`docs/systems/MAP_MASTER_PLAN.md`](docs/systems/MAP_MASTER_PLAN.md) | `MapSpec` contract; Rule 7 (buffer only in `MapCompiler`) |
| MAPFILE persistence (`.map.json`) | [`docs/technical/MAPFILE_REFERENCE.md`](docs/technical/MAPFILE_REFERENCE.md) | Sections versioned + owner-registered; unknown sections round-trip verbatim; loud-fail load |
| Lighting & visibility | [`docs/systems/LIGHT_MASTER_PLAN.md`](docs/systems/LIGHT_MASTER_PLAN.md) | Visual brightness ≠ tactical visibility; lights come from the map |
| Localization | [`docs/technical/LOCALIZATION_REFERENCE.md`](docs/technical/LOCALIZATION_REFERENCE.md) | `tr("domain.key")`; singleton via `get_node_or_null("/root/Localization")`; dev overlays stay English |
| Art authoring (any new texture/decal) | [`ASSETS/ART_SPECIFICATIONS.md`](ASSETS/ART_SPECIFICATIONS.md) | `TEX_AUTHORING_N = 16` texels/voxel is PINNED; never pre-stretch for projection — the compositor owns it. A facade is **1024×512 grayscale, never pre-squared** (D34 mirrors it vertically) and serves that material's wall, roof AND floor. A colored or un-imported facade is rejected with **no error at all** — Tier.NONE, generic atlas, silently wrong; measure a new one and reimport after every re-export. §7 = damage decals (square 256×256, alpha, 3 variants/family/material) |
| **Character bakes** (any new frame, palette or posed export) | [`docs/pipelines/character_bake_pipeline.md`](docs/pipelines/character_bake_pipeline.md) | Blender model → posed GLB → windowed Godot frame bake. Camera is 30°/45° and CANNOT move (D26 — a wrong angle breaks the light maths silently); scale factor is fixed at 2.00/1.898 so every variant's body matches, which means total height varies with silhouette and the gate must be told (`P2_EXPECTED_HEIGHT_M`). §8 is the trap table — `P1_MODEL` is not a model-script variable, and stage 2's closing log prints the WRONG out_dir |
| Asset & TileSet pipeline | [`tools/persistent/ASSET_PIPELINE_QUICK_REFERENCE.md`](tools/persistent/ASSET_PIPELINE_QUICK_REFERENCE.md) | One on-disk TileSet (`tileset_blocks` 256×128, floor tiles only, `source_assets/generated/` scan); voxel atoms (32×16) build in memory at room load, no `.tres` |
| Mobile device testing | [`tools/persistent/MobileTesting.md`](tools/persistent/MobileTesting.md) | Local HTTP server + ngrok tunnel; re-export `export/web` after code changes |
| File map, API surface | [`tools/persistent/CODEMAP.md`](tools/persistent/CODEMAP.md) | **Generated — never hand-edit, never mirror lists here.** Consult on demand |
| Full documentation index | [`docs/README.md`](docs/README.md) | Every doc that exists; a dead link there is a bug |

**CODEMAP governance:** `python3 tools/persistent/gen_codemap.py`
(`--check` fails if stale) — the pre-commit hook regenerates and blocks
stale commits.
