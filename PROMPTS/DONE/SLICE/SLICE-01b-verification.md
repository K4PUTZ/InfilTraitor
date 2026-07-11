# SLICE-01b — Geometry Module Verification (Post-Revert Audit)

> **Series:** SLICE — verification pass, sits between SLICE-01 (accepted) and SLICE-02
> (previous attempt reverted after breaking wall rendering). **Nature:** READ-ONLY audit +
> selftest execution. This prompt does not add, remove, or wire anything. Its only output
> is a pass/fail report and, if needed, a short list of specific fixes to propose back to
> the design director before SLICE-02 is attempted again. Do not touch `room.gd` or any
> scene file in this prompt under any circumstance.

---

## CONTEXT

On 2026-07-01 a SLICE-02 Stage A attempt (wiring `geometry/` into `room.gd`) broke wall
rendering (walls disappeared, then returned malformed and out of position). The design
director reverted to an earlier commit. A static audit of the recovered state (see
`docs/history/refactor_logs/AUDIT_20260702_estado_seguro.md`) confirmed:

- The live render path is still 100% the legacy system
  (`subcube_geometry.gd` → `room.gd` → `WallContainerClass`), with SLICE-00's transform
  canon applied. This is what's on screen right now and it is correct.
- `godot/scripts/geometry/` (SLICE-01's module) is fully present and has **zero**
  references from any production script — confirmed dormant, as designed.
- However, three files inside the module carry a **later timestamp** than the rest and
  contain functionality beyond SLICE-01's original scope:
  - `voxel_renderer.gd` has a `render_block()` method (not in the SLICE-01 spec).
  - `edge_extractor.gd` and `slice_generator.gd` were also touched after initial creation.
  - These are almost certainly partial groundwork from the SLICE-02 attempt that
    survived the revert (the revert appears to have restored `room.gd` and the legacy
    files, but not necessarily the `geometry/` folder to its exact SLICE-01-acceptance
    state).

This means the module has **unknown drift** from the last verified-good state
(SLICE-01's own acceptance checks A1–A8). Before trusting it as the foundation for a new
SLICE-02 attempt, we need to know exactly what changed and whether it's still internally
consistent — not assume either "it's fine" or "it's broken."

---

## TASK

### V1 — Re-run SLICE-01's original acceptance checks, verbatim

Re-verify A1–A6 from `PROMPTS/DONE/SLICE-01-geometry-module.md` against the CURRENT state
of `godot/scripts/geometry/`:

- **A1:** file inventory unchanged (same 11 files + `.uid`, no new/missing files).
- **A2:** `class_name` declared once each, no duplicates outside the folder.
- **A3:** `grep -rin "subcube" godot/scripts/geometry/` → still ZERO matches.
- **A4:** `grep -rin "slice_index" godot/scripts/geometry/` → still ZERO matches.
- **A5:** `geometry_selftest.gd` runs headless, exits 0, all 6 check groups pass.
- **A6:** `slice_geometry_selftest.gd` (SLICE-00 canon) still exits 0.

Report each as PASS/FAIL with the actual command output, not a summary.

### V2 — Diff the three drifted files against SLICE-01's spec

For `edge_extractor.gd`, `slice_generator.gd`, `voxel_renderer.gd`:

1. List every function/method present that is **not** named in SLICE-01 T6/T8's spec
   (e.g. `render_block()`). For each extra method found, read it fully and report:
   - What it does, in one sentence.
   - Whether it's self-contained (only calls methods that exist inside `geometry/`) or
     reaches outside the module (would indicate a half-finished wiring stub).
   - Whether it's dead code (nothing in the module calls it — expected today, since
     nothing is wired) or already invoked internally.
2. Confirm the functions that ARE in SLICE-01's original spec still match their
   documented signature and behavior (no accidental edits while adding the new ones).
3. Explicitly check `render_block(gu_cell, storey_count, material)` for correctness
   against the Transform Canon and against `slice_voxel_positions()` / the
   `_render_solid_blocks` intent implied by `slice_02_integration_selftest.gd`'s Check 3
   and Check 4 — since that selftest clearly expects this method to exist and work.

### V3 — Run the SLICE-02 integration selftest in its current (pre-wiring) state

Run `slice_02_integration_selftest.gd` headless now, BEFORE any wiring exists. Expected:
most/all of its 6 checks FAIL, because `room.gd` has no integration yet. Confirm they fail
for the RIGHT reason (absence of wiring in `room.gd`), not for a wrong reason (e.g. a
crash, a missing method inside `geometry/` itself, a broken reference). If any check fails
because something inside `geometry/` is broken rather than simply "not wired yet," flag it
as a blocking finding — that would be a real regression, not an expected pre-integration
state.

### V4 — Confirm total isolation from live game code (unchanged from SLICE-01 A8 intent)

- `grep -rln "EdgeRegistry\|SliceGenerator\|VoxelRenderer\|EdgeExtractor\|JunctionResolver\|HighWallGroup" godot/scripts/` restricted to paths OUTSIDE `godot/scripts/geometry/` and `godot/scripts/tools/` → must be empty.
- `room.gd` byte-for-byte unaffected by anything in `geometry/`: confirm no preload/const/
  reference to the `geometry/` folder anywhere in `room.gd`.
- Smoke test: launch the project, confirm the game renders identically to the current
  known-good screenshot (walls aligned, no console errors/warnings beyond pre-existing
  baseline).

### V5 — Report

Produce `PROMPTS/DONE/SLICE-01b-verification-report.md` with:

1. Table of V1 checks, PASS/FAIL + evidence.
2. List of every drifted function found in V2, with the self-contained/reaches-outside/
   dead-code classification.
3. V3 results with the "failed for the right reason" judgment per check.
4. V4 confirmation.
5. A clear **VERDICT**: either
   - "Module is verified consistent with SLICE-01 intent plus additive, self-contained
     groundwork — safe foundation for a new SLICE-02 attempt," or
   - "Module has drift that needs correction before SLICE-02: [specific list]."
6. If verdict is the second, do NOT attempt fixes in this prompt — stop and report back
   for a design decision on each item.

---

## DO NOT TOUCH

- `room.gd`, any `.tscn` file, any legacy world script (`subcube_geometry.gd`,
  `wall_container.gd`, `subcube_coords.gd`, `map_compiler.gd`) — read-only references.
- Nothing inside `godot/scripts/geometry/` gets modified in this prompt, even if V2 finds
  something questionable — only reported.
- No commits beyond adding the report file itself.

---

## ACCEPTANCE

- **B1:** `SLICE-01b-verification-report.md` exists with all 5 sections filled from actual
  command output (no paraphrased/assumed results).
- **B2:** V1's A1–A6 all re-confirmed PASS, or each FAIL is explicitly explained.
- **B3:** Every method found in V2 is classified (self-contained / reaches-outside /
  dead-code) with no "unknown" left unresolved.
- **B4:** V3's 6 checks are each annotated with "failed for expected reason" or "blocking
  finding."
- **B5:** A single clear VERDICT sentence at the top of the report (repeated from section
  5), so the design director can read one line and know whether to proceed to SLICE-02.
- **B6:** Zero files under `godot/scripts/geometry/`, `godot/scripts/world/`, or any
  `.tscn` modified — only the new report file added.

Do not commit automatically.
