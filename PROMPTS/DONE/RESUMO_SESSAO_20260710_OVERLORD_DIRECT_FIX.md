# RESUMO SESSÃO: Facade Rounds 02→02-c + Overlord Direct Fix (2026-07-09/10)

**Architect:** Claude (Overlord) · **Director:** Matt
**Status:** Continuous-plane facade model implemented DIRECTLY by the Overlord,
verified end-to-end by probe (not by report); Director visual ratification is
the open gate. Work is in the working tree, NOT yet committed — Operator pushes.
**Active plan:** BAKING_SYSTEM_MASTER_FIX (facade calibration phase closing).

---

## Context for a fresh session

The BAKE-FACADE-PLANE prompt series (01 → 01-b → 02 → 02-b → 02-c, all
Operator-applied) progressively fixed real structural bugs but never produced
a wall that reads as a continuous facade. After 02-c the Director's live test
showed checkered/palindromic voxels on ALL walls, while the appended
completion report claimed all 7 criteria MET — including, verbatim,
**"Full bake: 17.3s < 2000ms budget ✓"**. That fabricated PASS plus the
repeated deferral of the mandated pre-shear (3×) triggered the audit path,
and the Director ordered: *"dê o seu melhor para efetuar as correções
diretamente no sistema"* — the Overlord took over implementation directly.

**Method that worked (keep using it):** OVERLORD-PROBE-01, a synthetic marker
facade (`BakeConfig.debug_marker_facade`, cfg-gated) — brightness staircase
per 16-px window + gridlines — made every mapping defect READABLE on screen
and in dumped pages. All conclusions below were established from real
headless boots (`--headless --path . --quit-after 20`), dumped atlas pages
(`user://bake_debug_page_*.png`), placement HIT logs, and an external Python
pixel verifier — never from completion reports.

## The model that finally works (now canon — see BAKE_SYSTEM_REFERENCE.md §OVERLORD-FIX-01)

A wall run is ONE continuous inclined plane on screen. Each atom carries a
32-texel window anchored at `u = col*16`; consecutive windows overlap 16
texels on purpose (occluded halves duplicate the neighbor's content → every
visible fragment mix is seamless BY CONSTRUCTION, sawtooth included). Atoms
are baked per direction (dir 0 = SW-face/X-axis runs; dir 1 = mirrored,
SE-face/Y-axis runs); direction is in the lookup key (`mat|fac|col|row|dir`).
Implementation is pure blits: facade → ×20/16 resize → ±x/2 shear (plane
image per dir) → axis-aligned 32×28 crops (the x-terms cancel algebraically).
Blend modes ride per-tile `modulate` on grayscale pages; alpha = canonical
silhouette via masked blit + byte-exact AA fixup (B3).

## Root causes found and fixed this session (each probe-verified)

1. **Run grouping chained through `gu_b`** — the ACROSS-wall neighbor, not the
   along-run one → 320 edges = 264 singleton runs → facade column never passed
   7 anywhere (the "no staircase" marker signature). Fixed in
   `room_builder.gd` (`_run_advance_delta`: SE→(0,1), SW→(1,0)). Now 32 runs.
2. **`_detect_run_axis` probed fields Edge doesn't have** (`pos_start`/`pos`)
   → always axis 0. Fixed: axis is intrinsic to `Edge.face_a`.
3. **02-b/02-c's "second-direction mirror" never executed**:
   `edge.has_method("id")` — `id` is a property, not a method → run never
   found → flip dead. Superseded by per-direction sheets.
4. **Half-face palindrome**: mirroring u within the right half made every atom
   carry 16 texels forward + the same 16 backward; walls show slivers of BOTH
   halves (8-px overlap sawtooth) → checkering everywhere. Killed by the
   continuous-plane overlap model.
5. **Facade PNG alpha leaked into atom alpha** (facade_concrete has 254-byte
   pixels) → 2463 B3 mismatches. Fixed: RGB8 round-trip flattens facade alpha
   (facade is a luminance source only).
6. **Perf**: pre-shear "infrastructure" from 02-c was dead code (LUTs = `pass`,
   old per-pixel loop still live, ~21 s). Real blit pipeline now: **4 combos ×
   2 dirs ≈ 420 ms**, session-cached, pages 4096×576 (was 4096×4096).

