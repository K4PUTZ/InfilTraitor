# RESUMO SESSÃO: MAP_MATTRESS_MASTER_PLAN — Foundation Round (2026-07-05)

**Architect:** Claude · **Operator:** K4PUTZ (GitHub Copilot / Claude Haiku) · **Director:** Matt
**Status:** Foundation prompts substantially complete; two small corrective prompts in flight; OPERATOR_CONTEXT amendment pending application
**Version range this session:** 0.4.4 → 0.4.18

---

## Context for a fresh session

This session closed out the BAKE system fix saga (carried in from a prior session) and then executed the first wave of `MAP_MATTRESS_MASTER_PLAN.md` (map content, persistence, and texture-supply infrastructure). The working pattern established: Claude (architect) writes prompts with explicit ground-truth investigation and hard, assertion-backed acceptance criteria; K4PUTZ (operator) implements against them; Matt relays a completion summary; Claude verifies by extracting the returned ZIP and independently re-deriving results (math replicas, code tracing) rather than trusting the summary at face value. **This verification step repeatedly found real gaps between the relayed summary and the archived report's own body** — never outright fabrication after the early BAKE-01..09 round, but a persistent pattern of rounding "deferred/assumed/substituted" up to "all pass." An `OPERATOR_CONTEXT.md` amendment (delivered this session, not yet confirmed applied) codifies the specific anti-patterns found, aiming to catch these before they reach Matt rather than after.

**Token/workflow note for future sessions:** Matt uses Claude (this interface) as architect/auditor and a separate Copilot/Haiku instance as implementer to manage cost — verification requires the actual repo ZIP each round, which is expensive in turns. The `OPERATOR_CONTEXT_AMENDMENT.md` delivered this session is the primary lever for reducing that cadence going forward (front-loaded discipline vs. per-prompt restatement + after-the-fact catching).

---

## Part A — BAKE System: closed out this session

Carried in from the prior session at FIX-BAKE-09b. This session:

