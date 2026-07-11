# BAKE-FIX-03 — Close B3 For Real: Visual QA Against the Generic Renderer

> **Part of `PROMPTS/PLANNING/BAKING_SYSTEM_MASTER_FIX.md` (Phase 3). Depends on
> BAKE-FIX-01 + BAKE-FIX-02 landing. This is the prompt that actually earns "B3
> closed" — every prior attempt (`FIX-BAKE-04`, `FIX-BAKE-09`, `FIX-BAKE-09b`,
> `BAKE-SILHOUETTE-01`) marked it closed on selftest output alone and was wrong every
> time. This prompt's bar is a literal pixel comparison against the real, currently-
> shipping generic renderer — not another selftest.**

---

## CONTEXT

`BAKING_MASTER_PLAN.md`'s own B3 definition: "the baked wall's shape is bit-identical
to the generic wall's shape by construction — this is what makes the swap risk-free."
No prior BAKE-FIX or FIX-BAKE prompt ever actually checked that literally — they
checked "does this tile have both opaque and transparent pixels somewhere," which is
necessary but not sufficient (a wrong-shaped silhouette can still have both). This
prompt does the real check: render the same wall both ways and diff the pixels.

---

## MODULE

- No production code expected to change unless this prompt finds a real discrepancy —
  if it does, that's a bug found by this prompt, fix it here and say so plainly in the
  completion report (do not silently patch and under-report it as "QA passed with
  minor adjustment").
- `godot/scripts/tools/` — new comparison tool if one doesn't already fit
- `tools/persistent/OPERATOR_CONTEXT.md` — B3 status, only after the comparison
  actually passes

---

## TASK

### 1. Pixel-identical shape comparison

For each of the 4 materials, each of the 4 wall compass directions, and at least one
V-junction corner (to exercise the mirrored column from BAKE-FIX-02):

- Render the wall with `BakeConfig.enabled = false` (generic path) and capture the
  rendered pixels.
- Render the same wall with `BakeConfig.enabled = true` (baked path, this plan's new
  master-strip pipeline) and capture the rendered pixels.
- Diff alpha channels pixel-for-pixel. They must match exactly — same silhouette,
  same shape, at every orientation and at the junction column. RGB will legitimately
  differ (that's the facade texture doing its job) — only alpha/shape must be
  identical.
- Paste the literal diff result (pixel counts matched/mismatched), not a screenshot
  described in prose.

### 2. Continuity check

- Confirm a multi-edge wall run's facade texture reads as visually continuous across
  slice boundaries (no visible seam at each 8-voxel edge boundary) and continues into
  its V-junction's mirrored column without an obvious discontinuity.
- Confirm the two other junction-column cases from BAKE-FIX-02 (material override
  with facade on, material override with facade off) render as expected in an actual
  loaded map, not just in the headless test.

### 3. Live smoke test

- Enable baking (`user://bake_config.cfg`, `enabled=true`) on PLAYGROUND. Load it.
  Walk the whole map visually (or via the comparison tool). No opaque rectangles, no
  invisible walls, no seams, no z-fighting between baked wall layers.
- Revert the config. Confirm `BakeConfig.enabled` still defaults to `false` with no
  config file present — no regression to the shipped default.

### 4. Close B3

Only after 1–3 pass with literal evidence: update `OPERATOR_CONTEXT.md`'s GO-LIVE
BLOCKERS section. Replace the current "B3 RE-OPENED" language (from this session's
correction) with the real closure: cite this prompt's pixel-diff evidence, not a
selftest assertion. Leave a note that `BakeConfig.enabled`'s *default* (on vs. off for
shipped builds) is still a separate Director decision, not implied by B3 closing.

---

## DO NOT TOUCH

- `BakeConfig.enabled`'s hardcoded default — stays `false` regardless of this
  prompt's outcome; enabling by default is a separate, explicit Director call.
- Anything in `junction_resolver.gd` (detection logic, unrelated to this QA pass).

---

## ACCEPTANCE

```bash
godot --headless --check-only 2>&1 | grep -iE 'error|SCRIPT ERROR' || echo "parse OK"
# pixel-diff tool output, literal, for all 4 materials x 4 orientations x junction case
```

- Completion report includes the literal pixel-diff results (§1), the continuity
  check description with evidence (§2), and the live PLAYGROUND smoke-test outcome
  (§3) — screenshots or exact pixel comparisons, not narrative claims.
- `OPERATOR_CONTEXT.md`'s B3 entry only changes if §1–3 actually passed. If they
  didn't, this prompt's job is to report exactly what's wrong, not to close B3 anyway.
- Bump `VERSION` per repo convention.

---

**Scope:** QA + doc update, code changes only if a real bug surfaces · 1 session ·
unblocks BAKE-FIX-04.