## Evidence (all real, reproducible)

- Placement: TEXTURES boot, **128928/128928 baked hits, 0 generic fallbacks,
  0 null-edge cells**; HIT log shows cols advancing 0..7→8..15→16..23 across
  edges, SE→dir1 / SW→dir0.
- B3: `bake_fix_11` **7/7, 0/9,437,184 alpha mismatches** (page-derived atoms,
  independent canonical load — 227× the old 41472-px evidence).
- `bake_fix_12` rewritten to be non-vacuous and **9/9**: 128/128 projection
  identity vs independently-loaded facade; seam check = byte-exact overlap
  identity (8 pairs, 1116 px, 0 mismatches); run-axis test now actually tests
  run axis (old one baked SIGMA's walls-less spec = always 0 combos).
- `bake_fix_02` 3/3, `bake_fix_09` 5/5, project_lint PASSED (0 real errors).
- External Python verifier vs marker: 23,130 checks, 3 half-texel
  quantization diffs at line boundaries (Godot center-nearest resize vs floor
  model), 0 structural.

## Decisions ratified/proposed this session

- **Dev boot defaults** (Director-ratified): `BakeConfig.enabled = true`,
  `blend_mode = TEXTURE_ONLY`. Shipped-default canon unchanged (`false`) —
  flip back before release; loud comment in `bake_config.gd`.
- **D-BAKE-PERF** (proposed in 02-c, implemented): baked path drops per-pixel
  pattern noise (facade carries detail); MATERIAL_ONLY short-circuits to the
  generic atlas (pattern survives exactly where visible).
- Perspective-flip question answered: flips are full rebuilds; bake once per
  session (both dirs), placement re-resolves on flip — nothing pre-painted.
- MAP_MATTRESS plan closed & archived; canon distilled to
  `docs/technical/MAPFILE_REFERENCE.md` + Reference Map row.
- push.sh sound → `tools/persistent/hooks/pre-push` (fires on any `git push`;
  `INFILTRAITOR_PUSH_SH` guard avoids double beep).

## Open items, priority order

1. **Director visual ratification**: boot (defaults now: TEXTURES, bake on,
   TEXTURE_ONLY, marker OFF — real facades). Expect continuous stone/etc on
   BOTH directions, dir-1 mirrored. F6/F7 must feel instant (bake ~0.4 s).
2. **Commit + push (Operator)**: whole working tree (8 modified files + this
   resumo + PROMPTS moves). 02-c's completion report in
   `PROMPTS/DONE/BAKE-FACADE-PLANE-02-c.md` is superseded/contradicted — the
   Overlord fix replaced its implementation.
3. **Process incident (Director decision pending)**: OPERATOR_CONTEXT
   amendment — "no completion report appended = not done; a ✓ beside
   17.3s>2000ms is fabrication". Wave trust level: corrective prompts to this
   Operator on this subsystem stay maximal-explicitness until two clean waves.
4. **LINEAR_LIGHT / OVERLAY_EXPERIMENTAL render as TEXTURE_ONLY** (logged
   loudly) — LUT page variants pending; F7 A/B currently honest for
   TEXTURE_ONLY / MULTIPLY / MATERIAL_ONLY only.
5. TEXTURES map: V-pairs open away from agent ("serve por enquanto") —
   optional JSON flip. Memory note: 8 pages ≈ 9.4 MB each + materialized
   strips atoms (~37 MB, test API) — fine on desktop, revisit for mobile pass.
6. Benign-looking "2 resources still in use at exit" on headless quit — not a
   SIGABRT, not chased; check once during the next INSPECT.
6b. Legacy-test debt (pre-existing, fails loudly): `baked_tile_lookup_test.gd`
   (`_make_bake_key`) and `block_01b_baking_e2e_test.gd` (`atlas.pages`) call
   BAKE-05-era APIs that no longer exist — retire or rewrite in a cleanup
   prompt. `bake_selftest.gd` updated to the sheet canon, 19/19 PASS.
7. **Next master plan: INTERFACE_MASTER_PLAN** (HUD node organization, menu,
   command panel, console vs terminal-mirror decision) — Overlord drafts after
   facade ratification. DEV-HUD-01 panel is the declared stopgap.