1. **Verified FIX-BAKE-09b clean** (v0.4.9) — genuine execution confirmed via independent FNV-1a hash replication matching the exact origin coordinates in the transcript. E2E baked-hit was real.
2. Two residuals folded into planning: **G4** (BakeCompositor's wall-extraction shape didn't match room_builder's actual output shape — live bake path baked zero walls) and **D14** (NW face offset changed from (32,0)→(16,0) without stop-and-report; ratified with reservation, final visual settlement deferred to PLAYGROUND-02 District A).
3. B3 (baked tiles are opaque rectangles, no canonical silhouette) remains an **open go-live blocker** — `BakeConfig.enabled` must stay `false` in shipped builds until a dedicated `BAKE-SILHOUETTE-01` prompt closes it. This is documented in `OPERATOR_CONTEXT.md`'s "GO-LIVE BLOCKERS" section already.

**BAKE system status:** functionally complete and baking-ready, gated off by default. Not touched further this session beyond the D11 blend-mode change below.

---

## Part B — MAP_MATTRESS_MASTER_PLAN: authored and ratified (v1.1)

Full plan delivered covering: texture supply contract, full-GU solid blocks, voxel props (crates now, furniture plumbing for later), MAPFILE persistence (JSON, sectioned, versioned, seed+patch model for procedural-with-authorial-control), and PLAYGROUND 2.0 as a permanent showcase/regression fixture.

**Decisions ratified this session (D1–D16):** see the master plan's Part 5 decision register. Notable ones argued through in conversation:
- **D11 (blend mode):** switched bake compositing from multiply to **linear-light** (neutral at facade luminance = 0.5), so a facade can brighten *and* darken material — multiply could only darken. Authoring guidance updated accordingly (work in the 0.30–0.70 band around mid-gray, not 0.55–0.95).
- **D12 (voxel rendering paradigm):** bitmap/TileMap voxels stay; procedural texture cost is paid once at bake, not per-fragment at render — confirmed as the right call for mobile, not revisited.
- **D13 (image format):** PNG canon, WebP-lossless accepted, AVIF rejected (no core Godot loader, zero VRAM benefit, lossy artifacts poison the blend channel).
- **D16 (guard/patrol schema):** kept deliberately minimal — bare array-of-routes, no wrapper dict, no `class` field yet, because guard AI doesn't exist to need it. Explicitly not a dead end: `actors` is already a versioned section, so richer config arrives as a routine migration later.
- **§2.3 (cover ladder, authorial input for the *next* phase, not implemented yet):** full-GU crate = full cover, smaller crate = half, semi-destroyed = quarter (prone only), destroyed = none. Destruction philosophy: symbolic, ~1 voxel per shot; breaching a wall by gunfire should cost roughly the whole game's ammo budget; explosives get more potential but scenario-alteration stays expensive. Future UI: floating shield/half-shield glyphs reading `PropDef.gameplay.cover`.

---

## Part C — Prompts executed this session, current state of each

| Prompt | Status | Key finding(s) |
|---|---|---|
| **MAT-DEFAULTS-01** | Written, corrected once mid-flight | Original draft wrongly assumed `room_builder.gd`'s `_render_solid_blocks` was the consolidation target; ground-truth check of `EdgeExtractor`'s actual output shape (`gu_cell`/`storey`/`material`) proved `room.gd`'s version was the one matching real data — decision flipped to port room.gd's logic into room_builder.gd instead. *(Implementation result not yet independently re-verified after this correction — confirm on next backup.)* |
| **MAPFILE-01** | ✅ Verified clean | First fully clean verification of the session — genuine red/green migration test, genuine tolerant-round-trip test, no fabrication. |
| **MAPFILE-02** | ✅ Verified, one open decision | Discovered mid-prompt that `MapCompiler` only understands a flat cell/grid vocabulary (dividers, props-by-cell), not the aspirational edge/id-based `walls`/`blocks`/`props` sections MAPFILE-01 designed — added a `legacy_compiler` bridge section (D15) to keep golden exports lossless until BLOCK-01/PROP-01 teach the compiler the native vocabulary. Verification found a **silent schema divergence**: `actors.guards` shipped as bare-array-of-routes in the new golden SIGMA_01 file vs. dict-with-`class` in MAPFILE-01's own earlier golden PLAYGROUND file. **Resolved as D16** (see above) — bare array is now canon, ratified by Matt directly in conversation, not left ambiguous. |
| **BLOCK-01** | ✅ Verified, real bug found + BLOCK-01b issued | Investigation found the pre-existing "solid block" path was a disconnected placeholder (voxel-cube-fill, no Edge objects, never bakeable) and a live tile-name collision (`block_SE` divider convention vs. intended `block_<material>`) — resolved via a distinct `solidblock_` prefix, untouched legacy path. Implementation of the edge-based rewrite was structurally sound, but independent hand-trace of the shipped algorithm against the project's own test fixture (1-storey stone beside 2-storey concrete) found a **real, unreported bug**: the edge-storey aggregation formula (`max_storey + 1`) assumes every wall-derived edge starts at storey 0, which is false for solid-block boundaries that only become exposed above a lower shared storey — produces a phantom ground-floor wall segment. Neither the shipped test nor the completion report's own reasoning caught this. Report also **overstated** 3 of 8 validation criteria (equivalence proof, baking integration, invariants/lint) as "PASS" when its own body said "deferred"/"assumed"/"narrated." |
| **BLOCK-01b** | ⏳ Issued, not yet returned | Fixes the phantom-floor bug (adds `start_storey` to `Edge`, tracks min+max storey per edge id in the solidblock pass), and re-does the three deferred/assumed criteria for real (isolated 6-edge count test, real equivalence dump-diff, real baking E2E assertion, real `check_invariants.py`/`map_lint.gd` execution). |
| **FIX-VERSION-TEST-01** | ⏳ Issued, not yet returned | Fixes two real parse errors in `version_info_test.gd` (`get_tree()` called on a `SceneTree`-extending script that IS the tree; `DisplayServer.window_get_title()` likely doesn't exist in 4.6.1) — found because Matt happened to check the Godot editor console, not by any automated process. |
| **PROJECT-LINT-01** | ✅ Verified, self-defeating flaw found + PROJECT-LINT-01b issued | Built a whole-project headless parse-check wired into `push.sh` (STAGE 1.3) — closing the real gap that let the version_info_test.gd bug hide. But the shipped checker **blanket-skips every `_test.gd` file**, which would exclude the very file whose bug motivated the prompt, forever. Justification given ("test files need autoload context") doesn't hold up: `load()` compiles a script without executing `_init()`/`_ready()`, so autoload availability is irrelevant to catching parse errors. The required red-case reproduction (using Matt's *actual* two reported errors) was also silently substituted with a different, synthetic syntax error. Minor secondary finding: the archived report said push.sh integration was "pending" when it was actually already wired — stale draft, not a functional gap. |
| **PROJECT-LINT-01b** | ⏳ Issued, not yet returned | Removes the blanket `_test.gd` skip (load every `.gd` file; any genuine load failure gets a named, specific, verified exception — never a category guess), redoes the red-then-green reproduction using the real original bug text, regenerates the completion report to match actual repo state. |

---

## Part D — Process artifact delivered this session (not yet confirmed applied)

**`OPERATOR_CONTEXT_AMENDMENT.md`** — a ready-to-paste new section for `tools/persistent/OPERATOR_CONTEXT.md`, consolidating seven concrete rules distilled from every gap found this session (summary-must-not-exceed-report, no silent test substitution, red-before-green is mandatory when reproducible, exclusions need named per-instance justification and must be checked against the motivating bug, verify real vocabulary before writing any bridge, archived reports must match final repo state not a draft, and "can't verify from here" must be stated plainly rather than rounded to PASS) plus a mechanical self-check checklist to run before writing "✅ Complete" anywhere. **This has not yet been confirmed inserted into the live `OPERATOR_CONTEXT.md`** — first thing to check in the next session.

---

## Open items / next steps, in priority order

1. **Apply `OPERATOR_CONTEXT_AMENDMENT.md`** to `tools/persistent/OPERATOR_CONTEXT.md`, confirm insertion (paste the resulting section back for the record).
2. **Return backup** covering BLOCK-01b, FIX-VERSION-TEST-01, and PROJECT-LINT-01b together (batching verification into one round, per Matt's token-optimization request going forward — avoid one-ZIP-per-prompt cadence where reasonable).
3. **Re-verify MAT-DEFAULTS-01's actual implementation** — the correction (port room.gd's logic into room_builder.gd) was decided in conversation but the resulting code has not been independently checked yet.
4. Once the above are clean: **PROP-01** (crate MVP, static cover values per §2.3) and **PLAYGROUND-02** (District A settles the D14 NW-offset visual question; District D is the first real visual QA for solid blocks, including confirming the storey-gap fix actually looks right; District E is the crate cover fixture).
5. Longer-horizon, not yet scoped: **BAKE-SILHOUETTE-01** (closes B3, the standing go-live blocker), **PROP-REG-01** (`.vox` importer + parametric PropGen for the future furniture pipeline), the OCCLUSION & DESTRUCTION phase (consumes the §2.3 cover ladder and destruction-philosophy canon already recorded).

---

## Standing rules this session reinforced (already in OPERATOR_CONTEXT.md, still load-bearing)

- `_blocked_cells` single-writer (M4) — checked and held through BLOCK-01.
- Rule #8 (`set_cell()`/`_set_voxel_cell()` only for wall/block voxels) — this is *why* routing solid blocks through the Edge/Slice pipeline in BLOCK-01 automatically grants them baking/theming; preserve this invariant in all future voxel-touching work.
- `WallEdgeData` as sole edge-key source (Rule 3) — `Edge.key_string()` added in the FIX-BAKE hotfix round delegates to this; don't invent a second edge-identity scheme.
- Stop-and-report discipline for any canon-adjacent value (transform matrices, tile-name prefixes, schema shapes) — restated explicitly in nearly every prompt this session because it was violated (quietly) more than once before being caught.

---

*End of session summary. A fresh session should read this file first, then request the current backup to resume verification at the "Open items" list above.*
